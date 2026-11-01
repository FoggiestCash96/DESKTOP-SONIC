"""Emerald Shore Act 1: Sunny Beachfront. Upbeat tropical funk in F major: FM brass on the tune,
slap bass, steel drums, a clavinet chopping the off-beats, congas and a shaker.

Form: a four-bar intro, then a loop of A (the hook), A2 (the hook again, steel drums doubling
the brass, rising into the bridge), B (a smoother bridge on a pop synth) and C (a breakdown for
the slap bass and a steel drum solo), back to A.
"""
from instruments import BRASS, BRASS_STABS, CLAV, KIT, PAD, POP_LEAD, SLAP_BASS, STEEL
from song import Comp, Drums, Pad, Song, arp, bass, melody

TEMPO = 150
FAST = 1.25  # Speed shoes play it this much faster.

song = Song("emerald_shore_1", tempo=TEMPO, key="F major", swing=0.06)

STEEL_LEAD = STEEL.copy(name="steel lead", gain_db=-9.0, pan=0.15, echo=0.12)
STEEL_SOLO = STEEL.copy(name="steel solo", gain_db=-5.0, pan=0.08, echo=0.15)
CLAV_FUNK = CLAV.copy(name="clav funk", gain_db=-13.0, pan=-0.3)

GROOVE = {
    "kick":   "x..x....x.x.....",
    "snare":  "....X..o....X...",
    "hat":    "x.x.x.x.x.x.x...",
    "open":   "..............x.",
    "shaker": "xoxoxoxoxoxoxoxo",
    "conga":  "..x..x....x..x..",
    "conga2": ".......x.......x",
}
FILL = {
    "kick":  "x.....x.........",
    "snare": "....X.........xX",
    "hat":   "x.x.x.x.........",
    "open":  "................",
    "tom1":  "........xx......",
    "tom2":  "..........xx....",
    "tom3":  "............xx..",
}
BRIDGE_GROOVE = {
    "kick":   "x.......x.x.....",
    "snare":  "....X.......X...",
    "clap":   "....x.......x...",
    "hat":    "x.x.x.x.x.x.x.x.",
    "shaker": "xoxoxoxoxoxoxoxo",
    "conga":  "......x.......x.",
    "conga2": "..x.......x.....",
}
BREAK_GROOVE = {
    "kick":     "x..x....x.x..x..",
    "snare":    "....X..o.o..X..o",
    "hat":      "x.xxx.xxx.xxx.xx",
    "cowbell":  "x...x...x...x...",
    "conga":    "..x..x.x..x..x.x",
    "conga2":   "x.......x.......",
    "timbale":  "...............x",
}
BREAK_FILL = {
    "kick":     "x.....x.........",
    "snare":    "....X...........",
    "timbale":  "........x.x.x.xx",
    "timbale2": ".........x.x.x..",
}

FUNK_BASS = "1:8 8:16 r 1 1 r 8 r 1 5 7 8:8 5:16 3"
BRIDGE_BASS = "1:4 r:8 1:8 5 8 r 5"
BREAK_BASS = "1:16 1 8 r 1 r 8 7 r 7 5 r 8 r 1 r"
STEEL_ARP = "1:8 5 8 5 3' 5 8 5"

A_CHORDS = "| Fmaj7 | Am7 | Bbmaj7 | C7sus4 C7 | Fmaj7 | Am7 D7 | Gm7 | C7 |"

HOOK = """
    r:8 c5 f5 a5:8. g5:16 a5:4 c6:8 | a5:8 g5 e5 c5:4 r:8 d5 e5 |
    f5:8. d5 bb4:8 d5 f5 a5:4 | g5:4. f5:8 e5 f5 g5:4 |
    r:8 c5 f5 a5:8. g5:16 a5:4 c6:8 | e6:8. d6 c6:8 a5 f#5 a5:4 |
    bb5:8. a5 g5:8 f5 d5 f5 g5 |
"""
HOOK_END = "e5:4 g5 bb5:8 a5 g5:4 |"
HOOK_RISE = "e5:8 f5 g5 bb5 c6:2 |"

