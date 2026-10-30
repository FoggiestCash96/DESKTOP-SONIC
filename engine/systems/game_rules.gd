class_name GameRules
extends Resource
## Rules for a whole game rather than for one character: lives, and what happens after a death.
## GameState uses engine/systems/game_rules.tres.

@export var start_lives: int = 5  ## Lives at the start of a new game.
@export var restart_delay: float = 2.0  ## Seconds between a death and the stage restarting.
@export var game_over_time: float = 3.0  ## Seconds the game-over message shows before the title screen returns.
