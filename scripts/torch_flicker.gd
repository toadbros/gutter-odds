extends OmniLight3D

var _base: float = 1.0
var _t: float = 0.0
var _rate: float = 8.0


func _ready() -> void:
	_base = light_energy
	_t = randf() * 20.0
	_rate = randf_range(6.5, 10.5)


func _process(delta: float) -> void:
	_t += delta * _rate
	var flicker := 0.78 + 0.14 * sin(_t) + 0.08 * sin(_t * 2.37 + 1.1)
	if randf() < 0.015:
		flicker *= 0.55
	light_energy = _base * clampf(flicker, 0.45, 1.15)
