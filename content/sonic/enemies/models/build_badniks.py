"""Builds the models that dress Emerald Shore's badniks: Scuttler (crab), Galegull (gull),
Pearlshot (clam) and Leapfin (fish). Each is a .glb next to this file, built from the layout of the
badnik's placeholder scene (<name>.parts.json, written by tools/godot/export_parts.gd), so every part
keeps its node, and the badnik's animations, collision and script work unchanged. Each badnik scene
names its model in its `skin` (see engine/art/model_skin.gd).

Run it from the repository root (Blender 5.0 or newer), after exporting any changed layout:

    godot --headless --path . --script res://tools/godot/export_parts.gd -- res://content/sonic/enemies/scuttler.tscn content/sonic/enemies/models/scuttler.parts.json
    blender --background --factory-startup --python content/sonic/enemies/models/build_badniks.py
"""

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.append(os.path.join(HERE, "..", "..", "..", "..", "tools", "blender"))

import art_kit  # noqa: E402
from art_kit import Parts, lathe, paint, sphere, tube  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

STEEL = paint((0.66, 0.69, 0.76))
STEEL_DARK = paint((0.32, 0.34, 0.40))
RED = paint((0.93, 0.28, 0.20))
RED_DARK = paint((0.76, 0.18, 0.12))
CREAM = paint((0.98, 0.88, 0.70))
WHITE = paint((0.97, 0.97, 0.98))
BLACK = paint((0.06, 0.06, 0.08))
YELLOW = paint((1.0, 0.86, 0.20))
ORANGE = paint((1.0, 0.62, 0.15))
PURPLE = paint((0.74, 0.44, 0.78))
PURPLE_DARK = paint((0.56, 0.30, 0.62))
PINK = paint((1.0, 0.70, 0.78))
PEARL = paint((1.0, 0.96, 0.97))
BLUE = paint((0.20, 0.56, 0.92))
BLUE_DARK = paint((0.12, 0.34, 0.70))
PALE = paint((0.86, 0.93, 0.96))
GREY = paint((0.56, 0.61, 0.69))
GLOW = paint((1.0, 0.25, 0.18))


def ellipsoid(centre, radii, segments: int = 14, rings: int = 8):
    return art_kit.transformed(sphere(1.0, segments, rings), Matrix.Translation(Vector(centre)) @ Matrix.Diagonal((*radii, 1.0)))


def rod(start, end, radius: float, segments: int = 7):
    return tube([Vector(start), Vector(end)], [radius, radius], segments)


def eye(batch, centre, radius: float, look=Vector((0, 0, -1)), iris=BLACK) -> None:
    """A white eyeball with a pupil and a glint, looking along `look`."""
    centre = Vector(centre)
    batch.add(ellipsoid(centre, (radius, radius, radius), 12, 8), WHITE, smooth=True)
    batch.add(ellipsoid(centre + look * radius * 0.72, (radius * 0.5, radius * 0.5, radius * 0.4), 10, 6), iris, smooth=True)
    batch.add(ellipsoid(centre + look * radius * 0.95 + Vector((radius * 0.25, radius * 0.25, 0)), (radius * 0.14,) * 3, 6, 4), WHITE)


def flat_shape(points, thickness: float, frame: Matrix):
    """A flat shape from (x, y) points (convex, in order), `thickness` deep along its Z, placed by `frame`."""
    count = len(points)
    vertices = [Vector((x, y, thickness / 2)) for x, y in points] + [Vector((x, y, -thickness / 2)) for x, y in points]
    faces = [art_kit._orient(tuple(range(count)), vertices, Vector((0, 0, 1))),
             art_kit._orient(tuple(range(count, 2 * count)), vertices, Vector((0, 0, -1)))]
    middle = sum(vertices, Vector()) / len(vertices)
    for i in range(count):
        j = (i + 1) % count
        face = (i, j, count + j, count + i)
        side = (vertices[i] + vertices[j]) / 2 - middle
        faces.append(art_kit._orient(face, vertices, Vector((side.x, side.y, 0))))
    return art_kit.transformed((vertices, faces), frame)


