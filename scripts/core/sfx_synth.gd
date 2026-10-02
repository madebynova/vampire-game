class_name SfxSynth
extends RefCounted
## Procedural sound recipes added in Task 1.75 (the original ones still live in sfx.gd). Each
## function returns mono float samples at RATE; Sfx turns them into streams lazily on first use so
## startup stays cheap. Looping recipes choose frequencies whose cycles divide the loop length,
## so the seam does not click. Deliberately simple: placeholder audio that carries feeling.

const RATE := 22050

static var _rng := RandomNumberGenerator.new()


static func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


static func _noise() -> float:
	return _rng.randf() * 2.0 - 1.0


static func _seed() -> void:
	_rng.seed = 4242


## A two-part heartbeat ("lub-dub"). `click` adds a sharp attack, for frightened hearts.
static func heartbeat(f_low: float, f_high: float, decay: float, gap: float, second_gain: float, click: float, seconds := 0.9) -> PackedFloat32Array:
	_seed()
	var b := _buf(seconds)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var s := 0.0
		for beat in [[0.0, 1.0], [gap, second_gain]]:
			var tt: float = t - beat[0]
			if tt >= 0.0:
				var f := f_low + (f_high - f_low) * exp(-tt * decay * 1.4)
				s += sin(TAU * f * tt) * exp(-tt * decay) * beat[1]
				if click > 0.0:
					lp += (_noise() - lp) * 0.5
					s += lp * exp(-tt * 90.0) * click * beat[1]
		b[i] = s * 0.9
	return b


## Transformation into a vampire: a held breath rising, a deep impact, leather wings, a dark tail.
static func transform_vampire() -> PackedFloat32Array:
	_seed()
	var b := _buf(2.1)
	var ph := 0.0
	var lp := 0.0
	var lp2 := 0.0
	for i in b.size():
		var t := float(i) / RATE
		# Riser 0..0.55: tone climbing under tightening noise.
		var rise := 0.0
		if t < 0.55:
			var k := t / 0.55
			ph += TAU * (80.0 + 520.0 * k * k) / RATE
			lp += (_noise() - lp) * (0.05 + 0.5 * k)
			rise = (sin(ph) * 0.35 + lp * 0.5) * k * k * (1.0 if t < 0.52 else (0.55 - t) / 0.03)
		# Impact at 0.55.
		var tt := t - 0.55
		var hit := 0.0
		if tt >= 0.0:
			hit += sin(TAU * (30.0 + 80.0 * exp(-tt * 7.0)) * tt) * exp(-tt * 3.2) * 1.0
			lp2 += (_noise() - lp2) * 0.35
			hit += lp2 * exp(-tt * 12.0) * 0.7
			for p in [[900.0, 0.05], [1370.0, 0.04], [2110.0, 0.03]]:
				hit += sin(TAU * p[0] * tt) * exp(-tt * 3.0) * p[1]
			# Leather wings: gated noise bursts just after the hit.
			var flap := maxf(sin(TAU * 11.0 * tt), 0.0) * clampf(tt * 12.0, 0.0, 1.0) * exp(-maxf(tt - 0.2, 0.0) * 3.5)
			hit += lp2 * flap * 0.45
			# Dark drone under the tail.
			hit += sin(TAU * 55.0 * tt + sin(TAU * 0.7 * tt) * 2.0) * exp(-tt * 1.4) * 0.25
		b[i] = clampf((rise + hit) * 0.85, -1.0, 1.0)
	return b


## Back to human: a long exhale and the warmth of a normal heartbeat returning.
static func transform_human() -> PackedFloat32Array:
	_seed()
	var b := _buf(1.3)
	var ph := 0.0
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var k := t / 1.3
		lp += (_noise() - lp) * lerpf(0.3, 0.04, k)
		ph += TAU * lerpf(300.0, 120.0, k) / RATE
		var env := sin(PI * minf(k * 1.15, 1.0)) * (1.0 - k * 0.4)
		var s := (lp * 0.5 + sin(ph) * 0.22) * env
		for beat in [0.25, 0.85]:
			var tt: float = t - beat
			if tt >= 0.0:
				s += sin(TAU * (56.0 + 40.0 * exp(-tt * 25.0)) * tt) * exp(-tt * 14.0) * 0.6
		b[i] = s * 0.8
	return b


