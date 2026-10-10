# Folio

**A little wordplay, every day.** An offline, portrait-first mobile word game made with **Godot 4.6.3**. Crisp ink, cobalt accents, Fraunces headlines, and DM Sans letterforms.

## Download and play

**[Download the Android test APK](https://github.com/akhileshedd71-rgb/Word-Puzzle-game-2/raw/refs/heads/main/downloads/Folio-android.apk)**

1. Download the APK on an **Android 7.0+ ARM64** phone or tablet. x86_64 is included for compatible emulators.
2. Open the file and allow installation from your browser/file manager if Android asks.
3. Open **Folio**, tap **Continue journey**, and swipe or tap letters to make words.

This is a **debug-signed playtest build**, not a store release. It requests no Android permissions and needs no account or internet connection. Progress stays on your device; uninstalling removes it. Keep the existing installation when installing updates signed by the same test key.

Prefer the editor? Download this repository, import **`project.godot`** into **Godot 4.6.3 standard edition**, then press **F5**. No plugins, C#, npm packages, or dictionary API keys are needed. Desktop mouse and keyboard are supported.

## What's playable

- **5,200 distinct campaign letter banks**, sequential progression, five difficulty bands, relief puzzles, and learning-focused challenge pages. The first 20 puzzles are hand-selected; the rest use a reproducible generator.
- **Daily edition:** the same deterministic puzzle on the same UTC date, one completion reward per date, and a spoiler-free result to copy.
- **Cozy:** untimed practice at any of five difficulties.
- **Clue:** solve one word from its definition at a time.
- **Sprint:** a 90-second word hunt with a saved personal best. The clock pauses for menus and when the app loses focus.
- **10,011 accepted words with offline meanings.** Extra valid words count as bonus discoveries. This is a bounded learning dictionary, not a tournament word list.
- **Personal word collection:** definitions, search, and active recall. Newly collected words can be reviewed immediately; later reviews use 1, 3, 7, 14, and 30-day spacing.
- **Milestone challenges, earned coins, and a placeholder ink shop.** Campaign/daily rewards cannot be repeatedly farmed. Hints cost 15 coins; definition clues are free.
- **Paper and Midnight themes**, four accent choices, sound and reduced-motion settings, drawn vector icons, and a quiet generated completion chime.
- **Automatic local saves**, backup recovery, and separate progress for campaign, daily, and practice.

There are no ads, payments, energy limits, punitive streak resets, accounts, or online services in this edition. Monetization remains future work.

## Controls

**Touch/mouse:** swipe between letter circles and release to submit; or tap letters and press **Submit**. Use each physical letter tile once per word. Tap the wheel's center to shuffle. Tap a blank target for a free definition clue, or a solved target for its meaning.

**Keyboard:** type letters, **Enter** to submit, **Backspace** to undo, **Escape** to dismiss or go back.

Finish all required words to turn the page. Found words enter **Words**, and challenge rewards and cosmetics live in **Studio**.

## Run and verify

```sh
godot --editor --path .
# Or run directly:
godot --path .

# All checks (Godot + Python standard library):
tools/check.sh

# Individual checks:
python3 tools/build_content.py --validate
godot --headless --path . --script tests/test_systems.gd
godot --headless --path . --script tests/test_ui.gd
```

The tests use disposable profiles and preserve real player progress. They cover every bundled target, letter multiplicities, definition coverage, unlocks, daily isolation, idempotent rewards, hint prices, purchases, review scheduling, malformed saves, backup recovery, real UI navigation, wheel input, and contrast.

Browser/WebGL gameplay has been tested through puzzle completion. APK signatures and alignment are verified. **Native Android hardware and iOS have not been tested here.** See [PLAYTEST.md](docs/PLAYTEST.md) for a phone checklist.

[BUILDING.md](docs/BUILDING.md) documents Android/Web exports. The GitHub Actions workflow validates and builds downloadable artifacts on pushes and manual runs; the Actions tab shows the actual run status.

## Design and content

- [Design and research](docs/DESIGN.md): game inspirations, puzzle loops, active recall, difficulty, visual choices, evidence, and future ideas.
- [Content and generation](docs/CONTENT.md): JSON schema, filtering, deterministic generation, licensing, and limits.
- [Build instructions](docs/BUILDING.md): exact versions, Android signing, and CI.

This is a playable first edition, not 5,200 manually edited puzzles. Automated validation proves formability and definition coverage; editorial playtesting still needs to assess vocabulary and difficulty. WordNet wording can be formal or dated. Folio does not make clinical memory or cognitive-training claims.

Future work includes broad editorial review, difficulty calibration from playtests, iOS export/signing, assistive-technology testing, localization, and optional cloud saves. Leaderboards and store monetization are not implemented.

## Project map

```text
project.godot            Entry point and portrait display configuration
scenes/main.tscn         Main scene
scripts/main.gd         Interface, navigation, and game modes
scripts/letter_wheel.gd Tap, swipe, and shuffle input
scripts/catalog.gd      Dictionary, levels, and daily selection
scripts/game_state.gd   Saves, rewards, hints, challenges, and recall
scripts/mark.gd         Vector interface artwork
data/                   Levels, definitions, and licenses
tests/                  System and real-scene integration tests
tools/                  Content generator, validation, and exports
```

## Credits and licensing

Game code and original artwork: **MIT**, see [LICENSE](LICENSE).

Definitions derive from **Princeton WordNet 3.0**, Copyright 2006 Princeton University, with authored clarifications and filtering. Frequency guidance uses **wordfreq 3.1.1 by Robyn Speer** and its credited sources. The **content compilation, generated levels, and authored additions are CC BY-SA 4.0**; WordNet text retains its original notice. See [data/licenses](data/licenses/README.md) and [wordfreq source credits](data/licenses/WORDFREQ-NOTICES.md).

Typography: **Fraunces** by Undercase Type / Phaedra Charles / Flavia Zimbardi and **DM Sans** by Colophon Foundry and contributors, under the [SIL Open Font License](assets/fonts/). Engine: [Godot, MIT](assets/GODOT-LICENSE.txt). About → Licenses in the app contains the notices too.
