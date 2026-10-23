# m27 grade A: positioning and layout

**Moved away from RIVALS: partly, on found.** Taking out the width fudge fixed the left inset, but the tip text shrank. Its glyph band went from 30.3 to 27.3 design px (t0022 is 30), and the right inset is still about twice the target. Both captures' tips have one descender each (m26 "g", m27 "p"), so the heights compare. The cause is in `MatchFoundGate.lua` line 204: the text is measured in `Enum.Font.SourceSansBold`, but the label renders Rubik Bold with TextScaled. Rubik is wider, so TextScaled drops the text one integer size to fit, and because the text is left-aligned the leftover ends up on the right. The old `* 1.08` fudge had been hiding this font mismatch.

Measured pixel by pixel, in design px (1920 wide):

| | bubble x | width | inset L | inset R | glyph h | bubble y |
|---|---|---|---|---|---|---|
| m26 | 241-946 | 706 | 35 | 64 | 30.3 | 92.6-97.5 % |
| **m27** | 241-868 | 627 | **21** | **42** | **27.3** | 92.6-97.5 % |
| t0022 | 240-1416 | 1176 | 20 | 20 | 30 | 92.6-97.3 % |

The other m26 fixes landed:
- **Loadout tiles:** top 429 → 425.5 (39.69 → 39.41 %), 2 capture px higher. This landed.
- **Results gaps:** they grew, but they're still short (see below). Measured outline edge to outline edge, the gaps went from 1.5 / 3 to 4.5 / 4.5 design px. Rematch's top moved up from 535 to 532 capture px to make the room.

Unchanged: the searching pill (x 457-813, y 69-121 capture px), vote (only the map art and name changed), and the in-match screens (only the background and pose changed).

**found 8.5/10** (t0022)
- Measure with the label's real font: `TextService:GetTextBoundsAsync` with `Font = tipLabel.FontFace` at `math.floor(h)`. Or, one frame after setting the text, size the bubble from `tipLabel.TextBounds.X + 2 * inset`.
- Target: insets 21 / 42 → **20 / 20**, glyph band 27 → **30**, and bubble width = text + 40. With this tip that's about 603 + 40 = 643 at full text size. Keep `inset = h * 0.5`.

**results 9.2/10** (t0140)
- Button gaps 4.5 → **about 9 design px**. t0140's Play Again / Leave gap is 7 px at 1600 wide, which is 8.4 design px (0.78 % h). Keep the bottom of Leave at 99.3 % and grow each gap upwards. Button heights already match (8.0 vs 7.9 % h).
- Stat labels 87.7 → 87.1 %, damage numbers 91.9 → 90.6 % (t0140). These carry over: the rows are pixel-identical to m26.

**loadout 9.5/10** (t0036)
- The tile item is done.
- The "Map:" label trim (glyph band 26 → 21, top held at 21.5 %) carries over. It's a borderline type item, so defer it to the typography grader. The band reads 27 this round only because "Practice Range" has descenders.

**searching 9/10, vote 9.5, countdown 9, live 9, kill 9.8, matchpoint 9.7, death 9.8, death2 9.8/10:** nothing to fix.

**playmenu: settled** (grid top y 306). **Victory:** a settled cutscene that appears in no capture. **Mascot:** none, so the tip's left edge at x 241 is correct.

*Timing (unscored): Studio slows the short holds about 6x, so hold lengths aren't judged. Round-end and kill-cam durations are server timing.*

## Top 8 by visible impact
1. Found tip: measure in Rubik (FontFace), not SourceSansBold. Right inset 42 → 20 and glyph band 27 → 30 (t0022).
2. Results button gaps 4.5 → about 9 design px (t0140).
3. Results stat labels about 1 % higher (87.1 %) and damage numbers to 90.6 % (t0140).
4. Loadout "Map:" label trim of about 5 px (t0036). Typography grader's call.
5. (none)
6. (none)
7. (none)
8. (none)

Remaining layout gap worth another round: yes (small: the found tip's font mismatch, and the results gaps and stat rows)
