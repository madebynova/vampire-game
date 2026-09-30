class_name BloodPool
extends PlayerComponent
## Prototype blood resource. Blood is fuel (Sense, healing, existing as a vampire) - and, through
## feeding, information. A Human spends it very slowly, a Vampire noticeably faster; drinking
## refills it. Low blood never kills: it slows a vampire, stops Sense and healing, and makes the
## body loud about it. This is deliberately NOT the final blood economy.

signal changed(value: float, max_value: float)
signal hungry_changed(is_hungry: bool)
## Blood just rose by `amount` (feeding); the HUD makes a moment of it.
signal gained(amount: float)

@export var max_blood := 100.0
@export var start_blood := 55.0
@export var hungry_threshold := 25.0
## Below this the body is starving: Sense fails, the world feels thin.
@export var starving_threshold := 8.0

var value := 0.0
## Blood spent per second by everything right now (background drain + abilities), for the HUD.
var spend_rate := 0.0
var _hungry := false


func _on_setup() -> void:
	value = start_blood
	_hungry = is_hungry()
	changed.emit(value, max_blood)


func _process(delta: float) -> void:
	if player.state.is_dead() or player.state.mode == PlayerState.Mode.RESTING:
		return
	var f := player.form.current
	var drain := f.blood_drain_per_sec
	spend_rate = drain
	if drain > 0.0:
		take(drain * delta)
	for a in player.abilities.abilities:
		spend_rate += a.current_cost_per_sec()
	# A hungry vampire is a slower vampire. Humans shrug hunger off.
	if f.hunger_slows and is_hungry():
		player.speed_modifiers[&"hunger"] = 0.85 if not is_empty() else 0.7
	else:
		player.speed_modifiers.erase(&"hunger")


func add(amount: float) -> void:
	var before := value
	_set_value(value + amount)
	if value > before:
		gained.emit(value - before)


## Remove up to `amount`; returns how much was actually taken.
func take(amount: float) -> float:
	var taken := minf(amount, value)
	_set_value(value - taken)
	return taken


func set_floor(minimum: float) -> void:
	if value < minimum:
		_set_value(minimum)


func is_empty() -> bool:
	return value <= 0.01


func is_hungry() -> bool:
	return value <= hungry_threshold


func is_starving() -> bool:
	return value <= starving_threshold


## 0..1 of the vessel.
func fraction() -> float:
	return value / max_blood


## How fast your own heart is going, for the HUD pulse and heartbeat audio. A vampire's heart is
## slow and heavy at rest; hunger, feeding, a Bloodrush and burning all quicken it.
func pulse_rate() -> float:
	var bpm := player.form.current.heartbeat_bpm
	if is_starving():
		bpm *= 1.7
	elif is_hungry():
		bpm *= 1.35
	if player.feeding.is_feeding():
		bpm *= 2.3
	if player.surge.active:
		bpm *= 1.0 + 0.45 * player.surge.intensity()
	bpm *= 1.0 + player.sunlight.stage_fraction() * 0.7
	return bpm


func _set_value(v: float) -> void:
	value = clampf(v, 0.0, max_blood)
	changed.emit(value, max_blood)
	var h := is_hungry()
	if h != _hungry:
		_hungry = h
		hungry_changed.emit(h)
