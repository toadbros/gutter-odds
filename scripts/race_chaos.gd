class_name RaceChaos
extends RefCounted

enum Condition { FAIR_DIRT, DUST_BOWL, GREASE_DRIP, KERNEL_SCATTER, STORM_COMING }
enum LiveEvent {
	NONE, OIL_SLICK, CORN_RAIN, HAWK, FALSE_GUN, LOOSE_DOG, CROWD_SQUEEZE,
	RACCOON_SNIPER, HAWK_DIVE, LAWN_CHAIR, BOTTLE_ROCKET,
}

const GREASE_FRAC := 0.52
const GREASE_WIDTH := 0.08
const OIL_REACH := 1.18
const FREEZE_LOCK := 1.85
const LAST_FRAC := 0.88

const CONDITION_NAMES: PackedStringArray = [
	"Fair Dirt",
	"Dust Bowl",
	"Grease Drip",
	"Kernel Scatter",
	"Storm Coming",
]

const CONDITION_TELLS: PackedStringArray = [
	"Track's honest. For a gutter.",
	"Wind's stripping the oval. Stay on the rail or eat dirt.",
	"Far turn looks like a skillet.",
	"Somebody seeded the dirt with corn. Don't trust a hungry bird.",
	"Sky's going mean. Flapping gets you nowhere.",
]

const EVENT_NAMES: PackedStringArray = [
	"",
	"Oil Slick",
	"Corn Rain",
	"Hawk",
	"False Gun",
	"Loose Dog",
	"Crowd Squeeze",
	"Raccoon Sniper",
	"Hawk Dive",
	"Lawn Chair",
	"Bottle Rocket",
]

const COMMON_EVENTS: Array[int] = [
	LiveEvent.OIL_SLICK, LiveEvent.CORN_RAIN, LiveEvent.HAWK,
	LiveEvent.FALSE_GUN, LiveEvent.LOOSE_DOG, LiveEvent.CROWD_SQUEEZE,
]

const RARE_EVENTS: Array[int] = [
	LiveEvent.RACCOON_SNIPER, LiveEvent.HAWK_DIVE,
	LiveEvent.LAWN_CHAIR, LiveEvent.BOTTLE_ROCKET,
]

# Sparse spice. Commons stay the default diet. At most one rare per night.
const RARE_CHANCE := 1.0 / 12.0

# Locked W2-T1 card tells. One line, laugh-first. Do not invent a second wiki.
const TELL_CHAOS_CORN := "Chaos birds love corn. Problem."
const TELL_HUNGRY_CORN := "Hungry. Don’t trust the dirt."
const TELL_SPRINTER_OIL := "Fast until the skillet."
const TELL_SPRINTER_GUN := "Jumps at bangs. Sometimes wins."
const TELL_STEADY_DOG := "Safe on the rail. Until dogs."
const TELL_HAWK_BLIND := "Hawk? What hawk."
const TELL_LATE_HAWK := "Waits out the dive."
const TELL_GREASE_LUCKY := "Skillet doesn’t scare this one."
const TELL_GLUE_BEAK := "Will stop to eat. Guaranteed."
const TELL_HUNGRY := "Kernel scatter = free nap."
const TELL_SPRINTER := "Hates oil. Loves a false gun."
const TELL_STEADY := "Rail bird. Dogs ruin their day."
const TELL_CHAOS := "Will stop for corn. Bet against dignity."
const TELL_LATE := "Sleeps early. Eats late."


static func condition_name(condition: int) -> String:
	var i := clampi(condition, 0, CONDITION_NAMES.size() - 1)
	return CONDITION_NAMES[i]


static func condition_tell(condition: int) -> String:
	var i := clampi(condition, 0, CONDITION_TELLS.size() - 1)
	return CONDITION_TELLS[i]


static func event_name(event: int) -> String:
	var i := clampi(event, 0, EVENT_NAMES.size() - 1)
	return EVENT_NAMES[i]


static func event_title(event: int) -> String:
	var name := event_name(event)
	return name.to_upper() if not name.is_empty() else ""


