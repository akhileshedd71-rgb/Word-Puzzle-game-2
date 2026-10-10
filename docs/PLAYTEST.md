# Folio mobile playtest

This is a checklist for testing v0.1 on a real phone. It is **not a record of completed device testing**. Automated content and Godot integration checks cover data and application behavior; touch comfort, notches, keyboards, battery use, and operating-system transitions still need physical-device testing. See [BUILDING.md](BUILDING.md) for Android/Web build instructions.

## First five minutes

- [ ] Install and launch in portrait. Check that the masthead, bottom navigation, and modal close buttons avoid system bars and screen cutouts.
- [ ] Start Journey level 1. Form **TEA**, **EAT**, and **ATE** using taps and Submit; replay input on another page with a continuous swipe and finger release.
- [ ] Check that a tile cannot be reused unless another tile contains the same letter. Drag back one letter, clear an entry, and shuffle from the wheel's center.
- [ ] Submit a duplicate and an invalid word. Check that progress and balance stay unchanged and feedback is readable.
- [ ] Open a blank target's free definition, buy one 15-coin hint, and finish a page. Confirm the revealed letter, reward, and next-level unlock.
- [ ] Leave midway through another page, close the app, and reopen it. Confirm found words, hints, coins, and unlocked pages persist.

## Modes, learning, and rewards

- [ ] Play Cozy at Gentle and Intense difficulty. There should be no countdown or loss of lives, and its completion should not unlock Journey or grant repeat coins.
- [ ] Play Clue. Its current definition should correspond to the required next word; an answer to a later target should not skip the displayed clue.
- [ ] Start Sprint, find target and bonus words, then pause, background the app, and return. Verify the 90-second timer resumes only when intended, the ending is navigable, and the personal best survives a relaunch.
- [ ] Open the Daily Edition on two devices using the same build and UTC date. Check matching letters, a once-per-date reward, and spoiler-free clipboard sharing. Check behavior across 00:00 UTC, especially with yesterday's puzzle still open.
- [ ] Open Words after the first page. Newly discovered words should be ready to review immediately. Reveal an answer and try each self-rating. The reviewed word should leave today's queue; success schedules 1, 3, 7, 14, then 30 days, while a miss schedules one day and resets the sequence.
- [ ] Search the collection with the phone keyboard. Check matching results, empty results, keyboard dismissal, and access to controls while the keyboard is visible.
- [ ] Claim a completed Studio milestone twice; only the first claim should award coins. Buy and select an accent, try an unaffordable purchase, and verify persistence after relaunch.

## Comfort and resilience

- [ ] Test Paper and Midnight in indoor and bright lighting. Check primary buttons, selected letters, bonus feedback, and every purchased accent for readability.
- [ ] Switch sound off and reduced motion on. Confirm the preferences survive relaunch and leave all necessary feedback visible.
- [ ] Scroll long word definitions and the field guide. Use Android Back or browser navigation appropriately; verify that modals and puzzle exits behave predictably.
- [ ] Try a small phone, a tall phone, and a tablet. Check that swiping the wheel does not accidentally scroll the page, text stays legible, and buttons are comfortable to hit.
- [ ] Play with connectivity disabled. The installed Android build should still validate words, show meanings, save progress, and select the daily. A Web/PWA build needs its initial assets loaded/cached first.

## Known scope and limitations

- The campaign has 5,200 distinct generated letter banks with a curated opening. Broad editorial review is pending; frequency estimates do not guarantee familiar vocabulary or ideal pacing. Some WordNet meanings are formal or dated. The bounded bonus dictionary omits some legitimate regional spellings and inflections.
- Daily selection and review due dates use the device clock. There is no trusted-time server, cloud sync, account, multiplayer leaderboard, or cross-device save transfer.
- Recall uses self-ratings and fixed intervals. It has not been evaluated as a learning intervention and does not measure mastery.
- The shop uses earned local coins only. There are no ads, payment SDKs, or real-money purchases. Native haptics and a signed iOS binary are not included.
- Android downloads are debug builds. Builds signed with a different test key may require uninstalling the previous app, which deletes local progress. See the signing notes in [BUILDING.md](BUILDING.md).
- Web saves depend on browser storage and origin. Clearing site data, private browsing, or moving to another host can discard or isolate progress.

For a useful report, include the build/commit, phone model and OS, exact steps, expected result, observed result, and a screenshot or short recording. Mention the mode, difficulty, level number or daily UTC date, and relevant word. Do not include account credentials or private device information.
