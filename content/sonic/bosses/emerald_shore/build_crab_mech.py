"""Builds the models for Emerald Shore's boss: the crab mech (crab_mech.glb) and Eggman's ship
(egg_ship.glb). Both dress the placeholder shapes of crab_mech.tscn, whose layout is in
crab_mech.parts.json (written by tools/godot/export_parts.gd), so the boss's animations, attacks
and hit areas work unchanged: the mech's `skin` and `ship_skin` name them (see
engine/art/model_skin.gd).

Run it from the repository root (Blender 5.0 or newer), after exporting any changed layout:

    godot --headless --path . --script res://tools/godot/export_parts.gd -- res://content/sonic/bosses/emerald_shore/crab_mech.tscn content/sonic/bosses/emerald_shore/crab_mech.parts.json
    blender --background --factory-startup --python content/sonic/bosses/emerald_shore/build_crab_mech.py
"""

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.append(os.path.join(HERE, "..", "..", "..", "..", "tools", "blender"))

import art_kit  # noqa: E402
from art_kit import Parts, define_material, lathe, paint, rounded_slab, sphere, tube  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

ORANGE = paint((0.96, 0.46, 0.18))
ORANGE_DARK = paint((0.80, 0.30, 0.12))
CREAM = paint((0.98, 0.87, 0.66))
STEEL = paint((0.62, 0.65, 0.72))
STEEL_DARK = paint((0.24, 0.26, 0.31))
WHITE = paint((0.96, 0.96, 0.97))
SHIP_WHITE = paint((0.90, 0.91, 0.94))
RED = paint((0.86, 0.13, 0.10))
YELLOW = paint((1.0, 0.82, 0.18))
SKIN = paint((1.0, 0.80, 0.64))
PINK = paint((1.0, 0.66, 0.56))
BROWN = paint((0.42, 0.24, 0.10))
BLUE = paint((0.30, 0.60, 1.0))
GLOW = paint((1.0, 0.18, 0.12))
CORE = define_material("core_glow", (0.45, 0.95, 1.0))  # Library materials, tuned in Godot.
GLASS = define_material("glass", (0.7, 0.9, 1.0))
FLAME = define_material("flame", (1.0, 0.7, 0.2))


def ellipsoid(centre, radii, segments: int = 16, rings: int = 10):
    return art_kit.transformed(sphere(1.0, segments, rings), Matrix.Translation(Vector(centre)) @ Matrix.Diagonal((*radii, 1.0)))


def at(shape, position, scale=(1.0, 1.0, 1.0)):
    return art_kit.transformed(shape, Matrix.Translation(Vector(position)) @ Matrix.Diagonal((*scale, 1.0)))


def ring(centre, radius_x: float, radius_z: float, thickness: float, count: int = 40):
    points = [Vector(centre) + Vector((radius_x * math.cos(t), 0.0, radius_z * math.sin(t))) for t in (i * math.tau / count for i in range(count + 1))]
    return tube(points, [thickness] * len(points), 8, cap_end=False)


