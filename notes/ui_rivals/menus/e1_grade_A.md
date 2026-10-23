# e1 grade A: positioning and layout

All px are 1920x1080 design px (ours = capture x 1.514; RIVALS refs scaled the same way to their game area).

## ranked: 5/10 (ref 02_ranked_screen, 03_ranked_contract)
1. Mode cards: 480x379 landscape, gap 21 -> 465x604 portrait, gap 7, filling down to y 1032. Drop the PLAY bars: the whole card is the button; mode badge 64 px at the bottom left, inset 22.
2. Header: one 150 px tall plate at y 70 -> 66 px tall at y 134, split in 3 like RIVALS (status pill left / rules strip middle / Ranks button right). Close top 114 -> 134, same as the header top.
3. ELO bar: rank icon only at the left -> mirrored icons at both ends (current left, next right). Banner 55 -> 68 tall, with down-notches over each card centre. Warlord strip moves below the cards and scrolls, like the Contract.

## ranks: 5/10 (ref 05_rank_ladder, 06)
1. Modal 1299x756 at (310,160) -> 882x629 at (519,225).
2. Ladder: flat row of icons + chips at 151 pitch -> stepped podium, columns 92 wide, gap 8, bases aligned, heights 71 -> 338 rising left to right, icon on top of each column, name at the base.
3. Close 95x48 -> 108x62, 10 in from the top-right corner; left-aligned "Ranks" section heading at modal left +45.

## rankedlb: 5/10 (no RIVALS reference; judged against the 05 modal frame)
1. Frame 900x819 at (510,130) -> the same 882x629 at (519,225) as Ranks (right now the two sibling modals don't match).
2. Add a fixed column-header row (Rank / Player / ELO) 48 tall under the title; put the empty state in the middle of the list area, not right under the title.
3. Hide the full-height scrollbar when nothing scrolls.

## party: 4/10 (ref rivals_rec t0152 player picker)
1. List area 1302 wide and empty -> RIVALS rows: 93 tall, gap 12, avatar 72 at +24, name at +110, action button 144x78 inset 8 on the right. The empty state goes in the first row slot.
2. Empty slots: centred "+ Invite" text -> the same structure as a filled row (a 72 px "+" circle where the avatar sits, label at +110).
3. The "Invite" tooltip floats at (1222,920), away from everything -> anchor it to the hovered slot's right edge +12, centred vertically. "YOUR PARTY" goes into a header plate as wide as the column (like the 0/25 points plate).

## playercard: 7/10 (ref rv_playermenu)
1. Card top 101 -> 70 (RIVALS lines it up with the top of the player list). The width (302 vs 292) and the 6 px dock gap already match.
2. Rows 51 tall with a 3 gap -> 48 tall with a 7 gap; the arrow goes into a 48x48 darker cell flush right.
3. Header avatar 61 -> 79.

## inbox: 5/10 (no RIVALS inbox; judged against news_panel)
1. Row 562-1346 sits inset from the 540-1367 header -> the row uses the full header width.
2. The "1m ago" chip hangs outside the column at x 424 -> move it inside the row, right side above the reward, or as a left-aligned label above the row.
3. Column top 207 -> 119. The subtitle is centred under a left-aligned title -> left-align it at +60.

## news: 4/10 (ref news_panel)
1. The column x 540-1367 matches the ref (544-1376). Top 207 -> 119.
2. No hero -> a 827x465 (16:9) image at the top, then the version title right-aligned 48 below it.
3. Centred pill rows (text runs into the pill ends) -> flat left-aligned headings at +55 and bullets at +71. Stack a next-page arrow 67x36 under the close. Right now the lower 40% of the screen is empty.

## Top 8 across menus
1. Ranked cards to 465x604 portrait, gap 7, no PLAY bars.
2. Ranked header 150 -> 66 tall at y 134, in 3 blocks; close top lined up with it.
3. News: hero image + left-aligned body, column top 119.
4. Ranks modal 882x629 at (519,225) with a stepped podium ladder.
5. Party list in RIVALS row structure (93 rows, 72 avatar, 144x78 action); empty slots use the same structure.
6. Ranks and Leaderboard share one modal frame; Leaderboard gets a column-header row and no idle scrollbar.
7. Inbox rows full column width, timestamp inside the column, top 119.
8. Close buttons all over the place (121x62, 95x48, 85x50, 80x55, some top-aligned to the panel, some not) -> side-docked close 112x62 lined up with the panel top; in-modal close 108x62 inset 10.

Remaining gap worth another round: yes
