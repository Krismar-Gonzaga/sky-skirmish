# Progress

## Milestones

| Milestone | Status |
| --- | --- |
| M0 Setup and skeleton | Done, awaiting review |
| M1 Player movement | Not started |
| M2 Combat | Not started |
| M3 Bots | Not started |
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

## Open design questions

`docs/DESIGN.md` is an unedited copy of the design until these are agreed.

### Waiting on the team

- A. Crate contents. Proposed: campaign crates drop only unlocked weapons; multiplayer crates drop all weapons.
- B. "Offline practice" (section 3) has no screen in section 8. Proposed: campaign replay counts as practice.
- C. Node version. Node 20 reached end-of-life in April 2026. Proposed: target Node 24 LTS, keep code compatible with 20.
- D. Choosing the "Sky Ace" skin. Proposed: a toggle in Settings, shown once earned.

### Proposed defaults, applied unless the team objects

Master prompt overrides the design:

1. Sixth autoload, `Settings`.
2. Custom `RelayMultiplayerPeer` replaces `WebSocketMultiplayerPeer`.
3. Add `data/difficulty.json` and `data/tuning.json`.
4. Thin `Bot extends Player` that attaches `BotBrain`.

Contradictions inside the design:

5. Survive levels: timer expiry is a win, and the 3-star time condition counts as met.
6. Levels with no time limit: the 3-star time condition counts as met.
7. Level 6 "max 2 deaths" stays as a `max_deaths` field; it matches the 3-lives rule today.
8. Respawn at the spawn point farthest from the opponent, or the nearest bot in the campaign, after 3 s.
9. Forfeit: the survivor sees Match Results and returns to the lobby. The dropped phone sees "Connection lost" and returns to the Multiplayer screen.
10. Fail shows Level Results with Retry.
11. The section 7 save sample shows the shotgun too early; it is only an example.
12. `unlocked_level` is clamped to the number of levels.
13. Relay rooms gain a `last_activity` field for idle cleanup.
14. T7's 10 s is measured with the relay already awake.

Missing from the design:

15. Reload times, reserve ammo, projectile speed, range, spread, melee range and cooldown, throw speed, splash falloff (linear), rocket self-damage and crouch numbers: chosen in the JSON data and marked tunable.
16. Fire gesture: below 70% aims only; past 70% auto-fires; a quick flick and release fires one shot.
17. `bot_count` is the number alive at once. Bots respawn after 3 s, except in gauntlet waves. Level 8 escorts respawn.
18. Capture time is cumulative and pauses while the zone is empty or contested.
19. A tie at 5:00 is a draw and changes neither win nor loss stats.
20. Save v1 adds `hash`, `unlocked_skins` and `selected_skin`.
21. Bots regenerate health with the same `Player` code.
22. The 4-player stretch goal is not planned. Handout pages 2–39 were not available, so rubric rows may be missing.

## Known issues

- JDK 17 is missing. To be checked at M8; the default (non-Gradle) export may work with JDK 21.
- `icon.svg` is still the Godot default. Replaced in M8.

## Next steps

Review M0, answer questions A–D, then start M1.
