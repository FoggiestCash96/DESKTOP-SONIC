"""Shared helpers for art built by scripts in Blender: meshes made of simple shapes, materials by
name, deterministic noise and randomness, and the glTF export.

Everything is built in Godot's axes (Y up, -Z forward, 1 unit = 1 m), so positions can be copied
from a scene, and turned into Blender's Z-up axes only when the objects are made. The glTF export
turns them back, so Godot gets what was written.

Materials are named and given a colour. On import, engine/art/art_import.gd swaps a material for
the project's material of the same name if there is one (tuned in Godot), and otherwise gives it
the toon look in the colour set here, tinted by the vertex colours.

Small things are better painted: a Paint is a colour written into the vertex colours of one shared
material ("painted", or "painted_two_sided" for leaves and blades), so a whole chunk of plants,
rocks and posts draws in one go instead of one draw call per colour.
"""

import json
import math
import os
import random
import zlib

import bpy
from mathutils import Matrix, Vector

IMPORT_SCRIPT = "res://engine/art/art_import.gd"
NO_SHADOW = "_noshadow"  # A mesh whose name ends with this casts no shadow in the game.

# Colours as they should look on screen (sRGB), by material name.
_colours = {"painted": (1.0, 1.0, 1.0), "painted_two_sided": (1.0, 1.0, 1.0)}


def linear(colour) -> tuple:
    """An sRGB colour converted to linear light, with alpha 1."""
    return tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in colour[:3]) + (1.0,)


def define_material(name: str, colour) -> str:
    """Registers a material's colour and returns its name, for Batch.add()."""
    _colours[name] = tuple(colour)
    return name


def _material(name: str) -> bpy.types.Material:
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    colour = linear(_colours.get(name, (0.8, 0.8, 0.8)))
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = colour
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = colour
        bsdf.inputs["Roughness"].default_value = 0.6
    return mat


PAINTED = "painted"
PAINTED_TWO_SIDED = "painted_two_sided"  # A library material: the same, drawn from both sides.


class Paint(str):
    """A colour for Batch.add() that's painted into the vertex colours of a shared material."""

    def __new__(cls, colour, two_sided: bool = False):
        paint = str.__new__(cls, PAINTED_TWO_SIDED if two_sided else PAINTED)
        paint.colour = tuple(colour)
        return paint


def paint(colour, two_sided: bool = False) -> Paint:
    return Paint(colour, two_sided)


def to_blender(point) -> tuple:
    """A point in Godot's axes turned into Blender's."""
    return (point[0], -point[2], point[1])


# --- Randomness and noise ----------------------------------------------------------------------

def rng(*keys) -> random.Random:
    """A random generator seeded by the given keys, so a build gives the same result every time."""
    return random.Random(zlib.crc32(repr(keys).encode()))


def _hash(*ints) -> float:
    h = 2166136261
    for value in ints:
        h = ((h ^ (value & 0xFFFFFFFF)) * 16777619) & 0xFFFFFFFF
    h ^= h >> 15
    h = (h * 2246822519) & 0xFFFFFFFF
    h ^= h >> 13
    return h / 0xFFFFFFFF


def noise2(x: float, y: float, seed: int = 0) -> float:
    """Smooth value noise in 0..1."""
    ix, iy = math.floor(x), math.floor(y)
    fx, fy = x - ix, y - iy
    ux, uy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a = _hash(ix, iy, seed)
    b = _hash(ix + 1, iy, seed)
    c = _hash(ix, iy + 1, seed)
    d = _hash(ix + 1, iy + 1, seed)
    return (a + (b - a) * ux) + ((c + (d - c) * ux) - (a + (b - a) * ux)) * uy


def noise3(x: float, y: float, z: float, seed: int = 0) -> float:
    """Smooth value noise in 0..1, in 3D."""
    lower = noise2(x + 31.7 * math.floor(z), y, seed)
    upper = noise2(x + 31.7 * (math.floor(z) + 1), y, seed)
    fz = z - math.floor(z)
    return lower + (upper - lower) * fz * fz * (3 - 2 * fz)


# --- Shapes ------------------------------------------------------------------------------------
# Each returns (vertices, faces): Vectors and tuples of vertex indices, wound counter-clockwise
# seen from outside, so the normals face out.

def _orient(face: tuple, vertices: list, outward: Vector) -> tuple:
    a, b, c = (vertices[i] for i in face[:3])
    return face if (b - a).cross(c - a).dot(outward) >= 0 else tuple(reversed(face))


def _orient_convex(vertices: list, faces: list) -> list:
    centre = sum(vertices, Vector()) / len(vertices)
    result = []
    for face in faces:
        middle = sum((vertices[i] for i in face), Vector()) / len(face)
        result.append(_orient(face, vertices, middle - centre))
    return result


