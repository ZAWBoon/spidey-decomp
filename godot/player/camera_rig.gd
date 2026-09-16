class_name CameraRig
extends Node3D
## Third-person orbit camera: mouse orbit + spring-arm collision,
## trauma shake, speed-reactive FOV.

@export var sensitivity: float = 0.0026
@export var pitch_min: float = -0.96
@export var pitch_max: float = 0.78
@export var base_fov: float = 70.0

var target: Node3D = null
var trauma: float = 0.0

@onready var yaw: Node3D = $Yaw
@onready var pitch: Node3D = $Yaw/Pitch
@onready var arm: SpringArm3D = $Yaw/Pitch/SpringArm3D
@onready var camera: Camera3D = $Yaw/Pitch/SpringArm3D/Camera3D


func _ready() -> void:
	target = get_parent() as Node3D
	camera.current = true
	camera.fov = base_fov
	pitch.rotation.x = -0.18
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		yaw.rotate_y(-motion.relative.x * sensitivity)
		pitch.rotation.x = clampf(pitch.rotation.x - motion.relative.y * sensitivity,
			pitch_min, pitch_max)


func _process(delta: float) -> void:
	if target != null:
		var goal: Vector3 = target.global_position + Vector3(0, 1.6, 0)
		global_position = global_position.lerp(goal, minf(1.0, 14.0 * delta))
	trauma = maxf(0.0, trauma - delta * 1.6)
	if trauma > 0.0:
		var s := trauma * trauma
		camera.h_offset = randf_range(-s, s) * 0.35
		camera.v_offset = randf_range(-s, s) * 0.35
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
	var speed := 0.0
	if target is CharacterBody3D:
		var body := target as CharacterBody3D
		speed = Vector2(body.velocity.x, body.velocity.z).length()
	var want_fov := base_fov + clampf(speed / 19.0, 0.0, 1.0) * 12.0
	camera.fov = lerpf(camera.fov, want_fov, minf(1.0, 5.0 * delta))


func add_trauma(amount: float) -> void:
	trauma = minf(1.0, trauma + amount)


func get_move_basis() -> Basis:
	return yaw.global_transform.basis


## World point the crosshair looks at (for web aiming).
func get_aim_point() -> Vector3:
	var viewport := get_viewport()
	if viewport == null:
		return global_position - global_transform.basis.z * 30.0
	var center := viewport.get_visible_rect().size * 0.5
	var from := camera.project_ray_origin(center)
	var to := from + camera.project_ray_normal(center) * 60.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	if target != null:
		query.exclude = [target.get_rid()]
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(query)
	if hit.has("position"):
		return hit["position"]
	return to