## The surge when a feed ends: a chord swelling out of two heartbeats.
static func feed_rush() -> PackedFloat32Array:
	_seed()
	var b := _buf(2.0)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var swell := clampf(t / 0.6, 0.0, 1.0) * exp(-maxf(t - 0.6, 0.0) * 1.3)
		var s := 0.0
		for f in [110.0, 164.8, 220.0, 329.6]:
			s += sin(TAU * f * t) * 0.15 + sin(TAU * (f * 1.004) * t) * 0.1
		lp += (_noise() - lp) * 0.08
		s = (s + lp * 0.12) * swell
		for beat in [0.05, 0.3]:
			var tt: float = t - beat
			if tt >= 0.0:
				s += sin(TAU * (50.0 + 60.0 * exp(-tt * 22.0)) * tt) * exp(-tt * 10.0) * 0.8
		b[i] = s * 0.85
	return b


## Vampiric Sense switching on: a thump in the chest, then the world opening like a long breath.
static func sense_on() -> PackedFloat32Array:
	_seed()
	var b := _buf(1.1)
	var ph := 0.0
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var k := t / 1.1
		ph += TAU * (160.0 * pow(1300.0 / 160.0, k)) / RATE
		lp += (_noise() - lp) * lerpf(0.06, 0.4, k)
		var env := sin(PI * k)
		var s := (sin(ph) * 0.3 + sin(ph * 2.01) * 0.1 + lp * 0.3) * env
		s += sin(TAU * (48.0 + 50.0 * exp(-t * 18.0)) * t) * exp(-t * 7.0) * 0.9
		b[i] = s * 0.7
	return b


## A low throb for a living thing very close.
static func sense_throb() -> PackedFloat32Array:
	_seed()
	var b := _buf(0.45)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = sin(TAU * (44.0 + 30.0 * exp(-t * 16.0)) * t) * exp(-t * 7.5) * 0.9 + sin(TAU * 88.0 * t) * exp(-t * 14.0) * 0.2
	return b


## Breath out as the Bloodrush fades.
static func surge_end() -> PackedFloat32Array:
	_seed()
	var b := _buf(1.3)
	var lp := 0.0
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var k := t / 1.3
		lp += (_noise() - lp) * lerpf(0.25, 0.03, k)
		ph += TAU * lerpf(230.0, 95.0, k) / RATE
		b[i] = (lp * 0.5 + sin(ph) * 0.2) * sin(PI * k) * 0.7
	return b


## Hunger: a low hollow pang.
static func hunger_pang() -> PackedFloat32Array:
	_seed()
	var b := _buf(1.0)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += (_noise() - lp) * 0.03
		var env := sin(PI * t) * (0.6 + 0.4 * sin(TAU * 5.0 * t))
		b[i] = (sin(TAU * 62.0 * t) * 0.5 + lp * 2.0) * env * 0.6
	return b


## Memory beds (4.0 s loops). Every frequency is a multiple of 0.25 Hz so the loop is seamless.

## Calm: a warm pad breathing once per loop with two distant bells.
static func memory_calm() -> PackedFloat32Array:
	_seed()
	var b := _buf(4.0)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var breath := 0.65 + 0.35 * sin(TAU * 0.25 * t - 1.2)
		var s := 0.0
		for f in [110.0, 165.0, 220.0, 262.0, 330.0]:
			s += sin(TAU * f * t) * 0.09 + sin(TAU * (f + 0.5) * t) * 0.06
		lp += (_noise() - lp) * 0.02
		s = (s + lp * 0.5) * breath
		for bell in [[1.0, 523.0], [2.75, 659.0]]:
			var tt: float = t - bell[0]
			if tt >= 0.0:
				s += sin(TAU * bell[1] * tt) * exp(-tt * 2.4) * 0.08
		b[i] = s * 0.9
	return b


## Asleep: a slow music-box tune over a sub hum, lightly detuned like a dream.
static func memory_asleep() -> PackedFloat32Array:
	_seed()
	var b := _buf(4.0)
	var notes := [[0.0, 440.0], [0.5, 523.0], [1.0, 659.0], [1.75, 587.0], [2.5, 523.0], [3.0, 440.0]]
	for i in b.size():
		var t := float(i) / RATE
		var s := sin(TAU * 55.0 * t) * 0.16 + sin(TAU * 110.0 * t) * 0.07
		var wobble := 1.0 + 0.004 * sin(TAU * 0.5 * t)
		for n in notes:
			var tt: float = t - n[0]
			if tt >= 0.0:
				var f: float = n[1] * wobble
				s += (sin(TAU * f * tt) * 0.2 + sin(TAU * f * 2.0 * tt) * 0.06) * exp(-tt * 3.6)
		b[i] = s * 0.85
	return b


