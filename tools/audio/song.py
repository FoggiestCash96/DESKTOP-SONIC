"""Music notation and arrangement: notes, chord symbols and drum grids written as text, sections
built from them, and a song rendered from an intro and a seamless loop. tools/audio/README.md has
the full guide to the notation; in short:

Notes (melodies):  c5:8 f#5:16 bb4:4. g5:4+16 r:8 (c5 e5 g5):4 |
    A pitch (letter, optional # or b, octave: c4 is middle C) and a length: 1 2 4 8 16 32 from a
    whole note to a thirty-second, . for dotted, t for triplet, + to tie lengths. Leave the length
    off to repeat the last one. r is a rest, ( ) a chord, | a bar line (checked to fall on the bar).
    Prefixes: ! accent, _ soft, ~ slide from the last note, ^ short. v=90 sets the loudness (0-127)
    of the notes after it, q=60 how much of each note sounds (percent). [ ... ]*2 repeats.
Degrees (bass lines, arpeggios):  1:8 8:16 r 5 7, 3' 1-
    Like notes, but numbered from the chord playing at the time: 1 its bass note (or root), 3 5 7
    its third, fifth and seventh, 2 4 6 the steps between, 8 the octave. ' is an octave up and , an
    octave down; a trailing - or + shifts a semitone.
Grids (drums, chord stabs):  "x..x..X...x.o..."  one step per sixteenth: x hit, X accent,
    o soft, - hold the last hit, . rest.
Chords:  "| Fmaj7 | Am7 D7 | Bb/C |"  one or more chords per bar, sharing it evenly.
"""
from __future__ import annotations

import itertools
import math
import re
from dataclasses import dataclass, field

import numpy as np

import synth
from synth import RATE

BEATS_PER_BAR = 4
NOTE_CLASSES = {"c": 0, "d": 2, "e": 4, "f": 5, "g": 7, "a": 9, "b": 11}
SCALES = {
    "major": (0, 2, 4, 5, 7, 9, 11),
    "minor": (0, 2, 3, 5, 7, 8, 10),
    "dorian": (0, 2, 3, 5, 7, 9, 10),
    "mixolydian": (0, 2, 4, 5, 7, 9, 10),
    "harmonic minor": (0, 2, 3, 5, 7, 8, 11),
}
QUALITIES = {
    "": (0, 4, 7), "maj": (0, 4, 7), "m": (0, 3, 7), "min": (0, 3, 7), "dim": (0, 3, 6),
    "aug": (0, 4, 8), "+": (0, 4, 8), "sus4": (0, 5, 7), "sus2": (0, 2, 7), "5": (0, 7),
    "6": (0, 4, 7, 9), "m6": (0, 3, 7, 9), "7": (0, 4, 7, 10), "maj7": (0, 4, 7, 11), "m7": (0, 3, 7, 10),
    "mmaj7": (0, 3, 7, 11), "dim7": (0, 3, 6, 9), "m7b5": (0, 3, 6, 10), "7sus4": (0, 5, 7, 10),
    "9": (0, 4, 7, 10, 14), "maj9": (0, 4, 7, 11, 14), "m9": (0, 3, 7, 10, 14), "add9": (0, 4, 7, 14),
    "madd9": (0, 3, 7, 14), "7b9": (0, 4, 7, 10, 13), "7#9": (0, 4, 7, 10, 15), "7#5": (0, 4, 8, 10),
}


class NotationError(ValueError):
    pass


def pitch_class(name: str) -> int:
    pc = NOTE_CLASSES[name[0].lower()]
    for accidental in name[1:]:
        pc += 1 if accidental == "#" else -1 if accidental == "b" else 0
    return pc % 12


def parse_key(text: str) -> tuple[int, tuple[int, ...]]:
    """'F major' or 'D minor' as (tonic pitch class, scale intervals)."""
    tonic, _, mode = text.partition(" ")
    return pitch_class(tonic), SCALES[mode or "major"]


# --- Chords ----------------------------------------------------------------------------------

@dataclass
class Chord:
    symbol: str
    root: int  # pitch class
    tones: tuple[int, ...]  # semitones above the root
    bass: int  # pitch class of the bass note: the root, or the note after a slash

    def classes(self) -> set[int]:
        return {(self.root + t) % 12 for t in self.tones}

    def interval(self, wanted: tuple[int, ...]) -> int | None:
        """The first of this chord's intervals (above the root, within an octave) in `wanted`."""
        for t in self.tones:
            if t % 12 in wanted:
                return t % 12
        return None