def box(size, centre=(0, 0, 0)) -> tuple:
    sx, sy, sz = (s / 2 for s in size)
    cx, cy, cz = centre
    vertices = [Vector((cx + x * sx, cy + y * sy, cz + z * sz)) for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)]
    faces = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    return vertices, _orient_convex(vertices, faces)


def lathe(profile, segments: int = 8, cap_bottom: bool = True, cap_top: bool = True) -> tuple:
    """A surface of revolution around +Y: `profile` is (radius, height) pairs from the bottom up."""
    vertices = []
    for radius, height in profile:
        for j in range(segments):
            angle = math.tau * j / segments
            vertices.append(Vector((radius * math.cos(angle), height, -radius * math.sin(angle))))
    faces = []
    for i in range(len(profile) - 1):
        for j in range(segments):
            k = (j + 1) % segments
            faces.append((i * segments + j, i * segments + k, (i + 1) * segments + k, (i + 1) * segments + j))
    if cap_bottom and profile[0][0] > 0:
        faces.append(tuple(reversed(range(segments))))
    if cap_top and profile[-1][0] > 0:
        last = (len(profile) - 1) * segments
        faces.append(tuple(range(last, last + segments)))
    return vertices, faces


def loft(rings, cap_bottom: bool = True, cap_top: bool = True) -> tuple:
    """A surface through outlines stacked up Y: each ring is (points, y), the points (x, z) going
    counter-clockwise seen from above, the same number in every ring."""
    count = len(rings[0][0])
    vertices = [Vector((x, y, z)) for points, y in rings for x, z in points]
    faces = []
    for i in range(len(rings) - 1):
        for j in range(count):
            k = (j + 1) % count
            faces.append((i * count + j, i * count + k, (i + 1) * count + k, (i + 1) * count + j))
    if cap_bottom:
        faces.append(tuple(reversed(range(count))))
    if cap_top:
        last = (len(rings) - 1) * count
        faces.append(tuple(range(last, last + count)))
    return vertices, faces


def rounded_rectangle(width: float, depth: float, radius: float, segments: int = 3) -> list:
    """Points (x, z) around a rectangle with rounded corners, counter-clockwise seen from above."""
    radius = min(radius, width / 2, depth / 2)
    points = []
    for quarter, (sx, sz) in enumerate(((1, -1), (-1, -1), (-1, 1), (1, 1))):
        cx, cz = sx * (width / 2 - radius), sz * (depth / 2 - radius)
        for i in range(segments + 1):
            angle = math.pi / 2 * (quarter + i / segments)
            points.append((cx + radius * math.cos(angle), cz - radius * math.sin(angle)))
    return points


def rounded_slab(width: float, depth: float, height: float, radius: float, bevel: float = 0.0, segments: int = 3) -> tuple:
    """A slab with rounded corners from y = 0 up to `height`, its top edge bevelled by `bevel`."""
    outline = rounded_rectangle(width, depth, radius, segments)
    rings = [(outline, 0.0)]
    if bevel > 0:
        rings.append((outline, height - bevel))
        rings.append((rounded_rectangle(width - 2 * bevel, depth - 2 * bevel, max(radius - bevel, 0.001), segments), height))
    else:
        rings.append((outline, height))
    return loft(rings)


def star_prism(points: int, outer: float, inner: float, thickness: float) -> tuple:
    """A flat star facing +Z, `thickness` deep, centred on the origin."""
    outline = []
    for i in range(points * 2):
        angle = math.pi / 2 + math.pi * i / points
        radius = outer if i % 2 == 0 else inner
        outline.append((radius * math.cos(angle), radius * math.sin(angle)))
    count = len(outline)
    vertices = [Vector((x, y, thickness / 2)) for x, y in outline] + [Vector((x, y, -thickness / 2)) for x, y in outline]
    vertices += [Vector((0, 0, thickness / 2)), Vector((0, 0, -thickness / 2))]
    front, back = 2 * count, 2 * count + 1
    faces = []
    for i in range(count):
        j = (i + 1) % count
        faces.append(_orient((front, i, j), vertices, Vector((0, 0, 1))))
        faces.append(_orient((back, count + j, count + i), vertices, Vector((0, 0, -1))))
        side = (vertices[i] + vertices[j]) / 2
        faces.append(_orient((i, count + i, count + j, j), vertices, Vector((side.x, side.y, 0))))
    return vertices, faces


def cylinder(radius: float, height: float, segments: int = 8, top_radius: float = None) -> tuple:
    """A cylinder (or a cone's frustum) standing on the origin along +Y."""
    return lathe([(radius, 0.0), (radius if top_radius is None else top_radius, height)], segments)


