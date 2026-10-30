"""Builds the stand-in Sonic model: mesh, rig and animations, saved as sonic.blend and sonic.glb.

Run it from the repository root (Blender 5.0 or newer):

    blender --background --factory-startup --python content/sonic/characters/sonic/build_sonic.py

The model is made of simple shapes, each bound rigidly to one bone, so the whole character
pipeline (Blender, glTF, Godot's AnimationTree) works before real art exists. A hand-made model
can replace it: keep the bone names, the animation names and the conventions below, and export
it with tools/blender/export_glb.py.

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


def rod(bone: str, colour: str, start, end, radius: float) -> bpy.types.Object:
    """A cylinder from `start` to `end`."""
    start, end = Vector(start), Vector(end)
    axis = end - start
    bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=radius, depth=axis.length, location=(start + end) / 2)
    obj = bpy.context.active_object
    obj.rotation_mode = 'QUATERNION'
    obj.rotation_quaternion = axis.to_track_quat('Z', 'Y')
    return finish_part(obj, bone, colour)


def spike(bone: str, colour: str, base, direction, radius: float, length: float) -> bpy.types.Object:
    """A cone whose base is centred at `base`, pointing along `direction`."""
    direction = Vector(direction).normalized()
    bpy.ops.mesh.primitive_cone_add(vertices=10, radius1=radius, radius2=0.0, depth=length, location=Vector(base) + direction * length / 2)
    obj = bpy.context.active_object
    obj.rotation_mode = 'QUATERNION'
    obj.rotation_quaternion = direction.to_track_quat('Z', 'Y')
    return finish_part(obj, bone, colour)


def build_mesh() -> bpy.types.Object:
    parts = []
    # Head: a big sphere with a muzzle, eyes, ears and quills sweeping back.
    parts.append(ellipsoid("head", "Blue", (0, 0, 0.78), (0.21, 0.21, 0.21), 24, 12))
    parts.append(ellipsoid("head", "Skin", (0, 0.15, 0.71), (0.11, 0.075, 0.07)))
    parts.append(ellipsoid("head", "Black", (0, 0.225, 0.745), (0.026, 0.024, 0.022), 10, 6))
    parts.append(ellipsoid("head", "White", (0, 0.155, 0.83), (0.12, 0.065, 0.085)))
    for sign in (-1, 1):
        parts.append(ellipsoid("head", "Green", (0.04 * sign, 0.212, 0.83), (0.024, 0.012, 0.032), 10, 6))
        parts.append(spike("head", "Blue", (0.10 * sign, -0.02, 0.93), (0.45 * sign, -0.15, 1.0), 0.05, 0.11))
    for base, direction, radius, length in (
        ((0, -0.10, 0.92), (0, -1.0, 0.45), 0.08, 0.30),
        ((-0.09, -0.12, 0.81), (-0.35, -1.0, 0.05), 0.085, 0.32),
        ((0.09, -0.12, 0.81), (0.35, -1.0, 0.05), 0.085, 0.32),
        ((0, -0.13, 0.80), (0, -1.0, 0.0), 0.09, 0.36),
        ((0, -0.12, 0.68), (0, -1.0, -0.40), 0.08, 0.30),
    ):
        parts.append(spike("head", "Blue", base, direction, radius, length))
    # Body, with a light belly, two small back quills and a stubby tail.
    parts.append(ellipsoid("chest", "Blue", (0, 0, 0.48), (0.125, 0.11, 0.135)))
    parts.append(ellipsoid("chest", "Skin", (0, 0.055, 0.465), (0.085, 0.07, 0.095)))
    parts.append(spike("chest", "Blue", (0, -0.09, 0.53), (0, -1.0, -0.5), 0.05, 0.14))
    parts.append(spike("hips", "Blue", (0, -0.09, 0.40), (0, -1.0, -0.2), 0.035, 0.10))
    for side, sign in (("L", -1), ("R", 1)):
        # Arms and gloves.
        parts.append(rod(f"upper_arm.{side}", "Skin", (0.11 * sign, 0, 0.58), (0.20 * sign, 0, 0.46), 0.03))
        parts.append(rod(f"forearm.{side}", "Skin", (0.20 * sign, 0, 0.46), (0.26 * sign, 0, 0.36), 0.03))
        parts.append(ellipsoid(f"hand.{side}", "White", (0.275 * sign, 0, 0.33), (0.055, 0.055, 0.055)))
        parts.append(rod(f"forearm.{side}", "White", (0.248 * sign, 0, 0.38), (0.262 * sign, 0, 0.358), 0.045))
        # Legs and shoes.
        parts.append(rod(f"thigh.{side}", "Blue", (0.07 * sign, 0, 0.40), (0.08 * sign, 0, 0.24), 0.035))
        parts.append(rod(f"shin.{side}", "Blue", (0.08 * sign, 0, 0.24), (0.09 * sign, 0, 0.10), 0.035))
        parts.append(ellipsoid(f"foot.{side}", "Red", (0.09 * sign, 0.04, 0.06), (0.07, 0.15, 0.065)))
        parts.append(ellipsoid(f"foot.{side}", "White", (0.09 * sign, 0.03, 0.10), (0.072, 0.03, 0.03), 12, 6))
        parts.append(ellipsoid(f"foot.{side}", "White", (0.09 * sign, -0.02, 0.012), (0.075, 0.13, 0.014), 12, 4))

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
