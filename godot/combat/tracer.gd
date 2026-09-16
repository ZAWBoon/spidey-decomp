class_name Tracer
extends Area3D
## Enemy gunfire: fast bolt that hurts the player. Set `tint` before
## add_child for alt colors (Scorpion venom bolts are green).

@export var speed: float = 24.0
@export var life: float = 3.0
@export var damage: float = 8.0

var tint: Color = Color(1, 0.2, 0.1)

var _dir: Vector3 = Vector3.FORWARD


func _ready() -> void:
	add_to_group("fx")
	collision_layer = 16
	collision_mask = 3
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body)
	var glow := $MeshInstance3D as MeshInstance3D
	glow.material_override = Blockout.mat_emissive(tint, 3.0)


func launch(direction: Vector3, damage_amount: float = -1.0) -> void:
	_dir = direction.normalized()
	if damage_amount > 0.0:
		damage = damage_amount
	look_at(global_position + _dir)


func _physics_process(delta: float) -> void:
	global_position += _dir * speed * delta
	life -= delta
	if life <= 0.0:
		queue_free()


func _on_body(body: Node3D) -> void:
	if body.is_in_group("player"):
		var target: Variant = body
		target.take_hit(damage, self)
		queue_free()
	elif body is StaticBody3D:
		queue_free()
