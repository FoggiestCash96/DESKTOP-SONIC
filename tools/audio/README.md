# Music and sound tools

Everything the game plays is made here, from text: the music is written as notes in `music/`, played on instruments modelled on the Sega Genesis's FM chip (`instruments.py`), and the sound effects are short recipes in `sounds.py`. Nothing is sampled or downloaded, and all of it is original (CC BY-SA 4.0, like the rest of the game's art).

## Rendering

You need Python 3.10 or newer with numpy and SciPy, and [FFmpeg](https://ffmpeg.org/) (built with libvorbis, as most are) on your `PATH` for the music. From the repository root:

```bash
python tools/audio/render.py
```

| Command | Renders |
|---|---|
| `python tools/audio/render.py` | Everything (about 3 minutes) |
| `python tools/audio/render.py --music` | All the music |
| `python tools/audio/render.py --sounds` | All the sound effects (a few seconds) |
| `python tools/audio/render.py emerald_shore_1 jump` | One track and one sound, by name |
| `python tools/audio/render.py --check` | Nothing: checks every track's notation and lists notes that clash with their chords |

Music goes to `content/sonic/audio/music/<name>.ogg`, with the loop point written into the `.ogg.import` file beside it. A track that sets `FAST` also gets `<name>_fast.ogg`, the same music faster at the same pitch, which plays while speed shoes last. Sound effects go to `content/sonic/audio/sounds/<name>.wav`; one that loops (in `LOOPS`) carries its loop points inside the WAV, where Godot finds them. Then let Godot re-import: open the editor, or run `godot --headless --path . --import`. Renders are exact: the same notes always make the same file.

## Changing the music

There are three ways, and none needs any code changed:

1. **Edit the notes.** Each track is one file in `music/` (`emerald_shore_1.py` is Act 1). Change a melody, the chords or the drums, then re-render that track.
2. **Use your own recording.** Make the track in any tool (Furnace, LMMS, a DAW), export Ogg Vorbis, and save it over the file in `content/sonic/audio/music/`. In Godot, select it, and in the Import dock tick **Loop**, set **Loop Offset** to the second your loop starts (0 loops the whole file), and click **Reimport**. For a stage's track, replace its `_fast` file too, or clear the stage's **Fast Music**: without one, speed shoes play the track 20% faster and higher.
3. **Point the game at another file.** A stage's music is the `Music` and `Fast Music` of its root node; the boss fight's is the `Music` of the act's `BossArena`; the menus' is `Music` on the title screen, save slots and world map; invincibility, the extra life, the act clear and game over are the music cues in `content/sonic/audio/sound_bank.tres`.

Sound effects work the same way: edit the recipe in `sounds.py` and re-render it, or replace its WAV, or change `sound_bank.tres`.

## The tracks

| File | Plays | Key, tempo |
|---|---|---|
| `title.py` | Title screen, save slots and world map | F major, 120 |
| `emerald_shore_1.py` | Emerald Shore Act 1 (and the test room) | F major, 150 |
| `emerald_shore_8.py` | Emerald Shore Act 8, until the boss | D minor, 156 |
| `boss.py` | Boss fights | C minor, 168 |
| `invincible.py` | While invincible | A major, 168 |
| `extra_life.py` | An extra life (the music stops for it) | B-flat major, 150 |
| `act_clear.py` | The goal, or a boss beaten | F major, 140 |
| `game_over.py` | The last life lost | D minor, 100 |

## Writing music

A track builds a `Song` from sections, then names its intro and its loop:

```python
song = Song("emerald_shore_1", tempo=150, key="F major", swing=0.06)

song.section("A", "| Fmaj7 | Am7 | Bbmaj7 | C7sus4 C7 |",
    lead=melody(BRASS, "r:8 c5 f5 a5:8. g5:16 a5:4 c6:8 | a5:8 g5 e5 c5:4 r:8 d5 e5 | ..."),
    bass=bass(SLAP_BASS, "1:8 8:16 r 1 1 r 8 r 1 5 7 8:8 5:16 3"),
    keys=Comp(CLAV, "..x...x...x...x."),
    drums=Drums(KIT, {"kick": "x..x....x.x.....", "snare": "....X..o....X..."}),
)

INTRO = ["intro"]
LOOP = ["A", "A2", "B", "C"]   # None for a jingle that plays once
FAST = 1.25                     # Also render a version this much faster, for speed shoes
```

**Chords** go one bar between each pair of bar lines; two chords in a bar share it. Any common chord works: `F`, `Am`, `Bb7`, `Cmaj7`, `Dm7`, `G7sus4`, `Em7b5`, `Ab/C` (a slash names the bass note).

**Notes** (`melody`) are a pitch and a length:

| Write | Means |
|---|---|
| `c5` `f#4` `bb3` | A pitch: the letter, `#` or `b`, then the octave. `c4` is middle C. |
| `:4` `:8` `:16` `:2` `:1` | A quarter note, eighth, sixteenth, half, whole |
| `:8.` `:8t` `:4+16` | Dotted, triplet, and tied lengths |
| `c5` (no length) | The same length as the note before |
| `r:8` | A rest |
| `(c5 e5 g5):4` | A chord |
| `\|` | A bar line. Every bar is checked to add up to four beats. |
| `!c5` `_c5` `~c5` `^c5` | Accented, soft, sliding from the note before, short |
| `v=90` `q=60` | Loudness (0 to 127) and how much of each note sounds (percent), from here on |
| `[ ... ]*2` | Repeat |
| `; a comment` | Ignored |

**Degrees** (`bass` and `arp`) are written the same way, but numbered from the chord playing at that moment, so one bar of bass line fits every chord under it: `1` is the bass note (or for `arp`, the root), `3` `5` `7` the chord's third, fifth and seventh, `2` `4` `6` the notes between, and `8` the octave. `'` raises a note an octave and `,` lowers it; a trailing `-` or `+` shifts it a semitone (`1-` leads into the root from below).

**Grids** (`Comp` for chord stabs, `Drums`) have one character per sixteenth note: `x` a hit, `X` an accent, `o` a soft hit, `-` holds the last hit, `.` a rest. A row can be one bar long or several, and repeats to fill its section. `Drums` takes a `fill` that replaces those rows in the last bar of every eight (or of a shorter section), and `crash=True` hits a cymbal as the section starts. The kit has `kick`, `snare`, `clap`, `hat`, `open`, `crash`, `tom1` to `tom3`, `conga`, `conga2`, `shaker`, `cowbell`, `claves`, `timbale`, `timbale2`, `timpani` and `thunder`.

`Pad` holds each chord for as long as it lasts. Parts repeat to fill their section, so a one-bar pattern plays under an eight-bar section.

**Instruments** are in `instruments.py`: `BRASS`, `BRASS_STABS`, `SLAP_BASS`, `SYNTH_BASS`, `STEEL`, `CLAV`, `EPIANO`, `BELL`, `POP_LEAD`, `ARP`, `PAD`, `STRINGS` and the drum `KIT`. `.copy()` makes a variation for one track, for example `STEEL.copy(name="steel solo", gain_db=-5.0)`; `gain_db`, `pan`, `reverb` and `echo` set its place in the mix.

## Levels

Each track is mixed to **−17 LUFS** with peaks under −1 dB, and a gentle EQ nudges it toward a typical mix's balance (a song's `eq` sets how far: `game_over.py` keeps it low to stay dark). Sound effects each have a loudness in `sounds.LEVELS`, from −15 LUFS for the boost down to −28 for a menu tick: frequent sounds sit lower. The render prints each instrument's level against the whole mix, so a part that's lost or too loud shows up as a number.
