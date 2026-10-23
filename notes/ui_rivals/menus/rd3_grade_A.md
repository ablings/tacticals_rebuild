# rd3 grade A: positioning and layout (live-like data)

1920x1080 design px (capture x 1.514; ref 02/05 x 1.319, 01b x 2.637, news_panel 1:1, rv_playermenu x 2.2).

## ranked: 9/10 (02_ranked_screen, placed Bronze 2)
Frame, banner, cards (392-955 vs ref 425-987, same 563 tall) and Warlord strip all sit right.
1. ELO plate 94 -> 105 tall; tier icons 70 -> 86, hugging the plate ends (ref 215-280 / 1176-1241).
2. Progress bar 8 -> 11 thick, run icon-to-icon (ref 275-1180); ours stops at capture 1009, short of the right icon at 1032.
3. Header chip icon 39 -> 66, allowed to overhang the chip top/bottom like the ref Glory medal.

## ranks: 9.5/10 (05_rank_ladder)
Rules gap landed (pillar base to first bullet = 36, ref 36).
1. Optional: 10 gaps between pillars (ref ~8 at 1456); ours are ~2.

## rankedlb: 8.5/10 (no RIVALS LB ref; judged on the 05 modal frame)
Real rows expose column drift.
1. Player column: only your row has an avatar, so names sit at x 760 (yours) vs 693 (rest); header "Player" at 709. Add a 36 avatar to every row at x 711 so all names start at 760, header over the avatar.
2. Scroll rows end at 1346 while header and own row end 1361: rows -> 559-1361, scrollbar outside at 1370 (05 thumb sits outside the pillars). ELO right edge then aligns at 1341 in all three.
3. None further.

## party: 9.5/10 (rivals_rec t0152). Unchanged; lobby list still empty.
1. Avatar 73 in a 92 row -> 84, name / handle x +11.
2. Handle 9 under the name baseline -> 4.

## playercard: 9/10 (rv_playermenu). Geometry settled; abuts the player list (3 px gap, ref ~5). No fix.

## inbox: 8.5/10 (news_panel family)
Check icon fix landed (56). With rewards the right column breaks.
1. Timestamp jumps from right 1344 (plain rows) to 1260 (reward rows). Pin it at right 1344, top line with the title (y row+45); stack the scissors 46 + amount under it right-aligned to 1344.
2. Rows end 1357 under a header ending 1367; scrollbar touches the rows. Rows -> 1367, thumb outside at 1384 (news_panel thumb position).
3. None further.

## news: 10/10 (news_panel). Panel 543-1376 x 120, art foot 587, close 1402-1469: matches.
1. Optional: 9x110 thumb at x 1384, y 119.

## play: 8.5/10 (01b / 01 play menu)
Grid width 73% and row heights (274 / 275) match; Ranked tile width and close gap match.
1. Ranked tile: tier star sits bottom-left at 60. Ref: rank icon centred, ~145, at tile centre (x 1452, y ~628); flame shield 53 bottom-left (x 1266, y 802) as on the 1v1/2v2/3v3 cards.
2. Optional: grid top 306 vs ref ~13% (140); fine while nothing scrolls below it.
3. None further.

## Top 8 across menus
1. Play: Ranked tile rank icon -> centred 145; flame shield at bottom-left 53.
2. LB: avatar on every row, names at x 760.
3. LB: rows -> 559-1361, scrollbar outside at 1370.
4. Inbox: timestamp pinned right 1344 on the title line; reward stacked below it.
5. Inbox: rows to 1367, thumb outside at 1384.
6. Ranked: ELO plate 105 tall, tier icons 86, bar 11 thick icon-to-icon.
7. Ranked: header chip icon 39 -> 66, overhanging.
8. Party: avatar 73 -> 84, handle 4 under the name.

Remaining gap worth another round: yes (live data exposed real column drift in the Leaderboard and Inbox, and the placed Ranked tile on Play lacks the ref's centred rank icon; all are one-round fixes)