def crab_mech(parts: Parts) -> None:
    body = parts.origin("Model/Body")
    oval = (1.0, 1.0, 0.86)
    shell = lathe([(2.62, 0.0), (2.6, 0.22), (2.32, 0.52), (1.82, 0.78), (1.05, 0.93), (0.92, 0.86)], 28, cap_bottom=False, cap_top=False)
    parts.part("Model/Body/Shell").add(at(shell, body - Vector((0, 0.05, 0)), oval), ORANGE, smooth=True)
    # Armour seams and rivets on the shell.
    for height, reach in ((0.36, 2.48), (0.66, 2.06)):
        parts.part("Model/Body/Shell").add(ring(body + Vector((0, height - 0.05, 0)), reach, reach * 0.86, 0.035), ORANGE_DARK, smooth=True)
    for k in range(14):
        angle = math.tau * k / 14
        rivet = body + Vector((2.25 * math.cos(angle), 0.4, 2.25 * 0.86 * math.sin(angle)))
        parts.part("Model/Body/Shell").add(ellipsoid(rivet, (0.06, 0.06, 0.06), 6, 4), STEEL, smooth=True)
    parts.part("Model/Body/Band").add(ring(parts.origin("Model/Body/Band"), 2.66, 2.66 * 0.86, 0.15), STEEL_DARK, smooth=True)
    belly = lathe([(0.0, -0.9), (0.95, -0.86), (1.85, -0.72), (2.42, -0.42), (2.6, -0.08)], 28, cap_bottom=False, cap_top=False)
    parts.part("Model/Body/Belly").add(at(belly, body, oval), CREAM, smooth=True)
    parts.part("Model/Body/Core").add(ellipsoid(parts.origin("Model/Body/Core"), (0.55, 0.5, 0.55), 18, 12), CORE, smooth=True)
    parts.part("Model/Body/CoreRim").add(ring(parts.origin("Model/Body/CoreRim"), 0.86, 0.86, 0.12, 28), STEEL_DARK, smooth=True)
    for side, sign in (("Left", 1), ("Right", -1)):
        plate = parts.origin(f"Model/Body/Lid{side}/Plate")
        lid = rounded_slab(0.82, 1.56, 0.2, 0.18, bevel=0.06)
        parts.part(f"Model/Body/Lid{side}/Plate").add(at(lid, plate - Vector((0, 0.1, 0))), STEEL, smooth=False)
        parts.part(f"Model/Body/Lid{side}/Plate").add(at(rounded_slab(0.6, 1.3, 0.04, 0.12), plate + Vector((0, 0.1, 0))), RED)
        eye = parts.origin(f"Model/Body/Eye{side}")
        stalk_foot = Vector((0.5 * sign, 3.25, -10.9))
        parts.part(f"Model/Body/Stalk{side}").add(tube([stalk_foot, eye - Vector((0, 0.2, 0.05))], [0.11, 0.08], 8), STEEL, smooth=True)
        parts.part(f"Model/Body/Eye{side}").add(ellipsoid(eye, (0.26, 0.26, 0.26), 14, 10), WHITE, smooth=True)
        parts.part(f"Model/Body/Eye{side}").add(ring(eye + Vector((0, 0, 0.05)), 0.27, 0.27, 0.04, 20), STEEL_DARK, smooth=True)
        pupil = parts.origin(f"Model/Body/Pupil{side}")
        parts.part(f"Model/Body/Pupil{side}").add(ellipsoid(pupil, (0.13, 0.13, 0.06), 12, 8), GLOW, smooth=True)
        # The claws: a jointed arm, a big armoured pincer and a thumb, both with pale tips.
        claw = f"Model/Body/Claw{side}"
        shoulder = parts.origin(claw)
        pincer = parts.origin(claw + "/Pincer")
        elbow = shoulder.lerp(pincer, 0.5) + Vector((0.3 * sign, 0.55, 0.0))
        parts.part(claw + "/Arm").add(tube([shoulder, elbow, pincer + Vector((0, 0.2, -0.4))], [0.32, 0.28, 0.26], 10), STEEL_DARK, smooth=True)
        parts.part(claw + "/Arm").add(ellipsoid(elbow, (0.36, 0.36, 0.36), 10, 7), STEEL, smooth=True)
        parts.part(claw + "/Pincer").add(ellipsoid(pincer, (0.62, 0.48, 0.92), 16, 10), ORANGE, smooth=True)
        parts.part(claw + "/Pincer").add(art_kit.transformed(lathe([(0.32, 0.0), (0.0, 0.6)], 10), Matrix.Translation(pincer + Vector((0.0, -0.1, 0.72))) @ Matrix.Rotation(math.pi / 2, 4, 'X')), CREAM, smooth=True)
        thumb = parts.origin(claw + "/Thumb")
        parts.part(claw + "/Thumb").add(ellipsoid(thumb, (0.3, 0.26, 0.5), 12, 8), ORANGE_DARK, smooth=True)
        parts.part(claw + "/Thumb").add(art_kit.transformed(lathe([(0.17, 0.0), (0.0, 0.34)], 8), Matrix.Translation(thumb + Vector((0.0, 0.0, 0.42))) @ Matrix.Rotation(math.pi / 2, 4, 'X')), CREAM, smooth=True)
    # Eight legs: a thick upper segment up to a knee, a thinner one down to a pointed foot.
    for i in range(8):
        leg = f"Model/Body/Legs/Leg{i}"
        hip = parts.origin(leg)
        foot = parts.origin(leg + "/Foot")
        sign = 1 if hip.x > 0 else -1
        knee = Vector((hip.x + 1.0 * sign, hip.y + 0.55, (hip.z + foot.z) / 2))
        parts.part(leg + "/Bone").add(tube([hip, knee], [0.2, 0.17], 8), STEEL_DARK, smooth=True)
        parts.part(leg + "/Bone").add(ellipsoid(knee, (0.21, 0.21, 0.21), 10, 6), STEEL, smooth=True)
        parts.part(leg + "/Bone").add(tube([knee, foot + Vector((0, 0.3, 0))], [0.15, 0.12], 8), ORANGE_DARK, smooth=True)
        parts.part(leg + "/Foot").add(art_kit.transformed(lathe([(0.0, 0.0), (0.2, 0.32), (0.16, 0.42)], 8), Matrix.Translation(foot - Vector((0, 0.02, 0)))), STEEL, smooth=True)


