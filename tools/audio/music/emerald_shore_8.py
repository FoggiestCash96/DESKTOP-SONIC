"""Emerald Shore Act 8: Stormy Coastal Fortress. Act 1's tune turned stormy: D minor, driving
synth bass, brass and strings, timpani and thunder, and the steel drums in a minor key.

Form: a four-bar intro under thunder, then a loop of A (the hook in minor), A2 (the hook with
steel drums, rising), B (a lift into the relative major on strings and a synth lead) and C (a
pounding steel drum riff with brass stabs), back to A.
"""
from instruments import ARP, BRASS, BRASS_STABS, KIT, POP_LEAD, STEEL, STRINGS, SYNTH_BASS
from song import Comp, Drums, Pad, Song, arp, bass, melody

TEMPO = 156
FAST = 1.25

song = Song("emerald_shore_8", tempo=TEMPO, key="D minor", reverb=2.0)

DARK_BRASS = BRASS.copy(name="dark brass", lowpass=7000.0)
STEEL_LEAD = STEEL.copy(name="steel lead", gain_db=-9.0, pan=0.15, echo=0.12)
STEEL_RIFF = STEEL.copy(name="steel riff", gain_db=-6.0, pan=0.1, echo=0.14)
STORM_LEAD = POP_LEAD.copy(name="storm lead", gain_db=-8.0)

INTRO_DRUMS = {
    "thunder": "x" + "." * 63,
    "timpani": "x...x...x...x..." "x...x...x...x..." "x.......x......." "x.x.x.x.xxxxxxxx",
    "crash":   "x" + "." * 63,
}
GROOVE = {
    "kick":  "x..x..x.x.......",
    "snare": "....X.......X...",
    "hat":   "x.x.x.x.x.x.x.x.",
    "open":  "......x.......x.",
    "timpani": "x" + "." * 63,
}
FILL = {
    "kick":  "x.....x.........",
    "snare": "....X.......xxXX",
    "tom1":  "........xx......",
    "tom2":  "..........xx....",
    "tom3":  "............xx..",
}
HALF_TIME = {
    "kick":  "x.........x.....",
    "snare": "........X.......",
    "hat":   "x.x.x.x.x.x.x.x.",
    "open":  "..x...x...x...x.",
    "thunder": "x" + "." * 127,
}
POUND = {
    "kick":  "x..x..x.x..x..x.",
    "snare": "....X..o....X..o",
    "hat":   "XoxoXoxoXoxoXoxo",
    "tom3":  "x...............",
    "timpani": "x.......x.......",
}

A_CHORDS = "| Dm | Dm | Bb | C | Dm | Dm | Gm | A7 |"
HOOK = """
    r:8 a4 d5 f5:8. e5:16 f5:4 a5:8 | f5:8 e5 d5 a4:4 r:8 c5 d5 |
    d5:8. bb4 g4:8 bb4 d5 f5:4 | e5:4. d5:8 c5 d5 e5:4 |
    r:8 a4 d5 f5:8. e5:16 f5:4 a5:8 | c6:8. bb5 a5:8 f5 d5 f5:4 |
    g5:8. f5 e5:8 d5 bb4 d5 e5 |
"""
DRIVE_BASS = "1:16 1 r 1 8:8 1:16 1 r 1 5:8 8 1"

song.section("intro", "| Dm | Dm | Bb | A7 |",
    lead=melody(DARK_BRASS, "r:1 | r:2 a4:8 d5 f5 a5 | bb5:4. a5:8 g5:4 f5 | e5:2 c#5:4 a4 |"),
    bass=bass(SYNTH_BASS, "1:1", low=33),
    strings=Pad(STRINGS, low=50, high=70),
    drums=Drums(KIT, INTRO_DRUMS),
)

song.section("A", A_CHORDS,
    lead=melody(DARK_BRASS, HOOK + "c#5:4 e5 g5:8 f5 e5:4 |"),
    bass=bass(SYNTH_BASS, DRIVE_BASS, low=33),
    strings=Pad(STRINGS, low=50, high=70),
    arp=arp(ARP, "[1:16 3 5 8]*4", low=57),
    drums=Drums(KIT, GROOVE, FILL, crash=True),
)

song.section("A2", A_CHORDS,
    lead=melody(DARK_BRASS, HOOK + "c#5:8 d5 e5 g5 a5:2 |"),
    double=melody(STEEL_LEAD, HOOK + "c#5:8 d5 e5 g5 a5:2 |"),
    bass=bass(SYNTH_BASS, DRIVE_BASS, low=33),
    strings=Pad(STRINGS, low=50, high=70),
    stabs=Comp(BRASS_STABS, "......x.......x.", low=57, high=72),
    drums=Drums(KIT, GROOVE, FILL, crash=True),
)

song.section("B", "| Bbmaj7 | C | Am7 | Dm | Gm7 | C | Fmaj7 | A7 |",
    lead=melody(STORM_LEAD, """
        f5:4. ~e5:8 d5:4 bb4 | c5:4. d5:8 e5:4 g5 |
        a5:4. ~g5:8 e5:4 c5 | d5:2 f5:4 a5 |
        bb5:4. ~a5:8 g5:4 d5 | e5:4. f5:8 g5:4 c6 |
        a5:4. ~g5:8 f5:4 c5 | e5:2 r:8 c#5 d5 e5 |
    """),
    bass=bass(SYNTH_BASS, "1:4. 5:8 8:4 5:8 1:8", low=33),
    strings=Pad(STRINGS.copy(name="strings high", gain_db=-13.0), low=55, high=76),
    arp=arp(ARP, "[1:16 3 5 8]*4", low=57),
    drums=Drums(KIT, HALF_TIME, FILL, crash=True),
)

song.section("C", "| Dm | Bb | Gm | A | Dm | Bb | Gm | A7 |",
    riff=melody(STEEL_RIFF, """
        d5:16 f5 a5 d6 r:8 a5 f5:16 a5 d6 r:16 c6:8 a5 | d5:16 f5 bb5 d6 r:8 bb5 f5:16 bb5 d6 r:16 c6:8 bb5 |
        d5:16 g5 bb5 d6 r:8 bb5 g5:16 bb5 d6 r:16 c6:8 bb5 | c#5:16 e5 a5 c#6 r:8 a5 e5:16 a5 c#6 r:16 e6:8 c#6 |
        d5:16 f5 a5 d6 r:8 a5 f5:16 a5 d6 r:16 c6:8 a5 | d5:16 f5 bb5 d6 r:8 bb5 f5:16 bb5 d6 r:16 c6:8 bb5 |
        d5:16 g5 bb5 d6 r:8 bb5 g5:16 bb5 d6 r:16 c6:8 bb5 | c#6:8 a5 e5 c#5 e5:4 r:4 |
    """),
    bass=bass(SYNTH_BASS, "1:16 1 8 1 1 8 1 5 1 1 8 1 7 8 5 8", low=33),
    stabs=Comp(BRASS_STABS, "x..x..x...x...x.", low=57, high=74),
    strings=Pad(STRINGS, low=50, high=70),
    drums=Drums(KIT, POUND, FILL, crash=True),
)

INTRO = ["intro"]
LOOP = ["A", "A2", "B", "C"]
