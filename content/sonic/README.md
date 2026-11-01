# content/sonic/

Everything specific to Sonic the Hedgehog: characters, stages, UI and audio.

Sonic and all related characters and trademarks belong to SEGA. Our original files in this folder are licensed under CC BY-SA 4.0 (see [LICENSE-ASSETS.md](../../LICENSE-ASSETS.md)), but that license grants no rights to SEGA's characters.

| Folder | Contents |
|---|---|
| `characters/sonic/` | Sonic's character definition (`sonic.tres`), his character scene with its AnimationTree (`sonic.tscn`), and his model (`sonic.glb`, from `sonic.blend`). `build_sonic.py` builds the model in Blender (Milestone 7, rebuilt in the Milestone 10 art pass). |
| `enemies/` | Badniks: the engine's enemy behaviours dressed up as Emerald Shore's Scuttler (crab), Galegull (gull), Pearlshot (clam) and Leapfin (fish) (Milestone 8). `models/` has their models and `build_badniks.py`, which builds them (Milestone 10). |
| `bosses/emerald_shore/` | The Egg Tidecrab: the crab mech's fight (`crab_mech.gd`) and its scene, with Eggman's ship, the intro wave and the intro camera (Milestone 8), and the models for the mech and the ship, from `build_crab_mech.py` (Milestone 10) |
| `stages/` | One folder per world (`emerald_shore/`, `toxic_citadel/`...), one scene per act. `emerald_shore/act_1.tscn` and `act_8.tscn` (the boss act, in a storm) have their art in `emerald_shore/art/`: each act's greybox as JSON, its build script and its `.glb`, the world's kits (`shore_kit.py`, `fortress_kit.py`) and its materials. `worlds.tres` lists every world and act for the world map. |
| `objects/` | Models for the engine's objects (springs, dash panels, item monitors, checkpoints, the goal, the extra life, spikes, freed animals), `build_objects.py`, which builds them, and `art_bank.tres`, where the engine finds them (Milestone 10) |
| `materials/` | Materials shared by all the art, found by name when a `.glb` is imported: the two-sided painted material, glass, glows, waves and spike plates |
| `ui/title/` | Title screen with the fan-game disclaimer and the main menu, in front of a live beach (`title_backdrop.tscn`, its art built by `art/build_title_beach.py`) |
| `ui/menus/` | Save slots, options (with control remapping) and the pause menu, plus `menu_kit.gd`, their shared helpers |
| `ui/map/` | The world map: a menu map of the six worlds and their acts |
| `ui/hud/` | Adventure-style HUD: rings, time, red rings, lives, power-ups, the boost gauge, a boss's hits left, the results and the pause menu, with icons drawn in code |
| `ui/translations/` | Every player-facing string, by key, in `strings.csv` (English for now) |
| `ui/menu_theme.tres` | The menus' shared look |
| `audio/` | The music (`music/`, Ogg Vorbis with loop points, plus faster versions for speed shoes) and sound effects (`sounds/`), all original and made by `tools/audio/`, and `sound_bank.tres`, which names the file for each of the engine's sounds and music cues (Milestone 10) |
