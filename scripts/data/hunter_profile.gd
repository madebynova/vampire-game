class_name HunterProfile
extends ContentDef
## Static data about one kind of vampire hunter: how he looks, how well he sees, hears and fights, when he is
## about, what his blood is like and what it remembers. Add a `.tres` of this type under content/hunters to add
## one; a LocationData places it (HunterPlacement). The behaviour is in Hunter; every number is here, so a
## tougher or sleepier hunter is a new resource and no code.

@export var title := "Lamplighter"
## What he says (short, a few words): noticing something, spotting you, losing you, being hurt, going down.
@export var lines_suspicious: PackedStringArray = PackedStringArray()
@export var lines_spot: PackedStringArray = PackedStringArray()
@export var lines_lost: PackedStringArray = PackedStringArray()
@export var lines_hurt: PackedStringArray = PackedStringArray()
@export var lines_down: PackedStringArray = PackedStringArray()

@export_group("Body")
@export var skin_color := Color(0.78, 0.6, 0.5)
@export var coat_color := Color(0.2, 0.17, 0.12)
@export var pants_color := Color(0.1, 0.09, 0.09)
@export var hat_color := Color(0.1, 0.08, 0.07)
@export var base_heart_rate := 56.0

@export_group("Fighting")
@export var max_health := 120.0
@export var patrol_speed := 1.7
@export var investigate_speed := 2.9
@export var chase_speed := 5.4
@export var retreat_speed := 3.0
## He starts to swing when the player is this close (flat distance, metres) ...
@export var attack_range := 2.2
## ... and the blow only lands if the player is still this close when it comes down.
@export var attack_reach := 2.45
@export var attack_damage := 26.0
## The tell: raised blade, flared lantern, a scrape of steel. Fair warning for a vampire who moves.
@export var attack_windup := 0.55
@export var attack_recovery := 0.5
## Extra pause after recovering before he may swing again.
@export var attack_gap := 0.45
## How hard a landed blow throws the player back (m/s) and how long it staggers them.
@export var knockback := 9.0
@export var stagger_seconds := 0.3
## A normal Rend does not interrupt a swing already begun; a stronger strike (lunge, plunge, ambush) does.
@export var flinch_seconds := 0.22
@export var stagger_hit_seconds := 0.7

@export_group("Senses")
@export var sight_range := 15.0
@export var sight_half_angle_degrees := 58.0
## Fraction of his sight range left in full dark (away from any light).
@export var dark_sight_factor := 0.55
## How far a still, walking and running vampire is heard (metres).
@export var hear_still := 1.5
@export var hear_walk := 4.5
@export var hear_run := 9.5
## Someone this close behind him is felt, slowly.
@export var feel_radius := 2.6
## Awareness gained per second: at the far edge of his sight, at point-blank, and from sound alone.
@export var notice_rate_far := 0.35
@export var notice_rate_near := 2.2
@export var notice_rate_heard := 0.9
## Seconds of looking for you at the last place he knew, before he gives up.
@export var search_seconds := 7.0
## Seconds he will stand beneath a player he cannot reach (a roof) before he gives up.
@export var give_up_unreachable := 9.0
## While wary (after losing you, or being hurt) he notices more, for this long.
@export var wary_seconds := 75.0

@export_group("Hours")
## He arrives at his camp at `active_from` and goes on his round; at `active_until` he withdraws. If a fight
## runs on he stays until `dawn_hour`, when the sky drives him off whatever is happening.
@export var active_from := 19.0
@export var active_until := 5.0
@export var dawn_hour := 5.75

@export_group("Blood")
@export var blood_type: StringName = &"hunter"
@export var blood_description := "Salt and hawthorn, cold silver, a steady drum."
@export var blood_yield := 62.0
@export var feed_style: StringName = &"hunter"
@export var feed_seconds := 3.8
## What his blood holds. Told the first time only.
@export var memories: Array[BloodMemory] = []

@export_group("Sense")
## Vampiric Sense reads him from this far (hunters mask their scent with lavender: Sense itself reaches 28 m, so
## you have to be within about 22 m of him to feel his heart).
@export var sense_range := 22.0


func blood_definition() -> BloodDefinition:
	return ContentRegistry.get_def(&"BloodDefinition", blood_type) as BloodDefinition


func memory() -> BloodMemory:
	return memories[0] if not memories.is_empty() else null


## Is `hour` (0..24) inside the hours he walks his round?
func is_on_duty(hour: float) -> bool:
	if active_from <= active_until:
		return hour >= active_from and hour < active_until
	return hour >= active_from or hour < active_until
