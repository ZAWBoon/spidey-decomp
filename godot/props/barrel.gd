class_name Barrel
extends StaticBody3D
## Explosive red barrel. Joins the "enemies" group so punches, webs and
## tracers hit it (collision_layer 5 = world + enemy bits). Levels only
## count Thug instances, so barrels stay out of the objectives.
## NOTE: deliberate shortcut - split into a "breakable" group later.

@export var radius: float = 6.0
@export var enemy_damage: float = 60.0
@export var player_damage: float = 25.0

var _exploded: bool = false
var _fusing: bool = false


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 5
	collision_mask = 0
	Blockout.cylinder(self, Vector3(0, 0.6, 0), 0.45, 1.2, Color(0.8, 0.1, 0.1), false)
	Blockout.cylinder(self, Vector3(0, 0.6, 0), 0.47, 0.2, Color(0.92, 0.9, 0.85), false)
	Blockout.label(self, Vector3(0, 1.6, 0), "!", Color(1, 0.3, 0.2), 72)


func take_hit(_amount: float, _from: Node = null) -> void:
	explode()


func apply_web(_stun_time: float) -> void:
	pass


func fuse(delay: float) -> void:
	if _exploded or _fusing:
		return
	_fusing = true
	await get_tree().create_timer(delay).timeout
	explode()


func explode() -> void:
	if _exploded:
		return
	_exploded = true
	Sfx.play_at("explosion", global_position)
	_flash()
	for node in get_tree().get_nodes_in_group("enemies"):
		var target := node as Node3D
		if target == null or target == self:
			continue
		if global_position.distance_to(target.global_position) > radius:
			continue
		var other: Variant = node
		if node is Thug:
			other.take_hit(enemy_damage, self)
		elif node is Barrel:
			other.fuse(0.25)
	if Game.player != null:
		var hero: Variant = Game.player
		if global_position.distance_to(hero.global_position) <= radius:
			hero.take_hit(player_damage, self)
			var rig: Variant = hero.cam_rig
			if rig != null:
				rig.add_trauma(0.7)
	visible = false
	($CollisionShape3D as CollisionShape3D).set_deferred("disabled", true)
	get_tree().create_timer(0.5).timeout.connect(queue_free)


func _flash() -> void:
	var scene := get_tree().current_scene as Node3D
	if scene == null:
		return
	var ball := Blockout.sphere(scene, global_position + Vector3(0, 0.8, 0), 1.0,
		Color(1, 0.6, 0.2))
	ball.material_override = Blockout.mat_emissive(Color(1, 0.55, 0.15), 3.0)
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tween := ball.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ball, "scale", Vector3.ONE * radius * 0.9, 0.25)
	tween.tween_property(ball, "transparency", 1.0, 0.4)
	tween.chain().tween_callback(ball.queue_free)
