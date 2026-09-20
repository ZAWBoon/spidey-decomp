class_name SpiderToken
extends Area3D
## Hidden collectible: +100 score, globally numbered via Game.tokens_found.
## Code-built (no tscn): spinning gold coin + red gem, bobs in place.

var _t: float = 0.0
var _coin: Node3D = null
var _taken: bool = false


func _ready() -> void:
	add_to_group("spider_token")
	collision_layer = 8
	collision_mask = 2
	monitoring = true
	monitorable = false
	var cs := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.5
	cs.shape = shape
	add_child(cs)
	_coin = Node3D.new()
	_coin.name = "Coin"
	add_child(_coin)
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.32
	cyl.bottom_radius = 0.32
	cyl.height = 0.1
	disc.mesh = cyl
	disc.material_override = Blockout.mat_emissive(Color(1.0, 0.75, 0.2), 1.2)
	_coin.add_child(disc)
	var gem := Blockout.sphere(_coin, Vector3(0, 0.08, 0), 0.12, Color(0.8, 0.05, 0.1))
	gem.material_override = Blockout.mat_emissive(Color(1.0, 0.1, 0.15), 2.0)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta
	_coin.rotation.y = _t * 2.5
	_coin.position.y = 0.25 * sin(_t * 2.0)


func _on_body_entered(body: Node3D) -> void:
	if _taken or not body.is_in_group("player"):
		return
	_taken = true
	Game.tokens_found += 1
	Game.add_score(100)
	Sfx.play_at("pickup", global_position)
	FX.sparkle(get_tree().current_scene, global_position, Color(1.0, 0.8, 0.3))
	if Game.hud != null:
		var msg := "SPIDER TOKEN #%d +100" % Game.tokens_found
		Game.hud.flash_message(msg, Color(1, 0.8, 0.3), 2.0)
	queue_free()
