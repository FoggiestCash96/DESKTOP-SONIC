"""Emerald Shore's look: its materials, scenery and set dressing, built from simple shapes for the
act build scripts next to this file (see tools/blender/stage_kit.py for how a stage is dressed).

Green grass tops over sandstone cliffs in warm horizontal bands, white sand, wooden piers on
posts, palms leaning out over a turquoise sea, and islands and sea stacks on the horizon. For
Acts 2 to 7 too: jungle palms and ferns, fallen logs, waterfalls, coral, cave rock with
stalactites and glowing crystals, and supports for grind rails.
"""

import math

from mathutils import Matrix, Vector

import art_kit
from art_kit import define_material as material, noise2, paint, rng
from stage_kit import UP, _matrix

# The big surfaces have materials of their own, tuned in materials/ (stripes and bands); the colours
# here only show in Blender. Everything else is painted (see art_kit.Paint), so a chunk of the
# stage draws in a handful of calls.
GRASS = material("grass", (0.40, 0.75, 0.23))
SAND = material("sand", (0.94, 0.85, 0.63))
WET_SAND = material("wet_sand", (0.86, 0.77, 0.57))
SANDSTONE = material("sandstone", (0.92, 0.62, 0.36))
PLANKS = material("planks", (0.76, 0.54, 0.32))
GRASS_LIP = paint((0.25, 0.60, 0.19))
SAND_LIP = paint((0.88, 0.76, 0.54))
WOOD = paint((0.60, 0.40, 0.24))
WOOD_DARK = paint((0.43, 0.28, 0.17))
PALM_TRUNK = paint((0.66, 0.49, 0.31))
PALM_LEAF = paint((0.20, 0.64, 0.22), two_sided=True)
COCONUT = paint((0.42, 0.27, 0.13))
BUSH = paint((0.22, 0.60, 0.24))
ROCK = paint((0.66, 0.60, 0.53))
GRASS_TUFT = paint((0.30, 0.70, 0.22), two_sided=True)
PETALS = [paint(colour) for colour in ((0.96, 0.27, 0.32), (1.0, 0.86, 0.22), (0.68, 0.40, 0.95), (0.98, 0.98, 0.98))]
FLOWER_HEART = paint((1.0, 0.70, 0.12))
STARFISH = paint((1.0, 0.52, 0.32))
SHELL = paint((0.99, 0.86, 0.80))
WHITE_PAINT = paint((0.96, 0.96, 0.94))
RED_PAINT = paint((0.86, 0.16, 0.14))
LAMP = paint((1.0, 0.95, 0.60))

SCENERY = art_kit.NO_SHADOW  # Far scenery and small things on the ground cast no shadows.


# --- Plants ------------------------------------------------------------------------------------

def palm(batch, base: Vector, height: float, yaw: float, lean: float, seed, far: bool = False) -> None:
    """A palm tree whose trunk rises from `base`, curving over by `lean` radians toward `yaw`.
    A `far` palm is simpler, for scenery seen only from a distance."""
    r = rng("palm", seed)
    toward = Vector((math.sin(yaw), 0, math.cos(yaw)))
    rings = 4 if far else 7
    points, radii = [], []
    for i in range(rings + 1):
        t = i / rings
        points.append(base + UP * (height * t) + toward * (height * math.sin(lean) * t * t))
        radii.append(0.32 - 0.14 * t)
    segments = 5 if far else 6
    shade = []
    for i in range(rings + 1):
        value = 1.0 if i % 2 == 0 else 0.8
        shade.extend([(value, value, value)] * segments)
    batch.add(art_kit.tube(points, radii, segments), PALM_TRUNK, smooth=True, colour=shade)
    top = points[-1]
    fronds = 5 if far else r.randint(7, 8)
    for k in range(fronds):
        angle = math.tau * k / fronds + r.uniform(-0.25, 0.25)
        _frond(batch, top, angle, r.uniform(2.8, 3.6) * max(0.8, height / 9.0) ** 0.4, r.uniform(0.7, 1.1),
               r.uniform(0.25, 0.55), 4 if far else 6)
    if far:
        return
    for k in range(2):
        angle = math.tau * k / 3 + r.uniform(0, 1)
        nut = top + Vector((math.cos(angle) * 0.24, -0.22, math.sin(angle) * 0.24))
        batch.add(art_kit.transformed(art_kit.sphere(0.16, 5, 3), Matrix.Translation(nut)), COCONUT, smooth=True)


def _frond(batch, top: Vector, angle: float, length: float, droop: float, rise: float, samples: int) -> None:
    """One palm leaf: an arching blade with a folded middle and a jagged edge."""
    out = Vector((math.cos(angle), 0, math.sin(angle)))
    side = out.cross(UP)
    vertices, colours, faces = [], [], []
    for i in range(samples + 1):
        s = i / samples
        spine = top + out * (length * s) + UP * (length * (rise * math.sin(math.pi * s * 0.8) - droop * 0.55 * s * s))
        width = 0.62 * math.sin(math.pi * min(1.0, s * 1.08)) * (0.62 if i % 2 else 1.0)
        fold = UP * (0.1 * width)
        vertices.extend([spine + side * width - fold * 0.2, spine + fold, spine - side * width - fold * 0.2])
        tone = 0.68 + 0.32 * s
        colours.extend([(tone, tone, tone)] * 3)
    for i in range(samples):
        a = i * 3
        faces.append(art_kit._orient((a, a + 1, a + 4, a + 3), vertices, UP))
        faces.append(art_kit._orient((a + 1, a + 2, a + 5, a + 4), vertices, UP))
    batch.add((vertices, faces), PALM_LEAF, smooth=True, colour=colours)


