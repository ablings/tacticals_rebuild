# m28 grade A: positioning and layout

**Moved away from RIVALS:** nothing this round.

**m27 fixes, measured pixel by pixel** (capture px x 1.514 = design px):

| found tip | bubble x | width | inset L | inset R | glyph h | bubble y |
|---|---|---|---|---|---|---|
| m27 | 241-868 | 627 | 21 | 42 | 27.3 | 92.6-97.5 % |
| **m28** | 241-994 | 753 | **21** | **42** | **31.8** | 92.6-97.5 % |
| t0022 | 240-1416 | 1176 | 20 | 20 | 30 | 92.6-97.3 % |

- **Found tip text size: landed.** The words are back to full size. The glyph band is 27.3 → 31.8 (both tips have a "g"/"p" descender, and t0022 is 30), so Rubik no longer drops a size.
- **Found tip insets: not landed.** The right inset is still 42 against a target of 20. `GetTextBoundsAsync` at `floor(h)` returns about 470 capture px, but the label draws the line 455 px wide. That's about 3 % narrower, which looks like TextScaled drawing one integer size below `floor(h)`. The bubble is therefore still about 22 design px too wide on the right.
- **Results button gaps: landed.** The outlines are Rematch 523-580, Play Again 587-644 and Leave 652-708 (capture y). That gives clear gaps of 6 / 7 capture px, which is **9.1 / 10.6 design px**. The commit says "~14", but what renders is close to t0140's 8.4, which is better. Leave's bottom holds at 99.3 %, and all three heights are 8.0-8.1 % h (t0140 is 7.9).
- Unchanged in layout: searching pill, vote (only the map art changed), loadout (map name and art only), and the in-match screens (pose and background only).

**found 8.8/10** (t0022)
- Size the bubble from the drawn text, not the measured text. After the first resize, wait a frame (`task.wait()`) and set `w = tipLabel.TextBounds.X + 2 * inset`. Then re-apply the tip size and the label position and size as now. Because the label stays wider than its text, TextScaled won't change size on the second pass.
- Target: right inset 42 → **20**, which takes the bubble width from 753 to about **731** design px (689 text + 40). Keep the left inset at 21 and the height and y as they are.

**results 9.4/10** (t0140)
- Gaps done. Optional evening-out: Rematch top 0.81 → 0.8105 would make both gaps about 10 design px. Below the noise; skip it unless you're already in the file.
- Stat labels 87.7 → **87.1 %**, damage numbers 91.9 → **90.6 %** (t0140). These carry over from m27: the rows are pixel-identical.

**loadout 9.5/10** (t0036): no layout fix left. The "Map:" label trim stays with the typography grader.

**searching 9, vote 9.5, countdown 9, live 9, kill 9.8, matchpoint 9.7, death 9.8, death2 9.8/10:** nothing to fix.

**playmenu: settled** (grid top y 306). **Victory:** a settled cutscene. **Mascot:** none, so the tip's left edge at x 241 is correct.

*Timing (unscored): Studio slows the short holds about 6x, so hold lengths aren't judged. Round-end and kill-cam durations are server timing.*

## Top 8 by visible impact
1. Found tip: size the bubble from `tipLabel.TextBounds.X` one frame later. Right inset 42 → 20, width 753 → about 731 (t0022).
2. Results stat labels to 87.1 % and damage numbers to 90.6 %, about 1 % higher (t0140).
3. Loadout "Map:" label trim of about 5 px (t0036). Typography grader's call.
4. Results gap evening-out (9.1 / 10.6 → 10 / 10). Optional.
5. (none)
6. (none)
7. (none)
8. (none)

Remaining layout gap worth another round: yes (small: the found tip's right inset and the results stat rows)
