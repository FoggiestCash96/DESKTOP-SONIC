"""Emerald Shore Act 5: Underground Grotto. Act 1's tune in the dark: A minor and unhurried, a
cave flute over a marimba pattern, bells dripping through a long echo, a soft synth bass and
light hand drums, all in a big, ringing room.

Form: a four-bar intro of dripping bells, then a loop of A (the hook in minor on the flute), A2
(the hook on flute and marimba, rising), B (a hidden room in C major: a warm, slow bridge on
strings over electric piano) and C (a marimba riff over a bass groove, for the side-on
stretches), back to A.
"""
from instruments import BELL, EPIANO, FLUTE, KIT, MARIMBA, PAD, STRINGS, SYNTH_BASS
from song import Comp, Drums, Pad, Song, arp, bass, melody

TEMPO = 120
FAST = 1.25  # Speed shoes play it this much faster.

song = Song("emerald_shore_5", tempo=TEMPO, key="A minor", swing=0.1, reverb=2.6, eq=0.5)

CAVE_FLUTE = FLUTE.copy(name="cave flute", reverb=0.4, echo=0.25)
DRIPS = BELL.copy(name="drips", gain_db=-13.0, pan=0.35, echo=0.35, reverb=0.45)
MARIMBA_BED = MARIMBA.copy(name="marimba bed", gain_db=-11.0, pan=-0.25, reverb=0.3)
MARIMBA_LEAD = MARIMBA.copy(name="marimba lead", gain_db=-7.0, pan=0.0, reverb=0.3, echo=0.12)
SOFT_BASS = SYNTH_BASS.copy(name="soft bass", gain_db=-9.0, lowpass=1200.0, reverb=0.08)
ROOM_STRINGS = STRINGS.copy(name="room strings", gain_db=-12.0, reverb=0.45)
HIDDEN_STRINGS = STRINGS.copy(name="hidden strings", gain_db=-7.0, reverb=0.4)
CAVE_PIANO = EPIANO.copy(name="cave piano", gain_db=-12.0, reverb=0.4)

INTRO_DRUMS = {
    "shaker": "." * 16 + "xoxoxoxoxoxoxoxo" * 3,
    "claves": "." * 32 + "x..x..x...x.x..." * 2,
    "conga2": "." * 48 + "x.....x.....x.x.",
}
CAVE = {
    "kick":   "x.........x.....",
    "snare":  "........X.......",
    "hat":    "..x...x...x...x.",
    "claves": "x..x..x...x.x...",
    "conga":  "..x....x..x....x",
    "conga2": "x.....x.....x...",
    "shaker": "xoxoxoxoxoxoxoxo",
}
FILL = {
    "snare": "........X.....xx",
    "tom1":  "..........x.....",
    "tom2":  "...........x....",
    "tom3":  "............xx..",
}
HIDDEN = {
    "kick":   "x.......x.......",
    "conga":  "......x.......x.",
    "claves": "x..x..x...x.x...",
    "shaker": "xoxoxoxoxoxoxoxo",
}
STRETCH = {
    "kick":   "x..x....x.x.....",
    "snare":  "....X.......X...",
    "hat":    "x.x.x.x.x.x.x.x.",
    "conga":  "..x..x.x..x..x.x",
    "conga2": "x.......x.......",
    "claves": "x..x..x...x.x...",
}
STRETCH_FILL = {
    "kick":  "x.....x.........",
    "snare": "....X.........xX",
    "tom1":  "........xx......",
    "tom2":  "..........xx....",
    "tom3":  "............xx..",
}

CAVE_BASS = "1:4 r:8 1:8 5:4 r:8 5:8"
HIDDEN_BASS = "1:2. 5:4"
STRETCH_BASS = "1:8. 8:16 r:8 1 5:8. 8:16 7:8 5"
MARIMBA_PATTERN = "1:8 5 8 r 3' 8 5 r"
DRIP_LINE = """
    r:1 | r:2 e6:8 r:8 r:4 | r:1 | r:2 d6:8 r:8 r:4 |
    r:1 | r:2 e6:8 r:8 r:4 | r:1 | r:2 b5:8 r:8 r:4 |
"""

A_CHORDS = "| Am | Am | F | G | Am | Am | Dm | E7 |"

