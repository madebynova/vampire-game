class_name AudioBuses
extends RefCounted
## The game's audio bus layout, created in code (no .tres bus layout to keep in sync):
##   Master
##     Effects   (feeding, Sense, heartbeats, UI)              + low-pass
##     Ambience  (wind, crickets, birds)                        + low-pass, + reverb while a Vampire
##     Music     (the procedural Blood Memory beds; no score yet) + low-pass
## The low-pass "muffle" is how transformation, Blood Memory and the pause menu push the world away.

const EFFECTS := &"Effects"
const AMBIENCE := &"Ambience"
const MUSIC := &"Music"
const OPEN_HZ := 20500.0
const CLOSED_HZ := 500.0


static func ensure() -> void:
	for bus in [EFFECTS, AMBIENCE, MUSIC]:
		if AudioServer.get_bus_index(bus) != -1:
			continue
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus)
		AudioServer.set_bus_send(idx, &"Master")
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = OPEN_HZ
		AudioServer.add_bus_effect(idx, lp, 0)
		AudioServer.set_bus_effect_enabled(idx, 0, false)
		if bus == AMBIENCE:
			var rv := AudioEffectReverb.new()
			rv.room_size = 0.55
			rv.damping = 0.6
			rv.wet = 0.22
			rv.dry = 0.95
			AudioServer.add_bus_effect(idx, rv, 1)
			AudioServer.set_bus_effect_enabled(idx, 1, false)


## A vampire's heightened hearing: the night gets a subtle, cavernous depth. Off as a Human.
static func set_vampire_hearing(on: bool) -> void:
	var idx := AudioServer.get_bus_index(AMBIENCE)
	if idx != -1 and AudioServer.get_bus_effect_count(idx) > 1:
		AudioServer.set_bus_effect_enabled(idx, 1, on)


## 0 = fully open, 1 = heavily muffled. Disabled entirely when open (no CPU cost).
static func set_muffle(bus: StringName, amount: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx == -1:
		return
	var a := clampf(amount, 0.0, 1.0)
	AudioServer.set_bus_effect_enabled(idx, 0, a > 0.01)
	var lp := AudioServer.get_bus_effect(idx, 0) as AudioEffectLowPassFilter
	if lp:
		lp.cutoff_hz = OPEN_HZ * pow(CLOSED_HZ / OPEN_HZ, a)


static func muffle_of(bus: StringName) -> float:
	var idx := AudioServer.get_bus_index(bus)
	if idx == -1 or not AudioServer.is_bus_effect_enabled(idx, 0):
		return 0.0
	var lp := AudioServer.get_bus_effect(idx, 0) as AudioEffectLowPassFilter
	if lp == null:
		return 0.0
	return clampf(log(lp.cutoff_hz / OPEN_HZ) / log(CLOSED_HZ / OPEN_HZ), 0.0, 1.0)


static func set_volume(bus: StringName, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx == -1:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.001)))
