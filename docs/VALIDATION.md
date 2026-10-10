# Playtest build validation

Validated in the cloud on 2026-10-10 with Godot 4.6.3 (standard), GL Compatibility, and the bundled content.

| Check | Result |
| --- | --- |
| Offline Python content validator | PASS: 5,200 unique letter multisets, 5,810 target words, 10,011 defined words |
| Godot system/content suite | PASS: 130,337 checks |
| Godot real-scene UI suite | PASS: 95 checks |
| Web export | PASS |
| Chromium/WebGL with touch emulation | Home → swipe TEA → keyboard EAT/ATE → completion → word collection → recall → Midnight theme; zero browser script errors |
| Android debug export | PASS, ARM64 and x86_64 |
| APK signature | Verified by apksigner |
| APK alignment | Verified for 16 KiB pages |
| Manifest | Portrait, Android 7+ (API24), targetAPI36, no requested permissions |

The screenshots in `docs/screenshots/` are from the actual exported game. Engine tests use disposable saves and do not overwrite a player's profile. Required letter multiplicities, one-time rewards, daily isolation, hint/cosmetic accounting, recall scheduling, corrupt-save recovery, swipe/tap/shuffle input, Android Back behavior, theme contrast, and answer concealment are covered.

A browser touch test exposed a scene-removal warning during pointer dispatch. Navigation and wheel-submission callbacks now run deferred; the same complete browser flow was rerun with no errors.

Native Android hardware, Android emulator execution, iOS, and assistive technologies have **not** been validated in this environment. APK signing and browser play do not replace a phone playtest. The GitHub Actions workflow is configured; its remote run outcome was not verified here. See PLAYTEST.md for the next checks and CONTENT.md for the generated campaign's editorial limitations.
