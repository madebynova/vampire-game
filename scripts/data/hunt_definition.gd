class_name HuntDefinition
extends ContentDef
## The hunt: one small objective, told in a line under the clock rather than in a quest log. It names the
## quarry (a HunterProfile) and says, for each state the quarry can be in, what the player should be thinking.
## Which state it is in is never stored: HuntDirector works it out from the hunter (see HuntDirector.Stage).

@export var hunter_id: StringName = &"lamplighter"
@export var title := "THE HUNT"

@export_group("What the player is told")
@export_multiline var text_rumor := ""
## After dark with the quarry on his round, once you know where he is.
@export_multiline var text_sighted := ""
@export_multiline var text_engaged := ""
## He has lost you and is searching.
@export_multiline var text_wary := ""
@export_multiline var text_down := ""
@export_multiline var text_done := ""
## The quarry has withdrawn for the day but will be back.
@export_multiline var text_withdrawn := ""

@export_group("What can be learned")
@export var clues: Array[HuntClue] = []
