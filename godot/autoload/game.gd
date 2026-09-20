extends Node
## Autoload "Game": level flow, runtime input map, score/time, results.
##
## Input actions are registered at runtime (instead of project.godot) so the
## default bindings live in one readable place and never suffer from
## hand-written .godot serialization issues.

signal level_completed(stats: Dictionary)
signal game_over(reason: String)
signal objective_changed(text: String)

const ACTION_NAMES: Array[String] = [
	"move_forward", "move_back", "move_left", "move_right",
	"jump", "sprint", "attack", "web", "swing", "interact",
	"dodge", "yank",
	"pause", "debug",
]

const MENU_SCENE := "res://ui/main_menu.tscn"

var level: LevelBase = null
var player = null
var hud: HUD = null
var score: int = 0
var tokens_found: int = 0
var level_start_msec: int = 0
var is_active: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	_setup_input()


func _setup_input() -> void:
	for action: String in ACTION_NAMES:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_set_deadzone(action, 0.2)
	# Movement: WASD + arrows + left stick.
	_add_keys("move_forward", [KEY_W, KEY_UP])
	_add_keys("move_back", [KEY_S, KEY_DOWN])
	_add_keys("move_left", [KEY_A, KEY_LEFT])
	_add_keys("move_right", [KEY_D, KEY_RIGHT])
	_add_stick("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_add_stick("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_add_stick("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_stick("move_right", JOY_AXIS_LEFT_X, 1.0)
	# Actions.
	_add_keys("jump", [KEY_SPACE])
	_add_pad_buttons("jump", [JOY_BUTTON_A])
	_add_keys("sprint", [KEY_SHIFT])
	_add_pad_buttons("sprint", [JOY_BUTTON_LEFT_STICK])
	_add_keys("attack", [KEY_J])
	_add_mouse_buttons("attack", [MOUSE_BUTTON_LEFT])
	_add_pad_buttons("attack", [JOY_BUTTON_X])
	_add_keys("web", [KEY_K])
	_add_mouse_buttons("web", [MOUSE_BUTTON_RIGHT])
	_add_pad_buttons("web", [JOY_BUTTON_B])
	_add_keys("swing", [KEY_F])
	_add_mouse_buttons("swing", [MOUSE_BUTTON_MIDDLE])
	_add_pad_buttons("swing", [JOY_BUTTON_LEFT_SHOULDER])
	_add_keys("interact", [KEY_E])
	_add_pad_buttons("interact", [JOY_BUTTON_Y])
	_add_keys("dodge", [KEY_C])
	_add_pad_buttons("dodge", [JOY_BUTTON_RIGHT_SHOULDER])
	_add_keys("yank", [KEY_Q])
	_add_pad_buttons("yank", [JOY_BUTTON_RIGHT_STICK])
	_add_keys("pause", [KEY_ESCAPE, KEY_P])
	_add_pad_buttons("pause", [JOY_BUTTON_START])
	_add_keys("debug", [KEY_F1])


func _add_keys(action: String, codes: Array) -> void:
	for code in codes:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		InputMap.action_add_event(action, ev)


func _add_mouse_buttons(action: String, buttons: Array) -> void:
	for button in buttons:
		var ev := InputEventMouseButton.new()
		ev.button_index = button
		InputMap.action_add_event(action, ev)


func _add_pad_buttons(action: String, buttons: Array) -> void:
	for button in buttons:
		var ev := InputEventJoypadButton.new()
		ev.button_index = button
		InputMap.action_add_event(action, ev)


func _add_stick(action: String, axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)


# ---------------------------------------------------------------- levels ---
func register_level(level_base: LevelBase) -> void:
	level = level_base
	score = 0
	is_active = false


func register_player(player_node) -> void:
	player = player_node


func register_hud(hud_node: HUD) -> void:
	hud = hud_node


func level_started() -> void:
	level_start_msec = Time.get_ticks_msec()
	is_active = true


func change_level(scene_path: String) -> void:
	get_tree().paused = false
	is_active = false
	player = null
	hud = null
	level = null
	call_deferred("_do_change_level", scene_path)


func _do_change_level(scene_path: String) -> void:
	Engine.time_scale = 1.0
	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("Game: cannot load level: " + scene_path)


func restart_level() -> void:
	if level != null and level.scene_file_path != "":
		change_level(level.scene_file_path)


func to_menu() -> void:
	change_level(MENU_SCENE)


func add_score(points: int) -> void:
	score += points


func elapsed_seconds() -> float:
	if level_start_msec <= 0:
		return 0.0
	return float(Time.get_ticks_msec() - level_start_msec) / 1000.0


func complete_level() -> void:
	if not is_active or level == null:
		return
	is_active = false
	var stats := level.get_stats()
	stats["score"] = score
	stats["time_text"] = format_time(elapsed_seconds())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.play("win")
	level_completed.emit(stats)
	if hud != null:
		hud.show_result(true, stats)


func trigger_game_over(reason: String) -> void:
	if not is_active:
		return
	is_active = false
	var stats := {"score": score, "time_text": format_time(elapsed_seconds())}
	if level != null:
		stats.merge(level.get_stats(), false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.play("lose")
	game_over.emit(reason)
	if hud != null:
		hud.show_result(false, stats, reason)


func set_objective(text: String) -> void:
	objective_changed.emit(text)
	if hud != null:
		hud.set_objective(text)


static func format_time(seconds: float) -> String:
	var total := int(seconds)
	var minutes := total / 60
	var secs := total % 60
	return "%d:%02d" % [minutes, secs]
