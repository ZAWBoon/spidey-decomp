class_name HUD
extends CanvasLayer
## In-game UI: bars, objectives, counters, prompts, messages, pause, results.

var _player = null
var _msg_tween: Tween = null
var _dmg_tween: Tween = null
var _result_shown: bool = false

@onready var hp_bar: ProgressBar = $Root/TopLeft/HPBar
@onready var web_bar: ProgressBar = $Root/TopLeft/WebBar
@onready var objective_label: Label = $Root/ObjectivePanel/ObjectiveLabel
@onready var counters_label: Label = $Root/CountersLabel
@onready var timer_label: Label = $Root/TimerLabel
@onready var prompt_panel: PanelContainer = $Root/PromptPanel
@onready var prompt_label: Label = $Root/PromptPanel/PromptVBox/PromptLabel
@onready var interact_bar: ProgressBar = $Root/PromptPanel/PromptVBox/InteractBar
@onready var message_label: Label = $Root/MessageLabel
@onready var damage_rect: ColorRect = $Root/DamageRect
@onready var debug_panel: PanelContainer = $Root/DebugPanel
@onready var debug_label: Label = $Root/DebugPanel/DebugLabel
@onready var pause_dim: ColorRect = $Root/PauseDim
@onready var pause_panel: CenterContainer = $Root/PausePanel
@onready var result_dim: ColorRect = $Root/ResultDim
@onready var result_panel: CenterContainer = $Root/ResultPanel
@onready var result_title: Label = $Root/ResultPanel/ResultBox/ResultTitle
@onready var result_stats: Label = $Root/ResultPanel/ResultBox/ResultStats
@onready var result_primary: Button = $Root/ResultPanel/ResultBox/ResultBtns/BtnPrimary
@onready var boss_panel: PanelContainer = $Root/BossPanel
@onready var boss_name: Label = $Root/BossPanel/BossVBox/BossName
@onready var boss_bar: ProgressBar = $Root/BossPanel/BossVBox/BossBar


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	prompt_panel.visible = false
	timer_label.visible = false
	debug_panel.visible = false
	pause_dim.visible = false
	pause_panel.visible = false
	result_dim.visible = false
	result_panel.visible = false
	boss_panel.visible = false
	message_label.modulate.a = 0.0
	damage_rect.modulate.a = 0.0
	($Root/PausePanel/PauseBox/BtnResume as Button).pressed.connect(_on_resume)
	($Root/PausePanel/PauseBox/BtnRestart as Button).pressed.connect(_on_restart)
	($Root/PausePanel/PauseBox/BtnMenu as Button).pressed.connect(_on_menu)
	result_primary.pressed.connect(_on_result_primary)
	($Root/ResultPanel/ResultBox/ResultBtns/BtnMenu as Button).pressed.connect(_on_menu)
	Game.objective_changed.connect(set_objective)


func bind(player_node) -> void:
	_player = player_node
	_player.health.changed.connect(_on_hp_changed)
	_player.fluid_changed.connect(_on_fluid_changed)
	_on_hp_changed(_player.health.hp, _player.health.max_hp)
	_on_fluid_changed(_player.web_fluid, Player.WEB_MAX)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug"):
		debug_panel.visible = not debug_panel.visible
	elif event.is_action_pressed("pause"):
		if not _result_shown:
			toggle_pause()


func _process(_delta: float) -> void:
	if debug_panel.visible and _player != null:
		var enemies := get_tree().get_nodes_in_group("enemies").size()
		var pos_text := str(_player.global_position.snapped(Vector3.ONE * 0.1))
		var swing_text := str(_player.is_swinging())
		var fmt := "FPS: %d | Pos: %s | Speed: %.1f"
		fmt += " | Swing: %s | HP: %d | Web: %d | Actors: %d"
		debug_label.text = fmt % [
			int(Engine.get_frames_per_second()),
			pos_text,
			_player.get_horizontal_speed(),
			swing_text,
			int(_player.health.hp),
			int(_player.web_fluid),
			enemies,
		]


# ------------------------------------------------------------------ widgets --
func set_objective(text: String) -> void:
	objective_label.text = text


