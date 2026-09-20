class_name Mysterio
extends CharacterBody3D
## L6 boss: illusionist. Never walks - only teleports between pedestals.
## Fields 1-HP transparent clones that shoot back (the SOLID one is real).
## Interrupt volleys, jump the hypno wave, chase the teleports.

signal downed
signal activated

enum State { DORMANT, TAUNT, VOLLEY_W, VOLLEY, WAVE_W, WAVE, VANISH, APPEAR,
	STAGGER, DEAD }

const MYSTERIO_SCENE: PackedScene = preload("res://enemies/mysterio.tscn")
const TRACER_SCENE: PackedScene = preload("res://combat/tracer.tscn")
const BOLT_TINT := Color(0.7, 0.3, 1.0)

@export var max_hp: float = 500.0
@export var bolt_damage: float = 10.0
@export var wave_damage: float = 12.0
@export var is_clone: bool = false

var pedestals: Array[Vector3] = []
var state: int = State.DORMANT
var gravity: float = 22.0

var _state_t: float = 0.0
var _act_cd: float = 2.0
var _tele_cd: float = 7.0
var _shots_left: int = 0
var _shot_t: float = 0.0
var _bolt_cd: float = 1.5
var _wave_next: bool = false
var _ped_i: int = 0
var _enraged: bool = false
var _clones: Array[Mysterio] = []
var _player = null
var _body_root: Node3D = null
var _ring: MeshInstance3D = null

@onready var rig: Node3D = $Rig
@onready var health: Health = $Health


func _ready() -> void:
	add_to_group("enemies")
	if not is_clone:
		add_to_group("mysterio")
	gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 22.0))
	if is_clone:
		max_hp = 1.0
	health.max_hp = max_hp
	health.reset()
	health.died.connect(_die)
	health.changed.connect(_on_hp_changed)
	_build_body()
	if is_clone:
		_ghostify()
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
		State.TAUNT:
			_tick_taunt(delta)
		State.VOLLEY_W:
			_brake(delta)
			_face_player()
			_state_t -= delta
			if _state_t <= 0.0:
				_to_volley()
		State.VOLLEY:
			_tick_volley(delta)
		State.WAVE_W:
			_brake(delta)
			_state_t -= delta
			if _state_t <= 0.0:
				_do_wave()
		State.WAVE:
			_brake(delta)
			_state_t -= delta
			if _state_t <= 0.0:
				state = State.TAUNT
		State.VANISH:
			_brake(delta)
			_state_t -= delta
			if _state_t <= 0.0:
				_reappear()
		State.APPEAR:
			_brake(delta)
			_state_t -= delta
			if _state_t <= 0.0:
				state = State.TAUNT
		State.STAGGER:
			_brake(delta)
			_state_t -= delta
			if _state_t <= 0.0:
				state = State.TAUNT
	move_and_slide()


func activate() -> void:
	if is_clone or state != State.DORMANT:
		return
	state = State.TAUNT
	_ped_i = 0
	_act_cd = 2.0
	_tele_cd = 7.0
	Sfx.play_at("sting", global_position)
	if Game.hud != null:
		Game.hud.show_boss("MYSTERIO", health.hp, health.max_hp)
		Game.hud.flash_message("MYSTERIO! The solid one is real!",
			Color(0.8, 0.5, 1.0), 3.0)
	Game.set_objective("Unmask Mysterio!")
	_spawn_clones()
	activated.emit()


func take_hit(amount: float, _from: Node = null) -> void:
	if state == State.DEAD:
		return
	if state == State.DORMANT and not is_clone:
		activate()
	if not is_clone and state == State.VOLLEY_W:
		state = State.STAGGER
		_state_t = 1.0
		_act_cd = maxf(_act_cd, 1.5)
		if Game.hud != null:
			Game.hud.flash_message("Interrupted!", Color(0.4, 1, 0.5), 1.5)
	health.take_damage(amount, _from)
	Sfx.play_at("hit", global_position)
	_pop_scale()
	if state == State.DEAD:
		return
	if not is_clone and not _enraged and health.hp < health.max_hp * 0.3:
		_enraged = true
		_tele_cd = minf(_tele_cd, 2.0)
		_spawn_clones()
		Sfx.play_at("sting", global_position)
		if Game.hud != null:
			Game.hud.flash_message("MYSTERIO ENRAGED!", Color(1, 0.2, 0.2), 2.5)


