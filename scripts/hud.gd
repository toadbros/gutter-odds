extends CanvasLayer

const INK := Color("f0e6d0")
const MUTED := Color("c4b48a")
const BRASS := Color("b08d57")
const DARK := Color(0.08, 0.05, 0.04, 0.94)

var _prompt: Label
var _toast: Label
var _callout: Label
var _yell_title: Label
var _yell_tween: Tween
var _caps: Label
var _phase: Label
var _bet_slip: Label
var _help: Label
var _countdown: Label
var _flash: ColorRect
var _bang: AudioStreamPlayer
var _count_tween: Tween
var _go_linger: float = 0.0
var _standings: VBoxContainer
var _cam_mode: Label
var _binoculars: ColorRect
var _menu: Control
var _pause: Control
var _bookie: Control
var _inspect: Control
var _results: Control
var _bookie_list: VBoxContainer
var _inspect_body: RichTextLabel
var _results_body: RichTextLabel
var _ticket: Panel
var _ticket_label: Label
var _confirm_btn: Button
var _stake_label: Label
var _stake_buttons: Array[Button] = []
var _inspect_index: int = 0
var _toast_time: float = 0.0
var _callout_time: float = 0.0
var _selected_snail: int = 0
var _stake: int = 10
var _paused: bool = false
var _coop_ui: Control
var _market_ui: Control
var _coop_list: VBoxContainer
var _market_list: VBoxContainer
var _coop_detail: RichTextLabel
var _meet: Label
var _net: Label
var _join_ip: LineEdit
var _join_port: LineEdit
var _join_name: LineEdit
var _join_status: Label
var _host_name: LineEdit
var _host_port: LineEdit
var _host_status: Label
var _menu_home: Control
var _menu_host: Control
var _menu_join: Control
var _lobby: Control
var _lobby_list: VBoxContainer
var _lobby_info: Label
var _lobby_hint: Label
var _ready_btn: Button
var _start_btn: Button
var _coop_selected: String = ""
var _breed_hen: String = ""
var _breed_rooster: String = ""
var _shed_line: Label
var _market_hint: Label
var _window_clock: Label
var _lock_btn: Button
var _results_hint: Label
var _next_card_btn: Button
var _field_card: Control
var _field_list: VBoxContainer
var _table_board: Control
var _table_list: VBoxContainer


func _ready() -> void:
	add_to_group("hud")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_build()
	Game.phase_changed.connect(_on_phase)
	Game.money_changed.connect(_on_money)
	Game.bet_changed.connect(_on_bet_changed)
	Game.toast.connect(show_toast)
	Game.callout.connect(show_callout)
	Game.event_callout.connect(show_event_callout)
	Game.countdown_tick.connect(_on_countdown)
	Game.bookie_requested.connect(open_bookie)
	Game.inspect_requested.connect(open_inspect)
	Game.results_ready.connect(open_results)
	Game.coop_changed.connect(_on_coop_changed)
	Game.market_changed.connect(_on_market_changed)
	Game.meet_changed.connect(_refresh_meet)
	Game.coop_requested.connect(open_coop)
	Game.market_requested.connect(open_market)
	NetPlay.status_changed.connect(_on_net)
	NetPlay.lobby_changed.connect(_fill_lobby)
	NetPlay.peers_changed.connect(_fill_lobby)
	NetPlay.slips_changed.connect(_refresh_table_slips)
	_on_money(Game.bottlecaps)
	_on_phase(Game.phase)
	_refresh_slip()
	_refresh_meet()
	_on_net(NetPlay.status)


func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time -= delta
		if _toast_time <= 0.0:
			_toast.modulate.a = 0.0
	if _callout_time > 0.0:
		_callout_time -= delta
		if _callout_time <= 0.0:
			_callout.modulate.a = 0.0
			if _yell_title:
				_yell_title.modulate.a = 0.0
				_yell_title.text = ""
	if _flash:
		_flash.color.a = move_toward(_flash.color.a, 0.0, delta * 2.6)
	if _go_linger > 0.0:
		_go_linger -= delta
		if _go_linger <= 0.0:
			_fade_go()
	_refresh_loop_clocks()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if Game.phase == Game.Phase.MENU:
			return
		if Game.phase == Game.Phase.LOBBY:
			Game.return_to_menu()
			_show_menu_home()
			return
		if _bookie.visible:
			close_panels()
			return
		if _inspect.visible:
			close_panels()
			return
		if _coop_ui and _coop_ui.visible:
			close_panels()
			return
		if _market_ui and _market_ui.visible:
			close_panels()
			return
		if _results.visible:
			return
		if Game.phase == Game.Phase.COUNTDOWN or Game.phase == Game.Phase.RACE:
			Game.toast.emit("They're running. You can stare, you can't pause.")
			return
		toggle_pause()


func set_prompt(text: String) -> void:
	_prompt.text = text
	_prompt.visible = not text.is_empty() and not Game.is_sitting()


func set_binoculars(on: bool) -> void:
	_binoculars.visible = on


func set_camera_mode(cinematic: bool, shot: String = "") -> void:
	_cam_mode.visible = Game.phase == Game.Phase.RACE or Game.phase == Game.Phase.COUNTDOWN or Game.phase == Game.Phase.RESULTS
	if not shot.is_empty():
		_cam_mode.text = shot
	else:
		_cam_mode.text = "PACK CAM" if cinematic else "ON THE RAIL"


func camera_mode_text() -> String:
	return _cam_mode.text if _cam_mode else ""


func yell_text() -> String:
	return _yell_title.text if _yell_title else ""


func show_finish_punch(bird_name: String, yours: bool = false) -> void:
	if _yell_title:
		_yell_title.text = "THEY'RE IN"
		_yell_title.modulate = Color.WHITE
		_yell_title.add_theme_font_size_override("font_size", 78)
		_yell_title.add_theme_color_override("font_color", Color("e8c03a"))
		_punch_yell()
	_callout.text = ("%s  ·  YOURS" % bird_name) if yours else ("%s TAKES IT" % bird_name)
	_callout.add_theme_font_size_override("font_size", 34)
	_callout.add_theme_color_override("font_color", Color("c4e08a") if yours else INK)
	_callout.modulate.a = 1.0
	_callout_time = 3.4
	if _flash:
		_flash.color = Color(1.0, 0.94, 0.72, 0.55)
	_play_gun()


func show_results_punch(bird_name: String = "", yours: bool = false) -> void:
	if _yell_title:
		_yell_title.text = "PHOTO FINISH"
		_yell_title.modulate = Color.WHITE
		_yell_title.add_theme_font_size_override("font_size", 72)
		_yell_title.add_theme_color_override("font_color", Color("e8c03a"))
		_punch_yell()
	if not bird_name.is_empty() and (_callout_time <= 0.0 or _callout.text.is_empty()):
		_callout.text = ("%s  ·  YOURS" % bird_name) if yours else ("%s takes the ring." % bird_name)
		_callout.add_theme_font_size_override("font_size", 28)
		_callout.modulate.a = 1.0
		_callout_time = 2.4
	if _flash:
		_flash.color = Color(1.0, 0.94, 0.72, 0.42)
	_cam_mode.visible = true
	if _cam_mode.text.is_empty():
		_cam_mode.text = "PHOTO FINISH"


func set_standings(rows: Array) -> void:
	for child in _standings.get_children():
		child.queue_free()
	for row in rows:
		var line := Label.new()
		var mark := "●"
		if row.get("finished", false):
			mark = str(row.get("place", ""))
		line.text = "%s  %s   %s" % [mark, row.get("name", ""), row.get("odds", Vector2i(1, 1))]
		if row.get("odds") is Vector2i:
			var o: Vector2i = row["odds"]
			var tag := str(row.get("tag", ""))
			if tag.is_empty():
				line.text = "%s  %s    %d/%d" % [mark, row.get("name", ""), o.x, o.y]
			else:
				line.text = "%s  %s  %s    %d/%d" % [mark, row.get("name", ""), tag, o.x, o.y]
		if row.get("yours", false):
			line.text += "  YOURS"
		line.add_theme_color_override("font_color", row.get("color", INK))
		line.add_theme_font_size_override("font_size", 16)
		_standings.add_child(line)


func show_toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	_toast_time = 5.8 if Game.phase == Game.Phase.RESULTS else 3.2


func show_callout(text: String) -> void:
	# Finish/event yells win mid-race. RESULTS roast still has to land.
	if Game.phase != Game.Phase.RESULTS and _yell_title and _yell_title.modulate.a > 0.05 and not _yell_title.text.is_empty():
		return
	if _yell_title:
		_yell_title.modulate.a = 0.0
		_yell_title.text = ""
	_callout.add_theme_font_size_override("font_size", 26)
	_callout.add_theme_color_override("font_color", BRASS)
	_callout.text = text
	_callout.modulate.a = 1.0
	_callout_time = 2.6


