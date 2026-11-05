"""The game's sound effects, each made from scratch by a short recipe. render.py writes them to
content/sonic/audio/sounds/<name>.wav; content/sonic/audio/sound_bank.tres says which game event
plays which.

To change a sound, edit its function and re-render it (`python tools/audio/render.py jump`).
LEVELS sets how loud each one peaks, and LOOPS lists the ones that repeat seamlessly.
"""
from __future__ import annotations

import math

import numpy as np

import synth
from synth import RATE, Op


def ns(seconds: float) -> int:
    return synth.n_samples(seconds)


def times(n: int) -> np.ndarray:
    return np.arange(n) / RATE


def whoosh(seconds: float, start: float, peak: float, end: float, seed: int, q: float = 0.8,
           rise: float = 0.3) -> np.ndarray:
    """Air rushing past: noise through a band that sweeps from `start` to `peak` to `end` Hz,
    swelling for `rise` of the time and then fading."""
    n = ns(seconds)
    freqs = synth.curve([(0.0, start), (seconds * rise, peak), (seconds, end)], n, exponential=True)
    air = synth.sweep(synth.noise(n, seed), "bandpass", freqs, q)
    env = synth.curve([(0.0, 0.0), (seconds * rise, 1.0), (seconds, 0.0)], n) ** 1.5
    return air * env


def bell(freq: float, seconds: float, bright: float = 1.0) -> np.ndarray:
    """An FM bell or chime at `freq` Hz, ringing for about `seconds`."""
    n = ns(seconds)
    return synth.fm(np.full(n, freq), seconds * 0.5, 1.0, [
        Op(ratio=3.5, level=2.0 * bright, decay=seconds * 0.3, sustain=0.0, release=seconds * 0.4, velocity=0.0),
        Op(ratio=1.0, level=0.7, decay=seconds, sustain=0.0, release=seconds * 0.5, velocity=0.0),
        Op(ratio=7.0, level=0.8 * bright, decay=seconds * 0.15, sustain=0.0, release=seconds * 0.2, velocity=0.0),
        Op(ratio=2.0, level=0.25, decay=seconds * 0.6, sustain=0.0, release=seconds * 0.3, velocity=0.0),
    ], 4)


def blip(freq: float, seconds: float, kind: str = "square", width: float = 0.5) -> np.ndarray:
    n = ns(seconds)
    tone = synth.wave(kind, freq, n, width)
    return synth.filt(tone, "lowpass", 5000.0) * synth.decay_env(n, seconds * 0.8, 0.002)


def place(parts: list[tuple[float, np.ndarray]], length: float, stereo: bool = False) -> np.ndarray:
    """Sounds mixed together, each starting at its time (seconds)."""
    out = np.zeros((2, ns(length))) if stereo else np.zeros(ns(length))
    for at, sound in parts:
        synth.add_at(out, sound, ns(at))
    return out


# --- The player --------------------------------------------------------------------------

def jump() -> np.ndarray:
    n = ns(0.26)
    freq = synth.curve([(0.0, 290.0), (0.13, 780.0), (0.26, 840.0)], n, exponential=True)
    body = synth.wave("pulse", freq, width=0.3) * 0.55 + synth.wave("triangle", freq) * 0.45
    body = synth.filt(body, "lowpass", 5200.0) * synth.adsr(0.1, 0.004, 0.1, 0.5, 0.14, length=n)
    air = synth.filt(synth.noise(n, 21), "bandpass", 3000.0, 0.7) * synth.decay_env(n, 0.06) * 0.15
    return body + air


def roll() -> np.ndarray:
    n = ns(0.24)
    t = times(n)
    freqs = synth.curve([(0.0, 600.0), (0.2, 2600.0)], n, exponential=True)
    spin = synth.sweep(synth.noise(n, 22), "bandpass", freqs, 1.2) * (0.6 + 0.4 * np.sin(synth.TAU * 38.0 * t))
    return spin * synth.adsr(0.12, 0.005, 0.1, 0.6, 0.1, length=n)


def spin_charge() -> np.ndarray:
    n = ns(0.36)
    t = times(n)
    freq = synth.curve([(0.0, 220.0), (0.2, 540.0), (0.36, 560.0)], n, exponential=True)
    rev = synth.filt(synth.wave("saw", freq), "lowpass", 3500.0) * (0.65 + 0.35 * np.sin(synth.TAU * 32.0 * t))
    whir = synth.filt(synth.noise(n, 23), "bandpass", 1600.0, 1.5) * 0.35
    return (rev + whir) * synth.adsr(0.2, 0.004, 0.1, 0.7, 0.15, length=n)


