extends Node
## Autoload. Registers every gameplay input action at startup (in code, so bindings are reviewable
## as plain text) and tracks which kind of device the player touched last so prompts can show the
## right glyph. Gameplay code only ever talks about ACTION NAMES - never keycodes or device names -
## which is what makes rebinding and more pad layouts possible later.
##
## Pad layout (Xbox-style / XInput is the reference; PlayStation labels are mapped from the same
## Godot JoyButton indices, so a DualSense works with no extra bindings):
##   Left stick  move            Right stick  camera
##   A / Cross   jump / confirm  B / Circle   cancel / back
##   X / Square  interact, feed (hold)        Y / Triangle  transform
##   LB / L1     Vampiric Sense (toggle)      R3 also toggles Sense
##   RB / R1     Rend (the vampire's strike; also left mouse button / R)
##   L3          run (toggle)    RT / R2      run (hold)
##   Menu        pause           View         controls

signal device_changed(kind: StringName)

const KEYBOARD := &"keyboard"
const XBOX := &"xbox"
const PLAYSTATION := &"playstation"

## Every action the game reads. Tests assert each has at least one event.
const GAMEPLAY_ACTIONS: Array[StringName] = [
	&"move_forward", &"move_back", &"move_left", &"move_right", &"look_up", &"look_down",
	&"look_left", &"look_right", &"sprint", &"sprint_toggle", &"jump", &"interact", &"feed",
	&"transform", &"vampiric_sense", &"pause", &"toggle_help", &"toggle_debug", &"memory_dismiss", &"attack",
]

const _XBOX_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "View", JOY_BUTTON_START: "Menu", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "D-pad Up", JOY_BUTTON_DPAD_DOWN: "D-pad Down", JOY_BUTTON_DPAD_LEFT: "D-pad Left", JOY_BUTTON_DPAD_RIGHT: "D-pad Right",
}
const _PS_NAMES := {
	JOY_BUTTON_A: "Cross", JOY_BUTTON_B: "Circle", JOY_BUTTON_X: "Square", JOY_BUTTON_Y: "Triangle",
	JOY_BUTTON_BACK: "Create", JOY_BUTTON_START: "Options", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "L1", JOY_BUTTON_RIGHT_SHOULDER: "R1",
	JOY_BUTTON_DPAD_UP: "D-pad Up", JOY_BUTTON_DPAD_DOWN: "D-pad Down", JOY_BUTTON_DPAD_LEFT: "D-pad Left", JOY_BUTTON_DPAD_RIGHT: "D-pad Right",
}

var device_kind: StringName = KEYBOARD


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register(&"move_forward", [KEY_W, KEY_UP], [[JOY_AXIS_LEFT_Y, -1.0]])
	_register(&"move_back", [KEY_S, KEY_DOWN], [[JOY_AXIS_LEFT_Y, 1.0]])
	_register(&"move_left", [KEY_A, KEY_LEFT], [[JOY_AXIS_LEFT_X, -1.0]])
	_register(&"move_right", [KEY_D, KEY_RIGHT], [[JOY_AXIS_LEFT_X, 1.0]])
	_register(&"look_up", [], [[JOY_AXIS_RIGHT_Y, -1.0]])
	_register(&"look_down", [], [[JOY_AXIS_RIGHT_Y, 1.0]])
	_register(&"look_left", [], [[JOY_AXIS_RIGHT_X, -1.0]])
	_register(&"look_right", [], [[JOY_AXIS_RIGHT_X, 1.0]])
	# Run: Shift or the right trigger held; the left stick click latches it on for as long as you keep moving.
	_register(&"sprint", [KEY_SHIFT], [[JOY_AXIS_TRIGGER_RIGHT, 1.0]])
	_register(&"sprint_toggle", [], [], [JOY_BUTTON_LEFT_STICK])
	_register(&"jump", [KEY_SPACE], [], [JOY_BUTTON_A])
	_register(&"interact", [KEY_E], [], [JOY_BUTTON_X])
	_register(&"feed", [KEY_E], [], [JOY_BUTTON_X])
	_register(&"transform", [KEY_F], [], [JOY_BUTTON_Y])
	_register(&"vampiric_sense", [KEY_Q], [], [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_STICK])
	# Rend, the vampire's strike: R, the left mouse button, or the right bumper (RT stays the run trigger).
	_register(&"attack", [KEY_R], [], [JOY_BUTTON_RIGHT_SHOULDER])
	var strike_click := InputEventMouseButton.new()
	strike_click.button_index = MOUSE_BUTTON_LEFT
	strike_click.device = -1
	InputMap.action_add_event(&"attack", strike_click)
	_register(&"pause", [KEY_ESCAPE], [], [JOY_BUTTON_START])
	_register(&"toggle_help", [KEY_H], [], [JOY_BUTTON_BACK])
	_register(&"toggle_debug", [KEY_F3])
	# Dismissing a Blood Memory: any deliberate "continue" input on either device.
	_register(&"memory_dismiss", [KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER], [], [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X])
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.device = -1
	InputMap.action_add_event(&"memory_dismiss", click)
	_ensure_ui_pad_bindings()
	# Abilities (including mod abilities) may declare their own default key / pad button.
	for def in ContentRegistry.list(&"AbilityDefinition"):
		if def.input_action != &"" and not InputMap.has_action(def.input_action):
			_register(def.input_action, [def.default_key] if def.default_key != 0 else [], [], [def.default_joy_button] if def.default_joy_button >= 0 else [])


