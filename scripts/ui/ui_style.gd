class_name UiStyle
extends RefCounted
## Shared look for every piece of UI: a few colours, two fonts, and small factories, so the HUD,
## menus, controls screen and Blood Memory read as one game. No art assets - drawn with styleboxes,
## `_draw()` and a system serif.

const INK := Color(0.04, 0.02, 0.03, 0.82)          ## panel background
const INK_SOFT := Color(0.04, 0.02, 0.03, 0.55)
const BONE := Color(0.93, 0.88, 0.80)               ## main text
const BONE_DIM := Color(0.74, 0.69, 0.64)
const BLOOD := Color(0.78, 0.07, 0.12)
const BLOOD_DEEP := Color(0.42, 0.02, 0.06)
const BLOOD_BRIGHT := Color(1.0, 0.25, 0.3)
const GOLD := Color(1.0, 0.8, 0.4)
const MOON := Color(0.7, 0.78, 1.0)
const SUN := Color(1.0, 0.85, 0.5)
const OUTLINE := Color(0, 0, 0, 0.85)

static var _serif: SystemFont
static var _serif_bold: SystemFont


## An elegant serif for titles, the clock and Blood Memories. Falls back to the default font where
## none of these are installed.
static func serif() -> Font:
	if _serif == null:
		_serif = SystemFont.new()
		_serif.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Book Antiqua", "Cambria", "Times New Roman", "serif"])
		_serif.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return _serif


static func serif_bold() -> Font:
	if _serif_bold == null:
		_serif_bold = SystemFont.new()
		_serif_bold.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Book Antiqua", "Cambria", "Times New Roman", "serif"])
		_serif_bold.font_weight = 700
		_serif_bold.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return _serif_bold


static func label(text: String, size: int, color := BONE, use_serif := false, outline := 5) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	l.add_theme_color_override(&"font_outline_color", OUTLINE)
	l.add_theme_constant_override(&"outline_size", outline)
	if use_serif:
		l.add_theme_font_override(&"font", serif())
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func panel_style(bg := INK, border := Color(0.5, 0.1, 0.14, 0.7), radius := 10, margin := 18) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 12
	return sb


## Menu button look: flat, dark, with a blood-coloured edge when focused or hovered.
static func style_button(b: Button) -> void:
	var normal := panel_style(Color(0.05, 0.03, 0.04, 0.6), Color(0.3, 0.1, 0.12, 0.5), 6, 12)
	normal.shadow_size = 0
	var focus := panel_style(Color(0.22, 0.03, 0.06, 0.9), BLOOD_BRIGHT, 6, 12)
	focus.set_border_width_all(2)
	focus.shadow_size = 0
	var pressed := panel_style(Color(0.4, 0.05, 0.09, 0.95), GOLD, 6, 12)
	pressed.shadow_size = 0
	b.add_theme_stylebox_override(&"normal", normal)
	b.add_theme_stylebox_override(&"hover", focus)
	b.add_theme_stylebox_override(&"focus", focus)
	b.add_theme_stylebox_override(&"pressed", pressed)
	b.add_theme_stylebox_override(&"disabled", normal)
	b.add_theme_font_size_override(&"font_size", 26)
	b.add_theme_color_override(&"font_color", BONE_DIM)
	b.add_theme_color_override(&"font_hover_color", BONE)
	b.add_theme_color_override(&"font_focus_color", BONE)
	b.add_theme_color_override(&"font_pressed_color", GOLD)
	b.add_theme_color_override(&"font_disabled_color", Color(0.4, 0.38, 0.38))
	b.add_theme_font_override(&"font", serif())
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(300, 52)
	b.focus_mode = Control.FOCUS_ALL


## 12-hour clock text (player-facing): 0.0 -> "12:00 AM", 12.5 -> "12:30 PM", 17.72 -> "5:43 PM".
static func clock12(hour: float) -> String:
	return TimeOfDay.format_12h(hour)
