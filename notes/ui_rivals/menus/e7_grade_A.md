# e7 grade A: positioning and layout

1920x1080 design px (capture x 1.514; refs 02/05 x 1.319, news_panel 1:1, t0152 x 1.5).

## ranked: 8.5/10 (02_ranked_screen). Not addressed this round.
1. ELO bar ends still bare: 64x85 emblem slot at bar left/right (ref 284 / 1552), labels shift +100 / -100.
2. Banner pointer tails: 3 tails 24x12 under the banner (y 374), centred on each card.
3. Badge inset 18 -> 22.

## ranks: 8.5/10 (05_rank_ladder). Landed: labels fit their pillars.
1. Scroll still a 20-tall sliver at x 1387, y 745 inside the rules -> whole modal body scrolls; track at modal right -27 (x 1373, ref 1364-1373) from y 322 to bottom -20, thumb ~125 at top (ref).
2. Podium base sits at 731 (ref 637) so only 1.5 rules lines show (ref 3.5) -> raise the podium ~80: Bronze emblem top 560 -> 495, base 650, first bullet 674.
3. "Commander" fits only by shrinking (~13 vs 20 on the others) -> one label size for all 8 (ref: uniform), e.g. 16 on every pillar, or columns 101 with gap 4.

## rankedlb: 8/10 (05 frame). Not addressed.
1. Header row inset 40 -> 35 (match Ranks heading).
2. Header row top 326 -> 371 (Ranks heading line).
3. Empty text y 595 -> 640 (centre of 371-910).

## party: 8/10 (rivals_rec t0152). Landed: name bold with handle under, YOUR PARTY flush at x 300.
1. Name 30 is still small for a 91 row: ref name ~48 in a 105 row (46%) -> name 38 bold, handle 14 -> 20 (ref 24), handle overlapping name baseline -4 like ref.
2. Right-pane plate 230-418 still ends above the party column (742) -> plate height to 742 so both panes end on one line.
3. Filled row and Invite rows share 91 height/105 pitch (good); keep "Invite" the same size as the name (38) so all rows read as one list (ref).

## playercard: 8/10 (rv_playermenu). Geometry settled; no layout fix.

## inbox: 7/10 (news_panel family). Not addressed.
1. Row title/body centred (x 950) -> left-align at row +80 beside the check (x 620).
2. Header-to-row gap 23 -> 12.
3. "now" chip at row top (y 302) -> vertically centred at row right -24.

## news: 9/10 (news_panel). Landed: scrollbar outside the panel at x 1388-1397 in the gap, close at 1410, hero 833 wide.
1. Bar is a full-height grey strip (y 124-1048) -> proportional thumb, ref 9x110 at y 119-229, faint track or none.
2. Close 85x48 at (1410,120) -> ref 67x36 at (1402,119).
3. Spacing still loose: title 624 -> first heading 715 (ref 618 -> 735, +117: move headings down 26); bullet-to-next-heading centre 86-94 -> 60 (ref 786 -> 846).

## Top 8 across menus
1. Ranks: whole-modal scroll, track x 1373 from y 322, thumb ~125.
2. Ranks: podium base 731 -> 650 so 3+ rule lines show.
3. Party: name 30 -> 38, handle 20; right pane down to 742.
4. Ranked ELO bar end emblems + banner pointer tails.
5. LB header on the Ranks heading line (371, inset 35), empty text 640.
6. Inbox row text left at +80, gap 12, chip centred.
7. News: proportional 110 thumb, close 67x36, heading +117 / block pitch +60.
8. Ranks: one label size on all pillars.

Remaining gap worth another round: yes
