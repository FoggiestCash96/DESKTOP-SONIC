"""Renders the game's music and sound effects into content/sonic/audio/.

    python tools/audio/render.py                  everything
    python tools/audio/render.py --music          all the music
    python tools/audio/render.py emerald_shore_1  one track (or sound) by name
    python tools/audio/render.py --sounds jump    one sound
    python tools/audio/render.py --check          check the notation and harmony without rendering

Needs Python 3.10+ with numpy and scipy, and FFmpeg (with libvorbis) on the PATH for the music.
Each track in music/ becomes music/<name>.ogg, plus <name>_fast.ogg for speed shoes when the track
sets FAST; its loop point is written into the .ogg.import file beside it. Each sound in sounds.py
becomes sounds/<name>.wav. Re-import in Godot afterwards (open the editor, or run
`godot --headless --path . --import`).
"""
from __future__ import annotations

import argparse
import importlib.util
import os
import re
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)

import synth  # noqa: E402

OUT = os.path.join(ROOT, "content", "sonic", "audio")


def load_track(name: str):
    path = os.path.join(HERE, "music", name + ".py")
    spec = importlib.util.spec_from_file_location("track_" + name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def track_names() -> list[str]:
    return sorted(f[:-3] for f in os.listdir(os.path.join(HERE, "music")) if f.endswith(".py") and not f.startswith("_"))


def set_loop(ogg_path: str, loop: bool, offset: float) -> None:
    """Writes the loop settings into the .ogg.import file Godot reads them from, creating it
    if Godot hasn't imported the file yet."""
    import_path = ogg_path + ".import"
    # Written the way Godot writes it back (the shortest form), so importing doesn't change the file.
    params = {"loop": "true" if loop else "false", "loop_offset": repr(round(offset, 6)) if loop else "0"}
    if os.path.exists(import_path):
        text = open(import_path, encoding="utf-8").read()
        for key, value in params.items():
            if re.search(r"^%s=.*$" % key, text, flags=re.M):
                text = re.sub(r"^%s=.*$" % key, "%s=%s" % (key, value), text, flags=re.M)
            else:
                text = text.rstrip("\n") + "\n%s=%s\n" % (key, value)
    else:
        text = ('[remap]\n\nimporter="oggvorbisstr"\ntype="AudioStreamOggVorbis"\n\n[params]\n\n'
                "loop=%s\nloop_offset=%s\nbpm=0\nbeat_count=0\nbar_beats=4\n" % (params["loop"], params["loop_offset"]))
    with open(import_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


def render_track(name: str, check_only: bool) -> None:
    module = load_track(name)
    song = module.song
    harmony = song.harmony_report()
    print("%s: %d sections, %d notes off the chord on the beat" % (name, len(song.sections), len(harmony)))
    for line in harmony:
        print(line)
    if check_only:
        for section in song.sections.values():
            song._events(section)  # Parses every part, so notation mistakes show up.
        return
    loop = getattr(module, "LOOP", None)
    versions = [("", 1.0)]
    if getattr(module, "FAST", None):
        versions.append(("_fast", module.FAST))
    for suffix, scale in versions:
        started = time.time()
        result = song.render(module.INTRO, loop, scale)
        path = os.path.join(OUT, "music", name + suffix + ".ogg")
        synth.write_ogg(path, result.audio)
        set_loop(path, result.loops, result.loop_start)
        print("  wrote %s in %.0f s" % (os.path.relpath(path, ROOT), time.time() - started))
        for line in result.report:
            print(line)


def render_sounds(names: list[str] | None) -> None:
    import sounds
    for name, make in sounds.SOUNDS.items():
        if names and name not in names:
            continue
        audio, loop = sounds.finish(name, make())
        path = os.path.join(OUT, "sounds", name + ".wav")
        synth.write_wav(path, audio, loop)
        print("  %-14s %5.2f s  peak %5.1f dB  %5.1f LUFS%s" % (
            name, audio.shape[-1] / synth.RATE, synth.peak_db(audio), synth.lufs(audio), "  (loops)" if loop else ""))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("names", nargs="*", help="tracks or sounds to render (default: all)")
    parser.add_argument("--music", action="store_true", help="only music")
    parser.add_argument("--sounds", action="store_true", help="only sound effects")
    parser.add_argument("--check", action="store_true", help="check the music's notation without rendering")
    args = parser.parse_args()
    import sounds
    tracks = track_names()
    wanted_tracks = [n for n in args.names if n in tracks] if args.names else tracks
    wanted_sounds = [n for n in args.names if n in sounds.SOUNDS] if args.names else None
    unknown = [n for n in args.names if n not in tracks and n not in sounds.SOUNDS]
    if unknown:
        parser.error("no track or sound called " + ", ".join(unknown))
    if not args.sounds and (wanted_tracks or not args.names):
        for name in wanted_tracks:
            render_track(name, args.check)
    if not args.music and not args.check and (wanted_sounds is None or wanted_sounds):
        render_sounds(wanted_sounds)


if __name__ == "__main__":
    main()
