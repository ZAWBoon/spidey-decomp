class_name BankLevel
extends LevelBase
## Level 1: bank heist in three gated zones.
## A) Lobby: rescue 3 hostages + drop 4 thugs. B) Vault hall: drop 5 thugs.
## C) Back room: defuse the bomb, then escape.

const THUG_SCENE: PackedScene = preload("res://enemies/thug.tscn")
const HOSTAGE_SCENE: PackedScene = preload("res://npc/hostage.tscn")
const PICKUP_SCENE: PackedScene = preload("res://pickups/web_pickup.tscn")
const BOMB_SCENE: PackedScene = preload("res://props/bomb.tscn")
const EXIT_SCENE: PackedScene = preload("res://props/exit_gate.tscn")

var _gate_a: Node3D = null
var _gate_b: Node3D = null
var _gate_a_open: bool = false
var _gate_b_open: bool = false
var _exit: ExitGate = null
var _bomb: Bomb = null
var _zone_b_announced: bool = false
var _zone_c_announced: bool = false


func _build() -> void:
	SkyDeco.day(self)
	level_id = "bank"
	level_name = "Level 1: Bank"
	next_level_path = "res://levels/docks/docks.tscn"
	_build_shell()
	_build_zone_a()
	_build_zone_b()
	_build_zone_c()
	Game.set_objective("Rescue 3 hostages, take down 4 thugs")


func _build_shell() -> void:
	var floor_mat := Color(0.42, 0.4, 0.38)
	var wall_mat := Color(0.55, 0.52, 0.45)
	Blockout.box(self, Vector3(0, -0.5, 0), Vector3(40, 1, 30), floor_mat)
	Blockout.box(self, Vector3(38.5, -0.5, 0), Vector3(33, 1, 30), floor_mat)
	Blockout.box(self, Vector3(67.5, -0.5, 0), Vector3(21, 1, 30), floor_mat)
	# North + south perimeter.
	Blockout.box(self, Vector3(29, 3, -15), Vector3(98, 6, 1), wall_mat)
	Blockout.box(self, Vector3(29, 3, 15), Vector3(98, 6, 1), wall_mat)
	# West + east perimeter.
	Blockout.box(self, Vector3(-20, 3, 0), Vector3(1, 6, 30), wall_mat)
	Blockout.box(self, Vector3(78, 3, 0), Vector3(1, 6, 30), wall_mat)
	# Dividing walls with 4m door gaps (z in [-2, 2]).
	_gate_a = _dividing_wall(21.0, wall_mat)
	_gate_b = _dividing_wall(56.0, wall_mat)
	Blockout.label(self, Vector3(0, 5.2, -12), "FIRST NATIONAL BANK", Color(1, 0.85, 0.4), 80)


func _dividing_wall(x: float, color: Color) -> Node3D:
	Blockout.box(self, Vector3(x, 3, -8.5), Vector3(1, 6, 13), color)
	Blockout.box(self, Vector3(x, 3, 8.5), Vector3(1, 6, 13), color)
	Blockout.box(self, Vector3(x, 4.5, 0), Vector3(1, 3, 4), color)
	var barrier := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.6, 3.0, 4.0)
	barrier.mesh = mesh
	barrier.material_override = Blockout.mat_transparent(Color(0.9, 0.1, 0.1, 0.5))
	add_child(barrier)
	barrier.global_position = Vector3(x, 1.5, 0)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.6, 3.0, 4.0)
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
	body.global_position = Vector3(x, 1.5, 0)
	barrier.set_meta("blocker", body)
	Blockout.label(self, Vector3(x, 3.6, 0), "LOCKED", Color(1, 0.3, 0.25), 56)
	return barrier


func _open_gate(barrier: MeshInstance3D, gate_name: String) -> void:
	if barrier == null or not is_instance_valid(barrier):
		return
	var blocker: Node = barrier.get_meta("blocker") as Node
	if blocker != null and is_instance_valid(blocker):
		blocker.queue_free()
	barrier.queue_free()
	Sfx.play("rescue")
	if hud != null:
		hud.flash_message(gate_name + " open!", Color(0.4, 1, 0.5))


