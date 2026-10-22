# 05 - Match HUD + Results vs RIVALS (audit 2026-10-21, read-only)

Area: `ui/set/HUD.lua`, `ui/set/HotbarController.lua`, `ui/set/HealthBarController.lua`, `ui/match/DuelHUD.client.lua`,
`ui/match/KillIcons.lua`, `ui/hud/CombatFeedbackController.lua`. Our screens: `notes/ui_duel_real.png`, `notes/match_place_flow_sheet.png`,
`notes/weapon_feel/sheet_2026-10-21.jpg`.

## What RIVALS does here
- **Interactability:** the round card pops in under the timer with a white flash wiping across it (`ref_rivals_rounds/round_won_flash.jpg` -> `round_won.jpg`).
  Spectate controls are big pressable arrows with mouse glyphs, plus a camera button and a red Leave with an `M` chip (`rivals_rec/t0113.0s.jpg`, `t0114.3s.jpg`).
  The hit arrow and red edge vignette land at once (`hit_vignette_arrow.jpg`).
- **Cleanliness:** the top bar is just three chunky blocks (score + head, timer, score + head) and nothing else up there (`t0116.0s.jpg`, `t0119.0s.jpg`).
  At round end you get one card and one action, "Switch Weapons [M]" (`intermission_switch.jpg`). The killer card carries name, icon and "eliminated you with X" and nothing more (`round_lost_full.jpg`).
- **Kid-friendly:** words are short ("ROUND / WON", "Switch Weapons", "Eliminated debits"). The colours tell you which side is which. Every action button is big, bright and filled, with a key chip on it (`t0113.0s.jpg`, `round_lost_full.jpg`).
  The in-match Daily Tasks bars show progress as it happens (`round_lost_full.jpg`). That belongs to another area.

## Gaps
| Our element | RIVALS behaviour | Quality | Sev |
|---|---|---|---|
| Result buttons (Back / Rematch / Play Again / Leave) are identical dark plates, hover 1.04 only | One bright filled primary; press squash | Int / Kid | P1 |
| Results card (VICTORY, stats) just appears (`results.Visible = true`) | Pops in; numbers animate | Int | P1 |
| Six stats with "-" placeholders (Assists / Damage) | Few big numbers | Clean / Kid | P1 |
| Score digit changes silently (set every frame, L1333) | Score block bumps on a point | Int | P2 |
| Round card: scale pop only. The comment promises a flash; `showRoundCard` has none | White flash + sweep | Int | P2 |
| Spectate "Q <" / "> E" are labels, not buttons (L354-355) | Big clickable arrow buttons | Int / Kid | P2 |
| DuelHUD buttons skip `Kit.bindButton` (no press, no hover sfx, no pad-select grow) | Every button squashes | Int | P2 |
| Head turns into a skull instantly (L1217-1219) | Inferred: a death is noticed | Int | P3 |
| Timer under 5 s only turns red (L1339) | Inferred: ticks | Int | P3 |
| Rank lines are long sentences (L633-645) | Short pill ("+22", "Promoted!") | Kid | P3 |
| Health bar: no hit punch (only a number flash) | Bar reacts | Int | P3 |

