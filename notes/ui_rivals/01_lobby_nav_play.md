# 01 Lobby nav + Play row + Play screen vs RIVALS (UI audit, 2026-10-21)

## What RIVALS does
- **Interactability:** dock icons get a dark round disc behind them on hover (Shop in `t0188.9`, `t0254.9`). The world Ranked pad shows a "Ranked / Play Now" billboard as you walk up (`t0284.0` to `t0285.0`). Ranked then pops in as one centred card (`t0285.4` to `t0286.0`, about 0.5 s). Red count badges sit on the icons (`t0000.0`).
- **Cleanliness:** a single row under the hub: Play, your head and "+". Below that, 7 icons with one-word labels on a thin bar (`t0000.0`). Daily Tasks is three lines, each with a bar, a count and a reward, plus one secondary "To Duels" button.
- **Kid-friendly:** Ranked is a 5-line checklist. Each line has a progress bar, a "12 / 30" count or a green tick, and the greyed Play sits right under it (`t0287.0`). You can see at a glance why you can't play and what to do next. Labels are one word ("Tasks", "Pass").

## Gap table
| Our element | RIVALS behaviour | Quality | Sev |
|---|---|---|---|
| Lobby accents are yellow: `Theme.color.olive` and `amber` = #FFD400. They tint the PlayRow avatar ring and "+" (`PlayRow.lua:76,83,132`), the done mission bar (`LobbyHudController.lua:587`), the "found" state and the Ranked ELO fill | Neutral white / green accents | Clean (our look) | P1 |
| Locked Ranked tile: click shows a toast (`PlayScreen.lua:286-289`) | Checklist card with bars and a grey Play | Kid | P1 |
| Ranked 1v1/2v2/3v3 cards show "Click to queue" text and no button (`RankedScreen.lua:276`) | A real Play button | Kid / Clean | P1 |
| Scissors count and mission bars jump straight to the new value (`LobbyHudController.lua:560,587`) | Counters and bars animate (inferred) | Interact | P2 |
| Dock hover: grow and lift, bubble after 0.55 s (`:450-464`). No disc highlight, no press squash below 1 (`:481` presses to 1.02) | Disc lights up; press dips | Interact | P2 |
| Play screen tiles all appear at once with the root's 0.9 to 1 scale (`Kit.open`) | Card pops in (stagger inferred) | Interact | P2 |
| Ranked popups / ladder just set `Visible = true` (`RankedScreen.lua:306,308`) | Pop-in | Interact | P2 |
| Training copy is two 21 px sentences (`PlayScreen.lua:301`) | One short line | Kid | P2 |
| Ranked tile and strips are violet (`T.violet`, `PlayScreen.lua:208,265,431`) | n/a (off-palette for us) | Clean (our look) | P3 |

