class_name Webshot
extends Area3D
## Player web projectile: stuns thugs in a cocoon, splats on walls.

@export var speed: float = 32.0
@export var life: float = 2.0
@export var stun_time: float = 4.0

var _dir: Vector3 = Vector3.FORWARD


func _ready() -> void:
	add_to_group("fx")
	collision_layer = 16
	collision_mask = 5
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body)


func launch(direction: Vector3) -> void:
	_dir = direction.normalized()
	look_at(global_position + _dir)


func _physics_process(delta: float) -> void:
	global_position += _dir * speed * delta
	life -= delta
	if life <= 0.0:
		queue_free()


func _on_body(body: Node3D) -> void:
	if body.is_in_group("enemies"):
		var enemy: Variant = body
		enemy.take_hit(5.0, self)
		enemy.apply_web(stun_time)
		Sfx.play_at("hit", global_position, -4.0)
		queue_free()
	elif body is StaticBody3D:
		_make_splat()
		queue_free()


func _make_splat() -> void:
	var splat := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.22
	mesh.height = 0.08
	splat.mesh = mesh
	splat.material_override = Blockout.mat(Color(0.93, 0.94, 0.96))
	get_tree().current_scene.add_child(splat)
	splat.global_position = global_position
	var tween := splat.create_tween()
	tween.tween_interval(2.0)
	tween.tween_callback(splat.queue_free)
