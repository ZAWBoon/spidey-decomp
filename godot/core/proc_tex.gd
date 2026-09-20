class_name ProcTex
extends RefCounted
## Procedural texture pass: runtime-painted ImageTextures that dress the
## greybox levels (tiled ground detail + lit window facades on towers).
## dress_level() runs once from LevelBase._ready AFTER _build(). It only
## touches scriptless StaticBody3D boxes (Blockout greybox): it swaps a
## MeshInstance3D material or adds shadowless visual quads, so collision,
## gating and actor logic cannot change. Textures are painted once per
## session (deterministic seeds, cached in _tex) and shared by all levels.

const TILE_METERS := 8.0
const FACADE_METERS := 6.0
const NIGHT_LEVELS := ["bugle", "roofs", "theater"]

static var _tex: Dictionary = {}


## Walk the finished level and skin what qualifies. Safe to call once.
static func dress_level(level: Node) -> void:
	if level == null or not (level is Node3D):
		return
	var key := (level as Node).get_scene_file_path().get_file().get_basename()
	var boxes: Array[Node] = []
	_collect(level, boxes)
	for node in boxes:
		_dress_box(level, node as StaticBody3D, key)


static func _collect(node: Node, out: Array[Node]) -> void:
	for child in node.get_children():
		if child is StaticBody3D and child.get_script() == null:
			out.append(child)
		_collect(child, out)


static func _dress_box(level: Node, body: StaticBody3D, key: String) -> void:
	if body == null or not is_instance_valid(body):
		return
	if body.rotation.length() > 0.02:
		return  # Ramps and tilted props keep flat colors.
	var mi: MeshInstance3D = null
	for child in body.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh is BoxMesh:
			mi = child
	if mi == null:
		return
	var base := mi.material_override as StandardMaterial3D
	if base == null or base.emission_enabled:
		return
	if base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return
	var size := (mi.mesh as BoxMesh).size
	var c := base.albedo_color
	var gkind := ""
	if _is_ground(size):
		gkind = _ground_kind(key, c, body.position.y)
	if gkind != "":
		_skin_ground(mi, size, gkind, c)
	elif _is_tower(size, c):
		_add_facades(level, body.position, size, key in NIGHT_LEVELS)


static func _is_ground(size: Vector3) -> bool:
	return size.y <= 1.5 and minf(size.x, size.z) >= 8.0


static func _ground_kind(key: String, c: Color, y: float) -> String:
	if c.b > 0.45 and c.b > c.r + 0.25 and c.b > c.g + 0.1:
		return ""  # Water and sky-glass stay flat.
	var v := (c.r + c.g + c.b) / 3.0
	if v < 0.08:
		return ""
	if c.g > c.r and c.g > c.b:
		return "grass"
	if c.r > c.g + 0.08 and c.g > c.b + 0.03 and c.r > 0.28 and v < 0.55:
		return "wood"
	var mx := maxf(c.r, maxf(c.g, c.b))
	var mn := minf(c.r, minf(c.g, c.b))
	if mx - mn > 0.32:
		return ""  # Saturated gameplay paint stays flat.
	if y > 12.0:
		return "gravel"  # High slabs are roofs, not floors.
	if v < 0.38:
		return "asphalt"
	match key:
		"bank":
			return "tile"
		"theater", "bugle":
			return "carpet"
		"roofs":
			return "gravel"
	return "concrete"


static func _is_tower(size: Vector3, c: Color) -> bool:
	if size.y < 6.0 or minf(size.x, size.z) < 4.0 or maxf(size.x, size.z) < 6.0:
		return false
	var mx := maxf(c.r, maxf(c.g, c.b))
	var mn := minf(c.r, minf(c.g, c.b))
	if mx - mn > 0.28:
		return false
	var v := (c.r + c.g + c.b) / 3.0
	return v > 0.12 and v < 0.8


