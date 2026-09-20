class_name TrainingLevel
extends LevelBase
## Level 0: outdoor training yard. Teaches move/jump/punch/web/swing,
## then a ring run and an exit gate. South annex: freerun pad with
## crates, a pole and a token. 3 spider-tokens hidden around.

const THUG_SCENE: PackedScene = preload("res://enemies/thug.tscn")
const PICKUP_SCENE: PackedScene = preload("res://pickups/web_pickup.tscn")
const EXIT_SCENE: PackedScene = preload("res://props/exit_gate.tscn")

var _step: int = 0
var _start_pos: Vector3 = Vector3.ZERO
var _punches: int = 0
var _rings_done: int = 0
var _ring_flags: Dictionary = {}
var _exit: ExitGate = null
var _jump_seen: bool = false


func _build() -> void:
	SkyDeco.day(self)
	level_id = "training"
	level_name = "Training Yard"
	next_level_path = "res://levels/bank/bank.tscn"
	_build_ground()
	_build_dummies()
	_build_swing_lane()
	_build_side_pad()
	_build_tokens()
	_build_exit()
	Blockout.label(self, Vector3(0, 6, 14), "TRAINING YARD", Color(1, 0.9, 0.4), 96)
	Game.set_objective("Move: WASD / left stick")


func _build_ground() -> void:
	var grass := Color(0.25, 0.42, 0.25)
	# Main floor (z from -40 to +60) and far floor (z from -100 to -48).
	Blockout.box(self, Vector3(0, -0.5, 10), Vector3(120, 1, 100), grass)
	Blockout.box(self, Vector3(0, -0.5, -74), Vector3(120, 1, 52), grass)
	# Pit visual under the 8m gap.
	Blockout.box(self, Vector3(0, -8, -44), Vector3(120, 1, 8), Color(0.02, 0.02, 0.04), false)
	# Dirt patches (thin, coplanar-safe).
	var dirt := Color(0.45, 0.35, 0.22)
	Blockout.box(self, Vector3(-20, 0.02, 20), Vector3(18, 0.04, 14), dirt, false)
	Blockout.box(self, Vector3(25, 0.02, -10), Vector3(22, 0.04, 16), dirt, false)
	# Boundary fences (south fence has a 8m gap to the side pad).
	var fence := Color(0.5, 0.5, 0.55)
	Blockout.box(self, Vector3(-32, 1.5, 60), Vector3(56, 3, 1), fence)
	Blockout.box(self, Vector3(32, 1.5, 60), Vector3(56, 3, 1), fence)
	Blockout.box(self, Vector3(0, 1.5, -100), Vector3(120, 3, 1), fence)
	Blockout.box(self, Vector3(-60, 1.5, -20), Vector3(1, 3, 160), fence)
	Blockout.box(self, Vector3(60, 1.5, -20), Vector3(1, 3, 160), fence)


func _build_dummies() -> void:
	for pos in [Vector3(-4, 0, 0), Vector3(0, 0, -2), Vector3(4, 0, 0)]:
		var dummy := THUG_SCENE.instantiate() as Thug
		dummy.passive = true
		dummy.max_hp = 99999.0
		add_child(dummy)
		dummy.global_position = pos
		dummy.health.damaged.connect(_on_dummy_damaged)
		dummy.webbed.connect(_on_dummy_webbed)
	Blockout.label(self, Vector3(0, 4, 0), "PUNCH + WEB DUMMIES", Color.WHITE, 64)
	for pos in [Vector3(-6, 0, 6), Vector3(6, 0, 6)]:
		var pickup := PICKUP_SCENE.instantiate() as WebPickup
		add_child(pickup)
		pickup.global_position = pos


func _build_swing_lane() -> void:
	Blockout.label(self, Vector3(0, 9, -26), "SWING LANE - hold F near a pole", Color(0.6, 0.9, 1), 64)
	var pole_spots := [Vector3(-6, 0, -8), Vector3(6, 0, -20),
		Vector3(-6, 0, -32), Vector3(6, 0, -44)]
	for spot in pole_spots:
		Blockout.cylinder(self, spot + Vector3(0, 5.5, 0), 0.3, 11.0, Color(0.45, 0.45, 0.5))
		var anchor := SwingAnchor.new()
		add_child(anchor)
		anchor.global_position = spot + Vector3(0, 11.0, 0)
	var ring_spots := [Vector3(0, 6, -14), Vector3(0, 6, -26), Vector3(0, 6, -38)]
	var ring_i := 0
	for spot in ring_spots:
		_make_ring(spot, ring_i)
		ring_i += 1


