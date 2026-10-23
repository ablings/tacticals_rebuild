# e5 grade A: positioning and layout

1920x1080 design px (capture x 1.514; refs 02/05 scaled 1.319 to the game area).

## ranked: 8/10 (02_ranked_screen). Landed: 3-block header 65 tall at y 126, ELO bar 95 at 203, banner 64 at 310, cards 466x563 gap 6 at y 392, Warlord strip at 967.
1. Mode badge still missing: add a 63x63 shield/emblem at the card's bottom-left, inset 22 (ref: the flame shield on every card).
2. ELO bar ends are bare: put a 64x80 emblem slot at the bar's left and right (inset 30), with the text at +100 / -100 ("?" placement emblem left, Bronze 1 emblem right).
3. Banner: add 3 pointer tails (24x12) under the banner, centred on each card (ref 02).

## ranks: 8/10 (05_rank_ladder). Landed: modal 881x626 at (519,226), podium columns 97 wide, 107 -> 310 tall.
1. Add the left "Ranks" section heading at +51, y 262 (26 px bold); push the podium down 40 so the Top 200 emblem clears the title.
2. Columns are straight boxes -> taper them (base 97, top 75) as in the ref. Emblems read 64-76, not 88: set every emblem to 88.
3. The scroll thumb sits inside the rules text at x 1370, y 712-742 -> move it to modal right -18, running from y 262 to the modal bottom -20, and hide it when the rules fit.

## rankedlb: 8/10 (05 modal frame). Landed: shared 881x626 frame.
1. Header row insets 39 while the Ranks podium/rules inset 33/30: use one content inset (39) on both modals.
2. Header row top 326 -> 300 (under the title, in line with the Ranks heading line).
3. Empty state y 595 -> 612 (true centre of the list area 371-852).

## party: 6/10 (rivals_rec t0152). Landed: 73 "+" circle, "Invite" at +110.
1. Rows still 106 tall with a 12 gap -> 93 tall, gap 12 (ref).
2. Filled row does not line up with the empty rows: avatar 64 at +12, name at +86 -> avatar 73 at +18, name at +110, name 30 px bold vertically centred (ref names are the row's main text).
3. "Nobody else here yet" still floats at y 321 in the right pane -> centre it in the list area, or drop it; "YOUR PARTY" goes into a 341-wide header plate 84 tall (ref 0/25 plate).

## playercard: 7/10 (rv_playermenu). Not addressed.
1. Top 101 -> 68.
2. Rows 51 tall, gap 3 -> 48 tall, gap 7; arrow in a 48x48 darker cell flush right.
3. Header avatar 61 -> 79.

## inbox: 7/10 (news_panel family). Landed: scrollbar no longer overlaps.
1. Row title and body are centred -> left-align them at +80 (beside the check icon).
2. Header-to-row gap 21 -> 12.
3. "now" chip at row top -> centre it vertically at row right -24.

## news: 8/10 (news_panel). Not addressed.
1. Hero 833x400 -> 833x468 (16:9).
2. Panel stops at 1019 -> run it to the screen bottom and scroll; next-page arrow 67x36 under the close.
3. Version-title-to-first-heading gap 77 -> 117; the gap after the one-line bullet (97) matches the two-line one (70): fix the item height to its text.

## Top 8 across menus
1. Ranked mode badge 63 px bottom-left at inset 22 on every card.
2. Ranks: "Ranks" heading at y 262, podium down 40, tapered columns, all emblems 88.
3. Ranks scroll thumb at modal right -18, hidden when not needed.
4. Party rows 93 tall; filled row aligned to the empty rows (avatar 73 at +18, name at +110).
5. Player card top 68, rows 48 with a 7 gap, avatar 79.
6. News hero 16:9, panel to the bottom with scroll.
7. Inbox row text left-aligned at +80, header gap 12.
8. ELO bar end emblems; one shared 39 inset across the Ranks/LB modals.

Remaining gap worth another round: yes
