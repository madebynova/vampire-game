class_name MemoryView
extends CanvasLayer
## A Blood Memory, experienced rather than read off a popup.
##
## The moment a feed completes the world FREEZES (PauseControl) and the victim's memory intrudes:
## the picture drains into the memory's colour and dims, the room's sound is pushed away and a
## procedural bed plays underneath (calm = warm and quiet, asleep = a slow music box, afraid =
## dissonant, torn, a racing heart). A title, a line about how it arrived, then the memory itself
## is told a few characters at a time with breaths at punctuation, then what you learned.
##
## Readability rules (tested): nothing dismisses it until you have had time to read - the
## intro plays, the text is told - and there is NO timeout. Only a deliberate input dismisses it
## (E / Space / Enter / click, pad A / B / X), and the input still held from the feed cannot: the
## dismiss actions must be seen RELEASED after the memory opened before any press counts. A press
## during the telling completes the text instead of closing; closing needs another press.

signal opened
signal closed

## The intro plays this long before the text begins to be told.
@export var intro_time := 2.4
## Nothing can dismiss it before this many seconds (the intro).
@export var arm_time := 2.6
## Base reveal speed, characters per second (style.memory_pace multiplies it).
@export var chars_per_second := 34.0
## After the text is complete, how long before closing is allowed.
@export var hold_after_text := 1.2
@export var fade_in := 0.9
@export var fade_out := 0.8

var player: Player
var result: Dictionary = {}
var style: FeedStyle

var _open := false
var _age := 0.0
var _armed := false
var _released_seen := false
var _chars := 0.0
var _total_chars := 0
var _pause_left := 0.0
var _text_done_at := -1.0
var _skip_lock := 0.0
var _closing := false
var _beat_t := 0.0
var _frag_t := 0.0
var _body_base_x := 0.0
var _tween: Tween
var _saved_fov := 0.0
var _saved_dim := 0.0

var _root: Control
var _backing: TextureRect
var _column: VBoxContainer
var _kicker: Label
var _frame: Label
var _title: Label
var _body: Label
var _facts: VBoxContainer
var _meta: Label
var _prompt_row: HBoxContainer
var _prompt_label: Label
var _glyph: InputGlyph
var _dust: CPUParticles2D


func _ready() -> void:
	add_to_group(&"memory_view")
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP   # swallows clicks while open
	add_child(_root)

	# A dark rise from the bottom edge keeps the words readable over any scene, and leaves the
	# victim's face visible above them.
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.0))
	grad.set_color(1, Color(0.01, 0.0, 0.01, 0.92))
	grad.add_point(0.45, Color(0, 0, 0, 0.55))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 256
	_backing = TextureRect.new()
	_backing.texture = gt
	_backing.stretch_mode = TextureRect.STRETCH_SCALE
	_backing.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backing.anchor_top = 0.22
	_backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_backing)

	_dust = CPUParticles2D.new()
	_dust.amount = 40
	_dust.lifetime = 7.0
	_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_dust.direction = Vector2(0, -1)
	_dust.spread = 25.0
	_dust.gravity = Vector2.ZERO
	_dust.initial_velocity_min = 6.0
	_dust.initial_velocity_max = 22.0
	_dust.scale_amount_min = 1.0
	_dust.scale_amount_max = 3.0
	_dust.color = Color(1, 1, 1, 0.25)
	_dust.emitting = false
	_root.add_child(_dust)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.anchor_top = 0.3
	center.offset_bottom = -26
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	_column = VBoxContainer.new()
	_column.custom_minimum_size = Vector2(760, 0)
	_column.add_theme_constant_override(&"separation", 8)
	center.add_child(_column)

	_kicker = UiStyle.label("BLOOD MEMORY", 15, UiStyle.BLOOD_BRIGHT)
	_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(_kicker)
	_frame = UiStyle.label("", 18, UiStyle.BONE_DIM, true, 3)
	_frame.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_frame.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_column.add_child(_frame)
	_title = UiStyle.label("", 34, UiStyle.BONE, true, 6)
	_title.add_theme_font_override(&"font", UiStyle.serif_bold())
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_column.add_child(_title)
	_body = UiStyle.label("", 21, Color(0.98, 0.94, 0.9), true, 5)
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(740, 0)
	_body.add_theme_constant_override(&"line_spacing", 6)
	_column.add_child(_body)
	_facts = VBoxContainer.new()
	_facts.add_theme_constant_override(&"separation", 3)
	_column.add_child(_facts)
	_meta = UiStyle.label("", 16, UiStyle.BONE_DIM, false, 3)
	_meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_column.add_child(_meta)

	_prompt_row = HBoxContainer.new()
	_prompt_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_prompt_row.add_theme_constant_override(&"separation", 10)
	_column.add_child(_prompt_row)
	_glyph = InputGlyph.new(&"memory_dismiss")
	_prompt_row.add_child(_glyph)
	_prompt_label = UiStyle.label("Continue", 18, UiStyle.BONE, true, 4)
	_prompt_row.add_child(_prompt_label)