song.section("intro", "| Fmaj7 | Fmaj7 | Bbmaj7 | C7sus4 C7 |",
    lead=melody(BRASS, """
        r:8 c5 f5 a5:8. g5:16 a5:4 c6:8 | a5:8 g5 f5 c5:4 r:4. |
        r:8 d5 f5 bb5:8. a5:16 bb5:4 d6:8 | c6:4 bb5 g5 e5 |
    """),
    bass=bass(SLAP_BASS, FUNK_BASS, low=29),
    keys=Comp(CLAV, "..x...x...x...x.", low=60, high=76),
    drums=Drums(KIT, GROOVE, FILL, fill_every=4, crash=True),
)

song.section("A", A_CHORDS,
    lead=melody(BRASS, HOOK + HOOK_END),
    bass=bass(SLAP_BASS, FUNK_BASS, low=29),
    steel=arp(STEEL, STEEL_ARP, low=55),
    keys=Comp(CLAV, "..x...x...x...x.", low=60, high=76),
    drums=Drums(KIT, GROOVE, FILL, crash=True),
)

song.section("A2", A_CHORDS,
    lead=melody(BRASS, HOOK + HOOK_RISE),
    double=melody(STEEL_LEAD, HOOK + HOOK_RISE),
    bass=bass(SLAP_BASS, FUNK_BASS, low=29),
    keys=Comp(CLAV, "..x...x...x...x.", low=60, high=76),
    pad=Pad(PAD, low=53, high=72),
    drums=Drums(KIT, GROOVE, FILL, crash=True),
)

song.section("B", "| Bbmaj7 | C7 | Am7 | Dm7 | Gm7 | A7 | Dm7 G7 | C7sus4 C7 |",
    lead=melody(POP_LEAD, """
        d6:4. ~c6:8 a5:4 f5 | g5:4. a5:8 bb5:4 c6 |
        e6:4. ~d6:8 c6:4 a5 | f5:2 e5:8 f5 a5:4 |
        bb5:4. ~a5:8 g5:4 d6 | c#6:4. ~b5:8 a5:4 e5 |
        f5:4 a5 g5:8 b5 d6:4 | c6:2 r:8 bb5 a5 g5 |
    """),
    bass=bass(SLAP_BASS, BRIDGE_BASS, low=29),
    stabs=Pad(BRASS_STABS.copy(name="brass pad", gain_db=-14.0), low=55, high=72, voices=3, velocity=0.5),
    pad=Pad(PAD, low=53, high=72),
    steel=arp(STEEL, "1:8 5 8 5 3' 5 8 5", low=55),
    drums=Drums(KIT, BRIDGE_GROOVE, FILL, crash=True),
)

song.section("C", "| Dm7 | Dm7 | Gm7 | Gm7 | Dm7 | Dm7 | Bbmaj7 | C7 |",
    solo=melody(STEEL_SOLO, """
        a5:8 c6:16 d6 r:8 c6 a5 g5 f5 d5 | f5:8 g5 a5:4 r:8 c6 d6:4 |
        d6:8 bb5:16 c6 r:8 bb5 g5 f5 d5 f5 | g5:8 a5 bb5:4 r:8 d6 f6:4 |
        a5:8 c6:16 d6 r:8 c6 a5 g5 f5 d5 | f6:8 e6 d6 c6 a5 c6 d6:4 |
        d6:8. c6 bb5:8 a5 f5 d5:4 | e5:8 g5 bb5 c6 e6 g6 r:4 |
    """),
    bass=bass(SLAP_BASS, BREAK_BASS, low=29),
    stabs=Comp(BRASS_STABS, "......x.......x.", low=60, high=77, voices=3),
    keys=Comp(CLAV_FUNK, ".x.xx..x.x.x.xx.", low=60, high=74),
    drums=Drums(KIT, BREAK_GROOVE, BREAK_FILL, crash=True),
)

INTRO = ["intro"]
LOOP = ["A", "A2", "B", "C"]
