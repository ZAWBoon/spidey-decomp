class_name LevelBase
extends Node3D
## Base class for every level: builds the world, spawns player+HUD,
## tracks hostages/enemies, exposes debug hooks for the self-test.

const PLAYER_SCENE: PackedScene = preload("res://player/player.tscn")
const HUD_SCENE: PackedScene = preload("res://ui/hud.tscn")

@export var level_id: String = "level"
@export var level_name: String = "Level"
@export var next_level_path: String = ""

var player: Player = null
var hud: HUD = null
var spawn_point: Marker3D = null
var elapsed: float = 0.0
var active: bool = false
var hostages_total: int = 0
var hostages_saved: int = 0
var enemies_total: int = 0
var enemies_down: int = 0


func _ready() -> void:
	Game.register_level(self)
	_build()
	_spawn_player()
	_spawn_hud()
	_connect_actors()
	active = true
	Game.level_started()
	_update_counters()


func _process(delta: float) -> void:
	if active and not get_tree().paused:
		elapsed += delta


## Override: construct geometry + actors.
func _build() -> void:
	pass


## Override: react to kills/rescues/defuses (gates, objective text...).
func _on_actor_event() -> void:
	pass


func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate() as Player
	add_child(player)
	spawn_point = get_node_or_null("SpawnPoint") as Marker3D
	if spawn_point != null:
		player.global_position = spawn_point.global_position
		player.cam_rig.yaw.rotation.y = spawn_point.rotation.y
	Game.register_player(player)


func respawn_player() -> void:
	if player == null:
		return
	if spawn_point != null:
		player.global_position = spawn_point.global_position + Vector3(0, 0.5, 0)
	else:
		player.global_position = Vector3(0, 2, 0)
	player.velocity = Vector3.ZERO


func _spawn_hud() -> void:
	hud = HUD_SCENE.instantiate() as HUD
	add_child(hud)
	hud.bind(player)
	Game.register_hud(hud)


func _connect_actors() -> void:
	for node in get_tree().get_nodes_in_group("hostages"):
		var hostage := node as Hostage
		if hostage != null and hostage.is_inside_tree():
			hostages_total += 1
			if not hostage.rescued.is_connected(_on_hostage_saved):
				hostage.rescued.connect(_on_hostage_saved)
	for node in get_tree().get_nodes_in_group("enemies"):
		var thug := node as Thug
		if thug != null and thug.is_inside_tree():
			enemies_total += 1
			if not thug.downed.is_connected(_on_enemy_downed):
				thug.downed.connect(_on_enemy_downed)
	for node in get_tree().get_nodes_in_group("bomb"):
		var bomb := node as Bomb
		if bomb != null and bomb.is_inside_tree():
			if not bomb.defused.is_connected(_on_bomb_defused):
				bomb.defused.connect(_on_bomb_defused)
			if not bomb.exploded.is_connected(_on_bomb_exploded):
				bomb.exploded.connect(_on_bomb_exploded)


func _on_hostage_saved(_hostage: Hostage) -> void:
	hostages_saved += 1
	Game.add_score(200)
	if hud != null:
		hud.flash_message("Hostage saved! +200", Color(0.4, 1, 0.5))
	_update_counters()
	_on_actor_event()


func _on_enemy_downed(_thug: Thug) -> void:
	enemies_down += 1
	Game.add_score(100)
	_update_counters()
	_on_actor_event()


func _on_bomb_defused(_bomb: Bomb) -> void:
	Game.add_score(300)
	_on_actor_event()


func _on_bomb_exploded(_bomb: Bomb) -> void:
	pass


func _update_counters() -> void:
	if hud != null:
		hud.set_counters(hostages_saved, hostages_total, enemies_down, enemies_total)


func get_stats() -> Dictionary:
	var stats := {"score": Game.score, "time": elapsed}
	if hostages_total > 0:
		stats["hostages"] = "%d/%d" % [hostages_saved, hostages_total]
	if enemies_total > 0:
		stats["enemies"] = "%d/%d" % [enemies_down, enemies_total]
	return stats


# ------------------------------------------------------- debug/test hooks ---
func debug_defeat_all_enemies() -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		var thug := node as Thug
		if thug != null:
			thug.take_hit(99999.0, null)
		else:
			var other: Variant = node
			if other.has_method("take_hit"):
				other.take_hit(99999.0, null)


func debug_rescue_all_hostages() -> void:
	for node in get_tree().get_nodes_in_group("hostages"):
		var hostage := node as Hostage
		if hostage != null:
			hostage.rescue_now()


func debug_defuse_bombs() -> void:
	for node in get_tree().get_nodes_in_group("bomb"):
		var bomb := node as Bomb
		if bomb != null:
			bomb.debug_defuse()