def bush(batch, base: Vector, size: float, seed) -> None:
    r = rng("bush", seed)
    for k in range(3):
        offset = Vector((r.uniform(-0.5, 0.5), 0, r.uniform(-0.5, 0.5))) * size
        radius = size * r.uniform(0.45, 0.7)
        shape = art_kit.blob(radius, 0.25, r.randint(0, 999), 9, 5, squash=(1.0, 0.75, 1.0))
        centre = base + offset + UP * radius * 0.45
        vertices, faces = art_kit.transformed(shape, Matrix.Translation(centre))
        shade = [(0.75 + 0.25 * min(1.0, max(0.0, (v.y - base.y) / (radius * 1.2))),) * 3 for v in vertices]
        batch.add((vertices, faces), BUSH, smooth=True, colour=shade)


def rock(batch, base: Vector, size: float, seed, flatten: float = 0.7) -> None:
    r = rng("rock", seed)
    shape = art_kit.blob(size, 0.4, r.randint(0, 999), 8, 5, squash=(1.0, flatten, r.uniform(0.7, 1.0)))
    batch.add(art_kit.transformed(shape, art_kit.placement(base + UP * size * flatten * 0.3, r.uniform(0, math.tau))), ROCK)


def flowers(batch, base: Vector, seed) -> None:
    """A clump of three to five flowers on short stems, to run through."""
    r = rng("flowers", seed)
    petal = PETALS[r.randrange(len(PETALS))]
    for k in range(r.randint(3, 5)):
        foot = base + Vector((r.uniform(-0.45, 0.45), 0, r.uniform(-0.45, 0.45)))
        height = r.uniform(0.22, 0.42)
        head = foot + UP * height
        stem_side = Vector((0.025, 0, 0))
        stem = [foot - stem_side, foot + stem_side, head + stem_side, head - stem_side]
        batch.add((stem, [(0, 1, 2, 3)]), GRASS_TUFT)
        star, centre = [], []
        turn = r.uniform(0, math.tau)
        for i in range(10):
            angle = turn + math.tau * i / 10
            radius = 0.16 if i % 2 == 0 else 0.07
            star.append(head + Vector((math.cos(angle) * radius, 0.0, math.sin(angle) * radius)))
        for i in range(6):
            angle = turn + math.tau * i / 6
            centre.append(head + Vector((math.cos(angle) * 0.05, 0.015, math.sin(angle) * 0.05)))
        batch.add((star, [art_kit._orient(tuple(range(10)), star, UP)]), petal)
        batch.add((centre, [art_kit._orient(tuple(range(6)), centre, UP)]), FLOWER_HEART)


def tuft(batch, base: Vector, seed) -> None:
    """A few blades of grass, to run through."""
    r = rng("tuft", seed)
    for k in range(r.randint(3, 5)):
        angle = r.uniform(0, math.tau)
        out = Vector((math.cos(angle), 0, math.sin(angle)))
        side = out.cross(UP) * 0.05
        foot = base + out * r.uniform(0, 0.12)
        tip = foot + out * r.uniform(0.05, 0.18) + UP * r.uniform(0.3, 0.5)
        blade = [foot - side, foot + side, tip]
        batch.add((blade, [(0, 1, 2)]), GRASS_TUFT, colour=[(0.8, 0.8, 0.8), (0.8, 0.8, 0.8), (1.0, 1.0, 1.0)])


def starfish(batch, base: Vector, seed) -> None:
    r = rng("starfish", seed)
    turn = r.uniform(0, math.tau)
    rim = []
    for i in range(10):
        angle = turn + math.tau * i / 10
        radius = 0.22 if i % 2 == 0 else 0.09
        rim.append(base + Vector((math.cos(angle) * radius, 0.02, math.sin(angle) * radius)))
    middle = base + UP * 0.06
    vertices = rim + [middle]
    faces = [art_kit._orient((i, (i + 1) % 10, 10), vertices, UP) for i in range(10)]
    batch.add((vertices, faces), STARFISH)


def shell(batch, base: Vector, seed) -> None:
    r = rng("shell", seed)
    shape = art_kit.lathe([(0.12, 0.0), (0.09, 0.05), (0.0, 0.09)], 7, cap_bottom=False)
    batch.add(art_kit.transformed(shape, art_kit.placement(base, r.uniform(0, math.tau), (1.0, 1.0, 0.8))), SHELL, smooth=True)


# --- Rocks, sea stacks and islands --------------------------------------------------------------

def rough_circle(radius: float, sides: int, seed) -> list:
    """Points around an uneven circle, as offsets from its middle."""
    r = rng("circle", seed)
    rim = []
    for i in range(sides):
        angle = math.tau * i / sides + r.uniform(-0.1, 0.1)
        reach = radius * (0.75 + 0.5 * noise2(math.cos(angle) * 1.3 + 3, math.sin(angle) * 1.3 + 3, r.randint(0, 999)))
        rim.append(Vector((math.cos(angle) * reach, 0, math.sin(angle) * reach)))
    return rim