func show_event_callout(text: String, event_id: int = 0) -> void:
	var title := RaceChaos.event_title(event_id)
	if title.is_empty():
		title = RaceChaos.condition_name(Game.card_condition()).to_upper()
	var rank := RaceChaos.event_rank(event_id)
	var size := 52
	if event_id > 0:
		size = 86 if rank <= 1 else (70 if rank == 2 else 58)
	if _yell_title:
		_yell_title.text = title
		_yell_title.modulate = Color.WHITE
		_yell_title.add_theme_font_size_override("font_size", size)
		_yell_title.add_theme_color_override("font_color", RaceChaos.event_flash(event_id).lightened(0.45))
		_punch_yell()
	_callout.text = text
	_callout.add_theme_font_size_override("font_size", 30 if event_id > 0 else 22)
	_callout.add_theme_color_override("font_color", INK)
	_callout.modulate.a = 1.0
	_callout_time = RaceChaos.event_yell_secs(event_id) if event_id > 0 else 4.0
	if _flash:
		var flash := RaceChaos.event_flash(event_id)
		var peak := 0.52 if rank <= 1 else (0.36 if rank == 2 else 0.26)
		if event_id <= 0:
			peak = 0.22
		_flash.color = Color(flash.r, flash.g, flash.b, peak)
	_play_chaos_sting(event_id)


func open_bookie() -> void:
	if Game.phase != Game.Phase.OPEN:
		return
	if Game.bet_index >= 0:
		_selected_snail = Game.bet_index
	_fill_bookie()
	_bookie.visible = true
	_inspect.visible = false
	if _coop_ui:
		_coop_ui.visible = false
	if _market_ui:
		_market_ui.visible = false
	Game.set_ui_open(true)
	_refresh_field_card()


func open_inspect(index: int) -> void:
	var manager := _manager()
	if manager == null or index < 0 or index >= manager.field.size():
		return
	var snail: Snail = manager.field[index]
	_inspect_index = index
	_inspect_body.clear()
	_inspect_body.append_text("[b]%s[/b]  ·  #%d\n" % [snail.display_name, index + 1])
	_inspect_body.append_text("[color=#b08d57]%s  ·  %s  ·  %s  ·  %s[/color]\n\n" % [
		snail.grade_name(),
		ChickenStock.sex_name({"sex": snail.sex, "grade": snail.grade}),
		snail.archetype_name(),
		snail.odds_text(),
	])
	_inspect_body.append_text("%s\n\n" % snail.flavor)
	_inspect_body.append_text("[color=#b08d57]%s[/color]\n" % RaceChaos.condition_name(Game.card_condition()).to_upper())
	_inspect_body.append_text("[i]%s[/i]\n\n" % RaceChaos.condition_tell(Game.card_condition()))
	_inspect_body.append_text("[i]%s[/i]\n\n" % snail.hint)
	_inspect_body.append_text("%s\n\n" % ChickenStock.trait_block(snail))
	_inspect_body.append_text("Mood: %s\n" % snail.mood)
	if snail.owner_id == NetPlay.local_id() and not snail.chicken_id.begins_with("npc_"):
		_inspect_body.append_text("[color=#c4e08a]This one is yours. Do not finish last.[/color]\n")
	_inspect.visible = true
	_bookie.visible = false
	Game.set_ui_open(true)
	_refresh_field_card()


func open_results(payload: Dictionary) -> void:
	_results_body.clear()
	_results_body.append_text("[color=#b08d57]1st drinks. 2nd almost. 3rd still has feathers.[/color]\n")
	var places := {1: "—", 2: "—", 3: "—"}
	for row in Game.podium_from(payload.get("standings", [])):
		var place := int(row.get("place", 0))
		if not places.has(place):
			continue
		var name := str(row.get("name", "Chicken"))
		if row.get("yours", false):
			name += "  · yours"
		places[place] = name
	_results_body.append_text("[b]1st[/b]  %s\n" % places[1])
	_results_body.append_text("[b]2nd[/b]  %s\n" % places[2])
	_results_body.append_text("[b]3rd[/b]  %s\n\n" % places[3])
	_results_body.append_text("[b]%s[/b]\n" % payload.get("race_name", "The card"))
	var roast := str(payload.get("roast", ""))
	var fried := str(payload.get("fried_name", ""))
	var fried_owner := str(payload.get("fried_owner", ""))
	if roast.is_empty():
		_results_body.append_text("[b]%s[/b] takes the ring.\n" % payload.get("winner_name", "A chicken"))
		if not fried.is_empty():
			_results_body.append_text("[color=#e8a028]%s[/color]\n" % RaceChaos.fryer_crisp_line(fried, fried_owner))
	else:
		_results_body.append_text("[color=#e8a028]%s[/color]\n" % roast)
	if payload.get("fried_owned", false) and not fried.is_empty():
		_results_body.append_text("The fryer paid %d caps for the carcass.\n" % ChickenStock.FRY_PAYOUT)
	if int(payload.get("purse_won", 0)) > 0:
		_results_body.append_text("Your bird took the purse: [color=#c4e08a]+%d[/color]\n" % int(payload.get("purse_won", 0)))
	if payload.get("wing_complete", false):
		_results_body.append_text("[color=#e8c03a]TRIPLE WING. That's the barn's whole argument.[/color]\n")
	var payout := str(payload.get("payout_line", ""))
	if payout.is_empty():
		if payload.get("won", false):
			payout = "Your slip paid %d bottlecaps." % int(payload.get("pay", 0))
		elif int(payload.get("bet_amount", 0)) > 0:
			payout = "Your slip is trash. The tin is heavier."
		else:
			payout = "You watched. That's free, and it looks like it."
	if payload.get("won", false):
		_results_body.append_text("[color=#c4e08a]%s[/color]" % payout)
	else:
		_results_body.append_text(payout)
	_results.visible = true
	_bookie.visible = false
	_inspect.visible = false
	if _coop_ui:
		_coop_ui.visible = false
	if _market_ui:
		_market_ui.visible = false
	_countdown.text = ""
	if _next_card_btn:
		_next_card_btn.modulate = Color("e8d5a0")
	_refresh_loop_clocks()
	Game.set_ui_open(true)


func close_panels() -> void:
	_bookie.visible = false
	_inspect.visible = false
	if _coop_ui:
		_coop_ui.visible = false
	if _market_ui:
		_market_ui.visible = false
	_refresh_field_card()
	if not _results.visible and not _paused:
		Game.set_ui_open(false)


func toggle_pause() -> void:
	_paused = not _paused
	_pause.visible = _paused
	get_tree().paused = _paused
	Game.set_ui_open(_paused or _bookie.visible or _inspect.visible or _results.visible or (_coop_ui and _coop_ui.visible) or (_market_ui and _market_ui.visible))


func _on_phase(phase: Game.Phase) -> void:
	_menu.visible = phase == Game.Phase.MENU
	if _lobby:
		_lobby.visible = phase == Game.Phase.LOBBY
	if _ticket:
		_ticket.visible = not Game.is_sitting()
	if _caps:
		_caps.visible = not Game.is_sitting()
	_standings.visible = phase == Game.Phase.RACE or phase == Game.Phase.RESULTS
	_refresh_field_card()
	_refresh_table_slips()
	_cam_mode.visible = phase == Game.Phase.RACE or phase == Game.Phase.COUNTDOWN or phase == Game.Phase.RESULTS
	_help.visible = not Game.is_sitting()
	if phase != Game.Phase.RESULTS and _results:
		_results.visible = false
	if phase != Game.Phase.OPEN:
		_bookie.visible = false
		_inspect.visible = false
		if _coop_ui:
			_coop_ui.visible = false
		if _market_ui:
			_market_ui.visible = false
	if phase == Game.Phase.MENU:
		close_panels()
		_show_menu_home()
	if phase == Game.Phase.LOBBY:
		_fill_lobby()
	match phase:
		Game.Phase.MENU:
			_phase.text = ""
			_clear_count()
		Game.Phase.LOBBY:
			_phase.text = ""
			_clear_count()
			_help.text = ""
		Game.Phase.OPEN:
			_phase.text = "%s  ·  %s" % [Game.race_name().to_upper(), RaceChaos.condition_name(Game.card_condition()).to_upper()]
			_help.text = "WASD move  ·  E use  ·  B bookie  ·  K coop  ·  M market  ·  R lock the window"
			_clear_count()
		Game.Phase.COUNTDOWN:
			_phase.text = "THEY'RE LINING UP  ·  %s" % RaceChaos.condition_name(Game.card_condition()).to_upper()
			_help.text = "Hold still."
			set_camera_mode(true)
		Game.Phase.RACE:
			_phase.text = "LIVE · %s  ·  %s" % [Game.race_name(), RaceChaos.condition_name(Game.card_condition()).to_upper()]
			_help.text = "C pack / your bird / rail  ·  VIP: hold RMB for binoculars"
			if OS.is_debug_build():
				_help.text += "  ·  1 Hawk  2 Corn  3 Oil  4 Dog  5 Gun  6 Crowd  7 Sniper  8 Dive  9 Chair  0 Rocket"
			set_camera_mode(true)
		Game.Phase.RESULTS:
			_phase.text = "PHOTO FINISH"
			_help.text = "DEAL THE NEXT CARD  ·  or it deals itself"
			show_results_punch()
	_refresh_loop_clocks()
	_refresh_meet()


