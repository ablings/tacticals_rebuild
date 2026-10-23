# e14 grade C: interactivity and feel

Sources: the e14 captures and the code at 9285239 (the PartyScreen, RankedScreen and Notify diffs against d570aff).

**What landed:** Party: the friends redraw now only runs for the same open and only on Friends (PartyScreen:382-383: `isOpen and openedAt == token and current == "Friends"`). The token is taken when the fetch returns rather than at spawn. That still works: if the player reopened during the fetch, the wait is measured from the new open, and the new open's own fetch returns early on the same key. So a stale redraw can no longer cut a pop, and All and Lobby no longer lose hover. The empty plate is now a fixed sibling of the grid (built once at 700,230 900x512 and toggled in renderGrid). Search keystrokes no longer destroy and rebuild it, and the capture shows it ending level with the party column (490 capture px = 742). The other e14 changes are layout only: the Ranked "0/10 Placed", the leaderboard header and hint, and the News gap.

**Still open:** CanvasGroup rows in the leaderboard and inbox, `Theme.blur` in Notify (215, 304, still the literal 24), the player-menu un-light, and the crest pop.

## ranked: 10/10
No feel fixes left. Nit outside my lens: rankUnit is measured with `Enum.Font.GothamBold`, but rankName uses FB (Rubik). Use `TextService:GetTextBoundsAsync` with FB, or the label's `TextBounds`, so "Placed" doesn't drift.

## ranks: 10/10
No feel fixes left.

## rankedlb: 7.5/10 (unchanged)
1. The rows are Frames, so popIn scales them at full opacity. Target: CanvasGroup rows, so `Kit.popIn` fades GroupTransparency from 1 to 0.
2. Rows use a circular Scale height (0.07 of an AutomaticCanvasSize list). Target: a fixed 56 px row through toScale, tested with 15 fake entries.
3. The empty state (crest, line and the new hint) appears with no motion. Target: `Kit.popIn(cHold, 0.08)`, then fade in the line at 0.12 and the hint at 0.16.

## party: 9.5/10 (held)
1. The cards still pop at full opacity. Target: CanvasGroup cards, or a 0.18 s BackgroundTransparency tween from 1 to 0.25 alongside the pop.
2. The empty plate snaps on with `Visible`. On a tab change, cards pop but the plate doesn't. Target: when it turns visible on an animated render, tween BackgroundTransparency from 1 to 0.35 and the label TextTransparency from 1 to 0 over 0.18 s.
3. Nit: take `local token = openedAt` before `GetFriendsOnline` so the intent reads directly.

## playercard: 9.5/10 (unchanged)
1. A click-outside close still snaps the row to transparency 1 (PlayerCards:382). Target: `Kit.tween(m.row, 0.1, {BackgroundTransparency = 1})`, the same as the RIVALS playerlist fade (rivals_rec t0152-t0156).
2. The 2-player click-through Y test against `GuiService:GetGuiInset()` is still pending.

## inbox: 8/10 (unchanged)
1. popIn scales the rows at full opacity (Notify:197-201). Target: CanvasGroup rows, the same as the News blocks.
2. The age chip pops around its own centre. Target: parent it to the row at (686, 31) and drop its separate popIn.
3. Change the literal 24 at Notify:215 to `Theme.blur`.

## news: 10/10
Nit: `Theme.blur` instead of 24 (Notify:304). The shorter block pitch doesn't change the motion.

## Top 8
1. Leaderboard: CanvasGroup rows at a fixed 56 px.
2. Inbox: CanvasGroup rows, with the chip parented to its row.
3. Leaderboard: pop in the empty-state crest, then fade in the line and the hint.
4. Party: fade the empty plate in when it appears on an animated render.
5. Use `Theme.blur` in Notify (215, 304).
6. Party: fade the cards in as well as scaling them.
7. Player menu: a 0.1 s un-light on a click-outside close.
8. Ranked: measure rankUnit with the real font (FB), not GothamBold.

Remaining gap worth another round: yes
