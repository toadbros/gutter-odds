extends Area3D
class_name Interactable

@export var kind: String = "generic"
@export var prompt: String = "Use"
@export var index: int = 0


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 4
	collision_mask = 0
	monitoring = false
	monitorable = true
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.15
	cs.shape = sphere
	add_child(cs)


func get_prompt() -> String:
	match kind:
		"bookie":
			return "Talk to the bookie"
		"pen":
			return "Inspect the chicken"
		"vip":
			if Game.vip_owned:
				return "Take the box seats"
			return "Buy the box seats  ·  %d caps" % Game.VIP_COST
		"bell":
			if Game.phase == Game.Phase.OPEN:
				return "Lock the window  ·  ring the bell"
			return "The bell already sang"
		"coop":
			return "Open your coop"
		"market":
			return "Bird market and feed shed"
		"fryer":
			return "The fryer. Last place ends up here."
		_:
			return prompt


func interact(_player: Node3D) -> void:
	match kind:
		"bookie":
			if Game.phase == Game.Phase.OPEN:
				Game.bookie_requested.emit()
			else:
				Game.toast.emit("Window's shut. Wait for the next card.")
		"pen":
			Game.inspect_requested.emit(index)
		"vip":
			if Game.vip_owned:
				Game.vip_enter_requested.emit()
			elif Game.buy_vip():
				Game.vip_enter_requested.emit()
			else:
				Game.toast.emit("The clerk looks at your tin. Not today.")
		"bell":
			Game.ring_the_bell()
		"coop":
			Game.coop_requested.emit()
		"market":
			if Game.is_sitting():
				Game.toast.emit("Start the day first.")
			else:
				Game.market_requested.emit()
		"fryer":
			var fried := str(Game.last_results.get("fried_name", ""))
			if fried.is_empty():
				Game.toast.emit("Oil's hot. Last place is dinner.")
			else:
				Game.toast.emit("%s was last. Extra crispy." % fried)
		"generic":
			Game.toast.emit(prompt)
