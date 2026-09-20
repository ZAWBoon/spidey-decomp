class_name TrafficCar
extends AnimatableBody3D
## Ambient traffic for the avenue: loops a straight lane forever, bumps
## the player (12 dmg + shove, 2 s cooldown per car). Layer 4 so the
## player physically collides; mask 2 (player only) so parked cars,
## poles, planters and Rhino never snag it - lanes are straight and
## pre-cleared, walls are never touched.

var lane_from: Vector3 = Vector3.ZERO
var lane_to: Vector3 = Vector3.ZERO
var speed: float = 11.0
var paint: Color = Color(0.7, 0.7, 0.72)

var _dir: Vector3 = Vector3.FORWARD
var _length: float = 1.0
var _hit_cd: float = 0.0


static func spawn(parent: Node, from: Vector3, to: Vector3,
		paint_color: Color, offset: float, spd: float) -> TrafficCar:
	var c := TrafficCar.new()
	c.lane_from = from
	c.lane_to = to
	c.paint = paint_color
	c.speed = spd
	parent.add_child(c)
	var d := to - from
	if d.length() < 0.05:
		d = Vector3.FORWARD
	c.global_position = from + d.normalized() * offset
	return c


func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	sync_to_physics = true
	var d := lane_to - lane_from
	_length = d.length()
	if _length < 0.05:
		d = Vector3.FORWARD
		_length = 1.0
	_dir = d.normalized()
	rotation.y = atan2(_dir.x, _dir.z)
	_build_visual()


func _physics_process(delta: float) -> void:
	_hit_cd = maxf(0.0, _hit_cd - delta)
	position += _dir * speed * delta
	if (position - lane_from).dot(_dir) >= _length:
		position = lane_from
	_try_bump()


func _try_bump() -> void:
	if _hit_cd > 0.0:
		return
	var hero := Game.player as Player
	if hero == null or hero.health.is_dead():
		return
	if global_position.distance_to(hero.global_position) > 2.6:
		return
	_hit_cd = 2.0
	hero.take_hit(12.0, self)
	var body := hero as CharacterBody3D
	if body != null:
		body.velocity = _dir * 9.0 + Vector3(0, 4.0, 0)
	var rig: Variant = hero.cam_rig
	if rig != null:
		rig.add_trauma(0.5)
	Sfx.play_at("crash", global_position, -6.0)


func _build_visual() -> void:
	Blockout.box(self, Vector3(0, 0.62, 0), Vector3(2.0, 0.65, 4.4), paint, false)
	Blockout.box(self, Vector3(0, 1.2, -0.2), Vector3(1.7, 0.55, 2.1),
		Color(0.1, 0.12, 0.16), false)
	var tire := Color(0.06, 0.06, 0.07)
	for sx in [-1.0, 1.0]:
		for sz in [-1.45, 1.45]:
			var wheel := Blockout.cylinder(self, Vector3(sx, 0.36, sz), 0.36, 0.3,
				tire, false) as MeshInstance3D
			wheel.rotation.z = PI * 0.5
	var lamp := Blockout.mat_emissive(Color(1, 0.95, 0.8), 2.0)
	var tail := Blockout.mat_emissive(Color(0.8, 0.05, 0.05), 1.5)
	for sx2 in [-0.6, 0.6]:
		var head := Blockout.sphere(self, Vector3(sx2, 0.7, 2.25), 0.14, Color.WHITE)
		head.material_override = lamp
		var back := Blockout.sphere(self, Vector3(sx2, 0.7, -2.25), 0.12, Color.WHITE)
		back.material_override = tail