## Afraid: dissonance beating against itself, ragged breath, a racing heart.
static func memory_afraid() -> PackedFloat32Array:
	_seed()
	var b := _buf(4.0)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var trem := 0.55 + 0.45 * sin(TAU * 8.0 * t + sin(TAU * 1.0 * t) * 2.0)
		var s := (sin(TAU * 100.0 * t) * 0.14 + sin(TAU * 106.0 * t) * 0.14 + sin(TAU * 530.0 * t) * 0.05 + sin(TAU * 557.0 * t) * 0.05) * trem
		lp += (_noise() - lp) * 0.3
		var breath := maxf(sin(TAU * 1.0 * t - 0.5), 0.0)
		s += lp * breath * breath * 0.22
		var bt := fposmod(t, 0.5)
		s += sin(TAU * (55.0 + 50.0 * exp(-bt * 25.0)) * bt) * exp(-bt * 12.0) * 0.5
		b[i] = s * 0.8
	return b


static func traverse_window() -> PackedFloat32Array:
	_seed()
	var b := _buf(0.7)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += (_noise() - lp) * lerpf(0.05, 0.35, t / 0.7)
		var env := exp(-pow((t - 0.25) / 0.14, 2.0))
		var s := lp * env * 0.8
		s += sin(TAU * (120.0 - 60.0 * t) * t) * exp(-t * 6.0) * 0.3
		var tt := t - 0.05
		if tt >= 0.0:
			s += _noise() * exp(-tt * 70.0) * 0.4   # the tick of wood and cloth at the sill
		b[i] = s
	return b


static func traverse_climb() -> PackedFloat32Array:
	_seed()
	var b := _buf(0.9)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += (_noise() - lp) * 0.22
		var s := lp * exp(-pow((t - 0.35) / 0.25, 2.0)) * 0.5
		for scuff in [0.08, 0.3, 0.52]:
			var tt: float = t - scuff
			if tt >= 0.0:
				s += _noise() * exp(-tt * 38.0) * 0.35
		b[i] = s
	return b


static func land() -> PackedFloat32Array:
	_seed()
	var b := _buf(0.3)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += (_noise() - lp) * 0.2
		b[i] = sin(TAU * (70.0 - 30.0 * t) * t) * exp(-t * 16.0) * 0.8 + lp * exp(-t * 30.0) * 0.4
	return b


static func ui_move() -> PackedFloat32Array:
	var b := _buf(0.06)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = sin(TAU * 440.0 * t) * sin(PI * t / 0.06) * 0.2
	return b


static func ui_confirm() -> PackedFloat32Array:
	var b := _buf(0.16)
	for i in b.size():
		var t := float(i) / RATE
		var f := 330.0 if t < 0.07 else 495.0
		b[i] = sin(TAU * f * t) * exp(-fposmod(t, 0.07) * 18.0) * 0.22
	return b


static func ui_back() -> PackedFloat32Array:
	var b := _buf(0.12)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = sin(TAU * lerpf(400.0, 250.0, t / 0.12) * t) * sin(PI * t / 0.12) * 0.2
	return b


# ---------------------------------------------------------------- the hunt (v0.2.0)

## A boot on packed earth: a short low thud with a dry scuff.
static func step_boot() -> PackedFloat32Array:
	_seed()
	var b := _buf(0.16)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += (_noise() - lp) * 0.3
		b[i] = sin(TAU * (95.0 - 40.0 * t) * t) * exp(-t * 38.0) * 0.7 + lp * exp(-t * 55.0) * 0.5
	return b


## A tiny iron tick as a lantern swings on its ring.
static func lantern_clink() -> PackedFloat32Array:
	_seed()
	var b := _buf(0.35)
	for i in b.size():
		var t := float(i) / RATE
		var s := 0.0
		for p in [[2100.0, 1.0], [3150.0, 0.5], [4400.0, 0.25]]:
			s += sin(TAU * p[0] * t) * exp(-t * 22.0) * p[1] * 0.12
		b[i] = s * clampf(t * 400.0, 0.0, 1.0)
	return b


## "Hm?": a short, low, questioning two-note hum.
static func hunter_notice() -> PackedFloat32Array:
	_seed()
	var b := _buf(0.5)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var f := 150.0 if t < 0.2 else lerpf(150.0, 215.0, (t - 0.2) / 0.3)
		ph += TAU * f * (1.0 + 0.02 * sin(TAU * 6.0 * t)) / RATE
		var env := sin(PI * minf(t / 0.5, 1.0)) * 0.9
		b[i] = (sin(ph) * 0.5 + sin(ph * 2.0) * 0.18 + sin(ph * 3.0) * 0.08) * env * 0.75
	return b


