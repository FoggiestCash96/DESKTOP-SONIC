extends CanvasLayer
## Placeholder heads-up display for the greybox stages: rings, time, lives, red rings and the
## power-ups running, plus the game-over message. Milestone 9 decides its real style.

const WARNING := Color(1.0, 0.3, 0.25)
const WARNING_PERIOD := 1.0  ## Seconds per flash of the ring count while it is zero.

@export var target: Player  ## The player whose rings and power-ups are shown.

@onready var _rings: Label = %Rings
@onready var _time: Label = %Time
@onready var _red_rings: Label = %RedRings
@onready var _lives: Label = %Lives
@onready var _power_ups: Label = %PowerUps
@onready var _game_over: Label = %GameOver


func _ready() -> void:
	_game_over.visible = false
	GameState.game_over.connect(func() -> void: _game_over.visible = true)


func _process(_delta: float) -> void:
	_time.text = "TIME    %s" % GameState.format_time(GameState.time)
	_lives.text = "LIVES   %d" % GameState.lives
	_red_rings.visible = GameState.hidden_total > 0
	_red_rings.text = "RED RINGS   %d / %d" % [GameState.hidden_found, GameState.hidden_total]
	if target == null:
		return
	_rings.text = "RINGS   %d" % target.rings
	# No rings means the next hit is fatal, so the count flashes red, as in the classic games.
	var flash := target.rings == 0 and fmod(Time.get_ticks_msec() / 1000.0, WARNING_PERIOD) < WARNING_PERIOD * 0.5
	_rings.modulate = WARNING if flash else Color.WHITE
	_power_ups.text = _describe_power_ups()


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
