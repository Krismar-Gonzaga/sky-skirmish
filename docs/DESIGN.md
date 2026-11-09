# Sky Skirmish — Game Development Documentation

Nov 9, 2026 · @Krismar Gonzaga

## 1. Project overview

Sky Skirmish is a 2D side-view jetpack shooter for Android. It is inspired by Mini Militia: players fly with a jetpack, aim with a second thumb stick and fight on multi-level maps. The player clears campaign levels against bots to unlock the next one, and can fight another player offline over local Wi-Fi/hotspot or online over the internet.

The game uses its own name, characters, maps and art. It reuses the genre and mechanics only, with no Mini Militia names, logos or assets.

| Item | Decision |
| --- | --- |
| Course | ITSD 85 – Special Topics in Software Development (Laboratory 5) |
| Genre | 2D side-scrolling multiplayer shooter with jetpack movement |
| Target platform | Android 8.0+ (API 26), phone, landscape only |
| Engine | Godot 4.x (MIT licence, free) with GDScript |
| Team | 2–3 students: Gameplay dev, Network dev, UI/Art + QA |
| Duration | 5 weeks (about 3 h lab + 3 h outside work per week) |
| Budget | ₱0 – free and open-source tools and free-tier hosting only |

**Game goal (for the GDD):** Clear all 10 campaign levels by completing each mission, earning up to 3 stars per level. In multiplayer, be the first to reach the kill limit, or have the most kills when the timer runs out.

**Core rules (for the GDD):**

- Each fighter has 100 HP and a jetpack fuel bar that refills while standing on the ground.
- A fighter that reaches 0 HP respawns after 3 seconds at the spawn point farthest from the opponent (in the campaign, farthest from the nearest bot).
- Weapons are picked up from the map; each has limited ammo and a reload time.
- In the campaign, failing the mission (dying with no lives left, or the timer running out on a non-survive level) shows Level Results with Retry.
- Clearing a level saves progress and unlocks the next level.

## 2. Requirements traceability

Every Laboratory 5 requirement maps to a feature and a section of this document. Only page 1 of the 39-page handout was available, so add any rows from pages 2–39 (rubric, weekly deliverables) before Week 1 approval.

| Lab requirement | How Sky Skirmish meets it | Section |
| --- | --- | --- |
| Own mobile game for Android or iOS | Android build (APK/AAB) made with Godot 4 | 1, 6 |
| Player must clear a level to unlock the next one | 10-level campaign; level N+1 unlocks only after level N is cleared; progress saved on device | 4, 7 |
| Playable offline against another player | LAN/hotspot match: one phone hosts, the other joins by scanning or typing the host IP; no internet needed | 5 |
| Playable online against another player | Internet match through a free relay/lobby server using a 6-character room code | 5 |
| Improve the game from structured playtest feedback | Two playtest rounds with a fixed feedback form; changes logged in a change log | 9 |
| One-page Game Design Document (GDD): goal, rules, … | Goal and rules from Section 1, controls and levels from Sections 3–4, condensed to one page | 1, 3, 4 |
| Game idea approved by the instructor in Week 1 | This concept plus the GDD is the Week 1 pitch | 9 |
| Teams of 2–3 students | Roles: Gameplay dev, Network dev, UI/Art + QA | 1, 9 |
| ₱0 cost, free and open-source tools only | Godot (MIT), GDScript, Krita/LibreSprite, CC0 art and sound, free-tier server hosting | 6 |
| 5-week duration | Weekly milestone plan | 9 |

## 3. Core gameplay design

The core loop is: fly, find a weapon, aim and shoot, survive, repeat. Everything runs on two virtual thumb sticks so the game plays with two thumbs in landscape.

### Controls