static func is_corn_card(condition: int, event: int = LiveEvent.NONE) -> bool:
	return condition == Condition.KERNEL_SCATTER or event == LiveEvent.CORN_RAIN


static func is_oil_card(condition: int, event: int = LiveEvent.NONE) -> bool:
	return condition == Condition.GREASE_DRIP or event == LiveEvent.OIL_SLICK


static func is_dog_card(condition: int, event: int = LiveEvent.NONE) -> bool:
	return condition == Condition.DUST_BOWL or event == LiveEvent.LOOSE_DOG


static func is_hawk_card(condition: int, event: int = LiveEvent.NONE) -> bool:
	return condition == Condition.STORM_COMING or event == LiveEvent.HAWK or event == LiveEvent.HAWK_DIVE


static func is_rare(event: int) -> bool:
	return RARE_EVENTS.has(event)


# One tell. Chemistry (tonight's card) beats quirk/archetype defaults.
# Priority: Chaos/Hungry/Glue-Beak corn > Sprinter oil > Steady dog > Hawk pairs > rest.
# CORN_FIEND = Hungry (and Glue-Beak when no corn match). GREASE_LEGS = Grease-Lucky.
# HAWK_BLIND is the calm/skip-hawk quirk — "Hawk? What hawk." matches the sim.
static func card_tell(arch: int, traits: Variant, condition: int, event: int = LiveEvent.NONE) -> String:
	var ids := ChickenStock.traits_from(traits)
	var hungry := ids.has(ChickenStock.Trait.CORN_FIEND)
	var grease_lucky := ids.has(ChickenStock.Trait.GREASE_LEGS)
	var hawk_blind := ids.has(ChickenStock.Trait.HAWK_BLIND)
	var corn := is_corn_card(condition, event)
	var oil := is_oil_card(condition, event)
	var dog := is_dog_card(condition, event)
	var hawk := is_hawk_card(condition, event)
	var bang := event == LiveEvent.FALSE_GUN
	if corn and arch == 2:
		return TELL_CHAOS_CORN
	if corn and hungry:
		return TELL_HUNGRY_CORN
	if oil and arch == 0:
		return TELL_SPRINTER_OIL
	if dog and arch == 1:
		return TELL_STEADY_DOG
	if hawk and hawk_blind:
		return TELL_HAWK_BLIND
	if hawk and arch == 3:
		return TELL_LATE_HAWK
	if oil and grease_lucky:
		return TELL_GREASE_LUCKY
	if bang and arch == 0:
		return TELL_SPRINTER_GUN
	if hungry:
		return TELL_HUNGRY
	if grease_lucky:
		return TELL_GREASE_LUCKY
	match arch:
		0:
			return TELL_SPRINTER
		1:
			return TELL_STEADY
		2:
			return TELL_CHAOS
		3:
			return TELL_LATE
	return ""


# Same W2-T1 pairs, live event only. Do not invent a second chemistry wiki.
static func has_live_chemistry(arch: int, traits: Variant, event: int) -> bool:
	if event <= 0:
		return false
	var live := card_tell(arch, traits, Condition.FAIR_DIRT, event)
	match event:
		LiveEvent.CORN_RAIN:
			return live == TELL_CHAOS_CORN or live == TELL_HUNGRY_CORN
		LiveEvent.OIL_SLICK:
			return live == TELL_SPRINTER_OIL or live == TELL_GREASE_LUCKY
		LiveEvent.LOOSE_DOG:
			return live == TELL_STEADY_DOG
		LiveEvent.HAWK, LiveEvent.HAWK_DIVE:
			return live == TELL_HAWK_BLIND or live == TELL_LATE_HAWK
		LiveEvent.FALSE_GUN:
			return live == TELL_SPRINTER_GUN
	return false


static func social_called_line(trainer: String, event: int) -> String:
	var who := trainer if not trainer.is_empty() else "Someone"
	match event:
		LiveEvent.CORN_RAIN:
			return "%s called it. Corn was bait." % who
		LiveEvent.OIL_SLICK:
			return "%s called the skillet." % who
		LiveEvent.LOOSE_DOG:
			return "%s called the dog." % who
		LiveEvent.HAWK, LiveEvent.HAWK_DIVE:
			return "%s called the hawk." % who
		LiveEvent.FALSE_GUN:
			return "%s called the fake bang." % who
	return "%s called it." % who


