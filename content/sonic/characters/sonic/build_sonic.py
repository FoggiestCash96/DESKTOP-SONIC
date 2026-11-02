"""Builds the Sonic model: mesh, rig and animations, saved as sonic.blend and sonic.glb.

Run it from the repository root (Blender 5.0 or newer):

    blender --background --factory-startup --python content/sonic/characters/sonic/build_sonic.py

The fur (head, quills, ears, body, arms and legs) is one smooth surface, skinned so the joints
bend; the eyes, nose, gloves and shoes are separate pieces, each moving with one bone. Everything
is made from simple shapes in code (see build_fur), so it can be tweaked and rebuilt. A hand-made
model can replace it: keep the bone names, the animation names and the conventions below, and
export it with tools/blender/export_glb.py.

Conventions: 1 unit = 1 m, feet at the origin, facing +Y in Blender (which becomes Godot's -Z),
about 1 m tall to match the player's collision capsule.
"""

import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.append(os.path.join(HERE, "..", "..", "..", "..", "tools", "blender"))
from export_glb import export_glb  # noqa: E402

FPS = 30

# Colours as they should look on screen (sRGB); material() converts them to Blender's linear values.
COLOURS = {
    "Blue": (0.07, 0.27, 0.85),
    "Skin": (0.96, 0.78, 0.60),
    "White": (0.96, 0.96, 0.96),
    "Red": (0.86, 0.10, 0.10),
    "Black": (0.04, 0.04, 0.05),
    "Green": (0.10, 0.65, 0.25),
    "Gold": (1.0, 0.75, 0.15),
}


def linear(colour) -> tuple:
    """An sRGB colour converted to linear light, with alpha 1."""
    return tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in colour) + (1.0,)

# name: (head, tail, parent, roll axis). Every bone's local X axis points along world +X, so a
# positive X rotation swings a hanging limb forward and leans an upright bone back.
UP_ROLL = (0, -1, 0)
DOWN_ROLL = (0, 1, 0)
FORWARD_ROLL = (0, 0, 1)
BONES = {
    "root": ((0, 0, 0.30), (0, 0, 0.40), None, UP_ROLL),
    "hips": ((0, 0, 0.40), (0, 0, 0.52), "root", UP_ROLL),
    "chest": ((0, 0, 0.52), (0, 0, 0.62), "hips", UP_ROLL),
    "head": ((0, 0, 0.62), (0, 0, 0.98), "chest", UP_ROLL),
}
for side, sign in (("L", -1), ("R", 1)):  # The character's left is -X, since it faces +Y.
    BONES[f"upper_arm.{side}"] = ((0.11 * sign, 0, 0.58), (0.20 * sign, 0, 0.46), "chest", DOWN_ROLL)
    BONES[f"forearm.{side}"] = ((0.20 * sign, 0, 0.46), (0.26 * sign, 0, 0.36), f"upper_arm.{side}", DOWN_ROLL)
    BONES[f"hand.{side}"] = ((0.26 * sign, 0, 0.36), (0.29 * sign, 0, 0.30), f"forearm.{side}", DOWN_ROLL)
    BONES[f"thigh.{side}"] = ((0.07 * sign, 0, 0.40), (0.08 * sign, 0, 0.24), "hips", DOWN_ROLL)
    BONES[f"shin.{side}"] = ((0.08 * sign, 0, 0.24), (0.09 * sign, 0, 0.10), f"thigh.{side}", DOWN_ROLL)
    BONES[f"foot.{side}"] = ((0.09 * sign, 0, 0.10), (0.09 * sign, 0.14, 0.05), f"shin.{side}", FORWARD_ROLL)


def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS


def material(name: str) -> bpy.types.Material:
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = linear(COLOURS[name])
    bsdf = mat.node_tree.nodes.get("Principled BSDF") if mat.node_tree else None
    if bsdf:
        bsdf.inputs["Base Color"].default_value = linear(COLOURS[name])
        bsdf.inputs["Roughness"].default_value = 0.6
    return mat


def finish_part(obj: bpy.types.Object, bone: str, colour: str) -> bpy.types.Object:
    obj.data.materials.append(material(colour))
    group = obj.vertex_groups.new(name=bone)
    group.add(range(len(obj.data.vertices)), 1.0, 'REPLACE')
    return obj


