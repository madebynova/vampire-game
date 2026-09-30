class_name SunlightModel
extends RefCounted
## Pure sunlight maths (no nodes, no physics): heat accumulates while in the light and cools in
## shade; heat decides the stage; the stage decides damage and slowdown. All numbers come from a
## SunlightProfile, so it is unit-testable and mod-tunable.
##
## `strength` is the heat-per-second being applied right now: (fraction of body in light)
## x (sun intensity) x (every multiplier: form, resistance, feeding, ...). Damage scales with
## strength too, so half the exposure takes exactly twice as long to kill.

var profile: SunlightProfile
var heat := 0.0
var stage := 0


func _init(p: SunlightProfile) -> void:
	profile = p


func reset() -> void:
	heat = 0.0
	stage = 0


## Advance by dt seconds. Returns the health damage dealt.
func step(dt: float, strength: float) -> float:
	var in_light := strength > profile.shade_threshold
	if in_light:
		heat = minf(heat + strength * dt, profile.heat_max)
	else:
		heat = maxf(heat - profile.cooldown_per_sec * dt, 0.0)
	stage = profile.stage_for(heat, in_light)
	if in_light:
		return profile.stage_dps[stage] * strength * dt
	return 0.0


func speed_multiplier() -> float:
	return profile.stage_speed[stage]


func stage_name() -> String:
	return profile.stage_names[stage]


## Heat at which the last (critical) stage begins; UI scales its bar against this.
func critical_heat() -> float:
	return profile.stage_from_heat[profile.stage_count() - 1]


## Heat as 0..1 of the way to the critical stage.
func ratio() -> float:
	return clampf(heat / critical_heat(), 0.0, 1.0)


## Seconds until `health` runs out if `strength` stays constant. INF if it never would.
func seconds_to_death(health: float, strength: float) -> float:
	if strength <= profile.shade_threshold:
		return INF
	var sim := SunlightModel.new(profile)
	sim.heat = heat
	var hp := health
	var t := 0.0
	while hp > 0.0 and t < 3600.0:
		hp -= sim.step(0.5, strength)
		t += 0.5
	return t if hp <= 0.0 else INF
