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
- **Hub:** world map: for now a menu map of the six worlds (decided 2026-10-31, §10.1). A grander one comes with the art pass.
- **Acts:** each act has its own focus (speed, platforming or combat). Emerald Shore Act 1 is a speed act (decided 2026-10-30).
- **Bosses** (decided 2026-10-30): each world's boss waits at the end of its **Act 8**, a short run that ends in the boss arena (§9.3).
- **Routes:** 1 to 3 per act. High routes reward skill, low routes are safer.
- **Save system:** 10 save slots, each a JSON file in `user://saves/` with its act progress, best times and red rings, saved after every act (decided 2026-10-31). Settings are kept apart, for the whole game (§10.2).

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
| Roll, spin dash, drop dash (hold 0.33 s), Super Peel Out | Yes: the roll and spin dash built in Milestone 3, the drop dash and Super Peel Out in Milestone 11 (§5.10) |
| Homing attack, air dash | Yes. Homing locks on up to **12 m** away within a **90° cone** (45° either side), chosen 2026-10-29. Built in Milestone 8 (§9.2). |
| Boost, air boost | Yes, built 2026-10-31 (decided then: 30 m/s on the ground and in the air, about 5 s per full gauge), §5.8 |
| Quickstep | Yes, built with the boost (2.5 m sideways), §5.8 |
| Drift | Yes, Milestone 11 (§5.10) |
| Stomp/bounce | The stomp (decided 2026-11-05), Milestone 11 (§5.10) |
| Grind rails (`Path3D`) | Yes, built in Milestone 10 for Acts 2 to 7 (§5.7) |
| Wall-run and wall-jump | Yes, on marked walls only (decided 2026-11-05), Milestone 11 (§5.10) |
| Swimming (half acc/dec/frc/top and gravity, air timer) | Yes, built in Milestone 10 with drowning (§5.9) |
| Light speed dash | **Yes**, chosen 2026-10-29 (`special` button along ring trails), Milestone 11 (§5.10) |
| Insta-shield and elemental shields | No |

### 5.5 Damage, rings and lives

Built in Milestone 5. The values are classic ones, in `player_physics.tres` (damage, ring loss and power-ups) and `engine/systems/game_rules.tres` (lives and restart timing).

- **Rings:** touch one to collect it. The HUD's ring count flashes red at zero, because the next hit is then fatal. 100 rings don't give a life.
- **Hit with rings:** all of them are lost, and up to 32 scatter. The first 16 fly out at 7.5 m/s and the rest at 3.75 m/s, fanned out all around the player and upward. They fall under 10.55 m/s² of gravity and bounce off level geometry, keeping 75% of their speed into the surface. They can be grabbed back after 64 frames (1.07 s) and vanish after 256 frames (4.27 s).
- **Knockback:** a hit throws the player away from what hurt them at 3.75 m/s and up at 7.5 m/s, under lighter gravity (21.09 m/s²) and with no control. Landing stops them dead. Then follow 2.0 s (120 frames) of flashing, during which nothing can hurt them.
- **Shield:** takes the next hit instead of the rings, with the same knockback and flashing.
- **Hit with no rings:** the player dies. They hop up at 13.1 m/s and fall through everything, and the camera stops to watch. 2 s later the stage restarts from the last checkpoint, a life down.
- **Lives:** you start with **5**. Extra lives come only from a unique hidden 1-up object in each act. Each gives a life once per visit, and one found before a death stays found. Losing the last life shows GAME OVER for 3 s, then the world map returns (or the title screen, with no save slot) with 5 lives again. Nothing on the save slot is lost.
- **Pit deaths** are on: falling below `kill_height` (y = −50 m) costs a life the same way. **Crush deaths** are on too (since Milestone 10): a moving platform that squeezes the player into the level kills them, rings or not. So does **drowning** (§5.9).
- **Item monitors** (decided 2026-10-30):

| Item | Effect |
|---|---|
| Rings | 10 rings. The amount is a setting on each monitor, so 5- and 20-ring boxes need nothing new. |
| Shield | Takes the next hit in place of the rings |
| Speed shoes | 20 s of doubled acceleration, friction, top speed, air acceleration and roll friction, as the classic shoes |
| Invincibility | 20 s of ignoring hits. Pits still kill. |
| Ring magnet | 20 s of pulling in rings within 5 m. A pulled ring flies 15 m/s faster than the player, so it always catches up. |
| Boost refill | Fills the boost gauge |

  Monitors are solid: a player standing up bumps into them or stands on them. Curled up (jumping, rolling or spin dashing) they break them open. Breaking one from above bounces the player back up: their falling speed turns into rising speed, still cut short if jump is let go.
- **Hidden collectibles** (decided 2026-10-30): **red rings, 5 per act.** The HUD counts them. One found before a death stays found and shows greyed out after the restart. Clearing the act saves the ones found to the save slot for good (Milestone 9); on later visits they show greyed out, and the HUD and map count them.
- **Checkpoints:** passing a post saves the spot and the stage clock. After a death the stage restarts 1 m in front of the post, facing the way it points, with the clock as it was then and no rings. The lamp turns from blue to red.
- **Stage clock:** counts up with no time limit (the modern rule; the classic games had 10 minutes). It stops while the player is dead.

### 5.6 Player controller (Milestones 2 and 3)

