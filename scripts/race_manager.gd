extends Node3D
class_name RaceManager

const ROSTER: Array[Dictionary] = [
	{"name": "Gutter Pete", "shell": Color("c45a28"), "flavor": "Rust rooster. Mean about corn. Has won before. Remembers."},
	{"name": "Lady Cluck", "shell": Color("e8d0a8"), "flavor": "A ribbon someone tied on. She has not noticed. Or she has."},
	{"name": "Captain Comb", "shell": Color("b85a28"), "flavor": "Bit a bookie once. The bookie still limps. The chicken does not."},
	{"name": "The Brine", "shell": Color("2a2e32"), "flavor": "Black as the drain. Stood in a flood last spring and came out philosophical."},
	{"name": "Quick Nickel", "shell": Color("f0ead8"), "flavor": "Smallest on the card. Fastest off the scratch. Do not trust the pretty ones."},
	{"name": "Churchyard", "shell": Color("3a3a32"), "flavor": "Used to live behind a chapel. Has been descending, spiritually, ever since."},
	{"name": "Tin Widow", "shell": Color("8a8e86"), "flavor": "Quiet. Too quiet. The other birds won't share a kernel with her."},
	{"name": "Sir Speckle", "shell": Color("7a6a58"), "flavor": "Someone painted a crown on the wing. It will not come off."},
	{"name": "Puddle King", "shell": Color("4a6a8a"), "flavor": "Claims the wet patch of infield. Collects taxes in corn. Nobody elected him."},
	{"name": "Miss Whisper", "shell": Color("d4a078"), "flavor": "Head tilts whenever anyone whispers odds. She knows. She always knows."},
]

const MOODS: PackedStringArray = [
	"Hungry.",
	"Smug.",
	"Damp with ambition.",
	"Thinking about corn.",
	"Not thinking at all.",
	"Has a secret.",
	"Recently dropped.",
]

var field: Array[Snail] = []
var racing: bool = false
var race_time: float = 0.0
var track_length: float = 1.0
var first_finish_at: float = -1.0
var card_condition: int = RaceChaos.Condition.FAIR_DIRT
var live_event: int = RaceChaos.LiveEvent.NONE
var event_t: float = 0.0
var event_dur: float = 0.0
var event_at: float = 0.0
var events_left: int = 0
var events_used: Array[int] = []
var next_event_frac: float = 0.28
var _event_struck: bool = false
var _dealt: Array[int] = []
var _snap_t: float = 0.0
var _npc_backup: Array[Dictionary] = []

const SNAIL_SCENE := preload("res://scenes/snail.tscn")
const RACE_HARD_CAP := 75.0
const PHOTO_WAIT := 8.0


func _ready() -> void:
	add_to_group("race_manager")


func reset_night() -> void:
	racing = false
	_clear_live_event(false)
	card_condition = RaceChaos.Condition.FAIR_DIRT
	events_left = 0
	events_used.clear()
	get_tree().call_group("stadium", "apply_card_condition", card_condition)
	for snail in field:
		snail.racing = false
		snail.visible = false


func deal_field() -> void:
	if NetPlay.is_client():
		return
	racing = false
	race_time = 0.0
	first_finish_at = -1.0
	_roll_card_chaos()
	_ensure_snails()
	var path := _path()
	if path and path.curve:
		track_length = path.curve.get_baked_length()
	var min_grade := Game.race_min_grade()
	var picks := _pick_field()
	var arches: Array[Snail.Archetype] = [
		Snail.Archetype.SPRINTER,
		Snail.Archetype.STEADY,
		Snail.Archetype.CHAOS,
		Snail.Archetype.LATE,
		Snail.Archetype.STEADY,
		Snail.Archetype.CHAOS,
	]
	arches.shuffle()
	_npc_backup.clear()
	for i in Game.FIELD_SIZE:
		var roster: Dictionary = ROSTER[picks[i]].duplicate()
		var grade := mini(min_grade + (randi() % 2), ChickenStock.Grade.CROWN)
		var data := ChickenStock.make_chicken(grade, 0, {
			"id": "npc_%d_%d" % [Game.meet_index, i],
			"name": str(roster.get("name", "Chicken")),
			"shell": roster.get("shell", Color("c45a28")),
			"flavor": str(roster.get("flavor", "")),
			"archetype": arches[i],
			"hunger": 92.0,
			"condition": 90.0,
		})
		data["mood"] = MOODS[randi() % MOODS.size()]
		data["odds"] = _odds_for(ChickenStock.race_form(data), int(data["archetype"]), ChickenStock.traits_from(data.get("traits", [])))
		_npc_backup.append(data.duplicate(true))
		var start_groove := lerpf(0.42, 0.9, float(i) / float(maxi(Game.FIELD_SIZE - 1, 1)))
		field[i].configure(data, i + 1, start_groove)
		field[i].lap_length = track_length
		_place_in_pen(field[i], i)
	apply_player_entries()
	broadcast_now()
	_refresh_board()
	Game.bet_changed.emit()