def spin_release() -> np.ndarray:
    n = ns(0.55)
    tone = synth.wave("saw", synth.curve([(0.0, 320.0), (0.45, 110.0)], n, exponential=True))
    tone = synth.filt(tone, "lowpass", 1800.0) * synth.decay_env(n, 0.35) * 0.5
    air = whoosh(0.55, 3200.0, 2600.0, 700.0, 24, rise=0.08)
    click = synth.filt(synth.noise(ns(0.01), 25), "highpass", 2000.0) * synth.decay_env(ns(0.01), 0.006)
    return place([(0.0, tone), (0.0, air), (0.0, click * 0.6)], 0.55)


def skid() -> np.ndarray:
    n = ns(0.38)
    t = times(n)
    rough = 0.6 + 0.4 * synth.filt(synth.noise(n, 26), "lowpass", 60.0) * 6.0
    screech = synth.sweep(synth.noise(n, 27), "bandpass", synth.curve([(0.0, 2500.0), (0.38, 1800.0)], n, True), 3.0)
    rumble = synth.filt(synth.noise(n, 28), "lowpass", 400.0) * 0.4
    env = synth.adsr(0.22, 0.01, 0.1, 0.8, 0.14, length=n)
    return (screech * np.clip(rough, 0.2, 1.4) + rumble) * env * (1.0 - 0.2 * t / t[-1])


def _ring(side: float) -> np.ndarray:
    first = bell(1568.0, 0.35, 0.7)
    second = bell(2093.0, 0.6, 0.8)
    shimmer = bell(2099.0, 0.6, 0.5) * 0.4  # A few hertz apart: a slow beat, like a real chime.
    mono = place([(0.0, first * 0.8), (0.045, second), (0.045, shimmer)], 0.66)
    return synth.pan(mono, side) / math.sqrt(2.0)


def ring_left() -> np.ndarray:
    return _ring(-0.55)


def ring_right() -> np.ndarray:
    return _ring(0.55)


def ring_loss() -> np.ndarray:
    pentatonic = [2093.0, 2349.0, 2637.0, 3136.0, 3520.0, 4186.0]
    parts = []
    for i in range(12):
        at = i * 0.045 + 0.01 * synth.wobble("ring_loss", i)
        tone = bell(pentatonic[int((synth.wobble("pitch", i) + 1.0) * 3.0) % 6], 0.3, 0.6)
        parts.append((at, synth.pan(tone, synth.wobble("pan", i)) * (1.0 - i * 0.05)))
    n = ns(0.3)
    spray = synth.filt(synth.noise(n, 29), "highpass", 4000.0) * synth.decay_env(n, 0.25) * 0.25
    parts.append((0.0, np.stack([spray, spray])))
    return place(parts, 0.9, stereo=True)


def death() -> np.ndarray:
    n = ns(0.75)
    t = times(n)
    vibrato = 1.0 + 0.04 * np.sin(synth.TAU * 12.0 * t) * np.minimum(t / 0.3, 1.0)
    freq = synth.curve([(0.0, 880.0), (0.65, 120.0)], n, exponential=True) * vibrato
    tone = synth.filt(synth.wave("square", freq), "lowpass", 3000.0)
    return tone * synth.adsr(0.5, 0.004, 0.3, 0.8, 0.22, length=n)


def shield_loss() -> np.ndarray:
    n = ns(0.36)
    pop = synth.filt(synth.noise(n, 30), "highpass", 2500.0) * synth.decay_env(n, 0.2)
    fall = synth.sine(synth.curve([(0.0, 1500.0), (0.25, 300.0)], n, exponential=True)) * synth.decay_env(n, 0.28)
    return pop * 0.5 + fall * 0.6


def homing() -> np.ndarray:
    n = ns(0.12)
    chirp = synth.sine(synth.curve([(0.0, 800.0), (0.08, 2400.0)], n, exponential=True)) * synth.decay_env(n, 0.1)
    return place([(0.0, chirp * 0.6), (0.03, whoosh(0.3, 2000.0, 5000.0, 2500.0, 31, rise=0.2) * 0.7)], 0.34)


def air_dash() -> np.ndarray:
    return whoosh(0.32, 1200.0, 3500.0, 1500.0, 32, rise=0.25)


