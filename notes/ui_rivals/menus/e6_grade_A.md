# e6 grade A: positioning and layout

1920x1080 design px (capture x 1.514; refs 02/05 x 1.319, news_panel 1:1, t0152 x 1.5).

## ranked: 8.5/10 (02_ranked_screen). Landed: badge 70 at bottom-left inset ~18 on all three cards.
1. ELO bar ends still bare: 64x80 emblem slot at bar left/right inset 30, labels moved to +100 / -100 ("?" left, Bronze 1 right).
2. Banner pointer tails: 3 tails 24x12 under the banner (y 374), centred on each card.
3. Badge inset 18 -> 22 (ref shield sits 22 in from left and bottom).

## ranks: 8.5/10 (05_rank_ladder). Landed: "Ranked" title, "Ranks" heading at +35 / y 329, podium lower, emblems 79-91.
1. Thumb is a 20-tall sliver at x 1378, y 745 inside the rules -> ref scrolls the whole modal body: track at modal right -18 from y 371 (heading top) to bottom -20, thumb >= 140 tall.
2. "Commander" label overflows its 97 column -> label 15 px (or columns 101, gap 4); still straight boxes, taper top to 75.
3. Podium base to first bullet 24 -> 37; rules text 21 -> 25 px (ref bullet size).

## rankedlb: 8/10 (05 frame). Not addressed.
1. Header row inset 40 vs Ranks heading inset 35: use 35 on both.
2. Header row top 326 -> 371 (on the Ranks heading line, under the title).
3. Empty text y 595 -> 640 (centre of list area 371-910 after the move).

## party: 7.5/10 (rivals_rec t0152). Landed: rows 91-93 at pitch 105, avatar 73 at +18, name at +110, right-pane plate.
1. Filled-row name is 21 px top-aligned with the handle under it -> name 30 px bold vertically centred, handle 16 px under it at +110 (ref names are the row's main text, bigger than "Invite").
2. "YOUR PARTY" sits at x 316 while the rows start at 300 -> left-align to 300, or put it in a 341x84 header plate (ref 0/25 plate) at the rows' left.
3. Right-pane plate is 188 tall for one line -> match the party column height (152-490 capture = 230-742) so both panes end on one line.

## playercard: 8/10 (rv_playermenu). Geometry settled; width 303 vs ref 290 and the gap to the list match. No layout fix this round.

## inbox: 7/10 (news_panel family). Not addressed.
1. Row title/body centred -> left-align at +80 beside the check.
2. Header-to-row gap 21 -> 12.
3. "now" chip at row top -> vertically centred at row right -24.

## news: 9/10 (news_panel). Landed: hero at (543,120) 822x468 vs ref (544,119) 832x468, panel to the bottom, UPDATE title at y 624 (ref 618).
1. Scrollbar sits inside the panel (x 1367-1375) and clips the hero -> move it outside: 9 wide at x 1384, close stays at 1402; hero back to 832.
2. Title-to-first-heading 89 -> 117 (first heading y 713 -> 735).
3. Blocks use a fixed 170 pitch so one-line blocks leave a 126 gap -> gap = text bottom + 60 to next heading centre (ref bullet 786 -> "Candy" 846).

## Top 8 across menus
1. Ranks: scroll the whole modal body, track at right -18, real-size thumb.
2. News scrollbar outside the panel at x 1384, hero 832 wide.
3. Party filled-row name 30 px bold centred; title aligned to the rows' left 300.
4. Ranked ELO bar end emblems + banner pointer tails.
5. LB header on the Ranks heading line (y 371, inset 35), empty text re-centred.
6. Inbox row text left at +80, gap 12, chip centred.
7. News block gap by content (+60), first heading +22.
8. Ranks "Commander" label fit, tapered columns.

Remaining gap worth another round: yes
