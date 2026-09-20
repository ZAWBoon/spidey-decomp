class_name TheaterLevel
extends LevelBase
## Level 6: abandoned theater vs MYSTERIO. Coplanar stage (no steps!),
## curtain backdrop, 24 velvet seats as bolt cover, chandelier swing
## anchor, 5 glowing pedestals the boss teleports between. East balcony
## (ramp up, projector, 2 tokens). 4 spider-tokens total.

const THUG_SCENE: PackedScene = preload("res://enemies/thug.tscn")
const MYSTERIO_SCENE: PackedScene = preload("res://enemies/mysterio.tscn")
const HOSTAGE_SCENE: PackedScene = preload("res://npc/hostage.tscn")
const WEB_SCENE: PackedScene = preload("res://pickups/web_pickup.tscn")
const HEALTH_SCENE: PackedScene = preload("res://pickups/health_pickup.tscn")
const EXIT_SCENE: PackedScene = preload("res://props/exit_gate.tscn")

var _mysterio: Mysterio = null
var _exit: ExitGate = null


func _build() -> void:
	SkyDeco.night(self)
	level_id = "theater"
	level_name = "Level 6: Theater"
	next_level_path = ""
	_build_hall()
	_build_balcony()
	_build_stage()
	_build_seats()
	_build_actors()
	Game.set_objective("The show begins - unmask Mysterio!")


func _build_hall() -> void:
	Blockout.box(self, Vector3(0, -0.5, 5), Vector3(40, 1, 30),
		Color(0.25, 0.12, 0.12))
	var wall := Color(0.18, 0.1, 0.14)
	Blockout.box(self, Vector3(0, 5, -10), Vector3(40, 10, 1), wall)
	Blockout.box(self, Vector3(0, 5, 20), Vector3(40, 10, 1), wall)
	Blockout.box(self, Vector3(-20, 5, 5), Vector3(1, 10, 32), wall)
	Blockout.box(self, Vector3(20, 5, 5), Vector3(1, 10, 32), wall)
	Blockout.omni(self, Vector3(0, 4, -7), Color(0.7, 0.4, 1.0), 1.5, 18.0)
	Blockout.omni(self, Vector3(0, 6, 8), Color(1, 0.8, 0.6), 0.8, 20.0)
	# Chandelier + swing anchor over the seats.
	var gold := Color(0.85, 0.65, 0.15)
	Blockout.cylinder(self, Vector3(0, 9, 5), 0.08, 2.0, gold, false)
	var gem := Blockout.sphere(self, Vector3(0, 8, 5), 0.5, gold)
	gem.material_override = Blockout.mat_emissive(gold, 2.0)
	_swing_anchor(Vector3(0, 8.5, 5))
	_swing_anchor(Vector3(-13, 8.2, -8))
	_swing_anchor(Vector3(13, 8.2, -8))
	# Aisle carpet + wall sconces + posters.
	Blockout.box(self, Vector3(0, 0.02, 9), Vector3(2, 0.04, 18),
		Color(0.45, 0.08, 0.1), false)
	var warm := Color(1, 0.75, 0.45)
	for pos in [Vector3(-19.3, 3.5, 0), Vector3(-19.3, 3.5, 10),
			Vector3(19.3, 3.5, 0), Vector3(19.3, 3.5, 10)]:
		var lamp := Blockout.sphere(self, pos, 0.15, warm)
		lamp.material_override = Blockout.mat_emissive(warm, 2.0)
	Blockout.box(self, Vector3(-8, 3, 19.4), Vector3(3, 4, 0.1),
		Color(0.7, 0.5, 0.15), false)
	Blockout.box(self, Vector3(8, 3, 19.4), Vector3(3, 4, 0.1),
		Color(0.4, 0.2, 0.6), false)
	Blockout.label(self, Vector3(0, 5.5, 19.4), "NOW SHOWING", Color(1, 0.85, 0.5), 48)


