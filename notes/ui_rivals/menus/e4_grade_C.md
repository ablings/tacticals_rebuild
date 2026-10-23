# e4 grade C: interactivity and feel

Sources: e4 captures, the code in the brief (commit e9d0137), RIVALS t0285.4-t0286, t0155-t0156, `05_rank_ladder.jpg`, `rv_playermenu.jpg`, `news_panel.png`.

**What landed:** popup shade fades 1 -> 0.35 in 0.2 s with `Kit.open`, and back out in 0.12 s with `Kit.close` (RankedScreen.lua:172-180). Scrollbars are 10 px white 0.4 in leaderboard, party and inbox. The leaderboard hides its bar when there are 9 rows or fewer. `PlayerCards.Menu` / `CloseMenu` now play open / close sounds.

**Still wrong:**
- The e4_inbox capture still draws a full-height idle thumb at (1361, 277-1034) with only one row. Line 208 is meant to hide it but the bar still shows.
- `Menu` plays "open" and then calls `CloseMenu()`. Switching straight from one player's menu to another plays open and close on top of each other (PlayerCards.lua:406-408).

## ranked: 9/10
1. Mode card hover 1.02 (line 338) -> 1.05 (t0155.3 vs t0156.6).

## ranks: 7/10
The 882 x 800 modal fits the rules, so it no longer needs to scroll. The podium just appears all at once.
1. Pillars appear at once -> on open, tween each pillar's Size Y 0 -> h (anchor bottom, 0.25 s Quad Out, 0.03 s stagger left to right), with the emblem and ELO label riding on top (05_rank_ladder).
2. Pillars are static -> hover 1.04 on each pillar + emblem, silent.

## rankedlb: 7/10
1. Rows are added all at once -> `Kit.popIn(row, 0.04 + i*0.02)` for the first 12.
2. Rows are sized `UDim2.new(1,-10,0.07,0)` inside an AutomaticCanvasSize list. Scale Y there follows the canvas, so a full list can grow on itself -> fixed 56 px rows through toScale, like the inbox's maths. Check it with fake data.

## party: 7/10
1. Empty slot hover only scales -> also tween BackgroundTransparency 0.35 -> 0.2 and back (t0155).
2. Tab switch / search rebuilds with no motion -> popIn the first 9 cards (0.03 s stagger), CanvasPosition 0 on tab change.

## playercard: 8/10
1. Double sound on switch -> call `CloseMenu(true)` (silent) inside `Menu`, or play "open" after it.
2. Clicked list row not held -> keep it tinted while the menu is open (rv_playermenu: the "debits" row stays lit).

## inbox: 7/10
1. Idle scrollbar still visible (capture) -> when rows fit, set `ScrollBarThickness = 0` and `ScrollingEnabled = false` as well as transparency 1. The canvas equals the window exactly (768/768), so a 1 px rounding error is enough to show a bar. Then re-capture.
2. Rows and chip are Frames, so popIn scales them at full opacity -> make them CanvasGroups and fade GroupTransparency 1 -> 0 with the pop.
3. Blur is still hard-coded 18 (line 210) -> `Theme.blur`.

## news: 6/10 (unchanged)
1. No paging -> arrow button 66 x 36 under the X (1402, 177), 0.15 s horizontal slide to the previous update (news_panel.png).
2. Clipped article body -> ScrollingFrame with the e4 bar spec. Line 257 notes the canvas maths hid children: use the inbox's canvas-relative-to-parent fix.
3. Heading + bullet pairs appear at once -> popIn, 0.05 s stagger after open.

## Top 8
1. Inbox: hide the idle scrollbar for real (thickness 0 / ScrollingEnabled false), then re-capture.
2. Player menu: no open+close double sound when switching players.
3. News: arrow paging between updates.
4. News: scrolling article body.
5. Ranks: pillars rise in a stagger on open.
6. Ranked mode card hover 1.02 -> 1.05.
7. Leaderboard rows stagger in; fixed-height rows.
8. Inbox rows as CanvasGroups; Party grid pops on tab / search; empty slots brighten; player row stays lit.

Remaining gap worth another round: yes
