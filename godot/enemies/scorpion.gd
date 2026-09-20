class_name Scorpion
extends CharacterBody3D
## L5 boss: ranged. Strafes at 10-16 m, fires venom-bolt bursts from the
## tail (punch the windup to interrupt!), tail-slams close players (jump
## it: dy < 1.0 hits). AC units block bolts - use cover. Webs stagger.

signal downed
signal activated

enum State { DORMANT, STRAFE, WINDUP, BURST, SLAM_W, SLAM, STAGGER, DEAD }

const TRACER_SCENE: PackedScene = preload("res://combat/tracer.tscn")
const BOLT_TINT := Color(0.3, 1, 0.2)

@export var max_hp: float = 450.0
@export var strafe_speed: float = 4.5
@export var bolt_damage: float = 12.0
@export var slam_damage: float = 15.0
@export var burst_gap: float = 4.0
@export var windup_time: float = 0.6
@export var burst_count: int = 3

var state: int = State.DORMANT
var gravity: float = 22.0

var _burst_cd: float = 2.0
var _state_t: float = 0.0
var _shots_left: int = 0
var _shot_t: float = 0.0
var _strafe_sign: float = 1.0
var _strafe_t: float = 0.0
var _enraged: bool = false
var _player = null
var _body_root: Node3D = null
var _ring: MeshInstance3D = null

@onready var rig: Node3D = $Rig
@onready var health: Health = $Health


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("scorpion")
	gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 22.0))
	health.max_hp = max_hp
	health.reset()
	health.died.connect(_die)
	health.changed.connect(_on_hp_changed)
	_build_body()
	_build_ring()


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_player = Game.player
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.5

	match state:
		State.DORMANT:
			_brake(delta)
		State.STRAFE:
			_tick_strafe(delta)
		State.WINDUP:
			_brake(delta)
			_face_player()
			_state_t -= delta
			if _state_t <= 0.0:
				_to_burst()
		State.BURST:
			_tick_burst(delta)
		State.SLAM_W:
			_brake(delta)
			_state_t -= delta
			if _state_t <= 0.0:
				_do_slam()
		State.SLAM:
			_brake(delta)
			_state_t -= delta
			if _state_t <= 0.0:
				state = State.STRAFE
		State.STAGGER:
			_brake(delta)
			_state_t -= delta
			if _state_t <= 0.0:
				state = State.STRAFE
	move_and_slide()


func activate() -> void:
	if state != State.DORMANT:
		return
	state = State.STRAFE
	_burst_cd = 1.5
	Sfx.play_at("sting", global_position)
	if Game.hud != null:
		Game.hud.show_boss("SCORPION", health.hp, health.max_hp)
		Game.hud.flash_message("SCORPION! Use cover - interrupt the tail!",
			Color(0.4, 1, 0.3), 3.0)
	Game.set_objective("Take down Scorpion!")
	activated.emit()


func take_hit(amount: float, _from: Node = null) -> void:
	if state == State.DEAD:
		return
	if state == State.DORMANT:
		activate()
	if state == State.WINDUP:
		state = State.STAGGER
		_state_t = 1.0
		_burst_cd = maxf(_burst_cd, 1.5)
		if Game.hud != null:
			Game.hud.flash_message("Interrupted!", Color(0.4, 1, 0.5), 1.5)
	health.take_damage(amount, _from)
	Sfx.play_at("hit", global_position)
	_pop_scale()
	if state == State.DEAD:
		return
	if not _enraged and health.hp < health.max_hp * 0.3:
		_enraged = true
		_burst_cd = minf(_burst_cd, 1.0)
		Sfx.play_at("sting", global_position)
		if Game.hud != null:
			Game.hud.flash_message("SCORPION ENRAGED!", Color(1, 0.2, 0.2), 2.5)


