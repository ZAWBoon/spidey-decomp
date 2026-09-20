class_name ThugRig
extends Node3D
## Procedural thug: articulated body (same joint set as HeroRig) posed from
## Thug AI state - idle look-around, patrol/chase run cycle, melee jab,
## gunner aim (gun rides in the right hand), stagger flinch, webbed slump.
## Set `has_gun` and `variant` before add_child (0 melee, 1 gunner,
## 2 bruiser); all rotations absolute, zeroed first.

const HIPS_Y := 0.85

var has_gun: bool = false
var variant: int = 0

var _time: float = 0.0
var _phase: float = 0.0

var _hips: Node3D = null
var _torso: Node3D = null
var _head: Node3D = null
var _sh_l: Node3D = null
var _sh_r: Node3D = null
var _el_l: Node3D = null
var _el_r: Node3D = null
var _hip_l: Node3D = null
var _hip_r: Node3D = null
var _knee_l: Node3D = null
var _knee_r: Node3D = null


func _ready() -> void:
	_build()


func tick(delta: float, speed: float, state: int, gun: bool, punch: float) -> void:
	_time += delta
	_zero_pose()
	match state:
		Thug.State.IDLE:
			_pose_idle()
		Thug.State.PATROL, Thug.State.CHASE:
			if speed < 0.3:
				_pose_idle()
			else:
				_pose_run(delta, clampf(speed / 4.0, 0.0, 1.0))
		Thug.State.ATTACK:
			if gun:
				_pose_aim()
			else:
				_pose_idle()
				if punch > 0.01:
					_pose_jab(punch)
		Thug.State.STAGGER:
			_pose_stagger()
		Thug.State.STUNNED:
			_pose_slump()
		_:
			_pose_idle()


func _zero_pose() -> void:
	_hips.position.y = HIPS_Y
	for joint in [_hips, _torso, _head, _sh_l, _sh_r, _el_l, _el_r,
			_hip_l, _hip_r, _knee_l, _knee_r]:
		(joint as Node3D).rotation = Vector3.ZERO


func _pose_idle() -> void:
	var b := sin(_time * 2.0)
	_hips.position.y = HIPS_Y + 0.008 * b
	_torso.rotation.x = 0.06 + 0.02 * b
	_head.rotation.y = sin(_time * 0.6) * 0.45
	_sh_l.rotation.x = 0.05 * b
	_sh_r.rotation.x = -0.05 * b
	_el_l.rotation.x = -0.2
	_el_r.rotation.x = -0.2
	_knee_l.rotation.x = 0.06
	_knee_r.rotation.x = 0.06
	if variant == 2:
		_sh_l.rotation.z = 0.4
		_sh_r.rotation.z = -0.4
		_el_l.rotation.x = -0.9
		_el_r.rotation.x = -0.9


func _pose_run(delta: float, sf: float) -> void:
	_phase += delta * (5.0 + 6.0 * sf)
	var amp := 0.55 * (0.5 + 0.5 * sf)
	var s := sin(_phase)
	var c := cos(_phase)
	_hip_l.rotation.x = s * amp
	_hip_r.rotation.x = -s * amp
	_knee_l.rotation.x = 0.15 + 0.8 * maxf(0.0, sin(_phase - 1.2))
	_knee_r.rotation.x = 0.15 + 0.8 * maxf(0.0, sin(_phase + PI - 1.2))
	_sh_l.rotation.x = -s * amp * 0.8
	_sh_r.rotation.x = s * amp * 0.8
	_el_l.rotation.x = -0.45
	_el_r.rotation.x = -0.45
	_hips.position.y = HIPS_Y + absf(c) * 0.05 * sf
	_hips.rotation.y = s * 0.07
	_torso.rotation.x = 0.06 + 0.08 * sf
	_torso.rotation.y = -s * 0.09


func _pose_aim() -> void:
	_sh_l.rotation.x = -1.3
	_sh_r.rotation.x = -1.35
	_el_l.rotation.x = -0.15
	_el_r.rotation.x = -0.15
	_torso.rotation.x = 0.14
	_head.rotation.x = -0.06
	_hips.position.y = HIPS_Y - 0.06
	_knee_l.rotation.x = 0.25
	_knee_r.rotation.x = 0.25


func _pose_jab(k: float) -> void:
	_sh_r.rotation.x = lerpf(_sh_r.rotation.x, -1.8, k)
	_el_r.rotation.x = -0.05
	_torso.rotation.y = lerpf(_torso.rotation.y, 0.4, k)
	_torso.rotation.x = lerpf(_torso.rotation.x, 0.15, k)


