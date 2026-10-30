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

### 5.2 Simulation rules

| Rule | Value |
|---|---|
| Tick | 120 Hz |
| Ground model | Scalar `ground_speed` along the surface plus a surface-tangent heading. Free 3D velocity in the air. |
| Surfaces | **Full 360°**, chosen 2026-10-29: loops, half-pipes and wall runs all come from surface alignment, not tagged geometry. |
| Slopes | Gravity's pull along the surface (`slp`, or `slp_roll_up` / `slp_roll_down` while rolling) speeds the player up downhill and slows them uphill, and bends their path downhill across a slope. Standing still holds on slopes gentle enough for friction to win (about 22°). |
| Ground snap | Reaches up to 0.5 m for the ground, so crests don't launch the player. A ground ray reads the face underfoot and ignores surface changes sharper than 46° in one step, so the top of a wall or a ledge launches the player instead of being wrapped around. |
| Slip | Below `slip_threshold` (4.69 m/s) on a surface steeper than 46°, the stick is ignored for 0.5 s. |
| Fall | Past vertical, a player slower than the classic slip speed drops off. `ground_magnetism` would add grip, but it is **0 (classic)**, chosen 2026-10-29. |
| Input | Relative to the camera, projected onto the surface. Turn rate eases from 720°/s at rest to 180°/s at top speed. Input more than 135° from the heading brakes, and after stopping the player turns around at 0.94 m/s. On surfaces steeper than 46° the stick only speeds up or slows down along the path, so loops and walls work from any camera angle. |
| Launches | Leaving the top of a near-vertical wall (steeper than 75°) launches straight up, so the player falls back into a half-pipe. |

### 5.3 Constants

The classic values come from the Sonic Physics Guide (px/frame at 60 fps), converted to SI units with `PIXELS_PER_METER = 32`. Speeds use `× 60 / 32` and accelerations use `× 3600 / 32`.

`engine/player/player_physics.gd` defines each constant, with the converted classic value as its default. `engine/player/player_physics.tres` is the copy the game uses, and the one to tune. Milestone 2 added the ground, turning, air and assist values, and Milestone 3 the slope, rolling and spin dash values. The boost-era values (boost speed, gauge rates, quickstep distance) are set when the boost is built.

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
| `turnaround_speed` | 0.5 | 0.9375 m/s | Speed in the new direction after braking to a stop |
| `turn_rate_low` | — | 720°/s | Turn rate at rest (3D only) |
| `turn_rate_high` | — | 180°/s | Turn rate at top speed and above (3D only) |
| `brake_angle` | — | 135° | Input further than this from the heading brakes instead of turning (3D only) |
| `coyote_time` | — | 0.1 s | A jump still works this long after running off a ledge |
| `jump_buffer_time` | — | 0.1 s | A jump pressed this long before landing still happens |
| `roll_min_speed` | 1.0 | 1.875 m/s | Holding crouch at this speed or faster starts a roll |
| `unroll_speed` | 0.5 | 0.9375 m/s | A roll ends below this speed |
| `roll_turn_factor` | — | 0.5 | Turn rate while rolling, as a share of the running turn rate (3D only) |
| `spin_dash_speed` | 8.0 | 15.0 m/s | Spin dash launch speed with no charge |
| `spin_dash_charge_speed` | 0.5 | 0.9375 m/s | Extra launch speed per whole unit of charge (8 + floor(charge) / 2 px/frame) |
| `spin_dash_charge_per_press` | 2 | 2 | Charge added by each jump press; it bleeds off by 1/32 per 60 fps frame |
| `spin_dash_max_charge` | 8 | 8 | Most charge the spin dash holds (22.5 m/s launch) |
| `slip_angle` | 46° | 46° | Surfaces steeper than this can make a slow player slip, and the stick stops steering on them |
| `slip_lock_time` | 30 frames | 0.5 s | How long the stick is ignored after slipping |
| `ground_magnetism` | — | 0 m/s² | Extra grip on overhangs and ceilings for slow players; 0 is classic (3D only) |
| `snap_length` | — | 0.5 m | How far the player reaches for the ground over crests |
| `surface_step_angle` | — | 46° | Sharpest change of surface followed in one step; sharper edges act as ledges or walls |
| `upright_speed` | — | 540°/s | How fast the player turns back upright in the air (3D only) |

