# Folio Android test build

[Download Folio-android.apk](https://github.com/akhileshedd71-rgb/Word-Puzzle-game-2/raw/refs/heads/main/downloads/Folio-android.apk), then open it on your Android device to install. If Android asks, allow installation from the browser or file manager you used. The file is approximately 54 MiB.

- **Version:** 0.1.0, built with Godot 4.6.3.
- **Devices:** Android 7.0+ (API 24), ARM64 phones or x86_64 emulators, OpenGL ES 3.0.
- **Build type:** debug-signed testing APK; not an app store release.
- **Play:** portrait, offline, no requested Android permissions. Progress is stored locally.
- **Validation:** APK v2/v3 signatures, 16 KiB alignment, package metadata, permissions, and bundled content checked. The game was tested in the browser; **this APK has not been tested on a physical Android device**.

The same local debug signing key is retained in the development environment for future local builds. No signing key is committed to Git. A build signed with a different key cannot update this installation; Android may require uninstalling the previous version first, which deletes its local save. GitHub Actions creates a new temporary debug key for each run.

To verify the downloaded file from this directory:

```sh
sha256sum -c SHA256SUMS
```

See [build instructions](../docs/BUILDING.md) to run the source in Godot or export your own APK. The APK is committed here to provide a direct download without requiring a GitHub Actions artifact download.
