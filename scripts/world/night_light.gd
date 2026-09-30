class_name NightLight
extends OmniLight3D
## A light that fades in as the world darkens (lamps, lanterns, cottage windows).
## Data: energy by day and by night, plus a little flame flicker.

@export var day_energy := 0.0
@export var night_energy := 1.3
@export var flicker := 0.07

var _tod: TimeOfDay
var _seed := randf() * 10.0


func _process(_delta: float) -> void:
	if _tod == null:
		_tod = get_tree().get_first_node_in_group(&"time_of_day") as TimeOfDay
		if _tod == null:
			return
	var e := lerpf(day_energy, night_energy, _tod.darkness())
	if e > 0.01 and flicker > 0.0:
		var t := Time.get_ticks_msec() / 1000.0
		e *= 1.0 + flicker * (sin(t * 9.0 + _seed) * 0.6 + sin(t * 23.0 + _seed * 2.0) * 0.4)
	light_energy = e
	visible = e > 0.02
