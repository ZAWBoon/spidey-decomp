class_name RoofsLevel
extends LevelBase
## Level 5: night rooftops vs SCORPION. Main arena roof (cover AC units,
## water tower, billboard) + a side roof island 3.5 m east holding a
## hostage and pickups - fall and the kill plane costs 10 HP + respawn.

const THUG_SCENE: PackedScene = preload("res://enemies/thug.tscn")
const SCORPION_SCENE: PackedScene = preload("res://enemies/scorpion.tscn")
const HOSTAGE_SCENE: PackedScene = preload("res://npc/hostage.tscn")
const WEB_SCENE: PackedScene = preload("res://pickups/web_pickup.tscn")
const HEALTH_SCENE: PackedScene = preload("res://pickups/health_pickup.tscn")
const EXIT_SCENE: PackedScene = preload("res://props/exit_gate.tscn")

const SIDE_X := 35.5

var _scorpion: Scorpion = null
var _exit: ExitGate = null


func _build() -> void:
	level_id = "roofs"
	level_name = "Level 5: Roofs"
	next_level_path = "res://levels/theater/theater.tscn"
	_build_main_roof()
	_build_side_roof()
	_build_props()
	_build_actors()
	Game.set_objective("Cross the roofs - take down Scorpion!")


func _build_main_roof() -> void:
	Blockout.box(self, Vector3(0, -0.5, 0), Vector3(44, 1, 44),
		Color(0.32, 0.32, 0.34))
	Blockout.box(self, Vector3(0, -16, 0), Vector3(44, 30, 44),
		Color(0.15, 0.15, 0.18))
	var lip := Color(0.4, 0.4, 0.42)
	Blockout.box(self, Vector3(0, 0.5, -21.5), Vector3(44, 1, 1), lip)
	Blockout.box(self, Vector3(0, 0.5, 21.5), Vector3(44, 1, 1), lip)
	Blockout.box(self, Vector3(-21.5, 0.5, 0), Vector3(1, 1, 44), lip)
	# East lip split: jump gap at z in [-2, 2].
	Blockout.box(self, Vector3(22, 0.5, -12), Vector3(1, 1, 20), lip)
	Blockout.box(self, Vector3(22, 0.5, 12), Vector3(1, 1, 20), lip)
	for wy in [-6.0, -10.0, -14.0]:
		for wx in [-15.0, -5.0, 5.0, 15.0]:
			_lit_window(Vector3(wx, wy, 22.1))
	var kill := Blockout.trigger(self, Vector3(0, -3.5, 5), Vector3(130, 5, 130))
	kill.body_entered.connect(_on_fell)


func _lit_window(pos: Vector3) -> void:
	var warm := Color(1, 0.75, 0.45)
	var win := Blockout.box(self, pos, Vector3(1.6, 1.2, 0.2), warm, false)
	(win as MeshInstance3D).material_override = Blockout.mat_emissive(warm, 1.5)


func _build_side_roof() -> void:
	Blockout.box(self, Vector3(SIDE_X, -0.5, 0), Vector3(20, 1, 20),
		Color(0.3, 0.3, 0.32))
	Blockout.box(self, Vector3(SIDE_X, -16, 0), Vector3(20, 30, 20),
		Color(0.13, 0.13, 0.16))
	var lip := Color(0.38, 0.38, 0.4)
	Blockout.box(self, Vector3(SIDE_X, 0.5, -9.5), Vector3(20, 1, 1), lip)
	Blockout.box(self, Vector3(SIDE_X, 0.5, 9.5), Vector3(20, 1, 1), lip)
	Blockout.box(self, Vector3(SIDE_X + 9.5, 0.5, 0), Vector3(1, 1, 20), lip)
	Blockout.box(self, Vector3(SIDE_X - 10, 0.5, -6), Vector3(1, 1, 8), lip)
	Blockout.box(self, Vector3(SIDE_X - 10, 0.5, 6), Vector3(1, 1, 8), lip)
	# Pigeon coop + crates.
	Blockout.box(self, Vector3(SIDE_X + 5, 1.0, -5), Vector3(3, 2, 2),
		Color(0.4, 0.3, 0.2))
	Blockout.box(self, Vector3(SIDE_X - 4, 0.5, 6), Vector3(1.5, 1, 1.5),
		Color(0.45, 0.35, 0.22))


