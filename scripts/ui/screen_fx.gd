class_name ScreenFX
extends CanvasLayer
## Full-screen effect layer driven by one shader. Gameplay code sets *targets*; this smooths them
## so sunlight glare, sense tint, the feeding tunnel, hunger and the Bloodrush ease in and out.
## It keeps running while the tree is paused (Blood Memory and the pause menu are animated here).

var sun_target := 0.0
var sense_target := 0.0
var feed_target := 0.0
var memory_target := 0.0
var vamp_target := 0.0       ## persistent "you are a vampire" rim
var hunger_target := 0.0
var surge_target := 0.0
var pulse_strength_target := 0.0
var fade := 0.0

var memory_tint := Color(0.95, 0.72, 0.42)
var memory_fragmentation := 0.0
var memory_dim_target := 0.0

## Direct (un-smoothed) transformation controls, tweened by TransformPresentation.
var morph := 0.0
var morph_color := Color(0.3, 0.0, 0.05)
var morph_ring := -1.0
var morph_ring_strength := 0.0
var chroma := 0.0

var _sun := 0.0
var _sense := 0.0
var _feed := 0.0
var _memory := 0.0
var _vamp := 0.0
var _hunger := 0.0
var _surge := 0.0
var _pulse_strength := 0.0
var _memory_dim := 0.0
var _hurt := 0.0
var _flash := 0.0
var _flash_decay := 3.0
var _pulse := 0.0
var _rect: ColorRect
var _mat: ShaderMaterial


func _ready() -> void:
	add_to_group(&"screen_fx")
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	_memory = lerpf(_memory, memory_target, 1.0 - exp(-2.2 * delta))
	_memory_dim = lerpf(_memory_dim, memory_dim_target, 1.0 - exp(-3.0 * delta))
	_vamp = lerpf(_vamp, vamp_target, 1.0 - exp(-2.0 * delta))
	_hunger = lerpf(_hunger, hunger_target, 1.0 - exp(-1.5 * delta))
	_surge = lerpf(_surge, surge_target, 1.0 - exp(-3.0 * delta))
	_pulse_strength = lerpf(_pulse_strength, pulse_strength_target, 1.0 - exp(-2.0 * delta))
	_hurt = maxf(_hurt - delta * 1.8, 0.0)
	_flash = maxf(_flash - delta * _flash_decay, 0.0)
	_pulse = maxf(_pulse - delta * 3.2, 0.0)
	var size := get_viewport().get_visible_rect().size
	_mat.set_shader_parameter(&"sun_strength", _sun)
	_mat.set_shader_parameter(&"sense_strength", _sense)
	_mat.set_shader_parameter(&"feed_strength", _feed)
	_mat.set_shader_parameter(&"memory_strength", _memory)
	_mat.set_shader_parameter(&"memory_tint", Vector3(memory_tint.r, memory_tint.g, memory_tint.b))
	_mat.set_shader_parameter(&"memory_fragmentation", memory_fragmentation)
	_mat.set_shader_parameter(&"memory_dim", _memory_dim)
	_mat.set_shader_parameter(&"morph", morph)
	_mat.set_shader_parameter(&"morph_color", Vector3(morph_color.r, morph_color.g, morph_color.b))
	_mat.set_shader_parameter(&"morph_ring", morph_ring)
	_mat.set_shader_parameter(&"morph_ring_strength", morph_ring_strength)
	_mat.set_shader_parameter(&"chroma", chroma)
	_mat.set_shader_parameter(&"vamp_look", _vamp)
	_mat.set_shader_parameter(&"hunger", _hunger)
	_mat.set_shader_parameter(&"surge", _surge)
	_mat.set_shader_parameter(&"pulse_env", _pulse)
	_mat.set_shader_parameter(&"pulse_strength", _pulse_strength)
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


## One heartbeat, seen at the edges of the screen. Strength of the *visibility* is
## pulse_strength_target (hunger, Bloodrush, feeding); this only triggers the thump.
func beat() -> void:
	_pulse = 1.0


func set_fade(v: float) -> void:
	fade = v


func fade_to(target: float, duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(self, "fade", target, duration)
	await tw.finished


## Current smoothed value of a cue (tests and tools read what the player would see).
func level(cue: StringName) -> float:
	match cue:
		&"memory": return _memory
		&"vamp": return _vamp
		&"hunger": return _hunger
		&"surge": return _surge
		&"sense": return _sense
		&"feed": return _feed
		&"flash": return _flash
		&"dim": return _memory_dim
	return 0.0
