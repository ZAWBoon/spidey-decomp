class_name Player
extends CharacterBody3D
## Spider-Man controller: run/sprint/jump (coyote+buffer), 3-hit combo,
## web shots (stun), web swinging, hold-to-interact.

signal fluid_changed(value: float, maximum: float)

const WALK_SPEED := 6.0
const SPRINT_SPEED := 9.5
const TURN_SPEED := 12.0
const JUMP_SPEED := 7.5
const COYOTE_TIME := 0.12
const JUMP_BUFFER := 0.12
const ATTACK_DAMAGE: Array[float] = [22.0, 22.0, 38.0]
const ATTACK_TIME: Array[float] = [0.32, 0.32, 0.45]
const COMBO_WINDOW := 0.9
const WEB_COST := 10.0
const WEB_MAX := 100.0
const WEB_REGEN := 6.0
const WEB_REGEN_DELAY := 1.5
const SWING_RANGE := 30.0
const SWING_MIN_HEIGHT := 3.0
const SWING_MAX_SPEED := 19.0
const INTERACT_RANGE := 3.2

const WEBSHOT_SCENE: PackedScene = preload("res://combat/webshot.tscn")

var gravity: float = 22.0
var web_fluid: float = WEB_MAX
var input_enabled: bool = true

var _regen_t: float = 0.0
var _coyote: float = 0.0
var _buffer: float = 0.0
var _combo: int = 0
var _combo_t: float = 0.0
var _attack_t: float = 0.0
var _attack_hit_done: bool = false
var _iframes: float = 0.0
var _swinging: bool = false
var _anchor: Vector3 = Vector3.ZERO
var _rope_len: float = 0.0
var _rope_visible: bool = false
var _target: Interactable = null
var _pending_rope_fix: bool = false

@onready var rig: Node3D = $Rig
@onready var cam_rig: CameraRig = $CameraRig
@onready var health: Health = $Health
@onready var punch_area: Area3D = $PunchArea
@onready var web_origin: Marker3D = $WebOrigin
@onready var rope: MeshInstance3D = $RopeMesh


func _ready() -> void:
	add_to_group("player")
	gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 22.0))
	_build_body()
	health.died.connect(_on_died)
	rope.mesh = ImmediateMesh.new()
	rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var rope_mat := StandardMaterial3D.new()
	rope_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rope_mat.albedo_color = Color(0.95, 0.95, 0.95)
	rope.material_override = rope_mat


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	if not input_enabled or health.is_dead():
		velocity.x = move_toward(velocity.x, 0.0, 40.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 40.0 * delta)
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		_update_rope()
		return

	var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish: Vector3 = cam_rig.get_move_basis() * Vector3(input_vec.x, 0.0, input_vec.y)
	if wish.length() > 1.0:
		wish = wish.normalized()
	var sprinting := Input.is_action_pressed("sprint") and input_vec.length() > 0.1

	if _swinging:
		_physics_swing(delta, wish)
	else:
		_physics_ground(delta, wish, sprinting, input_vec)

	_physics_attack(delta)
	_physics_web()
	_physics_swing_input()
	_physics_interact(delta)
	_tick_web_regen(delta)

	move_and_slide()
	_update_rope()

	if global_position.y < -40.0 and Game.level != null:
		Game.level.respawn_player()


func _tick_timers(delta: float) -> void:
	_coyote = COYOTE_TIME if is_on_floor() else maxf(0.0, _coyote - delta)
	_buffer = maxf(0.0, _buffer - delta)
	_combo_t = maxf(0.0, _combo_t - delta)
	_attack_t = maxf(0.0, _attack_t - delta)
	_iframes = maxf(0.0, _iframes - delta)
	if Input.is_action_just_pressed("jump"):
		_buffer = JUMP_BUFFER


func _physics_ground(delta: float, wish: Vector3, sprinting: bool, input_vec: Vector2) -> void:
	var target_speed := SPRINT_SPEED if sprinting else WALK_SPEED
	var accel := 42.0 if is_on_floor() else 14.0
	var target_vel := wish * target_speed
	if input_vec.length() < 0.1:
		accel = 34.0 if is_on_floor() else 4.0
		target_vel = Vector3.ZERO
	velocity.x = move_toward(velocity.x, target_vel.x, accel * delta)
	velocity.z = move_toward(velocity.z, target_vel.z, accel * delta)
	if wish.length() > 0.1:
		_face_direction(wish, delta)
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.5
	if _buffer > 0.0 and (is_on_floor() or _coyote > 0.0):
		velocity.y = JUMP_SPEED
		_buffer = 0.0
		_coyote = 0.0
		Sfx.play("jump")