func _on_money(amount: int) -> void:
	_caps.text = "%d  caps" % amount


func _on_countdown(seconds: int) -> void:
	if _countdown == null:
		return
	if Game.phase != Game.Phase.COUNTDOWN:
		return
	_countdown.modulate.a = 1.0
	if seconds <= 0:
		_countdown.text = "GO"
		_countdown.add_theme_font_size_override("font_size", 148)
		_countdown.add_theme_color_override("font_color", Color("e8c03a"))
		_go_linger = 1.05
		if _flash:
			_flash.color = Color(1.0, 0.94, 0.72, 0.58)
		_play_gun()
		_punch_count(1.62)
		return
	_go_linger = 0.0
	_countdown.text = str(seconds)
	_countdown.add_theme_font_size_override("font_size", 128)
	_countdown.add_theme_color_override("font_color", INK)
	_play_tick(seconds)
	_punch_count(1.32)


func _on_bet_changed() -> void:
	_refresh_slip()
	_refresh_field_card()
	_refresh_table_slips()
	if _bookie and _bookie.visible:
		_fill_bookie()


func _refresh_slip() -> void:
	if _ticket_label == null:
		return
	if Game.bet_amount <= 0:
		_bet_slip.text = "No slip"
		_bet_slip.modulate = MUTED
		_ticket_label.text = "NO SLIP\nTalk to the bookie  ·  or press B\nPick a chicken, then stuff the slip."
		_ticket.modulate = Color(1, 1, 1, 0.92)
		return
	var name := "#" + str(Game.bet_index + 1)
	var odds := "—"
	var manager := _manager()
	if manager and Game.bet_index >= 0 and Game.bet_index < manager.field.size():
		var snail: Snail = manager.field[Game.bet_index]
		name = snail.display_name
		odds = snail.odds_text()
	var pay := Game.potential_payout()
	_bet_slip.text = "Slip  %d on %s" % [Game.bet_amount, name]
	_bet_slip.modulate = BRASS
	_ticket_label.text = "YOUR SLIP\n%d caps on %s  ·  %s\nPays %d if they win" % [Game.bet_amount, name, odds, pay]
	_ticket.modulate = Color("e8d5a0")
	_refresh_confirm()


func _fill_bookie() -> void:
	for child in _bookie_list.get_children():
		child.queue_free()
	var manager := _manager()
	if manager == null:
		return
	var tell := Label.new()
	tell.text = "%s  ·  %s" % [RaceChaos.condition_name(manager.card_condition), RaceChaos.condition_tell(manager.card_condition)]
	tell.add_theme_color_override("font_color", MUTED)
	tell.add_theme_font_size_override("font_size", 13)
	tell.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tell.custom_minimum_size = Vector2(460, 36)
	_bookie_list.add_child(tell)
	for i in manager.field.size():
		var snail: Snail = manager.field[i]
		var row := Button.new()
		row.text = "  #%d  %s    %s    %s\n  %s" % [
			i + 1,
			snail.display_name,
			snail.odds_text(),
			snail.bet_card_title(),
			snail.card_tell(),
		]
		row.custom_minimum_size = Vector2(500, 68)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_style_button(row)
		var idx: int = i
		row.pressed.connect(func() -> void:
			_selected_snail = idx
			_highlight_bookie()
			_refresh_confirm()
		)
		_bookie_list.add_child(row)
	if manager.field.size() > 0:
		_selected_snail = clampi(_selected_snail, 0, manager.field.size() - 1)
	_highlight_bookie()
	_refresh_confirm()
	_highlight_stakes()


func _refresh_field_card() -> void:
	if _field_card == null or _field_list == null:
		return
	var overlay_up := (_bookie and _bookie.visible) or _inspect.visible or (_coop_ui and _coop_ui.visible) or (_market_ui and _market_ui.visible) or _results.visible
	var show := Game.phase == Game.Phase.OPEN and not overlay_up
	_field_card.visible = show
	for child in _field_list.get_children():
		child.queue_free()
	if not show:
		return
	var manager := _manager()
	if manager == null:
		return
	for i in manager.field.size():
		var snail: Snail = manager.field[i]
		var row := Button.new()
		row.text = "#%d  %s    %s\n%s" % [
			i + 1,
			snail.display_name,
			snail.bet_card_title(),
			snail.card_tell(),
		]
		row.custom_minimum_size = Vector2(360, 62)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_style_button(row)
		row.add_theme_font_size_override("font_size", 15)
		var idx: int = i
		row.pressed.connect(func() -> void:
			_selected_snail = idx
			open_bookie()
		)
		_field_list.add_child(row)


func bet_card_rows() -> PackedStringArray:
	var rows: PackedStringArray = []
	var manager := _manager()
	if manager == null:
		return rows
	for snail in manager.field:
		rows.append(snail.bet_card_text())
	return rows


func field_card_count() -> int:
	if _field_card == null or _field_list == null or not _field_card.visible:
		return 0
	var n := 0
	for child in _field_list.get_children():
		if child is Button and not child.is_queued_for_deletion():
			n += 1
	return n


func table_slip_rows() -> PackedStringArray:
	var rows: PackedStringArray = []
	for row in NetPlay.visible_bets():
		if row is Dictionary:
			rows.append(_slip_line(row))
	return rows


func table_board_count() -> int:
	if _table_board == null or _table_list == null or not _table_board.visible:
		return 0
	var n := 0
	for child in _table_list.get_children():
		if child is Label and not child.is_queued_for_deletion():
			n += 1
	return n


func _slip_line(row: Dictionary) -> String:
	var who := str(row.get("name", "Trainer"))
	var amount := int(row.get("amount", 0))
	var idx := int(row.get("index", -1))
	if amount <= 0 or idx < 0:
		return "%s  ·  watching" % who
	var bird := "#%d" % (idx + 1)
	var manager := _manager()
	if manager and idx >= 0 and idx < manager.field.size():
		bird = manager.field[idx].display_name
	return "%s  ·  %d on %s" % [who, amount, bird]


func _refresh_table_slips() -> void:
	if _table_board == null or _table_list == null:
		return
	var show := (Game.phase == Game.Phase.OPEN or Game.phase == Game.Phase.COUNTDOWN) and not Game.is_sitting()
	_table_board.visible = show
	for child in _table_list.get_children():
		child.queue_free()
	if not show:
		return
	for row in NetPlay.visible_bets():
		if not row is Dictionary:
			continue
		var line := Label.new()
		line.text = _slip_line(row)
		var live := int(row.get("amount", 0)) > 0 and int(row.get("index", -1)) >= 0
		line.add_theme_color_override("font_color", BRASS if live else MUTED)
		line.add_theme_font_size_override("font_size", 15)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size = Vector2(300, 22)
		_table_list.add_child(line)


func _highlight_bookie() -> void:
	var n := 0
	for child in _bookie_list.get_children():
		var btn := child as Button
		if btn == null:
			continue
		btn.modulate = BRASS if n == _selected_snail else Color.WHITE
		n += 1


func _refresh_confirm() -> void:
	if _confirm_btn == null:
		return
	var manager := _manager()
	var name := "a chicken"
	var odds := Vector2i(1, 1)
	if manager and _selected_snail >= 0 and _selected_snail < manager.field.size():
		var snail: Snail = manager.field[_selected_snail]
		name = snail.display_name
		odds = snail.odds
	var purse := Game.purse()
	var amount := purse if _stake < 0 else _stake
	if purse <= 0:
		amount = Game.BOTTLECAP_STAKE
	else:
		amount = mini(amount, purse)
	var pay := amount + int(amount * odds.x / maxi(odds.y, 1))
	if purse <= 0:
		_confirm_btn.text = "Stuff a bottlecap  ·  1 on %s  ·  house mercy" % name
		if _stake_label:
			_stake_label.text = "Stake: bottlecap  ·  you're broke"
	else:
		_confirm_btn.text = "Stuff the slip  ·  %d on %s  ·  pays %d" % [amount, name, pay]
		if _stake_label:
			_stake_label.text = "Stake: %s caps" % ("ALL IN" if _stake < 0 else str(_stake))


func _highlight_stakes() -> void:
	for i in _stake_buttons.size():
		var on := false
		if i < 4:
			on = _stake == [5, 10, 25, 50][i]
		else:
			on = _stake < 0
		_stake_buttons[i].modulate = BRASS if on else Color.WHITE


func _confirm_bet() -> void:
	var amount := Game.purse() if _stake < 0 else _stake
	if Game.purse() <= 0:
		amount = Game.BOTTLECAP_STAKE
	if Game.place_bet(_selected_snail, amount):
		_refresh_slip()
		_refresh_confirm()
		_refresh_table_slips()


func _manager() -> RaceManager:
	return get_tree().get_first_node_in_group("race_manager") as RaceManager


