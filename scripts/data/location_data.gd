class_name LocationData
extends ContentDef
## What lives in a place: who is where, which secrets are hidden, where the lamps are.
## (The greybox *geometry* is still built in code by WorldBuilder - see docs/MODDING.md.)

@export var coffin_position := Vector3(-5.6, 0.0, -13.2)
@export var npcs: Array[NpcPlacement] = []
@export var secrets: Array[SecretPlacement] = []
## Wild creatures that live here (each keeps to its den).
@export var animals: Array[AnimalPlacement] = []
## Small things worth a look (a log, candle wax, a scratched lock).
@export var inspectables: Array[InspectPlacement] = []
## Street/yard lamps that come on after dark.
@export var lamp_positions: PackedVector3Array = PackedVector3Array()
## Designated routes (windows to slip through, ledges and roofs to climb) only some forms can use.
@export var traversals: Array[TraversalPlacement] = []
## Vampire hunters who make camp here and walk a round after dark.
@export var hunters: Array[HunterPlacement] = []
## Waypoints hunters path between (the world has no navmesh). Each is linked to every other it can walk to in a
## straight line, so the author only places points - on the ground, in doorways, inside rooms - and never edges.
@export var nav_points: PackedVector3Array = PackedVector3Array()
