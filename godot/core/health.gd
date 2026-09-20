class_name Health
extends Node
## Simple hit-points component with signals. Add as a child node.

signal damaged(amount: float, from: Node)
signal healed(amount: float)
signal died
signal changed(hp: float, max_hp: float)

@export var max_hp: float = 100.0

var hp: float = 100.0


func _ready() -> void:
	hp = max_hp


func reset() -> void:
	hp = max_hp
	changed.emit(hp, max_hp)


func is_dead() -> bool:
	return hp <= 0.0


func take_damage(amount: float, from: Node = null) -> void:
	if is_dead() or amount <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	damaged.emit(amount, from)
	changed.emit(hp, max_hp)
	if hp <= 0.0:
		died.emit()


func heal(amount: float) -> void:
	if is_dead() or amount <= 0.0:
		return
	hp = minf(max_hp, hp + amount)
	healed.emit(amount)
	changed.emit(hp, max_hp)
