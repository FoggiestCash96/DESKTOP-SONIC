"""Emerald Shore Act 7: Sunset Ridge Cliffs. Act 1's tune at full tilt into the evening: E-flat
major and the fastest of the shore's acts, brass and strings over a driving slap bass, a warm
synth lead for the sunset, and, as the fortress comes into view, a stormy turn to C minor that
Act 8 takes up.

Form: a four-bar intro on brass and strings, then a loop of A (the hook on brass over steel
drums), A2 (the hook on brass and steel drums together, rising), B (a wistful bridge on a synth
lead over a half-time beat) and C (Act 8's stormy hook in C minor on dark brass, with thunder and
timpani, rising back into E-flat), back to A.
"""
from instruments import BRASS, BRASS_STABS, KIT, PAD, POP_LEAD, SLAP_BASS, STEEL, STRINGS, SYNTH_BASS
from song import Comp, Drums, Pad, Song, arp, bass, melody

TEMPO = 164
FAST = 1.25  # Speed shoes play it this much faster.

song = Song("emerald_shore_7", tempo=TEMPO, key="Eb major", swing=0.04)

STEEL_LEAD = STEEL.copy(name="steel lead", gain_db=-9.0, pan=0.15, echo=0.12)
SUNSET_LEAD = POP_LEAD.copy(name="sunset lead", gain_db=-7.0, echo=0.28)
DARK_BRASS = BRASS.copy(name="dark brass", lowpass=7000.0)
HIGH_STRINGS = STRINGS.copy(name="strings high", gain_db=-13.0)
STORM_DRIVE = SYNTH_BASS.copy(name="storm bass", gain_db=-9.0)  # Sixteenths all the way: well under the tune.
RIDGE_KIT = dict(KIT, timpani=KIT["timpani"].copy(gain_db=-10.0))  # Timpani on every half bar in C, so softer.

INTRO_DRUMS = {
    "crash":   "x" + "." * 31 + "x" + "." * 31,
    "timpani": "x" + "." * 31 + "x" + "." * 31,
    "kick":    "x.......x......." * 2 + "x...x...x...x..." + "x...x...x.x.x.xx",
    "snare":   "." * 48 + "....x...x.x.xxXX",
}
GALLOP = {
    "kick":   "x..x..x...x..x..",
    "snare":  "....X.......X...",
    "hat":    "x.x.x.x.x.x.x.x.",
    "open":   "..............x.",
    "shaker": "xoxoxoxoxoxoxoxo",
}
FILL = {
    "kick":  "x.....x.........",
    "snare": "....X.......xxXX",
    "hat":   "x.x.x.x.........",
    "tom1":  "........xx......",
    "tom2":  "..........xx....",
}
HALF = {
    "kick":   "x.........x.....",
    "snare":  "........X.......",
    "hat":    "x.x.x.x.x.x.x.x.",
    "open":   "..x...x...x...x.",
    "shaker": "xoxoxoxoxoxoxoxo",
}
STORM = {
    "kick":    "x..x..x.x.......",
    "snare":   "....X.......X...",
    "hat":     "x.x.x.x.x.x.x.x.",
    "open":    "......x.......x.",
    "timpani": "x.......x.......",
    "thunder": "x" + "." * 127,
}
STORM_FILL = {
    "kick":    "x...x...x...x...",
    "snare":   "....X...x.x.xxXX",
    "timpani": "x...x...x.x.xxxx",
    "tom1":    "........xx......",
}

RIDGE_BASS = "1:8 8:16 r 1:8 8 r:16 1 5:8 8 7"
SUNSET_BASS = "1:4. 5:8 8:4 5:8 1"
STORM_BASS = "1:16 1 8 1 r 1 8 1 5 1 8 1 7 1 8 1"

A_CHORDS = "| Ebmaj7 | Gm7 | Abmaj7 | Bb7sus4 Bb7 | Ebmaj7 | Gm7 C7 | Fm7 | Bb7 |"

