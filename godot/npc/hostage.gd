class_name Hostage
extends Node3D
## Cowering civilian. Walk close to rescue: +score, +heal, objective count.
## Shirt/skin/size vary per instance (hash of instance id), so a crowd
## of hostages does not look like clones.

signal rescued(hostage: Hostage)

var _saved: bool = false
var _bob_t: float = 0.0
var _body: Node3D = null
var _label: Label3D = null
var _size: float = 1.0


func _ready() -> void:
	add_to_group("hostages")
	var shirts: Array[Color] = [Color(0.9, 0.55, 0.15), Color(0.2, 0.5, 0.85), \
			Color(0.7, 0.25, 0.3), Color(0.35, 0.65, 0.35), Color(0.55, 0.35, 0.7)]
	var skins: Array[Color] = [Color(0.85, 0.65, 0.5), \
			Color(0.6, 0.42, 0.3), Color(0.95, 0.78, 0.62)]
	var pick: int = abs(int(get_instance_id()))
	var shirt: Color = shirts[pick % shirts.size()]
	var skin: Color = skins[(pick / shirts.size()) % skins.size()]
	_size = 0.92 + 0.08 * float(pick % 3)
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	Blockout.capsule_mesh(_body, Vector3(0, 0.55, 0), 0.3, 0.8, shirt).name = "Torso"
	Blockout.sphere(_body, Vector3(0, 1.1, 0), 0.2, skin).name = "Head"
	ProcTex.face_quad(_body, Vector3(0, 1.12, 0.205), 0.28, "face_scared")
	_body.scale = Vector3(_size, 0.72 * _size, _size)
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
	_body.scale = Vector3(_size, _size, _size)
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
