extends Node
## The game's music: one track at a time, a power-up's music laid over it, and jingles that cut in
## and then let it carry on. Stages, menus and boss arenas say which track to play (play()); power-
## ups and events ask for the sound bank's music cues by name (start_override(), jingle()).
## Autoloaded as Music.
##
## Speed shoes switch the track to its fast version (set_fast()) from the same point in the tune;
## a track without one plays at FAST_PITCH instead. Music pauses with the game.

const BUS := &"Music"
const FADE_IN := 0.5  ## Seconds the music takes to come back after something interrupted it.
const FAST_PITCH := 1.2  ## Speed shoes play a track with no fast version this much faster (and higher).

## Every music cue the engine asks for, so tests can check that a bank has them all.
const CUES: Array[StringName] = [&"invincible", &"extra_life", &"clear", &"game_over"]

var bank: SoundBank  ## The music cues in use. Null has none.

var _track: AudioStream  # The track playing, or that would be if nothing had interrupted it.
var _fast_track: AudioStream  # The same music faster, for speed shoes, or null.
var _fast := false
var _track_time := 0.0  # Where an interruption stopped the track, in seconds at normal speed.
var _override := &""  # The music cue playing over the track, if any.
var _override_time := 0.0
var _jingle := &""  # The jingle playing, if any.

var _track_player: AudioStreamPlayer
var _override_player: AudioStreamPlayer
var _jingle_player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	bank = SoundBank.find() as SoundBank
	_track_player = _make_player()
	_override_player = _make_player()
	_jingle_player = _make_player()
	_jingle_player.finished.connect(_on_jingle_finished)


## Plays `track`: the music for a stage, a menu or a boss fight. If it's already the track, it
## carries on where it is. `fast_track` is the same music faster, for speed shoes. Null fades the
## music out.
func play(track: AudioStream, fast_track: AudioStream = null) -> void:
	_fast_track = fast_track
	if track == _track:
		return
	_fade_away(_track_player, 0.5)
	_track_player = _make_player()
	_track = track
	_track_time = 0.0
	_refresh()


## Fades the music out over `seconds`, power-up music too. A jingle plays on.
func stop(seconds := 0.5) -> void:
	_track = null
	_override = &""
	_fade_away(_track_player, seconds)
	_track_player = _make_player()
	_fade_away(_override_player, seconds)
	_override_player = _make_player()


## Speed shoes: the track plays faster from the same point in the tune, or at normal speed again.
func set_fast(on: bool) -> void:
	if on == _fast:
		return
	var time := _track_time_now()
	_fast = on
	if _track_player.playing:
		_start_track(time)


## Plays the bank's music cue `cue` instead of the track until end_override(), as for
## invincibility. Afterwards the track picks up where it stopped.
func start_override(cue: StringName) -> void:
	if cue == _override:
		return
	_override = cue
	_override_time = 0.0
	_override_player.stop()
	_refresh()


func end_override(cue: StringName) -> void:
	if cue != _override:
		return
	_override = &""
	_refresh()


## Plays the bank's jingle `cue`, silencing the music while it does. Afterwards the music picks up
## where it was, or with `resume` false (as at the goal) stays quiet until the next play().
func jingle(cue: StringName, resume := true) -> void:
	if not resume:
		_track = null
		_override = &""
	var stream := cue_stream(cue)
	if stream:
		_jingle = cue
		_jingle_player.stream = stream
		_jingle_player.play()
	_refresh()


## The bank's music for `cue`, or null.
func cue_stream(cue: StringName) -> AudioStream:
	if bank == null:
		return null
	return bank.music.get(cue)


## What can be heard: the jingle, the music over the track, or the track. Null in silence.
func now_playing() -> AudioStream:
	if _jingle_player.playing:
		return _jingle_player.stream
	if _override_player.playing:
		return _override_player.stream
	if _track_player.playing:
		return _track_player.stream
	return null


## The track the stage, menu or boss fight asked for, playing or interrupted.
func current_track() -> AudioStream:
	return _track


func is_fast() -> bool:
	return _fast


## How much faster `fast` is than `normal`: the music's speed-up for speed shoes. Their lengths
## give it, as the fast version is the same music played faster.
static func speed_ratio(normal: AudioStream, fast: AudioStream) -> float:
	if normal == null or fast == null or fast.get_length() <= 0.0:
		return 1.0
	return normal.get_length() / fast.get_length()


# Starts or stops each player to match what should be heard: a jingle over everything, then a cue
# over the track, then the track. Whatever is interrupted remembers where it was.
func _refresh() -> void:
	var jingle_on := _jingle != &""
	var override_on := not jingle_on and _override != &"" and cue_stream(_override) != null
	var track_on := not jingle_on and not override_on and _track != null
	if track_on and not _track_player.playing:
		_start_track(_track_time)
		if _track_time > 0.0:
			_fade_in(_track_player)
	elif not track_on and _track_player.playing:
		_track_time = _track_time_now()
		_halt(_track_player)
	if override_on and not _override_player.playing:
		_override_player.stream = cue_stream(_override)
		_override_player.play(_override_time)
		if _override_time > 0.0:
			_fade_in(_override_player)
	elif not override_on and _override_player.playing:
		_override_time = _override_player.get_playback_position() if _override != &"" else 0.0
		_halt(_override_player)


# Plays the track (or its fast version) from `time`, in seconds at normal speed.
func _start_track(time: float) -> void:
	var use_fast := _fast and _fast_track != null
	_track_player.stream = _fast_track if use_fast else _track
	_track_player.pitch_scale = FAST_PITCH if _fast and not use_fast else 1.0
	_track_player.play(time / speed_ratio(_track, _fast_track) if use_fast else time)


# Seconds into the track at normal speed.
func _track_time_now() -> float:
	if not _track_player.playing:
		return _track_time
	var position := _track_player.get_playback_position()
	if _fast_track != null and _track_player.stream == _fast_track and _fast_track != _track:
		position *= speed_ratio(_track, _fast_track)
	return position


func _on_jingle_finished() -> void:
	_jingle = &""
	_refresh()


func _make_player() -> AudioStreamPlayer:
	var made := AudioStreamPlayer.new()
	made.bus = BUS
	made.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(made)
	return made


# Stops a player at once, ending any fade, ready to play again at full volume.
func _halt(player: AudioStreamPlayer) -> void:
	if player.has_meta(&"fade"):
		(player.get_meta(&"fade") as Tween).kill()
	player.stop()
	player.volume_db = 0.0


func _fade_in(player: AudioStreamPlayer) -> void:
	player.volume_db = -30.0
	_fade(player).tween_property(player, "volume_db", 0.0, FADE_IN)


# Fades a player out over `seconds` and frees it.
func _fade_away(player: AudioStreamPlayer, seconds: float) -> void:
	if not player.playing or seconds <= 0.0:
		player.queue_free()
		return
	var fade := _fade(player)
	fade.tween_property(player, "volume_db", -40.0, seconds)
	fade.tween_callback(player.queue_free)


# A new fade for `player`, replacing any it was in the middle of.
func _fade(player: AudioStreamPlayer) -> Tween:
	if player.has_meta(&"fade"):
		(player.get_meta(&"fade") as Tween).kill()
	var fade := create_tween().set_ignore_time_scale()
	player.set_meta(&"fade", fade)
	return fade