func _build_balcony() -> void:
	# East balcony: solid block (top y=4) + ramp up from the south.
	# CharacterBody can't step, so the ramp top lands coplanar (y=4).
	Blockout.box(self, Vector3(16.5, 1.75, 5), Vector3(5, 4.5, 22),
		Color(0.3, 0.16, 0.16))
	_ramp(Vector3(16.5, 2, 9), 3.0, 14.0, 4.0, 0.0, 4.0)
	Blockout.box(self, Vector3(13.8, 4.5, 5), Vector3(0.3, 1, 22),
		Color(0.6, 0.45, 0.12))
	Blockout.box(self, Vector3(16.5, 4.5, -6), Vector3(5, 1, 0.3),
		Color(0.6, 0.45, 0.12))
	# Projector + tokens.
	Blockout.box(self, Vector3(16.5, 4.6, 14), Vector3(1, 0.6, 1.2),
		Color(0.1, 0.1, 0.12))
	var lens := Blockout.sphere(self, Vector3(15.8, 4.6, 14), 0.12,
		Color(0.8, 0.9, 1.0))
	lens.material_override = Blockout.mat_emissive(Color(0.8, 0.9, 1.0), 2.5)
	Blockout.label(self, Vector3(16.5, 5.8, 14), "PROJECTOR", Color(0.7, 0.8, 1.0), 40)
	_spawn_token(Vector3(16.5, 5.2, 12))
	_spawn_token(Vector3(16.5, 5.2, -2))


## Sloped walkway, +Z/low to -Z/high (same math as the Bugle ramps).
func _ramp(center: Vector3, width: float, z_from: float, z_to: float,
		y_from: float, y_to: float) -> void:
	var run := absf(z_to - z_from)
	var rise := y_to - y_from
	var length := sqrt(run * run + rise * rise) + 1.0
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, 0.5, length)
	mi.mesh = mesh
	mi.material_override = Blockout.mat(Color(0.35, 0.2, 0.2))
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, 0.5, length)
	cs.shape = shape
	body.add_child(mi)
	body.add_child(cs)
	add_child(body)
	body.global_position = center
	body.rotation.x = atan2(rise, run)


func _swing_anchor(pos: Vector3) -> void:
	var anchor := SwingAnchor.new()
	add_child(anchor)
	anchor.global_position = pos


func _build_stage() -> void:
	# Coplanar boards: CharacterBody can't step up, so no raised stage.
	Blockout.box(self, Vector3(0, -0.05, -7), Vector3(30, 0.1, 6),
		Color(0.4, 0.25, 0.12))
	Blockout.box(self, Vector3(0, 4, -9.5), Vector3(30, 8, 0.5),
		Color(0.08, 0.05, 0.1))
	var velvet := Color(0.6, 0.08, 0.1)
	Blockout.box(self, Vector3(-13, 4, -8), Vector3(4, 8, 1), velvet)
	Blockout.box(self, Vector3(13, 4, -8), Vector3(4, 8, 1), velvet)
	Blockout.box(self, Vector3(0, 7.5, -8), Vector3(30, 2, 1), velvet)
	Blockout.label(self, Vector3(0, 7.5, -7.4), "MYSTERIO", Color(1, 0.8, 0.3), 96)
	var warm := Color(1, 0.8, 0.5)
	for x in [-10.0, -5.0, 0.0, 5.0, 10.0]:
		var lamp := Blockout.sphere(self, Vector3(x, 0.3, -3.8), 0.18, warm)
		lamp.material_override = Blockout.mat_emissive(warm, 2.0)
	# Teleport pedestals.
	var disc := Color(0.3, 0.1, 0.45)
	for pos in _pedestals():
		Blockout.cylinder(self, pos + Vector3(0, 0.125, 0), 1.2, 0.25, disc)


func _pedestals() -> Array[Vector3]:
	return [Vector3(0, 0, -7), Vector3(-8, 0, -7), Vector3(8, 0, -7),
		Vector3(-12, 0, 6), Vector3(12, 0, 6)]