def boost() -> np.ndarray:
    n = ns(0.95)
    t = times(n)
    thump = synth.sine(synth.curve([(0.0, 95.0), (0.15, 40.0)], n, exponential=True)) * synth.decay_env(n, 0.35)
    roar = whoosh(0.95, 800.0, 4200.0, 1400.0, 33, q=0.6, rise=0.18)
    zap_len = ns(0.18)
    zap = synth.fm(synth.curve([(0.0, 600.0), (0.12, 1800.0)], zap_len, exponential=True), 0.1, 1.0, [
        Op(ratio=2.0, level=2.0, decay=0.1, sustain=0.0, release=0.05), Op(ratio=1.0, level=0.6, decay=0.15, sustain=0.0, release=0.05),
        Op(level=0.0), Op(level=0.0)], 4)
    rumble = synth.filt(synth.pink(n, 34), "lowpass", 300.0) * synth.decay_env(n, 0.6) * (1.0 - np.exp(-t / 0.03))
    return place([(0.0, thump * 0.9), (0.0, roar), (0.0, zap * 0.35), (0.0, rumble * 0.5)], 0.95)


def boost_loop() -> np.ndarray:
    seconds, cross = 2.0, 0.4
    n = ns(seconds + cross)
    t = times(n)
    wind = synth.filt(synth.pink(n, 35), "lowpass", 3000.0)
    wind = wind * 0.6 + synth.filt(synth.noise(n, 36), "bandpass", 1300.0, 0.9) * 0.4
    sway = 0.85 + 0.1 * np.sin(synth.TAU * 0.5 * t) + 0.05 * np.sin(synth.TAU * 1.5 * t + 1.0)
    return synth.seamless_loop(wind * sway, cross)


def air_boost() -> np.ndarray:
    roar = whoosh(0.55, 1000.0, 4000.0, 1600.0, 37, q=0.7, rise=0.15)
    n = ns(0.12)
    zap = synth.sine(synth.curve([(0.0, 700.0), (0.1, 1600.0)], n, exponential=True)) * synth.decay_env(n, 0.1)
    return place([(0.0, roar), (0.0, zap * 0.3)], 0.55)


def quickstep() -> np.ndarray:
    return whoosh(0.14, 2200.0, 5200.0, 3000.0, 38, q=1.0, rise=0.35)


# --- Items and gimmicks ------------------------------------------------------------------

def monitor() -> np.ndarray:
    n = ns(0.65)
    crunch = synth.filt(synth.noise(n, 39), "lowpass", 3200.0) * synth.decay_env(n, 0.15)
    thump = synth.sine(synth.curve([(0.0, 130.0), (0.12, 60.0)], n, exponential=True)) * synth.decay_env(n, 0.22)
    clink = synth.fm(np.full(ns(0.3), 2300.0), 0.05, 1.0, [
        Op(ratio=1.41, level=2.0, decay=0.15, sustain=0.0, release=0.1), Op(ratio=1.0, level=0.5, decay=0.25, sustain=0.0, release=0.1),
        Op(level=0.0), Op(level=0.0)], 4)
    tail = synth.filt(synth.noise(n, 40), "lowpass", 1000.0) * synth.decay_env(n, 0.4) * 0.4
    return place([(0.0, crunch * 0.7), (0.0, thump * 0.8), (0.01, clink * 0.4), (0.03, tail)], 0.65)


def shield() -> np.ndarray:
    n = ns(0.65)
    t = times(n)
    sweep = synth.sine(synth.curve([(0.0, 200.0), (0.45, 820.0)], n, exponential=True))
    sweep += synth.sine(synth.curve([(0.0, 203.0), (0.45, 826.0)], n, exponential=True))
    shimmer = sum(synth.sine(f, n) * synth.decay_env(n, 0.4) for f in (2637.0, 3136.0, 3951.0)) * 0.08
    env = synth.curve([(0.0, 0.0), (0.08, 1.0), (0.4, 0.8), (0.65, 0.0)], n)
    return sweep * 0.35 * env + shimmer * np.minimum(t / 0.2, 1.0)


def magnet() -> np.ndarray:
    n = ns(0.7)
    t = times(n)
    hum = synth.filt(synth.wave("saw", synth.curve([(0.0, 110.0), (0.5, 220.0)], n, exponential=True)), "lowpass", 1800.0)
    hum *= 0.6 + 0.4 * np.sin(synth.TAU * 30.0 * t)
    zap = synth.filt(synth.noise(n, 41), "bandpass", 4000.0, 2.0) * synth.decay_env(n, 0.08)
    return hum * synth.adsr(0.45, 0.02, 0.2, 0.8, 0.2, length=n) * 0.6 + zap * 0.4


