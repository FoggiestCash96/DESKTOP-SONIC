# Contributing

Thanks for helping. This page covers what we can accept and how to send it in.

## Ground rules

1. **Original work only.** Don't submit sprites, models, textures, music, sound or code extracted from SEGA games or from other fan games. Re-creating a *mechanic* from its documented behaviour (for example from the Sonic Physics Guide) is fine. Copying someone's files or code is not.
2. **No GPL code.** The code here is MIT. SRB2 and Open Sonic are great references, but they're GPL, so don't paste or translate their source into this project.
3. **Keep `engine/` franchise-free.** Code and assets under `engine/` must not mention or depict SEGA characters or trademarks. Sonic-specific content goes in `content/sonic/`. A unit test checks this.
4. **Free forever.** No monetization of any kind: no sales, ads or paid perks.
5. **Generated assets:** if you used generative tools to make an asset, say which ones in your pull request, and make sure the result doesn't imitate official SEGA artwork.

## Licensing of contributions

By opening a pull request, you confirm that:

- you made the contribution yourself, or you have the right to submit it, and
- you agree that code is released under the [MIT License](LICENSE) and original assets under [CC BY-SA 4.0](LICENSE-ASSETS.md).

If a contribution includes third-party assets, add each one to [CREDITS.md](CREDITS.md) with its author, source and license.

## How to contribute

1. Set up the project as described in [DEVELOPER.md](DEVELOPER.md).
2. For anything bigger than a small fix, open an issue first so we can agree on the approach.
3. Work on a branch, and keep each pull request focused on one change.
4. Run the unit tests and make sure they pass (see DEVELOPER.md).
5. In your pull request, explain what changed and how to test it in the editor.

## Code style

- Follow the [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html): tabs, `snake_case` names, `PascalCase` class names.
- Use static types everywhere (`var speed: float`, `func run() -> void`). The project warns on untyped declarations.
- Put tunable gameplay numbers in `.tres` resources, not in code.
- Add or update tests in `tests/unit/` for physics and other math.

## Code of conduct

Everyone taking part is expected to follow the [Code of Conduct](CODE_OF_CONDUCT.md).
