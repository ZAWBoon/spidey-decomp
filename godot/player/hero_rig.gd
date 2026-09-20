class_name HeroRig
extends Node3D
## Procedural Spider-Man v3: articulated suit (hips/torso/head/arms/legs
## with joint pivots), TRUE spider-web shader on red AND blue parts
## (radial spokes + concentric rings, no escape sequences - a stray
## backslash in shader code fails compile and pinks the hero), chest +
## back spider emblems, web-shooter wristbands, boot cuffs, reactive
## eyes with black rims (narrow when hurt). Player calls tick() every
## physics frame; all joint rotations are set absolute (zeroed first),
## so poses never drift.

const WEB_SHADER := """
shader_type spatial;
render_mode diffuse_burley, specular_disabled;
uniform vec4 tint : source_color = vec4(0.75, 0.08, 0.12, 1.0);
uniform vec4 line : source_color = vec4(0.05, 0.05, 0.08, 1.0);
void fragment() {
	vec2 cell = fract(UV * vec2(3.0, 3.0)) - 0.5;
	float ang = atan(cell.y, cell.x);
	float rad = length(cell) * 2.0;
	float sp = abs(fract(ang * 1.9099) - 0.5);
	float rg = abs(fract(rad * 2.5) - 0.5);
	float m = smoothstep(0.43, 0.5, min(sp, rg));
	ALBEDO = mix(tint.rgb, line.rgb, m);
	ROUGHNESS = 0.6;
}
"""

const HIPS_Y := 0.85

var _time: float = 0.0
var _phase: float = 0.0
var _dead_played: bool = false
var _red_web: ShaderMaterial = null
var _blue_web: ShaderMaterial = null

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
var _eye_l: MeshInstance3D = null
var _eye_r: MeshInstance3D = null


func _ready() -> void:
	var shader := Shader.new()
	shader.code = WEB_SHADER
	_red_web = ShaderMaterial.new()
	_red_web.shader = shader
	_blue_web = ShaderMaterial.new()
	_blue_web.shader = shader
	_blue_web.set_shader_parameter("tint", Color(0.08, 0.12, 0.5))
	_blue_web.set_shader_parameter("line", Color(0.02, 0.03, 0.14))
	_build()


func tick(delta: float, speed: float, airborne: bool, swinging: bool,
		attack_blend: float, combo: int, fx_timers: Vector2, dead: bool,
		hurt: float, alt: int) -> void:
	_time += delta
	if dead:
		_play_dead()
		return
	_zero_pose()
	var sf := clampf(speed / Player.SPRINT_SPEED, 0.0, 1.0)
	if swinging:
		_pose_swing()
	elif airborne:
		_pose_air()
	elif speed > 0.5:
		_pose_run(delta, sf)
	else:
		_pose_idle()
	if attack_blend > 0.01 and alt == 0:
		_pose_punch(attack_blend, combo)
	if fx_timers.x > 0.0:
		_pose_web_flick(clampf(fx_timers.x / 0.25, 0.0, 1.0))
	if fx_timers.y > 0.0:
		_pose_land(clampf(fx_timers.y / 0.25, 0.0, 1.0))
	if hurt > 0.0:
		_pose_hurt(minf(1.0, hurt))
	if alt == 1:
		_pose_launcher()
	elif alt == 2:
		_pose_slam()


func _zero_pose() -> void:
	_hips.position.y = HIPS_Y
	for joint in [_hips, _torso, _head, _sh_l, _sh_r, _el_l, _el_r,
			_hip_l, _hip_r, _knee_l, _knee_r]:
		(joint as Node3D).rotation = Vector3.ZERO
	_eye_l.scale = Vector3.ONE
	_eye_r.scale = Vector3.ONE


func _pose_idle() -> void:
	var b := sin(_time * 2.0)
	_hips.position.y = HIPS_Y + 0.008 * b
	_torso.rotation.x = 0.03 * b
	_head.rotation.x = -0.02 * b
	_sh_l.rotation.x = 0.06 * b
	_sh_r.rotation.x = -0.06 * b
	_el_l.rotation.x = -0.15
	_el_r.rotation.x = -0.15
	_knee_l.rotation.x = 0.05
	_knee_r.rotation.x = 0.05


func _pose_run(delta: float, sf: float) -> void:
	_phase += delta * (6.0 + 7.0 * sf)
	var amp := 0.65 * (0.4 + 0.6 * sf)
	var s := sin(_phase)
	var c := cos(_phase)
	_hip_l.rotation.x = s * amp
	_hip_r.rotation.x = -s * amp
	_knee_l.rotation.x = 0.15 + 0.85 * maxf(0.0, sin(_phase - 1.2))
	_knee_r.rotation.x = 0.15 + 0.85 * maxf(0.0, sin(_phase + PI - 1.2))
	_sh_l.rotation.x = -s * amp * 0.7
	_sh_r.rotation.x = s * amp * 0.7
	_el_l.rotation.x = -(0.4 + 0.2 * sf)
	_el_r.rotation.x = -(0.4 + 0.2 * sf)
	_hips.position.y = HIPS_Y + absf(c) * 0.055 * sf
	_hips.rotation.y = s * 0.08
	_torso.rotation.y = -s * 0.1
	_torso.rotation.x = 0.1 * sf
	_head.rotation.x = -0.08 * sf


