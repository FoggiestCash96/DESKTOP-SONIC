"""Drowning: the countdown under water, from twelve seconds of air left until the player breathes or
drowns. It replaces the stage music while it plays. Tense and climbing: a pulsing bass and an alarm
of bells that rise a semitone every bar for twelve seconds, then a frantic bar that repeats for as
long as it has to (at a slower game speed the countdown lasts longer).
"""
from instruments import BELL, KIT, STRINGS, SYNTH_BASS
from song import Drums, Pad, Song, arp, bass

song = Song("drowning", tempo=180, key="D minor", reverb=1.0)

ALARM = BELL.copy(name="alarm bells", gain_db=-5.0)
PULSE = SYNTH_BASS.copy(name="pulse bass", gain_db=-3.0)
RISE = STRINGS.copy(name="rising strings", gain_db=-9.0)

song.section("countdown", "| Dm | Ebm | Em | Fm | F#m | Gm | G#m | Am | Bbm |",
    bells=arp(ALARM, "1:8 5 8 5 3' 8 5 3", low=62),
    bass=bass(PULSE, "1:8 1 1 1 1 1 1 1", low=38),
    strings=Pad(RISE, low=57, high=76),
    drums=Drums(KIT, {
        "kick": "x...x...x...x...",
        "hat": "x.x.x.x.x.x.x.x.",
        "snare": "............x.x.",
    }),
)

song.section("panic", "| A7 |",
    bells=arp(ALARM, "[1:16 3 5 8]*4", low=62),
    bass=bass(PULSE, "1:16 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1", low=38),
    strings=Pad(RISE, low=57, high=76),
    drums=Drums(KIT, {
        "kick": "x.x.x.x.x.x.x.x.",
        "snare": "x.x.x.x.x.x.xxxx",
        "hat": "xxxxxxxxxxxxxxxx",
    }),
)

INTRO = ["countdown"]
LOOP = ["panic"]