| Input | Action |
| --- | --- |
| Left stick, left/right | Walk |
| Left stick, pushed up | Jetpack thrust (uses fuel) |
| Left stick, pushed down | Crouch (smaller hitbox, better aim) |
| Right stick, any direction | Aim; releasing past 70% of the radius fires (or hold to auto-fire) |
| Grenade button | Throw grenade in the aim direction (3 per life) |
| Swap button | Switch between the 2 carried weapons |
| Melee button | Short-range punch, 25 damage |
| Pause button | Pause (campaign) or open menu (multiplayer) |

### Movement and physics

- The fighter is a CharacterBody2D with gravity of 980 px/s² and a walk speed of 220 px/s.
- The jetpack adds 1,400 px/s² of upward force while held, capped at 360 px/s upward.
- Fuel: 100 units, drains 35/s while flying, refills 50/s on the ground after a 0.5 s delay.
- Maps are built with TileMap layers: solid ground, one-way platforms, and background decoration.

### Weapons

All values are starting points to tune after playtesting.

| Weapon | Damage per hit | Fire rate (shots/s) | Magazine | Notes |
| --- | --- | --- | --- | --- |
| Pistol (default) | 15 | 4 | 12 | Infinite reserve ammo |
| Assault rifle | 12 | 10 | 30 | Small spread |
| Shotgun | 8 × 6 pellets | 1.2 | 6 | Short range |
| Sniper | 70 | 0.8 | 5 | Long range, zoom on aim |
| Rocket launcher | 60 (splash) | 0.6 | 2 | Splash radius 96 px, self-damage |
| Frag grenade | 80 (splash) | – | 3 per life | 2.5 s fuse, bounces |

### Health and pickups

- 100 HP; health regenerates 5 HP/s after 5 s without taking damage.
- Weapon crates respawn every 20 s; a health pack restores 50 HP.

### Bots (campaign and offline practice)

Bots use a simple state machine: Patrol → Chase → Attack → Retreat (retreat when HP < 30%). Difficulty changes aim error, reaction time and HP, so the same AI scales across all 10 levels.

### Art and audio

Original characters drawn in Krita or LibreSprite, plus CC0 packs (e.g. Kenney.nl) for tiles, effects and sounds. Credit every asset in an in-game Credits screen.

## 4. Level progression system

The campaign has 10 levels across 3 maps. Only Level 1 is unlocked at first install, and Level N+1 unlocks the moment Level N is cleared with at least 1 star.

### Level list

| Level | Map | Mission | Bots (difficulty) | Time limit | Unlock reward |
| --- | --- | --- | --- | --- | --- |
| 1 | Outpost | Tutorial: move, fly, shoot 3 target dummies | 0 | none | – |
| 2 | Outpost | Eliminate 5 bots | 2 (Easy) | 3:00 | Assault rifle |
| 3 | Outpost | Survive 90 s | 4 (Easy) | 1:30 | – |
| 4 | Canyon | Eliminate 8 bots | 3 (Normal) | 3:00 | Shotgun |
| 5 | Canyon | Capture the flag zone for 30 s | 3 (Normal) | 2:30 | Canyon map in multiplayer |
| 6 | Canyon | Eliminate 10 bots, max 2 deaths | 4 (Normal) | 3:30 | Sniper |
| 7 | Skyforge | Survive 120 s | 6 (Hard) | 2:00 | – |
| 8 | Skyforge | Eliminate the bot leader (300 HP) | 3 + leader (Hard) | 3:00 | Rocket launcher |
| 9 | Skyforge | Eliminate 15 bots | 5 (Hard) | 4:00 | Skyforge map in multiplayer |
| 10 | All 3 (gauntlet) | Clear one wave on each map | 4 per wave (Expert) | 6:00 | "Sky Ace" skin |

### Clear, fail and star rules

- Clear: complete the mission objective. The game awards 1 star.
- 2 stars: clear with 1 death or fewer. 3 stars: clear with 0 deaths and more than 25% of the time left. On survive levels and levels with no time limit, the time condition counts as met.
- Fail: time runs out (except on survive levels, where the timer running out is the win), or the player loses all 3 lives. Level Results offers Retry; nothing is unlocked.
- Replaying a cleared level keeps the best star count.

### Difficulty curve

