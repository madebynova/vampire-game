class_name WorldAtmosphere
extends WorldEnvironment
## Builds the sunset environment and shifts "vision" per form: the vampire sees shadows
## and interiors far better than the human does (a mechanical + visual difference).

var _env: Environment
var _tween: Tween


func _ready() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color(0.16, 0.2, 0.42)
	mat.sky_horizon_color = Color(0.95, 0.5, 0.28)
	mat.ground_horizon_color = Color(0.55, 0.32, 0.22)
	mat.ground_bottom_color = Color(0.12, 0.09, 0.1)
	mat.sky_curve = 0.18
	mat.sun_angle_max = 32.0
	mat.sun_curve = 0.06
	sky.sky_material = mat
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.5, 0.52, 0.62)
	_env.ambient_light_energy = 0.28
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.glow_enabled = true
	_env.glow_intensity = 0.7
	_env.glow_bloom = 0.05
	_env.fog_enabled = true
	_env.fog_light_color = Color(0.72, 0.45, 0.35)
	_env.fog_density = 0.006
	_env.fog_sky_affect = 0.4
	_env.ssao_enabled = true
	_env.ssao_intensity = 2.0
	_env.adjustment_enabled = true
	environment = _env


func set_vision(f: FormData, duration := 0.6) -> void:
	if _env == null:
		return
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_env, "ambient_light_energy", maxf(f.vision_floor_energy, 0.28), duration)
	_tween.tween_property(_env, "ambient_light_color", f.vision_floor_color, duration)
	_tween.tween_property(_env, "adjustment_saturation", f.saturation, duration)
	_tween.tween_property(_env, "adjustment_brightness", f.brightness, duration)
	_tween.tween_property(_env, "adjustment_contrast", f.contrast, duration)
