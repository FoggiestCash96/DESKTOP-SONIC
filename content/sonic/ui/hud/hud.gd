extends CanvasLayer
## Heads-up display in the style of the 3D Adventure games (decided 2026-10-31): a big ring count
## with a ring icon at the top left, the time and the score below it and the act's red rings below
## that, lives with Sonic's icon at the bottom left, power-ups at the top right, and the boost gauge
## at the bottom right. It also shows the stage's title card, a boss's name and hits left, the
## drowning countdown under water, the results and rank at the goal, the game-over message, and holds
## the pause menu. In time attack the score gives way to the best time, a split against the best run
## shows at each checkpoint, and lives are hidden. Nothing relies on colour alone: the ring count
## blinks at zero, found red rings change shape, and splits carry a + or -. Its size follows the HUD
## size setting.

const WARNING := Color(1.0, 0.3, 0.25)
const WARNING_PERIOD := 1.0  ## Seconds per flash of the ring count while it is zero.
const TITLE_TIME := 2.5  ## Seconds the stage's title shows as it starts...
const TITLE_FADE := 0.6  ## ...before fading out over this long.
const RED_RING_ICON := preload("res://content/sonic/ui/hud/red_ring_icon.gd")
const RED_RING_SIZE := Vector2(34, 34)
const SPLIT_TIME := 3.0  ## Seconds a time attack split shows after a checkpoint.
const SPLIT_FASTER := Color(0.45, 0.85, 1.0)
const SPLIT_SLOWER := Color(1.0, 0.45, 0.35)
const RANK_DELAY := 1.0  ## Seconds after the results appear that the rank lands.
const RANK_COLORS: Dictionary[String, Color] = {
	"S": Color(1.0, 0.82, 0.25), "A": Color(1.0, 0.45, 0.35), "B": Color(0.45, 0.85, 1.0),
	"C": Color(0.55, 0.95, 0.5), "D": Color(0.8, 0.8, 0.85),
}

@export var target: Player  ## The player whose rings and power-ups are shown.

var _red_ring_icons: Array[Control] = []
var _best_time := -1.0  # In time attack, the act's fastest run, or -1 with none yet.
var _split_left := 0.0  # Seconds the split has left to show.

@onready var _top_left: Control = %TopLeft
@onready var _bottom_left: Control = %BottomLeft
@onready var _top_right: Control = %TopRight
@onready var _boost_slot: Control = %BoostSlot
@onready var _boost_gauge: Control = %BoostGauge
@onready var _rings: Label = %Rings
@onready var _time: Label = %Time
@onready var _score_caption: Label = %ScoreCaption
@onready var _score: Label = %Score
@onready var _split: Label = %Split
@onready var _red_rings: HBoxContainer = %RedRings
@onready var _life_icon: Control = %LifeIcon
@onready var _lives: Label = %Lives
@onready var _tags: Label = %Tags
@onready var _power_ups: Label = %PowerUps
@onready var _stage_title: Label = %StageTitle
@onready var _air_count: Label = %AirCount
@onready var _results: Control = %Results
@onready var _results_title: Label = %ResultsTitle
@onready var _result_time: Label = %ResultTime
@onready var _result_rings: Label = %ResultRings
@onready var _result_red_rings: Label = %ResultRedRings
@onready var _result_score: Label = %ResultScore
@onready var _result_time_bonus: Label = %ResultTimeBonus
@onready var _result_ring_bonus: Label = %ResultRingBonus
@onready var _result_total: Label = %ResultTotal
@onready var _result_rank: Label = %ResultRank
@onready var _new_record: Label = %NewRecord
@onready var _continue_hint: Label = %ContinueHint
@onready var _game_over: Label = %GameOver
@onready var _boss_bar: Control = %BossBar
@onready var _boss_name: Label = %BossName
@onready var _boss_hits: ProgressBar = %BossHits


func _ready() -> void:
	_game_over.visible = false
	_results.visible = false
	_split.visible = false
	GameState.game_over.connect(func() -> void: _game_over.visible = true)
	GameState.checkpoint_passed.connect(_show_split)
	var stage := owner as Stage
	if stage:
		stage.cleared.connect(_show_results)
	_stage_title.text = stage.title if stage else ""
	var fade := create_tween()
	fade.tween_interval(TITLE_TIME)
	fade.tween_property(_stage_title, "modulate:a", 0.0, TITLE_FADE)
	GameSettings.changed.connect(_apply_scale)
	_apply_scale()
	# Time attack has no lives to lose and no score: the best time shows in its place.
	_score_caption.text = "HUD_BEST" if GameState.time_attack else "HUD_SCORE"
	_life_icon.visible = not GameState.time_attack
	_lives.visible = not GameState.time_attack
	_best_time = float(SaveGame.act(GameState.stage).get("ta_time", -1.0))


