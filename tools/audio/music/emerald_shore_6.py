"""Emerald Shore Act 6: Tidal Cavern. Act 1's tune turned into a race against the tide: E minor,
a new tune on a synth lead grown from the hook's opening, a pulsing bass, percussion ticking like
a clock, and strings that climb as the water does.

Form: a four-bar intro of ticking under a swell, then a loop of A (the tune on a synth lead), A2
(the tune on brass and steel drums, rising), B (the tide: strings climbing over timpani) and C
(a ticking riff on marimba and bells, the clock running out), back to A.
"""
from instruments import ARP, BELL, BRASS, BRASS_STABS, KIT, MARIMBA, POP_LEAD, STEEL, STRINGS, SYNTH_BASS
from song import Comp, Drums, Pad, Song, arp, bass, melody

TEMPO = 148
FAST = 1.25  # Speed shoes play it this much faster.

song = Song("emerald_shore_6", tempo=TEMPO, key="E minor", reverb=2.0)

TIDE_LEAD = POP_LEAD.copy(name="tide lead", gain_db=-7.0)
STEEL_LEAD = STEEL.copy(name="steel lead", gain_db=-9.0, pan=0.15, echo=0.12)
TIDE_STRINGS = STRINGS.copy(name="tide strings", gain_db=-8.0)
LOW_STRINGS = STRINGS.copy(name="strings low", gain_db=-14.0)
TICK_MARIMBA = MARIMBA.copy(name="tick marimba", gain_db=-7.0, pan=-0.1)
TICK_BELLS = BELL.copy(name="tick bells", gain_db=-14.0, pan=0.3, echo=0.08)
PULSE = SYNTH_BASS.copy(name="pulse bass", gain_db=-9.0)  # Sixteenths all the way: well under the tune.
TIDE_KIT = dict(KIT, timpani=KIT["timpani"].copy(gain_db=-11.0))  # Timpani on every half bar, so softer.

INTRO_DRUMS = {
    "claves":  "x...x...x...x..." * 4,
    "hat":     "." * 32 + "x.x.x.x.x.x.x.x." * 2,
    "timpani": "." * 48 + "x...x...x.x.oooo",
}
TICK = {
    "kick":   "x..x..x...x..x..",
    "snare":  "....X.......X...",
    "hat":    "XoxoXoxoXoxoXoxo",
    "claves": "x...x...x...x...",
    "open":   "..............x.",
}
FILL = {
    "kick":  "x.....x.........",
    "snare": "....X.......xxXX",
    "hat":   "XoxoXoxo........",
    "tom1":  "........xx......",
    "tom2":  "..........xx....",
}
TIDE = {
    "kick":    "x.........x.....",
    "snare":   "........X.......",
    "hat":     "x.x.x.x.x.x.x.x.",
    "claves":  "x...x...x...x...",
    "timpani": "x.......x.......",
}
TIDE_FILL = {
    "kick":    "x.........x.....",
    "snare":   "........X...xxXX",
    "timpani": "x...x...x.x.oooo",  # Soft at the end: at speed-shoe tempo a roll of loud hits rings in phase.
}
RUN_OUT = {
    "kick":    "x...x...x...x...",
    "snare":   "....X..o....X..o",
    "hat":     "XoxoXoxoXoxoXoxo",
    "claves":  "x.x.x.x.x.x.x.x.",
    "timbale": "...............x",
}
RUN_FILL = {
    "kick":   "x.x.x.x.x.x.x.x.",
    "snare":  "x.x.x.x.xxxxXXXX",
    "hat":    "................",
    "claves": "................",
}

PULSE_BASS = "[1:16 1 8 1]*4"
TIDE_BASS = "1:8 1 1 1 5 5 8 8"
RUN_BASS = "1:16 r 1 8 r 1 5 r 1 r 8 7 r 5 8 r"

A_CHORDS = "| Em | Cmaj7 | Am7 | B7 | Em | Cmaj7 | Am7 D7 | B7sus4 B7 |"

