class_name StreetsLevel
extends LevelBase
## Level 4: Rhino rampages down the avenue. Advance north with 4 thugs
## and 2 hostages in the way, then boss fight: dodge the charge, lure
## him into a wall, punish the stun. Exit unlocks at full clear.

const THUG_SCENE: PackedScene = preload("res://enemies/thug.tscn")
const RHINO_SCENE: PackedScene = preload("res://enemies/rhino.tscn")
const HOSTAGE_SCENE: PackedScene = preload("res://npc/hostage.tscn")
const WEB_SCENE: PackedScene = preload("res://pickups/web_pickup.tscn")
const HEALTH_SCENE: PackedScene = preload("res://pickups/health_pickup.tscn")
const EXIT_SCENE: PackedScene = preload("res://props/exit_gate.tscn")

var _rhino: Rhino = null
var _exit: ExitGate = null


func _build() -> void:
	level_id = "streets"
	level_name = "Level 4: Streets"
	next_level_path = "res://levels/roofs/roofs.tscn"
	_build_road()
	_build_blocks()
	_build_street_props()
	_build_actors()
	Game.set_objective("Head north - stop the Rhino!")


func _build_road() -> void:
	Blockout.box(self, Vector3(0, -0.5, 0), Vector3(24, 1, 150),
		Color(0.12, 0.12, 0.14))
	for z in range(-69, 70, 6):
		Blockout.box(self, Vector3(0, 0.02, z), Vector3(0.3, 0.04, 2.0),
			Color(0.85, 0.7, 0.1), false)
	# Flush sidewalks (coplanar: CharacterBody can't step up).
	var walk := Color(0.38, 0.38, 0.4)
	Blockout.box(self, Vector3(-15, -0.05, 0), Vector3(6, 0.1, 150), walk)
	Blockout.box(self, Vector3(15, -0.05, 0), Vector3(6, 0.1, 150), walk)
	# Hard end caps.
	var cap := Color(0.3, 0.3, 0.34)
	Blockout.box(self, Vector3(0, 3, 74), Vector3(60, 6, 2), cap)
	Blockout.box(self, Vector3(0, 3, -74), Vector3(60, 6, 2), cap)
	_police_line(Vector3(0, 0, 70))
	_police_line(Vector3(0, 0, -68))


func _police_line(pos: Vector3) -> void:
	var blue := Color(0.1, 0.2, 0.7)
	for sx in [-4.0, 0.0, 4.0]:
		Blockout.box(self, pos + Vector3(sx, 0.5, 0), Vector3(3.4, 1.0, 0.4), blue)
	Blockout.label(self, pos + Vector3(0, 2.2, 0), "POLICE LINE", Color(0.6, 0.75, 1.0), 64)


func _build_blocks() -> void:
	var heights := [18.0, 26.0, 22.0, 30.0, 20.0, 24.0]
	var tints := [Color(0.5, 0.48, 0.45), Color(0.42, 0.45, 0.52),
		Color(0.55, 0.5, 0.45), Color(0.45, 0.42, 0.4),
		Color(0.48, 0.5, 0.55), Color(0.52, 0.47, 0.42)]
	var glass := Color(0.15, 0.22, 0.32)
	for side in [-1.0, 1.0]:
		for i in 6:
			var z := -70.0 + i * 28.0
			var h: float = heights[i]
			Blockout.box(self, Vector3(side * 23, h * 0.5, z),
				Vector3(10, h, 28), tints[i])
			for wy in [4.0, 9.0, 14.0, 19.0]:
				if wy > h - 2.0:
					continue
				for wz in [-7.0, 7.0]:
					Blockout.box(self, Vector3(side * 17.9, wy, z + wz),
						Vector3(0.2, 2.4, 8.0), glass, false)


