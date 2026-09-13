extends Node


func _ready() -> void:
	$World.add_to_group("world")
	if DisplayServer.get_name() != "headless":
		return
	_run_headless_smoke()


func _run_headless_smoke() -> void:
	print("SMOKE: net_smooth=", "ok" if NetSmooth.smoke_check() else "FAIL")
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