def frame(origin, x, y, z) -> Matrix:
    m = Matrix((Vector(x), Vector(y), Vector(z))).transposed().to_4x4()
    m.translation = Vector(origin)
    return m


# --- Scuttler: a robot crab -----------------------------------------------------------------------

def scuttler(parts: Parts) -> None:
    body = Vector((0.0, 0.55, 0.0))
    # A domed red shell with a cream rim, rivets and a little antenna.
    shell = lathe([(0.0, 0.0), (0.98, 0.0), (1.0, 0.06), (0.9, 0.24), (0.66, 0.42), (0.34, 0.52), (0.0, 0.55)], 18, cap_bottom=False)
    parts.part("Model/Body/Shell").add(art_kit.transformed(shell, Matrix.Translation(body) @ Matrix.Diagonal((0.7, 1.0, 0.56, 1.0))), RED, smooth=True)
    for k in range(8):
        angle = math.tau * k / 8
        rivet = body + Vector((0.62 * math.cos(angle), 0.13, 0.5 * math.sin(angle)))
        parts.part("Model/Body/Shell").add(ellipsoid(rivet, (0.035,) * 3, 6, 4), STEEL, smooth=True)
    parts.part("Model/Body/Shell").add(rod(body + Vector((0, 0.5, 0.1)), body + Vector((0, 0.72, 0.18)), 0.02), STEEL_DARK)
    parts.part("Model/Body/Shell").add(ellipsoid(body + Vector((0, 0.74, 0.19)), (0.05,) * 3, 8, 5), GLOW, smooth=True)
    parts.part("Model/Body/Belly").add(ellipsoid(body + Vector((0, -0.05, 0.0)), (0.66, 0.2, 0.52), 16, 8), CREAM, smooth=True)
    band = [body + Vector((0.71 * math.cos(t), 0.0, 0.57 * math.sin(t))) for t in (i * math.tau / 32 for i in range(33))]
    parts.part("Model/Body/Band").add(tube(band, [0.045] * len(band), 6, cap_end=False), STEEL, smooth=True)
    for side, sign in (("Left", -1), ("Right", 1)):
        stalk_base = body + Vector((0.18 * sign, 0.3, -0.28))
        stalk_top = body + Vector((0.2 * sign, 0.45, -0.33))
        parts.part(f"Model/Body/Stalk{side}").add(rod(stalk_base, stalk_top, 0.035), STEEL_DARK, smooth=True)
        parts.part(f"Model/Body/Eye{side}").add(ellipsoid(parts.origin(f"Model/Body/Eye{side}"), (0.095,) * 3, 12, 8), WHITE, smooth=True)
        pupil = parts.origin(f"Model/Body/Pupil{side}")
        parts.part(f"Model/Body/Pupil{side}").add(ellipsoid(pupil, (0.05, 0.05, 0.03), 10, 6), BLACK, smooth=True)
        parts.part(f"Model/Body/Pupil{side}").add(ellipsoid(pupil + Vector((0.015, 0.018, -0.03)), (0.014,) * 3, 6, 4), WHITE)
        # Claws: an arm, a big pincer and a smaller moving thumb.
        claw = f"Model/Body/Claw{side}"
        shoulder = parts.origin(claw)
        parts.part(claw + "/Arm").add(rod(shoulder, parts.origin(claw + "/Pincer") + Vector((0, 0, 0.12)), 0.075), RED_DARK, smooth=True)
        pincer = parts.origin(claw + "/Pincer")
        parts.part(claw + "/Pincer").add(ellipsoid(pincer, (0.2, 0.15, 0.27), 14, 8), RED, smooth=True)
        parts.part(claw + "/Pincer").add(art_kit.transformed(lathe([(0.11, 0.0), (0.0, 0.2)], 8), Matrix.Translation(pincer + Vector((0.04 * sign, -0.03, -0.2))) @ Matrix.Rotation(-1.4, 4, 'X')), CREAM, smooth=True)
        thumb = parts.origin(claw + "/Thumb")
        parts.part(claw + "/Thumb").add(ellipsoid(thumb, (0.1, 0.08, 0.14), 10, 6), RED, smooth=True)
        parts.part(claw + "/Thumb").add(art_kit.transformed(lathe([(0.06, 0.0), (0.0, 0.12)], 7), Matrix.Translation(thumb + Vector((0, 0, -0.12))) @ Matrix.Rotation(-1.6, 4, 'X')), CREAM, smooth=True)
        # Legs: two segments with a knee, on steel joints, ending in points.
        for i in range(3):
            leg = f"Model/Legs{side}/Leg{i}"
            z = parts.origin(leg).z
            hip = Vector((0.55 * sign, 0.5, z))
            knee = Vector((0.92 * sign, 0.62, z + 0.04))
            foot = Vector((1.02 * sign, 0.02, z + 0.06))
            parts.part(leg).add(tube([hip, knee], [0.06, 0.05], 7), STEEL, smooth=True)
            parts.part(leg).add(ellipsoid(knee, (0.065,) * 3, 8, 5), STEEL_DARK, smooth=True)
            parts.part(leg).add(tube([knee, foot], [0.05, 0.02], 7), RED_DARK, smooth=True)