## Ranked changes
1. **Give the result buttons a clear order and make them respond.** In `bigButton` (DuelHUD L715-727), make Play Again the field-green primary (#8DBF5A -> #4C7A2E gradient, cream text, ~1.2x taller). Rematch stays a tan secondary; Leave and Back stay dark. Bind each button with `Kit.bindButton` (hover 1.05, press 0.93, hover sfx). Size M. Kit: require `UIKit.Kit` into the existing `resultActs` table (no new local); Theme needs the field-green pair. *Look:* our green primary, our tan.
2. **Pop the results card in and count the numbers up.** In `showResults` L649-653: when the card shows, run a UIScale 0.85 -> 1 Back tween (0.3 s), slide and fade VICTORY in like `showBanner` L196-202, then count `stats.*` up from 0 over 0.5 s, staggered 0.08 s. Keep the tween state in the `stats` table. Size M. Kit: none (Kit.tween optional). *Look:* Montserrat Heavy and our colours are unchanged.
3. **Cut stat clutter.** In the stats loop at L530-534, hide any stat that is nil instead of showing "-". Put Eliminations / Deaths / Headshots big on row 1, and show damage only when the server sends it. Size S. *Look:* the layout stays the same, with fewer cells.
4. **Bump the score block on every point.** In the RenderStepped score bar code (L1331-1333), when `mine` or `theirs` differs from the last value kept in `mineBox` / `theirBox`, pop `box.score` 1.5 -> 1 (Back, 0.3 s) and flash the box stroke cream. Size S. *Look:* tan / dark-green fills untouched.
5. **Add the flash the round card is missing.** In `showRoundCard` L1014-1023 and `RV.showMatchPoint` L1186-1196, call the existing `sweep(roundCard, 8)` (L88) and fade a cream overlay from 0.3 to 1 over 0.25 s. Size S. *Look:* cream flash, our fills.
6. **Make the spectate arrows real buttons.** Turn `specPrev` / `specNext` (L354-355) into chunky TextButtons with cream Q / E key badges, wired to `cycle(-1/1)` (L420) and bound with `Kit.bindButton`. Change their texts in place rather than adding locals. Size M. Kit: `bindButton`. *Look:* uses the hotbar's cream key badges.
7. **Move every other DuelHUD button to `Kit.bindButton`.** That covers `panelButton` L940-952, `switchB` L1166-1167, `specStop` L356 and `leaveDuel` L503. Delete their hand-written MouseEnter / MouseLeave handlers. Size S. Kit: `bindButton`. *Look:* motion only.
8. **Pop the skull when a head dies.** In `fillBox` L1217-1219, when `dead` flips on, pop `s.skull` 1.6 -> 1 and fade a red flash over `s.h`. Keep the last state in `s.dead`, a slot field, not a new local. Size S. *Look:* our bone skull.
9. **Tick the timer in the last 5 s.** At L1338-1339, when `math.ceil(left)` changes during Live with under 5 s left, pop timerL 1.25 -> 1. Size S. *Look:* the red warning stays as it is.
10. **Shorten the ranked words.** Rewrite the rank lines at L633-645 as short phrases ("Rank up! Silver 1", "Shield saved you", "Placement 3/10") and keep the long explanation off the card. Size S. *Look:* text only.
11. **Punch the health bar on a hit.** In `update` L92-95 (HealthBarController), on a hit, punch a UIScale on `frame` 1.06 -> 1 (0.15 s). Leave the bone -> amber -> red ramp alone. Size S. Kit: none. *Look:* the bar itself is unchanged.

## Not verifiable from stills (motion inferred)
- The duel in the recording (~110-122 s) is **spectate only**. It has no round end, no results and no rematch screen, so the results motion is inferred from the lobby menus (pop-in, press squash) and from our own earlier refs.
- Tween lengths and easing for the round-card flash, score bump, skull pop and timer tick are guesses (~0.2-0.3 s Back). I did not check them frame by frame.
- Whether RIVALS counts result numbers up is unconfirmed. The ranked ELO bar does animate (we already copy that, L871).
- DuelHUD is at the 200-locals limit: every change above reuses `RV`, `resultActs`, `stats`, slot and box tables.

## Implemented (group E)
2026-10-21, RIVALS pass. Files: `ui/match/DuelHUD.client.lua`, `ui/set/HealthBarController.lua`. No new main-chunk locals in DuelHUD
(Kit lives in `stats.Kit`, helpers in `stats.bind` / `RV.flashRoundCard`; peak active locals unchanged, re-counted after the edits).
No Studio test was run (agent rule): needs a play test.
- **Kit access + one button behaviour** - DuelHUD:555-566 `stats.Kit` (pcall require of UIKit.Kit) and `stats.bind` (= `Kit.bindButton`,
  no-op without Kit). Bound: the spectate arrows, Stop Spectate and Leave Duel (:566), every results `bigButton` (:792, hand-written hover
  UIScale removed), every post-match `panelButton` (:1025, same), Switch Weapons (:1256, its MouseEnter/Leave removed; bindButton drives
  `switchScale`). bindButton re-centres anchors, so the per-frame `rematchP.Position` now keeps the bottom-right corner at (0.992, y)
  whatever the anchor (:1044-1046).
- **Results buttons** - DuelHUD:800-810: Play Again = field-green primary (#8DBF5A -> #4C7A2E gradient, cream #ECE6D2 words, its hairline
  stroke removed); Rematch = tan secondary (the file's TEAM_A.fill gradient; `styleRematch` still greys it / outlines your vote);
  Leave and Back unchanged dark plates.
- **Results card** - DuelHUD:705-719: the card opens with `Kit.open` (centre pop + open sfx) only when it wasn't already up; VICTORY /
  DEFEAT slides in from the left and fades up like `showBanner` (home kept in `stats.titleHome`); the numbers count up from 0 with
  `Kit.countTo` (0.5 s, staggered 0.08 s after 0.15 s).
- **Empty stats hidden** - DuelHUD:550-553 keeps each caption in `stats.cap`; :650-675 hides a stat (number + caption) the server didn't
  send instead of "-", and lays the shown ones out in order Eliminations / Deaths / Headshots big on row 1, Assists / damage on row 2
  (same grid, Scale positions, `dTS` + `rescale()`).
- **Score bump** - DuelHUD:1430-1437: when your / their score changes, `Kit.pop(box.score, 1.5)` (digit re-centred once so it grows from
  its middle); the last value is `box.last`, reset on a new match (:1393). The stroke cream flash from the audit was skipped (colour rule).
- **Round-card flash** - DuelHUD:1102-1112 `RV.flashRoundCard`: a cream wash fades 0.3 -> 1 over 0.25 s plus the existing `sweep(roundCard, 8)`;
  called from `showRoundCard` (:1100) and `RV.showMatchPoint` (:1285).
- **Spectate arrows** - DuelHUD:354-374: `specPrev` / `specNext` are TextButtons now (78 x 88 design px, solid dark block, no border, big
  Oswald chevron, cream Q / E key badge with dark letter), built in a function (no new locals); clicks call `cycle(-1/1)` (:441-443);
  Q / E keys and the `Visible` toggling in `refreshSpecCard` unchanged.
- **P3 done (trivial):** skull pops 1.6 -> 1 when a head flips to dead (DuelHUD:1310-1316, state in slot `s.dead`, skull re-centred once);
  short rank lines "Your rank: X" / "Placement 3/10" / "Shield saved you" / "Rank up! X +22" / "Rank down: X -15" (DuelHUD:686-698, colours
  unchanged); health bar punch `Kit.pop(frame, 1.06)` on a hit (HealthBarController:94-99).
- **Skipped:** timer tick in the last 5 s (timerL's Position is rewritten every frame with a top-left anchor, a UIScale pop would drift;
  needs a centred anchor rework). Play Again ~1.2x taller (would overlap Rematch in the column; needs a re-spaced column). The red hit
  flash over the head (colour on an existing element). The post-match panel's Play Again (`againP`) stays a dark plate (only the results
  buttons were in scope; easy to match later). HUD.lua, HotbarController.lua and CombatFeedbackController.lua untouched (no group E item
  needed them; hitmarker / damage numbers / hotbar kick / crosshair left alone).
- **Fonts / tells:** new text uses Oswald Bold (spectate chevrons + key letters); no new Montserrat / Builder Sans, no new UICorner + thin
  UIStroke combo, no left accent bars. Existing tells seen, not touched: Montserrat (`FX`) and Builder Sans (`FB`) across all of DuelHUD
  and the HealthBar number (Montserrat `STENCIL`); UICorner + hairline UIStroke on the score boxes, timer box, spectate bar, scoreboard
  board, Leave / Back / Rematch and panel buttons; the scoreboard's team header has a thin left accent bar (`sbHeader`). Removed one
  tell: Play Again's hairline stroke.
