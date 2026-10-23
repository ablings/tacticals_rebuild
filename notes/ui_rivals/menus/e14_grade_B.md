# e14 grade B: LOOK (typography, finish, icons, hierarchy)

All px are 1920x1080 design px (capture px x 1.514). I followed the Settled list: no weight, gloss, thin-outline or player-card geometry fixes.

What landed:
- Ranked: the status chip now reads "0/10" (~33) with a small "Placed" unit (~19). That is the "138 Glory" two-level read.
- Leaderboard: there is a hint line under the empty text at ~60% white. It is small (~17, target 22).
- Party: the "+" is now ~70% white, so the open slots are quiet and sit under your filled row.

Still open: banner shield glyphs, the crown chip, the pinned own row. Ranks, Player card, Inbox and News are unchanged from e13.

**ranked 9.5/10** (ref 02_ranked_screen), up from 9
1. The banner is still bare. Target: 40 shield glyphs, 16 in from each end of the text (ref "Daily ELO Shield").
2. The ELO "?" is ~30. Target: 48 bold, the strip's largest glyph (ref "393").
3. "0/10" is ~33. Target: 38, with "Placed" at 22, baselines aligned (ref 138 is ~37 at 1920 scale).

**ranks 9/10** (ref 05_rank_ladder), unchanged
1. The bar foot (~663) is ~12 from the first rule. Target: 36 (ref 483 -> 510).
2. The thumb is ~6 wide. Target: 8, with rounded ends.
3. The rules are ~23. Target: 25-26.

**rankedlb 7.5/10** (no LB ref; judged against the 05 modal), up from 7
1. There is no pinned own row. Target: a 64 own row at the foot, inset 12.
2. The header labels (Rank / Player / ELO) are ~23 at full white. Target: 20 at 60% white.
3. The hint is ~17. Target: 22, 8 below the empty line (it now reads as a footnote).

**party 8/10** (ref feel/rivals/playerlist), up from 7.5
1. There is no Leader mark. Target: a 28 crown chip at right-20, centred on your own row.
2. The empty state is text only. Target: a 64 people glyph, 16 above the 28 text.
3. The search field placeholder is ~22 at ~55% white. Target: a 28 magnifier glyph at left-16, with the text indented to 52.

**playercard 7.5/10** (ref rv_playermenu), unchanged
1. The arrows are ~30. Target: 40 at right-16.
2. Rows for other players: Add Friend, Spectate, Gift, Block, each with a 40 glyph.
3. There is no gap between the name row and View Profile. Target: 8.

**inbox 8/10** (no ref; judged against news_panel), unchanged
1. The "now" chip is ~16. Target: 20 at 60% white, at right-24.
2. The subtitle is ~20 with tight leading. Target: 22 at 70% white, with a 6 line gap.
3. The check has no backing. Target: a 56 rounded square at 8% white.

**news 8.5/10** (ref news_panel), unchanged
1. The thumb runs the full track. Target: 8 wide at 40% white, sized to the content.
2. "UPDATE 36" has no glyph. Target: a 36 glyph after it (ref bat glyph after "UPDATE 24").
3. The body is ~21. Target: 24.

## Top 8
1. Banner shield glyphs, and the ELO "?" at 48 (ranked 1-2).
2. Party crown chip and the empty-state glyph (party 1-2).
3. Leaderboard pinned own row (rankedlb 1).
4. Leaderboard headers at 20 / 60% white, and the hint at 22 (rankedlb 2-3).
5. Player card per-action rows and the 40 arrows (playercard 1-2).
6. Ranks gap of 36 and rules at 25-26 (ranks 1, 3).
7. News thumb sized to the content; Ranks thumb at 8 (news 1, ranks 2).
8. Inbox "now" chip, subtitle leading and check tile (inbox 1-3).

Remaining gap worth another round: yes