# --- Galegull: a robot gull ------------------------------------------------------------------------

def galegull(parts: Parts) -> None:
    parts.part("Model/Body").add(ellipsoid((0, 0, 0.05), (0.45, 0.4, 0.62), 16, 10), WHITE, smooth=True)
    parts.part("Model/Back").add(ellipsoid((0, 0.16, 0.12), (0.38, 0.24, 0.5), 14, 8), GREY, smooth=True)
    head = parts.origin("Model/Head")
    parts.part("Model/Head").add(ellipsoid(head, (0.24, 0.23, 0.26), 14, 9), WHITE, smooth=True)
    visor = parts.origin("Model/Visor")
    parts.part("Model/Visor").add(ellipsoid(visor + Vector((0, 0, 0.03)), (0.22, 0.07, 0.12), 14, 6), GLOW, smooth=True)
    parts.part("Model/Visor").add(ellipsoid(visor + Vector((0, 0.06, 0.05)), (0.2, 0.025, 0.1), 10, 4), STEEL_DARK, smooth=True)
    beak = parts.origin("Model/Beak")
    beak_shape = lathe([(0.085, 0.0), (0.06, 0.15), (0.0, 0.36)], 8)
    parts.part("Model/Beak").add(art_kit.transformed(beak_shape, Matrix.Translation(beak + Vector((0, 0, 0.17))) @ Matrix.Rotation(-math.pi / 2, 4, 'X')), YELLOW, smooth=True)
    tail = parts.origin("Model/Tail")
    for k, angle in enumerate((-0.35, 0.0, 0.35)):
        feather = [(0.0, -0.18), (0.09, 0.0), (0.0, 0.26), (-0.09, 0.0)]
        place = Matrix.Translation(tail + Vector((0, 0, -0.05))) @ Matrix.Rotation(angle, 4, 'Y') @ Matrix.Rotation(-math.pi / 2, 4, 'X')
        parts.part("Model/Tail").add(flat_shape(feather, 0.04, place), GREY if k != 1 else STEEL_DARK, smooth=True)
    for side, sign in (("Left", -1), ("Right", 1)):
        root = parts.origin(f"Model/Wing{side}")
        # The wing: a tapered blade with a notched trailing edge, and a dark tip.
        blade = [(0.0, -0.26), (1.02, -0.18), (1.02, 0.18), (0.75, 0.24), (0.5, 0.17), (0.25, 0.27), (0.0, 0.22)]
        place = frame(root, (sign, 0, 0), (0, 0, 1), (0, 1, 0))
        parts.part(f"Model/Wing{side}/Feathers").add(flat_shape([(x, y) for x, y in blade[:3]] + [(0.0, 0.22)], 0.05, place), GREY, smooth=True)
        parts.part(f"Model/Wing{side}/Feathers").add(flat_shape([(0.0, 0.22), (1.02, 0.18), (0.75, 0.3), (0.25, 0.3)], 0.045, place), WHITE, smooth=True)
        tip = [(1.0, -0.18), (1.45, -0.05), (1.32, 0.12), (1.0, 0.18)]
        parts.part(f"Model/Wing{side}/Tip").add(flat_shape(tip, 0.045, place), STEEL_DARK, smooth=True)


