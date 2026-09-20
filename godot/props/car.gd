class_name Car
extends StaticBody3D
## Parked car: solid cover until Rhino plows it into scrap. Set `paint`
## before add_child; place at y=0 with any yaw rotation.

var paint: Color = Color(0.7, 0.1, 0.1)

var _smashed: bool = false
var _shape: CollisionShape3D = null
var _visuals: Array[MeshInstance3D] = []


func _ready() -> void:
	add_to_group("cars")
	collision_layer = 1
	collision_mask = 0
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 1.5, 4.4)
	_shape.shape = box
	_shape.position = Vector3(0, 0.75, 0)
	add_child(_shape)
	_add_part(Vector3(2.0, 0.65, 4.4), Vector3(0, 0.62, 0), paint)
	_add_part(Vector3(1.7, 0.55, 2.1), Vector3(0, 1.2, -0.2), Color(0.1, 0.12, 0.16))
	var tire := Color(0.06, 0.06, 0.07)
	for sx in [-1.0, 1.0]:
		for sz in [-1.45, 1.45]:
			var wheel := Blockout.cylinder(self, Vector3(sx, 0.36, sz), 0.36, 0.3,
				tire, false) as MeshInstance3D
			wheel.rotation.z = PI * 0.5
			_visuals.append(wheel)


func smash() -> void:
	if _smashed:
		return
	_smashed = true
	_shape.set_deferred("disabled", true)
	Sfx.play_at("crash", global_position)
	var scrap := Blockout.mat(Color(0.15, 0.15, 0.16))
	for part in _visuals:
		part.material_override = scrap
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(1.15, 0.45, 0.9), 0.25)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func is_smashed() -> bool:
	return _smashed


func _add_part(size: Vector3, pos: Vector3, color: Color) -> void:
	var part := Blockout.box(self, pos, size, color, false) as MeshInstance3D
	_visuals.append(part)
