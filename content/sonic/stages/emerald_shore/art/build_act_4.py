"""Builds the art for Emerald Shore Act 4, Shallow Reef Lagoon (act_4_art.glb), from its greybox
(act_4.greybox.json).

Run both steps from the repository root after changing the act's greybox, then let Godot import:

    godot --headless --path . --script res://tools/godot/export_greybox.gd -- res://content/sonic/stages/emerald_shore/act_4.tscn content/sonic/stages/emerald_shore/art/act_4.greybox.json
    blender --background --factory-startup --python content/sonic/stages/emerald_shore/art/build_act_4.py

Each greybox piece is dressed by name below. A piece missing from the lists stops the build, so a
new piece can't slip into the act without art. The lagoon's surface is the sea's: the sandbars
show through it, coral grows on them and on the channels' beds, and coral heads stand around.
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

GRASS = ["Start", "Islet1", "Islet2", "Islet3", "Corner", "Islet4", "Islet5", "FinalIslet", "EndWall"]
BEACHES = ["StartBeach", "Islet1Beach", "Islet2Beach", "Sandbar2Beach", "Islet3Slope", "Islet4Beach", "Islet5Beach",
           "Sandbar3Beach", "FinalBeach"]
SANDBARS = ["Sandbar1", "Sandbar2", "Sandbar3"]  # Just under the surface: wading depth.
BEDS = ["Channel1Bed", "Channel1Out", "Channel2Bed", "Channel2Out", "Channel3Bed", "Channel3Out"]  # Deep: swimming.
REEF = ["ReefDown", "ReefRidge", "ReefPillar"]


def main() -> None:
    stage = Stage(os.path.join(HERE, "act_4.greybox.json"))
    dressed = GRASS + BEACHES + SANDBARS + BEDS + REEF
    missing = sorted(set(stage.pieces) - set(dressed))
    if missing:
        sys.exit(f"build_act_4.py doesn't say how to dress: {', '.join(missing)}")
    sea = stage.sea_height
    bottom = sea - 8.0  # The lagoon's beds are deep: cliffs reach down past them.
    zones = shore.keep_out_zones(stage)

    for name in GRASS:
        stage.ground(stage.piece(name), shore.GRASS, shore.GRASS_LIP, shore.SANDSTONE, bottom, seed=4)
        shore.dress_tops(stage, stage.piece(name), "grass", 1 / 45, 4)
    for name in BEACHES:
        stage.ground(stage.piece(name), shore.SAND, shore.SAND_LIP, shore.SANDSTONE, bottom, lip_depth=(0.2, 0.45), seed=4)
        shore.dress_tops(stage, stage.piece(name), "sand", 1 / 80, 4)
    for name in SANDBARS:
        stage.ground(stage.piece(name), shore.WET_SAND, shore.SAND_LIP, shore.SANDSTONE, bottom, lip_depth=(0.2, 0.45), seed=4)
        shore.reef_floor(stage, stage.piece(name), int(stage.piece(name).length() / 8), 4)
    for name in BEDS:
        stage.ground(stage.piece(name), shore.SAND, shore.SAND_LIP, shore.SANDSTONE, bottom, lip_depth=(0.2, 0.45), seed=4)
        shore.reef_floor(stage, stage.piece(name), int(stage.piece(name).length() / 3), 4)
    for name in REEF:
        stage.ground(stage.piece(name), shore.REEF, shore.CORALS[0], shore.SANDSTONE, bottom, lip_depth=(0.15, 0.3), seed=4)

    # Coral heads out in the lagoon, clear of the track.
    r = rng("coral heads", 4)
    placed = 0
    tries = 0
    while placed < 60 and tries < 2000:
        tries += 1
        x = r.uniform(-60.0, 460.0)
        z = r.uniform(-470.0, 40.0)
        point = Vector((x, sea - r.uniform(0.6, 2.5), z))
        if not stage.clear_of_track(point, 3.0) or stage.distance_to_track(point) > 40.0:
            continue
        placed += 1
        shore.coral(stage.batch(point, shore.SCENERY), point, r.uniform(0.8, 1.6), ("head", placed))
        shore.rock(stage.batch(point), point - Vector((0, 1.0, 0)), r.uniform(1.0, 2.0), ("head", placed))

    shore.signs(stage, sea)
    taken = []
    for name in GRASS + BEACHES:
        shore.palms_by_cliffs(stage, stage.piece(name), sea, zones, taken, 4)
    shore.scatter_scenery(stage, sea, zones, 4, stacks=12, islands=8)
    stage.export(os.path.join(HERE, "act_4_art.glb"))


main()
