# e17 grade B: LOOK (typography, finish, icons, hierarchy)

All px are 1920x1080 design px (capture px x 1.514). I followed the Settled list: no fixes for font weight, gloss, thin outlines or player-card geometry, and none asking for other-player rows on the Studio card.

What landed:
- Leaderboard own row: "#-" is now bold, and there is a headshot before the name. The headshot is ~36 (close to the 40 target), sits under the "Player" column head and is ~14 clear of "debits". It now reads as a proper list row. The rank's cap height still measures the same as the name's, so the jump to 28 barely shows. Only the weight change reads.
- Player card: the arrows are ~39 (target 40), and there is an ~8 gap between the name row and View Profile. Both are done and now match rv_playermenu's right-edge glyph column.

Not done: the Party people glyph and search magnifier, and the Leaderboard title badge. Ranked, Ranks, Party, Inbox and News are unchanged from e16.

**ranked 9.5/10** (ref 02_ranked_screen), unchanged
1. The ELO "?" is ~41. Target: 48 (ref "393").
2. "0/10" is ~33. Target: 38, with "Placed" at 22 on the same baseline (ref "138 Glory").
3. The mode-card corner badges are a 40 "?". Target: 56 (ref 1v1 flame shield).

**ranks 9/10** (ref 05_rank_ladder), unchanged
1. The bar foot is ~21 from the first rule. Target: 36.
2. The thumb is ~6 wide. Target: 8, with rounded ends.
3. The rules are ~23. Target: 25-26.

**rankedlb 9/10** (no LB ref; judged against the 05 modal), up from 8.5
1. The title has no glyph. Target: a 40 Warlord badge 12 left of "Warlord • Top 200" (ref 05: each title carries its badge).
2. The rank "#-" is the same visual size as the name. Target: 28-30, so it leads (ref 05: the tier number leads).
3. The headshot is ~36. Target: 40, centred on the 61 row.

**party 8.5/10** (ref feel/rivals/playerlist), unchanged
1. The empty state is text only. Target: a 64 people glyph 16 above the 28 "Nobody else here yet", centred as one block.
2. The search field has no glyph. Target: a 28 magnifier at left-16, with the placeholder indented to 52.
3. The crown (~45) overlaps the "d" of "debits". Target: 36, keeping 8 clear of the name.

**playercard 9/10** (ref rv_playermenu), up from 8
1. The two rows touch, with ~3 between them. Target: a 6 gap, as the ref rows are separated.
2. The "@ocxa" handle is ~17. Target: 20 at 70% white, 4 under the name (ref "@McFly_82" sits tight under the name).

**inbox 8/10** (no ref; judged against news_panel), unchanged
1. The "now" chip is ~16. Target: 20 at 60% white, at right-24.
2. The subtitle is ~20 with tight leading. Target: 22, with a 6 line gap.
3. The check has no backing. Target: a 56 rounded square at 8% white.

**news 8.5/10** (ref news_panel), unchanged
1. "UPDATE 36" has no glyph. Target: a 36 glyph 8 after it (ref bat after "UPDATE 24").
2. The section heads have no lead icon. Target: a 40 icon 10 before each head (ref pumpkin before "SPOOKY EVENT").
3. The body is ~21. Target: 24, with a bottom margin of 60 or more.

## Top 8
1. Party empty-state glyph and search magnifier (party 1-2).
2. Leaderboard title badge (rankedlb 1).
3. News UPDATE glyph and section-head icons (news 1-2).
4. Ranked ELO "?" at 48, and "0/10" at 38 with "Placed" at 22 (ranked 1-2).
5. Leaderboard rank visibly larger, at 28-30 (rankedlb 2).
6. Party crown at 36, clear of the name (party 3).
7. Ranks gap of 36 and rules at 25-26 (ranks 1, 3).
8. Inbox "now" chip, subtitle leading and check tile (inbox 1-3).

Remaining gap worth another round: yes
