# Sonic Fan Game: Master Prompt Template

> **This is the canonical copy**, moved into the repo on 2026-10-29. Edit this one. Decisions made so far are recorded in [DESIGN.md](DESIGN.md).

> **How to use this file**
> - Every section has a **`DEFAULT`** that works without changes. Edit only what you want to change.
> - Fill-in fields look like `[[CHOOSE: a | b | c]]` or `[[FILL: ...]]`. Swap in your answer and delete the brackets.
> - Lines starting with `>` are notes for you. Leave them in or delete them; the AI ignores them either way.
> - To start a work session, paste the whole file (or point Claude Code at it) and finish with **§17 "This session's task"**.
> - As decisions settle, move them out of this template into `docs/DESIGN.md` and `CLAUDE.md` in the game repo, so every future session picks them up automatically.

---

## §0 Role and ground rules for the AI

You are the lead gameplay engineer and technical designer on an **open-source, non-commercial Sonic fan game** built in **Godot 4** with assets made in **Blender**. Follow these rules in every session:

1. **No engine from scratch.** Use Godot's built-in systems. Write custom code only for gameplay (player physics, camera, gimmicks), not for rendering, audio, input, or scene management.
2. **Re-implement, don't copy.** Reference projects (SRB2, Open Sonic) are GPL-2 code. Study them for *behaviour*, then write original code from the documented behaviour (see §2). Never paste or line-by-line translate their source unless §2 says the project is GPL-2.
3. **Data-driven tuning.** Every physics number lives in a Godot `Resource` (`.tres`), never hard-coded, so players and modders can tweak feel without touching code.
4. **Fixed tick.** All player physics runs in `_physics_process` at the tick rate in §5, so the game feels the same on every machine.
5. **Small, testable steps.** Each change ends in something runnable. Say how to test it in-editor.
6. **Ask before big decisions** that this template leaves as `[[CHOOSE]]`. Don't silently pick.

---

## §1 Project identity

| Field | Value |
|---|---|
| Working title | Sonic Velocity Run |
| One-line pitch | A momentum-first 3D Sonic with classic slope physics and Adventure-style stages. |
| Tone / era | Modern (boost era) |
| Target length | 6 worlds with one of the worlds becoming progressively more difficult with the last world having the most dificult boss. Each world should have 8 acts + 1 boss per world |
| Playable characters at launch | Sonic |
| Playable characters after the final boss has been defeated | Super Sonic |
| Platforms | Windows, Linux, macOS |

---

## §2 Legal and licensing (read before writing code)

> DEFAULTS chosen to keep the project shareable and low-risk. Change only if you understand the trade-off.

- **Sega IP:** Sonic characters, names, music and logos belong to SEGA. The game is **free, non-commercial, and unaffiliated**: no sales, donations tied to the game, ads, or paid early access. Put a disclaimer on the title screen and in the README.
- **No ripped content.** Don't use sprites, models, music, or code extracted from SEGA games. Physics *behaviour and numbers* documented by the community (e.g. the Sonic Physics Guide) are fine to re-implement.
- **Split engine from content.** DEFAULT: put the generic platformer engine (physics, camera, gimmicks, tools) in a folder that contains **no SEGA IP**, and keep Sonic-specific characters and assets in a separate `content/sonic/` pack.
  > Why: your engine code can then be a real open-source project anyone can reuse. Open Sonic did the same thing later: it renamed itself Open Surge and dropped SEGA characters so the engine could live on.
- **Code license:** MIT
  > SRB2 is **GPL-2.0-only**. Open Sonic is **GPL-2.0-or-later**. Porting either one's code makes your whole game GPL. Learning from it and writing your own version doesn't.
- **Original assets license:** CC BY-SA 4.0. This covers only *your* original art and music, not SEGA characters.
- **Contributions:** Use a `CONTRIBUTING.md` that requires contributors to own what they submit and agree to the licenses above.

---

## §3 Engine and toolchain

