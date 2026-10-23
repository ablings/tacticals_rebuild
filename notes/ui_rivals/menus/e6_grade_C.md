# e6 grade C: interactivity and feel

Sources: the e6 captures, the code at 32751b5, `rv_playermenu.jpg`, `news_panel.png`, `05_rank_ladder.jpg`, rivals_rec t0152-t0156.

**What landed:** the PlayerCards catcher calls `GetGuiObjectsAtPosition` and, on another player's `Rows` button, opens that menu in one click with one sound (`Menu` plays open, its `CloseMenu(true)` is silent). Clicking the same row still just closes it. Ranked mode cards hover 1.05 / press 0.97. News is a ScrollingFrame with `AutomaticCanvasSize` Y and a UIListLayout of fixed-height blocks. The capture shows a live thumb at x 902, so the article scrolls.

**Not touched this round:** the Ranks hover and fade, the Leaderboard stagger and row height, the Party hover and grid motion, the inbox CanvasGroups, `Theme.blur`, and the lit row.

## ranked: 10/10
No feel fixes left.

## ranks: 8/10 (unchanged)
1. Columns don't react after they rise. Target: hover 1.04 on the column (pillar + emblem), silent (05_rank_ladder).
2. The rules end in a flat cut at the modal's bottom edge. Target: a 24 px fade strip (UIGradient Transparency 1 -> 0) over the last 24 px of `Rules`.

## rankedlb: 7/10 (unchanged)
1. Rows appear all at once. Target: `Kit.popIn(row, 0.04 + i*0.02)` for the first 12.
2. Rows are `UDim2.new(1,-10,0.07,0)` (RankedScreen:278, 284) inside an automatic canvas. Target: fixed 56 px through toScale. Test it with fake rows.

## party: 7/10
1. Empty-slot hover only scales. Target: also tween BackgroundTransparency 0.35 -> 0.2 and back (t0155).
2. `SetTab` / search re-render with no motion. Target: popIn the first 9 cards (0.03 s apart) and set `grid.CanvasPosition = Vector2.zero` on a tab change.

## playercard: 9/10
1. The row isn't held while its menu is open. Target: BackgroundTransparency 0.94 on the opener's row until `CloseMenu`; on a switch, move it to the new row (rv_playermenu: the row stays lit).
2. Check the click-through position: it uses `input.Position` as given. Rows are only 40 px apart, so a top-bar inset mismatch would pick the next row. Test with 2 players, clicking near a row's top and bottom edges. If it's off, add `GuiService:GetGuiInset()` to Y (the same correction as line 638).

## inbox: 8/10 (unchanged)
1. Rows and the chip are Frames, so popIn scales them at full opacity. Target: CanvasGroups with GroupTransparency 1 -> 0 during the pop.
2. Blur is hard-coded at 18 (Notify:215). Target: `Theme.blur`.

## news: 7/10 (was 6)
1. The hero is W = 832 wide, so the 10 px scrollbar draws over its right edge (capture x 902-908, y 84-385). Target: hero `W - 12` like the blocks, or `ScrollBarInset = ScrollBar`.
2. The heading + bullet blocks appear all at once. Target: `Kit.popIn` per block, 0.05 s apart after open (the inbox's stagger). The hero fades in over 0.15 s.
3. Blur is hard-coded at 18 (Notify:299). Target: `Theme.blur`.

## Top 8
1. Player menu: keep the opener's row lit, and test the click-through Y against the inset.
2. News: keep the scrollbar off the hero.
3. News: blocks stagger in.
4. Ranks: hover on each column, and a 24 px fade at the bottom of the rules.
5. Leaderboard: rows stagger in at a fixed 56 px height.
6. Party: empty slots brighten on hover; the grid pops in and resets its scroll on a tab change.
7. Inbox: CanvasGroup rows for a real fade-in.
8. `Theme.blur` in the inbox and News.

Remaining gap worth another round: yes