| Difficulty | Bot HP | Aim error | Reaction time |
| --- | --- | --- | --- |
| Easy | 60 | ±15° | 0.8 s |
| Normal | 80 | ±10° | 0.5 s |
| Hard | 100 | ±6° | 0.35 s |
| Expert | 100 | ±3° | 0.25 s |

### How unlocking works in code

1. LevelManager loads levels.json (the table above as data) at start-up.
2. On mission success, GameState calls ProgressService.complete_level(id, stars, time).
3. ProgressService saves the best stars and sets unlocked_level = max(unlocked_level, min(id + 1, level_count)).
4. The Level Select screen draws a lock icon on every level whose id is greater than unlocked_level. Tapping a locked level shows "Clear Level N first."

## 5. Multiplayer (offline and online)

Both modes share one networking layer: Godot's high-level multiplayer API (MultiplayerSpawner, MultiplayerSynchronizer, RPCs). Only the transport changes, so gameplay code is written once. The host phone is the authority: it runs physics, hit detection and scoring, and clients send only their inputs.

| | Offline (local) | Online (internet) |
| --- | --- | --- |
| Connection | Same Wi-Fi or one phone's mobile hotspot | Any internet (Wi-Fi or mobile data) |
| Transport | ENetMultiplayerPeer (UDP), port 7777 | RelayMultiplayerPeer (custom MultiplayerPeerExtension over WebSocketPeer) through a relay server |
| Finding a match | Host taps Host LAN; joiner sees it via UDP broadcast on port 7778, or types the host IP | Host taps Create Room and gets a 6-character code; joiner types the code |
| Who is authority | Host phone | Host phone (the relay only forwards packets) |
| Players | 2 (stretch: up to 4) | 2 (stretch: up to 4) |
| Needs a server | No | Yes, free-tier relay (Section 6) |

### Match rules (both modes)

- Deathmatch, 1 vs 1. First to 10 kills, or most kills after 5:00, wins. A tie at 5:00 is a draw and changes neither win nor loss stats.
- Map choice: Outpost always; Canyon and Skyforge once unlocked in the campaign on the host phone.
- Respawn after 3 s at the spawn point farthest from the opponent.

### What is synchronised

| Data | Direction | Rate |
| --- | --- | --- |
| Joystick input, aim angle, button presses | Client → host | Every physics frame (60 Hz) |
| Player positions, velocity, HP, fuel, current weapon | Host → clients | 20 Hz, interpolated on clients |
| Shots, explosions, pickups, kills | Host → clients | As events (reliable RPC) |
| Score and match timer | Host → clients | 1 Hz and on change |

### Connection handling

- A join attempt times out after 10 s with the message "Could not reach host."
- If a player disconnects mid-match, the other player wins by forfeit, sees Match Results and returns to the lobby. The disconnected phone shows "Connection lost" and returns to the Multiplayer screen.
- Both phones must run the same game version. The host sends its version on connect and rejects a mismatch.

## 6. Technical architecture

The game is one Godot 4 project exported to Android. A tiny Node.js relay is the only server, and it is needed only for online matches.

The campaign never touches the network. Offline matches link two phones directly, and online matches pass through the relay.

### Tools (all ₱0)

| Need | Tool | Licence / cost |
| --- | --- | --- |
| Game engine and editor | Godot 4.x (GDScript) | MIT, free |
| Android export | Android SDK + OpenJDK 17, Godot export templates | Free |
| Pixel art and sprites | Krita or LibreSprite | GPL, free |
| Sound effects | Audacity, jsfxr; CC0 packs from Kenney.nl / OpenGameArt | Free / CC0 |
| Relay server | Node.js + ws library | MIT, free |
| Server hosting | Render, Fly.io or Oracle Cloud free tier | Free tier |
| Version control | Git + GitHub (private repo) | Free |
| Task board | GitHub Projects | Free |

### Project structure

