class_name NpcProfile
extends ContentDef
## Static data about one human: look, personality knobs, what they say, what their blood
## remembers, and their daily routine. Add a `.tres` of this type under content/npcs to add a person.

@export var occupation := "Wanderer"

@export_group("Body")
@export var skin_color := Color(0.85, 0.68, 0.58)
@export var cloth_color := Color(0.4, 0.3, 0.2)
@export var pants_color := Color(0.25, 0.22, 0.2)
@export var hair_color := Color(0.25, 0.2, 0.15)
@export var base_heart_rate := 70.0

@export_group("Personality")
@export var notice_radius := 10.0
## Extra notice distance in the dark (nervous people watch the night).
@export var night_notice_bonus := 0.0
## How easily they wake when something moves near their bed (higher = lighter sleeper).
@export var light_sleeper := 1.0
## Willing to follow a trusted human for a while.
@export var can_follow := true

@export_group("Talk (Human form)")
@export var greeting_lines: PackedStringArray = PackedStringArray()
## Said once they know you a little (2nd conversation).
@export var familiar_lines: PackedStringArray = PackedStringArray()
## Said once they trust you (3rd conversation onward); the last one is what they say when they agree to follow.
@export var trust_lines: PackedStringArray = PackedStringArray()
## Replaces greetings after dark.
@export var night_lines: PackedStringArray = PackedStringArray()

@export_group("Blood")
## Id of a BloodDefinition (content/blood): colour in Sense, yield multiplier, name in the memory panel.
@export var blood_type: StringName = &"common"
## How the blood smells/tastes. Vampiric Sense shows it at close range.
@export var blood_description := "Warm and ordinary."
@export var blood_yield := 40.0
@export var memories: Array[BloodMemory] = []

@export_group("Routine")
@export var schedule: Array[ScheduleEntry] = []


func schedule_for(hour: float) -> ScheduleEntry:
	for e in schedule:
		if e.contains_hour(hour):
			return e
	return null


func blood_definition() -> BloodDefinition:
	return ContentRegistry.get_def(&"BloodDefinition", blood_type) as BloodDefinition


## Best memory for the victim's state; falls back to &"any", then the first memory.
func memory_for(condition: StringName) -> BloodMemory:
	for m in memories:
		if m.condition == condition:
			return m
	for m in memories:
		if m.condition == &"any":
			return m
	return memories[0] if not memories.is_empty() else null