HOOK = """
    r:8 e4 a4 c5:8. b4:16 c5:4 e5:8 | c5:8 b4 a4 e4:4 r:8 g4 a4 |
    a4:8. f4 d4:8 f4 a4 c5:4 | b4:4. a4:8 g4 a4 b4:4 |
    r:8 e4 a4 c5:8. b4:16 c5:4 e5:8 | g5:8. f5 e5:8 c5 a4 c5:4 |
    d5:8. c5 b4:8 a4 f4 a4 b4 |
"""
HOOK_END = "g#4:4 b4 d5:8 c5 b4:4 |"
HOOK_RISE = "g#4:8 a4 b4 d5 e5:2 |"

RIFF = """
    a4:16 c5 e5 a5 r:8 g5 e5:16 d5 c5:8 e5 a4 | c5:16 e5 a5 c6 r:8 b5 a5:16 g5 e5:8 c5 e5 |
    d5:16 f5 a5 d6 r:8 c6 a5:16 g5 f5:8 d5 f5 | f5:16 a5 d6 f6 r:8 e6 d6:16 c6 a5:8 f5 a5 |
    f5:16 a5 c6 f6 r:8 e6 c6:16 a5 f5:8 c5 f5 | g5:16 b5 d6 g6 r:8 f6 d6:16 b5 g5:8 d5 g5 |
    a5:16 c6 e6 a6 r:8 g6 e6:16 c6 a5:8 e5 a5 | g#5:16 b5 d6 e6 r:8 d6 b5:16 g#5 e5:4 r:8 |
"""

song.section("intro", "| Am | Am | F | E7 |",
    drips=melody(DRIPS, "r:4 e6:8 r:8 r:2 | r:2 a6:8 r:8 r:4 | r:4 c6:8 r:8 r:4 f6:8 r:8 | e6:4 r:4 g#6:4 r:4 |"),
    marimba=arp(MARIMBA_BED, MARIMBA_PATTERN, low=57),
    strings=Pad(ROOM_STRINGS, low=52, high=69),
    drums=Drums(KIT, INTRO_DRUMS),
)

song.section("A", A_CHORDS,
    lead=melody(CAVE_FLUTE, HOOK + HOOK_END, transpose=12),
    marimba=arp(MARIMBA_BED, MARIMBA_PATTERN, low=57),
    drips=melody(DRIPS, DRIP_LINE),
    piano=Comp(CAVE_PIANO, "x.......x.......", low=57, high=72),
    bass=bass(SOFT_BASS, CAVE_BASS, low=33),
    drums=Drums(KIT, CAVE, FILL, crash=True),
)

song.section("A2", A_CHORDS,
    lead=melody(CAVE_FLUTE, HOOK + HOOK_RISE, transpose=12),
    double=melody(MARIMBA_LEAD, HOOK + HOOK_RISE),
    drips=melody(DRIPS, DRIP_LINE),
    strings=Pad(ROOM_STRINGS, low=52, high=69),
    bass=bass(SOFT_BASS, CAVE_BASS, low=33),
    drums=Drums(KIT, CAVE, FILL),
)

song.section("B", "| Fmaj7 | G | Em7 | Am | Dm7 | G | Cmaj7 | E7 |",
    lead=melody(HIDDEN_STRINGS, """
        c5:2 e5:4 a5 | g5:2. d5:4 | e5:2 g5:4 b5 | a5:2. r:4 |
        f5:2 a5:4 c6 | b5:2. d6:4 | c6:2 b5:4 g5 | g#5:2 b5:4 d6 |
    """),
    piano=arp(CAVE_PIANO, "1:8 5 8 3' 8 5 3 5", low=55),
    pad=Pad(PAD, low=53, high=72),
    bass=bass(SOFT_BASS, HIDDEN_BASS, low=33),
    drums=Drums(KIT, HIDDEN, FILL),
)

song.section("C", "| Am | Am | Dm | Dm | F | G | Am | E7 |",
    riff=melody(MARIMBA_LEAD, RIFF),
    strings=Pad(ROOM_STRINGS, low=52, high=69),
    bass=bass(SOFT_BASS, STRETCH_BASS, low=33),
    drums=Drums(KIT, STRETCH, STRETCH_FILL, crash=True),
)

INTRO = ["intro"]
LOOP = ["A", "A2", "B", "C"]