def outcrop(batch, centre: Vector, radius: float, top: float, bottom: float, seed, sides: int = 9,
            top_material: str = GRASS, lip_material: str = GRASS_LIP, rim: list = None) -> list:
    """A rock rising from the sea with sandstone sides and a grassy top, like a small piece of the
    stage's cliffs. Returns points on its top for things to stand on."""
    r = rng("outcrop", seed)
    rim = rim or rough_circle(radius, sides, seed)
    sides = len(rim)
    levels = max(2, math.ceil((top - bottom) / 2.5))
    vertices, faces, colours = [], [], []
    for k in range(levels + 1):
        t = k / levels
        y = bottom + (top - bottom) * t
        spread = 1.08 - 0.12 * t  # a little narrower at the top
        for i, point in enumerate(rim):
            bump = 1.0 + 0.12 * (noise2(i * 0.9, k * 0.8, r.randint(0, 999)) - 0.5) if 0 < k < levels else 1.0
            vertices.append(centre + Vector((point.x * spread * bump, y, point.z * spread * bump)))
            shade = 0.72 + 0.28 * t
            colours.append((shade, shade, shade))
    for k in range(levels):
        for i in range(sides):
            j = (i + 1) % sides
            face = (k * sides + i, k * sides + j, (k + 1) * sides + j, (k + 1) * sides + i)
            outward = vertices[face[0]] - Vector((centre.x, vertices[face[0]].y, centre.z))
            faces.append(art_kit._orient(face, vertices, outward))
    batch.add((vertices, faces), SANDSTONE, colour=colours)
    # The grassy top: a fan from a slightly raised middle, and a lip around its edge.
    top_ring = vertices[levels * sides:]
    middle = centre + UP * (top + radius * 0.08)
    cap = top_ring + [middle]
    cap_faces = [art_kit._orient((i, (i + 1) % sides, sides), cap, UP) for i in range(sides)]
    batch.add((cap, cap_faces), top_material, uvs=[[(cap[k].x, cap[k].z) for k in face] for face in cap_faces])
    lip_vertices, lip_faces = [], []
    for i, point in enumerate(top_ring):
        outward = (point - Vector((centre.x, point.y, centre.z))).normalized()
        lip_vertices.extend([point, point + outward * 0.14 - UP * (0.4 + 0.35 * (i % 2))])
    for i in range(sides):
        j = (i + 1) % sides
        face = (2 * i, 2 * j, 2 * j + 1, 2 * i + 1)
        outward = lip_vertices[2 * i] - Vector((centre.x, lip_vertices[2 * i].y, centre.z))
        lip_faces.append(art_kit._orient(face, lip_vertices, outward))
    batch.add((lip_vertices, lip_faces), lip_material)
    spots = []
    for i in range(sides):
        spots.append(middle.lerp(top_ring[i], r.uniform(0.2, 0.6)))
    return spots


def island(batch, centre: Vector, radius: float, height: float, sea: float, seed) -> None:
    """A distant island: a sandy beach around a grassy plateau, with palms and bushes."""
    r = rng("island", seed)
    sides = 16
    rim = rough_circle(radius, sides, seed)
    beach = [centre + Vector((p.x * 1.3, sea + 0.4, p.z * 1.3)) for p in rim]
    shore = [centre + Vector((p.x * 1.5, sea - 1.0, p.z * 1.5)) for p in rim]
    foot = [centre + Vector((p.x * 1.06, sea + 0.6, p.z * 1.06)) for p in rim]
    vertices = shore + beach + foot
    faces = []
    for i in range(sides):
        j = (i + 1) % sides
        faces.append(art_kit._orient((i, j, sides + j, sides + i), vertices, UP))
        faces.append(art_kit._orient((sides + i, sides + j, 2 * sides + j, 2 * sides + i), vertices, UP))
    batch.add((vertices, faces), SAND)
    spots = outcrop(batch, centre, radius, sea + height, sea + 0.4, seed, rim=rim)
    palms = 0
    for k, spot in enumerate(spots):
        if r.random() < 0.45 and palms < 6:
            palm(batch, spot, r.uniform(6, 10), r.uniform(0, math.tau), r.uniform(0.1, 0.35), (seed, k), far=True)
            palms += 1
        elif r.random() < 0.5:
            bush(batch, spot, r.uniform(1.5, 2.5), (seed, k))


def sea_stack(batch, base: Vector, radius: float, top: float, sea: float, seed) -> None:
    """A rock pillar standing in the sea, with a palm or a bush on top."""
    r = rng("stack", seed)
    spots = outcrop(batch, base, radius, top, sea - 4.0, seed, sides=8)
    for _ in range(3):
        rock(batch, base + Vector((r.uniform(-1, 1) * radius * 1.3, sea - 0.8, r.uniform(-1, 1) * radius * 1.3)), r.uniform(0.8, 1.6), r.random())
    if r.random() < 0.7:
        palm(batch, spots[0], r.uniform(4, 7), r.uniform(0, math.tau), r.uniform(0.15, 0.4), seed, far=True)
    else:
        bush(batch, spots[0], r.uniform(1.2, 2.0), seed)