func _process(delta: float) -> void:
	_time.text = GameState.format_time(GameState.time)
	if GameState.time_attack:
		_score.text = GameState.format_time(_best_time) if _best_time >= 0.0 else "-:--.--"
	else:
		_score.text = str(GameState.score)
	_split_left -= delta
	_split.visible = _split_left > 0.0
	_lives.text = "× %d" % GameState.lives
	_tags.text = _describe_assists()
	_update_red_rings()
	_show_boss()
	if target == null:
		return
	_rings.text = str(target.rings)
	_boost_gauge.set("value", target.boost_gauge)
	_boost_gauge.set("active", target.is_boosting())
	# No rings means the next hit is fatal, so the count flashes, as in the classic games.
	var flash := target.rings == 0 and fmod(Time.get_ticks_msec() / 1000.0, WARNING_PERIOD) < WARNING_PERIOD * 0.5
	_rings.modulate = WARNING if flash else Color.WHITE
	_power_ups.text = _describe_power_ups()
	# Running out of air under water: 5 down to 0, as in the classic games.
	var count := PlayerMotion.drown_count(target.air_left(), target.physics.drown_countdown) if target.is_underwater() else -1
	_air_count.visible = count >= 0 and not target.is_dead()
	if _air_count.visible:
		_air_count.text = str(count)


## How many of the act's red rings have been found: on this visit, or on an earlier clear.
func red_rings_found() -> int:
	return mini(_found_red_rings().size(), GameState.hidden_total)


## Ids of the act's red rings found on this visit or on an earlier clear.
func _found_red_rings() -> PackedStringArray:
	var ids := SaveGame.red_rings(GameState.stage)
	for id in GameState.hidden_found_ids():
		if not ids.has(id):
			ids.append(id)
	return ids


func _update_red_rings() -> void:
	_red_rings.visible = GameState.hidden_total > 0
	if _red_ring_icons.size() != GameState.hidden_total:
		for icon in _red_ring_icons:
			icon.queue_free()
		_red_ring_icons.clear()
		for i in GameState.hidden_total:
			var icon := Control.new()
			icon.set_script(RED_RING_ICON)
			icon.custom_minimum_size = RED_RING_SIZE
			_red_rings.add_child(icon)
			_red_ring_icons.append(icon)
	# Each red ring lights its own slot; any without one fills the first slots left.
	var lit: Array[bool] = []
	lit.resize(_red_ring_icons.size())
	var loose := 0
	for id in _found_red_rings():
		var slot: int = GameState.hidden_slots.get(id, 0)
		if slot >= 1 and slot <= lit.size() and not lit[slot - 1]:
			lit[slot - 1] = true
		else:
			loose += 1
	for i in lit.size():
		if not lit[i] and loose > 0:
			lit[i] = true
			loose -= 1
		_red_ring_icons[i].set("found", lit[i])


