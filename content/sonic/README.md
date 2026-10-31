# content/sonic/

Everything specific to Sonic the Hedgehog: characters, stages, UI and audio.

Sonic and all related characters and trademarks belong to SEGA. Our original files in this folder are licensed under CC BY-SA 4.0 (see [LICENSE-ASSETS.md](../../LICENSE-ASSETS.md)), but that license grants no rights to SEGA's characters.

| Folder | Contents |
|---|---|
| `characters/sonic/` | Sonic's character definition (`sonic.tres`), his character scene with its AnimationTree (`sonic.tscn`), and the stand-in model (`sonic.glb`, from `sonic.blend`). `build_sonic.py` builds the model in Blender (Milestone 7). |
| `enemies/` | Badniks: the engine's enemy behaviours dressed up as Emerald Shore's Scuttler (crab), Galegull (gull), Pearlshot (clam) and Leapfin (fish), as simple stand-ins (Milestone 8) |
| `bosses/emerald_shore/` | The Egg Tidecrab: the crab mech's fight (`crab_mech.gd`) and its scene, with Eggman's ship, the intro wave and the intro camera (Milestone 8) |
| `stages/` | One folder per world (`emerald_shore/`, `toxic_citadel/`...), one scene per act. `emerald_shore/act_1.tscn` and `act_8.tscn` (the boss act, with its stormy sky) are greyboxes. `worlds.tres` lists every world and act for the world map. |
| `ui/title/` | Title screen with the fan-game disclaimer and the main menu |
| `ui/menus/` | Save slots, options (with control remapping) and the pause menu, plus `menu_kit.gd`, their shared helpers |
| `ui/map/` | The world map: a menu map of the six worlds and their acts |
| `ui/hud/` | Adventure-style HUD: rings, time, red rings, lives, power-ups, a boss's hits left, the results and the pause menu, with icons drawn in code |
| `ui/translations/` | Every player-facing string, by key, in `strings.csv` (English for now) |
| `ui/menu_theme.tres` | The menus' shared look |
