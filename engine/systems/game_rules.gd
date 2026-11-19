class_name GameRules
extends Resource
## Rules for a whole game rather than for one character: lives, what happens after a death, and how
## an act is scored and ranked. GameState uses engine/systems/game_rules.tres.

const RANKS: Array[String] = ["S", "A", "B", "C", "D"]  ## Best first. An act's Stage.rank_scores give the lowest total for each but the last.

@export var start_lives: int = 5  ## Lives at the start of a new game.
@export var restart_delay: float = 2.0  ## Seconds between a death and the stage restarting.
@export var game_over_time: float = 3.0  ## Seconds the game-over message shows before the title screen returns.
@export var results_time: float = 6.0  ## Seconds the results show after the goal before the stage moves on.

@export_group("Score")
@export var enemy_points: PackedInt32Array = [100, 200, 500, 1000]  ## Points for each badnik destroyed in a row without landing, as in the classic games: the first, the second and so on. The last carries on for every one after.
@export var boss_points: int = 1000  ## Points for beating a boss.
@export var ring_points: int = 100  ## The goal's ring bonus, for each ring held.
@export var time_points: int = 300  ## The goal's time bonus, for each second the act was cleared inside twice its par time (Stage.par_time).


## Points for destroying a badnik with `chain` others destroyed since the player last landed.
func enemy_points_for(chain: int) -> int:
	if enemy_points.is_empty():
		return 0
	return enemy_points[clampi(chain, 0, enemy_points.size() - 1)]


## The goal's time bonus for clearing an act whose par time is `par` in `time` seconds: time_points
## for every second under twice the par, in tens. None without a par time.
func time_bonus(time: float, par: float) -> int:
	if par <= 0.0:
		return 0
	return roundi(maxf(par * 2.0 - time, 0.0) * time_points / 10.0) * 10


## Adds up the goal's score: the points scored on the way (`score`), the time bonus, and the ring
## bonus for the `rings` held. Returns {score, time_bonus, ring_bonus, total}.
func tally(score: int, time: float, rings: int, par: float) -> Dictionary:
	var time_part := time_bonus(time, par)
	var ring_part := maxi(rings, 0) * ring_points
	return {"score": score, "time_bonus": time_part, "ring_bonus": ring_part, "total": score + time_part + ring_part}


## The rank a goal total earns against an act's `targets`, the lowest totals for S, A, B and C in
## that order: the first one reached, or D below them all. "" for an act with no targets.
func rank_of(total: int, targets: PackedInt32Array) -> String:
	if targets.is_empty():
		return ""
	var ranked := mini(targets.size(), RANKS.size() - 1)
	for i in ranked:
		if total >= targets[i]:
			return RANKS[i]
	return RANKS[ranked]
