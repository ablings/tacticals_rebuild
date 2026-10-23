# e15 grade A: positioning and layout

1920x1080 design px (capture x 1.514; ref 02/05 x 1.319, news_panel 1:1, t0152 x 1.5).

## ranked: 9.5/10 (02_ranked_screen). Landed: banner shields beside the words (shield -> text gap ~20 vs ref ~17; banner 64 tall vs ref 63). Reads like 02.
1. ELO plate still ~94 tall (134-196 capture) -> 105 (ref 172-252), cards and banner +11.
2. None further.

## ranks: 9.5/10 (05_rank_ladder). Landed: Warlord pillar right ~893 capture vs scroll bar ~906 -> gap ~20 (target 15; fine).
1. Pillar base (663) -> first rule bullet centre ~684 (gap 21) -> 34: first bullet 697. Not addressed.
2. None further.

## rankedlb: 9.5/10 (05 frame). Unchanged.
1. Header row insets: left 39 (559 from panel 519), right 50 (1350 from 1400) -> both 39: header right 1361.
2. None further.

## party: 9.5/10 (rivals_rec t0152). Unchanged.
1. Avatar 73 in a 92 row -> 84, name / handle x +11.
2. Handle 9 under the name baseline -> 4.
3. None further.

## playercard: 9/10 (rv_playermenu). Geometry settled; no layout fix.

## inbox: 9/10 (news_panel family). Landed: row title "Mission complete" now starts at capture 412 = header title "Inbox" 412 (one left edge, 624 design).
Partly landed: the visible "now" text ends at capture ~860 vs row right 902 -> ~64 design in. If the chip frame sits 24 in, its text is centred in a wide box; right-align the label inside it (TextXAlignment Right) so the glyphs end at 1343.
1. "now" glyph right ~1302 -> 1343 (24 in from row right 1367).
2. Check icon 48 -> 56, centred at row x +48.
3. None further.

## news: 9.5/10 (news_panel). Unchanged (not done this round, as noted).
1. Close 85x48 at (1410,120) -> 67x36 at (1402,119) (ref 1402-1468 x 119-155).
2. Add the ref's thin thumb 9x110 at x 1384-1393, y 119-229, no track (the body runs off the screen bottom, so it scrolls).
3. Bullet -> next heading 64-68 -> 60 (optional).

## Top 8 across menus
1. News: close 67x36 at (1402,119).
2. News: 9x110 scroll thumb at x 1384, y 119.
3. Inbox: "now" glyphs right-aligned to 1343 (24 in).
4. Ranks: first rule bullet 697 (34 under the pillar base).
5. Party: avatar 84, handle tucked to 4.
6. Ranked: ELO plate 105 tall.
7. LB: header right inset 50 -> 39.
8. Inbox: check icon 56.

Remaining gap worth another round: yes (small; news chrome is the last 1-point item, the rest are polish)
