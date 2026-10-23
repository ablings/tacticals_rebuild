# e3 grade A: positioning and layout

1920x1080 design px (capture x 1.514; ref 02 scaled 1.319 to its game area).

## ranked: 6/10 (ref 02_ranked_screen)
The PLAY bars are gone (landed). The cards are 480x480, which is square, not tall. Ref cards are 466x564 with a 7 gap.
1. Cards 480x480 with a 21 gap -> 466x564, gap 7, top 400. Get the height by shrinking the header (fix 2). Add the mode badge (64 px, bottom-left, inset 22).
2. Header still one 150-tall plate at y 70 -> 66 tall at y 125, split in 3: status pill / rules strip / Ranks button. Close (112x56 at y 117) -> top 125, flush with the header.
3. ELO bar: next-rank icon + "threshold / name" labels mirrored at the right. Banner 54 -> 63 tall, with down-notches over each card centre.

## ranks: 5/10 (ref 05_rank_ladder). Unchanged.
1. Modal 1299x756 at (310,162) -> 882x629 at (519,225).
2. Flat icon row at 151 pitch -> stepped podium: columns 92 wide, gap 8, heights 71 -> 338.
3. Close 96x48 -> 108x62, inset 10.

## rankedlb: 5/10 (no ref; 05 modal frame). Unchanged.
1. 900x819 at (510,130) -> the Ranks frame, 882x629 at (519,225).
2. Column-header row 48 tall (Rank / Player / ELO); centre the empty state in the list area.
3. Hide the idle full-height scrollbar.

## party: 5/10 (rivals_rec t0152)
The empty slots are brighter (landed), but they are still a centred "+ Invite".
1. Empty slot -> filled-row structure: 72 px "+" circle at +24, "Invite" left-aligned at +110. Rows 341x106 -> 93 tall, gap 12.
2. The tooltip still floats at (1222,920) -> anchor it to the hovered slot's right edge +12, centred vertically.
3. "Nobody else here yet" floats at y 320 -> put it in the first row slot. "YOUR PARTY" goes into a 341-wide header plate.

## playercard: 7/10 (rv_playermenu). Unchanged.
1. Top 101 -> 68 (the top of the player list).
2. Rows 51 tall with a 3 gap -> 48 tall with a 7 gap; arrow in a 48x48 darker cell flush right.
3. Header avatar 61 -> 79.

## inbox: 5/10 (news_panel family). Outside-click close isn't visible in a capture; the layout is unchanged.
1. Column top 207 -> 120. It now sits 87 lower than its sibling News (120).
2. Row 562-1346 -> the full column width, 540-1367. The "3m ago" chip at x 424 sits outside the column -> put it inside the row, top-right.
3. Subtitle is centred under a left-aligned title -> left-align it at +60.

## news: 8/10 (news_panel). Landed.
Column 543-1376 and top 120 match the ref (544-1376 / 119). Heading x 580 and bullet x 615 match exactly. The version title is right-aligned (1361 vs 1366).
1. Hero 833x400 (2.08:1) -> 833x468 (16:9).
2. The panel stops at 1019 -> run it to the screen bottom and scroll, with a slim scrollbar 10 wide at panel right +8. Add the next-page arrow 67x36 at (1402,160) under the close.
3. Gap from version title to first heading 77 -> 117. Keep an even 90 heading pitch; the blank line before "Switch Weapons" makes it uneven.

## Top 8 across menus
1. Ranked cards 466x564, gap 7, top 400, with mode badge; the header shrunk to 66 at y 125 pays for the height.
2. Ranked header in 3 blocks; close top-aligned to it.
3. Ranks modal 882x629 at (519,225) with a stepped podium.
4. Party empty slots in filled-row structure ("+" circle at +24, label at +110); tooltip anchored to the slot.
5. Inbox top 207 -> 120 to match News; row full width; timestamp inside the row.
6. Leaderboard shares the Ranks frame, gets a column-header row, no idle scrollbar.
7. News hero to 16:9 (468 tall), the panel scrolls to the screen bottom, next arrow under the close.
8. Player card top 68, rows 48 with a 7 gap; closes unified (side-docked: top = panel top; in-modal: 108x62, inset 10).

Remaining gap worth another round: yes
