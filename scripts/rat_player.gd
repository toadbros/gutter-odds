extends CharacterBody3D
class_name RatPlayer

const WALK_SPEED := 4.6
const SPRINT_SPEED := 7.2
const MOUSE := 0.0022
const GRAVITY := 24.0
const EYE_HEIGHT := 1.56

@onready var _pivot: Node3D = $CameraPivot
@onready var _camera: Camera3D = $CameraPivot/Camera3D
@onready var _model: Node3D = $Model

var _bob: float = 0.0
var _target: Interactable
var binoculars: bool = false
var local_controlled: bool = true
var _pose_t: float = 0.0
var _peer_id: int = 1


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	GutterLooks.build_person(_model, Color("3a6a9a"))
	# Mesh is built facing +Z; Godot walk-forward is -Z. Race cameras still need this.
	_model.rotation.y = PI
	Game.vip_enter_requested.connect(_warp_to_vip)
	NetPlay.peers_changed.connect(_retag)
	_retag()
	call_deferred("_snap_to_spawn")


func setup_remote(peer_id: int, player_name: String = "") -> void:
	local_controlled = false
	_peer_id = peer_id
	add_to_group("net_puppet")
	add_to_group("player_%d" % peer_id)
	remove_from_group("player")
	_camera.current = false
	set_process_unhandled_input(false)
	if Game.vip_enter_requested.is_connected(_warp_to_vip):
		Game.vip_enter_requested.disconnect(_warp_to_vip)
	for child in _model.get_children():
		child.queue_free()
	var colors: Array[Color] = [
		Color("c45a5a"), Color("3d8a48"), Color("d4a03a"), Color("7a4aaa"), Color("2e7a3a"),
	]
	GutterLooks.build_person(_model, colors[peer_id % colors.size()])
	_model.rotation.y = PI
	_model.visible = true
	var tag := Label3D.new()
	if player_name.is_empty():
		player_name = NetPlay.trainer_name(peer_id)
	tag.text = player_name.to_upper()
	tag.position = Vector3(0, 2.05, 0)
	tag.font_size = 22
	tag.pixel_size = 0.004
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = Color("f0e6d0")
	tag.outline_size = 6
	tag.outline_modulate = Color("1a120e")
	add_child(tag)


func apply_remote_pose(pos: Vector3, yaw: float, pitch: float) -> void:
	if local_controlled:
		return
	global_position = global_position.lerp(pos, 0.45)
	rotation.y = yaw
	_pivot.rotation.x = pitch
	_model.visible = true


func _retag() -> void:
	if not local_controlled:
		return
	_peer_id = NetPlay.local_id()
	add_to_group("player_%d" % _peer_id)


func _snap_to_spawn() -> void:
	var spawn := get_tree().get_first_node_in_group("player_spawn") as Node3D
	if spawn:
		global_position = spawn.global_position
		rotation.y = spawn.rotation.y


func _warp_to_vip() -> void:
	var spawn := get_tree().get_first_node_in_group("vip_spawn") as Node3D
	if spawn:
		global_position = spawn.global_position
		look_at(Vector3(0, global_position.y, 0), Vector3.UP)
		Game.toast.emit("Best seats in the house.")


func _unhandled_input(event: InputEvent) -> void:
	if not local_controlled:
		return
	if Game.is_sitting() or Game.ui_open:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE)
		_pivot.rotate_x(-event.relative.y * MOUSE)
		_pivot.rotation.x = clampf(_pivot.rotation.x, -1.2, 0.85)
	if event.is_action_pressed("toggle_camera") and Game.phase == Game.Phase.RACE:
		get_tree().call_group("race_director", "toggle_cinematic")
	if event.is_action_pressed("interact"):
		_try_interact()
	if event.is_action_pressed("ready_up") and Game.phase == Game.Phase.OPEN:
		Game.ring_the_bell()
	if event.is_action_pressed("open_bookie") and Game.phase == Game.Phase.OPEN:
		Game.bookie_requested.emit()
	if event.is_action_pressed("open_coop") and not Game.is_sitting():
		Game.coop_requested.emit()
	if event.is_action_pressed("open_market") and not Game.is_sitting():
		Game.market_requested.emit()


