"""Signal building blocks for the game's music and sound effects.

Everything works on numpy arrays of float samples at RATE: envelopes, oscillators, FM operators,
noise, filters, effects, loudness measurement and file output. Mono sound is a 1-D array; stereo
is a (2, n) array. The music (song.py, instruments.py) and the sound effects (sounds.py) are built
from these.
"""
from __future__ import annotations

import math
import os
import struct
import subprocess
import tempfile
import zlib
from dataclasses import dataclass

import numpy as np
from scipy import signal
from scipy.ndimage import maximum_filter1d

RATE = 44100
TAU = 2.0 * math.pi


def n_samples(seconds: float) -> int:
    return max(0, int(round(seconds * RATE)))


def midi_hz(note: float) -> float:
    return 440.0 * 2.0 ** ((note - 69.0) / 12.0)


def db(gain_db: float) -> float:
    return 10.0 ** (gain_db / 20.0)


def wobble(*keys) -> float:
    """A number from -1 to 1 that looks random but is always the same for the same keys, so
    renders repeat exactly."""
    return zlib.crc32(repr(keys).encode()) / 2.0 ** 31 - 1.0


# --- Envelopes -------------------------------------------------------------------------------

def adsr(gate: float, attack: float = 0.002, decay: float = 0.2, sustain: float = 1.0,
         release: float = 0.05, length: int | None = None) -> np.ndarray:
    """An attack-decay-sustain-release envelope: a linear rise over `attack` seconds, an
    exponential fall to `sustain` (most of the way by `decay` seconds), held until `gate` seconds,
    then an exponential release lasting `release` seconds. `length` pads or cuts it to that many
    samples."""
    n_gate = max(1, n_samples(gate))
    n_release = max(2, n_samples(release))
    t = np.arange(n_gate) / RATE
    attack = max(attack, 0.0005)
    rise = np.minimum(t / attack, 1.0)
    fall = sustain + (1.0 - sustain) * np.exp(-np.maximum(t - attack, 0.0) * 5.0 / max(decay, 1e-4))
    held = np.where(t < attack, rise, fall)
    level = held[-1]
    tail = level * np.exp(-np.arange(n_release) / RATE * 5.0 / max(release, 1e-4))
    fade = min(n_release, n_samples(0.002))
    tail[-fade:] *= np.linspace(1.0, 0.0, fade)
    env = np.concatenate([held, tail])
    return fit(env, length) if length is not None else env


def decay_env(n: int, seconds: float, attack: float = 0.001) -> np.ndarray:
    """A percussive envelope: a quick linear rise, then an exponential fall that is about -43 dB
    after `seconds`."""
    t = np.arange(n) / RATE
    attack = max(attack, 0.0002)
    return np.minimum(t / attack, 1.0) * np.exp(-np.maximum(t - attack, 0.0) * 5.0 / max(seconds, 1e-4))


def curve(points: list[tuple[float, float]], n: int, exponential: bool = False) -> np.ndarray:
    """A curve through (seconds, value) points, held flat after the last one. Exponential
    interpolation suits pitches and filter frequencies."""
    times = np.array([p[0] for p in points]) * RATE
    values = np.array([p[1] for p in points], dtype=float)
    x = np.arange(n)
    if exponential:
        return np.exp(np.interp(x, times, np.log(np.maximum(values, 1e-9))))
    return np.interp(x, times, values)


def fit(x: np.ndarray, length: int) -> np.ndarray:
    """`x` cut or zero-padded (along its last axis) to `length` samples."""
    have = x.shape[-1]
    if have >= length:
        return x[..., :length]
    pad = [(0, 0)] * (x.ndim - 1) + [(0, length - have)]
    return np.pad(x, pad)


# --- Oscillators ---------------------------------------------------------------------------

def phase(freq: np.ndarray | float, n: int | None = None) -> np.ndarray:
    """Running phase in cycles for a frequency (Hz), constant or one value per sample."""
    if np.isscalar(freq):
        return np.arange(n) * (float(freq) / RATE)
    return np.cumsum(freq) / RATE - freq[0] / RATE