# --- Pearlshot: a clam turret ----------------------------------------------------------------------

def _scallop(radius: float, height: float, ribs: int, upward: bool):
    """A ribbed half-shell: a bowl (upward False) or a dome (True) with a scalloped rim."""
    rings = []
    steps = 6
    for i in range(steps + 1):
        t = i / steps
        y = height * math.sin(t * math.pi / 2) * (1 if upward else -1)
        ring = []
        for j in range(ribs * 4):
            angle = math.tau * j / (ribs * 4)
            rib = 1.0 + 0.06 * math.cos(angle * ribs) * (1 - t * 0.5)
            r = radius * math.cos(t * math.pi / 2) * rib
            ring.append((r * math.cos(angle), -r * math.sin(angle)))
        rings.append((ring, y))
    if not upward:
        rings = list(reversed(rings))
    vertices, faces = art_kit.loft(rings, cap_bottom=False, cap_top=False)
    return vertices, [art_kit._orient(face, vertices, sum((vertices[k] for k in face), Vector()) / len(face)) for face in faces]


def pearlshot(parts: Parts) -> None:
    base = art_kit.lathe([(0.58, 0.0), (0.58, 0.12), (0.48, 0.2)], 16)
    parts.part("Model/Base").add(base, STEEL_DARK, smooth=True)
    for k in range(6):
        angle = math.tau * k / 6
        parts.part("Model/Base").add(ellipsoid((0.5 * math.cos(angle), 0.13, 0.5 * math.sin(angle)), (0.04,) * 3, 6, 4), STEEL)
    centre = Vector((0, 0.42, 0))
    parts.part("Model/BottomShell").add(art_kit.transformed(_scallop(0.62, 0.3, 9, False), Matrix.Translation(centre)), PURPLE, smooth=True)
    parts.part("Model/Tongue").add(art_kit.transformed(lathe([(0.5, 0.0), (0.46, 0.04), (0.0, 0.06)], 16), Matrix.Translation(centre)), PINK, smooth=True)
    parts.part("Model/Pearl").add(ellipsoid(parts.origin("Model/Pearl"), (0.17,) * 3, 14, 9), PEARL, smooth=True)
    barrel_start = Vector((0, 0.52, -0.18))
    barrel_end = Vector((0, 0.52, -0.56))
    parts.part("Model/Barrel").add(rod(barrel_start, barrel_end, 0.1, 10), STEEL, smooth=True)
    parts.part("Model/Barrel").add(tube([barrel_end + Vector((0, 0, 0.02)), barrel_end - Vector((0, 0, 0.05))], [0.14, 0.14], 10), STEEL_DARK, smooth=True)
    lid_centre = Vector((0, 0.44, 0))
    parts.part("Model/Lid/TopShell").add(art_kit.transformed(_scallop(0.63, 0.32, 9, True), Matrix.Translation(lid_centre)), PURPLE_DARK, smooth=True)
    for side, sign in (("Left", -1), ("Right", 1)):
        eye(parts.part(f"Model/Lid/Eye{side}"), parts.origin(f"Model/Lid/Eye{side}"), 0.085, iris=RED_DARK)


# --- Leapfin: a robot piranha ----------------------------------------------------------------------

