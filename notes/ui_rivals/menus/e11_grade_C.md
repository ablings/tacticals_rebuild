# e11 grade C: interactivity and feel

Sources: the e11 captures and sheet, the code at e35f838, `05_rank_ladder.jpg`, `news_panel.png`, `rv_playermenu.jpg`, rivals_rec t0152-t0156.

**What landed (both):**
- Party: `renderGrid` pops in the first 9 cards 0.03 s apart (PartyScreen:273-281), and `SetTab` sets `grid.CanvasPosition = Vector2.zero` before it re-renders (PartyScreen:296).
- Ranks: PH 350 -> 370 (RankedScreen:207). The Warlord column's top is now y 30 and its emblem's top is y 22. At the 1.1 lift the top goes to about y 17, so nothing is clipped. The "Ranks" heading (4, 4, 300x50) clears every column's lift.

**Still open:** CanvasGroup rows for the leaderboard and inbox, the inbox chip parenting, `Theme.blur`, and the player-menu un-light.

## ranked: 10/10
No feel fixes left.

## ranks: 10/10 (was 9.5)
No feel fixes left.

## rankedlb: 7.5/10 (unchanged)
1. The rows are Frames, so popIn only scales them, at full opacity (RankedScreen:299-301). Target: CanvasGroup rows (`Kit.popIn` already fades GroupTransparency 1 -> 0).
2. Rows are `UDim2.new(1,-10,0.07,0)` inside an AutomaticCanvasSize list. That makes a circular Scale. Target: a fixed 56 px row through toScale, tested with 15 fake entries.

## party: 8.5/10 (was 7.5)
1. The cards have AnchorPoint (0,0), so the PopScale UIScale grows each one from its top-left corner. That makes the grid look like it slides down and right. Target: AnchorPoint (0.5,0.5) at (x+145, y+h/2) so each card grows in place, like the RIVALS player-list cards (t0155).
2. Every search keystroke, PlayerAdded/Removing and attribute change also calls `renderGrid`, so all 9 cards re-pop while you type or when someone joins. Target: `renderGrid(animate)`, with true only from `SetTab` and open. Search and roster refreshes should swap the cards in place.
3. The cards are Frames, so they pop at full opacity. Target: CanvasGroup cards, or a 0.18 s tween of BackgroundTransparency 1 -> 0.25.

## playercard: 9.5/10 (unchanged)
1. A click-outside close still snaps the row to transparency 1 (PlayerCards:382). Target: `Kit.tween(m.row, 0.1, {BackgroundTransparency = 1})`.
2. The 2-player click-through Y test against `GuiService:GetGuiInset()` is still pending.

## inbox: 8/10 (unchanged)
1. popIn scales the rows at full opacity. Target: CanvasGroup rows, the same as the News blocks.
2. The age chip is a sibling with its own centre anchor (Notify:192, 198), so it scales around (745, y+51), not the row's centre. Target: parent the chip to the row at (686, 31).
3. Change the literal 24 to `Theme.blur` (Notify:215, 224).

## news: 10/10
Nit: use `Theme.blur` instead of the literal 24 (Notify:304).

## Top 8
1. Party: centre-anchor the cards so the pop grows them in place.
2. Party: animate only on a tab change or open, not on each search keystroke or roster event.
3. Leaderboard: CanvasGroup rows at a fixed 56 px height.
4. Inbox: CanvasGroup rows, with the chip parented to its row.
5. Party: fade the cards in as well as scaling them.
6. Player menu: a 0.1 s un-light on a click-outside close.
7. Use `Theme.blur` in Notify instead of the literal 24.
8. Player menu: the 2-player click-through Y test, plus a leaderboard stagger test with fake rows.

Remaining gap worth another round: yes
