extends Node


func _ready() -> void:
	$World.add_to_group("world")
	if DisplayServer.get_name() != "headless":
		return
	if OS.get_cmdline_user_args().has("--chaos-smoke"):
		_run_chaos_smoke()
		return
	_run_headless_smoke()


func _run_headless_smoke() -> void:
	var cards := {"n": 0}
	Game.results_ready.connect(func(payload: Dictionary) -> void:
		cards.n += 1
		var podium_bits: PackedStringArray = []
		for row in Game.podium_from(payload.get("standings", [])):
			podium_bits.append("%d:%s" % [int(row.get("place", 0)), str(row.get("name", ""))])
		if podium_bits.is_empty():
			push_error("SMOKE: podium empty after RESULTS")
		print(
			"SMOKE: card=", cards.n,
			" winner=", payload.get("winner_name"),
			" podium=", " / ".join(podium_bits),
			" won=", payload.get("won"),
			" pay=", payload.get("pay"),
			" fried=", payload.get("fried_name"),
			" caps=", Game.bottlecaps,
			" phase=", Game.phase
		)
		if cards.n >= 5:
			print("SMOKE: 5 cards done. caps=", Game.bottlecaps)
			get_tree().quit()
			return
		get_tree().create_timer(0.2).timeout.connect(func() -> void:
			Game.request_next_race()
		)
	)
	Game.phase_changed.connect(func(phase: Game.Phase) -> void:
		print("SMOKE: phase=", phase, " cards=", cards.n, " window=", Game.open_secs_left())
		if phase == Game.Phase.RACE and cards.n == 0:
			var manager := get_tree().get_first_node_in_group("race_manager") as RaceManager
			if manager and not manager.field.is_empty():
				var bird: Snail = manager.field[0]
				print(
					"SMOKE: track_y=", Game.TRACK_SURFACE_Y,
					" bird_y=", snappedf(bird.global_position.y, 0.001),
					" lift=", Game.TRACK_STAND_LIFT,
					" on_top=", bird.global_position.y >= Game.TRACK_SURFACE_Y - 0.01
				)
		if phase != Game.Phase.OPEN:
			return
		if cards.n == 0:
			_print_bet_card_smoke()
		if cards.n >= 5:
			return
		get_tree().create_timer(0.12).timeout.connect(func() -> void:
			if Game.phase != Game.Phase.OPEN:
				return
			Game.place_bet(0, 10)
			# First card proves the window slams itself. Later cards lock early.
			if cards.n == 0:
				Game.open_clock = 0.2
				print("SMOKE: waiting for window slam")
				return
			Game.ring_the_bell()
		)
	)
	await get_tree().process_frame
	await get_tree().process_frame
	Game.begin_night()


func _print_bet_card_smoke() -> void:
	await get_tree().process_frame
	var manager := get_tree().get_first_node_in_group("race_manager") as RaceManager
	if manager == null:
		push_error("SMOKE: no race manager for bet cards")
		return
	if manager.field.size() != Game.FIELD_SIZE:
		push_error("SMOKE: field size %d want %d" % [manager.field.size(), Game.FIELD_SIZE])
	var allowed := {"Sprinter": true, "Steady": true, "Chaos": true, "Late": true}
	var seen: Dictionary = {}
	for i in manager.field.size():
		var snail: Snail = manager.field[i]
		var arch := snail.archetype_name()
		var line := snail.archetype_line()
		var payload := snail.to_field_payload()
		print(
			"SMOKE: betcard=", i + 1,
			" name=", snail.display_name,
			" arch=", arch,
			" line=", line,
			" odds=", snail.odds_text(),
			" payload_arch=", int(payload.get("archetype", -1))
		)
		if snail.display_name.is_empty() or line.is_empty() or not allowed.has(arch):
			push_error("SMOKE: unreadable bet card #%d" % (i + 1))
		if int(payload.get("archetype", -1)) != int(snail.archetype):
			push_error("SMOKE: field payload drifted on #%d" % (i + 1))
		seen[arch] = true
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("bet_card_rows"):
		var rows: PackedStringArray = hud.bet_card_rows()
		var field_ui := hud.field_card_count() if hud.has_method("field_card_count") else 0
		print("SMOKE: hud_cards=", rows.size(), " field_ui=", field_ui)
		if rows.size() != Game.FIELD_SIZE:
			push_error("SMOKE: HUD bet cards %d want %d" % [rows.size(), Game.FIELD_SIZE])
		if field_ui != Game.FIELD_SIZE:
			push_error("SMOKE: OPEN field card missing slots")
		for row in rows:
			print("SMOKE: hud_row=", row)
		if hud.has_method("open_bookie"):
			hud.open_bookie()
			print("SMOKE: bookie opened with ", rows.size(), " readable cards")
		if hud.has_method("close_panels"):
			hud.close_panels()
	print("SMOKE: bet cards readable. types=", seen.keys())


func _run_chaos_smoke() -> void:
	var yells: Array[String] = []
	Game.event_callout.connect(func(text: String, event_id: int) -> void:
		var title := RaceChaos.event_title(event_id)
		if title.is_empty():
			title = RaceChaos.condition_name(Game.card_condition())
		var line := "SMOKE: yell=%s event=%d line=%s" % [title, event_id, text]
		yells.append(line)
		print(line)
	)
	Game.phase_changed.connect(func(phase: Game.Phase) -> void:
		print("SMOKE: chaos phase=", phase)
		if phase == Game.Phase.OPEN:
			get_tree().create_timer(0.08).timeout.connect(func() -> void:
				if Game.phase == Game.Phase.OPEN:
					Game.place_bet(0, 5)
					Game.ring_the_bell()
			)
		elif phase == Game.Phase.RACE:
			get_tree().create_timer(0.2).timeout.connect(_fire_chaos_order)
	)
	await get_tree().process_frame
	await get_tree().process_frame
	Game.begin_night()


func _fire_chaos_order() -> void:
	var manager := get_tree().get_first_node_in_group("race_manager") as RaceManager
	if manager == null:
		print("SMOKE: no race manager")
		get_tree().quit()
		return
	var order: Array[int] = [
		RaceChaos.LiveEvent.HAWK,
		RaceChaos.LiveEvent.CORN_RAIN,
		RaceChaos.LiveEvent.OIL_SLICK,
		RaceChaos.LiveEvent.LOOSE_DOG,
		RaceChaos.LiveEvent.FALSE_GUN,
		RaceChaos.LiveEvent.CROWD_SQUEEZE,
	]
	for event in order:
		manager.force_live_event(event)
		print("SMOKE: forced=", RaceChaos.event_name(event), " live=", manager.live_event)
		await get_tree().create_timer(0.12).timeout
	print("SMOKE: yell order done")
	get_tree().quit()
