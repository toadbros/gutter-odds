class_name ChickenStock
extends RefCounted

enum Grade { PULLET, SCRATCH, COUNTY, FAIR, WING, CROWN }
enum Sex { HEN, ROOSTER }
enum Trait {
	RAIL_RAT,
	CORN_FIEND,
	MEAN_BEAK,
	GREASE_LEGS,
	DUST_LUNGS,
	STONE_EATER,
	FRYER_FEAR,
	IRON_CROP,
	QUICK_SCRATCH,
	NAPPER,
	GLASS_ANKLES,
	ONE_EYE,
	SPITE,
	HAWK_BLIND,
	CROWD_HOG,
}

const TRAIT_NAMES: PackedStringArray = [
	"Rail Rat",
	"Corn Fiend",
	"Mean Beak",
	"Grease Legs",
	"Dust Lungs",
	"Stone Eater",
	"Fryer Fear",
	"Iron Crop",
	"Quick Scratch",
	"Napper",
	"Glass Ankles",
	"One Eye",
	"Spite",
	"Hawk Blind",
	"Crowd Hog",
]

const TRAIT_TELLS: PackedStringArray = [
	"Lives on the fence. The dirt out wide is a rumor.",
	"Would stop a derby for a kernel.",
	"Bites whoever's in front. Then whoever's left.",
	"Walks through oil like it's gravy.",
	"Was born in a drought. Wind is a suggestion.",
	"Ate a pebble once. Liked it.",
	"Keeps one eye on the fryer. Runs uglier when last.",
	"Won't stop for corn. Pride, or a full belly.",
	"First out of the crate. First to regret it, sometimes.",
	"Sleeps between strides. Then remembers.",
	"One bad flap and they're on their side.",
	"Depth perception is a rumor. Steering too.",
	"Faster if it can see someone to hate.",
	"Didn't notice the hawk. Won't notice the dog.",
	"Uses the crowd as a weapon. Gets used back.",
]

const GRADE_NAMES: PackedStringArray = ["Pullet", "Scratch", "County", "Fair", "Wing", "Crown"]
const COOP_CAP := 8
const PULLET_PRICE := 18
const SCRATCH_PRICE := 42
const TRAIN_COST := 8
const BREED_COST := 15
const FRY_PAYOUT := 8
const TRAINS_PER_GRADE := 3
const TRAIN_FORM := 0.045
const TRAIN_GRADE_CAP := Grade.FAIR
const BREED_HUNGER := 35
const YARD_FEED_MAX := 100.0

const HEN_FIRST: PackedStringArray = [
	"Lady", "Miss", "Penny", "Cinder", "Nugget", "Brine", "Puddle", "Widow",
]
const ROOSTER_FIRST: PackedStringArray = [
	"Gutter", "Captain", "Tin", "Sir", "Quick", "Rusty", "Barn", "Hobo",
]
const LAST_NAMES: PackedStringArray = [
	"Pete", "Cluck", "Comb", "Widow", "Speckle", "Whisper", "Nickel", "King",
	"Yard", "Fry", "Beak", "Dash", "Peck", "Drum", "Wattle", "Scratch",
]
const SUPPLY_ORDER: PackedStringArray = ["scratch", "mash", "grit", "tonic"]
const SUPPLIES: Array[Dictionary] = [
	{"id": "scratch", "name": "Scratch grain", "blurb": "Fills a belly. Pour a sack in the yard pans.", "price": 5},
	{"id": "mash", "name": "Layer mash", "blurb": "Puts a coat on a hen. Roosters steal it anyway.", "price": 8},
	{"id": "grit", "name": "Grit sack", "blurb": "For digestion. And for a clutch.", "price": 4},
	{"id": "tonic", "name": "Yard tonic", "blurb": "After a hard card. Molasses and spite.", "price": 12},
]
const COLORS: Array[Color] = [
	Color("c45a28"), Color("e8d0a8"), Color("b85a28"), Color("2a2e32"),
	Color("f0ead8"), Color("3a3a32"), Color("8a8e86"), Color("7a6a58"),
	Color("4a6a8a"), Color("d4a078"), Color("c42828"), Color("6b8f3a"),
]
const FLAVORS: PackedStringArray = [
	"Still smells like the crate it came in.",
	"Pecks like it has a lawyer.",
	"Has opinions about corn. All of them wrong.",
	"The other birds give it a wider berth than it deserves.",
	"Won a staring contest with a bucket.",
	"Bred for speed. Settled for spite.",
	"Keeps looking at the fryer. Knows something.",
	"A county-fair thoroughbred, if you squint.",
]

