# Test report

Build under test: version 1.0.0, Godot 4.7.2.

A test passes only when its expected result was actually observed. The "Automated" column is what has been proven by running code. The "On phones" column is for the team to fill in, because no phone was available to the automated runs.

## Functional test cases (design section 9)

| ID | Test | Expected result | Automated | On phones |
| --- | --- | --- | --- | --- |
| T1 | Fresh install, open Level Select | Only Level 1 unlocked | Pass | Not yet run |
| T2 | Clear Level 1 | Level 2 unlocks; stars saved | Pass | Not yet run |
| T3 | Fail Level 2 (time runs out) | Level 3 stays locked; retry offered | Pass | Not yet run |
| T4 | Close and reopen the app after clearing Level 3 | Levels 1–4 unlocked, stars kept | Pass | Not yet run |
| T5 | Tap a locked level | "Clear Level N first" message; level does not start | Pass | Not yet run |
| T6 | Host LAN on phone A, join from phone B on the same hotspot, no internet | Match starts; both see each other move | Pass, over localhost | Not yet run |
| T7 | Create online room, join with the code on mobile data | Match starts within 10 s | Pass, through a local relay | Not yet run |
| T8 | Join with a wrong room code | "Room not found" message | Pass, through a local relay | Not yet run |
| T9 | Turn off Wi-Fi on one phone mid-match | Other player wins by forfeit and returns to the lobby; the dropped phone shows "Connection lost" and returns to the Multiplayer screen | Pass, with a killed process and a simulated network loss | Not yet run |
| T10 | Different game versions try to connect | Connection rejected with "Update required" | Pass, over ENet and through a local relay | Not yet run |

## How each result was produced

- **T1 to T5:** `tests/integration/test_campaign.gd` runs the real Level Select, Match and Level Results scenes. T4 reloads the save from disk.
- **T6, T9, T10 (LAN):** `tools/run_net_tests.sh` starts two separate Godot processes that talk over ENet. T6 also plays a full match to 10 kills.
- **T9:** one process is killed mid-match, in each direction. A third scenario simulates this device having no network, to reach "Connection lost". Turning off real Wi-Fi has not been tested.
- **T7, T8, T10 (online):** the same script starts a real `server/relay.js` on this computer and sends both game processes through it. These scenarios fail if the relay was not actually used.

## Other automated checks

`tools/run_tests.sh` also covers:

- Weapon damage, splash falloff, ammo and reload rules, in unit tests and with every weapon killing a target in real physics
- Bot difficulty, navigation, and a soak test showing bots do not get stuck on any map
- Every mission type clearing and failing correctly
- Save recovery from missing, damaged, zero-filled and hand-edited files, and migration of older saves
- Every button on every screen leading where the design says, and every control meeting the 48 dp touch target
- Pause and save when the app goes to the background, through simulated notifications
- The relay on its own: 25 tests in `server/test/`

`tools/export_android.sh` runs the exported game data with no project folder present, loading every screen and all 10 levels, before it builds an APK.

## Performance

`tools/perf_bench.gd` measures the heaviest level, Level 7 with six Hard bots, without rendering.

| Measure | Result on the development PC |
| --- | --- |
| Game logic per frame | about 1.1 ms, 7% of the 16.7 ms available at 60 FPS |
| Generating all sound at start-up | about 100 ms |
| Starting a level | about 80 ms |

Projectiles are pooled. A desktop PC is much faster than a phone, and this measure excludes drawing, so **a steady 60 FPS on a mid-range phone has not been confirmed.** Use F3 or a three-finger tap on a phone to read the FPS.

## Not yet tested on real hardware

- Installing and running the APK on Android 8.0 or newer
- Multi-touch feel, frame rate and start-up time on a phone
- LAN play over a real hotspot, including host discovery
- The relay deployed on Render, and play over mobile data
- Audio: sounds are only checked to exist, so someone must listen to them
