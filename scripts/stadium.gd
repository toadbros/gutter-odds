extends Node3D
class_name Stadium

var _vip_gate: CSGBox3D
var _coop_birds: Array[Snail] = []
var _fry_plate: Node3D
var _track_body: MeshInstance3D
var _track_dirt: MeshInstance3D
var _world_env: WorldEnvironment
var _sun: DirectionalLight3D
var _card_fx: Node3D
var _live_fx: Node3D
var _painted_condition: int = -1
var _live_event: int = RaceChaos.LiveEvent.NONE
var _live_at: Vector3 = Vector3.ZERO
var _live_t: float = 0.0
var _condition_sign: Label3D
var _hawk: Node3D
var _dog: Node3D
var _hawk_shadow: Node3D
var _corn_mesh: BoxMesh
var _corn_mat: StandardMaterial3D

func _ready() -> void:
	add_to_group("stadium")
	_environment()
	_ground()
	_track()
	_infield()
	_paddock()
	_bookie()
	_stands()
	_vip()
	_coop()
	_market()
	_fryer()
	_flags()
	_props()
	_markers()
	_card_fx = Node3D.new()
	_card_fx.name = "CardFx"
	add_child(_card_fx)
	_live_fx = Node3D.new()
	_live_fx.name = "LiveFx"
	add_child(_live_fx)
	Game.vip_changed.connect(_on_vip_changed)
	Game.coop_changed.connect(_refresh_coop)
	Game.meet_changed.connect(_refresh_schedule)
	Game.results_ready.connect(_on_results)


func _environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("4a9ee8")
	sky_mat.sky_horizon_color = Color("d6eef8")
	sky_mat.ground_bottom_color = Color("3d6a28")
	sky_mat.ground_horizon_color = Color("8aab58")
	sky_mat.sun_angle_max = 30.0
	sky_mat.sky_energy_multiplier = 1.2
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.58
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = false
	env.fog_enabled = true
	env.fog_light_color = Color("d8eaf4")
	env.fog_density = 0.0012
	env.fog_aerial_perspective = 0.15
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	_world_env = world
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("fff1d2")
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-55, 40, 0)
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)
	_sun = sun


func _ground() -> void:
	_box(Vector3(120, 0.25, 90), GutterLooks.mat(Color("4f8a38"), 0.95), Vector3(0, -0.12, 0))
	# Thin disc, not CSG. Godot 4.7 Manifold CSG explodes r=22 / h=0.08 into a default 2m can.
	var packed := _cyl(Vector3(0, 0.04, 0), 22.0, 0.08, GutterLooks.mat(Color("6b9a42"), 0.92), 32, false)
	packed.name = "PackedDirt"


func _track() -> void:
	var surface := Game.TRACK_SURFACE_Y
	var path := Path3D.new()
	path.name = "TrackPath"
	path.curve = GutterLooks.make_oval_curve(Game.TRACK_RX, Game.TRACK_RZ, surface)
	path.add_to_group("track_path")
	add_child(path)
	var mesh_i := MeshInstance3D.new()
	mesh_i.mesh = _track_mesh(Game.TRACK_RX, Game.TRACK_RZ, Game.TRACK_WIDTH, surface - 0.05, 0.22)
	mesh_i.material_override = GutterLooks.mat(Color("c4a060"), 0.88, 0.05)
	add_child(mesh_i)
	_track_body = mesh_i
	var dirt := MeshInstance3D.new()
	dirt.mesh = _track_mesh(Game.TRACK_RX, Game.TRACK_RZ, Game.TRACK_WIDTH * 0.72, surface, 0.05)
	dirt.material_override = GutterLooks.mat(Color("d2b07a"), 0.92, 0.0)
	add_child(dirt)
	_track_dirt = dirt
	# Inner / outer rails.
	_white_fence(Game.TRACK_RX - Game.TRACK_WIDTH * 0.5, Game.TRACK_RZ - Game.TRACK_WIDTH * 0.5)
	_white_fence(Game.TRACK_RX + Game.TRACK_WIDTH * 0.5, Game.TRACK_RZ + Game.TRACK_WIDTH * 0.5)
	# Finish posts on the +X side.
	_box(Vector3(0.16, 1.8, 0.16), GutterLooks.mat(Color("f4f0e6"), 0.55), Vector3(Game.TRACK_RX + 1.5, 1.0, 1.4))
	_box(Vector3(0.16, 1.8, 0.16), GutterLooks.mat(Color("f4f0e6"), 0.55), Vector3(Game.TRACK_RX + 1.5, 1.0, -1.4))
	_box(Vector3(0.08, 0.7, 2.9), GutterLooks.mat(Color("c42828"), 0.7), Vector3(Game.TRACK_RX + 1.5, 1.7, 0))
	_label("FINISH", Vector3(Game.TRACK_RX + 1.7, 2.15, 0), 48, Color("1a120e"))


func _infield() -> void:
	# Circle must sit inside the inner rail (rz - half width = 7.9). Old r=8.6 spilled onto the dirt.
	var cap_r := Game.TRACK_RZ - Game.TRACK_WIDTH * 0.5 - 0.55
	var surface := Game.TRACK_SURFACE_Y
	var cap := _cyl(Vector3(0, surface - 0.05, 0), cap_r, 0.12, GutterLooks.mat(Color("5a9a3e"), 0.9), 28, true)
	cap.name = "InfieldCap"
	var grass := _cyl(Vector3(0, surface + 0.01, 0), maxf(cap_r - 1.0, 1.0), 0.05, GutterLooks.mat(Color("6b9a42"), 0.88), 28, false)
	grass.name = "InfieldGrass"
	_label("THE OVAL", Vector3(0, surface + 0.16, 0), 64, Color("1a3a18"))
	_condition_sign = _label("FAIR DIRT", Vector3(0, 2.72, 0), 56, Color("f0e6d0"))
	_condition_sign.name = "ConditionSign"
	var board := Label3D.new()
	board.name = "ScheduleBoard"
	board.add_to_group("schedule_board")
	board.text = "TRIPLE WING"
	board.font_size = 22
	board.pixel_size = 0.004
	board.position = Vector3(0, 1.35, 0)
	board.modulate = Color("1a120e")
	board.outline_size = 6
	board.outline_modulate = Color("f4f0e6")
	board.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(board)


