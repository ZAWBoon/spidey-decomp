class_name Rhino
extends CharacterBody3D
## L4 boss. Paws the ground (telegraphed), then charges in a locked line:
## sidestep it, lure him into a wall, punish the stun. Hide armor halves
## punch damage; wall-stunned Rhino takes x1.5. Webs only stagger/slow.

signal downed
signal activated

enum State { DORMANT, PAW, CHARGE, WALLSTUN, STAGGER, DEAD }

@export var max_hp: float = 400.0
@export var charge_speed: float = 15.0
@export var charge_damage: float = 20.0
@export var paw_time: float = 0.9
@export var stun_time: float = 3.0
@export var charge_timeout: float = 2.5

var state: int = State.DORMANT
var gravity: float = 22.0

var _charge_dir: Vector3 = Vector3.ZERO
var _state_t: float = 0.0
var _slow_t: float = 0.0
var _hit_done: bool = false
var _enraged: bool = false
var _player = null
var _body_root: Node3D = null

@onready var rig: Node3D = $Rig
@onready var health: Health = $Health


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("rhino")
	gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 22.0))
	health.max_hp = max_hp
	health.reset()
	health.died.connect(_die)
	health.changed.connect(_on_hp_changed)
	_build_body()


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_player = Game.player
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.5
	_slow_t = maxf(0.0, _slow_t - delta)

	match state:
		State.DORMANT:
			_brake(delta)
		State.PAW:
			_tick_paw(delta)
		State.CHARGE:
			_tick_charge(delta)
		State.WALLSTUN:
			_brake(delta)
			_state_t -= delta
			if _state_t <= 0.0:
				_to_paw()
		State.STAGGER:
			_brake(delta)
			_state_t -= delta
			if _state_t <= 0.0:
				_to_paw()
	move_and_slide()
	if state == State.CHARGE:
		_check_charge_hits()


func activate() -> void:
	if state != State.DORMANT:
		return
	_to_paw()
	Sfx.play_at("roar", global_position)
	if Game.hud != null:
		Game.hud.show_boss("RHINO", health.hp, health.max_hp)
		Game.hud.flash_message("RHINO! Sidestep the charge!", Color(1, 0.5, 0.2), 3.0)
	Game.set_objective("Bring down Rhino!")
	activated.emit()


func take_hit(amount: float, _from: Node = null) -> void:
	if state == State.DEAD:
		return
	if state == State.DORMANT:
		activate()
	if state == State.WALLSTUN:
		amount *= 1.5
	else:
		amount *= 0.5
	health.take_damage(amount, _from)
	Sfx.play_at("hit", global_position)
	_pop_scale()
	if state == State.DEAD:
		return
	if not _enraged and health.hp < health.max_hp * 0.3:
		_enraged = true
		paw_time = 0.6
		charge_speed = 17.0
		Sfx.play_at("roar", global_position)
		if Game.hud != null:
			Game.hud.flash_message("RHINO ENRAGED!", Color(1, 0.2, 0.2), 2.5)


func apply_web(_stun_time: float) -> void:
	if state == State.DEAD:
		return
	if state == State.DORMANT:
		activate()
	if state == State.CHARGE:
		_slow_t = 2.0
	else:
		state = State.STAGGER
		_state_t = 0.8


func _to_paw() -> void:
	state = State.PAW
	_state_t = paw_time


func _tick_paw(delta: float) -> void:
	_brake(delta)
	if _player != null and not _player.health.is_dead():
		_face_point(_player.global_position)
	_state_t -= delta
	if _state_t <= 0.0:
		_start_charge()


func _start_charge() -> void:
	state = State.CHARGE
	_state_t = charge_timeout
	_hit_done = false
	_charge_dir = -rig.global_transform.basis.z
	_charge_dir.y = 0.0
	if _charge_dir.length() < 0.05:
		_charge_dir = Vector3(0, 0, 1)
	_charge_dir = _charge_dir.normalized()
	Sfx.play_at("roar", global_position, -6.0)