func _build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_phase = _label(root, "BETTING OPEN", 22, Vector2(32, 24), BRASS)
	_meet = _label(root, "", 14, Vector2(32, 50), MUTED)
	_window_clock = _label(root, "", 34, Vector2(0, 18), BRASS)
	_window_clock.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_window_clock.offset_left = 280
	_window_clock.offset_right = -280
	_window_clock.offset_top = 16
	_window_clock.offset_bottom = 58
	_window_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_window_clock.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.02, 0.92))
	_window_clock.add_theme_constant_override("outline_size", 8)
	_window_clock.visible = false
	_caps = _label(root, "100  caps", 22, Vector2(0, 24), INK)
	_caps.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_caps.offset_left = -280
	_caps.offset_right = -36
	_caps.offset_top = 24
	_caps.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_bet_slip = _label(root, "No slip", 16, Vector2(32, 72), MUTED)
	_ticket = _build_ticket(root)
	_lock_btn = _btn(root, "LOCK THE WINDOW", Vector2(0, 0), Vector2(280, 42), func() -> void: Game.ring_the_bell())
	_lock_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_lock_btn.offset_left = -360
	_lock_btn.offset_right = -24
	_lock_btn.offset_top = 176
	_lock_btn.offset_bottom = 220
	_lock_btn.visible = false
	_net = _label(root, "", 13, Vector2(0, 52), MUTED)
	_net.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_net.offset_left = -360
	_net.offset_right = -36
	_net.offset_top = 228
	_net.offset_bottom = 248
	_net.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_toast = _label(root, "", 20, Vector2(0, 90), INK)
	_toast.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_toast.offset_left = 80
	_toast.offset_right = -80
	_toast.offset_top = 72
	_toast.offset_bottom = 128
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.modulate.a = 0.0

	_yell_title = _label(root, "", 88, Vector2(0, 96), INK)
	_yell_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_yell_title.offset_left = 80
	_yell_title.offset_right = -80
	_yell_title.offset_top = 88
	_yell_title.offset_bottom = 188
	_yell_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_yell_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_yell_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	_yell_title.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.02, 0.94))
	_yell_title.add_theme_constant_override("outline_size", 16)
	_yell_title.pivot_offset = Vector2(720, 50)
	_yell_title.modulate.a = 0.0
	_yell_title.z_index = 6

	_callout = _label(root, "", 26, Vector2(0, 186), BRASS)
	_callout.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_callout.offset_left = 80
	_callout.offset_right = -80
	_callout.offset_top = 186
	_callout.offset_bottom = 236
	_callout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_callout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_callout.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.02, 0.9))
	_callout.add_theme_constant_override("outline_size", 8)
	_callout.modulate.a = 0.0
	_callout.z_index = 6

	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1.0, 0.94, 0.72, 0.0)
	root.add_child(_flash)

	_countdown = _label(root, "", 128, Vector2(0, 0), INK)
	_countdown.set_anchors_preset(Control.PRESET_CENTER)
	_countdown.offset_left = -240
	_countdown.offset_right = 240
	_countdown.offset_top = -120
	_countdown.offset_bottom = 120
	_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_countdown.pivot_offset = Vector2(240, 120)
	_countdown.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.02, 0.92))
	_countdown.add_theme_constant_override("outline_size", 14)
	_countdown.z_index = 8

	_bang = AudioStreamPlayer.new()
	_bang.bus = "Master"
	add_child(_bang)

	_prompt = _label(root, "", 20, Vector2(0, -70), INK)
	_prompt.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_prompt.offset_top = -78
	_prompt.offset_bottom = -44
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_help = _label(root, "", 14, Vector2(0, -36), MUTED)
	_help.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_help.offset_top = -36
	_help.offset_bottom = -12
	_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_cam_mode = _label(root, "CAMERAS", 16, Vector2(32, 80), Color("c4e08a"))
	_cam_mode.visible = false

	_standings = VBoxContainer.new()
	_standings.position = Vector2(32, 164)
	_standings.visible = false
	root.add_child(_standings)
	_field_card = _build_field_card(root)
	_table_board = _build_table_board(root)

	_binoculars = ColorRect.new()
	_binoculars.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_binoculars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_binoculars.visible = false
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
void fragment() {
	vec2 uv = UV - vec2(0.5);
	uv.x *= 1.7;
	float d1 = length(uv - vec2(-0.22, 0.0));
	float d2 = length(uv - vec2(0.22, 0.0));
	float hole = min(d1, d2);
	float mask = smoothstep(0.30, 0.36, hole);
	COLOR = vec4(0.02, 0.03, 0.02, mask * 0.94);
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = shader
	_binoculars.material = sm
	root.add_child(_binoculars)

	_menu = _build_menu(root)
	_lobby = _build_lobby(root)
	_pause = _build_pause(root)
	_bookie = _build_bookie(root)
	_inspect = _build_inspect(root)
	_results = _build_results(root)
	_coop_ui = _build_coop(root)
	_market_ui = _build_market(root)


func _build_menu(root: Control) -> Control:
	var overlay := ColorRect.new()
	overlay.color = Color(0.42, 0.62, 0.8, 0.38)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(overlay)
	_menu_home = _build_menu_home(overlay)
	_menu_host = _build_menu_host(overlay)
	_menu_join = _build_menu_join(overlay)
	_show_menu_home()
	return overlay


func _build_menu_home(overlay: Control) -> Control:
	var panel := _panel(overlay, Vector2(540, 500))
	var title := _label(panel, "GUTTER ODDS", 42, Vector2(40, 28), INK)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_left = 24
	title.offset_right = -24
	title.offset_top = 24
	title.offset_bottom = 76
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := _label(panel, "Raise them. Race them. Don't finish last.", 18, Vector2(24, 80), MUTED)
	sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sub.offset_left = 24
	sub.offset_right = -24
	sub.offset_top = 78
	sub.offset_bottom = 108
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var blurb := _label(panel, "Buy hens and roosters. Feed them. Breed a clutch.\nWin the Peck Derby, the Comb, and the Long Cluck\nfor the Triple Wing. Last place is dinner.", 15, Vector2(24, 112), INK)
	blurb.set_anchors_preset(Control.PRESET_TOP_WIDE)
	blurb.offset_left = 36
	blurb.offset_right = -36
	blurb.offset_top = 112
	blurb.offset_bottom = 186
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_btn(panel, "Start the day  ·  solo", Vector2(70, 200), Vector2(400, 46), func() -> void: Game.begin_night())
	_btn(panel, "Host a table", Vector2(70, 258), Vector2(400, 46), func() -> void: _show_menu_host())
	_btn(panel, "Join a table", Vector2(70, 316), Vector2(400, 46), func() -> void: _show_menu_join())
	var soon := _label(panel, "Host opens a lobby. Friends join. Then you start the meet.", 13, Vector2(24, 380), MUTED)
	soon.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	soon.offset_left = 24
	soon.offset_right = -24
	soon.offset_top = -70
	soon.offset_bottom = -36
	soon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return panel


func _build_menu_host(overlay: Control) -> Control:
	var panel := _panel(overlay, Vector2(540, 460))
	panel.visible = false
	var title := _label(panel, "HOST A TABLE", 28, Vector2(24, 20), BRASS)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_left = 24
	title.offset_right = -24
	title.offset_top = 18
	title.offset_bottom = 56
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hint := _label(panel, "Open a lobby. Share your IP. Start when the barn's full enough.", 14, Vector2(24, 58), MUTED)
	hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hint.offset_left = 24
	hint.offset_right = -24
	hint.offset_top = 56
	hint.offset_bottom = 88
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(panel, "Your name", 14, Vector2(70, 104), MUTED)
	_host_name = _line(panel, "Trainer", Vector2(70, 126), Vector2(400, 42), _try_host)
	_label(panel, "Port", 14, Vector2(70, 176), MUTED)
	_host_port = _line(panel, str(NetPlay.DEFAULT_PORT), Vector2(70, 198), Vector2(400, 42), _try_host)
	_host_status = _label(panel, "", 14, Vector2(70, 248), BRASS)
	_host_status.size = Vector2(400, 40)
	_host_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_btn(panel, "Open the table", Vector2(70, 300), Vector2(400, 46), _try_host)
	_btn(panel, "Back", Vector2(70, 356), Vector2(400, 42), _show_menu_home)
	return panel


func _build_menu_join(overlay: Control) -> Control:
	var panel := _panel(overlay, Vector2(540, 520))
	panel.visible = false
	var title := _label(panel, "JOIN A TABLE", 28, Vector2(24, 20), BRASS)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_left = 24
	title.offset_right = -24
	title.offset_top = 18
	title.offset_bottom = 56
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hint := _label(panel, "Same PC: 127.0.0.1   ·   LAN: the host's IP.", 14, Vector2(24, 58), MUTED)
	hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hint.offset_left = 24
	hint.offset_right = -24
	hint.offset_top = 56
	hint.offset_bottom = 84
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(panel, "Your name", 14, Vector2(70, 96), MUTED)
	_join_name = _line(panel, "Trainer", Vector2(70, 118), Vector2(400, 42), _try_join)
	_label(panel, "Host IP", 14, Vector2(70, 168), MUTED)
	_join_ip = _line(panel, "127.0.0.1", Vector2(70, 190), Vector2(400, 42), _try_join)
	_label(panel, "Port", 14, Vector2(70, 240), MUTED)
	_join_port = _line(panel, str(NetPlay.DEFAULT_PORT), Vector2(70, 262), Vector2(400, 42), _try_join)
	_join_status = _label(panel, "", 14, Vector2(70, 312), BRASS)
	_join_status.size = Vector2(400, 44)
	_join_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_btn(panel, "Walk over", Vector2(70, 364), Vector2(400, 46), _try_join)
	_btn(panel, "Back", Vector2(70, 420), Vector2(400, 42), _show_menu_home)
	return panel


func _build_lobby(root: Control) -> Control:
	var overlay := ColorRect.new()
	overlay.color = Color(0.42, 0.62, 0.8, 0.38)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(overlay)
	var panel := _panel(overlay, Vector2(560, 620))
	var title := _label(panel, "THE TABLE", 28, Vector2(24, 16), BRASS)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_left = 24
	title.offset_right = -24
	title.offset_top = 14
	title.offset_bottom = 52
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lobby_info = _label(panel, "", 14, Vector2(28, 56), INK)
	_lobby_info.size = Vector2(504, 72)
	_lobby_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(28, 132)
	scroll.size = Vector2(504, 250)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_lobby_list = VBoxContainer.new()
	_lobby_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lobby_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_lobby_list)
	_lobby_hint = _label(panel, "", 13, Vector2(28, 390), MUTED)
	_lobby_hint.size = Vector2(504, 40)
	_lobby_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ready_btn = _btn(panel, "Ready up", Vector2(28, 438), Vector2(248, 44), func() -> void: NetPlay.toggle_ready())
	_start_btn = _btn(panel, "Start the meet", Vector2(284, 438), Vector2(248, 44), func() -> void: NetPlay.request_start())
	_btn(panel, "Copy join address", Vector2(28, 492), Vector2(504, 40), _copy_join_address)
	_btn(panel, "Leave the table", Vector2(28, 542), Vector2(504, 42), func() -> void:
		Game.return_to_menu()
		_show_menu_home()
	)
	return overlay


