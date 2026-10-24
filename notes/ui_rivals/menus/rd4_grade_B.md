# rd4 grade B (LOOK: typography, hierarchy, icons, finish, missing pieces)

Live-like data (Gold 2, 15-player Warlord board, inbox of 10). Design px = capture x 1.514; RIVALS 1456 refs x 1.319.
Landed since rd3: inbox per-type icons, age chip pinned top-right, rows ~101 px; headshots on every leaderboard row;
Play Ranked tile big emblem + "Gold 2" italic + shield. Not touched: ranked middle bar / ELO bar, pillars, medals, party, news.

## ranked: 7/10 (02_ranked_screen)
1. Middle bar: "Peak 905 ELO" 22 px centred in an empty 820 px bar -> mode rules 24 px left-aligned with " • " separators ("Standard duel gameplay • ..."), Peak moves under "Your ELO" as an 18 px line (02).
2. ELO bar 9 px, starts under the "800" label (x 392) and stops at 1528 -> 13 px, running icon edge to icon edge (x ~360 to ~1560) with the end badges overlapping it, as 02.
3. Selected/hovered tile has no frame -> 4 px white outline inset 6 px (02, 3v3 tile).

## ranks: 7/10 (05_rank_ladder)
1. Modal plate is translucent: the shield banner text reads through behind "Ranks" -> opaque plate (or 95% dim behind modal).
2. Pillars still flat rectangles -> tapered top (~70% of base) with the icon on the tip (05).
3. Third rules bullet is clipped at the plate bottom -> 24 px bottom fade or plate +60 px so the last bullet ends whole.

## rankedlb: 7/10 (no RIVALS ref; ranks modal family)
1. Top 3 still only coloured "#n", #2 reads plain white -> 34 px gold/silver/bronze medal in the rank column for #1-3 + 4 px left strip in the tone.
2. Same translucent plate: "Daily ELO Shield..." shows behind the column header -> opaque plate.
3. Column header Rank/Player/ELO 17 px grey -> 20 px, 70% white; 6 of 15 rows visible: plate +2 rows (~125 px) so the scroll reads as "more".

## party: 7/10 (rivals_rec player list ~150-165 s) - unchanged
1. No size readout -> "1/5" 28 px right of YOUR PARTY.
2. Crown clips off the headshot top-right -> 30 px crown inside the row, top-left of headshot.
3. "+" disc 73 px vs 26 px label -> disc 56 px, label 28 px 85% white.

## playercard: 8/10 (rv_playermenu; geometry settled)
1. Row labels ~20 px Medium -> 24 px Bold (RIVALS row weight).

## inbox: 8/10 (news_panel / tasks family)
1. "Friend joined" uses a play triangle -> person/friend glyph 52 px (the triangle reads as "play video").
2. Reward count overlaps the scissors (x1000 on the blades) -> icon 44 px, count 22 px below with 4 px gap, right-aligned to the age chip.
3. Age chip 13 px is near-unreadable -> 17 px, 60% white; "Weekly contract 16/20" gets a 6 px progress bar under the subtitle (tasks style).

## news: 8/10 (news_panel) - unchanged
1. "UPDATE 36" alone with a ~75 px dead band below -> 40 px glyph after it, band to 24 px.
2. Close 67x33 -> 67x36; bullet indent 34 -> 70 px (news_panel sub-indent).

## play: 8/10 (01_play_menu_ranked_tile)
1. "812 / 900" -> "812 ELO" 24 px (01: "393 ELO"); badge 150 -> ~200 px, shifted up so it crops at the tile top as 01.

## Top 8
1. Ranked middle bar filled with mode rules (ranked).
2. Opaque modal plates on Ranks + Leaderboard (ranks, rankedlb).
3. Leaderboard top-3 medals + edge strip (rankedlb).
4. ELO bar 13 px icon-to-icon (ranked).
5. Inbox reward count off the icon + friend glyph (inbox).
6. Tapered rank pillars + unclipped rules (ranks).
7. Party 1/5 + crown inside row (party).
8. Ranked tile "812 ELO" + cropped badge (play).

Remaining gap worth another round: yes