TUNE = """
    r:8 b4 e5 g5:8. f#5:16 g5:4 b5:8 | c6:8. b5 g5:8 e5 c5:4 b4:8 |
    r:8 a4 c5 e5:8. d5:16 e5:4 a5:8 | b5:8. a5 f#5:8 d#5 b4:4 r:8 |
    r:8 b4 e5 g5:8. f#5:16 g5:4 b5:8 | e6:8. d6 c6:8 b5 g5:4 e5:8 |
    a5:8. g5 e5:8 c5 d5 f#5 a5 |
"""
TUNE_END = "b5:4. a5:8 f#5:4 d#5 |"
TUNE_RISE = "e5:8 f#5 a5 b5 d#6:2 |"

RIFF = """
    e5:16 b5 g5 b5 e5 b5 g5 b5 e6:8 b5 g5:4 | e5:16 c6 g5 c6 e5 c6 g5 c6 e6:8 c6 g5:4 |
    e5:16 c6 a5 c6 e5 c6 a5 c6 e6:8 c6 a5:4 | d#5:16 b5 f#5 b5 d#5 b5 f#5 b5 a5:8 f#5 d#5:4 |
    e5:16 b5 g5 b5 e5 b5 g5 b5 e6:8 b5 g5:4 | e5:16 c6 g5 c6 e5 c6 g5 c6 e6:8 c6 g5:4 |
    e5:16 c6 a5 c6 e5 c6 a5 c6 e6:8 c6 a5:4 | d#5:16 f#5 a5 b5 d#6 f#6 a6 b6 r:2 |
"""

song.section("intro", "| Em | Em | C | B7 |",
    lead=melody(TIDE_LEAD, "r:1 | r:1 | r:8 b4 e5 g5:8. f#5:16 g5:4 b5:8 | b5:4. a5:8 f#5:4 d#5 |"),
    bass=bass(PULSE, PULSE_BASS, low=31),
    strings=Pad(STRINGS, low=52, high=71),
    drums=Drums(TIDE_KIT, INTRO_DRUMS),
)

song.section("A", A_CHORDS,
    lead=melody(TIDE_LEAD, TUNE + TUNE_END),
    bass=bass(PULSE, PULSE_BASS, low=31),
    arp=arp(ARP, "[1:16 5 8 5]*4", low=59),
    strings=Pad(STRINGS, low=52, high=71),
    drums=Drums(TIDE_KIT, TICK, FILL, crash=True),
)

song.section("A2", A_CHORDS,
    lead=melody(BRASS, TUNE + TUNE_RISE),
    double=melody(STEEL_LEAD, TUNE + TUNE_RISE),
    bass=bass(PULSE, PULSE_BASS, low=31),
    stabs=Comp(BRASS_STABS, "......x.......x.", low=57, high=72),
    strings=Pad(STRINGS, low=52, high=71),
    drums=Drums(TIDE_KIT, TICK, FILL, crash=True),
)

song.section("B", "| Cmaj7 | D | Em | Em | Cmaj7 | D | B7sus4 | B7 |",
    lead=melody(TIDE_STRINGS, """
        e5:2 g5:4 b5 | a5:2 f#5:4 d5 | g5:2 b5:4 e6 | e6:2. r:4 |
        g5:2 b5:4 e6 | f#6:2 d6:4 a5 | b5:2 e6:4 f#6 | d#6:2 f#6:4 a6 |
    """),
    bass=bass(PULSE, TIDE_BASS, low=31),
    arp=arp(ARP, "[1:16 3 5 8]*4", low=59),
    pad=Pad(LOW_STRINGS, low=48, high=64),
    drums=Drums(TIDE_KIT, TIDE, TIDE_FILL, crash=True),
)

song.section("C", "| Em | C | Am | B7 | Em | C | Am | B7 |",
    riff=melody(TICK_MARIMBA, RIFF),
    bells=melody(TICK_BELLS, RIFF),
    bass=bass(PULSE, RUN_BASS, low=31),
    stabs=Comp(BRASS_STABS, "x.......x.......", low=57, high=72),
    strings=Pad(STRINGS, low=52, high=71),
    drums=Drums(TIDE_KIT, RUN_OUT, RUN_FILL, crash=True),
)

INTRO = ["intro"]
LOOP = ["A", "A2", "B", "C"]
