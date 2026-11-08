"""Builds the art for Emerald Shore Act 5, Underground Grotto (act_5_art.glb), from its greybox
(act_5.greybox.json).

Run both steps from the repository root after changing the act's greybox, then let Godot import:

    godot --headless --path . --script res://tools/godot/export_greybox.gd -- res://content/sonic/stages/emerald_shore/act_5.tscn content/sonic/stages/emerald_shore/art/act_5.greybox.json
    blender --background --factory-startup --python content/sonic/stages/emerald_shore/art/build_act_5.py

Each greybox piece is dressed by name below. A piece missing from the lists stops the build, so a
new piece can't slip into the act without art. The cave's walls and roofs are rock, with
stalactites hanging from the roofs and glowing crystals in the walls.
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.append(os.path.join(HERE, "..", "..", "..", "..", "..", "tools", "blender"))
sys.path.append(HERE)

import shore_kit as shore  # noqa: E402
from art_kit import rng  # noqa: E402
from mathutils import Vector  # noqa: E402
from stage_kit import Stage  # noqa: E402

SAND = ["Beach"]
GRASS = ["Exit", "EndWall"]  # Out in the daylight again.
FLOORS = ["Tunnel1", "Room1", "ChasmLedge", "Tunnel2", "HallCorner", "HallFloor1", "HallStep", "HallLanding", "HallHigh",
          "HallDescent", "HallFloor2", "Tunnel3", "ShaftFloor", "ShaftLedge1", "ShaftLedge2", "HallApron"]
WALLS = ["Tunnel1WallL", "Tunnel1WallR1", "Tunnel1WallR2", "Room1Back", "Room1SideN", "Room1SideS", "Room1Lintel",
         "ChasmWallL", "ChasmWallR", "Tunnel2WallL", "Tunnel2WallR", "HallWallW", "HallWallN", "HallWallS", "HallWallE1",
         "HallWallE2", "Tunnel3WallL", "Tunnel3WallR", "ShaftWallN", "ShaftWallS", "ShaftWallW"]
ROOFS = ["Tunnel1Roof", "Room1Roof", "ChasmRoof", "Tunnel2Roof", "HallRoof", "Tunnel3Roof"]
CRYSTAL_WALLS = {"Tunnel1WallL": 1, "Tunnel2WallR": 0, "HallWallN": 1, "Tunnel3WallL": 1, "Tunnel3WallR": 0, "ShaftWallN": 1}


def main() -> None:
    stage = Stage(os.path.join(HERE, "act_5.greybox.json"))
    dressed = SAND + GRASS + FLOORS + WALLS + ROOFS
    missing = sorted(set(stage.pieces) - set(dressed))
    if missing:
        sys.exit(f"build_act_5.py doesn't say how to dress: {', '.join(missing)}")
    sea = stage.sea_height
    bottom = sea - 3.0
    zones = shore.keep_out_zones(stage)

    for name in SAND:
        stage.ground(stage.piece(name), shore.SAND, shore.SAND_LIP, shore.SANDSTONE, bottom, lip_depth=(0.2, 0.45), seed=5)
        shore.dress_tops(stage, stage.piece(name), "sand", 1 / 90, 5)
    for name in GRASS:
        stage.ground(stage.piece(name), shore.GRASS, shore.GRASS_LIP, shore.SANDSTONE, bottom, seed=5)
    shore.dress_tops(stage, stage.piece("Exit"), "grass", 1 / 45, 5)
    for i, name in enumerate(FLOORS):
        shore.cave_floor(stage, stage.piece(name), bottom, 50 + i)
    for name in WALLS + ROOFS:
        shore.cave_rock(stage, stage.piece(name))
    for name in ROOFS:
        shore.stalactites(stage, stage.piece(name), seed=5)
    for name, side in CRYSTAL_WALLS.items():
        shore.crystals(stage, stage.piece(name), side, seed=5)
    # Rocky mounds over the roofs, so the cave reads as a hill from the beach and the exit.
    r = rng("mounds", 5)
    for name in ROOFS:
        piece = stage.piece(name)
        top = max(p.y for p in piece.polygon)
        left = min(p.x for p in piece.polygon)
        right = max(p.x for p in piece.polygon)
        for k in range(max(1, int((right - left) / 14))):
            x = left + (k + r.uniform(0.2, 0.8)) * (right - left) / max(1, int((right - left) / 14))
            spot = piece.world(x, top, -piece.depth * r.uniform(0.3, 0.7))  # `top` is in the roof's own space.
            shore.outcrop(stage.batch(spot, shore.SCENERY), spot, r.uniform(5.0, 8.0), spot.y + r.uniform(1.5, 4.0), spot.y - 0.5, (name, k), sides=8)
    shore.rail_supports(stage, sea)

    shore.signs(stage, sea)
    taken = []
    for name in SAND + GRASS:
        shore.palms_by_cliffs(stage, stage.piece(name), sea, zones, taken, 5)
    shore.scatter_scenery(stage, sea, zones, 5, stacks=8, islands=5)
    stage.export(os.path.join(HERE, "act_5_art.glb"))


main()
