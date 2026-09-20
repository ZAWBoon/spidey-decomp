class_name Venom
extends CharacterBody3D
## Act boss: an unkillable chaser. Runs the player down and lunges;
## webs only slow him. Damage enrages him (faster). Retreats on order.

signal first_blood

enum State { DORMANT, CHASE, WINDUP, DASH, STAGGER, RETREAT }

@export var max_hp: float = 800.0
@export var move_speed: float = 7.2
@export var damage: float = 25.0

var state: int = State.DORMANT
var gravity: float = 22.0

var _player = null
var _hp: float = 800.0
var _enraged: int = 0
var _slow_t: float = 0.0
var _windup_t: float = 0.0
var _dash_t: float = 0.0
var _dash_dir: Vector3 = Vector3.ZERO
var _stagger_t: float = 0.0
var _retreat_t: float = 0.0
var _blood_shown: bool = false
var _body_root: Node3D = null
var _anim_t: float = 0.0
var _arm_l: Node3D = null
var _arm_r: Node3D = null
var _leg_l: Node3D = null
var _leg_r: Node3D = null

@onready var rig: Node3D = $Rig


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("venom")
	gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 22.0))
	_hp = max_hp
	_build_body()
	_arm_l = _body_root.get_node("ArmL") as Node3D
	_arm_r = _body_root.get_node("ArmR") as Node3D
	_leg_l = _body_root.get_node("LegL") as Node3D
	_leg_r = _body_root.get_node("LegR") as Node3D
	visible = false
	($CollisionShape3D as CollisionShape3D).disabled = true


func activate(spawn_pos: Vector3) -> void:
	if state != State.DORMANT:
		return
	global_position = spawn_pos
	visible = true
	($CollisionShape3D as CollisionShape3D).set_deferred("disabled", false)
	state = State.CHASE
	Sfx.play_at("roar", spawn_pos)


func retreat() -> void:
	if state == State.RETREAT:
		return
	state = State.RETREAT
	collision_mask = 0
	velocity = Vector3(0, 8, -12)
	_retreat_t = 0.0
	Sfx.play_at("roar", global_position)


func is_active() -> bool:
	return state != State.DORMANT and state != State.RETREAT


func _physics_process(delta: float) -> void:
	if state == State.DORMANT:
		return
	_player = Game.player
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0 and state != State.RETREAT:
		velocity.y = -0.5
	_slow_t = maxf(0.0, _slow_t - delta)
	match state:
		State.CHASE:
			_tick_chase(delta)
		State.WINDUP:
			velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
			_windup_t -= delta
			if _windup_t <= 0.0:
				state = State.DASH
				_dash_t = 0.28
				velocity.x = _dash_dir.x * 16.0
				velocity.z = _dash_dir.z * 16.0
				Sfx.play_at("roar", global_position, -8.0)
		State.DASH:
			_dash_t -= delta
			if _player != null and _dist_to_player() < 2.4:
				_land_hit()
			elif _dash_t <= 0.0:
				_to_stagger(0.8)
		State.STAGGER:
			velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
			_stagger_t -= delta
			if _stagger_t <= 0.0:
				state = State.CHASE
		State.RETREAT:
			_retreat_t += delta
			if _retreat_t > 2.5:
				queue_free()
	move_and_slide()
	_animate(delta)


func _dist_to_player() -> float:
	if _player == null:
		return 9999.0
	return global_position.distance_to(_player.global_position)


func _tick_chase(delta: float) -> void:
	if _player == null or _player.health.is_dead():
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
		return
	var to: Vector3 = _player.global_position - global_position
	var flat := to
	flat.y = 0.0
	if flat.length() > 0.05:
		rig.rotation.y = atan2(flat.x, flat.z)
	if flat.length() < 4.0 and absf(to.y) < 3.0:
		state = State.WINDUP
		_windup_t = 0.35
		_dash_dir = flat.normalized() if flat.length() > 0.05 else Vector3.FORWARD
		return
	# Leap up at campers on higher floors.
	if to.y > 3.0 and to.y < 9.0 and flat.length() < 7.0 and is_on_floor():
		velocity.y = 11.0
	var speed := move_speed + 0.4 * _enraged
	if _slow_t > 0.0:
		speed *= 0.5
	if flat.length() > 0.05:
		velocity.x = flat.normalized().x * speed
		velocity.z = flat.normalized().z * speed


func _land_hit() -> void:
	var to: Vector3 = _player.global_position - global_position
	to.y = 0.0
	_player.take_hit(damage, self)
	_player.velocity = to.normalized() * 12.0 + Vector3(0, 6, 0)
	_to_stagger(1.2)


func _to_stagger(time: float) -> void:
	state = State.STAGGER
	_stagger_t = time


