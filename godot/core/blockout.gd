class_name Blockout
extends RefCounted
## Static helpers that build greybox/blockout geometry from code.
## Levels describe rooms as data; this turns data into meshes+collision.

static var _mat_cache: Dictionary = {}
static var _emissive_cache: Dictionary = {}


static func mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.95
	m.metallic = 0.0
	_mat_cache[key] = m
	return m


static func mat_emissive(color: Color, energy: float = 1.5) -> StandardMaterial3D:
	var key := "%s_%f" % [color.to_html(), energy]
	if _emissive_cache.has(key):
		return _emissive_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	_emissive_cache[key] = m
	return m


static func mat_transparent(color: Color) -> StandardMaterial3D:
	var key := "t_" + color.to_html()
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.6
	_mat_cache[key] = m
	return m


## Box that optionally collides. Returns StaticBody3D or MeshInstance3D.
static func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color,
		collide: bool = true, col_layer: int = 1) -> Node3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat(color)
	if not collide:
		mi.position = pos
		parent.add_child(mi)
		return mi
	var body := StaticBody3D.new()
	body.collision_layer = col_layer
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	body.add_child(mi)
	body.position = pos
	parent.add_child(body)
	return body


static func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float,
		color: Color, collide: bool = true) -> Node3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mi.mesh = mesh
	mi.material_override = mat(color)
	if not collide:
		mi.position = pos
		parent.add_child(mi)
		return mi
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	cs.shape = shape
	body.add_child(cs)
	body.add_child(mi)
	body.position = pos
	parent.add_child(body)
	return body


static func sphere(parent: Node3D, pos: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mi.mesh = mesh
	mi.material_override = mat(color)
	mi.position = pos
	parent.add_child(mi)
	return mi


static func capsule_mesh(parent: Node3D, pos: Vector3, radius: float, height: float,
		color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mi.mesh = mesh
	mi.material_override = mat(color)
	mi.position = pos
	parent.add_child(mi)
	return mi


static func label(parent: Node3D, pos: Vector3, text: String,
		color: Color = Color.WHITE, font_size: int = 64) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = font_size
	l.pixel_size = 0.01
	l.modulate = color
	l.outline_size = 8
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = pos
	parent.add_child(l)
	return l


static func omni(parent: Node3D, pos: Vector3, color: Color = Color(1, 0.95, 0.85),
		energy: float = 1.5, light_range: float = 14.0) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
	parent.add_child(l)
	return l


## Invisible box trigger that reports the player entering. Returns the Area3D.
static func trigger(parent: Node3D, pos: Vector3, size: Vector3) -> Area3D:
	var area := Area3D.new()
	area.collision_layer = 8
	area.collision_mask = 2
	area.monitoring = true
	area.monitorable = false
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	area.add_child(cs)
	area.position = pos
	parent.add_child(area)
	return area
