"""Builds the title screen's backdrop (title_beach.glb): a grassy rock in the shallows for Sonic
to stand on, palms, sea stacks, islands on the horizon and the lighthouse, all from Emerald
Shore's kit (content/sonic/stages/emerald_shore/art/shore_kit.py). The sea and sky come from the
backdrop scene, title_backdrop.tscn.

Run it from the repository root (Blender 5.0 or newer):

    blender --background --factory-startup --python content/sonic/ui/title/art/build_title_beach.py
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "..", "..", "..", "..")
sys.path.append(os.path.join(ROOT, "tools", "blender"))
sys.path.append(os.path.join(ROOT, "content", "sonic", "stages", "emerald_shore", "art"))

import art_kit  # noqa: E402
import shore_kit as shore  # noqa: E402
from mathutils import Vector  # noqa: E402

SEA = 0.0
ROCK_TOP = 1.2  # Sonic stands in the middle of the rock's top, a little higher (see title_backdrop.gd).


def main() -> None:
    near = art_kit.Batch("beach")
    far = art_kit.Batch("horizon" + art_kit.NO_SHADOW)
    # The rock Sonic stands on, with a beach around it and palms behind him.
    rim = shore.rough_circle(6.0, 14, "title rock")
    shore.outcrop(near, Vector((0, 0, 0)), 6.0, SEA + ROCK_TOP, SEA - 3.0, "title rock", rim=rim)
    beach = [Vector((p.x * 1.35, SEA + 0.3, p.z * 1.35)) for p in rim]
    shore_line = [Vector((p.x * 1.6, SEA - 0.8, p.z * 1.6)) for p in rim]
    foot = [Vector((p.x * 1.05, SEA + 0.5, p.z * 1.05)) for p in rim]
    vertices = shore_line + beach + foot
    faces = []
    count = len(rim)
    for i in range(count):
        j = (i + 1) % count
        faces.append(art_kit._orient((i, j, count + j, count + i), vertices, Vector((0, 1, 0))))
        faces.append(art_kit._orient((count + i, count + j, 2 * count + j, 2 * count + i), vertices, Vector((0, 1, 0))))
    near.add((vertices, faces), shore.SAND)
    shore.palm(near, Vector((-4.6, ROCK_TOP + 0.1, -3.4)), 6.5, -0.7, 0.35, "title palm 1")
    shore.palm(near, Vector((3.6, ROCK_TOP + 0.2, -3.4)), 7.5, 0.6, 0.3, "title palm 2")
    shore.palm(near, Vector((-6.8, SEA - 0.4, 2.0)), 6.0, -1.2, 0.45, "title palm 3")
    shore.bush(near, Vector((-2.0, ROCK_TOP + 0.2, -3.6)), 1.2, "title bush")
    shore.bush(near, Vector((4.6, ROCK_TOP, -1.0)), 1.0, "title bush 2")
    for k, spot in enumerate((Vector((1.6, ROCK_TOP + 0.35, 1.2)), Vector((-2.8, ROCK_TOP + 0.3, -1.4)), Vector((2.6, ROCK_TOP + 0.35, -0.6)))):
        shore.flowers(near, spot, ("title flowers", k))
    for k, spot in enumerate((Vector((6.5, SEA, 4.0)), Vector((-5.5, SEA, 5.5)), Vector((7.5, SEA, -2.5)))):
        shore.rock(near, spot, 0.9 + 0.3 * k, ("title rock", k))
    # Scenery out to sea.
    shore.sea_stack(far, Vector((-26.0, SEA, -48.0)), 4.0, SEA + 14.0, SEA, "title stack 1")
    shore.sea_stack(far, Vector((30.0, SEA, -70.0)), 3.5, SEA + 9.0, SEA, "title stack 2")
    shore.sea_stack(far, Vector((-60.0, SEA, -110.0)), 5.0, SEA + 18.0, SEA, "title stack 3")
    shore.island(far, Vector((-170.0, SEA, -330.0)), 55.0, 12.0, SEA, "title island 1")
    shore.island(far, Vector((150.0, SEA, -400.0)), 45.0, 9.0, SEA, "title island 2")
    shore.island(far, Vector((-20.0, SEA, -560.0)), 70.0, 16.0, SEA, "title island 3")
    lighthouse_rock = Vector((70.0, SEA, -150.0))
    shore.outcrop(far, lighthouse_rock, 9.0, SEA + 7.0, SEA - 4.0, "title lighthouse", sides=11)
    shore.lighthouse(far, Vector((lighthouse_rock.x, SEA + 7.3, lighthouse_rock.z)), 16.0)

    art_kit.reset_scene()
    near.build()
    far.build()
    art_kit.export_glb(os.path.join(HERE, "title_beach.glb"))
    print(f"exported title_beach.glb: {near.triangles() + far.triangles()} triangles")


main()
