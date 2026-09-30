extends Node
## Registers every gameplay input action at startup.
## Done in code so bindings are reviewable as plain text (no serialized InputEvents).

func _ready() -> void:
	_register(&"move_forward", [KEY_W, KEY_UP], [[JOY_AXIS_LEFT_Y, -1.0]])
	_register(&"move_back", [KEY_S, KEY_DOWN], [[JOY_AXIS_LEFT_Y, 1.0]])
	_register(&"move_left", [KEY_A, KEY_LEFT], [[JOY_AXIS_LEFT_X, -1.0]])
	_register(&"move_right", [KEY_D, KEY_RIGHT], [[JOY_AXIS_LEFT_X, 1.0]])
	_register(&"look_up", [], [[JOY_AXIS_RIGHT_Y, -1.0]])
	_register(&"look_down", [], [[JOY_AXIS_RIGHT_Y, 1.0]])
	_register(&"look_left", [], [[JOY_AXIS_RIGHT_X, -1.0]])
	_register(&"look_right", [], [[JOY_AXIS_RIGHT_X, 1.0]])
	_register(&"sprint", [KEY_SHIFT], [], [JOY_BUTTON_LEFT_STICK])
	_register(&"jump", [KEY_SPACE], [], [JOY_BUTTON_A])
	_register(&"interact", [KEY_E], [], [JOY_BUTTON_X])
	_register(&"transform", [KEY_F], [], [JOY_BUTTON_Y])
	_register(&"vampiric_sense", [KEY_Q], [], [JOY_BUTTON_LEFT_SHOULDER])
	_register(&"toggle_help", [KEY_H])
	_register(&"toggle_debug", [KEY_F3])


func _register(action: StringName, keys: Array, axes: Array = [], buttons: Array = []) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)
	for k in keys:
		var key_event := InputEventKey.new()
		key_event.physical_keycode = k
		InputMap.action_add_event(action, key_event)
	for a in axes:
		var axis_event := InputEventJoypadMotion.new()
		axis_event.axis = a[0]
		axis_event.axis_value = a[1]
		InputMap.action_add_event(action, axis_event)
	for b in buttons:
		var button_event := InputEventJoypadButton.new()
		button_event.button_index = b
		InputMap.action_add_event(action, button_event)