HOOK = """
    r:8 bb4 eb5 g5:8. f5:16 g5:4 bb5:8 | g5:8 f5 d5 bb4:4 r:8 c5 d5 |
    eb5:8. c5 ab4:8 c5 eb5 g5:4 | f5:4. eb5:8 d5 eb5 f5:4 |
    r:8 bb4 eb5 g5:8. f5:16 g5:4 bb5:8 | d6:8. c6 bb5:8 g5 e5 g5:4 |
    ab5:8. g5 f5:8 eb5 c5 eb5 f5 |
"""
HOOK_END = "d5:4 f5 ab5:8 g5 f5:4 |"
HOOK_RISE = "d5:8 eb5 f5 ab5 bb5:2 |"

STORM_HOOK = """
    r:8 g4 c5 eb5:8. d5:16 eb5:4 g5:8 | eb5:8 d5 c5 g4:4 r:8 bb4 c5 |
    c5:8. ab4 f4:8 ab4 c5 eb5:4 | d5:4. c5:8 bb4 c5 d5:4 |
    r:8 g4 c5 eb5:8. d5:16 eb5:4 g5:8 | bb5:8. ab5 g5:8 eb5 c5 eb5:4 |
    f5:8. eb5 d5:8 c5 ab4 c5 d5 | d5:8 eb5 f5 ab5 bb5:2 |
"""

song.section("intro", "| Ebmaj7 | Cm7 | Abmaj7 | Bb7sus4 Bb7 |",
    lead=melody(BRASS, "r:2 r:8 bb4 eb5 f5 | g5:4. f5:8 eb5:4 bb4 | c5:4 eb5 ab5 c6 | bb5:2 ab5:4 d5 |"),
    bass=bass(SLAP_BASS, "1:4. 1:8 8:4 5", low=31),
    strings=Pad(STRINGS, low=55, high=74),
    drums=Drums(RIDGE_KIT, INTRO_DRUMS),
)

song.section("A", A_CHORDS,
    lead=melody(BRASS, HOOK + HOOK_END),
    bass=bass(SLAP_BASS, RIDGE_BASS, low=31),
    steel=arp(STEEL, "1:8 5 8 5 3' 5 8 5", low=58),
    strings=Pad(STRINGS, low=55, high=74),
    drums=Drums(RIDGE_KIT, GALLOP, FILL, crash=True),
)

song.section("A2", A_CHORDS,
    lead=melody(BRASS, HOOK + HOOK_RISE),
    double=melody(STEEL_LEAD, HOOK + HOOK_RISE),
    bass=bass(SLAP_BASS, RIDGE_BASS, low=31),
    stabs=Comp(BRASS_STABS, "......x.......x.", low=58, high=75),
    strings=Pad(HIGH_STRINGS, low=60, high=79),
    drums=Drums(RIDGE_KIT, GALLOP, FILL, crash=True),
)

song.section("B", "| Cm7 | Abmaj7 | Bb | Gm7 | Cm7 | Abmaj7 | Fm7 | Bb7sus4 Bb7 |",
    lead=melody(SUNSET_LEAD, """
        g5:4. ~f5:8 eb5:4 c5 | eb5:4. f5:8 g5:4 c6 |
        bb5:4. ~ab5:8 f5:4 d5 | f5:2 d5:4 bb4 |
        g5:4. ~f5:8 eb5:4 g5 | c6:4. ~bb5:8 ab5:4 eb5 |
        f5:4 ab5 c6 eb6 | f6:2 d6:4 bb5 |
    """),
    bass=bass(SLAP_BASS, SUNSET_BASS, low=31),
    strings=Pad(STRINGS, low=55, high=74),
    pad=Pad(PAD, low=53, high=72),
    drums=Drums(RIDGE_KIT, HALF, FILL, crash=True),
)

song.section("C", "| Cm | Cm | Ab | Bb | Cm | Cm | Fm | Bb7 |",
    lead=melody(DARK_BRASS, STORM_HOOK),
    stabs=Comp(BRASS_STABS, "x..x..x...x...x.", low=55, high=72),
    strings=Pad(STRINGS, low=50, high=70),
    bass=bass(STORM_DRIVE, STORM_BASS, low=31),
    drums=Drums(RIDGE_KIT, STORM, STORM_FILL, crash=True),
)

INTRO = ["intro"]
LOOP = ["A", "A2", "B", "C"]
