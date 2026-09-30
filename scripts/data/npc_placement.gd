class_name NpcPlacement
extends Resource
## Puts an NpcProfile (by id) in a location. Where they actually stand at a given hour
## is decided by the profile's schedule; this is the fallback/spawn spot.

@export var npc_id: StringName = &""
@export var position := Vector3.ZERO
@export var yaw_degrees := 0.0
