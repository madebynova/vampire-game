class_name Tiding
extends Resource
## One useful thing a person can tell you when you talk to them as a Human: a rumour, a schedule, a fear,
## a warning, who else is worth knowing. Not a quest and not a dialogue tree - a person simply has a few
## things to say, in order, and they open up as you earn their trust. What they say can DO something:
## put a name to a stranger (so Vampiric Sense calls them by it), or reveal a hidden thing.
##
## NpcProfile.tidings lists them; HumanNpc tells the next eligible one each time you talk, then falls back
## to their ordinary lines. The gold "Learned: ..." line on the HUD is `learned`.

@export var id: StringName = &""
## What they say, in their own voice.
@export_multiline var text := ""
## The plain takeaway, shown in gold on the HUD ("Learned: ...").
@export var learned := ""
## Trust tier needed: 0 first meeting, 1 once they know you, 2 once they trust you.
@export_range(0, 2) var min_trust := 0
## &"any", &"day" or &"night": some things are only said in the dark (or the light).
@export var when: StringName = &"any"
## Id of a tiding of the SAME person that must have been told first.
@export var after: StringName = &""
## Id of another person (NpcProfile.id): hearing this means you now know who they are (Sense shows a name).
@export var introduces: StringName = &""
## Id of a hidden thing (SecretPlacement.secret_id): hearing this reveals where it is, as a Blood Memory would.
@export var reveals_secret: StringName = &""
