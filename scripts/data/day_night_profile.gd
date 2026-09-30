class_name DayNightProfile
extends ContentDef
## Look of the sky/world across 24 game-hours as keyframes (parallel arrays, hours ascending,
## first = 0, last = 24 and equal to the first value so it wraps).
## Sun/moon *positions* come from TimeOfDay; this only says what colour the world is.

@export var hours: PackedFloat32Array = PackedFloat32Array([0.0, 4.5, 5.75, 7.5, 12.0, 16.5, 18.0, 19.25, 21.0, 24.0])
@export var sky_top: PackedColorArray = PackedColorArray()
@export var sky_horizon: PackedColorArray = PackedColorArray()
@export var ambient_color: PackedColorArray = PackedColorArray()
@export var fog_color: PackedColorArray = PackedColorArray()
@export var sun_color: PackedColorArray = PackedColorArray()
@export var ambient_energy: PackedFloat32Array = PackedFloat32Array()
@export var fog_density: PackedFloat32Array = PackedFloat32Array()
@export var moon_energy: PackedFloat32Array = PackedFloat32Array()
@export var star_strength: PackedFloat32Array = PackedFloat32Array()


func sample(hour: float) -> Dictionary:
	var n := hours.size()
	var h := fposmod(hour, 24.0)
	var i := 0
	while i < n - 2 and h >= hours[i + 1]:
		i += 1
	var span := maxf(hours[i + 1] - hours[i], 0.0001)
	var t := clampf((h - hours[i]) / span, 0.0, 1.0)
	return {
		"sky_top": sky_top[i].lerp(sky_top[i + 1], t),
		"sky_horizon": sky_horizon[i].lerp(sky_horizon[i + 1], t),
		"ambient_color": ambient_color[i].lerp(ambient_color[i + 1], t),
		"fog_color": fog_color[i].lerp(fog_color[i + 1], t),
		"sun_color": sun_color[i].lerp(sun_color[i + 1], t),
		"ambient_energy": lerpf(ambient_energy[i], ambient_energy[i + 1], t),
		"fog_density": lerpf(fog_density[i], fog_density[i + 1], t),
		"moon_energy": lerpf(moon_energy[i], moon_energy[i + 1], t),
		"star_strength": lerpf(star_strength[i], star_strength[i + 1], t),
	}
