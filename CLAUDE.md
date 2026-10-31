# CLAUDE.md

Guidance for AI coding sessions in this repository. Human contributors should start with [DEVELOPER.md](DEVELOPER.md).

## Read first

- [docs/DESIGN.md](docs/DESIGN.md): every decision so far, the open questions, and roadmap status.
- [docs/PROMPT_TEMPLATE.md](docs/PROMPT_TEMPLATE.md): the session prompt. §17 says which milestone to work on.

## Rules

1. **Use Godot's built-in systems.** Write custom code only for gameplay (player physics, camera, gimmicks, enemies).
2. **Never copy or translate code** from SRB2, Open Sonic or SEGA games. They're GPL or proprietary. Re-implement documented behaviour instead.
3. **No SEGA IP in `engine/`.** No character names, trademarks or likenesses there. `tests/unit/test_engine_ip_split.gd` fails the build if any appear. Sonic-specific material goes in `content/sonic/`.
4. **Data-driven tuning.** Gameplay numbers live in `.tres` resources, in SI units (m, m/s, m/s², seconds). Never hard-code them.
5. **Fixed tick.** Player physics runs in `_physics_process` at 120 Hz. Physics interpolation is on, so anything moved in `_process` (cameras, visual followers) sets `physics_interpolation_mode = PHYSICS_INTERPOLATION_MODE_OFF` and reads targets with `get_global_transform_interpolated()`.
6. **Static typing everywhere**, and no new warnings. Use typed `@onready var x: Type = %Node` instead of bare `$Node` property access.
7. **Small, runnable steps.** Every change ends in something you can run, with instructions for testing it in the editor. Add unit tests for physics math.
8. **Record decisions** in `docs/DESIGN.md`, and update its roadmap table when a milestone is finished.
9. **Ask the user** before deciding anything the template still leaves as `[[CHOOSE]]` or lists under "Open decisions".

## Commands

Use the `*_console.exe` Godot binary on Windows so output reaches the terminal.

```bash
# Re-import after adding or moving files (also generates .uid files, which are committed)
godot --headless --path . --import

# Compile every script with all warnings raised to errors (project rule: zero warnings)
godot --headless --path . --script res://tests/check_scripts.gd

# Run the unit tests (exit code 1 on failure; CI also fails on any "SCRIPT ERROR" line)
godot --headless --path . --script res://tests/run_tests.gd

# Rebuild the stand-in Sonic model (Blender 5.0+), then re-import
blender --background --factory-startup --python content/sonic/characters/sonic/build_sonic.py
```

## Gotchas

- Godot's own `.blend` import is off (`filesystem/import/blender/enabled=false`): headless imports can't run Blender, and the game uses the exported `.glb`. A character `.glb` needs `import_script/path` set to `engine/player/character_import.gd` in its `.import` file for toon materials and looping animations.

- A `--script` tool that names a class in a type (for example `var p: Player`) compiles that class before autoloads exist, so the class's uses of `DebugOverlay` and `GameState` fail to compile. In tool scripts, find such nodes at runtime and access them without the class type (a built-in type such as `CharacterBody3D` is fine).
- After adding a script with a new `class_name`, run the headless `--import` before any `--script` tool that loads scripts using it: tools read the global class cache, which only an import (or the editor) refreshes.
- `Area3D.get_overlapping_bodies()` errors while the area's `monitoring` is off, so code that switches an area off (enemy hitboxes, boss parts) must skip it.
- Gimmicks that act on the player (springs, dash panels, spikes, item monitors, enemies, bosses) check `get_overlapping_bodies()` in `_physics_process` instead of acting in `body_entered`. That lets them keep acting while the player stays in contact (spikes once the flashing ends, a dash panel the player lands on), and the ones with `process_physics_priority = -1` act before the player moves that tick. The flip side: overlaps are from the last physics step, so a player teleported off a gimmick still counts as touching it for one more tick.

## Layout

- `engine/`: reusable, franchise-free platformer engine (player, camera, gimmicks, enemies, systems, debug, greybox).
- `content/sonic/`: Sonic-specific characters, stages and UI.
- `stages/greybox/`: blockout and test scenes.
- `tests/`: headless test runner (`run_tests.gd`), base class (`test_suite.gd`) and `unit/test_*.gd`.