func apply_web(_stun_time: float) -> void:
	if state == State.DEAD:
		return
	if state == State.DORMANT:
		activate()
	state = State.STAGGER
	_state_t = 1.2
	_burst_cd = maxf(_burst_cd, 1.5)


func _tick_strafe(delta: float) -> void:
	if _player == null or _player.health.is_dead():
		_brake(delta)
		return
	_face_player()
	var to: Vector3 = _player.global_position - global_position
	var dist := to.length()
	to.y = 0.0
	var flat := to.normalized() if to.length() > 0.05 else Vector3.ZERO
	_burst_cd -= delta
	if dist < 4.0:
		_to_slam_w()
		return
	if _burst_cd <= 0.0:
		_to_windup()
		return
	_strafe_t -= delta
	if _strafe_t <= 0.0:
		_strafe_t = 2.5
		_strafe_sign = -_strafe_sign
	var tangent := Vector3(-flat.z, 0.0, flat.x) * _strafe_sign
	var radial := Vector3.ZERO
	if dist > 16.0:
		radial = flat
	elif dist < 9.0:
		radial = -flat
	var move := radial + tangent * 0.8
	if move.length() < 0.05:
		_brake(delta)
		return
	move = move.normalized()
	var speed := strafe_speed * (1.25 if _enraged else 1.0)
	velocity.x = move.x * speed
	velocity.z = move.z * speed


func _to_windup() -> void:
	state = State.WINDUP
	_state_t = windup_time
	Sfx.play_at("beep", global_position)


func _to_burst() -> void:
	state = State.BURST
	_shots_left = 5 if _enraged else burst_count
	_shot_t = 0.0


func _tick_burst(delta: float) -> void:
	_brake(delta)
	_face_player()
	_shot_t -= delta
	if _shots_left > 0 and _shot_t <= 0.0:
		_fire_bolt()
		_shots_left -= 1
		_shot_t = 0.16
	if _shots_left <= 0:
		state = State.STRAFE
		_burst_cd = 2.5 if _enraged else burst_gap


func _fire_bolt() -> void:
	if _player == null:
		return
	var fwd: Vector3 = rig.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.05 else Vector3(0, 0, 1)
	var origin := global_position + Vector3(0, 2.2, 0) + fwd * 1.0
	var target := _player.global_position + Vector3(0, 1.2, 0)
	var dir := (target - origin).normalized()
	var spread := 0.05 if _shots_left % 2 == 0 else -0.05
	dir = dir.rotated(Vector3.UP, spread)
	var bolt := TRACER_SCENE.instantiate() as Tracer
	bolt.tint = BOLT_TINT
	bolt.speed = 20.0
	get_tree().current_scene.add_child(bolt)
	bolt.global_position = origin
	bolt.launch(dir, bolt_damage)
	Sfx.play_at("sting", origin, -2.0)


func _to_slam_w() -> void:
	state = State.SLAM_W
	_state_t = 0.45 if _enraged else 0.6
	_ring.visible = true
	Sfx.play_at("beep", global_position, -2.0)


func _do_slam() -> void:
	_ring.visible = false
	state = State.SLAM
	_state_t = 0.4
	Sfx.play_at("crash", global_position)
	var scene := get_tree().current_scene
	FX.burst(scene, global_position + Vector3(0, 0.5, 0),
			Color(0.6, 0.55, 0.5), 20, 9.0, 0.15, 0.6)
	FX.ring(scene, global_position, Color(0.7, 1, 0.4, 0.7), 6.0, 0.4)
	if _player == null or _player.health.is_dead():
		return
	var to: Vector3 = _player.global_position - global_position
	var dy: float = to.y
	to.y = 0.0
	if to.length() < 8.0:
		_player.cam_rig.add_trauma(0.6)
		if to.length() < 3.5 and dy < 1.0:
			_player.take_hit(slam_damage, self)
			var push := to.normalized() if to.length() > 0.05 else Vector3(0, 0, 1)
			_player.velocity = push * 6.0 + Vector3(0, 6, 0)