func _make_ring(spot: Vector3, ring_i: int) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.18
	torus.outer_radius = 1.7
	torus.rings = 12
	torus.ring_segments = 32
	ring.mesh = torus
	ring.material_override = Blockout.mat_emissive(Color(0.3, 0.9, 1.0), 1.2)
	add_child(ring)
	ring.global_position = spot
	var area := Area3D.new()
	area.collision_layer = 8
	area.collision_mask = 2
	var cs := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.5
	cs.shape = shape
	area.add_child(cs)
	add_child(area)
	area.global_position = spot
	_ring_flags[ring_i] = false
	area.body_entered.connect(_on_ring_body.bind(ring_i, ring))


func _on_ring_body(body: Node3D, ring_i: int, ring: MeshInstance3D) -> void:
	if not body.is_in_group("player"):
		return
	if bool(_ring_flags.get(ring_i, true)):
		return
	_ring_flags[ring_i] = true
	_rings_done += 1
	ring.material_override = Blockout.mat_emissive(Color(0.3, 1.0, 0.4), 1.5)
	Sfx.play("pickup")
	_refresh_objective()


func _build_side_pad() -> void:
	# South freerun annex (z 60..90) behind the fence gap.
	Blockout.box(self, Vector3(0, -0.5, 75), Vector3(60, 1, 30), Color(0.3, 0.36, 0.3))
	var fence := Color(0.5, 0.5, 0.55)
	Blockout.box(self, Vector3(0, 1.5, 90), Vector3(60, 3, 1), fence)
	Blockout.box(self, Vector3(-30, 1.5, 75), Vector3(1, 3, 30), fence)
	Blockout.box(self, Vector3(30, 1.5, 75), Vector3(1, 3, 30), fence)
	var crate := Color(0.5, 0.38, 0.22)
	for pos in [Vector3(-12, 0, 70), Vector3(-8, 0, 72), Vector3(8, 0, 78), Vector3(12, 0, 74)]:
		Blockout.box(self, pos + Vector3(0, 0.6, 0), Vector3(1.2, 1.2, 1.2), crate)
	Blockout.cylinder(self, Vector3(0, 5.5, 82), 0.3, 11.0, Color(0.45, 0.45, 0.5))
	var anchor := SwingAnchor.new()
	add_child(anchor)
	anchor.global_position = Vector3(0, 11.0, 82)
	Blockout.label(self, Vector3(0, 4, 75), "FREERUN PAD", Color(0.6, 0.9, 1), 64)


func _build_tokens() -> void:
	_spawn_token(Vector3(6, 1.2, 12))
	_spawn_token(Vector3(0, 6.0, -26))
	_spawn_token(Vector3(3, 1.2, -88))


func _spawn_token(pos: Vector3) -> void:
	var token := SpiderToken.new()
	add_child(token)
	token.global_position = pos


func _build_exit() -> void:
	_exit = EXIT_SCENE.instantiate() as ExitGate
	add_child(_exit)
	_exit.global_position = Vector3(0, 0, -92)


func _process(delta: float) -> void:
	super._process(delta)
	if not active or player == null or player.health.is_dead():
		return
	if _step == 0:
		if _start_pos == Vector3.ZERO:
			_start_pos = player.global_position
		elif player.global_position.distance_to(_start_pos) > 3.0:
			_advance("Jump: SPACE")
	elif _step == 1:
		if not _jump_seen and not player.is_on_floor() and player.velocity.y > 2.0:
			_jump_seen = true
		elif _jump_seen and player.is_on_floor():
			_advance("Punch a dummy 3x: Left Click (0/3)")
	elif _step == 4:
		if player.is_swinging():
			_advance("Swing through 3 rings (%d/3)" % _rings_done)
	elif _step == 5:
		_refresh_objective()
		if _rings_done >= 3:
			_exit.unlock()
			_advance("Reach the EXIT gate!")


func _on_dummy_damaged(_amount: float, _from: Node) -> void:
	if _step != 2:
		return
	_punches += 1
	if _punches >= 3:
		_advance("Web a dummy: Right Click")
	else:
		_refresh_objective()


func _on_dummy_webbed(_thug: Thug) -> void:
	if _step == 3:
		_advance("Swing: HOLD F near a pole")


func _advance(text: String) -> void:
	_step += 1
	Sfx.play("click")
	Game.set_objective(text)


func _refresh_objective() -> void:
	match _step:
		2:
			Game.set_objective("Punch a dummy 3x: Left Click (%d/3)" % mini(_punches, 3))
		5:
			Game.set_objective("Swing through 3 rings (%d/3)" % mini(_rings_done, 3))


func _on_actor_event() -> void:
	pass