## Ranked change list
1. **Strip yellow from the lobby.** In `PlayRow.lua:76` use the avatar stroke `#ECE6D2`. At `:83` and `:132` use a `#8DBF5A` hairline. At `LobbyHudController.lua:587` the done bar becomes `#8DBF5A`. In `PlayRow` GRADS.found (`:25`), use a brighter field green instead of comic yellow. Size S. Needs Theme: add `Theme.color.field = #8DBF5A` and `cream = #ECE6D2`; leave `olive` / `amber` as they are for tutorial code. Look check: uses only our greens and cream.
2. **Locked Ranked becomes a checklist.** `PlayScreen.lua` render() `rt.Activated` (`:285`): replace the toast with a centred card. It shows "Reach Level 50" with a bar and an "n / 50" count, and a disabled grey PLAY under the card. Reuse the `popup()` pattern from `RankedScreen.lua:145`. Size M. No Kit change. Look check: dark plate, Montserrat Heavy title, our X.
3. **A PLAY bar on the Ranked mode cards.** In `RankedScreen.lua:266-276`, add the same 58 px field-green PLAY strip that PlayScreen's modeCard has (`:219-221`). The status text moves into it ("SEARCHING 0:12, tap to cancel"). Size S. Look check: one button system.
4. **Kit.countTo(label, from, to, t) and Kit.fillTo(bar, frac).** Use them for the scissors pill (`LobbyHudController.lua:560`), the mission bars (`:587`; this needs the bar rebuild at `:574` to keep the old fraction) and the ELO fill (`RankedScreen.lua:113`). Size M. Needs Kit: two new helpers. Look check: motion only.
5. **Dock hover disc and press squash.** In `LobbyHudController.lua:450-482`, tween the `Disc` frame (`:355`) to a brighter `#8DBF5A`, transparency 0.6, on enter. On press go to 0.94, then release with Back to 1.12. Size S. Look check: our green, flat cream icon unchanged.
6. **Staggered tile pop on the Play screen.** At the end of `render()` (`PlayScreen.lua:363`), give each tile a UIScale that goes 0.85 to 1 with Back, 0.18 s, with a 0.04 s step between tiles. Size S. Shared work could be `Kit.popIn(list, step)`. Look check: motion only.
7. **Pop the Ranked popups in.** At `RankedScreen.lua:306,308`, call `Kit.open(panel)` instead of `Visible = true`, and `Kit.close` in `hide()` (`:155`). Size S.
8. **Cut the reading load.** `PlayScreen.lua:301`: change the text to "Try every gun for free". `:281`: the Ranked tile says "PLAY RANKED" instead of "Click to play rated duels". `RankedScreen.lua:276`: drop "Click to". Size S. Look check: Builder Sans body as today.
9. **Show the dock bubble sooner.** In `LobbyHudController.lua:455`, drop the delay from 0.55 to 0.3 s. Pop the bubble in as it appears (scale 0.8 to 1, Back). Size S. Look check: white bubble kept.
10. **Ranked colour.** Change `T.violet` on the Ranked tile and strips to a tan / dark-green gradient (`#3B4524` to `#14170F`, which RankedScreen cards already use) with a tan edge. Size S. Needs Edward's OK (style reversal). Look check: moves Ranked onto our palette.

## Not verifiable from stills (inferred)
- Hover and press timing on the RIVALS dock and Play (only the hover disc shows in `t0188.9` / `t0254.9`). I assume a scale-up of about 0.1 s.
- Whether Ranked pops in with a scale or a fade (`t0285.4` to `t0286.0` are 0.6 s apart).
- Counter and bar animation in RIVALS (no before / after pair in the lobby).

## Implemented (group A)
Done 2026-10-21 by the group A agent. These are code edits only: nothing was run in Studio and nothing was committed. Line numbers are for the edited files.
Rules followed: no colour changes to existing elements. New elements use Theme.color field / fieldDark / cream / tan / plate. There are no UICorner + hairline UIStroke combos and no left-edge bars; new buttons are solid fills on an offset block. New text uses Oswald Bold (Theme.font.display / chunky) or Rubik (Theme.font.medium). Everything created after toScale is in Scale.

- **Nav disc lights + press squash** (`ui/hud/LobbyHudController.lua:367`, `:475`, `:496`). Each Disc gets a new `Glow` layer (Theme.color.field). It tweens to 0.6 transparency on hover and back on leave / resetNav. A press now squashes to 0.94 (was 1.02). Release springs with Back to 1.12 while hovered, or to 1 otherwise. The bubble delay stays at 0.55 s (Edward asked for it).
- **Corner buttons** (`LobbyHudController.lua:133`, `:211`). Settings / News / Inbox get `Kit.bindButton`. `ctl.setUnread` runs `Kit.pop` on the visible red count when the number goes up.
- **Scissors pill counts up** (`LobbyHudController.lua:577-585`). `Kit.countTo(count, old, new, 0.6, commas)` runs on each change, and the pill gets `Kit.pop(pill, 1.12)` when the count rises. The first fill is set directly.
- **Hub Daily Missions widget** (`LobbyHudController.lua:523`, `:600-652`). Each bar is built at its last fraction (`hudFx.frac`) and `Kit.fillTo` moves it to the new one after toScale. A mission that is done but not claimed shows a green **CLAIM** pill in place of the check: field fill on a fieldDark offset block, cream Oswald word, `bindButton`. The pill opens Missions, and it pops in when the mission has just finished. Claimed missions keep the check. The title uses `def.Short or def.Text` (`:609`), ready for the lead's `Short` label.
- **Player list** (`LobbyHudController.lua:707-799`, plus `:834`). Rows are kept in `lbRows[UserId]`:
  - a row's contents (`fillRow`) rebuild only when that player's own key changes, or when forced;
  - a re-sort tweens rows to their new slot (0.25 s Quad), newcomers pop in staggered, and leavers shrink away before they are destroyed;
  - your own row has a soft field-green fill (0.82; no bar);
  - hover brightens the row and lifts it (PopScale 1.02); rows are centre-anchored;
  - the list's x (`lbHide`) gets bindButton.