const SCHEDULE: Array[Dictionary] = [
	{
		"id": "claiming",
		"name": "Claiming Dash",
		"subtitle": "Anybody with feathers. Pullets welcome.",
		"min_grade": Grade.PULLET,
		"purse": 25,
		"wing": -1,
	},
	{
		"id": "scratch",
		"name": "Scratch Plate",
		"subtitle": "No pullets. The dirt gets honest here.",
		"min_grade": Grade.SCRATCH,
		"purse": 40,
		"wing": -1,
	},
	{
		"id": "county",
		"name": "County Purse",
		"subtitle": "The fair's idea of class.",
		"min_grade": Grade.COUNTY,
		"purse": 60,
		"wing": -1,
	},
	{
		"id": "derby",
		"name": "The Peck Derby",
		"subtitle": "Triple Wing · first jewel",
		"min_grade": Grade.FAIR,
		"purse": 120,
		"wing": 0,
	},
	{
		"id": "comb",
		"name": "The Comb",
		"subtitle": "Triple Wing · second jewel",
		"min_grade": Grade.FAIR,
		"purse": 150,
		"wing": 1,
	},
	{
		"id": "cluck",
		"name": "The Long Cluck",
		"subtitle": "Triple Wing · the distance",
		"min_grade": Grade.FAIR,
		"purse": 200,
		"wing": 2,
	},
]


static var _serial: int = 0


static func grade_name(grade: int) -> String:
	var g := clampi(grade, 0, GRADE_NAMES.size() - 1)
	return GRADE_NAMES[g]


static func current_meet(index: int) -> Dictionary:
	if SCHEDULE.is_empty():
		return {}
	return SCHEDULE[posmod(index, SCHEDULE.size())]


static func next_id() -> String:
	_serial += 1
	return "ch_%d_%d" % [Time.get_ticks_msec(), _serial]


static func random_name(sex: int = -1) -> String:
	var pool := HEN_FIRST if sex == Sex.HEN else ROOSTER_FIRST
	if sex < 0:
		pool = HEN_FIRST if randf() < 0.5 else ROOSTER_FIRST
	var first := pool[randi() % pool.size()]
	var last := LAST_NAMES[randi() % LAST_NAMES.size()]
	return "%s %s" % [first, last]


static func random_color() -> Color:
	return COLORS[randi() % COLORS.size()]


static func random_archetype() -> int:
	return randi() % 4


static func trait_name(trait_id: int) -> String:
	if trait_id < 0 or trait_id >= TRAIT_NAMES.size():
		return ""
	return TRAIT_NAMES[trait_id]


static func trait_tell(trait_id: int) -> String:
	if trait_id < 0 or trait_id >= TRAIT_TELLS.size():
		return ""
	return TRAIT_TELLS[trait_id]


static func traits_from(value: Variant) -> Array[int]:
	var out: Array[int] = []
	if not value is Array:
		return out
	for item in value:
		var id := int(item)
		if id < 0 or id >= TRAIT_NAMES.size():
			continue
		if not out.has(id):
			out.append(id)
	return out


static func has_trait(bird, trait_id: int) -> bool:
	return _bird_traits(bird).has(trait_id)