def lighthouse(batch, base: Vector, height: float) -> None:
    """A red and white lighthouse."""
    bands = 6
    for k in range(bands):
        y0, y1 = height * k / bands, height * (k + 1) / bands
        r0, r1 = 2.2 - 0.9 * k / bands, 2.2 - 0.9 * (k + 1) / bands
        shape = art_kit.lathe([(r0, y0), (r1, y1)], 12, cap_bottom=False, cap_top=False)
        batch.add(art_kit.transformed(shape, Matrix.Translation(base)), RED_PAINT if k % 2 else WHITE_PAINT, smooth=True)
    gallery = art_kit.lathe([(1.8, height), (1.8, height + 0.3)], 12)
    batch.add(art_kit.transformed(gallery, Matrix.Translation(base)), WOOD_DARK)
    lamp_room = art_kit.lathe([(1.0, height + 0.3), (1.0, height + 2.0)], 10)
    batch.add(art_kit.transformed(lamp_room, Matrix.Translation(base)), LAMP, smooth=True)
    roof = art_kit.lathe([(1.25, height + 2.0), (0.0, height + 3.2)], 10)
    batch.add(art_kit.transformed(roof, Matrix.Translation(base)), RED_PAINT, smooth=True)


# --- Wood ----------------------------------------------------------------------------------------

def pier(stage, piece, sea: float, post_spacing: float = 4.0, sides=(0, 1)) -> None:
    """A wooden pier: planks on beams, on posts standing in the sea. Posts go only where nothing
    walkable is below them, so none stand on ground a player can reach. `sides` picks the long
    sides that get posts (0 is the side at local z = 0)."""
    stage.slab(piece, PLANKS, WOOD_DARK)
    bottom = piece.bottom()
    length = piece.length()
    left = min(p.x for p in piece.polygon)
    count = max(1, round(length / post_spacing))
    for i in range(count + 1):
        x = left + length * i / count
        for side in sides:
            z = 0.15 if side == 0 else -piece.depth - 0.15
            point = piece.world(x, 0.0, z)
            if stage.top_below(Vector((point.x, bottom - 0.05, point.z)), ignore=(piece.name,)) is None:
                stage.posts([(point.x, point.z)], bottom + 0.2, sea - 3.0, 0.2, WOOD)


def plank_supports(stage, piece, sea: float, side: int) -> None:
    """Two tall posts from the sea to under a high plank, on one side only (the far side of a side view)."""
    left = min(p.x for p in piece.polygon)
    right = max(p.x for p in piece.polygon)
    under = piece.bottom()
    z = 0.2 if side == 0 else -piece.depth - 0.2
    for x in (left + 1.0, right - 1.0):
        point = piece.world(x, 0.0, z)
        stage.posts([(point.x, point.z)], under + 0.3, sea - 3.0, 0.22, WOOD)
        beam_start = piece.world(x, piece.local_y(under) - 0.15, 0.3)
        beam_end = piece.world(x, piece.local_y(under) - 0.15, -piece.depth - 0.3)
        beam = art_kit.tube([beam_start, beam_end], [0.12, 0.12], 5)
        stage.batch(beam_start).add(beam, WOOD_DARK)


def signs(stage, sea: float) -> None:
    """A wooden board behind each fixed sign (Label3D) in the stage. A sign over the track hangs
    from a beam between posts on either side, like a banner; any other stands on a post planted in
    the nearest edge."""
    for marker in stage.markers("Label3D"):
        if marker.get("billboard", True):
            continue
        matrix = _matrix(marker["transform"])
        centre = matrix.translation.copy()
        right = (matrix.to_3x3() @ Vector((1, 0, 0))).normalized()
        facing = (matrix.to_3x3() @ Vector((0, 0, 1))).normalized()
        width = marker["text_size"][0] + 0.9
        height = marker["text_size"][1] + 0.6
        frame = Matrix((right, UP, facing)).transposed().to_4x4()
        frame.translation = centre - facing * 0.1
        batch = stage.batch(centre)
        batch.add(art_kit.transformed(art_kit.box((width, height, 0.12)), frame), WOOD_DARK)
        for size, middle in (((width + 0.2, 0.16, 0.2), (0, height / 2, 0)), ((width + 0.2, 0.16, 0.2), (0, -height / 2, 0)),
                             ((0.16, height, 0.2), (width / 2, 0, 0)), ((0.16, height, 0.2), (-width / 2, 0, 0))):
            batch.add(art_kit.transformed(art_kit.box(size, middle), frame), WOOD)
        if stage.distance_to_track(centre) == 0.0:
            # A banner: posts just past the walkable ground on either side, and a beam across.
            ends = []
            for direction in (right, -right):
                point = centre.copy()
                for _ in range(200):
                    if stage.distance_to_track(point) > 0.3:
                        break
                    point += direction * 0.5
                ends.append(point)
            beam = centre.y + height / 2 + 0.3
            for end in ends:
                ground = _ground_near(stage, end, sea)
                stage.posts([(end.x, end.z)], beam + 0.3, ground - 1.0, 0.18, WOOD)
            bar = art_kit.tube([Vector((ends[0].x, beam, ends[0].z)), Vector((ends[1].x, beam, ends[1].z))], [0.14, 0.14], 6)
            batch.add(bar, WOOD)
        else:
            for offset in ((-width / 3, width / 3) if width > 3.0 else (0.0,)):
                foot = centre + right * offset
                ground = _ground_near(stage, foot, sea)
                stage.posts([(foot.x - facing.x * 0.2, foot.z - facing.z * 0.2)], centre.y, ground - 1.0, 0.13, WOOD)


