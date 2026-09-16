extends Node3D
class_name Snail

enum Archetype { SPRINTER, STEADY, CHAOS, LATE }
enum Crawl { REST, SLIDE }
enum ChaosBeat { NONE, PEBBLE, DART, LUNGE }
enum YardAct { IDLE, WANDER, PECK, EAT, SCRATCH, LOOK, DUST, STARTLE, CHASE, DRINK }

var snail_id: int = 0
var chicken_id: String = ""
var owner_id: int = 0
var grade: int = 0
var sex: int = 0
var display_name: String = "Chicken"
var flavor: String = ""
var hint: String = ""
var mood: String = ""
var shell_color: Color = Color("6b8f3a")
var archetype: Archetype = Archetype.STEADY
var form: float = 1.0
var odds: Vector2i = Vector2i(3, 1)
var fried: bool = false
var groove: float = 0.6
var height: float = 0.0
var height_vel: float = 0.0
var squish: float = 1.0
var distance: float = 0.0
var lap_length: float = 80.0
var racing: bool = false
var finished: bool = false
var finish_time: float = 0.0
var place: int = 0
var vel: float = 0.0
var bump_along: float = 0.0
var bump_lat: float = 0.0
var climb_timer: float = 0.0
var chaos_beat: ChaosBeat = ChaosBeat.NONE
var hunger: float = 80.0
var traits: Array[int] = []
var crop_boost: float = 0.0
var freeze_left: float = 0.0
var freeze_lock: float = 0.0
var zone_hit: bool = false
var chaos_tag: String = ""
var told_rail: bool = false
var told_climb: bool = false
var told_cut: bool = false
var told_slip: bool = false

var _model: Node3D
var _label: Label3D
var _mine_ring: MeshInstance3D
var _mine_light: OmniLight3D
var _legs: Node3D
var _wag: float = 0.0
var _crawl: Crawl = Crawl.REST
var _crawl_t: float = 0.0
var _slide_dur: float = 1.0
var _rest_dur: float = 0.5
var _peak: float = 1.6
var _chaos_t: float = 0.0
var _chaos_dur: float = 0.0
var _chaos_cd: float = 0.0
var in_yard: bool = false
var yard_min: Vector3 = Vector3.ZERO
var yard_max: Vector3 = Vector3.ZERO
var _yard_act: YardAct = YardAct.IDLE
var _yard_t: float = 0.0
var _yard_dur: float = 1.0
var _yard_target: Vector3 = Vector3.ZERO
var _yard_speed: float = 0.0
var _startle_cd: float = 0.0
var _eat_at: Vector3 = Vector3.ZERO
var _track_target: Vector3 = Vector3.ZERO
var _track_yaw: float = 0.0
var _have_track_target: bool = false
var _shown_vel: float = 0.0
var _gait_move: float = 0.0
var _head: Node3D
var _wings: Node3D
var _tail: Node3D
var _sweat: CPUParticles3D
var _voice: AudioStreamPlayer3D
var _head_rest: Vector3 = Vector3.ZERO
var _squawk_cd: float = 0.0
var net_smooth: NetSmooth = NetSmooth.new()


func _ready() -> void:
	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)
	_label = Label3D.new()
	_label.position = Vector3(0, 0.58, 0)
	_label.font_size = 22
	_label.pixel_size = 0.004
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.modulate = Color("f0e6d0")
	_label.outline_size = 8
	_label.outline_modulate = Color("1a120e")
	_label.no_depth_test = true
	add_child(_label)
	_mine_ring = MeshInstance3D.new()
	_mine_ring.name = "MineRing"
	_mine_ring.mesh = GutterLooks.cyl(0.28, 0.04, 14)
	_mine_ring.material_override = GutterLooks.mat(Color("c4e08a"), 0.35, 0.0, Color("c4e08a"), 2.4)
	_mine_ring.position = Vector3(0, 0.03, 0)
	_mine_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mine_ring.visible = false
	add_child(_mine_ring)
	_mine_light = OmniLight3D.new()
	_mine_light.light_color = Color("c4e08a")
	_mine_light.light_energy = 1.35
	_mine_light.omni_range = 2.4
	_mine_light.position = Vector3(0, 0.55, 0)
	_mine_light.visible = false
	_mine_light.shadow_enabled = false
	add_child(_mine_light)


func configure(data: Dictionary, number: int, lane_offset: float) -> void:
	snail_id = number - 1
	chicken_id = str(data.get("id", "npc_%d" % snail_id))
	owner_id = int(data.get("owner_id", 0))
	grade = int(data.get("grade", 0))
	sex = int(data.get("sex", ChickenStock.Sex.HEN))
	display_name = str(data.get("name", "Chicken"))
	flavor = str(data.get("flavor", ""))
	var shell_value: Variant = data.get("shell", Color("6b8f3a"))
	if shell_value is String:
		shell_color = Color(str(shell_value))
	elif shell_value is Color:
		shell_color = shell_value
	var arch_value: Variant = data.get("archetype", Archetype.STEADY)
	if arch_value is int:
		archetype = arch_value as Archetype
	else:
		archetype = arch_value as Archetype
	form = float(data.get("form", 1.0))
	odds = data.get("odds", Vector2i(3, 1))
	hint = _hint_for(archetype)
	mood = str(data.get("mood", "Unreadable."))
	hunger = float(data.get("hunger", 80.0))
	traits = ChickenStock.traits_from(data.get("traits", []))
	crop_boost = 0.0
	fried = false
	groove = clampf(lane_offset, 0.05, 0.95)
	height = 0.0
	height_vel = 0.0
	squish = 1.0
	climb_timer = 0.0
	distance = 0.0
	racing = false
	finished = false
	finish_time = 0.0
	place = 0
	vel = 0.0
	bump_along = 0.0
	bump_lat = 0.0
	freeze_left = 0.0
	freeze_lock = 0.0
	zone_hit = false
	chaos_tag = ""
	chaos_beat = ChaosBeat.NONE
	_chaos_t = 0.0
	_chaos_dur = 0.0
	_chaos_cd = randf_range(1.8, 4.2)
	in_yard = false
	_yard_act = YardAct.IDLE
	_startle_cd = randf_range(0.4, 1.6)
	told_rail = false
	told_climb = false
	told_cut = false
	told_slip = false
	_crawl = Crawl.REST
	_crawl_t = randf_range(0.0, 0.4)
	_rest_dur = _rest_for(0.0)
	_sweat = null
	for child in _model.get_children():
		child.queue_free()
	GutterLooks.build_chicken(_model, shell_color, number, ChickenStock.is_rooster(data))
	_bind_rig(true)
	_ensure_run_fx()
	_refresh_owned_nametag()
	_refresh_mine_mark()
	reset_pose()
	leave_track_follow()
	net_smooth.clear()
	visible = true


