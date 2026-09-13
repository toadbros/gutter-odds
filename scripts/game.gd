extends Node

enum Phase { MENU, OPEN, COUNTDOWN, RACE, RESULTS, LOBBY }

signal phase_changed(phase: Phase)
signal money_changed(amount: int)
signal bet_changed
signal vip_changed(owned: bool)
signal toast(text: String)
signal callout(text: String)
signal countdown_tick(seconds_left: int)
signal bookie_requested
signal inspect_requested(pen_index: int)
signal vip_enter_requested
signal results_ready(payload: Dictionary)
signal coop_changed
signal market_changed
signal meet_changed
signal coop_requested
signal market_requested
signal event_callout(text: String, event_id: int)

const STARTING_CAPS := 100
const VIP_COST := 25
const MERCY_LOAN := 20
const FIELD_SIZE := 6
const TRACK_RX := 15.0
const TRACK_RZ := 10.0
const TRACK_WIDTH := 4.2
# Dirt walking surface. Path Y used to sit at 0.22 while the oval mesh
# topped out at ~0.45, which sank the field "underwater."
const TRACK_SURFACE_Y := 0.45
const TRACK_STAND_LIFT := 0.02
const COUNT_BEAT := 1.15
const OPEN_WINDOW := 32.0
const RESULTS_BEAT := 7.0

var phase: Phase = Phase.MENU
var bottlecaps: int = STARTING_CAPS
var vip_owned: bool = false
var bet_index: int = -1
var bet_amount: int = 0
var countdown: float = 0.0
var open_clock: float = 0.0
var results_clock: float = 0.0
var _count_shown: int = -1
var ui_open: bool = false
var last_results: Dictionary = {}
var _announce_cd: float = 0.0
var coop: Array[Dictionary] = []
var market: Array[Dictionary] = []
var supplies: Dictionary = ChickenStock.empty_shed()
var yard_feed: float = 0.0
var entered_id: String = ""
var meet_index: int = 0
var _first_card: bool = true


func _ready() -> void:
	randomize()
	_bind_inputs()
	money_changed.emit(bottlecaps)


func _process(delta: float) -> void:
	_announce_cd = maxf(_announce_cd - delta, 0.0)
	match phase:
		Phase.OPEN:
			_tick_open_window(delta)
		Phase.COUNTDOWN:
			_tick_countdown(delta)
		Phase.RESULTS:
			_tick_results_beat(delta)
		_:
			pass


func is_sitting() -> bool:
	return phase == Phase.MENU or phase == Phase.LOBBY


func is_live_card() -> bool:
	return phase == Phase.COUNTDOWN or phase == Phase.RACE or phase == Phase.RESULTS


func enter_lobby() -> void:
	ui_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_set_phase(Phase.LOBBY)
	toast.emit("Sit tight. The host starts the meet.")


func begin_night() -> void:
	bottlecaps = STARTING_CAPS
	vip_owned = false
	bet_amount = 0
	bet_index = -1
	coop.clear()
	supplies = ChickenStock.empty_shed()
	supplies["scratch"] = 2
	yard_feed = 35.0
	entered_id = ""
	meet_index = 0
	_first_card = true
	vip_changed.emit(false)
	money_changed.emit(bottlecaps)
	bet_changed.emit()
	coop_changed.emit()
	market_changed.emit()
	new_round()
	_capture_mouse()
	toast.emit("Buy a hen and a rooster. Keep them fed. Last place hits the fryer.")


func begin_guest() -> void:
	if not is_sitting():
		return
	bottlecaps = STARTING_CAPS
	vip_owned = false
	bet_amount = 0
	bet_index = -1
	coop.clear()
	supplies = ChickenStock.empty_shed()
	supplies["scratch"] = 2
	yard_feed = 35.0
	entered_id = ""
	vip_changed.emit(false)
	money_changed.emit(bottlecaps)
	bet_changed.emit()
	coop_changed.emit()
	market_changed.emit()
	_set_phase(Phase.OPEN)
	set_ui_open(false)
	_capture_mouse()
	toast.emit("You're at their table. Buy a hen, a rooster, and some grain.")