func _pose_stagger() -> void:
	_torso.rotation.x = -0.35
	_head.rotation.x = -0.25
	_sh_l.rotation.x = -0.8
	_sh_r.rotation.x = -0.8
	_sh_l.rotation.z = 0.5
	_sh_r.rotation.z = -0.5
	_hips.position.y = HIPS_Y - 0.03


func _pose_slump() -> void:
	_hips.position.y = HIPS_Y - 0.28
	_knee_l.rotation.x = 0.7
	_knee_r.rotation.x = 0.7
	_torso.rotation.x = 0.45
	_head.rotation.x = 0.55
	_sh_l.rotation.x = 0.25
	_sh_r.rotation.x = 0.25
	_el_l.rotation.x = -0.1
	_el_r.rotation.x = -0.1


# --------------------------------------------------------------------- build --
func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var p := Node3D.new()
	p.position = pos
	parent.add_child(p)
	return p


func _build() -> void:
	var suit := Color(0.16, 0.22, 0.16)
	var bulk := 1.0
	if variant == 2:
		suit = Color(0.35, 0.12, 0.12)
		bulk = 1.3
	elif has_gun:
		suit = Color(0.25, 0.16, 0.2)
	else:
		var jackets: Array[Color] = [Color(0.16, 0.22, 0.16), \
				Color(0.3, 0.22, 0.12), Color(0.2, 0.2, 0.24)]
		suit = jackets[abs(int(get_instance_id())) % jackets.size()]
	var skin := Color(0.85, 0.65, 0.5)
	if variant == 2:
		skin = skin.darkened(0.25)
	var pants := Color(0.1, 0.1, 0.12)
	_hips = _pivot(self, Vector3(0, HIPS_Y, 0))
	Blockout.box(_hips, Vector3.ZERO, Vector3(0.4 * bulk, 0.24, 0.26 * bulk), \
		pants, false)
	_torso = _pivot(_hips, Vector3(0, 0.08, 0))
	Blockout.capsule_mesh(_torso, Vector3(0, 0.38, 0), 0.3 * bulk, 0.8, suit)
	_head = _pivot(_torso, Vector3(0, 0.8, 0))
	Blockout.sphere(_head, Vector3(0, 0.08, 0), 0.2, skin)
	if variant == 2:
		Blockout.box(_head, Vector3(0, 0.14, 0.19), Vector3(0.24, 0.06, 0.05), \
			Color(0.05, 0.05, 0.05), false)
	else:
		Blockout.cylinder(_head, Vector3(0, 0.26, 0), 0.16, 0.08,
			suit.darkened(0.4), false)
		Blockout.box(_head, Vector3(0, 0.24, 0.2), Vector3(0.2, 0.04, 0.16),
			suit.darkened(0.4), false)
	_sh_l = _pivot(_torso, Vector3(-0.35 * bulk, 0.62, 0))
	_sh_r = _pivot(_torso, Vector3(0.35 * bulk, 0.62, 0))
	_build_arm(_sh_l, suit, skin, false, bulk)
	_build_arm(_sh_r, suit, skin, has_gun, bulk)
	_hip_l = _pivot(_hips, Vector3(-0.15, -0.03, 0))
	_hip_r = _pivot(_hips, Vector3(0.15, -0.03, 0))
	_build_leg(_hip_l, pants)
	_build_leg(_hip_r, pants)


func _build_arm(shoulder: Node3D, suit: Color, skin: Color, gun: bool, bulk: float) -> void:
	Blockout.capsule_mesh(shoulder, Vector3(0, -0.2, 0), 0.1 * bulk, 0.42, suit)
	var elbow := _pivot(shoulder, Vector3(0, -0.4, 0))
	Blockout.capsule_mesh(elbow, Vector3(0, -0.17, 0), 0.09 * bulk, 0.38, suit)
	Blockout.sphere(elbow, Vector3(0, -0.4, 0), 0.09 * bulk, skin)
	if gun:
		Blockout.box(elbow, Vector3(0, -0.4, 0.12), Vector3(0.08, 0.12, 0.4),
			Color(0.05, 0.05, 0.05), false)
	if shoulder == _sh_l:
		_el_l = elbow
	else:
		_el_r = elbow


func _build_leg(hip: Node3D, pants: Color) -> void:
	Blockout.capsule_mesh(hip, Vector3(0, -0.22, 0), 0.12, 0.5, pants)
	var knee := _pivot(hip, Vector3(0, -0.46, 0))
	Blockout.capsule_mesh(knee, Vector3(0, -0.19, 0), 0.1, 0.42, pants)
	Blockout.box(knee, Vector3(0, -0.42, 0.04), Vector3(0.2, 0.13, 0.3),
		Color(0.06, 0.06, 0.07), false)
	if hip == _hip_l:
		_knee_l = knee
	else:
		_knee_r = knee
