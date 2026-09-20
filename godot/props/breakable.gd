class_name Breakable
extends StaticBody3D
## Smashable prop: crates, hydrants, sidewalk planters. Joins "enemies"
## (like Barrel) so punches, slams, webs and enemy tracers hit it with
## zero combat-code changes; LevelBase counts only Thug, so objectives
## ignore it. Explosions chain into it, Rhino plows straight through it.

const WEB_DROP: PackedScene = preload("res://pickups/web_pickup.tscn")

var kind: String = "crate"
var prop_size: float = 1.5

var _hp: int = 1
var _dead: bool = false


static func spawn(parent: Node, pos: Vector3, kind_name: String, size: float = 1.5) -> Breakable:
	var b := Breakable.new()
	b.kind = kind_name
	b.prop_size = size
	parent.add_child(b)
	b.global_position = pos
	return b


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("breakables")
	collision_layer = 5
	collision_mask = 0
	match kind:
		"hydrant":
			_build_hydrant()
		"planter":
			_build_planter()
		_:
			_build_crate()


func take_hit(_amount: float, _from: Node = null) -> void:
	smash()


func apply_web(_stun_time: float) -> void:
	pass


func smash() -> void:
	if _dead:
		return
	_hp -= 1
	if _hp > 0:
		Sfx.play_at("hit", global_position, -6.0)
		FX.hit_spark(get_parent(), global_position + Vector3(0, 0.8, 0),
			Color(0.8, 0.7, 0.5))
		return
	_dead = true
	var top := global_position + Vector3(0, prop_size * 0.5, 0)
	if kind == "hydrant":
		FX.splash(get_parent(), top)
		Sfx.play_at("poof", global_position)
	else:
		FX.burst(get_parent(), top, Color(0.55, 0.4, 0.22), 18, 7.0, 0.14, 0.6)
		Sfx.play_at("crash", global_position, -4.0)
	Game.add_score(25)
	if kind != "hydrant" and randf() < 0.3:
		var drop := WEB_DROP.instantiate() as Area3D
		get_parent().add_child(drop)
		drop.global_position = global_position + Vector3(0, 0.6, 0)
	queue_free()


func _build_crate() -> void:
	_hp = 1
	var s := prop_size
	_add_box(Vector3(s, s, s), Vector3(0, s * 0.5, 0))
	Blockout.box(self, Vector3(0, s * 0.5, 0), Vector3(s, s, s),
		Color(0.5, 0.38, 0.22), false)
	Blockout.box(self, Vector3(0, s * 0.92, 0), Vector3(s * 1.04, s * 0.12, s * 1.04),
		Color(0.42, 0.3, 0.18), false)


func _build_hydrant() -> void:
	_hp = 1
	_add_box(Vector3(0.6, 1.0, 0.6), Vector3(0, 0.5, 0))
	var red := Color(0.7, 0.1, 0.1)
	Blockout.cylinder(self, Vector3(0, 0.4, 0), 0.25, 0.8, red, false)
	Blockout.cylinder(self, Vector3(0, 0.55, 0), 0.32, 0.18, red, false)
	Blockout.sphere(self, Vector3(0, 0.88, 0), 0.16, Color(0.8, 0.75, 0.7))


func _build_planter() -> void:
	_hp = 2
	var s := prop_size
	_add_box(Vector3(s, 1.0, s), Vector3(0, 0.5, 0))
	Blockout.box(self, Vector3(0, 0.45, 0), Vector3(s, 0.9, s),
		Color(0.55, 0.55, 0.57), false)
	Blockout.box(self, Vector3(0, 1.05, 0), Vector3(s * 0.8, 0.35, s * 0.8),
		Color(0.15, 0.4, 0.15), false)


func _add_box(size: Vector3, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = pos
	add_child(cs)
