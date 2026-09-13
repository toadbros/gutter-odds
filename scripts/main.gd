extends Node


func _ready() -> void:
	$World.add_to_group("world")
	if DisplayServer.get_name() != "headless":
		return
	Game.results_ready.connect(
		func(payload: Dictionary) -> void:
			print(
				"SMOKE: winner=", payload.get("winner_name"),
				" won=", payload.get("won"),
				" pay=", payload.get("pay"),
				" fried=", payload.get("fried_name"),
				" caps=", Game.bottlecaps
			)
	)
	await get_tree().process_frame
	await get_tree().process_frame
	Game.begin_night()
	await get_tree().create_timer(0.15).timeout
	Game.place_bet(0, 10)
	Game.ring_the_bell()