func _build_zone_a() -> void:
	for pos in [Vector3(-8, 0, -7), Vector3(-8, 0, 7), Vector3(8, 0, -7), Vector3(8, 0, 7)]:
		Blockout.cylinder(self, pos + Vector3(0, 3, 0), 0.6, 6.0, Color(0.6, 0.58, 0.5))
	Blockout.box(self, Vector3(-10, 0.6, 0), Vector3(8, 1.2, 1.6), Color(0.35, 0.25, 0.15))
	Blockout.label(self, Vector3(-10, 2.4, 0), "TELLERS", Color.WHITE, 48)
	for pos in [Vector3(-14, 0, -8), Vector3(-14, 0, 8), Vector3(5, 0, 10)]:
		_spawn_hostage(pos)
	var thugs := [Vector3(-4, 0, -6), Vector3(-4, 0, 6), Vector3(10, 0, -4), Vector3(10, 0, 4)]
	for pos in thugs:
		_spawn_thug(pos, false)
	_spawn_pickup(Vector3(0, 0, -12))
	Blockout.omni(self, Vector3(0, 5, 0))
	Blockout.omni(self, Vector3(-12, 5, 8))


func _build_zone_b() -> void:
	Blockout.box(self, Vector3(38, 2, -14.2), Vector3(6, 4, 0.6), Color(0.3, 0.32, 0.35))
	Blockout.label(self, Vector3(38, 4.6, -13.4), "VAULT", Color(1, 0.85, 0.4), 56)
	Blockout.box(self, Vector3(30, 0.5, 6), Vector3(4, 1, 2), Color(0.35, 0.25, 0.15))
	Blockout.box(self, Vector3(46, 0.5, -6), Vector3(4, 1, 2), Color(0.35, 0.25, 0.15))
	for pos in [Vector3(28, 0, -4), Vector3(36, 0, 6), Vector3(46, 0, 0)]:
		_spawn_thug(pos, false)
	for pos in [Vector3(32, 0, -10), Vector3(50, 0, 10)]:
		_spawn_thug(pos, true)
	_spawn_pickup(Vector3(30, 0, 10))
	_spawn_pickup(Vector3(48, 0, -10))
	Blockout.omni(self, Vector3(38, 5, 0))


func _build_zone_c() -> void:
	Blockout.label(self, Vector3(67, 4.4, -10), "BACK ROOM", Color(1, 0.6, 0.3), 56)
	_bomb = BOMB_SCENE.instantiate() as Bomb
	_bomb.total_time = 90.0
	add_child(_bomb)
	_bomb.global_position = Vector3(70, 0, 0)
	_spawn_thug(Vector3(63, 0, -6), false)
	_spawn_thug(Vector3(63, 0, 6), true)
	_exit = EXIT_SCENE.instantiate() as ExitGate
	add_child(_exit)
	_exit.global_position = Vector3(75, 0, 0)
	Blockout.omni(self, Vector3(68, 5, 0), Color(1, 0.8, 0.7))


func _spawn_thug(pos: Vector3, gun: bool) -> Thug:
	var thug := THUG_SCENE.instantiate() as Thug
	thug.has_gun = gun
	if gun:
		thug.max_hp = 40.0
	add_child(thug)
	thug.global_position = pos
	return thug


func _spawn_hostage(pos: Vector3) -> void:
	var hostage := HOSTAGE_SCENE.instantiate() as Hostage
	add_child(hostage)
	hostage.global_position = pos


func _spawn_pickup(pos: Vector3) -> void:
	var pickup := PICKUP_SCENE.instantiate() as WebPickup
	add_child(pickup)
	pickup.global_position = pos


func _process(delta: float) -> void:
	super._process(delta)
	if not active or player == null:
		return
	var px := player.global_position.x
	if not _zone_b_announced and px > 22.0:
		_zone_b_announced = true
		if hud != null:
			hud.flash_message("Vault hall - armed guards!", Color(1, 0.6, 0.3))
	if not _zone_c_announced and px > 57.0:
		_zone_c_announced = true
		if _bomb != null:
			_bomb.arm()
			Game.set_objective("Defuse the bomb, then escape!")


func _on_actor_event() -> void:
	if not _gate_a_open and hostages_saved >= 3 and enemies_down >= 4:
		_gate_a_open = true
		_open_gate(_gate_a as MeshInstance3D, "Vault gate")
		Game.set_objective("Push to the vault - drop all 5 guards")
	elif not _gate_b_open and _gate_a_open and enemies_down >= 9:
		_gate_b_open = true
		_open_gate(_gate_b as MeshInstance3D, "Back-room gate")
		Game.set_objective("Sweep the back room")


func _on_bomb_defused(bomb: Bomb) -> void:
	super._on_bomb_defused(bomb)
	_on_actor_event()
	if _exit != null:
		_exit.unlock()
	Game.set_objective("Escape through the EXIT!")
