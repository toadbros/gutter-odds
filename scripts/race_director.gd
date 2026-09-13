extends Node3D
class_name RaceDirector

var _chase: Camera3D
var _enabled: bool = false
var _cinematic: bool = true
var _snap: bool = true
var _focus: Vector3 = Vector3.ZERO
var _look: Vector3 = Vector3.ZERO
var _behind: Vector3 = Vector3(0, 0, 1)
var _right: Vector3 = Vector3(1, 0, 0)


func _ready() -> void:
	add_to_group("race_director")
	_chase = _make_cam("ChaseCam")
	_chase.fov = 62.0


func activate() -> void:
	if _enabled:
		if _cinematic and _chase:
			_chase.current = true
		return
	_enabled = true
	_cinematic = true
	_snap = true
	_chase.current = true
	_update_chase(0.016)


func deactivate() -> void:
	_enabled = false
	_cinematic = false
	_chase.current = false
	_restore_player_cam()


func toggle_cinematic() -> void:
	if not _enabled:
		return
	_cinematic = not _cinematic
	if _cinematic:
		_snap = true
		_chase.current = true
		Game.toast.emit("Race cameras")
	else:
		_chase.current = false
		_restore_player_cam()
		Game.toast.emit("Back on the rail")
	get_tree().call_group("hud", "set_camera_mode", _cinematic)


func is_cinematic() -> bool:
	return _enabled and _cinematic


func reassert_camera() -> void:
	if _enabled and _cinematic and _chase:
		_chase.current = true
	else:
		_restore_player_cam()


func _process(delta: float) -> void:
	if not _enabled or not _cinematic:
		return
	_update_chase(delta)


func _update_chase(delta: float) -> void:
	var manager := get_tree().get_first_node_in_group("race_manager") as RaceManager
	if manager == null:
		return
	var state: Dictionary = manager.get_broadcast_state()
	if state.is_empty():
		return
	var raw_focus: Vector3 = state["position"]
	var raw_behind: Vector3 = state["behind"]
	var raw_right: Vector3 = state["right"]
	if raw_behind.length_squared() < 0.0001:
		raw_behind = Vector3(0, 0, 1)
	else:
		raw_behind = raw_behind.normalized()
	if raw_right.length_squared() < 0.0001:
		raw_right = Vector3(1, 0, 0)
	else:
		raw_right = raw_right.normalized()
	var spread: float = float(state.get("spread", 0.0))
	var dist: float = float(state.get("distance", 0.0))
	var length := maxf(manager.track_length, 0.001)
	var frac := clampf(dist / length, 0.0, 1.0)
	var back_len := lerpf(5.4, 7.4, clampf(spread / 5.0, 0.0, 1.0))
	var up_len := lerpf(2.15, 2.8, clampf(spread / 5.0, 0.0, 1.0))
	if frac > 0.84:
		back_len = lerpf(back_len, 4.6, (frac - 0.84) / 0.16)
		up_len = lerpf(up_len, 1.9, (frac - 0.84) / 0.16)
	var follow := 1.0 if _snap else (1.0 - exp(-delta * 1.55))
	var turn := 1.0 if _snap else (1.0 - exp(-delta * 1.25))
	_snap = false
	_focus = _focus.lerp(raw_focus, follow)
	_behind = (_behind.lerp(raw_behind, turn)).normalized()
	_right = (_right.lerp(raw_right, turn)).normalized()
	var target := _focus + _behind * back_len + Vector3.UP * up_len + _right * 1.45
	_chase.global_position = _chase.global_position.lerp(target, follow)
	var raw_look := _focus + Vector3.UP * 0.32 - _behind * 0.55
	_look = _look.lerp(raw_look, follow)
	if _chase.global_position.distance_to(_look) > 0.35:
		_chase.look_at(_look)


func _restore_player_cam() -> void:
	var player := get_tree().get_first_node_in_group("player") as RatPlayer
	if player:
		player.apply_camera_current()


func _make_cam(cam_name: String) -> Camera3D:
	var cam := Camera3D.new()
	cam.name = cam_name
	cam.fov = 62.0
	cam.near = 0.12
	cam.far = 180.0
	cam.current = false
	add_child(cam)
	return cam
