# e3 grade B: LOOK (typography, finish, icons, hierarchy)

All px are 1920x1080 design px (capture px x 1.514). Landed since e1: tall Ranked tiles with no PLAY bar, News rebuilt as an article, brighter Party "+ Invite". Ranks, Leaderboard, player card and Inbox are unchanged.

**ranked 7/10** (ref 02_ranked_screen), up from 6
1. Tiles have no foot. Target: a 64 px white shield-flame glyph at bottom-left (x+24, y-24) on each tile, and a 4 px white outline on the hovered or selected tile (ref 3v3).
2. ELO bar: the ends are still empty and the duplicate 52 px `?` diamond is still at the left. Target: 64 px end badges, with "? / Placement" (28/24 px) stacked inside each end. Remove the duplicate.
3. Placement strip: the text is 24 px. Target: 30 px, with 40 px shield icons on both sides and a 24 px down-notch under each tile centre (ref).

**ranks 5/10** (ref 05_rank_ladder), unchanged
1. Pills: black 17 px text, and "Commander" overflows its pill. Target: podium bars 108 wide, 120 -> 360 tall, italic threshold 32 px above, tier name 20 px at the base.
2. Add a left-aligned 34 px "Ranks" section head under the 52 px title.
3. Rules: target 28 px text plus a 6 px scrollbar.

**rankedlb 5/10** (no LB ref; judged against the 05 modal), unchanged
1. Add a 36 px header row "# / Player / ELO" at 22 px, 60% white.
2. Add a 96 px Warlord crest above the empty text, with the text at 30 px.
3. Hide the full-height scrollbar when nothing scrolls.

**party 5/10** (ref feel/rivals/playerlist), up from 4
1. Empty plates are still about 8% white, so only the text got brighter. Target: plate at 14%, a 2 px 25% outline and a 32 px plus glyph. The text is 24 px; target 26 px.
2. Own row: name 21 px / handle 15 px. Target: 26/19 px, plus a device icon after the name.
3. The "Invite" tooltip still floats at 1222,920. Anchor it to the hovered slot, or drop it.

**playercard 6/10** (ref rv_playermenu), unchanged
1. Labels are 17 px. Target: 22 px, with 54 px rows and 6 px gaps.
2. On other players, colour rows per action (green Add Friend, purple Gift, red Block).
3. Header: target a 30 px name and a 64 px avatar.

**inbox 6/10** (no ref; judged against news_panel), unchanged
1. Left-align the subtitle under the title, at 22 px.
2. The "3m ago" chip sits outside the card at x 424-542. Move it inside, top-right, at 18 px.
3. "x50" overlaps the scissors. Target: icon 48 px, with 26 px text 4 px below it.

**news 7/10** (ref news_panel), up from 4
1. The hero is 833x398 (about 2.1:1, cropped). Target: 832x468 (16:9, ref), keeping the panel width.
2. Body: the bullets are bold, grey, 24 px, and the wrapped line returns under the bullet (x 615). Target: regular weight, 26 px, 85% white, with a hanging indent so wrapped lines start at the text (x 630). Headings go from 36 to 40 px. Gaps between entries are uneven (about 71 vs 97 px): set 48 px.
3. Missing pieces: add the blue 100x54 next-page arrow under the X (ref), a 6 px scrollbar to the right of the panel, and a 36 px glyph after "UPDATE 36".

## Top 8
1. Ranks: podium ladder in place of the black-on-colour pills (ranks 1).
2. ELO bar end badges, and remove the duplicate `?` (ranked 2).
3. News body type: regular weight, 26 px, hanging indent, even gaps (news 2).
4. Party plates: lighter fill, outline, plus glyph (party 1).
5. Ranked tile foot glyph and selected outline (ranked 1).
6. News hero at 16:9, plus the next arrow and scrollbar (news 1, 3).
7. Body text at least 22-28 px in Ranks, Party and the player card (ranks 3, party 2, playercard 1).
8. Inbox alignment and the chip and reward overlap (inbox 1-3).

Remaining gap worth another round: yes
