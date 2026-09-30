class_name LocationData
extends ContentDef
## What lives in a place: who is where, which secrets are hidden, where the lamps are.
## (The greybox *geometry* is still built in code by WorldBuilder - see docs/MODDING.md.)

@export var coffin_position := Vector3(-5.6, 0.0, -13.2)
@export var npcs: Array[NpcPlacement] = []
@export var secrets: Array[SecretPlacement] = []
## Street/yard lamps that come on after dark.
@export var lamp_positions: PackedVector3Array = PackedVector3Array()
