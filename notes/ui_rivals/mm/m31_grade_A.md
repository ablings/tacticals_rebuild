# m31 grade A: positioning and layout

**Moved away from RIVALS:** the Match found tip text lost about one size. This round drew the same tip as m30 ("Headshots end fights…"). The cap height went from 16 to 15 capture px (24.2 → **22.7 design**; t0022: 24.0), and the drawn line got about 2 % narrower (421 → 412 capture px). The cause is `MatchFoundGate.lua` line 211: `TextSize = math.floor(h * 0.9)`. The label is 0.76 x 54 = 41 design px tall, so floor(36.9) gives 36 design. TextScaled had been drawing it at about 38.

**m30 fixes, measured (capture px x 1.514 = design px):**

| | m30 | **m31** | RIVALS |
|---|---|---|---|
| results stat label centre | 87.6 % | **87.0 %** | 87.1 % (t0140) |
| results label to damage number gap | 3.0 % | **3.6 %** | 3.4 % |
| results box / digit / damage row | 79.9-86.0 / 83.0 / 90.6 % | unchanged | match |
| found tip insets L / R (design) | 21 / 54 | **21 / 23** | 20 / 20 (t0022) |
| found bubble w x h (design) | 716 x 53 | **668 x 53** | 52.8 tall |

- **Results labels 6 up: landed.** They moved 4 capture px (6 design px) up, now 0.1 % from t0140, which is within a pixel.
- **Tip bubble from TextBounds: landed.** The insets are even at about 21-23 design px, against t0022's 20. The bubble width now follows the drawn text, so it fits every tip.

**found 9.4/10** (t0022)
1. Tip text size: `TextSize = math.floor(h * 0.9)` → `math.floor(h * 0.94 + 0.5)`, which gives about **38 design px** (cap 24, like t0022). The bubble then grows by itself to about 690 design px wide and keeps the 20 px insets. The settled width rule still holds: this restores the m29/m30 size rather than trimming further.

**results 9.6/10** (t0140): nothing to fix. The labels, boxes, damage row and buttons all sit within a few design px.

**playmenu, searching, vote, loadout, countdown, live, kill, matchpoint, death, death2:** the layout is unchanged from m30 (checked on m31_sheet), and only the results and tip code changed this round. Each keeps its m30 score (9-9.8). Nothing to fix.

**Victory:** settled cutscene. **Mascot:** none, so the tip left edge at x 241 design is correct.

*Timing (unscored): Studio slows the short holds about 6x, so hold lengths aren't judged. Round-end and kill-cam durations are server timing.*

## Top 8 by visible impact
1. Found tip text back up one size: line 211 `h * 0.9` floor → `h * 0.94` rounded (about 38 design px, cap 24; t0022).
2. (none)
3. (none)
4. (none)
5. (none)
6. (none)
7. (none)
8. (none)

Remaining layout gap worth another round: yes (tiny: one-line tip TextSize factor; everything else is within a few px)
