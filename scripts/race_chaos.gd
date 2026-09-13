class_name RaceChaos
extends RefCounted

enum Condition { FAIR_DIRT, DUST_BOWL, GREASE_DRIP, KERNEL_SCATTER, STORM_COMING }
enum LiveEvent { NONE, OIL_SLICK, CORN_RAIN, HAWK, FALSE_GUN, LOOSE_DOG, CROWD_SQUEEZE }

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
]

# Locked W2-T1 card tells. One line, laugh-first. Do not invent a second wiki.
const TELL_CHAOS_CORN := "Chaos birds love corn. Problem."
const TELL_HUNGRY_CORN := "Hungry. Don’t trust the dirt."
const TELL_SPRINTER_OIL := "Fast until the skillet."
const TELL_SPRINTER_GUN := "Jumps at bangs. Sometimes wins."
const TELL_STEADY_DOG := "Safe on the rail. Until dogs."
const TELL_SPOOKY_HAWK := "Hates the sky."
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
	return condition == Condition.STORM_COMING or event == LiveEvent.HAWK


# One tell. Chemistry (tonight's card) beats quirk/archetype defaults.
# Priority: Chaos/Hungry/Glue-Beak corn > Sprinter oil > Steady dog > Hawk pairs > rest.
# CORN_FIEND = Hungry (and Glue-Beak when no corn match). GREASE_LEGS = Grease-Lucky.
# HAWK_BLIND is calm, not Spooky — mapping it to "Hates the sky." would lie.
static func card_tell(arch: int, traits: Variant, condition: int, event: int = LiveEvent.NONE) -> String:
	var ids := ChickenStock.traits_from(traits)
	var hungry := ids.has(ChickenStock.Trait.CORN_FIEND)
	var grease_lucky := ids.has(ChickenStock.Trait.GREASE_LEGS)
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
		filtered = [
			LiveEvent.OIL_SLICK, LiveEvent.CORN_RAIN, LiveEvent.HAWK,
			LiveEvent.FALSE_GUN, LiveEvent.LOOSE_DOG, LiveEvent.CROWD_SQUEEZE,
		]
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
	return [
		LiveEvent.OIL_SLICK, LiveEvent.CORN_RAIN, LiveEvent.HAWK,
		LiveEvent.FALSE_GUN, LiveEvent.LOOSE_DOG, LiveEvent.CROWD_SQUEEZE,
	]