def boost_fill() -> np.ndarray:
    notes = [698.5, 880.0, 1046.5, 1396.9]
    parts = [(i * 0.05, blip(f, 0.16, "pulse", 0.3) * 0.5) for i, f in enumerate(notes)]
    parts.append((0.0, whoosh(0.5, 800.0, 3000.0, 2000.0, 42, rise=0.6) * 0.5))
    return place(parts, 0.55)


def spring() -> np.ndarray:
    n = ns(0.5)
    t = times(n)
    wobble = 1.0 + 0.18 * np.exp(-t / 0.12) * np.sin(synth.TAU * 17.0 * t)
    freq = synth.curve([(0.0, 300.0), (0.06, 640.0), (0.5, 600.0)], n, exponential=True) * wobble
    tone = synth.wave("triangle", freq) * 0.7 + synth.wave("pulse", freq, width=0.4) * 0.25
    return synth.filt(tone, "lowpass", 4500.0) * synth.adsr(0.25, 0.003, 0.2, 0.7, 0.22, length=n)


def dash_panel() -> np.ndarray:
    n = ns(0.42)
    t = times(n)
    rise = synth.filt(synth.wave("saw", synth.curve([(0.0, 200.0), (0.25, 950.0)], n, exponential=True)), "lowpass", 3000.0)
    rise *= (0.7 + 0.3 * np.sin(synth.TAU * 24.0 * t)) * synth.adsr(0.2, 0.004, 0.1, 0.8, 0.2, length=n)
    return rise * 0.45 + whoosh(0.42, 1500.0, 4500.0, 2000.0, 43, rise=0.4) * 0.6


def checkpoint() -> np.ndarray:
    n = ns(0.95)
    t = times(n)
    spin = 0.6 + 0.4 * np.sin(synth.TAU * 14.0 * t)
    ding = bell(1760.0, 0.6, 0.8)
    return place([(0.0, ding), (0.16, ding * 0.8)], 0.95) * spin


def goal() -> np.ndarray:
    seconds = 1.9
    n = ns(seconds)
    t = times(n)
    rate = synth.curve([(0.0, 16.0), (seconds, 3.0)], n)
    turns = np.cumsum(rate) / RATE
    swish = synth.filt(synth.noise(n, 44), "bandpass", 2200.0, 1.2) * (0.5 + 0.5 * np.cos(synth.TAU * turns)) ** 4
    parts = [(0.0, swish * synth.curve([(0.0, 1.0), (seconds, 0.0)], n) * 0.6)]
    for i, at in enumerate((0.0, 0.5, 1.1)):
        parts.append((at, bell(1318.5 if i < 2 else 1760.0, 0.7, 0.7) * 0.5))
    return place(parts, seconds + 0.5)


def red_ring() -> np.ndarray:
    notes = [1046.5, 1318.5, 1568.0, 2093.0, 2637.0]
    parts = [(i * 0.055, synth.pan(bell(f, 0.9, 0.7), -0.4 + 0.2 * i)) for i, f in enumerate(notes)]
    n = ns(1.2)
    glow = sum(synth.sine(f, n) for f in (4186.0, 5274.0, 6272.0)) * synth.curve([(0.0, 0.0), (0.3, 0.05), (1.2, 0.0)], n)
    parts.append((0.1, np.stack([glow, glow])))
    return place(parts, 1.5, stereo=True)


def wave() -> np.ndarray:
    seconds = 3.6
    n = ns(seconds)
    out = []
    for ch in range(2):
        water = synth.pink(n, 45 + ch)
        cutoff = synth.curve([(0.0, 400.0), (1.2, 2600.0), (seconds, 500.0)], n, exponential=True)
        water = synth.sweep(water, "lowpass", cutoff, 0.7)
        env = synth.curve([(0.0, 0.0), (1.2, 1.0), (seconds, 0.0)], n) ** 1.3
        crash = synth.filt(synth.noise(n, 47 + ch), "bandpass", 1500.0, 0.7) * synth.decay_env(n, 0.6)
        mixed = water * env
        synth.add_at(mixed, crash[:n - ns(1.1)] * 0.4, ns(1.1))
        out.append(mixed)
    return np.mean(out, axis=0)  # Mono: the 3D player places it.


def splash() -> np.ndarray:
    n = ns(0.3)
    burst = synth.sweep(synth.noise(n, 49), "bandpass", synth.curve([(0.0, 1200.0), (0.3, 3000.0)], n, True), 0.8)
    parts = [(0.0, burst * synth.decay_env(n, 0.25))]
    for i in range(6):
        drop_len = ns(0.05)
        f0 = 1200.0 + 900.0 * (synth.wobble("drop", i) + 1.0)
        drop = synth.sine(synth.curve([(0.0, f0), (0.05, f0 * 1.6)], drop_len, True)) * synth.decay_env(drop_len, 0.04)
        parts.append((0.05 + i * 0.05 + 0.02 * synth.wobble("at", i), drop * 0.3))
    return place(parts, 0.6)