def ellipsoid(bone: str, colour: str, centre, size, segments: int = 16, rings: int = 8) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=1.0, location=centre)
    obj = bpy.context.active_object
    obj.scale = size
    return finish_part(obj, bone, colour)


def tube_mesh(points, radii, segments: int = 12) -> bpy.types.Object:
    """A closed tube through `points`, as thick as `radii` at each, as a new object."""
    points = [Vector(p) for p in points]
    vertices, faces = [], []
    normal = None
    for i, point in enumerate(points):
        tangent = (points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]).normalized()
        if normal is None:
            helper = Vector((0, 0, 1)) if abs(tangent.z) < 0.9 else Vector((1, 0, 0))
            normal = tangent.cross(helper).normalized()
        else:
            normal = (normal - tangent * normal.dot(tangent)).normalized()
        binormal = tangent.cross(normal)
        for j in range(segments):
            angle = math.tau * j / segments
            vertices.append(point + (normal * math.cos(angle) + binormal * math.sin(angle)) * max(radii[i], 0.001))
    for i in range(len(points) - 1):
        for j in range(segments):
            k = (j + 1) % segments
            faces.append((i * segments + j, i * segments + k, (i + 1) * segments + k, (i + 1) * segments + j))
    faces.append(tuple(reversed(range(segments))))
    last = (len(points) - 1) * segments
    faces.append(tuple(range(last, last + segments)))
    mesh = bpy.data.meshes.new("tube")
    mesh.from_pydata([tuple(v) for v in vertices], [], faces)
    mesh.update()
    obj = bpy.data.objects.new("tube", mesh)
    bpy.context.collection.objects.link(obj)
    # Make the faces point outward, whichever way the frames turned.
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    return obj


def tube(bone: str, colour: str, points, radii, segments: int = 12) -> bpy.types.Object:
    return finish_part(tube_mesh(points, radii, segments), bone, colour)


# --- The fur ---------------------------------------------------------------------------------------
# The blue and tan fur is one surface. Simple shapes, each with a colour and a bone, are fused by a
# voxel remesh and trimmed to the triangle budget; then every face takes the colour of the shape it
# lies on, and every vertex is skinned to the bones of the shapes near it, so the body bends
# smoothly at the joints instead of coming apart.

FUR_VOXEL = 0.0075  # m: fine enough for the thin arms.
FUR_FACES = 9000  # The fur's budget after trimming.
SKIN_BLEND = 0.035  # m: how far past its own shape a bone still pulls on the fur.


class Shape:
    """A shape of the fur: its colour, its bone, and its signed distance (negative inside)."""

    def __init__(self, colour: str, bone: str, kind: str, *params):
        self.colour, self.bone, self.kind, self.params = colour, bone, kind, params

    def make(self) -> bpy.types.Object:
        if self.kind == "ellipsoid":
            centre, size = self.params
            bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=1.0, location=centre)
            obj = bpy.context.active_object
            obj.scale = size
            return obj
        points, radii = self.params
        return tube_mesh(points, radii, 14)

    def distance(self, point: Vector) -> float:
        if self.kind == "ellipsoid":
            centre, size = self.params
            q = Vector(((point.x - centre[0]) / size[0], (point.y - centre[1]) / size[1], (point.z - centre[2]) / size[2]))
            return (q.length - 1.0) * min(size)
        points, radii = self.params
        best = math.inf
        for i in range(len(points) - 1):
            a, b = Vector(points[i]), Vector(points[i + 1])
            ab = b - a
            t = max(0.0, min(1.0, (point - a).dot(ab) / max(ab.length_squared, 1e-9)))
            best = min(best, (point - (a + ab * t)).length - (radii[i] + (radii[i + 1] - radii[i]) * t))
        return best