static func trait_summary(bird) -> String:
	var ids := _bird_traits(bird)
	if ids.is_empty():
		return "No tell"
	var names: PackedStringArray = []
	for id in ids:
		names.append(trait_name(id))
	return ", ".join(names)


static func trait_block(bird) -> String:
	var ids := _bird_traits(bird)
	if ids.is_empty():
		return "No tell. That's either honest or hiding."
	var lines: PackedStringArray = []
	for id in ids:
		lines.append("[b]%s[/b]  ·  %s" % [trait_name(id), trait_tell(id)])
	return "\n".join(lines)


static func roll_traits(grade: int) -> Array[int]:
	var g := clampi(grade, 0, Grade.CROWN)
	var roll := randf()
	var count := 0
	if roll < 0.18 - float(g) * 0.02:
		count = 0
	elif roll < 0.78:
		count = 1
	else:
		count = 2
	var pool: Array[int] = []
	for i in TRAIT_NAMES.size():
		pool.append(i)
	pool.shuffle()
	var out: Array[int] = []
	for i in mini(count, pool.size()):
		out.append(pool[i])
	return out


static func inherit_traits(hen: Dictionary, rooster: Dictionary) -> Array[int]:
	var out: Array[int] = []
	for id in traits_from(hen.get("traits", [])):
		if randf() < 0.5 and not out.has(id):
			out.append(id)
	for id in traits_from(rooster.get("traits", [])):
		if randf() < 0.5 and not out.has(id):
			out.append(id)
	if randf() < 0.28 or out.is_empty():
		var extra := randi() % TRAIT_NAMES.size()
		if not out.has(extra):
			out.append(extra)
	while out.size() > 2:
		out.remove_at(randi() % out.size())
	return out


static func _bird_traits(bird) -> Array[int]:
	if bird is Dictionary:
		return traits_from((bird as Dictionary).get("traits", []))
	if bird is Object:
		var value: Variant = bird.get("traits")
		if value != null:
			return traits_from(value)
	return []


static func is_hen(bird: Dictionary) -> bool:
	return int(bird.get("sex", Sex.HEN)) == Sex.HEN


static func is_rooster(bird: Dictionary) -> bool:
	return int(bird.get("sex", Sex.HEN)) == Sex.ROOSTER


static func sex_name(bird: Dictionary) -> String:
	var hen := is_hen(bird)
	if int(bird.get("grade", 0)) <= Grade.PULLET:
		return "Pullet" if hen else "Cockerel"
	return "Hen" if hen else "Rooster"


static func sex_from_name(name: String) -> int:
	var first := name.split(" ")[0].to_lower()
	if first in ["lady", "miss", "widow", "penny"]:
		return Sex.HEN
	if first in ["sir", "captain", "gutter", "king"]:
		return Sex.ROOSTER
	return Sex.HEN if posmod(hash(name), 2) == 0 else Sex.ROOSTER


static func empty_shed() -> Dictionary:
	return {"scratch": 0, "mash": 0, "grit": 0, "tonic": 0}


static func supply_row(id: String) -> Dictionary:
	for row in SUPPLIES:
		if str(row.get("id", "")) == id:
			return row
	return {}


static func supply_price(id: String) -> int:
	return int(supply_row(id).get("price", 0))


static func form_for_grade(grade: int) -> float:
	var g := float(clampi(grade, 0, 5))
	var lo := 0.80 + g * 0.07
	var hi := 0.96 + g * 0.07
	return randf_range(lo, hi)


static func flavor_for(grade: int) -> String:
	if grade >= Grade.CROWN:
		return "Wears the Triple Wing like it was born in a winner's circle."
	if grade >= Grade.WING:
		return "Has the look of a bird that knows the jewels by name."
	return FLAVORS[randi() % FLAVORS.size()]