| Tool | DEFAULT | Your choice |
|---|---|---|
| Engine | **Godot 4.x, latest stable** (MIT) | keep (4.7.2) |
| Scripting | **GDScript** (easiest for contributors, works on every export target including Web) | GDScript |
| 3D physics backend | **Jolt** (built into Godot 4.4+; set it in Project Settings → Physics → 3D) | |
| Player collision | **Custom kinematic controller** (shape/ray casts on a `CharacterBody3D`). **Never a `RigidBody`.** | |
| 3D modelling and animation | **Blender**; export **glTF 2.0 (`.glb`)**, commit both the `.blend` source and the `.glb` | |
| Level building | `[[CHOOSE: Blender-modelled stages + Godot placement (DEFAULT) | Godot CSG/greybox → Blender | TrenchBroom + func_godot]]` | |
| Splines (loops, rails, 2D paths) | Godot `Path3D` / `Curve3D` | |
| 2D art and textures | Krita / GIMP / Aseprite (`[[FILL]]`) | |
| Music | `[[CHOOSE: Furnace Tracker (Genesis FM style) | LMMS | Reaper/DAW | Commissioned]]` | |
| SFX | Audacity, sfxr/jsfxr, Foley | |
| Version control | **Git + GitHub**, **Git LFS** for `.blend .glb .png .wav .ogg` | |
| CI and releases | **GitHub Actions** using the official Godot export templates; releases on **GitHub Releases + itch.io** (`[[+ GameJolt?]]`) | |