static func _skin_ground(mi: MeshInstance3D, size: Vector3, kind: String, tint: Color) -> void:
	var t := tex(kind)
	if t == null:
		return
	var m := StandardMaterial3D.new()
	m.albedo_texture = t
	m.albedo_color = tint.lerp(Color.WHITE, 0.6)
	m.roughness = 0.4 if kind == "tile" else 0.95
	var s := maxf(size.x, size.z) / TILE_METERS
	m.uv1_scale = Vector3(s, s, s)
	mi.material_override = m


static func _add_facades(level: Node, center: Vector3, size: Vector3, night: bool) -> void:
	var t := tex("windows_night" if night else "windows_day")
	if t == null or not (level is Node3D):
		return
	var sides := [
		[0.0, size.x, size.z * 0.5],
		[PI, size.x, size.z * 0.5],
		[PI * 0.5, size.z, size.x * 0.5],
		[-PI * 0.5, size.z, size.x * 0.5],
	]
	for side in sides:
		var ang := float(side[0])
		var fw := float(side[1]) - 0.4
		var dist := float(side[2]) + 0.06
		var fh := size.y - 1.0
		if fw < 2.0 or fh < 3.0:
			continue
		var m := StandardMaterial3D.new()
		m.albedo_texture = t
		if night:
			m.emission_enabled = true
			m.emission_texture = t
			m.emission = Color(1, 0.95, 0.85)
			m.emission_energy_multiplier = 1.2
			m.roughness = 0.85
		else:
			m.roughness = 0.35
			m.metallic = 0.25
		m.uv1_scale = Vector3(fw / FACADE_METERS, fh / FACADE_METERS, 1.0)
		var q := QuadMesh.new()
		q.size = Vector2(fw, fh)
		var qi := MeshInstance3D.new()
		qi.mesh = q
		qi.material_override = m
		qi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		qi.position = center + Vector3(sin(ang), 0.0, cos(ang)) * dist
		qi.position.y = center.y - size.y * 0.5 + 1.0 + fh * 0.5
		qi.rotation.y = ang
		(level as Node3D).add_child(qi)


# ------------------------------------------------------------- textures ---
static func tex(kind: String) -> ImageTexture:
	if _tex.has(kind):
		return _tex[kind]
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_of(kind)
	var img := _paint(kind, rng)
	if img == null:
		return null
	var t := ImageTexture.create_from_image(img)
	_tex[kind] = t
	return t


static func _seed_of(kind: String) -> int:
	var h := 7
	for i in range(kind.length()):
		h = (h * 31 + kind.unicode_at(i)) % 1000000007
	return h


static func _paint(kind: String, rng: RandomNumberGenerator) -> Image:
	match kind:
		"grass":
			return _paint_grass(rng)
		"asphalt":
			return _paint_asphalt(rng)
		"concrete":
			return _paint_concrete(rng)
		"tile":
			return _paint_tile(rng)
		"carpet":
			return _paint_carpet(rng)
		"wood":
			return _paint_wood(rng)
		"gravel":
			return _paint_gravel(rng)
		"windows_day":
			return _paint_windows(false, rng)
		"windows_night":
			return _paint_windows(true, rng)
		"face_thug":
			return _paint_face(0)
		"face_civ_a":
			return _paint_face(1)
		"face_civ_b":
			return _paint_face(2)
		"face_scared":
			return _paint_face(3)
		"armor":
			return _paint_armor(rng)
	return null


static func _blank(s: int, c: Color) -> Image:
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return img


static func _grain(img: Image, base: Color, amp: float, rng: RandomNumberGenerator) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for y in range(h):
		for x in range(w):
			var f := 1.0 + (rng.randf() * 2.0 - 1.0) * amp
			img.set_pixel(x, y, Color(base.r * f, base.g * f, base.b * f))


static func _speckle(img: Image, c: Color, count: int, rng: RandomNumberGenerator,
		sz: int = 1) -> void:
	var w := img.get_width() - sz
	var h := img.get_height() - sz
	for _i in range(count):
		var r := Rect2i(rng.randi_range(0, w), rng.randi_range(0, h), sz, sz)
		img.fill_rect(r, c)