def fur_shapes() -> list:
    shapes = [
        Shape("Blue", "head", "ellipsoid", (0, 0, 0.78), (0.205, 0.2, 0.2)),
        Shape("Skin", "head", "ellipsoid", (0, 0.145, 0.705), (0.105, 0.082, 0.072)),
        # Quills sweeping back from the head, curving as they go.
        Shape("Blue", "head", "tube", [(0, -0.09, 0.93), (0, -0.21, 0.98), (0, -0.34, 0.96)], [0.085, 0.058, 0.004]),
        Shape("Blue", "head", "tube", [(0, -0.15, 0.80), (0, -0.29, 0.79), (0, -0.44, 0.74)], [0.09, 0.06, 0.004]),
        Shape("Blue", "head", "tube", [(0, -0.12, 0.66), (0, -0.22, 0.60), (0, -0.32, 0.53)], [0.07, 0.045, 0.004]),
        Shape("Blue", "chest", "ellipsoid", (0, 0, 0.47), (0.125, 0.11, 0.14)),
        Shape("Blue", "chest", "ellipsoid", (0, -0.005, 0.585), (0.078, 0.072, 0.06)),
        Shape("Skin", "chest", "ellipsoid", (0, 0.05, 0.455), (0.088, 0.075, 0.1)),
        Shape("Blue", "hips", "ellipsoid", (0, 0, 0.405), (0.112, 0.095, 0.075)),
        Shape("Blue", "hips", "tube", [(0, -0.09, 0.39), (0, -0.16, 0.37)], [0.03, 0.005]),
    ]
    for side, sign in (("L", -1), ("R", 1)):
        shapes += [
            Shape("Blue", "head", "tube", [(0.09 * sign, -0.01, 0.94), (0.165 * sign, -0.05, 1.065)], [0.052, 0.004]),
            Shape("Blue", "head", "tube", [(0.1 * sign, -0.11, 0.86), (0.18 * sign, -0.23, 0.87), (0.25 * sign, -0.34, 0.83)], [0.08, 0.054, 0.004]),
            Shape("Blue", "head", "tube", [(0.08 * sign, -0.13, 0.71), (0.145 * sign, -0.24, 0.67), (0.2 * sign, -0.33, 0.61)], [0.072, 0.048, 0.004]),
            Shape("Blue", "chest", "tube", [(0.045 * sign, -0.09, 0.52), (0.065 * sign, -0.17, 0.48), (0.085 * sign, -0.22, 0.43)], [0.04, 0.025, 0.004]),
            Shape("Skin", f"upper_arm.{side}", "tube", [(0.10 * sign, 0, 0.575), (0.20 * sign, 0, 0.46)], [0.034, 0.03]),
            Shape("Skin", f"forearm.{side}", "tube", [(0.20 * sign, 0, 0.46), (0.255 * sign, 0, 0.37)], [0.03, 0.028]),
            Shape("Blue", f"thigh.{side}", "tube", [(0.07 * sign, 0, 0.40), (0.08 * sign, 0, 0.24)], [0.042, 0.035]),
            Shape("Blue", f"shin.{side}", "tube", [(0.08 * sign, 0, 0.24), (0.09 * sign, 0, 0.11)], [0.035, 0.031]),
        ]
    return shapes


def apply_modifier(obj: bpy.types.Object, kind: str, **settings) -> None:
    modifier = obj.modifiers.new(kind, kind)
    for key, value in settings.items():
        setattr(modifier, key, value)
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=modifier.name)


def build_fur() -> bpy.types.Object:
    shapes = fur_shapes()
    objects = [shape.make() for shape in shapes]
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    fur = bpy.context.active_object
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    apply_modifier(fur, 'REMESH', mode='VOXEL', voxel_size=FUR_VOXEL, adaptivity=0.0)
    apply_modifier(fur, 'SMOOTH', factor=0.5, iterations=3)
    apply_modifier(fur, 'DECIMATE', ratio=min(1.0, FUR_FACES / max(len(fur.data.polygons), 1)))
    # Each face takes the colour of the shape it lies on.
    fur.data.materials.clear()
    colours = sorted({shape.colour for shape in shapes})
    for colour in colours:
        fur.data.materials.append(material(colour))
    for polygon in fur.data.polygons:
        centre = Vector(polygon.center)
        nearest = min(shapes, key=lambda shape: shape.distance(centre))
        polygon.material_index = colours.index(nearest.colour)
    # Each vertex follows the bones of the shapes within SKIN_BLEND of the nearest one.
    groups = {bone: fur.vertex_groups.new(name=bone) for bone in sorted({shape.bone for shape in shapes})}
    for vertex in fur.data.vertices:
        distances = [shape.distance(vertex.co) for shape in shapes]
        closest = min(distances)
        weights = {}
        for shape, distance in zip(shapes, distances):
            pull = SKIN_BLEND - (distance - closest)
            if pull > 0:
                weights[shape.bone] = weights.get(shape.bone, 0.0) + pull
        total = sum(weights.values())
        for bone, weight in weights.items():
            groups[bone].add([vertex.index], weight / total, 'REPLACE')
    return fur


