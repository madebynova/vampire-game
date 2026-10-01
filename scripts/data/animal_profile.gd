class_name AnimalProfile
extends ContentDef
## Static data about one kind of wild animal that can be fed on: how it looks, how skittish it is, when it
## is about, what its blood is like and the one memory its blood holds. Add a `.tres` of this type under
## content/animals to add a creature; a LocationData places it (AnimalPlacement). Deliberately small: an
## animal wanders near its den, bolts from what frightens it, and can be drunk from. Nothing more.

@export var species := "fox"
## Short name Vampiric Sense shows ("A fox").
@export var sense_label := "A fox"

@export_group("Body")
@export var fur_color := Color(0.74, 0.34, 0.1)
@export var belly_color := Color(0.9, 0.82, 0.7)
@export var tail_tip_color := Color(0.95, 0.93, 0.88)
@export var dark_color := Color(0.12, 0.08, 0.06)
@export var body_scale := 1.0
@export var base_heart_rate := 118.0

@export_group("Behaviour")
## Out and about in the dark (and curled up in its den by day), or the other way round.
@export var nocturnal := true
@export var walk_speed := 1.6
@export var flee_speed := 6.4
## How far it notices a Vampire / a Human (metres), before the extras for speed. Humans are barely a worry.
@export var notice_vampire := 8.5
@export var notice_human := 4.0
## It roams within this distance of its den.
@export var roam_radius := 5.5
## After a feed it slinks off to its den and is gone for this long (seconds) - or until you sleep.
@export var away_seconds := 100.0

@export_group("Blood")
## Id of a BloodDefinition (content/blood).
@export var blood_type: StringName = &"wild"
@export var blood_description := "Wild and quick. Wet earth, hen-feathers, a thread of smoke."
## How much a full feed restores (before the blood and feeding style multipliers).
@export var blood_yield := 26.0
## Seconds a full feed takes (shorter than a person: there is less of it).
@export var feed_seconds := 2.4
## Id of a FeedStyle (content/feeding).
@export var feed_style: StringName = &"wild"
## What its blood holds. Told the first time only: after that a fox is a meal, not a memory.
@export var memories: Array[BloodMemory] = []


func memory_for(condition: StringName) -> BloodMemory:
	for m in memories:
		if m.condition == condition:
			return m
	return memories[0] if not memories.is_empty() else null


func blood_definition() -> BloodDefinition:
	return ContentRegistry.get_def(&"BloodDefinition", blood_type) as BloodDefinition
