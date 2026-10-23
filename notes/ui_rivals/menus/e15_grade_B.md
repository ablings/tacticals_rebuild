# e15 grade B: LOOK (typography, finish, icons, hierarchy)

All px are 1920x1080 design px (capture px x 1.514). I followed the Settled list: no weight, gloss, thin-outline or player-card geometry fixes.

What landed:
- Ranked: there are now shield glyphs at both ends of the banner text. They measure ~33 on the capture, and the ref's are ~32 at 1920 scale, so they match RIVALS 02. This closes my old fix 1.
- Leaderboard: the column heads (Rank / Player / ELO) are ~20 at about 60% white, so they now read as labels. The hint is ~22, about 8 under the empty line, and it is no longer a footnote. Both landed.

Not done (as stated): the Party crown chip and people glyph, and the pinned own row. Ranks, Player card, Inbox and News are unchanged from e14.

**ranked 9.5/10** (ref 02_ranked_screen), unchanged (the banner gap is closed)
1. The ELO "?" is ~41. Target: 48, the strip's largest glyph (ref "393").
2. "0/10" is ~33. Target: 38, with "Placed" at 22 on the same baseline (ref "138 Glory").
3. The mode-card corner badges are a 40 grey "?". Target: 56 (ref 1v1 flame shield ~58 at 1920 scale).

**ranks 9/10** (ref 05_rank_ladder), unchanged
1. The bar foot is ~21 from the first rule. Target: 36 (ref 483 -> 510).
2. The thumb is ~6 wide. Target: 8, with rounded ends.
3. The rules are ~23. Target: 25-26.

**rankedlb 8/10** (no LB ref; judged against the 05 modal), up from 7.5
1. There is no pinned own row. Target: a 64 own row at the foot, inset 12, with your rank at 28 bold.
2. The title has no glyph. Target: a 40 Warlord badge 12 left of "Warlord • Top 200" (ref 05: each rank title carries its badge).
3. The empty glyph is ~91 and floats. Target: 72, with 16 to the 26 empty line, centred as one block in the list area.

**party 8/10** (ref feel/rivals/playerlist), unchanged
1. There is no Leader mark. Target: a 28 crown chip at right-20 on your own row.
2. The empty state is text only. Target: a 64 people glyph, 16 above the 28 text.
3. The search field has no glyph. Target: a 28 magnifier at left-16, with the text indented to 52.

**playercard 7.5/10** (ref rv_playermenu), unchanged
1. The arrows are ~30. Target: 40 at right-16.
2. Other players' cards need rows for Add Friend, Spectate, Gift and Block, each with a 40 glyph.
3. There is no gap between the name row and View Profile. Target: 8.

**inbox 8/10** (no ref; judged against news_panel), unchanged
1. The "now" chip is ~16. Target: 20 at 60% white, at right-24.
2. The subtitle is ~20 with tight leading. Target: 22 at 70% white, with a 6 line gap.
3. The check has no backing. Target: a 56 rounded square at 8% white.

**news 8.5/10** (ref news_panel), unchanged
1. "UPDATE 36" has no glyph. Target: a 36 glyph 8 after it (ref bat after "UPDATE 24").
2. The section heads have no lead icon. Target: a 40 icon 10 before each head (ref pumpkin before "SPOOKY EVENT").
3. The body is ~21. Target: 24. The panel also runs to the screen foot; leave a bottom margin of 60 or more.

## Top 8
1. Party crown chip and empty-state glyph (party 1-2).
2. Leaderboard pinned own row (rankedlb 1).
3. Player card per-action rows and 40 arrows (playercard 1-2).
4. Ranked ELO "?" at 48, and "0/10" at 38 with "Placed" at 22 (ranked 1-2).
5. News UPDATE glyph and section-head icons (news 1-2).
6. Ranks gap of 36 and rules at 25-26 (ranks 1, 3).
7. Leaderboard title badge and a tighter empty block (rankedlb 2-3).
8. Inbox "now" chip, subtitle leading and check tile (inbox 1-3).

Remaining gap worth another round: yes
