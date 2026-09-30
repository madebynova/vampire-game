class_name SoundDefinition
extends ContentDef
## Replaces (or adds) a named sound. `id` is the sound name Sfx plays, e.g. &"heartbeat", &"bite",
## &"sense_on". Point `stream` at any AudioStream (wav/ogg/mp3).

@export var stream: AudioStream
