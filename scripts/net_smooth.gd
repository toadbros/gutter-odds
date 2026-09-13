class_name NetSmooth
extends RefCounted

## Client render delay. Existing pose/snapshot send is 20 Hz (50 ms).
## Holding ~2 packets gives a pair to lerp instead of chasing the latest unreliable hit.
const HOLD := 0.10
const EXTRAP := 0.08
const MAX_SAMPLES := 16

var _buf: Array[Dictionary] = []


func clear() -> void:
	_buf.clear()


func size() -> int:
	return _buf.size()


func is_empty() -> bool:
	return _buf.is_empty()


func latest() -> Dictionary:
	if _buf.is_empty():
		return {}
	return _buf[_buf.size() - 1]


func push(sample: Dictionary) -> void:
	push_at(Time.get_ticks_usec() * 0.000001, sample)


func push_at(t: float, sample: Dictionary) -> void:
	if not _buf.is_empty() and t + 0.0001 < float(_buf[_buf.size() - 1].get("t", 0.0)):
		return
	var row := sample.duplicate()
	row["t"] = t
	_buf.append(row)
	while _buf.size() > MAX_SAMPLES:
		_buf.pop_front()


func sample(render_at: float = -1.0) -> Dictionary:
	if _buf.is_empty():
		return {}
	if _buf.size() == 1:
		return _buf[0].duplicate()
	if render_at < 0.0:
		render_at = Time.get_ticks_usec() * 0.000001
	var at := render_at - HOLD
	var first: Dictionary = _buf[0]
	var last: Dictionary = _buf[_buf.size() - 1]
	if at <= float(first["t"]):
		return first.duplicate()
	if at >= float(last["t"]):
		var held := last.duplicate()
		var extra := minf(at - float(last["t"]), EXTRAP)
		if extra > 0.0 and held.has("along"):
			held["distance"] = float(held.get("distance", 0.0)) + float(held.get("along", 0.0)) * extra
		if extra > 0.0 and held.has("pos") and held.has("vel3"):
			held["pos"] = (held["pos"] as Vector3) + (held["vel3"] as Vector3) * extra
		return held
	for i in range(_buf.size() - 1):
		var a: Dictionary = _buf[i]
		var b: Dictionary = _buf[i + 1]
		if at > float(b["t"]):
			continue
		var span := maxf(float(b["t"]) - float(a["t"]), 0.0001)
		var u := clampf((at - float(a["t"])) / span, 0.0, 1.0)
		return blend(a, b, u)
	return last.duplicate()


static func blend(a: Dictionary, b: Dictionary, u: float) -> Dictionary:
	var out := a.duplicate()
	if a.has("distance"):
		out["distance"] = lerpf(float(a.get("distance", 0.0)), float(b.get("distance", 0.0)), u)
		out["groove"] = lerpf(float(a.get("groove", 0.0)), float(b.get("groove", 0.0)), u)
		out["height"] = lerpf(float(a.get("height", 0.0)), float(b.get("height", 0.0)), u)
		out["vel"] = lerpf(float(a.get("vel", 0.0)), float(b.get("vel", 0.0)), u)
		out["along"] = lerpf(float(a.get("along", 0.0)), float(b.get("along", 0.0)), u)
	if a.has("pos"):
		out["pos"] = (a["pos"] as Vector3).lerp(b["pos"] as Vector3, u)
		out["yaw"] = lerp_angle(float(a.get("yaw", 0.0)), float(b.get("yaw", 0.0)), u)
		out["pitch"] = lerpf(float(a.get("pitch", 0.0)), float(b.get("pitch", 0.0)), u)
	return out


static func smoke_check() -> bool:
	var mid := blend(
		{"distance": 0.0, "groove": 0.2, "height": 0.0, "vel": 1.0, "along": 1.0},
		{"distance": 2.0, "groove": 0.4, "height": 0.2, "vel": 3.0, "along": 3.0},
		0.5
	)
	if absf(float(mid["distance"]) - 1.0) > 0.001:
		return false
	if absf(float(mid["groove"]) - 0.3) > 0.001:
		return false
	var pose := blend(
		{"pos": Vector3.ZERO, "yaw": 0.0, "pitch": 0.0},
		{"pos": Vector3(4, 0, 0), "yaw": 0.4, "pitch": -0.2},
		0.25
	)
	var p: Vector3 = pose["pos"]
	if absf(p.x - 1.0) > 0.001 or absf(float(pose["yaw"]) - 0.1) > 0.001:
		return false
	# Two 50 ms packets, render 100 ms behind: halfway between them.
	var buf := NetSmooth.new()
	buf.push_at(1.00, {"distance": 0.0, "groove": 0.2, "height": 0.0, "vel": 2.0, "along": 2.0})
	buf.push_at(1.05, {"distance": 1.0, "groove": 0.2, "height": 0.0, "vel": 2.0, "along": 2.0})
	var held := buf.sample(1.125)
	if absf(float(held.get("distance", -1.0)) - 0.5) > 0.001:
		return false
	var coast := buf.sample(1.20)
	return absf(float(coast.get("distance", -1.0)) - 1.1) < 0.001
