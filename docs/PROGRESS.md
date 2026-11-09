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
- Two windows on one PC over LAN: `bash tools/run_local_mp.sh` (from Git Bash).
- Online on one PC: see "Run it on your own PC" in `docs/RELAY_DEPLOY.md`.
- Developer flags go after `--`: `--level=3`, `--unlock-all`, `--touch`, `--host`, `--join=<ip>`, `--relay=<url>`, `--room=<code>`, `--profile=<name>`.
- Debug APK for phones: `godot --headless --path . --export-debug "Android" build/sky-skirmish-debug.apk`. The `build/` folder is git-ignored.

## Tests

`tools/run_tests.sh` runs everything, about 4 minutes:

- GUT unit and integration tests, with `--fixed-fps 60` so simulated time runs as fast as the CPU allows.
- `tools/run_net_tests.sh`: two real Godot processes, for T6, T9 and T10 over ENet, and T7, T8, T10, forfeits, rematch and server wake-up through a real local relay. Online scenarios fail if the relay peer was not actually used.
- `npm test` in `server/`: the relay on its own.

Tests redirect saves to `user://test_saves/`, so running them never touches a real save.

## Known issues

- `relay_url` in `data/tuning.json` is empty until the relay is deployed. Until then the Online lobby says the server is not set up.
- The relay has only been tested on Node 24. Its code avoids anything newer than Node 20.
- Clients see their own fighter about 50 ms plus the network delay behind their input, because the host is authoritative and there is no client prediction. Online this delay is larger. Judge it on real phones.
- Discovery uses UDP broadcast, which some phones block. Manual IP entry is the fallback.
- `docs/CREDITS.md` and `data/credits.json` list only Krismar Gonzaga. Add the other team members.
- Placeholder music and sound effects are synthesised. They have only been checked for existence, so someone must listen to them.
- Music is generated at start-up. Check how long start-up takes on a mid-range phone.
- A standing fighter can wedge its head under a two-tile-high tunnel lip. Moving away frees it; bots recover through stuck detection.
- Level balance has only been reasoned about. It needs the structured playtests.
- `export_presets.cfg` has only what the debug APK needs. M8 finishes it and adds release signing.
- `icon.svg` is still the Godot default. Replaced in M8.

## Next steps

1. Confirm LAN play on two phones over a hotspot.
2. Deploy the relay using `docs/RELAY_DEPLOY.md` and confirm T7 and T8 over mobile data.
3. Start M8.
