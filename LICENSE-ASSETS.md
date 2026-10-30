# Asset licensing

This repository uses two licenses, plus material that belongs to SEGA and isn't ours to license.

## 1. Code: MIT

Everything that is code or engine configuration is under the [MIT License](LICENSE):

- GDScript (`*.gd`) and shaders (`*.gdshader`)
- Everything in `engine/`, `tests/` and `.github/`
- Project and export configuration (`project.godot`, `export_presets.cfg`)
- Scene and resource files (`*.tscn`, `*.tres`) that only wire up code, such as the player, camera, gimmicks, debug tools and greybox materials

## 2. Original assets: CC BY-SA 4.0

Original creative work made for this project is under
[Creative Commons Attribution-ShareAlike 4.0 International](https://creativecommons.org/licenses/by-sa/4.0/)
([legal code](https://creativecommons.org/licenses/by-sa/4.0/legalcode)):

- 3D models, rigs and animations (`*.blend`, `*.glb`)
- Textures, sprites, UI art and icons
- Music and sound effects
- Stage and level layouts in `content/` and `stages/`

**Attribution:** credit "The Sonic Velocity Run contributors" and link to this repository. Where `CREDITS.md` names an individual author for an asset, credit that person too.

## 3. Not covered: SEGA property

Sonic the Hedgehog and all related characters, names, logos and trademarks are the property of SEGA. Neither license above grants any rights to them. That includes our own original models and art *of* SEGA characters: the files are ours, but the characters aren't. This is a free, non-commercial fan project that isn't affiliated with or endorsed by SEGA.

## 4. Third-party assets

Assets made by others keep their own licenses. Each one must be listed in [CREDITS.md](CREDITS.md) with its author, source and license before it's merged.
