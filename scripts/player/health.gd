class_name Health
extends PlayerComponent
## Health, damage, death and form-based regeneration (vampire regen burns blood).

signal changed(value: float, max_value: float)
signal damaged(amount: float, source: StringName)
signal died(cause: StringName)

@export var max_health := 100.0

var value := 100.0
var is_dead := false
## Sources currently preventing regeneration (e.g. &"sunlight").
var _regen_blockers: Dictionary = {}


func _on_setup() -> void:
	value = max_health
	changed.emit(value, max_health)


func _process(delta: float) -> void:
	if is_dead or value >= max_health or not _regen_blockers.is_empty():
		return
	if player.state.mode == PlayerState.Mode.RESTING:
		return
	var f := player.form.current
	if f.regen_per_sec <= 0.0:
		return
	var want := minf(f.regen_per_sec * delta, max_health - value)
	if f.regen_blood_cost > 0.0:
		var affordable := player.blood.value / f.regen_blood_cost
		want = minf(want, affordable)
		if want <= 0.0:
			return
		player.blood.take(want * f.regen_blood_cost)
	value += want
	changed.emit(value, max_health)


func set_regen_blocked(source: StringName, blocked: bool) -> void:
	if blocked:
		_regen_blockers[source] = true
	else:
		_regen_blockers.erase(source)


func damage(amount: float, source: StringName = &"") -> void:
	if is_dead or amount <= 0.0:
		return
	value = maxf(value - amount, 0.0)
	damaged.emit(amount, source)
	changed.emit(value, max_health)
	if value <= 0.0:
		is_dead = true
		died.emit(source)


func heal(amount: float) -> void:
	if is_dead:
		return
	value = minf(value + amount, max_health)
	changed.emit(value, max_health)


func revive(fraction: float) -> void:
	is_dead = false
	value = max_health * clampf(fraction, 0.05, 1.0)
	_regen_blockers.clear()
	changed.emit(value, max_health)