def build_mesh() -> bpy.types.Object:
    parts = [build_fur()]
    # Eyes: one white mask with two green irises looking slightly inward, pupils and glints.
    for sign in (-1, 1):
        parts.append(ellipsoid("head", "White", (0.047 * sign, 0.158, 0.835), (0.066, 0.044, 0.088), 20, 10))
        parts.append(ellipsoid("head", "Green", (0.041 * sign, 0.197, 0.832), (0.028, 0.012, 0.04), 12, 6))
        parts.append(ellipsoid("head", "Black", (0.039 * sign, 0.205, 0.834), (0.014, 0.008, 0.022), 10, 5))
        parts.append(ellipsoid("head", "White", (0.032 * sign, 0.21, 0.85), (0.006, 0.004, 0.008), 8, 4))
        # Inner ears, tan, in front of each ear.
        parts.append(tube("head", "Skin", [(0.09 * sign, 0.012, 0.95), (0.155 * sign, -0.022, 1.045)], [0.03, 0.003], 10))
    parts.append(ellipsoid("head", "Black", (0, 0.222, 0.745), (0.028, 0.024, 0.022), 12, 6))
    for side, sign in (("L", -1), ("R", 1)):
        # Gloves: a white fist with a thumb, and a wide cuff around the wrist.
        parts.append(ellipsoid(f"hand.{side}", "White", (0.272 * sign, 0.0, 0.33), (0.058, 0.055, 0.062)))
        parts.append(ellipsoid(f"hand.{side}", "White", (0.25 * sign, 0.045, 0.348), (0.022, 0.026, 0.02), 10, 6))
        parts.append(tube(f"forearm.{side}", "White", [(0.247 * sign, 0, 0.388), (0.262 * sign, 0, 0.356)], [0.047, 0.05]))
        # Shoes: red with an upturned toe, a white strap with a gold buckle, a white sole and a sock cuff.
        parts.append(ellipsoid(f"foot.{side}", "Red", (0.09 * sign, 0.05, 0.065), (0.072, 0.155, 0.068)))
        parts.append(ellipsoid(f"foot.{side}", "Red", (0.09 * sign, 0.15, 0.072), (0.06, 0.07, 0.056)))
        parts.append(ellipsoid(f"foot.{side}", "White", (0.09 * sign, 0.03, 0.112), (0.076, 0.036, 0.03), 16, 8))
        parts.append(ellipsoid(f"foot.{side}", "Gold", (0.158 * sign, 0.03, 0.098), (0.012, 0.028, 0.022), 8, 5))
        parts.append(ellipsoid(f"foot.{side}", "White", (0.09 * sign, 0.04, 0.015), (0.078, 0.166, 0.017), 16, 6))
        parts.append(tube(f"foot.{side}", "White", [(0.09 * sign, 0, 0.13), (0.09 * sign, 0, 0.095)], [0.04, 0.045]))

    bpy.ops.object.select_all(action='DESELECT')
    for part in parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    body = bpy.context.active_object
    body.name = "SonicBody"
    body.data.name = "SonicBody"
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.shade_smooth()
    return body


def build_rig() -> bpy.types.Object:
    data = bpy.data.armatures.new("SonicRig")
    rig = bpy.data.objects.new("SonicRig", data)
    bpy.context.collection.objects.link(rig)
    bpy.ops.object.select_all(action='DESELECT')
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode='EDIT')
    for name, (head, tail, parent, roll) in BONES.items():
        bone = data.edit_bones.new(name)
        bone.head = head
        bone.tail = tail
        bone.align_roll(Vector(roll))
        if parent:
            bone.parent = data.edit_bones[parent]
    bpy.ops.object.mode_set(mode='OBJECT')
    for pose_bone in rig.pose.bones:
        pose_bone.rotation_mode = 'XYZ'
    return rig


