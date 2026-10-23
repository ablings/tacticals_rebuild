# e3 grade C: interactivity and feel

Sources: e3 captures, the code in the brief, RIVALS t0285.4-t0286 (Ranked opens), t0155-t0156 (tile hover, scrollbar), `05_rank_ladder.jpg`, `rv_playermenu.jpg`, `news_panel.png`.

**What landed since e1:** the ranked popup panel is `Active = true` (RankedScreen.lua:163); the inbox and news `Dim` are TextButtons that close on an outside click and fade 1 -> 0.45 over 0.2 s (Notify.lua:166-169, 247-250); News is an article with a hero, "UPDATE 36" and headed items; the Party empty slots have `bindButton {1.03, 0.97}` (PartyScreen.lua:216). All four work as described.

## ranked: 8/10
1. Mode card hover is still 1.02 (line 312) -> 1.05 (t0155.3 vs t0156.6).
2. The popup shade still appears at 0.35 in one frame (`show()` only sets Visible) -> set it to 1 and tween it to 0.35 over 0.2 s, and fade it back out in `hide()` (t0285.4 -> t0286).

## ranks: 7/10
1. The ladder and rules are still fixed -> one ScrollingFrame (1220 x 620 at 40,110) with a 10 px white thumb (05_rank_ladder).
2. Emblem columns are static -> bindButton each column, hover 1.06, silent.

## rankedlb: 6/10
1. ScrollBarThickness is still 6 with the default colour (line 214) -> 10, white, ScrollBarImageTransparency 0.2 (05_rank_ladder).
2. Rows are added all at once -> `Kit.popIn(row, 0.04 + i*0.02)` for the first 12.

## party: 7/10
1. Hover on an empty slot only scales -> also tween BackgroundTransparency 0.35 -> 0.2 on enter and back on leave (t0155 tile brightens).
2. A tab switch or search rebuilds the grid with no motion -> popIn the first 9 cards (0.03 s stagger), and reset CanvasPosition to 0 on a tab change.
3. Grid scrollbar 6 px field-green (line 318) -> 10 px, white, 0.2.

## playercard: 7/10 (unchanged)
1. Open and close are silent (plain tweens, not Kit.open) -> `Kit.sfx("open")` in `Menu`, `Kit.sfx("close")` in `CloseMenu`.
2. The clicked list row isn't held -> keep it tinted while the menu is open (rv_playermenu: the "debits" row stays highlighted).

## inbox: 7/10
1. Rows are Frames, so popIn scales them at full opacity -> make row and chip CanvasGroups and fade GroupTransparency 1 -> 0 with the pop.
2. Blur is hard-coded 18 -> `Theme.blur`. Scrollbar 6 -> 10 px white.

## news: 6/10
Big step from e1: it reads as an article now. Still nothing to do in it.
1. No paging -> blue arrow button 66 x 36 under the X (1402, 177), pages to the previous update with a 0.15 s horizontal slide (news_panel.png).
2. The article is a clipped Frame, so a longer update is cut off -> ScrollingFrame with AutomaticCanvasSize Y and a 10 px thumb beside the panel (news_panel: bar at 1384,120).
3. Rows appear at once -> popIn each heading+bullet pair, 0.05 s stagger after the panel's open.

## Top 8
1. Ranked popups: shade fades in and out, not a hard cut.
2. News: arrow paging between updates.
3. News: scrolling article body.
4. One scrollbar spec everywhere: 10 px, white, 0.2 (leaderboard, party grid, inbox, news, ranks).
5. Player menu: open / close sounds; the clicked list row stays highlighted.
6. Ranks: scroll the ladder + rules; emblem hover 1.06.
7. Inbox rows as CanvasGroups so the pop fades; Party grid pops in on tab switch and search.
8. Ranked mode card hover 1.02 -> 1.05; leaderboard rows stagger in; Party empty slots brighten on hover.

Remaining gap worth another round: yes
