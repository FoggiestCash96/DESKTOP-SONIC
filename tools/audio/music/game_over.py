"""Game over: a slow, falling phrase in D minor on electric piano and strings, ending on a held
minor chord. Plays once."""
from instruments import EPIANO, KIT, STRINGS
from song import Drums, Pad, Song, melody

song = Song("game_over", tempo=100, key="D minor", reverb=2.4, eq=0.15)  # Keep it dark.

SAD_KEYS = EPIANO.copy(name="sad piano", gain_db=-5.0, spread=0.0)

song.section("phrase", "| Gm A7 | Dm |",
    lead=melody(SAD_KEYS, "d5:4 c5 bb4 a4 | d4:1 |"),
    keys=melody(EPIANO, "(g3 bb3 d4):2 (a3 c#4 e4 g4):2 | (d3 a3 f4):1 |"),
    strings=Pad(STRINGS, low=50, high=69, velocity=0.6),
    drums=Drums(KIT, {"timpani": "x.......x......." "x..............."}),
)

INTRO = ["phrase"]
LOOP = None