def _ground_near(stage, point: Vector, sea: float) -> float:
    """The highest walkable top within a few metres of `point` (below it), or the sea."""
    best = None
    for dx in (-3.0, -1.5, 0.0, 1.5, 3.0):
        for dz in (-3.0, -1.5, 0.0, 1.5, 3.0):
            top = stage.top_below(Vector((point.x + dx, point.y, point.z + dz)))
            if top is not None and (best is None or top > best):
                best = top
    return best if best is not None else sea - 2.0


# --- Scattering ------------------------------------------------------------------------------------

def keep_out_zones(stage) -> list:
    """Boxes scenery must stay out of: the space between each side-view camera and its path."""
    zones = []
    for volume in stage.data.get("camera_volumes", []):
        if not volume["side_view"]:
            continue
        matrix = _matrix(volume["transform"])
        size = Vector(volume["size"])
        zones.append((matrix.inverted(), Vector((-size.x / 2 - 5, -1000, -1.0)), Vector((size.x / 2 + 5, 1000, volume["distance"] + 8.0))))
    return zones


def in_zones(point, zones) -> bool:
    for inverse, low, high in zones:
        p = inverse @ Vector(point)
        if low.x <= p.x <= high.x and low.y <= p.y <= high.y and low.z <= p.z <= high.z:
            return True
    return False


def dress_tops(stage, piece, kind: str, density: float, seed) -> None:
    """Things to run through on a walkable top: flowers and grass on grass, shells on sand."""
    r = rng("tops", piece.name, seed)
    markers = [Vector(m["position"]) for m in stage.markers() if m["kind"] not in ("Node3D", "Label3D")]
    for chain in piece.top_chains():
        for a, b in zip(chain, chain[1:]):
            area = (b - a).length * piece.depth
            for _ in range(int(area * density)):
                t = r.random()
                local = a.lerp(b, t)
                z = -r.uniform(0.4, piece.depth - 0.4)
                point = piece.world(local.x, local.y, z)
                if any((point - m).length < 2.0 for m in markers):
                    continue
                batch = stage.batch(point, SCENERY)
                roll = r.random()
                if kind == "grass":
                    (flowers if roll < 0.45 else tuft)(batch, point, (piece.name, t, z))
                elif roll < 0.5:
                    shell(batch, point, (piece.name, t, z))
                else:
                    starfish(batch, point, (piece.name, t, z))


def palms_by_cliffs(stage, piece, sea: float, zones, taken: list, seed, spacing=(16.0, 28.0)) -> None:
    """Palms standing in the shallows at the foot of a piece's cliffs, leaning out to sea."""
    r = rng("palms", piece.name, seed)
    for chain in piece.top_chains():
        for side_z, outward in ((0.0, piece.across), (-piece.depth, -piece.across)):
            points = [piece.world(p.x, p.y, side_z) for p in chain]
            total = sum((b - a).length for a, b in zip(points, points[1:]))
            distance = r.uniform(0, spacing[0])
            while distance < total:
                edge = _point_along(points, distance)
                base = edge + outward * r.uniform(2.0, 3.5)
                base.y = sea - 0.6
                distance += r.uniform(*spacing)
                if in_zones(base, zones) or not stage.clear_of_track(base, 1.2):
                    continue
                if any((base - other).length < 7.0 for other in taken):
                    continue
                taken.append(base)
                batch = stage.batch(base)
                height = (edge.y - sea) + r.uniform(1.5, 5.0)
                yaw = math.atan2(outward.x, outward.z) + r.uniform(-0.5, 0.5)
                palm(batch, base, height, yaw, r.uniform(0.18, 0.4), (piece.name, distance))
                rock(batch, base + UP * 0.3, r.uniform(0.9, 1.5), (piece.name, distance))


def _point_along(points, distance: float) -> Vector:
    for a, b in zip(points, points[1:]):
        length = (b - a).length
        if distance <= length:
            return a.lerp(b, distance / max(length, 1e-6))
        distance -= length
    return points[-1].copy()