func _paddock() -> void:
	_box(Vector3(12, 0.12, 18), GutterLooks.mat(Color("c4a070"), 0.9), Vector3(-26.5, 0.06, 0.5))
	_box(Vector3(0.12, 1.15, 18), GutterLooks.mat(Color("f4f0e6"), 0.65), Vector3(-32.4, 0.6, 0.5))
	_box(Vector3(12, 1.15, 0.12), GutterLooks.mat(Color("f4f0e6"), 0.65), Vector3(-26.5, 0.6, -8.4))
	_box(Vector3(8.5, 1.15, 0.12), GutterLooks.mat(Color("f4f0e6"), 0.65), Vector3(-28.2, 0.6, 9.4))
	for i in Game.FIELD_SIZE:
		var col := i % 3
		var row := int(i / 3)
		var x := -27.4 - float(row) * 2.6
		var z := float(col - 1) * 2.4
		_box(Vector3(1.8, 0.12, 1.7), GutterLooks.mat(Color("b8925a"), 0.88), Vector3(x, 0.06, z))
		_box(Vector3(0.08, 0.85, 1.7), GutterLooks.mat(Color("f4f0e6"), 0.65), Vector3(x - 0.9, 0.48, z))
		_box(Vector3(1.8, 0.85, 0.08), GutterLooks.mat(Color("f4f0e6"), 0.65), Vector3(x, 0.48, z - 0.85))
		_box(Vector3(1.8, 0.85, 0.08), GutterLooks.mat(Color("f4f0e6"), 0.65), Vector3(x, 0.48, z + 0.85))
		_marker("Pen%d" % i, Vector3(x, 0.12, z), ["pen_%d" % i]).rotation.y = -PI * 0.5
		_interact("pen", Vector3(x + 1.05, 0.4, z), i)
	_label("PADDOCK", Vector3(-26.5, 2.1, -8.1), 42, Color("1a3a18"))


func _bookie() -> void:
	_box(Vector3(3.2, 2.2, 2.4), GutterLooks.mat(Color("efe6d2")), Vector3(-24.2, 1.1, 8.8))
	_box(Vector3(3.6, 0.12, 1.8), GutterLooks.mat(Color("2e7a3a")), Vector3(-24.2, 2.32, 8.5))
	_box(Vector3(0.18, 0.35, 1.8), GutterLooks.mat(Color("f4f0e6")), Vector3(-25.7, 2.18, 8.5))
	_box(Vector3(0.18, 0.35, 1.8), GutterLooks.mat(Color("2e7a3a")), Vector3(-25.3, 2.18, 8.5))
	_box(Vector3(0.18, 0.35, 1.8), GutterLooks.mat(Color("f4f0e6")), Vector3(-22.7, 2.18, 8.5))
	_box(Vector3(3.0, 0.7, 0.7), GutterLooks.mat(Color("c4a882")), Vector3(-24.2, 0.9, 7.7))
	var board := Label3D.new()
	board.name = "OddsBoard"
	board.add_to_group("odds_board")
	board.text = "TODAY'S CARD"
	board.font_size = 26
	board.pixel_size = 0.004
	board.position = Vector3(-24.2, 1.85, 7.55)
	board.rotation.y = PI
	board.modulate = Color("1a120e")
	board.outline_size = 6
	board.outline_modulate = Color("f4f0e6")
	add_child(board)
	_label("WAGERING", Vector3(-24.2, 2.55, 8.8), 36, Color("1a3a18"))
	_interact("bookie", Vector3(-24.2, 0.4, 6.9))
	var clerk := Node3D.new()
	clerk.position = Vector3(-24.2, 0.0, 9.1)
	clerk.rotation.y = PI
	add_child(clerk)
	var clerk_model := Node3D.new()
	clerk.add_child(clerk_model)
	GutterLooks.build_person(clerk_model, Color("2e5a8a"))
	clerk.scale = Vector3.ONE


func _stands() -> void:
	_build_stand_bank(16.2, 1.0)
	_build_stand_bank(-16.2, -1.0)
	_cyl(Vector3(-10.0, 0.7, 17.6), 0.08, 1.4, GutterLooks.mat(Color("f4f0e6"), 0.55), 8, true)
	_cyl(Vector3(-10.0, 1.45, 17.6), 0.22, 0.22, GutterLooks.mat(Color("c42828"), 0.45), 10, false)
	_label("POST TIME", Vector3(-10.0, 1.95, 17.6), 28, Color("1a3a18"))
	_interact("bell", Vector3(-10.0, 0.4, 17.2))


func _build_stand_bank(z_start: float, z_dir: float) -> void:
	var vest_colors: Array[Color] = [
		Color("c45a5a"), Color("3a6aaa"), Color("3d8a48"), Color("d4a03a"), Color("5a5a62"), Color("e8e8e0"),
	]
	for row in 4:
		var y := 0.22 + float(row) * 0.48
		var z := z_start + z_dir * (0.2 + float(row) * 1.15)
		_box(Vector3(30.0, 0.42, 1.15), GutterLooks.mat(Color("e8e0d0"), 0.82), Vector3(0, y, z))
		if row == 0 or row == 2:
			continue
		for col in range(-4, 5):
			if abs(col) < 1 and abs(z_start) > 0:
				continue
			var person := Node3D.new()
			person.position = Vector3(float(col) * 2.15, y + 0.22, z - z_dir * 0.15)
			if z_dir > 0.0:
				person.rotation.y = PI
			person.scale = Vector3.ONE * randf_range(0.92, 1.06)
			person.set_script(preload("res://scripts/idle_bob.gd"))
			add_child(person)
			var model := Node3D.new()
			person.add_child(model)
			GutterLooks.build_person(model, vest_colors[randi() % vest_colors.size()])