func _face_direction(dir: Vector3, delta: float) -> void:
	var target_yaw := atan2(dir.x, dir.z)
	var current := rig.rotation.y
	rig.rotation.y = current + _angle_diff(current, target_yaw) * minf(1.0, TURN_SPEED * delta)


func _angle_diff(from: float, to: float) -> float:
	var d := fmod(to - from + PI, TAU)
	if d < 0.0:
		d += TAU
	return d - PI


# ------------------------------------------------------------------ combat --
func _physics_attack(_delta: float) -> void:
	if Input.is_action_just_pressed("attack") and _attack_t <= 0.0:
		if _combo_t > 0.0:
			_combo = mini(_combo + 1, 2)
		else:
			_combo = 0
		_combo_t = COMBO_WINDOW
		_attack_t = ATTACK_TIME[_combo]
		_attack_hit_done = false
		var fwd := -cam_rig.get_move_basis().z
		fwd.y = 0.0
		if fwd.length() > 0.01:
			_face_direction(fwd.normalized(), 1.0)
			if is_on_floor():
				velocity += fwd.normalized() * 2.5
		Sfx.play("swing_whoosh", -6.0)
	if _attack_t <= 0.0 or _attack_hit_done:
		return
	# Hit lands during the first 60% of the swing.
	var total: float = ATTACK_TIME[_combo]
	if _attack_t < total * 0.4:
		return
	_attack_hit_done = true
	var hit_any := false
	for body in punch_area.get_overlapping_bodies():
		if body.is_in_group("enemies"):
			var enemy: Variant = body
			enemy.take_hit(ATTACK_DAMAGE[_combo], self)
			hit_any = true
	if hit_any:
		Sfx.play("punch")
		cam_rig.add_trauma(0.25 + 0.12 * _combo)


func _physics_web() -> void:
	if not Input.is_action_just_pressed("web"):
		return
	_fire_web()


func _fire_web() -> void:
	if health.is_dead():
		return
	if web_fluid < WEB_COST:
		Sfx.play("empty")
		if Game.hud != null:
			Game.hud.flash_message("No web fluid!", Color(1, 0.6, 0.3))
		return
	web_fluid -= WEB_COST
	_regen_t = 0.0
	fluid_changed.emit(web_fluid, WEB_MAX)
	var shot := WEBSHOT_SCENE.instantiate() as Webshot
	get_tree().current_scene.add_child(shot)
	shot.global_position = web_origin.global_position
	var aim := cam_rig.get_aim_point() - web_origin.global_position
	if aim.length() < 0.5:
		aim = -global_transform.basis.z
	shot.launch(aim.normalized())
	var fwd := aim
	fwd.y = 0.0
	if fwd.length() > 0.01:
		_face_direction(fwd.normalized(), 1.0)
	Sfx.play("thwip")


func debug_fire_web() -> void:
	web_fluid = WEB_MAX
	_fire_web()


func _tick_web_regen(delta: float) -> void:
	_regen_t += delta
	if _regen_t >= WEB_REGEN_DELAY and web_fluid < WEB_MAX:
		web_fluid = minf(WEB_MAX, web_fluid + WEB_REGEN * delta)
		fluid_changed.emit(web_fluid, WEB_MAX)


# ------------------------------------------------------------------- swing --
func is_swinging() -> bool:
	return _swinging


func _physics_swing_input() -> void:
	if Input.is_action_just_pressed("swing"):
		_try_attach()
	if _swinging and not Input.is_action_pressed("swing"):
		_detach(true)


func _try_attach() -> void:
	var best: Node3D = null
	var best_dist := SWING_RANGE
	for node in get_tree().get_nodes_in_group("swing_anchor"):
		var anchor := node as Node3D
		if anchor == null:
			continue
		var to: Vector3 = anchor.global_position - global_position
		if to.y > SWING_MIN_HEIGHT and to.length() < best_dist:
			best = anchor
			best_dist = to.length()
	if best == null:
		return
	_swinging = true
	_anchor = best.global_position
	_rope_len = best_dist
	velocity *= 0.85
	Sfx.play("swing_whoosh")


func _detach(with_boost: bool) -> void:
	if not _swinging:
		return
	_swinging = false
	if with_boost:
		velocity *= 1.08
		velocity.y += 1.0
	_clear_rope()


func _physics_swing(delta: float, wish: Vector3) -> void:
	# Pendulum: strip radial velocity, add gravity + pumping.
	var offset := global_position - _anchor
	var dist := offset.length()
	if dist < 0.5:
		_detach(false)
		return
	var radial := offset / dist
	velocity -= radial * velocity.dot(radial)
	velocity += Vector3.DOWN * gravity * 0.92 * delta
	velocity += wish * 7.0 * delta
	if velocity.length() > SWING_MAX_SPEED:
		velocity = velocity.normalized() * SWING_MAX_SPEED
	if velocity.length() > 0.5:
		_face_direction(velocity.normalized(), delta)
	if not is_on_floor():
		velocity.y = maxf(velocity.y, -24.0)
	# Hard rope constraint after sliding (applied post-move in caller).
	_pending_rope_fix = true


