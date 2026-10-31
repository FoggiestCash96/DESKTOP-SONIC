class_name WorldInfo
extends Resource
## One world on the world map: its name, colour, and acts in order.

@export var title: String = ""
@export var color: Color = Color.WHITE  ## Its colour on the map.
@export var acts: Array[ActInfo] = []


## The acts' scene paths in order, "" for acts not built yet, as SaveData's unlock checks take them.
func act_scenes() -> PackedStringArray:
	var scenes: PackedStringArray = []
	for act in acts:
		scenes.append(act.scene if act else "")
	return scenes
