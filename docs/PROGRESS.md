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
| M6 Offline LAN multiplayer | Automated checks pass; waiting for the two-phone test |
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
| JDK | 21 (Android Studio) and 26 only. JDK 17 is not installed, but a debug APK exported and signed with JDK 21 |

## How to try the game

- Press F5 in the editor. The game starts at the Splash screen and goes to the Main Menu.
- Controls: A/D walk, W or Space jet, S crouch, mouse aims, left click fires, G grenade, Q swap, F melee, Esc pause, F3 debug overlay.
- Two windows on one PC: `bash tools/run_local_mp.sh` (from Git Bash).
- Developer flags go after `--`: `--level=3`, `--unlock-all`, `--touch`, `--host`, `--join=<ip>`, `--profile=<name>`.
- Debug APK for phones: `godot --headless --path . --export-debug "Android" build/sky-skirmish-debug.apk`. The `build/` folder is git-ignored.

## Tests

`tools/run_tests.sh` runs everything, about 2 minutes:

- GUT unit and integration tests, with `--fixed-fps 60` so simulated time runs as fast as the CPU allows.
- `tools/run_net_tests.sh`: two real Godot processes over ENet on localhost, for T6, T9, T10, the lobby, rematch and joining with nobody hosting.

Tests redirect saves to `user://test_saves/`, so running them never touches a real save.

## Known issues

- The Online lobby is a placeholder until M7. Back works.
- Clients see their own fighter about 50 ms plus the network delay behind their input, because the host is authoritative and there is no client prediction. Judge this on real phones.
- Discovery uses UDP broadcast, which some phones block. Manual IP entry is the fallback.
- `docs/CREDITS.md` and `data/credits.json` list only Krismar Gonzaga. Add the other team members.
- Placeholder music and sound effects are synthesised. They have only been checked for existence, so someone must listen to them.
- Music is generated at start-up. Check how long start-up takes on a mid-range phone.
- A standing fighter can wedge its head under a two-tile-high tunnel lip. Moving away frees it; bots recover through stuck detection.
- Level balance has only been reasoned about. It needs the structured playtests.
- `export_presets.cfg` has only what the debug APK needs. M8 finishes it and adds release signing.
- `icon.svg` is still the Godot default. Replaced in M8.

## Next steps

Confirm LAN play on two phones over a hotspot, then start M7.
