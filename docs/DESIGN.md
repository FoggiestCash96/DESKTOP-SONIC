# Sonic Velocity Run: Design Decisions

The record of every decision made so far. The session prompt lives in [PROMPT_TEMPLATE.md](PROMPT_TEMPLATE.md). Whenever a decision is made there or in a work session, record it here.

---

## 1. Identity

| | |
|---|---|
| Title | Sonic Velocity Run (repository: `DESKTOP-SONIC`) |
| Pitch | A momentum-first 3D Sonic with classic slope physics and Adventure-style stages. |
| Tone / era | Modern (boost era), built on classic momentum physics |
| Structure | 6 worlds × 8 acts, with a boss per world. Difficulty rises world by world, and the last world's boss is the hardest. |
| Playable at launch | Sonic |
| Unlocked after the final boss | Super Sonic |
| Platforms | Windows, Linux, macOS |

## 2. Legal and licensing

- The game is free, non-commercial and unaffiliated with SEGA. The disclaimer appears on the title screen and in the README.
- **Code: MIT** ([LICENSE](../LICENSE)). **Original assets: CC BY-SA 4.0** ([LICENSE-ASSETS.md](../LICENSE-ASSETS.md)).
- **Engine/content split:** `engine/` contains no SEGA characters, names or trademarks, and `tests/unit/test_engine_ip_split.gd` enforces this. Sonic-specific material lives in `content/sonic/`.
- SRB2 (GPL-2.0-only) and Open Sonic (GPL-2.0+) are studied for behaviour only. Never copy or translate their code.

## 3. Technology

| Area | Decision |
|---|---|
| Engine | Godot **4.7.2** stable, standard build (not .NET) |
| Language | GDScript with static typing. Untyped declarations and unsafe property/method access produce warnings. |
| 3D physics | **Jolt** (`physics/3d/physics_engine = "Jolt Physics"`) |
| Tick rate | **120 Hz** fixed (`physics/common/physics_ticks_per_second = 120`) |
| Physics interpolation | **On.** Things moved in `_physics_process` render smoothly at any frame rate. Anything moved in `_process` (cameras, visual followers) must set `physics_interpolation_mode = OFF` and follow `get_global_transform_interpolated()`. |
| Renderer | Forward+ (desktop). ETC2/ASTC import is on because universal macOS builds need it. |
| Units | 1 Godot unit = 1 m. Physics constants are stored in **SI units** (m/s, m/s², seconds), so the tick rate can change without retuning. Classic values convert with `PIXELS_PER_METER = 32`. |
| Player collision | Custom kinematic controller on `CharacterBody3D` (Milestone 2). Never a `RigidBody3D`. |
| Assets | Blender 5.0 → glTF 2.0 (`.glb`). Commit both `.blend` and `.glb` (Git LFS). |
| Tests | `tests/check_scripts.gd` makes every script compile with zero warnings, and `tests/run_tests.gd` runs the headless unit tests. No addons needed. |
| CI | GitHub Actions: tests on every push and pull request. Windows, Linux and macOS exports on `v*` tags and on manual runs. |

### Collision layers

| # | Name | Used by |
|---|---|---|
| 1 | `world` | Level geometry the player stands on |
| 2 | `player` | Player bodies |
| 3 | `enemies` | Badniks and bosses |
| 4 | `gimmicks` | Springs, dash panels, rails and similar |
| 5 | `collectibles` | Rings, monitors, 1-ups, boost items |
| 6 | `hazards` | Spikes, crushers, kill planes |
| 7 | `water` | Water volumes |
| 8 | `camera_collision` | Geometry only the camera collides with |

### Input actions

Controller first. Every gameplay action has both a keyboard and a controller binding, and a unit test checks this. Button names below are Xbox names.

| Action | Keyboard / mouse | Controller | Purpose |
|---|---|---|---|
| `move_left` / `move_right` / `move_forward` / `move_back` | A / D / W / S | Left stick, D-pad | Movement |
| `camera_left` / `camera_right` / `camera_up` / `camera_down` | Arrow keys (plus mouse) | Right stick | Camera |
| `jump` | Space | A | Jump. In the air: homing attack or air dash |
| `boost` | Shift | X, RT | Boost |
| `crouch` | Ctrl | B | Roll, spin dash (while still), slide, stomp (in the air) |
| `drift` | C | LT | Drift |
| `quickstep_left` / `quickstep_right` | Q / E | LB / RB | Quickstep |
| `special` | F | Y | Light speed dash, Super transform, interact |
| `camera_recenter` | Middle mouse | Right stick click | Recenter the camera |
| `pause` | Esc | Start | Pause menu |
| `debug_overlay` | F3 | none | Developer overlay |

## 4. Perspective and structure

