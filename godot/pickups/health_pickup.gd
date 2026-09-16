class_name HealthPickup
extends Area3D
## Spinning green medkit. Heals 40 HP on touch.

@export var heal_amount: float = 40.0

var _spin_t: float = 0.0
var _visual: Node3D = null


func _ready() -> void:
	add_to_group("pickups")
	collision_layer = 8
	collision_mask = 2
	monitoring = true
	monitorable = false
	_visual = Node3D.new()
	add_child(_visual)
	Blockout.box(_visual, Vector3.ZERO, Vector3(0.45, 0.3, 0.45), Color(0.1, 0.6, 0.2), false)
	Blockout.box(_visual, Vector3(0, 0.16, 0), Vector3(0.3, 0.04, 0.1), Color.WHITE, false)
	Blockout.box(_visual, Vector3(0, 0.16, 0), Vector3(0.1, 0.04, 0.3), Color.WHITE, false)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_spin_t += delta
	_visual.rotation.y = _spin_t * 2.5
	_visual.position.y = 0.9 + 0.15 * sin(_spin_t * 3.0)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		var hero: Variant = body
		hero.add_health(heal_amount)
		Sfx.play("pickup")
		if Game.hud != null:
			Game.hud.flash_message("+%d Health" % int(heal_amount), Color(0.4, 1, 0.5))
		queue_free()