func _update_rope() -> void:
	if _pending_rope_fix:
		_pending_rope_fix = false
		if _swinging:
			var offset := global_position - _anchor
			if offset.length() > _rope_len:
				global_position = _anchor + offset.normalized() * _rope_len
	var mesh := rope.mesh as ImmediateMesh
	if mesh == null:
		return
	if not _swinging:
		if _rope_visible:
			mesh.clear_surfaces()
			_rope_visible = false
		return
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(Vector3(0, 1.5, 0))
	mesh.surface_add_vertex(rope.to_local(_anchor))
	mesh.surface_end()
	_rope_visible = true


func _clear_rope() -> void:
	var mesh := rope.mesh as ImmediateMesh
	if mesh != null and _rope_visible:
		mesh.clear_surfaces()
		_rope_visible = false


# ---------------------------------------------------------------- interact --
func _physics_interact(delta: float) -> void:
	var nearest: Interactable = null
	var nearest_dist := INTERACT_RANGE
	for node in get_tree().get_nodes_in_group("interactable"):
		var inter := node as Interactable
		if inter == null or not inter.can_use():
			continue
		var d := global_position.distance_to((node as Node3D).global_position)
		if d < nearest_dist:
			nearest = inter
			nearest_dist = d
	if nearest != _target:
		if _target != null:
			_target.reset_hold()
		_target = nearest
		if Game.hud != null:
			Game.hud.hide_prompt()
	if _target == null or Game.hud == null:
		return
	Game.hud.show_prompt(_target.get_prompt())
	if _target.hold_time <= 0.0:
		if Input.is_action_just_pressed("interact"):
			_target.do_use()
			_target = null
			Game.hud.hide_prompt()
	else:
		if Input.is_action_pressed("interact"):
			Game.hud.update_hold(_target.get_progress())
			if _target.hold_tick(delta):
				_target = null
				Game.hud.hide_prompt()
		else:
			_target.reset_hold()
			Game.hud.update_hold(0.0)


# ------------------------------------------------------------------- damage --
func take_hit(damage: float, _from: Node = null) -> void:
	if health.is_dead() or _iframes > 0.0:
		return
	_iframes = 0.6
	_detach(false)
	health.take_damage(damage, _from)
	Sfx.play("hurt")
	if Game.hud != null:
		Game.hud.damage_flash()
	cam_rig.add_trauma(0.55)


func add_fluid(amount: float) -> void:
	web_fluid = minf(WEB_MAX, web_fluid + amount)
	fluid_changed.emit(web_fluid, WEB_MAX)


func add_health(amount: float) -> void:
	health.heal(amount)


func get_horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func _on_died() -> void:
	_detach(false)
	input_enabled = false
	Game.trigger_game_over("Spider-Man is down!")


# --------------------------------------------------------------------- look --
func _build_body() -> void:
	# Blockout hero: red torso, blue legs/head, white comic eyes.
	var torso := Blockout.capsule_mesh(rig, Vector3(0, 1.05, 0), 0.32, 1.0,
		Color(0.75, 0.08, 0.12))
	torso.name = "Torso"
	var leg_c := Color(0.08, 0.12, 0.5)
	var arm_c := Color(0.75, 0.08, 0.12)
	Blockout.capsule_mesh(rig, Vector3(-0.18, 0.35, 0), 0.13, 0.7, leg_c).name = "LegL"
	Blockout.capsule_mesh(rig, Vector3(0.18, 0.35, 0), 0.13, 0.7, leg_c).name = "LegR"
	Blockout.capsule_mesh(rig, Vector3(-0.42, 1.1, 0), 0.11, 0.62, arm_c).name = "ArmL"
	Blockout.capsule_mesh(rig, Vector3(0.42, 1.1, 0), 0.11, 0.62, arm_c).name = "ArmR"
	Blockout.sphere(rig, Vector3(0, 1.72, 0), 0.22, Color(0.75, 0.08, 0.12)).name = "Head"
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.95, 0.97, 1.0)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(0.9, 0.95, 1.0)
	eye_mat.emission_energy_multiplier = 0.6
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.055
		mesh.height = 0.16
		eye.mesh = mesh
		eye.material_override = eye_mat
		eye.position = Vector3(side * 0.09, 1.76, 0.17)
		eye.rotation.z = side * -0.35
		rig.add_child(eye)
