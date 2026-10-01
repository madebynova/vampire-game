class_name Hud
extends CanvasLayer
## The HUD, built in code. Presentation only: reads the player's components, never drives them.
##
## Priorities, in order: blood, form, time, immediate danger (sunlight), the interaction prompt.
## Everything else is quiet. Blood is a living vessel (BloodGauge) with a plain "73 / 100" under it; the clock is
## a 12-hour serif clock with a sun/moon glyph; prompts carry real button glyphs for whichever
## device you touched last; the controls screen sits on the right and is toggled with H / View.
## A Blood Memory is not here: MemoryView takes over the whole screen for that.

var player: Player

var _root: Control
var _gauge: BloodGauge
var _form_label: Label
var _tagline: Label
var _status_label: Label
var _surge_label: Label
var _surge_detail: Label
var _sense_label: Label
var _gain_label: Label
var _sun_box: VBoxContainer
var _sun_label: Label
var _sun_bar: ProgressBar
var _sun_icon: SkyGlyph
var _prompt_box: VBoxContainer
var _prompt_row: HBoxContainer
var _prompt_glyph: InputGlyph
var _prompt_label: Label
var _prompt_bar: ProgressBar
var _toast_label: Label
var _toast_tween: Tween
var _banner: Label
var _help: ControlsPanel
var _debug: Label
var _clock: Label
var _clock_sub: Label
var _clock_extra: Label
var _sky: SkyGlyph
var _chips: VBoxContainer
var _chip_transform: HBoxContainer
var _chip_sense: HBoxContainer
var _chip_transform_glyph: InputGlyph
var _chip_transform_label: Label
var _chip_sense_label: Label
var _tod: TimeOfDay
var _tagline_tween: Tween
var _gain_tween: Tween
var _gain_total := 0.0
var _gain_hide := 0.0
var _sense_hint_shown := false


func _ready() -> void:
	add_to_group(&"hud")
	layer = 10
	_build()