func _show_menu_home() -> void:
	if NetPlay.is_joining():
		NetPlay.close()
	if _menu_home:
		_menu_home.visible = true
	if _menu_host:
		_menu_host.visible = false
	if _menu_join:
		_menu_join.visible = false


func _show_menu_host() -> void:
	if _menu_home:
		_menu_home.visible = false
	if _menu_host:
		_menu_host.visible = true
	if _menu_join:
		_menu_join.visible = false
	if _host_status:
		_host_status.text = ""


func _show_menu_join() -> void:
	if _menu_home:
		_menu_home.visible = false
	if _menu_host:
		_menu_host.visible = false
	if _menu_join:
		_menu_join.visible = true
	if _join_status:
		_join_status.text = ""


func _try_host() -> void:
	var pname := _host_name.text if _host_name else "Trainer"
	var port := _parse_port(_host_port.text if _host_port else "")
	if not NetPlay.host_table(pname, port):
		if _host_status:
			_host_status.text = NetPlay.status


func _try_join() -> void:
	var pname := _join_name.text if _join_name else "Trainer"
	var ip := _join_ip.text if _join_ip else "127.0.0.1"
	var port := _parse_port(_join_port.text if _join_port else "")
	if _join_status:
		_join_status.text = "Walking over..."
	if not NetPlay.join_table(pname, ip, port):
		if _join_status:
			_join_status.text = NetPlay.status


func _parse_port(text: String) -> int:
	if text.strip_edges().is_valid_int():
		return NetPlay.clamp_port(int(text.strip_edges()))
	return NetPlay.DEFAULT_PORT


func _copy_join_address() -> void:
	var addrs := NetPlay.lan_addresses()
	var ip := "127.0.0.1"
	if not addrs.is_empty():
		ip = addrs[0]
	var text := "%s:%d" % [ip, NetPlay.host_port]
	DisplayServer.clipboard_set(text)
	Game.toast.emit("Copied %s" % text)


func _fill_lobby() -> void:
	if _lobby_list == null:
		return
	for child in _lobby_list.get_children():
		child.queue_free()
	var ids: Array = NetPlay.roster.keys()
	ids.sort()
	if ids.is_empty() and NetPlay.is_online():
		ids.append(NetPlay.local_id())
	for pid in ids:
		var row := Label.new()
		var ready := NetPlay.is_ready(int(pid))
		var host := int(pid) == 1
		var mark := "READY" if ready else "waiting"
		var role := "HOST" if host else "trainer"
		row.text = "  %s   ·   %s   ·   %s" % [NetPlay.trainer_name(int(pid)), role, mark]
		row.add_theme_color_override("font_color", BRASS if ready or host else INK)
		row.add_theme_font_size_override("font_size", 18)
		row.custom_minimum_size = Vector2(480, 32)
		_lobby_list.add_child(row)
	if _lobby_info:
		var lines := PackedStringArray()
		if NetPlay.is_server():
			var lan := NetPlay.lan_addresses()
			lines.append("You're hosting on port %d." % NetPlay.host_port)
			if lan.is_empty():
				lines.append("Same PC: 127.0.0.1")
			else:
				lines.append("LAN: %s" % ", ".join(lan))
				lines.append("Same PC: 127.0.0.1")
		else:
			lines.append("You're at %s's table." % NetPlay.trainer_name(1))
			lines.append("Waiting on the host to start the meet.")
		lines.append("%d / %d trainers" % [NetPlay.seat_count(), NetPlay.MAX_PESTS])
		_lobby_info.text = "\n".join(lines)
	if _lobby_hint:
		_lobby_hint.text = NetPlay.status
	if _ready_btn:
		_ready_btn.text = "Unready" if NetPlay.is_ready() else "Ready up"
	if _start_btn:
		_start_btn.visible = NetPlay.is_server()
		if NetPlay.everyone_ready():
			_start_btn.text = "Start the meet"
			_start_btn.disabled = false
		else:
			_start_btn.text = "Waiting on ready"
			_start_btn.disabled = true


func _build_pause(root: Control) -> Control:
	var overlay := ColorRect.new()
	overlay.color = Color(0.42, 0.62, 0.8, 0.32)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(overlay)
	var panel := _panel(overlay, Vector2(380, 260))
	_label(panel, "PAUSE", 28, Vector2(24, 24), INK).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title := panel.get_child(panel.get_child_count() - 1) as Label
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_left = 20
	title.offset_right = -20
	title.offset_top = 24
	title.offset_bottom = 64
	_btn(panel, "Back to the rail", Vector2(50, 90), Vector2(280, 42), func() -> void: toggle_pause())
	_btn(panel, "Leave the card", Vector2(50, 148), Vector2(280, 42), func() -> void:
		if _paused:
			toggle_pause()
		Game.return_to_menu()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	)
	return overlay


func _build_ticket(root: Control) -> Panel:
	var panel := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = DARK
	style.border_color = BRASS
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -360
	panel.offset_right = -24
	panel.offset_top = 56
	panel.offset_bottom = 168
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if Game.phase == Game.Phase.OPEN:
				open_bookie()
	)
	_ticket_label = _label(panel, "NO SLIP", 16, Vector2(12, 8), INK)
	_ticket_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ticket_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ticket_label.offset_left = 12
	_ticket_label.offset_right = -12
	_ticket_label.offset_top = 8
	_ticket_label.offset_bottom = -8
	root.add_child(panel)
	return panel


func _build_field_card(root: Control) -> Control:
	var panel := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.05, 0.04, 0.88)
	style.border_color = BRASS
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(24, 128)
	panel.size = Vector2(392, 430)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.visible = false
	var title := _label(panel, "THE FIELD", 16, Vector2(14, 8), BRASS)
	title.size = Vector2(360, 24)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(10, 34)
	scroll.size = Vector2(372, 386)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_field_list = VBoxContainer.new()
	_field_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_field_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_field_list)
	root.add_child(panel)
	return panel


func _build_table_board(root: Control) -> Control:
	var panel := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.05, 0.04, 0.88)
	style.border_color = BRASS
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -360
	panel.offset_right = -24
	panel.offset_top = 256
	panel.offset_bottom = 500
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false
	var title := _label(panel, "THE TABLE", 16, Vector2(14, 8), BRASS)
	title.size = Vector2(300, 22)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(10, 32)
	scroll.size = Vector2(316, 200)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(scroll)
	_table_list = VBoxContainer.new()
	_table_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_table_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_table_list)
	root.add_child(panel)
	return panel


