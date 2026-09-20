class_name Thug
extends CharacterBody3D
## Jade-syndicate street thug. Melee or gunner (has_gun), simple FSM AI:
## idle/patrol -> chase -> attack, plus stagger/stun/death. Visuals and
## procedural animation live in ThugRig (thug_rig.gd), fed state each frame.

signal downed(thug: Thug)
signal webbed(thug: Thug)

enum State { IDLE, PATROL, CHASE, ATTACK, STAGGER, STUNNED, DEAD }

const TRACER_SCENE: PackedScene = preload("res://combat/tracer.tscn")

@export var max_hp: float = 50.0
@export var move_speed: float = 3.6
@export var damage: float = 10.0
@export var has_gun: bool = false
@export var passive: bool = false
@export var sight_range: float = 18.0
@export var attack_range: float = 2.3
@export var attack_cooldown: float = 1.3

var patrol_points: Array[Vector3] = []

var state: int = State.IDLE
var gravity: float = 22.0
var rig_node: ThugRig = null

var _patrol_i: int = 0
var _attack_t: float = 0.0
var _stagger_t: float = 0.0
var _stun_t: float = 0.0
var _alert_t: float = 0.0
var _punch_t: float = 0.0
var _player = null
var _cocoon: MeshInstance3D = null
var _alert_label: Label3D = null
var _body_root: Node3D = null

@onready var rig: Node3D = $Rig
@onready var health: Health = $Health


func _ready() -> void:
	add_to_group("enemies")
	gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 22.0))
	health.max_hp = max_hp
	health.reset()
	health.died.connect(_die)
	_build_body()
	if has_gun:
		attack_range = 15.0
		attack_cooldown = 2.1
	if patrol_points.size() > 0:
		state = State.PATROL


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_player = Game.player
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.5
	_alert_t = maxf(0.0, _alert_t - delta)
	_punch_t = maxf(0.0, _punch_t - delta)
	if _alert_label != null:
		_alert_label.visible = _alert_t > 0.0 and state != State.DEAD

	match state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
			_scan()
		State.PATROL:
			_tick_patrol(delta)
			_scan()
		State.CHASE:
			_tick_chase(delta)
		State.ATTACK:
			_tick_attack(delta)
		State.STAGGER:
			velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
			_stagger_t -= delta
			if _stagger_t <= 0.0:
				state = State.CHASE
		State.STUNNED:
			velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
			_stun_t -= delta
			if _stun_t <= 0.0:
				_cocoon.visible = false
				state = State.CHASE
	if rig_node != null:
		var h_speed := Vector2(velocity.x, velocity.z).length()
		rig_node.tick(delta, h_speed, state, has_gun, _punch_t / 0.3)
	move_and_slide()


func _player_dist() -> float:
	if _player == null or _player.health.is_dead():
		return 9999.0
	return global_position.distance_to(_player.global_position)


func _scan() -> void:
	if passive or _player == null:
		return
	if _player_dist() < sight_range:
		state = State.CHASE
		_alert_t = 1.0
		Sfx.play_at("bark_alert", global_position)


func _face_point(point: Vector3) -> void:
	var flat := point - global_position
	flat.y = 0.0
	if flat.length() > 0.05:
		rig.rotation.y = atan2(flat.x, flat.z)


func _move_dir(dir: Vector3, _delta: float, speed_mult: float = 1.0) -> void:
	velocity.x = dir.x * move_speed * speed_mult
	velocity.z = dir.z * move_speed * speed_mult
	if dir.length() > 0.05:
		rig.rotation.y = atan2(dir.x, dir.z)


func _tick_patrol(delta: float) -> void:
	if patrol_points.is_empty():
		state = State.IDLE
		return
	var goal: Vector3 = patrol_points[_patrol_i]
	var flat := goal - global_position
	flat.y = 0.0
	if flat.length() < 0.6:
		_patrol_i = (_patrol_i + 1) % patrol_points.size()
		return
	_move_dir(flat.normalized(), delta, 0.5)


func _tick_chase(delta: float) -> void:
	var dist := _player_dist()
	if dist > sight_range * 1.6:
		state = State.PATROL if patrol_points.size() > 0 else State.IDLE
		return
	_face_point(_player.global_position)
	if has_gun:
		var flat: Vector3 = _player.global_position - global_position
		flat.y = 0.0
		if dist > 16.0:
			_move_dir(flat.normalized(), delta)
		elif dist < 8.0:
			_move_dir(-flat.normalized(), delta, 0.8)
		else:
			velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
			state = State.ATTACK
			_attack_t = 0.5
	else:
		if dist <= attack_range:
			state = State.ATTACK
			_attack_t = 0.3
		else:
			var flat2: Vector3 = _player.global_position - global_position
			flat2.y = 0.0
			_move_dir(flat2.normalized(), delta)


