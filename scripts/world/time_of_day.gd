class_name TimeOfDay
extends Node
## The world clock and the sun/moon path. Owns *time and geometry only*: where the sun is,
## how strong it is, how dark it is. Lighting, sky, sunlight damage, NPC schedules and audio all
## read from here; nothing else advances time (except skip_to(), used by sleeping).
##
## Sun path: rises in the east at 06:00, crosses the northern sky (this world's noon sun is north),
## sets in the west at 18:00. The moon is exactly opposite the sun.

signal phase_changed(new_phase: StringName, old_phase: StringName)
signal hour_changed(hour: int)

const DAWN := &"dawn"
const DAY := &"day"
const DUSK := &"dusk"
const NIGHT := &"night"

## Real seconds for a full 24 game-hours.
@export var day_length_seconds := 1200.0
@export var start_hour := 14.0
@export var paused := false
@export var max_sun_elevation_degrees := 52.0
@export var profile_id: StringName = &"default"

## Debug/test hook: if non-zero, the sun is pinned to this direction (toward the sun) regardless of
## the clock. Lets tests reproduce an exact shadow layout. Leave ZERO in the game.
var sun_override := Vector3.ZERO
var hour := 14.0
var day_count := 0
var profile: DayNightProfile
var _phase: StringName = DAY
var _last_hour_int := -1


func _ready() -> void:
	add_to_group(&"time_of_day")
	profile = ContentRegistry.get_def(&"DayNightProfile", profile_id) as DayNightProfile
	hour = start_hour
	_phase = phase()
	_last_hour_int = int(hour)


func _process(delta: float) -> void:
	if not paused:
		advance_hours(delta * 24.0 / day_length_seconds)


func advance_hours(hours: float) -> void:
	hour += hours
	if hour >= 24.0:
		hour = fposmod(hour, 24.0)
		day_count += 1
	_notify()


## Jump straight to an hour (sleeping, debugging, tests). Wrapping forward counts as a new day.
func skip_to(target_hour: float) -> void:
	var t := fposmod(target_hour, 24.0)
	if t <= hour:
		day_count += 1
	hour = t
	_notify()


## Set the clock without counting days (tests, editor tools).
func set_hour(h: float) -> void:
	hour = fposmod(h, 24.0)
	_notify()


func _notify() -> void:
	var p := phase()
	if p != _phase:
		var old := _phase
		_phase = p
		phase_changed.emit(p, old)
	var hi := int(hour)
	if hi != _last_hour_int:
		_last_hour_int = hi
		hour_changed.emit(hi)


# ---------------------------------------------------------------- sun & moon

## Unit vector from the ground toward the sun (below the horizon at night).
func sun_direction() -> Vector3:
	if sun_override != Vector3.ZERO:
		return sun_override.normalized()
	var theta := TAU * (hour - 6.0) / 24.0
	var phi := deg_to_rad(max_sun_elevation_degrees)
	return Vector3(cos(theta), sin(theta) * sin(phi), -sin(theta) * cos(phi)).normalized()


func moon_direction() -> Vector3:
	return -sun_direction()


func sun_elevation_degrees() -> float:
	return rad_to_deg(asin(clampf(sun_direction().y, -1.0, 1.0)))


func moon_elevation_degrees() -> float:
	return -sun_elevation_degrees()


## 0 when the sun is down, ramping to 1 by ~22 degrees elevation. This is what sunlight damage scales with.
func sun_strength() -> float:
	return smoothstep(0.0, 22.0, sun_elevation_degrees())


## 0 in full day, 1 in deep night (smooth through twilight).
func darkness() -> float:
	return smoothstep(4.0, -8.0, sun_elevation_degrees())


func is_night() -> bool:
	return _phase == NIGHT


func phase() -> StringName:
	var elev := sun_elevation_degrees()
	if elev > 10.0:
		return DAY
	if elev > -6.0:
		return DAWN if hour < 12.0 else DUSK
	return NIGHT


# ---------------------------------------------------------------- helpers

func hours_until(target_hour: float) -> float:
	return fposmod(target_hour - hour, 24.0)


func real_seconds_until(target_hour: float) -> float:
	return hours_until(target_hour) * day_length_seconds / 24.0


func clock_text() -> String:
	var h := int(hour)
	var m := int((hour - h) * 60.0)
	return "%02d:%02d" % [h, m]


## Hour of the next sunrise / sunset (elevation 0), for HUD hints and scheduling.
func sunrise_hour() -> float:
	return 6.0


func sunset_hour() -> float:
	return 18.0


func sample_look() -> Dictionary:
	return profile.sample(hour)