func new_round() -> void:
	if _first_card:
		_first_card = false
	else:
		meet_index = (meet_index + 1) % ChickenStock.SCHEDULE.size()
		if meet_index == 0:
			_new_meet()
	bet_amount = 0
	bet_index = -1
	entered_id = ""
	last_results = {}
	if not _first_card:
		_wear_coop()
	if not NetPlay.is_client():
		NetPlay.entries.clear()
	bet_changed.emit()
	_roll_market()
	open_clock = OPEN_WINDOW
	results_clock = 0.0
	_set_phase(Phase.OPEN)
	get_tree().call_group("race_manager", "deal_field")
	get_tree().call_group("race_director", "deactivate")
	set_ui_open(false)
	meet_changed.emit()
	NetPlay.broadcast_meet()


func current_race() -> Dictionary:
	return ChickenStock.current_meet(meet_index)


func race_name() -> String:
	return str(current_race().get("name", "Today's card"))


func race_min_grade() -> int:
	return int(current_race().get("min_grade", 0))


func race_purse() -> int:
	return int(current_race().get("purse", 0))


func race_wing_index() -> int:
	return int(current_race().get("wing", -1))


func card_condition() -> int:
	var manager = get_tree().get_first_node_in_group("race_manager")
	if manager:
		return int(manager.card_condition)
	return 0


func pack_meet() -> Dictionary:
	var chaos := {}
	var manager = get_tree().get_first_node_in_group("race_manager")
	if manager and manager.has_method("pack_chaos"):
		chaos = manager.pack_chaos()
	return {
		"phase": int(phase),
		"meet_index": meet_index,
		"countdown": countdown if phase == Phase.COUNTDOWN else 0.0,
		"open_clock": open_clock,
		"results_clock": results_clock,
		"first_card": _first_card,
		"card_condition": int(chaos.get("card_condition", 0)),
		"event_id": int(chaos.get("event_id", 0)),
		"event_t": float(chaos.get("event_t", 0.0)),
		"event_dur": float(chaos.get("event_dur", 0.0)),
		"event_at": float(chaos.get("event_at", 0.0)),
	}


func apply_meet(payload: Dictionary) -> void:
	meet_index = int(payload.get("meet_index", meet_index))
	_first_card = bool(payload.get("first_card", _first_card))
	open_clock = float(payload.get("open_clock", open_clock))
	results_clock = float(payload.get("results_clock", results_clock))
	var next_phase: Phase = int(payload.get("phase", phase)) as Phase
	var prev := phase
	# Roster / field sync mid-race must not drop survivors back into countdown residue.
	if prev == Phase.RACE and next_phase == Phase.COUNTDOWN:
		next_phase = Phase.RACE
	elif prev == Phase.RESULTS and next_phase == Phase.COUNTDOWN:
		next_phase = Phase.RESULTS
	if is_sitting() and next_phase != Phase.MENU and next_phase != Phase.LOBBY:
		begin_guest()
	if next_phase == Phase.COUNTDOWN and prev != Phase.RACE and prev != Phase.RESULTS:
		countdown = float(payload.get("countdown", COUNT_BEAT * 3.0))
		var shown := 0 if countdown <= 0.0 else clampi(int(ceil(countdown / COUNT_BEAT)), 0, 3)
		var entering := prev != Phase.COUNTDOWN
		_count_shown = shown
		if entering:
			countdown_tick.emit(shown)
	if next_phase != Phase.MENU and next_phase != Phase.LOBBY:
		_set_phase(next_phase)
	if next_phase == Phase.OPEN:
		if prev != Phase.OPEN:
			set_ui_open(false)
			get_tree().call_group("race_director", "deactivate")
	elif next_phase == Phase.COUNTDOWN:
		if prev != Phase.COUNTDOWN:
			get_tree().call_group("race_director", "activate")
			get_tree().call_group("race_manager", "move_to_gates")
	elif next_phase == Phase.RACE:
		get_tree().call_group("race_director", "activate")
		if prev != Phase.RACE:
			get_tree().call_group("race_manager", "start_race")
	elif next_phase == Phase.RESULTS:
		if prev != Phase.RESULTS:
			get_tree().call_group("race_director", "deactivate")
	var manager = get_tree().get_first_node_in_group("race_manager")
	if manager and manager.has_method("apply_chaos_state"):
		manager.apply_chaos_state(payload)
	meet_changed.emit()


