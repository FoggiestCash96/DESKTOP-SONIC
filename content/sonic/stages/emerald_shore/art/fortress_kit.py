"""Eggman's coastal fortress, for Emerald Shore Act 8: stone causeways and walls in block courses,
a metal bridge on pylons, steel towers with lit windows and beacons, and a hazard-striped fence
where the arena meets the sea. The beach and cliffs around the arena are the shore's own
(shore_kit), so the fortress sits in the same world.
"""

import math

from mathutils import Matrix, Vector

import art_kit
from art_kit import define_material as material, paint, rng
from stage_kit import UP, _matrix

STONE_TILES = material("stone_tiles", (0.60, 0.60, 0.64))
STONE_BLOCKS = material("stone_blocks", (0.52, 0.53, 0.57))
METAL_GRATE = material("metal_grate", (0.38, 0.40, 0.44))
HAZARD = material("hazard", (0.95, 0.76, 0.10))
STONE_TRIM = paint((0.40, 0.41, 0.45))
STEEL = paint((0.50, 0.53, 0.58))
STEEL_DARK = paint((0.30, 0.32, 0.36))
RED_TRIM = paint((0.74, 0.13, 0.10))
WINDOW = paint((1.0, 0.84, 0.38))
BEACON = paint((1.0, 0.28, 0.20))


def walkway(stage, piece, bottom: float) -> None:
    """A stone causeway or wall: tiled top, a coping stone edge, block courses down into the sea."""
    stage.ground(piece, STONE_TILES, STONE_TRIM, STONE_BLOCKS, bottom, lip_depth=(0.22, 0.22), relief=0.06)


def wall_lamps(stage, piece, spacing: float = 12.0) -> None:
    """Lamps on a wall's long faces, every `spacing` metres, glowing in the storm."""
    top = max(p.y for p in piece.polygon)
    left = min(p.x for p in piece.polygon)
    right = max(p.x for p in piece.polygon)
    if piece.depth > right - left:
        # Long along local Z: lamps on the faces at either end of the profile.
        count = max(1, int(piece.depth / spacing))
        spots = [(x, -piece.depth * (i + 0.5) / count, outward) for i in range(count)
                 for x, outward in ((left - 0.05, -piece.axis), (right + 0.05, piece.axis))]
    else:
        count = max(1, int((right - left) / spacing))
        spots = [(left + (right - left) * (i + 0.5) / count, z, outward) for i in range(count)
                 for z, outward in ((0.05, piece.across), (-piece.depth - 0.05, -piece.across))]
    for x, z, outward in spots:
        centre = piece.world(x, top - 1.2, z)
        frame = Matrix((outward.cross(UP), UP, outward)).transposed().to_4x4()
        frame.translation = centre
        batch = stage.batch(centre)
        batch.add(art_kit.transformed(art_kit.box((0.5, 0.7, 0.24), (0, 0, 0.1)), frame), STEEL_DARK)
        batch.add(art_kit.transformed(art_kit.box((0.32, 0.46, 0.08), (0, 0, 0.24)), frame), WINDOW)


def bridge(stage, piece, sea: float, spacing: float = 7.0) -> None:
    """A steel bridge with a grating deck, hazard-striped edge beams and pylons into the sea."""
    stage.slab(piece, METAL_GRATE, STEEL_DARK)
    left = min(p.x for p in piece.polygon)
    right = max(p.x for p in piece.polygon)
    top = max(p.y for p in piece.polygon)
    for z, outward in ((0.0, piece.across), (-piece.depth, -piece.across)):
        # The hazard band along each edge: UVs run diagonally so the stripes slant.
        corners = [piece.world(left, top - 0.05, z) + outward * 0.03, piece.world(right, top - 0.05, z) + outward * 0.03,
                   piece.world(right, top - 0.45, z) + outward * 0.03, piece.world(left, top - 0.45, z) + outward * 0.03]
        uvs = [(c.dot(piece.axis) + c.y, 0.0) for c in corners]
        stage._face(corners, outward, HAZARD, uvs)
    bottom = piece.bottom()
    count = max(1, round((right - left) / spacing))
    for i in range(count + 1):
        x = left + (right - left) * i / count
        for z in (0.25, -piece.depth - 0.25):
            point = piece.world(x, 0.0, z)
            stage.posts([(point.x, point.z)], bottom + 0.1, sea - 3.0, 0.32, STEEL, segments=8)


