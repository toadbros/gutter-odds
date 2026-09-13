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
	await _smoke_mid_race_peer_drop()


func _smoke_mid_race_peer_drop() -> void:
	var waited := 0.0
	while Game.phase != Game.Phase.RACE and waited < 6.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	if Game.phase != Game.Phase.RACE:
		push_error("SMOKE FAIL: never reached RACE")
		get_tree().quit(1)
		return
	var manager := get_tree().get_first_node_in_group("race_manager") as RaceManager
	if manager == null or not manager.racing:
		push_error("SMOKE FAIL: race manager not live")
		get_tree().quit(1)
		return
	var before: Array[float] = []
	var racing_before := 0
	for snail in manager.field:
		before.append(snail.distance)
		if snail.racing:
			racing_before += 1
	var stray: Array[int] = []
	var watch := func(seconds: int) -> void:
		stray.append(seconds)
	Game.countdown_tick.connect(watch)
	NetPlay._on_peer_disconnected(4242)
	manager.apply_player_entries()
	Game.apply_meet({
		"phase": int(Game.Phase.COUNTDOWN),
		"meet_index": Game.meet_index,
		"countdown": Game.COUNT_BEAT,
		"first_card": true,
	})
	await get_tree().create_timer(0.4).timeout
	Game.countdown_tick.disconnect(watch)
	if Game.phase != Game.Phase.RACE:
		push_error("SMOKE FAIL: phase after drop=%s" % Game.phase)
		get_tree().quit(1)
		return
	if not manager.racing:
		push_error("SMOKE FAIL: manager stopped racing after drop")
		get_tree().quit(1)
		return
	if not stray.is_empty():
		push_error("SMOKE FAIL: countdown after drop %s" % str(stray))
		get_tree().quit(1)
		return
	var racing_after := 0
	var moved := false
	for i in manager.field.size():
		var snail: Snail = manager.field[i]
		if snail.racing:
			racing_after += 1
		if i < before.size() and snail.distance > before[i] + 0.02:
			moved = true
	if racing_after < maxi(racing_before - 1, 3):
		push_error("SMOKE FAIL: birds stopped racing (%d)" % racing_after)
		get_tree().quit(1)
		return
	if not moved:
		push_error("SMOKE FAIL: pack did not keep moving after drop")
		get_tree().quit(1)
		return
	print("SMOKE: mid-race drop clean phase=RACE racing=%d ticks=[]" % racing_after)
	var results_wait := 0.0
	while Game.phase != Game.Phase.RESULTS and results_wait < 45.0:
		await get_tree().process_frame
		results_wait += get_process_delta_time()
	if Game.phase != Game.Phase.RESULTS:
		push_error("SMOKE FAIL: race did not finish after drop")
		get_tree().quit(1)
		return
	get_tree().quit(0)
