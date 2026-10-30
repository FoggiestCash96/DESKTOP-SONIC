# engine/

A reusable, franchise-free 3D platformer engine: player physics, camera, gimmicks, enemy base classes, game systems and developer tools.

## Rules for this folder

- **No franchise characters, names, logos or trademarks**, including in file names and comments. Game-specific material lives in `content/`. `tests/unit/test_engine_ip_split.gd` fails the build if any slip in.
- Gameplay numbers live in `.tres` resources in SI units (m, m/s, m/s², seconds).
- Nothing in here may depend on `content/`. Content depends on the engine, never the other way round.

## Layout

| Folder | Contents | Milestone |
|---|---|---|
| `player/` | Player controller, movement math and tuning resource | 2 |
| `player/states/` | One script per movement state, once there are more than ground and air (roll, spin dash, grind...) | 3 |
| `camera/` | Basic follow camera now; the full camera and camera volumes later | 2, 4 |
| `gimmicks/` | Springs, dash panels, rails and other reusable stage objects | 5 |
| `enemies/base/` | Enemy base classes and state machines | 8 |
| `systems/` | Save, settings, audio, scene loading, replays | 9 |
| `debug/` | Developer overlay (F3) and fly camera | 1 |
| `greybox/` | Grid shader, materials and environment for blockout scenes | 1 |