func _tick_charge(delta: float) -> void:
	var speed := charge_speed * (0.5 if _slow_t > 0.0 else 1.0)
	velocity.x = _charge_dir.x * speed
	velocity.z = _charge_dir.z * speed
	_state_t -= delta
	if not _hit_done and _player != null and not _player.health.is_dead():
		var flat: Vector3 = _player.global_position - global_position
		var dy: float = flat.y
		flat.y = 0.0
		if flat.length() < 2.6 and dy < 1.0:
			_hit_done = true
			_player.take_hit(charge_damage, self)
			var push := flat.normalized() if flat.length() > 0.05 else -_charge_dir
			_player.velocity = push * 14.0 + Vector3(0, 5, 0)
	if _state_t <= 0.0:
		_to_paw()


func _check_charge_hits() -> void:
	for i in get_slide_collision_count():
		var collider := get_slide_collision(i).get_collider()
		if collider is Car:
			(collider as Car).smash()
		elif collider is StaticBody3D:
			_wall_stun()
			return


func _wall_stun() -> void:
	state = State.WALLSTUN
	_state_t = 2.2 if _enraged else stun_time
	velocity = Vector3.ZERO
	Sfx.play_at("crash", global_position)
	var scene := get_tree().current_scene
	FX.burst(scene, global_position + Vector3(0, 1, 0),
			Color(0.8, 0.75, 0.7), 20, 8.0, 0.15, 0.6)
	FX.ring(scene, global_position, Color(1, 0.8, 0.4, 0.8), 4.0, 0.35)
	if Game.hud != null:
		Game.hud.flash_message("Now! Hit him!", Color(0.4, 1, 0.5), 2.0)
	if _player != null:
		var dist: float = global_position.distance_to(_player.global_position)
		if dist < 15.0:
			_player.cam_rig.add_trauma(0.7)


func _brake(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 24.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 24.0 * delta)


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
	($CollisionShape3D as CollisionShape3D).set_deferred("disabled", true)
	Sfx.play_at("crash", global_position)
	Sfx.play_at("thug_down", global_position, -4.0)
	if Game.hud != null:
		Game.hud.hide_boss()
	var tween := create_tween().set_parallel(true)
	var tip := tween.tween_property(rig, "rotation:z", PI * 0.5, 0.5)
	tip.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(rig, "position:y", 0.7, 0.5)
	downed.emit()


# --------------------------------------------------------------------- look --
func _build_body() -> void:
	_body_root = Node3D.new()
	_body_root.name = "Body"
	rig.add_child(_body_root)
	var hide := Color(0.45, 0.45, 0.48)
	var dark := Color(0.32, 0.32, 0.35)
	var horn_c := Color(0.85, 0.82, 0.7)
	var root := _body_root
	Blockout.box(root, Vector3(0, 1.25, -0.1), Vector3(1.9, 1.5, 2.7), hide, false).name = "Torso"
	Blockout.box(root, Vector3(0, 2.05, 0.5), Vector3(1.6, 0.7, 1.2), hide, false).name = "Hump"
	Blockout.box(root, Vector3(0, 1.4, 1.7), Vector3(1.2, 1.0, 1.1), hide, false).name = "Head"
	Blockout.box(root, Vector3(0, 1.2, 2.4), Vector3(0.7, 0.6, 0.5), dark, false).name = "Snout"
	var horn := Blockout.cylinder(root, Vector3(0, 1.45, 2.9), 0.14, 0.9, horn_c, false)
	horn.rotation.x = PI * 0.5
	horn.name = "HornBig"
	var horn2 := Blockout.cylinder(root, Vector3(0, 1.75, 2.45), 0.1, 0.5, horn_c, false)
	horn2.rotation.x = PI * 0.5
	horn2.name = "HornSmall"
	for sx in [-0.65, 0.65]:
		for sz in [-0.9, 0.9]:
			Blockout.cylinder(root, Vector3(sx, 0.5, sz), 0.28, 1.0, dark, false).name = "Leg"
	for sz in [-0.3, -0.9, -1.5]:
		Blockout.box(root, Vector3(0, 2.1, sz), Vector3(0.3, 0.4, 0.5), dark, false).name = "Plate"
	var eye_mat := Blockout.mat_emissive(Color(1, 0.1, 0.1), 2.0)
	for sx in [-0.32, 0.32]:
		var eye := Blockout.sphere(root, Vector3(sx, 1.7, 2.2), 0.1, Color(1, 0.1, 0.1))
		eye.material_override = eye_mat
		eye.name = "Eye"