func _brake(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 24.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 24.0 * delta)


func _face_player() -> void:
	if _player == null:
		return
	_face_point(_player.global_position)


func _face_point(point: Vector3) -> void:
	var flat := point - global_position
	flat.y = 0.0
	if flat.length() > 0.05:
		rig.rotation.y = atan2(flat.x, flat.z)


func _on_hp_changed(hp_value: float, hp_max: float) -> void:
	if Game.hud != null:
		Game.hud.set_boss_hp(hp_value, hp_max)


func _pop_scale() -> void:
	if _body_root == null:
		return
	var tween := create_tween()
	tween.tween_property(_body_root, "scale", Vector3(1.12, 0.88, 1.12), 0.06)
	tween.tween_property(_body_root, "scale", Vector3.ONE, 0.12)


func _die() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	_ring.visible = false
	($CollisionShape3D as CollisionShape3D).set_deferred("disabled", true)
	Sfx.play_at("crash", global_position)
	Sfx.play_at("thug_down", global_position, -4.0)
	if Game.hud != null:
		Game.hud.hide_boss()
	var tween := create_tween().set_parallel(true)
	var fall := tween.tween_property(rig, "rotation:x", -PI * 0.5, 0.35)
	fall.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(rig, "position:y", 0.35, 0.35)
	downed.emit()


# --------------------------------------------------------------------- look --
func _build_body() -> void:
	_body_root = Node3D.new()
	_body_root.name = "Body"
	rig.add_child(_body_root)
	var armor := Color(0.15, 0.45, 0.2)
	var dark := Color(0.08, 0.2, 0.1)
	var tail_c := Color(0.8, 0.7, 0.1)
	var root := _body_root
	Blockout.box(root, Vector3(0, 1.15, 0), Vector3(1.4, 1.3, 0.9), armor, false).name = "Torso"
	Blockout.sphere(root, Vector3(0, 2.0, 0.1), 0.28, armor).name = "Head"
	var eye_mat := Blockout.mat_emissive(Color(1, 0.9, 0.1), 2.0)
	for sx in [-0.12, 0.12]:
		var eye := Blockout.sphere(root, Vector3(sx, 2.05, 0.32), 0.07,
			Color(1, 0.9, 0.1))
		eye.material_override = eye_mat
		eye.name = "Eye"
	for sx in [-0.3, 0.3]:
		Blockout.capsule_mesh(root, Vector3(sx, 0.4, 0), 0.16, 0.8, dark).name = "Leg"
	for sx in [-0.85, 0.85]:
		Blockout.capsule_mesh(root, Vector3(sx, 1.2, 0), 0.13, 0.7, armor).name = "Arm"
		Blockout.box(root, Vector3(sx, 0.75, 0.15), Vector3(0.3, 0.25, 0.5),
			tail_c, false).name = "Claw"
	Blockout.box(root, Vector3(0, 1.7, -0.8), Vector3(0.35, 0.35, 1.2),
		tail_c, false).name = "Tail1"
	Blockout.box(root, Vector3(0, 2.3, -1.2), Vector3(0.3, 1.0, 0.3),
		tail_c, false).name = "Tail2"
	Blockout.box(root, Vector3(0, 2.8, -0.5), Vector3(0.28, 0.28, 1.2),
		tail_c, false).name = "Tail3"
	var sting := Blockout.sphere(root, Vector3(0, 2.8, 0.2), 0.2, BOLT_TINT)
	sting.material_override = Blockout.mat_emissive(BOLT_TINT, 2.5)
	sting.name = "Stinger"


func _build_ring() -> void:
	_ring = MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 3.5
	mesh.bottom_radius = 3.5
	mesh.height = 0.06
	_ring.mesh = mesh
	_ring.material_override = Blockout.mat_transparent(Color(1, 0.15, 0.1, 0.45))
	_ring.position = Vector3(0, 0.05, 0)
	_ring.visible = false
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