def sphere(radius: float = 1.0, segments: int = 12, rings: int = 6) -> tuple:
    vertices = [Vector((0, -radius, 0))]
    for i in range(1, rings):
        polar = math.pi * i / rings
        for j in range(segments):
            angle = math.tau * j / segments
            vertices.append(Vector((radius * math.sin(polar) * math.cos(angle), -radius * math.cos(polar), -radius * math.sin(polar) * math.sin(angle))))
    vertices.append(Vector((0, radius, 0)))
    top = len(vertices) - 1
    faces = []
    for j in range(segments):
        k = (j + 1) % segments
        faces.append((0, 1 + k, 1 + j))
        faces.append((top, top - segments + j, top - segments + k))
    for i in range(rings - 2):
        for j in range(segments):
            k = (j + 1) % segments
            a, b = 1 + i * segments + j, 1 + i * segments + k
            faces.append((a, b, b + segments, a + segments))
    return vertices, _orient_convex(vertices, faces)


def blob(radius: float, roughness: float, seed: int, segments: int = 10, rings: int = 6, squash=(1, 1, 1)) -> tuple:
    """A lumpy sphere, for rocks and bushes."""
    vertices, faces = sphere(1.0, segments, rings)
    shaped = []
    for v in vertices:
        lump = 1.0 + roughness * (noise3(v.x * 1.7 + 5, v.y * 1.7 + 5, v.z * 1.7 + 5, seed) - 0.5) * 2
        shaped.append(Vector((v.x * squash[0], v.y * squash[1], v.z * squash[2])) * radius * lump)
    return shaped, faces


def tube(path, radii, segments: int = 6, cap_end: bool = True) -> tuple:
    """A tube along the points of `path`, as thick as `radii` at each point."""
    path = [Vector(p) for p in path]
    vertices = []
    normal = None
    for i, point in enumerate(path):
        before = path[max(i - 1, 0)]
        after = path[min(i + 1, len(path) - 1)]
        tangent = (after - before).normalized()
        if normal is None:
            helper = Vector((0, 0, 1)) if abs(tangent.z) < 0.9 else Vector((1, 0, 0))
            normal = tangent.cross(helper).normalized()
        else:
            normal = (normal - tangent * normal.dot(tangent)).normalized()
        binormal = tangent.cross(normal)
        for j in range(segments):
            angle = math.tau * j / segments
            vertices.append(point + (normal * math.cos(angle) + binormal * math.sin(angle)) * radii[i])
    faces = []
    for i in range(len(path) - 1):
        for j in range(segments):
            k = (j + 1) % segments
            face = (i * segments + j, i * segments + k, (i + 1) * segments + k, (i + 1) * segments + j)
            middle = (path[i] + path[i + 1]) / 2
            faces.append(_orient(face, vertices, vertices[i * segments + j] - middle))
    if cap_end:
        last = (len(path) - 1) * segments
        faces.append(_orient(tuple(range(last, last + segments)), vertices, path[-1] - path[-2]))
    return vertices, faces


def matrix_from(transform: dict) -> Matrix:
    """A transform as tools/godot's exporters write it: basis columns and origin."""
    x, y, z, origin = (Vector(transform[key]) for key in ("x", "y", "z", "origin"))
    return Matrix(((x.x, y.x, z.x, origin.x), (x.y, y.y, z.y, origin.y), (x.z, y.z, z.z, origin.z), (0, 0, 0, 1)))


def transformed(shape: tuple, matrix: Matrix) -> tuple:
    vertices, faces = shape
    return [matrix @ v for v in vertices], faces


def placement(position, yaw: float = 0.0, scale=1.0, tilt=(0.0, 0.0)) -> Matrix:
    """A transform that tilts (around X, then Z), turns by `yaw` around Y, and moves to `position`."""
    if not isinstance(scale, (tuple, list)):
        scale = (scale, scale, scale)
    rotation = Matrix.Rotation(yaw, 4, 'Y') @ Matrix.Rotation(tilt[1], 4, 'Z') @ Matrix.Rotation(tilt[0], 4, 'X')
    return Matrix.Translation(Vector(position)) @ rotation @ Matrix.Diagonal((*scale, 1.0))


# --- Meshes ------------------------------------------------------------------------------------

