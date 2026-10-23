# e10 grade C: interactivity and feel

Sources: the e10 captures and sheet, the code at 6a3236a, `05_rank_ladder.jpg`, `news_panel.png`, `rv_playermenu.jpg`, rivals_rec t0152-t0156.

**What landed (all five):**
- Leaderboard: `Kit.popIn(row, 0.04 + i*0.02)` for the first 12 rows (RankedScreen:299).
- Party: empty slots tween BackgroundTransparency 0.35 -> 0.2 over 0.1 s on hover, on top of the bindButton scale (PartyScreen:221-223).
- Inbox and News: the blur goes to 24 (Notify:215, 304). It is the literal 24, not `Theme.blur`. That matches today, but it will drift if the theme changes.
- News: the hero's background fades with its image (Notify:311-312), so the black box is gone.
- Ranks: one `Body` ScrollingFrame with PaddingBottom 24, and `rise()` resets `CanvasPosition` to zero (RankedScreen:193-197, 264). The bar sits at the modal edge, clear of the fade.

**Still open:** Party grid motion and its scroll reset, the inbox CanvasGroup rows and chip parenting, the player-menu un-light, and Leaderboard rows sized in Scale.

## ranked: 10/10
No feel fixes left.

## ranks: 9.5/10 (unchanged)
1. The podium has `ClipsDescendants` on so the columns can rise into it. But the Warlord column's top is y 10, and its emblem holder (108 tall, centre 46) starts at -8. In e10_ranks the art already almost touches the clip line (capture y 241). The 1.1 hover lift will crop about 3 px off its top. Target: PH 350 -> 370 with the columns' offsets unchanged, which gives 20 px of headroom (05: the Warlord emblem stands free).

## rankedlb: 7.5/10 (was 7)
1. The rows are Frames, so popIn only scales them, at full opacity. Target: CanvasGroup rows (GroupTransparency 1 -> 0 is already in `Kit.popIn`).
2. Rows are still `UDim2.new(1,-10,0.07,0)` inside an AutomaticCanvasSize list, which is a circular Scale. Target: a fixed 56 px row through toScale, tested with 15 fake entries.

## party: 7.5/10 (was 7)
1. A tab change or search re-renders with no motion. Target: popIn the first 9 cards 0.03 s apart.
2. The grid keeps its old scroll on a tab change. Target: `grid.CanvasPosition = Vector2.zero` in `SetTab` (t0155).

## playercard: 9.5/10 (unchanged)
1. A click-outside close still snaps the row from 0.94 to 1 (PlayerCards:382). Target: `Kit.tween(m.row, 0.1, {BackgroundTransparency = 1})`.
2. The 2-player click-through Y test against `GuiService:GetGuiInset()` is still pending.

## inbox: 8/10 (unchanged)
1. popIn scales the rows at full opacity. Target: CanvasGroup rows, the same as the News blocks.
2. The age chip is a sibling with its own centre anchor (Notify:192, 198), so it scales around (745, y+51), not the row's centre. Target: parent the chip to the row at (686, 31).
3. Literal 24 -> `Theme.blur` (Notify:215, 224).

## news: 10/10 (was 9.5)
Only a nit is left: use `Theme.blur` instead of the literal 24 (Notify:304).

## Top 8
1. Party: popIn the grid and reset its scroll on a tab change.
2. Leaderboard: CanvasGroup rows at a fixed 56 px height.
3. Inbox: CanvasGroup rows, with the chip parented to its row.
4. Ranks: 20 px of podium headroom, so the Warlord emblem's hover lift isn't clipped.
5. Player menu: a 0.1 s un-light on a click-outside close.
6. Use `Theme.blur` in Notify instead of the literal 24.
7. Player menu: the 2-player click-through Y test.
8. Leaderboard: test the stagger with fake rows (Studio shows only the empty state).

Remaining gap worth another round: yes