def scatter_scenery(stage, sea: float, zones, seed, stacks: int = 14, islands: int = 8,
                    stack_range=(25.0, 90.0), island_range=(160.0, 520.0)) -> None:
    """Sea stacks near the stage and islands on the horizon, all clear of the track."""
    r = rng("scenery", seed)
    path = [piece.world(piece.polygon[0].x, 0, -piece.depth / 2) for piece in stage.pieces.values()]
    placed = []

    def place(count, distances, make, size):
        tries = 0
        while count > 0 and tries < count * 60:
            tries += 1
            anchor = path[r.randrange(len(path))]
            angle = r.uniform(0, math.tau)
            distance = r.uniform(*distances)
            point = anchor + Vector((math.cos(angle) * distance, 0, math.sin(angle) * distance))
            point.y = sea
            if in_zones(point, zones) or not stage.clear_of_track(point, size + 12.0):
                continue
            if any((point - other).length < size + other_size + 10.0 for other, other_size in placed):
                continue
            placed.append((point, size))
            make(point)
            count -= 1

    def make_stack(point):
        radius = r.uniform(2.5, 5.0)
        sea_stack(stage.batch(point), point, radius, sea + r.uniform(6.0, 22.0), sea, (seed, point.x, point.z))

    def make_island(point):
        radius = r.uniform(25.0, 60.0)
        island(stage.batch(point, SCENERY), point, radius, r.uniform(5.0, 16.0), sea, (seed, point.x, point.z))

    place(stacks, stack_range, make_stack, 5.0)
    place(islands, island_range, make_island, 60.0)


# --- Acts 2 to 7: jungle, cascades, reefs, caves and the sunset ridge ----------------------------

CAVE_ROCK = material("cave_rock", (0.44, 0.38, 0.40))
CAVE_FLOOR = material("cave_floor", (0.58, 0.50, 0.45))
RIVERBED = material("riverbed", (0.48, 0.58, 0.60))
REEF = material("reef", (0.96, 0.62, 0.50))
WATERFALL = material("waterfall", (0.62, 0.90, 1.0))
CRYSTAL = material("crystal", (0.70, 0.95, 1.0))
CAVE_LIP = paint((0.36, 0.31, 0.33))
STALACTITE = paint((0.50, 0.44, 0.45))
JUNGLE_LEAF = paint((0.13, 0.50, 0.18), two_sided=True)
FERN = paint((0.24, 0.62, 0.20), two_sided=True)
VINE = paint((0.20, 0.46, 0.16))
BARK = paint((0.46, 0.32, 0.20))
BARK_END = paint((0.80, 0.64, 0.42))
CORALS = [paint(colour) for colour in ((0.98, 0.44, 0.52), (1.0, 0.62, 0.26), (0.68, 0.42, 0.92), (1.0, 0.86, 0.36), (0.40, 0.84, 0.86))]
SEAWEED = paint((0.22, 0.58, 0.32), two_sided=True)
CRYSTAL_TINTS = [(0.70, 0.95, 1.0), (0.86, 0.72, 1.0), (0.60, 1.0, 0.86)]


def cave_rock(stage, piece, top: str = CAVE_ROCK) -> None:
    """A cave wall or roof: the box as the greybox has it, all in rock."""
    stage.slab(piece, top, CAVE_ROCK)


def cave_floor(stage, piece, bottom: float, seed) -> None:
    """A cave's floor: pebbly rock on top, rock below its edges."""
    stage.ground(piece, CAVE_FLOOR, CAVE_LIP, CAVE_ROCK, bottom, lip_depth=(0.15, 0.3), relief=0.25, seed=seed)


def stalactites(stage, piece, spacing: float = 4.0, longest: float = 3.0, seed=0) -> None:
    """Rock spikes hanging from a roof's underside, at most `longest` metres long."""
    r = rng("stalactites", piece.name, seed)
    under = piece.bottom()
    left = min(p.x for p in piece.polygon)
    right = max(p.x for p in piece.polygon)
    along = int((right - left) / spacing)
    across = max(1, int(piece.depth / spacing))
    for i in range(along):
        for j in range(across):
            if r.random() < 0.45:
                continue
            x = left + (i + r.uniform(0.2, 0.8)) * (right - left) / along
            z = -(j + r.uniform(0.2, 0.8)) * piece.depth / across
            point = piece.world(x, piece.local_y(under), z)
            length = r.uniform(0.6, longest)
            cone = art_kit.lathe([(r.uniform(0.25, 0.5), 0.0), (0.04, -length)], 6, cap_bottom=False)
            stage.batch(point, SCENERY).add(art_kit.transformed(cone, Matrix.Translation(point)), STALACTITE, smooth=True)


def crystals(stage, piece, side: int, spacing: float = 9.0, seed=0) -> None:
    """Glowing crystal clusters set into one long face of a wall (`side` 0 is its local z = 0
    face, 1 the other), low down so they light the floor beside it."""
    r = rng("crystals", piece.name, seed)
    left = min(p.x for p in piece.polygon)
    right = max(p.x for p in piece.polygon)
    bottom = min(p.y for p in piece.polygon)
    z = 0.0 if side == 0 else -piece.depth
    outward = piece.across if side == 0 else -piece.across
    distance = r.uniform(0.0, spacing)
    while distance < right - left:
        base = piece.world(left + distance, bottom + r.uniform(0.3, 2.5), z)
        distance += r.uniform(spacing * 0.6, spacing * 1.4)
        tint = CRYSTAL_TINTS[r.randrange(len(CRYSTAL_TINTS))]
        batch = stage.batch(base, SCENERY)
        for k in range(r.randint(3, 5)):
            length = r.uniform(0.6, 1.6)
            radius = r.uniform(0.12, 0.22)
            prism = art_kit.lathe([(radius, 0.0), (radius, length * 0.75), (0.0, length)], 6, cap_bottom=False)
            # Pointing out of the wall, fanned up and sideways.
            direction = (outward + UP * r.uniform(-0.2, 0.9) + piece.axis * r.uniform(-0.6, 0.6)).normalized()
            rotation = UP.rotation_difference(direction).to_matrix().to_4x4()
            spot = base - outward * 0.3 + piece.axis * r.uniform(-0.3, 0.3)
            batch.add(art_kit.transformed(prism, Matrix.Translation(spot) @ rotation), CRYSTAL, colour=tint)