func _build_bookie(root: Control) -> Control:
	var overlay := ColorRect.new()
	overlay.color = Color(0.35, 0.52, 0.68, 0.4)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(overlay)
	var panel := _panel(overlay, Vector2(580, 800))
	var title := _label(panel, "THE BOOKIE", 26, Vector2(24, 18), BRASS)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_left = 24
	title.offset_right = -24
	title.offset_top = 16
	title.offset_bottom = 52
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hint := _label(panel, "Name, type, quirks, one tell. Pick a bird before the window slams.", 14, Vector2(24, 52), MUTED)
	hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hint.offset_left = 24
	hint.offset_right = -24
	hint.offset_top = 50
	hint.offset_bottom = 74
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(28, 80)
	scroll.size = Vector2(524, 468)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_bookie_list = VBoxContainer.new()
	_bookie_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bookie_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_bookie_list)
	_stake_label = _label(panel, "Stake: 10 caps", 16, Vector2(28, 556), INK)
	var stake_row := HBoxContainer.new()
	stake_row.position = Vector2(28, 584)
	stake_row.add_theme_constant_override("separation", 8)
	panel.add_child(stake_row)
	_stake_buttons.clear()
	var stakes: Array[int] = [5, 10, 25, 50]
	for amount in stakes:
		var a: int = amount
		var b := _btn(stake_row, str(a), Vector2.ZERO, Vector2(70, 36), func() -> void:
			_stake = a
			_highlight_stakes()
			_refresh_confirm()
		)
		b.custom_minimum_size = Vector2(78, 38)
		_stake_buttons.append(b)
	var all_in := _btn(stake_row, "ALL IN", Vector2.ZERO, Vector2(90, 36), func() -> void:
		_stake = -1
		_highlight_stakes()
		_refresh_confirm()
	)
	all_in.custom_minimum_size = Vector2(100, 38)
	_stake_buttons.append(all_in)
	_confirm_btn = _btn(panel, "Stuff the slip", Vector2(28, 634), Vector2(524, 52), _confirm_bet)
	_confirm_btn.custom_minimum_size = Vector2(524, 52)
	_btn(panel, "Keep this slip  ·  walk away", Vector2(28, 694), Vector2(524, 42), close_panels)
	var note := _label(panel, "Your ticket stays up on the right. Press B to reopen.", 13, Vector2(28, 744), MUTED)
	note.size = Vector2(524, 40)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return overlay


func _build_inspect(root: Control) -> Control:
	var panel := _panel(root, Vector2(460, 420))
	panel.visible = false
	var title := _label(panel, "PADDOCK NOTES", 22, Vector2(24, 16), BRASS)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_left = 24
	title.offset_right = -24
	title.offset_top = 14
	title.offset_bottom = 48
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_inspect_body = RichTextLabel.new()
	_inspect_body.bbcode_enabled = true
	_inspect_body.position = Vector2(28, 60)
	_inspect_body.size = Vector2(404, 190)
	_inspect_body.fit_content = false
	_inspect_body.scroll_active = true
	_inspect_body.add_theme_color_override("default_color", INK)
	panel.add_child(_inspect_body)
	_btn(panel, "Bet on this chicken", Vector2(28, 258), Vector2(404, 42), func() -> void:
		_selected_snail = _inspect_index
		open_bookie()
	)
	_btn(panel, "That's enough looking", Vector2(28, 308), Vector2(404, 42), close_panels)
	return panel


func _build_results(root: Control) -> Control:
	var panel := _panel(root, Vector2(520, 580))
	panel.visible = false
	var title := _label(panel, "THE CARD IS SETTLED", 22, Vector2(24, 16), BRASS)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_left = 24
	title.offset_right = -24
	title.offset_top = 14
	title.offset_bottom = 48
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_results_body = RichTextLabel.new()
	_results_body.bbcode_enabled = true
	_results_body.position = Vector2(28, 52)
	_results_body.size = Vector2(464, 330)
	_results_body.add_theme_color_override("default_color", INK)
	panel.add_child(_results_body)
	_next_card_btn = _btn(panel, "DEAL THE NEXT CARD", Vector2(28, 400), Vector2(464, 58), func() -> void:
		_results.visible = false
		Game.request_next_race()
	)
	_next_card_btn.custom_minimum_size = Vector2(464, 58)
	_next_card_btn.add_theme_font_size_override("font_size", 20)
	_next_card_btn.modulate = Color("e8d5a0")
	_results_hint = _label(panel, "or it deals itself in 7", 15, Vector2(28, 468), MUTED)
	_results_hint.size = Vector2(464, 36)
	_results_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_results_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return panel


func _build_coop(root: Control) -> Control:
	var overlay := ColorRect.new()
	overlay.color = Color(0.35, 0.52, 0.68, 0.4)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(overlay)
	var panel := _panel(overlay, Vector2(580, 720))
	var title := _label(panel, "YOUR COOP", 26, Vector2(24, 16), BRASS)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_left = 24
	title.offset_right = -24
	title.offset_top = 14
	title.offset_bottom = 50
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hint := _label(panel, "Feed them. A clutch needs a hen, a rooster, and grit.", 13, Vector2(24, 50), MUTED)
	hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hint.offset_left = 24
	hint.offset_right = -24
	hint.offset_top = 46
	hint.offset_bottom = 68
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shed_line = _label(panel, "", 13, Vector2(24, 66), INK)
	_shed_line.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_shed_line.offset_left = 24
	_shed_line.offset_right = -24
	_shed_line.offset_top = 66
	_shed_line.offset_bottom = 88
	_shed_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(24, 90)
	scroll.size = Vector2(532, 168)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_coop_list = VBoxContainer.new()
	_coop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_coop_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_coop_list)
	_coop_detail = RichTextLabel.new()
	_coop_detail.bbcode_enabled = true
	_coop_detail.position = Vector2(24, 264)
	_coop_detail.size = Vector2(532, 108)
	_coop_detail.add_theme_color_override("default_color", INK)
	panel.add_child(_coop_detail)
	_btn(panel, "Enter today's card", Vector2(24, 380), Vector2(258, 36), func() -> void:
		if not _coop_selected.is_empty():
			Game.enter_chicken(_coop_selected)
			_fill_coop()
	)
	_btn(panel, "Scratch", Vector2(298, 380), Vector2(258, 36), func() -> void:
		Game.scratch_chicken()
		_fill_coop()
	)
	_btn(panel, "Train  ·  %d caps" % ChickenStock.TRAIN_COST, Vector2(24, 422), Vector2(258, 36), func() -> void:
		if not _coop_selected.is_empty():
			Game.train_chicken(_coop_selected)
			_fill_coop()
	)
	_btn(panel, "Sell", Vector2(298, 422), Vector2(258, 36), func() -> void:
		if not _coop_selected.is_empty():
			Game.sell_chicken(_coop_selected)
			_coop_selected = ""
			_fill_coop()
	)
	_btn(panel, "Feed scratch", Vector2(24, 464), Vector2(258, 36), func() -> void:
		if not _coop_selected.is_empty():
			Game.feed_chicken(_coop_selected, "scratch")
	)
	_btn(panel, "Feed mash", Vector2(298, 464), Vector2(258, 36), func() -> void:
		if not _coop_selected.is_empty():
			Game.feed_chicken(_coop_selected, "mash")
	)
	_btn(panel, "Give grit", Vector2(24, 506), Vector2(258, 36), func() -> void:
		if not _coop_selected.is_empty():
			Game.feed_chicken(_coop_selected, "grit")
	)
	_btn(panel, "Yard tonic", Vector2(298, 506), Vector2(258, 36), func() -> void:
		if not _coop_selected.is_empty():
			Game.feed_chicken(_coop_selected, "tonic")
	)
	_btn(panel, "Pour scratch in pans", Vector2(24, 548), Vector2(258, 36), func() -> void:
		Game.pour_yard_feed()
	)
	_btn(panel, "Mark for clutch", Vector2(298, 548), Vector2(258, 36), func() -> void:
		_toggle_breed(_coop_selected)
	)
	_btn(panel, "Hatch clutch  ·  %d caps + grit" % ChickenStock.BREED_COST, Vector2(24, 590), Vector2(532, 40), func() -> void:
		if not _breed_hen.is_empty() and not _breed_rooster.is_empty():
			if Game.breed_chickens(_breed_hen, _breed_rooster):
				_breed_hen = ""
				_breed_rooster = ""
			_fill_coop()
	)
	_btn(panel, "Back to the yard", Vector2(24, 640), Vector2(532, 42), close_panels)
	return overlay


func _build_market(root: Control) -> Control:
	var overlay := ColorRect.new()
	overlay.color = Color(0.35, 0.52, 0.68, 0.4)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(overlay)
	var panel := _panel(overlay, Vector2(560, 640))
	var title := _label(panel, "MARKET & FEED SHED", 24, Vector2(24, 16), BRASS)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_left = 24
	title.offset_right = -24
	title.offset_top = 14
	title.offset_bottom = 48
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_market_hint = _label(panel, "", 13, Vector2(24, 48), MUTED)
	_market_hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_market_hint.offset_left = 20
	_market_hint.offset_right = -20
	_market_hint.offset_top = 46
	_market_hint.offset_bottom = 78
	_market_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_market_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(24, 84)
	scroll.size = Vector2(512, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_market_list = VBoxContainer.new()
	_market_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_market_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_market_list)
	_btn(panel, "Walk away", Vector2(24, 564), Vector2(512, 42), close_panels)
	return overlay


