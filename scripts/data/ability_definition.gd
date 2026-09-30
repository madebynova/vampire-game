class_name AbilityDefinition
extends ContentDef
## Describes a supernatural ability as data. AbilityManager instantiates `behavior`
## (a script extending Ability) and applies these values, so an ability no longer has to
## be hand-wired into the player scene. Forms opt in by listing the ability `id` in FormData.abilities.

@export var input_action: StringName = &""
## Registered as the default key when `input_action` doesn't exist yet (0 = none). Godot Key enum value.
@export var default_key := 0
@export var toggle := true
@export var blood_cost_per_sec := 0.0
@export var min_blood_to_activate := 0.0
## Script extending Ability. Its exported properties may be tuned via `parameters`.
@export var behavior: Script
## Extra property overrides applied to the behavior instance, e.g. {"sense_range": 30.0}.
@export var parameters: Dictionary = {}
