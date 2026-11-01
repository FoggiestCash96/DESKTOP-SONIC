class_name SoundBank
extends Resource
## Which sound plays for each of the game's sound names, and which music for each music cue. The
## engine asks for sounds by name (Sfx.play(&"jump")) and music cues by name
## (Music.jingle(&"extra_life")); a game supplies the bank, named by the project setting
## game/audio/sound_bank. Names missing from the bank stay silent.
##
## Sfx.SOUNDS and Music.CUES list the names the engine itself uses. A game can add its own.

const SETTING := "game/audio/sound_bank"  ## The project setting holding the bank's path.

## Sound effects by name. An AudioStreamRandomizer plays variations, in turn or at random.
@export var sounds: Dictionary[StringName, AudioStream] = {}
## Music cues by name: tracks that play over the music (invincibility) and jingles that interrupt
## it (an extra life, the act clear, game over). Stages, menus and boss arenas name their own tracks.
@export var music: Dictionary[StringName, AudioStream] = {}


## The bank named by the project setting, or null if there isn't one. (Typed as a plain Resource:
## a script naming its own class in a static function is never freed.)
static func find() -> Resource:
	var path: String = ProjectSettings.get_setting(SETTING, "")
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path)
