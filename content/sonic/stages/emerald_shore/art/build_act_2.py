"""Builds the art for Emerald Shore Act 2, Lush Palm Grove (act_2_art.glb), from its greybox
(act_2.greybox.json).

Run both steps from the repository root after changing the act's greybox, then let Godot import:

    godot --headless --path . --script res://tools/godot/export_greybox.gd -- res://content/sonic/stages/emerald_shore/act_2.tscn content/sonic/stages/emerald_shore/art/act_2.greybox.json
    blender --background --factory-startup --python content/sonic/stages/emerald_shore/art/build_act_2.py

Each greybox piece is dressed by name below. A piece missing from the lists stops the build, so a
new piece can't slip into the act without art. The tree trunks (cylinders in the greybox, which
the player can't pass through) become jungle palms.
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

GRASS = ["Start", "Floor1", "FloorRise", "Merge", "FarBank", "Corner", "Canopy1", "Canopy2", "HighShelf", "Canopy3",
         "Corner2", "Terrace1", "Terrace2", "Terrace3", "LogRun", "LoopRun", "LoopFloor", "LoopExit", "Alcove", "EndWall"]
OUTCROPS = ["AlcoveBack", "AlcoveSideNorth", "AlcoveSideSouth"]  # The secret alcove's rock walls.
SAND = ["Beach"]
DECKS = ["Deck1", "Deck2", "Deck3", "Deck4"]  # The treetop decks, on posts beside the jungle floor.
BRIDGES = ["Bridge1", "Bridge2", "RopeBridge", "RiverBridge"]
LOGS = ["Log1", "Log2", "Log3"]  # Fallen trunks across the log run.


def main() -> None:
    stage = Stage(os.path.join(HERE, "act_2.greybox.json"))
    dressed = GRASS + OUTCROPS + SAND + DECKS + BRIDGES + LOGS
    missing = sorted(set(stage.pieces) - set(dressed))
    trunks = [p for p in stage.data["pieces"] if p["type"] == "cylinder"]
    missing += [p["name"] for p in trunks if not p["name"].startswith("Trunk")]
    if missing:
        sys.exit(f"build_act_2.py doesn't say how to dress: {', '.join(missing)}")
    sea = stage.sea_height
    bottom = sea - 3.0
    zones = shore.keep_out_zones(stage)

    for name in GRASS + OUTCROPS:
        stage.ground(stage.piece(name), shore.GRASS, shore.GRASS_LIP, shore.SANDSTONE, bottom, seed=2, cliff_rows=4.0)
    for name in GRASS:
        piece = stage.piece(name)
        shore.dress_tops(stage, piece, "grass", 1 / 100, 2)
        r = rng("ferns", name)
        for chain in piece.top_chains():
            for a, b in zip(chain, chain[1:]):
                for k in range(int((b - a).length * piece.depth / 240)):
                    local = a.lerp(b, r.random())
                    point = piece.world(local.x, local.y, -r.uniform(0.4, piece.depth - 0.4))
                    shore.ferns(stage.batch(point, shore.SCENERY), point, (name, k))
    for name in SAND:
        stage.ground(stage.piece(name), shore.SAND, shore.SAND_LIP, shore.SANDSTONE, bottom, lip_depth=(0.2, 0.45), seed=2, cliff_rows=4.0)
        shore.dress_tops(stage, stage.piece(name), "sand", 1 / 90, 2)
    for name in DECKS:
        shore.pier(stage, stage.piece(name), sea, post_spacing=6.0)
    for name in BRIDGES:
        shore.pier(stage, stage.piece(name), sea, post_spacing=5.0)
    for name in LOGS:
        shore.fallen_log(stage, stage.piece(name))
    for trunk in trunks:
        centre = Vector(trunk["transform"]["origin"])
        base = centre - Vector((0, trunk["height"] / 2, 0))
        shore.jungle_tree(stage.batch(base), base, trunk["height"] + 3.0, trunk["radius"], trunk["name"])
    shore.rail_supports(stage, sea)

    shore.signs(stage, sea)
    taken = []
    for name in GRASS + SAND:
        shore.palms_by_cliffs(stage, stage.piece(name), sea, zones, taken, 2)
    shore.scatter_scenery(stage, sea, zones, 2, stacks=8, islands=4)
    stage.export(os.path.join(HERE, "act_2_art.glb"))


main()
