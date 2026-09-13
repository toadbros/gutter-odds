extends Node3D
class_name IdleBob

var _origin_y: float = 0.0
var _t: float = 0.0
var _speed: float = 1.6
var _amp: float = 0.035


func _ready() -> void:
	_origin_y = position.y
	_t = randf() * TAU
	_speed = randf_range(1.1, 2.3)
	_amp = randf_range(0.02, 0.05)


func _process(delta: float) -> void:
	_t += delta * _speed
	position.y = _origin_y + sin(_t) * _amp
