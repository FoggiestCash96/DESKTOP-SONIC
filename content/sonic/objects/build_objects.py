"""Builds the models that dress the engine's objects: springs, dash panels, item monitors (with an
icon for each item), checkpoints, the goal ring, the extra life, spike points and the animals freed
from badniks. Each is a .glb next to this file, built from the layout of the object's placeholder
scene (<name>.parts.json, written by tools/godot/export_parts.gd), so every part lands where the
engine expects it. engine/art/model_skin.gd explains how a model dresses an object, and
art_bank.tres is where the game looks them up.

Run it from the repository root (Blender 5.0 or newer), after exporting any changed layout:

    godot --headless --path . --script res://tools/godot/export_parts.gd -- res://engine/gimmicks/spring.tscn content/sonic/objects/spring.parts.json
    blender --background --factory-startup --python content/sonic/objects/build_objects.py
"""

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.append(os.path.join(HERE, "..", "..", "..", "tools", "blender"))

import art_kit  # noqa: E402
from art_kit import Parts, lathe, paint, rounded_slab, sphere, star_prism, tube  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

STEEL_DARK = paint((0.30, 0.32, 0.37))
STEEL = paint((0.70, 0.72, 0.78))
CHROME = paint((0.86, 0.88, 0.92))
WHITE = paint((0.97, 0.97, 0.97))
BLACK = paint((0.08, 0.08, 0.10))
YELLOW = paint((1.0, 0.82, 0.16))
GOLD = paint((1.0, 0.76, 0.18))
GOLD_DEEP = paint((0.86, 0.46, 0.08))
RED = paint((0.88, 0.14, 0.12))
RED_LIGHT = paint((1.0, 0.34, 0.26))
BLUE = paint((0.14, 0.36, 0.92))
NAVY = paint((0.10, 0.16, 0.44))
SKY = paint((0.45, 0.75, 1.0))
CYAN = paint((0.30, 0.92, 1.0))
GREEN = paint((0.32, 0.92, 0.42))
CREAM = paint((0.97, 0.95, 0.88))
ORANGE = paint((1.0, 0.62, 0.16))
BIRD_BLUE = paint((0.25, 0.55, 1.0))
GOAL_DISC = "goal_disc"  # A library material: see-through, showing the vertex colours, from both sides.


def at(shape, position, yaw: float = 0.0, scale=1.0, tilt=(0.0, 0.0)):
    return art_kit.transformed(shape, art_kit.placement(position, yaw, scale, tilt))


def facing_z(shape, position, back: bool = False):
    """A shape modelled lying flat (facing +Y) stood up to face +Z, or -Z for the back of something."""
    turn = Matrix.Rotation(math.pi if back else 0.0, 4, 'Y') @ Matrix.Rotation(math.pi / 2, 4, 'X')
    return art_kit.transformed(shape, Matrix.Translation(Vector(position)) @ turn)


def flat(points, y: float):
    """A flat polygon facing up, from (x, z) points in any order around its middle."""
    vertices = [Vector((x, y, z)) for x, z in points]
    return vertices, [art_kit._orient(tuple(range(len(vertices))), vertices, Vector((0, 1, 0)))]


def bands(batch, colours, radius: float, bottom: float, top: float, count: int, segments: int = 10) -> None:
    """A pole in stripes of alternating colours."""
    for i in range(count):
        y0 = bottom + (top - bottom) * i / count
        y1 = bottom + (top - bottom) * (i + 1) / count
        batch.add(lathe([(radius, y0), (radius, y1)], segments, cap_bottom=i == 0, cap_top=i == count - 1),
                  colours[i % len(colours)], smooth=True)


# --- The objects ---------------------------------------------------------------------------------

def spring(parts: Parts) -> None:
    base = parts.part("Base")
    base.add(rounded_slab(1.0, 1.0, 0.18, 0.14, bevel=0.04), STEEL_DARK)
    for sx in (-1, 1):
        for sz in (-1, 1):
            base.add(at(art_kit.cylinder(0.05, 0.03, 6), (0.36 * sx, 0.18, 0.36 * sz)), CHROME, smooth=True)
    turns = 3
    helix = [Vector((0.24 * math.cos(t), 0.19 + 0.12 * t / (math.tau * turns), -0.24 * math.sin(t)))
             for t in (i * math.tau * turns / 54 for i in range(55))]
    parts.part("Coil").add(tube(helix, [0.035] * len(helix), 6), CHROME, smooth=True)
    parts.part("Pad").add(at(rounded_slab(0.9, 0.9, 0.12, 0.16, bevel=0.035), (0, 0.32, 0)), YELLOW)


def dash_panel(parts: Parts) -> None:
    plate = parts.part("Plate")
    plate.add(rounded_slab(2.0, 3.0, 0.045, 0.25, bevel=0.015), STEEL_DARK)
    plate.add(rounded_slab(1.72, 2.72, 0.05, 0.18), BLUE)
    for name, z in (("Arrow1", 0.6), ("Arrow2", -0.5)):
        right = [(0.0, z - 0.42), (0.58, z + 0.16), (0.58, z + 0.44), (0.0, z - 0.12)]
        for arm in (right, [(-x, zz) for x, zz in right]):
            parts.part(name).add(flat(arm, 0.056), YELLOW)


