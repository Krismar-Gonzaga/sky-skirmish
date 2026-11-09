# Progress

## Milestones

| Milestone | Status |
| --- | --- |
| M0 Setup and skeleton | Done |
| M1 Player movement | Done |
| M2 Combat | Done |
| M3 Bots | Done |
| M4 Campaign and level progression | Done |
| M5 Menus and screens | Done, awaiting review |
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

## How to try the game

- Press F5 in the editor. The game starts at the Splash screen and goes to the Main Menu.
- Controls: A/D walk, W or Space jet, S crouch, mouse aims, left click fires, G grenade, Q swap, F melee, Esc pause, F3 debug overlay.
- Developer flags go after `--`: `godot --path . -- --level=3 --unlock-all`. Also `--touch` for on-screen controls with a mouse.
- Weapon and bot sandbox: open `scenes/game/Sandbox.tscn` and press F6. Keys 1 to 4 set bot difficulty, 0 spawns dummies.

## Tests

`tools/run_tests.sh` adds `--fixed-fps 60` so simulated time runs as fast as the CPU allows (under a minute). Without that flag the same tests take several minutes.

Tests redirect saves to `user://test_saves/`, so running them never touches a real save.

## Known issues

- The LAN and Online lobbies are placeholders until M6 and M7. Their buttons are disabled, and Back works. Rematch on Match Results is also disabled until M6.
- `docs/CREDITS.md` and `data/credits.json` list only Krismar Gonzaga. Add the other team members.
- Placeholder music and sound effects are synthesised. They have only been checked for existence, so someone must listen to them.
- Music is generated at start-up. Check how long start-up takes on a mid-range phone in M8.
- A standing fighter can wedge its head under a two-tile-high tunnel lip. Moving away frees it; bots recover through stuck detection.
- Level balance has only been reasoned about. It needs the structured playtests.
- Real multi-touch feel has not been tried on a phone. Multi-touch logic is covered by automated event tests; the first APK comes in M8.
- M8 must add `data/*.json`, `data/maps/*.json` and `assets/asset_map.json` to the export include filter, and check they load in the APK.
- `DebugOverlay` shows ping as "-" until M6.
- JDK 17 is missing. To be checked at M8; the default (non-Gradle) export may work with JDK 21.
- `icon.svg` is still the Godot default. Replaced in M8.

## Next steps

Review M5, then start M6.