func move_to_gates() -> void:
	racing = false
	for snail in field:
		snail.distance = 0.28 + snail.groove * 0.16
		snail.height = 0.0
		snail.height_vel = 0.0
		snail.finished = false
		snail.place = 0
		snail.racing = false
		snail.lap_length = track_length
		snail.reset_pose()
		_place_on_track(snail)


func start_race() -> void:
	race_time = 0.0
	first_finish_at = -1.0
	racing = true
	live_event = RaceChaos.LiveEvent.NONE
	event_t = 0.0
	event_dur = 0.0
	_event_struck = false
	next_event_frac = RaceChaos.first_event_frac()
	get_tree().call_group("stadium", "clear_live_event")
	for snail in field:
		snail.finished = false
		snail.place = 0
		snail.racing = true
		snail.finish_time = 0.0
		snail.lap_length = track_length
		snail.kick_off()


func apply_player_entries() -> void:
	if field.is_empty():
		return
	if NetPlay.is_client():
		return
	if Game.is_live_card():
		return
	var used: Dictionary = {}
	for pid in NetPlay.entries.keys():
		var bird: Dictionary = ChickenStock.from_payload(NetPlay.entries[pid])
		var slot := _slot_for_owner(int(pid), used)
		if slot < 0:
			continue
		used[slot] = true
		bird["mood"] = "Here to win. Or to grease."
		bird["odds"] = _odds_for(ChickenStock.race_form(bird), int(bird.get("archetype", 2)), ChickenStock.traits_from(bird.get("traits", [])))
		var start_groove := lerpf(0.42, 0.9, float(slot) / float(maxi(Game.FIELD_SIZE - 1, 1)))
		field[slot].configure(bird, slot + 1, start_groove)
		field[slot].form = ChickenStock.race_form(bird)
		field[slot].lap_length = track_length
		_place_in_pen(field[slot], slot)
	for i in field.size():
		if used.has(i):
			continue
		if field[i].owner_id != 0 and not field[i].chicken_id.begins_with("npc_"):
			var data: Dictionary = _npc_backup[i] if i < _npc_backup.size() else ChickenStock.make_chicken(Game.race_min_grade(), 0)
			data["odds"] = _odds_for(float(data.get("form", 1.0)), int(data.get("archetype", 2)), ChickenStock.traits_from(data.get("traits", [])))
			var start_groove := lerpf(0.42, 0.9, float(i) / float(maxi(Game.FIELD_SIZE - 1, 1)))
			field[i].configure(data, i + 1, start_groove)
			field[i].lap_length = track_length
			_place_in_pen(field[i], i)
	broadcast_now()
	_refresh_board()
	Game.bet_changed.emit()


func broadcast_now() -> void:
	if not NetPlay.is_server():
		return
	var payload: Array = []
	for snail in field:
		payload.append(snail.to_field_payload())
	NetPlay.broadcast_field(payload)
	NetPlay.broadcast_meet()


func apply_network_field(payload: Array) -> void:
	if NetPlay.is_server():
		return
	var live := Game.phase == Game.Phase.RACE or Game.phase == Game.Phase.COUNTDOWN
	if not live:
		racing = false
	_ensure_snails()
	var path := _path()
	if path and path.curve:
		track_length = path.curve.get_baked_length()
	for i in mini(payload.size(), field.size()):
		var data: Dictionary = payload[i]
		if data is Dictionary:
			var bird := ChickenStock.from_payload(data)
			bird["odds"] = Vector2i(int(data.get("odds_x", 3)), int(data.get("odds_y", 1)))
			bird["mood"] = str(data.get("mood", "Unreadable."))
			bird["hunger"] = float(data.get("hunger", bird.get("hunger", 80.0)))
			bird["traits"] = ChickenStock.traits_from(data.get("traits", bird.get("traits", [])))
			var start_groove := float(data.get("groove", lerpf(0.42, 0.9, float(i) / 5.0)))
			if live:
				# Keep live poses. configure() zeros distance and would yank the pack.
				field[i].chicken_id = str(bird.get("id", field[i].chicken_id))
				field[i].owner_id = int(bird.get("owner_id", field[i].owner_id))
				field[i].display_name = str(bird.get("name", field[i].display_name))
				field[i].lap_length = track_length
			else:
				field[i].configure(bird, i + 1, start_groove)
				field[i].lap_length = track_length
				_place_in_pen(field[i], i)
	_refresh_board()
	Game.bet_changed.emit()


func apply_snapshot(data: Variant) -> void:
	if NetPlay.is_server():
		return
	var rows: Array = []
	if data is Array:
		rows = data
	elif data is Dictionary:
		apply_chaos_state(data)
		var packed: Variant = data.get("birds", [])
		if packed is Array:
			rows = packed
	for i in mini(rows.size(), field.size()):
		var row: Dictionary = rows[i]
		if not row is Dictionary:
			continue
		var snail: Snail = field[i]
		snail.distance = float(row.get("distance", snail.distance))
		snail.groove = float(row.get("groove", snail.groove))
		snail.height = float(row.get("height", snail.height))
		snail.vel = float(row.get("vel", snail.vel))
		snail.squish = float(row.get("squish", snail.squish))
		snail.freeze_left = float(row.get("freeze_left", snail.freeze_left))
		snail.chaos_tag = str(row.get("chaos_tag", snail.chaos_tag))
		snail.finished = bool(row.get("finished", snail.finished))
		snail.place = int(row.get("place", snail.place))
		snail.racing = bool(row.get("racing", snail.racing))
		snail.finish_time = float(row.get("finish_time", snail.finish_time))
		if bool(row.get("fried", false)) and not snail.fried:
			snail.make_fried()
		_place_on_track(snail)
	get_tree().call_group("hud", "set_standings", standings())


