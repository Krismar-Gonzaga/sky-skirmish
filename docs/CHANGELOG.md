# Change log

## Playtest changes

Fill in one row for every change made because of a playtest. The evidence column should compare results before and after, for example "Level 3 clear rate 2/5 → 4/5".

### Round 1

| Issue | Change made | Evidence it worked |
| --- | --- | --- |
| | | |

### Round 2

| Issue | Change made | Evidence it worked |
| --- | --- | --- |
| | | |

## Development history

### 1.0.0

**Android build and submission package (M8)**

- App icon, finished Android export preset and `tools/export_android.sh`.
- The export script now proves the packaged game is complete before building.
- Performance benchmark in `tools/perf_bench.gd`.
- README, build guide, GDD, test report, playtest kit and demo script.
- Settings sliders raised to the 48 dp touch target, with a test covering every menu control.

**Online multiplayer (M7)**

- `server/relay.js`: room codes, 2-player limit, version check, idle cleanup, heartbeat and `/health`.
- `RelayMultiplayerPeer` carries Godot's multiplayer packets over a WebSocket, so gameplay code is unchanged.
- Online lobby, "Waking server…" handling for free hosting, and a Render deployment guide.
- Fixed: Godot reported an error when packets from a departed guest were still queued.

**Local multiplayer (M6)**

- Host-authoritative 1 vs 1 deathmatch over ENet, with interpolation on clients.
- UDP host discovery, manual address entry, version check, forfeits and rematch.
- Fixed: a crash from replacing the network peer inside its own disconnect callback.
- Fixed: a screen change requested during a fade was dropped, stranding a player whose match had started.

**Menus and screens (M5)**

- All 11 screens, fades, saved settings, music, pause, aim assist and the Sky Ace skin.
- Android back gesture and pausing when the app goes to the background.

**Campaign (M4)**

- Outpost, Canyon and Skyforge maps, 10 levels and all mission types.
- Atomic, tamper-checked saves that recover from damage.
- Fixed: bots could start right beside the player, and a Canyon spawn point sat inside the arch.

**Bots (M3)**

- Patrol, Chase, Attack and Retreat, with four difficulty levels and A* navigation built for jetpack flight.
- Fixed: bots looped forever trying to reach high platforms on too little fuel.
- Fixed: a crash when a grenade or rocket outlived its owner.

**Combat (M2)**

- Five weapons, grenades, melee, splash damage, health, crates, respawns and the HUD.
- Screen shake, shader flashes, damage numbers, particles, parallax and sound for every action.

**Movement (M1)**

- Jetpack fighter with fuel and crouch, keyboard and multi-touch controls, and an aim-leading camera.

**Setup (M0)**

- Godot project, shared theme, GUT tests and the test script.