# ------------------------------------------------------------------- damage --
func take_hit(amount: float, _from: Node = null) -> void:
	if not is_active():
		return
	_hp = maxf(1.0, _hp - amount)
	Sfx.play_at("hit", global_position)
	_pop_scale()
	if not _blood_shown:
		_blood_shown = true
		first_blood.emit()
	var thresholds: Array[float] = [600.0, 400.0, 200.0, 2.0]
	while _enraged < 4 and _hp <= thresholds[_enraged]:
		_enraged += 1
		Sfx.play_at("roar", global_position, -4.0)


func apply_web(_stun_time: float) -> void:
	if not is_active():
		return
	_slow_t = maxf(_slow_t, 2.0)
	Sfx.play_at("hit", global_position, -6.0)


func _pop_scale() -> void:
	if _body_root == null:
		return
	var tween := create_tween()
	tween.tween_property(_body_root, "scale", Vector3(1.1, 0.9, 1.1), 0.06)
	tween.tween_property(_body_root, "scale", Vector3.ONE, 0.12)


# -------------------------------------------------------------------- anim --
func _animate(delta: float) -> void:
	if _arm_l == null:
		return
	_anim_t += delta
	var t := _anim_t
	match state:
		State.CHASE:
			_body_root.position.y = -0.25 + 0.1 * sin(t * 10.0)
			_body_root.rotation.x = 0.15
			_body_root.rotation.z = 0.08 * sin(t * 5.0)
			_leg_l.position.y = 0.4 + 0.25 * maxf(0.0, sin(t * 10.0))
			_leg_r.position.y = 0.4 + 0.25 * maxf(0.0, sin(t * 10.0 + PI))
			_arm_l.position.z = 0.35 * sin(t * 10.0)
			_arm_r.position.z = 0.35 * sin(t * 10.0 + PI)
		State.WINDUP:
			_body_root.position.y = 0.15
			_body_root.rotation.x = -0.2
			_body_root.rotation.z = 0.0
			_reset_limbs()
			_arm_l.position = Vector3(-0.58, 1.65, 0)
			_arm_r.position = Vector3(0.58, 1.65, 0)
		State.DASH:
			_body_root.position.y = -0.1
			_body_root.rotation.x = 0.35
			_body_root.rotation.z = 0.0
			_reset_limbs()
			_arm_l.position = Vector3(-0.58, 1.3, 0.4)
			_arm_r.position = Vector3(0.58, 1.3, 0.4)
		State.STAGGER:
			_body_root.position.y = 0.0
			_body_root.rotation.x = 0.0
			_body_root.rotation.z = 0.12 * sin(t * 18.0)
			_reset_limbs()
		State.RETREAT:
			_body_root.position.y = 0.0
			_body_root.rotation.x = -0.5
			_body_root.rotation.z = 0.0
			_reset_limbs()
			_arm_l.position = Vector3(-0.9, 1.6, 0)
			_arm_r.position = Vector3(0.9, 1.6, 0)


func _reset_limbs() -> void:
	_leg_l.position = Vector3(-0.26, 0.4, 0)
	_leg_r.position = Vector3(0.26, 0.4, 0)
	_arm_l.position = Vector3(-0.58, 1.3, 0)
	_arm_r.position = Vector3(0.58, 1.3, 0)


# --------------------------------------------------------------------- look --
func _build_body() -> void:
	_body_root = Node3D.new()
	_body_root.name = "Body"
	rig.add_child(_body_root)
	var black := Color(0.04, 0.04, 0.06)
	Blockout.capsule_mesh(_body_root, Vector3(0, 1.2, 0), 0.45, 1.6, black).name = "Torso"
	Blockout.sphere(_body_root, Vector3(0, 2.15, 0), 0.3, black).name = "Head"
	Blockout.capsule_mesh(_body_root, Vector3(-0.26, 0.4, 0), 0.16, 0.8, black).name = "LegL"
	Blockout.capsule_mesh(_body_root, Vector3(0.26, 0.4, 0), 0.16, 0.8, black).name = "LegR"
	Blockout.capsule_mesh(_body_root, Vector3(-0.58, 1.3, 0), 0.15, 0.9, black).name = "ArmL"
	Blockout.capsule_mesh(_body_root, Vector3(0.58, 1.3, 0), 0.15, 0.9, black).name = "ArmR"
	var eye_mat := Blockout.mat_emissive(Color(0.95, 0.97, 1.0), 1.5)
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.12, 0.22, 0.06)
		eye.mesh = mesh
		eye.material_override = eye_mat
		eye.position = Vector3(side * 0.12, 2.22, 0.24)
		eye.rotation.z = side * -0.4
		_body_root.add_child(eye)
	Blockout.box(_body_root, Vector3(0, 1.4, 0.42), Vector3(0.3, 0.4, 0.06),
		Color(0.92, 0.93, 0.95), false).name = "Emblem"
