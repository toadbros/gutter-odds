class_name GutterLooks
extends RefCounted

const DIRT := Color("3a2a1c")
const RUST := Color("8a3e24")
const BRASS := Color("b08d57")
const TIN := Color("8a8e86")
const SLIME := Color("6b8f3a")
const WOOD := Color("5c3a24")
const DARK_WOOD := Color("2b1b12")
const CLOTH := Color("6b1d1d")
const SKIN := Color("d2a07a")
const NIGHT := Color("1a120e")


static func mat(color: Color, rough: float = 0.86, metallic: float = 0.0, emission: Color = Color(0, 0, 0, 0), energy: float = 1.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metallic
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	if emission.a > 0.0:
		m.emission_enabled = true
		m.emission = Color(emission.r, emission.g, emission.b)
		m.emission_energy_multiplier = energy
	return m


static func mesh(parent: Node3D, mesh_res: Mesh, material: Material, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO, scale := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh_res
	mi.material_override = material
	mi.position = pos
	mi.rotation = rot
	mi.scale = scale
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi


static func capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	return c


static func sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return s


static func cyl(r: float, h: float, rings: int = 8) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = rings
	return c


static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func build_person(model: Node3D, vest: Color) -> void:
	var tones: Array[Color] = [
		Color("e2b08a"), Color("c48a62"), Color("8d5a3a"), Color("5c3a28"), Color("d8a878"),
	]
	var hairs: Array[Color] = [
		Color("1a120e"), Color("3a2418"), Color("6a4a28"), Color("c4c0b4"), Color("2a1a12"),
	]
	var pick := int(absf(vest.r * 11.0 + vest.g * 7.0 + vest.b * 3.0) * 13.0) % tones.size()
	var skin := mat(tones[pick], 0.72)
	var hair := mat(hairs[pick], 0.9)
	var vest_m := mat(vest, 0.78)
	var pants := mat(vest.darkened(0.35), 0.88)
	var dark := mat(Color("1c1612"), 0.9)
	var eye_w := mat(Color("f0ead8"), 0.4)
	var eye_b := mat(Color("12100e"), 0.3)
	mesh(model, capsule(0.075, 0.78), pants, Vector3(-0.09, 0.4, 0.02))
	mesh(model, capsule(0.075, 0.78), pants, Vector3(0.09, 0.4, 0.02))
	mesh(model, box(Vector3(0.18, 0.08, 0.28)), dark, Vector3(-0.09, 0.06, 0.04))
	mesh(model, box(Vector3(0.18, 0.08, 0.28)), dark, Vector3(0.09, 0.06, 0.04))
	mesh(model, box(Vector3(0.38, 0.52, 0.24)), vest_m, Vector3(0, 1.02, 0.02))
	mesh(model, box(Vector3(0.4, 0.12, 0.26)), pants, Vector3(0, 0.76, 0.02))
	mesh(model, capsule(0.055, 0.58), vest_m, Vector3(-0.24, 0.98, 0.02), Vector3(0, 0, 0.18))
	mesh(model, capsule(0.055, 0.58), vest_m, Vector3(0.24, 0.98, 0.02), Vector3(0, 0, -0.18))
	mesh(model, sphere(0.07), skin, Vector3(-0.24, 0.7, 0.04))
	mesh(model, sphere(0.07), skin, Vector3(0.24, 0.7, 0.04))
	mesh(model, sphere(0.13), skin, Vector3(0, 1.42, 0.04))
	mesh(model, sphere(0.135), hair, Vector3(0, 1.48, 0.0), Vector3.ZERO, Vector3(1.05, 0.7, 1.05))
	mesh(model, sphere(0.028), eye_w, Vector3(-0.045, 1.43, 0.14))
	mesh(model, sphere(0.028), eye_w, Vector3(0.045, 1.43, 0.14))
	mesh(model, sphere(0.014), eye_b, Vector3(-0.045, 1.43, 0.16))
	mesh(model, sphere(0.014), eye_b, Vector3(0.045, 1.43, 0.16))
	mesh(model, box(Vector3(0.1, 0.03, 0.05)), dark, Vector3(0, 1.37, 0.15))
	mesh(model, cyl(0.15, 0.08, 10), dark, Vector3(0, 1.56, 0.0))
	mesh(model, cyl(0.16, 0.03, 10), dark, Vector3(0, 1.52, 0.02))


static func build_chicken(model: Node3D, plumage: Color, number: int, rooster: bool = false) -> void:
	# Built facing Godot forward (-Z): beak first, tail trailing.
	var feather := mat(plumage, 0.82)
	var dark := mat(plumage.darkened(0.35), 0.85)
	var comb_m := mat(Color("b42828"), 0.55)
	var beak_m := mat(Color("e8a028"), 0.45)
	var eye_b := mat(Color("12100e"), 0.3)
	var leg_m := mat(Color("d4a03a"), 0.7)
	var body_s := Vector3(1.22, 1.06, 1.48) if rooster else Vector3(1.15, 1.0, 1.4)
	mesh(model, sphere(0.12), feather, Vector3(0, 0.22, 0.02), Vector3.ZERO, body_s)
	mesh(model, sphere(0.08), feather, Vector3(0, 0.2, -0.1), Vector3.ZERO, Vector3(1.1, 1.05, 1.15))
	if number % 3 == 0:
		mesh(model, sphere(0.03), dark, Vector3(-0.07, 0.26, 0.04))
		mesh(model, sphere(0.025), dark, Vector3(0.08, 0.24, -0.02))
		mesh(model, sphere(0.02), dark, Vector3(0.02, 0.28, 0.1))
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.36 if rooster else 0.36, -0.14)
	model.add_child(head)
	mesh(head, sphere(0.055), feather, Vector3.ZERO)
	mesh(head, box(Vector3(0.03, 0.022, 0.08)), beak_m, Vector3(0, -0.01, -0.08))
	var comb_h := 0.1 if rooster else 0.07
	mesh(head, box(Vector3(0.018, comb_h, 0.04)), comb_m, Vector3(0, 0.07, 0.0))
	mesh(head, box(Vector3(0.016, 0.07 if rooster else 0.05, 0.03)), comb_m, Vector3(0, 0.055, -0.035))
	mesh(head, box(Vector3(0.016, 0.06 if rooster else 0.045, 0.03)), comb_m, Vector3(0, 0.05, 0.03))
	if rooster:
		mesh(head, box(Vector3(0.014, 0.08, 0.025)), comb_m, Vector3(0, 0.08, 0.05))
	mesh(head, sphere(0.018), comb_m, Vector3(0, -0.04, -0.03), Vector3.ZERO, Vector3(0.7, 1.6 if rooster else 1.3, 0.7))
	if rooster:
		mesh(head, sphere(0.016), comb_m, Vector3(0, -0.05, -0.018), Vector3.ZERO, Vector3(0.65, 1.5, 0.65))
	mesh(head, sphere(0.012), eye_b, Vector3(-0.04, 0.015, -0.035))
	mesh(head, sphere(0.012), eye_b, Vector3(0.04, 0.015, -0.035))
	var wings := Node3D.new()
	wings.name = "Wings"
	model.add_child(wings)
	var left := Node3D.new()
	left.position = Vector3(-0.12, 0.24, 0.0)
	wings.add_child(left)
	mesh(left, box(Vector3(0.04, 0.1, 0.2)), dark, Vector3(-0.02, 0.0, 0.02))
	var right := Node3D.new()
	right.position = Vector3(0.12, 0.24, 0.0)
	wings.add_child(right)
	mesh(right, box(Vector3(0.04, 0.1, 0.2)), dark, Vector3(0.02, 0.0, 0.02))
	var tail := Node3D.new()
	tail.name = "Tail"
	tail.position = Vector3(0, 0.28, 0.16)
	model.add_child(tail)
	mesh(tail, box(Vector3(0.04, 0.16, 0.05)), dark, Vector3(0, 0.06, 0.04), Vector3(0.7, 0, 0))
	mesh(tail, box(Vector3(0.035, 0.14, 0.04)), feather, Vector3(-0.04, 0.05, 0.03), Vector3(0.65, 0.3, 0))
	mesh(tail, box(Vector3(0.035, 0.14, 0.04)), feather, Vector3(0.04, 0.05, 0.03), Vector3(0.65, -0.3, 0))
	if rooster:
		mesh(tail, box(Vector3(0.03, 0.22, 0.04)), dark, Vector3(0.0, 0.12, 0.08), Vector3(0.95, 0, 0))
		mesh(tail, box(Vector3(0.028, 0.2, 0.035)), feather, Vector3(-0.05, 0.1, 0.07), Vector3(0.9, 0.25, 0))
		mesh(tail, box(Vector3(0.028, 0.2, 0.035)), feather, Vector3(0.05, 0.1, 0.07), Vector3(0.9, -0.25, 0))
	var legs := Node3D.new()
	legs.name = "Legs"
	model.add_child(legs)
	for side in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.05, 0.12, 0.01)
		legs.add_child(leg)
		mesh(leg, cyl(0.012, 0.14, 5), leg_m, Vector3(0, -0.02, 0))
		mesh(leg, box(Vector3(0.07, 0.016, 0.08)), leg_m, Vector3(0, -0.09, -0.02))
	var tag := Label3D.new()
	tag.text = str(number)
	tag.font_size = 28
	tag.pixel_size = 0.0035
	tag.position = Vector3(0.0, 0.4, 0.02)
	tag.modulate = Color("f0e6d0")
	tag.outline_modulate = Color("1a120e")
	tag.outline_size = 5
	model.add_child(tag)


static func build_fried_chicken(model: Node3D) -> void:
	build_chicken(model, Color("c47828"), 0)
	mesh(model, cyl(0.16, 0.04, 10), mat(Color("8a5a28"), 0.7), Vector3(0, 0.02, 0))
	mesh(model, box(Vector3(0.18, 0.03, 0.22)), mat(Color("e8c03a"), 0.55), Vector3(0.12, 0.08, 0.02))


static func oval_point(t: float, rx: float, rz: float, y: float = 0.22) -> Vector3:
	var a := t * TAU
	return Vector3(cos(a) * rx, y, sin(a) * rz)


static func make_oval_curve(rx: float, rz: float, y: float, segments: int = 64) -> Curve3D:
	var curve := Curve3D.new()
	curve.bake_interval = 0.12
	for i in segments:
		var t := float(i) / float(segments)
		curve.add_point(oval_point(t, rx, rz, y))
	curve.add_point(oval_point(0.0, rx, rz, y))
	return curve
