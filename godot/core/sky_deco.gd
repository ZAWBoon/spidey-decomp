class_name SkyDeco
extends RefCounted
## One-shot sky dressing: moon, stars, clouds, sunset sun. Pure visuals
## floating far above the play space (y 30+), deterministic layout via
## fixed seeds so every run looks the same. Call once from _build().


static func night(parent: Node3D) -> void:
	_moon(parent, Vector3(-55, 52, -75), 5.0, Color(0.92, 0.95, 1.0))
	_stars(parent, 46)


static func day(parent: Node3D) -> void:
	_clouds(parent, 7, Color(0.95, 0.95, 0.97))


static func sunset(parent: Node3D) -> void:
	_moon(parent, Vector3(60, 14, -70), 7.0, Color(1.0, 0.55, 0.25))
	_clouds(parent, 8, Color(1.0, 0.75, 0.55))


static func _moon(parent: Node3D, pos: Vector3, r: float, tint: Color) -> void:
	var m := Blockout.sphere(parent, pos, r, Color.WHITE)
	m.material_override = Blockout.mat_emissive(tint, 1.5)


static func _stars(parent: Node3D, count: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var mat := Blockout.mat_emissive(Color(0.9, 0.93, 1.0), 2.0)
	for i in count:
		var pos := Vector3(rng.randf_range(-110.0, 110.0), \
				rng.randf_range(38.0, 70.0), rng.randf_range(-110.0, 110.0))
		var s := Blockout.sphere(parent, pos, rng.randf_range(0.1, 0.22), Color.WHITE)
		s.material_override = mat


static func _clouds(parent: Node3D, count: int, tint: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	for i in count:
		var base := Vector3(rng.randf_range(-90.0, 90.0), \
				rng.randf_range(30.0, 44.0), rng.randf_range(-90.0, 90.0))
		var puffs := 3 + rng.randi_range(0, 2)
		for j in puffs:
			var off := Vector3(rng.randf_range(-4.0, 4.0), \
					rng.randf_range(-1.0, 1.0), rng.randf_range(-2.0, 2.0))
			var c := Blockout.sphere(parent, base + off, rng.randf_range(2.0, 3.6), tint)
			c.scale.y = 0.55
