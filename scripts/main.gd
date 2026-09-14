extends Node


func _ready() -> void:
	$World.add_to_group("world")
	if OS.get_cmdline_user_args().has("--sep-demo"):
		_run_sep_demo()
		return
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
	if OS.get_cmdline_user_args().has("--feel-smoke"):
		_run_feel_smoke()
		return
	if OS.get_cmdline_user_args().has("--tell-smoke"):
		_run_tell_smoke()
		return
	if OS.get_cmdline_user_args().has("--sep-smoke"):
		_run_sep_smoke()
		return
	if OS.get_cmdline_user_args().has("--social-smoke"):
		_run_social_smoke()
		return
	_run_headless_smoke()


func _run_headless_smoke() -> void:
	print("SMOKE: net_smooth=", "ok" if NetSmooth.smoke_check() else "FAIL")
	_assert_social_copy()
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
			_print_tell_card_smoke()
		if cards.n >= 5:
			return
		get_tree().create_timer(0.12).timeout.connect(func() -> void:
			if Game.phase != Game.Phase.OPEN:
				return
			Game.place_bet(0, 10)
			_print_visible_bets_smoke()
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
		var tell := snail.card_tell()
		var card := snail.bet_card_text()
		var payload := snail.to_field_payload()
		print(
			"SMOKE: betcard=", i + 1,
			" name=", snail.display_name,
			" arch=", arch,
			" line=", line,
			" tell=", tell,
			" quirks=", snail.quirk_line(),
			" odds=", snail.odds_text(),
			" payload_arch=", int(payload.get("archetype", -1))
		)
		if snail.display_name.is_empty() or line.is_empty() or not allowed.has(arch):
			push_error("SMOKE: unreadable bet card #%d" % (i + 1))
		if tell.is_empty() or not card.contains(arch) or not card.contains(tell):
			push_error("SMOKE: missing T4/T1 card text #%d" % (i + 1))
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


func _run_tell_smoke() -> void:
	_assert_tell_copy()
	Game.phase_changed.connect(func(phase: Game.Phase) -> void:
		print("SMOKE: tell phase=", phase)
		if phase != Game.Phase.OPEN:
			return
		await _print_tell_card_smoke()
		get_tree().quit()
	)
	await get_tree().process_frame
	await get_tree().process_frame
	Game.begin_night()


func _print_tell_card_smoke() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var manager := get_tree().get_first_node_in_group("race_manager") as RaceManager
	if manager == null:
		push_error("SMOKE: no race manager for tells")
		return
	if manager.field.is_empty():
		push_error("SMOKE: field empty before tell rows")
		return
	_assert_tell_copy()
	var prev_cond := manager.card_condition
	var saved: Array = []
	for snail in manager.field:
		saved.append(snail.traits.duplicate())
	manager.stamp_tell_smoke_traits()
	manager.force_card_condition(RaceChaos.Condition.KERNEL_SCATTER)
	var corn_hits := 0
	var t4_hits := 0
	print("SMOKE: force_condition=", RaceChaos.condition_name(manager.card_condition))
	for i in manager.field.size():
		var snail: Snail = manager.field[i]
		var row := snail.bet_card_text()
		var payload := snail.to_field_payload()
		var peer := RaceChaos.card_tell(
			int(payload.get("archetype", -1)),
			payload.get("traits", []),
			int(manager.card_condition),
			RaceChaos.LiveEvent.NONE
		)
		print("SMOKE: tell_row=", i + 1, " cond=Kernel Scatter text=", row.replace("\n", " | "))
		if snail.archetype_line().is_empty() or not row.contains(snail.archetype_name()):
			push_error("SMOKE: T4 archetype missing on tell row #%d" % (i + 1))
		else:
			t4_hits += 1
		if snail.card_tell().is_empty():
			push_error("SMOKE: empty tell on #%d" % (i + 1))
		if peer != snail.card_tell():
			push_error("SMOKE: host/client tell desync on #%d" % (i + 1))
		if row.contains(RaceChaos.TELL_CHAOS_CORN) or row.contains(RaceChaos.TELL_HUNGRY_CORN):
			corn_hits += 1
	if corn_hits <= 0:
		push_error("SMOKE: kernel card missing corn chemistry")
	print("SMOKE: kernel chemistry rows=", corn_hits, " t4=", t4_hits)
	manager.force_card_condition(RaceChaos.Condition.GREASE_DRIP)
	var oil_hits := 0
	print("SMOKE: force_condition=", RaceChaos.condition_name(manager.card_condition))
	for i in manager.field.size():
		var snail: Snail = manager.field[i]
		var row := snail.bet_card_text()
		print("SMOKE: tell_row=", i + 1, " cond=Grease Drip text=", row.replace("\n", " | "))
		if row.contains(RaceChaos.TELL_SPRINTER_OIL) or row.contains(RaceChaos.TELL_GREASE_LUCKY):
			oil_hits += 1
	if oil_hits <= 0:
		push_error("SMOKE: grease card missing skillet chemistry")
	print("SMOKE: grease chemistry rows=", oil_hits)
	manager.force_card_condition(RaceChaos.Condition.STORM_COMING)
	var hawk_blind_hits := 0
	var late_hawk_hits := 0
	print("SMOKE: force_condition=", RaceChaos.condition_name(manager.card_condition))
	for i in manager.field.size():
		var snail: Snail = manager.field[i]
		var row := snail.bet_card_text()
		print("SMOKE: tell_row=", i + 1, " cond=Storm Coming text=", row.replace("\n", " | "))
		if row.contains(RaceChaos.TELL_HAWK_BLIND):
			hawk_blind_hits += 1
		if row.contains(RaceChaos.TELL_LATE_HAWK):
			late_hawk_hits += 1
	if hawk_blind_hits <= 0:
		push_error("SMOKE: storm card missing Hawk Blind chemistry")
	if late_hawk_hits <= 0:
		push_error("SMOKE: storm card missing Late hawk chemistry")
	print("SMOKE: hawk_blind rows=", hawk_blind_hits, " late_hawk rows=", late_hawk_hits)
	for i in manager.field.size():
		manager.field[i].traits = ChickenStock.traits_from(saved[i])
	manager.force_card_condition(prev_cond)
	print("SMOKE: tell cards ok")


func _assert_tell_copy() -> void:
	var corn := RaceChaos.Condition.KERNEL_SCATTER
	var oil := RaceChaos.Condition.GREASE_DRIP
	var dust := RaceChaos.Condition.DUST_BOWL
	var storm := RaceChaos.Condition.STORM_COMING
	var fair := RaceChaos.Condition.FAIR_DIRT
	var hungry: Array = [ChickenStock.Trait.CORN_FIEND]
	var grease: Array = [ChickenStock.Trait.GREASE_LEGS]
	var hawk_blind: Array = [ChickenStock.Trait.HAWK_BLIND]
	_expect_tell(2, [], corn, 0, RaceChaos.TELL_CHAOS_CORN, "chaos_corn")
	_expect_tell(1, hungry, corn, 0, RaceChaos.TELL_HUNGRY_CORN, "hungry_corn")
	_expect_tell(0, [], oil, 0, RaceChaos.TELL_SPRINTER_OIL, "sprinter_oil")
	_expect_tell(0, [], fair, RaceChaos.LiveEvent.FALSE_GUN, RaceChaos.TELL_SPRINTER_GUN, "sprinter_gun")
	_expect_tell(1, [], dust, 0, RaceChaos.TELL_STEADY_DOG, "steady_dog")
	_expect_tell(3, [], storm, 0, RaceChaos.TELL_LATE_HAWK, "late_hawk")
	_expect_tell(1, hawk_blind, storm, 0, RaceChaos.TELL_HAWK_BLIND, "hawk_blind_storm")
	_expect_tell(0, hawk_blind, fair, RaceChaos.LiveEvent.HAWK, RaceChaos.TELL_HAWK_BLIND, "hawk_blind_event")
	_expect_tell(3, hawk_blind, storm, 0, RaceChaos.TELL_HAWK_BLIND, "hawk_blind_over_late")
	_expect_tell(1, hawk_blind, fair, 0, RaceChaos.TELL_STEADY, "hawk_blind_no_hawk")
	_expect_tell(1, grease, oil, 0, RaceChaos.TELL_GREASE_LUCKY, "grease_lucky")
	_expect_tell(1, hungry, fair, 0, RaceChaos.TELL_HUNGRY, "hungry_default")
	_expect_tell(0, [], fair, 0, RaceChaos.TELL_SPRINTER, "sprinter_default")
	_expect_tell(1, [], fair, 0, RaceChaos.TELL_STEADY, "steady_default")
	_expect_tell(2, [], fair, 0, RaceChaos.TELL_CHAOS, "chaos_default")
	_expect_tell(3, [], fair, 0, RaceChaos.TELL_LATE, "late_default")
	_expect_tell(2, hungry, corn, 0, RaceChaos.TELL_CHAOS_CORN, "chaos_over_hungry")
	_expect_tell(0, grease, oil, 0, RaceChaos.TELL_SPRINTER_OIL, "sprinter_over_grease")
	var bird := {"archetype": 2, "traits": hungry}
	var host := RaceChaos.card_tell(2, hungry, corn)
	var peer := RaceChaos.card_tell(int(bird.get("archetype", -1)), bird.get("traits", []), corn)
	print("SMOKE: tell_peer=", peer)
	if host != peer or peer != RaceChaos.TELL_CHAOS_CORN:
		push_error("SMOKE: 6p derived tell drifted")
	print("SMOKE: tell copy ok")


func _expect_tell(arch: int, traits: Array, condition: int, event: int, want: String, label: String) -> void:
	var got := RaceChaos.card_tell(arch, traits, condition, event)
	print("SMOKE: tell_", label, "=", got)
	if got != want:
		push_error("SMOKE: tell %s want [%s] got [%s]" % [label, want, got])


func _print_visible_bets_smoke() -> void:
	var rows: Array = NetPlay.visible_bets()
	print("SMOKE: visible_bets=", rows.size())
	for row in rows:
		if not row is Dictionary:
			continue
		print("SMOKE: slip=", row.get("name", "?"), " idx=", row.get("index", -1), " amt=", row.get("amount", 0))
	if rows.is_empty():
		push_error("SMOKE: visible bets payload empty")
		return
	var local: Dictionary = rows[0]
	if int(local.get("amount", 0)) <= 0 or int(local.get("index", -1)) < 0:
		push_error("SMOKE: local slip missing from visible bets")


func _run_social_smoke() -> void:
	_assert_social_copy()
	Game.phase_changed.connect(func(phase: Game.Phase) -> void:
		print("SMOKE: social phase=", phase)
		if phase == Game.Phase.OPEN:
			await _probe_social_open()
		elif phase == Game.Phase.RACE:
			await _probe_social_race()
	)
	await get_tree().process_frame
	await get_tree().process_frame
	Game.begin_night()


func _assert_social_copy() -> void:
	var oil := RaceChaos.LiveEvent.OIL_SLICK
	var corn := RaceChaos.LiveEvent.CORN_RAIN
	var dog := RaceChaos.LiveEvent.LOOSE_DOG
	var hawk := RaceChaos.LiveEvent.HAWK
	var bang := RaceChaos.LiveEvent.FALSE_GUN
	if not RaceChaos.has_live_chemistry(0, [], oil):
		push_error("SMOKE: sprinter oil chemistry missing")
	if not RaceChaos.has_live_chemistry(2, [ChickenStock.Trait.CORN_FIEND], corn):
		push_error("SMOKE: chaos corn chemistry missing")
	if not RaceChaos.has_live_chemistry(1, [], dog):
		push_error("SMOKE: steady dog chemistry missing")
	if not RaceChaos.has_live_chemistry(3, [], hawk):
		push_error("SMOKE: late hawk chemistry missing")
	if not RaceChaos.has_live_chemistry(0, [ChickenStock.Trait.HAWK_BLIND], hawk):
		push_error("SMOKE: hawk-blind chemistry missing")
	if not RaceChaos.has_live_chemistry(0, [], bang):
		push_error("SMOKE: sprinter gun chemistry missing")
	if RaceChaos.has_live_chemistry(1, [], oil):
		push_error("SMOKE: steady should not oil-chem")
	if RaceChaos.has_live_chemistry(0, [], RaceChaos.LiveEvent.CROWD_SQUEEZE):
		push_error("SMOKE: crowd squeeze is not a tell pair")
	var birds: Array = [
		{"archetype": 0, "traits": [], "name": "Quick Nickel"},
		{"archetype": 3, "traits": [], "name": "Churchyard"},
	]
	var called := RaceChaos.social_spice_toast(
		[{"name": "Seat1", "index": 0, "amount": 10}],
		birds,
		oil,
		1
	)
	print("SMOKE: called_copy=", called)
	if called != RaceChaos.social_called_line("Seat1", oil):
		push_error("SMOKE: called-it copy drifted")
	var shame := RaceChaos.social_spice_toast(
		[{"name": "Seat2", "index": 1, "amount": 10}],
		birds,
		oil,
		1
	)
	print("SMOKE: shame_copy=", shame)
	if shame != RaceChaos.social_shame_line("Seat2", oil):
		push_error("SMOKE: shame copy drifted")
	var none := RaceChaos.social_spice_toast(
		[{"name": "Seat3", "index": 0, "amount": 10}],
		[{"archetype": 3, "traits": []}],
		oil,
		0
	)
	if not none.is_empty():
		push_error("SMOKE: toast without chemistry hit")
	var stacked := RaceChaos.social_spice_toast(
		[
			{"name": "Seat1", "index": 0, "amount": 10},
			{"name": "Seat2", "index": 1, "amount": 25},
		],
		birds,
		oil,
		1
	)
	if stacked != called:
		push_error("SMOKE: called-it should beat shame when both match")
	print("SMOKE: social copy ok")


func _probe_social_open() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var manager := get_tree().get_first_node_in_group("race_manager") as RaceManager
	if manager == null or manager.field.is_empty():
		push_error("SMOKE: no field for social board")
		get_tree().quit()
		return
	Game.bottlecaps = 0
	Game.bet_amount = 0
	Game.bet_index = -1
	Game.money_changed.emit(Game.bottlecaps)
	var floated := Game.place_bet(0, 10)
	print(
		"SMOKE: mercy ok=", floated,
		" amount=", Game.bet_amount,
		" caps=", Game.bottlecaps,
		" stake=", Game.BOTTLECAP_STAKE
	)
	if not floated or Game.bet_amount != Game.BOTTLECAP_STAKE:
		push_error("SMOKE: bottlecap mercy failed at 0 bankroll")
	if Game.bottlecaps != 0:
		push_error("SMOKE: floated bottlecap was not staked")
	var rows: Array = NetPlay.stamp_social_smoke_seats()
	print("SMOKE: table_seats=", rows.size())
	if rows.size() != 6:
		push_error("SMOKE: visible bets want 6 seats got %d" % rows.size())
	for i in rows.size():
		var row: Dictionary = rows[i]
		print(
			"SMOKE: seat=", row.get("name", "?"),
			" bird=#", int(row.get("index", -1)) + 1,
			" amt=", row.get("amount", 0)
		)
		if str(row.get("name", "")) != "Seat%d" % (i + 1):
			push_error("SMOKE: seat name drifted")
		if int(row.get("amount", 0)) <= 0:
			push_error("SMOKE: seat %d has no slip" % (i + 1))
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("table_slip_rows"):
		var ui: PackedStringArray = hud.call("table_slip_rows")
		print("SMOKE: hud_slips=", ui.size())
		for line in ui:
			print("SMOKE: hud_slip=", line)
		if ui.size() != 6:
			push_error("SMOKE: HUD table slips %d want 6" % ui.size())
	var sprinter := _first_arch_index(manager, 0)
	if sprinter < 0:
		push_error("SMOKE: no sprinter on the card")
		get_tree().quit()
		return
	NetPlay.slips[1] = {"id": 1, "name": "Seat1", "index": sprinter, "amount": 10}
	for pid in range(2, 7):
		NetPlay.slips[pid]["index"] = (sprinter + 1) % manager.field.size()
	NetPlay.slips_changed.emit()
	print("SMOKE: caller=Seat1 on #", sprinter + 1)
	Game.ring_the_bell()


func _probe_social_race() -> void:
	await get_tree().create_timer(0.12).timeout
	var manager := get_tree().get_first_node_in_group("race_manager") as RaceManager
	if manager == null:
		push_error("SMOKE: no race manager for social toast")
		get_tree().quit()
		return
	if not manager.racing:
		manager.start_race()
		await get_tree().process_frame
	Game.unlock_social_toast()
	Game.social_toast_count = 0
	Game.last_social_toast = ""
	manager.force_live_event(RaceChaos.LiveEvent.OIL_SLICK)
	print(
		"SMOKE: social_toast=", Game.last_social_toast,
		" count=", Game.social_toast_count,
		" live=", manager.live_event
	)
	if Game.social_toast_count != 1:
		push_error("SMOKE: want one social toast got %d" % Game.social_toast_count)
	if not Game.last_social_toast.contains("called the skillet"):
		push_error("SMOKE: forced oil missing called-it toast")
	if not Game.last_social_toast.contains("Seat1"):
		push_error("SMOKE: called-it toast missing seat name")
	Game.note_social_toast("spam stack")
	if Game.social_toast_count != 1 or Game.last_social_toast.contains("spam"):
		push_error("SMOKE: social toast stacked on the same live event")
	var shame_birds: Array = manager.pack_field_chemistry()
	var victim := int(manager.last_pack_beat.get("victim_index", -1))
	var shame := RaceChaos.social_spice_toast(
		[{"name": "Seat6", "index": victim if victim >= 0 else 1, "amount": 10}],
		shame_birds,
		RaceChaos.LiveEvent.OIL_SLICK,
		victim
	)
	print("SMOKE: shame_live=", shame, " victim=", victim)
	NetPlay.roster.clear()
	NetPlay.slips.clear()
	print("SMOKE: social spice ok")
	get_tree().quit()


func _first_arch_index(manager: RaceManager, arch: int) -> int:
	for i in manager.field.size():
		if int(manager.field[i].archetype) == arch:
			return i
	return -1


func _run_feel_smoke() -> void:
	var yells: Array[String] = []
	var flips := 0
	var beats := 0
	Game.event_callout.connect(func(text: String, event_id: int) -> void:
		yells.append("%s:%s" % [RaceChaos.event_title(event_id), text])
		print("SMOKE: yell=", RaceChaos.event_title(event_id), " line=", text)
	)
	Game.phase_changed.connect(func(phase: Game.Phase) -> void:
		print("SMOKE: feel phase=", phase)
		if phase == Game.Phase.OPEN:
			get_tree().create_timer(0.08).timeout.connect(func() -> void:
				if Game.phase != Game.Phase.OPEN:
					return
				var manager := get_tree().get_first_node_in_group("race_manager") as RaceManager
				if manager:
					var mine := manager.mark_local_entry(0)
					if mine:
						print("SMOKE: marked=", mine.owned_nametag(), " id=", mine.chicken_id)
				Game.place_bet(0, 5)
				Game.ring_the_bell()
			)
		elif phase == Game.Phase.RACE:
			get_tree().create_timer(0.12).timeout.connect(_probe_feel_race)
		elif phase == Game.Phase.RESULTS:
			var hud := get_tree().get_first_node_in_group("hud")
			var director := get_tree().get_first_node_in_group("race_director")
			var yell := ""
			var cam := ""
			if hud and hud.has_method("camera_mode_text"):
				cam = str(hud.call("camera_mode_text"))
			if director and director.has_method("camera_shot_name"):
				cam = str(director.call("camera_shot_name"))
			if hud and hud.has_method("yell_text"):
				yell = str(hud.call("yell_text"))
			print("SMOKE: results_cam=", cam, " results_yell=", yell, " flips=", flips, " beats=", beats)
			get_tree().create_timer(0.15).timeout.connect(func() -> void:
				print("SMOKE: feel done yells=", yells.size(), " flips=", flips)
				get_tree().quit()
			)
	)
	await get_tree().process_frame
	await get_tree().process_frame
	Game.begin_night()


func _probe_feel_race() -> void:
	var manager := get_tree().get_first_node_in_group("race_manager") as RaceManager
	var director := get_tree().get_first_node_in_group("race_director")
	var hud := get_tree().get_first_node_in_group("hud")
	if manager == null:
		push_error("SMOKE: no race manager")
		get_tree().quit()
		return
	if manager.local_entry() == null:
		manager.mark_local_entry(0)
	await get_tree().process_frame
	var feel: Dictionary = manager.feel_snapshot()
	print("SMOKE: mine=", feel.get("mine_tag"), " marked=", feel.get("mine_marked"), " lead=", feel.get("lead"))
	if str(feel.get("mine_tag", "")).find("YOURS") < 0:
		push_error("SMOKE: own-bird nametag missing YOURS")
	if not bool(feel.get("mine_marked", false)):
		push_error("SMOKE: own-bird ring missing")
	if director:
		print("SMOKE: cam0=", director.camera_shot_name())
		director.toggle_cinematic()
		print("SMOKE: cam1=", director.camera_shot_name(), " mine_shot=", director.is_tracking_mine())
		if not director.is_tracking_mine():
			push_error("SMOKE: C did not follow the entered bird")
		director.toggle_cinematic()
		print("SMOKE: cam2=", director.camera_shot_name())
		director.toggle_cinematic()
		print("SMOKE: cam3=", director.camera_shot_name())
	if hud and hud.has_method("camera_mode_text"):
		print("SMOKE: hud_cam=", hud.call("camera_mode_text"))
	var order: Array[int] = [
		RaceChaos.LiveEvent.HAWK,
		RaceChaos.LiveEvent.CORN_RAIN,
		RaceChaos.LiveEvent.OIL_SLICK,
		RaceChaos.LiveEvent.LOOSE_DOG,
		RaceChaos.LiveEvent.FALSE_GUN,
		RaceChaos.LiveEvent.CROWD_SQUEEZE,
	]
	var flips := 0
	var beats := 0
	for event in order:
		var before: Dictionary = manager.feel_snapshot()
		manager.force_live_event(event)
		var after: Dictionary = manager.feel_snapshot()
		var beat: Dictionary = after.get("beat", {})
		var flipped := bool(beat.get("flipped", false)) or str(before.get("lead", "")) != str(after.get("lead", ""))
		var dumped := absf(float(after.get("lead_d", 0.0)) - float(before.get("lead_d", 0.0))) > 0.04
		var tagged: PackedStringArray = after.get("tags", PackedStringArray())
		if flipped:
			flips += 1
		if dumped or not tagged.is_empty() or not str(beat.get("victim", "")).is_empty():
			beats += 1
		print(
			"SMOKE: forced=", RaceChaos.event_name(event),
			" lead=", before.get("lead"), "->", after.get("lead"),
			" flip=", flipped,
			" dump=", snappedf(float(after.get("lead_d", 0.0)) - float(before.get("lead_d", 0.0)), 0.01),
			" victim=", beat.get("victim", ""),
			" tags=", ",".join(tagged)
		)
		if not dumped and tagged.is_empty() and str(beat.get("victim", "")).is_empty():
			push_error("SMOKE: %s had no pack/body beat" % RaceChaos.event_name(event))
		await get_tree().create_timer(0.08).timeout
	if beats < 6:
		push_error("SMOKE: expected a body beat on every live event")
	if manager.field.size() >= 2:
		var closer: Snail = manager.field[1]
		closer.distance = manager.track_length
		closer.vel = 2.0
		await get_tree().process_frame
		await get_tree().process_frame
		print("SMOKE: finish_punched=", manager.did_finish_punch(), " first_at=", manager.first_finish_at)
		if not manager.did_finish_punch():
			push_error("SMOKE: first-across finish punch missing")
		if hud and hud.has_method("yell_text"):
			var yell := str(hud.call("yell_text"))
			print("SMOKE: finish_yell=", yell)
			if yell != "THEY'RE IN":
				push_error("SMOKE: finish yell missing")
	print("SMOKE: feel mid-race flips=", flips, " beats=", beats)
	var feel_gap := manager.min_pack_gap()
	print("SMOKE: feel_min_gap=", snappedf(feel_gap, 0.01))
	get_tree().quit()


func _run_sep_demo() -> void:
	Game.phase_changed.connect(func(phase: Game.Phase) -> void:
		if phase == Game.Phase.OPEN:
			await get_tree().process_frame
			Game.ring_the_bell()
		elif phase == Game.Phase.RACE:
			var manager := get_tree().get_first_node_in_group("race_manager") as RaceManager
			if manager == null:
				return
			manager.pack_for_sep_smoke()
			manager.racing = true
			print("SMOKE: sep-demo packed min_gap=", snappedf(manager.min_pack_gap(), 0.001))
	)
	await get_tree().process_frame
	await get_tree().process_frame
	Game.begin_night()


func _run_sep_smoke() -> void:
	print("SMOKE: net_smooth=", "ok" if NetSmooth.smoke_check() else "FAIL")
	Game.phase_changed.connect(func(phase: Game.Phase) -> void:
		print("SMOKE: sep phase=", phase)
		if phase != Game.Phase.OPEN:
			return
		await get_tree().process_frame
		await get_tree().process_frame
		var manager := get_tree().get_first_node_in_group("race_manager") as RaceManager
		if manager == null or manager.field.size() < 2:
			push_error("SMOKE: no packed field for sep")
			get_tree().quit()
			return
		_probe_sep_pack(manager)
		_probe_sep_chase(manager)
		_probe_sep_client_interp(manager)
		print("SMOKE: sep done")
		get_tree().quit()
	)
	await get_tree().process_frame
	await get_tree().process_frame
	Game.begin_night()


func _probe_sep_pack(manager: RaceManager) -> void:
	manager.pack_for_sep_smoke()
	var start_gap := manager.min_pack_gap()
	print("SMOKE: packed_gap=", snappedf(start_gap, 0.001), " birds=", manager.field.size())
	if start_gap > 0.12:
		push_error("SMOKE: pack did not stack the field")
	var worst := INF
	var max_jump := 0.0
	for i in 90:
		var step: Dictionary = manager.step_sep_smoke(1.0 / 60.0)
		if i >= 3:
			max_jump = maxf(max_jump, float(step.get("max_jump", 0.0)))
		if i >= 20:
			worst = minf(worst, float(step.get("min_gap", 0.0)))
	var end_gap := manager.min_pack_gap()
	print(
		"SMOKE: pack_end_gap=", snappedf(end_gap, 0.001),
		" pack_worst=", snappedf(worst, 0.001),
		" pack_max_jump=", snappedf(max_jump, 0.001)
	)
	if worst < 0.26:
		push_error("SMOKE: packed field stayed overlapping (worst %.3f)" % worst)
	if end_gap < 0.28:
		push_error("SMOKE: packed field did not separate (end %.3f)" % end_gap)
	if max_jump > 0.14:
		push_error("SMOKE: sep teleported a bird (jump %.3f)" % max_jump)


func _probe_sep_chase(manager: RaceManager) -> void:
	for i in manager.field.size():
		var snail: Snail = manager.field[i]
		snail.racing = true
		snail.finished = false
		snail.distance = 18.0 + float(i) * 0.10
		snail.groove = 0.12
		snail.height = 0.0
		snail.vel = 2.0
		snail.bump_along = 0.0
		snail.bump_lat = 0.0
		manager._place_on_track(snail, true)
	var worst := INF
	var max_jump := 0.0
	for i in 60:
		var step: Dictionary = manager.step_sep_smoke(1.0 / 60.0)
		if i >= 3:
			max_jump = maxf(max_jump, float(step.get("max_jump", 0.0)))
		if i >= 15:
			worst = minf(worst, float(step.get("min_gap", 0.0)))
	print(
		"SMOKE: chase_gap=", snappedf(manager.min_pack_gap(), 0.001),
		" chase_worst=", snappedf(worst, 0.001),
		" chase_max_jump=", snappedf(max_jump, 0.001)
	)
	if worst < 0.26:
		push_error("SMOKE: same-lane chase overlapped (worst %.3f)" % worst)
	if max_jump > 0.14:
		push_error("SMOKE: chase teleported a bird (jump %.3f)" % max_jump)


func _probe_sep_client_interp(manager: RaceManager) -> void:
	var crossed: Array[Dictionary] = [
		{"distance": 18.00, "groove": 0.20, "height": 0.0, "id": 0},
		{"distance": 18.02, "groove": 0.20, "height": 0.0, "id": 1},
	]
	var before := _vis_plan_gap(manager, crossed[0], crossed[1])
	manager._separate_vis_rows(crossed)
	var after := _vis_plan_gap(manager, crossed[0], crossed[1])
	print("SMOKE: vis_unstick ", snappedf(before, 0.001), "->", snappedf(after, 0.001))
	if after < 0.26:
		push_error("SMOKE: client vis still overlapping (%.3f)" % after)
	var buf_a := NetSmooth.new()
	var buf_b := NetSmooth.new()
	buf_a.push_at(1.00, {"distance": 18.00, "groove": 0.10, "height": 0.0, "vel": 2.0, "along": 2.0})
	buf_a.push_at(1.05, {"distance": 18.10, "groove": 0.10, "height": 0.0, "vel": 2.0, "along": 2.0})
	buf_b.push_at(1.00, {"distance": 18.48, "groove": 0.10, "height": 0.0, "vel": 2.0, "along": 2.0})
	buf_b.push_at(1.05, {"distance": 18.58, "groove": 0.10, "height": 0.0, "vel": 2.0, "along": 2.0})
	var sa := buf_a.sample(1.125)
	var sb := buf_b.sample(1.125)
	var interp := _vis_plan_gap(manager, sa, sb)
	print("SMOKE: interp_gap=", snappedf(interp, 0.001))
	if interp < 0.30:
		push_error("SMOKE: interpolated pair collapsed (%.3f)" % interp)


func _vis_plan_gap(manager: RaceManager, a: Dictionary, b: Dictionary) -> float:
	var along := float(a.get("distance", 0.0)) - float(b.get("distance", 0.0))
	var lat := (float(a.get("groove", 0.0)) - float(b.get("groove", 0.0))) * manager.groove_span()
	return Vector2(along, lat).length()


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
