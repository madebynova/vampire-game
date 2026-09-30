class_name FormController
extends PlayerComponent
## Owns the player's current form (FormData) and the transformation sequence.
## New forms = new FormData resources added to `forms`; no code changes needed for stats/look.

signal transform_started(to_form: FormData)
signal form_changed(old_form: FormData, new_form: FormData)
signal transform_finished(form: FormData)

@export var forms: Array[FormData] = [
	preload("res://data/forms/human.tres"),
	preload("res://data/forms/vampire.tres"),
]
@export var start_form_id: StringName = &"human"
## Forms the transform key cycles through (ids). Wolf/Bat would be appended later.
@export var cycle_ids: Array[StringName] = [&"human", &"vampire"]
@export var transform_time := 1.1

var current: FormData
var _transform_serial := 0


func _on_setup() -> void:
	current = get_form(start_form_id)
	assert(current != null, "FormController: start form missing")
	form_changed.emit(null, current)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"transform") and player.state.can_act():
		request_toggle()


func get_form(id: StringName) -> FormData:
	for f in forms:
		if f.id == id:
			return f
	return null


func is_form(id: StringName) -> bool:
	return current != null and current.id == id


func request_toggle() -> void:
	var idx := cycle_ids.find(current.id)
	request_form(cycle_ids[(idx + 1) % cycle_ids.size()])


## Play the transformation, swapping the form at the midpoint.
func request_form(id: StringName) -> void:
	if not player.state.can_act() or id == current.id:
		return
	var target := get_form(id)
	if target == null:
		return
	_transform_serial += 1
	var serial := _transform_serial
	player.state.set_mode(PlayerState.Mode.TRANSFORMING)
	transform_started.emit(target)
	await get_tree().create_timer(transform_time * 0.5).timeout
	if serial != _transform_serial or player.state.is_dead():
		return
	_apply(target)
	await get_tree().create_timer(transform_time * 0.5).timeout
	if serial != _transform_serial or player.state.is_dead():
		return
	player.state.set_mode(PlayerState.Mode.NORMAL)
	transform_finished.emit(current)


## Instant swap with no sequence (respawn, tests).
func set_form_immediate(id: StringName) -> void:
	_transform_serial += 1
	var target := get_form(id)
	if target != null and target != current:
		_apply(target)


func _apply(target: FormData) -> void:
	var old := current
	current = target
	form_changed.emit(old, current)