func set_nametag(text: String) -> void:
	if text.is_empty():
		return
	display_name = text
	_refresh_owned_nametag()


func is_local_entry() -> bool:
	return owner_id == NetPlay.local_id() and not chicken_id.begins_with("npc_")


func owned_nametag() -> String:
	if is_local_entry():
		return "%s  ·  YOURS" % display_name
	return display_name


func has_mine_mark() -> bool:
	return _mine_ring != null and _mine_ring.visible


func release_to_yard(amin: Vector3, amax: Vector3, at: Vector3) -> void:
	in_yard = true
	racing = false
	fried = false
	leave_track_follow()
	yard_min = amin
	yard_max = amax
	add_to_group("yard_chicken")
	global_position = _clamp_yard(at)
	rotation = Vector3(0.0, randf() * TAU, 0.0)
	_refresh_owned_nametag()
	_refresh_mine_mark()
	_hide_race_number()
	_startle_cd = randf_range(0.2, 1.4)
	_pick_yard_act(true)


func leave_yard() -> void:
	in_yard = false
	_yard_act = YardAct.IDLE
	_yard_speed = 0.0
	if is_in_group("yard_chicken"):
		remove_from_group("yard_chicken")


func _hide_race_number() -> void:
	if _model == null:
		return
	for child in _model.get_children():
		if child is Label3D:
			(child as Label3D).visible = false


func make_fried() -> void:
	fried = true
	racing = false
	leave_yard()
	_set_run_fx(false)
	_sweat = null
	shell_color = Color("c47828")
	for child in _model.get_children():
		child.queue_free()
	GutterLooks.build_fried_chicken(_model)
	_bind_rig(true)
	if _label:
		_label.text = "CRISPY"
		_label.modulate = Color("e8a028")


func kick_off() -> void:
	reset_pose()
	chaos_beat = ChaosBeat.NONE
	_chaos_cd = randf_range(1.6, 3.8)
	freeze_left = 0.0
	freeze_lock = 0.0
	zone_hit = false
	chaos_tag = ""
	crop_boost = 0.0
	bump_along = 0.0
	bump_lat = 0.0
	told_rail = false
	told_climb = false
	told_cut = false
	told_slip = false
	_squawk_cd = 0.05 + float(snail_id) * 0.08
	_begin_slide(0.0)
	_set_run_fx(true)


func reset_pose() -> void:
	if _model == null:
		return
	_model.position = Vector3.ZERO
	_model.rotation = Vector3.ZERO
	_model.scale = Vector3.ONE
	_gait_move = 0.0
	_shown_vel = 0.0
	_bind_rig()
	if _legs:
		for child in _legs.get_children():
			if child is Node3D:
				(child as Node3D).rotation = Vector3.ZERO
	if _wings:
		for child in _wings.get_children():
			if child is Node3D:
				(child as Node3D).rotation = Vector3.ZERO
	if _head:
		_head.rotation = Vector3.ZERO
		_head.position = _head_rest if _head_rest != Vector3.ZERO else _head.position
	if _tail:
		_tail.rotation = Vector3.ZERO
	_set_run_fx(false)


func leave_track_follow() -> void:
	_have_track_target = false
	net_smooth.clear()


func push_net_track() -> void:
	var last := net_smooth.latest()
	if not last.is_empty() and absf(distance - float(last.get("distance", distance))) > 2.4:
		net_smooth.clear()
	var along := 0.0
	if racing and not finished:
		along = vel * line_speed() + bump_along
	net_smooth.push({
		"distance": distance,
		"groove": groove,
		"height": height,
		"vel": vel,
		"along": along,
	})


func sample_net_track() -> Dictionary:
	return net_smooth.sample()


func decay_bump(delta: float) -> void:
	var keep := exp(-delta * 6.5)
	bump_along *= keep
	bump_lat *= keep
	if absf(bump_along) < 0.01:
		bump_along = 0.0
	if absf(bump_lat) < 0.01:
		bump_lat = 0.0
	bump_along = clampf(bump_along, -1.55, 1.55)
	bump_lat = clampf(bump_lat, -1.8, 1.8)


func hint_visual_speed(v: float) -> void:
	_shown_vel = v


func set_track_pose(origin: Vector3, yaw: float, snap: bool = false) -> void:
	_track_target = origin
	_track_yaw = yaw
	_have_track_target = true
	if snap or global_position.distance_to(origin) > 2.4:
		global_position = origin
		rotation = Vector3(0.0, yaw, 0.0)


func _follow_track(delta: float) -> void:
	if not _have_track_target:
		return
	# Snappy follow so the pack reads as running the tangent, not sliding behind it.
	var follow := 1.0 - exp(-delta * 16.0)
	var turn := 1.0 - exp(-delta * 14.0)
	global_position = global_position.lerp(_track_target, follow)
	rotation.y = lerp_angle(rotation.y, _track_yaw, turn)
	rotation.x = 0.0
	rotation.z = 0.0


func tick_crawl(delta: float) -> void:
	if freeze_lock > 0.0:
		freeze_lock = maxf(freeze_lock - delta, 0.0)
	if not racing or finished:
		vel = move_toward(vel, 0.0, delta * 4.5)
		height_vel -= 8.0 * delta
		height = maxf(height + height_vel * delta, 0.0)
		if height <= 0.0:
			height_vel = 0.0
		squish = move_toward(squish, 1.0, delta * 2.2)
		freeze_left = 0.0
		return
	var frac := clampf(distance / maxf(lap_length, 0.001), 0.0, 1.0)
	if archetype == Archetype.CHAOS:
		_tick_chaos(delta)
	if freeze_left > 0.0:
		freeze_left -= delta
		vel = 0.0
		_crawl = Crawl.REST
		climb_timer = maxf(climb_timer - delta, 0.0)
		squish = move_toward(squish, 1.0, delta * 1.8)
		if freeze_left <= 0.0:
			freeze_left = 0.0
			freeze_lock = RaceChaos.FREEZE_LOCK
			if has_trait(ChickenStock.Trait.CORN_FIEND):
				crop_boost = 0.9
		return
	if chaos_beat == ChaosBeat.PEBBLE:
		vel = 0.0
		_crawl = Crawl.REST
		climb_timer = maxf(climb_timer - delta, 0.0)
		squish = move_toward(squish, 1.0, delta * 1.8)
		return
	match _crawl:
		Crawl.REST:
			_crawl_t += delta
			vel = move_toward(vel, 0.0, delta * 4.6)
			if _crawl_t >= _rest_dur:
				_begin_slide(frac)
		Crawl.SLIDE:
			_crawl_t += delta
			var u := clampf(_crawl_t / maxf(_slide_dur, 0.05), 0.0, 1.0)
			var want := _peak * sin(u * PI)
			vel = lerpf(vel, want, 1.0 - exp(-delta * 9.0))
			if u >= 1.0:
				_begin_rest(frac)
	climb_timer = maxf(climb_timer - delta, 0.0)
	squish = move_toward(squish, 1.0, delta * 1.8)
	if crop_boost > 0.0:
		crop_boost = maxf(crop_boost - delta, 0.0)


