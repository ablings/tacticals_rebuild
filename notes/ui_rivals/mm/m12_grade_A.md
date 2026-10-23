# m12 grade A: positioning and layout

**Moved away from RIVALS:** nothing. Every screen except death and results is pixel-identical in layout to m11.

**m11 fixes, checked at 1268x713:**
- **Death arc: half landed.** It is now curved and sits on the ring: x 548-700 (43.2-55.2%), y 220-272 (30.9-38.1%). In t0206 the arc spans x 41.6-55.3% and y 26.7-38.7%, so the width is close (12.0% vs 13.7%). The shape is still wrong. Ours is a thin (~0.6% / 4 px), symmetric dome with a ~1.4% nub at the apex. t0206's arc is thick (~2.2% / 24 px at 1080) and tapers to the ends. It is tilted, with the left end lower (y 38.7%) than the right (y 33.3%). Its arrowhead is a large triangle, ~4.5% wide and 6.7% tall, at x 47-49.5%, rising to y 26.7%.
- **Results buttons: landed.** Play Again is at y 594-648 (83.3-90.9%, 7.6%) and Leave at y 653-708 (91.6-99.3%, 7.7%), with a ~0.7% gap. t0140 has 82.6-90.3% and 91.2-99.1%, with a 0.9% gap. Rematch is at 75.5-82.6% (t0140: 73.3-82.2%). The x range (86-99.6%) matches.

**searching 8/10** (t0018)
- Icon: 2.0% → 3.3% wide (62 px). Carried over.
- Pill top: y 11.1% → 9.7% (y 105). Carried over.

**found 8/10** (t0020)
- The text fills only x 13.5-43.6% of the bubble, which runs to 76.5%. Size the bubble to the text (AutomaticSize X, 1% pad, max 64%). Carried over.

**vote 9/10** (t0032)
- Tile: 25% → 22.6% wide (x 38.5-61.1%). Name strip: 17% → 20% of the tile height. Carried over.

**loadout 8/10** (t0036)
- Slot row: y 25.7% → 26.9% (290 px), for a 2.6% gap below the header. Carried over.
- Slot gaps: 0.3% / 0.6% → an even 0.6% (11 px).

**countdown / live 9/10.** Nothing to fix.

**kill 8/10** (t0054)
- "Eliminated" cap: y 70.4% → 69.1% (746 px).
- Hotbar block: x 80-98% → 81.3-99.4% (+27 px).

**matchpoint 9/10** (t0122)
- Switch Weapons: 4.5% → 5% tall. The M key sits inside the button (x 55.4-57.2%). It should straddle the right edge at x 56.5-58.3%.

**death 7.5/10** (up from 7) (t0206)
- Arc stroke: ~4 px → ~24 px at the centre, tapering to ~8 px at the tips, with a tilt of ~8° (left end low).
- Arrowhead: a ~1.4% nub → a ~86x72 px triangle (4.5% x 6.7%) set slightly left of the arc centre (x 47-49.5%), with its tip at y 26.7%.
- Killfeed chip: 18% wide (x 81-99%) → hug the text, ~14.4% (x 85-99.4%, t0212).

**death2 9/10** (t0212). The LOST card, killer card and Switch Weapons all match.
- Weapon model: x 83.2-96.2%, y 62-93.7% → x 80.6-98%, y 67-98%. Carried over.
- The M key overhang, as in matchpoint.

**results 9/10** (up from 8) (t0140). The banner, name plate and stat-tile centres (43.8 / 50 / 56.2%) match.
- Stat labels: y 87.7% → 87.1%. Damage numbers: y 91.9% → 90.6% (~14 px up at 1080).
- Button gap: 0.7% → 0.9% (10 px). This is minor.

**playmenu 8/10.** Settled. **Mascot:** skipped (none exists).

*Timing (unscored): nothing new seen in the stills.*

## Top 8 by visible impact
1. Death arc: thick tapered stroke, tilted, with a large 4.5% x 6.7% arrowhead (t0206).
2. Death2 weapon model to x 80.6-98%, y 67-98% (t0212).
3. Vote tile 22.6% wide, name strip 20% (t0032).
4. Searching icon 3.3% wide, pill top at 9.7% (t0018).
5. Found bubble sized to its text (t0020).
6. Loadout slot row at 26.9%, gaps an even 0.6% (t0036).
7. Switch Weapons 5% tall with the M key overhanging (t0122 / t0212); killfeed chip hugs its text.
8. Results stat labels and damage rows ~1% higher; kill "Eliminated" at 69.1% and hotbar +27 px (t0140 / t0054).