func _vip() -> void:
	_box(Vector3(5.4, 0.28, 3.6), GutterLooks.mat(Color("c4a882"), 0.75), Vector3(12.0, 3.35, -18.4))
	_box(Vector3(5.6, 1.1, 0.12), GutterLooks.mat(Color("f4f0e6"), 0.55), Vector3(12.0, 3.95, -16.65))
	_box(Vector3(0.12, 1.1, 3.6), GutterLooks.mat(Color("f4f0e6"), 0.55), Vector3(9.5, 3.95, -18.4))
	_box(Vector3(0.12, 1.1, 3.6), GutterLooks.mat(Color("f4f0e6"), 0.55), Vector3(14.5, 3.95, -18.4))
	for i in 7:
		_box(
			Vector3(1.6, 0.22, 1.1),
			GutterLooks.mat(Color("e8e0d0")),
			Vector3(9.8, 0.2 + float(i) * 0.45, -15.6 - float(i) * 0.35)
		)
	_vip_gate = _box(Vector3(1.7, 1.6, 0.2), GutterLooks.mat(Color("2e7a3a"), 0.55), Vector3(9.8, 1.0, -15.4))
	_label("BOX SEATS", Vector3(12.0, 4.7, -18.4), 36, Color("1a3a18"))
	_interact("vip", Vector3(9.8, 0.4, -14.6))
	_marker("VipSpawn", Vector3(12.0, 3.7, -18.2), ["vip_spawn"])
	var zone := Area3D.new()
	zone.name = "VipZone"
	zone.add_to_group("vip_zone")
	zone.position = Vector3(12.0, 3.7, -18.4)
	zone.monitoring = true
	zone.collision_mask = 2
	zone.collision_layer = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(5.2, 2.4, 3.4)
	cs.shape = box
	zone.add_child(cs)
	add_child(zone)
	_box(Vector3(0.7, 0.7, 0.7), GutterLooks.mat(Color("3a6aaa")), Vector3(11.0, 3.75, -18.8))
	_box(Vector3(0.7, 0.7, 0.7), GutterLooks.mat(Color("c45a5a")), Vector3(13.0, 3.75, -18.8))


func _coop() -> void:
	_box(Vector3(11.5, 0.12, 14.0), GutterLooks.mat(Color("b8925a"), 0.9), Vector3(-40.2, 0.06, 0.2))
	_box(Vector3(4.2, 2.6, 4.8), GutterLooks.mat(Color("8a5a32")), Vector3(-43.6, 1.3, -5.0))
	_box(Vector3(4.8, 0.16, 5.4), GutterLooks.mat(Color("6a3a1c")), Vector3(-43.6, 2.68, -5.0))
	_box(Vector3(0.16, 1.2, 14.0), GutterLooks.mat(Color("f4f0e6"), 0.65), Vector3(-45.8, 0.7, 0.2))
	_box(Vector3(11.5, 1.2, 0.16), GutterLooks.mat(Color("f4f0e6"), 0.65), Vector3(-40.2, 0.7, -6.7))
	_box(Vector3(11.5, 1.2, 0.16), GutterLooks.mat(Color("f4f0e6"), 0.65), Vector3(-40.2, 0.7, 7.1))
	_box(Vector3(0.16, 1.2, 5.4), GutterLooks.mat(Color("f4f0e6"), 0.65), Vector3(-34.5, 0.7, -3.8))
	_box(Vector3(0.16, 1.2, 5.4), GutterLooks.mat(Color("f4f0e6"), 0.65), Vector3(-34.5, 0.7, 4.2))
	_label("YOUR COOP", Vector3(-40.2, 2.35, -6.4), 42, Color("1a3a18"))
	_label("GATE", Vector3(-34.4, 1.55, 0.2), 22, Color("1a3a18"))
	for i in ChickenStock.COOP_CAP:
		var col := i % 3
		var row := int(i / 3)
		var x := -38.4 - float(row) * 2.5
		var z := float(col - 1) * 2.3
		_box(Vector3(1.5, 0.04, 1.4), GutterLooks.mat(Color("a87848"), 0.92), Vector3(x, 0.09, z))
		_marker("CoopPen%d" % i, Vector3(x, 0.12, z), ["coop_pen_%d" % i])
	_feed_pan(Vector3(-37.0, 0.1, 3.4))
	_feed_pan(Vector3(-40.6, 0.1, 1.8))
	_feed_pan(Vector3(-38.4, 0.1, -3.2))
	_water_dish(Vector3(-41.4, 0.1, -4.0))
	for i in 14:
		var kernel := _box(
			Vector3(0.04, 0.02, 0.03),
			GutterLooks.mat(Color("e8c03a"), 0.55),
			Vector3(-36.2 - randf() * 5.4, 0.13, -4.4 + randf() * 10.2)
		)
		kernel.use_collision = false
		kernel.rotation.y = randf() * TAU
	_interact("coop", Vector3(-33.6, 0.4, 0.2))


func _market() -> void:
	_box(Vector3(3.4, 2.1, 2.6), GutterLooks.mat(Color("efe6d2")), Vector3(-37.6, 1.05, 8.6))
	_box(Vector3(3.8, 0.12, 1.6), GutterLooks.mat(Color("c42828")), Vector3(-37.6, 2.2, 8.3))
	_box(Vector3(2.8, 0.6, 0.7), GutterLooks.mat(Color("c4a882")), Vector3(-37.6, 0.85, 7.5))
	_label("BIRD MARKET", Vector3(-37.6, 2.45, 8.6), 32, Color("1a3a18"))
	_label("FEED SHED", Vector3(-35.2, 1.55, 7.4), 18, Color("1a3a18"))
	_box(Vector3(0.7, 0.55, 0.45), GutterLooks.mat(Color("c4a04a")), Vector3(-35.4, 0.4, 7.2))
	_box(Vector3(0.55, 0.4, 0.38), GutterLooks.mat(Color("b08d57")), Vector3(-34.8, 0.32, 7.5))
	_interact("market", Vector3(-37.6, 0.4, 6.7))
	var dealer := Node3D.new()
	dealer.position = Vector3(-37.6, 0.0, 8.9)
	dealer.rotation.y = PI
	add_child(dealer)
	var model := Node3D.new()
	dealer.add_child(model)
	GutterLooks.build_person(model, Color("8a3e24"))


func _fryer() -> void:
	_box(Vector3(3.6, 2.4, 3.0), GutterLooks.mat(Color("6a4a32")), Vector3(18.4, 1.2, 12.6))
	_box(Vector3(3.9, 0.14, 3.3), GutterLooks.mat(Color("3a2a1c")), Vector3(18.4, 2.48, 12.6))
	_box(Vector3(1.4, 0.12, 0.9), GutterLooks.mat(Color("8a8e86"), 0.4, 0.35), Vector3(18.4, 1.05, 10.9))
	_box(Vector3(1.1, 0.16, 0.7), GutterLooks.mat(Color("c47828"), 0.55), Vector3(18.4, 1.14, 10.9))
	_label("THE FRYER", Vector3(18.4, 2.75, 12.6), 32, Color("1a3a18"))
	_label("LAST PLACE", Vector3(18.4, 1.55, 10.9), 18, Color("1a120e"))
	_interact("fryer", Vector3(18.4, 0.4, 10.4))
	var cook := Node3D.new()
	cook.position = Vector3(18.4, 0.0, 13.4)
	cook.rotation.y = PI
	add_child(cook)
	var cook_model := Node3D.new()
	cook.add_child(cook_model)
	GutterLooks.build_person(cook_model, Color("c45a28"))
	_fry_plate = Node3D.new()
	_fry_plate.position = Vector3(18.4, 1.22, 10.9)
	_fry_plate.visible = false
	add_child(_fry_plate)
	GutterLooks.build_fried_chicken(_fry_plate)


