# e7 grade C: interactivity and feel

Sources: the e7 captures and sheet, the code at 7167c02, `05_rank_ladder.jpg`, `news_panel.png`, `rv_playermenu.jpg`, rivals_rec t0152-t0156.

**What landed:** Ranks columns now take hover. Each emblem `hold` has a UIScale that tweens to 1.1 over 0.12 s on `MouseEnter` and back on `MouseLeave` (RankedScreen:217-219). The News plate is now its own Frame. The ScrollingFrame is W + 22 wide and transparent, so its bar (9 px, transparency 0.6) runs in the gap right of the panel. The e7 capture shows it clear of the hero, and the X moved to 544 + W + 34 so it clears the bar.

**Not done (as stated):** the player-list row isn't lit while its menu is open, the News blocks don't pop in, and the Leaderboard rows don't pop in. The Ranks rules fade, the Party hover and grid motion, the inbox CanvasGroups and `Theme.blur` are also untouched.

## ranked: 10/10
No feel fixes left.

## ranks: 8.5/10 (was 8)
1. The lift grows from the wrong corner. `hold` keeps AnchorPoint (0,0), and UIScale scales from the anchor, so the 108 px emblem grows to about 119 px down and to the right. It slides about 11 px onto the ELO floor label (y 90) and toward the next column. Target: `hold` AnchorPoint (0.5, 0.5) at offset (49, 46), so it lifts in place (05_rank_ladder: the emblem stays centred over its pillar).
2. The rules still end in a hard cut at the modal's bottom. Target: a 24 px UIGradient fade (Transparency 1 -> 0) over the last 24 px of `Rules`.

## rankedlb: 7/10 (unchanged)
1. Rows still appear all at once. Target: `Kit.popIn(row, 0.04 + i*0.02)` for the first 12.
2. Rows are still `UDim2.new(1,-10,0.07,0)` in an automatic canvas (RankedScreen:290). Target: a fixed 56 px through toScale, tested with fake rows.

## party: 7/10 (unchanged)
1. Empty-slot hover only scales. Target: also tween BackgroundTransparency 0.35 -> 0.2 (t0155).
2. A tab change or search re-renders with no motion. Target: popIn the first 9 cards 0.03 s apart, and reset `grid.CanvasPosition` to zero on a tab change.

## playercard: 9/10 (unchanged)
1. The opener's row isn't held lit. Target: BackgroundTransparency 0.94 on that row until `CloseMenu`; on a one-click switch, move it to the new row (rv_playermenu).
2. The click-through Y still needs a 2-player test against `GuiService:GetGuiInset()` (rows are 40 px apart).

## inbox: 8/10 (unchanged)
1. popIn scales rows at full opacity. Target: CanvasGroup rows, GroupTransparency 1 -> 0 during the pop.
2. The blur is hard-coded 18 (Notify:215). Target: `Theme.blur`.

## news: 8/10 (was 7)
1. All blocks appear at once. Target: `Kit.popIn` per block 0.05 s apart, after a 0.15 s hero fade (the inbox's stagger at Notify:197-201).
2. The bar breaks the e4 single scrollbar style: here it is 9 px at 0.6, elsewhere 10 px at 0.4. Pick one style. Either keep 9 px at 0.6 and move the others to it, or go back to 10 px at 0.4 (still outside the plate with the 22 px gap).
3. The blur is hard-coded 18 (Notify:303). Target: `Theme.blur`.

## Top 8
1. Player menu: keep the opener's row lit, and test the click-through Y against the inset.
2. Ranks: centre the hover lift (AnchorPoint 0.5 on `hold`).
3. News: blocks stagger in after a hero fade.
4. Leaderboard: rows stagger in at a fixed 56 px height.
5. Ranks: a 24 px fade at the bottom of the rules.
6. Party: empty slots brighten on hover; the grid pops in and resets its scroll on a tab change.
7. Inbox: CanvasGroup rows for a real fade-in.
8. `Theme.blur` in the inbox and News, and one scrollbar style across menus.

Remaining gap worth another round: yes
