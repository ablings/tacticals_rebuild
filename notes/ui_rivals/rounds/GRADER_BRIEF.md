# Section rounds: grader brief (shared by the 3 graders)

The task: make each lobby UI section of our Roblox game (Tacticals) look and feel like RIVALS. Our theme colours (purple
backdrop, tan / green team fills, bone health bar) are a deliberate choice. Judge layout, proportions, typography,
readability, icon placement, spacing, hierarchy, missing elements and finish, not the palette. Ignore RIVALS' seasonal
Halloween colours. Scissors is our currency; RIVALS uses keys.

## References = RIVALS' original UI (Edward)
Use the official RIVALS game and the RIVALS copies Edward pointed to (Kuroko's Rivals MODDED, the copies in `rivals_normal`
and `kuroko169`). They run RIVALS' original UI, so treat their layout, type and components as RIVALS. Ignore only what a
mod adds itself: the "Modded Shop" title, prices that all read "Free", the AIMBOT (OP) tile, extra tabs. Don't skip whole frames.

## Our captures (this round)
`C:\Users\aroki\Documents\tacticals_rebuild\notes\ui_rivals\rounds\<round>_<section>.png`, 1268x785. The 16:9 frame is centred
with 36 px bands at the top and bottom. The design canvas is 1920x1080. Sections: hub, play, kit, missions, shop, codes,
settings. The previous round's captures and grades are in the same folder, so check whether last round's fixes landed.

## RIVALS references (all under `C:\Users\aroki\Documents\tacticals_rebuild\notes\`)
- `ui_rivals\rivals_normal\`: play.png, weapons.png, tasks.png, shop.png, settings.png, profile_card.png, news_panel.png
  (1920x1010 captures; a chat window covers the right side).
- `ui_rivals\night1\kuroko169\`: kit.jpg, shop.jpg, settings.jpg, rv_tasks_live.jpg, rv_playermenu.jpg, rv_profile_streak.jpg,
  hub_prompt.jpg.
- `rivals_rec\tNNNN.Ns.jpg`: Edward's live RIVALS menu recording, 1280x720. Timeline in seconds:

  | Seconds | Screen |
  |---|---|
  | 0-15 | Backpack |
  | 50-60 | Weapons / Kit |
  | 65-100 | Shop (home, bundles, keys ~84, passes) |
  | 85-100 | Tasks / free rewards |
  | 95-105 | login rewards |
  | ~135 | Settings |
  | 150-165 | player list |
  | 170-300 | lobby / hub |
  | ~285 | Ranked / Play |

  Browse the neighbouring seconds to find the best frame.
- `ui_rivals\killcard\f\tNNNN.jpg`: Edward's live RIVALS games today (1600x900, every 2 s). Lobby is t0000-t0014; the Play
  menu is t0016.
- `ui_rivals\feel\rivals\`: live captures (hub_full, playerlist, nameplate_own, weapons_hover_wrap, board_winstreaks, frames\).
- Codes: RIVALS has no codes screen. Judge it against the RIVALS panel family (Tasks, free rewards, Settings).

## Report format
Write your report to `rounds\<round>_grade_<LETTER>.md`, under 500 words.

Per section:
- a score out of 10 for closeness to RIVALS on your lens;
- at most 4 fixes, each concrete: element, current → target, in design px or ratios, citing the RIVALS frame you used.

Then rank the fixes across sections by visible impact.

Rules:
- If a change from last round moved us away from RIVALS, say so first.
- Only list what you can see. Say "can't judge" when a crop is too small.
- Don't edit any files other than your report.