func clear_bet() -> void:
	if bet_amount > 0:
		bottlecaps += bet_amount
		bet_amount = 0
		bet_index = -1
		money_changed.emit(bottlecaps)
		bet_changed.emit()
		return
	bet_amount = 0
	bet_index = -1
	bet_changed.emit()


func place_bet(index: int, amount: int) -> bool:
	if phase != Phase.OPEN:
		toast.emit("Too late. They're lining up.")
		return false
	if index < 0 or amount <= 0:
		return false
	if amount > bottlecaps + bet_amount:
		toast.emit("That's more tin than you've got.")
		return false
	if bet_amount > 0:
		bottlecaps += bet_amount
	bottlecaps -= amount
	bet_index = index
	bet_amount = amount
	money_changed.emit(bottlecaps)
	bet_changed.emit()
	toast.emit("Slip taken: %d caps on #%d." % [amount, index + 1])
	return true


func potential_payout() -> int:
	if bet_amount <= 0:
		return 0
	var manager = get_tree().get_first_node_in_group("race_manager")
	if manager == null or bet_index < 0 or bet_index >= manager.field.size():
		return bet_amount
	var odds: Vector2i = manager.field[bet_index].odds
	return bet_amount + int(bet_amount * odds.x / maxi(odds.y, 1))


func buy_vip() -> bool:
	if vip_owned:
		return true
	if bottlecaps < VIP_COST:
		return false
	bottlecaps -= VIP_COST
	vip_owned = true
	money_changed.emit(bottlecaps)
	vip_changed.emit(true)
	toast.emit("The box seats are yours. Try the binoculars.")
	return true


func buy_listing(index: int) -> bool:
	if is_sitting():
		return false
	if index < 0 or index >= market.size():
		return false
	if coop.size() >= ChickenStock.COOP_CAP:
		toast.emit("Coop's full. Sell one or fry one.")
		return false
	var listing: Dictionary = market[index]
	var price := ChickenStock.buy_price(int(listing.get("grade", 0)))
	if bottlecaps < price:
		toast.emit("The dealer waits. Your tin does not.")
		return false
	bottlecaps -= price
	var bird := ChickenStock.duplicate_bird(listing)
	bird["id"] = ChickenStock.next_id()
	bird["owner_id"] = NetPlay.local_id()
	coop.append(bird)
	market.remove_at(index)
	money_changed.emit(bottlecaps)
	coop_changed.emit()
	market_changed.emit()
	toast.emit("%s is yours. Don't get attached." % bird["name"])
	return true


func sell_chicken(chicken_id: String) -> bool:
	var bird := find_chicken(chicken_id)
	if bird.is_empty():
		return false
	if chicken_id == entered_id:
		toast.emit("They're on the card. Scratch them first.")
		return false
	var price := ChickenStock.sell_price(bird)
	bottlecaps += price
	_remove_chicken(chicken_id)
	money_changed.emit(bottlecaps)
	coop_changed.emit()
	toast.emit("Sold %s for %d caps." % [bird["name"], price])
	return true


func train_chicken(chicken_id: String) -> bool:
	if phase != Phase.OPEN:
		toast.emit("Not now. The yard's closed.")
		return false
	if chicken_id == entered_id:
		toast.emit("They're already in the paddock.")
		return false
	if bottlecaps < ChickenStock.TRAIN_COST:
		toast.emit("Training costs corn. Corn costs caps.")
		return false
	for i in coop.size():
		if str(coop[i].get("id", "")) != chicken_id:
			continue
		var before := int(coop[i].get("grade", 0))
		bottlecaps -= ChickenStock.TRAIN_COST
		coop[i] = ChickenStock.apply_training(coop[i])
		money_changed.emit(bottlecaps)
		coop_changed.emit()
		if int(coop[i]["grade"]) > before:
			toast.emit("%s graded up to %s." % [coop[i]["name"], ChickenStock.grade_name(int(coop[i]["grade"]))])
		else:
			toast.emit("%s ran laps until it meant it." % coop[i]["name"])
		return true
	return false


