# m26 grade A: positioning and layout

**Moved away from RIVALS: yes, on found.** The m25 tip-inset fix overshot and came out lopsided. I measured the white bubble and the dark glyphs pixel by pixel, in design px (1920 wide):

| | bubble x | width | text inset L | text inset R | bubble y |
|---|---|---|---|---|---|
| m17 (last found) | 241-925 | 684 | 12 | 35 | 92.6-97.3 % |
| **m26** | 241-945 | 704 | **35** | **65** | 92.6-97.3 % |
| t0022 | 240-1416 | 1176 | 20 | 20 | 92.6-97.3 % |

The left inset is now 15 px too wide (it was 8 px short) and the right one is 45 px too wide (it was 15). The bubble's left edge, height (51-52) and vertical band match t0022 exactly, and the glyph height is 28.8 vs 30, so the inset is the only gap. Cause (`MatchFoundGate.lua` lines 206-207): `inset = h * 0.85` uses the label height (about 26 capture px), which gives about 22 capture px = 35 design px. The `* 1.08` width fudge adds about 22 more capture px, and with left-aligned text all of that spare width ends up on the right.

No other screen moved: vote and loadout are pixel-identical to m25, results differs only in the background and pose, and the searching pill is still at y 69-121, x 457-813, the same as m17.

**found 8/10** (t0022)
- Tip inset: 35 L / 65 R → **20 / 20**. Bubble width 704 → about **644** (text 604 + 2 × 20). In code, use `inset = h * 0.5` (about 13 capture px = 20 design px), and size the bubble from the rendered text, `tipLabel.TextBounds.X + 2 * inset`, instead of `size.X * 1.08`. Re-measure next round.

**loadout 9.3/10** (t0036): the m25 items didn't land (the capture is pixel-identical), so they carry over.
- Weapon tiles 4 design px up, top 429 → 425 (39.7 → 39.3 %). This is optional because it's under 3 capture px.
- "Map: Warehouse" label: trim it about 5 design px (glyph band 26 → 21) with the top held at 21.5 %. It's a borderline type item, so defer to the typography grader.

**results 9/10** (t0140): row-identical to m25, so the items carry over.
- Stat labels 87.7 → 87.1 %. Damage numbers 91.9 → 90.6 %. Rematch / Play Again / Leave gap about 6 → 10 design px (0.6 → 0.9 %).

**searching 9/10** (t0018): the pill hasn't moved since m17, and the top-centre placement is our own choice. Nothing to fix.

**kill 9.8, death 9.8, death2 9.8, vote 9.5, countdown 9, live 9, matchpoint 9.7/10:** nothing to fix. The only diffs from m25 are the background and pose.

**playmenu: settled** (grid top y 306). **victory: settled** (the cutscene); it appears in no capture this round. **Mascot:** none (our game has none, so the bubble's left edge at x 241 is correct without one).

*Timing (unscored): Studio slows the short holds about 6x, so hold lengths aren't judged. Round-end and kill-cam durations are server timing.*

## Top 8 by visible impact
1. Found tip inset 35 / 65 → 20 / 20 design px, bubble about 644 wide (t0022). Fix the m25 overshoot.
2. Results stat rows about 1 % higher, and the button gap 0.6 → 0.9 % (t0140).
3. Loadout map label trimmed about 5 design px, top held at 21.5 % (t0036).
4. Loadout weapon tiles 4 design px up, to 39.3 % (t0036).
5. (none; the kill line, slot row, kill-cam gun, hotbar, M key and searching pill are all within 1 capture px)
6. (none)
7. (none)
8. (none)

Remaining layout gap worth another round: yes (small: the found inset overshoot, plus the results and loadout carry-overs)
