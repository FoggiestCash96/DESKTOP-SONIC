extends CanvasLayer
## Placeholder heads-up display for the greybox stages: rings, time, lives, red rings and the
## power-ups running, the stage's title card, a boss's name and hits left during its fight, the
## results at the goal, and the game-over message. Milestone 9 decides its real style.

const WARNING := Color(1.0, 0.3, 0.25)
const WARNING_PERIOD := 1.0  ## Seconds per flash of the ring count while it is zero.
const TITLE_TIME := 2.5  ## Seconds the stage's title shows as it starts...
const TITLE_FADE := 0.6  ## ...before fading out over this long.

@export var target: Player  ## The player whose rings and power-ups are shown.

@onready var _rings: Label = %Rings
@onready var _time: Label = %Time
@onready var _red_rings: Label = %RedRings
@onready var _lives: Label = %Lives
@onready var _power_ups: Label = %PowerUps
@onready var _stage_title: Label = %StageTitle
@onready var _results: Control = %Results
@onready var _results_title: Label = %ResultsTitle
@onready var _result_time: Label = %ResultTime
@onready var _result_rings: Label = %ResultRings
@onready var _result_red_rings: Label = %ResultRedRings
@onready var _game_over: Label = %GameOver
@onready var _boss_bar: Control = %BossBar
@onready var _boss_name: Label = %BossName
@onready var _boss_hits: ProgressBar = %BossHits


func _ready() -> void:
	_game_over.visible = false
	_results.visible = false
	GameState.game_over.connect(func() -> void: _game_over.visible = true)
	GameState.stage_cleared.connect(_show_results)
	var stage := owner as Stage
	_stage_title.text = stage.title if stage else ""
	var fade := create_tween()
	fade.tween_interval(TITLE_TIME)
	fade.tween_property(_stage_title, "modulate:a", 0.0, TITLE_FADE)


func _process(_delta: float) -> void:
	_time.text = "TIME    %s" % GameState.format_time(GameState.time)
	_lives.text = "LIVES   %d" % GameState.lives
	_red_rings.visible = GameState.hidden_total > 0
	_red_rings.text = "RED RINGS   %d / %d" % [GameState.hidden_found, GameState.hidden_total]
	_show_boss()
	if target == null:
		return
	_rings.text = "RINGS   %d" % target.rings
	# No rings means the next hit is fatal, so the count flashes red, as in the classic games.
	var flash := target.rings == 0 and fmod(Time.get_ticks_msec() / 1000.0, WARNING_PERIOD) < WARNING_PERIOD * 0.5
	_rings.modulate = WARNING if flash else Color.WHITE
	_power_ups.text = _describe_power_ups()


func _show_results() -> void:
	var stage := owner as Stage
	_results_title.text = "%s CLEAR" % stage.title.to_upper() if stage and stage.title != "" else "CLEAR"
	_result_time.text = "TIME   %s" % GameState.format_time(GameState.time)
	_result_rings.text = "RINGS   %d" % GameState.cleared_rings
	_result_red_rings.text = "RED RINGS   %d / %d" % [GameState.hidden_found, GameState.hidden_total]
	_result_red_rings.visible = GameState.hidden_total > 0
	_results.visible = true


func _show_boss() -> void:
	var boss := get_tree().get_first_node_in_group(Boss.GROUP) as Boss
	_boss_bar.visible = boss != null and boss.fighting
	if not _boss_bar.visible:
		return
	_boss_name.text = boss.display_name.to_upper()
	_boss_hits.max_value = boss.hits
	_boss_hits.value = boss.hits_left


func _describe_power_ups() -> String:
	var lines: PackedStringArray = []
	if target.shield:
		lines.append("SHIELD")
	if target.shoes_time_left() > 0.0:
		lines.append("SPEED SHOES  %d" % ceili(target.shoes_time_left()))
	if target.invincibility_time_left() > 0.0:
		lines.append("INVINCIBLE  %d" % ceili(target.invincibility_time_left()))
	if target.magnet_time_left() > 0.0:
		lines.append("MAGNET  %d" % ceili(target.magnet_time_left()))
	return "\n".join(lines)