## Seen: a hard stab (a tritone swelling) over a low hit. The sound of the night turning on you.
static func hunter_spot() -> PackedFloat32Array:
	_seed()
	var b := _buf(0.95)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var swell := pow(clampf(t / 0.16, 0.0, 1.0), 2.0) * exp(-maxf(t - 0.16, 0.0) * 3.4)
		var s := (sin(TAU * 466.0 * t) + sin(TAU * 659.0 * t) * 0.8 + sin(TAU * 932.0 * t) * 0.3) * swell * 0.2
		s += sin(TAU * (58.0 + 90.0 * exp(-t * 20.0)) * t) * exp(-t * 7.0) * 0.8
		lp += (_noise() - lp) * 0.4
		s += lp * exp(-t * 26.0) * 0.5
		b[i] = s * 0.9
	return b


## A blade drawn and raised: steel scraping up through the air, a thin ring at the top.
static func hunter_windup() -> PackedFloat32Array:
	_seed()
	var b := _buf(0.6)
	var lp := 0.0
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var k := t / 0.6
		var n := _noise()
		lp += (n - lp) * 0.12
		var hiss := (n - lp) * pow(k, 1.4) * 0.4
		ph += TAU * (800.0 + 3000.0 * k) / RATE
		var ring := sin(ph) * pow(k, 2.0) * 0.12 * (1.0 if t < 0.56 else (0.6 - t) / 0.04)
		b[i] = (hiss + ring) * 1.55
	return b


## The blade coming down: a hard whoosh.
static func hunter_swing() -> PackedFloat32Array:
	_seed()
	var b := _buf(0.3)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var k := t / 0.3
		lp += (_noise() - lp) * lerpf(0.5, 0.06, k)
		var env := sin(PI * minf(k * 1.4, 1.0)) * (1.0 - k * 0.5)
		b[i] = lp * env * 1.1 + sin(TAU * (180.0 - 90.0 * k) * t) * env * 0.12
	return b


## A grunt: a low voiced burst with a breath behind it.
static func hunter_hurt() -> PackedFloat32Array:
	_seed()
	var b := _buf(0.32)
	var lp := 0.0
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += (_noise() - lp) * 0.2
		ph += TAU * (125.0 - 45.0 * t) / RATE
		var saw := fposmod(ph / TAU, 1.0) * 2.0 - 1.0
		var env := clampf(t / 0.03, 0.0, 1.0) * exp(-t * 9.0)
		b[i] = (saw * 0.3 + lp * 0.35) * env * 1.8
	return b


## Down: steel ringing out on stone, then a body.
static func hunter_down() -> PackedFloat32Array:
	_seed()
	var b := _buf(1.1)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var s := 0.0
		for hit in [[0.0, 1.0], [0.11, 0.5], [0.21, 0.28]]:
			var tt: float = t - hit[0]
			if tt >= 0.0:
				s += (sin(TAU * 1320.0 * tt) + sin(TAU * 1980.0 * tt) * 0.6 + sin(TAU * 3100.0 * tt) * 0.3) * exp(-tt * 14.0) * hit[1] * 0.14
		var tb := t - 0.16
		if tb >= 0.0:
			lp += (_noise() - lp) * 0.2
			s += sin(TAU * (60.0 - 20.0 * tb) * tb) * exp(-tb * 8.0) * 0.8 + lp * exp(-tb * 18.0) * 0.4
		b[i] = s
	return b


## Rend: claws through the air.
static func rend_swing() -> PackedFloat32Array:
	_seed()
	var b := _buf(0.24)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var k := t / 0.24
		var n := _noise()
		lp += (n - lp) * 0.25
		var env := sin(PI * k) * (1.0 - 0.3 * k)
		b[i] = ((n - lp) * 0.45 + sin(TAU * lerpf(380.0, 980.0, k) * t) * 0.06) * env
	return b


## Rend, landing: flesh torn, a thump behind it, a bright edge.
static func rend_hit() -> PackedFloat32Array:
	_seed()
	var b := _buf(0.38)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += (_noise() - lp) * 0.3
		var s := lp * exp(-t * 15.0) * 0.8
		s += sin(TAU * (120.0 - 60.0 * t) * t) * exp(-t * 14.0) * 0.8
		s += sin(TAU * 1800.0 * t) * exp(-t * 32.0) * 0.16
		b[i] = s * 0.95
	return b


## You are struck: the breath knocked out, a deep thump, steel ringing.
static func hit_taken() -> PackedFloat32Array:
	_seed()
	var b := _buf(0.5)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += (_noise() - lp) * 0.22
		var s := sin(TAU * (55.0 + 40.0 * exp(-t * 20.0)) * t) * exp(-t * 9.0) * 0.95
		s += lp * exp(-t * 13.0) * 0.5
		s += (sin(TAU * 1250.0 * t) + sin(TAU * 1870.0 * t) * 0.5) * exp(-t * 9.0) * 0.09
		b[i] = s
	return b