def _icon_shapes():
    """Each item's icon as shapes facing +Z around the origin, about 0.3 m across, with the colours
    they'd have on their own (the monitors draw them all in white)."""
    ring = [Vector((0.12 * math.cos(t), 0.12 * math.sin(t), 0.0)) for t in (i * math.tau / 16 for i in range(17))]
    shoe_upper = [(-0.15, -0.04), (0.15, -0.04), (0.15, 0.0), (0.04, 0.04), (-0.06, 0.12), (-0.15, 0.12)]
    bolt_top = [(0.0, -0.01), (0.07, -0.01), (0.13, 0.16), (0.06, 0.16)]
    bolt_bottom = [(-0.03, 0.02), (0.05, 0.02), (-0.05, -0.16), (-0.11, -0.16)]
    arc = [Vector((0.1 * math.cos(t), -0.02 - 0.1 * math.sin(t), 0.0)) for t in (i * math.pi / 10 for i in range(11))]
    magnet = [Vector((0.1, 0.12, 0.0))] + arc + [Vector((-0.1, 0.12, 0.0))]
    return {
        "IconRings": [(tube(ring, [0.032] * len(ring), 6, cap_end=False), GOLD)],
        "IconShield": [(facing_z(art_kit.cylinder(0.14, 0.012, 16), (0, 0, 0)), SKY),
                       (facing_z(art_kit.cylinder(0.05, 0.016, 8), (0.05, 0.05, 0.002)), WHITE)],
        "IconSpeedShoes": [(facing_z(flat(shoe_upper, 0.0), (0, 0, 0)), RED),
                           (facing_z(flat([(-0.16, -0.1), (0.17, -0.1), (0.17, -0.04), (-0.16, -0.04)], 0.0), (0, 0, 0)), WHITE),
                           (facing_z(flat([(-0.04, 0.0), (0.03, -0.04), (0.08, -0.04), (0.0, 0.03)], 0.002), (0, 0, 0)), WHITE)],
        "IconInvincibility": [(star_prism(5, 0.15, 0.065, 0.02), YELLOW)],
        "IconMagnet": [(tube(magnet, [0.035] * len(magnet), 6), RED),
                       (at(art_kit.box((0.075, 0.05, 0.075)), (0.1, 0.13, 0)), CHROME),
                       (at(art_kit.box((0.075, 0.05, 0.075)), (-0.1, 0.13, 0)), CHROME)],
        "IconBoost": [(facing_z(flat(bolt_top, 0.0), (0, 0, 0)), CYAN), (facing_z(flat(bolt_bottom, 0.0), (0, 0, 0)), CYAN)],
    }


def item_monitor(parts: Parts) -> None:
    parts.part("Base").add(rounded_slab(0.95, 0.95, 0.08, 0.1, bevel=0.02), STEEL_DARK)
    case = parts.part("Box/Case")
    case.add(at(rounded_slab(0.9, 0.9, 0.82, 0.12, bevel=0.06), (0, 0.04, 0)), STEEL)
    screen = parts.part("Box/Screen")
    for back in (False, True):
        side = -1 if back else 1
        # Stood up, a slab's thickness points out of the box: the screen's face ends at 0.462,
        # behind the icons at 0.475.
        case.add(facing_z(rounded_slab(0.74, 0.54, 0.02, 0.07), (0, 0.5, side * 0.436), back), BLACK)
        screen.add(facing_z(rounded_slab(0.62, 0.42, 0.02, 0.05), (0, 0.5, side * 0.442), back), WHITE)
    # Icons in white with a dark outline, so they read on every screen colour.
    outline = Matrix.Translation((0, 0, -0.006)) @ Matrix.Diagonal((1.25, 1.25, 0.5, 1.0))
    for name, shapes in _icon_shapes().items():
        for back in (False, True):
            turn = Matrix.Translation((0, 0.5, -0.475 if back else 0.475)) @ Matrix.Rotation(math.pi if back else 0.0, 4, 'Y')
            for shape, _colour in shapes:
                parts.part("Box/" + name).add(art_kit.transformed(shape, turn), WHITE, smooth=True)
                parts.part("Box/" + name).add(art_kit.transformed(shape, turn @ outline), BLACK, smooth=True)


def checkpoint(parts: Parts) -> None:
    parts.part("Foot").add(lathe([(0.3, 0.0), (0.3, 0.06), (0.2, 0.12)], 12), STEEL_DARK, smooth=True)
    bands(parts.part("Pole"), [NAVY, WHITE], 0.055, 0.1, 1.66, 8)
    cap = parts.part("Head/Cap")
    cap.add(lathe([(0.1, 1.64), (0.11, 1.76), (0.05, 1.84)], 10), STEEL, smooth=True)
    cap.add(tube([Vector((0.0, 1.75, 0.0)), Vector((0.17, 1.75, 0.0))], [0.03, 0.03], 6), CHROME, smooth=True)
    parts.part("Head/Lamp").add(at(sphere(0.14, 12, 8), (0.2, 1.75, 0.0)), WHITE, smooth=True)