func line_speed() -> float:
	var line := lerpf(1.36, 0.74, clampf(groove, 0.0, 1.0))
	if height > 0.07:
		line *= 0.86
	if squish < 0.9:
		line *= 0.78
	var manager := get_tree().get_first_node_in_group("race_manager") as RaceManager
	if manager == null:
		return line
	var extras := {
		"skate": has_trait(ChickenStock.Trait.GREASE_LEGS),
		"calm": has_trait(ChickenStock.Trait.HAWK_BLIND),
		"hog": has_trait(ChickenStock.Trait.CROWD_HOG),
		"dust_lungs": has_trait(ChickenStock.Trait.DUST_LUNGS),
	}
	line *= RaceChaos.line_mult(
		manager.card_condition,
		manager.live_event,
		groove,
		height,
		int(archetype),
		distance,
		manager.track_length,
		manager.event_at,
		extras
	)
	if has_trait(ChickenStock.Trait.RAIL_RAT):
		line *= 1.10 if groove < 0.22 else (0.86 if groove > 0.55 else 1.0)
	if has_trait(ChickenStock.Trait.QUICK_SCRATCH) and distance / maxf(lap_length, 0.001) < 0.2:
		line *= 1.10
	if has_trait(ChickenStock.Trait.FRYER_FEAR) and _is_trailing(manager):
		line *= 1.09
	if has_trait(ChickenStock.Trait.SPITE) and _rival_ahead(manager):
		line *= 1.08
	if crop_boost > 0.0:
		line *= 1.16
	return line


func desired_groove() -> float:
	var frac := clampf(distance / maxf(lap_length, 0.001), 0.0, 1.0)
	var groove_want := 0.2
	match archetype:
		Archetype.SPRINTER:
			groove_want = 0.06
		Archetype.STEADY:
			groove_want = 0.18 + sin(_wag * 0.35) * 0.05
		Archetype.CHAOS:
			if chaos_beat == ChaosBeat.DART:
				groove_want = 0.84
			else:
				groove_want = 0.14
		Archetype.LATE:
			groove_want = 0.78 if frac < 0.5 else 0.05
	if has_trait(ChickenStock.Trait.RAIL_RAT):
		groove_want = minf(groove_want, 0.10)
	if has_trait(ChickenStock.Trait.ONE_EYE):
		groove_want = clampf(groove_want + sin(_wag * 2.4) * 0.14, 0.05, 0.92)
	return groove_want


func steer_rate() -> float:
	var rate := 0.22
	match archetype:
		Archetype.SPRINTER:
			rate = 0.42
		Archetype.STEADY:
			rate = 0.16
		Archetype.CHAOS:
			rate = 0.55
		Archetype.LATE:
			rate = 0.12 if distance / maxf(lap_length, 1.0) < 0.5 else 0.5
	if _crawl == Crawl.REST:
		rate *= 0.4
	if has_trait(ChickenStock.Trait.RAIL_RAT):
		rate *= 1.28
	if has_trait(ChickenStock.Trait.ONE_EYE):
		rate *= 0.52
	return rate


func wants_to_climb() -> bool:
	if has_trait(ChickenStock.Trait.MEAN_BEAK):
		return true
	match archetype:
		Archetype.SPRINTER:
			return true
		Archetype.STEADY:
			return climb_timer > 0.0 or randf() < 1.4 * get_process_delta_time()
		Archetype.CHAOS:
			return chaos_beat == ChaosBeat.LUNGE or climb_timer > 0.0
		Archetype.LATE:
			return distance / maxf(lap_length, 1.0) > 0.42
	return false


func _process(delta: float) -> void:
	_wag += delta
	if _model == null:
		return
	if in_yard and visible and not racing and not fried:
		leave_track_follow()
		_set_run_fx(false)
		_tick_yard(delta)
		return
	if _have_track_target and not (NetPlay.is_client() and not net_smooth.is_empty()):
		_follow_track(delta)
	if not racing:
		_gait_move = move_toward(_gait_move, 0.0, delta * 5.0)
		_shown_vel = move_toward(_shown_vel, 0.0, delta * 5.0)
		_set_run_fx(false)
		if Game.phase == Game.Phase.OPEN:
			_paddock_act(delta)
			_animate_legs(false)
		elif Game.phase == Game.Phase.COUNTDOWN:
			reset_pose()
		else:
			_idle_on_track()
			_animate_legs(false)
		if _label and not fried and _label.text.contains("\n"):
			_refresh_owned_nametag()
		_refresh_mine_mark()
		return
	if not (NetPlay.is_client() and not net_smooth.is_empty()):
		_shown_vel = move_toward(_shown_vel, vel, delta * 8.0)
	var halted := chaos_beat == ChaosBeat.PEBBLE or freeze_left > 0.0 or chaos_tag == "SPOOKED"
	# Keep a sprint floor so REST beats still read as rushing, not a halt-and-peck.
	var want_move := 0.0 if halted else maxf(0.78, clampf(_shown_vel / 1.35, 0.78, 1.0))
	_gait_move = move_toward(_gait_move, want_move, delta * 7.0)
	_pose_sprint(delta, halted)
	_set_run_fx(not halted and _gait_move > 0.45)
	_tick_squawk(delta, not halted and _gait_move > 0.45)
	_refresh_chaos_nametag()
	_refresh_mine_mark()


func _bind_rig(capture_rest: bool = false) -> void:
	if _model == null:
		return
	_legs = _model.get_node_or_null("Legs")
	_head = _model.get_node_or_null("Head") as Node3D
	_wings = _model.get_node_or_null("Wings")
	_tail = _model.get_node_or_null("Tail") as Node3D
	if _head and (capture_rest or _head_rest == Vector3.ZERO):
		_head_rest = _head.position