func breed_chickens(id_a: String, id_b: String) -> bool:
	if phase != Phase.OPEN:
		toast.emit("They'll wait until the card's over.")
		return false
	if id_a == id_b:
		return false
	if coop.size() >= ChickenStock.COOP_CAP:
		toast.emit("No spare crate for a chick.")
		return false
	if bottlecaps < ChickenStock.BREED_COST:
		toast.emit("Breeding isn't free. The bookie taught us that.")
		return false
	if id_a == entered_id or id_b == entered_id:
		toast.emit("Can't breed a bird that's on the card.")
		return false
	var a := find_chicken(id_a)
	var b := find_chicken(id_b)
	if a.is_empty() or b.is_empty():
		return false
	var err := ChickenStock.pair_error(a, b)
	if not err.is_empty():
		toast.emit(err)
		return false
	if int(supplies.get("grit", 0)) < 1:
		toast.emit("Need a sack of grit for the clutch.")
		return false
	bottlecaps -= ChickenStock.BREED_COST
	supplies["grit"] = int(supplies.get("grit", 0)) - 1
	var chick := ChickenStock.breed(a, b, NetPlay.local_id())
	coop.append(chick)
	var hen_id := id_a if ChickenStock.is_hen(a) else id_b
	for i in coop.size():
		if str(coop[i].get("id", "")) == hen_id:
			coop[i]["nest_rest"] = true
			coop[i]["hunger"] = clampf(float(coop[i].get("hunger", 70.0)) - 18.0, 0.0, 100.0)
			break
	money_changed.emit(bottlecaps)
	coop_changed.emit()
	market_changed.emit()
	toast.emit("%s hatched. %s %s." % [
		chick["name"],
		ChickenStock.sex_name(chick),
		ChickenStock.grade_name(int(chick["grade"])),
	])
	return true


func buy_supply(kind: String) -> bool:
	if is_sitting():
		return false
	var row := ChickenStock.supply_row(kind)
	if row.is_empty():
		return false
	var price := int(row.get("price", 0))
	if bottlecaps < price:
		toast.emit("The shed waits. Your tin does not.")
		return false
	bottlecaps -= price
	supplies[kind] = int(supplies.get(kind, 0)) + 1
	money_changed.emit(bottlecaps)
	market_changed.emit()
	coop_changed.emit()
	toast.emit("Bought %s." % row.get("name", "feed"))
	return true


func feed_chicken(chicken_id: String, kind: String) -> bool:
	if phase != Phase.OPEN:
		toast.emit("Not now.")
		return false
	if chicken_id == entered_id:
		toast.emit("They're already in the paddock.")
		return false
	if int(supplies.get(kind, 0)) < 1:
		toast.emit("Shed's empty. Buy some at the market.")
		return false
	for i in coop.size():
		if str(coop[i].get("id", "")) != chicken_id:
			continue
		supplies[kind] = int(supplies.get(kind, 0)) - 1
		coop[i] = ChickenStock.apply_feed(coop[i], kind)
		coop_changed.emit()
		market_changed.emit()
		toast.emit("Fed %s %s." % [coop[i]["name"], ChickenStock.supply_row(kind).get("name", "feed")])
		return true
	return false


func pour_yard_feed() -> bool:
	if phase != Phase.OPEN:
		toast.emit("Not now.")
		return false
	if int(supplies.get("scratch", 0)) < 1:
		toast.emit("No scratch left to pour.")
		return false
	if yard_feed >= ChickenStock.YARD_FEED_MAX - 1.0:
		toast.emit("Pans are already heaped.")
		return false
	supplies["scratch"] = int(supplies.get("scratch", 0)) - 1
	yard_feed = minf(yard_feed + 42.0, ChickenStock.YARD_FEED_MAX)
	coop_changed.emit()
	market_changed.emit()
	toast.emit("Poured scratch in the pans.")
	return true


func nibble_yard(chicken_id: String, amount: float) -> void:
	if yard_feed <= 0.0 or amount <= 0.0:
		return
	var take := minf(yard_feed, amount)
	yard_feed -= take
	for i in coop.size():
		if str(coop[i].get("id", "")) != chicken_id:
			continue
		if float(coop[i].get("hunger", 70.0)) >= 99.0:
			return
		coop[i] = ChickenStock.apply_nibble(coop[i], take * 0.55)
		return


func shed_count(kind: String) -> int:
	return int(supplies.get(kind, 0))


