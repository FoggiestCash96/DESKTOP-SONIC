"""Emerald Shore Act 4: Shallow Reef Lagoon. Act 1's tune as a calypso to fight to: C major,
steel drums on the tune, punching brass, slap bass, clavinet, cowbell and timbales; a glassy
bridge for the reef under the water, and a brass riff for the badnik packs.

Form: a four-bar intro on the timbales, then a loop of A (the hook on steel drums, brass punching
between its phrases), A2 (the hook on brass and steel drums together, rising), B (a slow, glassy
bridge on a soft synth over electric piano, as if under water) and C (a brass riff in A minor
over tom-toms and timbales), back to A.
"""
from instruments import BELL, BRASS, BRASS_STABS, CLAV, EPIANO, KIT, PAD, POP_LEAD, SLAP_BASS, STEEL
from song import Comp, Drums, Pad, Song, arp, bass, melody

TEMPO = 146
FAST = 1.25  # Speed shoes play it this much faster.

song = Song("emerald_shore_4", tempo=TEMPO, key="C major", swing=0.08)

STEEL_LEAD = STEEL.copy(name="steel lead", gain_db=-6.0, pan=0.1, echo=0.12)
STEEL_DOUBLE = STEEL.copy(name="steel double", gain_db=-10.0, pan=0.2, echo=0.12)
REEF_LEAD = POP_LEAD.copy(name="reef lead", gain_db=-8.0, lowpass=3200.0, echo=0.3)
CLAV_SOCA = CLAV.copy(name="clav soca", gain_db=-13.0)
REEF_PIANO = EPIANO.copy(name="reef piano", gain_db=-15.0)
BUBBLES = BELL.copy(name="bubbles", gain_db=-15.0, pan=-0.3, echo=0.25)

INTRO_DRUMS = {
    "crash":    "x" + "." * 63,
    "timbale":  "x..x..x...x.x..." * 3 + "x.x.x.x.xxxxxxxx",
    "timbale2": "..x...x...x...x." * 3 + "........x.x.x.x.",
    "cowbell":  "x...x...x...x..." * 4,
    "kick":     "." * 48 + "x...x...x...x...",
}
SOCA = {
    "kick":    "x...x...x...x...",
    "snare":   "....X.......X...",
    "hat":     "..x...x...x...x.",
    "cowbell": "x..x..x...x.x...",
    "conga":   "..x..x....x..x..",
    "conga2":  "x......x.x......",
    "shaker":  "xoxoxoxoxoxoxoxo",
}
FILL = {
    "kick":     "x...x...x.......",
    "snare":    "....X...........",
    "hat":      "..x...x.........",
    "cowbell":  "x...x...........",
    "timbale":  "........x.x.x.xx",
    "timbale2": ".........x.x.x..",
}
LAGOON = {
    "kick":   "x.........x.....",
    "snare":  "........o.......",
    "shaker": "xoxoxoxoxoxoxoxo",
    "conga":  "......x.......x.",
    "claves": "x..x..x...x.x...",
}
FIGHT = {
    "kick":    "x..x..x.x..x..x.",
    "snare":   "....X.......X...",
    "tom3":    "x.......x.......",
    "tom2":    "......x.......x.",
    "hat":     "x.x.x.x.x.x.x.x.",
    "timbale": "...x......x....x",
}
FIGHT_FILL = {
    "kick":     "x.....x.........",
    "snare":    "....X...........",
    "tom1":     "x.x.............",
    "timbale":  "........x.x.x.xx",
    "timbale2": ".........x.x.x..",
}

SOCA_BASS = "1:8 r:16 1 r:8 8 r 5 r:16 5 8:8"
LAGOON_BASS = "1:2 5:4 8"
FIGHT_BASS = "1:8 1:16 1 8:8 1 r:16 1 5:8 7 8"

A_CHORDS = "| Cmaj7 | Em7 | Fmaj7 | G7sus4 G7 | Cmaj7 | Em7 A7 | Dm7 | G7 |"

