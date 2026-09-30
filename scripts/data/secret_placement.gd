class_name SecretPlacement
extends Resource
## A hidden thing in a location. BloodMemory.reveals_secret == secret_id makes it discoverable.

@export var secret_id: StringName = &""
@export var position := Vector3.ZERO
@export var sense_label := "Something hidden"
@export var prompt := "Search"
@export_multiline var reveal_text := ""
@export_multiline var found_text := ""
## Other systems can check this flag (e.g. the cellar hatch wants &"well_key").
@export var grants_flag: StringName = &""
