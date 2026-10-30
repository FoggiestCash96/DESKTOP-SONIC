class_name CharacterDef
extends Resource
## A playable character: its name, its model and, optionally, its own movement values. Give one
## to a Player's `character` to play as that character.

@export var display_name: String = ""
@export var model: PackedScene  ## A scene whose root is a CharacterModel. Empty keeps the stand-in capsule.
@export var physics: PlayerPhysics  ## Movement values for this character. Empty keeps the Player's own.