- **Dimension:** hybrid 3D with 2.5D path sections.
- **Stage style:** mixed per zone.
- **Hub:** world map.
- **Acts:** each act has its own focus (speed, platforming or combat). Each world ends with its boss.
- **Routes:** 1 to 3 per act. High routes reward skill, low routes are safer.
- **Save system:** per-slot JSON in `user://` with zone progress, collectibles, best times and settings.

## 5. Physics

### 5.1 Feel

**MODERN** moves (boost gauge, quickstep, drift, homing chains, scripted set pieces) layered on top of **classic momentum**: ground speed along the surface, with slopes adding and removing speed.

The **boost gauge** fills from rings and special boost items placed in acts, and from defeating certain enemies.

### 5.2 Simulation rules (defaults from the template)

| Rule | Value |
|---|---|
| Tick | 120 Hz |
| Ground model | Scalar `ground_speed` along the surface plus a surface-tangent heading. Free 3D velocity in the air. |
| Surfaces | Full 360° (loops and wall-running come from surface alignment) |
| Ground snap | Cast down up to 0.5 m. Detach if the angle changes by more than 45° in one tick. |
| Slip | Below `slip_threshold` on a surface steeper than 46°, horizontal input locks for 0.5 s |
| Fall | Detach when the surface is steeper than 90° |
| Input | Relative to the camera, projected onto the surface. Turn rate drops as speed rises. |

### 5.3 Constants

The classic values come from the Sonic Physics Guide (px/frame at 60 fps), converted to SI units with `PIXELS_PER_METER = 32`. Speeds use `× 60 / 32` and accelerations use `× 3600 / 32`. Milestone 2 puts these into `engine/player/player_physics.tres`. The boost-era values (boost speed, boost gauge rates, quickstep distance) are set during Milestone 2 tuning.

| Constant | Classic (px/frame) | SI default | Meaning |
|---|---|---|---|
| `acc` | 0.046875 | 5.273 m/s² | Ground acceleration |
| `dec` | 0.5 | 56.25 m/s² | Braking (input against motion) |
| `frc` | 0.046875 | 5.273 m/s² | Friction with no input |
| `top` | 6.0 | 11.25 m/s | Top running speed (slopes and boost can exceed it) |
| `slp` | 0.125 | 14.06 m/s² | Slope factor while running |
| `slp_roll_up` | 0.078125 | 8.789 m/s² | Slope factor while rolling uphill |
| `slp_roll_down` | 0.3125 | 35.16 m/s² | Slope factor while rolling downhill |
| `roll_frc` | 0.0234375 | 2.637 m/s² | Rolling friction |
| `roll_dec` | 0.125 | 14.06 m/s² | Rolling brake |
| `air_acc` | 0.09375 | 10.55 m/s² | Air acceleration |
| `air_drag` | on | on | Classic drag near the jump apex |
| `grv` | 0.21875 | 24.61 m/s² | Gravity |
| `jmp` | 6.5 | 12.19 m/s | Jump speed (about a 3.0 m jump) |
| `jmp_release_cap` | 4.0 | 7.5 m/s | Upward speed cap when jump is released early |
| `max_fall` | 16.0 | 30.0 m/s | Terminal fall speed |
| `slip_threshold` | 2.5 | 4.688 m/s | Below this on steep surfaces, the player slips |
| `max_ground_speed` | 16.0 | 30.0 m/s | Absolute cap, for collision safety |

### 5.4 Moves

| Move | Status |
|---|---|
| Roll, spin dash, drop dash (hold 0.33 s), Super Peel Out | Yes |
| Homing attack, air dash | Yes (lock-on range and cone not set yet) |
| Boost, stomp/bounce | Yes |
| Grind rails (`Path3D`), wall-run and wall-jump | Yes |
| Swimming (half acc/dec/frc/top and gravity, air timer) | Yes |
| Light speed dash | **Undecided** |
| Insta-shield and elemental shields | No |

### 5.5 Damage, rings and lives

- When hit with rings, scatter up to 32 of them and get 2.0 s of invulnerability.
- When hit with no rings, lose a life. You start with **5 lives**. Extra lives come from a unique hidden 1-up collectible in acts.
- Crush deaths and pit deaths are on.

## 6. Camera

All three modes are needed because stages are hybrid:

1. Free orbit with auto-follow (the default)
2. `CameraVolume` triggers that blend to scripted angles for set pieces
3. Side view on 2.5D path sections

Look-ahead is 0.3 × velocity (smoothed). Field of view goes from 70° at rest to 85° at top speed. During loops the camera keeps world-up unless a volume overrides it, and a smoothed spring arm keeps it out of walls.

## 7. Worlds

