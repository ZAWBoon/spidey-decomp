extends Node
## Headless self-test. Run on a machine with Godot installed:
##   godot --headless --path godot res://tools/test_runner.tscn
## Loads every level, drives scripted inputs, asserts behavior, prints
## PASS/FAIL and exits non-zero on failure.

const LEVELS: Array[String] = [
	"res://levels/training/training.tscn",
	"res://levels/bank/bank.tscn",
	"res://levels/docks/docks.tscn",
	"res://levels/bugle/bugle.tscn",
	"res://levels/streets/streets.tscn",
	"res://levels/roofs/roofs.tscn",
	"res://levels/theater/theater.tscn",
]
const SETTLE := 120
const WALK := 90
const CHEAT_WAIT := 40

var _checks: int = 0
var _failures: Array[String] = []
var _stage: int = 0
var _frame: int = 0
var _total: int = 0
var _level: LevelBase = null
var _level_i: int = 0
var _start_pos: Vector3 = Vector3.ZERO
var _completed: bool = false
var _done: bool = false


func _ready() -> void:
	print("[TEST] self-test starting (%d levels)" % LEVELS.size())
	Game.level_completed.connect(_on_level_completed)
	_load_level(0)


func _on_level_completed(_stats: Dictionary) -> void:
	_completed = true


func _physics_process(_delta: float) -> void:
	if _done or _level == null:
		return
	_frame += 1
	_total += 1
	if _total > 6000:
		_failures.append("global timeout")
		_finish()
		return
	match _stage:
		0:
			_tick_settle()
		1:
			_tick_walk()
		2:
			_tick_cheats()
		3:
			_tick_completion()


func _tick_settle() -> void:
	if _frame < SETTLE:
		return
	_check(_level.player != null, _tag("player spawned"))
	_check(_level.hud != null, _tag("hud spawned"))
	if _level.player != null:
		_check(_level.player.is_on_floor(), _tag("player rests on floor"))
		_start_pos = _level.player.global_position
		Input.action_press("move_forward")
	_stage = 1
	_frame = 0


func _tick_walk() -> void:
	if _frame == 30:
		Input.action_press("jump")
	if _frame == 33:
		Input.action_release("jump")
	if _frame < WALK:
		return
	Input.action_release("move_forward")
	Input.action_release("jump")
	var moved := _start_pos.distance_to(_level.player.global_position)
	_check(moved > 1.0, _tag("player walked %.1fm" % moved))
	_combat_checks()
	_stage = 2
	_frame = 0


func _combat_checks() -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	_check(enemies.size() > 0, _tag("enemies present (%d)" % enemies.size()))
	if _level.level_id == "bugle":
		var lurker := _get_venom()
		_check(lurker != null, _tag("venom lurks"))
		if lurker != null:
			_check(lurker.state == Venom.State.DORMANT, _tag("venom dormant before F2"))
	if _level.level_id == "streets":
		var rhino: Rhino = null
		for node in get_tree().get_nodes_in_group("rhino"):
			rhino = node as Rhino
		_check(rhino != null, _tag("rhino lurks"))
		if rhino != null:
			_check(rhino.state == Rhino.State.DORMANT, _tag("rhino dormant before arena"))
		var cars := get_tree().get_nodes_in_group("cars").size()
		_check(cars == 6, _tag("6 parked cars (%d)" % cars))
	if _level.level_id == "roofs":
		var boss: Scorpion = null
		for node in get_tree().get_nodes_in_group("scorpion"):
			boss = node as Scorpion
		_check(boss != null, _tag("scorpion lurks"))
		if boss != null:
			_check(boss.state == Scorpion.State.DORMANT, _tag("scorpion dormant before arena"))
	if _level.level_id == "theater":
		var myst: Mysterio = null
		for node in get_tree().get_nodes_in_group("mysterio"):
			myst = node as Mysterio
		_check(myst != null, _tag("mysterio lurks"))
		if myst != null:
			_check(myst.state == Mysterio.State.DORMANT, _tag("mysterio dormant before show"))
			_check(myst.pedestals.size() == 5, _tag("5 pedestals (%d)" % myst.pedestals.size()))
	var thug: Thug = null
	for node in enemies:
		if node is Thug:
			thug = node
			break
	_check(thug != null, _tag("a Thug exists"))
	if thug == null:
		return
	var hp0: float = thug.health.hp
	thug.take_hit(5.0, null)
	_check(thug.health.hp < hp0, _tag("thug hp dropped after punch"))
	thug.apply_web(3.0)
	_check(thug.state == Thug.State.STUNNED, _tag("thug stunned by web"))
	var barrels := 0
	for node in enemies:
		if node is Barrel:
			barrels += 1
	if _level.level_id == "docks":
		_check(barrels == 4, _tag("4 explosive barrels (%d)" % barrels))
	_level.player.debug_fire_web()
	await get_tree().physics_frame
	var shots := get_tree().get_nodes_in_group("fx").size()
	_check(shots > 0, _tag("webshot spawned (%d)" % shots))