def air_warning() -> np.ndarray:
    """Two quick high chimes: the air is running low."""
    ding = bell(1318.5, 0.3, 0.5)
    return place([(0.0, ding), (0.16, ding * 0.8)], 0.6)


def breathe() -> np.ndarray:
    """A gulp of air from a bubble: a rising bloop and a few little bubbles."""
    n = ns(0.22)
    gulp = synth.sine(synth.curve([(0.0, 260.0), (0.18, 720.0)], n, exponential=True))
    gulp = gulp * synth.adsr(0.16, 0.006, 0.06, 0.6, 0.06, length=n)
    parts = [(0.0, gulp)]
    for i in range(4):
        drop_len = ns(0.06)
        f0 = 900.0 + 500.0 * (synth.wobble("gulp", i) + 1.0)
        drop = synth.sine(synth.curve([(0.0, f0), (0.06, f0 * 1.8)], drop_len, True)) * synth.decay_env(drop_len, 0.05)
        parts.append((0.12 + i * 0.045, drop * 0.35))
    return place(parts, 0.45)


def drown() -> np.ndarray:
    """A gurgling fall in pitch, wobbling, with bubbles rising past."""
    seconds = 1.6
    n = ns(seconds)
    t = times(n)
    freq = synth.curve([(0.0, 520.0), (seconds, 90.0)], n, exponential=True) * (1.0 + 0.08 * np.sin(synth.TAU * 9.0 * t))
    gurgle = synth.filt(synth.wave("triangle", freq), "lowpass", 2400.0) * synth.adsr(1.4, 0.01, 0.3, 0.8, 0.2, length=n)
    parts = [(0.0, gurgle * 0.8)]
    for i in range(10):
        drop_len = ns(0.07)
        f0 = 500.0 + 700.0 * (synth.wobble("drown", i) + 1.0)
        drop = synth.sine(synth.curve([(0.0, f0), (0.07, f0 * 1.7)], drop_len, True)) * synth.decay_env(drop_len, 0.05)
        parts.append((0.05 + i * 0.14 + 0.04 * synth.wobble("drown at", i), drop * 0.3))
    return place(parts, seconds + 0.1)


def grind() -> np.ndarray:
    """Landing on a rail: a metal clank and the start of the scrape."""
    n = ns(0.5)
    clank = synth.fm(np.full(n, 640.0), 0.05, 1.0, [
        Op(ratio=2.76, level=2.4, decay=0.12, sustain=0.0, release=0.1, velocity=0.0),
        Op(ratio=1.0, level=0.8, decay=0.35, sustain=0.0, release=0.2, velocity=0.0),
        Op(ratio=5.4, level=1.0, decay=0.06, sustain=0.0, release=0.05, velocity=0.0),
        Op(ratio=1.0, level=0.0)], 4)
    scrape = synth.filt(synth.noise(n, 60), "bandpass", 3600.0, 2.5) * synth.curve([(0.0, 0.0), (0.05, 0.6), (0.5, 0.0)], n)
    return clank * 0.7 + scrape


def grind_loop() -> np.ndarray:
    """Grinding along a rail: a bright metal scrape with crackling sparks, looping seamlessly."""
    seconds, cross = 2.0, 0.4
    n = ns(seconds + cross)
    t = times(n)
    scrape = synth.filt(synth.noise(n, 61), "bandpass", 3200.0, 3.0) * 0.7
    ring = synth.filt(synth.noise(n, 62), "bandpass", 5200.0, 8.0) * 0.5
    hum = synth.filt(synth.pink(n, 63), "lowpass", 600.0) * 0.4
    sparks = synth.filt((synth.noise(n, 64) > 0.995) * 1.0, "highpass", 2500.0) * 0.5
    sway = 0.85 + 0.1 * np.sin(synth.TAU * 3.0 * t) + 0.05 * np.sin(synth.TAU * 7.0 * t + 1.0)
    return synth.seamless_loop((scrape + ring + hum + sparks) * sway, cross)