func enter_chicken(chicken_id: String) -> bool:
	if phase != Phase.OPEN:
		toast.emit("Too late to enter.")
		return false
	var bird := find_chicken(chicken_id)
	if bird.is_empty():
		return false
	if int(bird.get("grade", 0)) < race_min_grade():
		toast.emit("Too green for %s." % race_name())
		return false
	if bool(bird.get("nest_rest", false)):
		toast.emit("%s is on the nest. Sit this card out." % bird.get("name", "That hen"))
		return false
	entered_id = chicken_id
	NetPlay.submit_entry(bird)
	coop_changed.emit()
	toast.emit("%s is on the card. Don't finish last." % bird["name"])
	return true


func scratch_chicken() -> void:
	if phase != Phase.OPEN:
		return
	entered_id = ""
	NetPlay.scratch_entry()
	coop_changed.emit()
	toast.emit("Scratched. The paddock will fill the hole.")


func find_chicken(chicken_id: String) -> Dictionary:
	for bird in coop:
		if str(bird.get("id", "")) == chicken_id:
			return bird
	return {}


func local_entered_bird() -> Dictionary:
	if entered_id.is_empty():
		return {}
	return find_chicken(entered_id)


func ring_the_bell() -> void:
	if NetPlay.is_client():
		NetPlay.request_ring()
		return
	if phase != Phase.OPEN:
		return
	var slammed := open_clock <= 0.05
	open_clock = 0.0
	_set_phase(Phase.COUNTDOWN)
	countdown = COUNT_BEAT * 3.0
	_count_shown = 3
	countdown_tick.emit(3)
	get_tree().call_group("race_manager", "move_to_gates")
	get_tree().call_group("race_director", "activate")
	if slammed:
		toast.emit("Window's slammed. They're lining up.")
	else:
		toast.emit("Bell's rung. Slips are locked.")
	NetPlay.broadcast_meet()


func on_race_finished(winner_index: int, standings: Array) -> void:
	if phase != Phase.RACE:
		return
	results_clock = RESULTS_BEAT
	_set_phase(Phase.RESULTS)
	var payload := _settle_card(winner_index, standings)
	payload["results_clock"] = results_clock
	last_results = payload
	if NetPlay.is_server():
		NetPlay.send_results(payload)
		NetPlay.broadcast_meet()
	_play_results_roast(payload)
	results_ready.emit(payload)
	set_ui_open(true)


func apply_network_results(payload: Dictionary) -> void:
	if phase == Phase.RESULTS and not last_results.is_empty():
		return
	results_clock = float(payload.get("results_clock", RESULTS_BEAT))
	_set_phase(Phase.RESULTS)
	_settle_local_from(payload)
	last_results = payload
	_play_results_roast(payload)
	results_ready.emit(payload)
	set_ui_open(true)


func announce(text: String, force: bool = false) -> void:
	if text.is_empty():
		return
	if _announce_cd > 0.0 and not force:
		return
	_announce_cd = 2.3
	callout.emit(text)


func event_announce(text: String, event_id: int = 0) -> void:
	if text.is_empty():
		return
	_announce_cd = 1.4
	event_callout.emit(text, event_id)


func set_ui_open(open: bool) -> void:
	ui_open = open
	if is_sitting():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		_capture_mouse()


func return_to_menu() -> void:
	if phase == Phase.OPEN:
		clear_bet()
	else:
		bet_amount = 0
		bet_index = -1
		bet_changed.emit()
	ui_open = false
	entered_id = ""
	get_tree().call_group("race_director", "deactivate")
	get_tree().call_group("race_manager", "reset_night")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_set_phase(Phase.MENU)
	if NetPlay.is_online():
		NetPlay.close()


func request_next_race() -> void:
	if phase != Phase.RESULTS:
		return
	if NetPlay.is_client():
		NetPlay.request_next_race()
		return
	toast.emit("Next card. Don't wander off.")
	new_round()