def goal(parts: Parts) -> None:
    """The giant ring at the end of an act: a gold band with a darker rim on its inside, a disc of
    colour shading from red-orange at the edge through green to blue in the middle (seen through,
    from the library's goal_disc material), and a red star that turns in the middle."""
    middle = parts.origin("Ring")
    circle = [middle + Vector((math.cos(t), math.sin(t), 0.0)) for t in (i * math.tau / 64 for i in range(65))]
    band = parts.part("Ring/Band")
    band.add(tube([middle + (p - middle) * 2.7 for p in circle], [0.3] * len(circle), 14, cap_end=False), GOLD, smooth=True)
    band.add(tube([middle + (p - middle) * 2.42 for p in circle], [0.11] * len(circle), 8, cap_end=False), GOLD_DEEP, smooth=True)
    # The disc: rings of vertices from the middle out, each with its colour.
    stops = [(0.0, (0.12, 0.30, 0.95)), (0.45, (0.20, 0.55, 1.0)), (0.70, (0.15, 0.85, 0.70)), (0.86, (0.75, 0.95, 0.30)),
             (0.95, (1.0, 0.60, 0.15)), (1.0, (0.95, 0.30, 0.15))]
    segments = 64
    vertices, colours, faces = [middle.copy()], [stops[0][1]], []
    for fraction, colour in stops[1:]:
        for i in range(segments):
            angle = math.tau * i / segments
            vertices.append(middle + Vector((math.cos(angle), math.sin(angle), 0.0)) * 2.45 * fraction)
            colours.append(colour)
    for ring in range(len(stops) - 1):
        for i in range(segments):
            j = (i + 1) % segments
            outer_i, outer_j = 1 + ring * segments + i, 1 + ring * segments + j
            if ring == 0:
                faces.append((0, outer_i, outer_j))
            else:
                inner_i, inner_j = outer_i - segments, outer_j - segments
                faces.append((inner_i, outer_i, outer_j, inner_j))
    parts.part("Ring/Disc").add((vertices, faces), GOAL_DISC, colour=colours)
    star = parts.part("Ring/Emblem/Star")
    star.add(at(star_prism(5, 1.05, 0.45, 0.26), parts.origin("Ring/Emblem")), RED, smooth=False)
    star.add(at(star_prism(5, 0.78, 0.33, 0.30), parts.origin("Ring/Emblem")), RED_LIGHT, smooth=False)


def extra_life(parts: Parts) -> None:
    orb = parts.part("Orb")
    orb.add(sphere(0.35, 16, 10), GREEN, smooth=True)
    ring = [Vector((0.48 * math.cos(t), 0.0, 0.48 * math.sin(t))) for t in (i * math.tau / 24 for i in range(25))]
    orb.add(art_kit.transformed(tube(ring, [0.04] * len(ring), 6, cap_end=False), Matrix.Rotation(0.4, 4, 'X')), GOLD, smooth=True)


def spikes(parts: Parts) -> None:
    parts.part("Points").add(lathe([(0.17, -0.25), (0.0, 0.25)], 8), CHROME, smooth=True)


def animal(parts: Parts) -> None:
    parts.part("Body").add(at(sphere(0.18, 12, 8), (0.0, 0.2, 0.0), scale=(1.0, 1.05, 1.15)), BIRD_BLUE, smooth=True)
    parts.part("Belly").add(at(sphere(0.13, 10, 6), (0.0, 0.17, -0.08), scale=(1.0, 1.0, 0.6)), CREAM, smooth=True)
    parts.part("Head").add(at(sphere(0.12, 12, 8), (0.0, 0.42, -0.06)), BIRD_BLUE, smooth=True)
    beak = lathe([(0.045, 0.0), (0.0, 0.12)], 6)
    parts.part("Beak").add(art_kit.transformed(beak, Matrix.Translation((0.0, 0.41, -0.16)) @ Matrix.Rotation(-math.pi / 2, 4, 'X')), ORANGE, smooth=True)
    for name, x in (("EyeLeft", -0.06), ("EyeRight", 0.06)):
        parts.part(name).add(at(sphere(0.028, 8, 5), (x, 0.46, -0.15)), BLACK, smooth=True)
        parts.part(name).add(at(sphere(0.01, 6, 3), (x + 0.008, 0.47, -0.175)), WHITE)
    for name, x in (("WingLeft", -0.18), ("WingRight", 0.18)):
        parts.part(name).add(at(sphere(0.1, 8, 5), (x, 0.22, 0.03), scale=(0.25, 0.75, 1.1)), BIRD_BLUE, smooth=True)


OBJECTS = {
    "spring": spring,
    "dash_panel": dash_panel,
    "item_monitor": item_monitor,
    "checkpoint": checkpoint,
    "goal": goal,
    "extra_life": extra_life,
    "spikes": spikes,
    "animal": animal,
}


def main() -> None:
    for name, build in OBJECTS.items():
        parts = Parts(os.path.join(HERE, f"{name}.parts.json"))
        build(parts)
        parts.export(os.path.join(HERE, f"{name}.glb"))


main()