def crumble() -> np.ndarray:
    """A ledge giving way: a low rumble with stones cracking off."""
    seconds = 0.9
    n = ns(seconds)
    rumble = synth.filt(synth.pink(n, 65), "lowpass", 260.0) * synth.curve([(0.0, 0.0), (0.1, 1.0), (seconds, 0.0)], n)
    parts = [(0.0, rumble * 1.4)]
    for i in range(7):
        crack_len = ns(0.05)
        crack = synth.filt(synth.noise(crack_len, 66 + i), "bandpass", 900.0 + 300.0 * i, 1.2) * synth.decay_env(crack_len, 0.03)
        parts.append((0.05 + i * 0.1 + 0.03 * synth.wobble("crumble", i), crack * 0.6))
    return place(parts, seconds)


def wall_break() -> np.ndarray:
    """Smashing through a rock wall: a heavy thump, a crunch and rocks clattering away."""
    seconds = 1.1
    n = ns(seconds)
    thump = synth.sine(synth.curve([(0.0, 120.0), (0.2, 45.0)], n, exponential=True)) * synth.decay_env(n, 0.3)
    crunch = synth.sweep(synth.noise(n, 70), "lowpass", synth.curve([(0.0, 5000.0), (0.6, 600.0)], n, True), 0.8)
    crunch *= synth.decay_env(n, 0.4)
    parts = [(0.0, thump), (0.0, crunch * 0.8)]
    for i in range(9):
        knock_len = ns(0.06)
        knock = synth.filt(synth.noise(knock_len, 71 + i), "bandpass", 700.0 + 180.0 * i, 2.0) * synth.decay_env(knock_len, 0.04)
        parts.append((0.15 + i * 0.08 + 0.03 * synth.wobble("wall", i), knock * (0.5 - 0.03 * i)))
    return place(parts, seconds)


# --- Enemies and the boss -----------------------------------------------------------------

def enemy_pop() -> np.ndarray:
    n = ns(0.55)
    thump = synth.sine(synth.curve([(0.0, 600.0), (0.05, 100.0)], n, exponential=True)) * synth.decay_env(n, 0.12)
    blast = synth.sweep(synth.noise(n, 50), "lowpass", synth.curve([(0.0, 6000.0), (0.4, 700.0)], n, True), 0.7)
    blast *= synth.decay_env(n, 0.32)
    crackle = (synth.noise(n, 51) > 0.97) * synth.decay_env(n, 0.2) * 0.6
    return thump * 0.8 + blast + synth.filt(crackle, "highpass", 1500.0)


def explosion() -> np.ndarray:
    n = ns(1.3)
    boom = synth.sine(synth.curve([(0.0, 75.0), (0.4, 34.0)], n, exponential=True)) * synth.decay_env(n, 0.8)
    blast = synth.sweep(synth.noise(n, 52), "lowpass", synth.curve([(0.0, 4500.0), (1.0, 300.0)], n, True), 0.7)
    blast *= synth.decay_env(n, 1.0)
    crackle = (synth.noise(n, 53) > 0.985) * synth.decay_env(n, 0.5)
    return boom * 0.9 + blast + synth.filt(crackle, "highpass", 1200.0) * 0.7


def enemy_shot() -> np.ndarray:
    n = ns(0.2)
    freq = synth.curve([(0.0, 1400.0), (0.15, 350.0)], n, exponential=True)
    return synth.filt(synth.wave("square", freq), "lowpass", 4000.0) * synth.decay_env(n, 0.17)


def boss_hit() -> np.ndarray:
    n = ns(1.0)
    clang = synth.fm(np.full(n, 220.0), 0.1, 1.0, [
        Op(ratio=2.76, level=2.5, decay=0.4, sustain=0.0, release=0.4), Op(ratio=1.0, level=0.6, decay=0.9, sustain=0.0, release=0.4),
        Op(ratio=5.4, level=1.5, decay=0.2, sustain=0.0, release=0.2), Op(ratio=2.0, level=0.3, decay=0.6, sustain=0.0, release=0.3)], 4)
    thud = synth.sine(synth.curve([(0.0, 110.0), (0.1, 70.0)], n, exponential=True)) * synth.decay_env(n, 0.15)
    click = synth.filt(synth.noise(n, 54), "highpass", 3000.0) * synth.decay_env(n, 0.01)
    return clang * 0.8 + thud * 0.7 + click * 0.4


