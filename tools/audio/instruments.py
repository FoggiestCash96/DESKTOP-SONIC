"""The instruments the music is played on: FM brass, slap bass, steel drums, clavinet, electric
piano and bells after the Sega Genesis's FM chip, band-limited synth leads and pads, and a
synthesised drum kit with tropical percussion. Each is tuned here once and shared by every track.

An instrument's mix settings (gain_db, pan, reverb and echo sends) can be changed for one track
with .copy(): `BRASS.copy(name="brass stabs", pan=-0.2)`.
"""
from __future__ import annotations

import copy
import math

import numpy as np

import synth
from synth import RATE, Op


class Instrument:
    """Something that plays notes into a stereo track."""

    def __init__(self, name: str, gain_db: float = 0.0, pan: float = 0.0, reverb: float = 0.15,
                 echo: float = 0.0, spread: float = 0.0, humanize: float = 0.002, mono: bool = False,
                 glide: float = 0.05, tail: float = 0.3, scoop: float = 0.0, scoop_time: float = 0.04,
                 vibrato: float = 0.0, vibrato_rate: float = 5.5, vibrato_delay: float = 0.3,
                 lowpass: float = 0.0, highpass: float = 0.0, chorus: float = 0.0, drive: float = 0.0):
        self.name = name
        self.gain_db = gain_db
        self.pan = pan
        self.reverb = reverb  # share sent to the room
        self.echo = echo  # share sent to the tempo-synced echo
        self.spread = spread  # how far a chord's notes spread across the speakers
        self.humanize = humanize  # seconds of timing looseness
        self.mono = mono  # one note at a time: ~ slides glide between them
        self.glide = glide  # seconds a slide takes
        self.tail = tail  # seconds a note rings after it's let go
        self.scoop = scoop  # cents flat each note starts, rising to pitch
        self.scoop_time = scoop_time
        self.vibrato = vibrato  # cents
        self.vibrato_rate = vibrato_rate
        self.vibrato_delay = vibrato_delay
        self.lowpass = lowpass
        self.highpass = highpass
        self.chorus = chorus
        self.drive = drive

    def copy(self, **changes) -> "Instrument":
        made = copy.copy(self)
        for key, value in changes.items():
            setattr(made, key, value)
        return made

    def voice(self, freq: np.ndarray, gate: float, velocity: float) -> np.ndarray:
        raise NotImplementedError

    def modulate(self, freq: np.ndarray) -> np.ndarray:
        """The note's pitch with this instrument's scoop and vibrato."""
        if not self.scoop and not self.vibrato:
            return freq
        t = np.arange(len(freq)) / RATE
        cents = np.zeros(len(freq))
        if self.scoop:
            cents -= self.scoop * np.exp(-t / self.scoop_time)
        if self.vibrato:
            depth = np.clip((t - self.vibrato_delay) / 0.35, 0.0, 1.0) * self.vibrato
            cents += depth * np.sin(synth.TAU * self.vibrato_rate * t)
        return freq * 2.0 ** (cents / 1200.0)

    def play(self, track: np.ndarray, events: list, sample_of, beat_seconds: float, section: str) -> None:
        gain = synth.db(self.gain_db)
        for group in self._voices(events):
            first, last = group[0], group[-1]
            start = sample_of(first.beat)
            end = sample_of(last.beat + last.length * last.gate)
            jitter = synth.n_samples(self.humanize * synth.wobble(self.name, section, first.beat))
            gate = max(end - start, synth.n_samples(0.01)) / RATE
            length = synth.n_samples(gate + self.tail)
            pitches = first.pitches
            for i, pitch in enumerate(pitches):
                midi = np.full(length, float(pitch))
                for later in group[1:]:  # Slides: glide to each new note.
                    at = sample_of(later.beat) - start
                    glide = min(synth.n_samples(self.glide), max(1, (sample_of(later.beat + later.length) - start - at) // 3))
                    target = float(later.pitches[0])
                    midi[at:] = target
                    ramp = np.linspace(midi[at - 1] if at > 0 else target, target, glide)
                    midi[at:at + glide] = ramp[:len(midi[at:at + glide])]
                freq = 440.0 * 2.0 ** ((midi - 69.0) / 12.0)
                sound = self.voice(freq, gate, first.velocity) * gain
                spot = self.pan
                if self.spread and len(pitches) > 1:
                    spot += self.spread * (2.0 * i / (len(pitches) - 1) - 1.0)
                synth.add_at(track, synth.pan(sound, spot).astype(np.float32), start + jitter)

    def _voices(self, events: list) -> list[list]:
        """Events grouped into voices: each on its own, except slides on a one-note instrument,
        which join the note before."""
        groups: list[list] = []
        for e in sorted(events, key=lambda e: e.beat):
            if not e.pitches:
                continue
            if self.mono and e.slide and groups:
                groups[-1].append(e)
            else:
                groups.append([e])
        return groups

    def finish(self, track: np.ndarray) -> np.ndarray:
        """The whole track through this instrument's own effects."""
        if self.drive:
            track = synth.saturate(track, self.drive)
        if self.highpass:
            track = synth.filt(track, "highpass", self.highpass)
        if self.lowpass:
            track = synth.filt(track, "lowpass", self.lowpass)
        if self.chorus:
            track = synth.chorus(track, 0.7, 0.004, self.chorus)
        return track.astype(np.float32)


class FM(Instrument):
    """Four FM operators connected by one of the Genesis's eight algorithms."""

    def __init__(self, name: str, ops: list[Op], algorithm: int, **kw):
        kw.setdefault("tail", max(op.release for op in ops) + 0.02)
        super().__init__(name, **kw)
        self.ops = ops
        self.algorithm = algorithm

    def voice(self, freq: np.ndarray, gate: float, velocity: float) -> np.ndarray:
        return synth.fm(self.modulate(freq), gate, velocity, self.ops, self.algorithm)


class SlapBass(FM):
    """FM bass with a slap: notes from the G below middle C's octave down are thumbed, higher
    ones popped, brighter and snappier."""

    def voice(self, freq: np.ndarray, gate: float, velocity: float) -> np.ndarray:
        popped = freq[0] > 95.0
        ops = self.ops
        if popped:
            ops = [copy.copy(op) for op in ops]
            ops[2].level *= 1.7
            ops[3].level *= 1.5
        out = synth.fm(self.modulate(freq), gate, velocity, ops, self.algorithm)
        click_len = synth.n_samples(0.006)
        click = synth.filt(synth.noise(click_len, 11), "highpass", 1800.0) * synth.decay_env(click_len, 0.004)
        synth.add_at(out, click * (0.25 if popped else 0.12) * velocity, 0)
        return out


class SteelDrum(FM):
    """FM steel pan: a ringing fundamental and octave, a struck attack and a metallic ping."""

    def voice(self, freq: np.ndarray, gate: float, velocity: float) -> np.ndarray:
        t = np.arange(len(freq)) / RATE
        bent = freq * 2.0 ** (18.0 * np.exp(-t / 0.02) / 1200.0)  # The stick knocks it a touch sharp.
        out = synth.fm(bent, gate, velocity, self.ops, self.algorithm)
        ping = synth.sine(freq * 4.17) * synth.decay_env(len(freq), 0.035) * 0.07 * velocity
        return out + ping


class Wave(Instrument):
    """Band-limited oscillators (saw, square, triangle, pulse) through a filter that opens with
    each note."""

    def __init__(self, name: str, waves: list[tuple[str, float, float]], attack: float = 0.005,
                 decay: float = 0.3, sustain: float = 0.8, release: float = 0.1, cutoff: float = 4000.0,
                 cutoff_env: float = 0.0, cutoff_decay: float = 0.25, resonance: float = 0.8,
                 width: float = 0.5, octave_spread: bool = False, **kw):
        kw.setdefault("tail", release + 0.02)
        super().__init__(name, **kw)
        self.waves = waves  # (kind, detune in cents, level)
        self.attack, self.decay, self.sustain, self.release = attack, decay, sustain, release
        self.cutoff = cutoff
        self.cutoff_env = cutoff_env  # Hz the filter opens by at the start of each note
        self.cutoff_decay = cutoff_decay
        self.resonance = resonance
        self.width = width

    def voice(self, freq: np.ndarray, gate: float, velocity: float) -> np.ndarray:
        freq = self.modulate(freq)
        n = len(freq)
        out = np.zeros(n)
        for kind, cents, level in self.waves:
            out += synth.wave(kind, freq * 2.0 ** (cents / 1200.0), width=self.width) * level
        if self.cutoff_env:
            opening = synth.decay_env(n, self.cutoff_decay)
            out = synth.sweep(out, "lowpass", self.cutoff + self.cutoff_env * velocity * opening, self.resonance)
        else:
            out = synth.filt(out, "lowpass", self.cutoff, self.resonance)
        env = synth.adsr(gate, self.attack, self.decay, self.sustain, self.release, length=n)
        return out * env * (0.35 + 0.65 * velocity)


class Drum(Instrument):
    """One kit piece: the same sound for every hit, louder or softer."""

    def __init__(self, name: str, make, humanize: float = 0.0025, **kw):
        super().__init__(name, humanize=humanize, **kw)
        self.make = make  # velocity -> mono sound
        self._cache: dict[int, np.ndarray] = {}

    def hit(self, velocity: float) -> np.ndarray:
        key = int(round(velocity * 20))
        if key not in self._cache:
            self._cache[key] = self.make(key / 20.0)
        return self._cache[key]

    def play(self, track: np.ndarray, events: list, sample_of, beat_seconds: float, section: str) -> None:
        gain = synth.db(self.gain_db)
        for e in events:
            jitter = synth.n_samples(self.humanize * synth.wobble(self.name, section, e.beat))
            loud = min(1.0, max(0.05, e.velocity * (1.0 + 0.06 * synth.wobble(self.name, section, e.beat, "v"))))
            synth.add_at(track, synth.pan(self.hit(loud) * gain, self.pan).astype(np.float32), sample_of(e.beat) + jitter)


# --- FM and synth patches --------------------------------------------------------------------

BRASS = FM("brass", algorithm=4, ops=[
    Op(ratio=1.0, level=2.6, attack=0.035, decay=0.4, sustain=0.6, release=0.12, velocity=0.6, key_scale=-0.22, feedback=0.5),
    Op(ratio=1.0, level=0.5, attack=0.012, decay=0.6, sustain=0.85, release=0.14, detune=-5.0),
    Op(ratio=1.0, level=2.2, attack=0.04, decay=0.4, sustain=0.55, release=0.12, velocity=0.6, key_scale=-0.22),
    Op(ratio=1.0, level=0.5, attack=0.014, decay=0.6, sustain=0.85, release=0.14, detune=5.0),
], scoop=30.0, scoop_time=0.03, vibrato=12.0, vibrato_delay=0.28, mono=True, glide=0.04,
    gain_db=-5.0, pan=0.05, reverb=0.2, echo=0.06, lowpass=12000.0)

BRASS_STABS = BRASS.copy(name="brass stabs", mono=False, scoop=45.0, vibrato=0.0, gain_db=-9.0, pan=-0.12,
                         spread=0.35, echo=0.0, reverb=0.16)

SLAP_BASS = SlapBass("slap bass", algorithm=4, ops=[
    Op(ratio=1.0, level=3.0, attack=0.001, decay=0.1, sustain=0.22, release=0.05, velocity=0.7, feedback=0.35),
    Op(ratio=1.0, level=0.75, attack=0.001, decay=0.7, sustain=0.6, release=0.05),
    Op(ratio=3.0, level=1.6, attack=0.001, decay=0.04, sustain=0.0, release=0.03, velocity=0.9),
    Op(ratio=1.0, level=0.28, attack=0.001, decay=0.12, sustain=0.0, release=0.03),
], gain_db=-7.0, reverb=0.03, lowpass=5200.0, drive=1.4, humanize=0.0015)

SYNTH_BASS = FM("synth bass", algorithm=4, ops=[
    Op(ratio=1.0, level=2.0, attack=0.001, decay=0.18, sustain=0.45, release=0.06, velocity=0.6, feedback=0.75),
    Op(ratio=1.0, level=0.7, attack=0.001, decay=0.5, sustain=0.8, release=0.06),
    Op(ratio=1.0, level=0.5, attack=0.001, decay=0.25, sustain=0.2, release=0.05),
    Op(ratio=0.5, level=0.45, attack=0.001, decay=0.6, sustain=0.85, release=0.06),
], gain_db=-4.0, reverb=0.04, lowpass=2200.0, drive=1.5, humanize=0.001)

STEEL = SteelDrum("steel drum", algorithm=4, ops=[
    Op(ratio=1.0, level=1.1, attack=0.001, decay=0.25, sustain=0.12, release=0.3, velocity=0.7, key_scale=-0.2),
    Op(ratio=1.0, level=0.6, attack=0.001, decay=1.3, sustain=0.0, release=0.35),
    Op(ratio=3.0, level=0.8, attack=0.001, decay=0.08, sustain=0.0, release=0.1, velocity=0.8),
    Op(ratio=2.0, level=0.32, attack=0.001, decay=0.7, sustain=0.0, release=0.25),
], gain_db=-13.0, pan=0.22, reverb=0.24, echo=0.1, tail=0.4)

CLAV = FM("clav", algorithm=4, ops=[
    Op(ratio=3.0, level=1.6, attack=0.001, decay=0.06, sustain=0.2, release=0.03, velocity=0.6),
    Op(ratio=1.0, level=0.55, attack=0.001, decay=0.25, sustain=0.35, release=0.04),
    Op(ratio=1.0, level=1.2, attack=0.001, decay=0.1, sustain=0.3, release=0.03),
    Op(ratio=2.0, level=0.3, attack=0.001, decay=0.2, sustain=0.25, release=0.04),
], gain_db=-12.0, pan=-0.32, reverb=0.12, spread=0.2, highpass=180.0)

EPIANO = FM("electric piano", algorithm=4, ops=[
    Op(ratio=14.0, level=0.9, attack=0.001, decay=0.04, sustain=0.0, release=0.05, velocity=0.9, key_scale=-0.3),
    Op(ratio=1.0, level=0.45, attack=0.001, decay=1.6, sustain=0.25, release=0.25),
    Op(ratio=1.0, level=1.1, attack=0.001, decay=0.5, sustain=0.25, release=0.2, velocity=0.7),
    Op(ratio=1.0, level=0.5, attack=0.001, decay=2.0, sustain=0.3, release=0.3, detune=3.0),
], gain_db=-11.0, pan=-0.15, reverb=0.25, spread=0.3, chorus=0.4)

BELL = FM("bells", algorithm=4, ops=[
    Op(ratio=3.5, level=2.2, attack=0.001, decay=0.5, sustain=0.0, release=0.4, velocity=0.7, key_scale=-0.25),
    Op(ratio=1.0, level=0.6, attack=0.001, decay=2.0, sustain=0.0, release=0.6),
    Op(ratio=7.07, level=1.0, attack=0.001, decay=0.25, sustain=0.0, release=0.3),
    Op(ratio=2.0, level=0.2, attack=0.001, decay=1.0, sustain=0.0, release=0.4),
], gain_db=-12.0, pan=0.3, reverb=0.3, echo=0.15, tail=0.6)

POP_LEAD = Wave("pop lead", [("saw", -8.0, 0.45), ("saw", 8.0, 0.45), ("square", 0.0, 0.3)],
                attack=0.008, decay=0.3, sustain=0.75, release=0.12, cutoff=2400.0, cutoff_env=3200.0,
                cutoff_decay=0.3, resonance=0.9, vibrato=15.0, vibrato_rate=5.6, vibrato_delay=0.2,
                mono=True, glide=0.05, gain_db=-7.0, reverb=0.2, echo=0.22)

ARP = Wave("arp synth", [("pulse", 0.0, 0.7), ("pulse", 7.0, 0.3)], width=0.25, attack=0.002, decay=0.12,
           sustain=0.25, release=0.06, cutoff=3500.0, cutoff_env=4000.0, cutoff_decay=0.1,
           gain_db=-15.0, pan=-0.25, reverb=0.15, echo=0.3)

PAD = Wave("pad", [("saw", -12.0, 0.4), ("saw", 12.0, 0.4), ("saw", 0.0, 0.25)], attack=0.25, decay=1.0,
           sustain=0.8, release=0.6, cutoff=2200.0, resonance=0.6, gain_db=-16.0, reverb=0.4, spread=0.5,
           chorus=0.5, humanize=0.0)

STRINGS = Wave("strings", [("saw", -7.0, 0.4), ("saw", 7.0, 0.4), ("saw", 1200.0, 0.12)], attack=0.12,
               decay=0.8, sustain=0.85, release=0.35, cutoff=3200.0, resonance=0.6, vibrato=8.0,
               vibrato_rate=5.0, vibrato_delay=0.2, gain_db=-15.0, reverb=0.35, spread=0.6, chorus=0.35,
               humanize=0.0)


# --- Drum kit --------------------------------------------------------------------------------

def _kick(v: float) -> np.ndarray:
    n = synth.n_samples(0.45)
    t = np.arange(n) / RATE
    body = synth.sine(46.0 + 140.0 * np.exp(-t / 0.035)) * synth.decay_env(n, 0.38)
    click_len = synth.n_samples(0.006)
    click = synth.filt(synth.noise(click_len, 1), "highpass", 2500.0) * synth.decay_env(click_len, 0.004)
    synth.add_at(body, click * 0.35, 0)
    return synth.saturate(body * (0.8 + 0.4 * v), 1.8) * (0.6 + 0.4 * v)


def _snare(v: float) -> np.ndarray:
    n = synth.n_samples(0.3)
    t = np.arange(n) / RATE
    tone = synth.sine(185.0 + 30.0 * np.exp(-t / 0.01)) * synth.decay_env(n, 0.09) * 0.6
    tone += synth.sine(330.0, n) * synth.decay_env(n, 0.06) * 0.3
    hiss = synth.noise(n, 2)
    rattle = synth.filt(synth.filt(hiss, "bandpass", 2600.0, 0.5), "highpass", 900.0) * synth.decay_env(n, 0.2)
    crisp = synth.filt(hiss, "highpass", 6000.0) * synth.decay_env(n, 0.08) * 0.4
    return synth.normalize(tone + rattle * (0.7 + 0.5 * v) + crisp, 0.0) * (0.45 + 0.55 * v)


def _clap(v: float) -> np.ndarray:
    n = synth.n_samples(0.35)
    hiss = synth.filt(synth.filt(synth.noise(n, 3), "bandpass", 1150.0, 1.2), "highpass", 500.0)
    env = np.zeros(n)
    for k, at in enumerate((0.0, 0.011, 0.022)):
        start = synth.n_samples(at)
        env[start:] += synth.decay_env(n - start, 0.008 if k < 2 else 0.13) * (0.8 if k < 2 else 1.0)
    return synth.normalize(hiss * env, 0.0) * (0.45 + 0.55 * v)


def _hat(length: float):
    def make(v: float) -> np.ndarray:
        n = synth.n_samples(length * 3.0)
        metal = synth.metallic(n) * 0.6 + synth.noise(n, 4) * 0.4
        metal = synth.filt(synth.filt(metal, "bandpass", 10000.0, 0.8), "highpass", 7000.0)
        return synth.normalize(metal * synth.decay_env(n, length), 0.0) * (0.3 + 0.7 * v)
    return make


def _crash(v: float) -> np.ndarray:
    n = synth.n_samples(2.2)
    metal = synth.metallic(n) * 0.5 + synth.noise(n, 5) * 0.5
    metal = synth.filt(metal, "highpass", 4500.0)
    env = synth.decay_env(n, 1.9, attack=0.003) * 0.7 + synth.decay_env(n, 0.15) * 0.3
    return synth.normalize(metal * env, 0.0) * (0.5 + 0.5 * v)


def _tom(pitch: float):
    def make(v: float) -> np.ndarray:
        n = synth.n_samples(0.5)
        t = np.arange(n) / RATE
        body = synth.sine(pitch * (1.0 + 0.6 * np.exp(-t / 0.03))) * synth.decay_env(n, 0.4)
        thump = synth.filt(synth.noise(n, 6), "bandpass", 1000.0, 0.7) * synth.decay_env(n, 0.02) * 0.3
        return synth.saturate(body + thump, 1.3) * (0.45 + 0.55 * v)
    return make


def _conga(pitch: float):
    def make(v: float) -> np.ndarray:
        n = synth.n_samples(0.3)
        t = np.arange(n) / RATE
        body = synth.sine(pitch * (1.0 + 0.12 * np.exp(-t / 0.012))) * synth.decay_env(n, 0.2)
        body += synth.sine(pitch * 1.52, n) * synth.decay_env(n, 0.05) * 0.2
        slap = synth.filt(synth.noise(n, 7), "bandpass", 2500.0, 0.8) * synth.decay_env(n, 0.012) * 0.3
        return (body + slap) * (0.4 + 0.6 * v)
    return make


def _shaker(v: float) -> np.ndarray:
    n = synth.n_samples(0.12)
    t = np.arange(n) / RATE
    hiss = synth.filt(synth.noise(n, 8), "bandpass", 6500.0, 0.9)
    env = np.minimum(t / 0.012, 1.0) * np.exp(-np.maximum(t - 0.012, 0.0) / 0.03)
    return synth.normalize(hiss * env, 0.0) * (0.3 + 0.7 * v)


def _cowbell(v: float) -> np.ndarray:
    n = synth.n_samples(0.4)
    tone = synth.wave("square", 562.0, n) + synth.wave("square", 845.0, n)
    tone = synth.filt(tone, "bandpass", 2640.0, 1.2)
    env = synth.decay_env(n, 0.03) * 0.6 + synth.decay_env(n, 0.3) * 0.4
    return synth.normalize(tone * env, 0.0) * (0.4 + 0.6 * v)


def _claves(v: float) -> np.ndarray:
    n = synth.n_samples(0.08)
    tone = synth.sine(2500.0, n) * synth.decay_env(n, 0.03) + synth.sine(5000.0, n) * synth.decay_env(n, 0.015) * 0.2
    return tone * (0.4 + 0.6 * v)


def _timbale(pitch: float):
    def make(v: float) -> np.ndarray:
        n = synth.n_samples(0.4)
        ring = synth.sine(pitch, n) * synth.decay_env(n, 0.25) + synth.sine(pitch * 2.1, n) * synth.decay_env(n, 0.12) * 0.4
        rim = synth.filt(synth.noise(n, 9), "bandpass", 3000.0, 0.9) * synth.decay_env(n, 0.015) * 0.45
        return synth.normalize(ring + rim, 0.0) * (0.4 + 0.6 * v)
    return make


def _timpani(pitch: float):
    def make(v: float) -> np.ndarray:
        n = synth.n_samples(2.0)
        out = synth.sine(pitch, n) * synth.decay_env(n, 1.6)
        out += synth.sine(pitch * 1.504, n) * synth.decay_env(n, 0.9) * 0.5
        out += synth.sine(pitch * 1.98, n) * synth.decay_env(n, 0.6) * 0.3
        mallet = synth.filt(synth.noise(n, 10), "lowpass", 500.0) * synth.decay_env(n, 0.05) * 0.6
        return synth.saturate(out + mallet, 1.2) * (0.4 + 0.6 * v)
    return make


def _thunder(v: float) -> np.ndarray:
    n = synth.n_samples(3.5)
    rumble = synth.filt(synth.pink(n, 12), "lowpass", 220.0)
    crack = synth.filt(synth.noise(n, 13), "bandpass", 1500.0, 0.5) * synth.decay_env(n, 0.25) * 0.15
    env = synth.curve([(0.0, 0.0), (0.12, 1.0), (0.8, 0.7), (3.5, 0.0)], n)
    return synth.normalize(rumble * env + crack, 0.0) * v


KIT = {
    "kick": Drum("kick", _kick, gain_db=-6.0, reverb=0.02, humanize=0.001),
    "snare": Drum("snare", _snare, gain_db=2.0, pan=0.05, reverb=0.18),
    "clap": Drum("clap", _clap, gain_db=-4.0, pan=0.05, reverb=0.2),
    "hat": Drum("hat", _hat(0.045), gain_db=-8.0, pan=0.3, reverb=0.05),
    "open": Drum("open hat", _hat(0.35), gain_db=-12.0, pan=0.3, reverb=0.08),
    "crash": Drum("crash", _crash, gain_db=-10.0, pan=-0.25, reverb=0.12),
    "tom1": Drum("high tom", _tom(190.0), gain_db=-11.0, pan=-0.35, reverb=0.2),
    "tom2": Drum("mid tom", _tom(140.0), gain_db=-11.0, pan=0.0, reverb=0.2),
    "tom3": Drum("low tom", _tom(100.0), gain_db=-10.0, pan=0.35, reverb=0.2),
    "conga": Drum("high conga", _conga(330.0), gain_db=-14.0, pan=-0.4, reverb=0.12),
    "conga2": Drum("low conga", _conga(220.0), gain_db=-13.0, pan=0.15, reverb=0.12),
    "shaker": Drum("shaker", _shaker, gain_db=-17.0, pan=0.45, reverb=0.08),
    "cowbell": Drum("cowbell", _cowbell, gain_db=-6.0, pan=-0.2, reverb=0.12),
    "claves": Drum("claves", _claves, gain_db=-18.0, pan=0.25, reverb=0.12),
    "timbale": Drum("high timbale", _timbale(640.0), gain_db=-11.0, pan=-0.3, reverb=0.15),
    "timbale2": Drum("low timbale", _timbale(470.0), gain_db=-11.0, pan=0.3, reverb=0.15),
    "timpani": Drum("timpani", _timpani(73.4), gain_db=-6.0, reverb=0.25),
    "thunder": Drum("thunder", _thunder, gain_db=-10.0, reverb=0.3),
}