func _show_results(improved: Dictionary) -> void:
	var stage := owner as Stage
	var title := stage.title.to_upper() if stage else ""
	var time_attack := GameState.time_attack
	_results_title.text = tr("RESULTS_TIME_ATTACK" if time_attack else "RESULTS_CLEAR") % title
	_result_time.text = "%s   %s" % [tr("HUD_TIME"), GameState.format_time(GameState.time)]
	_result_rings.text = "%s   %d" % [tr("HUD_RINGS"), GameState.cleared_rings]
	_result_rings.visible = not time_attack
	_result_red_rings.text = tr("RESULTS_RED_RINGS") % [red_rings_found(), GameState.hidden_total]
	_result_red_rings.visible = GameState.hidden_total > 0 and not time_attack
	var tally: Dictionary = stage.tally if stage else {}
	for line: Label in [_result_score, _result_time_bonus, _result_ring_bonus, _result_total]:
		line.visible = not tally.is_empty()
	if time_attack:
		# The best time before this run, so a new record shows what it beat.
		_result_score.visible = _best_time >= 0.0
		_result_score.text = "%s   %s" % [tr("HUD_BEST"), GameState.format_time(_best_time)]
	elif not tally.is_empty():
		var assisted := GameSettings.assist or GameSettings.game_speed < 1.0
		_result_score.text = "%s   %d" % [tr("HUD_SCORE"), int(tally["score"])]
		_result_time_bonus.text = "%s   %d" % [tr("RESULTS_TIME_BONUS"), int(tally["time_bonus"])]
		_result_ring_bonus.text = "%s   %d" % [tr("RESULTS_RING_BONUS"), int(tally["ring_bonus"])]
		_result_total.text = "%s   %d%s" % [tr("RESULTS_TOTAL"), int(tally["total"]), ("  " + tr("MAP_ASSISTED")) if assisted else ""]
	_show_rank(str(tally.get("rank", "")))
	_new_record.visible = bool(improved.get("best_time", false)) and not bool(improved.get("first_clear", true))
	_continue_hint.text = "RESULTS_RETRY" if time_attack else "RESULTS_CONTINUE"
	_continue_hint.visible = true
	_results.visible = true


## The time attack split at a checkpoint: the stage clock there, and how far ahead (-) or behind (+)
## the act's fastest run it is.
func _show_split(id: String, time: float) -> void:
	if not GameState.time_attack:
		return
	var best: Variant = SaveData.splits_of(SaveGame.data, GameState.stage).get(id)
	_split.text = GameState.format_time(time)
	_split.modulate = Color.WHITE
	if best is float:
		var gap := time - float(best)
		_split.text += "   %s%s" % ["+" if gap > 0.0 else "-", GameState.format_time(absf(gap))]
		_split.modulate = SPLIT_SLOWER if gap > 0.0 else SPLIT_FASTER
	_split_left = SPLIT_TIME


# The rank stamps onto the results a moment after they appear.
func _show_rank(rank: String) -> void:
	_result_rank.visible = rank != ""
	if rank == "":
		return
	_result_rank.text = tr("RESULTS_RANK") % rank
	_result_rank.add_theme_color_override("font_color", RANK_COLORS.get(rank, Color.WHITE) as Color)
	_result_rank.modulate.a = 0.0  # Its line is there from the start, so the results don't shift when it lands.
	var stamp := create_tween()
	stamp.tween_interval(RANK_DELAY)
	stamp.tween_callback(func() -> void:
		_result_rank.pivot_offset = _result_rank.size * 0.5
		_result_rank.modulate.a = 1.0
		Sfx.play_ui(&"checkpoint"))
	stamp.tween_property(_result_rank, "scale", Vector2.ONE, 0.25).from(Vector2.ONE * 1.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _show_boss() -> void:
	var boss := get_tree().get_first_node_in_group(Boss.GROUP) as Boss
	_boss_bar.visible = boss != null and boss.fighting
	if not _boss_bar.visible:
		return
	_boss_name.text = boss.display_name.to_upper()
	_boss_hits.max_value = boss.hits
	_boss_hits.value = boss.hits_left


func _apply_scale() -> void:
	var factor := Vector2.ONE * GameSettings.hud_scale
	for corner: Control in [_top_left, _bottom_left, _top_right, _boost_slot]:
		corner.scale = factor


func _describe_assists() -> String:
	var tags: PackedStringArray = []
	if GameState.time_attack:
		tags.append(tr("HUD_TIME_ATTACK"))
	if GameSettings.assist:
		tags.append(tr("HUD_ASSIST"))
	if GameSettings.game_speed < 1.0:
		tags.append(tr("HUD_SPEED") % roundi(GameSettings.game_speed * 100.0))
	return "  ·  ".join(tags)


func _describe_power_ups() -> String:
	var lines: PackedStringArray = []
	if target.shield:
		lines.append(tr("HUD_SHIELD"))
	if target.shoes_time_left() > 0.0:
		lines.append("%s  %d" % [tr("HUD_SHOES"), ceili(target.shoes_time_left())])
	if target.invincibility_time_left() > 0.0:
		lines.append("%s  %d" % [tr("HUD_INVINCIBLE"), ceili(target.invincibility_time_left())])
	if target.magnet_time_left() > 0.0:
		lines.append("%s  %d" % [tr("HUD_MAGNET"), ceili(target.magnet_time_left())])
	return "\n".join(lines)