func _ensure_run_fx() -> void:
	if _model == null:
		return
	if _sweat != null and is_instance_valid(_sweat):
		_sweat.queue_free()
	_sweat = CPUParticles3D.new()
	_sweat.name = "Sweat"
	_sweat.emitting = false
	_sweat.amount = 14
	_sweat.lifetime = 0.55
	_sweat.explosiveness = 0.05
	_sweat.randomness = 0.45
	_sweat.local_coords = false
	_sweat.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_sweat.emission_sphere_radius = 0.07
	_sweat.direction = Vector3(0.0, 0.95, 1.15)
	_sweat.spread = 32.0
	_sweat.gravity = Vector3(0.0, -7.2, 0.0)
	_sweat.initial_velocity_min = 1.15
	_sweat.initial_velocity_max = 2.35
	_sweat.scale_amount_min = 0.7
	_sweat.scale_amount_max = 1.35
	var drop := SphereMesh.new()
	drop.radius = 0.028
	drop.height = 0.056
	drop.radial_segments = 6
	drop.rings = 3
	_sweat.mesh = drop
	var bead := StandardMaterial3D.new()
	bead.albedo_color = Color(0.96, 0.93, 0.72, 0.88)
	bead.emission_enabled = true
	bead.emission = Color(0.95, 0.9, 0.55)
	bead.emission_energy_multiplier = 1.8
	bead.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bead.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bead.cull_mode = BaseMaterial3D.CULL_DISABLED
	_sweat.material_override = bead
	_sweat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sweat.position = Vector3(0.0, 0.40, -0.08)
	_model.add_child(_sweat)
	if _voice == null:
		_voice = AudioStreamPlayer3D.new()
		_voice.name = "Squawk"
		_voice.bus = "Master"
		_voice.unit_size = 5.4
		_voice.max_distance = 28.0
		_voice.volume_db = -6.5
		_voice.attenuation_filter_cutoff_hz = 7000.0
		add_child(_voice)


func _set_run_fx(on: bool) -> void:
	if _sweat and is_instance_valid(_sweat):
		_sweat.emitting = on
	if not on and _voice and _voice.playing:
		_voice.stop()


func _tick_squawk(delta: float, rushing: bool) -> void:
	if _voice == null:
		return
	if not rushing:
		return
	_squawk_cd -= delta
	if _squawk_cd > 0.0:
		return
	_squawk_cd = randf_range(0.42, 1.15)
	_voice.stream = _make_squawk(snail_id * 17 + int(_wag * 10.0))
	_voice.pitch_scale = randf_range(0.92, 1.12)
	_voice.play()


