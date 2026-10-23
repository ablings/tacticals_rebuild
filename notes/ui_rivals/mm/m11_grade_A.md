# m11 grade A: positioning and layout

**Moved away from RIVALS:** nothing noticeable. The vote tile is marginally larger than in m10: x 37.5-62.5% now, against 37.9-62.1% then (within measurement noise).

**m10 fixes, pixel-checked (1268x713):**
- **Found tip bubble: landed.** It sits at x 159-970 (12.5-76.5%), y 660-695 (92.6-97.5%). t0020 has 12.5-76.6%, y 92.6-97.4%, so it is exact. The mascot is still missing.
- **Results banner: landed.** x 532-735 is 16.0% wide (307 px at 1920), y 10.7-19.4%. t0140 has x 42-58%, y 10.8-19.7%. The name plate (x 39.7-60.3%, y 70.8-76.9%) and stat tiles also match. The button gap and height did NOT land: Play Again and Leave still touch, sharing a white border at y 644-650.
- **Death chevron: it draws now**, at x 47.6-51.1%, y 31.4-37.9%, on a ~15% ring above the crosshair. The ring radius is right. The size and shape are not (see death).

**searching 8/10** (t0018)
- Icon: 23 px (1.8%) → 3.3% wide (62 px). Still not done.
- Pill top: y 11.1% → 9.7% (y 105). The height (7.3%) and x (36-64.2%) match.

**found 8/10** (up from 7) (t0020)
- Add the mascot at x 3-12%, y 76-100%, with the bubble tail at x ~13.5%, y 90-92.5%.
- The text spans only x 13.5-50.5% inside an 811 px bubble. In t0020 the text fills the bubble (1% pad each side). Size the bubble to the text (AutomaticSize X, max 64% wide) instead of a fixed width.

**vote 9/10** (t0032)
- Tile: 24.9% → 22.6% wide (x 38.5-61.1%, y 37.4-62.7%). Name strip: 17% → 20% of the tile height. Both carried over.

**loadout 8/10** (t0036)
- Header-to-slot gap: 1% → 2.6%, so the slot row moves to y 26.9% (290 px). The choices row (39.7-51%) can stay put. Carried over.
- Slot gaps: 0.3-0.6% → 0.6% (11 px), even.

**countdown / live 9/10.** Nothing to fix.

**kill 8/10** (t0054)
- "Eliminated" cap: y 70.4% → 69.1% (y 746).
- Hotbar block: x 80.1-98% → 81.3-99.4% (shift right by 27 px).

**matchpoint 9/10** (t0122)
- Switch Weapons: 4.6% → 5% tall. The M key sits inside the button at x 55.4-57.2%. It should straddle the right edge at x 56.5-58.3%. Carried over.

**death 7/10** (t0206)
- Chevron: a 45x46 px triangle (3.5% x 6.5%) → a ~263x128 px curved arc (13.7% x 11.9%), tangent to the ring, spanning x 41.6-55.3%, y 26.7-38.6% when the killer is ahead.
- Killfeed chip: 18% wide (x 81-99%) → hug the text. t0212's chip is 14.4% wide (x 85-99.4%) with the same height.

**death2 9/10** (t0212). LOST (43.6-56.4%, y 13.6-22.4%), the killer card (59.5-94.6%, 76.2-88.5%) and Switch Weapons (42.2-57.8%, 69.6-74.1%) all match.
- Weapon model: x 83.2-96.4%, y 62-93.7% → x 80.6-98%, y 67-98%. Carried over.
- M key overhang, as in matchpoint.

**results 8/10** (t0140)
- Button gap: 0 → 1% (11 px). Button height: 8.6% → 7.8% (84 px). Leave keeps its bottom edge at 99%, Play Again sits at y 82.4-90.2%, and Rematch at 73.3-82%.
- Stat labels and damage rows sit ~1.3% low (labels 87.7% → 87%, damage 91.9% → 90.5%).

**playmenu 8/10.** Settled.

*Timing (unscored): nothing new seen in the stills.*

## Top 8 by visible impact
1. Death chevron as a 13.7%-wide curved arc on the ring (t0206).
2. Results: 1% gap between the buttons and 7.8% button height (t0140).
3. Found: the mascot, plus a bubble sized to its text (t0020).
4. Death weapon model to x 80.6-98%, y 67-98% (t0212).
5. Vote tile 22.6% wide, name strip 20% (t0032).
6. Searching icon 3.3% wide, pill top at 9.7% (t0018).
7. Loadout slot row at 26.9%, with a 2.6% header gap (t0036).
8. Switch Weapons 5% tall with the M key overhanging (t0122); killfeed chip hugs its text (t0212).