static func make_chicken(grade: int, owner_id: int, overrides: Dictionary = {}) -> Dictionary:
	var g := clampi(grade, 0, Grade.CROWN)
	var sex := int(overrides.get("sex", randi() % 2))
	if overrides.has("name") and not overrides.has("sex"):
		sex = sex_from_name(str(overrides.get("name", "")))
	var shell: Color = overrides.get("shell", random_color())
	var traits: Array[int] = []
	if overrides.has("traits"):
		traits = traits_from(overrides.get("traits"))
	else:
		traits = roll_traits(g)
	var bird := {
		"id": str(overrides.get("id", next_id())),
		"name": str(overrides.get("name", random_name(sex))),
		"shell": shell,
		"archetype": overrides.get("archetype", random_archetype()),
		"grade": g,
		"sex": sex,
		"form": float(overrides.get("form", form_for_grade(g))),
		"hunger": float(overrides.get("hunger", randf_range(58.0, 88.0))),
		"condition": float(overrides.get("condition", randf_range(62.0, 92.0))),
		"training": int(overrides.get("training", 0)),
		"races": int(overrides.get("races", 0)),
		"wins": int(overrides.get("wins", 0)),
		"wing_flags": int(overrides.get("wing_flags", 0)),
		"nest_rest": bool(overrides.get("nest_rest", false)),
		"owner_id": int(overrides.get("owner_id", owner_id)),
		"flavor": str(overrides.get("flavor", flavor_for(g))),
		"traits": traits,
	}
	return bird


static func duplicate_bird(bird: Dictionary) -> Dictionary:
	return {
		"id": str(bird.get("id", next_id())),
		"name": str(bird.get("name", "Chicken")),
		"shell": _as_color(bird.get("shell", Color("c45a28"))),
		"archetype": int(bird.get("archetype", 2)),
		"grade": int(bird.get("grade", 0)),
		"sex": int(bird.get("sex", Sex.HEN)),
		"form": float(bird.get("form", 1.0)),
		"hunger": float(bird.get("hunger", 70.0)),
		"condition": float(bird.get("condition", 70.0)),
		"training": int(bird.get("training", 0)),
		"races": int(bird.get("races", 0)),
		"wins": int(bird.get("wins", 0)),
		"wing_flags": int(bird.get("wing_flags", 0)),
		"nest_rest": bool(bird.get("nest_rest", false)),
		"owner_id": int(bird.get("owner_id", 1)),
		"flavor": str(bird.get("flavor", "")),
		"traits": traits_from(bird.get("traits", [])),
	}


static func wire_payload(bird: Dictionary) -> Dictionary:
	var shell := _as_color(bird.get("shell", Color("c45a28")))
	var copy := duplicate_bird(bird)
	copy["shell"] = shell.to_html(false)
	copy["archetype"] = int(bird.get("archetype", 0))
	return copy


static func from_payload(data: Dictionary) -> Dictionary:
	var bird := duplicate_bird(data)
	bird["shell"] = _as_color(data.get("shell", Color("c45a28")))
	bird["archetype"] = int(data.get("archetype", 2))
	return bird


static func sell_price(bird: Dictionary) -> int:
	var bases: Array[int] = [12, 24, 40, 70, 110, 180]
	var g := clampi(int(bird.get("grade", 0)), 0, bases.size() - 1)
	var price := bases[g]
	price += int(bird.get("training", 0)) * 3
	price += int(bird.get("wins", 0)) * 8
	if int(bird.get("wing_flags", 0)) == 7:
		price += 80
	price += traits_from(bird.get("traits", [])).size() * 4
	return maxi(price, 6)


static func buy_price(grade: int) -> int:
	return SCRATCH_PRICE if grade >= Grade.SCRATCH else PULLET_PRICE