func _refresh_coop() -> void:
	while _coop_birds.size() < ChickenStock.COOP_CAP:
		var bird: Snail = preload("res://scenes/snail.tscn").instantiate()
		add_child(bird)
		bird.visible = false
		_coop_birds.append(bird)
	var claimed: Dictionary = {}
	for data in Game.coop:
		var chicken_id := str(data.get("id", ""))
		if chicken_id.is_empty() or chicken_id == Game.entered_id:
			continue
		var bird := _coop_bird_for(chicken_id)
		if bird == null:
			continue
		claimed[bird] = true
		var needs_yard := (not bird.in_yard) or bird.chicken_id != chicken_id or not bird.visible or bird.sex != int(data.get("sex", bird.sex))
		if needs_yard:
			bird.configure(data, _coop_birds.find(bird) + 1, 0.5)
			bird.release_to_yard(_yard_min(), _yard_max(), _random_yard_point())
		else:
			bird.set_nametag(str(data.get("name", bird.display_name)))
		bird.visible = true
	for bird in _coop_birds:
		if claimed.has(bird):
			continue
		bird.visible = false
		bird.leave_yard()


func _coop_bird_for(chicken_id: String) -> Snail:
	for bird in _coop_birds:
		if bird.chicken_id == chicken_id and (bird.in_yard or bird.visible):
			return bird
	for bird in _coop_birds:
		if not bird.visible and not bird.in_yard:
			return bird
	for bird in _coop_birds:
		if not bird.visible:
			return bird
	return null


func _yard_min() -> Vector3:
	return Vector3(-41.8, 0.12, -5.4)


func _yard_max() -> Vector3:
	return Vector3(-35.2, 0.12, 6.2)


func _random_yard_point() -> Vector3:
	var lo := _yard_min()
	var hi := _yard_max()
	return Vector3(randf_range(lo.x, hi.x), lo.y, randf_range(lo.z, hi.z))


func _feed_pan(at: Vector3) -> void:
	var pan := _cyl(at + Vector3(0, 0.03, 0), 0.28, 0.06, GutterLooks.mat(Color("8a8e86"), 0.45, 0.25), 10, false)
	var corn := _cyl(at + Vector3(0, 0.06, 0), 0.18, 0.03, GutterLooks.mat(Color("e8c03a"), 0.7), 8, false)
	var mark := Marker3D.new()
	mark.position = at
	mark.add_to_group("coop_feed")
	add_child(mark)


func _water_dish(at: Vector3) -> void:
	var dish := _box(Vector3(0.7, 0.08, 0.38), GutterLooks.mat(Color("8a8e86"), 0.4, 0.3), at + Vector3(0, 0.06, 0))
	dish.use_collision = false
	var water := _box(Vector3(0.58, 0.03, 0.28), GutterLooks.mat(Color("6a9ad0"), 0.2, 0.05), at + Vector3(0, 0.1, 0))
	water.use_collision = false
	var mark := Marker3D.new()
	mark.position = at
	mark.add_to_group("coop_water")
	add_child(mark)


func _refresh_schedule() -> void:
	var sched := get_tree().get_first_node_in_group("schedule_board") as Label3D
	if sched:
		var jewels := PackedStringArray(["TRIPLE WING"])
		for i in ChickenStock.SCHEDULE.size():
			var row: Dictionary = ChickenStock.SCHEDULE[i]
			var mark := ">" if i == Game.meet_index else " "
			var extra := " *" if int(row.get("wing", -1)) >= 0 else ""
			jewels.append("%s %s%s" % [mark, row.get("name", ""), extra])
		sched.text = "\n".join(jewels)
	apply_card_condition(Game.card_condition())


func apply_card_condition(condition: int) -> void:
	_paint_condition_sign(condition)
	if _painted_condition == condition and _card_fx != null and _card_fx.get_child_count() > 0:
		_paint_sky(condition)
		return
	_painted_condition = condition
	if _track_body:
		_track_body.material_override = GutterLooks.mat(RaceChaos.track_tint(condition), 0.88, 0.05)
	if _track_dirt:
		_track_dirt.material_override = GutterLooks.mat(RaceChaos.dirt_tint(condition), 0.92, 0.0)
	_paint_sky(condition)
	_clear_fx(_card_fx)
	if condition == RaceChaos.Condition.GREASE_DRIP:
		_spawn_slick(_card_fx, _path_point(RaceChaos.GREASE_FRAC), Color("1a1208"), 2.4)
		_spawn_slick(_card_fx, _path_point(RaceChaos.GREASE_FRAC + 0.04), Color("2a1a0c"), 1.7)
	elif condition == RaceChaos.Condition.KERNEL_SCATTER:
		for i in 24:
			var frac := 0.04 + float(i) / 24.0 * 0.92
			_spawn_kernels(_card_fx, _path_point(frac), 8, 0.14)
	elif condition == RaceChaos.Condition.DUST_BOWL:
		for i in 10:
			_spawn_dust(_card_fx, _path_point(float(i) / 10.0), Color("e8d090"))


func show_live_event(event: int, at_distance: float) -> void:
	_clear_fx(_live_fx)
	_hawk = null
	_dog = null
	_hawk_shadow = null
	_live_event = event
	_live_t = 0.0
	var length := _path_length()
	var frac := clampf(at_distance / maxf(length, 0.001), 0.0, 1.0)
	_live_at = _path_point(frac)
	match event:
		RaceChaos.LiveEvent.OIL_SLICK:
			_spawn_slick(_live_fx, _live_at, Color("14100a"), 2.8)
			_spawn_slick(_live_fx, _path_point(clampf(frac + 0.035, 0.05, 0.95)), Color("22180c"), 2.1)
			_spawn_slick(_live_fx, _path_point(clampf(frac - 0.03, 0.05, 0.95)), Color("1a1408"), 1.8)
			_spawn_event_light(_live_at + Vector3(0, 1.4, 0), Color("4a3a18"), 2.4, 10.0)
		RaceChaos.LiveEvent.CORN_RAIN:
			_spawn_corn_rain(_live_at, frac)
			_spawn_event_light(_live_at + Vector3(0, 3.4, 0), Color("e8c03a"), 4.2, 16.0)
		RaceChaos.LiveEvent.HAWK:
			_paint_sky(RaceChaos.Condition.STORM_COMING)
			_hawk = _spawn_hawk(_live_at)
			_hawk_shadow = _spawn_hawk_shadow(_live_at)
			_spawn_event_light(_live_at + Vector3(0, 5.0, 0), Color("8a2030"), 2.8, 14.0)
		RaceChaos.LiveEvent.LOOSE_DOG:
			_dog = _spawn_dog(Vector3(6.4, 0.28, 0.0))
			_spawn_event_light(Vector3(0, 2.2, 0), Color("8a5a28"), 2.2, 12.0)
		RaceChaos.LiveEvent.FALSE_GUN:
			_spawn_gun_puff(Vector3(-10.0, 1.6, 16.4))
		RaceChaos.LiveEvent.CROWD_SQUEEZE:
			_spawn_crowd_lean()


