class_name HuntClue
extends Resource
## One thing the player can learn that points at the quarry. It is not a quest step: it is a fact the world
## already holds (a clue read, a thing someone said), and the hunt notices when you have found it.

enum Kind { INSPECT, TIDING, MEMORY }

@export var id: StringName = &""
@export var kind: Kind = Kind.INSPECT
## What triggers it: an InspectPlacement id, a Tiding id, or a BloodMemory title.
@export var ref: StringName = &""
## The sentence the player now knows (shown under the objective).
@export var text := ""
