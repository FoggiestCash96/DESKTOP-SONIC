"""Emerald Shore Act 3: Cascading Waterfall Basin. Act 1's tune at a sprint: D major and faster,
with arpeggios tumbling down like the falls, bells for the spray, a driving octave bass and
four-on-the-floor drums.

Form: a four-bar intro of falling arpeggios that the drums build under, then a loop of A (the
hook on brass), A2 (the hook again, a synth lead doubling it an octave up, rising), B (a broad
climb on the synth lead over rising arpeggios, for the tiers) and C (a cascade of bells over a
half-time beat that rolls back into A), back to A.
"""
from instruments import ARP, BELL, BRASS, BRASS_STABS, KIT, PAD, POP_LEAD, STRINGS, SYNTH_BASS
from song import Comp, Drums, Pad, Song, arp, bass, melody

TEMPO = 162
FAST = 1.25  # Speed shoes play it this much faster.

song = Song("emerald_shore_3", tempo=TEMPO, key="D major", swing=0.03)

CASCADE = ARP.copy(name="cascade", gain_db=-13.0, echo=0.25)
SPRAY = BELL.copy(name="spray bells", gain_db=-14.0, pan=0.35, echo=0.2)
FALLS_BELLS = BELL.copy(name="falls bells", gain_db=-11.0, pan=0.15, echo=0.08)
FALLS_ARP = ARP.copy(name="falls arp", gain_db=-13.0, pan=-0.2, echo=0.1)
CLIMB_LEAD = POP_LEAD.copy(name="climb lead", gain_db=-7.0)
LEAD_DOUBLE = POP_LEAD.copy(name="lead double", gain_db=-13.0, pan=-0.15)
DRIVE = SYNTH_BASS.copy(name="drive bass", gain_db=-8.0)  # Octaves on every eighth: quieter than a sparser line.

INTRO_DRUMS = {
    "crash":  "x" + "." * 63,
    "shaker": "xoxoxoxoxoxoxoxo" * 4,
    "open":   "." * 16 + "..x...x...x...x." * 3,
    "kick":   "." * 32 + "x...x...x...x..." + "x...x...x.x.x.xx",
    "snare":  "." * 48 + "....x...x.x.xxXX",
}
GROOVE = {
    "kick":   "x...x...x...x...",
    "snare":  "....X.......X...",
    "clap":   "....x.......x...",
    "hat":    "x...x...x...x...",
    "open":   "..x...x...x...x.",
    "shaker": "xoxoxoxoxoxoxoxo",
}
FILL = {
    "kick":  "x...x...x.......",
    "snare": "....X.......xxXX",
    "open":  "..x...x.........",
    "tom1":  "........xx......",
    "tom2":  "..........xx....",
}
HALF = {
    "kick":   "x.........x.....",
    "snare":  "........X.......",
    "hat":    "x.x.x.x.x.x.x.x.",
    "shaker": "xoxoxoxoxoxoxoxo",
}
ROLL = {
    "kick":  "x...x...x...x...",
    "snare": "x.x.x.x.xxxxXXXX",
    "hat":   "................",
}

DRIVE_BASS = "1:8 8 1 8 1 8 1 8"
CLIMB_BASS = "1:4. 5:8 8:4 5:8 1"
HALF_BASS = "1:2 r:8 5 8 5"
SPRAY_LINE = "r:2 a6:8 f#6 d6:4 | r:1 |"

A_CHORDS = "| Dmaj7 | F#m7 | Gmaj7 | A7sus4 A7 | Dmaj7 | F#m7 B7 | Em7 | A7 |"

HOOK = """
    r:8 a4 d5 f#5:8. e5:16 f#5:4 a5:8 | f#5:8 e5 c#5 a4:4 r:8 b4 c#5 |
    d5:8. b4 g4:8 b4 d5 f#5:4 | e5:4. d5:8 c#5 d5 e5:4 |
    r:8 a4 d5 f#5:8. e5:16 f#5:4 a5:8 | c#6:8. b5 a5:8 f#5 d#5 f#5:4 |
    g5:8. f#5 e5:8 d5 b4 d5 e5 |
"""
HOOK_END = "c#5:4 e5 g5:8 f#5 e5:4 |"
HOOK_RISE = "c#5:8 d5 e5 g5 a5:2 |"

