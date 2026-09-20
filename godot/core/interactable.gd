class_name Interactable
extends Area3D
## Base class for "press/hold E" objects (bomb, switches, ...).
## The player drives these: scan -> prompt -> hold_tick -> do_use.

@export var prompt_text: String = "Use"
@export var hold_time: float = 0.0

var _hold: float = 0.0


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 8
	collision_mask = 2
	monitoring = true
	monitorable = false


func reset_hold() -> void:
	_hold = 0.0


func get_progress() -> float:
	if hold_time <= 0.0:
		return 1.0
	return clampf(_hold / hold_time, 0.0, 1.0)


func can_use() -> bool:
	return true


func get_prompt() -> String:
	return prompt_text


## Called every physics tick while the player holds interact. Returns true
## on the tick the use completes.
func hold_tick(delta: float) -> bool:
	if hold_time <= 0.0:
		do_use()
		return true
	_hold += delta
	if _hold >= hold_time:
		do_use()
		return true
	return false


func do_use() -> void:
	pass