func open_coop() -> void:
	if Game.is_sitting():
		return
	_fill_coop()
	_coop_ui.visible = true
	_market_ui.visible = false
	_bookie.visible = false
	_inspect.visible = false
	Game.set_ui_open(true)
	_refresh_field_card()


func open_market() -> void:
	if Game.is_sitting():
		return
	_fill_market()
	_market_ui.visible = true
	_coop_ui.visible = false
	_bookie.visible = false
	_inspect.visible = false
	Game.set_ui_open(true)
	_refresh_field_card()


func _on_coop_changed() -> void:
	if _coop_ui and _coop_ui.visible:
		_fill_coop()
	if _market_ui and _market_ui.visible:
		_fill_market()
	_refresh_meet()


func _on_market_changed() -> void:
	if _market_ui and _market_ui.visible:
		_fill_market()
	if _coop_ui and _coop_ui.visible:
		_fill_coop()


func _on_net(text: String) -> void:
	if _net:
		_net.text = text if not Game.is_sitting() else ""
	if _join_status and _menu_join and _menu_join.visible:
		_join_status.text = text
	if _host_status and _menu_host and _menu_host.visible:
		_host_status.text = text
	if Game.phase == Game.Phase.LOBBY:
		_fill_lobby()


func _refresh_meet() -> void:
	if _meet == null:
		return
	if Game.is_sitting():
		_meet.text = ""
		return
	var race := Game.current_race()
	var jewels := ""
	for bird in Game.coop:
		var flags := int(bird.get("wing_flags", 0))
		if flags > 0:
			jewels = ChickenStock.wing_title(bird)
			break
	var extra := "  ·  %s" % jewels if not jewels.is_empty() else ""
	_meet.text = "%s  ·  %s  ·  %s min  ·  purse %d%s" % [
		RaceChaos.condition_name(Game.card_condition()),
		race.get("subtitle", ""),
		ChickenStock.grade_name(int(race.get("min_grade", 0))),
		int(race.get("purse", 0)),
		extra,
	]
	if Game.phase == Game.Phase.OPEN:
		_phase.text = "%s  ·  %s" % [Game.race_name().to_upper(), RaceChaos.condition_name(Game.card_condition()).to_upper()]
	elif Game.phase == Game.Phase.RACE:
		_phase.text = "LIVE · %s  ·  %s" % [Game.race_name(), RaceChaos.condition_name(Game.card_condition()).to_upper()]
	_refresh_loop_clocks()


func _refresh_loop_clocks() -> void:
	if _window_clock:
		if Game.phase == Game.Phase.OPEN:
			var secs := Game.open_secs_left()
			_window_clock.visible = true
			_window_clock.text = "WINDOW  %d:%02d" % [int(secs / 60), secs % 60]
			_window_clock.add_theme_color_override("font_color", Color("e8c03a") if secs <= 5 else BRASS)
		else:
			_window_clock.visible = false
			_window_clock.text = ""
	if _lock_btn:
		_lock_btn.visible = Game.phase == Game.Phase.OPEN
		if _lock_btn.visible:
			_lock_btn.text = "LOCK THE WINDOW" if not NetPlay.is_client() else "YELL FOR THE BELL"
	if _results_hint and _results and _results.visible:
		var left := Game.results_secs_left()
		if NetPlay.is_client():
			_results_hint.text = "Smash DEAL THE NEXT CARD  ·  or wait on the host."
		elif left > 0:
			_results_hint.text = "or it deals itself in %d" % left
		else:
			_results_hint.text = "Dealing the next card..."


func _fill_coop() -> void:
	if _coop_list == null:
		return
	_refresh_shed_line()
	for child in _coop_list.get_children():
		child.queue_free()
	if Game.coop.is_empty():
		var empty := Label.new()
		empty.text = "Empty crates. Market's west of the paddock. Buy a hen and a rooster."
		empty.add_theme_color_override("font_color", MUTED)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_coop_list.add_child(empty)
		if _coop_detail:
			_coop_detail.text = ""
		return
	for bird in Game.coop:
		var id := str(bird.get("id", ""))
		var row := Button.new()
		var on_card := "  CARD" if id == Game.entered_id else ""
		var nest := "  NEST" if bool(bird.get("nest_rest", false)) else ""
		var marked := ""
		if id == _breed_hen:
			marked = "  HEN"
		elif id == _breed_rooster:
			marked = "  ROOSTER"
		row.text = "%s  ·  %s  ·  %s  ·  h%d%s%s%s" % [
			bird.get("name", "Chicken"),
			ChickenStock.sex_name(bird),
			ChickenStock.grade_name(int(bird.get("grade", 0))),
			int(float(bird.get("hunger", 70.0))),
			on_card,
			nest,
			marked,
		]
		row.custom_minimum_size = Vector2(510, 40)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_style_button(row)
		row.modulate = BRASS if id == _coop_selected else Color.WHITE
		var pick: String = id
		row.pressed.connect(func() -> void:
			_coop_selected = pick
			_fill_coop()
		)
		_coop_list.add_child(row)
	_refresh_coop_detail()


func _refresh_shed_line() -> void:
	if _shed_line == null:
		return
	_shed_line.text = "Shed  scratch %d  ·  mash %d  ·  grit %d  ·  tonic %d   pans %d%%" % [
		Game.shed_count("scratch"),
		Game.shed_count("mash"),
		Game.shed_count("grit"),
		Game.shed_count("tonic"),
		int(Game.yard_feed),
	]


func _refresh_coop_detail() -> void:
	if _coop_detail == null:
		return
	_coop_detail.clear()
	var bird := Game.find_chicken(_coop_selected)
	if bird.is_empty():
		_coop_detail.append_text("Pick a bird.")
		return
	var wing := ChickenStock.wing_title(bird)
	_coop_detail.append_text("[b]%s[/b]  ·  %s  ·  %s\n" % [
		bird.get("name", ""),
		ChickenStock.sex_name(bird),
		ChickenStock.grade_name(int(bird.get("grade", 0))),
	])
	_coop_detail.append_text("Form %.2f (runs %.2f)  ·  trained %d  ·  %d-for-%d\n" % [
		float(bird.get("form", 1.0)),
		ChickenStock.race_form(bird),
		int(bird.get("training", 0)),
		int(bird.get("wins", 0)),
		int(bird.get("races", 0)),
	])
	_coop_detail.append_text("Hunger %d  ·  condition %d" % [
		int(float(bird.get("hunger", 70.0))),
		int(float(bird.get("condition", 70.0))),
	])
	if bool(bird.get("nest_rest", false)):
		_coop_detail.append_text("  ·  [color=#e8c03a]on the nest[/color]")
	if not wing.is_empty():
		_coop_detail.append_text("  ·  %s" % wing)
	_coop_detail.append_text("\n%s\n" % ChickenStock.trait_block(bird))
	_coop_detail.append_text("Sells for %d caps." % ChickenStock.sell_price(bird))
	var hen := Game.find_chicken(_breed_hen)
	var rooster := Game.find_chicken(_breed_rooster)
	if not hen.is_empty() or not rooster.is_empty():
		_coop_detail.append_text("\nClutch: %s  ×  %s" % [
			hen.get("name", "need a hen"),
			rooster.get("name", "need a rooster"),
		])


func _toggle_breed(chicken_id: String) -> void:
	if chicken_id.is_empty():
		return
	var bird := Game.find_chicken(chicken_id)
	if bird.is_empty():
		return
	if ChickenStock.is_hen(bird):
		_breed_hen = "" if _breed_hen == chicken_id else chicken_id
	else:
		_breed_rooster = "" if _breed_rooster == chicken_id else chicken_id
	_fill_coop()


func _fill_market() -> void:
	if _market_list == null:
		return
	for child in _market_list.get_children():
		child.queue_free()
	if _market_hint:
		_market_hint.text = "Scratch %d  ·  mash %d  ·  grit %d  ·  tonic %d\nHens, roosters, and the grain they live on." % [
			Game.shed_count("scratch"),
			Game.shed_count("mash"),
			Game.shed_count("grit"),
			Game.shed_count("tonic"),
		]
	var shed := Label.new()
	shed.text = "FEED SHED"
	shed.add_theme_color_override("font_color", BRASS)
	shed.add_theme_font_size_override("font_size", 16)
	_market_list.add_child(shed)
	for row in ChickenStock.SUPPLIES:
		var kind := str(row.get("id", ""))
		var btn := Button.new()
		btn.text = "  %s    %d caps    have %d\n  %s" % [
			row.get("name", "Feed"),
			int(row.get("price", 0)),
			Game.shed_count(kind),
			row.get("blurb", ""),
		]
		btn.custom_minimum_size = Vector2(490, 56)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_style_button(btn)
		var pick: String = kind
		btn.pressed.connect(func() -> void:
			Game.buy_supply(pick)
		)
		_market_list.add_child(btn)
	var birds := Label.new()
	birds.text = "BIRDS"
	birds.add_theme_color_override("font_color", BRASS)
	birds.add_theme_font_size_override("font_size", 16)
	_market_list.add_child(birds)
	if Game.market.is_empty():
		var empty := Label.new()
		empty.text = "Crate's empty until the next card."
		empty.add_theme_color_override("font_color", MUTED)
		_market_list.add_child(empty)
		return
	for i in Game.market.size():
		var listing: Dictionary = Game.market[i]
		var idx: int = i
		var price := ChickenStock.buy_price(int(listing.get("grade", 0)))
		var bird_btn := Button.new()
		bird_btn.text = "  %s   %s %s    %d caps\n  %s" % [
			listing.get("name", "Chicken"),
			ChickenStock.sex_name(listing),
			ChickenStock.grade_name(int(listing.get("grade", 0))),
			price,
			ChickenStock.trait_summary(listing),
		]
		bird_btn.custom_minimum_size = Vector2(490, 56)
		bird_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_style_button(bird_btn)
		bird_btn.pressed.connect(func() -> void:
			if Game.buy_listing(idx):
				_fill_market()
		)
		_market_list.add_child(bird_btn)