static func roll_market() -> Array[Dictionary]:
	var listings: Array[Dictionary] = []
	listings.append(make_chicken(Grade.PULLET, 0, {"sex": Sex.HEN}))
	listings.append(make_chicken(Grade.PULLET, 0, {"sex": Sex.ROOSTER}))
	listings.append(make_chicken(Grade.PULLET, 0))
	if randf() < 0.55:
		listings.append(make_chicken(Grade.SCRATCH, 0, {"sex": Sex.HEN if randf() < 0.5 else Sex.ROOSTER}))
	else:
		listings.append(make_chicken(Grade.PULLET, 0, {"sex": Sex.ROOSTER if randf() < 0.45 else Sex.HEN}))
	return listings


static func pair_error(a: Dictionary, b: Dictionary) -> String:
	if a.is_empty() or b.is_empty():
		return "Pick a hen and a rooster."
	if is_hen(a) == is_hen(b):
		return "A clutch needs a hen and a rooster."
	var hen := a if is_hen(a) else b
	if bool(hen.get("nest_rest", false)):
		return "%s is on the nest. Wait for the next card." % hen.get("name", "The hen")
	if float(a.get("hunger", 0.0)) < BREED_HUNGER or float(b.get("hunger", 0.0)) < BREED_HUNGER:
		return "They're too hungry to clutch. Feed them first."
	return ""


static func race_form(bird: Dictionary) -> float:
	var h := clampf(float(bird.get("hunger", 70.0)) / 100.0, 0.0, 1.0)
	var c := clampf(float(bird.get("condition", 70.0)) / 100.0, 0.0, 1.0)
	return clampf(float(bird.get("form", 1.0)) * lerpf(0.78, 1.0, h) * lerpf(0.86, 1.0, c), 0.7, 1.42)


static func apply_feed(bird: Dictionary, kind: String) -> Dictionary:
	var next := duplicate_bird(bird)
	var hunger := float(next.get("hunger", 70.0))
	var condition := float(next.get("condition", 70.0))
	var form := float(next.get("form", 1.0))
	match kind:
		"scratch":
			hunger += 42.0
			condition += 6.0
		"mash":
			hunger += 32.0
			condition += 16.0
			if is_hen(next):
				condition += 6.0
		"grit":
			hunger += 8.0
			condition += 14.0
		"tonic":
			hunger += 14.0
			condition += 22.0
			form += 0.028
		_:
			return next
	next["hunger"] = clampf(hunger, 0.0, 100.0)
	next["condition"] = clampf(condition, 0.0, 100.0)
	next["form"] = clampf(form, 0.7, 1.42)
	return next


static func apply_nibble(bird: Dictionary, amount: float) -> Dictionary:
	var next := duplicate_bird(bird)
	next["hunger"] = clampf(float(next.get("hunger", 70.0)) + amount, 0.0, 100.0)
	next["condition"] = clampf(float(next.get("condition", 70.0)) + amount * 0.15, 0.0, 100.0)
	return next


static func apply_card_wear(bird: Dictionary) -> Dictionary:
	var next := duplicate_bird(bird)
	var hunger := float(next.get("hunger", 70.0)) - 24.0
	var condition := float(next.get("condition", 70.0))
	condition -= 12.0 if hunger < 40.0 else 5.0
	if hunger < 22.0:
		next["form"] = clampf(float(next.get("form", 1.0)) - 0.012, 0.7, 1.42)
	next["hunger"] = clampf(hunger, 0.0, 100.0)
	next["condition"] = clampf(condition, 0.0, 100.0)
	next["nest_rest"] = false
	return next