_CHORD = re.compile(r"^([A-G][#b]?)([^/]*)(?:/([A-G][#b]?))?$")


def parse_chord(symbol: str) -> Chord:
    match = _CHORD.match(symbol)
    if not match or match.group(2) not in QUALITIES:
        raise NotationError("unknown chord %r" % symbol)
    root = pitch_class(match.group(1))
    bass = pitch_class(match.group(3)) if match.group(3) else root
    return Chord(symbol, root, QUALITIES[match.group(2)], bass)


def parse_chords(text: str) -> list[tuple[float, float, Chord]]:
    """'| F | Am7 D7 |' as (start beat, length in beats, chord), one bar per | ... |."""
    bars = [bar.split() for bar in text.strip().strip("|").split("|")]
    out = []
    for i, symbols in enumerate(bars):
        if not symbols:
            raise NotationError("empty bar %d in %r" % (i + 1, text))
        share = BEATS_PER_BAR / len(symbols)
        for j, symbol in enumerate(symbols):
            out.append((i * BEATS_PER_BAR + j * share, share, parse_chord(symbol)))
    return out


def chord_at(chords: list[tuple[float, float, Chord]], beat: float) -> Chord:
    for start, length, chord in chords:
        if start - 1e-6 <= beat < start + length - 1e-6:
            return chord
    return chords[-1][2]


def voice_chord(chord: Chord, low: int, high: int, count: int, previous: list[int] | None) -> list[int]:
    """`count` notes of `chord` between MIDI notes `low` and `high`, moving as little as possible
    from `previous` (smooth voice leading), or else sitting near the middle of the range."""
    tones = list(dict.fromkeys(t % 12 for t in chord.tones))
    while len(tones) > count:  # Drop the fifth first, then the root.
        drop = 7 if 7 in tones and len(tones) > 3 else 0 if 0 in tones else tones[-1]
        tones.remove(drop)
    # Too few tones: double one, trying the root, then the fifth, then the third.
    choices = [tones]
    if len(tones) < count:
        extra = count - len(tones)
        choices = [tones + [d] * extra for d in (0, 7, 3, 4, 5) if d in tones]
    best, best_score = None, math.inf
    for chosen in choices:
        options = []
        for t in chosen:
            pc = (chord.root + t) % 12
            options.append([p for p in range(low, high + 1) if p % 12 == pc])
        for combo in itertools.product(*options):
            notes = sorted(combo)
            if len(set(notes)) < len(notes) or notes[-1] - notes[0] > 19:
                continue
            if previous and len(previous) == len(notes):
                score = sum(abs(a - b) for a, b in zip(notes, sorted(previous)))
            else:
                score = abs(sum(notes) / len(notes) - (low + high) / 2.0) * 2.0
            score += (notes[-1] - notes[0]) * 0.1
            if score < best_score:
                best, best_score = notes, score
    if best is None:
        raise NotationError("can't voice %s between %d and %d" % (chord.symbol, low, high))
    return best


# --- Notes -----------------------------------------------------------------------------------

@dataclass
class Event:
    beat: float  # start, in beats from the start of the section
    length: float  # beats
    pitches: list  # MIDI notes, or (degree, octaves, semitones) for a degree part
    velocity: float  # 0 to 1
    gate: float  # how much of the length sounds
    slide: bool = False  # glide from the note before, without a new attack


_TOKEN = re.compile(r"""
      (?P<bar>\|)
    | (?P<set>(?P<key>[vq])=(?P<value>\d+))
    | (?P<group>(?P<gmods>[!_^]*)\((?P<inner>[^)]*)\)(?P<glen>:[0-9t.+]+)?)
    | (?P<rest>r(?P<rlen>:[0-9t.+]+)?)
    | (?P<note>(?P<mods>[!_~^]*)(?P<name>[a-g][#b]?-?\d|[1-9]['\,]*[-+]?)(?P<len>:[0-9t.+]+)?)
""", re.VERBOSE)


def _length(text: str, last: float) -> float:
    if not text:
        return last
    total = 0.0
    for part in text[1:].split("+"):
        match = re.fullmatch(r"(\d+)(t?)(\.*)", part)
        if not match:
            raise NotationError("bad length %r" % text)
        value = 4.0 / int(match.group(1))
        if match.group(2):
            value *= 2.0 / 3.0
        value *= (1.0, 1.5, 1.75, 1.875)[len(match.group(3))]
        total += value
    return total


