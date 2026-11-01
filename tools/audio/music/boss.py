"""Boss: the fight with a boss, first the Egg Tidecrab. Tense and fast in C minor: a churning
synth bass, brass stabs, racing arpeggios, strings and timpani.

Form: a two-bar intro of hits, then a loop of A (the brass theme over the ostinato) and B (strings
take the tune while the brass punches out a 3-3-2 rhythm), back to A.
"""
from instruments import ARP, BRASS, BRASS_STABS, KIT, STRINGS, SYNTH_BASS
from song import Comp, Drums, Pad, Song, arp, bass, melody

TEMPO = 168

song = Song("boss", tempo=TEMPO, key="C minor", reverb=1.8)

BOSS_BRASS = BRASS.copy(name="boss brass", gain_db=-4.0)
HITS = BRASS_STABS.copy(name="hits", gain_db=-7.0)
STRING_LEAD = STRINGS.copy(name="string lead", gain_db=-8.0, spread=0.0, pan=-0.05, mono=True)
TENSE_PAD = STRINGS.copy(name="tense strings", gain_db=-17.0)
TIMPANI = KIT["timpani"].copy(name="boss timpani", gain_db=-4.0)
BOSS_KIT = dict(KIT, timpani=TIMPANI)

INTRO_DRUMS = {
    "kick":    "x.....x.x.......",
    "timpani": "x.....x.x.......",
    "crash":   "x.....x.x.......",
    "snare":   "............XXXX",
}
GROOVE = {
    "kick":  "x...x...x...x...",
    "snare": "....X.......X...",
    "hat":   "XxxxXxxxXxxxXxxx",
    "timpani": "x" + "." * 31,
}
FILL = {
    "kick":  "x...x...x.......",
    "snare": "....X...x.x.XXXX",
    "tom1":  "........x.......",
    "tom2":  "..........x.....",
    "tom3":  "............x...",
}
OSTINATO = "1:16 1 8 1 1 2 1 3 1 1 8 1 5 4 3 2"

song.section("intro", "| Cm | G7 |",
    hits=melody(HITS, "(c5 eb5 g5):4. (c5 eb5 g5):8 r:8 (c5 eb5 g5):8 r:4 | (b4 d5 f5):4. (b4 d5 f5):8 r:8 (b4 d5 f5):8 r:4 |"),
    bass=bass(SYNTH_BASS, "1:4. 1:8 r:8 1:8 r:4", low=36),
    drums=Drums(BOSS_KIT, INTRO_DRUMS),
)

song.section("A", "| Cm | Cm | Ab | Bb | Cm | Cm | Db | G7 |",
    lead=melody(BOSS_BRASS, """
        c5:4 r:8 c5:8 eb5:8. d5:16 c5:4 | g5:4. f5:8 eb5:4 d5 |
        c5:4 r:8 c5:8 eb5:8. d5:16 c5:4 | f5:4. eb5:8 d5:4 bb4 |
        c5:4 r:8 c5:8 eb5:8. d5:16 c5:4 | g5:4. ab5:8 g5:4 eb5 |
        f5:4. eb5:8 db5:4 ab4 | b4:4 d5 f5:8 eb5 d5:4 |
    """),
    bass=bass(SYNTH_BASS, OSTINATO, low=36),
    arp=arp(ARP, "[1:16 3 5 8]*4", low=60),
    pad=Pad(TENSE_PAD, low=48, high=67),
    drums=Drums(BOSS_KIT, GROOVE, FILL, fill_every=4, crash=True),
)

song.section("B", "| Fm | Fm | Cm | Cm | Ab | Bb | Ab | G7 |",
    lead=melody(STRING_LEAD, """
        ab5:2 g5:4 f5 | c6:2 ~bb5:4 ab5 | g5:2. eb5:4 | c5:1 |
        c6:2 bb5:4 ab5 | d6:2 c6:4 bb5 | c6:4. bb5:8 ab5:4 f5 | g5:2 b5:2 |
    """),
    bass=bass(SYNTH_BASS, OSTINATO, low=36),
    stabs=Comp(HITS, "x..x..x.x..x..x.", low=57, high=72),
    drums=Drums(BOSS_KIT, GROOVE, FILL, fill_every=4, crash=True),
)

INTRO = ["intro"]
LOOP = ["A", "B"]
