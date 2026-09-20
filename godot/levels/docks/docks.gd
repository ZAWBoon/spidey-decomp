class_name DocksLevel
extends LevelBase
## Level 2: sunset docks. Clear the yard (2 workers + 8 thugs, one a
## bruiser), then enter the warehouse and escape. Cranes and poles are
## swing anchors; two piers stretch over open water (don't fall in).
## 5 spider-tokens hidden around (one at each pier end).

const THUG_SCENE: PackedScene = preload("res://enemies/thug.tscn")
const HOSTAGE_SCENE: PackedScene = preload("res://npc/hostage.tscn")
const WEB_SCENE: PackedScene = preload("res://pickups/web_pickup.tscn")
const HEALTH_SCENE: PackedScene = preload("res://pickups/health_pickup.tscn")
const BARREL_SCENE: PackedScene = preload("res://props/barrel.tscn")
const EXIT_SCENE: PackedScene = preload("res://props/exit_gate.tscn")

const YARD_THUGS := 8
const YARD_HOSTAGES := 2

var _door_visual: MeshInstance3D = null
var _door_blocker: StaticBody3D = null
var _door_label: Label3D = null
var _door_open: bool = false
var _exit: ExitGate = null


func _build() -> void:
	SkyDeco.sunset(self)
	level_id = "docks"
	level_name = "Level 2: Docks"
	next_level_path = "res://levels/bugle/bugle.tscn"
	_build_ground()
	_build_water()
	_build_pier()
	_build_warehouse()
	_build_cranes()
	_build_crates()
	_build_tokens()
	_build_actors()
	Game.set_objective("Clear the docks: save 2 workers, drop 8 thugs")


func _build_ground() -> void:
	Blockout.box(self, Vector3(0, -0.5, 20), Vector3(80, 1, 80), Color(0.4, 0.4, 0.42))
	var fence := Color(0.5, 0.5, 0.55)
	Blockout.box(self, Vector3(0, 1.5, 60), Vector3(80, 3, 1), fence)
	Blockout.box(self, Vector3(-40, 1.5, 20), Vector3(1, 3, 80), fence)
	Blockout.box(self, Vector3(40, 1.5, 20), Vector3(1, 3, 80), fence)
	Blockout.label(self, Vector3(0, 7, 30), "PIER 7 - SUNSET", Color(1, 0.75, 0.45), 96)


func _build_water() -> void:
	var water := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(160, 1, 64)
	water.mesh = mesh
	water.material_override = Blockout.mat(Color(0.08, 0.25, 0.45))
	add_child(water)
	water.global_position = Vector3(0, -2, -52)
	# NOTE: trigger stays below the pier deck (top y=0) so walking the
	# pier is safe; only a real fall (body bottom under y=-1) fires it.
	var splash := Blockout.trigger(self, Vector3(0, -2.5, -52), Vector3(160, 3, 64))
	splash.body_entered.connect(_on_water_body)
	# Distant container ship (backdrop, far outside the trigger).
	Blockout.box(self, Vector3(-55, -1, -65), Vector3(30, 6, 12),
		Color(0.12, 0.16, 0.25), false)
	Blockout.box(self, Vector3(-60, 3.5, -65), Vector3(8, 3, 10), Color(0.7, 0.15, 0.1), false)
	Blockout.box(self, Vector3(-52, 3.5, -65), Vector3(8, 3, 10), Color(0.15, 0.5, 0.2), false)


func _on_water_body(body: Node3D) -> void:
	if not body.is_in_group("player") or player == null:
		return
	FX.splash(self, Vector3(body.global_position.x, -1.5, body.global_position.z))
	player.take_hit(10.0, null)
	if not player.health.is_dead():
		respawn_player()
		if hud != null:
			hud.flash_message("Man overboard! -10", Color(0.5, 0.8, 1.0))


