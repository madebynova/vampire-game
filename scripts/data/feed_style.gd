class_name FeedStyle
extends ContentDef
## How feeding *plays* for one kind of victim state: calm, asleep, afraid, trusting (or anything a
## mod adds). One resource per state under content/feeding/. HumanNpc picks the state id;
## FeedingController, the blood-memory view and Vampiric Sense read everything else from here,
## so "how a feed feels" is data, not code.

@export_group("Reward")
## Multiplies the victim's blood yield.
@export var yield_multiplier := 1.0
## Bloodrush: the temporary surge after a feed (see BloodSurge). Power 1.0 = +16% speed, free Sense.
@export var surge_name := "Bloodrush"
@export var surge_power := 1.0
@export var surge_seconds := 50.0

@export_group("Risk")
## How far the commotion carries to awake people who cannot see you (0 = silent).
@export var noise_radius := 0.0
## How strongly heard commotion alarms them (awareness gained).
@export var noise_alarm := 0.0
## Anyone who can SEE the feed from within this distance panics at once. 0 = nobody notices.
@export var witness_radius := 12.0

@export_group("Feel")
@export var camera_shake := 0.0
@export var feed_volume_db := -6.0
@export var feed_pitch := 1.0
## Controller vibration strength during the feed heartbeat (0..1).
@export var haptic_strength := 0.35
@export var taste_note := ""
## What Vampiric Sense whispers about this state while blood-memory is still unheard.
@export var sense_hint := "a memory waits"

@export_group("Blood memory")
## Colour the flashback washes the world in.
@export var memory_tint := Color(0.9, 0.7, 0.45)
## 0 = smooth and warm, 1 = fragmented and violent (screen tearing, flicker).
@export var memory_fragmentation := 0.0
## Name of a looping procedural sound (see Sfx) that underlies the memory.
@export var memory_bed: StringName = &"memory_calm"
## Text reveal speed multiplier (terror comes in bursts, dreams drift slowly).
@export var memory_pace := 1.0
## One line under the title that frames how this memory arrived.
@export var memory_frame := ""
