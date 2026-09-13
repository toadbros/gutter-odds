extends Node3D
class_name RaceDirector

enum Shot { PACK, MINE }

var _chase: Camera3D
var _enabled: bool = false
var _cinematic: bool = true
var _shot: Shot = Shot.PACK
var _snap: bool = true
var _focus: Vector3 = Vector3.ZERO
var _look: Vector3 = Vector3.ZERO
var _behind: Vector3 = Vector3(0, 0, 1)
var _right: Vector3 = Vector3(1, 0, 0)
var _look_hold: float = 0.0
var _finish_hold: float = 0.0
var _look_snail: Snail = null
var _look_pos: Vector3 = Vector3.ZERO
var _fov_want: float = 62.0


func _ready() -> void:
	add_to_group("race_director")
	_chase = _make_cam("ChaseCam")
	_chase.fov = 62.0


func activate() -> void:
	if _enabled:
		if _cinematic and _chase:
			_chase.current = true
		_notify_hud()
		return
	_enabled = true
	_cinematic = true
	_shot = Shot.PACK
	_snap = true
	_look_hold = 0.0
	_finish_hold = 0.0
	_look_snail = null
	_fov_want = 62.0
	_chase.fov = 62.0
	_chase.current = true
	_update_chase(0.016)
	_notify_hud()


func deactivate() -> void:
	_enabled = false
	_cinematic = false
	_shot = Shot.PACK
	_look_hold = 0.0
	_finish_hold = 0.0
	_look_snail = null
	_fov_want = 62.0
	if _chase:
		_chase.current = false
		_chase.fov = 62.0
	_restore_player_cam()
	_notify_hud()


func toggle_cinematic() -> void:
	if not _enabled:
		return
	if _cinematic and _shot == Shot.PACK and _local_entry() != null:
		_shot = Shot.MINE
		_snap = true
		_chase.current = true
		Game.toast.emit("Your bird")
		_notify_hud()
		return
	if _cinematic:
		_cinematic = false
		_shot = Shot.PACK
		_chase.current = false
		_restore_player_cam()
		Game.toast.emit("Back on the rail")
	else:
		_cinematic = true
		_shot = Shot.PACK
		_snap = true
		_chase.current = true
		Game.toast.emit("Race cameras")
	_notify_hud()


func is_cinematic() -> bool:
	return _enabled and _cinematic


func is_tracking_mine() -> bool:
	return is_cinematic() and _shot == Shot.MINE and _local_entry() != null


func camera_shot_name() -> String:
	if not _enabled:
		return "OFF"
	if not _cinematic:
		return "ON THE RAIL"
	if _shot == Shot.MINE and _local_entry() != null:
		return "YOUR BIRD"
	if _finish_hold > 0.0:
		return "PHOTO FINISH"
	return "PACK CAM"


func reassert_camera() -> void:
	if _enabled and _cinematic and _chase:
		_chase.current = true
	else:
		_restore_player_cam()
	_notify_hud()


func punch_look(pos: Vector3, secs: float = 1.28) -> void:
	if not _enabled:
		return
	_look_pos = pos
	_look_snail = null
	_look_hold = secs
	_fov_want = 50.0
	if _shot == Shot.MINE:
		# Stay locked on the entered bird; still tighten the lens so the wreck reads.
		_look_hold = 0.0
		_snap = false
		return
	if _cinematic:
		_snap = true
		_chase.current = true


func punch_snail(snail: Snail, secs: float = 1.28) -> void:
	if snail == null or not is_instance_valid(snail):
		return
	punch_look(snail.global_position, secs)
	if _shot != Shot.MINE:
		_look_snail = snail


func punch_finish(snail: Snail) -> void:
	if snail == null or not is_instance_valid(snail):
		return
	_enabled = true
	_cinematic = true
	_shot = Shot.PACK
	_look_snail = snail
	_look_pos = snail.global_position
	_look_hold = 1.75
	_finish_hold = 2.15
	_snap = true
	_fov_want = 46.0
	_chase.current = true
	_notify_hud()


func hold_results(snail: Snail) -> void:
	if snail == null or not is_instance_valid(snail):
		return
	punch_finish(snail)
	_look_hold = 2.35
	_finish_hold = 2.35
	_notify_hud()


