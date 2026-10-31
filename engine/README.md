# engine/

A reusable, franchise-free 3D platformer engine: player physics, camera, gimmicks, enemy base classes, game systems and developer tools.

## Rules for this folder

- **No franchise characters, names, logos or trademarks**, including in file names and comments. Game-specific material lives in `content/`. `tests/unit/test_engine_ip_split.gd` fails the build if any slip in.
- Gameplay numbers live in `.tres` resources in SI units (m, m/s, m/s², seconds).
- Nothing in here may depend on `content/`. Content depends on the engine, never the other way round.

## Layout

| Folder | Contents | Milestone |
|---|---|---|
| `player/` | Player controller, movement math and tuning resource; character definitions, the model driver and the character import script | 2, 7 |
| `player/states/` | One script per movement state: ground, roll, spin dash, air, homing attack, hurt, death (grind and more later) | 3, 5, 8 |
| `camera/` | Player camera, camera volumes, camera tuning, and the speed lines and motion blur | 4, 7 |
| `gimmicks/` | Reusable stage objects: loop track, springs, dash panels, spikes, checkpoints, tidal and rolling waves, goal; rails and more later | 3, 5, 6, 8 |
| `collectibles/` | Rings, ring rows, scattered rings, item monitors, hidden collectibles, extra lives | 5 |
| `enemies/` | Enemy behaviours: walker, flyer, turret, leaper | 8 |
| `enemies/base/` | The enemy state machine, the boss base and boss arena, homing targets, shots, explosions and freed animals | 8 |
| `systems/` | Stage root script; GameState (lives, checkpoints, stage clock), SaveGame (save slots) and GameSettings (settings, assists) autoloads; remappable controls; world map data. Audio, scene loading and replays later | 5, 9 |
| `debug/` | Developer overlay (F3) and fly camera | 1 |
| `greybox/` | Grid shader, materials and environment for blockout scenes | 1 |
