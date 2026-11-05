"""Builds the art for Emerald Shore Act 3, Cascading Waterfall Basin (act_3_art.glb), from its
greybox (act_3.greybox.json).

Run both steps from the repository root after changing the act's greybox, then let Godot import:

    godot --headless --path . --script res://tools/godot/export_greybox.gd -- res://content/sonic/stages/emerald_shore/act_3.tscn content/sonic/stages/emerald_shore/art/act_3.greybox.json
    blender --background --factory-startup --python content/sonic/stages/emerald_shore/art/build_act_3.py

Each greybox piece is dressed by name below. A piece missing from the lists stops the build, so a
new piece can't slip into the act without art. The streams and the plunge pool are the act's
water volumes, which draw their own surfaces in the game; this adds the waterfalls.
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.append(os.path.join(HERE, "..", "..", "..", "..", "..", "tools", "blender"))
sys.path.append(HERE)

import shore_kit as shore  # noqa: E402
from mathutils import Vector  # noqa: E402
from stage_kit import Stage  # noqa: E402

GRASS = ["Start", "Basin1", "TierA", "TierB", "TierC", "Basin2", "Alcove", "Corner", "Ledge2", "Bank3a", "Bank3b", "EndWall"]
OUTCROPS = ["AlcoveBack", "AlcoveSideNorth", "AlcoveSideSouth"]
SLIDES = ["Slide1", "Slide2", "Slide3", "Slide4"]  # The waterslides: a stream runs down each.
POOL = ["PoolBed", "PoolRamp"]
SAND = ["Beach"]


def main() -> None:
    stage = Stage(os.path.join(HERE, "act_3.greybox.json"))
    dressed = GRASS + OUTCROPS + SLIDES + POOL + SAND
    missing = sorted(set(stage.pieces) - set(dressed))
    if missing:
        sys.exit(f"build_act_3.py doesn't say how to dress: {', '.join(missing)}")
    sea = stage.sea_height
    bottom = sea - 3.0
    zones = shore.keep_out_zones(stage)

    for name in GRASS + OUTCROPS:
        stage.ground(stage.piece(name), shore.GRASS, shore.GRASS_LIP, shore.SANDSTONE, bottom, seed=3, cliff_rows=3.5)
    for name in GRASS:
        shore.dress_tops(stage, stage.piece(name), "grass", 1 / 80, 3)
    for name in SLIDES + POOL:
        stage.ground(stage.piece(name), shore.RIVERBED, shore.GRASS_LIP, shore.SANDSTONE, bottom, seed=3, cliff_rows=3.5)
    for name in SAND:
        stage.ground(stage.piece(name), shore.SAND, shore.SAND_LIP, shore.SANDSTONE, bottom, lip_depth=(0.2, 0.45), seed=3, cliff_rows=3.5)
        shore.dress_tops(stage, stage.piece(name), "sand", 1 / 90, 3)

    # Waterfalls pour down the left of each tier's face, beside the springs that climb them.
    for name, below in (("TierA", 34.0), ("TierB", 40.0), ("TierC", 46.0)):
        piece = stage.piece(name)
        top = max(p.y for p in piece.polygon)
        left = piece.world(0.0, top, -piece.depth + 1.0)
        right = piece.world(0.0, top, -piece.depth + 9.0)
        shore.waterfall(stage, left, right, below, name, lean=0.4)
    # Big falls off the plateau's sides at the start, and off the second basin, down to the sea.
    for name, side in (("Start", 0.0), ("Basin2", 0.0)):
        piece = stage.piece(name)
        top = max(p.y for p in piece.polygon)
        for edge_z in (0.4, -piece.depth - 0.4):
            length = min(piece.length(), 14.0)
            a = piece.world(piece.length() * 0.5 - length * 0.5, top - 0.1, edge_z)
            b = piece.world(piece.length() * 0.5 + length * 0.5, top - 0.1, edge_z)
            shore.waterfall(stage, a, b, sea, (name, edge_z), lean=1.5)
    shore.rail_supports(stage, sea)

    shore.signs(stage, sea)
    taken = []
    for name in GRASS + SAND:
        shore.palms_by_cliffs(stage, stage.piece(name), sea, zones, taken, 3)
    shore.scatter_scenery(stage, sea, zones, 3, stacks=8, islands=4)
    stage.export(os.path.join(HERE, "act_3_art.glb"))


main()
