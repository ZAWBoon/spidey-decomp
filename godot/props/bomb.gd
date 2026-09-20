class_name Bomb
extends Interactable
## Hold-E-to-defuse bomb with a countdown. Exploding ends the level.

signal defused(bomb: Bomb)
signal exploded(bomb: Bomb)

@export var total_time: float = 90.0

var time_left: float = 90.0
var armed: bool = false
var done: bool = false

var _beep_t: float = 0.0
var _blink_t: float = 0.0
var _lamp_mat: StandardMaterial3D = null
var _label: Label3D = null


func _ready() -> void:
	super._ready()
	add_to_group("bomb")
	prompt_text = "Defuse bomb"
	hold_time = 3.0
	time_left = total_time
	Blockout.box(self, Vector3(0, 0.35, 0), Vector3(0.9, 0.7, 0.6), Color(0.12, 0.12, 0.14), false)
	_lamp_mat = StandardMaterial3D.new()
	_lamp_mat.albedo_color = Color(0.4, 0.4, 0.4)
	_lamp_mat.emission_enabled = true
	_lamp_mat.emission = Color(1, 0.1, 0.1)
	_lamp_mat.emission_energy_multiplier = 0.2
	var lamp := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	lamp.mesh = mesh
	lamp.material_override = _lamp_mat
	lamp.position = Vector3(0, 0.85, 0)
	add_child(lamp)
	_label = Blockout.label(self, Vector3(0, 1.5, 0), "--", Color(1, 0.4, 0.3), 80)


func arm() -> void:
	if armed or done:
		return
	armed = true
	if Game.hud != null:
		Game.hud.flash_message("Bomb armed! Defuse it!", Color(1, 0.35, 0.25), 3.0)


func debug_defuse() -> void:
	armed = true
	if not done:
		do_use()


func can_use() -> bool:
	return armed and not done


func get_prompt() -> void:
	return "Defuse bomb [%ds] (hold)" % int(maxf(0.0, time_left))


func do_use() -> void:
	if done or not armed:
		return
	done = true
	reset_hold()
	_lamp_mat.emission = Color(0.2, 1, 0.3)
	_lamp_mat.emission_energy_multiplier = 2.0
	_label.text = "SAFE"
	_label.modulate = Color(0.4, 1, 0.5)
	Sfx.play("rescue")
	FX.sparkle(get_tree().current_scene,
			global_position + Vector3(0, 1.0, 0), Color(0.3, 1, 0.4))
	if Game.hud != null:
		Game.hud.flash_message("Bomb defused! +300", Color(0.4, 1, 0.5))
		Game.hud.hide_bomb_timer()
	defused.emit(self)


func _process(delta: float) -> void:
	if not armed or done:
		return
	time_left -= delta
	_label.text = "%d" % int(maxf(0.0, ceil(time_left)))
	var urgency := clampf(1.0 - time_left / total_time, 0.0, 1.0)
	_blink_t -= delta
	if _blink_t <= 0.0:
		_blink_t = lerpf(0.8, 0.12, urgency)
		_lamp_mat.emission_energy_multiplier = 4.0 if _lamp_mat.emission_energy_multiplier < 2.0 else 0.3
	_beep_t -= delta
	if _beep_t <= 0.0:
		_beep_t = lerpf(1.0, 0.18, urgency)
		Sfx.play_at("beep", global_position, -4.0)
	if Game.hud != null:
		Game.hud.show_bomb_timer(time_left)
	if time_left <= 0.0:
		_explode()


func _explode() -> void:
	done = true
	_label.text = "BOOM"
	Sfx.play("explosion")
	if Game.player != null:
		var hero: Variant = Game.player
		var rig: Variant = hero.cam_rig
		if rig != null:
			rig.add_trauma(1.0)
	if Game.hud != null:
		Game.hud.hide_bomb_timer()
		Game.hud.damage_flash()
	exploded.emit(self)
	Game.trigger_game_over("The bomb exploded...")
