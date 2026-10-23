# e4 grade B: LOOK (typography, finish, icons, hierarchy)

All px are 1920x1080 design px (capture px x 1.514). Landed: the Ranks podium (top fix last round), the Leaderboard header row and centred empty state, the hidden LB scrollbar, Inbox at y 120 with full-width rows and the time chip inside. Ranked, Party, player card and News are unchanged.

**ranked 7/10** (ref 02_ranked_screen), unchanged
1. Tiles have no foot. Target: a 64 px white shield-flame glyph at bottom-left (x+24, y-24), and a 4 px white outline on the hovered tile.
2. ELO bar: the ends are empty and the duplicate 52 px `?` diamond is still there. Target: 64 px end badges with "? / Placement" (28/24 px). Remove the duplicate.
3. Placement strip text is 24 px. Target: 30 px, with 40 px shields at both ends.

**ranks 7/10** (ref 05_rank_ladder), up from 5
1. Tier names are about 14 px, upright and dark on the bar. Target: 20 px italic, 85% white, at the bar foot (ref "Bronze ... Archnemesis").
2. Thresholds are 21 px upright bold inside the bar top. Target: 30 px italic, sitting on the pillar just under the emblem. Emblems are about 60 px; target 88 px, overlapping the bar top by 20 px. Pillars are 91 wide with 9 px gaps; target 104 wide, tapering 10% to the top, gradient fading to 20% at the foot.
3. There is still no "Ranks" section head. Add a left-aligned 34 px head at x+40 under the 52 px title. Rules go from 20 to 26 px, with 10 px between bullets (the gap before the last bullet is double now).

**rankedlb 6/10** (no LB ref; judged against the 05 modal), up from 5
1. The empty state is plain 33 px text in a 680 px black void. Target: a 96 px Warlord crest above it, text 30 px, plus a 22 px 60% white line "Reach 2200 ELO to appear here".
2. Header row: 48 px tall with 22 px labels at 100% white. Target: 40 px tall, labels 60% white, columns at x+20 / x+150 / right-20.
3. Add your own pinned row at the foot (64 px, "- / debits / ?"), as RIVALS does in its ranked lists.

**party 5/10** (ref feel/rivals/playerlist), unchanged
1. Empty plates are about 8% white. Target: 14% fill, a 2 px 25% outline and a 32 px plus glyph; text 26 px.
2. Own row: name 21 px / handle 15 px. Target: 26/19 px, plus a device icon after the name.
3. The "Invite" tooltip still floats at 1222,920. Anchor it to the hovered slot, or drop it.

**playercard 6/10** (ref rv_playermenu), unchanged
1. Labels are 17 px. Target: 22 px, with 54 px rows and 6 px gaps.
2. On other players, colour rows per action (green Add Friend, purple Gift, red Block).
3. Header: target a 30 px name and a 64 px avatar.

**inbox 7/10** (no ref; judged against news_panel), up from 6
1. The scrollbar (x 1358-1367) now runs over the right end of the row and through the 20 px gap. Target: 6 px at x 1380, outside the panel, hidden when nothing scrolls.
2. Mixed alignment: the icon is left but the title and sub are centred. Target: left-align them at x+96 (title 32 px, sub 24 px at 70% white), like the News headings.
3. Corners don't match: the row is a full pill (50 px radius), the header 6 px. Target: 12 px on both. Subtitle goes from 20 to 22 px, regular weight.

**news 7/10** (ref news_panel), unchanged
1. The hero is 833x398 (about 2.1:1). Target: 832x468 (16:9).
2. Body bullets: bold, grey, 24 px, no hanging indent. Target: regular, 26 px, 85% white, wrapped lines starting at x 630. Headings go from 36 to 40 px, with even 48 px gaps (now about 71 vs 97).
3. Add the blue 100x54 next arrow under the X, a 6 px scrollbar, and a 36 px glyph after "UPDATE 36".

## Top 8
1. Ranks podium type: italic thresholds and names, bigger emblems overlapping the bars (ranks 1-2).
2. ELO bar end badges, and remove the duplicate `?` (ranked 2).
3. News body type: regular weight, 26 px, hanging indent, even gaps (news 2).
4. Party plates: lighter fill, outline, plus glyph (party 1).
5. Inbox: scrollbar outside the panel, rows left-aligned (inbox 1-2).
6. Leaderboard empty state: crest and hint line, own pinned row (rankedlb 1, 3).
7. Ranked tile foot glyph and hover outline (ranked 1).
8. Body text at least 22-26 px in the Ranks rules, Party and the player card (ranks 3, party 2, playercard 1).

Remaining gap worth another round: yes
