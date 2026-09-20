class_name WebPickup
extends Area3D
## Spinning web-fluid cartridge. Refills 40 fluid on touch.

@export var fluid_amount: float = 40.0

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
	Blockout.box(_visual, Vector3.ZERO, Vector3(0.3, 0.45, 0.3), Color(0.92, 0.94, 0.96), false)
	Blockout.box(_visual, Vector3(0, 0.3, 0), Vector3(0.16, 0.14, 0.16), Color(0.1, 0.3, 0.9), false)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_spin_t += delta
	_visual.rotation.y = _spin_t * 2.5
	_visual.position.y = 0.9 + 0.15 * sin(_spin_t * 3.0)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		var hero: Variant = body
		hero.add_fluid(fluid_amount)
		Sfx.play("pickup")
		FX.sparkle(get_tree().current_scene,
				global_position + Vector3(0, 0.9, 0), Color(0.6, 0.85, 1.0))
		if Game.hud != null:
			Game.hud.flash_message("+%d Web Fluid" % int(fluid_amount), Color(0.6, 0.85, 1.0))
		queue_free()