static func social_shame_line(trainer: String, event: int) -> String:
	var who := trainer if not trainer.is_empty() else "Someone"
	match event:
		LiveEvent.CORN_RAIN:
			return "%s bet the bird that stopped for corn. Shame." % who
		LiveEvent.OIL_SLICK:
			return "%s's slip just drowned in oil. Shame." % who
		LiveEvent.LOOSE_DOG:
			return "%s picked the rail. Shame." % who
		LiveEvent.HAWK, LiveEvent.HAWK_DIVE:
			return "%s bet the flop. Shame." % who
		LiveEvent.FALSE_GUN:
			return "%s picked the wrong bang. Shame." % who
	return "%s picked the victim. Shame." % who


# One line. Called-it beats shame. Empty if tonight's live event has no tell-pair hit.
static func social_spice_toast(slips: Array, birds: Array, event: int, victim_index: int = -1) -> String:
	if event <= 0:
		return ""
	var chem_any := false
	for bird in birds:
		if not bird is Dictionary:
			continue
		if has_live_chemistry(int(bird.get("archetype", -1)), bird.get("traits", []), event):
			chem_any = true
			break
	if not chem_any:
		return ""
	var called := _first_slip_on_chemistry(slips, birds, event)
	if not called.is_empty():
		return social_called_line(str(called.get("name", "Someone")), event)
	var shame := _first_slip_on_index(slips, victim_index)
	if shame.is_empty():
		shame = _first_wrong_side_slip(slips, birds, event)
	if not shame.is_empty():
		return social_shame_line(str(shame.get("name", "Someone")), event)
	return ""


static func _first_slip_on_chemistry(slips: Array, birds: Array, event: int) -> Dictionary:
	for slip in slips:
		if not slip is Dictionary:
			continue
		if int(slip.get("amount", 0)) <= 0:
			continue
		var idx := int(slip.get("index", -1))
		if idx < 0 or idx >= birds.size():
			continue
		var bird: Variant = birds[idx]
		if not bird is Dictionary:
			continue
		if has_live_chemistry(int(bird.get("archetype", -1)), bird.get("traits", []), event):
			return slip
	return {}


static func _first_slip_on_index(slips: Array, index: int) -> Dictionary:
	if index < 0:
		return {}
	for slip in slips:
		if not slip is Dictionary:
			continue
		if int(slip.get("amount", 0)) <= 0:
			continue
		if int(slip.get("index", -1)) == index:
			return slip
	return {}


static func _first_wrong_side_slip(slips: Array, birds: Array, event: int) -> Dictionary:
	for slip in slips:
		if not slip is Dictionary:
			continue
		if int(slip.get("amount", 0)) <= 0:
			continue
		var idx := int(slip.get("index", -1))
		if idx < 0 or idx >= birds.size():
			continue
		var bird: Variant = birds[idx]
		if not bird is Dictionary:
			continue
		if not has_live_chemistry(int(bird.get("archetype", -1)), bird.get("traits", []), event):
			return slip
	return {}


static func event_callout(event: int) -> String:
	match event:
		LiveEvent.OIL_SLICK:
			return "Somebody dumped the skillet. Sprinters eat dirt."
		LiveEvent.CORN_RAIN:
			return "They're throwing scratch. The lead just forgot how to run."
		LiveEvent.HAWK:
			return "Everybody down. Belly-flop."
		LiveEvent.FALSE_GUN:
			return "A gun in the stands. That wasn't the starter."
		LiveEvent.LOOSE_DOG:
			return "A dog's on the rail. Steady birds dump inside."
		LiveEvent.CROWD_SQUEEZE:
			return "The crowd leans in. They're pinning the pack."
		LiveEvent.RACCOON_SNIPER:
			return "Raccoon in the stands. Somebody's getting popped."
		LiveEvent.HAWK_DIVE:
			return "That hawk picked a favorite. Hold your slip."
		LiveEvent.LAWN_CHAIR:
			return "Lawn chairs. The cheap seats just joined the race."
		LiveEvent.BOTTLE_ROCKET:
			return "Somebody lit a bottle rocket. Infield's a war crime."
	return ""


