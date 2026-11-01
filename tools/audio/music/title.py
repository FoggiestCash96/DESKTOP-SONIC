"""Title and menus: the main theme, relaxed. F major, like Act 1: electric piano and bells carry
Act 1's hook at an easier pace over a light groove, after a two-bar brass fanfare.

Form: the fanfare, then a loop of A (the hook) and B (a gentle bridge), back to A.
"""
from instruments import BELL, BRASS, BRASS_STABS, EPIANO, KIT, PAD, SLAP_BASS
from song import Drums, Pad, Song, arp, bass, melody

TEMPO = 120

song = Song("title", tempo=TEMPO, key="F major", swing=0.05, reverb=2.0)

KEYS_LEAD = EPIANO.copy(name="piano lead", gain_db=-6.0, spread=0.0, pan=-0.05, echo=0.12)
BELL_DOUBLE = BELL.copy(name="bell double", gain_db=-14.0, pan=0.2)
SOFT_BASS = SLAP_BASS.copy(name="soft bass", gain_db=-9.0)
FANFARE = BRASS.copy(name="fanfare brass", gain_db=-4.0)

INTRO_DRUMS = {
    "crash":   "x...............................",
    "timpani": "........x.......xxxxxxxxxxxxxxxx",
}
GROOVE = {
    "kick":   "x.......x.x.....",
    "snare":  "....o.......o...",
    "hat":    "x.x.x.x.x.x.x.x.",
    "shaker": "xoxoxoxoxoxoxoxo",
}
FILL = {
    "snare": "....o.......o.oo",
    "conga": "........x.x.....",
    "conga2": "............x.x.",
}

song.section("intro", "| Bb | C |",
    lead=melody(FANFARE, "r:8 f5:16 g5 a5:4 bb5:8 a5 bb5 d6 | c6:2. r:4 |"),
    stabs=melody(BRASS_STABS, "(d5 f5 bb5):4 r:4 (d5 f5 bb5):4 r:4 | (e5 g5 c6):2. r:4 |"),
    bass=bass(SOFT_BASS, "1:4 r:4 1:4 r:4 | 1:2. r:4 |", low=29),
    drums=Drums(KIT, INTRO_DRUMS),
)

HOOK = """
    r:8 c5 f5 a5:4. g5:8 a5 | f5:2 ~e5:4 d5 |
    r:8 d5 f5 bb5:4. a5:8 bb5 | g5:2 r:4 c5 |
    r:8 c5 f5 a5:4. g5:8 a5 | c6:2 ~a5:4 f5 |
    bb5:4. a5:8 g5:4 f5 | g5:2 e5:4 c5 |
"""
BRIDGE = """
    d6:4. c6:8 bb5:4 a5 | g5:4. a5:8 bb5:4 c6 |
    e6:4. d6:8 c6:4 a5 | f5:2. a5:4 |
    bb5:4. a5:8 g5:4 d6 | c6:4. a5:8 g5:4 e5 |
    d6:4 c6 bb5 a5 | g5:2 r:8 c5 d5 e5 |
"""

song.section("A", "| Fmaj7 | Dm7 | Bbmaj7 | C7 | Fmaj7 | Dm7 | Gm7 | C7sus4 C7 |",
    lead=melody(KEYS_LEAD, HOOK),
    double=melody(BELL_DOUBLE, HOOK, transpose=12),
    bass=bass(SOFT_BASS, "1:4. 5:8 r:8 8:8 5:4", low=29),
    pad=Pad(PAD, low=53, high=72),
    drums=Drums(KIT, GROOVE, FILL),
)

song.section("B", "| Bbmaj7 | C/Bb | Am7 | Dm7 | Gm7 | Am7 | Bbmaj7 | C7sus4 C7 |",
    lead=melody(KEYS_LEAD, BRIDGE),
    bells=arp(BELL, "1:8 5 8 3' 5' 3' 8 5", low=60),
    bass=bass(SOFT_BASS, "1:4. 5:8 r:8 8:8 5:4", low=29),
    pad=Pad(PAD, low=53, high=72),
    drums=Drums(KIT, GROOVE, FILL),
)

INTRO = ["intro"]
LOOP = ["A", "B"]
