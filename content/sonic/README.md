# content/sonic/

Everything specific to Sonic the Hedgehog: characters, stages, UI and audio.

Sonic and all related characters and trademarks belong to SEGA. Our original files in this folder are licensed under CC BY-SA 4.0 (see [LICENSE-ASSETS.md](../../LICENSE-ASSETS.md)), but that license grants no rights to SEGA's characters.

| Folder | Contents |
|---|---|
| `characters/sonic/` | Sonic's character definition (`sonic.tres`), his character scene with its AnimationTree (`sonic.tscn`), and the stand-in model (`sonic.glb`, from `sonic.blend`). `build_sonic.py` builds the model in Blender (Milestone 7). |
| `enemies/` | Badniks: the engine's enemy behaviours dressed up as Emerald Shore's Scuttler (crab), Galegull (gull), Pearlshot (clam) and Leapfin (fish), as simple stand-ins (Milestone 8) |
| `bosses/emerald_shore/` | The Egg Tidecrab: the crab mech's fight (`crab_mech.gd`) and its scene, with Eggman's ship, the intro wave and the intro camera (Milestone 8) |
| `stages/` | One folder per world (`emerald_shore/`, `toxic_citadel/`...), one scene per act. `emerald_shore/act_1.tscn` and `act_8.tscn` (the boss act, with its stormy sky) are greyboxes. |
| `ui/title/` | Title screen with the fan-game disclaimer |
| `ui/hud/` | Placeholder HUD: rings, time, lives, red rings, power-ups and a boss's hits left (final style in Milestone 9) |
