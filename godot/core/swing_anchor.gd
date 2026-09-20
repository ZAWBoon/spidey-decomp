class_name SwingAnchor
extends Node3D
## Marker the player can attach a web-swing rope to. Shows a faint ring
## so players learn where swinging is possible.

@export var ring_color: Color = Color(1, 1, 1, 0.45)


func _ready() -> void:
	add_to_group("swing_anchor")
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.25
	torus.outer_radius = 0.5
	torus.rings = 12
	torus.ring_segments = 24
	ring.mesh = torus
	var m := StandardMaterial3D.new()
	m.albedo_color = ring_color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.no_depth_test = false
	ring.material_override = m
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
