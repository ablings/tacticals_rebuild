# e12 grade C: interactivity and feel

Sources: the e12 captures and sheet, the code at 7b07364, `02` ranked screen, rivals_rec t0152-t0156, `rv_playermenu.jpg`, `news_panel.png`.

**What landed (both):**
- Party: `renderGrid(animate)` pops only from `Open` and `SetTab` (PartyScreen:301, 360). Search, PlayerAdded/Removing and attribute changes now redraw without the pop (343-349). `Kit.centreAnchor(c)` runs before `popIn` (280), so each card grows in place.
- Ranked: the "i" square (40x40 at 760,13 in the strip) is bound with hover 1.08 / press 0.94, and it opens the ladder (RankedScreen:437-438). Its parent has no layout, so bindButton centre-anchors it. The placement text is TextScaled (max 26) so it stops short of the square.

**Still open:** CanvasGroup rows for the leaderboard and inbox, the inbox chip parenting, `Theme.blur` in Notify, and the player-menu un-light.

## ranked: 10/10
No feel fixes left.

## ranks: 10/10
No feel fixes left.

## rankedlb: 7.5/10 (unchanged)
1. The rows are Frames, so popIn only scales them, at full opacity (RankedScreen:303-305). Target: CanvasGroup rows. `Kit.popIn` already fades GroupTransparency 1 -> 0.
2. Rows are `UDim2.new(1,-10,0.07,0)` inside an AutomaticCanvasSize list, which is a circular Scale. Target: a fixed 56 px row through toScale, tested with 15 fake entries.
3. The new empty-state crest and line appear without motion while the modal pops. Target: `Kit.popIn(crest, 0.08)`, then the label at 0.12.

## party: 9/10 (was 8.5)
1. On open, the async `GetFriendsOnline` calls `renderGrid()` (PartyScreen:374). That destroys the cards while they are still popping (the stagger and tween last about 0.53 s) and redraws them static, so the open pop is often cut off. Target: skip the redraw when the uid list is unchanged. Otherwise redraw with animate false, but only after the pop has finished (`task.delay(0.55)`) or when the Friends tab is the current tab.
2. The cards are Frames, so they pop at full opacity. Target: a 0.18 s tween of BackgroundTransparency 1 -> 0.25 inside the same delay, or CanvasGroup cards.

## playercard: 9.5/10 (unchanged)
1. A click-outside close still snaps the row to transparency 1 (PlayerCards:382). Target: `Kit.tween(m.row, 0.1, {BackgroundTransparency = 1})`.
2. The 2-player click-through Y test against `GuiService:GetGuiInset()` is still pending.

## inbox: 8/10 (unchanged)
1. popIn scales the rows at full opacity. Target: CanvasGroup rows, the same as the News blocks.
2. The age chip is a sibling with its own centre anchor, so it scales around (745, y+51) and not around the row's centre. Target: parent the chip to the row at (686, 31).
3. Change the literal 24 to `Theme.blur` (Notify:215).

## news: 10/10
Nit: use `Theme.blur` instead of the literal 24 (Notify:304).

## Top 8
1. Party: stop the friends-fetch redraw from cancelling the open pop (diff the uid list, or delay the redraw until 0.55 s).
2. Leaderboard: CanvasGroup rows at a fixed 56 px height.
3. Inbox: CanvasGroup rows, with the chip parented to its row.
4. Party: fade the cards in as well as scaling them.
5. Player menu: a 0.1 s un-light on a click-outside close.
6. Use `Theme.blur` in Notify (lines 215 and 304) instead of the literal 24.
7. Leaderboard: pop in the empty-state crest and line.
8. Player menu: the 2-player click-through Y test, plus a leaderboard stagger test with fake rows.

Remaining gap worth another round: yes