# ---------------------------------------------------------------- construction

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Bottom-left: the vessel, and what it has to say.
	_gauge = BloodGauge.new()
	_gauge.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_gauge.offset_left = 10
	_gauge.offset_top = -234
	_gauge.offset_right = 200
	_gauge.offset_bottom = -12
	_root.add_child(_gauge)

	var side := VBoxContainer.new()
	side.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	side.offset_left = 196
	side.offset_top = -270
	side.offset_right = 520
	side.offset_bottom = -40
	side.alignment = BoxContainer.ALIGNMENT_END
	side.add_theme_constant_override(&"separation", 2)
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(side)
	_form_label = UiStyle.label("HUMAN", 30, UiStyle.BONE, true, 6)
	_form_label.add_theme_font_override(&"font", UiStyle.serif_bold())
	side.add_child(_form_label)
	_tagline = UiStyle.label("", 15, UiStyle.BONE_DIM, true, 4)
	_tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tagline.custom_minimum_size = Vector2(300, 0)
	side.add_child(_tagline)
	_status_label = UiStyle.label("", 17, Color(1.0, 0.55, 0.45), false, 5)
	side.add_child(_status_label)
	_surge_label = UiStyle.label("", 18, UiStyle.GOLD, true, 5)
	side.add_child(_surge_label)
	# What the timer above is for: the rush's effect in words (so "Fury 0:32" is never a puzzle).
	_surge_detail = UiStyle.label("", 14, Color(1.0, 0.86, 0.6, 0.9), false, 4)
	_surge_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_surge_detail.custom_minimum_size = Vector2(300, 0)
	side.add_child(_surge_detail)
	_sense_label = UiStyle.label("", 16, UiStyle.BLOOD_BRIGHT, true, 5)
	side.add_child(_sense_label)
	_gain_label = UiStyle.label("", 34, Color(1.0, 0.45, 0.45), true, 7)
	_gain_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_gain_label.offset_left = 62
	_gain_label.offset_top = -258
	_gain_label.modulate.a = 0.0
	_root.add_child(_gain_label)

	# Top-right: the clock.
	var clock_box := VBoxContainer.new()
	clock_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	clock_box.offset_left = -330
	clock_box.offset_right = -24
	clock_box.offset_top = 14
	clock_box.add_theme_constant_override(&"separation", 0)
	clock_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(clock_box)
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_END
	top.add_theme_constant_override(&"separation", 10)
	clock_box.add_child(top)
	_sky = SkyGlyph.new()
	_sky.custom_minimum_size = Vector2(38, 38)
	top.add_child(_sky)
	_clock = UiStyle.label("", 38, UiStyle.SUN, true, 6)
	_clock.add_theme_font_override(&"font", UiStyle.serif_bold())
	top.add_child(_clock)
	_clock_sub = UiStyle.label("", 17, UiStyle.BONE_DIM, true, 4)
	_clock_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	clock_box.add_child(_clock_sub)
	_clock_extra = UiStyle.label("", 17, UiStyle.BLOOD_BRIGHT, true, 4)
	_clock_extra.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	clock_box.add_child(_clock_extra)

	# Top-centre: sunlight danger (shown only when it matters).
	_sun_box = VBoxContainer.new()
	_sun_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_sun_box.offset_left = -230
	_sun_box.offset_right = 230
	_sun_box.offset_top = 16
	_sun_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_sun_box.add_theme_constant_override(&"separation", 4)
	_sun_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sun_box.visible = false
	_root.add_child(_sun_box)
	var sun_row := HBoxContainer.new()
	sun_row.alignment = BoxContainer.ALIGNMENT_CENTER
	sun_row.add_theme_constant_override(&"separation", 8)
	_sun_box.add_child(sun_row)
	_sun_icon = SkyGlyph.new()
	_sun_icon.custom_minimum_size = Vector2(30, 30)
	_sun_icon.mode = SkyGlyph.Mode.SUN
	sun_row.add_child(_sun_icon)
	_sun_label = UiStyle.label("", 22, Color.WHITE, true, 6)
	_sun_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sun_row.add_child(_sun_label)
	_sun_bar = _bar(Color(1.0, 0.7, 0.2), 460.0, 10.0)
	_sun_box.add_child(_sun_bar)

	# Centre: a fine dot.
	var dot := ColorRect.new()
	dot.color = Color(1, 1, 1, 0.4)
	dot.custom_minimum_size = Vector2(3, 3)
	dot.set_anchors_preset(Control.PRESET_CENTER)
	dot.position = Vector2(-1.5, -1.5)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dot)

	# Bottom-centre: the interaction prompt, with a real button glyph.
	_prompt_box = VBoxContainer.new()
	_prompt_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_box.offset_left = -240
	_prompt_box.offset_right = 240
	_prompt_box.offset_top = -176
	_prompt_box.offset_bottom = -110
	_prompt_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_prompt_box.add_theme_constant_override(&"separation", 6)
	_prompt_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_box.visible = false
	_root.add_child(_prompt_box)
	_prompt_row = HBoxContainer.new()
	_prompt_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_prompt_row.add_theme_constant_override(&"separation", 12)
	_prompt_box.add_child(_prompt_row)
	_prompt_glyph = InputGlyph.new(&"interact")
	_prompt_row.add_child(_prompt_glyph)
	_prompt_label = UiStyle.label("", 25, UiStyle.BONE, true, 7)
	_prompt_row.add_child(_prompt_label)
	_prompt_bar = _bar(Color(0.9, 0.1, 0.15), 320.0, 8.0)
	_prompt_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_prompt_box.add_child(_prompt_bar)

	# Toast + banner.
	_toast_label = UiStyle.label("", 22, Color.WHITE, true, 7)
	_toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_label.offset_left = -380
	_toast_label.offset_right = 380
	_toast_label.offset_top = 112
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_label.modulate.a = 0.0
	_root.add_child(_toast_label)

	_banner = UiStyle.label("", 64, Color(0.95, 0.15, 0.15), true, 10)
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.offset_left = -450
	_banner.offset_right = 450
	_banner.offset_top = -60
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.modulate.a = 0.0
	_root.add_child(_banner)

	# Bottom-right: what you can do right now, quietly.
	_chips = VBoxContainer.new()
	_chips.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_chips.offset_left = -300
	_chips.offset_right = -22
	_chips.offset_top = -132
	_chips.offset_bottom = -20
	_chips.alignment = BoxContainer.ALIGNMENT_END
	_chips.add_theme_constant_override(&"separation", 6)
	_chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chips.modulate.a = 0.78
	_root.add_child(_chips)
	_chip_sense = _chip(&"vampiric_sense", "Vampiric Sense")
	_chip_sense_label = _chip_sense.get_child(1)
	_chip_transform = _chip(&"transform", "Become a vampire")
	_chip_transform_glyph = _chip_transform.get_child(0)
	_chip_transform_label = _chip_transform.get_child(1)
	var chip_help := _chip(&"toggle_help", "Controls")
	chip_help.modulate.a = 0.75

	# The controls screen, on the right.
	_help = ControlsPanel.new()
	_help.compact = true   # only the device you are using; the menus show both
	_help.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_help.offset_left = -424
	_help.offset_right = -14
	_help.offset_top = 104
	_root.add_child(_help)

	_debug = UiStyle.label("", 14, Color(0.7, 1.0, 0.7), false, 4)
	_debug.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_debug.offset_left = -330
	_debug.offset_top = 110
	_debug.visible = false
	_root.add_child(_debug)


