class_name TraversalPlacement
extends Resource
## A designated route between two spots that only some forms can take: slip through a window, climb
## to a ledge or a roof. Data, not code - a LocationData lists them and WorldBuilder turns each into
## a TraversalLink with an interaction prompt at both ends (routes work both ways).
##
## Which forms may use which type is FormData.traversal ("window", "climb"), so the Human uses none
## and the Vampire uses both: the same world, more of it open.

enum Type { WINDOW, CLIMB }

@export var id: StringName = &""
@export var type: Type = Type.WINDOW
## The two ends: where the player stands before, and where they end up (feet position). Either end may
## be the start. For CLIMB the higher end is the ledge / roof.
@export var a := Vector3.ZERO
@export var b := Vector3.ZERO
## Prompt shown when standing at end A (going to B) and at end B (going to A).
@export var prompt_a := ""
@export var prompt_b := ""
## Short name Vampiric Sense shows for the route ("Window", "Roof").
@export var sense_label := ""
## Seconds; 0 = worked out from the route.
@export var duration := 0.0


func type_name() -> StringName:
	return &"window" if type == Type.WINDOW else &"climb"


func end_position(end: int) -> Vector3:
	return a if end == 0 else b
