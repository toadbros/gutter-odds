extends Node

signal status_changed(text: String)
signal peers_changed
signal lobby_changed

const DEFAULT_PORT := 7777
const MAX_PESTS := 6

var status: String = "Solo barn"
var entries: Dictionary = {}
var roster: Dictionary = {}
var local_name: String = "Trainer"
var host_port: int = DEFAULT_PORT
var join_ip: String = "127.0.0.1"
var _closing: bool = false


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_gone)


func is_online() -> bool:
	return multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED


func is_server() -> bool:
	return is_online() and multiplayer.is_server()


func is_client() -> bool:
	return is_online() and not multiplayer.is_server()


func local_id() -> int:
	if is_online():
		return multiplayer.get_unique_id()
	return 1


func trainer_name(peer_id: int = -1) -> String:
	if peer_id < 0:
		peer_id = local_id()
	if roster.has(peer_id):
		return str(roster[peer_id].get("name", "Trainer"))
	if peer_id == local_id():
		return local_name
	return "Trainer %d" % peer_id


func is_ready(peer_id: int = -1) -> bool:
	if peer_id < 0:
		peer_id = local_id()
	if roster.has(peer_id):
		return bool(roster[peer_id].get("ready", false))
	return false


func seat_count() -> int:
	if roster.is_empty():
		return 1 if is_online() else 0
	return roster.size()


func everyone_ready() -> bool:
	if roster.is_empty():
		return is_server()
	for pid in roster.keys():
		if not bool(roster[pid].get("ready", false)) and int(pid) != 1:
			return false
	return true


func sanitize_name(text: String) -> String:
	var cleaned := text.strip_edges()
	if cleaned.is_empty():
		cleaned = "Trainer"
	if cleaned.length() > 16:
		cleaned = cleaned.substr(0, 16)
	return cleaned


func clamp_port(value: int) -> int:
	return clampi(value, 1024, 65535)


func lan_addresses() -> PackedStringArray:
	var out: PackedStringArray = []
	for addr in IP.get_local_addresses():
		var text := str(addr)
		if text.contains(":"):
			continue
		if text.begins_with("127.") or text.begins_with("0."):
			continue
		if text.begins_with("169.254."):
			continue
		out.append(text)
	return out


func host_table(player_name: String, port: int = DEFAULT_PORT) -> bool:
	close()
	_closing = false
	local_name = sanitize_name(player_name)
	host_port = clamp_port(port)
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(host_port, MAX_PESTS)
	if err != OK:
		_set_status("Couldn't open port %d. Is it already in use?" % host_port)
		return false
	multiplayer.multiplayer_peer = peer
	entries.clear()
	roster.clear()
	_seat(local_id(), local_name, true)
	_set_status("Table open on %d. Wait for trainers, then start." % host_port)
	Game.enter_lobby()
	lobby_changed.emit()
	peers_changed.emit()
	return true


func join_table(player_name: String, ip: String, port: int = DEFAULT_PORT) -> bool:
	close()
	_closing = false
	local_name = sanitize_name(player_name)
	join_ip = ip.strip_edges()
	if join_ip.is_empty():
		join_ip = "127.0.0.1"
	host_port = clamp_port(port)
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(join_ip, host_port)
	if err != OK:
		_set_status("Couldn't reach %s:%d." % [join_ip, host_port])
		return false
	multiplayer.multiplayer_peer = peer
	_set_status("Walking over to %s:%d..." % [join_ip, host_port])
	return true


func close() -> void:
	_closing = true
	entries.clear()
	roster.clear()
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	_set_status("Solo barn")
	peers_changed.emit()
	lobby_changed.emit()
	get_tree().call_group("net_puppet", "queue_free")


func toggle_ready() -> void:
	if Game.phase != Game.Phase.LOBBY:
		return
	var next := not is_ready()
	if is_client():
		rpc_id(1, "rpc_set_ready", next)
	else:
		_set_ready_flag(local_id(), next)


func request_start() -> void:
	if not is_server():
		return
	if Game.phase != Game.Phase.LOBBY:
		return
	if not everyone_ready():
		Game.toast.emit("Everyone needs to ready up first.")
		return
	rpc_start_meet.rpc()
	_spawn_all_puppets()
	Game.begin_night()


func request_ring() -> void:
	if is_client():
		rpc_id(1, "rpc_ring")
	else:
		Game.ring_the_bell()


func request_next_race() -> void:
	if is_client():
		rpc_id(1, "rpc_next_race")
	else:
		Game.request_next_race()


func submit_entry(bird: Dictionary) -> void:
	var payload := ChickenStock.wire_payload(bird)
	if is_client():
		rpc_id(1, "rpc_submit_entry", payload)
	else:
		_accept_entry(local_id(), payload)


func scratch_entry() -> void:
	if is_client():
		rpc_id(1, "rpc_scratch_entry")
	else:
		_drop_entry(local_id())


func send_snapshot(data: Variant) -> void:
	if not is_server() or multiplayer.get_peers().is_empty():
		return
	rpc_snapshot.rpc(data)