- `engine/player/player.tscn` is a `CharacterBody3D` on the `player` layer, colliding with `world` and `gimmicks` (for solid item monitors). Its origin is at its feet. Standing, it uses a capsule 1.0 m tall and 0.3 m in radius; rolling, spin dashing and jumping it curls into a 0.3 m ball.
- It is a state machine with one script per state in `engine/player/states/`: `GroundState` (run, brake, turn, crouch), `RollState`, `SpinDashState`, `AirState`, and since Milestone 5 `HurtState` (knockback) and `DeathState`; `HomingState` (Milestone 8), `GrindState` (Milestone 10), and in Milestone 11 `StompState`, `PeelOutState`, `DriftState`, `LightDashState`, `WallClingState` and `WallRunState`. The shared surface handling, rings, hits and power-ups live in `player.gd`.
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
- **Water** (Milestone 10, for Acts 2 to 7): a `WaterVolume` is a box of water whose surface is its node's XZ plane. Below the surface the player swims (§5.9) and the camera tints the view. Water can have a **current** that carries the player along its −Z axis (`current_speed`, pushing at 15 m/s²); tilted, it runs a stream down a slope, as on Act 3's waterslides, where the current (16 to 18 m/s) beats running. It can have a **tide** that raises the surface by `tide_height` on a timer (low, rising, high, falling), flooding whatever lies below, as in Act 6. Its surface uses the toon water shader, streaked along a current.
- **Air bubbles:** a vent under water breathes out a trickle of small bubbles, and every `interval` seconds (3.5 to 4) a big one that rises. Touching a big one gives the player a breath (§5.9).
- **Grind rails:** a `GrindRail` follows its curve and builds its own tube. Landing on it, or running onto its end, grinds along it: gravity speeds the player up downhill and slows them uphill (as when rolling), friction takes a little off (0.5 m/s², but never below 5 m/s), and pushing the stick the way they're going speeds them up to top speed. The boost holds its speed on a rail too. Jump leaves it with a jump, a quickstep hops to a rail up to 5 m beside it, and its end throws the player on into the air. A rail catches feet within 0.6 m, and not again for 0.3 s after leaving it.
- **Moving platforms:** a `MovingPlatform` travels back and forth by `travel` in its own space, easing in and out and waiting at each end, or floats on a `WaterVolume`, rising and falling with its tide. Players ride it. One that squeezes a player into the level crushes them (§5.5). It looks like a stone slab or a raft of logs.
- **Crumbling platforms:** a `CrumblingPlatform` shakes for 0.5 s once a player stands on it, then falls, and comes back 6 s later. A run across a row of them holds.
- **Breakable walls:** a `BreakableWall` of loose rocks. Rolling (or spin dashing) or boosting into it at 3 m/s or more smashes through without slowing down, and the rocks fly apart; anything else stops against it. It comes back when the stage reloads. Acts 2, 3, 5 and 6 hide their extra lives behind one.
- **Wall-jump panels and wall-run strips** (Milestone 11): a `WallJumpPanel` is a patch of wall to cling to and kick off, a `WallRunStrip` a band along a wall to run on (§5.10). Each builds its own plate and catch area; only walls that carry one can be clung to or run on.
- **Layers:** springs, dash panels, checkpoints, wall-jump panels, wall-run strips and the solid body of item monitors are on `gimmicks`; rings, red rings and 1-ups on `collectibles`; spikes on `hazards`.
- **Stages** use `engine/systems/stage.gd` as their root script, which handles restarts and game over. `GameState` (autoload, `engine/systems/game_state.gd`) keeps what outlives a restart.

### 5.8 Boost and quickstep

Built after Milestone 9 (decided 2026-10-31). The values are in `player_physics.tres` (the "Boost" and "Quickstep" groups).