func _make_squawk(seed: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed if seed != 0 else 1
	var rate := 22050
	var dur := rng.randf_range(0.09, 0.17)
	var nframes := int(rate * dur)
	var samples := PackedFloat32Array()
	samples.resize(nframes)
	var f0 := rng.randf_range(680.0, 1080.0)
	var f1 := f0 * rng.randf_range(1.38, 1.92)
	for i in nframes:
		var t := float(i) / float(rate)
		var u := t / dur
		var env := 1.0
		if u < 0.07:
			env = u / 0.07
		elif u > 0.52:
			env = maxf(1.0 - (u - 0.52) / 0.48, 0.0)
		var freq := lerpf(f1, f0, u)
		var vibr := 1.0 + 0.045 * sin(TAU * 36.0 * t)
		var tone := sin(TAU * freq * vibr * t)
		var harsh := sin(TAU * freq * 2.03 * t) * 0.3
		var noise := (rng.randf() * 2.0 - 1.0) * 0.14 * (1.0 - u)
		samples[i] = clampf((tone + harsh + noise) * env * 0.82, -1.0, 1.0)
	return _pcm16(samples, rate)


func _pcm16(samples: PackedFloat32Array, rate: int) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return stream


func _pose_sprint(delta: float, halted: bool) -> void:
	var move_w := _gait_move
	var flatten := 1.0
	if squish < 0.85:
		flatten = clampf(squish, 0.34, 1.0)
	if chaos_tag == "SPOOKED":
		flatten = minf(flatten, 0.42)
		move_w = 0.0
	if flatten < 0.999:
		_model.scale = Vector3(1.0 / maxf(flatten, 0.34), flatten, 1.15 / maxf(flatten, 0.5))
	else:
		_model.scale = Vector3.ONE
	var cadence := lerpf(12.0, 27.0, move_w)
	var gait := _wag * cadence
	var ease := 1.0 - exp(-delta * 10.0)
	# Node yaw already follows track tangent. Keep model yaw tiny so they don't wobble.
	var want_yaw := sin(gait) * 0.025 * move_w
	var want_pitch := -lerpf(0.12, 0.36, move_w) + clampf(height * 0.32, 0.0, 0.12)
	var want_roll := clampf((0.5 - groove) * 0.09, -0.11, 0.11)
	if chaos_tag == "GREASED":
		want_roll = sin(_wag * 11.0) * 0.55
		want_yaw += sin(_wag * 9.0) * 0.18
	if halted:
		want_pitch = 0.06
		want_yaw = 0.0
	_model.rotation.y = lerpf(_model.rotation.y, want_yaw, ease)
	_model.rotation.x = lerpf(_model.rotation.x, want_pitch, ease)
	_model.rotation.z = lerpf(_model.rotation.z, want_roll, ease)
	var bounce := 0.0
	if not halted:
		bounce = lerpf(0.014, 0.05, move_w) * absf(sin(gait))
	if chaos_tag == "SPOOKED":
		bounce = 0.0
	_model.position.x = 0.0
	_model.position.z = 0.0
	_model.position.y = lerpf(_model.position.y, bounce, 1.0 - exp(-delta * 16.0))
	_animate_sprint_rig(gait, move_w, halted)


func _animate_sprint_rig(gait: float, move_w: float, halted: bool) -> void:
	if _legs == null or _head == null:
		_bind_rig()
	if _legs:
		var amp := 0.12 if halted else lerpf(0.32, 0.95, move_w)
		for i in _legs.get_child_count():
			var leg := _legs.get_child(i) as Node3D
			if leg == null:
				continue
			leg.rotation.x = sin(gait + float(i) * PI) * amp
	if _wings:
		var flapping := height > 0.05
		for i in _wings.get_child_count():
			var wing := _wings.get_child(i) as Node3D
			if wing == null:
				continue
			var side := -1.0 if i == 0 else 1.0
			if flapping:
				var flap := _wag * 14.5
				wing.rotation = Vector3(0.12, 0.0, side * (0.22 + sin(flap) * 0.72))
			elif halted:
				wing.rotation = Vector3(0.06, 0.0, side * 0.14)
			else:
				var pump := sin(gait * 2.0) * 0.11 * move_w
				wing.rotation = Vector3(0.48 + pump, side * 0.06, side * (0.24 + pump * 0.35))
	if _head:
		if chaos_tag == "PECKING" or freeze_left > 0.0:
			_head.position = _head_rest
			_head.rotation.x = 0.45 + absf(sin(_wag * 14.0)) * 0.85
			_head.rotation.y = 0.0
			_head.rotation.z = 0.0
		elif halted:
			_head.position = _head_rest
			_head.rotation.x = 0.1
			_head.rotation.y = 0.0
			_head.rotation.z = 0.0
		else:
			_head.position = _head_rest + Vector3(0.0, -0.02 * move_w, -0.09 * move_w)
			_head.rotation.x = -lerpf(0.08, 0.22, move_w) + sin(gait * 2.0) * 0.045 * move_w
			_head.rotation.y = 0.0
			_head.rotation.z = 0.0
	if _tail:
		if halted:
			_tail.rotation = Vector3.ZERO
		else:
			_tail.rotation.x = lerpf(0.22, 0.58, move_w)
			_tail.rotation.y = sin(gait * 2.0) * 0.14 * move_w
			_tail.rotation.z = 0.0


func run_feel_snapshot() -> Dictionary:
	var head := _head
	if head == null and _model:
		head = _model.get_node_or_null("Head") as Node3D
	var leg0: Node3D = null
	if _legs and _legs.get_child_count() > 0:
		leg0 = _legs.get_child(0) as Node3D
	return {
		"gait": _gait_move,
		"body_pitch": _model.rotation.x if _model else 0.0,
		"body_yaw": _model.rotation.y if _model else 0.0,
		"head_pitch": head.rotation.x if head else 0.0,
		"head_z": head.position.z if head else 0.0,
		"leg_swing": absf(leg0.rotation.x) if leg0 else 0.0,
		"sweat": _sweat != null and is_instance_valid(_sweat) and _sweat.emitting,
		"voice": _voice != null,
		"squawking": _voice != null and _voice.playing,
		"racing": racing,
		"finished": finished,
		"halted": freeze_left > 0.0 or chaos_beat == ChaosBeat.PEBBLE or chaos_tag == "SPOOKED",
	}


func _animate_legs(moving: bool) -> void:
	if _legs == null:
		_bind_rig()
	var w := _gait_move if racing else (1.0 if moving else 0.0)
	if _legs:
		var gait := _wag * lerpf(2.1, 9.2, w)
		var amp := lerpf(0.10, 0.48, w)
		for i in _legs.get_child_count():
			var leg := _legs.get_child(i) as Node3D
			if leg == null:
				continue
			leg.rotation.x = sin(gait + float(i) * PI) * amp
	if _wings == null and _model:
		_wings = _model.get_node_or_null("Wings")
	if _wings:
		var flapping := w > 0.2 or height > 0.05
		var flap := _wag * (10.5 if flapping else 2.6)
		var wing_amp := 0.42 if flapping else 0.10
		for i in _wings.get_child_count():
			var wing := _wings.get_child(i) as Node3D
			if wing == null:
				continue
			var side := -1.0 if i == 0 else 1.0
			wing.rotation.z = side * (0.14 + sin(flap) * wing_amp)
	if _head == null and _model:
		_head = _model.get_node_or_null("Head") as Node3D
	if _head:
		var peck := 0.0
		if chaos_tag == "PECKING" or freeze_left > 0.0:
			peck = 0.45 + absf(sin(_wag * 14.0)) * 0.85
		elif w < 0.25:
			peck = maxf(sin(_wag * 4.2), 0.0) * 0.42
		_head.rotation.x = peck
	if _tail == null and _model:
		_tail = _model.get_node_or_null("Tail") as Node3D
	if _tail:
		_tail.rotation.y = sin(_wag * lerpf(1.5, 6.4, w)) * lerpf(0.07, 0.16, w)


func _refresh_owned_nametag() -> void:
	if _label == null or fried:
		return
	_label.text = owned_nametag()
	_label.modulate = Color("c4e08a") if is_local_entry() else Color("f0e6d0")
	_label.font_size = 28 if is_local_entry() else 22
	_label.outline_size = 10 if is_local_entry() else 8


func _refresh_mine_mark() -> void:
	var show := is_local_entry() and not fried and not in_yard and (
		racing or Game.phase == Game.Phase.RACE or Game.phase == Game.Phase.COUNTDOWN or Game.phase == Game.Phase.RESULTS
	)
	if _mine_ring:
		_mine_ring.visible = show
		if show:
			var pulse := 1.0 + 0.12 * sin(_wag * 6.4)
			_mine_ring.scale = Vector3(pulse, 1.0, pulse)
	if _mine_light:
		_mine_light.visible = show
		if show:
			_mine_light.light_energy = 1.15 + 0.35 * absf(sin(_wag * 6.4))


func _refresh_chaos_nametag() -> void:
	if _label == null or fried or not racing:
		return
	var tag := race_tag()
	var mine := is_local_entry()
	if tag.is_empty() or tag == "IN":
		_refresh_owned_nametag()
		if tag == "IN":
			_label.text = "%s\nIN" % owned_nametag()
			_label.font_size = 26 if mine else 22
		return
	_label.text = "%s\n%s" % [owned_nametag(), tag]
	_label.font_size = 28 if mine else 26
	match tag:
		"PECKING":
			_label.modulate = Color("e8c03a")
		"GREASED":
			_label.modulate = Color("8a6a28")
		"SPOOKED":
			_label.modulate = Color("e07070")
		"PINNED":
			_label.modulate = Color("d08090")
		_:
			_label.modulate = Color("c4e08a") if mine else Color("f0e6d0")


func race_tag() -> String:
	if fried:
		return "FRIED"
	if finished:
		return "IN"
	if not chaos_tag.is_empty():
		return chaos_tag
	if freeze_left > 0.0:
		return "PECKING"
	if squish < 0.78:
		return "PINNED"
	if height > 0.06:
		return "FLAPPING"
	if groove < 0.18:
		return "RAIL"
	if groove > 0.72:
		return "WIDE"
	return ""


func can_freeze() -> bool:
	return freeze_left <= 0.0 and freeze_lock <= 0.0 and chaos_beat != ChaosBeat.PEBBLE


func has_trait(trait_id: int) -> bool:
	return traits.has(trait_id)


func _is_trailing(manager: RaceManager) -> bool:
	var behind := 0
	for other in manager.field:
		if other == self or other.finished:
			continue
		if other.distance < distance:
			behind += 1
	return behind <= 1


func _rival_ahead(manager: RaceManager) -> bool:
	for other in manager.field:
		if other == self or other.finished:
			continue
		var gap := other.distance - distance
		if gap > 0.02 and gap < 1.15:
			return true
	return false


func begin_freeze(duration: float) -> bool:
	if not can_freeze() or duration <= 0.0:
		return false
	freeze_left = duration
	_crawl = Crawl.REST
	vel = 0.0
	return true


func odds_text() -> String:
	return "%d/%d" % [odds.x, odds.y]


func grade_name() -> String:
	return ChickenStock.grade_name(grade)


func to_field_payload() -> Dictionary:
	return {
		"id": chicken_id,
		"name": display_name,
		"shell": shell_color.to_html(false),
		"archetype": int(archetype),
		"grade": grade,
		"sex": sex,
		"form": form,
		"odds_x": odds.x,
		"odds_y": odds.y,
		"mood": mood,
		"flavor": flavor,
		"hunger": hunger,
		"traits": traits.duplicate(),
		"owner_id": owner_id,
		"groove": groove,
	}


func archetype_name() -> String:
	return ChickenStock.archetype_name(int(archetype))


func archetype_line() -> String:
	return ChickenStock.archetype_line(int(archetype))


func quirk_names() -> PackedStringArray:
	return ChickenStock.quirk_names(self)


func quirk_line() -> String:
	return ChickenStock.quirk_line(self)


func bet_card_title() -> String:
	var bits: PackedStringArray = [archetype_name()]
	bits.append_array(quirk_names())
	return "  ·  ".join(bits)


func card_tell() -> String:
	var event := RaceChaos.LiveEvent.NONE
	var manager := get_tree().get_first_node_in_group("race_manager")
	if manager:
		event = int(manager.live_event)
	return RaceChaos.card_tell(int(archetype), traits, Game.card_condition(), event)


func bet_card_text() -> String:
	var tell := card_tell()
	var headline := "%s  ·  %s" % [display_name, bet_card_title()]
	if tell.is_empty():
		return headline
	return "%s\n%s" % [headline, tell]


func _begin_slide(frac: float) -> void:
	_crawl = Crawl.SLIDE
	_crawl_t = 0.0
	_peak = _peak_for(frac)
	_slide_dur = _slide_for(frac)


func _begin_rest(frac: float) -> void:
	_crawl = Crawl.REST
	_crawl_t = 0.0
	_rest_dur = _rest_for(frac)


func _peak_for(frac: float) -> float:
	var p := 1.65 * form
	match archetype:
		Archetype.SPRINTER:
			p *= 1.35 if frac < 0.4 else 0.82
		Archetype.STEADY:
			p *= 1.02
		Archetype.CHAOS:
			p *= randf_range(0.7, 1.45)
		Archetype.LATE:
			p *= 0.72 if frac < 0.55 else 1.38
	if has_trait(ChickenStock.Trait.QUICK_SCRATCH) and frac < 0.22:
		p *= 1.16
	if has_trait(ChickenStock.Trait.NAPPER):
		p *= 1.10
	if crop_boost > 0.0:
		p *= 1.12
	return maxf(p, 0.7)


func _slide_for(frac: float) -> float:
	match archetype:
		Archetype.SPRINTER:
			return randf_range(1.05, 1.55) if frac < 0.4 else randf_range(0.7, 1.1)
		Archetype.STEADY:
			return randf_range(0.95, 1.25)
		Archetype.CHAOS:
			return randf_range(0.45, 1.7)
		Archetype.LATE:
			return randf_range(0.55, 0.9) if frac < 0.55 else randf_range(1.1, 1.6)
	return 1.0


func _rest_for(frac: float) -> float:
	var rest := 0.28
	match archetype:
		Archetype.SPRINTER:
			rest = randf_range(0.12, 0.24) if frac < 0.4 else randf_range(0.4, 0.7)
		Archetype.STEADY:
			rest = randf_range(0.18, 0.32)
		Archetype.CHAOS:
			rest = randf_range(0.1, 0.7)
		Archetype.LATE:
			rest = randf_range(0.45, 0.85) if frac < 0.55 else randf_range(0.12, 0.28)
	if has_trait(ChickenStock.Trait.NAPPER):
		rest *= 1.45
	if has_trait(ChickenStock.Trait.QUICK_SCRATCH) and frac < 0.22:
		rest *= 0.72
	return rest


func _idle_on_track() -> void:
	_model.scale = Vector3.ONE
	_model.rotation = Vector3(0.0, sin(_wag * 1.1) * 0.04, 0.0)
	_model.position = Vector3(0.0, 0.012 * sin(_wag * 1.5), 0.0)


func _paddock_act(delta: float) -> void:
	match archetype:
		Archetype.SPRINTER:
			var bump := absf(sin(_wag * 4.2))
			_model.position = Vector3(0.0, bump * 0.03, -0.08 * bump)
			_model.rotation = Vector3(0.25 * bump, 0.0, 0.0)
			_model.scale = Vector3.ONE
		Archetype.STEADY:
			var peck := maxf(sin(_wag * 3.1), 0.0)
			_model.position = Vector3.ZERO
			_model.rotation = Vector3(0.35 * peck, 0.0, 0.0)
			_model.scale = Vector3.ONE
		Archetype.CHAOS:
			_model.rotation.y += delta * 3.4
			_model.position = Vector3(sin(_wag * 6.0) * 0.05, absf(sin(_wag * 8.0)) * 0.04, cos(_wag * 5.0) * 0.05)
			_model.scale = Vector3.ONE
		Archetype.LATE:
			var twitch := 1.0 if fmod(_wag, 5.2) < 0.18 else 0.0
			_model.position = Vector3(0.0, twitch * 0.02, 0.0)
			_model.rotation = Vector3(0.18, 0.0, 0.1)
			_model.scale = Vector3(1.05, 0.9, 1.05)


func _tick_yard(delta: float) -> void:
	_startle_cd = maxf(_startle_cd - delta, 0.0)
	_yard_t += delta
	_maybe_startle_from_player()
	match _yard_act:
		YardAct.WANDER, YardAct.STARTLE, YardAct.CHASE:
			_yard_move(delta)
		YardAct.EAT, YardAct.DRINK:
			_yard_approach(delta, 0.55)
		_:
			_yard_speed = move_toward(_yard_speed, 0.0, delta * 4.0)
	_separate_yard(delta)
	global_position = _clamp_yard(global_position)
	if _yard_t >= _yard_dur:
		_pick_yard_act(false)
	_yard_pose(delta)


func _pick_yard_act(fresh: bool) -> void:
	_yard_t = 0.0
	var owned := Game.find_chicken(chicken_id)
	if not owned.is_empty() and Game.yard_feed > 1.0 and float(owned.get("hunger", 70.0)) < 48.0 and randf() < 0.62:
		_begin_yard_eat()
		return
	var roll := randf()
	if fresh:
		roll = randf_range(0.0, 0.45)
	match archetype:
		Archetype.SPRINTER:
			if roll < 0.42:
				_begin_yard_wander(randf_range(0.9, 1.35))
			elif roll < 0.62:
				_begin_yard_simple(YardAct.PECK, randf_range(0.6, 1.3))
			elif roll < 0.78:
				_begin_yard_eat()
			elif roll < 0.9:
				_begin_yard_simple(YardAct.SCRATCH, randf_range(0.8, 1.6))
			else:
				_begin_yard_simple(YardAct.LOOK, randf_range(0.5, 1.1))
		Archetype.STEADY:
			if roll < 0.22:
				_begin_yard_wander(randf_range(0.45, 0.75))
			elif roll < 0.48:
				_begin_yard_simple(YardAct.PECK, randf_range(1.1, 2.4))
			elif roll < 0.7:
				_begin_yard_eat()
			elif roll < 0.84:
				_begin_yard_simple(YardAct.SCRATCH, randf_range(1.0, 2.0))
			elif roll < 0.93:
				_begin_yard_drink()
			else:
				_begin_yard_simple(YardAct.IDLE, randf_range(1.0, 2.2))
		Archetype.CHAOS:
			if roll < 0.28:
				_begin_yard_wander(randf_range(1.0, 1.55))
			elif roll < 0.42:
				_begin_yard_chase()
			elif roll < 0.58:
				_begin_yard_simple(YardAct.STARTLE, randf_range(0.45, 0.8))
				_yard_target = _clamp_yard(global_position + Vector3(randf_range(-2.2, 2.2), 0.0, randf_range(-2.2, 2.2)))
			elif roll < 0.74:
				_begin_yard_simple(YardAct.PECK, randf_range(0.4, 1.0))
			elif roll < 0.88:
				_begin_yard_eat()
			else:
				_begin_yard_simple(YardAct.LOOK, randf_range(0.3, 0.8))
		Archetype.LATE:
			if roll < 0.16:
				_begin_yard_wander(randf_range(0.35, 0.6))
			elif roll < 0.34:
				_begin_yard_simple(YardAct.IDLE, randf_range(1.6, 3.2))
			elif roll < 0.52:
				_begin_yard_simple(YardAct.DUST, randf_range(2.0, 3.6))
			elif roll < 0.72:
				_begin_yard_simple(YardAct.PECK, randf_range(1.2, 2.6))
			elif roll < 0.88:
				_begin_yard_eat()
			else:
				_begin_yard_drink()
		_:
			_begin_yard_simple(YardAct.PECK, 1.2)


func _begin_yard_simple(act: YardAct, dur: float) -> void:
	_yard_act = act
	_yard_dur = dur
	_yard_t = 0.0
	_yard_speed = 0.0


func _begin_yard_wander(speed: float) -> void:
	_yard_act = YardAct.WANDER
	_yard_dur = randf_range(1.6, 4.2)
	_yard_t = 0.0
	_yard_speed = speed
	_yard_target = _clamp_yard(Vector3(
		randf_range(yard_min.x, yard_max.x),
		yard_min.y,
		randf_range(yard_min.z, yard_max.z)
	))


func _begin_yard_eat() -> void:
	_yard_act = YardAct.EAT
	_yard_dur = randf_range(2.2, 4.8)
	_yard_t = 0.0
	_eat_at = _nearest_prop("coop_feed", _random_yard_point())
	_yard_target = _eat_at
	_yard_speed = 0.7


func _begin_yard_drink() -> void:
	_yard_act = YardAct.DRINK
	_yard_dur = randf_range(1.4, 2.8)
	_yard_t = 0.0
	_eat_at = _nearest_prop("coop_water", _random_yard_point())
	_yard_target = _eat_at
	_yard_speed = 0.65


func _begin_yard_chase() -> void:
	_yard_act = YardAct.CHASE
	_yard_dur = randf_range(1.1, 2.2)
	_yard_t = 0.0
	_yard_speed = randf_range(1.1, 1.6)
	var other := _other_yard_bird()
	if other:
		_yard_target = other.global_position
	else:
		_begin_yard_wander(1.1)


func _yard_move(delta: float) -> void:
	if _yard_act == YardAct.CHASE:
		var other := _other_yard_bird()
		if other:
			_yard_target = other.global_position
	var to := _yard_target - global_position
	to.y = 0.0
	var dist := to.length()
	if dist < 0.12:
		if _yard_act == YardAct.WANDER:
			_begin_yard_simple(YardAct.PECK, randf_range(0.5, 1.2))
		elif _yard_act == YardAct.CHASE:
			_begin_yard_simple(YardAct.PECK, randf_range(0.4, 0.8))
		return
	var dir := to / dist
	var spd := _yard_speed
	if _yard_act == YardAct.STARTLE:
		spd = 2.3
	global_position += dir * spd * delta
	_face_dir(dir, delta * 8.0)


func _yard_approach(delta: float, speed: float) -> void:
	var to := _yard_target - global_position
	to.y = 0.0
	var dist := to.length()
	if dist < 0.22:
		_yard_speed = 0.0
		if _yard_act == YardAct.EAT and not chicken_id.is_empty():
			Game.nibble_yard(chicken_id, delta * 9.0)
		return
	var dir := to / dist
	global_position += dir * speed * delta
	_face_dir(dir, delta * 6.0)


func _face_dir(dir: Vector3, weight: float) -> void:
	if dir.length_squared() < 0.0001:
		return
	var target_yaw := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(weight, 0.0, 1.0))