func _pose_air() -> void:
	_sh_l.rotation.z = 1.1
	_sh_r.rotation.z = -1.1
	_sh_l.rotation.x = -0.3
	_sh_r.rotation.x = -0.3
	_el_l.rotation.x = -0.3
	_el_r.rotation.x = -0.3
	_hip_l.rotation.z = 0.18
	_hip_r.rotation.z = -0.18
	_hip_l.rotation.x = -0.25
	_hip_r.rotation.x = 0.15
	_knee_l.rotation.x = 0.5
	_knee_r.rotation.x = 0.35
	_torso.rotation.x = -0.1


func _pose_swing() -> void:
	_sh_r.rotation.x = -2.7
	_el_r.rotation.x = -0.2
	_sh_l.rotation.x = 0.4
	_el_l.rotation.x = -0.5
	_torso.rotation.x = -0.45
	_head.rotation.x = -0.3
	_hip_l.rotation.x = 0.55
	_hip_r.rotation.x = 0.35
	_knee_l.rotation.x = 0.9
	_knee_r.rotation.x = 0.7


func _pose_punch(blend: float, combo: int) -> void:
	if combo == 1:
		_sh_l.rotation.x = lerpf(_sh_l.rotation.x, -1.7, blend)
		_el_l.rotation.x = lerpf(_el_l.rotation.x, -0.1, blend)
		_torso.rotation.y = lerpf(_torso.rotation.y, -0.35, blend)
	else:
		var target := -2.3 if combo == 2 else -1.7
		_sh_r.rotation.x = lerpf(_sh_r.rotation.x, target, blend)
		_el_r.rotation.x = lerpf(_el_r.rotation.x, -0.1, blend)
		_torso.rotation.y = lerpf(_torso.rotation.y, 0.35, blend)
		if combo == 2:
			_torso.rotation.x = lerpf(_torso.rotation.x, 0.2, blend)


func _pose_web_flick(k: float) -> void:
	_sh_l.rotation.x = lerpf(_sh_l.rotation.x, -2.0, k)
	_el_l.rotation.x = lerpf(_el_l.rotation.x, -0.1, k)


func _pose_land(k: float) -> void:
	_hips.position.y -= 0.13 * k
	_hips.rotation.x = -0.25 * k
	_knee_l.rotation.x += 0.8 * k
	_knee_r.rotation.x += 0.8 * k
	_torso.rotation.x += 0.18 * k
	_sh_l.rotation.z = 0.3 * k
	_sh_r.rotation.z = -0.3 * k


func _pose_hurt(k: float) -> void:
	var sq := 1.0 - 0.45 * k
	_eye_l.scale = Vector3(1.0, sq, 1.0)
	_eye_r.scale = Vector3(1.0, sq, 1.0)
	_head.rotation.x += 0.25 * k
	_torso.rotation.x += 0.15 * k


func _pose_launcher() -> void:
	_sh_r.rotation.x = -2.9
	_el_r.rotation.x = -0.05
	_sh_l.rotation.x = 0.5
	_el_l.rotation.x = -0.6
	_torso.rotation.x = -0.18
	_head.rotation.x = -0.25
	_hips.position.y += 0.06
	_hip_l.rotation.x = -1.1
	_knee_l.rotation.x = 0.4
	_hip_r.rotation.x = 0.25
	_knee_r.rotation.x = 0.15


func _pose_slam() -> void:
	_hips.position.y -= 0.12
	_torso.rotation.x = 0.35
	_head.rotation.x = 0.3
	_sh_l.rotation.x = 0.7
	_sh_r.rotation.x = 0.7
	_el_l.rotation.x = -0.9
	_el_r.rotation.x = -0.9
	_hip_l.rotation.x = -1.1
	_hip_r.rotation.x = -1.1
	_knee_l.rotation.x = 1.6
	_knee_r.rotation.x = 1.6


func _play_dead() -> void:
	if _dead_played:
		return
	_dead_played = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "rotation:x", -PI * 0.5, 0.5)
	tween.tween_property(self, "position:y", 0.4, 0.5)


# --------------------------------------------------------------------- build --
func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var p := Node3D.new()
	p.position = pos
	parent.add_child(p)
	return p


func _webby(part: MeshInstance3D) -> MeshInstance3D:
	part.material_override = _red_web
	return part


func _webby_blue(part: MeshInstance3D) -> MeshInstance3D:
	part.material_override = _blue_web
	return part