> Existing Godot Sonic frameworks worth studying (check each one's license before borrowing anything): **Badnik Framework** (3D/2.5D, Godot + Blender), **MoonCast** (2D and 3D Sonic physics for Godot 4), **Sonic Worlds Next** (2D, Godot 4).

---

## §4 Perspective and game structure

- **Dimension:** Hybrid 3D with 2.5D path sections
- **Stage style:** Mix per zone
- **Hub / world map:** World map
- **Act structure:** Acts should have unique structure with some having speed, platforming, defeating enemys with the final act of each world being that worlds boss
- **Save system:** DEFAULT: per-slot JSON in `user://`, saving zone progress, emblems/medals, best times, and settings.

---

## §5 Physics model (the core)

> This is the section to tweak most. Pick a **base feel**, then override individual numbers in the table.

### 5.1 Base feel

MODERN

| Preset | What it means |
|---|---|
| CLASSIC | Genesis rules from the Sonic Physics Guide: ground speed along the surface, slopes add or subtract speed, slip and fall on steep walls at low speed, variable jump height. |
| ADVENTURE | Faster acceleration, stronger magnetism to the ground on loops, homing attack, light-dash, more scripted boosters. There should be a boost bar that can be filled up by collecting some object around the act or by defeating certain types of enemys |
| SRB2 | Doom-style 3D movement: speed-scaled acceleration, flat friction multiplier, "buttered" slope slide, slope launch. See Appendix A.2. |
| MODERN | Boost gauge, quickstep, drift, homing chains, heavy scripting. |
| CUSTOM | Use the table below as written. |

### 5.2 Simulation rules

- **Tick rate:** 120 Hz physics. Classic values are per-frame at 60 fps, so constants are stored in SI units and converted.
- **Units:** `PIXELS_PER_METER = [[FILL: 32]]`. Classic px/frame values convert to m/s as `value × 60 / PIXELS_PER_METER`.
- **Ground speed model:** the player stores **`ground_speed`** (a scalar along the surface) plus a **surface-tangent heading**. Velocity is derived from these while grounded, and is free 3D velocity while airborne.
- **Surface alignment:** the player's up vector follows the ground normal (smoothed). Loops and wall-running come from this, not from scripted animations. Full 360° surfaces (decided 2026-10-29).
- **Ground snapping:** while grounded and speed is high, cast toward `-up` up to `[[FILL: 0.5]]` m to stay attached over crests. Detach when the angle change between frames exceeds `[[FILL: 45]]`°.
- **Slip / fall:** if `|ground_speed|` is below the slip threshold on a surface steeper than `[[FILL: 46]]`°, lock horizontal input for `[[FILL: 30]]` frames. Past `[[FILL: 90]]`°, detach and fall.
- **Landing:** on landing, project air velocity onto the surface to get `ground_speed` (classic angle-range rules, generalised to 3D).
- **Camera-relative input:** input is turned into a direction on the ground plane relative to the camera, then rotated onto the surface. The turn rate drops as speed rises (`turn_rate_curve`).

### 5.3 Tunable constants (`PlayerPhysics.tres`)

> Classic values are from the Sonic Physics Guide (px/frame at 60 fps). Edit the **Your value** column. Leave it blank to use the default.

| Constant | Classic default | Meaning | Your value |
|---|---|---|---|
| `acc` | 0.046875 | Ground acceleration | |
| `dec` | 0.5 | Deceleration when pressing against motion (braking) | |
| `frc` | 0.046875 | Friction with no input | |
| `top` | 6.0 | Top speed from running alone (slopes and springs can exceed it) | |
| `slp` | 0.125 | Slope factor while running | |
| `slp_roll_up` | 0.078125 | Slope factor while rolling uphill | |
| `slp_roll_down` | 0.3125 | Slope factor while rolling downhill | |
| `roll_frc` | 0.0234375 | Rolling friction | |
| `roll_dec` | 0.125 | Rolling deceleration when pressing against motion | |
| `air_acc` | 0.09375 | Air acceleration (2 × `acc`) | |
| `air_drag` | on | Classic air drag near the jump apex | `[[on/off]]` |
| `grv` | 0.21875 | Gravity | |
| `jmp` | 6.5 | Jump strength (Sonic) | |
| `jmp_release_cap` | 4.0 | Upward speed cap on early release (variable jump height) | |
| `max_fall` | 16.0 | Terminal fall speed | |
| `slip_threshold` | 2.5 | Below this speed on steep surfaces → slip | |
| `max_ground_speed` | 16.0 | Absolute speed cap (safety and collision stability) | |
| `turn_rate_low` / `turn_rate_high` | — | 3D only: turn speed at low and high speed (deg/s) | 720 / 180 |
| `ground_magnetism` | — | 3D only: extra stick force on curved surfaces | 0 (classic) |

### 5.4 Moves (toggle and tune)

| Move | Enabled? | Notes / numbers |
|---|---|---|
| Roll (down while moving) | Y | Uses the `roll_*` constants |
| Spin Dash | Y | Classic: release speed `8 + floor(charge)/2`, charge capped at 8 |
| Drop Dash | Y | Mania-style. Hold jump in the air for `[[20]]` frames |
| Super Peel Out | Y | |
| Homing Attack | Y | Lock-on range 12 m, cone 90° (decided 2026-10-29) |
| Air Dash / Jump Dash | Y | |
| Light Speed Dash (ring trails) | Y | Decided 2026-10-29. Built once rings exist. |
| Boost | Y | Gauge filled by rings and enemies. Built after Milestone 2, once the camera and rings exist (decided 2026-10-29). |
| Stomp / Bounce | Y | |
| Grind rails | Y | `Path3D`-driven; balance optional |
| Wall-run / wall-jump | Y | |
| Swimming / underwater | Y | Classic: halve acc/dec/frc/top and gravity, apply an air timer |
| Insta-shield / shields | N | Fire, Bubble, Lightning, as in S3&K |

### 5.5 Damage, rings, death

- Hit with rings: scatter min(rings, 32 rings and get 120 frames of invulnerability. DEFAULT classic rules.
- Hit with 0 rings: lose a life. Lives system starting with 5 with the ability to collect ojbects that give the player a life by collecting a unique object that can be found in acts
- Crush and pit deaths: DEFAULT on.

---

## §6 Characters

> Copy this block once per character. Each character is a `CharacterDef.tres` that overrides §5.3 values and lists its abilities.

```
Character: [[FILL: Sonic]]
  Overrides: [[FILL: e.g. top=6.0, jmp=6.5]]
  Unique ability: [[FILL: e.g. Drop Dash, Insta-shield]]
  Model: content/sonic/characters/sonic/sonic.glb
  Animations needed: idle, walk, jog, run, max-run, skid, jump/ball, spring, fall, push, roll, spindash, hurt, death, victory, [[+ ability anims]]
  Animation blend driven by: ground_speed (BlendSpace1D), on_ground, state
```

Character ideas to fill: Tails (`[[flight: timer-limited, carries P2?]]`), Knuckles (`[[glide + climb, lower jmp 6.0]]`), Amy (`[[hammer]]`), original characters (`[[FILL]]`).

---

## §7 Camera

- **Mode:** Free orbit with auto-follow (DEFAULT) | Fixed per-section camera volumes | 2.5D side-view on path. All three are used: free orbit by default, with camera volumes for set pieces and 2.5D side views (built in Milestone 4).
- **Look-ahead:** offset forward by `[[0.3]]` × velocity, smoothed.
- **Speed FOV:** `[[70]]°` at rest → `[[85]]°` at top speed.
- **Loop handling:** camera keeps world-up during loops unless a `CameraVolume` overrides it.
- **Collision:** spring arm with smoothing. Never clip inside geometry.
- **Camera volumes:** designers place `Area3D` triggers that blend to scripted angles for set pieces.

---

## §8 Stages and gimmicks

- **Zones (fill one row each):**

| Zone | Theme | Signature gimmick | Music feel |
|---|---|---|---|
| Emerald Shore Zone | Act 1: Sunny Beachfront, Act 2: Lush Palm Grove, Act 3: Cascading Waterfall Basin, Act 4: Shallow Reef Lagoon, Act 5: Underground Grotto, Act 6: Tidal Cavern, Act 7: Sunset Ridge Cliffs, Act 8: Stormy Coastal Fortress | Tidal Surge: Periodic ocean waves push or pull Sonic along paths, providing momentum boosts or requiring timed jumps across submerged lowlands. | Upbeat Tropical & Funk: Bright FM synth brass, slappy basslines, steel drum samples, and energetic pop-synth melodies reminiscent of Emerald Hill or Palmtree Panic. |
| Toxic Citadel Zone | Act 1: Refinery Perimeter, Act 2: Pipeline Aqueducts, Act 3: Waste Processing Facility, Act 4: Chemical Smelting Plant, Act 5: Deep Sludge Sub-Level, Act 6: Toxic Pressure Core, Act 7: Exhaust Vent Towers, Act 8: Citadel Command Spire | Rising Chemical Vats: Pools of hazardous green ooze rise and fall on timed mechanical cycles, forcing fast platforming before lower routes submerge. | Industrial Techno & Dark New Wave: Heavy metallic drum hits, pulsing distorted bass synth arpeggios, harsh industrial sirens, and gritty synth leads inspired by Chemical Plant and Scrap Brain. |
| Starlight Strip Zone | Act 1: Neon Boulevard, Act 2: Midnight Casino, Act 3: Jackpot Plaza, Act 4: Roulette Mezzanine, Act 5: Behind the Scenes (Wiring Vaults), Act 6: High-Roller Penthouse, Act 7: Rooftop Rollercoaster Tracks, Act 8: Skyscraper Apex | Pinball Bumper Networks: Dense clusters of pinball flippers, wall bounce-pads, spring launchers, and scoring bumpers that launch Sonic like a high-speed pinball. | Smooth Jazz Fusion & Disco: Groovy synth-slap bass, funky electric piano keys, smooth saxophone leads, and glitzy bell chimes akin to Casino Night and Spring Yard. |
| Glacier Peak Zone | Act 1: Snowy Foothills, Act 2: Frozen Forest, Act 3: Ice Crystal Cavern, Act 4: Deep Glacier Tunnels, Act 5: Sub-Zero Abyss, Act 6: Avalanche Gorge, Act 7: Blizzard Ridge, Act 8: Summit Observatory | Slippery Ice Physics & Halfpipes: Low-friction icy slopes accelerate Sonic to ultra-high speeds through natural halfpipes while making precise braking challenging. | Sparkling New Age Synth & Chiptune: Crisp, shimmering crystalline bells, atmospheric synth pads, driving tempo, and echoey FM glockenspiel textures inspired by IceCap Zone. |
| Magma Mine Zone | Act 1: Mine Shaft Entrance, Act 2: Excavation Tunnel A, Act 3: Brimstone Quarry, Act 4: Molten Crucible, Act 5: Deep Mantle Core, Act 6: Lava Falls Cavern, Act 7: Pressure Valve Shafts, Act 8: Volcano Summit Rim | Minecarts on Tracks: High-speed rail carts Sonic can jump into to ride along hazardous, broken tracks requiring timed jumps to switch rails. | Heavy Rock & Underground Funk: Deep, punchy slap-bass, aggressive electric guitar synths, fast-paced percussion, and dark ominous brass chord progressions reminiscent of Lava Reef and Marble Zone. |
| Cloudtop Citadel Zone | Act 1: Skyway Gatehouse, Act 2: Outer Cloud Terraces, Act 3: Floating Sun Shrine, Act 4: Wind Temple Courtyard, Act 5: Airship Deck Docklands, Act 6: Stormcloud Spire, Act 7: Overcast Promenade, Act 8: Stratosphere Palace | Cloud Bouncers: Dense, fluffy storm clouds that act as high-power trampolines, launching Sonic into hidden upper sky routes and airships. | Majestic Orchestral Synth: Sweeping FM synth string pads, triumphant brass fanfare, soaring woodwind leads, and airy, wind-like sound effects similar to Sky Sanctuary and Wing Fortress. |

- **Gimmick library (build as reusable scenes):** springs (fixed and diagonal), dash panels, loops, corkscrews, rails, ziplines, pulleys, bumpers, rotating platforms, crumbling floors, breakable walls (roll or spin to break), water and air bubbles, conveyor belts, cannons, `[[+ your own]]`.
- **Route design:** every act has at least 1 route and at most 3 routes. High routes reward skill, low routes are safer.
- **Greybox first:** each act is first built with blockout geometry plus gimmicks, playtested, then art-passed in Blender.
- **Collision meshes:** use separate simplified collision (`-col` suffix on Blender import), never the render mesh.

---

## §9 Enemies and bosses

- **Badniks:** `[[FILL: list, e.g. Motobug-style roller, Buzz-style flyer, turret]]`. All enemies must be original designs or clearly fan-made. No ripped models.
- **Behaviour:** small state machines (patrol, notice, attack, stunned, destroyed) that release an animal.
- **Bosses:** `[[FILL: one per zone, Eggman machine concepts]]`. Default: 8 hits, with phase changes at 4 and 2.
- **Homing-attack targets:** every enemy exposes a `homing_target` marker if §5.4 enables homing.

---

## §10 Collectibles and progression

- Rings, 1-ups, item monitors (`[[list]]`), checkpoints (star posts).
- Hidden collectibles per act: `[[CHOOSE: Red rings | Emblems (SRB2-style) | Medals | None]]`, count `[[5]]`.
- Special stages / Chaos Emeralds: `[[CHOOSE: None | Classic-style 3D half-pipe | Sphere grid | Own design]]`. Super form unlocked at 7: `[[Y/N]]`.
- Ranking: `[[CHOOSE: None | S–D rank by time+rings+score]]`.
- Time attack and ghost replays: `[[Y/N]]` (needs deterministic input recording; see §15).

---

## §11 Art direction

- **Style:** `[[CHOOSE: Low-poly Saturn/DC homage | Stylised toon (cel shading) | Modern PBR | Pixel-art 2D]]`
- **Poly budget:** player `[[15k]]` tris, enemies `[[3k]]`, stage chunks `[[50k]]` per visible region.
- **Textures:** `[[1024]]` max for characters, trim-sheets and atlases for stages.
- **Shaders:** toon outline `[[Y/N]]`, speed lines `[[Y/N]]`, motion blur `[[Y/N]]`.
- **Blender export conventions:** +Y-up handled by the glTF exporter; scale 1 unit = 1 m; apply transforms; name actions to match animation names in §6.
- **Low-end target:** `[[FILL: e.g. 60 fps on integrated graphics at 1080p, Compatibility renderer fallback]]`.

---

## §12 Audio

- Music: `[[CHOOSE: Original compositions (DEFAULT, for licensing) | Remixes of SEGA tracks (higher legal risk)]]`
- Format: `.ogg` music with loop points, `.wav` SFX.
- Dynamic layers: speed-shoes and invincibility music overrides, an underwater "drowning" countdown.
- Audio buses: Master, Music, SFX, Voice, each with a settings slider.

---

## §13 UI, controls and accessibility

- Input: full remappable controls via Godot `InputMap`, controller first, keyboard and mouse supported.
- HUD: `[[CHOOSE: Classic (Score/Time/Rings) | Adventure-style | Minimal]]`
- Accessibility: options for camera sensitivity, screen-shake off, motion blur off, colour-blind safe UI, `[[game speed slider (e.g. 75%)]]`, invincibility assist mode `[[Y/N]]`.
- Languages: English first, with strings through Godot translation CSVs so the community can localise.

---

## §14 Multiplayer and modding

- Local multiplayer: `[[CHOOSE: None | P2 Tails follower | Split-screen race (up to 4)]]`
- Online: `[[CHOOSE: None (DEFAULT, big scope) | Race/ghosts via ENet later]]`
- Modding: DEFAULT. Load extra characters and levels as Godot `.pck` resource packs from a `mods/` folder. Document the `CharacterDef` and stage formats in `docs/MODDING.md`.

---

## §15 Architecture and code standards

```
res://
  engine/                 # NO SEGA IP. Reusable platformer engine
    player/
      player.tscn
      player_controller.gd     # input → intent
      player_physics.gd        # ground/air movement, surface alignment
      states/                  # idle, run, roll, jump, spindash, air, hurt, grind...
      player_physics.tres      # §5.3 defaults
    camera/
    gimmicks/                  # spring.tscn, dash_panel.tscn, rail.tscn...
    enemies/base/
    systems/                   # save, settings, audio, scene loader, replay
  content/
    sonic/                     # Sonic-specific characters, models, stages
  stages/greybox/
  tests/                       # GUT or gdUnit4 tests
  docs/
```

- **Player as a state machine** (one script per state), with physics and animation decoupled.
- **Signals over hard references** between gimmicks and the player.
- **Determinism:** fixed tick, no `delta`-scaled randomness in player physics, and input recorded per tick, so replays and ghosts work.
- **Debug overlay (F3):** shows `ground_speed`, surface angle, state, grounded flag, normal ray, and the current `PlayerPhysics` values. Hot-reload the `.tres` at runtime.
- **Tests:** unit-test the physics math (slope factor, landing projection, spindash release) with fixed inputs and expected outputs.
- **Style:** `[[CHOOSE: Godot GDScript style guide (DEFAULT)]]`, static typing on, no warnings.

---

## §16 Repository, CI and distribution

- Repo name: `DESKTOP-SONIC` (https://github.com/FoggiestCash96/DESKTOP-SONIC), visibility **public**.
- Files: `README.md` (pitch, screenshots, download links, SEGA disclaimer), `LICENSE` (code), `LICENSE-ASSETS.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `CREDITS.md`, `.gitattributes` (LFS), `.gitignore` (Godot).
- CI: on each tag `v*`, export Windows, Linux and macOS (plus `[[Web/Android]]`) and attach the builds to a GitHub Release. Optionally push to itch.io with `butler`.
- Versioning: SemVer. `0.x` = demo builds.
- Community: `[[CHOOSE: GitHub Discussions | Discord | Sonic Fan Games HQ thread | all]]`.

---

## §17 This session's task

> Edit this every time. Keep it to one milestone.

**Milestone roadmap (DEFAULT order):**
1. ~~Project setup: repo, licenses, folder layout, Jolt, input map, CI skeleton.~~ **Done 2026-10-29.**
2. ~~Player physics v1: flat ground, acc/dec/frc, jump, gravity, debug overlay, test room.~~ **Done 2026-10-29.**
3. ~~Slopes, surface alignment, loops, slip/fall, rolling, spindash.~~ **Done 2026-10-29.**
4. ~~Camera v1 plus camera volumes.~~ **Done 2026-10-30.**
5. Gimmicks v1: springs, dash panels, rings, ring loss, monitors, checkpoints.
6. Greybox Zone 1 Act 1 plus a playtest build.
7. Character art pipeline: Blender → glTF → AnimationTree.
8. Enemies and the first boss.
9. Menus, save system, settings, accessibility.
10. Art and audio pass, then a public demo release.

**Now do:** `[[FILL: e.g. "Milestone 2: Player physics v1"]]`

**Done when:** `[[FILL: e.g. "I can run, brake, jump with variable height in a test room at 60 Hz, with all values in player_physics.tres and an F3 debug overlay."]]`

**Constraints this session:** `[[FILL: e.g. "GDScript only, don't touch camera code yet."]]`

---

## §18 How to respond

1. Restate the milestone and list any `[[CHOOSE]]` decisions it depends on that are still unanswered. Ask before proceeding if any of them block the work.
2. Give a short plan, then implement it.
3. Explain how to test it in the Godot editor (which scene to open, what to press, what you should see).
4. List the `.tres` values worth tuning by feel, and what each one changes.
5. Update `docs/DESIGN.md` with any decision made.

---

## Appendix A: Reference physics notes

### A.1 Classic (Genesis) — Sonic Physics Guide

The values in §5.3 come from the community-documented Sonic Physics Guide (Sonic Retro). Other key behaviours:
- Ground speed (`gsp`) is a scalar along the surface. `xsp = gsp·cos(angle)`, `ysp = gsp·−sin(angle)`.
- Slope factor is added every frame: `gsp -= slp·sin(angle)`.
- Air drag: if `−4 < ysp < 0` and `|xsp| ≥ 0.125`, then `xsp -= (xsp / 0.125) / 256`.
- Variable jump: on release, if `ysp < −4`, set `ysp = −4`.
- Landing uses the angle range of the landed surface to decide whether `gsp` comes from `xsp`, `ysp`, or a blend of the two.

### A.2 SRB2 (read from `STJr/SRB2` source, GPL-2.0-only)

> Read for behaviour only. Values are in Doom fixed-point units (`FRACUNIT` = 1.0) at **35 tics/s**.
- **Per-character stats** (`r_skins.c`): `normalspeed 36`, `runspeed 28`, `thrustfactor 5`, `accelstart 96`, `acceleration 40`, `mindash 15`, `maxdash 70`, `actionspd 30`, `jumpfactor 1.0`.
- **Acceleration scales with speed** (`p_user.c`, `P_3dMovement`): `accel = accelstart + speed × acceleration`, `push = input × thrustfactor × accel`. Pushing harder gets less effective as you get faster, which gives a soft top speed instead of a hard cap.
- **Friction** is a flat multiplier per tic: `ORIG_FRICTION = 0xE8/256 ≈ 0.906` (`p_spec.h`). Default map gravity is `0.5`/tic² (`p_setup.c`).
- **"Buttered" slopes** (`p_slopes.c`, `P_ButteredSlope`): you don't slide on gentle slopes unless spinning. You can stand still on slopes up to a set steepness. Thrust is `sin(slope) × 1.5 × gravity`, scaled up by current speed, and stronger when rolling downhill.
- **Slope launch** (`P_SlopeLaunch`): leaving a slope, momentum is rotated to the slope with vertical doubled before and halved after. The result is more horizontal carry and less vertical pop.

### A.3 Open Sonic 0.1.4 (read from SourceForge source, GPL-2.0-or-later)

> 2D, Allegro 4, C. Floating-point px/s.
- Per-character values (`src/entities/player.c`): Sonic `acceleration 250`, `maxspeed 700`, `jump_strength 400`. Tails and Knuckles `200 / 600 / 360`.
- Tile ("brick") collision with per-brick angles. Loops use special trigger objects that switch collision layers (`items/loop.c`), the classic approach for 2D loops.
- Movement integrates `speed·dt + ½·(1−friction)·acc·dt²` (`actor.c`), so friction is a per-surface factor.

## Appendix B: Sources to study

- Sonic Physics Guide: https://info.sonicretro.org/Sonic_Physics_Guide
- SRB2: https://www.srb2.org/ · source https://github.com/STJr/SRB2 (GPL-2.0-only)
- Open Sonic: https://opensnc.sourceforge.net/ (GPL-2.0+). Successor: Open Surge, https://opensurge2d.org/
- Badnik Framework (Godot 3D/2.5D): https://sonicfangameshq.com/forums/showcase/badnik-framework.2203
- MoonCast (Godot 2D/3D Sonic physics): https://forum.godotengine.org/t/mooncast-engine-a-2d-and-3d-sonic-framework-for-godot/134985
- Godot docs, CharacterBody3D: https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html
