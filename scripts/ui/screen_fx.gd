class_name ScreenFX
extends CanvasLayer
## Full-screen effect layer driven by one shader. Gameplay code sets *targets*; this smooths
## them so sunlight glare, sense tint, and the feeding tunnel ease in and out.

var sun_target := 0.0
var sense_target := 0.0
var feed_target := 0.0
var fade := 0.0

var _sun := 0.0
var _sense := 0.0
var _feed := 0.0
var _hurt := 0.0
var _flash := 0.0
var _flash_decay := 3.0
var _rect: ColorRect
var _mat: ShaderMaterial


func _ready() -> void:
	add_to_group(&"screen_fx")
	layer = 5
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/screen_fx.gdshader")
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _mat
	add_child(_rect)


func _process(delta: float) -> void:
	_sun = lerpf(_sun, sun_target, 1.0 - exp(-4.0 * delta))
	_sense = lerpf(_sense, sense_target, 1.0 - exp(-5.0 * delta))
	_feed = lerpf(_feed, feed_target, 1.0 - exp(-4.0 * delta))
	_hurt = maxf(_hurt - delta * 1.8, 0.0)
	_flash = maxf(_flash - delta * _flash_decay, 0.0)
	var size := get_viewport().get_visible_rect().size
	_mat.set_shader_parameter(&"sun_strength", _sun)
	_mat.set_shader_parameter(&"sense_strength", _sense)
	_mat.set_shader_parameter(&"feed_strength", _feed)
	_mat.set_shader_parameter(&"hurt_strength", _hurt)
	_mat.set_shader_parameter(&"flash_strength", _flash)
	_mat.set_shader_parameter(&"fade", fade)
	_mat.set_shader_parameter(&"aspect", size.x / maxf(size.y, 1.0))


func flash(color: Color, strength := 1.0, decay := 3.0) -> void:
	_mat.set_shader_parameter(&"flash_color", color)
	_flash = strength
	_flash_decay = decay


func hurt_pulse(amount := 0.5) -> void:
	_hurt = maxf(_hurt, amount)


func set_fade(v: float) -> void:
	fade = v


func fade_to(target: float, duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(self, "fade", target, duration)
	await tw.finished
