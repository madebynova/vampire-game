class_name BloodSurge
extends PlayerComponent
## The Bloodrush: what a good feed leaves in a vampire for a while. It is the reason to WANT to
## feed beyond refilling a meter - quicker, higher, Sense that costs nothing, wounds that close
## faster and a little more patience with the sun. How strong and how long comes from the
## victim's FeedStyle (calm / asleep / afraid / trusting) and their blood type.
##
## Everything it touches goes through existing hooks (speed_modifiers, Ability.cost_modifiers,
## SunlightExposure.set_heat_modifier, Health regen), so nothing else knows the numbers.

signal started(info: Dictionary)
signal ended

@export var speed_bonus := 0.16      ## at power 1.0
@export var jump_bonus := 0.10
@export var sun_relief := 0.15       ## fraction of sun heat shrugged off at power 1.0
@export var max_seconds := 120.0
@export var fade_in := 0.5
@export var fade_out := 4.0          ## the last seconds taper instead of switching off

var active := false
var power := 0.0
var seconds_left := 0.0
var total_seconds := 0.0
var surge_name := ""
var _level := 0.0                    ## eased 0..1 strength actually applied


func _on_setup() -> void:
	player.form.form_changed.connect(func(_o, f: FormData):
		if not f.can_feed:
			stop(false))
	player.health.died.connect(func(_c): stop(false))


## Begin or refresh. A stronger surge replaces a weaker one; time stacks up to `max_seconds`.
func start(p: float, seconds: float, label: String) -> void:
	if p <= 0.0 or seconds <= 0.0:
		return
	var fresh := not active
	active = true
	if p >= power or fresh:
		power = p
		surge_name = label
	seconds_left = minf(seconds_left + seconds, max_seconds)
	total_seconds = maxf(total_seconds if not fresh else 0.0, seconds_left)
	started.emit({"name": surge_name, "power": power, "seconds": seconds_left, "fresh": fresh})


func stop(announce := true) -> void:
	if not active:
		return
	active = false
	seconds_left = 0.0
	power = 0.0
	_level = 0.0
	_apply()
	if announce:
		Sfx.play(&"surge_end", -8.0)
	ended.emit()


## 0..1 how much of the surge is being applied right now.
func intensity() -> float:
	return _level


## What a surge of `p` power does, in plain words and real numbers (the HUD and the memory screen show it,
## so a number on screen is never a mystery). Generated from the same tuning the surge applies.
func effect_text(p: float) -> String:
	return "+%d%% speed, +%d%% jump, Sense is free, sun burns %d%% slower" % [
		roundi(speed_bonus * p * 100.0), roundi(jump_bonus * p * 100.0), roundi(sun_relief * minf(p, 1.3) * 100.0)]


## The same in few words, for the line under the timer on the HUD.
func effect_short() -> String:
	return "Faster, higher jumps, Sense is free, the sun burns slower"


## "0:32" style clock for a number of seconds.
static func clock_text(seconds: float) -> String:
	var s := int(ceil(maxf(seconds, 0.0)))
	return "%d:%02d" % [s / 60, s % 60]


func _process(delta: float) -> void:
	if not active:
		return
	seconds_left -= delta
	if seconds_left <= 0.0:
		stop()
		return
	var goal := clampf(seconds_left / fade_out, 0.0, 1.0)
	_level = move_toward(_level, goal, delta / (fade_in if goal > _level else fade_out * 0.5))
	_apply()


func _apply() -> void:
	if active and _level > 0.001:
		player.speed_modifiers[&"surge"] = 1.0 + speed_bonus * power * _level
		player.jump_multiplier = 1.0 + jump_bonus * power * _level
		player.sunlight.set_heat_modifier(&"surge", 1.0 - sun_relief * minf(power, 1.3) * _level)
	else:
		player.speed_modifiers.erase(&"surge")
		player.jump_multiplier = 1.0
		player.sunlight.clear_heat_modifier(&"surge")
	# Sense is free while the blood is in you.
	for a in player.abilities.abilities:
		if active and _level > 0.35:
			a.cost_modifiers[&"surge"] = 0.0
		else:
			a.cost_modifiers.erase(&"surge")
