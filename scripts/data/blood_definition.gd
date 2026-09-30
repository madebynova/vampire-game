class_name BloodDefinition
extends ContentDef
## What kind of blood someone has. Deliberately tiny for now: it colours how Vampiric Sense shows
## the person, scales what a full feed restores, and is named in the blood-memory panel.
## The full blood system (types with effects on the drinker, blood archive...) is future work;
## `effects` is reserved for it and unused.

@export var sense_color := Color(0.85, 0.04, 0.1)
@export var yield_multiplier := 1.0
## Scales the Bloodrush (surge) this blood gives: duration and power.
@export var surge_seconds_multiplier := 1.0
@export var surge_power_multiplier := 1.0
## Reserved: effects on the drinker, e.g. {"sun_heat_multiplier": 0.9, "duration": 120.0}. Not applied yet.
@export var effects: Dictionary = {}
