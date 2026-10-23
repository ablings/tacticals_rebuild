# e4 grade A: positioning and layout

1920x1080 design px (capture x 1.514; ref 05 scaled 1.319 to its game area).

## ranked: 6/10 (02_ranked_screen). Unchanged.
1. Cards 480x480, gap 21 -> 466x564, gap 7, top 400, with a 64 px mode badge bottom-left at inset 22.
2. Header: one 150-tall plate at y 70 -> 66 tall at y 125, in 3 blocks (status pill / rules strip / Ranks button). Close top -> 125.
3. ELO bar: next-rank icon and "threshold / name" mirrored at the right.

## ranks: 7/10 (05_rank_ladder). Landed: podium and close.
The modal is 881x798 at (519,141). The close is 109x61 at inset 9, which matches the ref (108x58, inset 12). The podium columns are 91 wide with a 9 gap; the ref is 92 with an 8 gap.
1. Modal height 798 -> 629 at top 225, as in the ref. The ref scrolls the rules, so the rules block scrolls here too (slim bar 10 wide at modal right -12).
2. Column heights 71 -> 288 are too flat -> 110 -> 315. Taper each column (base 92, top 70). Sit the icon over the column top (overlapping by 20) with the "+ELO" label under it, not inside the column.
3. Add a left "Ranks" section heading at +51, y 262 (ref). Rules text ~20 px -> 26 px, starting 30 under the podium base.

## rankedlb: 7/10 (05 modal frame). Landed: shared frame, header row, centred empty state, no idle scrollbar.
The header row is 791x49 at (559,239), inset 39 each side. The empty state is centred at y 583 in the list area (288-939, centre 613).
1. Follow the Ranks modal to 882x629 at top 225 (keep the frame shared).
2. Header top 239 -> 262, so the gap under the title matches the Ranks section heading.
3. Empty state y 583 -> the true list centre (it moves with fix 1).

## party: 5/10 (rivals_rec t0152). Unchanged.
1. Empty slot -> filled-row structure: 72 "+" circle at +24, "Invite" at +110. Rows 106 -> 93 tall, gap 12.
2. Tooltip floating at (1222,920) -> anchor it at the hovered slot's right edge +12, centred vertically.
3. "Nobody else here yet" -> into the first slot. "YOUR PARTY" goes in a 341-wide header plate.

## playercard: 7/10 (rv_playermenu). Unchanged.
1. Top 101 -> 68.
2. Rows 51 tall with a 3 gap -> 48 tall with a 7 gap; arrow in a 48x48 darker cell flush right.
3. Header avatar 61 -> 79.

## inbox: 7/10 (news_panel family). Landed: top 120, full-width 540-1367, chip inside the row, close flush at 120.
1. The scrollbar (x 1359-1367) overlaps the row's right edge -> panel right +8 (x 1375), or hide it when not scrollable.
2. Row title is centred while the check icon is left -> left-align the title and body at +80 (news/tasks rows read left-to-right).
3. The subtitle sits at +24, under the icon, not the title (+83) -> indent it to +83. Header-to-row gap 21 -> 12.

## news: 8/10 (news_panel). Unchanged.
1. Hero 833x400 -> 833x468 (16:9).
2. Panel stops at 1019 -> run it to the screen bottom and scroll. Next-page arrow 67x36 at (1402,160).
3. Version-title-to-first-heading gap 77 -> 117. Even 90 heading pitch.

## Top 8 across menus
1. Ranked cards 466x564, gap 7, top 400, with mode badge, paid for by the 66-tall header.
2. Ranked header in 3 blocks at y 125; close top-aligned.
3. Ranks/LB shared modal 882x629 at top 225; rules scroll inside.
4. Podium heights 110 -> 315, tapered columns, icon over the top, label under the icon.
5. Party empty slots in filled-row structure; tooltip anchored to the slot.
6. Inbox scrollbar off the row (x 1375); row text left-aligned at +80; subtitle at +83.
7. News hero 16:9; panel scrolls to the bottom; next arrow under the close.
8. Player card top 68, rows 48 tall with a 7 gap, avatar 79.

Remaining gap worth another round: yes