### 5.4 Moves

| Move | Status |
|---|---|
| Roll, spin dash, drop dash (hold 0.33 s), Super Peel Out | Yes |
| Homing attack, air dash | Yes. Homing locks on up to **12 m** away within a **90° cone** (45° either side), chosen 2026-10-29. Built once there are targets. |
| Boost | Yes, built after Milestone 2, once the camera's speed effects and rings exist |
| Stomp/bounce | Yes |
| Grind rails (`Path3D`), wall-run and wall-jump | Yes |
| Swimming (half acc/dec/frc/top and gravity, air timer) | Yes |
| Light speed dash | **Yes**, chosen 2026-10-29 (`special` button along ring trails). Built once rings exist. |
| Insta-shield and elemental shields | No |

### 5.5 Damage, rings and lives

Built in Milestone 5. The values are classic ones, in `player_physics.tres` (damage, ring loss and power-ups) and `engine/systems/game_rules.tres` (lives and restart timing).

- **Rings:** touch one to collect it. The HUD's ring count flashes red at zero, because the next hit is then fatal. 100 rings don't give a life.
- **Hit with rings:** all of them are lost, and up to 32 scatter. The first 16 fly out at 7.5 m/s and the rest at 3.75 m/s, fanned out all around the player and upward. They fall under 10.55 m/s² of gravity and bounce off level geometry, keeping 75% of their speed into the surface. They can be grabbed back after 64 frames (1.07 s) and vanish after 256 frames (4.27 s).
- **Knockback:** a hit throws the player away from what hurt them at 3.75 m/s and up at 7.5 m/s, under lighter gravity (21.09 m/s²) and with no control. Landing stops them dead. Then follow 2.0 s (120 frames) of flashing, during which nothing can hurt them.
- **Shield:** takes the next hit instead of the rings, with the same knockback and flashing.
- **Hit with no rings:** the player dies. They hop up at 13.1 m/s and fall through everything, and the camera stops to watch. 2 s later the stage restarts from the last checkpoint, a life down.
- **Lives:** you start with **5**. Extra lives come only from a unique hidden 1-up object in each act. Each gives a life once per visit, and one found before a death stays found. Losing the last life shows GAME OVER for 3 s, then the title screen returns and the next game starts with 5 lives again.
- **Pit deaths** are on: falling below `kill_height` (y = −50 m) costs a life the same way. **Crush deaths** are on too, but come with the first moving solid objects, as there is nothing to be crushed by yet.
- **Item monitors** (decided 2026-10-30):

| Item | Effect |
|---|---|
| Rings | 10 rings. The amount is a setting on each monitor, so 5- and 20-ring boxes need nothing new. |
| Shield | Takes the next hit in place of the rings |
| Speed shoes | 20 s of doubled acceleration, friction, top speed, air acceleration and roll friction, as the classic shoes |
| Invincibility | 20 s of ignoring hits. Pits still kill. |
| Ring magnet | 20 s of pulling in rings within 5 m. A pulled ring flies 15 m/s faster than the player, so it always catches up. |
| Boost refill | Added once the boost exists |

  Monitors are solid: a player standing up bumps into them or stands on them. Curled up (jumping, rolling or spin dashing) they break them open. Breaking one from above bounces the player back up: their falling speed turns into rising speed, still cut short if jump is let go.
- **Hidden collectibles** (decided 2026-10-30): **red rings, 5 per act.** The HUD counts them. One found before a death stays found and shows greyed out after the restart. Saving them for good comes with the save system (Milestone 9).
- **Checkpoints:** passing a post saves the spot and the stage clock. After a death the stage restarts 1 m in front of the post, facing the way it points, with the clock as it was then and no rings. The lamp turns from blue to red.
- **Stage clock:** counts up with no time limit (the modern rule; the classic games had 10 minutes). It stops while the player is dead.

