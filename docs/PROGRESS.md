# Progress

## Milestones

| Milestone | Status |
| --- | --- |
| M0 Setup and skeleton | Done |
| M1 Player movement | Done |
| M2 Combat | Done |
| M3 Bots | Done, awaiting review |
| M4 Campaign and level progression | Not started |
| M5 Menus and screens | Not started |
| M6 Offline LAN multiplayer | Not started |
| M7 Online multiplayer | Not started |
| M8 Android build, polish, submission | Not started |

## Environment (this machine)

| Tool | State |
| --- | --- |
| Godot | 4.7.2 stable, in Downloads, not on PATH. `tools/local.env` points at it |
| Export templates | 4.7.2 installed |
| Node / npm | 24.16.0 / 11.13.0 |
| Git | 2.54.0 |
| Android SDK | Installed; platforms 35, 36, 36.1; build-tools up to 37.0.0 |
| JDK | 21 (Android Studio) and 26 only. JDK 17 is not installed |

## How to try the sandbox

- Desktop: press F5 in the editor. A/D walk, W or Space jet, S crouch, mouse aims, left click fires, G grenade, Q swap, F melee, F3 debug overlay.
- Keys 1 to 4 spawn two bots at Easy, Normal, Hard or Expert. Key 0 spawns target dummies.
- On-screen controls with a mouse: `godot --path . -- --touch` (one finger only).

## Tests

`tools/run_tests.sh` adds `--fixed-fps 60` so simulated time runs as fast as the CPU allows (about 30 s). Without that flag the same tests take about 3 minutes.

## Known issues

- `run/main_scene` points at `Sandbox` until the Splash screen is built in M5.
- Aim assist is saved in Settings by the design but not built yet. Planned for M5 with the Settings screen.
- The Pause button arrives with the pause flow in M5.
- Placeholder sound effects are synthesised. They have only been checked for existence, so someone must listen to them.
- A standing fighter can wedge its head under a two-tile-high tunnel lip. Moving away frees it; bots recover through stuck detection.
- Bots only carry the weapons they walk over. M4 may need bots to start with stronger weapons on later levels.
- Real multi-touch feel has not been tried on a phone. Multi-touch logic is covered by automated event tests; the first APK comes in M8.
- M8 must add `data/*.json`, `data/maps/*.json` and `assets/asset_map.json` to the export include filter, and check they load in the APK.
- `DebugOverlay` lives in the sandbox scene for now and shows ping as "-" until M6.
- JDK 17 is missing. To be checked at M8; the default (non-Gradle) export may work with JDK 21.
- `icon.svg` is still the Godot default. Replaced in M8.

## Next steps

Review M3, then start M4.
