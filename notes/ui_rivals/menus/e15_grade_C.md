# e15 grade C: interactivity and feel

Sources: the e15 captures and the code at cf764f6 (the Notify, PartyScreen and RankedScreen diffs against 9285239).

**What landed:** The leaderboard rows are now CanvasGroups (RankedScreen:331), so `Kit.popIn` fades GroupTransparency as it scales them (lobby Kit:957-966). The inbox age chip is now a child of its row at 686,31, and its own popIn is gone, so it pops with the row. The Party empty plate fades in over 0.2 s when it appears or on an animated render (PartyScreen:268-273). "Placed" is now placed from the live label's TextBounds, and the capture shows it hugging "0/10".

**Still open:** CanvasGroup rows in the inbox, `Theme.blur` in Notify (214 and 303 are still the literal 24), the Party cards popping at full opacity, the player-menu un-light, and the motion on the leaderboard's empty state.

## ranked: 10/10
No feel fixes left. On robustness: if `rankName.Parent.AbsoluteSize.X` is 0 when the deferred task runs, it returns early, so "Placed" stays at x 74 on top of the count and is never placed again. Target: run the same placement from `rankName:GetPropertyChangedSignal("TextBounds")` (the same fix covers a resolution change).

## ranks: 10/10
No feel fixes left.

## rankedlb: 8/10 (was 7.5)
1. The empty state (crest, line and hint) still appears with no motion, and in Studio it is the only state anyone sees. Target: make cHold a CanvasGroup and run `Kit.popIn(cHold, 0.08)`, then fade the line's TextTransparency from 1 to 0 at 0.12 and the hint's from 1 to 0.4 at 0.16. Use the 0.18 s Kit fade.
2. The rows still use a circular Scale height (0.07 of an AutomaticCanvasSize list). Target: a fixed 56 px row through toScale, tested with 15 fake entries.
3. Nit: the new `task.delay(... GroupTransparency = 0)` at 334 duplicates popIn's own fade for rows 1-12, with a 0.2 tween fighting a 0.18 one. Keep it for rows 13 and up only (`if i > 12`).

## party: 9.5/10 (held)
1. The cards still pop at full opacity. Target: CanvasGroup cards, which popIn already fades.
2. Switching between two empty tabs (All to Lobby) resets the visible plate to transparency 1 and fades it in again, so it blinks. Target: fade only when `not emptyPlate.Visible`, and on a tab change swap just the label: TextTransparency 1 to 0 over 0.15 s.

## playercard: 9.5/10 (unchanged)
1. A click-outside close still snaps the row to transparency 1 (PlayerCards:382). Target: `Kit.tween(m.row, 0.1, {BackgroundTransparency = 1})` (rivals_rec t0152-t0156).
2. The 2-player click-through Y test is still pending.

## inbox: 8.5/10 (was 8)
1. The rows (the `pill` Frames) still pop at full opacity (Notify:197-200). Target: build the row as a CanvasGroup in `pill`, so popIn fades it the same way as the News blocks and the leaderboard rows.
2. Change the literal 24 at Notify:214 to `Theme.blur`.

## news: 10/10
Nit: `Theme.blur` instead of 24 at Notify:303.

## Top 8
1. Leaderboard: pop the empty-state crest in, then fade in the line and the hint.
2. Inbox: CanvasGroup rows.
3. Party: CanvasGroup cards, so they fade as well as scale.
4. Party: no blink when switching between two empty tabs.
5. Leaderboard: a fixed 56 px row, and drop the duplicate fade for rows 1-12.
6. Notify: `Theme.blur` at 214 and 303.
7. Player menu: a 0.1 s un-light on a click-outside close.
8. Ranked: re-place "Placed" when TextBounds changes, so a zero-size first pass can't leave it on top of the count.

Remaining gap worth another round: yes
