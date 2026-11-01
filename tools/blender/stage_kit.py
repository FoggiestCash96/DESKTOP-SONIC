"""Builds a stage's art from its greybox, in Blender.

tools/godot/export_greybox.gd writes the greybox as JSON; a stage's build script loads it here,
dresses each piece (ground with cliffs and a grass lip, bridges, piers, walls), adds scenery, and
exports one .glb that the stage shows in place of the greybox. The greybox itself stays in the
stage, hidden, as the collision: the art follows its walkable surfaces exactly, so the art can
change without changing how the stage plays.

The rule that keeps it honest: only the tops of greybox pieces may look walkable. Cliffs drop
from their edges into the sea, scenery stands in the water or far away, and anything placed on a
walkable top is something a player can run through (flowers, grass, shells).

All positions are in Godot's axes (see art_kit).
"""

import json
import math

from mathutils import Matrix, Vector

import art_kit
from art_kit import Batch, noise2

UP = Vector((0, 1, 0))


def _matrix(transform: dict) -> Matrix:
    x, y, z, origin = (Vector(transform[key]) for key in ("x", "y", "z", "origin"))
    return Matrix(((x.x, y.x, z.x, origin.x), (x.y, y.y, z.y, origin.y), (x.z, y.z, z.z, origin.z), (0, 0, 0, 1)))


class Piece:
    """A greybox piece: a side profile (local X along the way, Y up) extruded over `depth` along
    local -Z, placed in the world by `matrix`. Boxes are turned into the same form."""

    def __init__(self, data: dict):
        self.name = data["name"]
        self.material = data.get("material", "")
        self.matrix = _matrix(data["transform"])
        if data["type"] == "box":
            sx, sy, sz = data["size"]
            self.polygon = [Vector((-sx / 2, -sy / 2)), Vector((sx / 2, -sy / 2)), Vector((sx / 2, sy / 2)), Vector((-sx / 2, sy / 2))]
            self.depth = sz
            self.matrix = self.matrix @ Matrix.Translation((0, 0, sz / 2))
        elif data["type"] == "polygon":
            self.polygon = [Vector(p) for p in data["polygon"]]
            self.depth = data["depth"]
        else:
            raise ValueError(f"{self.name}: can't dress a {data['type']} piece yet")
        self.inverse = self.matrix.inverted()
        area = sum(a.x * b.y - b.x * a.y for a, b in zip(self.polygon, self.polygon[1:] + self.polygon[:1]))
        self.clockwise = area < 0
        self.axis = (self.matrix.to_3x3() @ Vector((1, 0, 0))).normalized()  # along the way
        self.across = (self.matrix.to_3x3() @ Vector((0, 0, 1))).normalized()

    def world(self, x: float, y: float, z: float) -> Vector:
        return self.matrix @ Vector((x, y, z))

    def edges(self):
        """Each edge of the profile with its outward normal."""
        count = len(self.polygon)
        for i in range(count):
            a, b = self.polygon[i], self.polygon[(i + 1) % count]
            d = b - a
            normal = Vector((-d.y, d.x)) if self.clockwise else Vector((d.y, -d.x))
            yield a, b, normal.normalized()

    def top_chains(self) -> list:
        """The profile's upward-facing edges, joined into runs of points ordered along local +X."""
        count = len(self.polygon)
        up = [n.y > 0.3 for _, _, n in self.edges()]
        chains = []
        if all(up):
            return [self.polygon[:]]
        start = next(i for i in range(count) if not up[i])
        chain = []
        for step in range(1, count + 1):
            i = (start + step) % count
            if up[i]:
                if not chain:
                    chain.append(self.polygon[i])
                chain.append(self.polygon[(i + 1) % count])
            elif chain:
                chains.append(chain)
                chain = []
        if chain:
            chains.append(chain)
        return [c if c[0].x <= c[-1].x else list(reversed(c)) for c in chains]

    def local(self, point) -> Vector:
        return self.inverse @ Vector(point)

    def contains(self, point, margin: float = 0.0) -> bool:
        p = self.local(point)
        if p.z > margin or p.z < -self.depth - margin:
            return False
        return _inside_polygon(Vector((p.x, p.y)), self.polygon, margin)

    def top_at(self, point):
        """Height of this piece's top above or below `point` (same X and Z), or None if it has no top there."""
        p = self.local(point)
        if p.z > 0.0 or p.z < -self.depth:
            return None
        best = None
        for chain in self.top_chains():
            for a, b in zip(chain, chain[1:]):
                if min(a.x, b.x) <= p.x <= max(a.x, b.x) and b.x != a.x:
                    y = a.y + (b.y - a.y) * (p.x - a.x) / (b.x - a.x)
                    world_y = self.world(p.x, y, p.z).y
                    best = world_y if best is None else max(best, world_y)
        return best

    def bottom(self) -> float:
        return min(self.world(p.x, p.y, 0).y for p in self.polygon)

    def local_y(self, world_y: float) -> float:
        """A world height as a height in the profile (pieces are only ever turned around Y)."""
        return world_y - self.matrix.translation.y

    def distance_across(self, point) -> float:
        """How far `point` is from this piece's footprint, ignoring height."""
        p = self.local(point)
        left = min(q.x for q in self.polygon)
        right = max(q.x for q in self.polygon)
        dx = max(left - p.x, 0.0, p.x - right)
        dz = max(-self.depth - p.z, 0.0, p.z)
        return math.hypot(dx, dz)

    def length(self) -> float:
        return max(p.x for p in self.polygon) - min(p.x for p in self.polygon)


