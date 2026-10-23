# e13 grade C: interactivity and feel

Sources: the e13 captures and sheet, and the code at d570aff (the PartyScreen, RankedScreen and Notify diffs against 7b07364).

**What landed:** Party: the friends-online fetch now compares uid keys and returns when the list is unchanged (PartyScreen:375-376). When the list did change, it waits until 0.55 s after `openedAt` and then redraws without the pop (378-380). That removes the common case where the opening pop got cut off. The other e13 changes are layout only: the ELO-bar inset, the larger leaderboard crest, the News pitch and the quieter Invite label. None of them change motion or input.

**Still open:** CanvasGroup rows in the leaderboard and inbox, `Theme.blur` in Notify (215, 304; the comments still say Theme.blur but the code passes 24), the player-menu un-light, and the crest pop.

## ranked: 10/10
No feel fixes left.

## ranks: 10/10
No feel fixes left.

## rankedlb: 7.5/10 (unchanged)
1. The rows are Frames, so popIn scales them at full opacity (RankedScreen:306). Target: CanvasGroup rows, so `Kit.popIn` fades GroupTransparency from 1 to 0.
2. Rows use a circular Scale height (`0.07` of an AutomaticCanvasSize list). Target: a fixed 56 px row through toScale, tested with 15 fake entries.
3. The crest is now bigger (0.24) but it still appears with no motion. Target: `Kit.popIn(cHold, 0.08)`, then the line at 0.12.

## party: 9.5/10 (was 9)
1. Stale open: `wait` is worked out from the `openedAt` in place when the fetch returns. If the player closes and reopens inside that window, the first task wakes up and redraws over the second open's pop. Target: take `local token = openedAt` at spawn, and redraw only if `isOpen and openedAt == token`.
2. Friends who are not in the server show only on the Friends tab (`people()`; All and Lobby need `inServer`). On All or Lobby, the redraw destroys every card for no visible change, which drops any hover the player has on a card. Target: redraw only when `current == "Friends"`. On a later switch to that tab, SetTab already redraws.
3. The cards still pop at full opacity. Target: CanvasGroup cards, or a 0.18 s BackgroundTransparency tween from 1 to 0.25.

## playercard: 9.5/10 (unchanged)
1. A click-outside close still snaps the row to transparency 1 (PlayerCards:382). Target: `Kit.tween(m.row, 0.1, {BackgroundTransparency = 1})`, the same as the RIVALS playerlist fade (rivals_rec t0152-t0156).
2. The 2-player click-through Y test against `GuiService:GetGuiInset()` is still pending.

## inbox: 8/10 (unchanged)
1. popIn scales the rows at full opacity (Notify:197-201). Target: CanvasGroup rows, the same as the News blocks.
2. The age chip is a sibling with its own anchor, so it scales around its own centre and not the row's. Target: parent the chip to the row at (686, 31) and drop its separate popIn.
3. Change the literal 24 at Notify:215 to `Theme.blur`.

## news: 10/10
Nit: use `Theme.blur` instead of the literal 24 (Notify:304).

## Top 8
1. Leaderboard: CanvasGroup rows at a fixed 56 px.
2. Inbox: CanvasGroup rows, with the chip parented to its row.
3. Party: an open token on the friends redraw, so a fast close and reopen can't cut the new pop.
4. Party: redraw the friends list only on the Friends tab.
5. Use `Theme.blur` in Notify (215, 304).
6. Leaderboard: pop in the crest and the empty-state line.
7. Player menu: a 0.1 s un-light on a click-outside close.
8. Party: fade the cards in as well as scaling them.

Remaining gap worth another round: yes
