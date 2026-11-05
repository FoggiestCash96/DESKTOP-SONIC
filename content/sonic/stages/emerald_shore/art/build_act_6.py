"""Builds the art for Emerald Shore Act 6, Tidal Cavern (act_6_art.glb), from its greybox
(act_6.greybox.json).

Run both steps from the repository root after changing the act's greybox, then let Godot import:

    godot --headless --path . --script res://tools/godot/export_greybox.gd -- res://content/sonic/stages/emerald_shore/act_6.tscn content/sonic/stages/emerald_shore/art/act_6.greybox.json
    blender --background --factory-startup --python content/sonic/stages/emerald_shore/art/build_act_6.py

Each greybox piece is dressed by name below. A piece missing from the lists stops the build, so a
new piece can't slip into the act without art. The tides are the act's water volumes, which draw
their own surfaces in the game; the high ledges are rock shelves along the cavern walls.
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.append(os.path.join(HERE, "..", "..", "..", "..", "..", "tools", "blender"))
sys.path.append(HERE)

import shore_kit as shore  # noqa: E402
from art_kit import rng  # noqa: E402
from stage_kit import Stage  # noqa: E402

SAND = ["Beach", "EntryRamp"]
GRASS = ["Exit", "EndWall"]
FLOORS = ["LowFloor1", "LowRamp1", "Midpoint", "EntryRamp2", "LowFloor2", "LowRamp2", "Nook", "PoolFloor"]
LEDGES = ["HighLedge1", "HighLedge2", "HighLedge3", "HighLedge4", "HighLedge5", "HighLedge6", "PoolLedge"]
WALLS = ["CaveWallL1", "CaveWallR1", "MidWallW", "MidWallN", "MidWallE", "MidWallNE", "NookBack", "NookSideW", "NookSideE",
         "CaveWallN2a", "CaveWallN2b", "CaveWallN2d", "CaveWallN2c", "CaveWallS2", "PoolWallN", "PoolWallS"]
ROOFS = ["CaveRoof1", "MidRoof", "NookRoof", "CaveRoof2", "PoolRoof"]
CRYSTAL_WALLS = {"CaveWallR1": 1, "CaveWallS2": 1, "PoolWallS": 1, "MidWallW": 0}


def main() -> None:
    stage = Stage(os.path.join(HERE, "act_6.greybox.json"))
    dressed = SAND + GRASS + FLOORS + LEDGES + WALLS + ROOFS
    missing = sorted(set(stage.pieces) - set(dressed))
    if missing:
        sys.exit(f"build_act_6.py doesn't say how to dress: {', '.join(missing)}")
    sea = stage.sea_height
    bottom = sea - 3.0
    zones = shore.keep_out_zones(stage)

    for name in SAND:
        stage.ground(stage.piece(name), shore.SAND, shore.SAND_LIP, shore.SANDSTONE, bottom, lip_depth=(0.2, 0.45), seed=6)
        shore.dress_tops(stage, stage.piece(name), "sand", 1 / 90, 6)
    for name in GRASS:
        stage.ground(stage.piece(name), shore.GRASS, shore.GRASS_LIP, shore.SANDSTONE, bottom, seed=6)
    shore.dress_tops(stage, stage.piece("Exit"), "grass", 1 / 45, 6)
    for i, name in enumerate(FLOORS):
        shore.cave_floor(stage, stage.piece(name), bottom, 60 + i)
        shore.reef_floor(stage, stage.piece(name), int(stage.piece(name).length() / 12), 6)  # Tide-pool coral and weed.
    for name in LEDGES:
        stage.slab(stage.piece(name), shore.CAVE_FLOOR, shore.CAVE_ROCK)
    for name in WALLS + ROOFS:
        shore.cave_rock(stage, stage.piece(name))
    for name in ROOFS:
        shore.stalactites(stage, stage.piece(name), seed=6)
    for name, side in CRYSTAL_WALLS.items():
        shore.crystals(stage, stage.piece(name), side, seed=6)
    r = rng("mounds", 6)
    for name in ROOFS:
        piece = stage.piece(name)
        top = max(p.y for p in piece.polygon)
        left = min(p.x for p in piece.polygon)
        right = max(p.x for p in piece.polygon)
        count = max(1, int((right - left) / 14))
        for k in range(count):
            x = left + (k + r.uniform(0.2, 0.8)) * (right - left) / count
            spot = piece.world(x, top, -piece.depth * r.uniform(0.3, 0.7))  # `top` is in the roof's own space.
            shore.outcrop(stage.batch(spot, shore.SCENERY), spot, r.uniform(5.0, 8.0), spot.y + r.uniform(1.5, 4.0), spot.y - 0.5, (name, k), sides=8)
    shore.rail_supports(stage, sea)

    shore.signs(stage, sea)
    taken = []
    for name in SAND + GRASS:
        shore.palms_by_cliffs(stage, stage.piece(name), sea, zones, taken, 6)
    shore.scatter_scenery(stage, sea, zones, 6, stacks=8, islands=5)
    stage.export(os.path.join(HERE, "act_6_art.glb"))


main()