func _build_props() -> void:
	# AC units: bolt cover.
	var ac := Color(0.5, 0.55, 0.6)
	var fan := Color(0.15, 0.15, 0.17)
	for pos in [Vector3(-12, 0, -5), Vector3(12, 0, -5), Vector3(-8, 0, 8),
			Vector3(8, 0, 8), Vector3(-15, 0, 2), Vector3(15, 0, -12)]:
		Blockout.box(self, pos + Vector3(0, 0.6, 0), Vector3(2, 1.2, 1.5), ac)
		Blockout.cylinder(self, pos + Vector3(0, 1.25, 0), 0.5, 0.1, fan, false)
	for pos in [Vector3(-5, 0, -12), Vector3(5, 0, 14), Vector3(-18, 0, -15)]:
		Blockout.cylinder(self, pos + Vector3(0, 0.75, 0), 0.4, 1.5, ac)
	# Water tower.
	var wood := Color(0.42, 0.3, 0.18)
	for sx in [-1.2, 1.2]:
		for sz in [-1.2, 1.2]:
			Blockout.cylinder(self, Vector3(-16 + sx, 3, 14 + sz), 0.15, 6.0, wood)
	Blockout.cylinder(self, Vector3(-16, 7.7, 14), 2.2, 3.5, wood)
	Blockout.cylinder(self, Vector3(-16, 9.6, 14), 2.3, 0.3, Color(0.3, 0.2, 0.12))
	# Billboard + swing anchor.
	var post := Color(0.25, 0.25, 0.28)
	for sx in [-4.0, 4.0]:
		Blockout.cylinder(self, Vector3(sx, 3.5, -19), 0.2, 7.0, post)
	Blockout.box(self, Vector3(0, 8, -19), Vector3(12, 4, 0.4), Color(0.1, 0.1, 0.12))
	Blockout.label(self, Vector3(0, 8, -18.7), "SCORPION!", Color(1, 0.45, 0.1), 96)
	_swing_anchor(Vector3(0, 10.5, -19))
	# Antenna mast + red beacon + swing anchor.
	Blockout.cylinder(self, Vector3(18, 6, 16), 0.2, 12.0, post)
	var beacon := Blockout.sphere(self, Vector3(18, 12.2, 16), 0.3, Color(1, 0.1, 0.1))
	beacon.material_override = Blockout.mat_emissive(Color(1, 0.1, 0.1), 3.0)
	_swing_anchor(Vector3(18, 12.4, 16))
	# Stairwell hut + door.
	Blockout.box(self, Vector3(0, 1.25, -17), Vector3(4, 2.5, 3.5),
		Color(0.36, 0.36, 0.38))
	Blockout.box(self, Vector3(0, 1.0, -15.2), Vector3(1.4, 2.0, 0.2),
		Color(0.08, 0.08, 0.1), false)
	Blockout.omni(self, Vector3(0, 4, 5), Color(1, 0.9, 0.75), 1.2, 16.0)
	Blockout.omni(self, Vector3(0, 3, -14), Color(1, 0.85, 0.65), 1.0, 12.0)


func _swing_anchor(pos: Vector3) -> void:
	var anchor := SwingAnchor.new()
	add_child(anchor)
	anchor.global_position = pos


func _build_actors() -> void:
	_spawn_patrol(Vector3(-10, 0, 14), [Vector3(-10, 0, 14), Vector3(10, 0, 14)])
	_spawn_patrol(Vector3(10, 0, 18), [Vector3(10, 0, 18), Vector3(-10, 0, 18)])
	_spawn_thug(Vector3(-16, 0, -2), true)
	_spawn_thug(Vector3(16, 0, 2), true)
	_spawn_hostage(Vector3(2.8, 0, -16))
	_spawn_hostage(Vector3(SIDE_X + 1, 0, 4))
	_spawn_pickup(HEALTH_SCENE, Vector3(18, 0, 10))
	_spawn_pickup(HEALTH_SCENE, Vector3(SIDE_X, 0, -4))
	_spawn_pickup(WEB_SCENE, Vector3(-18, 0, -8))
	_spawn_pickup(WEB_SCENE, Vector3(SIDE_X + 3, 0, 6))
	_scorpion = SCORPION_SCENE.instantiate() as Scorpion
	add_child(_scorpion)
	_scorpion.global_position = Vector3(0, 0, -8)
	enemies_total = 1
	_scorpion.downed.connect(_on_scorpion_downed)
	var trigger := Blockout.trigger(self, Vector3(0, 2, -4), Vector3(34, 4, 20))
	trigger.body_entered.connect(_on_arena_entered)
	_exit = EXIT_SCENE.instantiate() as ExitGate
	add_child(_exit)
	_exit.global_position = Vector3(0, 0, -14)


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


func _on_arena_entered(body: Node3D) -> void:
	if body.is_in_group("player") and _scorpion != null:
		_scorpion.activate()


func _on_fell(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if player != null and not player.health.is_dead():
		player.take_hit(10.0, null)
		respawn_player()


func _on_scorpion_downed() -> void:
	enemies_down += 1
	Game.add_score(500)
	if hud != null:
		hud.flash_message("SCORPION DOWN! +500", Color(0.4, 1, 0.5), 3.0)
	_update_counters()
	_on_actor_event()


func _on_actor_event() -> void:
	if _exit != null and enemies_down >= enemies_total \
			and hostages_saved >= hostages_total:
		_exit.unlock()
		Game.set_objective("Escape through the EXIT!")
