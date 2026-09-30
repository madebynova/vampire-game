class_name Ability
extends PlayerComponent
## Base class for a supernatural ability. Add a child node with a script extending this
## under Player/Components/Abilities and AbilityManager finds it automatically.

signal activated
signal deactivated

@export var ability_id: StringName = &""
@export var display_name := "Ability"
@export var input_action: StringName = &""
@export var toggle := true
@export var blood_cost_per_sec := 0.0
@export var min_blood_to_activate := 0.0

var active := false


## Configure this instance from data (id, cost, key, tunables).
func apply_definition(def: AbilityDefinition) -> void:
	ability_id = def.id
	display_name = def.display_name
	input_action = def.input_action
	toggle = def.toggle
	blood_cost_per_sec = def.blood_cost_per_sec
	min_blood_to_activate = def.min_blood_to_activate
	for key in def.parameters:
		set(key, def.parameters[key])


func is_allowed_in_form() -> bool:
	return player.form.current.allows_ability(ability_id)


## Returns "" when usable, otherwise a player-facing reason.
func why_not() -> String:
	if not is_allowed_in_form():
		return _denied_message()
	if player.blood.value < min_blood_to_activate or (blood_cost_per_sec > 0.0 and player.blood.is_empty()):
		return "Too hungry. Your body has nothing left to spend."
	return ""


func _denied_message() -> String:
	return "You can't do that as a %s." % player.form.current.display_name.to_lower()


func activate() -> void:
	if active:
		return
	active = true
	_on_activated()
	activated.emit()


func deactivate() -> void:
	if not active:
		return
	active = false
	_on_deactivated()
	deactivated.emit()


func _process(delta: float) -> void:
	if not active:
		return
	if not is_allowed_in_form() or player.state.is_dead():
		deactivate()
		return
	if blood_cost_per_sec > 0.0:
		player.blood.take(blood_cost_per_sec * delta)
		if player.blood.is_empty():
			deactivate()
			return
	_on_tick(delta)


func _on_activated() -> void:
	pass


func _on_deactivated() -> void:
	pass


func _on_tick(_delta: float) -> void:
	pass
