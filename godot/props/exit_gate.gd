class_name ExitGate
extends Area3D
## Walk-in level exit. Locked (red) until the level unlocks it (green).

@export var locked: bool = true

var _deny_cd: float = 0.0
var _bars: Array[MeshInstance3D] = []
var _label: Label3D = null


func _ready() -> void:
	add_to_group("exit_gate")
	collision_layer = 8
	collision_mask = 2
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	_paint()


func _process(delta: float) -> void:
	_deny_cd = maxf(0.0, _deny_cd - delta)


func unlock() -> void:
	if not locked:
		return
	locked = false
	_paint()
	Sfx.play("pickup")
	if Game.hud != null:
		Game.hud.flash_message("Exit open!", Color(0.4, 1, 0.5))


func is_open() -> bool:
	return not locked


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if locked:
		if _deny_cd <= 0.0 and Game.hud != null:
			_deny_cd = 2.0
			Game.hud.flash_message("Locked - finish your objectives!", Color(1, 0.6, 0.3))
	else:
		Game.complete_level()


func _paint() -> void:
	for bar in _bars:
		bar.queue_free()
	_bars.clear()
	var color := Color(0.8, 0.1, 0.1) if locked else Color(0.15, 0.9, 0.3)
	var pillar_l := Blockout.box(self, Vector3(-1.6, 1.5, 0), Vector3(0.5, 3.0, 0.5), color, false)
	var pillar_r := Blockout.box(self, Vector3(1.6, 1.5, 0), Vector3(0.5, 3.0, 0.5), color, false)
	var top := Blockout.box(self, Vector3(0, 3.1, 0), Vector3(3.7, 0.4, 0.5), color, false)
	_bars.append(pillar_l as MeshInstance3D)
	_bars.append(pillar_r as MeshInstance3D)
	_bars.append(top as MeshInstance3D)
	if _label == null:
		_label = Blockout.label(self, Vector3(0, 3.9, 0), "EXIT", Color.WHITE, 80)
	_label.modulate = color
