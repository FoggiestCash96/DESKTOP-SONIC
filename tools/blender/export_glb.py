"""Exports the open .blend file as a .glb with the project's settings.

Run it on a character's .blend from the repository root:

    blender path/to/model.blend --background --python tools/blender/export_glb.py -- path/to/model.glb

The settings match docs/DESIGN.md (character pipeline): binary glTF, +Y up, skins kept (the
Armature modifier is not applied), and every action exported as its own animation, named as the
action is named.
"""

import sys

import bpy


def export_glb(path: str) -> None:
    """Exports the whole scene to `path` with the project's glTF settings."""
    for obj in bpy.data.objects:
        # Export each action on its own, not whatever happens to be playing.
        if obj.animation_data:
            obj.animation_data.action = None
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format='GLB',
        export_yup=True,
        export_apply=False,
        export_skins=True,
        export_def_bones=False,
        export_animations=True,
        export_animation_mode='ACTIONS',
        export_force_sampling=True,
        export_materials='EXPORT',
    )


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if not args:
        sys.exit("Usage: blender model.blend --background --python tools/blender/export_glb.py -- model.glb")
    export_glb(args[0])