def _pitch(name: str, degrees: bool):
    if degrees:
        if not name[0].isdigit():
            raise NotationError("expected a degree, found %r" % name)
        octaves = name.count("'") - name.count(",")
        semitones = 1 if name.endswith("+") else -1 if name.endswith("-") else 0
        return (int(name[0]), octaves, semitones)
    if name[0].isdigit():
        raise NotationError("expected a note name, found %r" % name)
    match = re.fullmatch(r"([a-g])([#b]?)(-?\d)", name)
    return 12 * (int(match.group(3)) + 1) + NOTE_CLASSES[match.group(1)] + (1 if match.group(2) == "#" else -1 if match.group(2) == "b" else 0)


def _expand_repeats(text: str) -> str:
    pattern = re.compile(r"\[([^\[\]]*)\]\*(\d+)")
    while "[" in text:
        new = pattern.sub(lambda m: " ".join([m.group(1)] * int(m.group(2))), text)
        if new == text:
            raise NotationError("unmatched [ in %r" % text[:60])
        text = new
    return text


def parse_notes(text: str, degrees: bool = False) -> tuple[list[Event], float]:
    """Notes or degrees as Events, and their total length in beats. Bar lines are checked."""
    text = re.sub(r";[^\n]*", " ", text)
    text = _expand_repeats(text)
    events: list[Event] = []
    beat, bar_start, bar_number = 0.0, 0.0, 1
    last_length, velocity, gate = 1.0, 100, 90
    pos = 0
    text = text.strip()
    while pos < len(text):
        if text[pos].isspace():
            pos += 1
            continue
        match = _TOKEN.match(text, pos)
        if not match:
            raise NotationError("can't read %r (bar %d)" % (text[pos:pos + 20], bar_number))
        pos = match.end()
        if match.group("bar"):
            if abs(beat - bar_start - BEATS_PER_BAR) > 1e-6:
                raise NotationError("bar %d is %.3g beats long, not %d: ...%s" % (
                    bar_number, beat - bar_start, BEATS_PER_BAR, text[max(0, match.start() - 60):match.start()]))
            bar_start, bar_number = beat, bar_number + 1
        elif match.group("set"):
            if match.group("key") == "v":
                velocity = int(match.group("value"))
            else:
                gate = int(match.group("value"))
        elif match.group("rest"):
            last_length = _length(match.group("rlen") or "", last_length)
            beat += last_length
        else:
            mods = match.group("gmods") if match.group("group") else match.group("mods")
            if match.group("group"):
                names = match.group("inner").split()
                last_length = _length(match.group("glen") or "", last_length)
            else:
                names = [match.group("name")]
                last_length = _length(match.group("len") or "", last_length)
            loud = velocity / 127.0
            if "!" in mods:
                loud = min(1.0, loud + 0.2)
            if "_" in mods:
                loud *= 0.6
            sounding = 0.45 if "^" in mods else gate / 100.0
            events.append(Event(beat, last_length, [_pitch(n, degrees) for n in names], loud, sounding, "~" in mods))
            beat += last_length
    if abs(beat - bar_start) > 1e-6 and abs(beat - bar_start - BEATS_PER_BAR) > 1e-6:
        raise NotationError("the last bar (%d) is %.3g beats long" % (bar_number, beat - bar_start))
    if abs(beat / BEATS_PER_BAR - round(beat / BEATS_PER_BAR)) > 1e-6:
        raise NotationError("%.3g beats isn't a whole number of bars" % beat)
    return events, beat


def degree_pitch(spec: tuple[int, int, int], chord: Chord, key: tuple[int, tuple[int, ...]], low: int, slash: bool) -> int:
    """The MIDI note for a degree over `chord`, with degree 1 the lowest note at or above `low`."""
    degree, octaves, semitones = spec
    base_class = chord.bass if slash else chord.root
    base = low + (base_class - low) % 12
    if degree in (1, 8):
        pitch = base + (12 if degree == 8 else 0)
    else:
        if degree == 3:
            interval = chord.interval((3, 4)) or chord.interval((5, 2)) or 4
        elif degree == 5:
            interval = chord.interval((7, 6, 8)) or 7
        elif degree == 7:
            interval = chord.interval((10, 11, 9))
            if interval is None:  # A triad: the seventh the key has above this root.
                tonic, scale = key
                in_key = {(tonic + s) % 12 for s in scale}
                interval = 11 if (chord.root + 11) % 12 in in_key else 10
        elif degree == 2:
            interval = 2
        elif degree == 4:
            interval = 5
        elif degree == 6:
            interval = 8 if chord.interval((6,)) is not None else 9
        else:
            raise NotationError("degree %d isn't one of 1-8" % degree)
        pitch_class_wanted = (chord.root + interval) % 12
        pitch = base + (pitch_class_wanted - base_class) % 12
    return pitch + 12 * octaves + semitones


