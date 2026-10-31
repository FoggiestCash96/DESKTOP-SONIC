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
| Assets | Blender 5.0 → glTF 2.0 (`.glb`). Commit both `.blend` and `.glb` (Git LFS). Godot's own `.blend` import is switched off (`filesystem/import/blender/enabled`), so the game always uses the exported `.glb`. |
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
- **Acts:** each act has its own focus (speed, platforming or combat). Emerald Shore Act 1 is a speed act (decided 2026-10-30).
- **Bosses** (decided 2026-10-30): each world's boss waits at the end of its **Act 8**, a short run that ends in the boss arena (§9.3).
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
| Homing attack, air dash | Yes. Homing locks on up to **12 m** away within a **90° cone** (45° either side), chosen 2026-10-29. Built in Milestone 8 (§9.2). |
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
- Since Milestone 7 the Player takes a `character` (a CharacterDef). Its model replaces the stand-in capsule and ball, and animates from the player's state (§8.2).

### 5.7 Gimmicks (Milestone 5)

All of these are scenes in `engine/gimmicks/` and `engine/collectibles/`, and every number is a setting on the node.

- **Springs** launch the player along the spring's +Y axis, uncurled, so letting go of jump doesn't cut the launch short (classic air drag still applies). Yellow springs launch at 18.75 m/s (10 px/frame, about 7.1 m high) and red ones at 30 m/s (16 px/frame, about 18 m). Upward springs keep the player's running speed, as the classic ones do. Turning `keep_momentum` off launches exactly along the spring, for diagonal springs aimed at a ledge. A spring lying on its side sends a grounded player along the ground at its speed instead. Springs can lock the stick for a moment: 0.27 s (16 frames) for classic sideways springs.
- **Dash panels** send a grounded player along the panel's −Z axis at 30 m/s (the classic speed booster, 16 px/frame), or faster if they already were, and lock the stick for 0.25 s.
- **Spikes** hurt on touch, and again once the flashing runs out if the player is still on them.
- **Ring rows** (`RingLine`) place rings along a line, straight or arched over a jump.
- **Checkpoints** count as passed anywhere through a gate around the post (`gate_width`), so a checkpoint can span the whole course and no route misses it.
- **Goal** (Milestone 6): running through it stops the clock and takes the controls away while the player coasts to a stop. The results (time, rings, red rings) show for 6 s, then the stage moves on: to its `next_scene`, or the title screen until the world map exists.
- **Tidal waves** (Milestone 6, Emerald Shore's Tidal Surge, decided 2026-10-30 as waves that push, with swimming later): a `TidalWave` washes along its −Z axis on a timer. The surge carries the player toward 17 m/s at 25 m/s², faster than running, so riding one gets up slopes too steep to run up. Then the water drains back as a deeper sheet, dragging toward the shore at up to 6 m/s at 8 m/s²: more than friction, so it moves a player standing still, while a runner only slows down. Then it rests. The water hugs the ground under it.
- **Rolling waves** (Milestone 8): a single crest that rolls along its −Z axis for `reach` metres, hugging the ground, then sinks away. A player it catches is carried along at its speed; jump it to stay clear. Bosses send them out (§9.3).
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
- **2.5D path lock** (Milestone 6): a camera volume with `lock_depth` also holds the player to the box's middle plane while they are inside. They are eased onto it at up to 8 m/s (`lane_pull_speed`), any motion across it is dropped, on the ground they run along the path, and the stick only moves them along it. The path is the box's X axis, so 2.5D sections are straight for now; curved ones would follow a `Path3D`. A loop inside such a section would need no sideways shift (`exit_offset` 0).

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

**Level building** (decided 2026-10-30): **Godot greybox, then Blender.** Acts are blocked out in the Godot editor with CSG shapes (`use_collision` on) and the generated pieces (loops, ring rows), playtested there, and remodelled in Blender for the art pass.

**Loops:** `engine/gimmicks/loop_track.gd` generates a loop from its radius, width and exit offset, in the editor as well as in the game. The exit comes back down beside the entry, and low curbs along both edges keep the player on the track as it shifts sideways. Players ride the inside curb as it shifts, so a red ring at the top goes on that line, not the middle. The curbs rise from nothing over the first and last 30° of the loop, so their ends can't snag a player running in. The test room's loop has a 4 m radius, which a runner at top speed clears with about 5 m/s to spare at the top; anything slower doesn't make it.

### 7.1 Emerald Shore Act 1: Sunny Beachfront (greybox, Milestone 6)

`content/sonic/stages/emerald_shore/act_1.tscn`, about 1.2 km long: a speedy run takes about 80 s. Two legs with a right turn between them:

1. **Beach start** (heading −Z): a ring row, a monitor, and a dash panel off to the side whose speed lasts into the first loop.
2. **First loop** (5 m radius) at the bottom of a downhill, with a red ring at its top.
3. **Tidal flats:** a wide beach where a wave washes up every 15.5 s, toward a 25° slope too steep to run up. Ride a wave (or spin dash) up it.
4. **Two routes from the crest:** jump a 9 m gap on the left to a high deck (a red ring over the gap, speed shoes, a dash panel), or run down the right to the low road (a shield, spikes, rings). The deck drops onto the ramp the low road climbs, and the routes meet at checkpoint 1.
5. **The corner:** a dash panel turns the run right (+X).
6. **2.5D pier:** a side view along a 4 m wide pier with gaps to the sea, spikes, and a red spring up to a high plank with a red ring.
7. **Second loop and rollers:** down to a second loop with a red ring at its top, up to checkpoint 2, over two humps, past a secret spring and an extra life high above another.
8. **Goal**, then a wall to stop against.

Falling into the sea (below y = −30) costs a life. The five red rings: the two loop tops, the gap to the deck, the plank, and one over a yellow spring by the rollers that needs you to stand still on it.

**Badniks** (Milestone 8): a crab on the beach start, a gull where the beach drops to the tidal flats (clear of where players wait for a wave), a hovering gull below the jump to the high deck (a stepping stone for anyone who comes up short), a crab on the deck, a clam and a crab on the low road, a gull over the merge, fish leaping across the pier, and a crab on the rollers. The goal leads on to Act 8 until Acts 2 to 7 exist. Milestone 8 also closed the pier's last gap, below the end of the high plank: players coming down long from the plank or the red spring fell into it with no warning.

### 7.2 Emerald Shore Act 8: Stormy Coastal Fortress (greybox, Milestone 8)

`content/sonic/stages/emerald_shore/act_8.tscn`, under a stormy sky (`stormy_environment.tres`): a short run along a walled causeway to the boss.

1. **Causeway:** two crabs, a clam on a block (a red ring above it), and checkpoint 1.
2. **The gap:** 12 m of sea, crossed with a homing chain on two hovering gulls (a red ring just above the second) or with the dash panel's speed and a jump.
3. **The bridge:** 4 m wide over the water, with three fish leaping across it in turn. A red ring floats over its middle.
4. **The platform:** a crab, a ring monitor, a red ring in the far corner, and checkpoint 2.
5. **The arena:** a beach 60 m wide below the fortress towers, walled in by cliffs, with the sea to the north and the fifth red ring in its far corner. A barrier closes the way in once the fight starts, a camera volume keeps the crab in view, and two ring monitors stand by the entrance. Beating the boss clears the act.

## 8. Art and characters

### 8.1 Art direction (decided 2026-10-30)

| | |
|---|---|
| Style | **Stylised toon**: cel shading (Godot's toon diffuse and specular modes) on flat colours. No ink outlines. |
| Speed lines | **Yes**, in the style of Sonic Colors: streaks flow out along the screen edges at high speed, and with the boost once it exists. They start at 12 m/s and are full by 26 m/s. |
| Motion blur | **Yes**, a full-screen radial blur at high speed (and boosting, later), from 16 m/s to full at 30 m/s. Some players find it uncomfortable, so it has an off switch (`motion_blur` in the camera settings now, the settings menu in Milestone 9). |
| Poly budgets | Player **30k** triangles, enemies **6k**, stage chunks **100k** per visible region |
| Low-end target | **60 fps at 1080p on a GTX 1060-class GPU**, with the Forward+ renderer |

Both speed effects live on the player camera (`engine/camera/speed_effects.gdshader`), drawn over the 3D view and under the HUD, and switch off entirely when there is nothing to show.

### 8.2 Character pipeline (Milestone 7)

From Blender to the game:

1. **Model in Blender** at 1 unit = 1 m, about 1 m tall to match the collision capsule, feet at the origin, facing +Y (glTF turns that into Godot's −Z). Give the armature the standard bones: `root` (the ball spins around it, 0.3 m up), `hips`, `chest`, `head`, and `upper_arm`, `forearm`, `hand`, `thigh`, `shin` and `foot`, each with `.L` and `.R`.
2. **Animate** one action per animation, with exactly these names: `idle`, `walk`, `jog`, `run`, `max_run`, `skid`, `ball`, `spring`, `fall`, `push`, `hurt`, `death`, `victory`.
3. **Export** with `tools/blender/export_glb.py`: binary glTF, skin kept, every action as its own animation.
4. **Import** in Godot with `engine/player/character_import.gd` as the `.glb`'s import script. It gives every material the toon look and loops the cyclic animations.
5. **Character scene**: the imported model under a root with `engine/player/character_model.gd`, plus an AnimationTree. On the ground the run cycle blends by speed: idle at 0, walk at 2, jog at 5, run at 10 and max run at 18 m/s, playing faster beyond that. The other poses are inputs of a transition with a 0.12 s crossfade, and the ball spins faster the faster the player moves.
6. **CharacterDef** (`engine/player/character_def.gd`): the character's name, model and, if it moves differently, its own `PlayerPhysics`. A stage gives one to its Player's `character`. Without one, the player is the stand-in capsule.

The model shows, in order of priority: death, hurt, the ball (jumping, rolling or spin dashing), spring (rising after a spring), fall (in the air otherwise), victory (stopped after the goal), skid (braking), push (pressing into a wall), and otherwise the run cycle (`PlayerMotion.pose()`).

**The stand-in Sonic** (`content/sonic/characters/sonic/`) is built entirely by `build_sonic.py`: simple shapes, each bound rigidly to one bone, in 3,526 triangles with 16 bones and all 13 animations. It proves the pipeline before real art exists. A hand-made model replaces it by keeping the bone names, animation names and conventions above.

## 9. Enemies and bosses

### 9.1 Enemies (Milestone 8)

Enemies are built on `engine/enemies/base/enemy.gd`: a small state machine that patrols, notices a player who comes close, attacks, and is stunned for a moment afterwards. Four behaviours live in `engine/enemies/`, and each world dresses them up as its own badniks in `content/sonic/enemies/`.

| Behaviour | What it does |
|---|---|
| `WalkerEnemy` | Patrols back and forth along the ground, rears up on noticing a player, then charges at where they were. It follows the ground and stops at edges and walls. |
| `FlyerEnemy` | Hovers, bobbing, and dives at a player who comes close, then flies home. With `swoops` off it only hovers, as a stepping stone for homing chains. |
| `TurretEnemy` | Stays put, opens up for a player in range, and fires shots at where they were. |
| `LeaperEnemy` | Waits out of sight below its spot and leaps out in an arc on its own timetable, across a path or straight up. |

- **Touching an enemy** hurts the player, unless they're curled up (jumping, rolling, spin dashing or homing in) or invincible. Then it bursts and frees an animal. Shots hurt even a curled-up player, unless a shield or invincibility protects them. Destroyed enemies come back when the stage reloads.
- **Rebound**, the classic rule: destroying one in the air while falling onto it from above bounces the player back up at the speed they fell. Rising, or level with its middle or lower, they're only slowed by 1 px/frame (1.875 m/s, `rebound_slowdown`). After a homing attack they bounce straight up instead (§9.2). Rolling or spin dashing on the ground, they carry straight on.
- **Homing targets:** every enemy, item monitor and boss weak point carries a `HomingTarget` marker where the attack aims, switched off while the thing can't be hit.
- **Animations:** if an enemy's model has an AnimationPlayer with animations named after the modes (`patrol`, `notice`, `attack`, `stunned`), each plays as its mode starts, so real models from Blender drop in the same way.

**Emerald Shore's badniks** (decided 2026-10-30): four original fan designs, built from simple shapes until the art pass.

| Badnik | Behaviour | Details |
|---|---|---|
| Scuttler | Walker | A crab. Patrols sideways 4 m either way, notices within 7 m, raises its claws and charges 7 m at 9 m/s. |
| Galegull | Flyer | A robot gull. Notices within 9 m and dives at 11 m/s. Hovering ones bridge gaps for homing chains. |
| Pearlshot | Turret | A clam. Within 14 m it opens and fires two pearls 0.8 s apart at 8 m/s. |
| Leapfin | Leaper | A fish. Leaps across piers and bridges, or straight up out of a pool. |

### 9.2 Homing attack and air dash (Milestone 8)

- **Homing attack:** pressing jump again in the air, once each time the player leaves the ground, locks on to the nearest target within **12 m** and **45° either side** of the way they face (where the stick points, or with it let go, their direction of travel), with no level geometry in the way. The player curls up and flies straight at it at 28 m/s, following it as it moves. A hit bounces them straight up at 10 m/s with the move ready again, so attacks chain from target to target. The attack gives up after 0.6 s, or if the target goes away.
- **Air dash:** with nothing in reach, the same press dashes ahead at 15 m/s (or the player's own speed, if faster), dropping any sideways drift and stopping a fall for a moment.
- It works after a jump, after running off a ledge, and after a spring. A yellow reticle shows on whatever a homing attack would lock on to.
- The values are in `player_physics.tres` (the "Homing attack" and "Enemies" groups).

### 9.3 Bosses (Milestone 8)

- **`engine/enemies/base/boss.gd`:** a boss takes `hits` hits, by default **8**, and moves on a phase at each of `phase_changes` hits left, by default **4 and 2**. After each hit it flashes for 1 s and can't be hit again, and the player is thrown back off it. Its weak point takes hits only while the boss is open to attack (`vulnerable`). Its body hurts a player standing up and bounces off a curled-up one, and attack parts (claws and the like) hurt anyone while they're active. Defeating it clears the stage 3 s later, with the results as at a goal.
- **`BossArena`:** an area that raises its barriers when a player first enters and starts the boss, intro first.
- A camera volume with a `focus` keeps that node in view beyond the player, which an arena uses to keep its boss on screen.
- The HUD shows a boss's name and hits left during its fight.
- **Where:** at the end of each world's Act 8 (decided 2026-10-30).

**Emerald Shore's boss: the Egg Tidecrab** (decided 2026-10-30: the user's combination of a wave-making ship and a crab mech).

- **Intro:** Eggman's ship flies in over the sea and lowers a pump that raises a great wave, then flies off. He isn't seen again in the stage. The crab mech rises out of the wave as it breaks on the beach.
- **Fight:** the crab scuttles sideways to line up with Sonic. Within about 6.5 m it sweeps a claw across in front of it (jump it). Otherwise it raises both claws and slams them down, sending waves rolling across the beach (jump them, or be carried away), and sinks low with the lid over its glowing core open: that's the moment to hit it, from a jump or with a homing attack.
- **Phases:** 1 wave per slam and the core open for 3.5 s at first. From 4 hits left it moves faster, sends 2 waves and opens for 3 s. From 2 left: 3 waves, 2.5 s, and a charge across the beach before each slam. It turns redder with each phase.
- **Defeat:** it bursts into explosions and collapses, and the act is clear.

---

## 10. Open decisions

Each one is grouped by the milestone where it starts to block work.

| Needed by | Decision |
|---|---|
| **Boost (after M4–M5)** | Boost speed and gauge rates; quickstep distance |
| **Each world, as it's built** | Its badnik roster and boss concept. Emerald Shore's are decided (§9). |
| **M9 (menus)** | HUD style; accessibility extras (game speed slider, assist mode) |
| **Later** | Special stages and Chaos Emeralds; ranking; time attack and ghosts; local and online multiplayer; music tool; 2D art tool; community channel; GameJolt |

## 11. Roadmap

| # | Milestone | Status |
|---|---|---|
| 1 | Project setup: repo, licenses, folder layout, Jolt, input map, CI, tests, title screen, greybox test room, debug overlay | **Done** |
| 2 | Player physics v1: flat ground, acc/dec/frc, jump, gravity, player values in the debug overlay | **Done** |
| 3 | Slopes, surface alignment, loops, slip/fall, rolling, spin dash | **Done** |
| 4 | Camera v1 plus camera volumes | **Done** |
| 5 | Gimmicks v1: springs, dash panels, rings, ring loss, monitors, checkpoints | **Done** |
| 6 | Greybox Emerald Shore Act 1 plus a playtest build | **Done** |
| 7 | Character art pipeline: Blender → glTF → AnimationTree | **Done** |
| 8 | Enemies and the first boss | **Done** |
| 9 | Menus, save system, settings, accessibility | Next |
| 10 | Art and audio pass, then a public demo release | |

**Scope plan:** 48 acts is a lot of content. Finish World 1 as a complete vertical slice (all its gimmicks, enemies and the boss) before greyboxing other worlds. Problems found in World 1 are much cheaper to fix than problems spread across six worlds.