func pack_chaos() -> Dictionary:
	return {
		"card_condition": card_condition,
		"event_id": live_event,
		"event_t": event_t,
		"event_dur": event_dur,
		"event_at": event_at,
		"events_left": events_left,
	}


func apply_chaos_state(payload: Dictionary) -> void:
	var prev_event := live_event
	var prev_cond := card_condition
	card_condition = int(payload.get("card_condition", card_condition))
	live_event = int(payload.get("event_id", payload.get("live_event", live_event)))
	event_t = float(payload.get("event_t", event_t))
	event_dur = float(payload.get("event_dur", event_dur))
	event_at = float(payload.get("event_at", event_at))
	if payload.has("events_left"):
		events_left = int(payload.get("events_left", events_left))
	get_tree().call_group("stadium", "apply_card_condition", card_condition)
	if live_event != RaceChaos.LiveEvent.NONE and live_event != prev_event:
		get_tree().call_group("stadium", "show_live_event", live_event, event_at)
	elif live_event == RaceChaos.LiveEvent.NONE and prev_event != RaceChaos.LiveEvent.NONE:
		get_tree().call_group("stadium", "clear_live_event")
	if card_condition != prev_cond and Game.phase == Game.Phase.OPEN:
		Game.event_announce("%s. %s" % [
			RaceChaos.condition_name(card_condition),
			RaceChaos.condition_tell(card_condition),
		], 0)


func apply_network_event(payload: Dictionary) -> void:
	if NetPlay.is_server():
		return
	var ended := bool(payload.get("ended", false))
	if ended:
		_clear_live_event(false)
		return
	apply_chaos_state(payload)
	var line := str(payload.get("callout", RaceChaos.event_callout(live_event)))
	var victim := str(payload.get("victim", ""))
	if not victim.is_empty():
		line = victim
	if not line.is_empty():
		Game.event_announce(line, live_event)


func _process(delta: float) -> void:
	if NetPlay.is_client():
		return
	if not racing:
		return
	race_time += delta
	_tick_live_events(delta)
	_apply_track_hazards(delta)
	var finished_count := 0
	for snail in field:
		snail.tick_crawl(delta)
	_jostle(delta)
	_stamp_chaos_tags()
	for snail in field:
		if snail.racing and not snail.finished:
			snail.distance += snail.vel * snail.line_speed() * delta
		if not snail.finished and snail.distance >= track_length:
			snail.finished = true
			snail.racing = false
			snail.finish_time = race_time
			snail.distance = track_length
			finished_count = _count_finished()
			snail.place = finished_count
			if first_finish_at < 0.0:
				first_finish_at = race_time
		_place_on_track(snail)
	_call_the_race()
	get_tree().call_group("hud", "set_standings", standings())
	_snap_t += delta
	if _snap_t >= 0.05:
		_snap_t = 0.0
		_push_snapshot()
	if _should_end():
		_finish_race()


func standings() -> Array:
	var rows: Array = []
	var order := field.duplicate()
	order.sort_custom(func(a: Snail, b: Snail) -> bool:
		if a.finished != b.finished:
			return a.finish_time < b.finish_time if a.finished and b.finished else a.finished
		return a.distance > b.distance
	)
	for i in order.size():
		var s: Snail = order[i]
		rows.append({
			"index": s.snail_id,
			"name": s.display_name,
			"color": s.shell_color,
			"progress": clampf(s.distance / maxf(track_length, 0.001), 0.0, 1.0),
			"place": s.place if s.finished else i + 1,
			"odds": s.odds,
			"tag": s.race_tag(),
			"finished": s.finished,
			"chicken_id": s.chicken_id,
			"owner_id": s.owner_id,
			"grade": s.grade,
			"yours": s.owner_id == NetPlay.local_id() and not s.chicken_id.begins_with("npc_"),
			"fried": s.fried,
		})
	return rows


func get_leader() -> Snail:
	var best: Snail = field[0] if not field.is_empty() else null
	for snail in field:
		if snail.distance > best.distance:
			best = snail
	return best