func _settle_card(winner_index: int, standings: Array) -> Dictionary:
	var won := bet_index == winner_index and bet_amount > 0
	var pay := 0
	var winner_name := "Unknown"
	var winner_odds := Vector2i(1, 1)
	var fried_name := ""
	var fried_owned := false
	var fried_id := ""
	var fried_owner_id := 0
	var fried_owner := ""
	var fried_arch := -1
	var purse_won := 0
	var wing_complete := false
	var last_place := 0
	for row in standings:
		var place := int(row.get("place", 99))
		last_place = maxi(last_place, place)
		if place == 1:
			winner_name = str(row.get("name", "Unknown"))
			winner_odds = row.get("odds", Vector2i(1, 1))
	if won:
		pay = bet_amount + int(bet_amount * winner_odds.x / maxi(winner_odds.y, 1))
		bottlecaps += pay
	for row in standings:
		if int(row.get("place", 0)) != last_place or last_place <= 1:
			continue
		fried_name = str(row.get("name", "A chicken"))
		fried_id = str(row.get("chicken_id", ""))
		fried_owner_id = int(row.get("owner_id", 0))
		fried_arch = int(row.get("archetype", -1))
		fried_owned = fried_owner_id == NetPlay.local_id() and not fried_id.begins_with("npc_")
		fried_owner = fried_owner_name(fried_owner_id, fried_id)
		if fried_owned:
			_remove_chicken(fried_id)
			if entered_id == fried_id:
				entered_id = ""
			bottlecaps += ChickenStock.FRY_PAYOUT
		break
	var local_bird := local_entered_bird()
	if not local_bird.is_empty():
		var local_id := str(local_bird.get("id", ""))
		if local_id != fried_id:
			var did_win := false
			for row in standings:
				if str(row.get("chicken_id", "")) == local_id and int(row.get("place", 99)) == 1:
					did_win = true
					purse_won = race_purse()
					bottlecaps += purse_won
					break
			_replace_chicken(local_id, ChickenStock.apply_race_result(local_bird, did_win, race_wing_index()))
			var after := find_chicken(local_id)
			if int(after.get("wing_flags", 0)) == 7:
				wing_complete = true
				bottlecaps += 300
	if bottlecaps <= 0:
		bottlecaps = MERCY_LOAN
	money_changed.emit(bottlecaps)
	coop_changed.emit()
	var deciding := _deciding_event()
	var fryer_line := RaceChaos.fryer_owner_line(fried_name, fried_owner)
	var punchline := RaceChaos.roast_punchline(deciding, fried_name, fried_owner, fried_arch)
	var roast := RaceChaos.table_roast(winner_name, fryer_line, punchline)
	return {
		"winner_index": winner_index,
		"winner_name": winner_name,
		"won": won,
		"pay": pay,
		"bet_amount": bet_amount,
		"bet_index": bet_index,
		"standings": standings,
		"podium": podium_from(standings),
		"fried_name": fried_name,
		"fried_owned": fried_owned,
		"fried_owner": fried_owner,
		"fried_owner_id": fried_owner_id,
		"fried_arch": fried_arch,
		"deciding_event": deciding,
		"fryer_line": fryer_line,
		"punchline": punchline,
		"roast": roast,
		"purse_won": purse_won,
		"wing_complete": wing_complete,
		"race_name": race_name(),
	}


func _settle_local_from(payload: Dictionary) -> void:
	var won := bet_index == int(payload.get("winner_index", -1)) and bet_amount > 0
	var pay := 0
	if won:
		var winner_odds := Vector2i(1, 1)
		for row in payload.get("standings", []):
			if int(row.get("place", 99)) == 1:
				winner_odds = row.get("odds", Vector2i(1, 1))
				break
		pay = bet_amount + int(bet_amount * winner_odds.x / maxi(winner_odds.y, 1))
		bottlecaps += pay
	var fried_id := ""
	var fried_owned := false
	var last_place := 0
	var purse_won := 0
	var wing_complete := false
	for row in payload.get("standings", []):
		last_place = maxi(last_place, int(row.get("place", 0)))
	for row in payload.get("standings", []):
		if int(row.get("place", 0)) != last_place or last_place <= 1:
			continue
		fried_id = str(row.get("chicken_id", ""))
		fried_owned = int(row.get("owner_id", 0)) == NetPlay.local_id() and not fried_id.begins_with("npc_")
		if fried_owned:
			_remove_chicken(fried_id)
			if entered_id == fried_id:
				entered_id = ""
			bottlecaps += ChickenStock.FRY_PAYOUT
		break
	var local_bird := local_entered_bird()
	if not local_bird.is_empty():
		var local_id := str(local_bird.get("id", ""))
		if local_id != fried_id:
			var did_win := false
			for row in payload.get("standings", []):
				if str(row.get("chicken_id", "")) == local_id and int(row.get("place", 99)) == 1:
					did_win = true
					purse_won = race_purse()
					bottlecaps += purse_won
					break
			_replace_chicken(local_id, ChickenStock.apply_race_result(local_bird, did_win, race_wing_index()))
			if int(find_chicken(local_id).get("wing_flags", 0)) == 7:
				wing_complete = true
				bottlecaps += 300
	if bottlecaps <= 0:
		bottlecaps = MERCY_LOAN
	money_changed.emit(bottlecaps)
	coop_changed.emit()
	payload["won"] = won
	payload["pay"] = pay
	payload["bet_amount"] = bet_amount
	payload["bet_index"] = bet_index
	payload["fried_owned"] = fried_owned
	payload["purse_won"] = purse_won
	payload["wing_complete"] = wing_complete
	if str(payload.get("roast", "")).is_empty() or str(payload.get("fryer_line", "")).is_empty():
		_fill_roast_fields(payload)


