class_name ControlsPanel
extends PanelContainer
## The controls screen: grouped, spaced, with real button glyphs - keyboard keycaps, Xbox-style coloured
## buttons, or PlayStation symbols - instead of a plain list. It lives on the right of the screen and is
## shown from the HUD (H / View) and from the pause and title menus.
##
## `compact` (the HUD): only the device you are using, so it stays narrow and out of the way.
## Not compact (menus): keyboard and pad side by side. Rows the current form cannot use are dimmed.

## Rows: [label, group tag, keyboard spec, pad spec]. A spec item is an action name (resolved from
## the InputMap so it always shows the real binding) or ["text", "shape"] for a fixed glyph.
const GROUPS := [
	["MOVE", [
		["Move", "", [["W", "key"], ["A", "key"], ["S", "key"], ["D", "key"]], [["Left stick", "pill"]]],
		["Look", "", [["Mouse", "mouse"]], [["Right stick", "pill"]]],
		["Run", "", [&"sprint"], [&"sprint", &"sprint_toggle"]],
		["Jump", "", [&"jump"], [&"jump"]],
	]],
	["BECOME", [
		["Transform", "", [&"transform"], [&"transform"]],
		["Vampiric Sense", "vampire", [&"vampiric_sense"], [&"vampiric_sense"]],
		["Feed (hold)", "vampire", [&"feed"], [&"feed"]],
	]],
	["THE WORLD", [
		["Talk, dig, sleep", "", [&"interact"], [&"interact"]],
		["Windows, climbing", "vampire", [&"interact"], [&"interact"]],
		["Continue a memory", "", [&"memory_dismiss"], [&"memory_dismiss"]],
	]],
	["GAME", [
		["Pause", "", [&"pause"], [&"pause"]],
		["This screen", "", [&"toggle_help"], [&"toggle_help"]],
	]],
]

@export var compact := false

var _rows: Array[Dictionary] = []   ## {box, vampire_only}
var _built_kind: StringName = &""


func _ready() -> void:
	add_theme_stylebox_override(&"panel", UiStyle.panel_style(Color(0.03, 0.015, 0.02, 0.8), Color(0.55, 0.1, 0.16, 0.55), 12, 16))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	InputSetup.device_changed.connect(func(_k): _build())


func _pad_kind() -> StringName:
	return InputSetup.device_kind if InputSetup.device_kind != InputSetup.KEYBOARD else InputSetup.XBOX


func _build() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_rows.clear()
	var pad := _pad_kind()
	_built_kind = InputSetup.device_kind
	var using_keyboard := InputSetup.device_kind == InputSetup.KEYBOARD
	var root := VBoxContainer.new()
	root.add_theme_constant_override(&"separation", 2)
	add_child(root)

	var head := HBoxContainer.new()
	root.add_child(head)
	var title := UiStyle.label("CONTROLS", 24, UiStyle.BONE, true, 4)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var kb_name := "KEYBOARD"
	var pad_name := "PLAYSTATION" if pad == InputSetup.PLAYSTATION else "CONTROLLER"
	if compact:
		head.add_child(_column_header(kb_name if using_keyboard else pad_name, 150))
	else:
		head.add_child(_column_header(kb_name, 170))
		head.add_child(_column_header(pad_name, 130))

	for g in GROUPS:
		var gl := UiStyle.label(g[0], 13, UiStyle.BLOOD_BRIGHT, false, 3)
		gl.custom_minimum_size = Vector2(0, 22)
		gl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		root.add_child(gl)
		root.add_child(_rule())
		for r in g[1]:
			root.add_child(_row(r, pad, using_keyboard))

	var foot := UiStyle.label("Dimmed rows need the Vampire form.", 13, UiStyle.BONE_DIM, false, 3)
	foot.custom_minimum_size = Vector2(0, 24)
	foot.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	root.add_child(foot)
	refresh_form(null)


func _column_header(text: String, width: float) -> Label:
	var l := UiStyle.label(text, 12, UiStyle.BONE_DIM, false, 2)
	l.custom_minimum_size = Vector2(width, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return l


func _rule() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.5, 0.12, 0.16, 0.45)
	r.custom_minimum_size = Vector2(0, 1)
	return r


func _row(spec: Array, pad: StringName, using_keyboard: bool) -> Control:
	var h := HBoxContainer.new()
	h.custom_minimum_size = Vector2(0, 34)
	h.add_theme_constant_override(&"separation", 6)
	var name_box := HBoxContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.add_theme_constant_override(&"separation", 8)
	var l := UiStyle.label(spec[0], 17, UiStyle.BONE, false, 3)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_box.add_child(l)
	var vampire_only: bool = spec[1] == "vampire"
	if vampire_only:
		var tag := UiStyle.label("VAMPIRE", 10, UiStyle.BLOOD_BRIGHT, false, 2)
		tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_box.add_child(tag)
	h.add_child(name_box)
	if compact:
		if using_keyboard:
			h.add_child(_glyph_cell(spec[2], InputSetup.KEYBOARD, 150))
		else:
			h.add_child(_glyph_cell(spec[3], pad, 150))
	else:
		h.add_child(_glyph_cell(spec[2], InputSetup.KEYBOARD, 170))
		h.add_child(_glyph_cell(spec[3], pad, 130))
	_rows.append({"box": h, "vampire_only": vampire_only})
	return h


func _glyph_cell(items: Array, kind: StringName, width: float) -> Control:
	var cell := HBoxContainer.new()
	cell.custom_minimum_size = Vector2(width, 0)
	cell.add_theme_constant_override(&"separation", 3)
	cell.alignment = BoxContainer.ALIGNMENT_BEGIN
	for it in items:
		if it is Array:
			cell.add_child(InputGlyph.literal(it[0], StringName(it[1]), kind))
		else:
			var g := InputGlyph.new(it, kind)
			cell.add_child(g)
	return cell


## Dim the rows the current form cannot use.
func refresh_form(form: FormData) -> void:
	for r in _rows:
		var usable: bool = not r["vampire_only"] or form == null or form.can_feed
		(r["box"] as Control).modulate.a = 1.0 if usable else 0.42