func clear_live_event() -> void:
	_live_event = RaceChaos.LiveEvent.NONE
	_live_t = 0.0
	_hawk = null
	_dog = null
	_hawk_shadow = null
	_clear_fx(_live_fx)
	_paint_sky(_painted_condition if _painted_condition >= 0 else RaceChaos.Condition.FAIR_DIRT)


func _process(delta: float) -> void:
	if _live_event == RaceChaos.LiveEvent.NONE or _live_fx == null:
		return
	_live_t += delta
	match _live_event:
		RaceChaos.LiveEvent.CORN_RAIN:
			_tick_corn_rain(delta)
		RaceChaos.LiveEvent.HAWK:
			_tick_hawk()
		RaceChaos.LiveEvent.LOOSE_DOG:
			_tick_dog(delta)


func _paint_sky(condition: int) -> void:
	if _world_env == null or _world_env.environment == null:
		return
	var env := _world_env.environment
	var sky_mat := env.sky.sky_material as ProceduralSkyMaterial if env.sky else null
	match condition:
		RaceChaos.Condition.STORM_COMING:
			if sky_mat:
				sky_mat.sky_top_color = Color("3a4a62")
				sky_mat.sky_horizon_color = Color("8aa0b0")
				sky_mat.ground_horizon_color = Color("6a7a58")
			env.fog_light_color = Color("9aa8b4")
			env.fog_density = 0.0048
			if _sun:
				_sun.light_energy = 0.85
				_sun.light_color = Color("d8dce4")
		RaceChaos.Condition.DUST_BOWL:
			if sky_mat:
				sky_mat.sky_top_color = Color("6aa8d8")
				sky_mat.sky_horizon_color = Color("e8dcb0")
				sky_mat.ground_horizon_color = Color("c4b070")
			env.fog_light_color = Color("e4d6a8")
			env.fog_density = 0.0032
			if _sun:
				_sun.light_energy = 1.35
				_sun.light_color = Color("ffe8b8")
		RaceChaos.Condition.KERNEL_SCATTER:
			if sky_mat:
				sky_mat.sky_top_color = Color("5aa8e0")
				sky_mat.sky_horizon_color = Color("f0d888")
				sky_mat.ground_horizon_color = Color("d4b048")
			env.fog_light_color = Color("f0dc90")
			env.fog_density = 0.0024
			if _sun:
				_sun.light_energy = 1.65
				_sun.light_color = Color("ffe08a")
		RaceChaos.Condition.GREASE_DRIP:
			if sky_mat:
				sky_mat.sky_top_color = Color("3a6a88")
				sky_mat.sky_horizon_color = Color("c4b080")
				sky_mat.ground_horizon_color = Color("6a5230")
			env.fog_light_color = Color("b8a070")
			env.fog_density = 0.0028
			if _sun:
				_sun.light_energy = 1.05
				_sun.light_color = Color("e0c890")
		_:
			if sky_mat:
				sky_mat.sky_top_color = Color("4a9ee8")
				sky_mat.sky_horizon_color = Color("d6eef8")
				sky_mat.ground_horizon_color = Color("8aab58")
			env.fog_light_color = Color("d8eaf4")
			env.fog_density = 0.0012
			if _sun:
				_sun.light_energy = 1.5
				_sun.light_color = Color("fff1d2")


func _paint_condition_sign(condition: int) -> void:
	if _condition_sign == null:
		return
	_condition_sign.text = RaceChaos.condition_name(condition).to_upper()
	_condition_sign.modulate = RaceChaos.condition_banner_color(condition)
	_condition_sign.outline_modulate = Color("1a120e")
	_condition_sign.font_size = 62


func _spawn_slick(parent: Node3D, at: Vector3, color: Color, radius: float = 1.15) -> void:
	if parent == null:
		return
	var y := Game.TRACK_SURFACE_Y + 0.025
	var slick := _fx_disc(parent, Vector3(at.x, y, at.z), radius, 0.06, GutterLooks.mat(color, 0.08, 0.92, Color("6a5a28"), 1.4), 12)
	slick.name = "OilSlick"
	var smear := MeshInstance3D.new()
	smear.mesh = GutterLooks.box(Vector3(radius * 2.2, 0.03, radius * 0.7))
	smear.material_override = GutterLooks.mat(color.lightened(0.08), 0.16, 0.7, color.lightened(0.15), 0.4)
	smear.position = Vector3(at.x, y - 0.005, at.z)
	smear.rotation.y = atan2(at.x, at.z)
	smear.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(smear)
	var rim := _fx_disc(parent, Vector3(at.x, y + 0.008, at.z), radius + 0.22, 0.03, GutterLooks.mat(Color("e8c03a"), 0.35, 0.15, Color("f0d060"), 1.6), 14)
	rim.name = "OilRim"


func _spawn_kernels(parent: Node3D, at: Vector3, count: int, size: float = 0.05) -> void:
	if parent == null:
		return
	for i in count:
		var kernel := MeshInstance3D.new()
		kernel.mesh = GutterLooks.box(Vector3(size, size * 0.55, size * 0.72))
		kernel.material_override = GutterLooks.mat(Color("e8c03a"), 0.4, 0.0, Color("f0d060"), 1.1)
		kernel.position = at + Vector3(randf_range(-0.85, 0.85), 0.0, randf_range(-0.85, 0.85))
		kernel.position.y = Game.TRACK_SURFACE_Y + 0.03
		kernel.rotation.y = randf() * TAU
		kernel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(kernel)


func _spawn_dust(parent: Node3D, at: Vector3, color: Color) -> void:
	if parent == null:
		return
	# Haze pancake on the dirt — the old 0.9m CSG can read as a giant drum on the oval.
	var mat := GutterLooks.mat(color.lightened(0.08), 0.95)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, 0.42)
	var puff := _fx_disc(parent, Vector3(at.x, Game.TRACK_SURFACE_Y + 0.08, at.z), 1.15, 0.12, mat, 8)
	puff.name = "DustHaze"


