class_name BugleLevel
extends LevelBase
## Level 3: Daily Bugle at night. Climb lobby -> newsroom -> JJJ offices
## -> roof. Entering floor 2 drops Venom: an unkillable chaser. Run.
## West alley annex (dumpsters, car, token). 5 spider-tokens total.

const THUG_SCENE: PackedScene = preload("res://enemies/thug.tscn")
const VENOM_SCENE: PackedScene = preload("res://enemies/venom.tscn")
const HOSTAGE_SCENE: PackedScene = preload("res://npc/hostage.tscn")
const WEB_SCENE: PackedScene = preload("res://pickups/web_pickup.tscn")
const HEALTH_SCENE: PackedScene = preload("res://pickups/health_pickup.tscn")
const EXIT_SCENE: PackedScene = preload("res://props/exit_gate.tscn")

var _venom: Venom = null
var _venom_out: bool = false
var _roof_done: bool = false
var _exit: ExitGate = null


func _build() -> void:
	SkyDeco.night(self)
	level_id = "bugle"
	level_name = "Level 3: Bugle"
	next_level_path = "res://levels/streets/streets.tscn"
	_build_street()
	_build_alley()
	_build_shell()
	_build_floors()
	_build_ramps()
	_build_actors()
	Game.set_objective("Climb to the newsroom (floor 2)")


func _build_street() -> void:
	Blockout.box(self, Vector3(0, -0.5, 40), Vector3(60, 1, 40), Color(0.16, 0.16, 0.2))
	var fence := Color(0.35, 0.35, 0.4)
	Blockout.box(self, Vector3(0, 1.5, 60), Vector3(60, 3, 1), fence)
	# West fence split: 6m gap (z 38..44) into the alley.
	Blockout.box(self, Vector3(-30, 1.5, 29), Vector3(1, 3, 18), fence)
	Blockout.box(self, Vector3(-30, 1.5, 52), Vector3(1, 3, 16), fence)
	Blockout.box(self, Vector3(30, 1.5, 40), Vector3(1, 3, 40), fence)
	for spot in [Vector3(-20, 0, 35), Vector3(20, 0, 35)]:
		Blockout.cylinder(self, spot + Vector3(0, 5.5, 0), 0.3, 11.0,
			Color(0.4, 0.4, 0.45))
		var anchor := SwingAnchor.new()
		add_child(anchor)
		anchor.global_position = spot + Vector3(0, 11, 0)
		Blockout.omni(self, spot + Vector3(0, 9, 0), Color(0.6, 0.75, 1.0), 1.5, 16.0)
	Blockout.label(self, Vector3(0, 8, 50), "DAILY BUGLE - NIGHT", Color(0.7, 0.85, 1.0), 96)
	_spawn_token(Vector3(-20, 1.2, 28))


func _build_alley() -> void:
	# West service alley (x -50..-30), enemy-free side pocket.
	Blockout.box(self, Vector3(-40, -0.5, 40), Vector3(20, 1, 40), Color(0.13, 0.13, 0.16))
	var fence := Color(0.35, 0.35, 0.4)
	Blockout.box(self, Vector3(-40, 1.5, 60), Vector3(20, 3, 1), fence)
	Blockout.box(self, Vector3(-50, 1.5, 40), Vector3(1, 3, 40), fence)
	Blockout.box(self, Vector3(-40, 1.5, 20), Vector3(20, 3, 1), fence)
	var dump := Color(0.12, 0.3, 0.14)
	Blockout.box(self, Vector3(-45, 0.75, 45), Vector3(3, 1.5, 2), dump)
	Blockout.box(self, Vector3(-45, 0.75, 49), Vector3(3, 1.5, 2), dump)
	_spawn_car(Vector3(-38, 0, 34), 0.0, Color(0.1, 0.15, 0.3))
	Blockout.box(self, Vector3(-33, 0.6, 26), Vector3(1.2, 1.2, 0.8), Color(0.2, 0.3, 0.6))
	Blockout.label(self, Vector3(-33, 2.0, 26), "NEWS", Color(0.8, 0.9, 1.0), 32)
	_spawn_pickup(WEB_SCENE, Vector3(-36, 0, 32))
	_spawn_token(Vector3(-44, 1.2, 52))


func _spawn_car(pos: Vector3, yaw: float, paint: Color) -> void:
	var car := Car.new()
	car.paint = paint
	add_child(car)
	car.global_position = pos
	car.rotation.y = yaw