### 5.6 Player controller (Milestones 2 and 3)

- `engine/player/player.tscn` is a `CharacterBody3D` on the `player` layer, colliding with `world` and `gimmicks` (for solid item monitors). Its origin is at its feet. Standing, it uses a capsule 1.0 m tall and 0.3 m in radius; rolling, spin dashing and jumping it curls into a 0.3 m ball.
- It is a state machine with one script per state in `engine/player/states/`: `GroundState` (run, brake, turn, crouch), `RollState`, `SpinDashState`, `AirState`, and since Milestone 5 `HurtState` (knockback) and `DeathState`. The shared surface handling, rings, hits and power-ups live in `player.gd`.
- On the ground, `ground_speed` and `heading` set the velocity along the surface, and `move_and_slide()` resolves collisions. The body turns to match the ground normal, pivoting on the center of its rounded bottom so the part touching the ground stays put.
- Godot only snaps a body to the floor when its velocity points into it, and velocity along a slope rounds either way, so the player calls `apply_floor_snap()` itself after each move. A ray from the center of its rounded bottom then reads the ground normal, as the classic ground sensors did.
- Walls: a head-on hit stops the player. A glancing hit slides along the wall, keeping only the part of the speed that wasn't pointing into it.
- Variable jump height: while jump is not held, upward speed is capped at `jmp_release_cap`. Jumps push away from the surface, along its normal.
- Landing keeps the part of the velocity that runs along the surface. Touching only an edge, with no ground under the player's middle, isn't a landing.
- Falling below `kill_height` (y = −50 m) costs a life (§5.5).
- `engine/player/player_motion.gd` holds the movement math as static functions, so `tests/unit/test_player_motion.gd` can check it against the classic values without running a scene.
- The F3 overlay shows the state, ground speed, velocity, surface angle (and any time the stick is locked), heading with the current turn rate, position, and rings and power-ups. A "Game" line shows lives, the stage clock and the last checkpoint.

### 5.7 Gimmicks (Milestone 5)

All of these are scenes in `engine/gimmicks/` and `engine/collectibles/`, and every number is a setting on the node.

- **Springs** launch the player along the spring's +Y axis, uncurled, so letting go of jump doesn't cut the launch short (classic air drag still applies). Yellow springs launch at 18.75 m/s (10 px/frame, about 7.1 m high) and red ones at 30 m/s (16 px/frame, about 18 m). Upward springs keep the player's running speed, as the classic ones do. Turning `keep_momentum` off launches exactly along the spring, for diagonal springs aimed at a ledge. A spring lying on its side sends a grounded player along the ground at its speed instead. Springs can lock the stick for a moment: 0.27 s (16 frames) for classic sideways springs.
- **Dash panels** send a grounded player along the panel's −Z axis at 30 m/s (the classic speed booster, 16 px/frame), or faster if they already were, and lock the stick for 0.25 s.
- **Spikes** hurt on touch, and again once the flashing runs out if the player is still on them.
- **Ring rows** (`RingLine`) place rings along a line, straight or arched over a jump.
- **Layers:** springs, dash panels, checkpoints and the solid body of item monitors are on `gimmicks`; rings, red rings and 1-ups on `collectibles`; spikes on `hazards`.
- **Stages** use `engine/systems/stage.gd` as their root script, which handles restarts and game over. `GameState` (autoload, `engine/systems/game_state.gd`) keeps what outlives a restart.

## 6. Camera

All three modes are needed because stages are hybrid:

1. Free orbit with auto-follow (the default)
2. `CameraVolume` boxes that blend to set angles for set pieces
3. Side view on 2.5D path sections, as a kind of camera volume

`engine/camera/player_camera.tscn` (Milestone 4) does all three. Its tuning lives in `engine/camera/camera_settings.tres`.

