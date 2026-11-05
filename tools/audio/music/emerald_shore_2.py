"""Emerald Shore Act 2: Lush Palm Grove. Act 1's tune in the jungle: B-flat major with a bouncing
swing, brass and a wooden flute on the tune over a marimba, slap bass, and tom-toms, congas and
claves under it all.

Form: a four-bar intro of jungle drums, then a loop of A (the hook on brass over a marimba
pattern), A2 (the hook on the flute, the marimba doubling it, rising into the bridge), B (a
climbing bridge on the flute, a step higher every two bars, like the treetop route on its
springs) and C (a tom-tom breakdown with a marimba solo), back to A.
"""
from instruments import BRASS, BRASS_STABS, FLUTE, KIT, MARIMBA, PAD, SLAP_BASS
from song import Comp, Drums, Pad, Song, arp, bass, melody

TEMPO = 138
FAST = 1.25  # Speed shoes play it this much faster.

song = Song("emerald_shore_2", tempo=TEMPO, key="Bb major", swing=0.12)

MARIMBA_BED = MARIMBA.copy(name="marimba bed", gain_db=-12.0, pan=-0.25)
MARIMBA_DOUBLE = MARIMBA.copy(name="marimba double", gain_db=-10.0, pan=-0.1)
MARIMBA_SOLO = MARIMBA.copy(name="marimba solo", gain_db=-6.0, pan=0.05, echo=0.1)

INTRO_DRUMS = {
    "tom3":   "x..x....x..x...." * 4,
    "tom2":   "......x.......x." * 4,
    "shaker": "xoxoxoxoxoxoxoxo" * 4,
    "conga":  "." * 32 + "..x...x...x..x.x" * 2,
    "conga2": "." * 32 + "x..x...x.x..x..." * 2,
    "claves": "." * 32 + "x..x..x...x.x..." * 2,
    "kick":   "." * 48 + "x...x...x.x.x.xx",
    "snare":  "." * 48 + "....x...x.x.xxXX",
}
GROOVE = {
    "kick":   "x..x....x..x....",
    "snare":  "....X.......X...",
    "hat":    "x.x.x.x.x.x.x.x.",
    "shaker": "xoxoxoxoxoxoxoxo",
    "conga":  "..x...x...x..x..",
    "conga2": "x......x.x......",
    "claves": "x..x..x...x.x...",
    "tom3":   "...............x",
}
FILL = {
    "kick":  "x.....x.........",
    "snare": "....X...........",
    "hat":   "x.x.x.x.........",
    "tom1":  "........xx......",
    "tom2":  "..........xx....",
    "tom3":  "............xxxx",
}
CLIMB = {
    "kick":   "x...x...x...x...",
    "snare":  "....X.......X...",
    "clap":   "....x.......x...",
    "open":   "..x...x...x...x.",
    "shaker": "xoxoxoxoxoxoxoxo",
    "conga":  "..x..x....x..x..",
}
BREAK = {
    "kick":   "x.....x...x.....",
    "tom3":   "x..x....x..x....",
    "tom2":   "......x.......x.",
    "tom1":   "..........x.....",
    "snare":  "....o.......o...",
    "conga":  "..x..x.x..x..x.x",
    "claves": "x..x..x...x.x...",
    "shaker": "xoxoxoxoxoxoxoxo",
}
BREAK_FILL = {
    "kick": "x.....x.........",
    "tom1": "x.x.x.x.........",
    "tom2": "........x.x.x...",
    "tom3": "..............xx",
}

BOUNCE_BASS = "1:8 r 8 r 5:16 5 r:8 1:8 8:16 r"
CLIMB_BASS = "1:8 1 8 1 5 1 8 5"
BREAK_BASS = "1:8. 1:16 r:8 8 r 5 7 8"
MARIMBA_PATTERN = "1:16 5 8 r 5 8 3' r 8 5 1 r 5 8 3' 5"

A_CHORDS = "| Bbmaj7 | Dm7 | Ebmaj7 | F7sus4 F7 | Bbmaj7 | Dm7 G7 | Cm7 | F7 |"

