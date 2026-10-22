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