func _physics_process(delta: float) -> void:
	if not local_controlled:
		return
	if Game.is_sitting():
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	var moving := Vector3.ZERO
	if not Game.ui_open:
		var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var yaw := Basis(Vector3.UP, rotation.y)
		moving = yaw * Vector3(input.x, 0.0, input.y)
	var speed := SPRINT_SPEED if Input.is_action_pressed("sprint") and not binoculars else WALK_SPEED
	if moving.length() > 0.1:
		velocity.x = moving.x * speed
		velocity.z = moving.z * speed
		_bob += delta * speed * 1.8
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * 4.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, speed * 4.0 * delta)
		_bob = move_toward(_bob, 0.0, delta * 6.0)
	move_and_slide()
	_update_view(delta)
	_update_interactable()
	_update_binoculars(delta)
	if global_position.y < -6.0:
		_snap_to_spawn()
	_pose_t += delta
	if _pose_t >= 0.05:
		_pose_t = 0.0
		NetPlay.send_pose(global_position, rotation.y, _pivot.rotation.x)


func wants_player_camera() -> bool:
	var director := get_tree().get_first_node_in_group("race_director")
	if director and director.has_method("is_cinematic") and director.is_cinematic():
		return false
	return true


func apply_camera_current() -> void:
	if not local_controlled:
		_camera.current = false
		return
	_camera.current = wants_player_camera() or Game.phase != Game.Phase.RACE


func _update_view(delta: float) -> void:
	if not local_controlled:
		_model.visible = true
		return
	# Hide the body in first person so we aren't staring into our own skull.
	# Race cameras should still see a person in the stands.
	_model.visible = not _camera.current
	var bob := sin(_bob) * (0.045 if binoculars else 0.055)
	var target_y := EYE_HEIGHT + (bob if velocity.length() > 0.4 else 0.0)
	_pivot.position.y = lerpf(_pivot.position.y, target_y, 1.0 - exp(-delta * 12.0))
	_model.position.y = sin(_bob) * 0.03
	_model.rotation.z = sin(_bob) * 0.04


func _update_binoculars(delta: float) -> void:
	var want := (
		Input.is_action_pressed("binoculars")
		and Game.vip_owned
		and _in_vip()
		and not Game.ui_open
		and _camera.current
	)
	binoculars = want
	var target_fov := 24.0 if binoculars else 72.0
	_camera.fov = lerpf(_camera.fov, target_fov, 1.0 - exp(-delta * 10.0))
	get_tree().call_group("hud", "set_binoculars", binoculars)


func _in_vip() -> bool:
	for node in get_tree().get_nodes_in_group("vip_zone"):
		if node is Area3D and (node as Area3D).overlaps_body(self):
			return true
	return false


func _update_interactable() -> void:
	_target = null
	if Game.ui_open or Game.is_sitting():
		get_tree().call_group("hud", "set_prompt", "")
		return
	var forward := -_camera.global_transform.basis.z
	var best_score := 0.35
	for node in get_tree().get_nodes_in_group("interactable"):
		if node is Interactable:
			var to: Vector3 = (node as Node3D).global_position + Vector3.UP * 0.4 - _camera.global_position
			var dist := to.length()
			if dist > 3.4 or dist < 0.05:
				continue
			var facing := forward.dot(to.normalized())
			if facing < 0.42:
				continue
			var score := facing * (1.6 / dist)
			if score > best_score:
				best_score = score
				_target = node
	if _target:
		get_tree().call_group("hud", "set_prompt", "E  " + _target.get_prompt())
	else:
		get_tree().call_group("hud", "set_prompt", "")


func _try_interact() -> void:
	if _target == null:
		return
	_target.interact(self)