## Menus must be navigable with a pad. Godot's built-in ui_* actions are not guaranteed to carry pad
## bindings in every build (ui_accept had none in 4.8-dev6), so make sure each one has them:
## D-pad or left stick to move, A to accept, B to go back.
func _ensure_ui_pad_bindings() -> void:
	var buttons := {
		&"ui_accept": JOY_BUTTON_A, &"ui_cancel": JOY_BUTTON_B,
		&"ui_up": JOY_BUTTON_DPAD_UP, &"ui_down": JOY_BUTTON_DPAD_DOWN,
		&"ui_left": JOY_BUTTON_DPAD_LEFT, &"ui_right": JOY_BUTTON_DPAD_RIGHT,
	}
	for action in buttons:
		if not _has_joy_button(action, buttons[action]):
			var ev := InputEventJoypadButton.new()
			ev.button_index = buttons[action]
			ev.device = -1
			InputMap.action_add_event(action, ev)
	var axes := {
		&"ui_up": [JOY_AXIS_LEFT_Y, -1.0], &"ui_down": [JOY_AXIS_LEFT_Y, 1.0],
		&"ui_left": [JOY_AXIS_LEFT_X, -1.0], &"ui_right": [JOY_AXIS_LEFT_X, 1.0],
	}
	for action in axes:
		if not _has_joy_axis(action, axes[action][0], axes[action][1]):
			var ev := InputEventJoypadMotion.new()
			ev.axis = axes[action][0]
			ev.axis_value = axes[action][1]
			ev.device = -1
			InputMap.action_add_event(action, ev)


func _has_joy_button(action: StringName, button: int) -> bool:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton and ev.button_index == button:
			return true
	return false


func _has_joy_axis(action: StringName, axis: int, value: float) -> bool:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadMotion and ev.axis == axis and signf(ev.axis_value) == signf(value):
			return true
	return false


func _register(action: StringName, keys: Array, axes: Array = [], buttons: Array = []) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)
	for k in keys:
		var key_event := InputEventKey.new()
		key_event.physical_keycode = k
		key_event.device = -1
		InputMap.action_add_event(action, key_event)
	for a in axes:
		var axis_event := InputEventJoypadMotion.new()
		axis_event.axis = a[0]
		axis_event.axis_value = a[1]
		axis_event.device = -1
		InputMap.action_add_event(action, axis_event)
	for b in buttons:
		var button_event := InputEventJoypadButton.new()
		button_event.button_index = b
		button_event.device = -1
		InputMap.action_add_event(action, button_event)


# ---------------------------------------------------------------- last-used device

func _input(event: InputEvent) -> void:
	var kind := device_kind
	if event is InputEventKey and event.pressed:
		kind = KEYBOARD
	elif event is InputEventMouseButton and event.pressed:
		kind = KEYBOARD
	elif event is InputEventJoypadButton and event.pressed:
		kind = classify_joypad(Input.get_joy_name(event.device))
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		kind = classify_joypad(Input.get_joy_name(event.device))
	if kind != device_kind:
		device_kind = kind
		device_changed.emit(kind)


