# e5 grade B: LOOK (typography, finish, icons, hierarchy)

All px are 1920x1080 design px (capture px x 1.514). Landed: the Ranks podium type (italic thresholds and names, pillars 98 wide), the ELO bar end labels with the duplicate `?` removed, the 3-block Ranked header, the Party "+" circles (the floating tooltip is gone too), and no Inbox scrollbar when idle. Unchanged: rankedlb, player card, News.

**ranked 8/10** (ref 02_ranked_screen), up from 7
1. The ELO bar ends are text only. Target: 64 px end badges outside the text (x+20 left, right-20), as in "200 Bronze 2 [badge]". Our "?" diamond fits the left one.
2. The centre "?" is 33 px. Target: 40 px, matching "393". The "Your ELO" label goes from 18 to 20 px.
3. The tiles still have no foot. Target: a 64 px white shield glyph at bottom-left (x+24, y-24). The strip gets 40 px shields at both ends and three 20 px down-notches over the tile centres.

**ranks 8/10** (ref 05_rank_ladder), up from 7
1. Emblems measure 64 px (Bronze) to 76 px (Warlord), not 88. Target: 88 px, overlapping the bar top by 20 px. Thresholds measure about 26 px; target 30 px. Names measure about 17 px; target 20 px.
2. A short scrollbar thumb sits inside the rules text at x 1370, y 712-742. Target: a 6 px bar at the panel's right edge (x 1385), running from the podium top down (ref's white bar at the right).
3. There is still no "Ranks" section head. Add a 34 px left-aligned head at x+40. Rules are bold 23 px; target regular 26 px. Pillar taper and foot fade are not done yet (10% narrower at the top, fading to 20% at the foot).

**rankedlb 6/10** (no LB ref; judged against the 05 modal), unchanged
1. The empty state is 33 px text in a 600 px black void. Target: a 96 px Warlord crest, 30 px text, plus a 22 px 60% white hint line.
2. Header labels are 100% white. Target: 60% white, 40 px tall row.
3. Add a 64 px pinned own row at the foot.

**party 6/10** (ref feel/rivals/playerlist), up from 5
1. Own row: name 21 px / handle 15 px, and the right 60% of the plate is empty. Target: 26/19 px, a device icon after the name, and a 28 px "Leader" crown chip at right-20.
2. Empty plates have no edge. Target: a 2 px 25% white outline, so they read as slots.
3. "Nobody else here yet" is 23 px in an empty field. Target: 28 px with a 64 px people glyph above it, centred in the list area.

**playercard 6/10** (ref rv_playermenu), unchanged
1. Labels are 17 px. Target: 20-22 px, with 54 px rows. Arrow glyphs go from 30 to 40 px.
2. Header: the name is 21 px. Target: 28 px, avatar 64 px.
3. Rows per action on other players (green Add Friend, purple Gift, red Block), as in the ref.

**inbox 7/10** (no ref; judged against news_panel), unchanged score
1. The title and sub are still centred while the icon sits left. Target: left-align at x+96 (title 32 px, sub 24 px at 70% white).
2. The row is a full pill; the header has 6 px corners. Target: 12 px on both.
3. The "now" chip is 17 px. Target: 20 px. The header sub goes from 20 px bold to 22 px regular.

**news 7/10** (ref news_panel), unchanged
1. Body: bold grey 24 px, no hanging indent. Target: regular 26 px at 85% white, wrapped lines starting at the text after the bullet.
2. The gaps before the headings are uneven (71 vs 98 px). Target: 48 px on both. The hero goes from 833x400 to 832x468.
3. Add the blue 100x54 next arrow under the X, and a 36 px glyph after "UPDATE 36".

## Top 8
1. News body type and even gaps (news 1-2).
2. Ranks: 88 px emblems, 30/20 px type, a proper scrollbar (ranks 1-2).
3. ELO bar end badges, and a 40 px centre value (ranked 1-2).
4. Ranked tile foot glyph, plus strip shields and notches (ranked 3).
5. Inbox left alignment and matching corners (inbox 1-2).
6. Party own row type and outlined slots (party 1-2).
7. Player card type at 20-22 px, and per-action rows (playercard 1, 3).
8. Leaderboard empty-state crest and pinned own row (rankedlb 1, 3).

Remaining gap worth another round: yes
