class_name WorldAtmosphere
extends WorldEnvironment
## Turns TimeOfDay into a look: sun/moon lights, sky, ambient, fog. Also applies the current
## form's *vision*: a human is nearly blind in the dark, a vampire sees by a cool floor light.

const SUN_PEAK_ENERGY := 2.3
const SKY_SHADER := preload("res://shaders/sky.gdshader")

var tod: TimeOfDay
var sun: DirectionalLight3D
var moon: DirectionalLight3D

var _env: Environment
var _sky_mat: ShaderMaterial
var _from_form: FormData
var _to_form: FormData
var _blend := 1.0
var _tween: Tween


func _ready() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.glow_enabled = true
	_env.glow_intensity = 0.7
	_env.glow_bloom = 0.05
	_env.fog_enabled = true
	_env.fog_sky_affect = 0.3
	_env.ssao_enabled = true
	_env.ssao_intensity = 2.0
	_env.adjustment_enabled = true
	environment = _env


func setup(time_of_day: TimeOfDay, sun_light: DirectionalLight3D, moon_light: DirectionalLight3D) -> void:
	tod = time_of_day
	sun = sun_light
	moon = moon_light
	_update()


## Switch the vision profile (called when the player changes form).
func set_vision(f: FormData, duration := 0.6) -> void:
	if _to_form == null:
		_from_form = f
		_to_form = f
		_blend = 1.0
		return
	_from_form = _to_form
	_to_form = f
	_blend = 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "_blend", 1.0, duration)


func _process(_delta: float) -> void:
	_update()


func _update() -> void:
	if tod == null or tod.profile == null or _env == null:
		return
	var look := tod.sample_look()
	var sd := tod.sun_direction()
	var md := tod.moon_direction()
	var sun_elev := tod.sun_elevation_degrees()

	# Lights.
	if sun:
		sun.global_transform.basis = _aim(-sd)
		sun.light_color = look["sun_color"]
		sun.light_energy = SUN_PEAK_ENERGY * smoothstep(-1.0, 9.0, sun_elev)
		sun.visible = sun.light_energy > 0.02
	if moon:
		moon.global_transform.basis = _aim(-md)
		moon.light_color = Color(0.62, 0.72, 1.0)
		moon.light_energy = float(look["moon_energy"]) * smoothstep(-2.0, 8.0, -sun_elev)
		moon.visible = moon.light_energy > 0.02

	# Sky.
	_sky_mat.set_shader_parameter(&"sky_top", look["sky_top"])
	_sky_mat.set_shader_parameter(&"sky_horizon", look["sky_horizon"])
	_sky_mat.set_shader_parameter(&"ground_color", (look["sky_horizon"] as Color).darkened(0.7))
	_sky_mat.set_shader_parameter(&"sun_dir", sd)
	_sky_mat.set_shader_parameter(&"moon_dir", md)
	_sky_mat.set_shader_parameter(&"sun_color", look["sun_color"])
	_sky_mat.set_shader_parameter(&"star_strength", look["star_strength"])

	# Fog + ambient + vision.
	_env.fog_light_color = look["fog_color"]
	_env.fog_density = look["fog_density"]
	var base_e: float = look["ambient_energy"]
	var base_c: Color = look["ambient_color"]
	var a := _vision(_from_form, base_e, base_c)
	var b := _vision(_to_form, base_e, base_c)
	_env.ambient_light_energy = lerpf(a["energy"], b["energy"], _blend)
	_env.ambient_light_color = (a["color"] as Color).lerp(b["color"], _blend)
	_env.adjustment_saturation = lerpf(a["sat"], b["sat"], _blend)
	_env.adjustment_brightness = lerpf(a["bri"], b["bri"], _blend)
	_env.adjustment_contrast = lerpf(a["con"], b["con"], _blend)


## Ambient a form perceives given the time-of-day ambient: never darker than its floor.
func _vision(f: FormData, base_e: float, base_c: Color) -> Dictionary:
	if f == null:
		return {"energy": base_e, "color": base_c, "sat": 1.0, "bri": 1.0, "con": 1.0}
	var e := maxf(base_e, f.vision_floor_energy)
	var mix := clampf((e - base_e) / maxf(e, 0.001), 0.0, 1.0)
	return {
		"energy": e,
		"color": base_c.lerp(f.vision_floor_color, mix),
		"sat": f.saturation, "bri": f.brightness, "con": f.contrast,
	}


static func _aim(travel: Vector3) -> Basis:
	var up := Vector3.UP if absf(travel.y) < 0.99 else Vector3.FORWARD
	return Basis.looking_at(travel, up)