class Batch:
    """Faces gathered for one mesh object, each with a material, UVs and colours."""

    def __init__(self, name: str):
        self.name = name
        self.positions = []
        self.colours = []
        self.faces = []
        self.face_materials = []
        self.face_smooth = []
        self.uvs = []  # one (u, v) per face corner, in face order
        self.materials = []

    def add(self, shape: tuple, material: str, smooth: bool = False, colour=(1, 1, 1), uvs=None) -> None:
        """Adds a shape. `colour` is one tint or one per vertex; `uvs` is one (u, v) per face corner."""
        vertices, faces = shape
        start = len(self.positions)
        self.positions.extend(vertices)
        colours = list(colour) if isinstance(colour[0], (tuple, list)) else [colour] * len(vertices)
        if isinstance(material, Paint):
            colours = [tuple(a * b for a, b in zip(c, material.colour)) for c in colours]
            material = str(material)
        self.colours.extend(colours)
        if material not in self.materials:
            self.materials.append(material)
        index = self.materials.index(material)
        for n, face in enumerate(faces):
            self.faces.append(tuple(start + i for i in face))
            self.face_materials.append(index)
            self.face_smooth.append(smooth)
            self.uvs.extend(uvs[n] if uvs else [(0.0, 0.0)] * len(face))

    def __len__(self) -> int:
        return len(self.faces)

    def triangles(self) -> int:
        return sum(len(face) - 2 for face in self.faces)

    def build(self, collection=None) -> bpy.types.Object:
        mesh = bpy.data.meshes.new(self.name)
        mesh.from_pydata([to_blender(p) for p in self.positions], [], self.faces)
        for name in self.materials:
            mesh.materials.append(_material(name))
        mesh.polygons.foreach_set("material_index", self.face_materials)
        sharp = mesh.attributes.get("sharp_face") or mesh.attributes.new("sharp_face", 'BOOLEAN', 'FACE')
        sharp.data.foreach_set("value", [not smooth for smooth in self.face_smooth])
        layer = mesh.uv_layers.new(name="UVMap")
        layer.data.foreach_set("uv", [value for uv in self.uvs for value in uv])
        colours = mesh.color_attributes.new("Color", 'FLOAT_COLOR', 'CORNER')
        flat = []
        for face in self.faces:
            for index in face:
                flat.extend(linear(self.colours[index]))
        colours.data.foreach_set("color", flat)
        mesh.color_attributes.active_color = colours
        mesh.color_attributes.render_color_index = mesh.color_attributes.active_color_index
        mesh.validate(clean_customdata=False)
        mesh.update()
        obj = bpy.data.objects.new(self.name, mesh)
        (collection or bpy.context.scene.collection).objects.link(obj)
        return obj


class Parts:
    """A model that dresses the nodes of a scene (see engine/art/model_skin.gd), from the layout
    tools/godot/export_parts.gd writes. Parts are built in the scene's space, where the layout says
    each node is; on export each one moves into the space of the node it dresses (or, for a new
    part, the node it goes under) and is named after it, with "__" for "/"."""

    def __init__(self, layout_path: str, root: str = ""):
        """`root` is the node the model dresses, if not the scene's root: paths are then relative to it."""
        with open(layout_path, encoding="utf-8") as file:
            self.nodes = {node["path"]: node for node in json.load(file)["nodes"]}
        self.root = root
        self.parts = {}
        self.hidden = []

    def _full(self, path: str) -> str:
        return f"{self.root}/{path}" if self.root else path

    def frame(self, path: str) -> Matrix:
        return matrix_from(self.nodes[self._full(path)]["transform"])

    def origin(self, path: str) -> Vector:
        return self.frame(path).translation

    def info(self, path: str) -> dict:
        return self.nodes[self._full(path)].get("mesh", {})

    def part(self, path: str) -> "Batch":
        if path not in self.parts:
            self.parts[path] = Batch(path.replace("/", "__"))
        return self.parts[path]

    def hide(self, path: str) -> None:
        """Hides a placeholder the model has no part for."""
        self.hidden.append(path)

    def export(self, glb_path: str) -> None:
        reset_scene()
        triangles = 0
        for path, batch in self.parts.items():
            owner = self._full(path)
            while owner not in self.nodes and "/" in owner:
                owner = owner.rsplit("/", 1)[0]
            inverse = matrix_from(self.nodes[owner]["transform"]).inverted() if owner in self.nodes else Matrix.Identity(4)
            batch.positions = [inverse @ p for p in batch.positions]
            batch.build()
            triangles += batch.triangles()
        for path in self.hidden:
            bpy.context.scene.collection.objects.link(bpy.data.objects.new(path.replace("/", "__"), None))
        export_glb(glb_path)
        print(f"exported {os.path.basename(glb_path)}: {len(self.parts)} parts, {triangles} triangles")


def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def export_glb(path: str, animations: bool = False) -> None:
    """Exports the scene as a .glb with vertex colours, and makes sure Godot imports it with the
    art import script (a new .glb gets a .glb.import file naming it; Godot fills in the rest)."""
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format='GLB',
        export_yup=True,
        export_apply=True,
        export_materials='EXPORT',
        export_vertex_color='ACTIVE',
        export_animations=animations,
        export_extras=False,
    )
    import_file = path + ".import"
    if not os.path.exists(import_file):
        with open(import_file, "w", encoding="utf-8", newline="\n") as file:
            file.write('[remap]\n\nimporter="scene"\nimporter_version=1\ntype="PackedScene"\n\n'
                       f'[params]\n\nimport_script/path="{IMPORT_SCRIPT}"\n')