func _tick_attack(delta: float) -> void:
	var dist := _player_dist()
	if _player == null or _player.health.is_dead():
		state = State.IDLE
		return
	_face_point(_player.global_position)
	velocity.x = move_toward(velocity.x, 0.0, 24.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 24.0 * delta)
	if has_gun:
		if dist > 20.0:
			state = State.CHASE
			return
		_attack_t -= delta
		if _attack_t <= 0.0:
			_attack_t = attack_cooldown
			_shoot()
	else:
		if dist > attack_range * 1.35:
			state = State.CHASE
			return
		_attack_t -= delta
		if _attack_t <= 0.0:
			_attack_t = attack_cooldown
			Sfx.play_at("swing_whoosh", global_position, -4.0)
			Sfx.play_at("bark_attack", global_position, -8.0)
			_punch_t = 0.3
			if dist < attack_range * 1.25:
				_player.take_hit(damage, self)


func _shoot() -> void:
	if _player == null:
		return
	var tracer := TRACER_SCENE.instantiate() as Tracer
	get_tree().current_scene.add_child(tracer)
	tracer.global_position = global_position + Vector3(0, 1.5, 0)
	var aim: Vector3 = (_player.global_position + Vector3(0, 1.2, 0)) - tracer.global_position
	tracer.launch(aim.normalized(), damage * 0.8)
	_flash_muzzle(tracer.global_position + aim.normalized() * 0.9)
	Sfx.play_at("gunshot", global_position)


func _flash_muzzle(pos: Vector3) -> void:
	var scene := get_tree().current_scene as Node3D
	if scene == null:
		return
	var flash := Blockout.sphere(scene, pos, 0.22, Color(1, 0.8, 0.3))
	flash.material_override = Blockout.mat_emissive(Color(1, 0.75, 0.25), 4.0)
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().create_timer(0.06).timeout.connect(flash.queue_free)


# ------------------------------------------------------------------- damage --
func take_hit(amount: float, _from: Node = null) -> void:
	if state == State.DEAD:
		return
	health.take_damage(amount, _from)
	Sfx.play_at("hit", global_position)
	FX.hit_spark(get_tree().current_scene,
			global_position + Vector3(0, 1.2, 0), Color(1, 0.85, 0.3))
	_pop_scale()
	if state == State.DEAD:
		return
	Sfx.play_at("bark_hurt", global_position, -2.0)
	if state != State.STUNNED:
		state = State.STAGGER
		_stagger_t = 0.35
	elif state == State.STUNNED:
		_stun_t = maxf(0.5, _stun_t - 0.5)


func apply_web(stun_time: float) -> void:
	if state == State.DEAD:
		return
	state = State.STUNNED
	_stun_t = stun_time
	_cocoon.visible = true
	webbed.emit(self)


func yank_pull(pull_dir: Vector3) -> void:
	if state == State.DEAD:
		return
	state = State.STAGGER
	_stagger_t = 0.6
	velocity = pull_dir * 16.0 + Vector3(0, 4.0, 0)
	Sfx.play_at("bark_hurt", global_position, -4.0)


func air_pop(power: float) -> void:
	if state == State.DEAD:
		return
	velocity.y = power
	if state != State.STUNNED:
		state = State.STAGGER
		_stagger_t = 0.7


func _pop_scale() -> void:
	if _body_root == null:
		return
	var tween := create_tween()
	tween.tween_property(_body_root, "scale", Vector3(1.15, 0.85, 1.15), 0.06)
	tween.tween_property(_body_root, "scale", Vector3.ONE, 0.12)


func _die() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	_cocoon.visible = false
	if _alert_label != null:
		_alert_label.visible = false
	($CollisionShape3D as CollisionShape3D).set_deferred("disabled", true)
	Sfx.play_at("thug_down", global_position)
	var tween := create_tween().set_parallel(true)
	var rot := tween.tween_property(rig, "rotation:x", -PI * 0.5, 0.35)
	rot.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(rig, "position:y", 0.35, 0.35)
	downed.emit(self)


# --------------------------------------------------------------------- look --
func _build_body() -> void:
	rig_node = ThugRig.new()
	rig_node.has_gun = has_gun
	rig.add_child(rig_node)
	_body_root = rig_node
	_cocoon = MeshInstance3D.new()
	var cocoon_mesh := CapsuleMesh.new()
	cocoon_mesh.radius = 0.55
	cocoon_mesh.height = 2.0
	_cocoon.mesh = cocoon_mesh
	_cocoon.material_override = Blockout.mat_transparent(Color(0.92, 0.94, 0.96, 0.75))
	_cocoon.position = Vector3(0, 1.0, 0)
	_cocoon.visible = false
	rig.add_child(_cocoon)
	_alert_label = Blockout.label(rig, Vector3(0, 2.3, 0), "!", Color(1, 0.25, 0.2), 96)
	_alert_label.visible = false
