extends Node


func _ready() -> void:
	$World.add_to_group("world")
	if DisplayServer.get_name() != "headless":
		return
	_run_headless_smoke()


func _run_headless_smoke() -> void:
	var cards := {"n": 0}
	Game.results_ready.connect(
		func(payload: Dictionary) -> void:
			cards.n += 1
			print(
				"SMOKE: card=", cards.n,
				" winner=", payload.get("winner_name"),
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
			get_tree().create_timer(0.2).timeout.connect(
				func() -> void:
					Game.request_next_race()
				, CONNECT_ONE_SHOT
			)
	)
	Game.phase_changed.connect(
		func(phase: Game.Phase) -> void:
			print("SMOKE: phase=", phase, " cards=", cards.n, " window=", Game.open_secs_left())
			if phase != Game.Phase.OPEN:
				return
			if cards.n >= 5:
				return
			get_tree().create_timer(0.12).timeout.connect(
				func() -> void:
					if Game.phase != Game.Phase.OPEN:
						return
					Game.place_bet(0, 10)
					Game.ring_the_bell()
				, CONNECT_ONE_SHOT
			)
	)
	await get_tree().process_frame
	await get_tree().process_frame
	Game.begin_night()
