class_name FX
extends RefCounted
## One-shot juice: particle bursts + shockwave rings, all code-built.
## Callers pass a parent Node (usually the level or current_scene) and a
## world position. Bursts auto-free; group "vfx" (NOT "fx", which the
## self-test counts for webshots). Only battle-tested CPUParticles3D
## properties are used (no engine here to catch typos at runtime).

static var _dot: SphereMesh = null
static var _flat: StandardMaterial3D = null


static func _mesh() -> SphereMesh:
	if _dot == null:
		_dot = SphereMesh.new()
		_dot.radius = 1.0
		_dot.height = 2.0
		_dot.radial_segments = 8
		_dot.rings = 4
		_flat = StandardMaterial3D.new()
		_flat.albedo_color = Color.WHITE
		_flat.roughness = 1.0
		_dot.material = _flat
	return _dot


## Core burst. glow > 0 adds a per-call emissive override (shared mesh).
static func burst(parent: Node, pos: Vector3, color: Color, count: int = 12,
		speed: float = 6.0, size: float = 0.12, life: float = 0.6,
		gravity: Vector3 = Vector3(0, -9, 0), glow: float = 0.0) -> void:
	if parent == null:
		return
	var tree := parent.get_tree()
	if tree == null:
		return
	var p := CPUParticles3D.new()
	p.add_to_group("vfx")
	p.amount = count
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.25
	p.direction = Vector3(0, 1, 0)
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = gravity
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size
	p.draw_pass_1 = _mesh()
	if glow > 0.0:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
		p.material_override = mat
		p.color = Color.WHITE
	else:
		p.color = color
	p.emitting = false
	parent.add_child(p)
	if p is Node3D:
		(p as Node3D).global_position = pos
	p.emitting = true
	var timer := tree.create_timer(life + 1.0)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free())


## Flat expanding shockwave ring (slams, explosions, waves).
static func ring(parent: Node, pos: Vector3, color: Color, max_r: float = 5.0,
		dur: float = 0.4) -> void:
	if parent == null:
		return
	var tree := parent.get_tree()
	if tree == null or not (parent is Node3D):
		return
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.85
	mesh.outer_radius = 1.0
	mesh.rings = 24
	mesh.ring_segments = 8
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	var band := MeshInstance3D.new()
	band.mesh = mesh
	band.material_override = mat
	band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(band)
	band.global_position = pos + Vector3(0, 0.15, 0)
	band.scale = Vector3(0.5, 1, 0.5)
	var tween := tree.create_tween()
	tween.set_parallel(true)
	tween.tween_property(band, "scale", Vector3(max_r, 1, max_r), dur)
	tween.tween_property(mat, "albedo_color:a", 0.0, dur)
	tween.chain().tween_callback(band.queue_free)


# ------------------------------------------------------------------ presets --
static func punch_hit(parent: Node, pos: Vector3) -> void:
	burst(parent, pos, Color(1, 0.9, 0.4), 10, 7.0, 0.1, 0.4,
		Vector3(0, -9, 0), 2.0)


static func hit_spark(parent: Node, pos: Vector3, color: Color) -> void:
	burst(parent, pos, color, 8, 6.0, 0.09, 0.35, Vector3(0, -9, 0), 1.5)


static func land_dust(parent: Node, pos: Vector3) -> void:
	burst(parent, pos, Color(0.7, 0.7, 0.72), 10, 2.5, 0.16, 0.7,
		Vector3(0, -2, 0))


static func explosion(parent: Node, pos: Vector3) -> void:
	burst(parent, pos, Color(1, 0.5, 0.1), 24, 10.0, 0.2, 0.8,
		Vector3(0, -6, 0), 3.0)
	burst(parent, pos, Color(0.25, 0.25, 0.26), 16, 4.0, 0.3, 1.2,
		Vector3(0, 2, 0))
	burst(parent, pos, Color(1, 0.9, 0.4), 16, 14.0, 0.08, 0.5,
		Vector3(0, -12, 0), 3.0)
	ring(parent, pos, Color(1, 0.6, 0.2, 0.8), 6.0, 0.45)


static func poof(parent: Node, pos: Vector3, color: Color) -> void:
	burst(parent, pos, color, 14, 4.0, 0.18, 0.6, Vector3(0, 2, 0), 1.0)


static func sparkle(parent: Node, pos: Vector3, color: Color) -> void:
	burst(parent, pos, color, 12, 3.0, 0.08, 0.8, Vector3(0, 3, 0), 2.5)


static func trail_puff(parent: Node, pos: Vector3, color: Color) -> void:
	burst(parent, pos, color, 4, 1.5, 0.14, 0.5, Vector3(0, -1, 0))


static func splash(parent: Node, pos: Vector3) -> void:
	burst(parent, pos, Color(0.5, 0.75, 1.0), 16, 6.0, 0.12, 0.7,
		Vector3(0, -12, 0), 0.5)