def bind(body: bpy.types.Object, rig: bpy.types.Object) -> None:
    body.parent = rig
    modifier = body.modifiers.new("Armature", 'ARMATURE')
    modifier.object = rig


# --- Animations -----------------------------------------------------------------------------
# Each pose maps bones to Euler rotations in degrees (bone-local X, Y, Z). Bones a pose leaves out
# go back to rest, so every action fully defines the character.

def mirror(pose: dict) -> dict:
    """The same pose with left and right swapped (for the second half of a stride)."""
    flipped = {}
    for name, (x, y, z) in pose.items():
        if name.endswith(".L"):
            flipped[name[:-2] + ".R"] = (x, -y, -z)
        elif name.endswith(".R"):
            flipped[name[:-2] + ".L"] = (x, -y, -z)
        else:
            flipped[name] = (x, -y, -z)
    return flipped


def stride(thigh: float, shin: float, arm: float, forearm: float, lean: float, head: float = 0.0) -> dict:
    """The left leg forward and right arm forward, half a running or walking cycle."""
    return {
        "chest": (-lean, 0, 0), "head": (head + lean * 0.5, 0, 0),
        "thigh.L": (thigh, 0, 0), "shin.L": (-shin * 0.2, 0, 0),
        "thigh.R": (-thigh, 0, 0), "shin.R": (-shin, 0, 0),
        "upper_arm.L": (-arm, 0, 8), "forearm.L": (forearm, 0, 0),
        "upper_arm.R": (arm, 0, -8), "forearm.R": (forearm, 0, 0),
    }