func _spawn_event_light(at: Vector3, color: Color, energy: float, radius: float) -> void:
	if _live_fx == null:
		return
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.position = at
	light.shadow_enabled = false
	_live_fx.add_child(light)


func _ensure_corn_assets() -> void:
	if _corn_mesh == null:
		_corn_mesh = BoxMesh.new()
		_corn_mesh.size = Vector3(0.22, 0.13, 0.16)
	if _corn_mat == null:
		_corn_mat = GutterLooks.mat(Color("e8c03a"), 0.38, 0.0, Color("f4d060"), 1.8)


func _spawn_corn_rain(at: Vector3, frac: float) -> void:
	_ensure_corn_assets()
	for i in 48:
		var k := MeshInstance3D.new()
		k.mesh = _corn_mesh
		k.material_override = _corn_mat
		k.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var around := _path_point(clampf(frac + randf_range(-0.12, 0.12), 0.04, 0.96))
		k.position = around + Vector3(randf_range(-2.4, 2.4), randf_range(2.8, 9.5), randf_range(-2.4, 2.4))
		k.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		k.set_meta("fall", randf_range(5.2, 9.0))
		k.set_meta("spin", Vector3(randf_range(-5.0, 5.0), randf_range(-8.0, 8.0), randf_range(-5.0, 5.0)))
		_live_fx.add_child(k)
	for i in 10:
		_spawn_kernels(_live_fx, _path_point(clampf(frac + float(i - 5) * 0.04, 0.05, 0.95)), 4, 0.16)


func _tick_corn_rain(delta: float) -> void:
	for child in _live_fx.get_children():
		if not child.has_meta("fall"):
			continue
		var node := child as Node3D
		if node == null:
			continue
		node.position.y -= float(node.get_meta("fall")) * delta
		var spin: Vector3 = node.get_meta("spin")
		node.rotation += spin * delta
		if node.position.y < Game.TRACK_SURFACE_Y + 0.04:
			node.position.y = randf_range(5.5, 9.2)
			node.position.x = _live_at.x + randf_range(-2.6, 2.6)
			node.position.z = _live_at.z + randf_range(-2.6, 2.6)


func _spawn_hawk(at: Vector3) -> Node3D:
	var hawk := Node3D.new()
	hawk.name = "Hawk"
	hawk.position = at + Vector3(0, 7.2, 0)
	var feather := GutterLooks.mat(Color("3a2418"), 0.78)
	var dark := GutterLooks.mat(Color("1a120e"), 0.7)
	var beak := GutterLooks.mat(Color("c47828"), 0.45)
	_mesh_on(hawk, GutterLooks.box(Vector3(0.38, 0.22, 1.15)), feather, Vector3(0, 0, 0))
	_mesh_on(hawk, GutterLooks.box(Vector3(3.4, 0.08, 0.7)), dark, Vector3(0, 0.04, 0.05))
	_mesh_on(hawk, GutterLooks.box(Vector3(0.22, 0.16, 0.32)), feather, Vector3(0, 0.04, -0.62))
	_mesh_on(hawk, GutterLooks.box(Vector3(0.08, 0.08, 0.22)), beak, Vector3(0, 0.0, -0.82))
	_mesh_on(hawk, GutterLooks.box(Vector3(0.18, 0.28, 0.12)), dark, Vector3(0, 0.16, 0.52))
	_live_fx.add_child(hawk)
	return hawk


func _spawn_hawk_shadow(at: Vector3) -> Node3D:
	var shadow := _fx_disc(
		_live_fx,
		Vector3(at.x, Game.TRACK_SURFACE_Y + 0.02, at.z),
		1.8,
		0.04,
		GutterLooks.mat(Color(0.04, 0.03, 0.02, 0.7), 0.95),
		10
	)
	shadow.name = "HawkShadow"
	return shadow


func _tick_hawk() -> void:
	if _hawk == null:
		return
	var dive := clampf(_live_t / 1.15, 0.0, 1.0)
	var y := lerpf(7.2, 1.05, dive)
	if _live_t > 1.2:
		y = lerpf(1.05, 5.4, clampf((_live_t - 1.2) / 1.1, 0.0, 1.0))
	var sweep := sin(_live_t * 2.1) * 2.4
	_hawk.position = _live_at + Vector3(sweep, y, cos(_live_t * 1.6) * 1.4)
	_hawk.rotation.z = -sweep * 0.12
	_hawk.rotation.x = 0.55 if dive < 1.0 and _live_t < 1.2 else -0.15
	if _hawk_shadow:
		_hawk_shadow.position = Vector3(_hawk.position.x, Game.TRACK_SURFACE_Y + 0.02, _hawk.position.z)
		var wide := 2.6 if y < 2.2 else 1.6
		_hawk_shadow.scale = Vector3(wide, 1.0, wide)


func _spawn_dog(at: Vector3) -> Node3D:
	var dog := Node3D.new()
	dog.name = "LooseDog"
	dog.position = at
	var hide := GutterLooks.mat(Color("6a4224"), 0.82)
	var dark := GutterLooks.mat(Color("2a1a10"), 0.75)
	_mesh_on(dog, GutterLooks.box(Vector3(0.42, 0.38, 0.95)), hide, Vector3(0, 0.32, 0))
	_mesh_on(dog, GutterLooks.box(Vector3(0.36, 0.32, 0.36)), hide, Vector3(0, 0.42, -0.52))
	_mesh_on(dog, GutterLooks.box(Vector3(0.08, 0.22, 0.12)), dark, Vector3(-0.12, 0.62, -0.52))
	_mesh_on(dog, GutterLooks.box(Vector3(0.08, 0.22, 0.12)), dark, Vector3(0.12, 0.62, -0.52))
	_mesh_on(dog, GutterLooks.box(Vector3(0.1, 0.08, 0.16)), dark, Vector3(0, 0.34, -0.7))
	_mesh_on(dog, GutterLooks.box(Vector3(0.08, 0.1, 0.28)), hide, Vector3(0, 0.38, 0.55))
	for side in [-1.0, 1.0]:
		_mesh_on(dog, GutterLooks.cyl(0.055, 0.28, 6), dark, Vector3(side * 0.14, 0.12, -0.28))
		_mesh_on(dog, GutterLooks.cyl(0.055, 0.28, 6), dark, Vector3(side * 0.14, 0.12, 0.28))
	_live_fx.add_child(dog)
	return dog