- **Boost** (`boost`: Shift, X or RT): pressed on the ground with some gauge left, the player snaps to **30 m/s** (a dash panel's speed, and the most collision handles safely) and holds at least that while the button is held. They can't brake, but steer as at any high speed. It smashes through enemies and breaks monitors as a curled-up player does, but spikes and shots still hurt. Letting go, running out of gauge, a hit, rolling, a spin dash, or running head-on into a wall ends it. It carries on through jumps while held, and picks up again on landing.
- **Air boost:** pressed in the air, a straight dash at 30 m/s where the player faces (the stick, or their direction of travel), with no gravity for 0.4 s. Once each time they leave the ground, for 10% of the gauge. Held on, the boost carries on after landing.
- **The gauge** (decided: about 5 s per full gauge): boosting on the ground uses **20% a second**; each act starts **a third full**; each ring adds **2%** (50 rings fill it), each enemy destroyed **10%**, and a boost monitor fills it.
- **Quickstep** (`quickstep_left` / `quickstep_right`: Q / E, LB / RB): running on the ground at 8 m/s or faster, the player shifts **2.5 m** sideways in 0.12 s, keeping their speed and heading, for dodging at boost speed. Not on 2.5D paths.
- **Feedback:** while boosting the speed lines and motion blur show at full strength, the view widens to 95°, a shell of light surrounds the player, and a burst of air marks the start. The HUD's boost gauge sits at the bottom right (§10.4).

### 5.9 Swimming and drowning

Built in Milestone 10 for Acts 2 to 7 (decided 2026-11-02: the classic rules). The values are in `player_physics.tres` (the "Water" group).

- **Under water** (the player's middle below a `WaterVolume`'s surface): acceleration, deceleration, friction, top speed, air acceleration, roll friction and the boost's speed are halved, as the classic games halve them. Gravity is 0.0625 px/frame² (7.03 m/s²), a jump leaves at 3.5 px/frame (6.56 m/s), and letting go of jump early caps the rise at 2 px/frame (3.75 m/s).
- **In and out:** falling in keeps half the horizontal speed and a quarter of the vertical, with a splash. Leaving the water while rising doubles the upward speed, so a jump from under the surface carries the player out.
- **Slopes:** with the acceleration halved, slopes steeper than about 11° can't be run up under water. The acts' ways out of the water are gentler than that (Act 3's pool ramp is 8°).
- **Air:** 30 s. Chimes warn at 25, 20 and 15 s left. With 12 s left the drowning music (§11.2) takes over from the stage's, and a big count from 5 down to 0 shows high in the middle of the screen, one number every 2 s. At 0 the player drowns, which costs a life, rings or not.
- **Breathing:** surfacing, or touching a big air bubble (§5.7), fills the air again and ends the countdown and its music. A breath from a bubble holds the player still for 0.35 s.
- The view under water is tinted blue.

### 5.10 Drop dash, stomp, Super Peel Out, drift, light speed dash and walls (Milestone 11)

Decided 2026-11-05: Milestone 11 finishes the moveset, so later worlds can be built for all of it. The values are in `player_physics.tres`.

- **Stomp** (roll in the air: Ctrl / B): a slam straight down at 30 m/s (16 px/frame, the classic top falling speed), curled up, so it destroys badniks and breaks monitors on the way down without bouncing off them. It lands without speed, but for what a slope gives. Not during a homing attack, a knockback or an air boost.
- **Drop dash** (as in Sonic Mania): with nothing in homing reach, holding the second jump press for 0.33 s (20 frames) charges it, and landing with jump still held launches a roll at 15 m/s (8 px/frame) plus a quarter of the speed already going that way, up to 22.5 m/s (12 px/frame); against the way the player was going, at 15 m/s. Letting go before landing cancels it. A quick tap of the second press is still the air dash, now fired as the button is let go. With a homing target in reach, the press is the homing attack, as before.
- **Super Peel Out** (as in Sonic CD): standing still, hold drift (C / LT) and tap jump to rev. After 0.5 s (30 frames) of revving it's ready, and letting go of drift launches the player running at 22.5 m/s (12 px/frame); letting go sooner cancels it. The stick aims it while revving, as with the spin dash.
- **Drift** (hold drift while running at 10 m/s or more and steering): the player slides round the corner, turning up to 300°/s however fast they go, where running turns 180°/s at speed. Friction still slows them, though the boost holds its speed.
- **Light speed dash** (special: F / Y, decided 2026-10-29): with a ring within 3 m, the player zips from ring to ring at 40 m/s, collecting them, for as long as the next ring is within 6 m, then carries on at 15 m/s. A trail of rings across a gap is a path only the light speed dash can follow.
- **Wall-jump panels** (marked walls only, decided 2026-11-05): a `WallJumpPanel` on a wall catches a player who jumps into it. They cling, sliding down slowly for up to 1 s, and jump kicks them off and up (9 m/s out, 13 m/s up), so two facing panels make a shaft to climb.
- **Wall-run strips** (marked walls only): a `WallRunStrip` along a wall catches a player who jumps at it going 10 m/s or more along its length. They run on the wall at their speed with no gravity, carry on into the air at its end, and jump kicks them off it. The camera pivots 0.75 m out from the wall meanwhile, so it stays out of the rock.
- Ordinary walls work as before.
- **Where to try them:** the test room's moves area has a spot for each. In Emerald Shore: a wall-jump climb up to Act 2's high shelf, a wall to run along over Act 5's chasm, and a ring trail for the light speed dash over Act 7's cannon chasm (§7.2). The others work anywhere.

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

**Greybox first:** every act starts as blockout geometry plus gimmicks, gets playtested, then gets an art pass in Blender. The greybox stays in the act, hidden, as its collision, and the art never collides (§8.3).

**Level building** (decided 2026-10-30): **Godot greybox, then Blender.** Acts are blocked out in the Godot editor with CSG shapes (`use_collision` on) and the generated pieces (loops, ring rows), playtested there, and dressed in Blender for the art pass by a script that reads the greybox (§8.3).

**Loops:** `engine/gimmicks/loop_track.gd` generates a loop from its radius, width and exit offset, in the editor as well as in the game. The exit comes back down beside the entry, and low curbs along both edges keep the player on the track as it shifts sideways. Players ride the inside curb as it shifts, so a red ring at the top goes on that line, not the middle. The curbs rise from nothing over the first and last 30° of the loop, so their ends can't snag a player running in. The test room's loop has a 4 m radius, which a runner at top speed clears with about 5 m/s to spare at the top; anything slower doesn't make it.

### 7.1 Emerald Shore Act 1: Sunny Beachfront (Milestone 6, art in Milestone 10)

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

**Badniks** (Milestone 8): a crab on the beach start, a gull where the beach drops to the tidal flats (clear of where players wait for a wave), a hovering gull below the jump to the high deck (a stepping stone for anyone who comes up short), a crab on the deck, a clam and a crab on the low road, a gull over the merge, fish leaping across the pier, and a crab on the rollers. The goal leads on to Act 2 (to Act 8 until Acts 2 to 7 existed). Milestone 8 also closed the pier's last gap, below the end of the high plank: players coming down long from the plank or the red spring fell into it with no warning.

### 7.2 Emerald Shore Acts 2 to 7 (Milestone 10)

Decided 2026-11-02, so the demo has all eight acts (the user: "The game should have stages 1 though 8. Not 1 and 8."):

| Act | Focus | The idea |
|---|---|---|
| 2: Lush Palm Grove | Platforming | A treetop route on springs and rope bridges over the jungle floor |
| 3: Cascading Waterfall Basin | Speed | Race down the cascades, and climb the tiers between them |
| 4: Shallow Reef Lagoon | Combat | Badnik packs and homing chains between reef islets, and big waves |
| 5: Underground Grotto | Platforming | Caves, 2.5D stretches and hidden rooms |
| 6: Tidal Cavern | Mixed | The tide floods the low route on a timer; the high ledges stay dry |
| 7: Sunset Ridge Cliffs | Speed | The long cliff-top run toward the fortress: loops and big jumps |

- **Length:** like Act 1: a good run takes about 80 to 100 s and a first careful one 2 to 3 minutes, so the speed acts run about 1 to 1.3 km and the platforming ones less.
- **New gimmicks:** all four offered: flowing and rising water (waterfall currents that carry the player, a tide that rises and falls), grind rails, moving and crumbling platforms (which bring crush deaths in), and breakable walls that a roll, spin dash or boost smashes open.
- **Swimming and drowning** in the water acts (Shallow Reef Lagoon, Tidal Cavern), with the classic rules: slower movement and lighter gravity underwater, 30 s of air with a countdown and its music, air bubbles to breathe, and drowning costs a life.
- **Music:** a new track for each act, written with `tools/audio/` like the others, each Emerald Shore's tune in its act's setting, with speed-shoe versions.

Built 2026-11-02 to 11-05. Each is `content/sonic/stages/emerald_shore/act_<n>.tscn`, and each act's goal leads on to the next (Act 7's to Act 8). Falling into the sea (below y = −30) costs a life in all of them. An autopilot drives each act from the start to the goal on its safest route, in 76 to 82 s on the stage clock, then tries its other routes and gimmicks one by one.

#### Act 2: Lush Palm Grove

About 0.9 km in three legs. Platforming: a treetop route over a safe jungle floor.

1. **The jungle floor** (heading −Z): an 18 m wide floor between palm trunks, the safe route. A diagonal spring on its left ("to the treetops") throws the player up to the treetop route: decks 6 m up joined by rope bridges, with a red ring over the gap between two decks and a shield. A fall from the decks lands on the floor. A breakable wall on the floor's right hides an alcove with the extra life.
2. **The ravine:** the routes meet at checkpoint 1 above a ravine. A long rope bridge on the right crosses it safely; on the left, two moving platforms and two crumbling ledges between them cross faster, with speed shoes and a red ring on the second ledge.
3. **The canopy** (heading +X): a lift, a homing chain on two gulls, or a wall-jump climb (panels on the shelf's cliff and on a rock pillar facing it, Milestone 11) goes up to a high shelf 16 m up, with a red ring at its end. From there a vine rail runs down over the canopy, with a red ring along it. Below, the canopy carries on over a pit (a crumbling ledge in it), past checkpoint 2, to a red spring with a red ring high above it.
4. **The terraces** (heading −Z): down three terraces to fallen logs across the way (or a rail above them on the left), a loop, a bridge over the river, and the beach with the goal.

Badniks: crabs on the start, the floor, the rope bridge (patrolling it), the far bank, the canopy, the terraces, the logs and the beach; clams on the third deck, the canopy and the beach; gulls hovering under the decks' gap and over the ravine's platforms as stepping stones, two for the homing chain, and one over the river.

#### Act 3: Cascading Waterfall Basin

About 1 km in two legs, from a plateau 60 m up down to the sea. Speed: waterslides whose current is faster than running.

1. **The first cascade** (heading −Z): a dash panel sends the player down a 140 m waterslide, with a current of 18 m/s down its middle ("Ride the current!").
2. **The tiers:** a basin with a loop (a red ring at its top), then three tiers, each climbed by a yellow spring beside a waterfall. A red spring on the top tier throws the player up to a red ring.
3. **The second cascade:** 160 m down to the second basin, with a rail beside the stream for a faster line and a red ring over the rail. In the basin, a breakable wall hides the extra life, and checkpoint 1.
4. **The third cascade** (heading +X): 120 m down, with another rail, to a plunge pool crossed on three floating logs or swum, with a red ring over its middle. The pool is shallow, and its ramp out a gentle 8°. Checkpoint 2.
5. **The last cascade** down to the beach, a loop with the fifth red ring at its top, and the goal.

Badniks: crabs on the start, both basins, the bank past the pool and the beach; clams on the middle tier and the ledge before the third cascade; gulls hovering by the top tier and over the third cascade's rail, and one swooping over the beach; fish leaping out of the second cascade's stream and out of the plunge pool.

#### Act 4: Shallow Reef Lagoon

About 0.85 km in two legs. Combat: packs of badniks on reef islets, homing chains across the channels between them, and waves to surf. The lagoon's surface is the sea's (y = −1): sandbars lie just under it, to wade through at full speed, and islets stand above it. Only the three channels are deep enough to swim in, with air bubbles on their beds and gentle slopes out; beyond the sandbars the open sea is a fall. A shield waits before each pack.

1. **Sandbar and first islet** (heading −Z): two crabs and a gull on the sandbar, then two clams and a crab on the islet.
2. **The first channel:** a homing chain of three gulls across it, or a swim past a red ring by the air bubbles. A fish leaps across.
3. **The second islet:** checkpoint 1, and a pack of three crabs and two clams.
4. **The surfing sandbar:** waves wash along a 90 m sandbar every 14 s ("Surf the waves!"), with a red ring above it to jump for and gulls over it.
5. **The high islet,** 5 m up: two clams and a hovering gull, with a red ring high above them, reached off the gull.
6. **The reef ridge** (heading +X): a narrow coral ridge with four fish leaping over it in turn, and a red ring on a coral pillar beside it.
7. **The second channel:** a drifting raft, a homing chain, or a swim past the extra life on the bed and a red ring by the bubbles.
8. **The big islet:** checkpoint 2 and the biggest pack: four crabs, two clams and two gulls.
9. **The third channel** (gulls or a swim), a pack of two crabs, a clam and two gulls, a second surfing sandbar, and the goal on the last islet.

#### Act 5: Underground Grotto

About 0.7 km. Platforming in caves, under a dim sky of its own (`grotto_environment.tres`), with two 2.5D stretches.

1. **Into the cave** (heading −Z): a tunnel from the beach. A breakable wall under a rock lintel on its right hides a room with the extra life and a red ring.
2. **The chasm:** a narrow ledge along the left wall (safe), three crumbling stones across the middle, with a red ring over the second, or (Milestone 11) a wall-run strip along the right wall, 3 m up, with rings along it ("Running fast? Jump at the gold strip to run along the wall!"). Checkpoint 1.
3. **The great hall,** crossed in 2.5D (heading +X): a pit with a platform shuttling over it, two crumbling ledges end to end over another pit (keep running and they hold), a lift to a high ledge (a red ring above its top stop), spikes, and a rock wall across the way to roll or boost through ("Roll or boost to smash through!").
4. **The river tunnel,** in 3D again: a river with a 12 m/s current, a rail beside it with a red ring on its line, and fish leaping across. Checkpoint 2.
5. **The shaft,** climbed in 2.5D: a spring to a ledge (a red ring above it), a lift, and a red spring up into the daylight, the exit and the goal.

Badniks: crabs on the beach, in the tunnels, in the hall and at the exit; clams in the second tunnel and the shaft; a gull hovering over the chasm (a stepping stone) and one in the hall; two fish in the river.

#### Act 6: Tidal Cavern

About 0.6 km in two legs, under the grotto's sky. Mixed: two sea caverns whose tide rises 4.5 m on a 28 s cycle (9 s low, 5 s rising, 9 s high, 5 s falling). The low route along each cavern's floor is quick at low tide and under water at high tide: swim it, with air bubbles along the way, or ride a raft up with the water. The high route along ledges over it stays dry, with its own hazards ("Low tide: run. High tide: swim, or take the ledges.").

1. **The first cavern** (heading −Z): a spring up to the ledges, a red ring over the gap between the first two, a clam, three crumbling ledges in a row, a gull, and a rail down to the dry midpoint. Below, two rafts (a red ring over the first, reached by riding it up at high tide), a crab and a fish.
2. **The dry midpoint:** checkpoint 1, and a dash panel round the corner.
3. **The second cavern** (heading +X), its tide out of step with the first: on the ledges, a shuttling platform over a gap (a red ring over it), a clam, a nook behind a breakable wall with the extra life, and a rail with a red ring on its line. Below, checkpoint 2, two rafts, two crabs and a fish.
4. **The tide pool:** a chamber whose water rises 7.5 m. Swim or ride a raft up to the exit at high tide ("Ride the tide up!"); at low tide a red spring throws the player up to it, or a ledge goes round. The fifth red ring is by the pool's air bubbles.
5. **The exit,** a crab and the goal outside.

#### Act 7: Sunset Ridge Cliffs

About 1 km in three legs, from 40 m up down to just above the sea, under a sunset sky (`sunset_environment.tres`) with a low, warm sun ahead of the final straight. Speed: the long cliff-top run toward the fortress.

1. **Leg one** (heading −Z): a dash panel and a long downhill to a loop (a red ring at its top), then a dash panel and a ramp to jump a chasm (a red ring over it), or a sloping bridge beside it. A 120 m downhill follows, with two rails over the cliff edge and a red ring on the outer one, to checkpoint 1 and speed shoes.
2. **Leg two** (heading +X): a spring cannon (a red spring tilted to throw anyone who touches it over a 16 m chasm, with a red ring on its arc) or a homing chain of three gulls beside it, or (Milestone 11) a trail of rings arcing over the chasm just beyond the gulls, for the light speed dash, a loop, and a second big jump from a dash panel and a ramp, or a bridge.
3. **Leg three** (heading −Z): a loop (the fifth red ring at its top), a narrow ridge with rails on both sides over the void (checkpoint 2, and gulls swooping), the extra life on a sea stack off the ridge, and the final straight with Act 8's fortress out at sea ahead.

Badniks: crabs on the start, the first loop's floor, the ledges, the third leg's run and the final straight; clams on both landings; gulls over the first downhill and the rail run, three by the cannon, and two over the ridge.

### 7.3 Emerald Shore Act 8: Stormy Coastal Fortress (Milestone 8, art in Milestone 10)

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
| Speed lines | **Yes**, in the style of Sonic Colors: streaks flow out along the screen edges at high speed, and at full strength while boosting. They start at 12 m/s and are full by 26 m/s. |
| Motion blur | **Yes**, a full-screen radial blur at high speed, from 16 m/s to full at 30 m/s, and at full strength while boosting. Some players find it uncomfortable, so it has an off switch (the Options menu's Camera tab, Milestone 9). |
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

**Sonic** (`content/sonic/characters/sonic/`) is built entirely by `build_sonic.py`. Since the art pass (§8.3) his fur is one smooth surface: simple shapes (head, muzzle, ears, quills, body, arms and legs, each with a colour and a bone) are fused by a voxel remesh and trimmed to the budget, each face takes the colour of the shape it lies on, and each vertex is skinned to the bones of the shapes near it, so the joints bend smoothly. The eyes, nose, gloves and shoes (red, with a white strap, a gold buckle and a white sole) are separate pieces, each moving with one bone. He has 22,024 triangles, 16 bones and all 13 animations. A hand-made model can replace him by keeping the bone names, animation names and conventions above.

### 8.3 The art pass (Milestone 10)

Decided 2026-11-01: the art pass covers the stages and scenery, the objects, the badniks and the boss, and a rebuilt Sonic, all **built by scripts in Blender**, so anyone can change and rebuild them. Emerald Shore's land is **banded sandstone**: green grass tops over warm sandstone cliffs in horizontal bands, white sand, palms and a turquoise sea, a look of its own rather than Green Hill's checkerboard. The collision stays exactly the greybox's, so the art changed nothing about how the acts play. The test room stays a greybox. The demo has **all eight of Emerald Shore's acts** (decided 2026-11-01): Acts 2 to 7 were built and dressed the same way afterwards (2026-11-05).

**Stages.** An act's greybox stays in the act, hidden, as its collision (a hidden CSG shape still collides). `tools/godot/export_greybox.gd` writes it as JSON next to the act's art (`act_<n>.greybox.json`): every piece's profile and placement, the loops, the camera volumes, invisible walls, signs, gimmicks and enemies. The act's build script (`build_act_<n>.py`) dresses each piece by name with the world's kit (`shore_kit.py`, `fortress_kit.py`, using `tools/blender/stage_kit.py`) and exports `act_<n>_art.glb`, which the act shows as its `Art`. The rules that keep the art honest:

- Only the tops of greybox pieces look walkable. Each top is copied exactly; cliffs drop from its edges into the sea, under a lip of grass, and where pieces meet, their cliffs give way to each other.
- Anything on a walkable top is something to run through: flowers, grass, shells, starfish. Palms stand in the shallows at the foot of the cliffs, sea stacks and islands keep well clear, and nothing stands between a side view's camera and its path.
- Bridges, decks and piers keep the greybox's shape, on posts only where nothing walkable is below them.
- Hints are signs: the art puts a board behind each fixed `Label3D`, on a post planted in the nearest edge, or as a banner across the track. An invisible wall gets a fence.
- A piece the build script doesn't name stops the build, and a unit test fails when an act's greybox has changed since its art was built.

Act 1 is a sandstone coast: striped grass, sand, rippled wet sand on the tidal flats, a wooden pier and a high deck, palms, sea stacks, islands and a lighthouse past the goal. Act 8 is Eggman's fortress: tiled stone causeways and walls in block courses with lamps, a steel bridge on pylons with hazard stripes, the shore's sand and cliffs around the arena, a fence along its sea wall, three steel towers out at sea with lit windows and red beacons, rain and lightning. The greybox's floating labels became signs: "Wait for a wave, then ride it up!", the fork's banner, the turn arrow and "Homing attack across!". The act-name labels (the title card shows the name) and "2.5D pier" (a note for developers) are gone.

Acts 2 to 7 add to the shore's kit (`shore_kit.py`). Act 2 is a jungle: tall palms around the greybox's trunks, ferns, plank decks and rope bridges on posts, and fallen logs. Act 3 has riverbeds under its streams and waterfalls down every tier and off the plateau and the second basin into the sea, drawn by `waterfall.gdshader`. Act 4's lagoon has its own sea (`lagoon.tres`, with a thin line of foam where the sandbars break the surface), wet sand and reef floors under the water, a coral ridge, and coral heads out in the lagoon. Acts 5 and 6 are caves: rough rock walls and roofs with stalactites, glowing crystals in the walls, rocky mounds over the roofs so the caves read as hills from outside, tide pools of coral on Act 6's floors, and a dim sky of their own (`grotto_environment.tres`). Act 7 is the coast at sunset (`sunset_environment.tres`), with a low, warm sun ahead of the final straight and three of the fortress's towers dark out at sea. Rails stand on posts down to the ground or into the sea, never on ground a player can run on (`rail_supports`). The water volumes draw their own surfaces (streaked along a current), and the rails, platforms, crumbling ledges, breakable walls and bubbles build their own meshes from their settings, with materials from the art bank (`water`, `water_flowing`, `rail`, `platform_stone`, `log_bark`, `crumbling_rock`, `breakable_rock`, `bubble`).

**Looks.** The big surfaces use shaders in `engine/art/`, tuned in materials next to the art:

| Shader | For |
|---|---|
| `stripes.gdshader` | Stripes along the way the player runs: mown grass, planks, ripples in wet sand, a loop's tiles (loops now have UVs in metres) |
| `height_bands.gdshader` | Colour by height, so sandstone bands and block courses line up across every cliff |
| `toon_water.gdshader` | Light over the shallows and dark in the deep (from the depth below), foam wherever the water meets something, drifting ripples |
| `toon_sky.gdshader` | A gradient, the sun and flat-shaded clouds, with a flash for lightning |

Everything else is painted: its colour is in its vertex colours, on one shared material (`painted`, or `painted_two_sided` for leaves), so a chunk of the stage draws in a handful of calls. `engine/art/art_import.gd`, a `.glb`'s import script, swaps its materials for the library's by name (`materials/` next to it, then `content/sonic/materials/`, set by `game/art/material_library`) and gives the rest the toon look. `engine/art/storm.gd` adds rain around the camera and lightning. The sun is warm and the tonemapping linear, so the colours stay bright.

**Objects, badniks and the boss.** The engine's objects keep their placeholder shapes, and a model dresses them at start-up (`engine/art/model_skin.gd`): each part of the model is named after the node it dresses (`Head__Lamp` dresses `Head/Lamp`), so the object's scripts, animations and collision are untouched. A part with no node of its name is added, an empty hides a placeholder, and scripts that colour a part (a spring's pad, a monitor's screen, a checkpoint's lamp, the boss's shell) colour the model's. `tools/godot/export_parts.gd` writes a scene's layout for the Blender scripts. The engine finds its objects' models, and the materials for meshes it builds (waves, spike plates), in an `ArtBank` named by the project setting `game/art/art_bank` (`content/sonic/objects/art_bank.tres`); a badnik or boss names its own `skin`. The models: springs with real coils, dash panels with chevrons, item monitors with an icon for each item (the monitor shows the one for what's inside), a striped checkpoint post, the goal's chequered banner and star sign, the extra life, spike points, the freed bird, the four badniks (about 1,000 to 3,000 triangles each, from tens of thousands as placeholders) and the Egg Tidecrab with Eggman's ship (8,404 and 3,334 triangles).

**Title screen.** A live beach behind the menu: Sonic on a rock in the shallows, palms, sea stacks and the lighthouse, with the camera drifting slowly (`content/sonic/ui/title/title_backdrop.tscn`).

**Measured** (1280×720, triangles drawn in the frame, shadows not counted): Act 1's art is 118,606 triangles in 55 chunks and Act 8's 42,678. From Act 1's start, which sees the whole first straight, the frame draws about 106,000 triangles; every other spot checked in either act draws 17,000 to 80,000, within the budget of 100,000 per visible region (§8.1). Rings stop being drawn beyond 120 m, where they're a few pixels across.

Acts 2 to 7's art is 74,956, 65,780, 98,732, 66,428, 63,661 and 76,935 triangles in 30 to 48 chunks. Counted every frame along each act's autopilot run (everything drawn, at 1280×720, shadows not counted), the median frame draws 29,000 (Act 5) to 62,000 (Act 4) triangles and the busiest 77,000 to 109,000. Acts 3 to 6 stay under 100,000 all the way. Acts 2 and 7 go over in 6 to 8% of their frames, along their first straights, as Act 1's start does: in those views the art draws 54,000 to 64,000 triangles (Act 1's start: 78,000 of 105,000), well within the budget, and the rest is about 25,000 for the rings in sight (each a 384-triangle torus, drawn out to 120 m), the badniks and Sonic.

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

## 10. Menus, saves and settings (Milestone 9)

### 10.1 Flow and the world map

- **Title screen:** Enter, A or Start brings up the main menu: Play, Options, Test room and Quit. Two developer shortcuts skip the menus without a save slot: F or Y opens the test room, Shift or X Act 8's boss.
- **Play** leads to the save slots, then the **world map** (decided 2026-10-31: a menu map for now). The six worlds sit along a path, with the chosen world's eight acts listed beside it: each act's best time, most rings and red rings found (out of 5), whether it is cleared, locked or not built yet, and the boss act marked. Left and right pick a world, up and down an act, and jump plays it.
- **Unlocking:** a world's first built act is open from the start; each later act opens when the built act before it is cleared (Act 8 opened after Act 1 until Acts 2 to 7 existed). A world opens once the world before it is beaten (its last built act cleared).
- **After an act:** the results show for 6 s (a jump press after 1.5 s skips them), then the world map returns with the next act to play chosen. Leaving an act from the pause menu returns to its place on the map. With no save slot, as when a stage is run on its own, the goal leads to the stage's `next_scene` or the title screen instead.
- **Pause:** Start or Esc pauses the game: resume, restart from the last checkpoint (once one is touched), restart the act, the options, or quit to the world map (the title screen without a save slot). The game can't be paused once the goal is reached or the player has died.

### 10.2 Save slots and settings

- **Save slots** (decided 2026-10-31: 10): each is `user://saves/slot_NN.json`, holding the play time and, for every cleared act, its best time (marked if set with an assist), most rings, and the ids of every red ring found there. Clearing an act saves at once, through a temporary file so a crash can't leave half a save. A slot that can't be read, or comes from a newer version, shows as a new game. The special button (F or Y) deletes a slot, after asking.
- **Lives** aren't saved: every visit to a slot starts with 5, and a game over sends you back to the map with 5 again.
- **Settings** are kept apart from the slots, for the whole game, in `user://settings.cfg`, so they apply from the title screen on. They change in the Options menu, from the title screen or the pause menu, take effect at once, and are saved when it closes:

| Tab | Settings |
|---|---|
| Video | Fullscreen, v-sync, 3D resolution (50 to 100%, for slower graphics cards), frame rate limit |
| Audio | Master, music, sound effects and voice volume, one bus each (`default_bus_layout.tres`) |
| Camera | Camera sensitivity (25 to 200%), invert either axis, speed lines, motion blur, screen shake |
| Controls | Remap every action's keyboard or mouse binding, and the controller button (or trigger) of every button action; movement and the camera stay on the sticks and D-pad. Reset to defaults. |
| Accessibility | Game speed, the invincibility assist, HUD size (100, 125 or 150%) |

### 10.3 Accessibility (decided 2026-10-31: both assists)

- **Game speed:** 100, 90, 80 or 70%. Everything in a stage slows down, giving more time to react; menus stay at full speed.
- **Invincibility assist:** hits never hurt, and falling into a pit puts the player back on solid ground (where they stood a moment before) instead of costing a life.
- Best times set with either assist are saved marked as assisted, and the HUD tags a stage played with them.
- Along with camera sensitivity, motion blur and speed lines off, and a HUD that never relies on colour alone.

### 10.4 HUD (decided 2026-10-31: Adventure-style)

- **Top left:** a big ring count beside a ring icon (blinking red at zero, since the next hit is fatal), the time below it, and the act's red rings below that: a bright filled ring for each one found, an outline for each still to find.
- **Bottom left:** lives beside Sonic's icon, with the assists in use tagged above.
- **Top right:** the power-ups running and their seconds left. **Bottom right:** the boost gauge, ten segments that fill as it does, brighter while boosting and pulsing when full; empty segments stay as outlines.
- **Also:** the act's title card as it starts, a boss's name and hits left during its fight, the results (with a new record marked), GAME OVER, and the pause menu.
- Its size follows the HUD size setting. The icons are drawn in code until the art pass.

### 10.5 Text

All menu and HUD text goes through Godot's translation system, from `content/sonic/ui/translations/strings.csv` (English for now), so the community can add languages by adding a column.

Characters the engine's default font lacks, such as the arrows on signs, come from a bundled font, DejaVu Sans Bold (decided 2026-11-05 for the demo): it's added to the default font's fallbacks at start-up (`SymbolFont`, named by the project setting `game/ui/symbol_font`), so those characters look the same on every system instead of depending on the fonts each one has installed, where a system without such a font would show boxes. Everything else keeps the default font's look. `tests/unit/test_fonts.gd` checks that every character on a sign in a stage, and in the game's text, is in one font or the other. A sign's text faces its +Z axis, toward the players coming at it; on a 2.5D stretch it faces the side-view camera.

## 11. Audio (Milestone 10)

Decided 2026-10-31: **original music, composed in code** and changeable at any time, and **sound effects synthesised in code**, all CC BY-SA 4.0. Nothing is sampled or downloaded.

### 11.1 How it's made

- `tools/audio/` renders everything: `python tools/audio/render.py` (Python 3 with numpy and SciPy, and FFmpeg for Ogg Vorbis). Each track is written as notes in `tools/audio/music/<track>.py`, in a small text notation (`tools/audio/README.md`), and played on instruments modelled on the Genesis's FM chip (`instruments.py`): FM brass, slap bass, steel drums, clavinet, electric piano, bells and marimba, plus synth leads, a flute, pads and strings, and a synthesised drum kit with congas, shaker, timbales and timpani. The sound effects are short recipes in `sounds.py`.
- **Levels:** music is mixed to −17 LUFS with peaks under −1 dB, and an automatic EQ nudges each track toward a typical mix's tonal balance. Each sound effect has its own loudness, from −15 LUFS (the boost) to −28 (a menu tick); frequent sounds sit lower. Renders are exact, so re-rendering unchanged music leaves the files alone.
- **Loops:** the music loops from the end of its intro, seamlessly (the loop is rendered twice and the second pass kept, so echoes and reverb carry over the seam). The loop point is written into the `.ogg.import` file. A looping sound effect (the boost's rush of air) carries its loop points in its WAV.
- **Changing it** (asked for: the user may want to change the music later): edit a track's notes and re-render it; or replace its `.ogg` with a recording from any tool, setting the loop in Godot's Import dock; or point a stage, a menu or the sound bank at another file. None of these needs code.

### 11.2 The music

| Track | Plays | Feel |
|---|---|---|
| Title (`title.ogg`) | Title screen, save slots and world map, carrying on between them | Act 1's hook, relaxed: electric piano and bells over a light groove, after a brass fanfare. F major, 120 BPM. |
| Emerald Shore Act 1 (`emerald_shore_1.ogg`) | Act 1 and the test room | Tropical funk: brass on the hook, slap bass, steel drums, a clavinet on the off-beats, congas and shaker. A lyrical bridge and a slap bass and steel drum breakdown. F major, 150 BPM, a 4-bar intro and a 51 s loop. |
| Emerald Shore Act 2 (`emerald_shore_2.ogg`) | Act 2 | The tune in the jungle, with a bounce: brass and a wooden flute over a marimba, slap bass, tom-toms, congas and claves. A bridge that climbs on the flute, and a tom-tom breakdown with a marimba solo. B-flat major, 138 BPM. |
| Emerald Shore Act 3 (`emerald_shore_3.ogg`) | Act 3 | At a sprint: brass over arpeggios tumbling like the falls, bells for the spray, a driving octave bass and four-on-the-floor drums. A bridge over rising arpeggios for the tiers, and a cascade of bells. D major, 162 BPM. |
| Emerald Shore Act 4 (`emerald_shore_4.ogg`) | Act 4 | A calypso to fight to: steel drums on the tune, punching brass, cowbell and timbales. A glassy bridge as if under water, and a brass riff in A minor for the badnik packs. C major, 146 BPM. |
| Emerald Shore Act 5 (`emerald_shore_5.ogg`) | Act 5 | The tune in the dark: a cave flute over a marimba, bells dripping through a long echo and light hand drums, in a big, ringing room. A warm bridge in C major for the hidden rooms. A minor, 120 BPM. |
| Emerald Shore Act 6 (`emerald_shore_6.ogg`) | Act 6 | A race against the tide: a new tune grown from the hook's opening on a synth lead, a pulsing bass and percussion ticking like a clock, strings climbing over timpani, and a ticking marimba riff. E minor, 148 BPM. |
| Emerald Shore Act 7 (`emerald_shore_7.ogg`) | Act 7 | Full tilt into the evening: brass, strings and a galloping beat, a wistful bridge on a synth lead, then Act 8's stormy hook in C minor, with thunder, as the fortress comes into view. E-flat major, 164 BPM. |
| Emerald Shore Act 8 (`emerald_shore_8.ogg`) | Act 8, until the boss | The same tune stormy: D minor, a driving synth bass, strings, timpani and thunder, and a pounding steel drum riff. 156 BPM. |
| Boss (`boss.ogg`) | Boss fights, from the boss's entrance | A churning bass ostinato, brass and racing arpeggios, then strings over 3-3-2 brass stabs. C minor, 168 BPM. |
| Invincibility (`invincible.ogg`) | Instead of the music while invincible | Heroic brass and a four-on-the-floor beat. A major, 168 BPM. |
| Extra life (`extra_life.ogg`) | A jingle; the music stops for it and carries on afterwards | About 4 s. B-flat major. |
| Act clear (`act_clear.ogg`) | A jingle at the goal or when a boss is beaten, over the results | A 5 s fanfare, then its last chord rings out. F major. |
| Game over (`game_over.ogg`) | A jingle when the last life is lost | A slow falling phrase of 5 s, ringing out. D minor. |
| Drowning (`drowning.ogg`) | Instead of the music for the last 12 s of air under water (§5.9) | Alarm bells rising a semitone every bar over a pulsing bass, then one frantic bar that repeats. D minor, 180 BPM. |

**Speed shoes** switch a stage's music to its `_fast` version (rendered 25% faster at the same pitch) from the same point in the tune, and back when they run out. Music without a fast version plays 20% faster and higher instead. Every act's track has a fast version.

### 11.3 In the game

- **Engine:** two autoloads in `engine/audio/`. `Sfx` plays sound effects by name (`Sfx.play(&"jump")`); `Music` plays the music. Both take their sounds from a `SoundBank` resource, named by the project setting `game/audio/sound_bank` (`content/sonic/audio/sound_bank.tres`), which maps each of the engine's sound names and music cues to a file. A name the bank doesn't have stays silent, so the engine runs without content.
- **Music:** a stage plays its `music` as it loads, carrying on if it's already playing (restarting from the pause menu); after a death it starts from the top, since dying fades it out. A menu's music carries on from one menu to the next. Invincibility's music replaces the track while it lasts, and the track picks up where it stopped; so does the drowning countdown's, until the player breathes or drowns. A jingle cuts in: the extra life's hands back, the act clear's and game over's don't. A boss arena starts its `music` as the fight begins and fades it when the boss is beaten. Dying fades the music over a second. The music pauses with the game.
- **Sounds:** the player's own sounds are heard the same everywhere. Things in the world (a badnik popping, a shot, a fish's splash, a tidal wave washing up the beach, a wall breaking, a ledge crumbling, the boss) are heard from where they are, fading out by 80 m. Rings alternate between the speakers. Up to four plays of one sound overlap. Menus get their sounds without any code of their own: a tick when the focus moves, a blip when a button is pressed, another on back.
- **Buses:** music on Music, sound effects on SFX, each with its slider (§10.2). Sound effects pause with the game, except the menus'.

---

## 12. Open decisions

Each one is grouped by the milestone where it starts to block work.

| Needed by | Decision |
|---|---|
| **Each world, as it's built** | Its badnik roster and boss concept. Emerald Shore's are decided (§9). |
| **Later** | Special stages and Chaos Emeralds; ranking; time attack and ghosts; local and online multiplayer; 2D art tool; community channel; itch.io and GameJolt pages |

## 13. Roadmap

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
| 9 | Menus, save system, settings, accessibility | **Done** |
| 10 | Art and audio pass, then a public demo release | **Done** (2026-11-05): audio (2026-10-31, §11), the art pass (2026-11-01, §8.3), Acts 2 to 7 with their art and music (2026-11-05, §7.2), bringing water, grind rails, moving and crumbling platforms, breakable walls, and swimming and drowning (§5.7, §5.9), and the first public demo, **v0.1.0**, on GitHub Releases |
| 11 | The rest of the moves: stomp, drop dash, Super Peel Out, drift, light speed dash, wall-jumps and wall-running (§5.10) | **Done** (2026-11-06): decided 2026-11-05, with a moves area in the test room and spots in Acts 2, 5 and 7 |

**Releases** (decided 2026-11-05): pushing a `v*` tag publishes a GitHub pre-release (while the game is in 0.x) with Windows, Linux and macOS builds, each carrying the licenses, the credits and the bundled font's license, and with the notes in `docs/releases/<tag>.md`. The demo is on GitHub Releases only; itch.io can follow later. Each release is first checked from a test build (Actions → CI → Run workflow), launched on Windows.

**Scope plan:** 48 acts is a lot of content. Finish World 1 as a complete vertical slice (all its gimmicks, enemies and the boss) before greyboxing other worlds. Problems found in World 1 are much cheaper to fix than problems spread across six worlds.
