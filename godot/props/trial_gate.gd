class_name TrialGate
extends Area3D
## Checkpoint ring for time trials (training freerun, roofs islands).
## spawn() one gate per checkpoint sharing trial/total; run state lives
## in statics so any gate can advance or recolor the set. Level loads
## reset the run but best times persist for the session. Rings: cyan =
## start here, green = next, gold = cleared, gray = waiting.

static var _runs: Dictionary = {}
static var _best: Dictionary = {}

var trial: String = "training"
var index: int = 0
var total: int = 5

var _ring: MeshInstance3D = null
var _label: Label3D = null


static func spawn(parent: Node, pos: Vector3, yaw: float, trial_name: String,
		idx: int, count: int) -> TrialGate:
	var g := TrialGate.new()
	g.trial = trial_name
	g.index = idx
	g.total = count
	parent.add_child(g)
	g.global_position = pos
	g.rotation.y = yaw
	return g


func _ready() -> void:
	add_to_group("trial_gate")
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	_runs[trial] = {"next": 0, "start": 0}
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.0
	cs.shape = sphere
	add_child(cs)
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.2
	torus.outer_radius = 2.0
	torus.rings = 12
	torus.ring_segments = 32
	_ring.mesh = torus
	_ring.rotation.x = PI * 0.5
	add_child(_ring)
	_label = Blockout.label(self, Vector3(0, 2.8, 0),
		"START" if index == 0 else str(index + 1), Color.WHITE, 72)
	body_entered.connect(_on_gate_body)
	_refresh()


func _on_gate_body(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	var run: Dictionary = _runs.get(trial, {"next": 0, "start": 0})
	if index == 0:
		_runs[trial] = {"next": 1, "start": Time.get_ticks_msec()}
		_msg("TRIAL START - reach gate 2/%d!" % total, Color(0.4, 0.9, 1.0))
		Sfx.play("beep")
		FX.ring(get_parent(), global_position, Color(0.4, 0.9, 1.0, 0.8), 3.0, 0.4)
		_refresh_trial(trial)
		return
	var nxt: int = int(run.get("next", 0))
	if nxt == 0:
		_msg("Run starts at the START gate!", Color(1, 0.7, 0.3))
		return
	if index != nxt:
		_msg("WRONG WAY - find gate %d/%d!" % [nxt + 1, total], Color(1, 0.4, 0.3))
		return
	nxt += 1
	if nxt >= total:
		_finish(int(run.get("start", 0)))
		return
	_runs[trial] = {"next": nxt, "start": int(run.get("start", 0))}
	_msg("CHECKPOINT %d/%d!" % [index + 1, total], Color(0.4, 1, 0.5))
	Sfx.play("beep")
	FX.ring(get_parent(), global_position, Color(0.4, 1, 0.5, 0.8), 3.0, 0.4)
	_refresh_trial(trial)


func _finish(start_ms: int) -> void:
	var ms := Time.get_ticks_msec() - start_ms
	var prev: int = int(_best.get(trial, 0))
	var record := prev == 0 or ms < prev
	if record:
		_best[trial] = ms
	_runs[trial] = {"next": 0, "start": 0}
	Game.add_score(500 if record else 200)
	_msg("FINISH %s%s!" % [_fmt_time(ms), " - NEW BEST" if record else ""],
		Color(1, 0.85, 0.3) if record else Color(0.4, 1, 0.5))
	Sfx.play("win" if record else "sting")
	FX.ring(get_parent(), global_position, Color(1, 0.85, 0.3, 0.9), 5.0, 0.5)
	_refresh_trial(trial)


func _refresh() -> void:
	if _ring == null:
		return
	var run: Dictionary = _runs.get(trial, {"next": 0})
	var nxt: int = int(run.get("next", 0))
	var col := Color(0.35, 0.35, 0.4)
	if nxt == 0:
		if index == 0:
			col = Color(0.3, 0.9, 1.0)
	elif index < nxt:
		col = Color(1.0, 0.8, 0.3)
	elif index == nxt:
		col = Color(0.3, 1.0, 0.4)
	_ring.material_override = Blockout.mat_emissive(col, 1.2)
	if index == 0 and _label != null:
		if _best.has(trial):
			_label.text = "START\n%s" % _fmt_time(int(_best[trial]))
		else:
			_label.text = "START"


func _refresh_trial(trial_name: String) -> void:
	for node in get_tree().get_nodes_in_group("trial_gate"):
		var g := node as TrialGate
		if g != null and g.trial == trial_name:
			g._refresh()


static func _fmt_time(ms: int) -> String:
	var t := float(ms) / 1000.0
	var m := int(t) / 60
	var s := float(int(t) % 60) + t - float(int(t))
	return "%d:%04.1f" % [m, s]


func _msg(text: String, color: Color) -> void:
	if Game.hud != null:
		Game.hud.flash_message(text, color, 2.0)