func _tick_dog(_delta: float) -> void:
	if _dog == null:
		return
	var a := _live_t * 2.15
	var rx := Game.TRACK_RX - Game.TRACK_WIDTH * 0.22
	var rz := Game.TRACK_RZ - Game.TRACK_WIDTH * 0.22
	var next := Vector3(cos(a) * rx, 0.12 + absf(sin(_live_t * 14.0)) * 0.08, sin(a) * rz)
	_dog.global_position = next
	var ahead := Vector3(cos(a + 0.12) * rx, next.y, sin(a + 0.12) * rz)
	if Vector3(ahead.x - next.x, 0.0, ahead.z - next.z).length_squared() > 0.0001:
		_dog.look_at(ahead, Vector3.UP)


func _spawn_gun_puff(at: Vector3) -> void:
	var puff := _fx_disc(_live_fx, at, 0.55, 1.1, GutterLooks.mat(Color(0.85, 0.85, 0.8, 0.55), 0.95), 8)
	puff.name = "GunPuff"
	_spawn_event_light(at, Color("f0ead8"), 5.5, 9.0)


func _spawn_crowd_lean() -> void:
	for i in 8:
		var t := float(i) / 8.0
		var p := Vector3((t - 0.5) * 18.0, 1.4, 15.4)
		var slab := CSGBox3D.new()
		slab.size = Vector3(1.6, 1.1, 0.35)
		slab.position = p
		slab.rotation.x = 0.35
		slab.material = GutterLooks.mat(Color("8a3a4a"), 0.7)
		slab.use_collision = false
		_live_fx.add_child(slab)
	_spawn_event_light(Vector3(0, 2.6, 0), Color("8a3a4a"), 2.0, 14.0)


func _mesh_on(parent: Node3D, mesh_res: Mesh, material: Material, pos: Vector3) -> MeshInstance3D:
	return GutterLooks.mesh(parent, mesh_res, material, pos)


func _clear_fx(root: Node3D) -> void:
	if root == null:
		return
	for child in root.get_children():
		child.queue_free()


func _path_length() -> float:
	var path := get_tree().get_first_node_in_group("track_path") as Path3D
	if path == null or path.curve == null:
		return 1.0
	return maxf(path.curve.get_baked_length(), 0.001)


func _path_point(frac: float) -> Vector3:
	var path := get_tree().get_first_node_in_group("track_path") as Path3D
	if path == null or path.curve == null:
		return Vector3(cos(frac * TAU) * Game.TRACK_RX, Game.TRACK_SURFACE_Y, sin(frac * TAU) * Game.TRACK_RZ)
	var xf := path.curve.sample_baked_with_rotation(clampf(frac, 0.0, 1.0) * path.curve.get_baked_length(), true)
	var inward := Vector3(-xf.origin.x, 0.0, -xf.origin.z)
	if inward.length_squared() < 0.0001:
		inward = -xf.basis.x
	else:
		inward = inward.normalized()
	return xf.origin + inward * 0.15


func _on_results(payload: Dictionary) -> void:
	if _fry_plate == null:
		return
	_fry_plate.visible = not str(payload.get("fried_name", "")).is_empty()


func _flags() -> void:
	var colors: Array[Color] = [
		Color("c42828"), Color("2e5aaa"), Color("e8c03a"), Color("2e7a3a"), Color("f4f0e6"),
	]
	var rx := Game.TRACK_RX + Game.TRACK_WIDTH * 0.5 + 0.55
	var rz := Game.TRACK_RZ + Game.TRACK_WIDTH * 0.5 + 0.55
	for i in 10:
		var t := float(i) / 10.0
		_pennant(GutterLooks.oval_point(t, rx, rz, 0.0), colors[i % colors.size()])
	_pennant(Vector3(-26.5, 0.0, -8.2), Color("c42828"))
	_pennant(Vector3(-24.2, 0.0, 7.2), Color("2e7a3a"))
	_pennant(Vector3(12.0, 3.4, -18.4), Color("2e5aaa"))
	_pennant(Vector3(-40.2, 0.0, -6.4), Color("c42828"))
	_pennant(Vector3(18.4, 0.0, 11.4), Color("e8c03a"))


func _props() -> void:
	_cyl(Vector3(-18.5, 0.4, 12.0), 0.42, 0.8, GutterLooks.mat(Color("d4b85a"), 0.9), 12, true)
	_cyl(Vector3(-17.6, 0.32, 12.6), 0.38, 0.64, GutterLooks.mat(Color("c4a050"), 0.9), 12, true)
	_box(Vector3(1.6, 0.55, 0.7), GutterLooks.mat(Color("8a8e86"), 0.45, 0.35), Vector3(-19.5, 0.32, -12.5))
	_box(Vector3(1.4, 0.12, 0.55), GutterLooks.mat(Color("6a9ad0"), 0.3, 0.1), Vector3(-19.5, 0.62, -12.5))
	_box(Vector3(2.6, 0.9, 0.16), GutterLooks.mat(Color("f4f0e6"), 0.6), Vector3(20.8, 0.5, 0))
	_box(Vector3(2.6, 0.9, 0.16), GutterLooks.mat(Color("f4f0e6"), 0.6), Vector3(20.8, 0.5, 1.4))
	_label("GATE", Vector3(20.8, 1.15, 0.7), 22, Color("1a3a18"))


func _markers() -> void:
	var spawn := _marker("PlayerSpawn", Vector3(-24.0, 0.08, 1.6), ["player_spawn"])
	spawn.rotation.y = PI * 0.15


func _on_vip_changed(owned: bool) -> void:
	if _vip_gate == null:
		return
	_vip_gate.visible = not owned
	_vip_gate.use_collision = not owned