func get_broadcast_state() -> Dictionary:
	var live: Array[Snail] = []
	var max_d := 0.0
	var min_d := INF
	for snail in field:
		if snail.finished:
			continue
		live.append(snail)
		max_d = maxf(max_d, snail.distance)
		min_d = minf(min_d, snail.distance)
	if live.is_empty():
		var winner := get_leader()
		if winner == null:
			return {}
		return {
			"position": winner.global_position,
			"distance": winner.distance,
			"behind": winner.global_transform.basis.z,
			"right": winner.global_transform.basis.x,
			"spread": 0.0,
		}
	var acc_pos := Vector3.ZERO
	var acc_d := 0.0
	var wsum := 0.0
	for snail in live:
		var lag := max_d - snail.distance
		var w := exp(-lag * 0.7)
		acc_pos += snail.global_position * w
		acc_d += snail.distance * w
		wsum += w
	var dist := acc_d / maxf(wsum, 0.001)
	var pos := acc_pos / maxf(wsum, 0.001)
	var behind := Vector3(0, 0, 1)
	var right := Vector3(1, 0, 0)
	var path := _path()
	if path and path.curve:
		var length := maxf(path.curve.get_baked_length(), 0.001)
		var xf := path.curve.sample_baked_with_rotation(clampf(dist, 0.0, length), true)
		behind = xf.basis.z
		right = xf.basis.x
	return {
		"position": pos,
		"distance": dist,
		"behind": behind,
		"right": right,
		"spread": maxf(max_d - min_d, 0.0),
	}


func pack_is_stacked() -> bool:
	return _pack_count() >= 3


func get_pack_focus() -> Vector3:
	var cluster := _biggest_cluster()
	if cluster.size() >= 3:
		var acc := Vector3.ZERO
		for snail in cluster:
			acc += snail.global_position
		return acc / float(cluster.size())
	var leader := get_leader()
	return leader.global_position if leader else Vector3.ZERO


func _pack_count() -> int:
	return _biggest_cluster().size()


func _biggest_cluster() -> Array[Snail]:
	var best: Array[Snail] = []
	for snail in field:
		if snail.finished:
			continue
		var cluster: Array[Snail] = []
		for other in field:
			if other.finished:
				continue
			if absf(other.distance - snail.distance) < 0.75:
				cluster.append(other)
		if cluster.size() > best.size():
			best = cluster
	return best


func _call_the_race() -> void:
	for snail in field:
		if snail.finished or not snail.racing:
			continue
		if snail.height > 0.07:
			if not snail.told_climb:
				snail.told_climb = true
				Game.announce("%s flaps over the pack." % snail.display_name)
		elif snail.height < 0.03:
			snail.told_climb = false
			snail.told_slip = false
		if snail.groove < 0.16 and not snail.told_rail:
			snail.told_rail = true
			Game.announce("%s takes the rail." % snail.display_name)
		if snail.archetype == Snail.Archetype.LATE:
			var frac := snail.distance / maxf(track_length, 0.001)
			if frac >= 0.5 and not snail.told_cut:
				snail.told_cut = true
				Game.announce("%s dives inside." % snail.display_name)


func _finish_race() -> void:
	racing = false
	_clear_live_event(true)
	_fry_last()
	var rows := standings()
	var winner_index := 0
	for row in rows:
		if int(row["place"]) == 1:
			winner_index = int(row["index"])
			break
	_push_snapshot()
	Game.on_race_finished(winner_index, rows)


func _fry_last() -> void:
	var last: Snail = null
	var last_place := 0
	for snail in field:
		if snail.place >= last_place:
			last_place = snail.place
			last = snail
	if last == null or last_place <= 1:
		return
	last.make_fried()


func _push_snapshot() -> void:
	if not NetPlay.is_server():
		return
	var data: Array = []
	for snail in field:
		data.append({
			"distance": snail.distance,
			"groove": snail.groove,
			"height": snail.height,
			"vel": snail.vel,
			"squish": snail.squish,
			"freeze_left": snail.freeze_left,
			"chaos_tag": snail.chaos_tag,
			"finished": snail.finished,
			"place": snail.place,
			"racing": snail.racing,
			"finish_time": snail.finish_time,
			"fried": snail.fried,
		})
	var payload := pack_chaos()
	payload["birds"] = data
	NetPlay.send_snapshot(payload)


func _slot_for_owner(peer_id: int, used: Dictionary) -> int:
	for i in field.size():
		if field[i].owner_id == peer_id and not field[i].chicken_id.begins_with("npc_"):
			return i
	for i in range(field.size() - 1, -1, -1):
		if not used.has(i) and (field[i].owner_id == 0 or field[i].chicken_id.begins_with("npc_")):
			return i
	return -1


func _should_end() -> bool:
	if field.is_empty():
		return true
	if _count_finished() >= field.size():
		return true
	var photo_up := first_finish_at >= 0.0 and race_time - first_finish_at > PHOTO_WAIT
	var hard_cap := race_time >= RACE_HARD_CAP
	if not photo_up and not hard_cap:
		return false
	# Rank anyone still running so the card always pays.
	var leftover := field.filter(func(s: Snail) -> bool: return not s.finished)
	leftover.sort_custom(func(a: Snail, b: Snail) -> bool: return a.distance > b.distance)
	var next_place := _count_finished() + 1
	for s in leftover:
		s.finished = true
		s.racing = false
		s.place = next_place
		s.finish_time = race_time
		next_place += 1
	return true


