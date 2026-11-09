# Playtest kit

Run 2 rounds, in Week 3 and Week 4, with at least 5 classmates who did not build the game. Each tester plays Levels 1–3 and one multiplayer match, then fills in the form.

## Tester form

Copy this for each tester.

**Tester:** ________ **Round:** 1 / 2 **Date:** ________

| # | Question | Answer |
| --- | --- | --- |
| 1 | How easy were the controls to learn? | 1  2  3  4  5 (1 = very hard, 5 = very easy) |
| 2 | Was any level too hard or too easy? Which? | Level: ____ Too hard / Too easy. Comment: |
| 3 | Did you understand what to do to clear each level? | Yes / No. Comment: |
| 4 | Did the multiplayer match lag or disconnect? | Yes / No. Comment: |
| 5 | How fun was the game overall? | 1  2  3  4  5 (1 = not fun, 5 = very fun) |
| 6 | The one thing you would change | |

## Observer sheet

Watch silently. Do not help unless the tester is completely stuck, and note it if you do.

**Tester:** ________ **Round:** 1 / 2 **Phone model:** ________

| Level | Deaths | Time to clear | Cleared? |
| --- | --- | --- | --- |
| 1 | | | |
| 2 | | | |
| 3 | | | |

| Multiplayer | Result |
| --- | --- |
| Mode (LAN or online) | |
| Lag or disconnects seen | |

| Bugs and moments of confusion | Where it happened |
| --- | --- |
| | |

The debug overlay shows FPS and ping. Open it with a three-finger tap.

## Round summary

Complete one per round.

**Round:** ____ **Testers:** ____ **Date:** ________

| Measure | Result |
| --- | --- |
| Average controls score (Q1) | |
| Average fun score (Q5) | |
| Level 1 clear rate | __ / __ |
| Level 2 clear rate | __ / __ |
| Level 3 clear rate | __ / __ |
| Testers who understood the objectives (Q3) | __ / __ |
| Matches with lag or disconnects (Q4) | __ / __ |

**Top 5 issues**

| # | Issue | Evidence | How many testers |
| --- | --- | --- | --- |
| 1 | | | |
| 2 | | | |
| 3 | | | |
| 4 | | | |
| 5 | | | |

After each round, log every change in the playtest table in [CHANGELOG.md](CHANGELOG.md), with the evidence that it worked.

## Where to make changes

Most fixes need only a data edit, with no code changes.

| To change | Edit |
| --- | --- |
| Movement, jetpack, health, camera, stick sizes | `data/tuning.json` |
| Weapon damage, ammo, reload, spread | `data/weapons.json` |
| Level targets, bot counts, time limits | `data/levels.json` |
| Bot HP, aim error, reaction time | `data/difficulty.json` |
| Map layouts | `data/maps/*.json` |

Tests compare some of these values with the design. If a test fails after a deliberate change, update `docs/DESIGN.md` and that test together.
