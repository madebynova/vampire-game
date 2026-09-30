class_name NpcProfile
extends Resource
## Static data about one human. The blood "remembers" this; feeding surfaces it.

@export var display_name := "Stranger"
@export var occupation := "Wanderer"
@export var greeting_lines: PackedStringArray = PackedStringArray()

@export_group("Body")
@export var skin_color := Color(0.85, 0.68, 0.58)
@export var cloth_color := Color(0.4, 0.3, 0.2)
@export var pants_color := Color(0.25, 0.22, 0.2)
@export var hair_color := Color(0.25, 0.2, 0.15)
@export var base_heart_rate := 70.0

@export_group("Blood")
## How the blood smells/tastes. Shown by Vampiric Sense (from a distance) and after feeding.
@export var blood_description := "Warm and ordinary."
## Blood restored when fully drained.
@export var blood_yield := 40.0

@export_group("Memory (blood as information)")
@export var memory_title := "A Memory"
@export_multiline var memory_text := ""
@export var facts: PackedStringArray = PackedStringArray()
## If set, feeding reveals the world secret with this id (see SecretStash).
@export var reveals_secret := &""