def waterfall(stage, left: Vector, right: Vector, bottom: float, seed, lean: float = 0.6) -> None:
    """A curtain of water from the edge between `left` and `right` (at their height) down to
    `bottom`, bowing out by `lean` metres, with white water at its foot."""
    r = rng("waterfall", seed)
    width = (right - left).length
    across = max(2, math.ceil(width / 1.5))
    height = left.y - bottom
    down = max(3, math.ceil(height / 1.5))
    outward = (right - left).cross(UP).normalized()
    vertices, colours, uvs_by_vertex = [], [], []
    for i in range(down + 1):
        t = i / down
        bow = lean * math.sin(t * math.pi * 0.5)
        for j in range(across + 1):
            s = j / across
            top_point = left.lerp(right, s)
            ripple = 0.08 * math.sin(s * 9.0 + t * 4.0 + r.uniform(0, 0.3))
            vertices.append(Vector((top_point.x, top_point.y - height * t, top_point.z)) + outward * (bow + ripple))
            foam = max(0.0, (t - 0.82) / 0.18)
            colours.append((foam, foam, foam))
            uvs_by_vertex.append((s * width, t * height))
    faces, uvs = [], []
    for i in range(down):
        for j in range(across):
            a = i * (across + 1) + j
            face = art_kit._orient((a, a + 1, a + across + 2, a + across + 1), vertices, outward)
            faces.append(face)
            uvs.append([uvs_by_vertex[k] for k in face])
    middle = left.lerp(right, 0.5)
    stage.batch(middle).add((vertices, faces), WATERFALL, colour=colours, uvs=uvs)
    # Spray where it lands.
    batch = stage.batch(middle, SCENERY)
    for k in range(max(3, int(width / 1.2))):
        spot = left.lerp(right, r.uniform(0.0, 1.0)) + outward * (lean + r.uniform(0.0, 0.6))
        spot.y = bottom + r.uniform(0.0, 0.4)
        puff = art_kit.blob(r.uniform(0.4, 0.8), 0.3, r.randint(0, 999), 7, 4, squash=(1.0, 0.6, 1.0))
        batch.add(art_kit.transformed(puff, Matrix.Translation(spot)), WHITE_PAINT, smooth=True)


def jungle_tree(batch, base: Vector, height: float, radius: float, seed) -> None:
    """A tall jungle palm with a trunk `radius` thick at the bottom (matching its collider) and a
    full crown of fronds and broad leaves, with a few vines hanging from it."""
    r = rng("jungle", seed)
    rings = 6
    points, radii, shade = [], [], []
    lean = Vector((r.uniform(-0.3, 0.3), 0, r.uniform(-0.3, 0.3)))
    for i in range(rings + 1):
        t = i / rings
        points.append(base + UP * (height * t) + lean * (t * t))
        radii.append(radius * (1.0 - 0.35 * t))
    for i in range(rings + 1):
        value = 1.0 if i % 2 == 0 else 0.8
        shade.extend([(value, value, value)] * 7)
    batch.add(art_kit.tube(points, radii, 7), PALM_TRUNK, smooth=True, colour=shade)
    top = points[-1]
    for k in range(8):
        angle = math.tau * k / 8 + r.uniform(-0.2, 0.2)
        _frond(batch, top, angle, r.uniform(3.6, 4.6), r.uniform(0.8, 1.2), r.uniform(0.2, 0.45), 5)
    for k in range(2):
        offset = Vector((r.uniform(-1.2, 1.2), r.uniform(-0.4, 0.4), r.uniform(-1.2, 1.2)))
        leaf = art_kit.blob(r.uniform(1.2, 1.8), 0.3, r.randint(0, 999), 7, 4, squash=(1.0, 0.55, 1.0))
        batch.add(art_kit.transformed(leaf, Matrix.Translation(top + offset)), JUNGLE_LEAF, smooth=True)
    for k in range(3):
        angle = r.uniform(0, math.tau)
        start = top + Vector((math.cos(angle), -0.2, math.sin(angle))) * 1.6
        length = r.uniform(2.0, 4.0)
        vine = [start, start + Vector((0.1, -length * 0.5, 0.05)), start + Vector((0.0, -length, 0.1))]
        batch.add(art_kit.tube(vine, [0.05, 0.04, 0.03], 4), VINE)


def ferns(batch, base: Vector, seed) -> None:
    """A fern of arching fronds, to run through."""
    r = rng("fern", seed)
    for k in range(r.randint(5, 7)):
        angle = math.tau * k / 6 + r.uniform(-0.3, 0.3)
        out = Vector((math.cos(angle), 0, math.sin(angle)))
        side = out.cross(UP) * 0.09
        length = r.uniform(0.6, 1.0)
        vertices, faces = [], []
        for i in range(4):
            s = i / 3
            spine = base + out * (length * s) + UP * (0.55 * math.sin(math.pi * s * 0.8))
            width = 1.0 - s * 0.8
            vertices.extend([spine - side * width, spine + side * width])
        for i in range(3):
            a = 2 * i
            faces.append((a, a + 1, a + 3, a + 2))
        batch.add((vertices, faces), FERN, colour=[(0.8, 0.8, 0.8)] * 2 + [(1, 1, 1)] * 6)


