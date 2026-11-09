# Sky Skirmish: Game Design Document

ITSD 85, Laboratory 5 · Android 8.0+ · Godot 4 · 2D side-view multiplayer shooter

**Goal.** Clear all 10 campaign levels, earning up to 3 stars each. In multiplayer, reach 10 kills first, or have the most kills after 5:00.

**Rules**

- A fighter has 100 HP, regenerating 5 HP/s after 5 s without damage.
- The jetpack burns fuel while flying and refills on the ground.
- Fighters carry 2 weapons and 3 grenades per life. Weapons come from crates; health packs restore 50 HP.
- In the campaign you have 3 lives. Losing them all fails the level, as does the timer running out, except on survive levels, where outlasting the timer is the win.
- Clearing a level saves progress and unlocks the next. 1 star for a clear, 2 for at most 1 death, 3 for no deaths and more than 25% of the time left.
- In multiplayer, a defeated fighter returns after 3 s at the spawn farthest from the opponent.

**Controls**

| Input | Action |
| --- | --- |
| Left stick | Walk; up for jetpack; down to crouch |
| Right stick | Aim; past 70% fires |
| Grenade, Swap, Melee buttons | Throw, switch weapon, punch for 25 damage |
| Pause button | Pause (campaign) or open the menu (multiplayer) |

**Weapons**

| Weapon | Damage | Shots/s | Magazine | Trait |
| --- | --- | --- | --- | --- |
| Pistol | 15 | 4 | 12 | Infinite reserve |
| Assault rifle | 12 | 10 | 30 | Small spread |
| Shotgun | 8 × 6 | 1.2 | 6 | Short range |
| Sniper | 70 | 0.8 | 5 | Long range, zoom |
| Rocket launcher | 60 splash | 0.6 | 2 | Can hurt you |
| Frag grenade | 80 splash | – | 3 per life | 2.5 s fuse, bounces |

**Levels**

| # | Map | Mission | Bots | Time | Unlocks |
| --- | --- | --- | --- | --- | --- |
| 1 | Outpost | Tutorial, 3 dummies | – | – | – |
| 2 | Outpost | Eliminate 5 | 2 Easy | 3:00 | Assault rifle |
| 3 | Outpost | Survive 90 s | 4 Easy | 1:30 | – |
| 4 | Canyon | Eliminate 8 | 3 Normal | 3:00 | Shotgun |
| 5 | Canyon | Hold zone 30 s | 3 Normal | 2:30 | Canyon in multiplayer |
| 6 | Canyon | Eliminate 10, max 2 deaths | 4 Normal | 3:30 | Sniper |
| 7 | Skyforge | Survive 120 s | 6 Hard | 2:00 | – |
| 8 | Skyforge | Defeat 300 HP leader | 3 + leader Hard | 3:00 | Rocket launcher |
| 9 | Skyforge | Eliminate 15 | 5 Hard | 4:00 | Skyforge in multiplayer |
| 10 | All 3 | One wave per map | 4 per wave Expert | 6:00 | "Sky Ace" skin |

**Multiplayer: 1 vs 1 deathmatch.** The host phone runs the game; the other sends its input.

- **Offline:** same Wi-Fi or a phone's hotspot, no internet. Join from a list of found hosts or by typing the host's address.
- **Online:** one player creates a room and shares its 6-character code; the other types it. A free relay server forwards the traffic.
- If a player disconnects, the other wins by forfeit. Both phones must run the same version.