def boss_slam() -> np.ndarray:
    n = ns(0.95)
    boom = synth.sine(synth.curve([(0.0, 60.0), (0.3, 30.0)], n, exponential=True)) * synth.decay_env(n, 0.6)
    body = synth.filt(synth.noise(n, 55), "lowpass", 800.0) * synth.decay_env(n, 0.4)
    clank = synth.fm(np.full(n, 140.0), 0.05, 1.0, [
        Op(ratio=2.76, level=2.0, decay=0.25, sustain=0.0, release=0.2), Op(ratio=1.0, level=0.5, decay=0.5, sustain=0.0, release=0.2),
        Op(level=0.0), Op(level=0.0)], 4)
    hiss = synth.filt(synth.noise(n, 56), "bandpass", 2500.0, 0.6) * synth.curve([(0.0, 0.0), (0.1, 0.4), (0.95, 0.0)], n)
    return boom + body * 0.7 + clank * 0.4 + hiss * 0.5


def boss_sweep() -> np.ndarray:
    n = ns(0.7)
    rumble = synth.filt(synth.pink(n, 57), "lowpass", 250.0) * synth.curve([(0.0, 0.0), (0.25, 1.0), (0.7, 0.0)], n)
    return whoosh(0.7, 400.0, 2000.0, 500.0, 58, q=0.7, rise=0.4) + rumble * 0.5


def boss_charge() -> np.ndarray:
    n = ns(0.9)
    t = times(n)
    freq = synth.curve([(0.0, 70.0), (0.8, 165.0)], n, exponential=True)
    rev = synth.filt(synth.wave("saw", freq), "lowpass", 1400.0)
    rev *= 0.6 + 0.4 * np.sin(synth.TAU * np.cumsum(synth.curve([(0.0, 20.0), (0.9, 36.0)], n)) / RATE)
    gears = synth.filt((np.sin(synth.TAU * np.cumsum(synth.curve([(0.0, 25.0), (0.9, 45.0)], n)) / RATE) > 0.97) * 1.0, "highpass", 2000.0)
    return (rev * 0.8 + gears * 0.3) * synth.adsr(0.7, 0.05, 0.3, 0.9, 0.2, length=n) * np.minimum(t / 0.1, 1.0)


def boss_roar() -> np.ndarray:
    n = ns(1.35)
    t = times(n)
    bend = synth.curve([(0.0, 0.85), (0.3, 1.05), (1.35, 0.8)], n)
    roar = sum(synth.wave("saw", f * bend) for f in (82.0, 87.0, 123.0))
    roar = synth.filt(synth.saturate(roar, 3.0), "lowpass", 1500.0) * (0.7 + 0.3 * np.sin(synth.TAU * 25.0 * t))
    return roar * synth.adsr(0.9, 0.12, 0.3, 0.85, 0.35, length=n)


def ship() -> np.ndarray:
    seconds = 2.8
    n = ns(seconds)
    t = times(n)
    hum = sum(synth.wave("saw", f, n) * a for f, a in ((55.0, 0.6), (110.0, 0.4), (165.0, 0.25)))
    hum = synth.filt(hum, "lowpass", 800.0) * (0.75 + 0.25 * np.sin(synth.TAU * 6.0 * t))
    jet = synth.filt(synth.pink(n, 59), "highpass", 800.0) * 0.35
    env = synth.curve([(0.0, 0.0), (0.8, 1.0), (2.0, 0.9), (seconds, 0.0)], n)
    return (hum + jet) * env


# --- Menus -------------------------------------------------------------------------------

def ui_move() -> np.ndarray:
    n = ns(0.06)
    return (synth.sine(1320.0, n) + synth.sine(2640.0, n) * 0.3) * synth.decay_env(n, 0.04)


def ui_confirm() -> np.ndarray:
    return place([(0.0, blip(988.0, 0.06, "pulse", 0.25)), (0.05, blip(1318.5, 0.11, "pulse", 0.25))], 0.17)


def ui_back() -> np.ndarray:
    return place([(0.0, blip(1318.5, 0.06, "pulse", 0.25)), (0.05, blip(880.0, 0.11, "pulse", 0.25))], 0.17)


def ui_locked() -> np.ndarray:
    n = ns(0.2)
    buzz = synth.wave("square", 160.0, n) + synth.wave("square", 170.0, n)
    return synth.filt(buzz, "lowpass", 1500.0) * synth.adsr(0.12, 0.003, 0.05, 0.8, 0.06, length=n) * 0.5


def ui_pause() -> np.ndarray:
    return place([(0.0, bell(1046.5, 0.45, 0.6)), (0.0, bell(1568.0, 0.45, 0.5) * 0.6)], 0.45)


