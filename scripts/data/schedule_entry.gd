class_name ScheduleEntry
extends Resource
## One block of an NPC's day. Hours are 0..24 game-time; an entry may wrap midnight
## (start 22, end 5). Activities: &"patrol" (walk the points back and forth, pausing),
## &"idle" (walk to the last point and stand), &"sleep" (walk to the last point and lie down).

@export var start_hour := 0.0
@export var end_hour := 24.0
@export var activity: StringName = &"idle"
## World-space route. Walked in order; patrol loops back and forth over it.
@export var points: PackedVector3Array = PackedVector3Array()
@export var face_yaw_degrees := 0.0
## Height of the resting surface for &"sleep" (bed, bench).
@export var rest_height := 0.0
## Carries a lantern while awake in the dark.
@export var lantern := false


func contains_hour(h: float) -> bool:
	if start_hour <= end_hour:
		return h >= start_hour and h < end_hour
	return h >= start_hour or h < end_hour