func _process(delta: float) -> void:
	_look_hold = maxf(_look_hold - delta, 0.0)
	_finish_hold = maxf(_finish_hold - delta, 0.0)
	if _look_hold <= 0.0 and _finish_hold <= 0.0:
		_look_snail = null
		_fov_want = 62.0
	if _chase:
		var fov_follow := 1.0 - exp(-delta * 6.0)
		_chase.fov = lerpf(_chase.fov, _fov_want, fov_follow)
	if not _enabled or not _cinematic:
		return
	_update_chase(delta)


func _update_chase(delta: float) -> void:
	var manager := get_tree().get_first_node_in_group("race_manager") as RaceManager
	if manager == null:
		return
	var focus_snail := _chase_snail(manager)
	var raw_focus: Vector3
	var raw_behind: Vector3
	var raw_right: Vector3
	var spread := 0.0
	var dist := 0.0
	var tight := focus_snail != null
	if focus_snail:
		raw_focus = focus_snail.global_position
		raw_behind = focus_snail.global_transform.basis.z
		raw_right = focus_snail.global_transform.basis.x
		dist = focus_snail.distance
		spread = 0.35
	else:
		var state: Dictionary = manager.get_broadcast_state()
		if state.is_empty():
			return
		raw_focus = state["position"]
		raw_behind = state["behind"]
		raw_right = state["right"]
		spread = float(state.get("spread", 0.0))
		dist = float(state.get("distance", 0.0))
		if _look_hold > 0.0:
			raw_focus = raw_focus.lerp(_look_pos, 0.72)
			tight = true
	if raw_behind.length_squared() < 0.0001:
		raw_behind = Vector3(0, 0, 1)
	else:
		raw_behind = raw_behind.normalized()
	if raw_right.length_squared() < 0.0001:
		raw_right = Vector3(1, 0, 0)
	else:
		raw_right = raw_right.normalized()
	var length := maxf(manager.track_length, 0.001)
	var frac := clampf(dist / length, 0.0, 1.0)
	var back_len := lerpf(5.4, 7.4, clampf(spread / 5.0, 0.0, 1.0))
	var up_len := lerpf(2.15, 2.8, clampf(spread / 5.0, 0.0, 1.0))
	if tight:
		back_len = lerpf(back_len, 4.15, 0.72)
		up_len = lerpf(up_len, 1.7, 0.72)
	if frac > 0.84 or _finish_hold > 0.0:
		var close := 1.0 if _finish_hold > 0.0 else (frac - 0.84) / 0.16
		back_len = lerpf(back_len, 4.2, close)
		up_len = lerpf(up_len, 1.7, close)
	var follow := 1.0 if _snap else (1.0 - exp(-delta * 1.55))
	var turn := 1.0 if _snap else (1.0 - exp(-delta * 1.25))
	_snap = false
	_focus = _focus.lerp(raw_focus, follow)
	_behind = (_behind.lerp(raw_behind, turn)).normalized()
	_right = (_right.lerp(raw_right, turn)).normalized()
	var side := 0.85 if tight else 1.45
	var target := _focus + _behind * back_len + Vector3.UP * up_len + _right * side
	_chase.global_position = _chase.global_position.lerp(target, follow)
	var raw_look := _focus + Vector3.UP * (0.38 if tight else 0.32) - _behind * 0.55
	_look = _look.lerp(raw_look, follow)
	if _chase.global_position.distance_to(_look) > 0.35:
		_chase.look_at(_look)


func _chase_snail(manager: RaceManager) -> Snail:
	if _look_snail and is_instance_valid(_look_snail) and (_look_hold > 0.0 or _finish_hold > 0.0):
		return _look_snail
	if _shot == Shot.MINE:
		return _local_entry()
	return null


func _local_entry() -> Snail:
	var manager := get_tree().get_first_node_in_group("race_manager") as RaceManager
	if manager and manager.has_method("local_entry"):
		return manager.local_entry()
	return null


func _notify_hud() -> void:
	get_tree().call_group("hud", "set_camera_mode", _cinematic, camera_shot_name())


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
