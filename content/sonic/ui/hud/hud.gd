extends CanvasLayer
## Heads-up display in the style of the 3D Adventure games (decided 2026-10-31): a big ring count
## with a ring icon at the top left, the time below it and the act's red rings below that, lives with
## Sonic's icon at the bottom left, power-ups at the top right, and the bottom right kept for the boost
## gauge. It also shows the stage's title card, a boss's name and hits left, the results at the goal,
## the game-over message, and holds the pause menu. Nothing relies on colour alone: the ring count
## blinks at zero and found red rings change shape. Its size follows the HUD size setting.

const WARNING := Color(1.0, 0.3, 0.25)
const WARNING_PERIOD := 1.0  ## Seconds per flash of the ring count while it is zero.
const TITLE_TIME := 2.5  ## Seconds the stage's title shows as it starts...
const TITLE_FADE := 0.6  ## ...before fading out over this long.
const RED_RING_ICON := preload("res://content/sonic/ui/hud/red_ring_icon.gd")
const RED_RING_SIZE := Vector2(34, 34)

@export var target: Player  ## The player whose rings and power-ups are shown.

var _red_ring_icons: Array[Control] = []

@onready var _top_left: Control = %TopLeft
@onready var _bottom_left: Control = %BottomLeft
@onready var _top_right: Control = %TopRight
@onready var _rings: Label = %Rings
@onready var _time: Label = %Time
@onready var _red_rings: HBoxContainer = %RedRings
@onready var _lives: Label = %Lives
@onready var _tags: Label = %Tags
@onready var _power_ups: Label = %PowerUps
@onready var _stage_title: Label = %StageTitle
@onready var _results: Control = %Results
@onready var _results_title: Label = %ResultsTitle
@onready var _result_time: Label = %ResultTime
@onready var _result_rings: Label = %ResultRings
@onready var _result_red_rings: Label = %ResultRedRings
@onready var _new_record: Label = %NewRecord
@onready var _continue_hint: Label = %ContinueHint
@onready var _game_over: Label = %GameOver
@onready var _boss_bar: Control = %BossBar
@onready var _boss_name: Label = %BossName
@onready var _boss_hits: ProgressBar = %BossHits


func _ready() -> void:
	_game_over.visible = false
	_results.visible = false
	GameState.game_over.connect(func() -> void: _game_over.visible = true)
	var stage := owner as Stage
	if stage:
		stage.cleared.connect(_show_results)
	_stage_title.text = stage.title if stage else ""
	var fade := create_tween()
	fade.tween_interval(TITLE_TIME)
	fade.tween_property(_stage_title, "modulate:a", 0.0, TITLE_FADE)
	GameSettings.changed.connect(_apply_scale)
	_apply_scale()


func _process(_delta: float) -> void:
	_time.text = GameState.format_time(GameState.time)
	_lives.text = "× %d" % GameState.lives
	_tags.text = _describe_assists()
	_update_red_rings()
	_show_boss()
	if target == null:
		return
	_rings.text = str(target.rings)
	# No rings means the next hit is fatal, so the count flashes, as in the classic games.
	var flash := target.rings == 0 and fmod(Time.get_ticks_msec() / 1000.0, WARNING_PERIOD) < WARNING_PERIOD * 0.5
	_rings.modulate = WARNING if flash else Color.WHITE
	_power_ups.text = _describe_power_ups()


## How many of the act's red rings have been found: on this visit, or on an earlier clear.
func red_rings_found() -> int:
	var ids := SaveGame.red_rings(GameState.stage)
	for id in GameState.hidden_found_ids():
		if not ids.has(id):
			ids.append(id)
	return mini(ids.size(), GameState.hidden_total)


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
	var found := red_rings_found()
	for i in _red_ring_icons.size():
		_red_ring_icons[i].set("found", i < found)


func _show_results(improved: Dictionary) -> void:
	var stage := owner as Stage
	_results_title.text = tr("RESULTS_CLEAR") % stage.title.to_upper() if stage and stage.title != "" else tr("RESULTS_CLEAR") % ""
	_result_time.text = "%s   %s" % [tr("HUD_TIME"), GameState.format_time(GameState.time)]
	_result_rings.text = "%s   %d" % [tr("HUD_RINGS"), GameState.cleared_rings]
	_result_red_rings.text = tr("RESULTS_RED_RINGS") % [red_rings_found(), GameState.hidden_total]
	_result_red_rings.visible = GameState.hidden_total > 0
	_new_record.visible = bool(improved.get("best_time", false)) and not bool(improved.get("first_clear", true))
	_continue_hint.visible = true
	_results.visible = true


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
	for corner: Control in [_top_left, _bottom_left, _top_right]:
		corner.scale = factor


func _describe_assists() -> String:
	var tags: PackedStringArray = []
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