FALLS = """
    f#6:16 d6 b5 g5 f#6 d6 b5 g5 g6:8 f#6 d6:4 | e6:16 c#6 a5 f#5 e6 c#6 a5 f#5 f#6:8 e6 c#6:4 |
    d6:16 b5 g5 e5 d6 b5 g5 e5 e6:8 d6 b5:4 | c#6:16 a5 f#5 d5 c#6 a5 f#5 d5 d6:8 c#6 a5:4 |
    f#6:16 d6 b5 g5 f#6 d6 b5 g5 g6:8 f#6 d6:4 | e6:16 c#6 a5 f#5 e6 c#6 a5 f#5 f#6:8 e6 c#6:4 |
    d6:16 b5 g5 e5 d6 b5 g5 e5 e6:8 d6 b5:4 | e6:16 d6 b5 a5 e6 d6 b5 a5 c#6:8 e6 g6:4 |
"""

song.section("intro", "| Dmaj7 | Bm7 | Gmaj7 | A7sus4 A7 |",
    lead=melody(BRASS, "r:1 | r:1 | r:8 a4 d5 f#5:8. e5:16 f#5:4 a5:8 | a5:4 g5 e5 c#5 |"),
    cascade=arp(CASCADE, "[8:16 5 3 1]*4", low=62),
    spray=melody(SPRAY, "r:2 a6:8 f#6 d6:4 | r:1 | r:2 b6:8 g6 d6:4 | r:2 c#7:8 a6 e6:4 |"),
    strings=Pad(STRINGS, low=55, high=74),
    drums=Drums(KIT, INTRO_DRUMS),
)

song.section("A", A_CHORDS,
    lead=melody(BRASS, HOOK + HOOK_END),
    bass=bass(DRIVE, DRIVE_BASS, low=33),
    cascade=arp(CASCADE, "[8:16 5 3 1]*4", low=62),
    spray=melody(SPRAY, SPRAY_LINE),
    strings=Pad(STRINGS, low=55, high=74),
    drums=Drums(KIT, GROOVE, FILL, crash=True),
)

song.section("A2", A_CHORDS,
    lead=melody(BRASS, HOOK + HOOK_RISE),
    double=melody(LEAD_DOUBLE, HOOK + HOOK_RISE, transpose=12),
    bass=bass(DRIVE, DRIVE_BASS, low=33),
    cascade=arp(CASCADE, "[8:16 5 3 1]*4", low=62),
    stabs=Comp(BRASS_STABS, "......x.......x.", low=57, high=74),
    drums=Drums(KIT, GROOVE, FILL, crash=True),
)

song.section("B", "| Bm7 | Gmaj7 | Em7 | A7sus4 A7 | Bm7 | Gmaj7 | Em7 F#m7 | Gmaj7 A7 |",
    lead=melody(CLIMB_LEAD, """
        f#5:4. ~e5:8 d5:4 b4 | d5:4. e5:8 f#5:4 b5 |
        g5:4. ~f#5:8 e5:4 b4 | e5:2 c#5:8 d5 e5:4 |
        f#5:4. ~e5:8 d5:4 f#5 | b5:4. ~a5:8 g5:4 d5 |
        e5:4 g5 a5 c#6 | d6:4 b5 c#6:2 |
    """),
    bass=bass(DRIVE, CLIMB_BASS, low=33),
    cascade=arp(CASCADE, "[1:16 3 5 8]*4", low=62),
    strings=Pad(STRINGS.copy(name="strings high", gain_db=-13.0), low=57, high=76),
    drums=Drums(KIT, GROOVE, FILL, crash=True),
)

song.section("C", "| Gmaj7 | F#m7 | Em7 | Dmaj7 | Gmaj7 | F#m7 | Em7 | A7sus4 A7 |",
    bells=melody(FALLS_BELLS, FALLS),
    arp=melody(FALLS_ARP, FALLS, transpose=-12),
    bass=bass(DRIVE, HALF_BASS, low=33),
    pad=Pad(PAD, low=53, high=72),
    drums=Drums(KIT, HALF, ROLL, crash=True),
)

INTRO = ["intro"]
LOOP = ["A", "A2", "B", "C"]
