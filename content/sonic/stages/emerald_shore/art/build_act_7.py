"""Builds the art for Emerald Shore Act 7, Sunset Ridge Cliffs (act_7_art.glb), from its greybox
(act_7.greybox.json).

Run both steps from the repository root after changing the act's greybox, then let Godot import:

    godot --headless --path . --script res://tools/godot/export_greybox.gd -- res://content/sonic/stages/emerald_shore/act_7.tscn content/sonic/stages/emerald_shore/art/act_7.greybox.json
    blender --background --factory-startup --python content/sonic/stages/emerald_shore/art/build_act_7.py

Each greybox piece is dressed by name below. A piece missing from the lists stops the build, so a
new piece can't slip into the act without art. The fortress of Act 8 stands out at sea ahead of
the final straight, its towers dark against the sunset.
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.append(os.path.join(HERE, "..", "..", "..", "..", "..", "tools", "blender"))
sys.path.append(HERE)

import fortress_kit as fortress  # noqa: E402
import shore_kit as shore  # noqa: E402
from mathutils import Vector  # noqa: E402
from stage_kit import Stage  # noqa: E402

GRASS = ["Start", "Downhill1", "LoopFloor1", "Ramp1", "Landing1", "RailRun", "Ledge1", "Corner1", "Ledge2", "Ledge3", "Ramp2",
         "Landing2", "Corner2", "Run3", "Downhill3", "LoopFloor3", "Rise3", "Ridge", "FinalStraight", "EndWall", "SeaStack"]
BRIDGES = ["SafeBridge1", "SafeBridge2"]  # Sloping plank bridges beside the big jumps.


def main() -> None:
    stage = Stage(os.path.join(HERE, "act_7.greybox.json"))
    dressed = GRASS + BRIDGES
    missing = sorted(set(stage.pieces) - set(dressed))
    if missing:
        sys.exit(f"build_act_7.py doesn't say how to dress: {', '.join(missing)}")
    sea = stage.sea_height
    bottom = sea - 3.0
    zones = shore.keep_out_zones(stage)

    for name in GRASS:
        stage.ground(stage.piece(name), shore.GRASS, shore.GRASS_LIP, shore.SANDSTONE, bottom, seed=7, cliff_rows=4.5)
        shore.dress_tops(stage, stage.piece(name), "grass", 1 / 110, 7)
    for name in BRIDGES:
        shore.pier(stage, stage.piece(name), sea, post_spacing=5.0)
    shore.rail_supports(stage, sea)

    # The fortress waits out at sea, ahead of the final straight.
    end = stage.piece("EndWall").world(0, 0, 0)
    for k, offset in enumerate((Vector((-60, 0, -260)), Vector((10, 0, -300)), Vector((75, 0, -250)))):
        spot = Vector((end.x + offset.x, 0.0, end.z + offset.z))
        fortress.tower(stage.batch(spot), spot, sea, 40.0 + 6.0 * k, 6.0, ("fortress", k))

    shore.signs(stage, sea)
    taken = []
    for name in GRASS:
        shore.palms_by_cliffs(stage, stage.piece(name), sea, zones, taken, 7)
    shore.scatter_scenery(stage, sea, zones, 7, stacks=8, islands=5)
    stage.export(os.path.join(HERE, "act_7_art.glb"))


main()