```
sky-skirmish/
  project.godot
  autoload/      GameState.gd, LevelManager.gd, ProgressService.gd,
                 NetworkManager.gd, AudioManager.gd, Settings.gd
  scenes/
    ui/          Splash, MainMenu, LevelSelect, MultiplayerMenu, LanLobby,
                 OnlineLobby, HUD, LevelResults, MatchResults, Settings, Credits
    game/        Match.tscn, Player.tscn, Bot.tscn, Projectile.tscn
    maps/        Outpost.tscn, Canyon.tscn, Skyforge.tscn
  scripts/
    core/        Tuning.gd, DataFile.gd, AssetMap.gd
    input/       PlayerInput.gd, InputProvider.gd and its implementations
    player/      Player.gd, PlayerMotor.gd, FuelTank.gd, PlayerVisual.gd
    game/        Arena.gd, GameMap.gd, AimCamera.gd, CombatEffects.gd, Pickup.gd
    ui/          Hud.gd, VirtualStick.gd, TouchActionButton.gd, TouchControls.gd
    weapons/     Weapon.gd (base), Pistol.gd, Rifle.gd, Loadout.gd, Projectile.gd, ...
    net/         NetFighter.gd, DeathmatchRules.gd, NetEventRelay.gd, LanBroadcaster.gd, ...
    bots/        Bot.gd, BotBrain.gd, BotDecision.gd, JetNavGraph.gd, PathFollower.gd
    missions/    Mission.gd (base), Eliminate, Survive, Capture, Boss, Gauntlet, Tutorial
  data/          tuning.json, levels.json, weapons.json, difficulty.json, maps/
  assets/        asset_map.json, theme/, sprites/, tiles/, audio/, fonts/
  server/        relay.js, package.json
  tests/         GUT unit and integration tests
  tools/         run_tests.sh, run_local_mp.sh, export_android.sh
```

### Key classes

| Class | Responsibility |
| --- | --- |
| Player (CharacterBody2D) | Movement, jetpack, health, holds 2 weapons; reads input locally or from the network |
| Weapon (base class) | Fire rate, ammo, reload, spawns Projectile; subclasses set stats from weapons.json |
| Bot (extends Player) | A Player with a BotBrain attached; BotBrain is the AI state machine that writes the same input struct a human produces |
| Arena | Turns shots into projectiles, applies damage, handles pickups and respawns, reports every event as a signal |
| Match | Spawns players, tracks score and timer, decides win/lose, emits match_ended |
| LevelManager | Loads levels.json, builds the mission for a level, checks the objective |
| ProgressService | Reads and writes save.json, unlocks levels, weapons and maps |
| NetworkManager | Hosts or joins (ENet or relay), room codes, version check, disconnects |
| Settings | Live player preferences; ProgressService persists them |

Because Bot produces the same input struct as a human, the same Player code serves the campaign, local multiplayer and online multiplayer.

## 7. Data and persistence

All player progress is stored on the phone, so the campaign works with no internet. The relay server stores nothing permanent; rooms live only in memory.

### Save file: user://save.json

```json
{
  "version": 1,
  "player_name": "Kris",
  "unlocked_level": 4,
  "levels": {
    "1": {"stars": 3, "best_time": 41.2},
    "2": {"stars": 2, "best_time": 132.5},
    "3": {"stars": 1, "best_time": 90.0}
  },
  "unlocked_weapons": ["pistol", "rifle"],
  "unlocked_maps": ["outpost"],
  "unlocked_skins": [],
  "selected_skin": "",
  "stats": {"mp_wins": 5, "mp_losses": 3, "total_kills": 211},
  "settings": {"music": 0.7, "sfx": 0.9, "aim_assist": true, "stick_size": 1.0},
  "hash": "<salted SHA-256 of the other fields>"
}
```

- ProgressService writes the file after every level clear, multiplayer match and settings change. It writes to save.tmp first, then renames, so a crash cannot corrupt the save.
- The version field allows the save format to change later without losing progress.
- The game hashes the file (SHA-256 plus a salt) to detect casual hand-editing; a bad hash resets to Level 1 after a warning.