func _build_shell() -> void:
	var wall := Color(0.32, 0.3, 0.36)
	Blockout.box(self, Vector3(-15, 7.5, 0), Vector3(1, 15, 30), wall)
	Blockout.box(self, Vector3(15, 7.5, 0), Vector3(1, 15, 30), wall)
	Blockout.box(self, Vector3(0, 7.5, -15), Vector3(31, 15, 1), wall)
	Blockout.box(self, Vector3(-8.75, 7.5, 15), Vector3(12.5, 15, 1), wall)
	Blockout.box(self, Vector3(8.75, 7.5, 15), Vector3(12.5, 15, 1), wall)
	Blockout.box(self, Vector3(0, 9.5, 15), Vector3(5, 11, 1), wall)
	# Lit windows on the south face.
	var lit := Color(1, 0.85, 0.55)
	for wx in range(-12, 13, 4):
		for wy in [3.0, 8.0, 13.0]:
			Blockout.box(self, Vector3(wx, wy, 15.6), Vector3(2, 1.5, 0.2), lit, false)
	# Roof parapets + globe.
	Blockout.box(self, Vector3(0, 15.6, -15), Vector3(31, 1.2, 1), wall)
	Blockout.box(self, Vector3(0, 15.6, 15), Vector3(31, 1.2, 1), wall)
	Blockout.box(self, Vector3(-15, 15.6, 0), Vector3(1, 1.2, 30), wall)
	Blockout.box(self, Vector3(15, 15.6, 0), Vector3(1, 1.2, 30), wall)
	Blockout.sphere(self, Vector3(0, 17, -12), 2.0, Color(0.2, 0.35, 0.6))
	Blockout.label(self, Vector3(0, 19.6, -12), "DAILY BUGLE", Color(0.8, 0.9, 1.0), 72)


func _build_floors() -> void:
	var slab := Color(0.45, 0.44, 0.42)
	Blockout.box(self, Vector3(0, -0.5, 0), Vector3(30, 1, 30), slab)
	# F2 (top y=5), shaft over ramp 1 (x in [10, 14]).
	Blockout.box(self, Vector3(-2.5, 4.5, 0), Vector3(25, 1, 30), slab)
	Blockout.box(self, Vector3(14.5, 4.5, 0), Vector3(1, 1, 30), slab)
	# F3 (top y=10), shaft over ramp 2 (x in [-14, -10]).
	Blockout.box(self, Vector3(-14.5, 9.5, 0), Vector3(1, 1, 30), slab)
	Blockout.box(self, Vector3(2.5, 9.5, 0), Vector3(25, 1, 30), slab)
	# Roof (top y=15), shaft over ramp 3 (x in [10, 14]).
	Blockout.box(self, Vector3(-2.5, 14.5, 0), Vector3(25, 1, 30), slab)
	Blockout.box(self, Vector3(14.5, 14.5, 0), Vector3(1, 1, 30), slab)
	Blockout.omni(self, Vector3(0, 3.5, 0))
	Blockout.omni(self, Vector3(0, 8.5, 0))
	Blockout.omni(self, Vector3(0, 13.5, 0))
	Blockout.omni(self, Vector3(0, 17, -8), Color(1, 0.9, 0.75), 1.0, 12.0)


func _build_ramps() -> void:
	_ramp(Vector3(12, 2.5, 0), 3.0, 10.0, -10.0, 0.0, 5.0)
	_landing(Vector3(12, 4.75, -11.5))
	_ramp(Vector3(-12, 7.5, 0), 3.0, 10.0, -10.0, 5.0, 10.0)
	_landing(Vector3(-12, 9.75, -11.5))
	_ramp(Vector3(12, 12.5, 0), 3.0, 10.0, -10.0, 10.0, 15.0)
	_landing(Vector3(12, 14.75, -11.5))


## Sloped walkway. All ramps run from +Z/low to -Z/high.
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
	mi.material_override = Blockout.mat(Color(0.5, 0.5, 0.52))
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, 0.5, length)
	cs.shape = shape
	body.add_child(mi)
	body.add_child(cs)
	add_child(body)
	body.global_position = center
	body.rotation.x = atan2(rise, run)


func _landing(center: Vector3) -> void:
	Blockout.box(self, center, Vector3(4, 0.5, 3), Color(0.48, 0.48, 0.5))


