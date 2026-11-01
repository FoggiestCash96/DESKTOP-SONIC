"""Invincibility: plays over the stage music while the power-up lasts. Bright and fast in A major:
heroic brass, racing arpeggios and a four-on-the-floor beat.

Form: a one-bar run-up, then a loop of A and B.
"""
from instruments import ARP, BELL, BRASS, KIT, SLAP_BASS
from song import Drums, Song, arp, bass, melody

TEMPO = 168

song = Song("invincible", tempo=TEMPO, key="A major")

HERO = BRASS.copy(name="hero brass", gain_db=-4.0)
RACE = ARP.copy(name="racing arp", gain_db=-12.0)

GROOVE = {
    "kick":  "x...x...x...x...",
    "snare": "....X.......X...",
    "hat":   "xxxxxxxxxxxxxxxx",
    "open":  "..x...x...x...x.",
}
FILL = {
    "kick":  "x...x...x.......",
    "snare": "....X...XXXXXXXX",
}

song.section("intro", "| E7 |",
    lead=melody(HERO, "b4:8 e5 g#5 b5 e6:2 |"),
    bass=bass(SLAP_BASS, "1:8 8 1 8 1 8 1 8", low=33),
    drums=Drums(KIT, {"snare": "x.x.x.x.xxxxXXXX", "crash": "........x......."}),
)

song.section("A", "| A | E/G# | F#m | D | A | E | D | E7 |",
    lead=melody(HERO, """
        e5:8 a5 c#6 e6:4 c#6:8 e6 a6 | g#6:4. f#6:8 e6:4 b5 |
        c#6:4. b5:8 a5:4 f#5 | a5:2 f#5:4 d5 |
        e5:8 a5 c#6 e6:4 c#6:8 e6 a6 | b6:4. a6:8 g#6:4 e6 |
        f#6:4 e6 d6:8 c#6 b5:4 | g#5:4 b5 d6 e6 |
    """),
    bass=bass(SLAP_BASS, "1:8 8 1 8 1 8 1 8", low=33),
    arp=arp(RACE, "[1:16 3 5 8]*4", low=57),
    drums=Drums(KIT, GROOVE, FILL, crash=True),
)

song.section("B", "| D | E | C#m7 | F#m7 | Bm7 | E | A | E7 |",
    lead=melody(HERO, """
        f#6:2 e6:4 d6 | e6:2 d6:4 b5 | e6:4. c#6:8 g#5:4 b5 | a5:2 c#6:4 e6 |
        d6:4. c#6:8 b5:4 f#5 | g#5:4. a5:8 b5:4 e6 | c#6:4 e6 a6:2 | g#6:8 f#6 e6 d6 b5:2 |
    """),
    bells=arp(BELL, "1:8 5 8 3' 5' 3' 8 5", low=64),
    bass=bass(SLAP_BASS, "1:8 8 1 8 1 8 1 8", low=33),
    arp=arp(RACE, "[1:16 3 5 8]*4", low=57),
    drums=Drums(KIT, GROOVE, FILL, crash=True),
)

INTRO = ["intro"]
LOOP = ["A", "B"]