static func fryer_owner_line(bird: String, owner: String) -> String:
	if bird.is_empty():
		return ""
	if owner.is_empty():
		return "%s is last. Heat the oil." % bird
	return "%s's %s is last. Heat the oil." % [owner, bird]


static func fryer_crisp_line(bird: String, owner: String) -> String:
	if bird.is_empty():
		return ""
	if owner.is_empty():
		return "%s is extra crispy. House bird. House dinner." % bird
	return "%s's %s is extra crispy." % [owner, bird]


static func roast_punchline(event: int, bird: String, owner: String, arch: int) -> String:
	if bird.is_empty() or event <= 0:
		return ""
	var kind := ChickenStock.archetype_name(arch)
	var owned := not owner.is_empty()
	var bird_who := ("%s's %s" % [owner, bird]) if owned else bird
	var arch_who := ("%s's %s" % [owner, kind]) if owned else ("%s the %s" % [bird, kind])
	match event:
		LiveEvent.OIL_SLICK:
			return "%s met the skillet." % arch_who
		LiveEvent.HAWK:
			return "Hawk put %s on the plate." % bird_who
		LiveEvent.CORN_RAIN:
			return "%s stopped for corn. The fryer did not." % bird_who
		LiveEvent.LOOSE_DOG:
			return "%s dumped the rail. Dinner followed." % bird_who
		LiveEvent.FALSE_GUN:
			return "False gun, real grease. %s is toast." % bird_who
		LiveEvent.CROWD_SQUEEZE:
			return "The crowd pinned %s. The oil finished it." % bird_who
		LiveEvent.RACCOON_SNIPER:
			return "A raccoon sniped %s. Fryer said thanks." % bird_who
		LiveEvent.HAWK_DIVE:
			return "Hawk dove for %s. Dinner volunteered." % bird_who
		LiveEvent.LAWN_CHAIR:
			return "%s lost to a lawn chair. The oil was mercy." % bird_who
		LiveEvent.BOTTLE_ROCKET:
			return "Bottle rocket found %s. Extra crispy." % bird_who
	return ""


static func table_roast(winner: String, fryer_line: String, punch: String) -> String:
	var bits: PackedStringArray = []
	if not winner.is_empty():
		bits.append("%s takes the ring." % winner)
	if not fryer_line.is_empty():
		bits.append(fryer_line)
	if not punch.is_empty():
		bits.append(punch)
	return " ".join(bits)


static func event_rank(event: int) -> int:
	match event:
		LiveEvent.HAWK, LiveEvent.CORN_RAIN:
			return 1
		LiveEvent.RACCOON_SNIPER, LiveEvent.HAWK_DIVE, LiveEvent.LAWN_CHAIR, LiveEvent.BOTTLE_ROCKET:
			return 1
		LiveEvent.OIL_SLICK, LiveEvent.LOOSE_DOG:
			return 2
		LiveEvent.FALSE_GUN, LiveEvent.CROWD_SQUEEZE:
			return 3
	return 3


static func event_yell_secs(event: int) -> float:
	match event_rank(event):
		1:
			return 4.2
		2:
			return 3.6
	return 3.1


static func event_flash(event: int) -> Color:
	match event:
		LiveEvent.OIL_SLICK:
			return Color("3a2a10")
		LiveEvent.CORN_RAIN:
			return Color("e8c03a")
		LiveEvent.HAWK:
			return Color("6a2030")
		LiveEvent.FALSE_GUN:
			return Color("f0ead8")
		LiveEvent.LOOSE_DOG:
			return Color("8a5a28")
		LiveEvent.CROWD_SQUEEZE:
			return Color("8a3a4a")
		LiveEvent.RACCOON_SNIPER:
			return Color("4a3a28")
		LiveEvent.HAWK_DIVE:
			return Color("8a1020")
		LiveEvent.LAWN_CHAIR:
			return Color("b07a48")
		LiveEvent.BOTTLE_ROCKET:
			return Color("f8e070")
	return Color("b08d57")


