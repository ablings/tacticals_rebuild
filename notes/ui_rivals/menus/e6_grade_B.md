# e6 grade B: LOOK (typography, finish, icons, hierarchy)

All px are 1920x1080 design px (capture px x 1.514). Landed: Ranks emblems (now about 79-91 px), italic thresholds (~30) and names (~20), and the "Ranks" head. The ELO centre "?" is now ~45 px. The Ranked tiles got a foot badge. News has the hanging bullet, a scrolling article, and a hero at 822x468. The Inbox header is now left-aligned. Unchanged: rankedlb, party, player card.

**ranked 8/10** (ref 02_ranked_screen), unchanged
1. The ELO bar ends are still text only ("0 / Placements played", "10 / Rank reveal"). Target: 84 px end badges outside the text (left x+20, right -20), with the text inset to x+120. Use the "?" diamond on both ends while unranked.
2. The strip has no glyphs and no notches. Target: 40 px flat white shields 16 px from each end of the text, and three 20 px down-notches under the strip over the tile centres.
3. The header middle text is 21 px at 70% grey. Target: 26 px at 100% white, plus a 40 px "i" button at right-20 (ref's info box). The foot badge reads grey. Target: a flat white 64 px glyph, as in the ref shield.

**ranks 8/10** (ref 05_rank_ladder), unchanged
1. Bug: "Commander" is clipped ("Commande") and bleeds into the Warlord pillar. Target: fit the names at 18 px with a 4 px pad (or TextScaled with a 21 px cap).
2. The scrollbar is still a 12 px thumb at x 1378, y 746-765, inside the rules. Target: a 6 px white thumb about 125 px long at x 1385. It should start under the X (y 370), as the ref's bar does beside Top 200.
3. The rules are bold ~22 px in a ~98 px window (two bullets). Target: regular 26 px in a 150 px window, with the podium base raised 50 px. The pillars still don't taper or fade at the foot.

**rankedlb 6/10** (no LB ref; judged against the 05 modal), unchanged
1. The empty state is 28 px text in a black void. Target: a 96 px Warlord crest above 30 px text, plus a 22 px 60% white hint.
2. The header labels are near white. Target: 60% white.
3. A 64 px pinned own row at the foot.

**party 6/10** (ref feel/rivals/playerlist), unchanged
1. Own row: the name is 20 px and the handle 14 px. Target: 26/19 px, and a 28 px Leader crown chip at right-20.
2. The Invite plates have no edge. Target: a 2 px outline at 25% white.
3. "Nobody else here yet" is 23 px grey. Target: 28 px, with a 64 px people glyph above it.

**playercard 6/10** (ref rv_playermenu), unchanged
1. The labels are 17 px. Target: 21 px. Arrows go from 30 to 40 px.
2. The name is 20 px. Target: 28 px.
3. Per-action rows for other players (Add Friend, Gift, Block).

**inbox 7/10** (no ref; judged against news_panel)
1. The row is still centred ("Mission complete" at mid) while its check sits left. Target: left-align at x+96 (title 30, sub 22 at 70% white).
2. The row is a full pill and the header has 6 px corners. Target: 12 px corners on both.
3. The "now" chip is 17 px. Target: 20 px. The header sub goes from 20 px bold to 22 px regular.

**news 8/10** (ref news_panel), up from 7
1. The scrollbar sits flush on the hero's right edge (x 1366, 10 px grey, nearly full height). Target: 8 px in the gutter at panel right +12, 40% white, as in the ref (x 1384, beside the X).
2. The gaps before the headings are still uneven (73 vs 98 px). Target: 40 px after each body block. The body reads ~22 px semi-bold grey. Target: regular 24-26 px at 90% white.
3. A 36 px glyph after "UPDATE 36", and 12 px corners on the hero top.

## Top 8
1. Ranks: fix the clipped "Commander" (ranks 1).
2. Ranks scrollbar at the right edge, 125 px thumb (ranks 2).
3. ELO bar end badges (ranked 1).
4. News scrollbar in the gutter, and even 40 px heading gaps (news 1-2).
5. Ranked strip shields and notches, and the 26 px header text (ranked 2-3).
6. Rules at regular 26 px in a 150 px window (ranks 3).
7. Inbox row left-aligned, with 12 px corners (inbox 1-2).
8. Party own row type and outlined slots (party 1-2).

Remaining gap worth another round: yes
