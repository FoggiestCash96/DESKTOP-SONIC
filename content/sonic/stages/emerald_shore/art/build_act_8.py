"""Builds the art for Emerald Shore Act 8 (act_8_art.glb) from its greybox (act_8.greybox.json).

Run both steps from the repository root after changing the act's greybox, then let Godot import:

    godot --headless --path . --script res://tools/godot/export_greybox.gd -- res://content/sonic/stages/emerald_shore/act_8.tscn content/sonic/stages/emerald_shore/art/act_8.greybox.json
    blender --background --factory-startup --python content/sonic/stages/emerald_shore/art/build_act_8.py

Each greybox piece is dressed by name below. A piece missing from the lists stops the build, so a
new piece can't slip into the act without art.
"""

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.append(os.path.join(HERE, "..", "..", "..", "..", "..", "tools", "blender"))
sys.path.append(HERE)

import fortress_kit as fortress  # noqa: E402
import shore_kit as shore  # noqa: E402
from art_kit import rng  # noqa: E402
from mathutils import Vector  # noqa: E402
from stage_kit import Stage  # noqa: E402

WALKWAYS = ["Causeway1", "Causeway2", "Platform", "Entrance", "ClamBlock"]
WALLS = ["WallsCauseway1Left", "WallsCauseway1Right", "WallsPlatformLeft", "WallsPlatformRight",
         "WallsEntranceLeft", "WallsEntranceRight"]
BRIDGES = ["Bridge"]
BEACH = ["ArenaFloor"]
CLIFFS = ["CliffWest", "CliffEast", "CliffSouthWest", "CliffSouthEast"]  # Around the arena, too tall to climb.
TOWERS = ["Tower1", "Tower2", "Tower3"]  # Out at sea behind the arena: scenery only.


def main() -> None:
    stage = Stage(os.path.join(HERE, "act_8.greybox.json"))
    dressed = WALKWAYS + WALLS + BRIDGES + BEACH + CLIFFS + TOWERS
    missing = sorted(set(stage.pieces) - set(dressed))
    if missing:
        sys.exit(f"build_act_8.py doesn't say how to dress: {', '.join(missing)}")
    sea = stage.sea_height
    bottom = sea - 3.0
    zones = shore.keep_out_zones(stage)

    for name in WALKWAYS + WALLS:
        fortress.walkway(stage, stage.piece(name), bottom)
    for name in WALLS:
        fortress.wall_lamps(stage, stage.piece(name))
    for name in BRIDGES:
        fortress.bridge(stage, stage.piece(name), sea)
    for name in BEACH:
        stage.ground(stage.piece(name), shore.SAND, shore.SAND_LIP, shore.SANDSTONE, bottom, lip_depth=(0.2, 0.45), seed=8)
        shore.dress_tops(stage, stage.piece(name), "sand", 1 / 120, 8)
    for name in CLIFFS:
        piece = stage.piece(name)
        stage.ground(piece, shore.GRASS, shore.GRASS_LIP, shore.SANDSTONE, bottom, seed=8)
        r = rng("cliff palms", name)
        top = max(p.y for p in piece.polygon)
        for k in range(2):
            spot = piece.world(r.uniform(-0.3, 0.3), top - piece.world(0, 0, 0).y, -piece.depth * r.uniform(0.2, 0.8))
            shore.palm(stage.batch(spot), spot, r.uniform(5.0, 7.0), r.uniform(0, math.tau), r.uniform(0.2, 0.45), (name, k))
    for name in TOWERS:
        piece = stage.piece(name)
        centre = piece.world(0.0, 0.0, -piece.depth / 2)
        fortress.tower(stage.batch(centre), Vector((centre.x, 0.0, centre.z)), sea, 34.0, 5.4, name)
    for wall in stage.data.get("walls", []):
        fortress.fence(stage, wall, stage.piece("ArenaFloor").world(0, 0, 0).y)

    shore.signs(stage, sea)
    fortress.rocks_in_sea(stage, sea, zones, 8)
    shore.scatter_scenery(stage, sea, zones, 8, stacks=10, islands=5)
    stage.export(os.path.join(HERE, "act_8_art.glb"))


main()
