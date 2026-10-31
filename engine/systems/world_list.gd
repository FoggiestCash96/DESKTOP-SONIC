class_name WorldList
extends Resource
## Every world in the game, in order, for the world map.

@export var worlds: Array[WorldInfo] = []


## The world and act index of the act whose scene is `scene`, as Vector2i(world, act), or (-1, -1).
func find_act(scene: String) -> Vector2i:
	if scene == "":
		return Vector2i(-1, -1)  # Acts not built yet have no scene, and aren't what's being looked for.
	for w in worlds.size():
		var acts := worlds[w].acts
		for a in acts.size():
			if acts[a] and acts[a].scene == scene:
				return Vector2i(w, a)
	return Vector2i(-1, -1)
