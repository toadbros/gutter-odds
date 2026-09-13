extends Node


func _ready() -> void:
	$World.add_to_group("world")
	if DisplayServer.get_name() != "headless":
		return
	if OS.get_cmdline_user_args().has("--chaos-smoke"):
		_run_chaos_smoke()
		return
	if OS.get_cmdline_user_args().has("--roast-smoke"):
		_print_roast_copy_smoke()
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--mesh-smoke"):
		_run_mesh_smoke()
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
		var roast := str(payload.get("roast", ""))
		var fryer := str(payload.get("fryer_line", ""))
		var toast_beat := str(payload.get("table_toast", ""))
		if roast.is_empty() or fryer.is_empty():
			push_error("SMOKE: roast beat missing after RESULTS")
		if not roast.contains(str(payload.get("winner_name", "???"))):
			push_error("SMOKE: roast missing winner")
		if not fryer.contains(str(payload.get("fried_name", "???"))):
			push_error("SMOKE: fryer line missing bird")
		if not str(payload.get("fried_owner", "")).is_empty() and not fryer.contains(str(payload.get("fried_owner", ""))):
			push_error("SMOKE: fryer line missing owner")
		print(
			"SMOKE: card=", cards.n,
			" winner=", payload.get("winner_name"),
			" podium=", " / ".join(podium_bits),
			" won=", payload.get("won"),
			" pay=", payload.get("pay"),
			" fried=", payload.get("fried_name"),
			" owner=", payload.get("fried_owner"),
			" roast=", roast,
			" punch=", payload.get("punchline"),
			" toast=", toast_beat,
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
		if phase == Game.Phase.OPEN or phase == Game.Phase.COUNTDOWN or phase == Game.Phase.RACE:
			if cards.n == 0:
				_audit_oval_meshes(str(phase))
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
	_print_roast_copy_smoke()
	await get_tree().process_frame
	await get_tree().process_frame
	Game.begin_night()


func _print_roast_copy_smoke() -> void:
	var punch := RaceChaos.roast_punchline(RaceChaos.LiveEvent.OIL_SLICK, "Quick Nickel", "Lance", 0)
	print("SMOKE: punch=", punch)
	if not punch.contains("Sprinter") or not punch.contains("skillet"):
		push_error("SMOKE: oil sprinter punchline missing")
	var fryer := RaceChaos.fryer_crisp_line("Quick Nickel", "Lance")
	print("SMOKE: fryer=", fryer)
	if not fryer.contains("Lance") or not fryer.contains("Quick Nickel"):
		push_error("SMOKE: fryer line missing bird+owner")
	var roast := RaceChaos.table_roast("Lady Cluck", RaceChaos.fryer_owner_line("Quick Nickel", "Lance"), punch)
	print("SMOKE: table_roast=", roast)
	if not roast.contains("Lady Cluck") or not roast.contains("Lance") or not roast.contains("Quick Nickel"):
		push_error("SMOKE: table roast missing winner or fried bird+owner")
	for i in 6:
		var trainer := "Seat%d" % (i + 1)
		var line := RaceChaos.fryer_crisp_line("Bird%d" % (i + 1), trainer)
		if not line.contains(trainer):
			push_error("SMOKE: 6p roast missing owner %s" % trainer)
	print("SMOKE: 6p roast owners named")
	var house := RaceChaos.fryer_crisp_line("Churchyard", "")
	if not house.contains("Churchyard"):
		push_error("SMOKE: barn fryer line missing bird")
	NetPlay.roster.clear()
	for i in 6:
		NetPlay.roster[i + 1] = {"name": "Seat%d" % (i + 1), "ready": true}
	var seat6 := Game.fried_owner_name(6, "ch_fried")
	print("SMOKE: six_seat_owner=", seat6)
	if seat6 != "Seat6":
		push_error("SMOKE: trainer name for seat 6 drifted")
	var peer_line := RaceChaos.fryer_owner_line("Bird6", seat6)
	var peer_roast := RaceChaos.table_roast("Bird1", peer_line, punch)
	var host_payload := {
		"winner_name": "Bird1",
		"fried_name": "Bird6",
		"fried_owner": seat6,
		"fried_owned": false,
		"bet_amount": 10,
		"won": false,
		"roast": peer_roast,
		"fryer_line": peer_line,
		"punchline": punch,
	}
	Game._play_results_roast(host_payload)
	var shared := str(host_payload.get("table_toast", ""))
	print("SMOKE: client_shared_toast=", shared)
	if not shared.contains("Seat6") or not shared.contains("Bird6") or not shared.contains("Bird1"):
		push_error("SMOKE: shared 6p toast missing winner or fried bird+owner")
	if not shared.contains("Your slip is trash"):
		push_error("SMOKE: shared 6p toast missing local payout")
	NetPlay.roster.clear()
	print("SMOKE: roast copy ok")


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
		var rows: PackedStringArray = hud.call("bet_card_rows")
		var field_ui := 0
		if hud.has_method("field_card_count"):
			field_ui = int(hud.call("field_card_count"))
		print("SMOKE: hud_cards=", rows.size(), " field_ui=", field_ui)
		if rows.size() != Game.FIELD_SIZE:
			push_error("SMOKE: HUD bet cards %d want %d" % [rows.size(), Game.FIELD_SIZE])
		if field_ui != Game.FIELD_SIZE:
			push_error("SMOKE: OPEN field card missing slots")
		for row in rows:
			print("SMOKE: hud_row=", row)
		if hud.has_method("open_bookie"):
			hud.call("open_bookie")
			print("SMOKE: bookie opened with ", rows.size(), " readable cards")
		if hud.has_method("close_panels"):
			hud.call("close_panels")
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


func _run_mesh_smoke() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_audit_oval_meshes("BOOT")
	var stadium := get_tree().get_first_node_in_group("stadium") as Stadium
	if stadium == null:
		push_error("SMOKE: no stadium for mesh audit")
		get_tree().quit()
		return
	for condition in [
		RaceChaos.Condition.FAIR_DIRT,
		RaceChaos.Condition.DUST_BOWL,
		RaceChaos.Condition.GREASE_DRIP,
		RaceChaos.Condition.KERNEL_SCATTER,
		RaceChaos.Condition.STORM_COMING,
	]:
		stadium.apply_card_condition(condition)
		await get_tree().process_frame
		_audit_oval_meshes("COND_%s" % RaceChaos.condition_name(condition))
	for event in [
		RaceChaos.LiveEvent.OIL_SLICK,
		RaceChaos.LiveEvent.HAWK,
		RaceChaos.LiveEvent.CORN_RAIN,
		RaceChaos.LiveEvent.LOOSE_DOG,
		RaceChaos.LiveEvent.FALSE_GUN,
		RaceChaos.LiveEvent.CROWD_SQUEEZE,
	]:
		stadium.show_live_event(event, 20.0)
		await get_tree().process_frame
		_audit_oval_meshes("LIVE_%s" % RaceChaos.event_name(event))
	stadium.clear_live_event()
	print("SMOKE: mesh audit done")
	get_tree().quit()


func _audit_oval_meshes(label: String) -> void:
	var stadium := get_tree().get_first_node_in_group("stadium") as Stadium
	if stadium == null:
		push_error("SMOKE: no stadium at %s" % label)
		return
	var all := stadium.list_oval_cylinders()
	var bad := stadium.audit_oval_cylinders()
	print("SMOKE: cyl_phase=", label, " count=", all.size(), " bad=", bad.size())
	var skipped := 0
	for line in all:
		if line.contains("RailPost") or line.contains("FlagPole") or line.begins_with("MeshInstance3D "):
			skipped += 1
			continue
		print("SMOKE: cyl ", line)
	print("SMOKE: cyl skipped_props=", skipped)
	for line in bad:
		push_error("SMOKE: giant cylinder %s @ %s" % [line, label])
	if bad.is_empty():
		print("SMOKE: oval cylinders clean @ ", label)