func _track_mesh(rx: float, rz: float, width: float, top_y: float, thickness: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 72
	var yb := top_y - thickness
	var yt := top_y
	for i in segments:
		var t0 := float(i) / float(segments)
		var t1 := float(i + 1) / float(segments)
		var a0 := t0 * TAU
		var a1 := t1 * TAU
		var p0 := Vector3(cos(a0) * rx, 0.0, sin(a0) * rz)
		var p1 := Vector3(cos(a1) * rx, 0.0, sin(a1) * rz)
		var n0 := Vector3(cos(a0) * rz, 0, sin(a0) * rx).normalized()
		var n1 := Vector3(cos(a1) * rz, 0, sin(a1) * rx).normalized()
		var hw := width * 0.5
		var a := p0 + n0 * hw + Vector3.UP * yt
		var b := p1 + n1 * hw + Vector3.UP * yt
		var c := p1 - n1 * hw + Vector3.UP * yt
		var d := p0 - n0 * hw + Vector3.UP * yt
		var a2 := p0 + n0 * hw + Vector3.UP * yb
		var b2 := p1 + n1 * hw + Vector3.UP * yb
		var c2 := p1 - n1 * hw + Vector3.UP * yb
		var d2 := p0 - n0 * hw + Vector3.UP * yb
		_quad(st, a, b, c, d)
		_quad(st, a, a2, b2, b)
		_quad(st, d, c, c2, d2)
	st.generate_normals()
	return st.commit()


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(d)


func _white_fence(rx: float, rz: float) -> void:
	var white := GutterLooks.mat(Color("f4f0e6"), 0.62)
	var segments := 48
	var post_h := 0.7
	var rail_y := Game.TRACK_SURFACE_Y + 0.38
	for i in segments:
		var t0 := float(i) / float(segments)
		var t1 := float(i + 1) / float(segments)
		var p0 := GutterLooks.oval_point(t0, rx, rz, rail_y)
		var p1 := GutterLooks.oval_point(t1, rx, rz, rail_y)
		var post := _cyl(GutterLooks.oval_point(t0, rx, rz, Game.TRACK_SURFACE_Y + post_h * 0.5), 0.045, post_h, white, 6, false)
		post.name = "RailPost"
		var delta := p1 - p0
		var mid := (p0 + p1) * 0.5
		var board := CSGBox3D.new()
		board.size = Vector3(maxf(delta.length(), 0.08), 0.08, 0.04)
		board.position = mid
		var x_axis := Vector3(delta.x, 0.0, delta.z)
		if x_axis.length_squared() < 0.0001:
			continue
		x_axis = x_axis.normalized()
		var z_axis := x_axis.cross(Vector3.UP).normalized()
		board.transform = Transform3D(Basis(x_axis, Vector3.UP, z_axis), mid)
		board.material = white
		board.use_collision = false
		add_child(board)


func _pennant(at: Vector3, color: Color) -> void:
	var outward := Vector3(at.x, 0.0, at.z)
	if outward.length_squared() < 0.01:
		outward = Vector3.RIGHT
	else:
		outward = outward.normalized()
	var pole := _cyl(at + Vector3(0, 1.15, 0), 0.03, 2.3, GutterLooks.mat(Color("f4f0e6"), 0.6), 6, false)
	pole.name = "FlagPole"
	var flag := _box(Vector3(0.58, 0.34, 0.04), GutterLooks.mat(color, 0.72), at + outward * 0.32 + Vector3(0, 2.05, 0))
	flag.use_collision = false


func _box(size: Vector3, material: Material, pos: Vector3) -> CSGBox3D:
	var b := CSGBox3D.new()
	b.size = size
	b.position = pos
	b.material = material
	b.use_collision = true
	add_child(b)
	return b


func _fx_disc(parent: Node3D, at: Vector3, radius: float, height: float, material: Material, sides: int = 12) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = GutterLooks.cyl(radius, height, sides)
	mi.material_override = material
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _cyl(pos: Vector3, radius: float, height: float, material: Material, sides: int = 12, collide: bool = true) -> MeshInstance3D:
	# CylinderMesh, not CSG. Thin/huge CSGCylinder3D hits Godot 4.7 Manifold and can
	# come back as the default r=0.5 / h=2.0 can — that's the giant-on-the-oval bug.
	var mi := GutterLooks.mesh(self, GutterLooks.cyl(radius, height, sides), material, pos)
	if collide:
		var body := StaticBody3D.new()
		body.position = pos
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		cs.shape = shape
		body.add_child(cs)
		add_child(body)
	return mi


func list_oval_cylinders() -> PackedStringArray:
	var lines: PackedStringArray = []
	_collect_cylinders(self, lines, false)
	return lines


func audit_oval_cylinders() -> PackedStringArray:
	var bad: PackedStringArray = []
	_collect_cylinders(self, bad, true)
	return bad


func _collect_cylinders(node: Node, out: PackedStringArray, offenders_only: bool) -> void:
	if node is CSGCylinder3D:
		var csg := node as CSGCylinder3D
		# Leftover CSG on the oval is the bug — always report it.
		out.append("%s csg r=%.3f h=%.3f at=%s" % [csg.name, csg.radius, csg.height, csg.global_position])
	elif node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var mesh := mi.mesh
		if mesh is CylinderMesh:
			var cyl := mesh as CylinderMesh
			var sc := mi.global_transform.basis.get_scale()
			var radius := maxf(cyl.top_radius, cyl.bottom_radius) * maxf(absf(sc.x), absf(sc.z))
			var height := cyl.height * absf(sc.y)
			var line := "%s mesh r=%.3f h=%.3f at=%s" % [mi.name, radius, height, mi.global_position]
			if not offenders_only or _cylinder_pollutes_oval(mi.global_position, radius, height):
				out.append(line)
	for child in node.get_children():
		_collect_cylinders(child, out, offenders_only)


func _cylinder_pollutes_oval(pos: Vector3, radius: float, height: float) -> bool:
	# Any leftover CSG cylinder is a Manifold risk. Fat + tall on the racing ribbon
	# is the playtest "giant cans on the oval" look.
	if radius >= 0.4 and height >= 0.45 and _on_oval_ribbon(pos):
		return true
	return false


func _on_oval_ribbon(pos: Vector3) -> bool:
	var rx := Game.TRACK_RX
	var rz := Game.TRACK_RZ
	if rx <= 0.001 or rz <= 0.001:
		return false
	var e := (pos.x * pos.x) / (rx * rx) + (pos.z * pos.z) / (rz * rz)
	var band := Game.TRACK_WIDTH / minf(rx, rz)
	return e >= 1.0 - band and e <= 1.0 + band


func _label(text: String, pos: Vector3, size: int, color: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.font_size = size
	l.pixel_size = 0.004
	l.modulate = color
	l.outline_size = 8
	l.outline_modulate = Color("f4f0e8")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	add_child(l)
	return l


func _marker(marker_name: String, pos: Vector3, groups: Array = []) -> Marker3D:
	var m := Marker3D.new()
	m.name = marker_name
	m.position = pos
	add_child(m)
	for g in groups:
		m.add_to_group(str(g))
	return m


func _interact(kind: String, pos: Vector3, index: int = 0) -> Interactable:
	var a := Interactable.new()
	a.kind = kind
	a.index = index
	a.position = pos
	add_child(a)
	return a
