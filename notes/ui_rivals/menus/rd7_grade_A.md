# rd7 grade A: positioning and layout (live-like data)

1920x1080 design px (capture x 1.514; ref 02/05/01 x 1.319, 01b x 2.637, news_panel 1:1, rv_playermenu x 2.2).

Landed since rd3: LB headshot on every row (all names at x 760, header "Player" over the avatar column); inbox chip on the
title line (right 1344) with the reward under it, rows to 1367, thumb outside at 1375-1384; Play Ranked tile emblem centred
(x 1452, y ~605, ~151) with the shield bottom-left (x 1266, y ~805, 55); ranked progress bar now runs icon to icon.

## ranked: 9/10 (02_ranked_screen)
1. ELO plate still 92 tall -> 105 (ref 172-251).
2. Tier icons still 68 -> 86, hugging the plate ends (ref 215-280 / 1176-1241).
3. Header chip star 42 -> 64, overhanging the 65-tall chip top/bottom like the ref Glory medal.

## ranks: 9.5/10 (05_rank_ladder)
Modal 519-1400 matches ref 520-1400; pillar foot to first bullet 27 (ref 26).
1. Optional: pillar gaps 3 -> 10 (ref ~8 at 1456).

## rankedlb: 9/10 (no RIVALS LB ref; 05 modal frame)
Name column fixed. One drift left:
1. Scroll rows still end at 1346 while header and own row end 1361; the thumb sits inside the header width (1352-1360). Rows -> 559-1361, thumb at 1370 outside, so ELO right edges line up at 1341 (rows now 1325, header 1343, own row 1341).
2. Own row "#15" x 578 vs row/header rank x 584: start all rank text at 584.

## party: 9.5/10 (rivals_rec t0152). Unchanged; list still empty.
1. Avatar / + circle 73 in a 91 row -> 84, name / handle x +11.
2. Handle 12 under the name baseline -> 4.

## playercard: 9/10 (rv_playermenu). Geometry settled; 5 gap to the player list. No fix.

## inbox: 9/10 (news_panel family)
Right column now holds. Remaining:
1. Reward stack is centred in a column (x 1270-1344), so "x300" ends at 1335 and "x1,000" at 1344: right-align icon and amount to 1344 under the timestamp.
2. Stack crowds the row foot (amount bottom 6 above the row edge; row 101 tall): icon 33 -> 30 and lift the stack so it sits in y row+20..row+92, 9 clear of the foot.
3. None further.

## news: 10/10 (news_panel). Panel 543-1376 x 120, close 1402-1469 x 120-153, header icon x 580, bullet 589 / text 615 (ref 617 / 627): matches.
1. Optional: 9x110 thumb at x 1384, y 119 (ref has one even on one article).

## play: 9.5/10 (01 / 01b)
Ranked tile matches ref layout: emblem centred, shield 37 above the tile foot (ref 39), rank/ELO centred over the shield line.
1. Optional: grid top 306 vs ref ~150; fine while nothing scrolls below it.
2. None further.

## Top 8 across menus
1. LB: scroll rows -> 559-1361, thumb outside at 1370; ELO right edges all 1341.
2. Ranked: ELO plate 92 -> 105 tall.
3. Ranked: tier icons 68 -> 86 at the plate ends.
4. Ranked: header chip star 42 -> 64, overhanging.
5. Inbox: right-align scissors + amount to 1344; lift stack 9 clear of the row foot.
6. Party: avatar 73 -> 84, handle 4 under the name.
7. LB: own row rank text x 578 -> 584.
8. Ranks: pillar gaps 3 -> 10 (optional).

Remaining gap worth another round: yes, but a short one (the three rd3 ranked-screen sizes and the LB row width are
still open; everything else is optional polish, so one fix round then close the layout lens)
