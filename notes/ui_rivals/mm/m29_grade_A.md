# m29 grade A: positioning and layout

**Moved away from RIVALS:** the results stat boxes and their big digits went up with the labels. Digit centre 83.1 → **82.5 %** (t0140: 83.0), box 79.9-86.0 → **79.4-85.4 %** (t0140 about 80.0-85.8). That's about 6 design px too high now. Only the labels and the damage rows were meant to move.

**m28 fixes, measured (capture px x 1.514 = design px):**

| found tip | bubble x | inset L | inset R | glyph h | bubble y |
|---|---|---|---|---|---|
| m28 | 241-993 | 21.2 | 42.4 | 31.8 | 92.6-97.5 % |
| **m29** | 241-1069 (new, longer tip) | **21.2** | **25.7** | 33.3 | 92.6-97.5 % |
| t0022 | 240-1416 | 20 | 20 | 30 | 92.6-97.3 % |

- **Found tip right inset: mostly landed.** It went from 42 to 25.7 against a target of 20, so about 6 design px is left. The text kept its full size, and the left inset and y are unchanged.
- **Results rows: landed.** The stat labels are at **87.1 %** (target 87.1, t0140 87.2). The damage numbers are at **90.7 %** (target 90.6). The damage labels are at about 93.3 % (t0140 93.1).
- **Capture artefact:** the m29 world didn't render, so every in-match and results backdrop is white or grey. The results buttons' white outlines vanish against it, so I can't judge them this round. Their fills sit where m28's did (x 1094-1261, 3 px inside the m28 outline). Not graded.

**results 9.3/10** (t0140)
1. Stat boxes and digits back down **+6 design px**: box top 79.4 → **80.0 %**, digit centre 82.5 → **83.0 %**. Keep the labels at 87.1 % and the damage rows where they are. That also brings the gap from box bottom to label centre back to t0140's ~1.3 % (it's 1.7 % now).

**found 9.4/10** (t0022)
1. Right inset 25.7 → **20**. The fixed 0.97 factor can't be trimmed further: the label is already only about 3 capture px wider than its words, so a lower factor makes TextScaled drop a size. Instead, on the next frame set `w = tipLabel.TextBounds.X + 2*inset + 1` (the drawn width) and re-apply the label position and size. For this tip that's bubble width 828 → about **822** design px.

**searching 9, vote 9.5, loadout 9.5, countdown 9, live 9, kill 9.8, matchpoint 9.7, death 9.8, death2 9.8/10:** the layout matches m28 and there's nothing to fix. The backdrops are the same artefact.

**playmenu: settled** (grid top y 306). **Victory:** settled cutscene. **Mascot:** none, so the tip's left edge at x 241 is correct.

*Timing (unscored): Studio slows the short holds about 6x, so hold lengths aren't judged. Round-end and kill-cam durations are server timing.*

## Top 8 by visible impact
1. Results stat boxes and digits +6 design px down (digit centre 83.0 %, box top 80.0 %; t0140). This undoes this round's overshoot.
2. Found tip: size the bubble from `TextBounds.X` one frame later. Right inset 25.7 → 20 (t0022).
3. Re-capture results with the world loaded so the button outlines can be checked (no layout change).
4. (none)
5. (none)
6. (none)
7. (none)
8. (none)

Remaining layout gap worth another round: yes (small: results stat boxes 6 px back down, found tip right inset about 6 px)