# ---------------------------------------------------------------- public

func is_open() -> bool:
	return _open


func title_text() -> String:
	return _title.text


func body_text() -> String:
	return _body.text


## True once a press would close it (text told, held long enough, input released and re-pressed).
func can_dismiss() -> bool:
	return _open and _armed and _released_seen and _text_done_at >= 0.0 and _age - _text_done_at >= hold_after_text and _skip_lock <= 0.0


func text_complete() -> bool:
	return _text_done_at >= 0.0


func seconds_open() -> float:
	return _age


## Begin a memory for a finished feed. `feed_result` is the dictionary FeedingController emits.
func present(p: Player, feed_result: Dictionary) -> void:
	if _open:
		force_close()
	player = p
	result = feed_result
	style = feed_result.get("style", null) as FeedStyle
	if style == null:
		style = ContentRegistry.get_def(&"FeedStyle", &"calm") as FeedStyle
	_open = true
	_closing = false
	_age = 0.0
	_armed = false
	_released_seen = false
	_chars = 0.0
	_pause_left = 0.0
	_text_done_at = -1.0
	_skip_lock = 0.0
	_beat_t = 0.5
	_fill_text()
	_root.visible = true
	_root.modulate.a = 0.0
	for n in [_kicker, _frame, _title, _body, _facts, _meta, _prompt_row]:
		n.modulate.a = 0.0
	_body.visible_characters = 0
	_body_base_x = _body.position.x
	_dust.position = Vector2(0, get_viewport().get_visible_rect().size.y)
	_dust.emission_rect_extents = Vector2(get_viewport().get_visible_rect().size.x * 0.5, 4)
	_dust.position.x = get_viewport().get_visible_rect().size.x * 0.5
	_dust.color = Color(style.memory_tint.r, style.memory_tint.g, style.memory_tint.b, 0.28)
	_dust.emitting = true

	PauseControl.request(&"memory")
	player.state.set_mode(PlayerState.Mode.MEMORY)
	player.abilities.deactivate_all()
	# The world drains into the memory's colour.
	var fx := get_tree().get_first_node_in_group(&"screen_fx") as ScreenFX
	if fx:
		fx.memory_tint = style.memory_tint
		fx.memory_fragmentation = style.memory_fragmentation
		fx.memory_target = 1.0
		fx.memory_dim_target = 1.0
		fx.feed_target = 0.0
		fx.flash(style.memory_tint.lightened(0.45), 0.85, 2.6)
	var hud := get_tree().get_first_node_in_group(&"hud") as Hud
	if hud:
		hud.set_dimmed(true)
	# Sound: the room recedes, the memory's own bed rises.
	AudioBuses.set_muffle(AudioBuses.AMBIENCE, 0.8)
	AudioBuses.set_muffle(AudioBuses.EFFECTS, 0.5)
	Sfx.play(&"memory", -3.0)
	Sfx.start_loop(style.memory_bed, -60.0)
	Haptics.pulse(0.2, 0.7, 0.3)
	# Slow camera drift toward the victim's face while the memory is told.
	var cam := player.camera_rig.camera
	_saved_fov = cam.fov
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_root, "modulate:a", 1.0, fade_in)
	_tween.tween_property(cam, "fov", maxf(_saved_fov - 14.0, 34.0), 22.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_method(func(db: float): Sfx.set_loop_volume(style.memory_bed, db), -60.0, -12.0, 2.2)
	# The intro: each line surfaces in turn.
	_reveal(_kicker, 0.5)
	_reveal(_frame, 1.0)
	_reveal(_title, 1.5)
	_reveal(_body, 1.9, 0.3)
	opened.emit()


## Leave at once (death, tests, scene change). Restores everything.
func force_close() -> void:
	if not _open:
		return
	_finish()


# ---------------------------------------------------------------- build the text

func _fill_text() -> void:
	_title.text = str(result.get("title", "A Memory"))
	_frame.text = style.memory_frame
	_body.text = str(result.get("memory", ""))
	_total_chars = _body.text.length()
	for c in _facts.get_children():
		c.queue_free()
	for fact in result.get("facts", PackedStringArray()):
		var l := UiStyle.label("·  %s" % fact, 17, Color(1.0, 0.86, 0.6), false, 3)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.modulate.a = 0.0
		_facts.add_child(l)
	var first_time: bool = result.get("first_time", true)
	var bits := PackedStringArray()
	bits.append("%s, %s" % [result.get("name", ""), str(result.get("occupation", "")).to_lower()])
	bits.append("%s blood" % result.get("blood_type", ""))
	bits.append("+%d blood" % roundi(float(result.get("yield", 0.0))))
	if float(result.get("surge_seconds", 0.0)) > 0.0:
		bits.append("%s  %d:%02d" % [result.get("surge_name", "Bloodrush"), int(result["surge_seconds"]) / 60, int(result["surge_seconds"]) % 60])
	_meta.text = "  ·  ".join(bits) + ("" if first_time else "  ·  a memory you have tasted before")
	_prompt_label.text = "Continue"
	_glyph.refresh()


func _reveal(node: CanvasItem, delay: float, _unused := 0.0) -> void:
	_tween.tween_property(node, "modulate:a", 1.0, 0.8).set_delay(delay)


# ---------------------------------------------------------------- per frame

func _process(delta: float) -> void:
	if not _open:
		return
	_age += delta
	_skip_lock = maxf(_skip_lock - delta, 0.0)
	# The release gate: the input that started this (the held feed key) must be let go first.
	if not _any_dismiss_held():
		_released_seen = true
	if _age >= arm_time:
		_armed = true
	_tell(delta)
	_heart(delta)
	_fragment(delta)
	# The prompt appears only once a press would actually do something.
	var ready := can_dismiss()
	_prompt_row.modulate.a = lerpf(_prompt_row.modulate.a, 1.0 if ready else 0.0, 1.0 - exp(-6.0 * delta))
	if ready:
		_prompt_label.modulate.a = 0.75 + 0.25 * sin(_age * 4.0)
	if _closing:
		return
	if _armed and _released_seen and _dismiss_pressed():
		if _text_done_at < 0.0:
			_complete_text()          # first press: finish the telling
		elif can_dismiss():
			dismiss()


func _any_dismiss_held() -> bool:
	return Input.is_action_pressed(&"memory_dismiss") or Input.is_action_pressed(&"ui_accept") \
		or Input.is_action_pressed(&"ui_cancel") or Input.is_action_pressed(&"interact") or Input.is_action_pressed(&"feed")


func _dismiss_pressed() -> bool:
	return Input.is_action_just_pressed(&"memory_dismiss") or Input.is_action_just_pressed(&"ui_accept") \
		or Input.is_action_just_pressed(&"ui_cancel")


## Reveal the text a few characters at a time, breathing at punctuation.
func _tell(delta: float) -> void:
	if _text_done_at >= 0.0 or _age < intro_time:
		return
	if _pause_left > 0.0:
		_pause_left -= delta
		return
	var pace := maxf(style.memory_pace, 0.2)
	var before := int(_chars)
	_chars += chars_per_second * pace * delta
	var after := mini(int(_chars), _total_chars)
	# A breath after a stop.
	for i in range(before, after):
		var ch := _body.text[i]
		if ch == "." or ch == "!" or ch == "?":
			_pause_left = maxf(_pause_left, 0.42 / pace)
		elif ch == "," or ch == ";" or ch == ":":
			_pause_left = maxf(_pause_left, 0.16 / pace)
		elif ch == "\n":
			_pause_left = maxf(_pause_left, 0.7 / pace)
		if _pause_left > 0.0:
			after = i + 1
			_chars = float(after)
			break
	_body.visible_characters = after
	if after >= _total_chars:
		_complete_text(false)


func _complete_text(skipped := true) -> void:
	_chars = float(_total_chars)
	_body.visible_characters = -1
	_text_done_at = _age
	if skipped:
		_skip_lock = 0.7
	var tw := create_tween().set_parallel(true)
	var i := 0
	for f in _facts.get_children():
		tw.tween_property(f, "modulate:a", 1.0, 0.6).set_delay(0.3 + 0.45 * i)
		i += 1
	tw.tween_property(_facts, "modulate:a", 1.0, 0.1)
	tw.tween_property(_meta, "modulate:a", 1.0, 0.8).set_delay(0.4 + 0.45 * i)


## The memory has a pulse of its own: slow and warm, slower and deeper asleep, sharp and quick in fear.
func _heart(delta: float) -> void:
	_beat_t -= delta
	if _beat_t > 0.0:
		return
	var id := style.id if style else &"calm"
	var gap := 1.25
	var snd := &"heartbeat"
	var vol := -17.0
	match id:
		&"asleep":
			gap = 1.8
			snd = &"heartbeat_deep"
			vol = -16.0
		&"afraid":
			gap = 0.46
			snd = &"heartbeat_sharp"
			vol = -12.0
	_beat_t = gap
	Sfx.play(snd, vol)
	var fx := get_tree().get_first_node_in_group(&"screen_fx") as ScreenFX
	if fx:
		fx.beat()
		fx.pulse_strength_target = 0.6 if id == &"afraid" else 0.25


## Terror comes apart: the text trembles and the lines jump.
func _fragment(delta: float) -> void:
	if style == null or style.memory_fragmentation <= 0.0:
		return
	_frag_t -= delta
	if _frag_t > 0.0:
		return
	_frag_t = 0.08
	_body.position.x = _body_base_x + randf_range(-1.0, 1.0) * 2.4 * style.memory_fragmentation
	_title.position.x = randf_range(-1.0, 1.0) * 1.8 * style.memory_fragmentation


# ---------------------------------------------------------------- closing

## Close deliberately (the player asked to). Ignores the call unless allowed.
func dismiss() -> bool:
	if not can_dismiss() or _closing:
		return false
	_closing = true
	Sfx.play(&"ui_confirm", -6.0)
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_root, "modulate:a", 0.0, fade_out)
	_tween.tween_method(func(db: float): Sfx.set_loop_volume(style.memory_bed, db), -12.0, -60.0, fade_out)
	var fx := get_tree().get_first_node_in_group(&"screen_fx") as ScreenFX
	if fx:
		fx.memory_target = 0.0
		fx.memory_dim_target = 0.0
	_tween.chain().tween_callback(_finish)
	return true


func _finish() -> void:
	if not _open:
		return
	_open = false
	_closing = false
	if _tween:
		_tween.kill()
	Sfx.stop_loop(style.memory_bed if style else &"memory_calm")
	_dust.emitting = false
	_root.visible = false
	_body.position.x = _body_base_x
	_title.position.x = 0.0
	AudioBuses.set_muffle(AudioBuses.AMBIENCE, 0.0)
	AudioBuses.set_muffle(AudioBuses.EFFECTS, 0.0)
	var fx := get_tree().get_first_node_in_group(&"screen_fx") as ScreenFX
	if fx:
		fx.memory_target = 0.0
		fx.memory_dim_target = 0.0
		fx.pulse_strength_target = 0.0
	var hud := get_tree().get_first_node_in_group(&"hud") as Hud
	if hud:
		hud.set_dimmed(false)
	if player:
		player.camera_rig.camera.fov = _saved_fov
		if player.state.mode == PlayerState.Mode.MEMORY:
			player.state.set_mode(PlayerState.Mode.NORMAL)
	PauseControl.release(&"memory")
	closed.emit()
