class_name HunterPlacement
extends Resource
## Puts a HunterProfile (by id) in a location: where he makes camp, and the round he walks from it.

@export var hunter_id: StringName = &""
## His camp: where he arrives at dusk, and where he goes back to when the night is over.
@export var camp := Vector3.ZERO
@export var yaw_degrees := 0.0
## The round: points he visits in order and then in reverse. He finds his own way between them.
@export var patrol: PackedVector3Array = PackedVector3Array()
## Seconds he lingers at each patrol point (looking about). Missing entries mean `default_pause`.
@export var pauses: PackedFloat32Array = PackedFloat32Array()
@export var default_pause := 3.0
## Build a small camp (bedroll, stakes, a hung lantern, two things to read) at `camp`.
@export var build_camp := true


func pause_at(i: int) -> float:
	return pauses[i] if i >= 0 and i < pauses.size() else default_pause