func _count_finished() -> int:
	var n := 0
	for snail in field:
		if snail.finished:
			n += 1
	return n


func _ensure_snails() -> void:
	while field.size() < Game.FIELD_SIZE:
		var snail: Snail = SNAIL_SCENE.instantiate()
		add_child(snail)
		field.append(snail)


func _pick_field() -> Array[int]:
	var ids: Array[int] = []
	for i in ROSTER.size():
		ids.append(i)
	ids.shuffle()
	if _dealt.size() >= ROSTER.size() - 2:
		_dealt.clear()
	var picks: Array[int] = []
	for id in ids:
		if not _dealt.has(id) and picks.size() < Game.FIELD_SIZE:
			picks.append(id)
	# If the roster is smaller than a card, reuse leftovers.
	for id in ids:
		if picks.size() >= Game.FIELD_SIZE:
			break
		if not picks.has(id):
			picks.append(id)
	for id in picks:
		_dealt.append(id)
	return picks


func _odds_for(form: float, arch: int, traits: Array = []) -> Vector2i:
	var est := form + randf_range(-0.16, 0.16)
	match arch:
		Snail.Archetype.SPRINTER:
			est += 0.08
		Snail.Archetype.LATE:
			est -= 0.1
		Snail.Archetype.CHAOS:
			est -= 0.05
	var ids := ChickenStock.traits_from(traits)
	if ids.has(ChickenStock.Trait.QUICK_SCRATCH) or ids.has(ChickenStock.Trait.RAIL_RAT) or ids.has(ChickenStock.Trait.MEAN_BEAK):
		est += 0.05
	if ids.has(ChickenStock.Trait.NAPPER) or ids.has(ChickenStock.Trait.ONE_EYE) or ids.has(ChickenStock.Trait.GLASS_ANKLES):
		est -= 0.07
	if ids.has(ChickenStock.Trait.FRYER_FEAR):
		est -= 0.04
	if est > 1.12:
		return Vector2i(5, 2)
	if est > 1.02:
		return Vector2i(3, 1)
	if est > 0.94:
		return Vector2i(4, 1)
	if est > 0.88:
		return Vector2i(6, 1)
	return Vector2i(9, 1)


func _place_in_pen(snail: Snail, index: int) -> void:
	var marker := get_tree().get_first_node_in_group("pen_%d" % index) as Node3D
	if marker == null:
		snail.global_position = Vector3(-22.0, 0.12, float(index - 1) * 2.4)
		return
	snail.global_transform = marker.global_transform
	snail.distance = 0.0


func _place_on_track(snail: Snail) -> void:
	var path := _path()
	if path == null or path.curve == null:
		return
	var length := maxf(path.curve.get_baked_length(), 0.001)
	var d := clampf(snail.distance, 0.0, length)
	var xf := path.curve.sample_baked_with_rotation(d, true)
	var inward := Vector3(-xf.origin.x, 0.0, -xf.origin.z)
	if inward.length_squared() < 0.0001:
		inward = -xf.basis.x
	else:
		inward = inward.normalized()
	var usable := Game.TRACK_WIDTH * 0.78
	var origin := xf.origin + inward * (0.5 - snail.groove) * usable + Vector3.UP * snail.height
	snail.global_transform = Transform3D(xf.basis.orthonormalized(), origin)


