# content/sonic/

Everything specific to Sonic the Hedgehog: characters, stages, UI and audio.

Sonic and all related characters and trademarks belong to SEGA. Our original files in this folder are licensed under CC BY-SA 4.0 (see [LICENSE-ASSETS.md](../../LICENSE-ASSETS.md)), but that license grants no rights to SEGA's characters.

| Folder | Contents |
|---|---|
| `characters/sonic/` | Sonic's character definition (`sonic.tres`), his character scene with its AnimationTree (`sonic.tscn`), and the stand-in model (`sonic.glb`, from `sonic.blend`). `build_sonic.py` builds the model in Blender (Milestone 7). |
| `stages/` | One folder per world (`emerald_shore/`, `toxic_citadel/`...), one scene per act. `emerald_shore/act_1.tscn` is the first, as a greybox. |
| `ui/title/` | Title screen with the fan-game disclaimer |
| `ui/hud/` | Placeholder HUD: rings, time, lives, red rings and power-ups (final style in Milestone 9) |