def _inside_polygon(point: Vector, polygon: list, margin: float) -> bool:
    inside = False
    for a, b in zip(polygon, polygon[1:] + polygon[:1]):
        if (a.y > point.y) != (b.y > point.y):
            x = a.x + (point.y - a.y) * (b.x - a.x) / (b.y - a.y)
            if point.x < x:
                inside = not inside
    if inside or margin <= 0:
        return inside
    for a, b in zip(polygon, polygon[1:] + polygon[:1]):
        d = b - a
        t = max(0.0, min(1.0, (point - a).dot(d) / max(d.length_squared, 1e-9)))
        if (a + d * t - point).length <= margin:
            return True
    return False


class Stage:
    """A greybox and the art being built for it, sorted into square chunks so Godot can skip
    what's off screen."""

    def __init__(self, greybox_path: str, chunk_size: float = 96.0):
        with open(greybox_path, encoding="utf-8") as file:
            self.data = json.load(file)
        self.pieces = {p["name"]: Piece(p) for p in self.data["pieces"] if p["type"] in ("polygon", "box")}
        self.sea_height = self.data.get("sea_height")
        self.chunk_size = chunk_size
        self.batches = {}

    # --- Queries ---

    def piece(self, name: str) -> Piece:
        return self.pieces[name]

    def markers(self, kind: str = None) -> list:
        return [m for m in self.data["markers"] if kind is None or m["kind"] == kind]

    def solid_at(self, point, margin: float = 0.0, ignore=()) -> bool:
        """Whether `point` is inside any greybox piece (optionally grown by `margin`)."""
        return any(p.contains(point, margin) for p in self.pieces.values() if p.name not in ignore)

    def top_below(self, point, ignore=()):
        """The highest walkable top at or below `point`, or None."""
        best = None
        for piece in self.pieces.values():
            if piece.name in ignore:
                continue
            top = piece.top_at(point)
            if top is not None and top <= point[1] + 0.01 and (best is None or top > best):
                best = top
        return best

    def distance_to_track(self, point) -> float:
        """How far `point` is from the nearest piece or loop, ignoring height."""
        nearest = min((piece.distance_across(point) for piece in self.pieces.values()), default=math.inf)
        for loop in self.data["loops"]:
            centre = _matrix(loop["transform"]) @ Vector((loop["exit_offset"] / 2, loop["radius"], 0.0))
            reach = loop["radius"] + loop["width"] + loop["exit_offset"] / 2
            nearest = min(nearest, max(0.0, math.hypot(point[0] - centre.x, point[2] - centre.z) - reach))
        return nearest

    def clear_of_track(self, point, margin: float) -> bool:
        """True if nothing walkable is within `margin` of `point` sideways, so scenery there can't
        be mistaken for ground or get in a player's way."""
        return self.distance_to_track(point) > margin

    # --- Output ---

    def batch(self, position, layer: str = "") -> Batch:
        """The batch for the chunk `position` is in. Layers split things that import differently,
        such as art_kit.NO_SHADOW."""
        key = (math.floor(position[0] / self.chunk_size), math.floor(position[2] / self.chunk_size), layer)
        if key not in self.batches:
            self.batches[key] = Batch(f"chunk_{key[0]}_{key[1]}{layer}".replace("-", "m"))
        return self.batches[key]

    def export(self, glb_path: str) -> None:
        art_kit.reset_scene()
        triangles = 0
        for key in sorted(self.batches):
            batch = self.batches[key]
            if len(batch):
                batch.build()
                triangles += batch.triangles()
        art_kit.export_glb(glb_path)
        print(f"exported {glb_path}: {len(self.batches)} chunks, {triangles} triangles")
        by_material = {}
        for batch in self.batches.values():
            for face, index in zip(batch.faces, batch.face_materials):
                name = batch.materials[index]
                by_material[name] = by_material.get(name, 0) + len(face) - 2
        print("  triangles by material: " + ", ".join(f"{name} {count}" for name, count in sorted(by_material.items(), key=lambda item: -item[1])))

    # --- Dressing ---

    def ground(self, piece: Piece, top: str, lip: str, cliff: str, bottom: float, lip_depth=(0.35, 0.75),
               relief: float = 0.35, seed: int = 0) -> None:
        """Solid ground: the walkable top (with UVs in metres for stripes), a lip of the top's colour
        hanging over each edge, and cliffs from the edges down to `bottom`, bumped outward. Where
        another piece covers an edge (a neighbour at the same height), it gets no cliff or lip, and
        a cliff stops at the top of any lower piece it stands on."""
        for chain in piece.top_chains():
            self._top(piece, chain, top)
            runs = [([piece.world(p.x, p.y, z) for p in chain], outward)
                    for z, outward in ((0.0, piece.across), (-piece.depth, -piece.across))]
            for index, outward in ((0, -piece.axis), (-1, piece.axis)):
                end = chain[index]
                runs.append(([piece.world(end.x, end.y, 0.0), piece.world(end.x, end.y, -piece.depth)], outward))
            for points, outward in runs:
                self._cliff(piece, points, outward, bottom, cliff, relief, seed)
                self._lip(piece, points, outward, lip, lip_depth, seed)

    def slab(self, piece: Piece, top: str, side: str) -> None:
        """The piece exactly as the greybox has it, for thin things like bridges and planks."""
        for chain in piece.top_chains():
            self._top(piece, chain, top)
        polygon = piece.polygon
        for a, b, normal in piece.edges():
            if normal.y > 0.3:
                continue
            corners = [piece.world(a.x, a.y, 0), piece.world(b.x, b.y, 0), piece.world(b.x, b.y, -piece.depth), piece.world(a.x, a.y, -piece.depth)]
            self._face(corners, piece.matrix.to_3x3() @ Vector((normal.x, normal.y, 0)), side)
        for z, outward in ((0.0, piece.across), (-piece.depth, -piece.across)):
            corners = [piece.world(p.x, p.y, z) for p in polygon]
            self._face(corners, outward, side, [(c.dot(piece.axis), c.y) for c in corners])

    def posts(self, points, top: float, bottom: float, radius: float, material: str, segments: int = 6) -> None:
        """Round wooden posts at each (x, z), from `top` down to `bottom`."""
        for x, z in points:
            shape = art_kit.transformed(art_kit.cylinder(radius, top - bottom, segments), Matrix.Translation((x, bottom, z)))
            self.batch((x, 0, z)).add(shape, material, smooth=True)

    # --- Pieces of the above ---

    def _face(self, corners, outward, material, uvs=None) -> None:
        face = art_kit._orient(tuple(range(len(corners))), corners, outward)
        if uvs:
            uvs = [uvs[i] for i in face]
        middle = sum(corners, Vector()) / len(corners)
        self.batch(middle).add((corners, [face]), material, uvs=[uvs] if uvs else None)

    def _top(self, piece: Piece, chain: list, material: str, cell: float = 4.0) -> None:
        """The walkable top, split into cells about `cell` metres across for gentle shade variation."""
        across = max(1, round(piece.depth / cell))
        for a, b in zip(chain, chain[1:]):
            along = max(1, round((b - a).length / cell))
            grid = []
            for i in range(along + 1):
                t = i / along
                point = a.lerp(b, t)
                grid.append([piece.world(point.x, point.y, -piece.depth * j / across) for j in range(across + 1)])
            for i in range(along):
                for j in range(across):
                    corners = [grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]]
                    middle = sum(corners, Vector()) / 4
                    face = art_kit._orient((0, 1, 2, 3), corners, UP)
                    uvs = [(corners[k].dot(piece.axis), corners[k].dot(piece.across)) for k in face]
                    self.batch(middle).add((corners, [face]), material, colour=[_shade(c) for c in corners], uvs=[uvs])

    def _covered(self, piece: Piece, edge: Vector, outward: Vector) -> bool:
        """Whether the ground just past this edge belongs to another piece."""
        return self.solid_at(edge + outward * 0.3 - UP * 0.3, ignore=(piece.name,))

    def _cliff(self, piece: Piece, points, outward: Vector, bottom: float, material: str, relief: float, seed: int,
               step: float = 2.0, rows: float = 1.6) -> None:
        """A cliff face hanging from the edge through `points` down to `bottom` (or the top of a
        lower piece), pushed outward by up to `relief` metres in bumps. It starts just under and
        behind the lip, so the two never fight over the same pixels, and the bumps grow in below it."""
        columns = []
        for point in _resample(points, step):
            if self._covered(piece, point, outward):
                columns.append(None)
                continue
            start = point - UP * 0.05 - outward * 0.05
            below = self.top_below(start - outward * 0.1 - UP * 0.05, ignore=(piece.name,))
            floor = max(bottom, below) if below is not None else bottom
            height = start.y - floor
            if height < 0.05:
                columns.append(None)
                continue
            count = max(1, math.ceil(height / rows))
            column = []
            for k in range(count + 1):
                y = start.y - height * k / count
                ramp = min(1.0, (start.y - y) / 2.0) ** 2
                bump = relief * ramp * noise2((point.x + point.z) * 0.35, y * 0.45, seed)
                column.append(Vector((start.x, y, start.z)) + outward * bump)
            columns.append(column)
        for left, right in zip(columns, columns[1:]):
            if left is None or right is None:
                continue
            rows_here = min(len(left), len(right))
            for k in range(rows_here - 1):
                corners = [left[k], right[k], right[k + 1], left[k + 1]]
                if (corners[1] - corners[0]).length < 1e-4:
                    continue
                face = art_kit._orient((0, 1, 2, 3), corners, outward)
                shade = [_depth_shade(c.y, bottom) for c in corners]
                self.batch(sum(corners, Vector()) / 4).add((corners, [face]), material, colour=shade)
            # Where neighbouring columns have different numbers of rows, a fan closes the gap.
            longer, shorter = (left, right) if len(left) > len(right) else (right, left)
            for k in range(rows_here - 1, len(longer) - 1):
                corners = [longer[k], longer[k + 1], shorter[-1]]
                face = art_kit._orient((0, 1, 2), corners, outward)
                self.batch(corners[0]).add((corners, [face]), material, colour=[_depth_shade(c.y, bottom) for c in corners])

    def _lip(self, piece: Piece, points, outward: Vector, material: str, depth_range, seed: int, out: float = 0.14, step: float = 0.4) -> None:
        """A strip of the top's colour hanging over the edge, with a scalloped bottom edge."""
        samples = _resample(points, step)
        covered = [self._covered(piece, point, outward) for point in samples]
        distance = 0.0
        bottoms = []
        for n, point in enumerate(samples):
            if n:
                distance += (point - samples[n - 1]).length
            scallop = abs(math.sin(distance * math.pi / 1.2)) ** 0.6
            wander = noise2(distance * 0.15, 3.7, seed + 11)
            depth = depth_range[0] + (depth_range[1] - depth_range[0]) * (0.35 * scallop + 0.65 * wander)
            bottoms.append(point + outward * out - UP * depth)
        shade = [(1.0, 1.0, 1.0), (1.0, 1.0, 1.0), (0.8, 0.8, 0.8), (0.8, 0.8, 0.8)]
        for i in range(len(samples) - 1):
            if covered[i] or covered[i + 1]:
                continue
            corners = [samples[i], samples[i + 1], bottoms[i + 1], bottoms[i]]
            face = art_kit._orient((0, 1, 2, 3), corners, outward)
            self.batch(corners[0]).add((corners, [face]), material, colour=shade)

def _resample(points, step: float) -> list:
    """Points along the polyline `points`, at most `step` apart, including every corner."""
    result = [points[0]]
    for a, b in zip(points, points[1:]):
        count = max(1, math.ceil((b - a).length / step))
        result.extend(a.lerp(b, i / count) for i in range(1, count + 1))
    return result


def _shade(point: Vector) -> tuple:
    """A gentle brightness variation for large flat areas."""
    value = 0.9 + 0.1 * noise2(point.x * 0.09, point.z * 0.09, 7)
    return (value, value, value)


def _depth_shade(y: float, bottom: float) -> tuple:
    """Cliffs get a little darker toward the bottom, like ambient occlusion."""
    value = 0.72 + 0.28 * min(1.0, max(0.0, (y - bottom) / 8.0))
    return (value, value, value)
