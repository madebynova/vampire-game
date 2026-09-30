class_name SunlightProfile
extends ContentDef
## The sunlight survival curve as data. "Heat" is exposure-seconds at full strength: standing
## in direct noon sun adds 1 heat per second; heat cools when out of the light.
## Stage 0 is always Safe. Parallel arrays: entry i describes stage i.
##
## Default tuning: about 180 s of continuous full sunlight to die.

@export var stage_names: PackedStringArray = PackedStringArray(["Safe", "Initial", "Prolonged", "Severe", "Critical"])
## Heat at which each stage begins (index 0 unused).
@export var stage_from_heat: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 8.0, 80.0, 140.0])
## Health damage per second (at full strength) while in each stage.
@export var stage_dps: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.2, 0.55, 1.3])
## Movement speed multiplier while in each stage.
@export var stage_speed: PackedFloat32Array = PackedFloat32Array([1.0, 1.0, 0.97, 0.85, 0.65])
@export var heat_max := 240.0
## Heat lost per second while out of the light.
@export var cooldown_per_sec := 0.5
## Strength below this counts as "in shade".
@export var shade_threshold := 0.03


func stage_count() -> int:
	return stage_names.size()


func stage_for(heat: float, in_light: bool) -> int:
	if heat <= 0.0 and not in_light:
		return 0
	var s := 1
	for i in range(1, stage_count()):
		if heat >= stage_from_heat[i]:
			s = i
	return s