func _chip(action: StringName, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override(&"separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(InputGlyph.new(action))
	var l := UiStyle.label(text, 17, UiStyle.BONE, false, 4)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	_chips.add_child(row)
	return row


func _bar(fill: Color, width: float, height: float) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(width, height)
	b.max_value = 100.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bg.set_corner_radius_all(int(height / 2.0))
	bg.set_border_width_all(1)
	bg.border_color = Color(0.6, 0.5, 0.45, 0.35)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(int(height / 2.0))
	b.add_theme_stylebox_override(&"background", bg)
	b.add_theme_stylebox_override(&"fill", fg)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


# ---------------------------------------------------------------- binding

func bind(p: Player) -> void:
	player = p
	_gauge.bind(p)
	p.form.form_changed.connect(_on_form_changed)
	p.abilities.ability_denied.connect(func(_a, reason): toast(reason, Color(0.9, 0.75, 0.6), 2.5))
	p.feeding.feed_started.connect(_on_feed_started)
	p.feeding.feed_interrupted.connect(func(_n, _pr): toast("You lost your grip. They tear free, terrified.", Color(1.0, 0.6, 0.5), 3.0))
	p.feeding.witnessed.connect(func(n: int): toast("Someone saw. %s" % ("They run." if n == 1 else "They scatter."), Color(1.0, 0.5, 0.4), 3.5))
	p.blood.gained.connect(_on_blood_gained)
	p.surge.started.connect(_on_surge_started)
	p.health.died.connect(_on_died)
	p.sunlight.stage_changed.connect(_on_stage_changed)
	var sense := p.abilities.get_ability(&"vampiric_sense")
	if sense:
		sense.activated.connect(_on_sense_on)
	p.blood.hungry_changed.connect(func(_h): _refresh_status())
	if p.form.current:
		_on_form_changed(null, p.form.current)


func _on_form_changed(old: FormData, f: FormData) -> void:
	_form_label.text = f.display_name.to_upper()
	_form_label.add_theme_color_override(&"font_color", f.hud_color)
	_tagline.text = f.tagline
	_help.refresh_form(f)
	_chip_sense.visible = f.can_feed
	_chip_transform_label.text = "Human form" if f.can_feed else "Become a vampire"
	_refresh_status()
	if old != null:
		# The form announces itself, then steps back.
		_form_label.pivot_offset = Vector2(0, 16)
		_form_label.scale = Vector2(1.35, 1.35)
		create_tween().tween_property(_form_label, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tagline.modulate.a = 1.0
		if _tagline_tween:
			_tagline_tween.kill()
		_tagline_tween = create_tween()
		_tagline_tween.tween_interval(4.0)
		_tagline_tween.tween_property(_tagline, "modulate:a", 0.0, 1.5)


func _refresh_status() -> void:
	if player == null:
		return
	if player.blood.is_hungry():
		_status_label.text = "STARVING" if player.blood.is_starving() else "HUNGRY"
	else:
		_status_label.text = ""


func _on_feed_started(_npc: FeedSource) -> void:
	_gain_total = 0.0
	_gain_hide = 0.0


func _on_blood_gained(amount: float) -> void:
	if player == null or not player.feeding.is_feeding():
		return
	_gain_total += amount
	_gain_label.text = "+%d" % roundi(_gain_total)
	_gain_label.modulate.a = 1.0
	_gain_hide = 2.6


func _on_surge_started(info: Dictionary) -> void:
	if info.get("fresh", true):
		var effect := player.surge.effect_text(float(info.get("power", 1.0)))
		toast("%s for %s: %s" % [info["name"], BloodSurge.clock_text(float(info.get("seconds", 0.0))), effect], UiStyle.GOLD, 5.0)


func _on_sense_on() -> void:
	if not _sense_hint_shown:
		_sense_hint_shown = true
		toast("Sense drinks your blood while it runs. Feeding makes it free for a while.", Color(1.0, 0.7, 0.7), 4.0)


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


## Hide the whole HUD (a Blood Memory owns the screen).
func set_dimmed(dimmed: bool) -> void:
	_root.visible = not dimmed


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
	_chips.visible = not _help.visible
	_update_prompt()
	_update_sun()
	_update_clock()
	_update_side(delta)
	if _debug.visible:
		_update_debug()


## Surge, Sense cost and feed-gain text next to the vessel.
func _update_side(delta: float) -> void:
	_refresh_status()
	var s := player.surge
	if s.active:
		_surge_label.text = "%s  %s left" % [s.surge_name, BloodSurge.clock_text(s.seconds_left)]
		_surge_detail.text = s.effect_short()
	else:
		_surge_label.text = ""
		_surge_detail.text = ""
	var sense := player.abilities.get_ability(&"vampiric_sense")
	if sense and sense.active:
		var cost := sense.current_cost_per_sec()
		_sense_label.text = "SENSE  free" if cost <= 0.001 else "SENSE  -%.1f blood/s" % cost
		_chip_sense_label.text = "Sense off"
	else:
		_sense_label.text = ""
		if _chip_sense_label:
			_chip_sense_label.text = "Vampiric Sense"
	if _gain_hide > 0.0:
		_gain_hide -= delta
		if _gain_hide <= 0.0:
			_gain_tween = create_tween()
			_gain_tween.tween_property(_gain_label, "modulate:a", 0.0, 0.8)


## Everything about the clock the player can read, as words (tests, accessibility).
func clock_summary() -> String:
	return "%s   %s\n%s" % [_clock.text, _clock_sub.text, _clock_extra.text]


func _update_clock() -> void:
	if _tod == null:
		_tod = get_tree().get_first_node_in_group(&"time_of_day") as TimeOfDay
		if _tod == null:
			return
	var phase := "Daylight" if _tod.phase() == TimeOfDay.DAY else String(_tod.phase()).capitalize()
	var extra := ""
	if player.form.current.sun_vulnerable and (_tod.phase() == TimeOfDay.NIGHT or _tod.phase() == TimeOfDay.DAWN):
		var secs := int(_tod.real_seconds_until(_tod.sunrise_hour()))
		if _tod.hour < _tod.sunrise_hour() or _tod.hour > 12.0:
			extra = "Sunrise in %d:%02d" % [secs / 60, secs % 60]
	_clock.text = _tod.clock_text_12h()
	_clock_sub.text = "%s  ·  Day %d" % [phase, _tod.day_count + 1]
	_clock_extra.text = extra
	var c := UiStyle.SUN if _tod.phase() != TimeOfDay.NIGHT else UiStyle.MOON
	_clock.add_theme_color_override(&"font_color", c)
	_sky.phase = _tod.phase()
	_sky.queue_redraw()


func _update_prompt() -> void:
	var has_prompt := false
	if player.feeding.is_feeding():
		has_prompt = true
		_prompt_label.text = "Feeding...  keep holding"
		_prompt_glyph.set_action(&"feed")
		_prompt_bar.value = player.feeding.progress * 100.0
		_prompt_bar.visible = true
	elif player.state.can_act() and player.interactor.focused != null:
		var it := player.interactor.focused
		var hold := it.get_hold_time(player) > 0.0
		_prompt_label.text = "%s%s" % [it.get_prompt(player), "  (hold)" if hold else ""]
		var act := it.get_action(player)
		if _prompt_glyph.action != act:
			_prompt_glyph.set_action(act)
		_prompt_bar.value = player.interactor.hold_progress * 100.0
		_prompt_bar.visible = hold
		has_prompt = true
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
	var col := Color(1.0, 0.9, 0.4).lerp(Color(1.0, 0.15, 0.1), f)
	_sun_label.add_theme_color_override(&"font_color", col)
	_sun_icon.tint = col
	_sun_icon.pulse = f
	_sun_icon.queue_redraw()
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color(1.0, 0.75, 0.25).lerp(Color(1.0, 0.15, 0.1), f)
	fg.set_corner_radius_all(5)
	_sun_bar.add_theme_stylebox_override(&"fill", fg)


func _update_debug() -> void:
	var s := player.sunlight
	_debug.text = "FPS %d\nform %s  state %s\nsun exposure %.2f  meter %.2f  stage %d\nhealth %.0f  blood %.0f (%.2f/s)  pulse %.0f bpm\nsurge %.2f (%.0fs)  speed x%.2f\nclock %s" % [
		Engine.get_frames_per_second(), player.form.current.id, PlayerState.Mode.keys()[player.state.mode],
		s.exposure, s.model.heat, s.stage, player.health.value, player.blood.value, player.blood.spend_rate, player.blood.pulse_rate(),
		player.surge.intensity(), player.surge.seconds_left, player.get_speed_multiplier(), _tod.clock_text() if _tod else "?"]
