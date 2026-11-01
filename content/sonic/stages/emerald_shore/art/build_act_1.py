"""Builds the art for Emerald Shore Act 1 (act_1_art.glb) from its greybox (act_1.greybox.json).

Run both steps from the repository root after changing the act's greybox, then let Godot import:

    godot --headless --path . --script res://tools/godot/export_greybox.gd -- res://content/sonic/stages/emerald_shore/act_1.tscn content/sonic/stages/emerald_shore/art/act_1.greybox.json
    blender --background --factory-startup --python content/sonic/stages/emerald_shore/art/build_act_1.py

Each greybox piece is dressed by name below. A piece missing from the lists stops the build, so a
new piece can't slip into the act without art.
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.append(os.path.join(HERE, "..", "..", "..", "..", "..", "tools", "blender"))
sys.path.append(HERE)

import shore_kit as shore  # noqa: E402
from mathutils import Vector  # noqa: E402
from stage_kit import Stage  # noqa: E402

GRASS = ["Start", "Downhill", "LoopFloor", "LoopExitUphill", "Crest", "LowSlope", "LowGround", "LowRamp",
         "Merge", "PierRamp", "Downhill2", "Loop2Floor", "Uphill2", "Rollers", "Hump1", "Hump2", "FinalStraight", "EndWall"]
SAND = ["BeachTop", "BeachDown", "SurgeSlope", "Shore"]
WET_SAND = ["Flats"]
DECKS = ["Deck"]  # The high deck, over the low road: posts only on its seaward side.
PIERS = ["Pier1", "Pier2", "Pier3", "Pier4", "Pier5"]
HIGH_PLANKS = ["HighPlank"]  # Over the pier in the side view: supports on the far side only.
FAR_SIDE = 1  # The side view's camera is on the +Z side, so the pier's far side is its local -Z one.


def main() -> None:
    stage = Stage(os.path.join(HERE, "act_1.greybox.json"))
    dressed = GRASS + SAND + WET_SAND + DECKS + PIERS + HIGH_PLANKS
    missing = sorted(set(stage.pieces) - set(dressed))
    if missing:
        sys.exit(f"build_act_1.py doesn't say how to dress: {', '.join(missing)}")
    sea = stage.sea_height
    bottom = sea - 3.0
    zones = shore.keep_out_zones(stage)

    for name in GRASS:
        stage.ground(stage.piece(name), shore.GRASS, shore.GRASS_LIP, shore.SANDSTONE, bottom, seed=1)
        shore.dress_tops(stage, stage.piece(name), "grass", 1 / 45, 1)
    for name in SAND + WET_SAND:
        top = shore.WET_SAND if name in WET_SAND else shore.SAND
        stage.ground(stage.piece(name), top, shore.SAND_LIP, shore.SANDSTONE, bottom, lip_depth=(0.2, 0.45), seed=2)
        shore.dress_tops(stage, stage.piece(name), "sand", 1 / 90, 2)
    for name in DECKS:
        shore.pier(stage, stage.piece(name), sea, post_spacing=6.0)
    for name in PIERS:
        shore.pier(stage, stage.piece(name), sea)
    for name in HIGH_PLANKS:
        stage.slab(stage.piece(name), shore.PLANKS, shore.WOOD_DARK)
        shore.plank_supports(stage, stage.piece(name), sea, FAR_SIDE)

    shore.signs(stage, sea)
    taken = []
    for name in GRASS + SAND + WET_SAND:
        shore.palms_by_cliffs(stage, stage.piece(name), sea, zones, taken, 1)
    shore.scatter_scenery(stage, sea, zones, 1)

    # A lighthouse on its own rock past the end of the act, where the finish straight points.
    end = stage.piece("EndWall").world(0, 0, 0)
    rock_centre = Vector((end.x + 70.0, sea, end.z - 40.0))
    spots = shore.outcrop(stage.batch(rock_centre), rock_centre, 9.0, sea + 7.0, sea - 4.0, "lighthouse", sides=11)
    shore.lighthouse(stage.batch(rock_centre), Vector((rock_centre.x, sea + 7.3, rock_centre.z)), 16.0)
    shore.palm(stage.batch(rock_centre), spots[3], 6.0, 0.5, 0.3, "lighthouse")

    stage.export(os.path.join(HERE, "act_1_art.glb"))


main()
