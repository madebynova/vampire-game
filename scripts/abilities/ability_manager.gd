class_name AbilityManager
extends PlayerComponent
## Routes input to Ability children and enforces form rules. When a form doesn't allow an
## ability, the player gets explicit feedback instead of silence.

signal ability_denied(ability: Ability, reason: String)

var abilities: Array[Ability] = []


func _on_setup() -> void:
	# Abilities are data: every AbilityDefinition in the registry becomes a child node. Which
	# ones the player may *use* is decided per form (FormData.abilities). Player._setup_components
	# calls setup() on these children right after this returns.
	for def: AbilityDefinition in ContentRegistry.list(&"AbilityDefinition"):
		if def.behavior == null:
			push_warning("AbilityDefinition '%s' has no behavior script" % def.id)
			continue
		var a: Ability = def.behavior.new()
		a.name = String(def.id).to_pascal_case()
		a.apply_definition(def)
		add_child(a)
		abilities.append(a)
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
