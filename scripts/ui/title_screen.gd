extends Control
## A small title screen so "Quit to Title" goes somewhere real and playtesters land on something
## friendlier than an open coffin: Play, Controls, Options, Quit. Same components as the pause menu.

const MAIN_SCENE := "res://scenes/main.tscn"

var _list: VBoxContainer
var _play: Button
var _controls_btn: Button
var _options_btn: Button
var _quit_btn: Button
var _controls_panel: ControlsPanel
var _options_panel: OptionsPanel
var _embers: CPUParticles2D
var _t := 0.0
var _title: Label
var _view := 0   # 0 list, 1 controls, 2 options


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	PauseControl.clear()
	var bg := ColorRect.new()
	bg.color = Color(0.015, 0.005, 0.01)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_embers = CPUParticles2D.new()
	_embers.amount = 60
	_embers.lifetime = 9.0
	_embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_embers.direction = Vector2(0, -1)
	_embers.spread = 20.0
	_embers.gravity = Vector2.ZERO
	_embers.initial_velocity_min = 8.0
	_embers.initial_velocity_max = 30.0
	_embers.scale_amount_min = 1.0
	_embers.scale_amount_max = 3.5
	_embers.color = Color(0.85, 0.12, 0.1, 0.35)
	add_child(_embers)
	_layout_embers()
	get_viewport().size_changed.connect(_layout_embers)

	var left := VBoxContainer.new()
	left.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	left.offset_left = 110
	left.offset_right = 470
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override(&"separation", 10)
	add_child(left)
	_title = UiStyle.label("VAMPIRE", 92, Color(0.85, 0.1, 0.14), true, 10)
	_title.add_theme_font_override(&"font", UiStyle.serif_bold())
	left.add_child(_title)
	left.add_child(UiStyle.label("a prototype - Blackthorn Estate", 20, UiStyle.BONE_DIM, true, 3))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 28)
	left.add_child(gap)
	_list = left
	_play = _button("Play", left)
	_controls_btn = _button("Controls", left)
	_options_btn = _button("Options", left)
	_quit_btn = _button("Quit", left)
	_play.pressed.connect(_start)
	_controls_btn.pressed.connect(func(): _show(1))
	_options_btn.pressed.connect(func(): _show(2))
	_quit_btn.pressed.connect(func(): get_tree().quit())
	if OS.has_feature("web"):
		_quit_btn.visible = false
	_controls_btn.focus_entered.connect(func(): if _view == 0: _preview(1))
	_options_btn.focus_entered.connect(func(): if _view == 0: _preview(2))
	_play.focus_entered.connect(func(): if _view == 0: _preview(0))
	_quit_btn.focus_entered.connect(func(): if _view == 0: _preview(0))

	_controls_panel = ControlsPanel.new()
	_controls_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_controls_panel.offset_left = -640
	_controls_panel.offset_right = -30
	_controls_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_controls_panel.visible = false
	add_child(_controls_panel)
	_options_panel = OptionsPanel.new()
	_options_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_options_panel.offset_left = -640
	_options_panel.offset_right = -30
	_options_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_options_panel.visible = false
	_options_panel.back_requested.connect(func(): _show(0))
	add_child(_options_panel)
	_play.grab_focus()


func _button(text: String, parent: Control) -> Button:
	var b := Button.new()
	b.text = text
	UiStyle.style_button(b)
	parent.add_child(b)
	return b


func _layout_embers() -> void:
	var s := get_viewport().get_visible_rect().size
	_embers.position = Vector2(s.x * 0.5, s.y + 10.0)
	_embers.emission_rect_extents = Vector2(s.x * 0.5, 4.0)


func _process(delta: float) -> void:
	_t += delta
	_title.modulate = Color(1, 1, 1, 0.88 + 0.12 * sin(_t * 1.7))
	if Input.is_action_just_pressed(&"ui_cancel") and _view != 0:
		_show(0)


func _show(v: int) -> void:
	_view = v
	_preview(v)
	match v:
		1:
			_controls_btn.grab_focus()
		2:
			_options_panel.focus_first()
		0:
			_play.grab_focus()


func _preview(v: int) -> void:
	_controls_panel.visible = v == 1
	_options_panel.visible = v == 2


func _start() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE)