def sine(freq: np.ndarray | float, n: int | None = None) -> np.ndarray:
    return np.sin(TAU * phase(freq, n))


_TABLES: dict[tuple[str, int, float], np.ndarray] = {}
_TABLE_SIZE = 4096


def _table(kind: str, harmonics: int, width: float) -> np.ndarray:
    key = (kind, harmonics, round(width, 3))
    if key not in _TABLES:
        x = np.arange(_TABLE_SIZE) / _TABLE_SIZE
        out = np.zeros(_TABLE_SIZE)
        for k in range(1, harmonics + 1):
            if kind == "saw":
                amp = 1.0 / k
            elif kind == "square":
                amp = 1.0 / k if k % 2 else 0.0
            elif kind == "triangle":
                amp = ((-1) ** ((k - 1) // 2)) / (k * k) if k % 2 else 0.0
            else:  # pulse of the given width
                amp = math.sin(math.pi * k * width) / k
            if amp:
                # A little roll-off near the top keeps the brightest harmonics from ringing.
                amp *= 0.5 + 0.5 * math.cos(math.pi * k / (harmonics + 1)) if harmonics > 8 else 1.0
                out += amp * (np.sin(TAU * k * x) if kind != "pulse" else np.cos(TAU * k * x))
        out /= max(np.max(np.abs(out)), 1e-9)
        _TABLES[key] = out
    return _TABLES[key]


def wave(kind: str, freq: np.ndarray | float, n: int | None = None, width: float = 0.5) -> np.ndarray:
    """A band-limited saw, square, triangle or pulse wave (no aliasing below the highest
    frequency it reaches)."""
    top = float(np.max(freq)) if not np.isscalar(freq) else float(freq)
    harmonics = max(1, min(256, int(RATE * 0.45 / max(top, 1.0))))
    table = _table(kind, harmonics, width)
    p = phase(freq, n) % 1.0
    return np.interp(p * _TABLE_SIZE, np.arange(_TABLE_SIZE + 1), np.append(table, table[0]))


def noise(n: int, seed: int) -> np.ndarray:
    """White noise between about -1 and 1, the same every time for the same seed."""
    return np.random.default_rng(seed).uniform(-1.0, 1.0, n)


def pink(n: int, seed: int) -> np.ndarray:
    """Pink noise (falling 3 dB an octave), softer and more natural than white for wind and water."""
    white = np.random.default_rng(seed).standard_normal(n + 4096)
    b = [0.049922035, -0.095993537, 0.050612699, -0.004408786]
    a = [1.0, -2.494956002, 2.017265875, -0.522189400]
    out = signal.lfilter(b, a, white)[4096:]
    return out / max(np.max(np.abs(out)), 1e-9)


def metallic(n: int) -> np.ndarray:
    """Six square waves at unrelated pitches, the classic drum machine recipe for cymbals and hats."""
    out = np.zeros(n)
    for f in (205.3, 304.4, 369.6, 522.7, 540.0, 800.0):
        out += wave("square", f * 1.9, n)
    return out / 6.0


# --- FM synthesis --------------------------------------------------------------------------

@dataclass
class Op:
    """One FM operator: a sine at `ratio` times the note's pitch (or `fixed` Hz) with its own
    envelope. A carrier's `level` is its loudness; a modulator's is its peak modulation index,
    in radians, which sets how bright it makes what it feeds."""
    ratio: float = 1.0
    level: float = 1.0
    attack: float = 0.002
    decay: float = 0.3
    sustain: float = 1.0
    release: float = 0.08
    detune: float = 0.0  # cents
    fixed: float = 0.0  # Hz, instead of following the note
    velocity: float = 0.5  # 0: the level ignores velocity; 1: scales fully with it
    key_scale: float = 0.0  # level change per octave above middle C, as a factor (e.g. -0.2)
    feedback: float = 0.0  # self-modulation, toward a saw-like tone


# Which operators feed which, after the Genesis's YM2612. Each entry maps an operator to those
# modulating it; the last list is the carriers, whose sum is heard.
ALGORITHMS: dict[int, tuple[dict[int, list[int]], list[int]]] = {
    0: ({1: [0], 2: [1], 3: [2]}, [3]),
    1: ({2: [0, 1], 3: [2]}, [3]),
    2: ({3: [0, 2], 2: [1]}, [3]),
    3: ({1: [0], 3: [1, 2]}, [3]),
    4: ({1: [0], 3: [2]}, [1, 3]),
    5: ({1: [0], 2: [0], 3: [0]}, [1, 2, 3]),
    6: ({1: [0]}, [1, 2, 3]),
    7: ({}, [0, 1, 2, 3]),
}


def fm(freq: np.ndarray, gate: float, velocity: float, ops: list[Op], algorithm: int) -> np.ndarray:
    """A note through four FM operators connected by `algorithm`, at the pitch `freq` (Hz per
    sample, which also sets the length), held for `gate` seconds."""
    n = len(freq)
    links, carriers = ALGORITHMS[algorithm]
    base_phase = TAU * phase(freq)
    t = np.arange(n) / RATE
    octaves_up = math.log2(max(float(freq[0]), 1.0) / 261.63)
    out_of: dict[int, np.ndarray] = {}
    for i, op in enumerate(ops):
        if op.fixed:
            ph = TAU * op.fixed * t
        else:
            ph = base_phase * (op.ratio * 2.0 ** (op.detune / 1200.0))
        mod = 0.0
        for j in links.get(i, []):
            mod = mod + out_of[j]
        level = op.level * (1.0 - op.velocity + op.velocity * velocity)
        level *= max(0.0, 1.0 + op.key_scale * octaves_up)
        env = adsr(gate, op.attack, op.decay, op.sustain, op.release, length=n)
        if op.feedback:
            y = np.sin(ph + mod)
            for _ in range(6):  # Settles toward y = sin(phase + feedback * y).
                y = 0.5 * y + 0.5 * np.sin(ph + mod + op.feedback * y)
        else:
            y = np.sin(ph + mod)
        out_of[i] = level * env * y
    return sum(out_of[c] for c in carriers)


# --- Filters ----------------------------------------------------------------------------

def biquad(kind: str, freq: float, q: float = 0.7071, gain_db: float = 0.0) -> tuple[np.ndarray, np.ndarray]:
    """Coefficients for one of the Audio EQ Cookbook filters: lowpass, highpass, bandpass, peak,
    lowshelf or highshelf."""
    freq = min(max(freq, 10.0), RATE * 0.49)
    w = TAU * freq / RATE
    cos_w, sin_w = math.cos(w), math.sin(w)
    alpha = sin_w / (2.0 * q)
    a_gain = 10.0 ** (gain_db / 40.0)
    if kind == "lowpass":
        b = [(1 - cos_w) / 2, 1 - cos_w, (1 - cos_w) / 2]
        a = [1 + alpha, -2 * cos_w, 1 - alpha]
    elif kind == "highpass":
        b = [(1 + cos_w) / 2, -(1 + cos_w), (1 + cos_w) / 2]
        a = [1 + alpha, -2 * cos_w, 1 - alpha]
    elif kind == "bandpass":
        b = [alpha, 0.0, -alpha]
        a = [1 + alpha, -2 * cos_w, 1 - alpha]
    elif kind == "peak":
        b = [1 + alpha * a_gain, -2 * cos_w, 1 - alpha * a_gain]
        a = [1 + alpha / a_gain, -2 * cos_w, 1 - alpha / a_gain]
    elif kind in ("lowshelf", "highshelf"):
        sq = 2.0 * math.sqrt(a_gain) * alpha
        sign = 1.0 if kind == "lowshelf" else -1.0
        b = [a_gain * ((a_gain + 1) - sign * (a_gain - 1) * cos_w + sq),
             sign * 2 * a_gain * ((a_gain - 1) - sign * (a_gain + 1) * cos_w),
             a_gain * ((a_gain + 1) - sign * (a_gain - 1) * cos_w - sq)]
        a = [(a_gain + 1) + sign * (a_gain - 1) * cos_w + sq,
             -sign * 2 * ((a_gain - 1) + sign * (a_gain + 1) * cos_w),
             (a_gain + 1) + sign * (a_gain - 1) * cos_w - sq]
    else:
        raise ValueError("unknown filter " + kind)
    b, a = np.array(b), np.array(a)
    return b / a[0], a / a[0]


def filt(x: np.ndarray, kind: str, freq: float, q: float = 0.7071, gain_db: float = 0.0) -> np.ndarray:
    b, a = biquad(kind, freq, q, gain_db)
    return signal.lfilter(b, a, x, axis=-1)


def sweep(x: np.ndarray, kind: str, freqs: np.ndarray, q: float = 0.7071, block: int = 32) -> np.ndarray:
    """A filter whose frequency follows `freqs` (Hz per sample), for sweeps and wah."""
    out = np.empty_like(x)
    zi = np.zeros(2)
    for start in range(0, len(x), block):
        stop = min(start + block, len(x))
        b, a = biquad(kind, float(freqs[start]), q)
        out[start:stop], zi = signal.lfilter(b, a, x[start:stop], zi=zi)
    return out


def one_pole(x: np.ndarray, seconds: float) -> np.ndarray:
    """Smooths `x` with a one-pole lowpass of time constant `seconds`."""
    k = 1.0 - math.exp(-1.0 / max(seconds * RATE, 1e-6))
    return signal.lfilter([k], [1.0, k - 1.0], x, axis=-1)


# --- Shaping and mixing ---------------------------------------------------------------------

def saturate(x: np.ndarray, drive: float) -> np.ndarray:
    """Soft clipping: `drive` above 1 adds warmth and grit, keeping the peak level."""
    return np.tanh(x * drive) / math.tanh(drive)


def pan(mono: np.ndarray, position: float) -> np.ndarray:
    """Constant-power panning from -1 (left) to 1 (right) into a stereo pair."""
    angle = (min(max(position, -1.0), 1.0) + 1.0) * math.pi / 4.0
    return np.stack([mono * math.cos(angle), mono * math.sin(angle)]) * math.sqrt(2.0)


def add_at(buffer: np.ndarray, sound: np.ndarray, start: int) -> None:
    """Adds `sound` into `buffer` starting at sample `start`, cut to fit (along the last axis)."""
    if start >= buffer.shape[-1] or start + sound.shape[-1] <= 0:
        return
    skip = max(0, -start)
    start = max(0, start)
    stop = min(buffer.shape[-1], start + sound.shape[-1] - skip)
    buffer[..., start:stop] += sound[..., skip:skip + stop - start]


def normalize(x: np.ndarray, peak_db: float = -1.0) -> np.ndarray:
    return x * (db(peak_db) / max(float(np.max(np.abs(x))), 1e-9))


def fade(x: np.ndarray, fade_in: float = 0.0, fade_out: float = 0.0) -> np.ndarray:
    x = x.copy()
    n_in, n_out = n_samples(fade_in), n_samples(fade_out)
    if n_in:
        x[..., :n_in] *= np.linspace(0.0, 1.0, n_in)
    if n_out:
        x[..., -n_out:] *= np.linspace(1.0, 0.0, n_out)
    return x


def trim_silence(x: np.ndarray, threshold_db: float = -60.0, keep: float = 0.01) -> np.ndarray:
    """Cuts the silent end off a sound, keeping `keep` seconds past the last audible sample."""
    level = np.max(np.abs(x), axis=0) if x.ndim == 2 else np.abs(x)
    audible = np.nonzero(level > db(threshold_db))[0]
    if len(audible) == 0:
        return x[..., :1]
    return x[..., :min(x.shape[-1], audible[-1] + n_samples(keep))]


def seamless_loop(x: np.ndarray, crossfade: float) -> np.ndarray:
    """Folds the last `crossfade` seconds of `x` over its start, so it loops without a seam."""
    n = n_samples(crossfade)
    body = x[..., :-n].copy()
    w = np.sin(np.linspace(0.0, math.pi / 2.0, n)) ** 2
    body[..., :n] = body[..., :n] * w + x[..., -n:] * (1.0 - w)
    return body


# --- Effects -----------------------------------------------------------------------------

def reverb_ir(seconds: float, seed: int, damping: float = 0.6, predelay: float = 0.012,
              brightness: float = 9000.0) -> np.ndarray:
    """A stereo impulse response for a room: early reflections, then a diffuse tail that fades
    by 60 dB over `seconds` and darkens as it goes (`damping` 0 to 1)."""
    n = n_samples(seconds + predelay)
    t = np.arange(n) / RATE
    ir = np.zeros((2, n))
    rng = np.random.default_rng(seed)
    start = n_samples(predelay)
    for ch in range(2):
        tail = rng.standard_normal(n) * np.exp(-6.9 * t / seconds)
        dark = filt(tail, "lowpass", brightness * 0.25)
        mix = np.minimum(t / seconds, 1.0) * damping
        tail = filt(tail * (1.0 - mix) + dark * mix * 1.6, "lowpass", brightness)
        tail[:start] = 0.0
        tail[start:start + n_samples(0.02)] *= np.linspace(0.0, 1.0, n_samples(0.02))
        ir[ch] = tail
        for _ in range(6):  # Early reflections off nearby walls.
            at = start + int(rng.uniform(0.002, 0.045) * RATE)
            ir[ch, at] += rng.uniform(0.3, 0.7) * rng.choice([-1.0, 1.0])
    return ir / math.sqrt(np.sum(ir ** 2) / 2.0)


def convolve(x: np.ndarray, ir: np.ndarray) -> np.ndarray:
    """A stereo signal through a stereo impulse response, keeping its length."""
    out = np.stack([signal.oaconvolve(x[ch], ir[ch])[:x.shape[-1]] for ch in range(2)])
    return out


def echo(x: np.ndarray, delay: float, feedback: float, damping: float = 3500.0, ping_pong: bool = True) -> np.ndarray:
    """Repeats of a stereo signal every `delay` seconds, each `feedback` times quieter and duller,
    bouncing between the speakers."""
    out = np.zeros_like(x)
    step = n_samples(delay)
    tap = x.copy()
    gain = 1.0
    k = 1
    while gain * feedback > 0.02 and k * step < x.shape[-1]:
        gain *= feedback
        tap = filt(tap, "lowpass", damping)
        moved = tap[::-1] if ping_pong and k % 2 else tap
        add_at(out, moved * gain, k * step)
        k += 1
    return out


def chorus(x: np.ndarray, rate: float = 0.8, depth: float = 0.004, mix: float = 0.5) -> np.ndarray:
    """A stereo chorus: copies delayed by a slowly swaying amount, opposite in each speaker."""
    n = x.shape[-1]
    t = np.arange(n) / RATE
    idx = np.arange(n, dtype=float)
    out = np.empty_like(x)
    for ch in range(2):
        delay = (0.012 + depth * (0.5 + 0.5 * np.sin(TAU * rate * t + ch * math.pi))) * RATE
        wet = np.interp(idx - delay, idx, x[ch], left=0.0)
        out[ch] = x[ch] * (1.0 - mix * 0.5) + wet * mix
    return out


def widen(mono: np.ndarray, amount: float, delay: float = 0.011) -> np.ndarray:
    """A mono sound spread across the speakers: a slightly delayed copy on one side."""
    late = np.zeros_like(mono)
    add_at(late, mono, n_samples(delay))
    return np.stack([mono, mono * (1.0 - amount) + late * amount])


def envelope_follow(x: np.ndarray, hold: float, release: float) -> np.ndarray:
    """The level of a stereo signal over time: the loudest sample within `hold` seconds, falling
    away over `release` seconds."""
    level = np.max(np.abs(x), axis=0) if x.ndim == 2 else np.abs(x)
    held = maximum_filter1d(level, size=max(1, n_samples(hold)), origin=0)
    # Instant rise, slow fall: smooth the drop only, by smoothing and keeping the higher.
    smooth = one_pole(held, release)
    return np.maximum(held, smooth)


def compress(x: np.ndarray, threshold_db: float, ratio: float, hold: float = 0.01, release: float = 0.15) -> np.ndarray:
    """Turns down what rises above `threshold_db`, by `ratio`."""
    level = envelope_follow(x, hold, release)
    over = 20.0 * np.log10(np.maximum(level, 1e-9)) - threshold_db
    gain_db = -np.maximum(over, 0.0) * (1.0 - 1.0 / ratio)
    gain = 10.0 ** (one_pole(gain_db, 0.003) / 20.0)
    return x * gain


def limit(x: np.ndarray, ceiling_db: float = -1.0, lookahead: float = 0.004, release: float = 0.06) -> np.ndarray:
    """Keeps peaks under `ceiling_db`, looking ahead so it turns down before each peak."""
    ceiling = db(ceiling_db)
    level = np.max(np.abs(x), axis=0) if x.ndim == 2 else np.abs(x)
    # How much each sample needs turning down, held across the look-ahead on both sides so the
    # gain is already down when the peak arrives, then let go over `release`.
    cut = 1.0 - np.minimum(1.0, ceiling / np.maximum(level, 1e-9))
    cut = envelope_follow(cut, 2.0 * lookahead, release)
    gain = one_pole(1.0 - cut, lookahead / 4.0)
    return np.clip(x * gain, -ceiling, ceiling)


# --- Loudness ----------------------------------------------------------------------------

def _k_weighting() -> list[tuple[np.ndarray, np.ndarray]]:
    # ITU-R BS.1770 pre-filter (a high shelf) and RLB weighting (a high-pass), for this sample rate.
    f0, gain, q = 1681.974450955533, 3.999843853973347, 0.7071752369554196
    k = math.tan(math.pi * f0 / RATE)
    vh = 10.0 ** (gain / 20.0)
    vb = vh ** 0.4996667741545416
    a0 = 1.0 + k / q + k * k
    shelf = (np.array([(vh + vb * k / q + k * k) / a0, 2.0 * (k * k - vh) / a0, (vh - vb * k / q + k * k) / a0]),
             np.array([1.0, 2.0 * (k * k - 1.0) / a0, (1.0 - k / q + k * k) / a0]))
    f0, q = 38.13547087602444, 0.5003270373238773
    k = math.tan(math.pi * f0 / RATE)
    a0 = 1.0 + k / q + k * k
    high = (np.array([1.0, -2.0, 1.0]), np.array([1.0, 2.0 * (k * k - 1.0) / a0, (1.0 - k / q + k * k) / a0]))
    return [shelf, high]


def lufs(x: np.ndarray) -> float:
    """Integrated loudness (LUFS, ITU-R BS.1770) of a mono or stereo signal."""
    stereo = x if x.ndim == 2 else x[np.newaxis, :]
    weighted = stereo
    for b, a in _k_weighting():
        weighted = signal.lfilter(b, a, weighted, axis=-1)
    block, step = n_samples(0.4), n_samples(0.1)
    if weighted.shape[-1] < block:
        weighted = fit(weighted, block)
    energies = []
    for start in range(0, weighted.shape[-1] - block + 1, step):
        energies.append(float(np.sum(np.mean(weighted[:, start:start + block] ** 2, axis=-1))))
    energies = np.array(energies)
    loud = energies[energies > 10.0 ** ((-70.0 + 0.691) / 10.0)]
    if len(loud) == 0:
        return -70.0
    relative = 10.0 * math.log10(np.mean(loud)) - 0.691 - 10.0
    gated = loud[10.0 * np.log10(loud) - 0.691 > relative]
    return 10.0 * math.log10(np.mean(gated)) - 0.691


def peak_db(x: np.ndarray) -> float:
    return 20.0 * math.log10(max(float(np.max(np.abs(x))), 1e-9))


BAND_CENTERS = (63.0, 125.0, 250.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0, 16000.0)
# Power in each octave band (dB, against 1 kHz) of a typical finished pop mix: about even up to
# 1 kHz, a little fuller in the bass, rolling off above.
MIX_CURVE = (3.0, 4.0, 2.0, 1.0, 0.0, -2.5, -5.5, -9.0, -16.0)


def band_levels(x: np.ndarray) -> np.ndarray:
    """Power in each octave band of BAND_CENTERS, in dB."""
    mono = x.mean(axis=0) if x.ndim == 2 else x
    freqs, power = signal.welch(mono, RATE, nperseg=8192)
    out = []
    for center in BAND_CENTERS:
        band = (freqs >= center / math.sqrt(2.0)) & (freqs < center * math.sqrt(2.0))
        out.append(10.0 * math.log10(float(np.sum(power[band])) + 1e-20))
    return np.array(out)


def match_eq(x: np.ndarray, strength: float = 0.6, most: float = 6.0) -> tuple[np.ndarray, np.ndarray]:
    """Nudges a mix's octave balance toward MIX_CURVE: each band is boosted or cut by `strength`
    of its difference from the curve, at most `most` dB. Returns the result and the gains used."""
    levels = band_levels(x)
    off = levels - np.array(MIX_CURVE)
    off -= np.mean(off[1:7])  # Judge the shape, not the overall level.
    gains = np.clip(-off * strength, -most, most)
    out = x
    for i, (center, gain) in enumerate(zip(BAND_CENTERS, gains)):
        if abs(gain) < 0.25:
            continue
        kind = "lowshelf" if i == 0 else "highshelf" if i == len(BAND_CENTERS) - 1 else "peak"
        out = filt(out, kind, center * (1.4 if i == 0 else 0.7 if kind == "highshelf" else 1.0), 0.9, float(gain))
    return out, gains


# --- Files -------------------------------------------------------------------------------

def to_pcm16(x: np.ndarray, seed: int = 0) -> np.ndarray:
    """Float samples as interleaved 16-bit integers, with a whisper of dither."""
    frames = x.T if x.ndim == 2 else x[:, np.newaxis]
    rng = np.random.default_rng(seed)
    dither = (rng.uniform(-0.5, 0.5, frames.shape) + rng.uniform(-0.5, 0.5, frames.shape)) / 32768.0
    return np.clip(np.round((frames + dither) * 32767.0), -32768, 32767).astype("<i2")


def write_wav(path: str, x: np.ndarray, loop: tuple[int, int] | None = None) -> None:
    """A 16-bit PCM WAV file. `loop` (first and last sample frame) adds a "smpl" chunk, which
    Godot's importer reads as the loop points."""
    pcm = to_pcm16(x)
    channels = pcm.shape[1]
    data = pcm.tobytes()
    chunks = [b"fmt " + struct.pack("<IHHIIHH", 16, 1, channels, RATE, RATE * channels * 2, channels * 2, 16)]
    if loop:
        smpl = struct.pack("<9I", 0, 0, int(1e9 / RATE), 60, 0, 0, 0, 1, 0)
        smpl += struct.pack("<6I", 0, 0, loop[0], loop[1], 0, 0)
        chunks.append(b"smpl" + struct.pack("<I", len(smpl)) + smpl)
    chunks.append(b"data" + struct.pack("<I", len(data)) + data)
    body = b"WAVE" + b"".join(chunks)
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "wb") as f:
        f.write(b"RIFF" + struct.pack("<I", len(body)) + body)


def write_ogg(path: str, x: np.ndarray, quality: float = 4.0) -> None:
    """An Ogg Vorbis file, encoded by FFmpeg. The bit-exact flags keep it the same byte for byte
    each time, so re-rendering unchanged music doesn't change the file."""
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    handle, temp = tempfile.mkstemp(suffix=".wav")
    os.close(handle)
    try:
        write_wav(temp, x)
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", temp, "-c:a", "libvorbis", "-q:a", str(quality),
                        "-fflags", "+bitexact", "-flags:a", "+bitexact", "-map_metadata", "-1", path], check=True)
    finally:
        os.remove(temp)
