extends Node
## Autoload "Sfx": procedural sound effects (no audio assets needed).
##
## All effects are synthesized at startup into AudioStreamWAV buffers:
## sine sweeps + filtered noise bursts. Placeholder until real assets land.

const RATE := 22050
const POOL_SIZE := 12

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_i := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_all()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)


func has_sound(sound_name: String) -> bool:
	return _streams.has(sound_name)


func play(sound_name: String, volume_db: float = 0.0) -> void:
	if not _streams.has(sound_name):
		return
	var p := _pool[_pool_i]
	_pool_i = (_pool_i + 1) % POOL_SIZE
	p.stream = _streams[sound_name]
	p.volume_db = volume_db
	p.play()


func play_at(sound_name: String, pos: Vector3, volume_db: float = 0.0) -> void:
	if not _streams.has(sound_name):
		return
	var scene := get_tree().current_scene
	if scene == null:
		play(sound_name, volume_db)
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = _streams[sound_name]
	p.volume_db = volume_db
	p.max_distance = 45.0
	p.finished.connect(p.queue_free)
	scene.add_child(p)
	p.global_position = pos
	p.play()


# ---------------------------------------------------------------- synth ---
func _build_all() -> void:
	_streams["punch"] = _render([
		{"k": "n", "at": 0.0, "dur": 0.12, "vol": 0.9, "lp0": 0.5, "lp1": 0.05},
		{"k": "t", "at": 0.0, "dur": 0.12, "f0": 160.0, "f1": 60.0, "vol": 0.6},
	], 0.14)
	_streams["swing_whoosh"] = _render([
		{"k": "n", "at": 0.0, "dur": 0.22, "vol": 0.45, "lp0": 0.05, "lp1": 0.6},
	], 0.24)
	_streams["thwip"] = _render([
		{"k": "t", "at": 0.0, "dur": 0.09, "f0": 900.0, "f1": 300.0, "vol": 0.7},
		{"k": "n", "at": 0.0, "dur": 0.05, "vol": 0.35, "lp0": 0.8, "lp1": 0.3},
	], 0.11)
	_streams["hit"] = _render([
		{"k": "t", "at": 0.0, "dur": 0.10, "f0": 320.0, "f1": 120.0, "vol": 0.7},
		{"k": "n", "at": 0.0, "dur": 0.08, "vol": 0.5, "lp0": 0.6, "lp1": 0.1},
	], 0.12)
	_streams["hurt"] = _render([
		{"k": "t", "at": 0.0, "dur": 0.25, "f0": 420.0, "f1": 140.0, "vol": 0.75},
		{"k": "n", "at": 0.0, "dur": 0.20, "vol": 0.4, "lp0": 0.5, "lp1": 0.1},
	], 0.27)
	_streams["pickup"] = _render([
		{"k": "t", "at": 0.0, "dur": 0.08, "f0": 660.0, "f1": 660.0, "vol": 0.6},
		{"k": "t", "at": 0.08, "dur": 0.12, "f0": 880.0, "f1": 880.0, "vol": 0.6},
	], 0.22)
	_streams["rescue"] = _render([
		{"k": "t", "at": 0.0, "dur": 0.10, "f0": 523.0, "f1": 523.0, "vol": 0.6},
		{"k": "t", "at": 0.10, "dur": 0.10, "f0": 659.0, "f1": 659.0, "vol": 0.6},
		{"k": "t", "at": 0.20, "dur": 0.16, "f0": 784.0, "f1": 784.0, "vol": 0.6},
	], 0.38)
	_streams["beep"] = _render([
		{"k": "t", "at": 0.0, "dur": 0.07, "f0": 1200.0, "f1": 1200.0, "vol": 0.5},
	], 0.09)
	_streams["explosion"] = _render([
		{"k": "n", "at": 0.0, "dur": 0.90, "vol": 1.0, "lp0": 0.7, "lp1": 0.02},
		{"k": "t", "at": 0.0, "dur": 0.70, "f0": 120.0, "f1": 30.0, "vol": 0.8},
	], 0.95)
	_streams["click"] = _render([
		{"k": "t", "at": 0.0, "dur": 0.04, "f0": 1200.0, "f1": 900.0, "vol": 0.35},
	], 0.06)
	_streams["win"] = _render([
		{"k": "t", "at": 0.0, "dur": 0.10, "f0": 523.0, "f1": 523.0, "vol": 0.6},
		{"k": "t", "at": 0.09, "dur": 0.10, "f0": 659.0, "f1": 659.0, "vol": 0.6},
		{"k": "t", "at": 0.18, "dur": 0.10, "f0": 784.0, "f1": 784.0, "vol": 0.6},
		{"k": "t", "at": 0.27, "dur": 0.20, "f0": 1046.0, "f1": 1046.0, "vol": 0.6},
	], 0.50)
	_streams["lose"] = _render([
		{"k": "t", "at": 0.0, "dur": 0.20, "f0": 392.0, "f1": 392.0, "vol": 0.6},
		{"k": "t", "at": 0.15, "dur": 0.20, "f0": 311.0, "f1": 311.0, "vol": 0.6},
		{"k": "t", "at": 0.30, "dur": 0.30, "f0": 262.0, "f1": 262.0, "vol": 0.6},
	], 0.62)
	_streams["thug_down"] = _render([
		{"k": "t", "at": 0.0, "dur": 0.20, "f0": 220.0, "f1": 70.0, "vol": 0.7},
		{"k": "n", "at": 0.05, "dur": 0.15, "vol": 0.5, "lp0": 0.4, "lp1": 0.05},
	], 0.24)
	_streams["gunshot"] = _render([
		{"k": "n", "at": 0.0, "dur": 0.14, "vol": 1.0, "lp0": 0.9, "lp1": 0.1},
		{"k": "t", "at": 0.0, "dur": 0.10, "f0": 200.0, "f1": 50.0, "vol": 0.6},
	], 0.16)
	_streams["jump"] = _render([
		{"k": "t", "at": 0.0, "dur": 0.09, "f0": 300.0, "f1": 600.0, "vol": 0.3},
	], 0.11)
	_streams["empty"] = _render([
		{"k": "t", "at": 0.0, "dur": 0.05, "f0": 200.0, "f1": 150.0, "vol": 0.4},
	], 0.07)
	_streams["roar"] = _render([
		{"k": "t", "at": 0.0, "dur": 1.0, "f0": 90.0, "f1": 45.0, "vol": 0.9},
		{"k": "t", "at": 0.0, "dur": 1.0, "f0": 135.0, "f1": 60.0, "vol": 0.6},
		{"k": "n", "at": 0.1, "dur": 0.8, "vol": 0.7, "lp0": 0.5, "lp1": 0.1},
	], 1.05)
	_streams["crash"] = _render([
		{"k": "n", "at": 0.0, "dur": 0.4, "vol": 1.0, "lp0": 0.8, "lp1": 0.1},
		{"k": "t", "at": 0.0, "dur": 0.3, "f0": 150.0, "f1": 40.0, "vol": 0.7},
		{"k": "n", "at": 0.25, "dur": 0.3, "vol": 0.5, "lp0": 0.6, "lp1": 0.2},
	], 0.6)
	_streams["sting"] = _render([
		{"k": "t", "at": 0.0, "dur": 0.12, "f0": 1600.0, "f1": 250.0, "vol": 0.6},
		{"k": "n", "at": 0.0, "dur": 0.06, "vol": 0.3, "lp0": 0.9, "lp1": 0.5},
	], 0.14)
	_streams["poof"] = _render([
		{"k": "n", "at": 0.0, "dur": 0.3, "vol": 0.6, "lp0": 0.3, "lp1": 0.7},
		{"k": "t", "at": 0.0, "dur": 0.2, "f0": 400.0, "f1": 900.0, "vol": 0.25},
	], 0.32)
	_streams["bark_alert"] = _render([
		{"k": "t", "at": 0.0, "dur": 0.08, "f0": 300.0, "f1": 620.0, "vol": 0.7},
		{"k": "t", "at": 0.10, "dur": 0.10, "f0": 350.0, "f1": 700.0, "vol": 0.7},
	], 0.24)
	_streams["bark_hurt"] = _render([
		{"k": "t", "at": 0.0, "dur": 0.18, "f0": 520.0, "f1": 180.0, "vol": 0.75},
		{"k": "t", "at": 0.0, "dur": 0.18, "f0": 260.0, "f1": 90.0, "vol": 0.5},
		{"k": "n", "at": 0.0, "dur": 0.15, "vol": 0.4, "lp0": 0.5, "lp1": 0.1},
	], 0.22)
	_streams["bark_attack"] = _render([
		{"k": "t", "at": 0.0, "dur": 0.12, "f0": 240.0, "f1": 130.0, "vol": 0.7},
		{"k": "n", "at": 0.0, "dur": 0.10, "vol": 0.45, "lp0": 0.6, "lp1": 0.2},
	], 0.15)
	_streams["yank"] = _render([
		{"k": "t", "at": 0.0, "dur": 0.15, "f0": 900.0, "f1": 200.0, "vol": 0.7},
		{"k": "n", "at": 0.0, "dur": 0.08, "vol": 0.35, "lp0": 0.8, "lp1": 0.3},
	], 0.18)
	_streams["perfect"] = _render([
		{"k": "t", "at": 0.0, "dur": 0.12, "f0": 660.0, "f1": 1320.0, "vol": 0.6},
		{"k": "t", "at": 0.10, "dur": 0.20, "f0": 880.0, "f1": 1760.0, "vol": 0.6},
	], 0.34)