HOOK = """
    r:8 g4 c5 e5:8. d5:16 e5:4 g5:8 | e5:8 d5 b4 g4:4 r:8 a4 b4 |
    c5:8. a4 f4:8 a4 c5 e5:4 | d5:4. c5:8 b4 c5 d5:4 |
    r:8 g4 c5 e5:8. d5:16 e5:4 g5:8 | b5:8. a5 g5:8 e5 c#5 e5:4 |
    f5:8. e5 d5:8 c5 a4 c5 d5 |
"""
HOOK_END = "b4:4 d5 f5:8 e5 d5:4 |"
HOOK_RISE = "b4:8 c5 d5 f5 g5:2 |"

RIFF = """
    a4:8. a4:16 r:8 c5 e5:8. d5:16 r:8 c5 | a4:8. a4:16 r:8 c5 e5:8 g5 a5:4 |
    f4:8. f4:16 r:8 a4 c5:8. b4:16 r:8 a4 | g4:8. g4:16 r:8 b4 d5:8 f5 g5:4 |
    a4:8. a4:16 r:8 c5 e5:8. d5:16 r:8 c5 | a4:8. a4:16 r:8 c5 e5:8 g5 a5:4 |
    f4:8. f4:16 r:8 a4 c5:8. b4:16 r:8 a4 | g4:8 b4 d5 f5 g5:8 f5 d5 b4 |
"""

song.section("intro", "| C | C | F | G7 |",
    lead=melody(STEEL_LEAD, "r:1 | r:1 | r:8 g5 c6 e6:8. d6:16 e6:4 g6:8 | f6:4 d6 b5 g5 |"),
    bass=bass(SLAP_BASS, SOCA_BASS, low=28),
    drums=Drums(KIT, INTRO_DRUMS),
)

song.section("A", A_CHORDS,
    lead=melody(STEEL_LEAD, HOOK + HOOK_END, transpose=12),
    stabs=Comp(BRASS_STABS, "......x.......x.", low=60, high=76),
    bass=bass(SLAP_BASS, SOCA_BASS, low=28),
    keys=Comp(CLAV_SOCA, "..x...x...x...x.", low=60, high=76),
    drums=Drums(KIT, SOCA, FILL, crash=True),
)

song.section("A2", A_CHORDS,
    lead=melody(BRASS, HOOK + HOOK_RISE),
    double=melody(STEEL_DOUBLE, HOOK + HOOK_RISE, transpose=12),
    bass=bass(SLAP_BASS, SOCA_BASS, low=28),
    keys=Comp(CLAV_SOCA, "..x...x...x...x.", low=60, high=76),
    pad=Pad(PAD, low=53, high=72),
    drums=Drums(KIT, SOCA, FILL, crash=True),
)

song.section("B", "| Am7 | Fmaj7 | Cmaj7 | G | Am7 | Fmaj7 | Dm7 | Esus4 E7 |",
    lead=melody(REEF_LEAD, """
        e5:4. ~d5:8 c5:4 a4 | c5:4. d5:8 e5:4 f5 |
        e5:2 g5:4 b5 | b5:4. a5:8 g5:2 |
        e5:4. ~d5:8 c5:4 e5 | a5:4. g5:8 f5:4 c5 |
        d5:4 f5 a5 c6 | b5:2 g#5:4 e5 |
    """),
    piano=Comp(REEF_PIANO, "x.....x.....x...", low=57, high=74, voices=4),
    bubbles=melody(BUBBLES, """
        r:2 e6:16 a6 c7:8 r:4 | r:1 | r:2 g6:16 c7 e7:8 r:4 | r:1 |
        r:2 e6:16 a6 c7:8 r:4 | r:1 | r:2 f6:16 a6 d7:8 r:4 | r:1 |
    """),
    pad=Pad(PAD, low=53, high=72),
    bass=bass(SLAP_BASS, LAGOON_BASS, low=28),
    drums=Drums(KIT, LAGOON, FILL, crash=True),
)

song.section("C", "| Am | Am | F | G | Am | Am | F | G7 |",
    riff=melody(BRASS, RIFF),
    stabs=Comp(BRASS_STABS, "x..x..x...x...x.", low=57, high=74),
    steel=arp(STEEL_DOUBLE, "r:4 1:16 5 8 5 r:4 3:16 5 8 5", low=60),
    bass=bass(SLAP_BASS, FIGHT_BASS, low=28),
    drums=Drums(KIT, FIGHT, FIGHT_FILL, crash=True),
)

INTRO = ["intro"]
LOOP = ["A", "A2", "B", "C"]
