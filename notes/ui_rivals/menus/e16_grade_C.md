# e16 grade C: interactivity and feel

Sources: the e16 captures and the code at 6f29542 (the Notify, PartyScreen and RankedScreen diffs against cf764f6).

**What landed:**
- The leaderboard empty state now has motion. `Kit.popIn(cHold, 0.08)` runs, then the line fades in at 0.12 and the hint at 0.16 (RankedScreen:345-349).
- The duplicate row fade is gone. Rows 1-12 are faded only by popIn's 0.18 s tween, and rows 13 and up start at GroupTransparency 0.
- Party no longer blinks between two empty tabs. It fades only when `not emptyPlate.Visible` (PartyScreen:269).
- "Placed" is re-placed when the label's TextBounds or its parent's AbsoluteSize changes. The hook is connected once (`ui.unitHooked`), so connections don't pile up across renders.

**Still open:** CanvasGroup rows in the inbox, CanvasGroup cards in Party, `Theme.blur` in Notify (214 and 304 are still the literal 24), and the player-menu un-light.

## ranked: 10/10
No feel fixes left. The robustness gap from e15 is closed.

## ranks: 10/10
No feel fixes left.

## rankedlb: 8.5/10 (was 8)
1. cHold is a plain Frame, so popIn only scales the crest. It comes in at 0.85 scale and full opacity while the text fades around it. Target: make cHold a CanvasGroup so popIn's GroupTransparency fade applies, or tween the emblem ImageLabel's ImageTransparency from 1 to 0 over 0.18 s at 0.08.
2. The new pinned own row (y 553, 792x64) appears with no motion. Target: build it as a CanvasGroup and run `Kit.popIn(own, 0.1)` in fillBoard, so it arrives with the list.
3. The rows still use a circular Scale height (0.07 of an auto-sized list, which is now 388 tall). Target: a fixed 56 px row through toScale, tested with 15 fake entries.

## party: 9.5/10 (held)
1. The cards still pop at full opacity. Target: CanvasGroup cards, which popIn already fades.
2. Switching from All to Friends while both are empty now swaps the text instantly ("Nobody else here yet" becomes "No friends online right now"). Target: when the text changes and the plate is already visible, fade emptyLabel's TextTransparency from 1 to 0 over 0.15 s.

## playercard: 9.5/10 (unchanged)
1. A click-outside close still snaps the row to transparency 1 (PlayerCards:382). Target: `Kit.tween(m.row, 0.1, {BackgroundTransparency = 1})` (rivals_rec t0152-t0156).
2. The 2-player click-through Y test is still pending.

## inbox: 8.5/10 (held)
1. The rows (the `pill` Frames) still pop at full opacity (Notify:197-200). Target: build the row as a CanvasGroup in `pill`, so it fades like the leaderboard rows.
2. Change the literal 24 at Notify:214 to `Theme.blur`.

## news: 10/10
Nits:
- Use `Theme.blur` instead of 24 at Notify:304.
- The close button shrank to 67x36, so check that Kit.closeButton's hover and press scale still read at that size. If they don't, give it a 84x50 transparent hit area.

## Top 8
1. Inbox: CanvasGroup rows.
2. Party: CanvasGroup cards, so they fade as well as scale.
3. Leaderboard: a CanvasGroup crest holder, so the crest fades as well as scales.
4. Leaderboard: the pinned own row pops in with the list.
5. Party: fade the empty label when the text changes between two empty tabs.
6. Notify: `Theme.blur` at 214 and 304.
7. Player menu: a 0.1 s un-light on a click-outside close.
8. Leaderboard: a fixed 56 px row height.

Remaining gap worth another round: yes