def parse_grid(text: str, steps_per_bar: int = 16) -> tuple[list[tuple[int, str, int]], int]:
    """A grid as (step, kind, steps held), and its length in steps."""
    cells = [c for c in text if c in "xXo.-"]
    hits = []
    for i, c in enumerate(cells):
        if c in "xXo":
            held = 1
            while i + held < len(cells) and cells[i + held] == "-":
                held += 1
            hits.append((i, c, held))
    if len(cells) % steps_per_bar:
        raise NotationError("grid of %d steps isn't a whole number of bars: %r" % (len(cells), text))
    return hits, len(cells)


GRID_VELOCITY = {"x": 0.78, "X": 1.0, "o": 0.42}


# --- Parts -----------------------------------------------------------------------------------

@dataclass
class Notes:
    """A line of notes (or degrees) for one instrument, repeated to fill its section."""
    instrument: object
    text: str
    degrees: bool = False
    low: int = 40  # for degrees: degree 1 is the lowest note at or above this MIDI note
    slash: bool = True  # for degrees: 1 is the chord's slash bass note rather than its root
    transpose: int = 0


@dataclass
class Comp:
    """Chords voiced from the section's chord symbols, struck on a grid."""
    instrument: object
    grid: str
    low: int = 57
    high: int = 76
    voices: int = 3


@dataclass
class Pad:
    """The section's chords held for as long as each lasts."""
    instrument: object
    low: int = 53
    high: int = 74
    voices: int = 4
    velocity: float = 0.7


@dataclass
class Drums:
    """Drum grids, one row per kit piece, repeated to fill the section. `fill` rows replace
    theirs in the last bar of every `fill_every` bars; `crash` hits the crash cymbal on the
    section's first beat."""
    kit: dict
    rows: dict
    fill: dict | None = None
    fill_every: int = 8
    crash: bool = False


def melody(instrument, text: str, transpose: int = 0) -> Notes:
    return Notes(instrument, text, transpose=transpose)


def bass(instrument, text: str, low: int = 28) -> Notes:
    return Notes(instrument, text, degrees=True, low=low, slash=True)


def arp(instrument, text: str, low: int = 72) -> Notes:
    return Notes(instrument, text, degrees=True, low=low, slash=False)


# --- Songs -----------------------------------------------------------------------------------

@dataclass
class Section:
    name: str
    bars: int
    chords: list
    parts: dict


@dataclass
class Rendered:
    audio: np.ndarray  # stereo
    loop_start: float  # seconds; 0 with no loop
    loops: bool
    report: list = field(default_factory=list)