func _maybe_startle_from_player() -> void:
	if _startle_cd > 0.0 or _yard_act == YardAct.STARTLE:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	var away: Vector3 = global_position - player.global_position
	away.y = 0.0
	if away.length() > 1.35:
		return
	if randf() > 0.35:
		_startle_cd = 0.8
		return
	_yard_act = YardAct.STARTLE
	_yard_t = 0.0
	_yard_dur = randf_range(0.45, 0.85)
	_yard_speed = 2.4
	if away.length_squared() < 0.0001:
		away = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	_yard_target = _clamp_yard(global_position + away.normalized() * randf_range(1.4, 2.4))
	_startle_cd = randf_range(2.5, 5.0)


func _separate_yard(delta: float) -> void:
	for node in get_tree().get_nodes_in_group("yard_chicken"):
		if node == self or not (node is Node3D):
			continue
		var other := node as Node3D
		var delta_pos: Vector3 = global_position - other.global_position
		delta_pos.y = 0.0
		var d := delta_pos.length()
		if d < 0.08 or d > 0.42:
			continue
		global_position += delta_pos.normalized() * (0.42 - d) * 1.8 * delta


func _yard_pose(delta: float) -> void:
	var moving := _yard_speed > 0.18 or _yard_act == YardAct.WANDER or _yard_act == YardAct.STARTLE or _yard_act == YardAct.CHASE
	if _yard_act == YardAct.EAT or _yard_act == YardAct.DRINK:
		var dist := Vector3(global_position.x - _yard_target.x, 0.0, global_position.z - _yard_target.z).length()
		moving = dist > 0.24
	var peck := 0.0
	var bob := 0.012 * absf(sin(_wag * 2.0))
	var squish_y := 1.0
	match _yard_act:
		YardAct.PECK, YardAct.EAT, YardAct.DRINK:
			if not moving:
				peck = 0.35 + absf(sin(_wag * 9.0)) * 0.7
				bob = absf(sin(_wag * 9.0)) * 0.02
		YardAct.SCRATCH:
			peck = 0.55 + absf(sin(_wag * 11.0)) * 0.35
			bob = absf(sin(_wag * 11.0)) * 0.03
			rotation.y += sin(_wag * 6.0) * 0.4 * delta
		YardAct.DUST:
			peck = 0.85
			squish_y = 0.72 + absf(sin(_wag * 7.0)) * 0.08
			bob = 0.0
			rotation.y += sin(_wag * 5.0) * 1.2 * delta
		YardAct.LOOK:
			rotation.y += sin(_wag * 1.4) * 1.1 * delta
		YardAct.IDLE:
			peck = maxf(sin(_wag * 2.2), 0.0) * 0.2
		YardAct.STARTLE:
			moving = true
			bob = 0.05
	_model.scale = Vector3(1.0, squish_y, 1.0)
	_model.rotation = Vector3(0.0, sin(_wag * (2.4 if moving else 1.4)) * (0.1 if moving else 0.05), 0.0)
	_model.position = Vector3(0.0, bob, 0.0)
	_animate_legs(moving or _yard_act == YardAct.SCRATCH)
	var head := _model.get_node_or_null("Head") as Node3D
	if head:
		head.rotation.x = peck
	var wings := _model.get_node_or_null("Wings")
	if wings and _yard_act == YardAct.STARTLE:
		for i in wings.get_child_count():
			var wing := wings.get_child(i) as Node3D
			if wing:
				var side := -1.0 if i == 0 else 1.0
				wing.rotation.z = side * (0.4 + sin(_wag * 22.0) * 0.8)


