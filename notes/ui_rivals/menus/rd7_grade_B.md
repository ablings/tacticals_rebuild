# rd7 grade B (LOOK: typography, hierarchy, icons, finish, missing pieces)

Live-like data. Design px = capture x 1.514; RIVALS 1456 refs x 1.319.
Landed since rd4: rules strip with " • ", peak beside Your ELO, opaque modals, #1-3 edge strips, people glyph, reward count under the icon with commas.
Not landed: 13 px icon-to-icon ELO bar, selected-tile outline, tapered pillars, top-3 medals, party, news, play tile.

## ranked: 8/10 (02_ranked_screen)
1. ELO bar ~10 px, runs x 366-1553 and stops short of both badges -> 13 px, x ~330 to ~1590 with the end badges overlapping its ends (02).
2. Selected/hovered tile has no frame -> 4 px white outline inset 6 px (02, 3v3 tile).
3. Rules strip text ~21 px -> 24 px Medium, so it carries like the 02 strip.

## ranks: 8/10 (05_rank_ladder)
1. Pillars are flat rectangles -> tapered tops (~70% of base width) with the emblem sitting on the tip (05).
2. Third bullet now fades out mid-line at the plate bottom -> keep the fade but add a 6 px scroll thumb track that reads as scrollable, or plate +60 px (05 also crops, but under a visible thumb).

## rankedlb: 8/10 (ranks modal family; no RIVALS ref)
1. #1-3 have the strips but still only a coloured "#n" -> 34 px gold/silver/bronze medal in the rank column.
2. Column header Rank/Player/ELO ~17 px grey -> 20 px, 70% white.
3. Headshots ~36 px in 61 px rows -> 46 px; 6 of 15 rows visible -> plate +2 rows (~125 px).

## party: 7/10 (rivals_rec player list ~150-165 s) - unchanged again
1. No size readout -> "1/5" 28 px right of YOUR PARTY.
2. Crown clips off the headshot top-right -> 30 px crown inside the row, top-left of the headshot.
3. "+" disc 73 px vs 26 px label -> disc 56 px, label 28 px 85% white.

## playercard: 8/10 (rv_playermenu; geometry settled)
1. Row labels ~20 px -> 24 px Bold (RIVALS row weight).

## inbox: 8.5/10 (news_panel / tasks family)
1. Age chip ~12 px collides with the reward stack (sits on the scissors) -> 17 px, 60% white, reward stack moved down 10 px so 6 px clears between them.
2. Row-type glyphs ~33 px in a 55 px tile -> 40 px glyph (the inbox header megaphone is the size to match).
3. "Weekly contract 16/20" -> 6 px progress bar under the subtitle (tasks style).

## news: 8/10 (news_panel) - unchanged
1. "UPDATE 36" alone with a ~75 px dead band below -> 40 px glyph after it, band to 24 px.
2. Close 67x33 -> 67x36; bullet indent 34 -> 70 px (news_panel sub-indent).

## play: 8/10 (01_play_menu_ranked_tile) - unchanged
1. "812 / 900" -> "812 ELO" 24 px (01: "393 ELO"); badge 150 -> ~200 px, shifted up so it crops at the tile top as 01.

## Top 8
1. ELO bar 13 px icon-to-icon (ranked).
2. Leaderboard top-3 medals + 20 px header + bigger headshots (rankedlb).
3. Party 1/5 + crown inside the row + smaller "+" disc (party).
4. Tapered rank pillars (ranks).
5. Selected-tile white outline (ranked).
6. Inbox age chip clear of the reward stack (inbox).
7. Ranked tile "812 ELO" + cropped badge (play).
8. News dead band + bullet indent (news).

Remaining gap worth another round: yes
