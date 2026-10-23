# e18 grade B: LOOK (typography, finish, icons, hierarchy)

All px are 1920x1080 design px (capture px x 1.514). I followed the Settled list: no fixes for font weight, gloss, thin outlines, player-card geometry or other-player rows.

What landed:
- Leaderboard title badge: there is now a gold Warlord badge before "Warlord • Top 200". It matches the ref 05 idea, where each title carries its badge. But it is ~48 tall (target 40) and sits ~42 left of the "W" (target 12). Because of that, badge plus title sit ~47 left of the panel centre (603 vs 634 capture), so the title no longer centres over the list.
- Own-row rank: "#-" is bold. Studio has no rank, so the "32" state can't be seen. The cap height still matches the name, so it leads by weight only.

Not done, as briefed: the Party glyph and magnifier, and the News icons. Ranked, Ranks, Party, Player card, Inbox and News look unchanged from e17 (the files differ only by recapture noise).

**ranked 9.5/10** (ref 02_ranked_screen), unchanged
1. The ELO "?" is ~41. Target: 48 (ref "393").
2. "0/10" is ~33. Target: 38, with "Placed" at 22 on the same baseline (ref "138 Glory").
3. The mode-card corner badges are 40. Target: 56 (ref flame shield).

**ranks 9/10** (ref 05_rank_ladder), unchanged
1. The bar foot is ~21 from the first rule. Target: 36.
2. The thumb is ~6 wide. Target: 8, with rounded ends.
3. The rules are ~23. Target: 25-26.

**rankedlb 9/10** (no LB ref; judged against the 05 modal), held. The badge is in but loosely set.
1. The title badge is 48, with a 42 gap. Target: 40 with a 12 gap, and centre badge plus title as one group on the panel (ref 05 title centred).
2. The rank "#-"/"32" is the same cap height as the name. Target: 28-30 (ref 05: the number leads).
3. The headshot is ~33. Target: 40, centred on the 61 row.

**party 8.5/10** (ref feel/rivals/playerlist), unchanged
1. The empty state is text only. Target: a 64 people glyph 16 above "Nobody else here yet" at 28, centred as one block.
2. The search field has no glyph. Target: a 28 magnifier at left-16, with the placeholder at 52.
3. The crown is ~45 and now clears the name by ~8. Target: 36, so it reads as a badge rather than a hat.

**playercard 9/10** (ref rv_playermenu), unchanged
1. The two rows are ~3 apart. Target: a 6 gap.
2. The "@ocxa" handle is ~17. Target: 20 at 70% white, 4 under the name.

**inbox 8/10** (no ref; judged against news_panel), unchanged
1. The "now" chip is ~16. Target: 20 at 60% white, at right-24.
2. The subtitle is ~20 with tight leading. Target: 22, with a 6 line gap.
3. The check has no backing. Target: a 56 rounded square at 8% white.

**news 8.5/10** (ref news_panel), unchanged
1. "UPDATE 36" has no glyph. Target: a 36 glyph 8 after it (ref bat).
2. The section heads have no icon. Target: a 40 icon 10 before each head (ref pumpkin).
3. The body is ~21. Target: 24, with a bottom margin of 60 or more.

## Top 8
1. Leaderboard badge at 40 with a 12 gap, and the group centred (rankedlb 1). This is cheap and fixes a regression in centring.
2. Party empty-state glyph and search magnifier (party 1-2). These are waiting on assets.
3. News UPDATE glyph and section icons (news 1-2). These are waiting on assets.
4. Ranked ELO "?" at 48, and "0/10" at 38 with "Placed" at 22 (ranked 1-2).
5. Leaderboard rank at 28-30 and headshot at 40 (rankedlb 2-3).
6. Inbox "now" chip, subtitle leading and check tile (inbox 1-3).
7. Ranks foot gap of 36 and rules at 25-26 (ranks 1, 3).
8. Player-card 6 row gap and handle at 20 (playercard 1-2).

Remaining gap worth another round: yes. Only for 1, 4-8 (sizing work, no assets) and the icons once they exist. Otherwise the returns are now small.
