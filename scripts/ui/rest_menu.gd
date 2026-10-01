class_name RestMenu
extends CanvasLayer
## The coffin's "when will you wake?" choice: a short list (RestOption data, hours slept shown) with the
## old behaviour - sleep until dusk - first and focused, so a single press does what the coffin always did.
## The world is frozen while it is open (PauseControl, reason "rest"). Arrows / D-pad / stick to move,
## Enter / A to choose, Esc / B to stay awake.

signal chosen(option: RestOption)
signal cancelled

var _root: Control
var _list: VBoxContainer
var _subtitle: Label
var _buttons: Array[Button] = []
var _hint: HBoxContainer
var _options: Array[RestOption] = []
var _open := false
var _closed_frame := -1
var _prev_mouse_mode := Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	add_to_group(&"rest_menu")
	layer = 26
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.58)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	_list = VBoxContainer.new()
	_list.set_anchors_preset(Control.PRESET_CENTER)
	_list.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_list.grow_vertical = Control.GROW_DIRECTION_BOTH
	_list.alignment = BoxContainer.ALIGNMENT_CENTER
	_list.add_theme_constant_override(&"separation", 10)
	_root.add_child(_list)
	var title := UiStyle.label("REST", 52, UiStyle.BONE, true, 8)
	title.add_theme_font_override(&"font", UiStyle.serif_bold())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_list.add_child(title)
	_subtitle = UiStyle.label("", 20, UiStyle.BONE_DIM, true, 4)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_list.add_child(_subtitle)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 14)
	_list.add_child(gap)
	# How to answer, in the real buttons of whatever you are holding.
	_hint = HBoxContainer.new()
	_hint.alignment = BoxContainer.ALIGNMENT_CENTER
	_hint.add_theme_constant_override(&"separation", 10)
	_hint.add_child(InputGlyph.new(&"ui_accept"))
	_hint.add_child(UiStyle.label("Choose", 18, UiStyle.BONE, true, 4))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(24, 0)
	_hint.add_child(spacer)
	_hint.add_child(InputGlyph.new(&"ui_cancel"))
	_hint.add_child(UiStyle.label("Stay awake", 18, UiStyle.BONE, true, 4))
	_root.visible = false


func is_open() -> bool:
	return _open


## It closed during the frame being processed (so the same key press that closed it must not also open
## the pause menu: Esc is both "stay awake" here and "pause" there).
func closed_this_frame() -> bool:
	return _closed_frame == Engine.get_process_frames()


## The options currently listed (those far enough ahead to be worth sleeping for).
func options() -> Array[RestOption]:
	return _options


func _process(_delta: float) -> void:
	if _open and Input.is_action_just_pressed(&"ui_cancel"):
		close(true)


## Offer the choices for the time it is now. Options less than an hour ahead are not offered.
func open(tod: TimeOfDay) -> void:
	if _open:
		return
	for b in _buttons:
		b.queue_free()
	_buttons.clear()
	_options.clear()
	var all: Array = tod.profile.rest_options if tod.profile != null and not tod.profile.rest_options.is_empty() else RestOption.defaults()
	for o in all:
		var hours := tod.hours_until(o.hour)
		if hours < 1.0:
			continue
		_options.append(o)
		var b := Button.new()
		b.text = "%s   ·   %s   ·   about %d h" % [o.label, TimeOfDay.format_12h(o.hour), maxi(1, roundi(hours))]
		UiStyle.style_button(b)
		b.custom_minimum_size = Vector2(520, 54)
		b.pressed.connect(func(): _choose(o))
		b.focus_entered.connect(func(): if _open: Sfx.play(&"ui_move", -10.0))
		_list.add_child(b)
		_buttons.append(b)
	var stay := Button.new()
	stay.text = "Stay awake"
	UiStyle.style_button(stay)
	stay.custom_minimum_size = Vector2(520, 54)
	stay.pressed.connect(func(): close(true))
	stay.focus_entered.connect(func(): if _open: Sfx.play(&"ui_move", -10.0))
	_list.add_child(stay)
	_buttons.append(stay)
	if _hint.get_parent() != null:
		_hint.get_parent().remove_child(_hint)
	_list.add_child(_hint)
	_subtitle.text = "It is %s. When will you wake?" % tod.clock_text_12h()
	_open = true
	_prev_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	PauseControl.request(&"rest")
	var hud := get_tree().get_first_node_in_group(&"hud") as Hud
	if hud:
		hud.set_dimmed(true)
	_root.visible = true
	Sfx.play(&"ui_confirm", -8.0)
	_buttons[0].grab_focus()


func _choose(o: RestOption) -> void:
	if not _open:
		return
	close(false)
	chosen.emit(o)


func close(was_cancel: bool) -> void:
	if not _open:
		return
	_open = false
	_closed_frame = Engine.get_process_frames()
	_root.visible = false
	var hud := get_tree().get_first_node_in_group(&"hud") as Hud
	if hud:
		hud.set_dimmed(false)
	PauseControl.release(&"rest")
	var main := get_tree().current_scene as Main
	if main == null or main.capture_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = _prev_mouse_mode
	if was_cancel:
		Sfx.play(&"ui_back", -8.0)
		cancelled.emit()