def fallen_log(stage, piece) -> None:
    """A fallen tree trunk lying across the way where the greybox has a box: bark round its length,
    pale cut rings at its ends."""
    left = min(p.x for p in piece.polygon)
    right = max(p.x for p in piece.polygon)
    low = min(p.y for p in piece.polygon)
    high = max(p.y for p in piece.polygon)
    long_x = right - left >= piece.depth
    radius = (high - low) * 0.5
    if long_x:
        a, b = piece.world(left, (low + high) / 2, -piece.depth / 2), piece.world(right, (low + high) / 2, -piece.depth / 2)
    else:
        a, b = piece.world((left + right) / 2, (low + high) / 2, 0.0), piece.world((left + right) / 2, (low + high) / 2, -piece.depth)
    batch = stage.batch(a.lerp(b, 0.5))
    batch.add(art_kit.tube([a, a.lerp(b, 0.5), b], [radius, radius * 1.04, radius], 10), BARK, smooth=True)
    for end, toward in ((a, a - b), (b, b - a)):
        disc = art_kit.lathe([(radius * 0.98, 0.0), (radius * 0.98, 0.02)], 10)
        rotation = UP.rotation_difference(toward.normalized()).to_matrix().to_4x4()
        batch.add(art_kit.transformed(disc, Matrix.Translation(end) @ rotation), BARK_END)


def coral(batch, base: Vector, size: float, seed) -> None:
    """A coral head: branching tubes, a round brain coral and a frond or two of weed."""
    r = rng("coral", seed)
    colour = CORALS[r.randrange(len(CORALS))]
    for k in range(r.randint(3, 6)):
        angle = r.uniform(0, math.tau)
        lean = Vector((math.cos(angle), 0, math.sin(angle))) * r.uniform(0.2, 0.5)
        length = size * r.uniform(0.6, 1.2)
        start = base + Vector((r.uniform(-0.3, 0.3), 0, r.uniform(-0.3, 0.3))) * size
        branch = [start, start + (UP + lean * 0.5) * length * 0.5, start + (UP + lean) * length]
        batch.add(art_kit.tube(branch, [size * 0.12, size * 0.09, size * 0.05], 5), colour, smooth=True)
    other = CORALS[r.randrange(len(CORALS))]
    brain = art_kit.blob(size * r.uniform(0.35, 0.55), 0.2, r.randint(0, 999), 9, 5, squash=(1.0, 0.7, 1.0))
    batch.add(art_kit.transformed(brain, Matrix.Translation(base + Vector((size * 0.4, 0, -size * 0.3)))), other, smooth=True)
    for k in range(2):
        spot = base + Vector((r.uniform(-1, 1), 0, r.uniform(-1, 1))) * size * 0.6
        tip = spot + UP * size * r.uniform(0.8, 1.5) + Vector((r.uniform(-0.3, 0.3), 0, r.uniform(-0.3, 0.3)))
        side = Vector((0.12, 0, 0)) * size
        batch.add(([spot - side, spot + side, tip + side * 0.3, tip - side * 0.3], [(0, 1, 2, 3)]), SEAWEED)


def reef_floor(stage, piece, count: int, seed) -> None:
    """Coral scattered over a sea bed or sandbar's top, all small enough to run (or swim) through."""
    r = rng("reef floor", piece.name, seed)
    chains = piece.top_chains()
    if not chains:
        return
    for k in range(count):
        chain = chains[r.randrange(len(chains))]
        a, b = chain[0], chain[-1]
        local = a.lerp(b, r.uniform(0.05, 0.95))
        point = piece.world(local.x, local.y, -r.uniform(0.5, piece.depth - 0.5))
        coral(stage.batch(point, SCENERY), point, r.uniform(0.35, 0.7), (piece.name, k))


def rail_supports(stage, sea: float, spacing: float = 8.0) -> None:
    """Posts holding up each grind rail, every `spacing` metres, down to the ground below or into
    the sea; none where a post would stand on ground a player can run on."""
    for rail in stage.data.get("rails", []):
        points = [Vector(p) for p in rail["points"]]
        total = sum((b - a).length for a, b in zip(points, points[1:]))
        count = max(1, round(total / spacing))
        for i in range(count + 1):
            point = _point_along(points, total * i / count)
            below = stage.top_below(point - UP * 0.2)
            if below is not None and point.y - below < 6.0:
                continue  # Over ground a player can reach: the rail floats there.
            foot = below if below is not None else sea - 3.0
            stage.posts([(point.x, point.z)], point.y - rail["radius"] - 0.05, foot, 0.12, WOOD_DARK, segments=6)
            bracket = art_kit.box((0.5, 0.12, 0.3), (0, 0, 0))
            stage.batch(point).add(art_kit.transformed(bracket, Matrix.Translation(point - UP * (rail["radius"] + 0.08))), WOOD_DARK)
