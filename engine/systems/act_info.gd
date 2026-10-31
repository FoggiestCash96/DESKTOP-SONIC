class_name ActInfo
extends Resource
## One act on the world map.

@export var title: String = ""  ## Its name, such as "Act 1: Sunny Beachfront".
@export_file("*.tscn") var scene: String = ""  ## Empty for an act that isn't built yet.
@export var boss: bool = false  ## The act with the world's boss.