static func breed(a: Dictionary, b: Dictionary, owner_id: int) -> Dictionary:
	var hen := a if is_hen(a) else b
	var rooster := b if is_hen(a) else a
	var ga := int(hen.get("grade", 0))
	var gb := int(rooster.get("grade", 0))
	var child_grade := clampi(maxi(ga, gb) + 1, 0, Grade.CROWN)
	if int(hen.get("training", 0)) < 1 or int(rooster.get("training", 0)) < 1:
		child_grade = clampi(maxi(ga, gb), 0, Grade.CROWN)
	var color_a := _as_color(hen.get("shell", random_color()))
	var color_b := _as_color(rooster.get("shell", random_color()))
	var shell := color_a.lerp(color_b, randf_range(0.35, 0.65))
	shell.r = clampf(shell.r + randf_range(-0.08, 0.08), 0.05, 1.0)
	shell.g = clampf(shell.g + randf_range(-0.08, 0.08), 0.05, 1.0)
	shell.b = clampf(shell.b + randf_range(-0.08, 0.08), 0.05, 1.0)
	var arch: int = int(hen.get("archetype", 2))
	if randf() < 0.5:
		arch = int(rooster.get("archetype", 2))
	var form := (float(hen.get("form", 1.0)) + float(rooster.get("form", 1.0))) * 0.5
	form += randf_range(-0.04, 0.08)
	form = clampf(form, 0.78, 1.38)
	var sex := Sex.HEN if randf() < 0.5 else Sex.ROOSTER
	var first := str(hen.get("name", "Lady")).split(" ")[0]
	if sex == Sex.ROOSTER:
		first = str(rooster.get("name", "Sir")).split(" ")[0]
	var last := LAST_NAMES[randi() % LAST_NAMES.size()]
	return make_chicken(child_grade, owner_id, {
		"name": "%s %s" % [first, last],
		"sex": sex,
		"shell": shell,
		"archetype": arch,
		"form": form,
		"hunger": randf_range(70.0, 90.0),
		"condition": randf_range(68.0, 88.0),
		"flavor": "Hatched in your coop. Already judging you.",
		"traits": inherit_traits(hen, rooster),
	})


static func apply_training(bird: Dictionary) -> Dictionary:
	var next := duplicate_bird(bird)
	next["form"] = clampf(float(next["form"]) + TRAIN_FORM, 0.7, 1.42)
	next["training"] = int(next["training"]) + 1
	var grade := int(next["grade"])
	if grade < TRAIN_GRADE_CAP and int(next["training"]) > 0 and int(next["training"]) % TRAINS_PER_GRADE == 0:
		next["grade"] = grade + 1
		next["flavor"] = "Came back from the yard meaner. %s now." % grade_name(int(next["grade"]))
	return next


static func apply_race_result(bird: Dictionary, won: bool, wing_index: int) -> Dictionary:
	var next := duplicate_bird(bird)
	next["races"] = int(next["races"]) + 1
	if won:
		next["wins"] = int(next["wins"]) + 1
		next["form"] = clampf(float(next["form"]) + 0.02, 0.7, 1.42)
		if wing_index >= 0:
			next["wing_flags"] = int(next["wing_flags"]) | (1 << wing_index)
		if int(next["grade"]) < Grade.WING and wing_index >= 0:
			next["grade"] = Grade.WING
		if int(next["wing_flags"]) == 7:
			next["grade"] = Grade.CROWN
			next["flavor"] = "Triple Wing. The barn will tell this story wrong, but loudly."
	else:
		next["form"] = clampf(float(next["form"]) - 0.01, 0.7, 1.42)
	next["hunger"] = clampf(float(next.get("hunger", 70.0)) - (22.0 if won else 28.0), 0.0, 100.0)
	next["condition"] = clampf(float(next.get("condition", 70.0)) - (6.0 if won else 10.0), 0.0, 100.0)
	return next


static func wing_title(bird: Dictionary) -> String:
	var flags := int(bird.get("wing_flags", 0))
	if flags == 7:
		return "Triple Wing"
	var n := 0
	if flags & 1:
		n += 1
	if flags & 2:
		n += 1
	if flags & 4:
		n += 1
	if n <= 0:
		return ""
	return "%d/3 jewels" % n


static func _as_color(value: Variant) -> Color:
	if value is Color:
		return value
	if value is String:
		return Color(str(value))
	if value is Array and value.size() >= 3:
		return Color(float(value[0]), float(value[1]), float(value[2]))
	return Color("c45a28")