func send_race_event(payload: Dictionary) -> void:
	if not is_server() or multiplayer.get_peers().is_empty():
		return
	rpc_race_event.rpc(payload)


func broadcast_meet() -> void:
	if not is_server():
		return
	rpc_meet.rpc(Game.pack_meet())


func broadcast_field(payload: Array) -> void:
	if not is_server():
		return
	rpc_field.rpc(payload)


@rpc("any_peer", "call_remote", "reliable")
func rpc_hello(player_name: String) -> void:
	if not multiplayer.is_server():
		return
	var pid := multiplayer.get_remote_sender_id()
	if Game.phase != Game.Phase.LOBBY:
		_refuse_peer(pid, "Table's mid-meet. Join when they're back in lobby.")
		return
	if not roster.has(pid) and seat_count() >= MAX_PESTS:
		_refuse_peer(pid, "Table's full. Six trainers max.")
		return
	_seat(pid, sanitize_name(player_name), false)
	_broadcast_roster()


@rpc("any_peer", "call_remote", "reliable")
func rpc_set_ready(ready: bool) -> void:
	if not multiplayer.is_server():
		return
	_set_ready_flag(multiplayer.get_remote_sender_id(), ready)


@rpc("authority", "call_remote", "reliable")
func rpc_roster(packed: Array) -> void:
	roster.clear()
	for row in packed:
		if row is Dictionary:
			_seat(int(row.get("id", 0)), str(row.get("name", "Trainer")), bool(row.get("ready", false)))
	lobby_changed.emit()
	peers_changed.emit()


@rpc("authority", "call_remote", "reliable")
func rpc_start_meet() -> void:
	_spawn_all_puppets()
	Game.begin_guest()


@rpc("authority", "call_remote", "reliable")
func rpc_late_join() -> void:
	_spawn_all_puppets()
	Game.begin_guest()


@rpc("any_peer", "call_remote")
func rpc_ring() -> void:
	if not multiplayer.is_server():
		return
	Game.ring_the_bell()


@rpc("any_peer", "call_remote")
func rpc_next_race() -> void:
	if not multiplayer.is_server():
		return
	Game.request_next_race()