func _build_street_props() -> void:
	# Lamps double as swing anchors down the avenue.
	var lamp_i := 0
	for z in [-60.0, -30.0, 0.0, 30.0, 60.0]:
		var x := 10.5 if lamp_i % 2 == 0 else -10.5
		Blockout.cylinder(self, Vector3(x, 4.5, z), 0.15, 9.0, Color(0.25, 0.25, 0.28))
		Blockout.box(self, Vector3(x, 9.1, z), Vector3(1.6, 0.3, 0.5),
			Color(0.25, 0.25, 0.28))
		var anchor := SwingAnchor.new()
		add_child(anchor)
		anchor.global_position = Vector3(x, 9.3, z)
		lamp_i += 1
	# Parked cars (Rhino fodder).
	_spawn_car(Vector3(-5, 0, 40), 0.0, Color(0.7, 0.1, 0.1))
	_spawn_car(Vector3(5, 0, 15), PI, Color(0.1, 0.2, 0.7))
	_spawn_car(Vector3(-4, 0, -5), 0.1, Color(0.8, 0.6, 0.1))
	_spawn_car(Vector3(4, 0, -22), -0.05, Color(0.2, 0.6, 0.2))
	_spawn_car(Vector3(-5, 0, -40), PI, Color(0.6, 0.6, 0.65))
	_spawn_car(Vector3(5, 0, -55), 0.0, Color(0.4, 0.1, 0.5))
	# Concrete planters: mid-road stun walls.
	for pos in [Vector3(-3, 0, 8), Vector3(3, 0, -12), Vector3(0, 0, -34)]:
		Blockout.box(self, pos + Vector3(0, 0.5, 0), Vector3(2, 1, 2),
			Color(0.55, 0.55, 0.57))
		Blockout.box(self, pos + Vector3(0, 1.1, 0), Vector3(1.8, 0.3, 1.8),
			Color(0.15, 0.4, 0.15))


func _spawn_car(pos: Vector3, yaw: float, paint: Color) -> void:
	var car := Car.new()
	car.paint = paint
	add_child(car)
	car.global_position = pos
	car.rotation.y = yaw


func _build_actors() -> void:
	# South patrols.
	_spawn_patrol(Vector3(-6, 0, 50), [Vector3(-6, 0, 50), Vector3(6, 0, 50)])
	_spawn_patrol(Vector3(6, 0, 58), [Vector3(6, 0, 58), Vector3(-6, 0, 58)])
	# Gunners on the sidewalks.
	_spawn_thug(Vector3(-15, 0, 25), true)
	_spawn_thug(Vector3(15, 0, 5), true)
	_spawn_hostage(Vector3(-7, 0, 36))
	_spawn_hostage(Vector3(7, 0, -3))
	_spawn_pickup(HEALTH_SCENE, Vector3(10, 0, 30))
	_spawn_pickup(HEALTH_SCENE, Vector3(-10, 0, -45))
	_spawn_pickup(WEB_SCENE, Vector3(-10, 0, 50))
	_spawn_pickup(WEB_SCENE, Vector3(10, 0, -20))
	# The boss, dormant until the trigger.
	_rhino = RHINO_SCENE.instantiate() as Rhino
	add_child(_rhino)
	_rhino.global_position = Vector3(0, 0, -25)
	enemies_total = 1
	_rhino.downed.connect(_on_rhino_downed)
	var trigger := Blockout.trigger(self, Vector3(0, 2, 20), Vector3(24, 4, 4))
	trigger.body_entered.connect(_on_arena_entered)
	_exit = EXIT_SCENE.instantiate() as ExitGate
	add_child(_exit)
	_exit.global_position = Vector3(0, 0, -62)


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
	if body.is_in_group("player") and _rhino != null:
		_rhino.activate()


func _on_rhino_downed() -> void:
	enemies_down += 1
	Game.add_score(500)
	if hud != null:
		hud.flash_message("RHINO DOWN! +500", Color(0.4, 1, 0.5), 3.0)
	_update_counters()
	_on_actor_event()


func _on_actor_event() -> void:
	if _exit != null and enemies_down >= enemies_total \
			and hostages_saved >= hostages_total:
		_exit.unlock()
		Game.set_objective("Escape through the EXIT!")
