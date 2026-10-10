# Run and build Folio

Folio is a Godot **4.6.3 standard edition** project using GDScript and the GL Compatibility renderer. It has no paid plugins, external runtime services, ads, or required credentials. All game content is bundled. Use the existing checkout; a cloud task already runs in isolation and does not need another Git worktree.

## Play in the editor

1. Install [Godot 4.6.3](https://github.com/godotengine/godot-builds/releases/tag/4.6.3-stable).
2. Import the repository's `project.godot` in Godot.
3. Press **F6** with the main scene open, or **F5** to run the project.

The project is portrait oriented and scales to the available screen. Mouse input works in the editor and touch works on phones. Saves live in Godot's `user://` application data folder, not in the repository.

## Download an Android test build

Download [Folio-android.apk](../downloads/Folio-android.apk) for a ready-to-install test build; its checksum and testing notes are in [downloads](../downloads/README.md).

The GitHub **Actions → Build Folio** workflow runs on pushes to `main` and can be run manually. Open a successful run, download **Folio-Android-debug** from **Artifacts**, unzip it, and install `Folio-debug.apk` on an Android phone. Android may ask you to allow installation from the browser or file manager you use. This is a debug build for testing, not an app store release.

The APK includes ARM64 phones and x86_64 emulators. It requests no network, billing, notification, location, or storage permission. It requires Android 7.0 or newer and OpenGL ES 3.0. No internet connection is required to play after installation. Local daily puzzles use the device's date; no server validates the clock.

Each CI run creates a new test signing key. Android will not install an update signed by a different key over an existing build. In that case uninstall the previous test build first; **uninstalling deletes its local save**. Local builds preserve their key across exports and can update each other. Production signing, app store packages, and monetization are intentionally future work.

## Command line checks

From the repository root:

```sh
godot --headless --path . --editor --import
godot --headless --path . --script tests/test_systems.gd
```

## Export from Linux or a cloud environment

Install the official **4.6.3 export templates** through Godot's **Editor → Manage Export Templates**. Alternatively download `Godot_v4.6.3-stable_export_templates.tpz` and `SHA512-SUMS.txt` from the release above, verify the archive against that exact entry in the checksum file, and extract its `templates/` contents into:

```text
${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/4.6.3.stable/
```

`web_nothreads_release.zip`, `web_nothreads_debug.zip`, `android_release.apk`, and `android_debug.apk` should be directly inside that directory (extracting all template files is also fine). The command line script requires Bash and Python 3. Set `GODOT_BIN` if your executable is not named `godot`.

Web export:

```sh
tools/export_game.sh web builds
python3 -m http.server 8000 --directory builds/web
```

Open `http://localhost:8000`. Use HTTP or HTTPS instead of opening the HTML file directly. The Web preset is single threaded, so no special cross-origin isolation headers are required. The browser needs WebGL 2. Save persistence depends on browser storage; private browsing, clearing site data, and a changed site origin can remove or isolate saves. The PWA can be installed from a compatible browser on HTTPS (or localhost) and cached for offline use after its first load.

Android export additionally requires OpenJDK 17+ (tested with 21) and the [Android SDK command line tools](https://developer.android.com/studio#command-tools). Using `sdkmanager`, install:

```sh
sdkmanager 'platform-tools' 'build-tools;36.0.0' 'platforms;android-36'
# Set these to your own installations:
export ANDROID_HOME=/path/to/android-sdk
export JAVA_HOME=/path/to/jdk-21
tools/export_game.sh android builds
```

The current SDK command line tool also supports `android sdk` as the replacement for `sdkmanager`. Follow the SDK's license prompts. Godot 4.6.3 uses target SDK 36. Folio uses the built-in APK templates, so a Gradle build, Android source template, and NDK are not required.

The export script creates temporary editor settings, preserves your own settings, and stores a reusable **test-only** signing key in `${XDG_DATA_HOME:-$HOME/.local/share}/folio/signing/`. Override `FOLIO_SIGNING_DIR` to select another local directory. Keystores and build outputs are ignored by Git. Never use the generated debug key for production signing. A real iOS build requires macOS, Xcode, and Apple signing, and is not included in this Android/Web testing workflow.

## Paths in this cloud workspace

The checked setup uses:

```sh
export XDG_DATA_HOME=/workspace/.folio-tools/share
export XDG_CACHE_HOME=/workspace/.folio-tools/cache
export XDG_CONFIG_HOME=/workspace/.folio-tools/config
export ANDROID_HOME=/workspace/.folio-tools/android-sdk
tools/export_game.sh all /workspace/folio-builds
```

These paths are conveniences for the current cloud environment, not requirements for your computer. Tools and templates live outside the checkout. Verify downloaded artifacts using official checksums and keep TLS verification enabled.