func apply_web(_stun_time: float) -> void:
	if state == State.DEAD:
		return
	if state == State.DORMANT and not is_clone:
		activate()
	if is_clone:
		return
	state = State.STAGGER
	_state_t = 1.0
	_act_cd = maxf(_act_cd, 1.5)


func _tick_taunt(delta: float) -> void:
	_brake(delta)
	_face_player()
	if is_clone:
		_bolt_cd -= delta
		if _bolt_cd <= 0.0:
			_bolt_cd = 3.0
			_fire_bolt(6.0, 16.0)
		return
	_act_cd -= delta
	_tele_cd -= delta
	if _tele_cd <= 0.0:
		_vanish()
		return
	if _act_cd > 0.0:
		return
	var dist := 9999.0
	if _player != null:
		dist = global_position.distance_to(_player.global_position)
	if dist < 7.0 or _wave_next:
		_wave_next = false
		_to_wave_w()
	else:
		_wave_next = true
		state = State.VOLLEY_W
		_state_t = 0.7
		Sfx.play_at("beep", global_position)


func _to_volley() -> void:
	state = State.VOLLEY
	_shots_left = 5 if _enraged else 3
	_shot_t = 0.0


func _tick_volley(delta: float) -> void:
	_brake(delta)
	_face_player()
	_shot_t -= delta
	if _shots_left > 0 and _shot_t <= 0.0:
		_fire_bolt(bolt_damage, 18.0)
		_shots_left -= 1
		_shot_t = 0.2
	if _shots_left <= 0:
		state = State.TAUNT
		_act_cd = 1.2 if _enraged else 2.0


func _to_wave_w() -> void:
	state = State.WAVE_W
	_state_t = 0.8
	_ring.visible = true
	Sfx.play_at("beep", global_position, -2.0)


func _do_wave() -> void:
	_ring.visible = false
	state = State.WAVE
	_state_t = 0.4
	_act_cd = 1.5 if _enraged else 2.5
	Sfx.play_at("crash", global_position)
	if _player == null or _player.health.is_dead():
		return
	var to: Vector3 = _player.global_position - global_position
	var dy: float = to.y
	to.y = 0.0
	if to.length() < 9.0:
		_player.cam_rig.add_trauma(0.6)
		if to.length() < 6.0 and dy < 1.0:
			_player.take_hit(wave_damage, self)
			var push := to.normalized() if to.length() > 0.05 else Vector3(0, 0, 1)
			_player.velocity = push * 8.0 + Vector3(0, 5, 0)


func _vanish() -> void:
	state = State.VANISH
	_state_t = 0.4
	rig.visible = false
	Sfx.play_at("poof", global_position)


func _reappear() -> void:
	_ped_i = _pick_pedestal([_ped_i])
	if _ped_i >= 0 and _ped_i < pedestals.size():
		global_position = pedestals[_ped_i]
		velocity = Vector3.ZERO
	rig.visible = true
	state = State.APPEAR
	_state_t = 0.3
	_tele_cd = 4.5 if _enraged else 7.0
	Sfx.play_at("poof", global_position)
	var scene := get_tree().current_scene
	FX.poof(scene, global_position + Vector3(0, 1.2, 0), Color(0.7, 0.3, 1.0))
	FX.ring(scene, global_position, Color(0.7, 0.3, 1.0, 0.7), 3.0, 0.35)
	_reshuffle_clones()


func _pick_pedestal(avoid: Array) -> int:
	var options: Array[int] = []
	for i in pedestals.size():
		if not avoid.has(i):
			options.append(i)
	if options.is_empty() or pedestals.is_empty():
		return _ped_i
	return options[randi() % options.size()]


func _live_clones() -> Array[Mysterio]:
	var alive: Array[Mysterio] = []
	for clone in _clones:
		if is_instance_valid(clone) and clone.state != State.DEAD:
			alive.append(clone)
	_clones = alive
	return alive


func _spawn_clones() -> void:
	if is_clone or pedestals.is_empty():
		return
	var want := 3 if _enraged else 2
	var alive := _live_clones()
	var taken: Array = [_ped_i]
	for clone in alive:
		taken.append(clone._ped_i)
	while alive.size() < want:
		var idx := _pick_pedestal(taken)
		taken.append(idx)
		var clone := MYSTERIO_SCENE.instantiate() as Mysterio
		clone.is_clone = true
		clone.pedestals = pedestals
		clone._ped_i = idx
		get_parent().add_child(clone)
		clone.global_position = pedestals[idx]
		clone._clone_start()
		_clones.append(clone)
		alive.append(clone)


