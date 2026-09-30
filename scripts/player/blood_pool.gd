class_name BloodPool
extends PlayerComponent
## Prototype blood resource. Blood is fuel (sense, healing, existing as a vampire) - and,
## through feeding, information. This is deliberately NOT the final blood economy.

signal changed(value: float, max_value: float)
signal hungry_changed(is_hungry: bool)

@export var max_blood := 100.0
@export var start_blood := 55.0
@export var hungry_threshold := 25.0

var value := 0.0
var _hungry := false


func _on_setup() -> void:
	value = start_blood
	changed.emit(value, max_blood)


func _process(delta: float) -> void:
	if player.state.is_dead() or player.state.mode == PlayerState.Mode.RESTING:
		return
	var drain := player.form.current.blood_drain_per_sec
	if drain > 0.0:
		take(drain * delta)
		# A hungry vampire is a slower vampire.
		if is_hungry():
			player.speed_modifiers[&"hunger"] = 0.85 if not is_empty() else 0.7
		else:
			player.speed_modifiers.erase(&"hunger")
	else:
		player.speed_modifiers.erase(&"hunger")


func add(amount: float) -> void:
	_set_value(value + amount)


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


func _set_value(v: float) -> void:
	value = clampf(v, 0.0, max_blood)
	changed.emit(value, max_blood)
	var h := is_hungry()
	if h != _hungry:
		_hungry = h
		hungry_changed.emit(h)