| # | Zone | Acts 1–8 | Signature gimmick | Music |
|---|---|---|---|---|
| 1 | **Emerald Shore** | Sunny Beachfront, Lush Palm Grove, Cascading Waterfall Basin, Shallow Reef Lagoon, Underground Grotto, Tidal Cavern, Sunset Ridge Cliffs, Stormy Coastal Fortress | **Tidal Surge:** periodic waves push or pull Sonic for momentum boosts or timed jumps | Upbeat tropical funk: FM brass, slap bass, steel drums |
| 2 | **Toxic Citadel** | Refinery Perimeter, Pipeline Aqueducts, Waste Processing Facility, Chemical Smelting Plant, Deep Sludge Sub-Level, Toxic Pressure Core, Exhaust Vent Towers, Citadel Command Spire | **Rising Chemical Vats:** timed ooze cycles flood the lower routes | Industrial techno and dark new wave |
| 3 | **Starlight Strip** | Neon Boulevard, Midnight Casino, Jackpot Plaza, Roulette Mezzanine, Behind the Scenes (Wiring Vaults), High-Roller Penthouse, Rooftop Rollercoaster Tracks, Skyscraper Apex | **Pinball Bumper Networks:** flippers, bounce pads and bumpers | Smooth jazz fusion and disco |
| 4 | **Glacier Peak** | Snowy Foothills, Frozen Forest, Ice Crystal Cavern, Deep Glacier Tunnels, Sub-Zero Abyss, Avalanche Gorge, Blizzard Ridge, Summit Observatory | **Slippery Ice and Halfpipes:** low-friction surfaces, hard braking | Sparkling new-age synth and chiptune |
| 5 | **Magma Mine** | Mine Shaft Entrance, Excavation Tunnel A, Brimstone Quarry, Molten Crucible, Deep Mantle Core, Lava Falls Cavern, Pressure Valve Shafts, Volcano Summit Rim | **Minecarts:** rail carts with timed jumps to switch tracks | Heavy rock and underground funk |
| 6 | **Cloudtop Citadel** | Skyway Gatehouse, Outer Cloud Terraces, Floating Sun Shrine, Wind Temple Courtyard, Airship Deck Docklands, Stormcloud Spire, Overcast Promenade, Stratosphere Palace | **Cloud Bouncers:** trampolines that launch Sonic to sky routes | Majestic orchestral synth |

**Engine implications:** surface friction has to be a per-surface property (Glacier Peak). Moving water and liquid volumes need to push the player and rise and fall over time (Emerald Shore, Toxic Citadel). Bumpers and launchers are shared gimmicks (Starlight Strip, Cloudtop Citadel). Minecarts are rideable path followers (Magma Mine).

**Greybox first:** every act starts as blockout geometry plus gimmicks, gets playtested, then gets an art pass in Blender. Collision uses simplified meshes (`-col` suffix on import), never the render mesh.

---

## 8. Open decisions

Each one is grouped by the milestone where it starts to block work.

| Needed by | Decision |
|---|---|
| **M2–M3 (physics)** | Turn rate at low and high speed; ground magnetism; homing lock-on range and cone; boost speed and gauge rates; light speed dash yes or no |
| **Structure** | Is Act 8 the boss act, or does a boss stage follow Act 8? (Act 8 names read like boss arenas.) |
| **M5 (gimmicks)** | Item monitor list; hidden collectible type (red rings, emblems or medals) and count per act |
| **M6 (first act)** | Level-building workflow: Blender stages, CSG greybox → Blender, or TrenchBroom |
| **M7 (art)** | Art style, poly budgets, outline and speed-line shaders, low-end performance target |
| **M8 (enemies)** | Badnik roster and boss concepts per world |
| **M9 (menus)** | HUD style; accessibility extras (game speed slider, assist mode) |
| **Later** | Special stages and Chaos Emeralds; ranking; time attack and ghosts; local and online multiplayer; music tool; 2D art tool; community channel; GameJolt |

## 9. Roadmap

| # | Milestone | Status |
|---|---|---|
| 1 | Project setup: repo, licenses, folder layout, Jolt, input map, CI, tests, title screen, greybox test room, debug overlay | **Done** |
| 2 | Player physics v1: flat ground, acc/dec/frc, jump, gravity, player values in the debug overlay | Next |
| 3 | Slopes, surface alignment, loops, slip/fall, rolling, spin dash | |
| 4 | Camera v1 plus camera volumes | |
| 5 | Gimmicks v1: springs, dash panels, rings, ring loss, monitors, checkpoints | |
| 6 | Greybox Emerald Shore Act 1 plus a playtest build | |
| 7 | Character art pipeline: Blender → glTF → AnimationTree | |
| 8 | Enemies and the first boss | |
| 9 | Menus, save system, settings, accessibility | |
| 10 | Art and audio pass, then a public demo release | |

**Scope plan:** 48 acts is a lot of content. Finish World 1 as a complete vertical slice (all its gimmicks, enemies and the boss) before greyboxing other worlds. Problems found in World 1 are much cheaper to fix than problems spread across six worlds.
