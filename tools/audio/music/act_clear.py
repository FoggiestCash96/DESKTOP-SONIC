"""Act clear: the fanfare at the goal, while the results show. F major, brass over a drum build,
landing on a held chord with a timpani roll. Plays once."""
from instruments import BRASS, BRASS_STABS, KIT, SLAP_BASS, STEEL
from song import Drums, Song, melody

song = Song("act_clear", tempo=140, key="F major", reverb=2.0)

FANFARE = BRASS.copy(name="fanfare brass", gain_db=-3.0)
STEEL_DOUBLE = STEEL.copy(name="steel double", gain_db=-10.0)
TUNE = "f5:8 f5 g5 a5 bb5:8. a5:16 g5:8 c6 | a5:4 c6:8 a5 f6:2 | r:1 |"

song.section("fanfare", "| Bb C | F | F |",
    lead=melody(FANFARE, TUNE),
    double=melody(STEEL_DOUBLE, TUNE),
    stabs=melody(BRASS_STABS, "r:1 | r:4 (a4 c5 f5):4. r:8 (a4 c5 f5):4 | (a4 c5 f5):1 |"),
    bass=melody(SLAP_BASS, "bb1:4 bb1 c2 c2 | f1:4. f2:8 r:4 c2:4 | f1:1 |"),
    drums=Drums(KIT, {
        "snare":   "....x.x.xxxxXXXX" "................" "................",
        "kick":    "x.......x......." "x.......x......." "x...............",
        "crash":   "................" "x..............." "x...............",
        "timpani": "................" "................" "xxxxxxxxxxxxxxxx",
    }),
)

INTRO = ["fanfare"]
LOOP = None