HOOK = """
    r:8 f4 bb4 d5:8. c5:16 d5:4 f5:8 | d5:8 c5 a4 f4:4 r:8 g4 a4 |
    bb4:8. g4 eb4:8 g4 bb4 d5:4 | c5:4. bb4:8 a4 bb4 c5:4 |
    r:8 f4 bb4 d5:8. c5:16 d5:4 f5:8 | a5:8. g5 f5:8 d5 b4 d5:4 |
    eb5:8. d5 c5:8 bb4 g4 bb4 c5 |
"""
HOOK_END = "a4:4 c5 eb5:8 d5 c5:4 |"
HOOK_RISE = "a4:8 bb4 c5 eb5 f5:2 |"

song.section("intro", "| Bbmaj7 | Bbmaj7 | Ebmaj7 | F7sus4 F7 |",
    lead=melody(FLUTE, "r:1 | r:2 r:8 f4 bb4 c5 | d5:8. c5:16 d5:4 g5 bb5:8 g5 | bb5:4. c6:8 a5:4 eb5 |"),
    bass=bass(SLAP_BASS, BOUNCE_BASS, low=29),
    marimba=arp(MARIMBA_BED, MARIMBA_PATTERN, low=58),
    drums=Drums(KIT, INTRO_DRUMS),
)

song.section("A", A_CHORDS,
    lead=melody(BRASS, HOOK + HOOK_END),
    bass=bass(SLAP_BASS, BOUNCE_BASS, low=29),
    marimba=arp(MARIMBA_BED, MARIMBA_PATTERN, low=58),
    drums=Drums(KIT, GROOVE, FILL, crash=True),
)

song.section("A2", A_CHORDS,
    lead=melody(FLUTE, HOOK + HOOK_RISE, transpose=12),
    double=melody(MARIMBA_DOUBLE, HOOK + HOOK_RISE),
    bass=bass(SLAP_BASS, BOUNCE_BASS, low=29),
    stabs=Comp(BRASS_STABS, "......x.......x.", low=58, high=74),
    pad=Pad(PAD, low=53, high=72),
    drums=Drums(KIT, GROOVE, FILL, crash=True),
)

song.section("B", "| Gm7 | Ebmaj7 | F7sus4 | Bbmaj7 | Gm7 | Ebmaj7 | Cm7 | F7sus4 F7 |",
    lead=melody(FLUTE, """
        d5:8 f5 g5:4 bb5:8 a5 g5:4 | g5:4. f5:8 eb5:4 d5 |
        f5:8 a5 c6:4 eb6:8 d6 c6:4 | d6:2 r:4 bb5:8 c6 |
        f5:8 g5 bb5:4 d6:8 c6 bb5:4 | bb5:4. g5:8 eb6:4 d6 |
        c6:8 eb6 g6:4 eb6:8 f6 g6:4 | f6:4 eb6:8 c6 a5:4 c6:8 eb6 |
    """),
    bass=bass(SLAP_BASS, CLIMB_BASS, low=29),
    marimba=arp(MARIMBA_BED, "1:8 5 8 5 3' 5 8 5", low=58),
    stabs=Pad(BRASS_STABS.copy(name="brass pad", gain_db=-14.0), low=55, high=72, voices=3, velocity=0.5),
    pad=Pad(PAD, low=53, high=72),
    drums=Drums(KIT, CLIMB, FILL, crash=True),
)

song.section("C", "| Gm7 | Gm7 | Cm7 | Cm7 | Gm7 | Gm7 | Ebmaj7 | F7 |",
    solo=melody(MARIMBA_SOLO, """
        g5:16 bb5 d6 f6 d6:8 bb5 r:8 g5:16 a5 bb5:8 d6 | f6:8 d6 bb5 g5 f5:4 r:8 d5 |
        eb5:16 g5 c6 eb6 c6:8 g5 r:8 eb5:16 f5 g5:8 c6 | bb5:8 g5 eb5 g5 c6:4 r:8 bb5 |
        d6:16 c6 bb5 a5 bb5:8 g5 d6:8 f6 r:8 g6 | f6:8 d6 f6 g6 bb6:4 g6:8 f6 |
        eb6:8. d6 bb5:8 g5 eb5 g5:4 | f5:8 a5 c6 eb6 f6:4 r:4 |
    """),
    bass=bass(SLAP_BASS, BREAK_BASS, low=29),
    stabs=Comp(BRASS_STABS, "......x.......x.", low=58, high=74),
    drums=Drums(KIT, BREAK, BREAK_FILL, crash=True),
)

INTRO = ["intro"]
LOOP = ["A", "A2", "B", "C"]