func _tick_cheats() -> void:
	if _frame == 1:
		_level.debug_defeat_all_enemies()
		_level.debug_rescue_all_hostages()
		_level.debug_defuse_bombs()
	if _level.level_id == "bugle":
		_tick_bugle_cheats()
		return
	if _frame < CHEAT_WAIT:
		return
	if _level.level_id == "training":
		_next_level_or_finish()
		return
	_check(_level.enemies_down == _level.enemies_total,
		_tag("all enemies down %d/%d" % [_level.enemies_down, _level.enemies_total]))
	_check(_level.hostages_saved == _level.hostages_total,
		_tag("all hostages saved %d/%d" % [_level.hostages_saved, _level.hostages_total]))
	var exits := get_tree().get_nodes_in_group("exit_gate")
	if exits.size() > 0:
		var gate := exits[0] as Node3D
		_teleport_player(gate.global_position + Vector3(0, 0.5, 0))
	_stage = 3
	_frame = 0


## Bugle: Venom can't die, so the cheat flow is teleport-driven:
## F2 -> Venom hunts -> roof -> exit unlocks -> gate -> complete.
func _tick_bugle_cheats() -> void:
	match _frame:
		10:
			_teleport_player(Vector3(0, 5.5, 5))
		20:
			var venom := _get_venom()
			_check(venom != null, _tag("venom present"))
			if venom != null:
				_check(venom.state != Venom.State.DORMANT,
					_tag("venom hunts (state %d)" % venom.state))
		30:
			_teleport_player(Vector3(0, 15.5, 0))
		45:
			var exits := get_tree().get_nodes_in_group("exit_gate")
			_check(exits.size() > 0, _tag("exit gate present"))
			if exits.size() > 0:
				_check(not bool(exits[0].get("locked")), _tag("roof exit unlocked"))
				_teleport_player((exits[0] as Node3D).global_position + Vector3(0, 0.5, 0))
		50:
			var thugs := 0
			var down := 0
			for node in get_tree().get_nodes_in_group("enemies"):
				if node is Thug:
					thugs += 1
					if (node as Thug).health.is_dead():
						down += 1
			_check(thugs == 6, _tag("6 thugs (%d)" % thugs))
			_check(down == thugs and thugs > 0,
				_tag("all thugs down %d/%d" % [down, thugs]))
			_check(_level.hostages_saved == _level.hostages_total,
				_tag("all hostages saved %d/%d" % [_level.hostages_saved, _level.hostages_total]))
	if _frame < 60:
		return
	_stage = 3
	_frame = 0


func _tick_completion() -> void:
	if _frame < CHEAT_WAIT:
		return
	_check(_completed, _tag("level_completed fired"))
	_next_level_or_finish()


func _next_level_or_finish() -> void:
	if _level != null:
		_level.get_parent().remove_child(_level)
		_level.queue_free()
		_level = null
	_level_i += 1
	if _level_i >= LEVELS.size():
		_finish()
		return
	_completed = false
	_load_level(_level_i)
	_stage = 0
	_frame = 0


func _load_level(index: int) -> void:
	print("[TEST] loading %s" % LEVELS[index])
	var packed := load(LEVELS[index]) as PackedScene
	_level = packed.instantiate() as LevelBase
	get_tree().root.add_child(_level)
	get_tree().current_scene = _level


func _teleport_player(pos: Vector3) -> void:
	_level.player.global_position = pos
	_level.player.velocity = Vector3.ZERO


func _get_venom() -> Venom:
	for node in get_tree().get_nodes_in_group("venom"):
		return node as Venom
	return null


func _tag(name: String) -> String:
	return "[%s] %s" % [_level.level_id, name]


func _check(ok: bool, name: String) -> void:
	_checks += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", name])
	if not ok:
		_failures.append(name)


func _finish() -> void:
	if _done:
		return
	_done = true
	print("[TEST] %d checks, %d failures" % [_checks, _failures.size()])
	for failure in _failures:
		print("[TEST] FAILED: " + failure)
	get_tree().quit(1 if _failures.size() > 0 else 0)