def leapfin(parts: Parts) -> None:
    # The body: a fish shape along Z, blunt at the head (-Z) and narrowing to the tail.
    profile = [(0.0, -0.62), (0.3, -0.5), (0.42, -0.25), (0.43, 0.05), (0.33, 0.4), (0.16, 0.72), (0.08, 0.84)]
    body = lathe([(r, z) for r, z in profile], 16, cap_bottom=False, cap_top=True)
    turn = Matrix.Rotation(math.pi / 2, 4, 'X')
    shaped = art_kit.transformed(body, Matrix.Diagonal((0.85, 1.0, 1.15, 1.0)) @ turn)
    parts.part("Model/Body").add(shaped, BLUE, smooth=True)
    parts.part("Model/Belly").add(ellipsoid((0, -0.14, -0.08), (0.3, 0.24, 0.5), 14, 8), PALE, smooth=True)
    jaw = parts.origin("Model/Jaw")
    parts.part("Model/Jaw").add(ellipsoid(jaw + Vector((0, -0.02, 0.0)), (0.2, 0.09, 0.2), 12, 6), STEEL_DARK, smooth=True)
    teeth = parts.origin("Model/Teeth")
    for k in range(5):
        x = -0.12 + 0.06 * k
        tooth = [(x - 0.028, 0.0), (x + 0.028, 0.0), (x, -0.07)]
        parts.part("Model/Teeth").add(flat_shape(tooth, 0.03, Matrix.Translation(teeth + Vector((0, 0.02, 0)))), WHITE)
        bottom = [(x - 0.028, 0.0), (x, 0.07), (x + 0.028, 0.0)]
        parts.part("Model/Teeth").add(flat_shape(bottom, 0.03, Matrix.Translation(teeth + Vector((0.03, -0.12, 0.04)))), WHITE)
    for side, sign in (("Left", -1), ("Right", 1)):
        eye(parts.part(f"Model/Eye{side}"), parts.origin(f"Model/Eye{side}"), 0.11, Vector((0.6 * sign, 0.1, -0.8)).normalized(), iris=BLACK)
        fin_root = parts.origin(f"Model/Fin{side}")
        fin = [(0.0, -0.12), (0.34, 0.0), (0.3, 0.16), (0.0, 0.12)]
        parts.part(f"Model/Fin{side}").add(flat_shape(fin, 0.035, frame(fin_root, (sign, -0.35, 0), (0, 0, 1), (0, 1, 0))), BLUE_DARK, smooth=True)
    dorsal = parts.origin("Model/Dorsal")
    spine = [(-0.0, -0.22), (0.1, -0.22), (0.38, 0.28), (0.18, 0.2)]
    parts.part("Model/Dorsal").add(flat_shape([(z, y) for y, z in spine], 0.04, frame(dorsal + Vector((0, -0.1, 0)), (0, 0, 1), (0, 1, 0), (1, 0, 0))), BLUE_DARK, smooth=True)
    tail = parts.origin("Model/Tail/TailFin")
    fork = [(0.0, -0.06), (0.26, -0.34), (0.2, 0.0), (0.26, 0.34), (0.0, 0.06)]
    parts.part("Model/Tail/TailFin").add(flat_shape(fork[:3] + [(0.0, 0.06)], 0.04, frame(tail - Vector((0, 0, 0.12)), (0, 0, 1), (0, 1, 0), (1, 0, 0))), BLUE_DARK, smooth=True)
    parts.part("Model/Tail/TailFin").add(flat_shape([(0.0, -0.06), (0.2, 0.0), (0.26, 0.34), (0.0, 0.06)], 0.04, frame(tail - Vector((0, 0, 0.12)), (0, 0, 1), (0, 1, 0), (1, 0, 0))), BLUE_DARK, smooth=True)


BADNIKS = {"scuttler": scuttler, "galegull": galegull, "pearlshot": pearlshot, "leapfin": leapfin}


def main() -> None:
    for name, build in BADNIKS.items():
        parts = Parts(os.path.join(HERE, f"{name}.parts.json"))
        build(parts)
        parts.export(os.path.join(HERE, f"{name}.glb"))


main()