def egg_ship(parts: Parts) -> None:
    pod = parts.origin("Pod")
    hull = lathe([(0.0, -1.05), (0.9, -0.95), (1.42, -0.52), (1.6, 0.0), (1.56, 0.17)], 24, cap_bottom=False, cap_top=False)
    parts.part("Pod").add(at(hull, pod), SHIP_WHITE, smooth=True)
    parts.part("Pod").add(ring(pod + Vector((0, -0.25, 0)), 1.53, 1.53, 0.05, 32), RED, smooth=True)
    parts.part("Rim").add(ring(parts.origin("Rim"), 1.6, 1.6, 0.11, 32), STEEL, smooth=True)
    dome = lathe([(1.45, 0.0), (1.3, 0.72), (0.82, 1.24), (0.0, 1.42)], 20, cap_bottom=False, cap_top=False)
    parts.part("Dome").add(at(dome, pod + Vector((0, 0.17, 0))), GLASS, smooth=True)
    # Eggman: a red coat with yellow trim, a big round head, goggles, nose and moustache.
    coat = parts.origin("Coat")
    parts.part("Coat").add(ellipsoid(coat, (0.5, 0.46, 0.44), 14, 9), RED, smooth=True)
    parts.part("Coat").add(ring(coat + Vector((0, 0.12, 0)), 0.46, 0.4, 0.04, 20), YELLOW, smooth=True)
    for k in range(3):
        parts.part("Coat").add(ellipsoid(coat + Vector((0.08 if k % 2 else -0.08, 0.05 - 0.12 * k, -0.42)), (0.04,) * 3, 6, 4), YELLOW)
    head = parts.origin("Head")
    parts.part("Head").add(ellipsoid(head + Vector((0, 0.04, 0)), (0.32, 0.36, 0.32), 14, 10), SKIN, smooth=True)
    parts.part("Nose").add(ellipsoid(parts.origin("Nose"), (0.1, 0.09, 0.1), 10, 6), PINK, smooth=True)
    for side, sign in (("Left", -1), ("Right", 1)):
        start = parts.origin(f"Moustache{side}") + Vector((-0.14 * sign, 0.04, 0.0))
        curl = [start, start + Vector((0.16 * sign, -0.02, -0.02)), start + Vector((0.3 * sign, 0.02, 0.03)), start + Vector((0.36 * sign, 0.1, 0.06))]
        parts.part(f"Moustache{side}").add(tube(curl, [0.07, 0.075, 0.055, 0.03], 7), BROWN, smooth=True)
        goggle = parts.origin(f"Goggle{side}")
        parts.part(f"Goggle{side}").add(ellipsoid(goggle, (0.09, 0.09, 0.05), 10, 6), BLUE, smooth=True)
        parts.part(f"Goggle{side}").add(ring(goggle, 0.095, 0.095, 0.022, 14), STEEL_DARK, smooth=True)
    thruster = parts.origin("Thruster")
    parts.part("Thruster").add(at(lathe([(0.55, 0.22), (0.5, -0.1), (0.36, -0.22)], 16), thruster), STEEL_DARK, smooth=True)
    flame = parts.origin("Flame")
    parts.part("Flame").add(at(lathe([(0.0, -0.4), (0.3, 0.1), (0.36, 0.3)], 12, cap_bottom=False), flame), FLAME, smooth=True)
    pipe_top = parts.origin("Pump/Pipe") + Vector((0, 1.3, 0))
    nozzle = parts.origin("Pump/Nozzle")
    parts.part("Pump/Pipe").add(tube([pipe_top, nozzle + Vector((0, 0.2, 0))], [0.16, 0.16], 8), STEEL, smooth=True)
    parts.part("Pump/Nozzle").add(at(lathe([(0.3, 0.25), (0.45, -0.05), (0.42, -0.25)], 14), nozzle), YELLOW, smooth=True)


def main() -> None:
    mech = Parts(os.path.join(HERE, "crab_mech.parts.json"), root="CrabMech")
    crab_mech(mech)
    mech.export(os.path.join(HERE, "crab_mech.glb"))
    ship = Parts(os.path.join(HERE, "crab_mech.parts.json"), root="EggShip")
    egg_ship(ship)
    ship.export(os.path.join(HERE, "egg_ship.glb"))


main()
