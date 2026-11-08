# Developer guide

How to set up, run, test and release Sonic Velocity Run. Design decisions are in [docs/DESIGN.md](docs/DESIGN.md), and contribution rules are in [CONTRIBUTING.md](CONTRIBUTING.md).

## Requirements

| Tool | Version | Notes |
|---|---|---|
| [Godot](https://github.com/godotengine/godot/releases/tag/4.7.2-stable) | **4.7.2 stable, standard build** (not .NET) | The CI uses the same version (`GODOT_VERSION` in `.github/workflows/ci.yml`). |
| Git and [Git LFS](https://git-lfs.com/) | Any recent version | Run `git lfs install` once, before cloning. |
| [Blender](https://www.blender.org/) | 5.0 or newer | Only needed for 3D assets, such as rebuilding or replacing the character model. |
| Python with numpy and SciPy, and [FFmpeg](https://ffmpeg.org/) | Python 3.10 or newer | Only needed to re-render the music and sound effects ([tools/audio/README.md](tools/audio/README.md)). |

## Get the code

```bash
git lfs install
```

```bash
git clone https://github.com/FoggiestCash96/DESKTOP-SONIC.git
```

In the Godot Project Manager, choose **Import**, select `project.godot`, and open the project. The first import takes a moment.

## Run the game

- **F5** runs the game from the title screen. Press Enter (or A / Start on a controller) for the main menu: **Play** goes to the save slots and then the world map, where you pick an act; **Options** has the settings; **Test room** opens the greybox test room. Two developer shortcuts skip the menus without a save slot: F (Y) for the test room, Shift (X) for Act 8 and its boss.
- **F6** runs whichever scene is open. Open one of the acts in `content/sonic/stages/emerald_shore/` (`act_1.tscn` to `act_8.tscn`) or `stages/greybox/test_room.tscn` to go straight there. Without a save slot nothing is saved, and the goal leads to the stage's `next_scene` (each act to the next) or the title screen.

You play Sonic, built by a script in Blender, with toon shading and animations for running, jumping, springs, skids and more. The camera follows behind as you run, adds speed lines and motion blur when you go fast, and you can turn it yourself at any time:

| Action | Keyboard and mouse | Controller |
|---|---|---|
| Move (relative to the camera) | W A S D | Left stick |
| Jump (hold for a higher jump) | Space | A |
| In the air: homing attack (with a target in reach) or air dash (a tap) | Space again | A again |
| Drop dash: in the air, hold the second press, and keep holding as you land | Space again (hold) | A again (hold) |
| Stomp (in the air) | Ctrl | B |
| Roll (hold while moving) | Ctrl | B |
| Spin dash: hold while still, tap jump to charge, let go to launch | Ctrl, then Space | B, then A |
| Boost (hold; in the air, an air boost) | Shift | X or RT |
| Drift (hold while running fast and steering) | C | LT |
| Super Peel Out: standing still, hold drift and tap jump, then let go of drift | C, then Space | LT, then A |
| Light speed dash (by a ring) | F | Y |
| Quickstep left / right (running fast) | Q / E | LB / RB |
| Orbit the camera | Mouse or arrow keys | Right stick |
| Swing the camera behind the player | Middle mouse button | Right stick click |
| Debug overlay (player and camera state) | F3 | |
| Pause menu | Esc | Start |

Menus work with a controller (D-pad or stick, A to choose, B to go back), the keyboard (arrows, Enter, Esc) or the mouse. Every control can be remapped in Options. The mouse is captured while you play; if you alt-tab away, click the window to capture it again. The HUD shows rings, the stage clock, the act's red rings (filled once found), lives, the power-ups running, and the boost gauge. Rings, enemies and boost monitors fill the gauge; boosting smashes through enemies. Falling off the edge or getting hurt with no rings costs a life, and the stage restarts from the last checkpoint touched (or the start). After the last life it's game over and back to the title screen.

Land on a grind rail, or run onto its end, to grind it: Q / E (LB / RB) hops to a rail beside it, and jump leaves it. Under water everything is slower and floatier: lower jumps, slow falls. Air lasts 30 s; touch a big bubble from a vent, or come up for air, before the count runs out. A roll, spin dash or boost smashes through walls of loose rock.

Badniks hurt you if you touch them standing up. Jump on them, roll into them, or homing attack them: in the air, a yellow reticle marks what a second jump press would lock on to, and each hit bounces you up ready for the next. Springs are targets too: homing into one launches you straight along it, ready to home in on whatever is next. With nothing in reach, a quick tap of the second press is an air dash, and holding it charges a drop dash that launches you rolling as you land (let go first to cancel it).

The stomp slams you straight down, smashing badniks and monitors on the way. The Super Peel Out revs up on the spot: after half a second, letting go of drift launches you running at full speed. Drifting slides you round corners far tighter than running turns. The light speed dash zips you along a trail of rings, even across a gap or up into the air. Jump at a blue wall-jump panel to cling to it, and jump again to kick off: two facing panels make a climb. Jump at a gold strip on a wall while running fast to run along the wall.

**Emerald Shore Act 1** is the first greybox act, a speed act about 1.2 km long:
- Waves wash up the tidal flats every 15 seconds. Ride one up the steep slope.
- From the top, jump the gap on the left to the high deck, or run down the right to the low road.
- After the right turn there's a side-view pier, then a second loop.
- Five red rings are hidden along the way.
- Badniks along the way: crabs, gulls, a clam that fires pearls, and fish leaping across the pier.
- The goal shows your time and rings, then moves on to Act 2.

**Acts 2 to 7** follow on, each taking about as long to play:
- **Act 2, Lush Palm Grove:** a treetop route of decks and rope bridges over a safe jungle floor, a ravine crossed on a bridge or on moving and crumbling platforms, a lift, a homing chain or a wall-jump climb up to a high shelf, and a vine rail down from it.
- **Act 3, Cascading Waterfall Basin:** waterslides whose current is faster than running, springs up tiers beside waterfalls, rails beside the slides, and a plunge pool crossed on floating logs.
- **Act 4, Shallow Reef Lagoon:** packs of badniks on reef islets, homing chains of gulls (or a swim, or a raft) across deep channels, and waves to surf along the sandbars.
- **Act 5, Underground Grotto:** caves with a hidden room, a chasm (crossed on a ledge, on crumbling stones, or by running along the wall), a great hall and a shaft in side view, and a river tunnel with a current and a rail.
- **Act 6, Tidal Cavern:** two caverns where the tide floods the low route on a timer (run it at low tide, swim or ride a raft at high tide) while the high ledges stay dry, and a tide pool to ride up.
- **Act 7, Sunset Ridge Cliffs:** a fast cliff-top run with three loops, a spring cannon (or a homing chain, or a light speed dash) over a chasm, big jumps (or bridges beside them), rails and a narrow ridge, toward the fortress.

**Emerald Shore Act 8** is a short run along a fortress causeway (a homing chain across a gap, fish leaping over a bridge) to the beach where the boss waits. Eggman raises a wave and leaves; the crab mech that rises out of it takes 8 hits on its core, which opens after it slams its claws down. Jump the waves it sends, then hit the core. Beating it shows the results, then returns to the title screen.

[docs/DESIGN.md](docs/DESIGN.md#7-worlds) maps each act section by section.

The test room has 15°, 30° and 45° ramps, a half-pipe, a loop (to the right of the half-pipe), a long 20° hill for rolling (to the left of the ramps), steps, a wall and a 1 km runway. Top running speed is just enough for the loop; a spin dash clears the half-pipe's lip. The camera swings side-on at the loop, and again on a 2.5D stretch at the far end of the runway.

Follow the ring trail to the right of the start for the gimmick area, three lanes running away from you:

- **Left lane:** rings, a dash panel, a checkpoint, then spikes.
- **Middle lane:** springs (yellow, red, diagonal onto a ledge, and one lying on its side), to run over or homing attack.
- **Right lane:** item monitors (rings, shield, speed shoes, invincibility, magnet) with spikes to try them on.

Five red rings are hidden around the room, and an extra life floats over the yellow spring.

Past the right lane is the water and rails area: a pool to swim in (with an air vent, and a spring out), a shallow stream flowing over the floor, a tide pool that floods and drains with a raft on it, two grind rails side by side to hop between, a lift, a platform that crushes anyone under it against a low roof, a crumbling ledge, and a rock wall to smash through.

Beyond the far end of the gimmick lanes is the moves area: a tower to stomp off onto a crab and a monitor, a ring trail up to a ledge for the light speed dash, a shaft with wall-jump panels on both sides, and a long wall with a wall-run strip. The drop dash, Super Peel Out and drift work anywhere.

Far to the left of the start, past the long hill, is the enemy gallery: a crab, a clam, a gull and a leaping fish to try jumping, rolling and homing attacks on, and a homing chain of three gulls across a gap between two platforms.

### Tuning

- **Player:** `engine/player/player_physics.tres`. Select it in the FileSystem dock, change values in the Inspector, save, and run again to try them. Every value is in SI units, and its tooltip says what it does. Besides movement it holds the homing attack and air dash, the boost and quickstep, damage, ring-loss and power-up values. [docs/DESIGN.md](docs/DESIGN.md#53-constants) lists the classic value behind each default.
- **Camera:** `engine/camera/camera_settings.tres`: distance, pitch, look-ahead, field of view, auto-follow, wall handling, and the speed lines and motion blur. Players' own choices (sensitivity, inverted axes, effects on or off) are in the Options menu and act on top of these.
- **Player settings and saves:** the Options menu writes `user://settings.cfg`, and each save slot is `user://saves/slot_NN.json` (`user://` is `%APPDATA%\Godot\app_userdata\Sonic Velocity Run` on Windows when running from the editor). Delete them to start fresh.
- **Lives and restarts:** `engine/systems/game_rules.tres`: starting lives, the delay before a restart, and how long GAME OVER shows.
- **Gimmicks:** each spring, dash panel, monitor and ring row has its own settings in the Inspector.
- **Enemies and bosses:** each badnik scene (`content/sonic/enemies/`) and each placed badnik has its own settings: notice range, speeds, patrol distance and so on. The boss's are on the `CrabMech` node in `content/sonic/bosses/emerald_shore/crab_mech.tscn`, per phase where they change.

### Camera volumes

To give part of a level a set camera angle or a 2.5D side view, add a `Node3D` with `engine/camera/camera_volume.gd` and set its `size`. Its box shows in the editor. Turn the node so its -Z axis points the way the camera should look; the box turns with it. For a side view, tick `side_view` and lay the box's X axis along the path. Turn off `avoid_walls` where the camera should look through geometry, as at the loop. Set `focus` to keep a node in view beyond the player instead, as a boss arena does.

### Gimmicks and collectibles

Drag these scenes into a stage. A stage's root node needs `engine/systems/stage.gd` (or a script that extends `Stage`) so deaths restart it from the last checkpoint.

| Scene | Notes |
|---|---|
| `engine/gimmicks/spring.tscn` | Launches along its +Y axis, so turn it to aim. `speed` 18.75 is the yellow spring and 30 the red one. Turn off `keep_momentum` for exact diagonal launches. On its side it pushes a grounded player along the ground. It's a homing target: a homing attack that reaches it puts the player on its pad and launches them exactly along it, whatever `keep_momentum` says, so aim a spring meant for homing at where it should land. |
| `engine/gimmicks/dash_panel.tscn` | Sends a grounded player along its −Z axis (the arrows) at `speed` or faster. |
| `engine/gimmicks/spikes.tscn` | Set `size` for the bed's footprint. |
| `engine/gimmicks/checkpoint.tscn` | The player restarts 1 m in front of it, facing its −Z axis. |
| `engine/collectibles/ring.tscn` | One ring. For rows and arches, add a `Node3D` with `engine/collectibles/ring_line.gd` instead: set `count`, `spacing` and `arc_height`, and turn it to aim along its −Z axis. |
| `engine/collectibles/item_monitor.tscn` | Pick the `item`: rings, shield, speed shoes, invincibility, magnet or boost. Ring monitors have a `ring_amount`. |
| `engine/collectibles/hidden_collectible.tscn` | A red ring. Acts have five. |
| `engine/collectibles/extra_life.tscn` | The act's hidden 1-up. |
| `engine/gimmicks/tidal_wave.tscn` | Washes along its −Z axis on a timer: set `size`, `reach` and the surge, backwash and rest times. Keep its path clear of overhangs, since the water follows the ground. |
| `engine/gimmicks/goal.tscn` | The end of an act. Turn it so its −Z axis points the way the player runs through. |
| `engine/gimmicks/rolling_wave.tscn` | One wave crest rolling along its −Z axis for `reach` metres. Bosses send these out; with `rolling` on it starts by itself. |
| `engine/gimmicks/water_volume.tscn` | Water to swim in: its surface is the node's XZ plane, `size` sets its width, depth below the surface and length. A `current_speed` carries the player along its −Z axis (tilt the node to run a stream down a slope); a `tide_height` floods and drains it on a timer, staggered with `start_time`. Turn off `show_surface` where the stage's art draws the water. |
| `engine/gimmicks/air_bubbles.tscn` | An air vent for the bottom of the water: a big bubble every `interval` seconds gives a breath. |
| `engine/gimmicks/grind_rail.tscn` | A rail along its `Path3D` curve: edit the curve's points. It builds its own tube. Start it just past a ledge's edge, not inside the ledge, or players running off the ledge get knocked off it. |
| `engine/gimmicks/moving_platform.tscn` | Moves by `travel` (in its own space) and back, or floats on the water named in `float_on`. Its origin is the middle of its top. Give players solid ground to wait on beside it. |
| `engine/gimmicks/crumbling_platform.tscn` | Falls `delay` seconds after a player stands on it and comes back after `respawn_time`. Its origin is the middle of its top. |
| `engine/gimmicks/breakable_wall.tscn` | Smashed by a player rolling or boosting into it. Its origin is the middle of its bottom. |
| `engine/gimmicks/wall_jump_panel.tscn` | A patch of wall to cling to and kick off. Put it flat on a wall, its +Z axis pointing out of the wall; its origin is the middle of the panel and `size` its width and height. Face two panels across a shaft 6 to 7 m wide for a climb (each kick gains about 3 m), and make the side to finish on the lower one, so the last kick lands on top of it. |
| `engine/gimmicks/wall_run_strip.tscn` | A band along a wall to run on, at 10 m/s or more. Put it on a wall with its +Z axis pointing out of the wall; the player runs along its X axis for `length` metres from its origin, at its origin's height, and the band is `height` tall. Start it a little before where the run should begin, so players can jump at it from the ground. |

A checkpoint counts anywhere through its gate: set `gate_width` to the width of the course. For a 2.5D section, tick `lock_depth` on a side-view camera volume as well as `side_view`; the player then stays on the box's middle plane. Players heading into it are eased onto that plane from `lead_in` (16 m) before either end, out of a funnel that widens as it goes, so a 3D stretch wider than the path can lead into it. Where they can arrive from the side, as at a corner, make the box deep enough to take in all the floor they can arrive on: running at the path, they carry straight on to it, then turn along it. Leave floor under them while they come onto the path, which takes them two metres of running for every three they were off it.

### Building an act

Acts live in `content/sonic/stages/<world>/act_<n>.tscn`, blocked out in Godot and dressed in Blender afterwards. An act needs:

- A root `Node3D` with `engine/systems/stage.gd`. Set its `title` (shown on the title card and the results), its `hub_scene` (`content/sonic/ui/map/world_map.tscn`, where the goal leads while a save slot is played), and its `next_scene` (where the goal leads without one).
- An instance of `engine/player/player.tscn`. Set its `character` (`content/sonic/characters/sonic/sonic.tres` for Sonic) and a `kill_height` a little below the lowest ground.
- `engine/camera/player_camera.tscn` (its `target` is the player) and `content/sonic/ui/hud/hud.tscn` (its `target` too).
- The greybox environment and a sun, then ground made of CSG shapes with `use_collision` on, using the greybox materials.

Then add gimmicks, badniks, checkpoints, five red rings, one extra life and a goal (or, in Act 8, the boss). Play it, and keep at least one route open to players who aren't fast. Finally put its scene on its act in `content/sonic/stages/worlds.tres`, the world map's list of worlds and acts, so the map can open it.

### Dressing an act (the art pass)

An act's art is built from its greybox by a script, and the greybox stays in the act, hidden, as the collision ([docs/DESIGN.md](docs/DESIGN.md#83-the-art-pass-milestone-10) has the rules). After changing an act's greybox, export it and build its art again (from the repository root):

```bash
godot --headless --path . --script res://tools/godot/export_greybox.gd -- res://content/sonic/stages/emerald_shore/act_1.tscn content/sonic/stages/emerald_shore/art/act_1.greybox.json
blender --background --factory-startup --python content/sonic/stages/emerald_shore/art/build_act_1.py
godot --headless --path . --import
```

The build script dresses every greybox piece by name (grass, sand, piers...) and stops if a piece has no style, so a new piece can't slip in without art. For a new act, copy a build script, list its pieces, and add the result to the act as an instance named `Art`; then hide the greybox's CSG shapes (leave `use_collision` on), give the `Sea` the world's water material and the `WorldEnvironment` its sky. Hints are `Label3D`s with billboard off: the art puts a board behind each one. A label's text faces its +Z axis, so turn it to face the players coming toward it (on a 2.5D stretch, the camera). A unit test fails when an act's greybox has changed since its art was built.

### Models for objects, badniks and bosses

The engine's objects keep simple placeholder shapes, and a model dresses them when the game runs (`engine/art/model_skin.gd`): each part of the model is named after the node it dresses, with `__` for `/`. To change a model, edit its build script and run it, then import:

```bash
blender --background --factory-startup --python content/sonic/objects/build_objects.py
blender --background --factory-startup --python content/sonic/enemies/models/build_badniks.py
blender --background --factory-startup --python content/sonic/bosses/emerald_shore/build_crab_mech.py
```

The scripts build each part where the object's scene puts that node, from a layout `tools/godot/export_parts.gd` writes (`<name>.parts.json`); export it again after moving or renaming a placeholder's nodes. The engine's objects find their models in `content/sonic/objects/art_bank.tres` (the project setting `game/art/art_bank`); a badnik or boss names its own in `skin`.

To force Godot to import a `.glb` again (after changing a material in a `materials/` library, say), delete its files in `.godot/imported/` (`<name>.glb-*`) and run the import.

### Enemies and bosses

Drag a badnik from `content/sonic/enemies/` into a stage (under an `Enemies` node keeps things tidy), then adjust it in the Inspector:

| Scene | Behaviour | Placing it |
|---|---|---|
| `scuttler.tscn` | Walker | Patrols along its own X axis, `patrol_distance` either side. Keep its patrol on solid ground. |
| `galegull.tscn` | Flyer | Untick `swoops` for a hovering stepping stone in a homing chain; chained targets want to be within 12 m of each other, and nearer each other than any spring, since the homing attack picks the nearest target in reach. |
| `pearlshot.tscn` | Turret | Fires at the player from `notice_range` away. Give players something to hide behind, or a way round. |
| `leapfin.tscn` | Leaper | Put it at the water's surface. With `leap_distance` it leaps along its −Z axis and back; stagger neighbours with `start_delay`. |

A new kind of enemy is a scene whose root has one of the scripts in `engine/enemies/` (or a script extending `Enemy`), with a `Hitbox` Area3D on the enemies layer watching the player layer, a `HomingTarget` marker (`engine/enemies/base/homing_target.gd`) where the homing attack should aim, and a `Model` with the visuals, all with **Access as Unique Name** ticked. Give the model an AnimationPlayer with `patrol`, `notice`, `attack` and `stunned` animations and they play by themselves.

A boss is a script extending `Boss` (`engine/enemies/base/boss.gd`) with a `WeakPoint` area, a `HomingTarget` and a `Model`, and its `body_areas` and `danger_areas` set. It fills in `_fight()` and decides when it's `vulnerable`; overriding `begin()` gives it an intro. In the stage, a `BossArena` area (`engine/enemies/base/boss_arena.gd`, with a `Barriers` static body under it) starts the boss when the player walks in, and a camera volume with the boss as its `focus` keeps it on screen. `content/sonic/bosses/emerald_shore/` is the worked example.

### Menus and text

The menus live in `content/sonic/ui/`: the title screen, `menus/` (save slots, options, pause), `map/` (the world map) and `hud/`. They share `menu_theme.tres` for their look and `menus/menu_kit.gd` for building buttons and labels. Every piece of text shown to players is a key such as `MENU_PLAY`, translated through `ui/translations/strings.csv`: add a key there for new text, and a column (say `fr`) for a new language. Godot turns the CSV into `.translation` files when it imports, and `project.godot` lists them. Commit those too (`.gitignore` lets them through): the game loads them as it starts, before an import could make them, so a checkout without them logs errors.

### Music and sound

The music and sound effects are made from text by `tools/audio/`: the tracks are notes in `tools/audio/music/`, the sounds recipes in `tools/audio/sounds.py`. [tools/audio/README.md](tools/audio/README.md) explains the notation and how to swap in your own recordings. After re-rendering, re-import (open the editor, or `godot --headless --path . --import`).

In code, play a sound by name and the sound bank (`content/sonic/audio/sound_bank.tres`) finds its file:

```gdscript
Sfx.play(&"spring")                     # heard the same everywhere, as the player's own sounds are
Sfx.play_at(&"enemy_pop", position)     # from a point in the world
Sfx.play_on(&"wave", water)             # following a node as it moves
Music.jingle(&"extra_life")             # cuts in, then the music carries on
```

To add a sound, render it (add a recipe to `sounds.py`), then add its name to the bank in the Inspector. A stage's music is the `Music` and `Fast Music` of its root node (`Fast Music` plays during speed shoes); a boss fight's is the `Music` of its `BossArena`.

### Characters: from Blender to Godot

Sonic is built entirely by a script, so rebuilding him is one command (from the repository root):

```bash
blender --background --factory-startup --python content/sonic/characters/sonic/build_sonic.py
```

It writes `sonic.blend` and `sonic.glb`, and Godot re-imports the `.glb` the next time the editor or `--import` runs. To make or replace a character by hand, follow the conventions in [docs/DESIGN.md](docs/DESIGN.md#82-character-pipeline-milestone-7):

1. Model at 1 m per unit, feet at the origin, facing +Y in Blender, with the standard bone and animation names.
2. Export the `.blend` with the project's settings:

   ```bash
   blender path/to/model.blend --background --python tools/blender/export_glb.py -- path/to/model.glb
   ```

3. In Godot, select the `.glb`, set **Import Script** in the Import dock to `engine/player/character_import.gd`, and click **Reimport**. Materials become cel-shaded and the cycles loop.
4. Make a character scene like `content/sonic/characters/sonic/sonic.tscn`: a root with `engine/player/character_model.gd`, the model, and the same AnimationTree.
5. Make a `CharacterDef` resource (like `sonic.tres`) pointing at that scene, and set it as the Player's `character`.

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
  gimmicks/       Loop, springs, dash panels, spikes, checkpoints, tidal waves, water, air bubbles, grind rails, moving and crumbling platforms, breakable walls, goal
  collectibles/   Rings, ring rows, scattered rings, item monitors, red rings, 1-ups
  enemies/        Enemy behaviours (walker, flyer, turret, leaper); base/ has the enemy and boss bases, homing targets, the boss arena, shots, explosions and freed animals
  systems/        Stage root script, GameState, SaveGame and GameSettings (autoloads), remappable controls, world map data
  audio/          Sfx and Music (autoloads) and the SoundBank resource
  art/            Toon shaders (stripes, height bands, water, waterfalls, sky), the art import script, model skins, the ArtBank, and storms
  debug/          F3 overlay (autoload "DebugOverlay") and fly camera
  greybox/        Grid shader, blockout materials and environment
content/sonic/    Sonic-specific characters, badniks, bosses, stages (Emerald Shore's eight acts with their art, the list of worlds), objects (models for the engine's objects, the art bank), materials, UI (title with its beach, menus, world map, HUD, translations) and audio (music, sounds, the sound bank)
stages/greybox/   Blockout and test scenes
tests/            Script checker, test runner, base class, unit tests
tools/blender/    Blender scripts: the glTF export, and the kits art is built with (art_kit, stage_kit)
tools/godot/      Godot scripts that write a stage's greybox or a scene's layout as JSON for the Blender scripts
tools/audio/      The music and sound effects, written as notes and recipes, and the synth that renders them
thirdparty/       Assets made by others, each folder with its license: the DejaVu font for symbols the default font lacks
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
- Model in Blender at 1 unit = 1 m, apply transforms, and export glTF 2.0 (`.glb`). Commit the `.blend` next to the `.glb`. Godot doesn't import `.blend` files itself (that's switched off), so always export.
- The art style is stylised toon (cel shading, flat colours). Budgets: player 30k triangles, enemies 6k, stage chunks 100k per visible region. Target: 60 fps at 1080p on a GTX 1060-class GPU.
- Give collision meshes the `-col` suffix so Godot generates simplified collision on import.
- Binary assets go through Git LFS automatically (see `.gitattributes`).

## Releases

- **Test build:** on GitHub, go to **Actions → CI → Run workflow** and pick the branch. The Windows, Linux and macOS builds appear as a downloadable artifact on the run page. Try one before each release.
- **Release:** write the release page's notes in `docs/releases/v<version>.md` (without that file, GitHub lists the merged pull requests instead), bump `application/config/version` in Project Settings if it changed, commit, then tag and push:

```bash
git tag v0.1.0
```

```bash
git push origin v0.1.0
```

CI exports all three platforms, puts the licenses, the credits and the bundled font's license in every download, and publishes a GitHub pre-release with the notes.

- When upgrading Godot, change `GODOT_VERSION` in `.github/workflows/ci.yml` and the version in this file together.
- Release builds check out LFS files. GitHub meters LFS storage and bandwidth, so keep large source files (such as `.blend`) reasonably sized.