def fence(stage, wall: dict, ground: float) -> None:
    """A steel fence along an invisible wall, so players can see what stops them."""
    matrix = _matrix(wall["transform"])
    size = Vector(wall["size"])
    start = matrix @ Vector((-size.x / 2, 0, 0))
    end = matrix @ Vector((size.x / 2, 0, 0))
    count = max(1, round((end - start).length / 3.0))
    for i in range(count + 1):
        point = start.lerp(end, i / count)
        stage.posts([(point.x, point.z)], ground + 1.3, ground - 4.0, 0.09, STEEL_DARK)
        cap = art_kit.transformed(art_kit.cylinder(0.12, 0.18, 6), Matrix.Translation((point.x, ground + 1.3, point.z)))
        stage.batch(point).add(cap, HAZARD)
    for height in (0.55, 1.15):
        rail = art_kit.tube([Vector((start.x, ground + height, start.z)), Vector((end.x, ground + height, end.z))], [0.06, 0.06], 6)
        stage.batch(start.lerp(end, 0.5)).add(rail, STEEL)


def tower(batch, centre: Vector, base: float, height: float, radius: float, seed) -> None:
    """A fortress tower: a stone foundation in the sea, a steel shaft with red bands and rows of lit
    windows, a gallery, a domed top and an antenna with a red beacon."""
    r = rng("tower", seed)
    sides = 8
    foundation = art_kit.lathe([(radius * 1.35, base - 3.0), (radius * 1.3, base + 3.0), (radius * 1.15, base + 3.6)], sides)
    batch.add(art_kit.transformed(foundation, Matrix.Translation(centre)), STONE_TRIM)
    shaft_bottom = base + 3.6
    shaft_top = base + height * 0.78
    shaft = art_kit.lathe([(radius, shaft_bottom), (radius * 0.92, shaft_top)], sides, cap_bottom=False)
    batch.add(art_kit.transformed(shaft, Matrix.Translation(centre)), STEEL)
    y = shaft_bottom + 4.0
    while y < shaft_top - 2.0:
        t = (y - shaft_bottom) / (shaft_top - shaft_bottom)
        reach = radius * (1.0 - 0.08 * t)
        band = art_kit.lathe([(reach + 0.12, y), (reach + 0.12, y + 0.7)], sides)
        batch.add(art_kit.transformed(band, Matrix.Translation(centre)), RED_TRIM)
        for k in range(sides):
            if r.random() < 0.7:
                angle = math.tau * (k + 0.5) / sides
                out = Vector((math.cos(angle), 0.0, -math.sin(angle)))
                window = art_kit.box((1.0, 1.2, 0.2))
                frame = Matrix((out.cross(UP), UP, out)).transposed().to_4x4()
                frame.translation = centre + out * (reach * math.cos(math.pi / sides) + 0.02) + UP * (y + 2.2)
                batch.add(art_kit.transformed(window, frame), WINDOW)
        y += 5.5
    gallery = art_kit.lathe([(radius * 1.2, shaft_top), (radius * 1.2, shaft_top + 0.6)], sides)
    batch.add(art_kit.transformed(gallery, Matrix.Translation(centre)), STEEL_DARK)
    dome = art_kit.lathe([(radius * 0.92 * math.cos(a), shaft_top + 0.6 + radius * 0.8 * math.sin(a))
                          for a in (0.0, 0.4, 0.8, 1.2, 1.57)], sides, cap_bottom=False)
    batch.add(art_kit.transformed(dome, Matrix.Translation(centre)), RED_TRIM, smooth=True)
    mast_bottom = shaft_top + 0.6 + radius * 0.8
    mast = art_kit.cylinder(0.15, height * 0.22, 6)
    batch.add(art_kit.transformed(mast, Matrix.Translation(centre + UP * mast_bottom)), STEEL_DARK)
    beacon = art_kit.sphere(0.5, 8, 5)
    batch.add(art_kit.transformed(beacon, Matrix.Translation(centre + UP * (mast_bottom + height * 0.22 + 0.4))), BEACON, smooth=True)


def rocks_in_sea(stage, sea: float, zones, seed, count: int = 40, distances=(8.0, 70.0)) -> None:
    """Dark rocks breaking the surface around the fortress."""
    from shore_kit import in_zones, rock
    r = rng("sea rocks", seed)
    path = [piece.world(piece.polygon[0].x, 0, -piece.depth / 2) for piece in stage.pieces.values()]
    placed = 0
    for _ in range(count * 20):
        if placed >= count:
            break
        anchor = path[r.randrange(len(path))]
        angle = r.uniform(0, math.tau)
        point = anchor + Vector((math.cos(angle), 0, math.sin(angle))) * r.uniform(*distances)
        point.y = sea - 0.8
        if in_zones(point, zones) or not stage.clear_of_track(point, 3.0):
            continue
        rock(stage.batch(point), point, r.uniform(1.0, 3.2), (seed, placed), flatten=r.uniform(0.6, 1.0))
        placed += 1
