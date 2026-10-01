class_name TraversalPlacement
extends Resource
## A designated route between two spots that only some forms can take: slip through a window, climb
## to a ledge or a roof. Data, not code - a LocationData lists them and WorldBuilder turns each into
## a TraversalLink with an interaction prompt at both ends (routes work both ways).
##
## Which forms may use which type is FormData.traversal ("window", "climb"), so the Human uses none
## and the Vampire uses both: the same world, more of it open.
##
## A route is only ever taken on purpose: standing near it is never enough. From an end you must be on
## that end's level, close to it, on its own side of the wall, roughly in line with it, and facing the
## way it goes (see entry_problem). Stand anywhere else and the route simply is not offered.

enum Type { WINDOW, CLIMB }

## A little give (metres) when deciding whether the player is already past the wall.
const SIDE_MARGIN := 0.1

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
## How high the body arcs over the lip of a climb (metres): a low wall top, or a raised broken edge.
@export var lip_height := 0.22
## Vampiric Sense draws a pale strip up the face of a climbable wall. Off for routes that are not a wall (a hole).
@export var show_wall := true

@export_group("Rules")
## How far (metres, on the ground plane) from the starting end the player may stand.
@export var reach := 2.0
## Largest height difference between the player's feet and the starting end: a roof is not the yard.
@export var level_tolerance := 1.1
## How far sideways of the route's line (along the wall) the player may stand.
@export var lateral_tolerance := 1.2
## How squarely the player must face the way the route goes (dot of flat facing and route direction).
@export var facing_min := 0.25
## Where the wall (or roof edge) the route crosses sits along the ground run from A to B, 0..1. The
## player must still be on the start end's side of it. 0.5 = halfway, as for a window.
@export_range(0.0, 1.0) var barrier := 0.5


func type_name() -> StringName:
	return &"window" if type == Type.WINDOW else &"climb"


func end_position(end: int) -> Vector3:
	return a if end == 0 else b


## Ground-plane direction of travel when starting from `end` (zero for a purely vertical route).
func direction_from(end: int) -> Vector2:
	var s := end_position(end)
	var e := end_position(1 - end)
	var d := Vector2(e.x - s.x, e.z - s.z)
	return d.normalized() if d.length() > 0.05 else Vector2.ZERO


## Why the player, standing with their feet at `feet` and facing any of `facings` (world-space flat
## directions, e.g. body and camera), may NOT start this route from `from_end`. &"" means they may.
## Pure geometry, no physics: level, reach, side, lateral, facing - in that order.
func entry_problem(from_end: int, feet: Vector3, facings: Array) -> StringName:
	var s := end_position(from_end)
	var e := end_position(1 - from_end)
	if absf(feet.y - s.y) > level_tolerance:
		return &"level"
	var rel := Vector2(feet.x - s.x, feet.z - s.z)
	if rel.length() > reach:
		return &"far"
	var run := Vector2(e.x - s.x, e.z - s.z).length()
	if run < 0.2:
		return &""   # a straight vertical route: no side or direction to speak of
	var dir := direction_from(from_end)
	# Descending from a roof there is nothing to be "behind": the lip is the way out. Everywhere else
	# the player must not already be past the wall.
	var descending := e.y < s.y - level_tolerance * 0.5
	if not descending:
		var barrier_here := barrier if from_end == 0 else 1.0 - barrier
		if rel.dot(dir) > run * barrier_here + SIDE_MARGIN:
			return &"side"
	if absf(rel.dot(Vector2(-dir.y, dir.x))) > lateral_tolerance:
		return &"lateral"
	var best := -1.0
	for f in facings:
		var flat := Vector2(f.x, f.z)
		if flat.length() > 0.01:
			best = maxf(best, flat.normalized().dot(dir))
	# Stepping off a roof is only ever offered to someone facing the edge, whatever the route says: you
	# arrive facing away from it, so a second press can never send you straight back down.
	var need := maxf(facing_min, 0.25) if descending else facing_min
	if best < need:
		return &"facing"
	return &""
