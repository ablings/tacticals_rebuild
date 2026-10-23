# e11 grade A: positioning and layout

1920x1080 design px (capture x 1.514; ref 05 x 1.319, news_panel 1:1, t0152 x 1.5).

## ranked: 9/10 (02_ranked_screen). Not addressed.
1. End badges almost on the plate edge (inset ~6) -> inset 28; track ends move in with them.
2. Label-to-badge gap 11 -> 26: "0" / "Placements played" x 362 -> 386, mirror right.
3. ELO plate height 92 -> 105 (ref 172-252), cards and banner +13.

## ranks: 9.5/10 (05_rank_ladder). Landed: "Ranks" heading inside the podium's top-left (x 554, y 324), Top 200 emblem top 322, level with it (ref 245 vs 252); podium base 707 -> 663; bar inset 26 from the modal right (ref 28); thumb top 298, 71 below the modal top (ref 88, fine, dropping my old "thumb on the heading line" ask). Rank names measure ~14 vs ref ~13: dropped.
1. Warlord pillar right edge 1364 nearly touches the bar (1369, gap 5) -> pillar row right 1354 (ref gap 11 x 1.319 = 15); shrink the 8 pillars 1-2 px each or start the row 10 left.
2. Base -> first rule bullet 21 -> 34 (ref 484 -> 510 = 26 x 1.319): first bullet 684 -> 697.
3. None further.

## rankedlb: 8/10 (05 frame). Not addressed. Now the odd one out next to Ranks, which shares its modal.
1. Header row inset 39 -> 35 (Ranks heading x 554).
2. Header row top 326 -> 324 (Ranks heading line); keeps one top line across both modals.
3. Empty text y 595 -> 640 (centre of the body under the header).

## party: 8/10 (rivals_rec t0152). Regression/overshoot.
1. Right-pane plate now runs 232 -> 987 (capture 653), 245 past the party column's last row (743). Target was the party column bottom: plate bottom 987 -> 743, empty text recentres to ~488. Looks like 742 was applied in a different unit (742 / 1.514 = 490 would be the capture line).
2. Avatar 73 in a 91 row -> 84, text x +11 (ref avatar ~88% of the row).
3. Handle 9 under the name baseline -> 4 (ref name and handle read as one block).

## playercard: 9/10 (rv_playermenu). Landed: name 28 / labels 21. Geometry settled; no layout fix.

## inbox: 8.5/10 (news_panel family). Not addressed.
1. Row title x 636 vs header title x 624 -> row text x 624, one left edge.
2. "now" chip inset ~65 from row right -> 24 (chip right x 1343).
3. Check icon 47 -> 56, centred at row x +48.

## news: 9/10 (news_panel). Not addressed.
1. Bar is a full-height grey strip (y 124-1045) -> proportional thumb 9x110 at y 119-229, faint or no track.
2. Close 85x48 at (1410,120) -> 67x36 at (1402,119).
3. Title -> first heading +91 -> +117; bullet -> next heading 86-94 -> 60.

## Top 8 across menus
1. Party: right-pane plate bottom 987 -> 743 (overshot; fourth round open).
2. News: 110 thumb, close 67x36, heading +117 / block pitch 60.
3. LB: header on the Ranks heading line (324, inset 35), empty text 640.
4. Ranked: end badges inset 28, label gap 26.
5. Inbox: row titles on the header's left edge (624), chip inset 24.
6. Ranks: 15 gap between the Warlord pillar and the bar; first rule 697.
7. Ranked: ELO plate 105 tall.
8. Party: avatar 84, handle tucked to 4.

Remaining gap worth another round: yes