- **Play tiles pop in** (`ui/play/PlayScreen.lua:194-206`, `:536-538`). `tile()` calls `Kit.popIn(f, step * 0.04)` when `popStep` is set. setOpen sets it only around the opening render, so tab / party re-renders don't pop. popIn runs before bindButton, so both share one UIScale.
- **Locked Ranked requirement card** (`PlayScreen.lua:208-259`, `:344`, `:543`). This replaces the toast. The centred plate card has:
  - "RANKED", a "Reach Level N" line with an "n / N" count (tan) and a bar that fills with `Kit.fillTo`;
  - a greyed PLAY under it that `Kit.shake`s when pressed;
  - the Kit X close.
  It opens and closes with `Kit.open` / `Kit.close`, and it is removed when the Play screen closes. It is built in design px and then `Kit.toScale(shade, 1920x1080)`. `big()` got an optional font argument.
- **Green PLAY bars on the Ranked mode cards** (`ui/ranked/RankedScreen.lua:283-292`, `:131-141`). PlayScreen's field-green gradient strip is used as an inset 432x62 button on a fieldDark offset block, replacing the grey "Click to queue" line. The status is written in the bar:
  - idle: PLAY on green;
  - searching: "SEARCHING... TAP TO CANCEL" on a dark bar;
  - in another queue: "IN ANOTHER QUEUE".
- **Fonts (Edward's decision)**: in LobbyHudController and PlayScreen, the Montserrat / Gotham definitions (`OSWALD`, `BODY`, `BOLD`, and the corner's italic `BODYI`) now point at Theme.font.display / medium / bold and Rubik italic.

### Skipped / notes
- **PlayRow.lua: no changes.** Its only audit items are colour changes (the yellow ring, + and found state), which are blocked by the no-colour rule (Q1).
- Not in the group A list, so not done: the Ranked popups' Kit.open (audit item 7), the ELO bar fillTo, cutting the reading load (8), and the Ranked violet (Q2).
- I did not give `lbMode` a bindButton: `modeIcon()` destroys all its children, which would include the UIScale.
- **Kit issue (not changed):** `Kit.pop` / `popIn` / `breathe` add a *second* UIScale ("PopScale" / "BreatheScale") to anything that already has a bindButton UIScale. Roblox applies only one UIScale per object. I worked around it by calling popIn before bindButton. A shared fix would be for motionScale to reuse an existing UIScale.
- **Existing AI tells seen, left alone:**
  - Builder Sans is still the base font of PlayScreen (`HEAVY` / `SEMI`), RankedScreen (`FB` / `FS` / `FM`) and the HUD (`WFONT`, `PFONT`, `NAV_FONT`, `LB_*`, the bubble).
  - `Kit.closeButton` is corner + 1.5 px tan hairline.
  - PlayRow's Invite + is corner + hairline (`PlayRow.lua:83`).
  - The Play tiles and plates use corner + 2-3 px edge strokes (`PlayScreen.lua` edge() / tile()).
  - The HUD `brackets()` helper is corner + 1.5 px edge.
  - The Ranked popups use corner panels.
- **Not verified in Studio:** I couldn't run Luau tooling. A token-level check shows balanced blocks and brackets in all three files, and the HUD's Start() has ~80 top-level locals, under the 200 limit.
