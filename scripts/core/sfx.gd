extends Node
## Procedural prototype audio. No asset files: every sound is synthesised once at startup.
## API: Sfx.play(name), Sfx.play_at(name, pos), Sfx.start_loop(name), Sfx.stop_loop(name).

const RATE := 22050
const POOL_2D := 8
const POOL_3D := 8

var _streams: Dictionary = {}
var _pool2d: Array[AudioStreamPlayer] = []
var _pool3d: Array[AudioStreamPlayer3D] = []
var _loops: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 1337
	for i in POOL_2D:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool2d.append(p)
	for i in POOL_3D:
		var p3 := AudioStreamPlayer3D.new()
		p3.unit_size = 5.0
		p3.max_distance = 45.0
		add_child(p3)
		_pool3d.append(p3)
	_build_all()


# ---------------------------------------------------------------- playback

func play(sound: StringName, volume_db := 0.0, pitch := 1.0) -> AudioStreamPlayer:
	if not _streams.has(sound):
		return null
	var player := _free_2d()
	player.stream = _streams[sound]
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()
	return player


func play_at(sound: StringName, pos: Vector3, volume_db := 0.0, pitch := 1.0) -> AudioStreamPlayer3D:
	if not _streams.has(sound):
		return null
	var player := _free_3d()
	player.stream = _streams[sound]
	player.global_position = pos
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()
	return player


func start_loop(sound: StringName, volume_db := 0.0) -> void:
	if not _streams.has(sound):
		return
	var p: AudioStreamPlayer = _loops.get(sound)
	if p == null:
		p = AudioStreamPlayer.new()
		p.stream = _streams[sound]
		add_child(p)
		_loops[sound] = p
	p.volume_db = volume_db
	if not p.playing:
		p.play()


func set_loop_volume(sound: StringName, volume_db: float) -> void:
	var p: AudioStreamPlayer = _loops.get(sound)
	if p:
		p.volume_db = volume_db


func stop_loop(sound: StringName) -> void:
	var p: AudioStreamPlayer = _loops.get(sound)
	if p and p.playing:
		p.stop()


func stop_all_loops(except: Array = []) -> void:
	for key in _loops:
		if not except.has(key):
			stop_loop(key)


func _free_2d() -> AudioStreamPlayer:
	for p in _pool2d:
		if not p.playing:
			return p
	return _pool2d[0]


func _free_3d() -> AudioStreamPlayer3D:
	for p in _pool3d:
		if not p.playing:
			return p
	return _pool3d[0]


# ---------------------------------------------------------------- synthesis

func _build_all() -> void:
	_streams[&"heartbeat"] = _to_wav(_heartbeat())
	_streams[&"transform_vampire"] = _to_wav(_transform_vampire())
	_streams[&"transform_human"] = _to_wav(_transform_human())
	_streams[&"sense_on"] = _to_wav(_sweep(0.9, 180.0, 1300.0, 0.35, true))
	_streams[&"sense_off"] = _to_wav(_sweep(0.5, 900.0, 140.0, 0.3, false))
	_streams[&"sense_ping"] = _to_wav(_sense_ping())
	_streams[&"sense_loop"] = _to_wav(_sense_loop(), true)
	_streams[&"bite"] = _to_wav(_bite())
	_streams[&"feed_loop"] = _to_wav(_feed_loop(), true)
	_streams[&"feed_end"] = _to_wav(_feed_end())
	_streams[&"sun_warn"] = _to_wav(_sun_warn())
	_streams[&"sizzle_loop"] = _to_wav(_sizzle_loop(), true)
	_streams[&"death"] = _to_wav(_death())
	_streams[&"coffin"] = _to_wav(_coffin())
	_streams[&"gasp"] = _to_wav(_gasp())
	_streams[&"blip"] = _to_wav(_blip())
	_streams[&"memory"] = _to_wav(_memory())
	_streams[&"deny"] = _to_wav(_deny())
	_streams[&"secret"] = _to_wav(_chime())
	_streams[&"wind_loop"] = _to_wav(_wind_loop(), true)
	_streams[&"crickets_loop"] = _to_wav(_crickets_loop(), true)
	_streams[&"birds_loop"] = _to_wav(_birds_loop(), true)
	_streams[&"bell"] = _to_wav(_bell())


