extends Node
## Plays the game's sound effects by name, from the sound bank (SoundBank.find()):
## Sfx.play(&"jump"). Names the bank doesn't have stay silent, so the engine runs without any
## sounds. Autoloaded as Sfx.
##
## It also gives every menu its sounds with no code in the menus: a tick when the focus moves (with
## the arrow keys, the stick or the d-pad) or a focused slider changes, a blip when a button is
## pressed, and another on ui_cancel while something has the focus.

const BUS := &"SFX"
const VOICES := 4  ## How many plays of one sound can overlap. Past that, the oldest is cut off.
const WORLD_VOICES := 16  ## How many sounds placed in the world (play_at()) can play at once.
const UNIT_SIZE := 8.0  ## A sound in the world plays at full volume this close to the camera (m)...
const MAX_DISTANCE := 80.0  ## ...and can't be heard beyond this (m).
const NAVIGATION_MSEC := 250  ## A focus change this soon after a menu direction press ticks.

## Every sound name the engine plays, so tests can check that a bank has them all. A game can play
## its own names too, such as a boss's.
const SOUNDS: Array[StringName] = [
	&"jump", &"roll", &"spin_charge", &"spin_release", &"skid", &"homing", &"air_dash", &"boost",
	&"boost_loop", &"air_boost", &"quickstep", &"ring", &"ring_loss", &"shield_loss", &"death",
	&"shield", &"magnet", &"boost_fill", &"monitor", &"spring", &"dash_panel", &"checkpoint", &"goal",
	&"red_ring", &"wave", &"splash", &"enemy_pop", &"enemy_shot", &"boss_hit",
	&"air_warning", &"breathe", &"drown", &"grind", &"grind_loop", &"crumble", &"wall_break",
	&"ui_move", &"ui_confirm", &"ui_back",
]
const NAVIGATION: Array[StringName] = [&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_focus_next", &"ui_focus_prev"]

var bank: SoundBank  ## The sounds in use. Null plays nothing.

var _players: Dictionary[StringName, AudioStreamPlayer] = {}
var _ui_players: Dictionary[StringName, AudioStreamPlayer] = {}
var _world_players: Array[AudioStreamPlayer3D] = []
var _next_world := 0
var _navigated_at := -1000000  # When a menu direction was last pressed (ms).


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	bank = SoundBank.find() as SoundBank
	for i in WORLD_VOICES:
		var player := _make_world_player()
		add_child(player)
		_world_players.append(player)
	get_tree().node_added.connect(_on_node_added)
	get_viewport().gui_focus_changed.connect(_on_focus_changed)


func _input(event: InputEvent) -> void:
	for action in NAVIGATION:
		if event.is_action_pressed(action, true):
			_navigated_at = Time.get_ticks_msec()
	if event.is_action_pressed(&"ui_cancel") and get_viewport().gui_get_focus_owner() != null:
		play_ui(&"ui_back")


## Plays a sound heard the same everywhere, as for the player's own moves. A `pitch` above 1 plays it
## faster and higher.
func play(sound: StringName, pitch := 1.0) -> void:
	var player := _player(sound, false)
	if player:
		player.pitch_scale = pitch
		player.play()


## Plays a sound that carries on while the game is paused, for menus.
func play_ui(sound: StringName) -> void:
	var player := _player(sound, true)
	if player:
		player.play()


## Plays a sound from a point in the world: quieter the further it is from the camera, and from
## the side it's on.
func play_at(sound: StringName, at: Vector3, pitch := 1.0) -> void:
	var stream := stream_of(sound)
	if stream == null:
		return
	var player := _world_players[_next_world]
	for i in WORLD_VOICES:  # Prefer one that's free; otherwise cut off the oldest.
		var candidate := _world_players[(_next_world + i) % WORLD_VOICES]
		if not candidate.playing:
			player = candidate
			break
	_next_world = (_world_players.find(player) + 1) % WORLD_VOICES
	player.stream = stream
	player.pitch_scale = pitch
	player.global_position = at
	player.play()


## Plays a sound from `node`, following it as it moves, as for a wave washing up a beach.
func play_on(sound: StringName, node: Node3D, pitch := 1.0) -> void:
	var stream := stream_of(sound)
	if stream == null or not is_instance_valid(node) or not node.is_inside_tree():
		return
	var player := _make_world_player()
	player.stream = stream
	player.pitch_scale = pitch
	player.finished.connect(player.queue_free)
	node.add_child(player)
	player.play()


## Starts or stops a looping sound, such as the boost's rush of air.
func set_looping(sound: StringName, on: bool) -> void:
	var player: AudioStreamPlayer = _player(sound, false) if on else _players.get(sound)
	if player == null:
		return
	if on and not player.playing:
		player.pitch_scale = 1.0
		player.play()
	elif not on and player.playing:
		player.stop()


## Whether `sound` is playing now: played with play(), play_ui(), play_at() or set_looping().
func is_playing(sound: StringName) -> bool:
	for players: Dictionary in [_players, _ui_players]:
		var player: AudioStreamPlayer = players.get(sound)
		if player and player.playing:
			return true
	var stream := stream_of(sound)
	for player in _world_players:
		if player.playing and player.stream == stream:
			return true
	return false


## The bank's sound called `sound`, or null.
func stream_of(sound: StringName) -> AudioStream:
	if bank == null:
		return null
	return bank.sounds.get(sound)


func _player(sound: StringName, ui: bool) -> AudioStreamPlayer:
	var players := _ui_players if ui else _players
	if players.has(sound):
		return players[sound]
	var stream := stream_of(sound)
	if stream == null:
		return null
	var made := AudioStreamPlayer.new()
	made.stream = stream
	made.bus = BUS
	made.max_polyphony = VOICES
	# Menu sounds play while the game is paused; the rest pause with it.
	made.process_mode = Node.PROCESS_MODE_ALWAYS if ui else Node.PROCESS_MODE_PAUSABLE
	add_child(made)
	players[sound] = made
	return made


func _make_world_player() -> AudioStreamPlayer3D:
	var made := AudioStreamPlayer3D.new()
	made.bus = BUS
	made.unit_size = UNIT_SIZE
	made.max_distance = MAX_DISTANCE
	made.process_mode = Node.PROCESS_MODE_PAUSABLE
	return made


func _on_node_added(node: Node) -> void:
	var button := node as BaseButton
	if button and not button.pressed.is_connected(_on_button_pressed):
		button.pressed.connect(_on_button_pressed)
	var slider := node as Slider
	if slider and not slider.value_changed.is_connected(_on_slider_moved):
		slider.value_changed.connect(_on_slider_moved)


func _on_button_pressed() -> void:
	play_ui(&"ui_confirm")


func _on_slider_moved(_value: float) -> void:
	if get_viewport().gui_get_focus_owner() is Slider:
		play_ui(&"ui_move")


func _on_focus_changed(_control: Control) -> void:
	if Time.get_ticks_msec() - _navigated_at < NAVIGATION_MSEC:
		play_ui(&"ui_move")
