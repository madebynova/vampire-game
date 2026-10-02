class_name HitInfo
extends RefCounted
## One blow, as the target receives it. Built by whoever swings (PlayerCombat, Hunter) so that the thing hit
## never needs to know what hit it.

## Damage after every multiplier.
var amount := 0.0
## &"rend" (plain), &"lunge" (struck at a run), &"plunge" (struck from above), &"blade" (a hunter's sword).
var kind: StringName = &"rend"
var source: Node3D
## Where the blow came from (the direction of the knockback is away from here).
var origin := Vector3.ZERO
## Metres per second of push, and seconds the target is staggered.
var knockback := 0.0
var stagger := 0.0
## A strong blow cannot be shrugged off: it interrupts a swing that has begun.
var strong := false
## The target did not know the attacker was there.
var ambush := false