func _jostle(delta: float) -> void:
	const ALONG := 0.38
	const GROOVE := 0.16
	for snail in field:
		if snail.finished or not snail.racing:
			continue
		var blocker: Snail = _inside_blocker(snail, ALONG, GROOVE)
		if blocker == null:
			snail.groove = move_toward(snail.groove, snail.desired_groove(), snail.steer_rate() * delta)
		elif snail.wants_to_climb():
			snail.climb_timer = maxf(snail.climb_timer, 0.55)
			snail.height_vel = maxf(snail.height_vel, 2.6)
			if snail.height > blocker.height + 0.055:
				snail.groove -= (0.7 if snail.archetype == Snail.Archetype.SPRINTER else 0.5) * delta
				if snail.has_trait(ChickenStock.Trait.MEAN_BEAK):
					snail.groove -= 0.18 * delta
					blocker.vel *= 0.94
				blocker.groove += 0.28 * delta
				blocker.squish = minf(blocker.squish, 0.58)
				blocker.vel *= 0.97
				var slip_chance := 0.12 * delta * 8.0
				if snail.has_trait(ChickenStock.Trait.GLASS_ANKLES):
					slip_chance *= 2.4
				if randf() < slip_chance:
					# Slip off the pile, dumped wide.
					snail.height_vel = -1.5
					snail.groove += randf_range(0.08, 0.18)
					if not snail.told_slip:
						snail.told_slip = true
						Game.announce("%s slips wide." % snail.display_name)
		else:
			# Can't pass: get squeezed a hair wide and wait.
			snail.groove = move_toward(snail.groove, blocker.groove + 0.12, 0.15 * delta)

	if live_event == RaceChaos.LiveEvent.CROWD_SQUEEZE:
		var cluster := _biggest_cluster()
		if cluster.size() >= 3:
			for snail in cluster:
				if snail.has_trait(ChickenStock.Trait.CROWD_HOG):
					snail.squish = minf(snail.squish, 0.78)
					snail.groove = clampf(snail.groove - 0.18 * delta, 0.04, 0.96)
					continue
				snail.squish = minf(snail.squish, 0.56)
				snail.groove = clampf(snail.groove + 0.22 * delta * (1.0 if snail.snail_id % 2 == 0 else -1.0), 0.04, 0.96)
				if snail.can_freeze() and randf() < 0.35 * delta:
					snail.height_vel = -1.2
					snail.groove = clampf(snail.groove + randf_range(0.06, 0.14), 0.04, 0.96)
					if not snail.told_slip:
						snail.told_slip = true
						Game.announce("%s gets pinned and dumped." % snail.display_name)

	# Soft overlap so feathers don't occupy the same dirt.
	for i in field.size():
		var a: Snail = field[i]
		if a.finished:
			continue
		for j in range(i + 1, field.size()):
			var b: Snail = field[j]
			if b.finished:
				continue
			if absf(a.distance - b.distance) > ALONG:
				continue
			if absf(a.height - b.height) > 0.09:
				continue
			var gdiff := a.groove - b.groove
			if absf(gdiff) > GROOVE:
				continue
			var push := 0.45 * delta
			if absf(gdiff) < 0.001:
				a.groove += push
				b.groove -= push
			else:
				var s := signf(gdiff)
				a.groove += s * push
				b.groove -= s * push

	for snail in field:
		var support := 0.0
		for other in field:
			if other == snail or other.finished:
				continue
			if absf(other.distance - snail.distance) > ALONG:
				continue
			if absf(other.groove - snail.groove) > GROOVE:
				continue
			if other.height < snail.height - 0.02:
				support = maxf(support, other.height + 0.05)
		snail.height_vel -= 7.5 * delta
		snail.height += snail.height_vel * delta
		if snail.height <= support:
			snail.height = support
			if snail.height_vel < 0.0:
				snail.height_vel = 0.0
		snail.groove = clampf(snail.groove, 0.04, 0.96)
		snail.height = clampf(snail.height, 0.0, 0.28)


func _inside_blocker(snail: Snail, along: float, groove: float) -> Snail:
	var best: Snail = null
	var best_g := snail.groove
	for other in field:
		if other == snail or other.finished:
			continue
		if other.distance - snail.distance > along or snail.distance - other.distance > along * 0.7:
			continue
		if other.groove >= snail.groove - 0.02:
			continue
		if snail.groove - other.groove > groove + 0.08:
			continue
		if absf(other.height - snail.height) > 0.1:
			continue
		if other.groove < best_g:
			best_g = other.groove
			best = other
	return best


func _roll_card_chaos() -> void:
	var wing := Game.race_wing_index()
	card_condition = RaceChaos.roll_condition(wing)
	live_event = RaceChaos.LiveEvent.NONE
	event_t = 0.0
	event_dur = 0.0
	event_at = 0.0
	events_used.clear()
	events_left = RaceChaos.planned_event_count(card_condition, wing >= 0)
	next_event_frac = RaceChaos.first_event_frac()
	_event_struck = false
	get_tree().call_group("stadium", "apply_card_condition", card_condition)
	get_tree().call_group("stadium", "clear_live_event")
	Game.event_announce("%s. %s" % [
		RaceChaos.condition_name(card_condition),
		RaceChaos.condition_tell(card_condition),
	], 0)


func _tick_live_events(delta: float) -> void:
	if live_event != RaceChaos.LiveEvent.NONE:
		event_t += delta
		if not _event_struck:
			_strike_live_event()
			_event_struck = true
		if event_t >= event_dur:
			_clear_live_event(true)
		return
	if events_left <= 0:
		return
	var frac := _leader_frac()
	if frac < next_event_frac or frac >= RaceChaos.LAST_FRAC:
		return
	_begin_live_event()


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if NetPlay.is_client() or not racing:
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var picked := RaceChaos.LiveEvent.NONE
	if event.is_action_pressed("chaos_hawk"):
		picked = RaceChaos.LiveEvent.HAWK
	elif event.is_action_pressed("chaos_corn"):
		picked = RaceChaos.LiveEvent.CORN_RAIN
	elif event.is_action_pressed("chaos_oil"):
		picked = RaceChaos.LiveEvent.OIL_SLICK
	elif event.is_action_pressed("chaos_dog"):
		picked = RaceChaos.LiveEvent.LOOSE_DOG
	elif event.is_action_pressed("chaos_gun"):
		picked = RaceChaos.LiveEvent.FALSE_GUN
	elif event.is_action_pressed("chaos_crowd"):
		picked = RaceChaos.LiveEvent.CROWD_SQUEEZE
	if picked == RaceChaos.LiveEvent.NONE:
		return
	force_live_event(picked)
	get_viewport().set_input_as_handled()


