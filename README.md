# Sonic Velocity Run

This is my open source game. Enjoy!

**Sonic Velocity Run** is a free, open-source 3D Sonic fan game made in [Godot](https://godotengine.org/). It aims for momentum-first movement with classic slope physics, boost-era moves, and Adventure-style stages spread across six worlds.

> **Status: pre-alpha.** Two acts are playable, with their art. **Emerald Shore Act 1, Sunny Beachfront** is a speed act with loops, tidal waves to ride up the beach, a high and a low route, and a side-view pier. **Act 8, Stormy Coastal Fortress** is a short run to the world's first boss, a crab mech that rises out of a tidal wave. The core physics, the camera and the first gimmicks are in: slopes and loops, rolling and the spin dash, the homing attack and air dash, the boost (with an air boost) and quickstep, rings and losing them, springs, dash panels, item monitors, checkpoints, five hidden red rings per act, and four kinds of badnik. There are ten save slots, a world map to pick acts from, an options menu (video, audio, camera, remappable controls), a pause menu, and accessibility options: a slower game speed, an invincibility assist, and a bigger HUD. A greybox test room for trying everything is on the main menu. All the art is toon-shaded and built by scripts in Blender: Act 1's banded sandstone coast with palms and a wooden pier, Act 8's fortress in a storm, the springs, monitors and other objects, the badniks, the boss, the title screen's beach, and Sonic himself, with Sonic Colors-style speed lines and motion blur. Acts 2 to 7 come next, so the demo has all eight of Emerald Shore's acts. The music and sound are in: original tracks for the menus, both acts, the boss and invincibility, with jingles and about 40 sound effects, all made in code.

## Download

Windows, Linux and macOS builds will be published on the [Releases page](https://github.com/FoggiestCash96/DESKTOP-SONIC/releases). There are no releases yet.

> macOS builds aren't notarized by Apple. The first time you open one, right-click the app and choose **Open**.

## What's planned

- **Six worlds** with 8 acts each, ending in a boss: Emerald Shore, Toxic Citadel, Starlight Strip, Glacier Peak, Magma Mine and Cloudtop Citadel. Difficulty rises world by world, and the last boss is the hardest.
- **Moves:** boost, homing attack, air dash, drift, quickstep, spin dash, drop dash, Super Peel Out, stomp, grind rails, wall-running and swimming.
- **Hybrid stages:** full 3D running mixed with 2.5D side-view path sections.
- **Super Sonic**, unlocked after the final boss.
- A world map, a lives system, and saves for best times.

The full design is in [docs/DESIGN.md](docs/DESIGN.md).

## Build and run from source

See [DEVELOPER.md](DEVELOPER.md). In short: install Godot 4.7.2 and Git LFS, clone the repo, open `project.godot` in Godot, and press F5.

## Contributing

Contributions are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) first. Everything you contribute has to be your own original work, with no ripped SEGA assets or code.

## License

| What | License |
|---|---|
| Code (scripts, shaders, scenes, configuration) | [MIT](LICENSE) |
| Original art, models, music and sound | [CC BY-SA 4.0](LICENSE-ASSETS.md) |
| Sonic the Hedgehog characters, names and trademarks | © SEGA. Not covered by either license. |

## Disclaimer

Sonic Velocity Run is a non-commercial fan game made by fans, for fans. It is not affiliated with, endorsed, sponsored or approved by SEGA. Sonic the Hedgehog and all related characters, names, marks and logos are trademarks of SEGA. This project contains no code or assets taken from SEGA games, and it will always be free.