func _reshuffle_clones() -> void:
	var taken: Array = [_ped_i]
	for clone in _live_clones():
		var idx := _pick_pedestal(taken)
		taken.append(idx)
		clone._ped_i = idx
		clone.global_position = pedestals[idx]
		Sfx.play_at("poof", pedestals[idx], -4.0)


func _clone_start() -> void:
	state = State.TAUNT
	_bolt_cd = 1.5


func _fire_bolt(dmg: float, speed: float) -> void:
	if _player == null or _player.health.is_dead():
		return
	_face_player()
	var fwd: Vector3 = rig.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.05 else Vector3(0, 0, 1)
	var origin := global_position + Vector3(0, 2.0, 0) + fwd * 0.8
	var target := _player.global_position + Vector3(0, 1.2, 0)
	var dir := (target - origin).normalized()
	var bolt := TRACER_SCENE.instantiate() as Tracer
	bolt.tint = BOLT_TINT
	bolt.speed = speed
	get_tree().current_scene.add_child(bolt)
	bolt.global_position = origin
	bolt.launch(dir, dmg)
	Sfx.play_at("sting", origin, -4.0)


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
	if is_clone:
		return
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
	if is_clone:
		_shatter()
		return
	($CollisionShape3D as CollisionShape3D).set_deferred("disabled", true)
	Sfx.play_at("crash", global_position)
	Sfx.play_at("thug_down", global_position, -4.0)
	if Game.hud != null:
		Game.hud.hide_boss()
	for clone in _live_clones():
		clone._shatter()
	var tween := create_tween().set_parallel(true)
	var fall := tween.tween_property(rig, "rotation:x", -PI * 0.5, 0.35)
	fall.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(rig, "position:y", 0.35, 0.35)
	downed.emit()


func _shatter() -> void:
	Sfx.play_at("poof", global_position)
	Game.add_score(25)
	var scene := get_tree().current_scene as Node3D
	if scene != null:
		var puff := Blockout.sphere(scene, global_position + Vector3(0, 1.2, 0),
			0.6, Color(0.5, 1, 0.6))
		puff.material_override = Blockout.mat_transparent(Color(0.5, 1, 0.6, 0.6))
		var timer := get_tree().create_timer(0.3)
		timer.timeout.connect(puff.queue_free)
	queue_free()


# --------------------------------------------------------------------- look --
func _build_body() -> void:
	_body_root = Node3D.new()
	_body_root.name = "Body"
	rig.add_child(_body_root)
	var suit := Color(0.1, 0.5, 0.25)
	var dark := Color(0.06, 0.2, 0.1)
	var cape := Color(0.35, 0.1, 0.5)
	var gold := Color(0.85, 0.65, 0.15)
	var root := _body_root
	var dome := Blockout.sphere(root, Vector3(0, 2.0, 0), 0.45,
		Color(0.75, 0.88, 1.0))
	dome.material_override = Blockout.mat_transparent(Color(0.75, 0.88, 1.0, 0.35))
	dome.name = "Dome"
	Blockout.sphere(root, Vector3(0, 1.95, 0), 0.24,
		Color(0.85, 0.65, 0.5)).name = "Head"
	Blockout.capsule_mesh(root, Vector3(0, 1.05, 0), 0.32, 1.1, suit).name = "Torso"
	Blockout.box(root, Vector3(0, 1.2, -0.4), Vector3(0.9, 1.2, 0.15),
		cape, false).name = "Cape"
	for sx in [-0.2, 0.2]:
		Blockout.capsule_mesh(root, Vector3(sx, 0.35, 0), 0.13, 0.7, dark).name = "Leg"
	for sx in [-0.42, 0.42]:
		Blockout.capsule_mesh(root, Vector3(sx, 1.1, 0), 0.11, 0.62, suit).name = "Arm"
		Blockout.sphere(root, Vector3(sx, 0.75, 0), 0.1, gold).name = "Glove"


func _ghostify() -> void:
	var ghost := Blockout.mat_transparent(Color(0.5, 1, 0.6, 0.45))
	for child in _body_root.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).material_override = ghost


func _build_ring() -> void:
	_ring = MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 6.0
	mesh.bottom_radius = 6.0
	mesh.height = 0.06
	_ring.mesh = mesh
	_ring.material_override = Blockout.mat_transparent(Color(0.7, 0.3, 1.0, 0.4))
	_ring.position = Vector3(0, 0.05, 0)
	_ring.visible = false
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