func force_live_event(event: int) -> void:
	if event == RaceChaos.LiveEvent.NONE or not racing:
		return
	if NetPlay.is_client():
		return
	if live_event != RaceChaos.LiveEvent.NONE:
		_clear_live_event(false)
	_fire_live_event(event, false)


func _begin_live_event() -> void:
	var picked := RaceChaos.pick_live_event(card_condition, Game.race_wing_index(), events_used)
	if picked == RaceChaos.LiveEvent.NONE:
		events_left = 0
		return
	_fire_live_event(picked, true)


func _fire_live_event(picked: int, consume: bool) -> void:
	live_event = picked
	event_t = 0.0
	event_dur = RaceChaos.event_duration(live_event)
	event_at = _event_mark()
	_event_struck = false
	if consume:
		events_used.append(live_event)
		events_left = maxi(events_left - 1, 0)
		next_event_frac = RaceChaos.next_event_frac(_leader_frac())
	var victim := _strike_live_event()
	_event_struck = true
	var line := RaceChaos.event_callout(live_event)
	var shown := victim if not victim.is_empty() else line
	Game.event_announce(shown, live_event)
	get_tree().call_group("stadium", "show_live_event", live_event, event_at)
	NetPlay.send_race_event({
		"card_condition": card_condition,
		"event_id": live_event,
		"event_t": event_t,
		"event_dur": event_dur,
		"event_at": event_at,
		"callout": shown,
		"victim": victim,
		"ended": false,
	})


func _event_mark() -> float:
	var leader := get_leader()
	var lead_d := leader.distance if leader else track_length * 0.4
	if live_event == RaceChaos.LiveEvent.OIL_SLICK:
		return clampf(lead_d + 0.35, track_length * 0.12, track_length * 0.84)
	return clampf(lead_d + randf_range(-0.25, 0.55), track_length * 0.12, track_length * 0.84)


func _strike_live_event() -> String:
	var victim := ""
	match live_event:
		RaceChaos.LiveEvent.HAWK:
			var flop: Snail = null
			var flop_h := -1.0
			for snail in field:
				if snail.finished or not snail.racing:
					continue
				if snail.has_trait(ChickenStock.Trait.HAWK_BLIND):
					continue
				if snail.height > flop_h:
					flop_h = snail.height
					flop = snail
				snail.height = 0.0
				snail.height_vel = -5.6
				snail.squish = 0.38
				snail.groove = clampf(snail.groove + randf_range(-0.10, 0.22), 0.04, 0.96)
			if flop:
				victim = "%s belly-flops." % flop.display_name
		RaceChaos.LiveEvent.FALSE_GUN:
			for snail in field:
				if snail.finished or not snail.racing:
					continue
				if snail.archetype == Snail.Archetype.LATE:
					snail.begin_freeze(randf_range(0.7, 1.05))
				elif snail.archetype == Snail.Archetype.SPRINTER:
					snail.vel = maxf(snail.vel, snail.vel * 1.15 + 0.35)
		RaceChaos.LiveEvent.CORN_RAIN:
			var leader := get_leader()
			if leader and leader.racing and not leader.finished and not leader.has_trait(ChickenStock.Trait.IRON_CROP):
				leader.begin_freeze(randf_range(1.35, 2.15))
				victim = "%s stops for corn." % leader.display_name
			for snail in field:
				if snail.finished or not snail.racing:
					continue
				if snail.has_trait(ChickenStock.Trait.IRON_CROP):
					continue
				if snail == leader:
					continue
				var hungry := RaceChaos.wants_corn_freeze(int(snail.archetype), snail.hunger)
				if hungry or snail.has_trait(ChickenStock.Trait.CORN_FIEND):
					snail.begin_freeze(randf_range(1.15, 2.05))
		RaceChaos.LiveEvent.LOOSE_DOG:
			var punished: Snail = null
			for snail in field:
				if snail.finished or not snail.racing:
					continue
				if snail.has_trait(ChickenStock.Trait.HAWK_BLIND):
					continue
				if snail.groove < 0.32:
					if punished == null or snail.archetype == Snail.Archetype.STEADY:
						punished = snail
					snail.groove = clampf(snail.groove + randf_range(0.16, 0.34), 0.04, 0.96)
					snail.vel *= 0.62
					snail.squish = minf(snail.squish, 0.62)
			if punished:
				victim = "%s dumps the rail." % punished.display_name
		RaceChaos.LiveEvent.CROWD_SQUEEZE:
			var cluster := _biggest_cluster()
			if cluster.size() >= 3:
				for snail in cluster:
					if snail.has_trait(ChickenStock.Trait.CROWD_HOG):
						snail.squish = minf(snail.squish, 0.82)
						continue
					snail.squish = 0.52
					snail.vel *= 0.88
	return victim