static func _paint_grass(rng: RandomNumberGenerator) -> Image:
	var img := _blank(96, Color(0.24, 0.47, 0.18))
	_grain(img, Color(0.24, 0.47, 0.18), 0.22, rng)
	_speckle(img, Color(0.13, 0.3, 0.1), 500, rng)
	_speckle(img, Color(0.35, 0.6, 0.25), 350, rng)
	return img


static func _paint_asphalt(rng: RandomNumberGenerator) -> Image:
	var img := _blank(96, Color(0.15, 0.15, 0.17))
	_grain(img, Color(0.15, 0.15, 0.17), 0.2, rng)
	_speckle(img, Color(0.32, 0.32, 0.34), 400, rng)
	_speckle(img, Color(0.07, 0.07, 0.08), 250, rng)
	return img


static func _paint_concrete(rng: RandomNumberGenerator) -> Image:
	var img := _blank(96, Color(0.6, 0.6, 0.58))
	_grain(img, Color(0.6, 0.6, 0.58), 0.07, rng)
	var j := Color(0.42, 0.42, 0.4)
	img.fill_rect(Rect2i(0, 0, 96, 2), j)
	img.fill_rect(Rect2i(0, 94, 96, 2), j)
	img.fill_rect(Rect2i(0, 0, 2, 96), j)
	img.fill_rect(Rect2i(94, 0, 2, 96), j)
	_speckle(img, Color(0.5, 0.5, 0.48), 150, rng)
	return img


static func _paint_tile(rng: RandomNumberGenerator) -> Image:
	var img := _blank(128, Color(0.74, 0.73, 0.69))
	_grain(img, Color(0.74, 0.73, 0.69), 0.03, rng)
	var alt := Color(0.66, 0.65, 0.61)
	img.fill_rect(Rect2i(64, 0, 64, 64), alt)
	img.fill_rect(Rect2i(0, 64, 64, 64), alt)
	var g := Color(0.4, 0.39, 0.37)
	img.fill_rect(Rect2i(62, 0, 4, 128), g)
	img.fill_rect(Rect2i(0, 62, 128, 4), g)
	img.fill_rect(Rect2i(0, 0, 128, 3), g)
	img.fill_rect(Rect2i(0, 125, 128, 3), g)
	img.fill_rect(Rect2i(0, 0, 3, 128), g)
	img.fill_rect(Rect2i(125, 0, 3, 128), g)
	_speckle(img, Color(0.6, 0.6, 0.58), 120, rng)
	return img


static func _paint_carpet(rng: RandomNumberGenerator) -> Image:
	var img := _blank(96, Color(0.32, 0.07, 0.09))
	_grain(img, Color(0.32, 0.07, 0.09), 0.12, rng)
	for y in range(0, 96, 8):
		img.fill_rect(Rect2i(0, y, 96, 2), Color(0.26, 0.05, 0.07))
	_speckle(img, Color(0.2, 0.04, 0.05), 250, rng)
	return img


static func _paint_wood(rng: RandomNumberGenerator) -> Image:
	var img := _blank(128, Color(0.46, 0.31, 0.18))
	for b in range(8):
		var tone := Color(0.46, 0.31, 0.18) if b % 2 == 0 else Color(0.4, 0.26, 0.15)
		img.fill_rect(Rect2i(0, b * 16, 128, 16), tone)
		img.fill_rect(Rect2i(0, b * 16, 128, 1), Color(0.22, 0.14, 0.08))
	_speckle(img, Color(0.3, 0.19, 0.1), 350, rng)
	_speckle(img, Color(0.55, 0.38, 0.22), 150, rng)
	return img


static func _paint_gravel(rng: RandomNumberGenerator) -> Image:
	var img := _blank(96, Color(0.38, 0.36, 0.34))
	_grain(img, Color(0.38, 0.36, 0.34), 0.3, rng)
	_speckle(img, Color(0.55, 0.52, 0.48), 300, rng, 2)
	_speckle(img, Color(0.22, 0.2, 0.19), 350, rng)
	return img


