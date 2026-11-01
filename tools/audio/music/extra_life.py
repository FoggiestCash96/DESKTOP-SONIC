"""Extra life: a short, happy fanfare. The music stops while it plays and picks up afterwards.
B-flat major, brass and steel drums. Plays once."""
from instruments import BRASS, BRASS_STABS, KIT, SLAP_BASS, STEEL
from song import Drums, Song, melody

song = Song("extra_life", tempo=150, key="Bb major", reverb=1.6)

FANFARE = BRASS.copy(name="fanfare brass", gain_db=-3.0)
STEEL_DOUBLE = STEEL.copy(name="steel double", gain_db=-8.0)
TUNE = "bb4:8 d5 f5 bb5:4 a5:8 bb5 c6 | d6:2 bb5:2 |"

song.section("fanfare", "| Eb F | Bb |",
    lead=melody(FANFARE, TUNE),
    double=melody(STEEL_DOUBLE, TUNE),
    stabs=melody(BRASS_STABS, "r:1 | (d5 f5 bb5):4 r:4 (d5 f5 bb5):2 |"),
    bass=melody(SLAP_BASS, "eb2:4 eb2 f2 f2 | bb1:2 bb1:2 |"),
    drums=Drums(KIT, {
        "snare": "........x.x.XXXX" "................",
        "kick":  "x.......x......." "x.......x.......",
        "crash": "................" "x...............",
    }),
)

INTRO = ["fanfare"]
LOOP = None