func _build_pier() -> void:
	var wood := Color(0.45, 0.32, 0.2)
	Blockout.box(self, Vector3(0, -0.25, -32), Vector3(10, 0.5, 24), wood)
	for px in [-4.0, 4.0]:
		for pz in [-24.0, -32.0, -40.0]:
			Blockout.cylinder(self, Vector3(px, -1.5, pz), 0.25, 3.0,
				Color(0.3, 0.22, 0.15))
	# East pier: same deck, crates + barrel + token at the far end.
	Blockout.box(self, Vector3(25, -0.25, -32), Vector3(10, 0.5, 24), wood)
	for px in [21.0, 29.0]:
		for pz in [-24.0, -32.0, -40.0]:
			Blockout.cylinder(self, Vector3(px, -1.5, pz), 0.25, 3.0,
				Color(0.3, 0.22, 0.15))
	# Lamp posts on both piers (emissive heads catch the sunset glow).
	for pos in [Vector3(-4, 0, -24), Vector3(4, 0, -40),
			Vector3(21, 0, -24), Vector3(29, 0, -40)]:
		Blockout.cylinder(self, pos + Vector3(0, 1.5, 0), 0.12, 3.0,
			Color(0.2, 0.2, 0.22))
		var head := Blockout.sphere(self, pos + Vector3(0, 3.1, 0), 0.22,
			Color(1, 0.9, 0.7))
		head.material_override = Blockout.mat_emissive(Color(1, 0.9, 0.7), 2.0)


func _build_warehouse() -> void:
	var wall := Color(0.45, 0.28, 0.2)
	Blockout.box(self, Vector3(-9, 4, 35), Vector3(12, 8, 1), wall)
	Blockout.box(self, Vector3(9, 4, 35), Vector3(12, 8, 1), wall)
	Blockout.box(self, Vector3(0, 7, 35), Vector3(6, 2, 1), wall)
	Blockout.box(self, Vector3(0, 4, 55), Vector3(31, 8, 1), wall)
	Blockout.box(self, Vector3(-15, 4, 45), Vector3(1, 8, 21), wall)
	Blockout.box(self, Vector3(15, 4, 45), Vector3(1, 8, 21), wall)
	_door_visual = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(6, 3, 0.6)
	_door_visual.mesh = mesh
	_door_visual.material_override = Blockout.mat_transparent(Color(0.9, 0.1, 0.1, 0.5))
	add_child(_door_visual)
	_door_visual.global_position = Vector3(0, 1.5, 35)
	_door_blocker = StaticBody3D.new()
	_door_blocker.collision_layer = 1
	_door_blocker.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(6, 3, 0.6)
	cs.shape = shape
	_door_blocker.add_child(cs)
	add_child(_door_blocker)
	_door_blocker.global_position = Vector3(0, 1.5, 35)
	_door_label = Blockout.label(self, Vector3(0, 3.8, 35), "LOCKED", Color(1, 0.3, 0.25), 56)
	Blockout.label(self, Vector3(0, 8.6, 45), "WAREHOUSE 7", Color(1, 0.8, 0.5), 72)
	Blockout.omni(self, Vector3(0, 6, 45), Color(1, 0.9, 0.75), 1.2, 18.0)


func _build_cranes() -> void:
	_crane(Vector3(-25, 0, -5))
	_crane(Vector3(25, 0, 15))
	for spot in [Vector3(-12, 0, -16), Vector3(12, 0, -16)]:
		Blockout.cylinder(self, spot + Vector3(0, 5.5, 0), 0.3, 11.0,
			Color(0.45, 0.45, 0.5))
		_add_anchor(spot + Vector3(0, 11, 0))


func _crane(base: Vector3) -> void:
	var yellow := Color(0.85, 0.65, 0.1)
	Blockout.box(self, base + Vector3(-2.5, 5.5, 0), Vector3(0.8, 11, 0.8), yellow)
	Blockout.box(self, base + Vector3(2.5, 5.5, 0), Vector3(0.8, 11, 0.8), yellow)
	Blockout.box(self, base + Vector3(0, 11, 0), Vector3(7, 0.8, 0.8), yellow)
	_add_anchor(base + Vector3(0, 10.4, 0))


func _add_anchor(pos: Vector3) -> void:
	var anchor := SwingAnchor.new()
	add_child(anchor)
	anchor.global_position = pos


func _build_crates() -> void:
	var wood_a := Color(0.5, 0.38, 0.22)
	var wood_b := Color(0.42, 0.3, 0.18)
	_crate(Vector3(-22, 0, 8), 3.0, wood_a)
	_crate(Vector3(-22, 3.0, 8), 1.6, wood_b)
	Breakable.spawn(self, Vector3(-18, 0, 12), "crate", 2.0)
	_crate(Vector3(16, 0, 18), 2.5, wood_a)
	_crate(Vector3(19, 0, 18), 2.0, wood_b)
	Breakable.spawn(self, Vector3(16, 0, 30), "crate", 2.0)
	_crate(Vector3(24, 0, 32), 3.0, wood_a)
	_crate(Vector3(-8, 0, 40), 2.5, wood_a)
	Breakable.spawn(self, Vector3(8, 0, 42), "crate", 2.0)
	_crate(Vector3(-30, 0, 25), 2.2, wood_b)
	_crate(Vector3(30, 0, 5), 2.2, wood_a)
	Breakable.spawn(self, Vector3(5, 0, -8), "crate", 2.0)
	_crate(Vector3(23, 0, -30), 2.0, wood_b)
	_crate(Vector3(27, 0, -36), 1.6, wood_a)
	for pos in [Vector3(-19, 0, 5), Vector3(17.5, 0, 15),
			Vector3(0, 0, -40), Vector3(-28, 0, 28), Vector3(25, 0, -24)]:
		var barrel := BARREL_SCENE.instantiate() as Barrel
		add_child(barrel)
		barrel.global_position = pos