func _to_wav(samples: PackedFloat32Array, looped := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	if looped:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav


func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


func _noise() -> float:
	return _rng.randf() * 2.0 - 1.0


func _edge_fade(b: PackedFloat32Array, seconds: float) -> void:
	var n := int(seconds * RATE)
	for i in n:
		var k := float(i) / n
		b[i] *= k
		b[b.size() - 1 - i] *= k


func _heartbeat() -> PackedFloat32Array:
	var b := _buf(0.9)
	for i in b.size():
		var t := float(i) / RATE
		var s := 0.0
		for beat in [[0.0, 0.9], [0.28, 0.6]]:
			var tt: float = t - beat[0]
			if tt >= 0.0:
				var f := 48.0 + 40.0 * exp(-tt * 28.0)
				s += sin(TAU * f * tt) * exp(-tt * 20.0) * beat[1]
		b[i] = s
	return b


func _transform_vampire() -> PackedFloat32Array:
	var b := _buf(1.6)
	var ph := 0.0
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var f := 320.0 * exp(-t * 1.8) + 42.0
		ph += TAU * f / RATE
		var body := sin(ph) * 0.45 + sin(ph * 0.5) * 0.35
		lp += (_noise() - lp) * 0.12
		var flutter := lp * (0.5 + 0.5 * sin(TAU * 13.0 * t)) * clampf(t * 3.0, 0.0, 1.0) * exp(-maxf(t - 0.5, 0.0) * 2.5)
		var burst := lp * exp(-t * 4.0) * 0.8
		var env := clampf(t * 40.0, 0.0, 1.0) * clampf((1.6 - t) * 4.0, 0.0, 1.0)
		b[i] = (body * 0.7 + flutter * 1.3 + burst) * env * 0.7
	return b


func _transform_human() -> PackedFloat32Array:
	var b := _buf(0.9)
	var ph := 0.0
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		ph += TAU * (90.0 + 260.0 * t) / RATE
		lp += (_noise() - lp) * 0.2
		var env := sin(PI * t / 0.9)
		b[i] = (sin(ph) * 0.35 + lp * 0.3) * env
	return b


func _sweep(seconds: float, f0: float, f1: float, amp: float, rising: bool) -> PackedFloat32Array:
	var b := _buf(seconds)
	var ph := 0.0
	var lp := 0.0
	for i in b.size():
		var k := float(i) / b.size()
		var f := f0 * pow(f1 / f0, k)
		ph += TAU * f / RATE
		lp += (_noise() - lp) * 0.3
		var env := sin(PI * k) if rising else (1.0 - k) * clampf(k * 30.0, 0.0, 1.0)
		var vib := 1.0 + 0.02 * sin(TAU * 7.0 * k * seconds)
		b[i] = (sin(ph * vib) * 0.6 + sin(ph * 2.01) * 0.2 + lp * 0.15) * env * amp
	return b


func _sense_ping() -> PackedFloat32Array:
	var b := _buf(1.3)
	for i in b.size():
		var t := float(i) / RATE
		var s := 0.0
		for echo in [[0.0, 1.0], [0.28, 0.4], [0.56, 0.16]]:
			var tt: float = t - echo[0]
			if tt >= 0.0:
				s += (sin(TAU * 520.0 * tt) * 0.6 + sin(TAU * 780.0 * tt) * 0.25) * exp(-tt * 6.5) * echo[1]
		b[i] = s * 0.35
	return b


func _sense_loop() -> PackedFloat32Array:
	var b := _buf(2.0)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += (_noise() - lp) * 0.05
		var trem := 0.75 + 0.25 * sin(TAU * 0.5 * t)
		b[i] = (sin(TAU * 70.0 * t) * 0.3 + sin(TAU * 105.0 * t) * 0.16 + sin(TAU * 210.0 * t) * 0.05 + lp * 0.18) * trem * 0.6
	return b


func _bite() -> PackedFloat32Array:
	var b := _buf(0.5)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += (_noise() - lp) * 0.4
		var crunch := lp * exp(-t * 35.0) * 0.8
		var thump := sin(TAU * (70.0 + 60.0 * exp(-t * 20.0)) * t) * exp(-t * 12.0) * 0.9
		var squelch := sin(TAU * (260.0 - 220.0 * t) * t) * exp(-t * 9.0) * 0.25
		b[i] = crunch + thump + squelch
	return b


func _feed_loop() -> PackedFloat32Array:
	var b := _buf(1.2)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var s := 0.0
		for g in [0.0, 0.6]:
			var tt: float = t - g
			if tt >= 0.0:
				s += sin(TAU * (34.0 + 70.0 * exp(-tt * 9.0)) * tt) * exp(-tt * 9.0) * 0.8
				lp += (_noise() - lp) * 0.18
				s += lp * exp(-tt * 14.0) * 0.35
		b[i] = s
	return b


func _feed_end() -> PackedFloat32Array:
	var b := _buf(1.4)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var env := clampf(t * 5.0, 0.0, 1.0) * exp(-t * 1.6)
		lp += (_noise() - lp) * 0.12
		b[i] = (sin(TAU * 110.0 * t) * 0.3 + sin(TAU * 165.0 * t) * 0.2 + sin(TAU * 220.0 * t) * 0.12 + lp * 0.25) * env
	return b


func _sun_warn() -> PackedFloat32Array:
	var b := _buf(0.7)
	for i in b.size():
		var t := float(i) / RATE
		var f := 740.0 if t < 0.3 else 600.0
		var tt := t if t < 0.3 else t - 0.3
		var env := exp(-tt * 7.0) * clampf(tt * 100.0, 0.0, 1.0)
		b[i] = (sin(TAU * f * t) * 0.5 + sin(TAU * f * 3.0 * t) * 0.12) * env * 0.5
	return b


func _sizzle_loop() -> PackedFloat32Array:
	var b := _buf(1.5)
	var lp := 0.0
	var click := 0.0
	for i in b.size():
		lp += (_noise() - lp) * 0.5
		if _rng.randf() < 0.004:
			click = _rng.randf_range(0.5, 1.0)
		click *= 0.985
		b[i] = lp * 0.12 + _noise() * click * 0.5
	return b


func _death() -> PackedFloat32Array:
	var b := _buf(1.8)
	var lp := 0.0
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += (_noise() - lp) * 0.25
		ph += TAU * (220.0 * exp(-t * 1.6) + 28.0) / RATE
		var env := clampf(t * 8.0, 0.0, 1.0) * clampf((1.8 - t) * 2.0, 0.0, 1.0)
		b[i] = (lp * 0.5 * (0.4 + 0.6 * exp(-t * 1.2)) + sin(ph) * 0.4) * env
	return b


func _coffin() -> PackedFloat32Array:
	var b := _buf(1.3)
	var ph := 0.0
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var f := 62.0 + 26.0 * sin(TAU * 1.3 * t) + 14.0 * t
		ph += f / RATE
		var saw := fmod(ph, 1.0) * 2.0 - 1.0
		lp += (saw - lp) * 0.08
		var creak := lp * clampf(t * 6.0, 0.0, 1.0) * (1.0 if t < 0.7 else exp(-(t - 0.7) * 20.0)) * 0.7
		var tt := t - 0.8
		var thud := 0.0
		if tt >= 0.0:
			thud = sin(TAU * 52.0 * tt) * exp(-tt * 10.0) * 0.9
		b[i] = creak * (1.0 if t < 0.75 else 0.0) + thud
	return b


func _gasp() -> PackedFloat32Array:
	var b := _buf(0.5)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += (_noise() - lp) * 0.35
		var env := clampf(t / 0.07, 0.0, 1.0) * exp(-maxf(t - 0.07, 0.0) * 7.0)
		b[i] = lp * env * 0.8
	return b


func _blip() -> PackedFloat32Array:
	var b := _buf(0.12)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = sin(TAU * 210.0 * t) * sin(PI * t / 0.12) * 0.25
	return b


func _memory() -> PackedFloat32Array:
	var b := _buf(2.2)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += (_noise() - lp) * 0.1
		var swell := pow(clampf(t / 0.9, 0.0, 1.0), 2.0) * exp(-maxf(t - 0.9, 0.0) * 2.2)
		var bells := 0.0
		for n in [[523.0, 0.9], [659.0, 1.1], [784.0, 1.3], [1046.0, 1.55]]:
			var tt: float = t - n[1] * 0.5
			if tt >= 0.0:
				bells += sin(TAU * n[0] * tt) * exp(-tt * 2.6) * 0.12
		b[i] = lp * swell * 0.9 + bells
	return b


func _deny() -> PackedFloat32Array:
	var b := _buf(0.3)
	for i in b.size():
		var t := float(i) / RATE
		var sq := 1.0 if sin(TAU * 110.0 * t) > 0.0 else -1.0
		b[i] = sq * exp(-t * 12.0) * 0.18
	return b


func _chime() -> PackedFloat32Array:
	var b := _buf(1.2)
	for i in b.size():
		var t := float(i) / RATE
		var s := 0.0
		for n in [[880.0, 0.0], [1318.0, 0.12], [1760.0, 0.24]]:
			var tt: float = t - n[1]
			if tt >= 0.0:
				s += sin(TAU * n[0] * tt) * exp(-tt * 4.0) * 0.25
		b[i] = s
	return b


func _wind_loop() -> PackedFloat32Array:
	var b := _buf(4.0)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += (_noise() - lp) * 0.02
		b[i] = lp * (0.6 + 0.4 * sin(TAU * 0.5 * t)) * 1.6
	_edge_fade(b, 0.05)
	return b


func _crickets_loop() -> PackedFloat32Array:
	var b := _buf(3.0)
	for i in b.size():
		var t := float(i) / RATE
		var s := 0.0
		for voice in [[4300.0, 0.0, 0.75], [4750.0, 0.31, 0.9]]:
			var tt := fposmod(t - voice[1], voice[2])
			# Three quick chirps, then silence, repeating (period divides the loop length).
			var burst := 0.0
			if tt < 0.36:
				var local := fposmod(tt, 0.12)
				burst = sin(PI * local / 0.12) if local < 0.12 else 0.0
			s += sin(TAU * voice[0] * t) * burst * 0.5
		b[i] = s * 0.35
	return b


func _birds_loop() -> PackedFloat32Array:
	var b := _buf(6.0)
	var tweets := [[0.4, 3000.0], [0.62, 3500.0], [1.9, 2600.0], [2.05, 3100.0], [2.2, 3600.0], [3.6, 2900.0], [4.3, 3300.0], [4.48, 3800.0], [5.0, 2700.0]]
	for tw in tweets:
		var start := int(tw[0] * RATE)
		var n := int(0.14 * RATE)
		var ph := 0.0
		for j in n:
			var k := float(j) / n
			ph += TAU * (float(tw[1]) * (1.0 + 0.35 * sin(PI * k) + 0.05 * sin(k * 90.0))) / RATE
			b[start + j] += sin(ph) * sin(PI * k) * 0.22
	return b


func _bell() -> PackedFloat32Array:
	var b := _buf(3.2)
	for i in b.size():
		var t := float(i) / RATE
		var s := 0.0
		for part in [[1.0, 1.0, 1.1], [2.0, 0.6, 1.6], [2.76, 0.5, 2.2], [5.4, 0.3, 3.5], [8.93, 0.15, 5.0]]:
			s += sin(TAU * 196.0 * part[0] * t) * part[1] * exp(-t * part[2])
		b[i] = s * clampf(t * 300.0, 0.0, 1.0) * 0.32
	return b