func _build_seats() -> void:
	var velvet := Color(0.5, 0.08, 0.12)
	for z in [2.0, 6.0, 10.0, 14.0]:
		for x in [-12.0, -7.2, -2.4, 2.4, 7.2, 12.0]:
			Blockout.box(self, Vector3(x, 0.45, z), Vector3(1.8, 0.9, 0.7), velvet)


func _build_actors() -> void:
	_spawn_patrol(Vector3(-5, 0, 12), [Vector3(-5, 0, 12), Vector3(5, 0, 12)])
	_spawn_patrol(Vector3(5, 0, 16), [Vector3(5, 0, 16), Vector3(-5, 0, 16)])
	_spawn_thug(Vector3(-17, 0, 0), true)
	_spawn_thug(Vector3(10, 0, -2), true)
	_spawn_hostage(Vector3(-14, 0, 8))
	_spawn_hostage(Vector3(14, 0, 4))
	_spawn_token(Vector3(0, 7.0, 5))
	_spawn_token(Vector3(13, 1.2, -6))
	_spawn_pickup(HEALTH_SCENE, Vector3(10, 0, 18))
	_spawn_pickup(HEALTH_SCENE, Vector3(-10, 0, -2))
	_spawn_pickup(WEB_SCENE, Vector3(-4, 0, 4))
	_spawn_pickup(WEB_SCENE, Vector3(4, 0, 12))
	var peds := _pedestals()
	_mysterio = MYSTERIO_SCENE.instantiate() as Mysterio
	_mysterio.pedestals = peds
	add_child(_mysterio)
	_mysterio.global_position = peds[0]
	enemies_total = 1
	_mysterio.downed.connect(_on_mysterio_downed)
	var trigger := Blockout.trigger(self, Vector3(0, 2, -2), Vector3(36, 4, 16))
	trigger.body_entered.connect(_on_arena_entered)
	_exit = EXIT_SCENE.instantiate() as ExitGate
	add_child(_exit)
	_exit.global_position = Vector3(-16, 0, -7)
	Blockout.label(self, Vector3(-16, 3.6, -7), "STAGE DOOR", Color(0.4, 1, 0.5), 64)


func _spawn_patrol(pos: Vector3, points: Array) -> void:
	var thug := THUG_SCENE.instantiate() as Thug
	for point in points:
		thug.patrol_points.append(point)
	add_child(thug)
	thug.global_position = pos


func _spawn_thug(pos: Vector3, gun: bool) -> void:
	var thug := THUG_SCENE.instantiate() as Thug
	thug.has_gun = gun
	if gun:
		thug.max_hp = 40.0
	add_child(thug)
	thug.global_position = pos


func _spawn_hostage(pos: Vector3) -> void:
	var hostage := HOSTAGE_SCENE.instantiate() as Hostage
	add_child(hostage)
	hostage.global_position = pos


func _spawn_pickup(scene: PackedScene, pos: Vector3) -> void:
	var pickup := scene.instantiate() as Area3D
	add_child(pickup)
	pickup.global_position = pos


func _spawn_token(pos: Vector3) -> void:
	var token := SpiderToken.new()
	add_child(token)
	token.global_position = pos


func _on_arena_entered(body: Node3D) -> void:
	if body.is_in_group("player") and _mysterio != null:
		_mysterio.activate()


func _on_mysterio_downed() -> void:
	enemies_down += 1
	Game.add_score(500)
	if hud != null:
		hud.flash_message("MYSTERIO DOWN! +500", Color(0.4, 1, 0.5), 3.0)
	_update_counters()
	_on_actor_event()


func _on_actor_event() -> void:
	if _exit != null and enemies_down >= enemies_total \
		and hostages_saved >= hostages_total:
		_exit.unlock()
		Game.set_objective("Escape through the EXIT!")
