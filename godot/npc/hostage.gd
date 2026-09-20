class_name Hostage
extends Node3D
## Cowering civilian. Walk close to rescue: +score, +heal, objective count.

signal rescued(hostage: Hostage)

var _saved: bool = false
var _bob_t: float = 0.0
var _body: Node3D = null
var _label: Label3D = null


func _ready() -> void:
	add_to_group("hostages")
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	Blockout.capsule_mesh(_body, Vector3(0, 0.55, 0), 0.3, 0.8, Color(0.9, 0.55, 0.15)).name = "Torso"
	Blockout.sphere(_body, Vector3(0, 1.1, 0), 0.2, Color(0.85, 0.65, 0.5)).name = "Head"
	_body.scale = Vector3(1, 0.72, 1)
	_label = Blockout.label(self, Vector3(0, 1.9, 0), "Help!", Color(1, 0.75, 0.3), 72)
	($RescueArea as Area3D).body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _saved:
		return
	_bob_t += delta
	_body.position.y = 0.05 * sin(_bob_t * 9.0)


func rescue_now() -> void:
	_save()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_save()


func _save() -> void:
	if _saved:
		return
	_saved = true
	_body.scale = Vector3.ONE
	_body.position.y = 0.0
	_label.text = "Saved!"
	_label.modulate = Color(0.4, 1, 0.5)
	Sfx.play_at("rescue", global_position)
	FX.sparkle(get_tree().current_scene,
			global_position + Vector3(0, 1.0, 0), Color(0.3, 1, 0.4))
	if Game.player != null:
		var hero: Variant = Game.player
		hero.add_health(25.0)
	rescued.emit(self)
