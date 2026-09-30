class_name Hud
extends CanvasLayer
## Prototype HUD, built in code. Presentation only: reads player components, never drives them.

const OUTLINE := Color(0, 0, 0, 0.9)

var player: Player

var _root: Control
var _form_label: Label
var _tagline: Label
var _health_bar: ProgressBar
var _blood_bar: ProgressBar
var _status_label: Label
var _sense_label: Label
var _sun_box: VBoxContainer
var _sun_label: Label
var _sun_bar: ProgressBar
var _prompt_box: VBoxContainer
var _prompt_label: Label
var _prompt_bar: ProgressBar
var _toast_label: Label
var _toast_tween: Tween
var _banner: Label
var _help: Label
var _debug: Label
var _clock: Label
var _tod: TimeOfDay
var _memory_panel: PanelContainer
var _memory_title: Label
var _memory_body: Label
var _memory_meta: Label
var _memory_time := 0.0
var _memory_age := 0.0
var _memory_tween: Tween

signal memory_closed


func _ready() -> void:
	add_to_group(&"hud")
	layer = 10
	_build()


# ---------------------------------------------------------------- construction

func _label(text: String, size: int, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	l.add_theme_color_override(&"font_outline_color", OUTLINE)
	l.add_theme_constant_override(&"outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _bar(fill: Color, width := 280.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(width, 14)
	b.max_value = 100.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bg.set_corner_radius_all(3)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(3)
	b.add_theme_stylebox_override(&"background", bg)
	b.add_theme_stylebox_override(&"fill", fg)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Top-left: form, vitality, blood.
	var tl := VBoxContainer.new()
	tl.position = Vector2(22, 16)
	tl.add_theme_constant_override(&"separation", 4)
	_root.add_child(tl)
	_form_label = _label("HUMAN", 34)
	tl.add_child(_form_label)
	_tagline = _label("", 15, Color(0.8, 0.8, 0.8))
	tl.add_child(_tagline)
	tl.add_child(_label("VITALITY", 13, Color(0.85, 0.85, 0.85)))
	_health_bar = _bar(Color(0.85, 0.85, 0.8))
	tl.add_child(_health_bar)
	tl.add_child(_label("BLOOD", 13, Color(0.9, 0.5, 0.5)))
	_blood_bar = _bar(Color(0.75, 0.05, 0.1))
	tl.add_child(_blood_bar)
	_status_label = _label("", 15, Color(1.0, 0.6, 0.5))
	tl.add_child(_status_label)
	_sense_label = _label("VAMPIRIC SENSE", 18, Color(1.0, 0.25, 0.3))
	_sense_label.visible = false
	tl.add_child(_sense_label)

	# Top-centre: sunlight danger.
	_sun_box = VBoxContainer.new()
	_sun_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_sun_box.position = Vector2(-220, 18)
	_sun_box.custom_minimum_size = Vector2(440, 0)
	_sun_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_sun_box.visible = false
	_root.add_child(_sun_box)
	_sun_label = _label("", 24)
	_sun_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sun_box.add_child(_sun_label)
	_sun_bar = _bar(Color(1.0, 0.7, 0.2), 440.0)
	_sun_box.add_child(_sun_bar)

	# Centre: crosshair.
	var dot := ColorRect.new()
	dot.color = Color(1, 1, 1, 0.55)
	dot.custom_minimum_size = Vector2(4, 4)
	dot.set_anchors_preset(Control.PRESET_CENTER)
	dot.position = Vector2(-2, -2)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dot)

	# Bottom-centre: interaction prompt.
	_prompt_box = VBoxContainer.new()
	_prompt_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_box.position = Vector2(-200, -170)
	_prompt_box.custom_minimum_size = Vector2(400, 0)
	_prompt_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_prompt_box.visible = false
	_root.add_child(_prompt_box)
	_prompt_label = _label("", 24)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_box.add_child(_prompt_label)
	_prompt_bar = _bar(Color(0.9, 0.1, 0.15), 400.0)
	_prompt_box.add_child(_prompt_bar)

	# Toast + banner.
	_toast_label = _label("", 22)
	_toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_label.position = Vector2(-380, 120)
	_toast_label.custom_minimum_size = Vector2(760, 0)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_label.modulate.a = 0.0
	_root.add_child(_toast_label)

	_banner = _label("", 64, Color(0.95, 0.15, 0.15))
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.position = Vector2(-450, -60)
	_banner.custom_minimum_size = Vector2(900, 0)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.modulate.a = 0.0
	_root.add_child(_banner)

	# Bottom-left controls.
	_help = _label(
		"WASD move    Shift run    Space jump    Mouse look\n"
		+ "F  transform  (Human <-> Vampire)\n"
		+ "Q  Vampiric Sense  (Vampires only)\n"
		+ "E  interact - as a Vampire, HOLD E on a human to feed\n"
		+ "Esc free mouse    H hide this    F3 debug", 15, Color(0.85, 0.85, 0.85))
	_help.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_help.position = Vector2(22, -130)
	_root.add_child(_help)

	_clock = _label("", 22, Color(0.95, 0.9, 0.8))
	_clock.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_clock.position = Vector2(-250, 14)
	_clock.custom_minimum_size = Vector2(230, 0)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(_clock)

	_debug = _label("", 14, Color(0.7, 1.0, 0.7))
	_debug.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_debug.position = Vector2(-330, 80)
	_debug.visible = false
	_root.add_child(_debug)

	_build_memory_panel()


func _build_memory_panel() -> void:
	_memory_panel = PanelContainer.new()
	_memory_panel.set_anchors_preset(Control.PRESET_CENTER)
	_memory_panel.position = Vector2(-340, -190)
	_memory_panel.custom_minimum_size = Vector2(680, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.01, 0.03, 0.88)
	sb.border_color = Color(0.75, 0.08, 0.14)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(22)
	_memory_panel.add_theme_stylebox_override(&"panel", sb)
	_memory_panel.visible = false
	_root.add_child(_memory_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	_memory_panel.add_child(box)
	box.add_child(_label("BLOOD MEMORY", 14, Color(0.8, 0.3, 0.35)))
	_memory_title = _label("", 30, Color(1.0, 0.85, 0.85))
	box.add_child(_memory_title)
	_memory_body = _label("", 19, Color(0.95, 0.9, 0.9))
	_memory_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_memory_body.custom_minimum_size = Vector2(630, 0)
	box.add_child(_memory_body)
	_memory_meta = _label("", 17, Color(1.0, 0.7, 0.7))
	_memory_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_memory_meta.custom_minimum_size = Vector2(630, 0)
	box.add_child(_memory_meta)
	box.add_child(_label("[E] dismiss", 14, Color(0.7, 0.7, 0.7)))


# ---------------------------------------------------------------- binding

func bind(p: Player) -> void:
	player = p
	p.form.form_changed.connect(_on_form_changed)
	p.blood.changed.connect(func(v, m): _blood_bar.value = v / m * 100.0)
	p.health.changed.connect(func(v, m): _health_bar.value = v / m * 100.0)
	p.abilities.ability_denied.connect(func(_a, reason): toast(reason, Color(0.9, 0.75, 0.6), 2.5))
	p.feeding.feed_completed.connect(_on_feed_completed)
	p.feeding.feed_interrupted.connect(func(_n, _pr): toast("You lost your grip. They tear free, terrified.", Color(1.0, 0.6, 0.5), 3.0))
	p.health.died.connect(_on_died)
	p.sunlight.stage_changed.connect(_on_stage_changed)
	var sense := p.abilities.get_ability(&"vampiric_sense")
	if sense:
		sense.activated.connect(func(): _sense_label.visible = true)
		sense.deactivated.connect(func(): _sense_label.visible = false)
	p.blood.hungry_changed.connect(func(_h): _refresh_status())
	_health_bar.value = 100.0
	_blood_bar.value = p.blood.value / p.blood.max_blood * 100.0
	if p.form.current:
		_on_form_changed(null, p.form.current)


func _on_form_changed(_old: FormData, f: FormData) -> void:
	_form_label.text = f.display_name.to_upper()
	_form_label.add_theme_color_override(&"font_color", f.hud_color)
	_tagline.text = f.tagline
	_refresh_status()


func _refresh_status() -> void:
	if player == null:
		return
	if player.form.current.can_feed and player.blood.is_hungry():
		_status_label.text = "HUNGRY - find a human" if not player.blood.is_empty() else "STARVING - senses failing"
	else:
		_status_label.text = ""


func _on_stage_changed(stage: int, old: int) -> void:
	if stage <= old or player == null:
		return
	var f := player.sunlight.stage_fraction()
	if stage == 1:
		toast("Sunlight! Your skin prickles - find shade.", Color(1.0, 0.85, 0.4), 3.0)
	elif f < 0.99:
		toast("Sunlight: %s exposure. The light is doing real harm." % player.sunlight.stage_name().to_lower(), Color(1.0, 0.6, 0.25), 3.0)
	else:
		toast("CRITICAL exposure. Get out of the light or you will die.", Color(1.0, 0.2, 0.15), 4.0)


func _on_died(_cause: StringName) -> void:
	_banner.text = "THE SUN TOOK YOU"
	_banner.add_theme_color_override(&"font_color", Color(1.0, 0.7, 0.4))
	_banner.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(_banner, "modulate:a", 0.0, 1.0)
	_sun_box.visible = false
	_close_memory()


func _on_feed_completed(_npc: HumanNpc, result: Dictionary) -> void:
	_memory_title.text = result["title"]
	_memory_body.text = str(result["memory"])
	var facts: PackedStringArray = result["facts"]
	var lines := PackedStringArray()
	lines.append("%s - %s" % [result["name"], result["occupation"]])
	lines.append("Blood: %s" % result["blood"])
	lines.append("%s   (+%d blood)" % [result["taste_note"], roundi(result["yield"])])
	for fact in facts:
		lines.append("Learned: %s" % fact)
	_memory_meta.text = "
".join(lines)
	_memory_panel.visible = true
	_memory_age = 0.0
	_memory_time = 24.0
	Sfx.play(&"memory", -3.0)
	# The memory surfaces: panel fades in, the recollection is "remembered" letter by letter,
	# the facts arrive once it has been told.
	if _memory_tween:
		_memory_tween.kill()
	_memory_panel.modulate.a = 0.0
	_memory_body.visible_ratio = 0.0
	_memory_meta.modulate.a = 0.0
	var read_time := clampf(_memory_body.text.length() * 0.026, 1.5, 5.0)
	_memory_tween = create_tween()
	_memory_tween.tween_property(_memory_panel, "modulate:a", 1.0, 0.7)
	_memory_tween.tween_property(_memory_body, "visible_ratio", 1.0, read_time)
	_memory_tween.tween_property(_memory_meta, "modulate:a", 1.0, 0.6)


func _close_memory() -> void:
	if _memory_panel.visible:
		_memory_panel.visible = false
		memory_closed.emit()


func toast(text: String, color := Color.WHITE, seconds := 3.0) -> void:
	_toast_label.text = text
	_toast_label.add_theme_color_override(&"font_color", color)
	if _toast_tween:
		_toast_tween.kill()
	_toast_label.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(seconds)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.8)


# ---------------------------------------------------------------- per-frame

func _process(delta: float) -> void:
	if player == null:
		return
	if Input.is_action_just_pressed(&"toggle_help"):
		_help.visible = not _help.visible
	if Input.is_action_just_pressed(&"toggle_debug"):
		_debug.visible = not _debug.visible
	_update_prompt()
	_update_sun()
	_update_clock()
	if _memory_panel.visible:
		_memory_age += delta
		_memory_time -= delta
		if _memory_time <= 0.0 or (_memory_age > 1.0 and Input.is_action_just_pressed(&"interact")):
			_close_memory()
	if _debug.visible:
		_update_debug()


func _update_clock() -> void:
	if _tod == null:
		_tod = get_tree().get_first_node_in_group(&"time_of_day") as TimeOfDay
		if _tod == null:
			return
	var phase := String(_tod.phase()).capitalize()
	var extra := ""
	if player.form.current.sun_vulnerable and (_tod.phase() == TimeOfDay.NIGHT or _tod.phase() == TimeOfDay.DAWN):
		var secs := int(_tod.real_seconds_until(_tod.sunrise_hour()))
		if _tod.hour < _tod.sunrise_hour() or _tod.hour > 12.0:
			extra = "
Sunrise in %d:%02d" % [secs / 60, secs % 60]
	_clock.text = "Day %d   %s   %s%s" % [_tod.day_count + 1, _tod.clock_text(), phase, extra]
	var c := Color(1.0, 0.85, 0.6) if _tod.phase() != TimeOfDay.NIGHT else Color(0.7, 0.78, 1.0)
	_clock.add_theme_color_override(&"font_color", c)


func _update_prompt() -> void:
	var has_prompt := false
	if player.feeding.is_feeding():
		has_prompt = true
		_prompt_label.text = "Feeding...  keep holding [E]"
		_prompt_bar.value = player.feeding.progress * 100.0
	elif player.state.can_act() and player.interactor.focused != null and not _memory_panel.visible:
		var it := player.interactor.focused
		var hold := it.get_hold_time(player) > 0.0
		_prompt_label.text = "[E]  %s%s" % [it.get_prompt(player), "  (hold)" if hold else ""]
		_prompt_bar.value = player.interactor.hold_progress * 100.0
		_prompt_bar.visible = hold
		has_prompt = true
	if player.feeding.is_feeding():
		_prompt_bar.visible = true
	_prompt_box.visible = has_prompt


func _update_sun() -> void:
	var s := player.sunlight
	_sun_box.visible = s.stage > 0
	if not _sun_box.visible:
		return
	_sun_bar.value = s.burn_ratio() * 100.0
	var lit := s.strength > 0.03
	var f := s.stage_fraction()
	var eta := s.estimated_seconds_to_death() if lit else INF
	var title := "SUNLIGHT - %s" % s.stage_name()
	if not lit:
		if s.sun_intensity() > 0.1:
			title = "SMOLDERING - stay in shade (%s)" % s.stage_name().to_lower()
		else:
			title = "COOLING - the dark soothes you (%s)" % s.stage_name().to_lower()
	elif eta < 3600.0:
		title += "   ash in %d:%02d" % [int(eta) / 60, int(eta) % 60]
	if lit and s.heat_multiplier() > 1.2:
		title += "   (x%.1f heat)" % s.heat_multiplier()
	_sun_label.text = title
	_sun_label.add_theme_color_override(&"font_color", Color(1.0, 0.9, 0.4).lerp(Color(1.0, 0.15, 0.1), f))
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color(1.0, 0.75, 0.25).lerp(Color(1.0, 0.15, 0.1), f)
	fg.set_corner_radius_all(3)
	_sun_bar.add_theme_stylebox_override(&"fill", fg)


func _update_debug() -> void:
	var s := player.sunlight
	_debug.text = "FPS %d\nform %s  state %s\nsun exposure %.2f  meter %.2f  stage %d\nhealth %.0f  blood %.0f\nspeed x%.2f" % [
		Engine.get_frames_per_second(), player.form.current.id, PlayerState.Mode.keys()[player.state.mode],
		s.exposure, s.meter, s.stage, player.health.value, player.blood.value, player.get_speed_multiplier()]