func fried_owner_name(owner_id: int, chicken_id: String) -> String:
	if chicken_id.begins_with("npc_") or owner_id <= 0:
		return ""
	return NetPlay.trainer_name(owner_id)


func _deciding_event() -> int:
	var manager = get_tree().get_first_node_in_group("race_manager")
	if manager:
		return int(manager.get("last_event_id"))
	return 0


func _fill_roast_fields(payload: Dictionary) -> void:
	var fried_name := str(payload.get("fried_name", ""))
	var fried_owner := str(payload.get("fried_owner", ""))
	var fried_arch := int(payload.get("fried_arch", -1))
	var deciding := int(payload.get("deciding_event", 0))
	if fried_name.is_empty() or fried_owner.is_empty() or fried_arch < 0:
		var last_place := 0
		for row in payload.get("standings", []):
			last_place = maxi(last_place, int(row.get("place", 0)))
		for row in payload.get("standings", []):
			if int(row.get("place", 0)) != last_place or last_place <= 1:
				continue
			fried_name = str(row.get("name", fried_name))
			var fried_id := str(row.get("chicken_id", ""))
			var owner_id := int(row.get("owner_id", 0))
			if fried_owner.is_empty():
				fried_owner = fried_owner_name(owner_id, fried_id)
			if fried_arch < 0:
				fried_arch = int(row.get("archetype", fried_arch))
			payload["fried_name"] = fried_name
			payload["fried_owner"] = fried_owner
			payload["fried_owner_id"] = owner_id
			payload["fried_arch"] = fried_arch
			break
	var fryer_line := RaceChaos.fryer_owner_line(fried_name, fried_owner)
	var punchline := RaceChaos.roast_punchline(deciding, fried_name, fried_owner, fried_arch)
	payload["fryer_line"] = fryer_line
	payload["punchline"] = punchline
	payload["roast"] = RaceChaos.table_roast(str(payload.get("winner_name", "")), fryer_line, punchline)


func _payout_line(payload: Dictionary) -> String:
	if payload.get("won", false):
		return "Your slip paid %d." % int(payload.get("pay", 0))
	if int(payload.get("bet_amount", 0)) > 0:
		return "Your slip is trash."
	if payload.get("fried_owned", false):
		return "The fryer pays %d for your carcass." % ChickenStock.FRY_PAYOUT
	if int(payload.get("purse_won", 0)) > 0:
		return "Your bird took the purse. +%d." % int(payload.get("purse_won", 0))
	if payload.get("wing_complete", false):
		return "Triple Wing. The barn just got a legend. +300."
	return "You watched."


func _localize_roast(roast: String, owner: String, fried_owned: bool) -> String:
	if fried_owned and not owner.is_empty():
		return roast.replace("%s's" % owner, "Your")
	return roast


func _play_results_roast(payload: Dictionary) -> void:
	var roast := str(payload.get("roast", ""))
	if roast.is_empty():
		_fill_roast_fields(payload)
		roast = str(payload.get("roast", ""))
	var payout := _payout_line(payload)
	payload["payout_line"] = payout
	var local_roast := _localize_roast(roast, str(payload.get("fried_owner", "")), bool(payload.get("fried_owned", false)))
	var beat := local_roast if payout.is_empty() else "%s %s" % [local_roast, payout]
	payload["table_toast"] = beat
	if not beat.is_empty():
		toast.emit(beat)
	var fryer := _localize_roast(str(payload.get("fryer_line", "")), str(payload.get("fried_owner", "")), bool(payload.get("fried_owned", false)))
	if not fryer.is_empty():
		announce(fryer, true)