class Song:
    """A piece of music: sections of chords and parts, played as an intro then a loop."""

    def __init__(self, name: str, tempo: float, key: str = "C major", swing: float = 0.0,
                 loudness: float = -17.0, reverb: float = 1.6, echo_beats: float = 0.75, eq: float = 0.6):
        self.name = name
        self.tempo = tempo
        self.key = parse_key(key)
        self.swing = swing  # how late the off-beat sixteenths fall, as a share of a sixteenth
        self.loudness = loudness  # LUFS the finished track is set to
        self.reverb = reverb  # seconds the room rings for
        self.echo_beats = echo_beats  # echo delay, in beats
        self.eq = eq  # how far the master EQ moves the mix toward a typical pop balance (0 to 1)
        self.sections: dict[str, Section] = {}

    def section(self, name: str, chords: str | None = None, bars: int | None = None, **parts) -> Section:
        parsed = parse_chords(chords) if chords else []
        if bars is None:
            if not parsed:
                raise NotationError("section %s needs chords or a number of bars" % name)
            bars = int(round((parsed[-1][0] + parsed[-1][1]) / BEATS_PER_BAR))
        section = Section(name, bars, parsed, parts)
        self.sections[name] = section
        return section

    # --- Events ---------------------------------------------------------------------------

    def _events(self, section: Section) -> dict:
        """Every note in a section as {instrument: [Event with MIDI pitches]}, beats from its start."""
        out: dict = {}
        total = section.bars * BEATS_PER_BAR
        for part_name, part in section.parts.items():
            if part is None:
                continue
            notes: list[Event] = []
            if isinstance(part, Notes):
                events, length = parse_notes(part.text, part.degrees)
                if part.degrees and not section.chords:
                    raise NotationError("%s/%s uses degrees but the section has no chords" % (section.name, part_name))
                offset = 0.0
                while offset < total - 1e-6:
                    for e in events:
                        beat = e.beat + offset
                        if beat >= total - 1e-6:
                            break
                        if part.degrees:
                            chord = chord_at(section.chords, beat)
                            pitches = [degree_pitch(p, chord, self.key, part.low, part.slash) for p in e.pitches]
                        else:
                            pitches = [p + part.transpose for p in e.pitches]
                        notes.append(Event(beat, min(e.length, total - beat), pitches, e.velocity, e.gate, e.slide))
                    offset += length
                out.setdefault(part.instrument, []).extend(notes)
            elif isinstance(part, Comp):
                hits, steps = parse_grid(part.grid)
                previous = None
                for bar_step in range(0, section.bars * 16, steps):
                    for step, kind, held in hits:
                        at = bar_step + step
                        if at >= section.bars * 16:
                            break
                        beat = at / 4.0
                        voicing = voice_chord(chord_at(section.chords, beat), part.low, part.high, part.voices, previous)
                        previous = voicing
                        notes.append(Event(beat, held / 4.0, voicing, GRID_VELOCITY[kind], 0.9))
                out.setdefault(part.instrument, []).extend(notes)
            elif isinstance(part, Pad):
                previous = None
                for start, length, chord in section.chords:
                    voicing = voice_chord(chord, part.low, part.high, part.voices, previous)
                    previous = voicing
                    notes.append(Event(start, length, voicing, part.velocity, 0.98))
                out.setdefault(part.instrument, []).extend(notes)
            elif isinstance(part, Drums):
                def is_fill_bar(bar: int) -> bool:
                    # Every fill_every-th bar, and the last bar of a section shorter than that.
                    return (bar + 1) % part.fill_every == 0 or (bar == section.bars - 1 and section.bars < part.fill_every)

                fills = part.fill or {}
                for row in list(part.rows) + [r for r in fills if r not in part.rows]:
                    piece = part.kit[row]
                    groove, steps = parse_grid(part.rows[row]) if row in part.rows else ([], 16)
                    fill, fill_steps = parse_grid(fills[row]) if row in fills else (None, 16)
                    if fill_steps != 16:
                        raise NotationError("fills are one bar long (%s)" % row)
                    for bar in range(section.bars):
                        if fill is not None and is_fill_bar(bar):
                            hits = [(bar * 16 + s, k) for s, k, _ in fill]
                        else:
                            first = bar * 16
                            offset = first % steps
                            hits = [(first + s - offset, k) for s, k, _ in groove if offset <= s < offset + 16]
                        for at, kind in hits:
                            out.setdefault(piece, []).append(Event(at / 4.0, 0.25, [], GRID_VELOCITY[kind], 1.0))
                if part.crash and "crash" in part.kit:
                    out.setdefault(part.kit["crash"], []).append(Event(0.0, 1.0, [], 0.9, 1.0))
            else:
                raise NotationError("unknown part %r" % (part,))
        return out

    # --- Rendering ------------------------------------------------------------------------

    def _seconds(self, beat: float, tempo_scale: float) -> float:
        sixteenths = beat * 4.0
        if self.swing and abs(sixteenths - round(sixteenths)) < 1e-6 and round(sixteenths) % 2 == 1:
            beat += self.swing / 4.0
        return beat * 60.0 / (self.tempo * tempo_scale)

    def render(self, intro: list[str], loop: list[str] | None, tempo_scale: float = 1.0) -> Rendered:
        """The song as stereo audio: the intro sections, then the loop sections, which repeat
        seamlessly from Rendered.loop_start when `loop` is given. With no loop the track ends."""
        order = list(intro)
        if loop:
            order += list(loop) * 2 + [loop[0]]  # A second pass and a bit, for seamless tails.
        beat_seconds = 60.0 / (self.tempo * tempo_scale)
        # Sections start on whole samples, so both passes of the loop line up exactly.
        starts, at = [], 0
        for name in order:
            starts.append(at)
            at += synth.n_samples(self.sections[name].bars * BEATS_PER_BAR * beat_seconds)
        n = at + synth.n_samples(self.reverb + 2.0)
        dry = np.zeros((2, n), dtype=np.float32)
        reverb_send = np.zeros((2, n), dtype=np.float32)
        echo_send = np.zeros((2, n), dtype=np.float32)
        by_instrument: dict = {}
        for name, start in zip(order, starts):
            for instrument, events in self._events(self.sections[name]).items():
                by_instrument.setdefault(instrument, []).append((name, start, events))
        report = []
        for instrument, batches in by_instrument.items():
            track = np.zeros((2, n), dtype=np.float32)
            for section_name, section_start, events in batches:
                def sample_of(beat: float, start: int = section_start) -> int:
                    return start + synth.n_samples(self._seconds(beat, tempo_scale))
                instrument.play(track, events, sample_of, beat_seconds, section_name)
            track = instrument.finish(track)
            dry += track
            if instrument.reverb:
                reverb_send += track * instrument.reverb
            if instrument.echo:
                echo_send += track * instrument.echo
            report.append((instrument.name, synth.lufs(track), synth.peak_db(track)))
        echoes = synth.echo(echo_send, self.echo_beats * beat_seconds, 0.38).astype(np.float32)
        reverb_send += echoes * 0.5
        wet = synth.convolve(reverb_send, synth.reverb_ir(self.reverb, 7)).astype(np.float32)
        mix = (dry + echoes + wet).astype(np.float64)
        mix_loudness = synth.lufs(mix[:, :at])
        report = ["  %-14s %6.1f LU  (peak %5.1f dB)" % (name, level - mix_loudness, peak) for name, level, peak in report]
        mix = synth.filt(mix, "highpass", 28.0)
        mix, eq = synth.match_eq(mix[:, :n], self.eq)
        report.append("  master EQ " + " ".join("%+.1f" % g for g in eq))
        # Even out the level, then glue the mix together with gentle compression.
        mix *= synth.db(-20.0 - synth.lufs(mix[:, :at]))
        mix = synth.compress(mix, -16.0, 2.0, 0.01, 0.2)
        if loop:
            intro_end = starts[len(intro)]
            loop_len = starts[len(intro) + len(loop)] - intro_end
            cross = synth.n_samples(0.05)
            a = mix[:, intro_end:intro_end + cross]
            b = mix[:, intro_end + loop_len:intro_end + loop_len + cross]
            w = np.sin(np.linspace(0.0, math.pi / 2.0, cross)) ** 2
            out = np.concatenate([mix[:, :intro_end], a * (1.0 - w) + b * w,
                                  mix[:, intro_end + loop_len + cross:intro_end + 2 * loop_len + cross]], axis=1)
            loop_start = (intro_end + cross) / RATE
            body = out[:, intro_end + cross:]
        else:
            out = synth.trim_silence(mix, -70.0, 0.05)
            loop_start = 0.0
            body = out
        gain = synth.db(self.loudness - synth.lufs(body))
        out = synth.limit(out * gain, -1.0)
        if not loop:
            out = synth.fade(out, 0.0, 0.03)
        report.append("  loudness %.1f LUFS, peak %.1f dB, %.1f s%s" % (
            synth.lufs(body * gain), synth.peak_db(out), out.shape[1] / RATE,
            ", loops from %.3f s" % loop_start if loop else ""))
        return Rendered(out, loop_start, bool(loop), report)

    # --- Checks ---------------------------------------------------------------------------

    def harmony_report(self) -> list[str]:
        """Melody notes on the beat that aren't in the chord playing then, for a composer to
        check by eye: some are passing notes on purpose, others are mistakes."""
        tonic, scale = self.key
        in_key = {(tonic + s) % 12 for s in scale}
        lines = []
        for section in self.sections.values():
            if not section.chords:
                continue
            for part_name, part in section.parts.items():
                if not isinstance(part, Notes) or part.degrees:
                    continue
                events, _ = parse_notes(part.text)
                for e in events:
                    if e.beat >= section.bars * BEATS_PER_BAR or abs(e.beat - round(e.beat)) > 1e-6:
                        continue
                    chord = chord_at(section.chords, e.beat)
                    for p in e.pitches:
                        pc = (p + part.transpose) % 12
                        if pc not in chord.classes():
                            name = "c c# d eb e f f# g ab a bb b".split()[pc]
                            where = "out of key" if pc not in in_key else "not in chord"
                            lines.append("  %s/%s bar %d beat %d: %s over %s (%s)" % (
                                section.name, part_name, int(e.beat // 4) + 1, int(e.beat % 4) + 1, name, chord.symbol, where))
        return lines