## Test hook / device hot-swap: pretend the player just used this kind of device.
func set_device_kind(kind: StringName) -> void:
	if kind != device_kind:
		device_kind = kind
		device_changed.emit(kind)


## Pad family from the driver-reported name. Only the *family* matters (labels); nothing in
## gameplay ever branches on a device name. Unknown pads are treated as Xbox-style.
static func classify_joypad(joy_name: String) -> StringName:
	var n := joy_name.to_lower()
	if n.contains("xbox") or n.contains("xinput"):
		return XBOX   # "Xbox Wireless Controller" must not match the PlayStation "Wireless Controller"
	for marker in ["dualsense", "dualshock", "playstation", "ps5", "ps4", "ps3", "sony", "wireless controller"]:
		if n.contains(marker):
			return PLAYSTATION
	return XBOX


# ---------------------------------------------------------------- prompts

## Binding descriptions for `action` on a device family, primary first. Each entry:
## {"text": "X", "shape": "key"|"face"|"pill"|"stick"|"trigger"|"dpad"|"mouse", "color": Color}
func bindings_for(action: StringName, kind: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not InputMap.has_action(action):
		return out
	for ev in InputMap.action_get_events(action):
		if kind == KEYBOARD:
			if ev is InputEventKey:
				out.append({"text": _key_text(ev), "shape": &"key", "color": Color(0.85, 0.85, 0.88)})
			elif ev is InputEventMouseButton:
				out.append({"text": "Click", "shape": &"mouse", "color": Color(0.85, 0.85, 0.88)})
		else:
			var names := _PS_NAMES if kind == PLAYSTATION else _XBOX_NAMES
			if ev is InputEventJoypadButton:
				var b: int = ev.button_index
				out.append({"text": names.get(b, "Btn %d" % b), "shape": _pad_shape(b), "color": _pad_color(b, kind)})
			elif ev is InputEventJoypadMotion and (ev.axis == JOY_AXIS_TRIGGER_LEFT or ev.axis == JOY_AXIS_TRIGGER_RIGHT):
				var left: bool = ev.axis == JOY_AXIS_TRIGGER_LEFT
				out.append({"text": ("L2" if left else "R2") if kind == PLAYSTATION else ("LT" if left else "RT"), "shape": &"trigger", "color": Color(0.8, 0.8, 0.85)})
			elif ev is InputEventJoypadMotion:
				out.append({"text": _stick_text(ev), "shape": &"stick", "color": Color(0.8, 0.8, 0.85)})
	return out


## Text for the primary binding of `action` on the device in use ("E", "X", "LB"...).
func prompt_text(action: StringName, kind: StringName = &"") -> String:
	var k := device_kind if kind == &"" else kind
	var b := bindings_for(action, k)
	return b[0]["text"] if not b.is_empty() else "?"


func _key_text(ev: InputEventKey) -> String:
	var code: int = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
	var t := OS.get_keycode_string(code)
	match t:
		"Escape": return "Esc"
		"Kp Enter": return "Enter"
	return t


func _stick_text(ev: InputEventJoypadMotion) -> String:
	match ev.axis:
		JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y: return "Left stick"
		JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y: return "Right stick"
	return "Axis"


func _pad_shape(button: int) -> StringName:
	match button:
		JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y: return &"face"
		JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER: return &"pill"
		JOY_BUTTON_LEFT_STICK, JOY_BUTTON_RIGHT_STICK: return &"stick"
		JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT: return &"dpad"
	return &"pill"


func _pad_color(button: int, kind: StringName) -> Color:
	if kind == PLAYSTATION:
		match button:
			JOY_BUTTON_A: return Color(0.55, 0.7, 1.0)    # cross
			JOY_BUTTON_B: return Color(1.0, 0.45, 0.45)   # circle
			JOY_BUTTON_X: return Color(0.95, 0.6, 0.85)   # square
			JOY_BUTTON_Y: return Color(0.45, 0.9, 0.7)    # triangle
	else:
		match button:
			JOY_BUTTON_A: return Color(0.45, 0.85, 0.4)
			JOY_BUTTON_B: return Color(0.95, 0.4, 0.35)
			JOY_BUTTON_X: return Color(0.4, 0.6, 1.0)
			JOY_BUTTON_Y: return Color(1.0, 0.85, 0.3)
	return Color(0.8, 0.8, 0.85)
