# Matchmaking rounds: grader brief (shared by the 3 graders)

The task: make every matchmaking screen of our Roblox game (Tacticals) look, sit and feel like RIVALS. That covers the queue
from the lobby through the match to the results. Our theme colours (tan / green team fills, bone health bar, dark plates) are a
deliberate choice. Judge layout, proportions, position, typography, readability, icon placement, hierarchy, missing
elements, motion and finish, not the palette. Ignore RIVALS' seasonal Halloween colours. Scissors is our currency.

## Our captures (this round)
`C:\Users\aroki\Documents\tacticals_rebuild\notes\ui_rivals\mm\<round>_<screen>.png`, 1268x785 Studio viewport (16:10-ish,
full bleed). Some shots carry Studio artefacts: the bot is an empty placeholder, the map is a grey test map, and "Test match:
no rewards" shows. Don't grade those.

| Screen | What it is |
|---|---|
| playmenu | lobby Play menu (mode tiles) |
| searching | the queue pill at the top centre |
| found | "Match found" card before the teleport |
| vote | map vote |
| loadout | loadout pick (the timer, map name, slots, weapon choices) |
| countdown | round 1 pre-round |
| live | HUD mid-round |
| kill | you eliminated the enemy (round won card + MATCH POINT ribbon) |
| death / death2 | you died (killer card / kill-cam, 0.0 s and 2.5 s after) |
| victory | the match-won screen |
| results | the after-match screen with buttons |

Previous rounds' captures and grades sit in the same folder (`<round>_grade_<L>.md`), so check whether last round's fixes landed.
`m0_sheet.jpg` / `m0_lobby.jpg` are contact sheets.

## RIVALS references (all under `C:\Users\aroki\Documents\tacticals_rebuild\notes\`)
- `ui_rivals\killcard\f\tNNNN.jpg`: Edward's live RIVALS games, 1600x900, one frame every 2 s. Contact sheets are
  `ui_rivals\killcard\sheet00.jpg`, `sheet01.jpg` and `sheet02.jpg`. Sheet00 timeline:
  - t0016 Play menu; t0018 searching pill (top left in that version); t0020 teleporting
  - t0022-t0024 loading; t0026-t0030 map vote (grid of map tiles + Random); t0032 map chosen
  - t0034-t0038 loadout (Map: Arena, slot squares, weapon choices); t0040+ live HUD
  - t0054 elimination ("Eliminated X"); t0056 ROUND WON card; t0058 Switch Weapons
  - later frames: deaths, kill-cam, match end and results. Browse `sheet01` / `sheet02` to find them.
- `ui_rivals\killcard\key\`: picked key frames. `ref_rivals_rounds\`: round won / lost, killer card, kill-cam, death vignette,
  intermission switch. `match_ui_r1\`: hit vignette, killer card, round won, streak icons, switch weapons.
- `rivals_rec\tNNNN.Ns.jpg`: a live menu recording, 1280x720. Spectate controls are around t0113-t0119.
- `ref_rivals_ranked\`: Play menu and ranked screens.
- Earlier written audit: `ui_rivals\05_match_hud_results.md`, `ui_rivals\rivals_live_notes.md`.

Code (read-only, for the feel lens): `ui\match\DuelHUD.client.lua` (HUD, round card, ribbons, killer card, results),
`ui\match\MatchFlowUI.client.lua` (vote, loadout), `ui\hud\LobbyHudController.lua` (searching pill), `ui\play\PlayScreen.lua`,
`ui\hud\MatchFoundGate.lua`.

## Report format
Write your report to `mm\<round>_grade_<LETTER>.md`, under 500 words.

Per screen:
- a score out of 10 for closeness to RIVALS on your lens;
- at most 3 fixes, each concrete: element, current → target, in design px (1920x1080 canvas) or ratios, citing the RIVALS frame
  you used.

Skip screens with nothing to fix in one line. Then rank the top 8 fixes across screens by visible impact.

Rules:
- If a change from last round moved us away from RIVALS, say so first.
- Only list what you can see (or, for feel, what the code does). Say "can't judge" when a crop is too small.
- Don't edit any files other than your report.