func _tick_open_window(delta: float) -> void:
	if open_clock > 0.0:
		open_clock = maxf(open_clock - delta, 0.0)
	if open_clock <= 0.0 and not NetPlay.is_client():
		ring_the_bell()


func _tick_countdown(delta: float) -> void:
	countdown -= delta
	var shown := 0 if countdown <= 0.0 else clampi(int(ceil(countdown / COUNT_BEAT)), 0, 3)
	if shown != _count_shown:
		_count_shown = shown
		countdown_tick.emit(shown)
	if countdown <= 0.0 and not NetPlay.is_client():
		_start_race()


func _tick_results_beat(delta: float) -> void:
	if results_clock > 0.0:
		results_clock = maxf(results_clock - delta, 0.0)
	if results_clock <= 0.0 and not NetPlay.is_client():
		request_next_race()


func open_secs_left() -> int:
	return maxi(int(ceil(open_clock)), 0)


func results_secs_left() -> int:
	return maxi(int(ceil(results_clock)), 0)


func podium_from(standings: Array = []) -> Array:
	var rows: Array = standings
	if rows.is_empty():
		rows = last_results.get("standings", [])
	var by_place := {}
	for row in rows:
		if not row is Dictionary:
			continue
		var place := int(row.get("place", 0))
		if place >= 1 and place <= 3 and not by_place.has(place):
			by_place[place] = row
	var out: Array = []
	for place in [1, 2, 3]:
		if by_place.has(place):
			out.append(by_place[place])
	return out


func _start_race() -> void:
	if phase != Phase.COUNTDOWN:
		return
	_set_phase(Phase.RACE)
	get_tree().call_group("race_manager", "start_race")
	get_tree().call_group("race_director", "activate")
	NetPlay.broadcast_meet()
	get_tree().create_timer(0.9).timeout.connect(func() -> void:
		if phase == Phase.RACE:
			callout.emit("THEY'RE OFF")
	, CONNECT_ONE_SHOT)


func _set_phase(next: Phase) -> void:
	if phase == next:
		return
	phase = next
	phase_changed.emit(phase)


func _capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _roll_market() -> void:
	market = ChickenStock.roll_market()
	market_changed.emit()


func _wear_coop() -> void:
	for i in coop.size():
		coop[i] = ChickenStock.apply_card_wear(coop[i])
	coop_changed.emit()


func _new_meet() -> void:
	for i in coop.size():
		coop[i]["wing_flags"] = 0
	coop_changed.emit()
	toast.emit("New meet. The Triple Wing jewels are up again.")


func _remove_chicken(chicken_id: String) -> void:
	for i in coop.size():
		if str(coop[i].get("id", "")) == chicken_id:
			coop.remove_at(i)
			return


func _replace_chicken(chicken_id: String, bird: Dictionary) -> void:
	for i in coop.size():
		if str(coop[i].get("id", "")) == chicken_id:
			coop[i] = bird
			return


func _bind_inputs() -> void:
	_bind_key("move_forward", KEY_W)
	_bind_key("move_back", KEY_S)
	_bind_key("move_left", KEY_A)
	_bind_key("move_right", KEY_D)
	_bind_key("sprint", KEY_SHIFT)
	_bind_key("interact", KEY_E)
	_bind_key("toggle_camera", KEY_C)
	_bind_key("pause", KEY_ESCAPE)
	_bind_key("ready_up", KEY_R)
	_bind_key("open_bookie", KEY_B)
	_bind_key("open_coop", KEY_K)
	_bind_key("open_market", KEY_M)
	_bind_key("chaos_hawk", KEY_1)
	_bind_key("chaos_corn", KEY_2)
	_bind_key("chaos_oil", KEY_3)
	_bind_key("chaos_dog", KEY_4)
	_bind_key("chaos_gun", KEY_5)
	_bind_key("chaos_crowd", KEY_6)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_RIGHT
	if not InputMap.has_action("binoculars"):
		InputMap.add_action("binoculars")
	InputMap.action_add_event("binoculars", mouse)


func _bind_key(action: String, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = key
	InputMap.action_add_event(action, event)
