class_name RestOption
extends Resource
## One answer to "when will you wake?" at the coffin. A DayNightProfile lists them (content/time), so a
## mod can offer more (or fewer) without code. The vampire always wakes in the crypt, rested and a Human.

@export var id: StringName = &""
## What the menu says: "Until dusk".
@export var label := ""
## The hour (0..24) you wake at. If it has already passed today it means tomorrow's.
@export_range(0.0, 24.0) var hour := 19.0
## The line shown on waking.
@export var wake_text := ""


## The built-in choices, used when a day/night profile does not list any.
static func defaults() -> Array[RestOption]:
	var out: Array[RestOption] = []
	for d in [
		[&"dusk", "Until dusk", 19.0, "You sleep until dusk. The living have forgotten you."],
		[&"midnight", "Until midnight", 0.0, "You sleep until midnight. The night is deep, and everything in it is yours."],
		[&"dawn", "Until dawn", 5.5, "You sleep until dawn. The sky is pale, and the day will be long."],
		[&"daylight", "Until daylight", 8.0, "You sleep until morning. The sun is up, and you wake into it as a human."],
	]:
		var o := RestOption.new()
		o.id = d[0]
		o.label = d[1]
		o.hour = d[2]
		o.wake_text = d[3]
		out.append(o)
	return out