static func roll_condition(wing: int) -> int:
	if wing >= 0 and randf() < 0.55:
		match wing:
			0:
				return Condition.KERNEL_SCATTER
			1:
				return Condition.GREASE_DRIP
			_:
				return Condition.STORM_COMING
	var roll := randf()
	if roll < 0.35:
		return Condition.FAIR_DIRT
	if roll < 0.57:
		return Condition.DUST_BOWL
	if roll < 0.75:
		return Condition.GREASE_DRIP
	if roll < 0.90:
		return Condition.KERNEL_SCATTER
	return Condition.STORM_COMING


static func planned_event_count(condition: int, jewel: bool) -> int:
	if jewel:
		return 1
	if condition == Condition.FAIR_DIRT:
		return 1 if randf() < 0.42 else 0
	return 2 if randf() < 0.32 else 1


static func pick_live_event(condition: int, wing: int, used: Array) -> int:
	if wing >= 0 and used.is_empty():
		var named := _jewel_event(wing)
		if not used.has(named):
			return named
	var pool: Array[int] = _pool_for(condition)
	var filtered: Array[int] = []
	for event in pool:
		if not used.has(event):
			filtered.append(event)
	if filtered.is_empty():
		filtered = COMMON_EVENTS.duplicate()
		var leftover: Array[int] = []
		for event in filtered:
			if not used.has(event):
				leftover.append(event)
		filtered = leftover
	if filtered.is_empty():
		return LiveEvent.NONE
	return filtered[randi() % filtered.size()]


static func event_duration(event: int) -> float:
	match event:
		LiveEvent.OIL_SLICK:
			return randf_range(2.1, 3.2)
		LiveEvent.CORN_RAIN:
			return randf_range(1.6, 2.4)
		LiveEvent.HAWK:
			return randf_range(1.5, 2.2)
		LiveEvent.FALSE_GUN:
			return randf_range(1.4, 2.0)
		LiveEvent.LOOSE_DOG:
			return randf_range(1.7, 2.6)
		LiveEvent.CROWD_SQUEEZE:
			return randf_range(1.5, 2.3)
		LiveEvent.RACCOON_SNIPER:
			return randf_range(2.0, 2.8)
		LiveEvent.HAWK_DIVE:
			return randf_range(1.8, 2.6)
		LiveEvent.LAWN_CHAIR:
			return randf_range(1.7, 2.5)
		LiveEvent.BOTTLE_ROCKET:
			return randf_range(1.5, 2.2)
	return 1.8


static func first_event_frac() -> float:
	return randf_range(0.22, 0.40)


static func next_event_frac(prev: float) -> float:
	return minf(prev + randf_range(0.18, 0.28), 0.84)


static func in_grease_zone(distance: float, length: float) -> bool:
	var frac := clampf(distance / maxf(length, 0.001), 0.0, 1.0)
	return absf(frac - GREASE_FRAC) <= GREASE_WIDTH * 0.5


static func near_oil(distance: float, event_at: float) -> bool:
	return absf(distance - event_at) <= OIL_REACH


