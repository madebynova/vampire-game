class_name PauseMenu
extends CanvasLayer
## The pause menu: Resume, Controls, Options, Quit to Title. Opening it freezes the whole simulation
## (PauseControl): NPCs, the clock, sunlight, blood, abilities - nothing advances and no gameplay input
## reaches the game, because every gameplay node stops processing while the tree is paused.
## Navigable with mouse, keyboard (arrows / Enter / Esc) and pad (D-pad or stick / A / B / Menu).
##
## The Controls and Options screens open on the right while the list stays on the left. B / Esc goes
## back one level; from the list it resumes.

signal opened
signal closed

enum View { LIST, CONTROLS, OPTIONS }

var _root: Control
var _list: VBoxContainer
var _resume: Button
var _controls_btn: Button
var _options_btn: Button
var _quit_btn: Button
var _controls_panel: ControlsPanel
var _options_panel: OptionsPanel
var _subtitle: Label
var _open := false
var _view: View = View.LIST
var _prev_mouse_mode := Input.MOUSE_MODE_VISIBLE
var _recapture := true


func _ready() -> void:
	add_to_group(&"pause_menu")
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var left := VBoxContainer.new()
	left.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	left.offset_left = 90
	left.offset_right = 420
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override(&"separation", 10)
	_root.add_child(left)
	var title := UiStyle.label("PAUSED", 56, UiStyle.BONE, true, 8)
	title.add_theme_font_override(&"font", UiStyle.serif_bold())
	left.add_child(title)
	_subtitle = UiStyle.label("", 18, UiStyle.BONE_DIM, true, 3)
	left.add_child(_subtitle)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 18)
	left.add_child(gap)
	_list = left
	_resume = _button("Resume", left)
	_controls_btn = _button("Controls", left)
	_options_btn = _button("Options", left)
	_quit_btn = _button("Quit to Title", left)
	_resume.pressed.connect(close)
	_controls_btn.pressed.connect(func(): _show(View.CONTROLS))
	_options_btn.pressed.connect(func(): _show(View.OPTIONS))
	_quit_btn.pressed.connect(_quit_to_title)
	# Focus on Controls previews them on the right (handy with a pad).
	_controls_btn.focus_entered.connect(func(): if _view == View.LIST: _preview(View.CONTROLS))
	_options_btn.focus_entered.connect(func(): if _view == View.LIST: _preview(View.OPTIONS))
	_resume.focus_entered.connect(func(): if _view == View.LIST: _preview(View.LIST))
	_quit_btn.focus_entered.connect(func(): if _view == View.LIST: _preview(View.LIST))
	for b in [_resume, _controls_btn, _options_btn, _quit_btn]:
		b.focus_entered.connect(func(): if _open: Sfx.play(&"ui_move", -10.0))

	_controls_panel = ControlsPanel.new()
	_controls_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_controls_panel.offset_left = -640
	_controls_panel.offset_right = -30
	_controls_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_controls_panel.visible = false
	_root.add_child(_controls_panel)
	_options_panel = OptionsPanel.new()
	_options_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_options_panel.offset_left = -640
	_options_panel.offset_right = -30
	_options_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_options_panel.visible = false
	_options_panel.back_requested.connect(func(): _show(View.LIST))
	_root.add_child(_options_panel)


func _button(text: String, parent: Control) -> Button:
	var b := Button.new()
	b.text = text
	UiStyle.style_button(b)
	parent.add_child(b)
	return b


# ---------------------------------------------------------------- open / close

func is_open() -> bool:
	return _open


func current_view() -> View:
	return _view


func _process(_delta: float) -> void:
	var toggle := Input.is_action_just_pressed(&"pause")
	var back := Input.is_action_just_pressed(&"ui_cancel")
	if not _open:
		if toggle and _can_open():
			open()
		return
	if toggle or back:
		_back()


func _can_open() -> bool:
	var mv := get_tree().get_first_node_in_group(&"memory_view") as MemoryView
	if mv and mv.is_open():
		return false   # a Blood Memory is its own held moment
	if PauseControl.has_reason(&"rest"):
		return false   # the coffin's own question is open
	var rest := get_tree().get_first_node_in_group(&"rest_menu") as RestMenu
	if rest != null and rest.closed_this_frame():
		return false   # ...and the Esc that just closed it is not also a request to pause
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player and (player.state.is_dead() or player.state.mode == PlayerState.Mode.RESTING):
		return false
	return not PauseControl.has_reason(&"menu")


func open() -> void:
	if _open:
		return
	_open = true
	_view = View.LIST
	_prev_mouse_mode = Input.mouse_mode
	PauseControl.request(&"menu")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var tod := get_tree().get_first_node_in_group(&"time_of_day") as TimeOfDay
	_subtitle.text = "%s" % (tod.clock_text_12h() if tod else "")
	_root.visible = true
	_controls_panel.visible = false
	_options_panel.visible = false
	_controls_panel.refresh_form((get_tree().get_first_node_in_group(&"player") as Player).form.current if get_tree().get_first_node_in_group(&"player") else null)
	# The world stays audible but far away.
	AudioBuses.set_muffle(AudioBuses.AMBIENCE, 0.6)
	AudioBuses.set_muffle(AudioBuses.EFFECTS, 0.35)
	AudioBuses.set_muffle(AudioBuses.MUSIC, 0.35)
	Sfx.play(&"ui_confirm", -8.0)
	var hud := get_tree().get_first_node_in_group(&"hud") as Hud
	if hud:
		hud.set_dimmed(true)   # the menu has its own controls screen; don't ghost the HUD's behind it
	_resume.grab_focus()
	opened.emit()


func close() -> void:
	if not _open:
		return
	_open = false
	_root.visible = false
	AudioBuses.set_muffle(AudioBuses.AMBIENCE, 0.0)
	AudioBuses.set_muffle(AudioBuses.EFFECTS, 0.0)
	AudioBuses.set_muffle(AudioBuses.MUSIC, 0.0)
	Sfx.play(&"ui_back", -8.0)
	var hud := get_tree().get_first_node_in_group(&"hud") as Hud
	if hud:
		hud.set_dimmed(false)
	PauseControl.release(&"menu")
	var main := get_tree().current_scene as Main
	if main == null or main.capture_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = _prev_mouse_mode
	closed.emit()


func _back() -> void:
	if _view == View.LIST:
		close()
	else:
		_show(View.LIST)
		Sfx.play(&"ui_back", -8.0)


func _show(v: View) -> void:
	var prev := _view
	_view = v
	_preview(v)
	match v:
		View.CONTROLS:
			_controls_btn.grab_focus()
		View.OPTIONS:
			_options_panel.focus_first()
		View.LIST:
			# Return focus to whichever entry led here.
			match prev:
				View.OPTIONS:
					_options_btn.grab_focus()
				View.CONTROLS:
					_controls_btn.grab_focus()
				_:
					_resume.grab_focus()


func _preview(v: View) -> void:
	_controls_panel.visible = v == View.CONTROLS
	_options_panel.visible = v == View.OPTIONS


func _quit_to_title() -> void:
	PauseControl.clear()
	AudioBuses.set_muffle(AudioBuses.AMBIENCE, 0.0)
	AudioBuses.set_muffle(AudioBuses.EFFECTS, 0.0)
	AudioBuses.set_muffle(AudioBuses.MUSIC, 0.0)
	Sfx.stop_all_loops()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_open = false
	get_tree().change_scene_to_file("res://scenes/title.tscn")