### Level data: res://data/levels.json

One entry per level with id, map, mission_type, target, bot_count, difficulty, time_limit and reward. Designers add or tune levels by editing this file, not code.

### Relay server room (in memory only)

| Field | Example | Purpose |
| --- | --- | --- |
| code | K7Q2PX | Room code players type |
| host_socket | connection id | Host phone |
| guest_socket | connection id | Joining phone |
| game_version | 1.0.3 | Reject mismatched versions |
| created_at | timestamp | Diagnostics |
| last_activity | timestamp | Delete rooms idle for 10 minutes |

## 8. UI/UX screens and flow

The game has 11 screens, all reachable from the Main Menu in at most 2 taps. Level Results is the only screen that unlocks progress.

From Level Results, a clear returns to Level Select with the next level unlocked, and a fail goes back into the same level.

| Screen | What it shows | Main actions |
| --- | --- | --- |
| Splash | Logo, loading bar (loads save file) | – |
| Main Menu | Title art, player name | Campaign, Multiplayer, Settings, Credits |
| Level Select | 10 level cards with stars; locked cards greyed with a lock icon | Play an unlocked level |
| Campaign match / 1 vs 1 match | HUD: HP bar, fuel bar, ammo, grenades, timer, objective or score, two sticks, buttons | Play, Pause |
| Level Results | Clear/Fail, stars earned, time, "Level N+1 unlocked!" banner | Next, Retry, Level Select |
| Multiplayer | Two big buttons: Local (Wi-Fi/Hotspot) and Online | Choose mode |
| LAN lobby | Host: own IP + waiting list. Join: list of found hosts + manual IP field | Host, Join, Start |
| Online lobby | Create Room (shows 6-character code) or Join Room (code field), connection status | Create, Join, Start |
| Match results | Winner, kills/deaths per player | Rematch, Leave |
| Settings | Music and SFX volume, stick size, aim assist, player name | Save |
| Credits | Team names and every CC0/third-party asset credit | Back |

### Mobile UX rules

- Landscape only; touch targets at least 48 dp; sticks sized with a Settings slider.
- HUD stays in the screen corners so the action in the centre stays visible.
- The game pauses and saves when the app goes to the background (NOTIFICATION_APPLICATION_PAUSED).

## 9. Development plan, testing and deliverables

The team builds the offline game first and adds online play in Week 4. That way a working, gradable game exists even if the server work runs late.

Each week ends with a tagged Git release (v0.1 to v1.0) and an APK installed on at least 2 real phones.

### Team roles

| Role | Owns |
| --- | --- |
| Gameplay dev | Player, weapons, bots, levels, LevelManager, ProgressService |
| Network dev | NetworkManager, LAN discovery, relay server, sync and disconnect handling |
| UI/Art + QA | Screens, HUD, sprites, audio, test cases, playtest sessions and change log |

### Functional test cases

| ID | Test | Expected result |
| --- | --- | --- |
| T1 | Fresh install, open Level Select | Only Level 1 unlocked |
| T2 | Clear Level 1 | Level 2 unlocks; stars saved |
| T3 | Fail Level 2 (time runs out) | Level 3 stays locked; retry offered |
| T4 | Close and reopen the app after clearing Level 3 | Levels 1–4 unlocked, stars kept |
| T5 | Tap a locked level | "Clear Level N first" message; level does not start |
| T6 | Host LAN on phone A, join from phone B on the same hotspot, no internet | Match starts; both see each other move |
| T7 | Create online room, join with the code on mobile data (relay already awake) | Match starts within 10 s |
| T8 | Join with a wrong room code | "Room not found" message |
| T9 | Turn off Wi-Fi on one phone mid-match | Other player wins by forfeit and returns to the lobby; the dropped phone shows "Connection lost" and returns to the Multiplayer screen |
| T10 | Different game versions try to connect | Connection rejected with "Update required" |

### Structured playtests