static func _paint_windows(night: bool, rng: RandomNumberGenerator) -> Image:
	var img := _blank(128, Color(0.1, 0.1, 0.12))
	for cy in range(2):
		for cx in range(2):
			var ox := 6 + cx * 61
			var oy := 6 + cy * 61
			var lit := rng.randf() < (0.4 if night else 0.12)
			var glass := Color(1.0, 0.78, 0.5) if lit else Color(0.07, 0.09, 0.15)
			if lit:
				var f := 0.85 + rng.randf() * 0.3
				glass = Color(glass.r * f, glass.g * f, glass.b * f)
			elif not night:
				glass = Color(0.5, 0.7, 0.86)
			img.fill_rect(Rect2i(ox, oy, 55, 55), glass)
			if not night and not lit:
				img.fill_rect(Rect2i(ox, oy, 55, 20), Color(0.66, 0.82, 0.94))
			var bar := Color(0.1, 0.1, 0.12)
			img.fill_rect(Rect2i(ox + 26, oy, 3, 55), bar)
			img.fill_rect(Rect2i(ox, oy + 26, 55, 3), bar)
			img.fill_rect(Rect2i(ox, oy + 52, 55, 3), Color(0.55, 0.55, 0.58))
	return img


static func face_quad(parent: Node3D, pos: Vector3, size: float, kind: String) -> MeshInstance3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex(kind)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.roughness = 1.0
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _paint_face(mood: int) -> Image:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var dark := Color(0.08, 0.06, 0.06)
	var white := Color(0.96, 0.94, 0.9)
	var ey := 20
	var eh := 10
	if mood == 3:
		ey = 16
		eh = 14
	for ex in [16, 36]:
		img.fill_rect(Rect2i(ex, ey, 12, eh), white)
		img.fill_rect(Rect2i(ex + 3, ey + 2, 5, 6), dark)
	match mood:
		0:
			img.fill_rect(Rect2i(14, 10, 6, 4), dark)
			img.fill_rect(Rect2i(20, 12, 6, 4), dark)
			img.fill_rect(Rect2i(26, 14, 5, 4), dark)
			img.fill_rect(Rect2i(44, 10, 6, 4), dark)
			img.fill_rect(Rect2i(38, 12, 6, 4), dark)
			img.fill_rect(Rect2i(33, 14, 5, 4), dark)
			img.fill_rect(Rect2i(24, 44, 16, 3), dark)
		1:
			img.fill_rect(Rect2i(15, 13, 14, 3), dark)
			img.fill_rect(Rect2i(35, 13, 14, 3), dark)
			img.fill_rect(Rect2i(22, 44, 6, 3), dark)
			img.fill_rect(Rect2i(28, 46, 8, 3), dark)
			img.fill_rect(Rect2i(36, 44, 6, 3), dark)
		2:
			img.fill_rect(Rect2i(15, 9, 14, 3), dark)
			img.fill_rect(Rect2i(35, 9, 14, 3), dark)
			img.fill_rect(Rect2i(26, 45, 12, 3), dark)
		_:
			img.fill_rect(Rect2i(15, 6, 14, 3), dark)
			img.fill_rect(Rect2i(35, 6, 14, 3), dark)
			img.fill_rect(Rect2i(28, 42, 8, 12), dark)
			img.fill_rect(Rect2i(30, 44, 4, 8), Color(0, 0, 0, 0))
	return img


static func _paint_armor(rng: RandomNumberGenerator) -> Image:
	var img := _blank(128, Color(0.45, 0.45, 0.48))
	_grain(img, Color(0.45, 0.45, 0.48), 0.1, rng)
	var seam := Color(0.24, 0.24, 0.26)
	var hi := Color(0.62, 0.62, 0.64)
	for row in range(4):
		var y := row * 32
		img.fill_rect(Rect2i(0, y, 128, 3), seam)
		img.fill_rect(Rect2i(0, y + 3, 128, 1), hi)
		var xs := [31, 73, 115] if row % 2 == 1 else [10, 52, 94]
		for x in xs:
			img.fill_rect(Rect2i(x, y, 2, 32), seam)
			img.fill_rect(Rect2i(x + 2, y + 14, 3, 3), hi)
	_speckle(img, Color(0.3, 0.3, 0.32), 120, rng)
	return img
