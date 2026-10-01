class_name InspectPlacement
extends Resource
## A small thing in the world worth a look: a log book, candle wax under a window, a scratched lock. It
## says nothing the people do not (it backs up, or quietly contradicts, a rumour), asks nothing of you and
## gives nothing but a line. A LocationData lists them; WorldBuilder places an Inspectable for each.

@export var id: StringName = &""
## Where the prompt anchors (the thing itself; the player stands within a metre or two).
@export var position := Vector3.ZERO
@export var prompt := "Examine"
@export_multiline var text := ""
## Optional small mark on the ground / surface so the eye finds it (size in metres; zero = nothing drawn).
@export var mark_size := Vector2.ZERO
@export var mark_color := Color(0.85, 0.8, 0.65)