func _build_actors() -> void:
	# Floor 1: lobby.
	Blockout.box(self, Vector3(-5, 0.6, 8), Vector3(6, 1.2, 2), Color(0.35, 0.25, 0.15))
	Blockout.box(self, Vector3(0, 0.02, 0), Vector3(8, 0.04, 12),
		Color(0.4, 0.08, 0.1), false)
	for pos in [Vector3(-8, 0, 5), Vector3(8, 0, -5)]:
		Blockout.cylinder(self, pos + Vector3(0, 2, 0), 0.5, 4.0, Color(0.6, 0.58, 0.5))
	_spawn_thug(Vector3(-8, 0, 0), false)
	_spawn_thug(Vector3(8, 0, -8), false)
	_spawn_hostage(Vector3(12, 0, 12))
	_spawn_pickup(WEB_SCENE, Vector3(10, 0, 12))
	# Floor 2: newsroom.
	for pos in [Vector3(-4, 5, 2), Vector3(0, 5, 2), Vector3(4, 5, 2)]:
		Blockout.box(self, pos + Vector3(0, 1.5, 0), Vector3(3, 2, 0.2),
			Color(0.55, 0.55, 0.6))
		Blockout.box(self, pos + Vector3(0, 0.5, 1.2), Vector3(2.4, 1, 1),
			Color(0.4, 0.32, 0.22))
		Blockout.box(self, Vector3(pos.x, 6.05, 3.2), Vector3(1.2, 0.1, 0.8),
			Color(0.9, 0.88, 0.82), false)
	_spawn_thug(Vector3(-5, 5, -5), false)
	_spawn_thug(Vector3(5, 5, 5), true)
	_spawn_hostage(Vector3(-10, 5, 10))
	_spawn_pickup(HEALTH_SCENE, Vector3(-8, 5, 8))
	_spawn_token(Vector3(-12, 6.2, -12))
	# Floor 3: JJJ offices.
	Blockout.box(self, Vector3(0, 10.5, -10), Vector3(4, 1, 2), Color(0.3, 0.2, 0.12))
	Blockout.label(self, Vector3(0, 12.4, -10), "J. JONAH JAMESON", Color(1, 0.85, 0.5), 48)
	Blockout.box(self, Vector3(-8, 10.75, -12), Vector3(3, 1.5, 1), Color(0.35, 0.25, 0.15))
	for i in 3:
		Blockout.box(self, Vector3(-8.8 + i * 0.8, 11.7, -12), Vector3(0.5, 0.5, 0.7),
			[Color(0.7, 0.2, 0.2), Color(0.2, 0.4, 0.7), Color(0.2, 0.6, 0.3)][i], false)
	_spawn_thug(Vector3(0, 10, 5), false)
	_spawn_thug(Vector3(-5, 10, -5), true)
	_spawn_hostage(Vector3(10, 10, 10))
	_spawn_pickup(WEB_SCENE, Vector3(8, 10, -5))
	_spawn_token(Vector3(0, 11.2, -7))
	# Roof exit + dormant Venom.
	_spawn_token(Vector3(3, 16.2, -12))
	_exit = EXIT_SCENE.instantiate() as ExitGate
	add_child(_exit)
	_exit.global_position = Vector3(0, 15, -8)
	_venom = VENOM_SCENE.instantiate() as Venom
	add_child(_venom)
	_venom.global_position = Vector3(0, 8.5, 0)
	_venom.first_blood.connect(_on_first_blood)


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


func _process(delta: float) -> void:
	super._process(delta)
	if not active or player == null or player.health.is_dead():
		return
	var py := player.global_position.y
	if not _venom_out and py > 4.0:
		_venom_out = true
		_venom.activate(Vector3(0, 8.5, 0))
		Game.set_objective("VENOM! Run - reach the roof!")
		if hud != null:
			hud.flash_message("VENOM! RUN!", Color(0.7, 0.2, 1.0), 3.0)
	if not _roof_done and py > 13.5:
		_roof_done = true
		if _exit != null:
			_exit.unlock()
		if _venom != null and is_instance_valid(_venom):
			_venom.retreat()
		Game.set_objective("Escape through the EXIT!")
		if hud != null:
			hud.flash_message("He's gone... for now", Color(0.7, 0.8, 1.0))


func _on_first_blood() -> void:
	if hud != null:
		hud.flash_message("Venom is too strong - RUN!", Color(1, 0.5, 0.3), 3.0)


func _on_actor_event() -> void:
	pass
