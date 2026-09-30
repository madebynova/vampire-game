class_name AbilityManager
extends PlayerComponent
## Routes input to Ability children and enforces form rules. When a form doesn't allow an
## ability, the player gets explicit feedback instead of silence.

signal ability_denied(ability: Ability, reason: String)

var abilities: Array[Ability] = []


func _on_setup() -> void:
	for child in get_children():
		if child is Ability:
			abilities.append(child)
	player.form.form_changed.connect(_on_form_changed)
	player.health.died.connect(func(_c): deactivate_all())


func _process(_delta: float) -> void:
	if not player.state.can_act():
		return
	for a in abilities:
		if a.input_action != &"" and Input.is_action_just_pressed(a.input_action):
			_try_use(a)


func get_ability(id: StringName) -> Ability:
	for a in abilities:
		if a.ability_id == id:
			return a
	return null


func deactivate_all() -> void:
	for a in abilities:
		a.deactivate()


func _try_use(a: Ability) -> void:
	if a.active and a.toggle:
		a.deactivate()
		return
	var reason := a.why_not()
	if reason != "":
		Sfx.play(&"deny", -6.0)
		ability_denied.emit(a, reason)
		return
	a.activate()


func _on_form_changed(_old: FormData, new_form: FormData) -> void:
	for a in abilities:
		if a.active and not new_form.allows_ability(a.ability_id):
			a.deactivate()
