class_name CombatRules
extends RefCounted
## The small amount of arithmetic the hunt rests on, kept free of nodes so it can be tested and tuned in one
## place: how hard a strike lands, what hunger does to it, whether a target is in reach, and how a hunter's
## senses add up to awareness. Nothing here looks at the scene.

## A blow dealt to someone who did not know you were there.
const AMBUSH_MULTIPLIER := 3.0
## A strike at a run (the vampire pounces) and a strike falling onto someone.
const LUNGE_MULTIPLIER := 1.25
const PLUNGE_MULTIPLIER := 1.5
## Hunger takes the strength out of a strike: hungry x0.8, starving x0.6.
const HUNGRY_FACTOR := 0.8
const STARVING_FACTOR := 0.6
## Speeds the senses scale against: a vampire's walk and run.
const WALK_SPEED := 4.2
const RUN_SPEED := 9.0


## What a strike is called: a plunge beats a lunge beats a plain strike.
static func strike_kind(running: bool, falling: bool) -> StringName:
	if falling:
		return &"plunge"
	if running:
		return &"lunge"
	return &"rend"


static func kind_multiplier(kind: StringName) -> float:
	match kind:
		&"plunge":
			return PLUNGE_MULTIPLIER
		&"lunge":
			return LUNGE_MULTIPLIER
	return 1.0


## 1.0 when fed, less when hungry or starving.
static func hunger_factor(is_hungry: bool, is_starving: bool) -> float:
	if is_starving:
		return STARVING_FACTOR
	return HUNGRY_FACTOR if is_hungry else 1.0


## `base` damage after the kind of strike, ambush, hunger and a Bloodrush bonus (a fraction: 0.2 = +20%).
static func strike_damage(base: float, kind: StringName, ambush: bool, hunger: float, surge_bonus: float) -> float:
	var m := kind_multiplier(kind) * (AMBUSH_MULTIPLIER if ambush else 1.0)
	return base * m * hunger * (1.0 + surge_bonus)


## Is `point` within `reach` of `origin` and in front of `forward` (a flat direction) by no more than
## `half_angle_degrees`? Anything within `close` metres counts whichever way it lies (it is at your elbow).
static func in_cone(origin: Vector3, forward: Vector3, point: Vector3, reach: float, half_angle_degrees: float, close := 1.0) -> bool:
	var to := Vector3(point.x - origin.x, 0.0, point.z - origin.z)
	var d := to.length()
	if d > reach:
		return false
	if d <= close:
		return true
	var f := Vector3(forward.x, 0.0, forward.z)
	if f.length() < 0.01:
		return true
	return f.normalized().dot(to / d) >= cos(deg_to_rad(half_angle_degrees))


# ---------------------------------------------------------------- a hunter's senses

## How far a mover at `speed` is heard: a still body a little, a walker more, a runner a great deal.
static func hearing_radius(speed: float, still: float, walk: float, run: float) -> float:
	if speed <= 0.1:
		return still
	if speed <= WALK_SPEED:
		return lerpf(still, walk, speed / WALK_SPEED)
	return lerpf(walk, run, clampf((speed - WALK_SPEED) / (RUN_SPEED - WALK_SPEED), 0.0, 1.0))


## How far he can see you: his range, cut down in the dark and restored by light, scaled by wariness.
static func sight_radius(sight_range: float, dark_factor: float, lit: float, wary_multiplier := 1.0) -> float:
	return sight_range * lerpf(dark_factor, 1.0, clampf(lit, 0.0, 1.0)) * wary_multiplier


## Awareness gained per second. `seen` = in his cone with a clear line; `heard` = within hearing; `felt` = right
## behind him. Seen builds from `far` at the edge of sight to `near` point-blank; sound alone builds more
## slowly; being felt is the slowest. Zero when none apply.
static func notice_rate(dist: float, seen: bool, sight: float, heard: bool, hear: float, felt: bool,
		far_rate: float, near_rate: float, heard_rate: float) -> float:
	var rate := 0.0
	if seen and sight > 0.01:
		rate = lerpf(far_rate, near_rate, clampf(1.0 - dist / sight, 0.0, 1.0))
	if heard and hear > 0.01:
		rate = maxf(rate, heard_rate * clampf(1.0 - dist / hear, 0.05, 1.0))
	if felt:
		rate = maxf(rate, near_rate * 0.35)
	return rate
