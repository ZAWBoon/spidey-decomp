class_name Civilian
extends CharacterBody3D
## Ambient pedestrian: wanders around its spawn point, pauses, cowers when
## enemies come close or the player sprints past. Code-built (no tscn):
## ghost vs actors (layer 0, so punches pass through) but solid vs the
## world (mask 1). Home is captured on the first physics frame, because
## levels add_child() before setting positions.

@export var roam_radius: float = 10.0
@export var walk_speed: float = 1.6

var gravity: float = 22.0

var _homed: bool = false
var _home: Vector3 = Vector3.ZERO
var _target: Vector3 = Vector3.ZERO
var _has_target: bool = false
var _idle_t: float = 0.0
var _bob_t: float = 0.0
var _size: float = 1.0
var _body: Node3D = null


func _ready() -> void:
	add_to_group("civilians")
	collision_layer = 0
	collision_mask = 1
	gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 22.0))
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.5
	cs.shape = cap
	cs.position = Vector3(0, 0.75, 0)
	add_child(cs)
	_build_look()


func _physics_process(delta: float) -> void:
	if not _homed:
		_homed = true
		_home = global_position
		_target = global_position
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.5
	_bob_t += delta
	if _threat_near():
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
		_has_target = false
		_idle_t = 1.0
		_pose_cower()
	else:
		_tick_wander(delta)
	move_and_slide()


func _threat_near() -> bool:
	if Game.player != null:
		var hero: Variant = Game.player
		var pp: Vector3 = (Game.player as Node3D).global_position
		if global_position.distance_to(pp) < 3.5 and hero.get_horizontal_speed() > 7.0:
			return true
	for node in get_tree().get_nodes_in_group("enemies"):
		if not (node is CharacterBody3D):
			continue  # Static props (barrels, breakables) are not scary.
		var e := node as Node3D
		if e != null and global_position.distance_to(e.global_position) < 7.0:
			return true
	return false


func _tick_wander(delta: float) -> void:
	if _has_target:
		var flat := _target - global_position
		flat.y = 0.0
		if flat.length() < 0.6:
			_has_target = false
			_idle_t = randf_range(1.0, 3.0)
		else:
			velocity.x = flat.normalized().x * walk_speed
			velocity.z = flat.normalized().z * walk_speed
			rotation.y = atan2(flat.x, flat.z)
			_pose_walk()
			return
	velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
	_idle_t -= delta
	_pose_idle()
	if _idle_t <= 0.0:
		_has_target = true
		_target = _home + Vector3(randf_range(-roam_radius, roam_radius), 0.0, \
			randf_range(-roam_radius, roam_radius))


func _pose_walk() -> void:
	_body.scale = Vector3(_size, _size, _size)
	_body.position = Vector3(0.0, 0.06 * absf(sin(_bob_t * 8.0)), 0.0)
	_body.rotation.z = 0.06 * sin(_bob_t * 4.0)


func _pose_idle() -> void:
	_body.scale = Vector3(_size, _size, _size)
	_body.position = Vector3(0.0, 0.01 * sin(_bob_t * 2.0), 0.0)
	_body.rotation.z = 0.0


func _pose_cower() -> void:
	_body.scale = Vector3(_size, 0.7 * _size, _size)
	_body.position = Vector3(0.03 * sin(_bob_t * 30.0), 0.0, 0.0)
	_body.rotation.z = 0.0


func _build_look() -> void:
	var shirts: Array[Color] = [Color(0.2, 0.4, 0.75), Color(0.7, 0.3, 0.25), \
			Color(0.3, 0.55, 0.3), Color(0.5, 0.5, 0.52), Color(0.5, 0.3, 0.6)]
	var skins: Array[Color] = [Color(0.85, 0.65, 0.5), \
			Color(0.6, 0.42, 0.3), Color(0.95, 0.78, 0.62)]
	var pick: int = abs(int(get_instance_id()))
	var shirt: Color = shirts[pick % shirts.size()]
	var skin: Color = skins[(pick / shirts.size()) % skins.size()]
	_size = 0.92 + 0.08 * float(pick % 3)
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	Blockout.capsule_mesh(_body, Vector3(0, 0.75, 0), 0.28, 1.0, shirt).name = "Torso"
	Blockout.sphere(_body, Vector3(0, 1.42, 0), 0.19, skin).name = "Head"
	var hair := Blockout.sphere(_body, Vector3(0, 1.52, -0.02), 0.2, \
		Color(0.15, 0.1, 0.08))
	hair.scale = Vector3(1.0, 0.6, 1.0)
	hair.name = "Hair"
	var face := "face_civ_a" if abs(int(get_instance_id())) % 2 == 0 else "face_civ_b"
	ProcTex.face_quad(_body, Vector3(0, 1.42, 0.195), 0.26, face)
	_body.scale = Vector3(_size, _size, _size)