- **Free mode:** the camera orbits 6 m from a point 1 m above the player's feet, at −15° pitch by default. The mouse or right stick orbits it. One second after the player last touched the camera, it eases round behind them as they run, at up to 90°/s at top running speed. It leaves them alone when they run at the camera (more than 135° off), so they can come back toward it. `camera_recenter` swings it behind them in 0.25 s.
- **Look-ahead:** the camera aims 0.3 s of the player's velocity ahead of them (smoothed, at most 6 m). It only aims ahead; it doesn't move ahead, which could put it in front of a fast player.
- **Field of view:** 70° standing still, widening linearly to 85° at the player's top running speed (`top`), smoothed.
- **Loops:** the camera keeps world-up and never rolls. On steep surfaces it follows the direction the player was going before it got steep.
- **Walls:** a sphere cast from the player to the camera pulls it in front of anything in the way at once, then lets it ease back out at 6 m/s. It never sits inside geometry. If a wall pushes it closer than 1 m, the player's model is hidden.
- **Camera volumes** (`engine/camera/camera_volume.gd`): boxes that take over while the player is inside. The camera faces the volume's −Z axis (turn the node to aim it), with its own pitch, distance, optional fixed field of view and blend time. Side-view volumes are for 2.5D paths along the box's X axis and only look ahead along it. `avoid_walls` can be turned off where the view looks through geometry on purpose, such as the side of a loop. Overlapping volumes: the highest priority wins. Leaving a volume, free mode carries on from the volume's view.
- **Input during a switch:** movement is relative to the camera, but when a volume switches the view while the stick is held, input stays relative to the old view until the stick is let go. Running straight into a side-view section doesn't turn the player.
- The test room has a side-on loop view and a 2.5D side-view stretch at the far end of the runway (z −910 to −990).

Not built yet: constraining the player to the path in 2.5D sections. Side-view volumes only set the camera, so the player can still step off the path into depth. That belongs with the first act that has a 2.5D section.

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

**Loops:** `engine/gimmicks/loop_track.gd` generates a loop from its radius, width and exit offset, in the editor as well as in the game. The exit comes back down beside the entry, and low curbs along both edges keep the player on the track as it shifts sideways. The test room's loop has a 4 m radius, which a runner at top speed clears with about 5 m/s to spare at the top; anything slower doesn't make it.

---

## 8. Open decisions

Each one is grouped by the milestone where it starts to block work.

| Needed by | Decision |
|---|---|
| **Boost (after M4–M5)** | Boost speed and gauge rates; quickstep distance |
| **Structure** | Is Act 8 the boss act, or does a boss stage follow Act 8? (Act 8 names read like boss arenas.) |
| **M6 (first act)** | Level-building workflow: Blender stages, CSG greybox → Blender, or TrenchBroom |
| **M7 (art)** | Art style, poly budgets, outline and speed-line shaders, low-end performance target |
| **M8 (enemies)** | Badnik roster and boss concepts per world |
| **M9 (menus)** | HUD style; accessibility extras (game speed slider, assist mode) |
| **Later** | Special stages and Chaos Emeralds; ranking; time attack and ghosts; local and online multiplayer; music tool; 2D art tool; community channel; GameJolt |

## 9. Roadmap

| # | Milestone | Status |
|---|---|---|
| 1 | Project setup: repo, licenses, folder layout, Jolt, input map, CI, tests, title screen, greybox test room, debug overlay | **Done** |
| 2 | Player physics v1: flat ground, acc/dec/frc, jump, gravity, player values in the debug overlay | **Done** |
| 3 | Slopes, surface alignment, loops, slip/fall, rolling, spin dash | **Done** |
| 4 | Camera v1 plus camera volumes | **Done** |
| 5 | Gimmicks v1: springs, dash panels, rings, ring loss, monitors, checkpoints | **Done** |
| 6 | Greybox Emerald Shore Act 1 plus a playtest build | Next |
| 7 | Character art pipeline: Blender → glTF → AnimationTree | |
| 8 | Enemies and the first boss | |
| 9 | Menus, save system, settings, accessibility | |
| 10 | Art and audio pass, then a public demo release | |

**Scope plan:** 48 acts is a lot of content. Finish World 1 as a complete vertical slice (all its gimmicks, enemies and the boss) before greyboxing other worlds. Problems found in World 1 are much cheaper to fix than problems spread across six worlds.