## events: Array of {"k":"t"|"n", "at", "dur", "vol", "f0","f1" (tone), "lp0","lp1" (noise)}
func _render(events: Array, total_dur: float) -> AudioStreamWAV:
	var count := maxi(1, int(total_dur * RATE))
	var buf := PackedFloat32Array()
	buf.resize(count)
	for ev: Dictionary in events:
		if ev.get("k") == "t":
			_add_tone(buf, ev)
		else:
			_add_noise(buf, ev)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var s := int(clampf(buf[i], -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream


func _add_tone(buf: PackedFloat32Array, ev: Dictionary) -> void:
	var start := int(float(ev.get("at", 0.0)) * RATE)
	var n := int(float(ev.get("dur", 0.1)) * RATE)
	var f0 := float(ev.get("f0", 440.0))
	var f1 := float(ev.get("f1", 440.0))
	var vol := float(ev.get("vol", 0.5))
	var phase := 0.0
	for i in n:
		var t := float(i) / maxf(1.0, float(n))
		phase += TAU * lerpf(f0, f1, t) / RATE
		var idx := start + i
		if idx >= 0 and idx < buf.size():
			buf[idx] += sin(phase) * vol * exp(-3.0 * t)


func _add_noise(buf: PackedFloat32Array, ev: Dictionary) -> void:
	var start := int(float(ev.get("at", 0.0)) * RATE)
	var n := int(float(ev.get("dur", 0.1)) * RATE)
	var vol := float(ev.get("vol", 0.5))
	var lp0 := float(ev.get("lp0", 0.5))
	var lp1 := float(ev.get("lp1", 0.1))
	var y := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for i in n:
		var t := float(i) / maxf(1.0, float(n))
		var lp := lerpf(lp0, lp1, t)
		y += lp * (rng.randf_range(-1.0, 1.0) - y)
		var idx := start + i
		if idx >= 0 and idx < buf.size():
			buf[idx] += y * vol * exp(-2.5 * t)
