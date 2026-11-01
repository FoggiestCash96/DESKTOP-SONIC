extends "res://tests/test_suite.gd"
## Guards the game's audio (docs/DESIGN.md, section 11): the sound bank the project names has every
## sound and music cue the engine plays (Sfx.SOUNDS, Music.CUES), what should loop does, and each
## act has looping music with a faster version for speed shoes.

const SfxScript := preload("res://engine/audio/sfx.gd")
const MusicScript := preload("res://engine/audio/music.gd")
const ACTS: Array[String] = [
	"res://content/sonic/stages/emerald_shore/act_1.tscn",
	"res://content/sonic/stages/emerald_shore/act_8.tscn",
]
const SPEED_SHOES := 1.25  ## How much faster the speed shoes versions are rendered (tools/audio).


func test_the_project_names_a_sound_bank() -> void:
	assert_true(SoundBank.find() is SoundBank, "the setting %s doesn't name a SoundBank" % SoundBank.SETTING)


func test_the_bank_has_every_sound_the_engine_plays() -> void:
	var bank := SoundBank.find() as SoundBank
	if bank == null:
		return  # Reported by test_the_project_names_a_sound_bank.
	for sound in SfxScript.SOUNDS:
		assert_true(bank.sounds.get(sound) is AudioStream, "no sound for '%s'" % sound)


func test_the_bank_has_every_music_cue() -> void:
	var bank := SoundBank.find() as SoundBank
	if bank == null:
		return
	for cue in MusicScript.CUES:
		assert_true(bank.music.get(cue) is AudioStream, "no music for '%s'" % cue)


func test_every_sound_has_something_in_it() -> void:
	var bank := SoundBank.find() as SoundBank
	if bank == null:
		return
	for sound: StringName in bank.sounds:
		for stream in _variations(bank.sounds[sound]):
			assert_true(stream.get_length() > 0.04, "'%s' is empty" % sound)


func test_the_boost_rush_loops_and_one_shot_sounds_dont() -> void:
	var bank := SoundBank.find() as SoundBank
	if bank == null:
		return
	var rush := bank.sounds.get(&"boost_loop") as AudioStreamWAV
	assert_true(rush != null and rush.loop_mode == AudioStreamWAV.LOOP_FORWARD, "the boost's rush doesn't loop")
	if rush:
		assert_true(rush.loop_end > rush.loop_begin, "its loop is empty: %d to %d" % [rush.loop_begin, rush.loop_end])
	var jump := bank.sounds.get(&"jump") as AudioStreamWAV
	assert_true(jump != null and jump.loop_mode == AudioStreamWAV.LOOP_DISABLED, "the jump sound loops")


func test_invincibility_loops_and_the_jingles_play_once() -> void:
	var bank := SoundBank.find() as SoundBank
	if bank == null:
		return
	var invincible := bank.music.get(&"invincible") as AudioStreamOggVorbis
	assert_true(invincible != null and invincible.loop, "the invincibility music doesn't loop")
	for cue: StringName in [&"extra_life", &"clear", &"game_over"]:
		var jingle := bank.music.get(cue) as AudioStreamOggVorbis
		assert_true(jingle != null and not jingle.loop, "the '%s' jingle loops" % cue)


func test_each_act_has_looping_music_and_a_fast_version() -> void:
	for path in ACTS:
		var music := _property(path, ".", &"music") as AudioStreamOggVorbis
		var fast := _property(path, ".", &"fast_music") as AudioStreamOggVorbis
		assert_true(music != null and music.loop and music.loop_offset > 0.0, "%s's music doesn't loop after an intro" % path.get_file())
		assert_true(fast != null and fast.loop, "%s has no looping fast music" % path.get_file())
		if music and fast:
			assert_almost_eq(MusicScript.speed_ratio(music, fast), SPEED_SHOES, 0.01, path.get_file())
			assert_almost_eq(fast.loop_offset * SPEED_SHOES, music.loop_offset, 0.08, "the loops start at the same point in the tune")


func test_the_boss_arena_plays_its_own_music() -> void:
	var music := _property(ACTS[1], "Gimmicks/BossArena", &"music") as AudioStreamOggVorbis
	assert_true(music != null and music.loop, "Act 8's boss arena has no looping music")


func test_speed_ratio_compares_lengths() -> void:
	assert_almost_eq(MusicScript.speed_ratio(_silence(2.5), _silence(2.0)), 1.25, 1e-3)
	assert_almost_eq(MusicScript.speed_ratio(_silence(2.5), null), 1.0)
	assert_almost_eq(MusicScript.speed_ratio(null, _silence(2.0)), 1.0)


# A stream's variations: the streams of an AudioStreamRandomizer, or just the stream.
func _variations(stream: AudioStream) -> Array[AudioStream]:
	var out: Array[AudioStream] = []
	var varied := stream as AudioStreamRandomizer
	if varied:
		for i in varied.streams_count:
			out.append(varied.get_stream(i))
	else:
		out.append(stream)
	return out


# A property as saved on the node at `node_path` in a scene, without instancing it.
func _property(scene: String, node_path: NodePath, property: StringName) -> Variant:
	var state := (load(scene) as PackedScene).get_state()
	for node in state.get_node_count():
		if String(state.get_node_path(node)).trim_prefix("./") != String(node_path):  # Children read "./A/B".
			continue
		for i in state.get_node_property_count(node):
			if state.get_node_property_name(node, i) == property:
				return state.get_node_property_value(node, i)
	return null


func _silence(seconds: float) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 44100
	var data := PackedByteArray()
	data.resize(int(seconds * 44100.0) * 2)
	stream.data = data
	return stream