@rpc("any_peer", "call_remote")
func rpc_submit_entry(payload: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	_accept_entry(multiplayer.get_remote_sender_id(), payload)


@rpc("any_peer", "call_remote")
func rpc_scratch_entry() -> void:
	if not multiplayer.is_server():
		return
	_drop_entry(multiplayer.get_remote_sender_id())


@rpc("authority", "call_remote", "reliable")
func rpc_meet(payload: Dictionary) -> void:
	Game.apply_meet(payload)


@rpc("authority", "call_remote", "reliable")
func rpc_field(payload: Array) -> void:
	get_tree().call_group("race_manager", "apply_network_field", payload)


@rpc("authority", "call_remote", "unreliable")
func rpc_snapshot(data: Variant) -> void:
	get_tree().call_group("race_manager", "apply_snapshot", data)


@rpc("authority", "call_remote", "reliable")
func rpc_race_event(payload: Dictionary) -> void:
	get_tree().call_group("race_manager", "apply_network_event", payload)


@rpc("authority", "call_remote", "reliable")
func rpc_results(payload: Dictionary) -> void:
	Game.apply_network_results(payload)


@rpc("any_peer", "call_remote", "unreliable")
func rpc_pose(pos: Vector3, yaw: float, pitch: float) -> void:
	var pid := multiplayer.get_remote_sender_id()
	get_tree().call_group("player_%d" % pid, "apply_remote_pose", pos, yaw, pitch)


func send_pose(pos: Vector3, yaw: float, pitch: float) -> void:
	if not is_online() or Game.is_sitting():
		return
	rpc_pose.rpc(pos, yaw, pitch)


func send_results(payload: Dictionary) -> void:
	if not is_server():
		return
	rpc_results.rpc(payload)


func _accept_entry(peer_id: int, payload: Dictionary) -> void:
	if Game.phase != Game.Phase.OPEN:
		return
	if not entries.has(peer_id) and _entry_count() >= Game.FIELD_SIZE:
		return
	var bird := ChickenStock.from_payload(payload)
	bird["owner_id"] = peer_id
	entries[peer_id] = bird
	get_tree().call_group("race_manager", "apply_player_entries")
	_sync_entries()


func _drop_entry(peer_id: int) -> void:
	if not entries.has(peer_id):
		return
	entries.erase(peer_id)
	get_tree().call_group("race_manager", "apply_player_entries")
	_sync_entries()


func _sync_entries() -> void:
	if not is_server():
		return
	var packed: Array = []
	for pid in entries.keys():
		var row: Dictionary = ChickenStock.wire_payload(entries[pid])
		row["peer_id"] = int(pid)
		packed.append(row)
	rpc_entries.rpc(packed)


@rpc("authority", "call_remote", "reliable")
func rpc_entries(packed: Array) -> void:
	entries.clear()
	for row in packed:
		if row is Dictionary:
			var bird := ChickenStock.from_payload(row)
			var pid := int(row.get("peer_id", bird.get("owner_id", 0)))
			bird["owner_id"] = pid
			entries[pid] = bird
	get_tree().call_group("race_manager", "apply_player_entries")


func _entry_count() -> int:
	return entries.size()


func _seat(peer_id: int, player_name: String, ready: bool) -> void:
	if peer_id <= 0:
		return
	roster[peer_id] = {
		"name": sanitize_name(player_name),
		"ready": ready,
	}


func _set_ready_flag(peer_id: int, ready: bool) -> void:
	if not roster.has(peer_id):
		_seat(peer_id, trainer_name(peer_id), ready)
	else:
		roster[peer_id]["ready"] = ready
	if is_server():
		_broadcast_roster()
	lobby_changed.emit()


func _broadcast_roster() -> void:
	if not is_server():
		return
	var packed: Array = []
	var ids: Array = roster.keys()
	ids.sort()
	for pid in ids:
		packed.append({
			"id": int(pid),
			"name": str(roster[pid].get("name", "Trainer")),
			"ready": bool(roster[pid].get("ready", false)),
		})
	rpc_roster.rpc(packed)
	lobby_changed.emit()
	peers_changed.emit()


func _on_peer_connected(id: int) -> void:
	if is_server():
		if Game.phase != Game.Phase.LOBBY:
			_refuse_peer(id, "Table's mid-meet. Join when they're back in lobby.")
			return
		if seat_count() >= MAX_PESTS:
			_refuse_peer(id, "Table's full. Six trainers max.")
			return
		if not roster.has(id):
			_seat(id, "Trainer", false)
		_broadcast_roster()
		_set_status("%s sat down. %d at the table." % [trainer_name(id), seat_count()])
	peers_changed.emit()
	lobby_changed.emit()


func _on_peer_disconnected(id: int) -> void:
	entries.erase(id)
	roster.erase(id)
	_despawn_puppet(id)
	if is_server():
		# Live cards keep the field as-is so survivors don't get a countdown
		# replay, a camera snap, or a restart from the pens.
		if not Game.is_live_card():
			get_tree().call_group("race_manager", "apply_player_entries")
		_sync_entries()
		_broadcast_roster()
		_set_status("Someone walked off with their crate.")
	peers_changed.emit()
	lobby_changed.emit()


func _on_connected() -> void:
	_set_status("You're at the table. Wait for the host.")
	rpc_id(1, "rpc_hello", local_name)
	if Game.phase == Game.Phase.MENU:
		Game.enter_lobby()
	peers_changed.emit()
	lobby_changed.emit()


func _on_failed() -> void:
	close()
	_set_status("Nobody answered. Check the IP, port, and that they're hosting.")


func _on_server_gone() -> void:
	if _closing:
		return
	close()
	Game.toast.emit("The host folded the table.")
	if Game.phase != Game.Phase.MENU:
		Game.return_to_menu()


func _spawn_all_puppets() -> void:
	if is_server():
		for id in multiplayer.get_peers():
			_spawn_puppet(int(id))
		return
	_spawn_puppet(1)
	for id in multiplayer.get_peers():
		_spawn_puppet(int(id))


func _despawn_puppet(peer_id: int) -> void:
	if peer_id == local_id():
		return
	for node in get_tree().get_nodes_in_group("player_%d" % peer_id):
		if node.has_method("prepare_despawn"):
			node.prepare_despawn()
		node.queue_free()
	var director := get_tree().get_first_node_in_group("race_director")
	if director and director.has_method("reassert_camera"):
		director.reassert_camera()


func _spawn_puppet(peer_id: int) -> void:
	if peer_id == local_id():
		return
	if not get_tree().get_nodes_in_group("player_%d" % peer_id).is_empty():
		return
	var world := get_tree().get_first_node_in_group("world")
	if world == null:
		return
	var scene := preload("res://scenes/rat_player.tscn")
	var puppet: RatPlayer = scene.instantiate()
	puppet.name = "Trainer_%d" % peer_id
	world.add_child(puppet)
	puppet.setup_remote(peer_id, trainer_name(peer_id))


func _refuse_peer(peer_id: int, reason: String) -> void:
	if not is_server() or peer_id <= 0:
		return
	rpc_id(peer_id, "rpc_refused", reason)
	Game.toast.emit(reason)
	_set_status(reason)
	# Defer disconnect so the refuse RPC can flush.
	call_deferred("_disconnect_peer_now", peer_id)


func _disconnect_peer_now(peer_id: int) -> void:
	var peer := multiplayer.multiplayer_peer
	if peer != null:
		peer.disconnect_peer(peer_id)


@rpc("authority", "call_remote", "reliable")
func rpc_refused(reason: String) -> void:
	_closing = true
	Game.toast.emit(reason)
	close()
	if Game.phase != Game.Phase.MENU:
		Game.return_to_menu()


func _set_status(text: String) -> void:
	status = text
	status_changed.emit(text)
