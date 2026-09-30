class_name OptionsPanel
extends PanelContainer
## The prototype options: four volumes, two look sensitivities, vibration, fullscreen. Every
## control is reachable with mouse, keyboard and pad (focus navigation; left/right adjusts a slider).
## Values live in GameSettings, which saves and applies them immediately.

signal back_requested

var _first: Control
var _sliders: Dictionary = {}    ## option key -> HSlider
var _toggles: Dictionary = {}    ## option key -> CheckButton
var _value_labels: Dictionary = {}
var _last_tick := 0.0


func _ready() -> void:
	theme = _make_theme()
	add_theme_stylebox_override(&"panel", UiStyle.panel_style(Color(0.03, 0.015, 0.02, 0.9), Color(0.55, 0.1, 0.16, 0.6), 12, 24))
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	add_child(box)
	box.add_child(UiStyle.label("OPTIONS", 28, UiStyle.BONE, true, 4))
	box.add_child(_section("SOUND"))
	_slider(box, &"master_volume", "Master volume", 0.0, 1.0, false)
	_slider(box, &"effects_volume", "Effects", 0.0, 1.0, false)
	_slider(box, &"ambience_volume", "Ambience", 0.0, 1.0, false)
	_slider(box, &"music_volume", "Music (Blood Memories)", 0.0, 1.0, false)
	box.add_child(_section("CONTROLS"))
	_slider(box, &"mouse_sensitivity", "Mouse sensitivity", 0.25, 2.5, true)
	_slider(box, &"stick_sensitivity", "Controller look speed", 0.25, 2.5, true)
	_toggle(box, &"vibration", "Controller vibration")
	box.add_child(_section("DISPLAY"))
	_toggle(box, &"fullscreen", "Fullscreen")
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	box.add_child(row)
	var reset := Button.new()
	reset.text = "Reset to defaults"
	UiStyle.style_button(reset)
	reset.add_theme_font_size_override(&"font_size", 20)
	reset.custom_minimum_size = Vector2(220, 44)
	reset.pressed.connect(func():
		GameSettings.reset_defaults()
		_sync())
	row.add_child(reset)
	var back := Button.new()
	back.text = "Back"
	UiStyle.style_button(back)
	back.add_theme_font_size_override(&"font_size", 20)
	back.custom_minimum_size = Vector2(140, 44)
	back.pressed.connect(func(): back_requested.emit())
	row.add_child(back)
	_sync()


func focus_first() -> void:
	if _first:
		_first.grab_focus()


func _section(text: String) -> Label:
	var l := UiStyle.label(text, 13, UiStyle.BLOOD_BRIGHT, false, 2)
	l.custom_minimum_size = Vector2(0, 22)
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return l


func _slider(parent: Control, key: StringName, text: String, lo: float, hi: float, as_multiplier: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	var l := UiStyle.label(text, 18, UiStyle.BONE, false, 3)
	l.custom_minimum_size = Vector2(235, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05 if as_multiplier else 0.01
	s.custom_minimum_size = Vector2(200, 30)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_ALL
	row.add_child(s)
	var v := UiStyle.label("", 18, UiStyle.BONE_DIM, false, 3)
	v.custom_minimum_size = Vector2(60, 0)
	row.add_child(v)
	parent.add_child(row)
	s.value_changed.connect(func(val: float):
		GameSettings.set_option(key, val)
		v.text = ("x%.2f" % val) if as_multiplier else ("%d%%" % roundi(val * 100.0))
		_tick())
	_sliders[key] = s
	_value_labels[key] = [v, as_multiplier]
	if _first == null:
		_first = s


func _toggle(parent: Control, key: StringName, text: String) -> void:
	var c := CheckButton.new()
	c.text = text
	c.add_theme_font_size_override(&"font_size", 19)
	c.focus_mode = Control.FOCUS_ALL
	c.toggled.connect(func(on: bool):
		GameSettings.set_option(key, on)
		_tick())
	parent.add_child(c)
	_toggles[key] = c


func _tick() -> void:
	# A quiet click as sliders move, at most ~12 per second.
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_tick > 0.08:
		_last_tick = now
		Sfx.play(&"ui_move", -10.0)


## Pull every control's value from GameSettings (after reset or when first shown).
func _sync() -> void:
	for key in _sliders:
		var s: HSlider = _sliders[key]
		s.set_value_no_signal(float(GameSettings.get(String(key))))
		var info: Array = _value_labels[key]
		(info[0] as Label).text = ("x%.2f" % s.value) if info[1] else ("%d%%" % roundi(s.value * 100.0))
	for key in _toggles:
		(_toggles[key] as CheckButton).set_pressed_no_signal(bool(GameSettings.get(String(key))))


func _make_theme() -> Theme:
	var th := Theme.new()
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.12, 0.07, 0.08, 0.95)
	track.set_corner_radius_all(3)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiStyle.BLOOD
	fill.set_corner_radius_all(3)
	fill.content_margin_top = 5
	fill.content_margin_bottom = 5
	var fill_hi := fill.duplicate() as StyleBoxFlat
	fill_hi.bg_color = UiStyle.BLOOD_BRIGHT
	th.set_stylebox(&"slider", &"HSlider", track)
	th.set_stylebox(&"grabber_area", &"HSlider", fill)
	th.set_stylebox(&"grabber_area_highlight", &"HSlider", fill_hi)
	th.set_color(&"font_color", &"CheckButton", UiStyle.BONE)
	th.set_color(&"font_hover_color", &"CheckButton", UiStyle.BONE)
	th.set_color(&"font_focus_color", &"CheckButton", UiStyle.GOLD)
	th.set_color(&"font_pressed_color", &"CheckButton", UiStyle.BONE)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0.3, 0.04, 0.08, 0.45)
	focus.border_color = UiStyle.BLOOD_BRIGHT
	focus.set_border_width_all(1)
	focus.set_corner_radius_all(5)
	th.set_stylebox(&"focus", &"CheckButton", focus)
	th.set_stylebox(&"focus", &"HSlider", focus)
	return th