func _apply_track_hazards(delta: float) -> void:
	for snail in field:
		if snail.finished or not snail.racing:
			continue
		var in_grease := card_condition == RaceChaos.Condition.GREASE_DRIP and RaceChaos.in_grease_zone(snail.distance, track_length)
		var in_oil := live_event == RaceChaos.LiveEvent.OIL_SLICK and RaceChaos.near_oil(snail.distance, event_at)
		if in_grease or in_oil:
			if snail.has_trait(ChickenStock.Trait.GREASE_LEGS):
				snail.zone_hit = true
			else:
				snail.groove = clampf(snail.groove + randf_range(-0.7, 1.05) * delta, 0.04, 0.96)
				if not snail.zone_hit:
					snail.zone_hit = true
					var wreck := in_oil and snail.archetype == Snail.Archetype.SPRINTER
					snail.groove = clampf(snail.groove + randf_range(0.10, 0.26 if wreck else 0.20), 0.04, 0.96)
					snail.vel *= 0.28 if wreck else 0.55
					snail.squish = 0.42 if wreck else minf(snail.squish, 0.7)
					snail.begin_freeze(randf_range(0.55, 0.9) if wreck else randf_range(0.28, 0.52))
					if wreck:
						Game.announce("%s wrecks on the oil." % snail.display_name, true)
		else:
			snail.zone_hit = false
		if card_condition == RaceChaos.Condition.KERNEL_SCATTER and snail.can_freeze() and not snail.has_trait(ChickenStock.Trait.IRON_CROP):
			var peck := RaceChaos.wants_kernel_peck(int(snail.archetype), snail.hunger, delta)
			if snail.has_trait(ChickenStock.Trait.CORN_FIEND):
				peck = peck or randf() < 0.55 * delta
			if peck:
				snail.begin_freeze(randf_range(0.55, 1.15))
		if card_condition == RaceChaos.Condition.STORM_COMING:
			snail.groove = clampf(snail.groove + sin(race_time * 6.4 + float(snail.snail_id) * 1.7) * 0.16 * delta, 0.04, 0.96)


func _stamp_chaos_tags() -> void:
	for snail in field:
		if snail.finished or snail.fried:
			snail.chaos_tag = ""
			continue
		var in_grease := card_condition == RaceChaos.Condition.GREASE_DRIP and RaceChaos.in_grease_zone(snail.distance, track_length)
		var in_oil := live_event == RaceChaos.LiveEvent.OIL_SLICK and RaceChaos.near_oil(snail.distance, event_at)
		if snail.freeze_left > 0.0 and (live_event == RaceChaos.LiveEvent.CORN_RAIN or card_condition == RaceChaos.Condition.KERNEL_SCATTER):
			snail.chaos_tag = "PECKING"
		elif in_grease or in_oil:
			snail.chaos_tag = "GREASED"
		elif live_event == RaceChaos.LiveEvent.HAWK or live_event == RaceChaos.LiveEvent.LOOSE_DOG or live_event == RaceChaos.LiveEvent.FALSE_GUN:
			snail.chaos_tag = "SPOOKED"
		elif card_condition == RaceChaos.Condition.DUST_BOWL and snail.groove > 0.58:
			snail.chaos_tag = "DUSTED"
		else:
			snail.chaos_tag = ""


func _clear_live_event(broadcast: bool) -> void:
	var had := live_event != RaceChaos.LiveEvent.NONE
	live_event = RaceChaos.LiveEvent.NONE
	event_t = 0.0
	event_dur = 0.0
	_event_struck = false
	get_tree().call_group("stadium", "clear_live_event")
	if broadcast and had:
		NetPlay.send_race_event({
			"card_condition": card_condition,
			"event_id": live_event,
			"event_t": 0.0,
			"event_dur": 0.0,
			"event_at": event_at,
			"ended": true,
		})


func _leader_frac() -> float:
	var leader := get_leader()
	if leader == null:
		return 0.0
	return clampf(leader.distance / maxf(track_length, 0.001), 0.0, 1.0)


func _path() -> Path3D:
	return get_tree().get_first_node_in_group("track_path") as Path3D


func _refresh_board() -> void:
	var board := get_tree().get_first_node_in_group("odds_board") as Label3D
	if board == null:
		return
	var race := Game.current_race()
	var lines := PackedStringArray([
		str(race.get("name", "TODAY'S CARD")).to_upper(),
		str(race.get("subtitle", "")),
		RaceChaos.condition_name(card_condition).to_upper(),
		"",
	])
	for snail in field:
		var mark := " *" if snail.owner_id == NetPlay.local_id() and not snail.chicken_id.begins_with("npc_") else ""
		lines.append("%s%s    %s    %s    %s" % [snail.display_name, mark, snail.grade_name(), snail.odds_text(), ChickenStock.trait_summary(snail)])
	board.text = "\n".join(lines)
	var sched := get_tree().get_first_node_in_group("schedule_board") as Label3D
	if sched:
		var jewels := PackedStringArray(["TRIPLE WING"])
		for i in ChickenStock.SCHEDULE.size():
			var row: Dictionary = ChickenStock.SCHEDULE[i]
			var mark := ">" if i == Game.meet_index else " "
			var wing := int(row.get("wing", -1))
			var extra := "  *" if wing >= 0 else ""
			jewels.append("%s %s%s" % [mark, row.get("name", ""), extra])
		sched.text = "\n".join(jewels)
