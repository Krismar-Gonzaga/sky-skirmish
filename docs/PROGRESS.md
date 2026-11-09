# Progress

## Milestones

| Milestone | Status |
| --- | --- |
| M0 Setup and skeleton | Done |
| M1 Player movement | Done |
| M2 Combat | Done |
| M3 Bots | Done |
| M4 Campaign and level progression | Done |
| M5 Menus and screens | Done |
| M6 Offline LAN multiplayer | Automated checks pass. Two-phone test not yet reported |
| M7 Online multiplayer | Automated checks pass through a local relay. Render deployment and mobile-data test not yet done |
| M8 Android build, polish, submission | Everything automatable is done. APK has not yet run on a phone |

## Submission checklist (design section 9)

| Item | State | Who finishes it |
| --- | --- | --- |
| One-page GDD | Done: `docs/GDD.md` | |
| Signed Android APK, Android 8.0+ | Build tested, including release signing with a temporary key. Not yet run on a phone | Team: create the keystore, build per `docs/BUILD.md` |
| Source code in Git, including `server/relay.js` | Done locally on branch `dev`. No remote yet | Team: push to GitHub |
| Technical documentation | Done: `docs/DESIGN.md` | |
| Test results T1–T10 | Automated results in `docs/TEST_REPORT.md`; "On phones" column empty | Team |
| Playtest forms, findings and change log, both rounds | Forms and templates ready: `docs/PLAYTEST_FORM.md`, `docs/CHANGELOG.md`. No playtests run yet | Team |
| Demo video, 2–3 min | Script ready: `docs/DEMO_SCRIPT.md`. Not filmed | Team |
| Credits for all assets | Done: `docs/CREDITS.md`, in-game Credits. Team names incomplete | Team: add members |

## Environment (this machine)

| Tool | State |
| --- | --- |
| Godot | 4.7.2 stable, in Downloads, not on PATH. `tools/local.env` points at it |
| Export templates | 4.7.2 installed |
| Node / npm | 24.16.0 / 11.13.0 |
| Git | 2.54.0 |
| Android SDK | Installed; platforms 35, 36, 36.1; build-tools up to 37.0.0. No emulator images |
| JDK | 21 (Android Studio) and 26 only. Debug and release APKs built with JDK 21 |

## How to try the game

See `README.md`. Build instructions are in `docs/BUILD.md`.

## Tests

`tools/run_tests.sh` runs everything, about 4 minutes. Tests redirect saves to `user://test_saves/`, so running them never touches a real save.

## Known issues

- `relay_url` in `data/tuning.json` is empty until the relay is deployed. Until then the Online lobby says the server is not set up.
- The relay has only been tested on Node 24. Its code avoids anything newer than Node 20.
- The APK declares a minimum of Android 7 (API 24), set by Godot's export template. That includes the design's Android 8.0 target.
- Clients see their own fighter about 50 ms plus the network delay behind their input, because the host is authoritative and there is no client prediction. Online this delay is larger. Judge it on real phones.
- Discovery uses UDP broadcast, which some phones block. Manual IP entry is the fallback.
- Placeholder music and sound effects are synthesised. They have only been checked for existence, so someone must listen to them.
- A standing fighter can wedge its head under a two-tile-high tunnel lip. Moving away frees it; bots recover through stuck detection.
- Level balance has only been reasoned about. It needs the structured playtests.

## Next steps

1. Install `build/sky-skirmish-debug.apk` on two phones and confirm LAN play over a hotspot.
2. Push to GitHub, deploy the relay per `docs/RELAY_DEPLOY.md`, and confirm T7 and T8 over mobile data.
3. Create the keystore and build the signed APK.
4. Run the two playtest rounds, film the demo, and fill in the "On phones" column of the test report.
