class_name ContentDef
extends Resource
## Base for every piece of data-driven game content (forms, NPCs, abilities, profiles...).
## ContentRegistry indexes anything that extends this by (class name, id).
## A mod can add content with a new id, or replace core content by reusing its id.

@export var id: StringName = &""
@export var display_name := ""
@export_multiline var description := ""

## Filled in by ContentRegistry: "core" or the mod folder name. Not saved.
var source := "core"