func set_counters(saved: int, hostages_total: int, down: int, enemies_total: int) -> void:
	var parts: Array[String] = []
	if hostages_total > 0:
		parts.append("Hostages %d/%d" % [saved, hostages_total])
	if enemies_total > 0:
		parts.append("Down %d/%d" % [down, enemies_total])
	counters_label.text = "    ".join(parts)


func flash_message(text: String, color: Color = Color.WHITE, duration: float = 2.0) -> void:
	if _msg_tween != null and _msg_tween.is_valid():
		_msg_tween.kill()
	message_label.text = text
	message_label.modulate = color
	message_label.modulate.a = 1.0
	_msg_tween = create_tween()
	_msg_tween.tween_interval(duration)
	_msg_tween.tween_property(message_label, "modulate:a", 0.0, 0.4)


func show_prompt(text: String) -> void:
	prompt_panel.visible = true
	prompt_label.text = "[E] " + text


func update_hold(ratio: float) -> void:
	interact_bar.value = ratio * 100.0


func hide_prompt() -> void:
	prompt_panel.visible = false
	interact_bar.value = 0.0


func damage_flash() -> void:
	if _dmg_tween != null and _dmg_tween.is_valid():
		_dmg_tween.kill()
	damage_rect.modulate.a = 0.45
	_dmg_tween = create_tween()
	_dmg_tween.tween_property(damage_rect, "modulate:a", 0.0, 0.35)


func show_bomb_timer(seconds: float) -> void:
	timer_label.visible = true
	timer_label.text = "%d" % int(maxf(0.0, ceil(seconds)))


func hide_bomb_timer() -> void:
	timer_label.visible = false


func show_boss(boss_display_name: String, hp: float, max_hp: float) -> void:
	boss_name.text = boss_display_name
	boss_bar.max_value = max_hp
	boss_bar.value = hp
	boss_panel.visible = true


func set_boss_hp(hp: float, max_hp: float) -> void:
	boss_bar.max_value = max_hp
	boss_bar.value = hp


func hide_boss() -> void:
	boss_panel.visible = false


func _on_hp_changed(hp: float, max_hp: float) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = hp


func _on_fluid_changed(value: float, maximum: float) -> void:
	web_bar.max_value = maximum
	web_bar.value = value


# ---------------------------------------------------------------- pause/end --
func toggle_pause() -> void:
	if _result_shown:
		return
	var paused := not get_tree().paused
	get_tree().paused = paused
	pause_dim.visible = paused
	pause_panel.visible = paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
	Sfx.play("click")


func show_result(won: bool, stats: Dictionary, reason: String = "") -> void:
	_result_shown = true
	get_tree().paused = true
	hide_prompt()
	hide_bomb_timer()
	hide_boss()
	if won:
		result_title.text = "LEVEL COMPLETE!"
		result_title.add_theme_color_override("font_color", Color(0.4, 1, 0.5))
		var next := ""
		if Game.level != null:
			next = Game.level.next_level_path
		result_primary.text = "NEXT LEVEL" if next != "" else "REPLAY"
	else:
		result_title.text = "GAME OVER"
		result_title.add_theme_color_override("font_color", Color(1, 0.35, 0.3))
		result_primary.text = "RETRY"
	var lines: Array[String] = []
	if reason != "":
		lines.append(reason)
	lines.append("Time: %s" % str(stats.get("time_text", "-")))
	lines.append("Score: %d" % int(stats.get("score", 0)))
	if stats.has("hostages"):
		lines.append("Hostages: %s" % str(stats["hostages"]))
	if stats.has("enemies"):
		lines.append("Enemies down: %s" % str(stats["enemies"]))
	result_stats.text = " / ".join(lines)
	result_dim.visible = true
	result_panel.visible = true


func _on_resume() -> void:
	toggle_pause()


func _on_restart() -> void:
	Sfx.play("click")
	Game.restart_level()


func _on_menu() -> void:
	Sfx.play("click")
	Game.to_menu()


func _on_result_primary() -> void:
	Sfx.play("click")
	if _result_shown and result_primary.text == "NEXT LEVEL" and Game.level != null:
		Game.change_level(Game.level.next_level_path)
	else:
		Game.restart_level()