func _punch_yell() -> void:
	if _yell_title == null:
		return
	_yell_title.pivot_offset = _yell_title.size * 0.5
	_yell_title.scale = Vector2(1.55, 1.55)
	if _yell_tween:
		_yell_tween.kill()
	_yell_tween = create_tween()
	_yell_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_yell_tween.tween_property(_yell_title, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _play_chaos_sting(event_id: int) -> void:
	if _bang == null:
		return
	if event_id == RaceChaos.LiveEvent.FALSE_GUN or event_id == RaceChaos.LiveEvent.RACCOON_SNIPER:
		_play_gun()
		return
	var rate := 22050
	var nframes := int(rate * (0.34 if event_id > 0 else 0.18))
	var samples := PackedFloat32Array()
	samples.resize(nframes)
	var rng := RandomNumberGenerator.new()
	rng.seed = 40 + event_id
	for i in nframes:
		var t := float(i) / float(rate)
		var s := 0.0
		match event_id:
			RaceChaos.LiveEvent.HAWK, RaceChaos.LiveEvent.HAWK_DIVE:
				s = sin(TAU * (980.0 - t * 420.0) * t) * exp(-t * 6.5) * 0.72
				s += sin(TAU * 1480.0 * t) * exp(-t * 14.0) * 0.28
				if event_id == RaceChaos.LiveEvent.HAWK_DIVE:
					s += sin(TAU * (1600.0 - t * 900.0) * t) * exp(-t * 5.2) * 0.42
			RaceChaos.LiveEvent.CORN_RAIN:
				s = (rng.randf() * 2.0 - 1.0) * exp(-fmod(t * 18.0, 1.0) * 8.0) * 0.55
				s += sin(TAU * 240.0 * t) * exp(-t * 5.0) * 0.22
			RaceChaos.LiveEvent.OIL_SLICK:
				s = sin(TAU * 62.0 * t) * exp(-t * 7.0) * 0.7
				s += (rng.randf() * 2.0 - 1.0) * exp(-t * 10.0) * 0.28
			RaceChaos.LiveEvent.LOOSE_DOG:
				s = sin(TAU * (220.0 + t * 80.0) * t) * exp(-t * 9.0) * 0.7
				s += sin(TAU * 90.0 * t) * exp(-t * 6.0) * 0.35
			RaceChaos.LiveEvent.CROWD_SQUEEZE:
				s = (rng.randf() * 2.0 - 1.0) * exp(-t * 4.2) * 0.4
				s += sin(TAU * 48.0 * t) * exp(-t * 3.4) * 0.55
			RaceChaos.LiveEvent.LAWN_CHAIR:
				s = (rng.randf() * 2.0 - 1.0) * exp(-fmod(t * 12.0, 1.0) * 6.0) * 0.58
				s += sin(TAU * 90.0 * t) * exp(-t * 5.5) * 0.32
			RaceChaos.LiveEvent.BOTTLE_ROCKET:
				s = sin(TAU * (420.0 + t * 980.0) * t) * exp(-t * 3.8) * 0.62
				s += (rng.randf() * 2.0 - 1.0) * exp(-t * 8.0) * 0.28
			_:
				s = sin(TAU * 420.0 * t) * exp(-t * 10.0) * 0.45
		samples[i] = clampf(s, -1.0, 1.0)
	_bang.stream = _pcm16(samples, rate)
	_bang.volume_db = -4.0
	_bang.play()


func _punch_count(from_scale: float) -> void:
	if _countdown == null:
		return
	_countdown.scale = Vector2(from_scale, from_scale)
	if _count_tween:
		_count_tween.kill()
	_count_tween = create_tween()
	_count_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_count_tween.tween_property(_countdown, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _fade_go() -> void:
	if _countdown == null:
		return
	if _count_tween:
		_count_tween.kill()
	_count_tween = create_tween()
	_count_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_count_tween.tween_property(_countdown, "modulate:a", 0.0, 0.28)
	_count_tween.tween_callback(func() -> void:
		if _countdown:
			_countdown.text = ""
			_countdown.scale = Vector2.ONE
			_countdown.modulate.a = 1.0
		_go_linger = 0.0
	)


func _clear_count() -> void:
	_go_linger = 0.0
	if _count_tween:
		_count_tween.kill()
		_count_tween = null
	if _countdown:
		_countdown.text = ""
		_countdown.scale = Vector2.ONE
		_countdown.modulate.a = 1.0


func _play_tick(n: int) -> void:
	if _bang == null:
		return
	var rate := 22050
	var nframes := int(rate * 0.12)
	var samples := PackedFloat32Array()
	samples.resize(nframes)
	var hz := 640.0 + float(4 - n) * 170.0
	for i in nframes:
		var t := float(i) / float(rate)
		var env := exp(-t * 26.0)
		var click := exp(-t * 80.0) * (randf() * 2.0 - 1.0) * 0.28
		samples[i] = sin(TAU * hz * t) * env * 0.62 + click
	_bang.stream = _pcm16(samples, rate)
	_bang.volume_db = -6.0
	_bang.play()


func _play_gun() -> void:
	if _bang == null:
		return
	var rate := 22050
	var nframes := int(rate * 0.46)
	var samples := PackedFloat32Array()
	samples.resize(nframes)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in nframes:
		var t := float(i) / float(rate)
		var crack := (rng.randf() * 2.0 - 1.0) * exp(-t * 38.0)
		var snap := (rng.randf() * 2.0 - 1.0) * exp(-t * 88.0)
		var boom := sin(TAU * 76.0 * t) * exp(-t * 8.5) * 0.78
		var body := sin(TAU * 128.0 * t) * exp(-t * 13.0) * 0.32
		samples[i] = clampf(crack * 0.9 + snap * 0.5 + boom + body, -1.0, 1.0)
	_bang.stream = _pcm16(samples, rate)
	_bang.volume_db = -1.5
	_bang.play()


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
	return stream


func _panel(parent: Node, size: Vector2) -> Panel:
	var panel := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = DARK
	style.border_color = BRASS
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = size
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -size.x * 0.5
	panel.offset_right = size.x * 0.5
	panel.offset_top = -size.y * 0.5
	panel.offset_bottom = size.y * 0.5
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(panel)
	return panel


func _label(parent: Node, text: String, size: int, pos: Vector2, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _btn(parent: Node, text: String, pos: Vector2, size: Vector2, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = size
	_style_button(b)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _line(parent: Node, text: String, pos: Vector2, size: Vector2, on_submit: Callable = Callable()) -> LineEdit:
	var e := LineEdit.new()
	e.text = text
	e.position = pos
	e.size = size
	e.max_length = 32
	e.caret_blink = true
	e.add_theme_color_override("font_color", INK)
	e.add_theme_color_override("font_placeholder_color", MUTED)
	e.add_theme_color_override("caret_color", BRASS)
	var n := StyleBoxFlat.new()
	n.bg_color = Color("2b1b12")
	n.border_color = BRASS
	n.set_border_width_all(1)
	n.set_corner_radius_all(4)
	n.content_margin_left = 12
	n.content_margin_right = 12
	n.content_margin_top = 8
	n.content_margin_bottom = 8
	e.add_theme_stylebox_override("normal", n)
	e.add_theme_stylebox_override("focus", n)
	e.add_theme_font_size_override("font_size", 16)
	if on_submit.is_valid():
		e.text_submitted.connect(func(_t: String) -> void: on_submit.call())
	parent.add_child(e)
	return e


func _style_button(b: Button) -> void:
	var n := StyleBoxFlat.new()
	n.bg_color = Color("2b1b12")
	n.border_color = BRASS
	n.set_border_width_all(1)
	n.set_corner_radius_all(4)
	n.content_margin_left = 12
	n.content_margin_right = 12
	n.content_margin_top = 8
	n.content_margin_bottom = 8
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = Color("3d2a18")
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_font_size_override("font_size", 16)
