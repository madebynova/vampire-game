class_name BloodMemory
extends Resource
## One thing a victim's blood can tell you. Which one you get depends on the victim's state
## when you feed: `condition` is &"calm", &"asleep", &"afraid" or &"any" (fallback).

@export var condition: StringName = &"any"
@export var title := "A Memory"
@export_multiline var text := ""
@export var facts: PackedStringArray = PackedStringArray()
## If set, feeding reveals the world secret with this id (see SecretStash).
@export var reveals_secret: StringName = &""