Run 2 rounds (Week 3 and Week 4) with at least 5 classmates who did not build the game. Each tester plays Levels 1–3 and one multiplayer match, then fills in this form:

| Question | Answer type |
| --- | --- |
| How easy were the controls to learn? | 1–5 scale |
| Was any level too hard or too easy? Which? | Level number + comment |
| Did you understand what to do to clear each level? | Yes / No + comment |
| Did the multiplayer match lag or disconnect? | Yes / No + comment |
| How fun was the game overall? | 1–5 scale |
| The one thing you would change | Free text |

The team also observes silently and records deaths per level, time to clear, and every bug. After each round, list the top 5 issues and log each change: issue → change made → evidence it worked (for example, "Level 3 clear rate 2/5 → 4/5").

### Submission checklist

- [ ] One-page Game Design Document (goal, rules, controls, levels, multiplayer modes)
- [ ] Signed Android APK, installable on Android 8.0+
- [ ] Source code in the Git repository, including server/relay.js
- [ ] This technical documentation
- [ ] Test case results (T1–T10) with pass/fail
- [ ] Playtest forms, summary of findings and change log for both rounds
- [ ] Demo video (2–3 min): level unlock, offline LAN match, online match
- [ ] Credits list for all CC0/third-party assets

## 10. Agreed clarifications

These fill gaps in the sections above.

### Combat and controls

- Reload times, reserve ammo, projectile speed, range, spread, melee range and cooldown, grenade throw speed, rocket self-damage and crouch numbers are starting values in `data/weapons.json` and `data/tuning.json`. Splash damage falls off linearly with distance.
- Right stick: below 70% of the radius it aims only. Past 70% it auto-fires. A quick flick and release fires one shot.
- Jetpack fuel does not refill while the jet control is held, which prevents stutter-hopping on an empty tank.
- Bots regenerate health with the same Player code as humans.
- Bullets and rockets pass through one-way platforms. Grenades bounce off them, and fighters stand on them.
- Weapon pickups: a weapon already held gains a magazine. A new weapon takes the free slot, or replaces the weapon in hand. It is selected at once.
- A weapon with no ammo left is dropped. A fighter who loses both weapons gets the pistol back.
- The frag grenade's splash radius is 120 px, because Section 3 gives only the rocket's.

### Missions

- `bot_count` is the number of bots alive at once. Bots respawn after 3 s, except in gauntlet waves. The Level 8 escorts respawn.
- Level 6's "max 2 deaths" is a `max_deaths` field. It matches the 3-lives rule today and can be tuned separately.
- Capture time is cumulative and pauses while the zone is empty or contested.
- Progress is saved the moment a level is cleared, so closing the app on Level Results loses nothing. Level Results announces the unlock.
- Bots start at the spawn points farthest from the player. Tutorial dummies use the nearest.

### Progress and modes

- Campaign crates drop only unlocked weapons. Multiplayer crates drop all weapons, so a fresh host still gets a real match.
- Replaying campaign levels serves as the "offline practice" against bots from Section 3. There is no separate practice screen.
- The "Sky Ace" skin is a toggle in Settings, shown once earned.

### Multiplayer

- Dying to your own rocket or grenade counts as a death but awards no kill.
- Each side of a broken connection only sees the other vanish. The phone that still has a network address wins by forfeit; the one without shows "Connection lost".
- A rematch starts when both players vote for it.
- Leaving a match from the menu forfeits it and counts as a loss.
- The menu in a 1 vs 1 match does not pause the game, because the other player's game cannot be frozen.

### Bots

- Navigation is a directed A* graph over map tiles. A bot can fly up through a one-way platform but must walk off its edge to go down, matching the player's rules.
- Bots fire only after their difficulty's reaction time has passed since they spotted a target.

### Scope

- The relay targets Node 24 LTS, because Node 20 reached end-of-life in April 2026. Its code stays compatible with Node 20.
- The 4-player stretch goal is not planned.
- Pages 2–39 of the lab handout were not available, so rubric rows may be missing from Section 2.
