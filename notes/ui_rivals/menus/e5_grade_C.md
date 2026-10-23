# e5 grade C: interactivity and feel

Sources: the e5 captures, the brief's code at 9eebb4a (News lives in `Notify.lua`), `Tooltip.lua`, `05_rank_ladder.jpg`, `rv_playermenu.jpg`, `news_panel.png`, rivals_rec t0155-t0156.

**What landed:** the Ranks columns rise from the podium floor, 0.05 + i*0.04 s apart (0.3 s Quad Out), with the emblem and ELO riding on top, and they store `_Home` so a reopen replays cleanly. The Ranks rules scroll (6 rules, a 10 px thumb at 1373, 712-742). `Menu` now plays one sound (`CloseMenu(true)`), and the catcher wraps `CloseMenu`. The inbox idle bar is gone in the capture (thickness 0, ScrollingEnabled false). The Tooltip hides under a higher-DisplayOrder gui. Party empty slots look like rows now.

**New finding:** the PlayerCards catcher (DisplayOrder 12) covers the player list (LobbyHud, 7). Clicking another player's row while a menu is open only closes the menu, so it takes two clicks to switch. That also means the silent-switch path never runs from the mouse.

## ranked: 9/10
1. Mode card hover 1.02 (RankedScreen:367) -> 1.05 (t0155.3 vs t0156.6). Not changed since e4.

## ranks: 8/10
1. Pillars are static after the rise -> hover 1.04 on the column (pillar + emblem), silent (05_rank_ladder).
2. Rules are cut off flat at the window's bottom edge (y 742) -> a 24 px fade (UIGradient on a bottom strip) so the scroll reads as more content.

## rankedlb: 7/10 (unchanged)
1. Rows appear at once -> `Kit.popIn(row, 0.04 + i*0.02)` for the first 12.
2. Rows are `UDim2.new(1,-10,0.07,0)` in an AutomaticCanvasSize list, so Scale Y follows the canvas -> fixed 56 px rows through toScale (the inbox's maths). Test it with fake data.

## party: 7/10
1. Empty slot hover only scales -> also tween BackgroundTransparency 0.35 -> 0.2 and back (t0155).
2. `SetTab` / search call renderGrid with no motion -> popIn the first 9 cards (0.03 s stagger) and set `grid.CanvasPosition = 0` on a tab change.

## playercard: 8/10
1. The catcher swallows the click on another row -> in the catcher's handler, `CloseMenu(true)`, then `GetGuiObjectsAtPosition`. If a LobbyHud player row is hit, call `Menu(thatPlayer)` (one sound). Clicking the same row still just closes.
2. The clicked row isn't held -> keep it at BackgroundTransparency 0.94 while its menu is open (rv_playermenu: the row stays lit).

## inbox: 8/10
1. Rows and chip are Frames, so popIn scales them at full opacity -> CanvasGroups, with GroupTransparency 1 -> 0 during the pop.
2. Blur is hard-coded 18 (Notify:215, 288) -> `Theme.blur`, like Party.

## news: 6/10 (not addressed, as expected)
1. No paging -> a 66 x 36 arrow under the X (1402, 177), with a 0.15 s horizontal slide to the previous update (news_panel.png).
2. The body is a clipped Frame (H 900) -> a ScrollingFrame using the inbox's canvas-relative-to-parent fix and the 10 px bar.
3. Heading + bullet pairs appear at once -> popIn with a 0.05 s stagger after open.

## Top 8
1. Player menu: one click on another row switches menus (catcher pass-through).
2. News: arrow paging between updates.
3. News: scrolling article body.
4. Ranked mode card hover 1.02 -> 1.05.
5. Ranks: hover on each column, and a fade at the bottom of the rules.
6. Leaderboard: rows stagger in, at a fixed height.
7. Party: empty slots brighten on hover; the grid pops in and resets its scroll on a tab change.
8. Inbox: CanvasGroup rows; `Theme.blur` in the inbox and News; the clicked player row stays lit.

Remaining gap worth another round: yes