func _clamp_yard(at: Vector3) -> Vector3:
	return Vector3(
		clampf(at.x, yard_min.x, yard_max.x),
		yard_min.y,
		clampf(at.z, yard_min.z, yard_max.z)
	)


func _random_yard_point() -> Vector3:
	return Vector3(
		randf_range(yard_min.x, yard_max.x),
		yard_min.y,
		randf_range(yard_min.z, yard_max.z)
	)


func _nearest_prop(group_name: String, fallback: Vector3) -> Vector3:
	var best := fallback
	var best_d := INF
	for node in get_tree().get_nodes_in_group(group_name):
		if node is Node3D:
			var d: float = global_position.distance_to((node as Node3D).global_position)
			if d < best_d:
				best_d = d
				best = (node as Node3D).global_position
	best.y = yard_min.y
	return best


func _other_yard_bird() -> Node3D:
	var options: Array[Node3D] = []
	for node in get_tree().get_nodes_in_group("yard_chicken"):
		if node != self and node is Node3D and (node as Node3D).visible:
			options.append(node)
	if options.is_empty():
		return null
	return options[randi() % options.size()]


func _tick_chaos(delta: float) -> void:
	if chaos_beat != ChaosBeat.NONE:
		_chaos_t += delta
		if _chaos_t >= _chaos_dur:
			if chaos_beat == ChaosBeat.PEBBLE:
				freeze_lock = maxf(freeze_lock, RaceChaos.FREEZE_LOCK)
			chaos_beat = ChaosBeat.NONE
			_chaos_cd = randf_range(2.6, 6.4)
		return
	_chaos_cd -= delta
	if _chaos_cd > 0.0:
		return
	var roll := randf()
	_chaos_t = 0.0
	if roll < 0.34:
		if has_trait(ChickenStock.Trait.STONE_EATER):
			chaos_beat = ChaosBeat.NONE
			_chaos_cd = randf_range(1.4, 2.6)
			crop_boost = 0.55
			Game.announce("%s eats a stone." % display_name)
			return
		chaos_beat = ChaosBeat.PEBBLE
		_chaos_dur = randf_range(1.05, 2.1)
		Game.announce("%s pecks a stone." % display_name)
	elif roll < 0.64:
		chaos_beat = ChaosBeat.DART
		_chaos_dur = randf_range(0.95, 1.7)
		Game.announce("%s panics wide." % display_name)
	else:
		chaos_beat = ChaosBeat.LUNGE
		_chaos_dur = 1.15
		climb_timer = 1.15
		Game.announce("%s flaps over somebody." % display_name)


func _hint_for(arch: Archetype) -> String:
	match arch:
		Archetype.SPRINTER:
			return "Keeps shouldering toward the rail. Will flap over whoever's in the way."
		Archetype.STEADY:
			return "Pecks a straight line. Politely. Until it isn't polite."
		Archetype.CHAOS:
			return "Spun a circle in the coop. Then flapped over another bird. Then ate a stone."
		Archetype.LATE:
			return "Loitering on the outside. That's a cut-in waiting to happen."
	return "Feathery."