def ui_start() -> np.ndarray:
    parts = [(0.0, whoosh(0.35, 600.0, 4000.0, 3000.0, 60, rise=0.9) * 0.6)]
    for i, f in enumerate((1046.5, 1318.5, 1568.0, 2093.0)):
        parts.append((0.25 + i * 0.05, bell(f, 0.8, 0.7) * 0.5))
    return place(parts, 1.2)


# Each sound's function, by the name of its file.
SOUNDS = {
    "jump": jump, "roll": roll, "spin_charge": spin_charge, "spin_release": spin_release, "skid": skid,
    "ring_left": ring_left, "ring_right": ring_right, "ring_loss": ring_loss, "death": death,
    "shield_loss": shield_loss, "homing": homing, "air_dash": air_dash, "boost": boost,
    "boost_loop": boost_loop, "air_boost": air_boost, "quickstep": quickstep,
    "monitor": monitor, "shield": shield, "magnet": magnet, "boost_fill": boost_fill, "spring": spring,
    "dash_panel": dash_panel, "checkpoint": checkpoint, "goal": goal, "red_ring": red_ring,
    "wave": wave, "splash": splash, "air_warning": air_warning, "breathe": breathe, "drown": drown,
    "grind": grind, "grind_loop": grind_loop, "crumble": crumble, "wall_break": wall_break,
    "enemy_pop": enemy_pop, "explosion": explosion, "enemy_shot": enemy_shot, "boss_hit": boss_hit,
    "boss_slam": boss_slam, "boss_sweep": boss_sweep, "boss_charge": boss_charge, "boss_roar": boss_roar,
    "ship": ship,
    "ui_move": ui_move, "ui_confirm": ui_confirm, "ui_back": ui_back, "ui_locked": ui_locked,
    "ui_pause": ui_pause, "ui_start": ui_start,
}

# How loud each sound is (LUFS; the music sits at -17). Frequent sounds sit lower, big hits higher.
LEVELS = {
    "jump": -19.0, "roll": -21.0, "spin_charge": -20.0, "spin_release": -18.0, "skid": -21.0,
    "ring_left": -20.0, "ring_right": -20.0, "ring_loss": -17.0, "death": -17.0, "shield_loss": -19.0,
    "homing": -19.0, "air_dash": -20.0, "boost": -15.0, "boost_loop": -27.0, "air_boost": -17.0,
    "quickstep": -22.0, "monitor": -17.0, "shield": -18.0, "magnet": -19.0, "boost_fill": -19.0,
    "spring": -18.0, "dash_panel": -19.0, "checkpoint": -19.0, "goal": -19.0, "red_ring": -17.0,
    "wave": -20.0, "splash": -21.0, "enemy_pop": -17.0, "explosion": -16.0, "enemy_shot": -20.0,
    "boss_hit": -16.0, "boss_slam": -16.0, "boss_sweep": -19.0, "boss_charge": -19.0, "boss_roar": -17.0,
    "ship": -20.0, "ui_move": -28.0, "ui_confirm": -24.0, "ui_back": -25.0, "ui_locked": -24.0,
    "ui_pause": -24.0, "ui_start": -19.0,
    "air_warning": -19.0, "breathe": -19.0, "drown": -17.0, "grind": -20.0, "grind_loop": -27.0,
    "crumble": -19.0, "wall_break": -16.0,
}

LOOPS = {"boost_loop", "grind_loop"}


def loudness(audio: np.ndarray) -> float:
    """LUFS, measured over the sound itself when it's shorter than the standard 0.4 s window."""
    if audio.shape[-1] >= ns(0.4):
        return synth.lufs(audio)
    stereo = audio if audio.ndim == 2 else audio[np.newaxis, :]
    weighted = stereo
    for b, a in synth._k_weighting():
        weighted = synth.signal.lfilter(b, a, weighted, axis=-1)
    return 10.0 * math.log10(float(np.sum(np.mean(weighted ** 2, axis=-1))) + 1e-12) - 0.691


def finish(name: str, audio: np.ndarray) -> tuple[np.ndarray, tuple[int, int] | None]:
    """A rendered sound set to its loudness, its peaks kept under -1 dB, trimmed, and its loop
    points if it loops."""
    if name in LOOPS:  # (No filtering or limiting: either would put a seam at the loop point.)
        audio = audio * synth.db(LEVELS[name] - loudness(audio))
        return audio, (0, audio.shape[-1] - 1)
    audio = synth.filt(audio, "highpass", 25.0)
    audio = synth.trim_silence(audio, -66.0, 0.01)
    audio = synth.fade(audio, 0.0, 0.006)
    audio = synth.limit(audio * synth.db(LEVELS[name] - loudness(audio)), -1.0)
    return audio, None