static func line_mult(condition: int, live: int, groove: float, height: float, arch: int, distance: float, length: float, event_at: float, extras: Dictionary = {}) -> float:
	var m := 1.0
	var skate := bool(extras.get("skate", false))
	var calm := bool(extras.get("calm", false))
	var hog := bool(extras.get("hog", false))
	var dust_lungs := bool(extras.get("dust_lungs", false))
	match condition:
		Condition.DUST_BOWL:
			m *= lerpf(1.16, 0.66 if not dust_lungs else 0.92, clampf(groove, 0.0, 1.0))
			if arch == 0 and groove < 0.22:
				m *= 1.06
			if arch == 3 and groove > 0.52:
				m *= 0.90
			if dust_lungs:
				m *= 1.08
		Condition.GREASE_DRIP:
			if in_grease_zone(distance, length):
				m *= 1.06 if skate else 0.80
		Condition.STORM_COMING:
			if height > 0.07:
				m *= 0.70
	match live:
		LiveEvent.OIL_SLICK:
			if near_oil(distance, event_at):
				m *= 1.08 if skate else 0.52
		LiveEvent.FALSE_GUN:
			if arch == 0:
				m *= 1.24
			elif arch == 3:
				m *= 0.74
		LiveEvent.HAWK:
			if height > 0.02 and not calm:
				m *= 0.68
		LiveEvent.LOOSE_DOG:
			if groove < 0.30 and not calm:
				m *= 0.78
		LiveEvent.CROWD_SQUEEZE:
			m *= 0.98 if hog else 0.92
		LiveEvent.HAWK_DIVE:
			if height > 0.02 and not calm:
				m *= 0.52
			else:
				m *= 0.86
		LiveEvent.RACCOON_SNIPER:
			m *= 0.88
		LiveEvent.LAWN_CHAIR:
			m *= 0.84
		LiveEvent.BOTTLE_ROCKET:
			m *= 0.82
	return m


static func wants_kernel_peck(arch: int, hunger: float, delta: float) -> bool:
	var chance := 0.10
	if arch == 2:
		chance = 0.38
	elif hunger < 52.0:
		chance = 0.48
	elif arch == 1:
		chance = 0.06
	return randf() < chance * delta


static func wants_corn_freeze(arch: int, hunger: float) -> bool:
	if arch == 2 or hunger < 58.0:
		return true
	if arch == 1:
		return randf() < 0.12
	return randf() < 0.28


static func track_tint(condition: int) -> Color:
	match condition:
		Condition.DUST_BOWL:
			return Color("e8d070")
		Condition.GREASE_DRIP:
			return Color("4a3214")
		Condition.KERNEL_SCATTER:
			return Color("e0a828")
		Condition.STORM_COMING:
			return Color("4a4a58")
	return Color("c4a060")


static func dirt_tint(condition: int) -> Color:
	match condition:
		Condition.DUST_BOWL:
			return Color("f0dc88")
		Condition.GREASE_DRIP:
			return Color("2e2010")
		Condition.KERNEL_SCATTER:
			return Color("f0c040")
		Condition.STORM_COMING:
			return Color("5a5462")
	return Color("d2b07a")


static func condition_banner_color(condition: int) -> Color:
	match condition:
		Condition.DUST_BOWL:
			return Color("e8d070")
		Condition.GREASE_DRIP:
			return Color("8a6a28")
		Condition.KERNEL_SCATTER:
			return Color("e8c03a")
		Condition.STORM_COMING:
			return Color("9aa8c4")
	return Color("f0e6d0")


static func _jewel_event(wing: int) -> int:
	match wing:
		0:
			return LiveEvent.CORN_RAIN
		1:
			return LiveEvent.CROWD_SQUEEZE
		_:
			return LiveEvent.HAWK


static func _pool_for(condition: int) -> Array[int]:
	match condition:
		Condition.DUST_BOWL:
			return [LiveEvent.LOOSE_DOG, LiveEvent.CROWD_SQUEEZE, LiveEvent.HAWK, LiveEvent.FALSE_GUN]
		Condition.GREASE_DRIP:
			return [LiveEvent.OIL_SLICK, LiveEvent.CROWD_SQUEEZE, LiveEvent.LOOSE_DOG]
		Condition.KERNEL_SCATTER:
			return [LiveEvent.CORN_RAIN, LiveEvent.CROWD_SQUEEZE, LiveEvent.FALSE_GUN]
		Condition.STORM_COMING:
			return [LiveEvent.HAWK, LiveEvent.FALSE_GUN, LiveEvent.LOOSE_DOG]
	return COMMON_EVENTS.duplicate()


static func roll_rare(night_used: bool, jewel: bool = false) -> int:
	if night_used or jewel:
		return LiveEvent.NONE
	if randf() >= RARE_CHANCE:
		return LiveEvent.NONE
	return RARE_EVENTS[randi() % RARE_EVENTS.size()]