func _build() -> void:
	var blue := Color(0.08, 0.12, 0.5)
	var red := Color(0.75, 0.08, 0.12)
	var dark := Color(0.03, 0.03, 0.05)
	var gold := Color(0.85, 0.65, 0.15)
	_hips = _pivot(self, Vector3(0, HIPS_Y, 0))
	_webby_blue(Blockout.box(_hips, Vector3.ZERO, Vector3(0.42, 0.25, 0.28), blue, false))
	Blockout.box(_hips, Vector3(0, 0.1, 0), Vector3(0.44, 0.08, 0.3), gold, false)
	_torso = _pivot(_hips, Vector3(0, 0.08, 0))
	_webby(Blockout.capsule_mesh(_torso, Vector3(0, 0.38, 0), 0.26, 0.8, red))
	_emblem(Vector3(0, 0.55, 0.27), 1.2, dark)
	_emblem(Vector3(0, 0.55, -0.27), 1.4, dark)
	_head = _pivot(_torso, Vector3(0, 0.8, 0))
	_webby(Blockout.sphere(_head, Vector3(0, 0.08, 0), 0.2, red))
	_eyes()
	_sh_l = _pivot(_torso, Vector3(-0.38, 0.62, 0))
	_sh_r = _pivot(_torso, Vector3(0.38, 0.62, 0))
	_build_arm(_sh_l, red)
	_build_arm(_sh_r, red)
	_hip_l = _pivot(_hips, Vector3(-0.15, -0.03, 0))
	_hip_r = _pivot(_hips, Vector3(0.15, -0.03, 0))
	_build_leg(_hip_l, blue, red)
	_build_leg(_hip_r, blue, red)


func _build_arm(shoulder: Node3D, red: Color) -> void:
	_webby(Blockout.capsule_mesh(shoulder, Vector3(0, -0.2, 0), 0.1, 0.45, red))
	var elbow := _pivot(shoulder, Vector3(0, -0.42, 0))
	_webby(Blockout.capsule_mesh(elbow, Vector3(0, -0.18, 0), 0.09, 0.4, red))
	Blockout.box(elbow, Vector3(0, -0.32, 0), Vector3(0.2, 0.08, 0.2),
		Color(0.75, 0.75, 0.8), false)
	Blockout.sphere(elbow, Vector3(0, -0.42, 0), 0.09, red)
	if shoulder == _sh_l:
		_el_l = elbow
	else:
		_el_r = elbow


func _build_leg(hip: Node3D, blue: Color, red: Color) -> void:
	_webby_blue(Blockout.capsule_mesh(hip, Vector3(0, -0.22, 0), 0.12, 0.5, blue))
	var knee := _pivot(hip, Vector3(0, -0.46, 0))
	_webby_blue(Blockout.capsule_mesh(knee, Vector3(0, -0.19, 0), 0.1, 0.42, blue))
	Blockout.box(knee, Vector3(0, -0.32, 0.02), Vector3(0.22, 0.1, 0.24),
		Color(0.45, 0.05, 0.08), false)
	Blockout.box(knee, Vector3(0, -0.42, 0.04), Vector3(0.2, 0.14, 0.3), red, false)
	if hip == _hip_l:
		_knee_l = knee
	else:
		_knee_r = knee


func _eyes() -> void:
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.95, 0.97, 1.0)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(0.9, 0.95, 1.0)
	eye_mat.emission_energy_multiplier = 0.6
	var rim_mat := StandardMaterial3D.new()
	rim_mat.albedo_color = Color(0.02, 0.02, 0.03)
	rim_mat.roughness = 0.4
	for side in [-1.0, 1.0]:
		var rim := MeshInstance3D.new()
		var rmesh := SphereMesh.new()
		rmesh.radius = 0.058
		rmesh.height = 0.155
		rim.mesh = rmesh
		rim.material_override = rim_mat
		rim.position = Vector3(side * 0.085, 0.12, 0.155)
		rim.rotation.z = side * -0.5
		_head.add_child(rim)
		var eye := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.05
		mesh.height = 0.14
		eye.mesh = mesh
		eye.material_override = eye_mat
		eye.position = Vector3(side * 0.085, 0.12, 0.16)
		eye.rotation.z = side * -0.5
		_head.add_child(eye)
		if side < 0.0:
			_eye_l = eye
		else:
			_eye_r = eye


func _emblem(center: Vector3, emblem_scale: float, dark: Color) -> void:
	var root := Node3D.new()
	root.position = center
	root.scale = Vector3.ONE * emblem_scale
	_torso.add_child(root)
	var belly := Blockout.sphere(root, Vector3(0, -0.05, 0), 0.09, dark)
	belly.scale = Vector3(1, 1.4, 0.5)
	Blockout.sphere(root, Vector3(0, 0.08, 0), 0.05, dark)
	for side in [-1.0, 1.0]:
		for i in 4:
			var leg := Blockout.box(root,
				Vector3(side * 0.14, -0.09 + i * 0.07, 0),
				Vector3(0.14, 0.025, 0.02), dark, false)
			leg.rotation.z = side * (0.6 - i * 0.35)
