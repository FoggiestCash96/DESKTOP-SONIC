# Developer guide

How to set up, run, test and release Sonic Velocity Run. Design decisions are in [docs/DESIGN.md](docs/DESIGN.md), and contribution rules are in [CONTRIBUTING.md](CONTRIBUTING.md).

## Requirements

| Tool | Version | Notes |
|---|---|---|
| [Godot](https://github.com/godotengine/godot/releases/tag/4.7.2-stable) | **4.7.2 stable, standard build** (not .NET) | The CI uses the same version (`GODOT_VERSION` in `.github/workflows/ci.yml`). |
| Git and [Git LFS](https://git-lfs.com/) | Any recent version | Run `git lfs install` once, before cloning. |
| [Blender](https://www.blender.org/) | 5.0 or newer | Only needed for 3D assets. |

## Get the code

```bash
git lfs install
```

```bash
git clone https://github.com/FoggiestCash96/DESKTOP-SONIC.git
```

In the Godot Project Manager, choose **Import**, select `project.godot`, and open the project. The first import takes a moment.

## Run the game

- **F5** runs the game from the title screen. Press Enter (or A / Start on a controller) to load the greybox test room.
- **F6** runs whichever scene is open. Open `stages/greybox/test_room.tscn` to go straight to the test room.

In the test room you control the player (a white capsule for now). The camera follows behind as you run, and you can turn it yourself at any time:

| Action | Keyboard and mouse | Controller |
|---|---|---|
| Move (relative to the camera) | W A S D | Left stick |
| Jump (hold for a higher jump) | Space | A |
| Roll (hold while moving) | Ctrl | B |
| Spin dash: hold while still, tap jump to charge, let go to launch | Ctrl, then Space | B, then A |
| Orbit the camera | Mouse or arrow keys | Right stick |
| Swing the camera behind the player | Middle mouse button | Right stick click |
| Debug overlay (player and camera state) | F3 | |
| Back to the title screen | Esc | Start |

The mouse is captured while the test room runs. If you alt-tab away, click the window to capture it again. The HUD shows rings, the stage clock, lives and red rings found. Falling off the edge of the floor or touching spikes with no rings costs a life, and the room restarts from the last checkpoint touched (or the start). After the last life it's game over and back to the title screen.

The test room has 15°, 30° and 45° ramps, a half-pipe, a loop (to the right of the half-pipe), a long 20° hill for rolling (to the left of the ramps), steps, a wall and a 1 km runway. Top running speed is just enough for the loop; a spin dash clears the half-pipe's lip. The camera swings side-on at the loop, and again on a 2.5D stretch at the far end of the runway.

Follow the ring trail to the right of the start for the gimmick area, three lanes running away from you:

- **Left lane:** rings, a dash panel, a checkpoint, then spikes.
- **Middle lane:** springs (yellow, red, diagonal onto a ledge, and one lying on its side).
- **Right lane:** item monitors (rings, shield, speed shoes, invincibility, magnet) with spikes to try them on.

Five red rings are hidden around the room, and an extra life floats over the yellow spring.

### Tuning

- **Player:** `engine/player/player_physics.tres`. Select it in the FileSystem dock, change values in the Inspector, save, and run again to try them. Every value is in SI units, and its tooltip says what it does. Besides movement it holds the damage, ring-loss and power-up values. [docs/DESIGN.md](docs/DESIGN.md#53-constants) lists the classic value behind each default.
- **Camera:** `engine/camera/camera_settings.tres`: distance, pitch, look-ahead, field of view, auto-follow and wall handling.
- **Lives and restarts:** `engine/systems/game_rules.tres`: starting lives, the delay before a restart, and how long GAME OVER shows.
- **Gimmicks:** each spring, dash panel, monitor and ring row has its own settings in the Inspector.

### Camera volumes

To give part of a level a set camera angle or a 2.5D side view, add a `Node3D` with `engine/camera/camera_volume.gd` and set its `size`. Its box shows in the editor. Turn the node so its -Z axis points the way the camera should look; the box turns with it. For a side view, tick `side_view` and lay the box's X axis along the path. Turn off `avoid_walls` where the camera should look through geometry, as at the loop.

### Gimmicks and collectibles

Drag these scenes into a stage. A stage's root node needs `engine/systems/stage.gd` (or a script that extends `Stage`) so deaths restart it from the last checkpoint.

| Scene | Notes |
|---|---|
| `engine/gimmicks/spring.tscn` | Launches along its +Y axis, so turn it to aim. `speed` 18.75 is the yellow spring and 30 the red one. Turn off `keep_momentum` for exact diagonal launches. On its side it pushes a grounded player along the ground. |
| `engine/gimmicks/dash_panel.tscn` | Sends a grounded player along its −Z axis (the arrows) at `speed` or faster. |
| `engine/gimmicks/spikes.tscn` | Set `size` for the bed's footprint. |
| `engine/gimmicks/checkpoint.tscn` | The player restarts 1 m in front of it, facing its −Z axis. |
| `engine/collectibles/ring.tscn` | One ring. For rows and arches, add a `Node3D` with `engine/collectibles/ring_line.gd` instead: set `count`, `spacing` and `arc_height`, and turn it to aim along its −Z axis. |
| `engine/collectibles/item_monitor.tscn` | Pick the `item`. Ring monitors have a `ring_amount`. |
| `engine/collectibles/hidden_collectible.tscn` | A red ring. Acts have five. |
| `engine/collectibles/extra_life.tscn` | The act's hidden 1-up. |

Rings sit about 0.8 m above the ground, so both a standing and a rolling player collect them.

## Checks and tests

Run both before opening a pull request. CI runs them on every push. On Windows, use the `Godot_v4.7.2-stable_win64_console.exe` binary so output appears in the terminal.

```bash
godot --headless --path . --script res://tests/check_scripts.gd
```

```bash
godot --headless --path . --script res://tests/run_tests.gd
```

- **`check_scripts.gd`** compiles every script with all warnings raised to errors. The project rule is zero warnings. It temporarily writes `override.cfg` to do this, and deletes it afterwards.
- **`run_tests.gd`** runs every `tests/unit/test_*.gd` file. CI also fails if any `SCRIPT ERROR` appears in the output.

### Writing a test

```gdscript
extends "res://tests/test_suite.gd"

func test_spin_dash_release_speed() -> void:
	assert_almost_eq(SpinDash.release_speed(8.0), 22.5, 0.001)
```

Each `test_*` method gets a fresh instance. The available helpers are `assert_true`, `assert_false`, `assert_eq`, `assert_almost_eq` and `fail`. Override `before_each()` and `after_each()` for setup and cleanup.

## Project layout

```
engine/           Reusable, franchise-free engine (no SEGA IP, enforced by a test)
  player/         Player controller, movement math and tuning resource
  camera/         Player camera, camera volumes and camera tuning
  gimmicks/       Loop, springs, dash panels, spikes, checkpoints; rails... later
  collectibles/   Rings, ring rows, scattered rings, item monitors, red rings, 1-ups
  enemies/base/   Enemy base classes (Milestone 8)
  systems/        Stage root script and GameState (autoload); save, settings, audio later
  debug/          F3 overlay (autoload "DebugOverlay") and fly camera
  greybox/        Grid shader, blockout materials and environment
content/sonic/    Sonic-specific characters, stages and UI (title screen, placeholder HUD)
stages/greybox/   Blockout and test scenes
tests/            Script checker, test runner, base class, unit tests
docs/             Design decisions and the AI session prompt
```

## Conventions

**Units and physics**
- 1 unit = 1 metre. Gameplay values are stored in SI units (m/s, m/s², seconds) in `.tres` resources, never hard-coded.
- Physics runs at a fixed **120 Hz** with **Jolt**. Move physics bodies only in `_physics_process`.
- **Physics interpolation is on.** Anything moved in `_process` (cameras, visual followers) must set `physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF` and read targets with `get_global_transform_interpolated()`. Otherwise it will stutter. `engine/debug/fly_camera.gd` is an example.
- Collision layers and input actions are listed in [docs/DESIGN.md](docs/DESIGN.md#collision-layers). Use the named layers. Don't invent new ones without adding them there and in Project Settings.

**Engine and content split**
- Nothing under `engine/` may name or depict SEGA characters or trademarks, including in file names and comments. `tests/unit/test_engine_ip_split.gd` enforces this.
- `engine/` must never depend on `content/`.

**GDScript**
- Follow the [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html), with static types everywhere.
- Access scene nodes through typed unique names, e.g. `@onready var _label: Label = %Label`, not `$Path.property`.
- Document scripts and exported properties with `##` doc comments.

**Greybox scenes**
- Build blockouts with CSG nodes (`use_collision = true`) and the materials in `engine/greybox/`: grey floor, orange slopes, blue walls.
- The grid is world-space: 1 square = 1 m, with a thick line every 5 m. Instance `greybox_environment.tres` for lighting and sky.

**3D assets**
- Model in Blender at 1 unit = 1 m, apply transforms, and export glTF 2.0 (`.glb`). Commit the `.blend` next to the `.glb`.
- Give collision meshes the `-col` suffix so Godot generates simplified collision on import.
- Binary assets go through Git LFS automatically (see `.gitattributes`).

## Releases

- **Test build:** on GitHub, go to **Actions → CI → Run workflow**. The Windows, Linux and macOS builds appear as a downloadable artifact on the run page.
- **Release:** bump `application/config/version` in Project Settings, commit, then tag and push:

```bash
git tag v0.1.0
```

```bash
git push origin v0.1.0
```

CI exports all three platforms and publishes a GitHub pre-release with generated notes.

- When upgrading Godot, change `GODOT_VERSION` in `.github/workflows/ci.yml` and the version in this file together.
- Release builds check out LFS files. GitHub meters LFS storage and bandwidth, so keep large source files (such as `.blend`) reasonably sized.