func _crate(base_pos: Vector3, size: float, color: Color) -> void:
	Blockout.box(self, base_pos + Vector3(0, size * 0.5, 0),
		Vector3(size, size, size), color)


func _build_tokens() -> void:
	_spawn_token(Vector3(0, 1.2, -42))
	_spawn_token(Vector3(-25, 1.2, -5))
	_spawn_token(Vector3(5, 1.2, 48))
	_spawn_token(Vector3(25, 1.2, -40))
	_spawn_token(Vector3(-22, 1.2, 2))


func _spawn_token(pos: Vector3) -> void:
	var token := SpiderToken.new()
	add_child(token)
	token.global_position = pos


func _build_actors() -> void:
	_spawn_hostage(Vector3(-30, 0, 30))
	_spawn_hostage(Vector3(30, 0, -5))
	_spawn_patrol(Vector3(-25, 0, 20), [Vector3(-25, 0, 20), Vector3(-10, 0, 25)])
	_spawn_patrol(Vector3(15, 0, 5), [Vector3(15, 0, 5), Vector3(28, 0, 12)])
	_spawn_thug(Vector3(-12, 0, 38), false)
	_spawn_thug(Vector3(12, 0, 38), false)
	_spawn_thug(Vector3(0, 0, 25), false)
	_spawn_thug(Vector3(-6, 0, 36), true)
	_spawn_thug(Vector3(6, 0, 36), true)
	_spawn_bruiser(Vector3(0, 0, -38))
	_spawn_pickup(WEB_SCENE, Vector3(-33, 0, 15))
	_spawn_pickup(WEB_SCENE, Vector3(33, 0, 20))
	_spawn_pickup(HEALTH_SCENE, Vector3(-8, 0, 30))
	_spawn_pickup(HEALTH_SCENE, Vector3(10, 0, -2))
	_exit = EXIT_SCENE.instantiate() as ExitGate
	add_child(_exit)
	_exit.global_position = Vector3(0, 0, 52)


func _spawn_thug(pos: Vector3, gun: bool) -> Thug:
	var thug := THUG_SCENE.instantiate() as Thug
	thug.has_gun = gun
	if gun:
		thug.max_hp = 40.0
	add_child(thug)
	thug.global_position = pos
	return thug


func _spawn_patrol(pos: Vector3, points: Array) -> void:
	var thug := THUG_SCENE.instantiate() as Thug
	thug.patrol_points.assign(points)
	add_child(thug)
	thug.global_position = pos


func _spawn_bruiser(pos: Vector3) -> void:
	var thug := THUG_SCENE.instantiate() as Thug
	thug.max_hp = 120.0
	thug.damage = 18.0
	thug.move_speed = 2.7
	thug.scale = Vector3(1.3, 1.3, 1.3)
	add_child(thug)
	thug.global_position = pos
	Blockout.label(thug, Vector3(0, 2.2, 0), "BRUISER", Color(1, 0.4, 0.3), 56)


func _spawn_hostage(pos: Vector3) -> void:
	var hostage := HOSTAGE_SCENE.instantiate() as Hostage
	add_child(hostage)
	hostage.global_position = pos


func _spawn_pickup(scene: PackedScene, pos: Vector3) -> void:
	var pickup := scene.instantiate() as Area3D
	add_child(pickup)
	pickup.global_position = pos


func _on_actor_event() -> void:
	if _door_open:
		return
	if hostages_saved >= YARD_HOSTAGES and enemies_down >= YARD_THUGS:
		_door_open = true
		_door_visual.queue_free()
		_door_blocker.queue_free()
		_door_label.queue_free()
		Sfx.play("rescue")
		if hud != null:
			hud.flash_message("Warehouse open!", Color(0.4, 1, 0.5))
		if _exit != null:
			_exit.unlock()
		Game.set_objective("Enter the warehouse - escape!")