def cycle(frames: int, half: dict) -> list:
    """A looping cycle: `half`, its mirror half way through, and `half` again at the end."""
    return [(1, half), (1 + frames // 2, mirror(half)), (1 + frames, half)]


def hold(pose: dict, frames: int = 10) -> list:
    return [(1, pose), (1 + frames, pose)]


CURLED = {
    "chest": (-55, 0, 0), "head": (-45, 0, 0),
    "thigh.L": (110, 0, 0), "shin.L": (-130, 0, 0), "thigh.R": (110, 0, 0), "shin.R": (-130, 0, 0),
    "upper_arm.L": (75, 0, -20), "forearm.L": (90, 0, 0), "upper_arm.R": (75, 0, 20), "forearm.R": (90, 0, 0),
}

ANIMATIONS = {
    "idle": [
        (1, {"upper_arm.L": (0, 0, 6), "upper_arm.R": (0, 0, -6)}),
        (31, {"chest": (-3, 0, 0), "head": (3, 0, 0), "upper_arm.L": (4, 0, 9), "upper_arm.R": (4, 0, -9)}),
        (61, {"upper_arm.L": (0, 0, 6), "upper_arm.R": (0, 0, -6)}),
    ],
    "walk": cycle(32, stride(25, 35, 20, 15, 4)),
    "jog": cycle(24, stride(40, 60, 35, 35, 10)),
    "run": cycle(16, stride(55, 95, 50, 60, 16, 8)),
    "max_run": cycle(12, {
        "chest": (-26, 0, 0), "head": (20, 0, 0),
        "thigh.L": (75, 0, 0), "shin.L": (-40, 0, 0), "thigh.R": (-60, 0, 0), "shin.R": (-110, 0, 0),
        "upper_arm.L": (-65, 0, 10), "forearm.L": (15, 0, 0), "upper_arm.R": (-65, 0, -10), "forearm.R": (15, 0, 0),
    }),
    "skid": hold({
        "chest": (18, 0, 0), "head": (-6, 0, 0),
        "thigh.L": (50, 0, 0), "shin.L": (-5, 0, 0), "foot.L": (25, 0, 0), "thigh.R": (-15, 0, 0), "shin.R": (-45, 0, 0),
        "upper_arm.L": (35, 0, 40), "upper_arm.R": (35, 0, -40),
    }),
    "ball": [(1, dict(CURLED, root=(0, 0, 0))), (16, dict(CURLED, root=(-360, 0, 0)))],
    "spring": hold({
        "chest": (6, 0, 0), "head": (12, 0, 0),
        "upper_arm.L": (165, 0, 10), "upper_arm.R": (165, 0, -10),
        "thigh.L": (-5, 0, 0), "thigh.R": (5, 0, 0), "foot.L": (-30, 0, 0), "foot.R": (-30, 0, 0),
    }),
    "fall": cycle(20, {
        "chest": (5, 0, 0),
        "upper_arm.L": (20, 0, 70), "forearm.L": (30, 0, 0), "upper_arm.R": (-10, 0, -95), "forearm.R": (10, 0, 0),
        "thigh.L": (25, 0, 0), "shin.L": (-40, 0, 0), "thigh.R": (-10, 0, 0), "shin.R": (-20, 0, 0),
    }),
    "push": cycle(24, {
        "chest": (-32, 0, 0), "head": (18, 0, 0),
        "upper_arm.L": (85, 0, 10), "forearm.L": (10, 0, 0), "upper_arm.R": (85, 0, -10), "forearm.R": (10, 0, 0),
        "thigh.L": (25, 0, 0), "shin.L": (-30, 0, 0), "thigh.R": (-30, 0, 0), "shin.R": (-20, 0, 0),
    }),
    "hurt": hold({
        "chest": (28, 0, 0), "head": (22, 0, 0),
        "upper_arm.L": (55, 0, 55), "upper_arm.R": (55, 0, -55),
        "thigh.L": (25, 0, 0), "shin.L": (-25, 0, 0), "thigh.R": (10, 0, 0), "shin.R": (-35, 0, 0),
    }),
    "death": hold({
        "chest": (22, 0, 0), "head": (32, 0, 0),
        "upper_arm.L": (40, 0, 125), "upper_arm.R": (40, 0, -125),
        "thigh.L": (15, 0, 25), "thigh.R": (15, 0, -25),
    }),
    "victory": [
        (1, {"upper_arm.R": (160, 0, -15), "forearm.R": (-10, 0, 0), "upper_arm.L": (-10, 0, 25), "forearm.L": (60, 0, 0), "head": (6, 0, 0)}),
        (16, {"upper_arm.R": (168, 0, -10), "forearm.R": (-15, 0, 0), "upper_arm.L": (-10, 0, 25), "forearm.L": (60, 0, 0), "head": (8, 0, 4)}),
        (31, {"upper_arm.R": (160, 0, -15), "forearm.R": (-10, 0, 0), "upper_arm.L": (-10, 0, 25), "forearm.L": (60, 0, 0), "head": (6, 0, 0)}),
    ],
}


def animate(rig: bpy.types.Object) -> None:
    rig.animation_data_create()
    preferences = bpy.context.preferences.edit
    for name, keys in ANIMATIONS.items():
        action = bpy.data.actions.new(name)
        action.use_fake_user = True
        rig.animation_data.action = action
        # The ball spins at a steady rate; everything else eases between poses.
        preferences.keyframe_new_interpolation_type = 'LINEAR' if name == "ball" else 'BEZIER'
        for frame, pose in keys:
            for bone_name in BONES:
                pose_bone = rig.pose.bones[bone_name]
                pose_bone.rotation_euler = [math.radians(angle) for angle in pose.get(bone_name, (0, 0, 0))]
                pose_bone.keyframe_insert("rotation_euler", frame=frame)
    rig.animation_data.action = None
    for pose_bone in rig.pose.bones:
        pose_bone.rotation_euler = (0, 0, 0)


def main() -> None:
    reset_scene()
    body = build_mesh()
    rig = build_rig()
    bind(body, rig)
    animate(rig)
    triangles = sum(len(polygon.vertices) - 2 for polygon in body.data.polygons)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "sonic.blend"))
    export_glb(os.path.join(HERE, "sonic.glb"))
    print(f"built sonic.blend and sonic.glb: {triangles} triangles, {len(BONES)} bones, {len(ANIMATIONS)} animations")


main()
