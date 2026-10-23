# m13 grade A: positioning and layout

**Moved away from RIVALS:** nothing. Only the death frame's UI changed since m12. In every other screen the pixel diffs come from the world, camera or mission text, and the layout is unchanged.

**m12 fixes, measured at 1268x713:**
- **Health bar at the death moment: landed.** m13_death reads "0" with an empty bar (m12 read 150). The bar sits at x 0.5-20.5%, y 95.1-98.9%. t0206 has x 0.6-21%, y 95.3-98.7%.
- **Death arc: mostly landed.** The arc runs x 43.3-55.2% (t0206: 41.6-55.1%). The stroke is now 8-11 px at the centre (1.1-1.5% of height) and tapers to 2 px at the tips. It tilts slightly, with the left tip at y 37.9% and the right at 35.9%. The arrowhead is a real triangle now, 1.9% wide and 4.8% tall, with its tip at y 29.3%. Three gaps to t0206 remain:
  - **Stroke weight.** RIVALS is a thick, near-even 18-20 px at 900 (2.0-2.2%). It stays ~18 px almost to the tips and ends blunt. It is not a needle taper, so we over-tapered.
  - **Arrowhead size.** t0206 has x 46-50% (4% wide) and a 6.9% height, with its tip at y 26.8%. Ours is about half that.
  - **Shape.** RIVALS is a hook. The left half climbs steeply from (41.6%, 38.3%), the head sits just left of centre (47.6%), and the right half runs almost flat at y 33%. Ours is a symmetric dome.

**searching 8/10** (t0018)
- Icon: 2.0% → 3.3% wide. Pill top: y 11.1% → 9.7%. Both carried over.

**found 8/10** (t0020)
- The bubble spans x 12.5-76.5%, but the text ends at 43.6%. Size the bubble to the text (AutomaticSize X, 1% pad). Carried over.

**vote 9/10** (t0032)
- Tile: 25% → 22.6% wide. Name strip: 17% → 20% of the tile height. Carried over.

**loadout 8/10** (t0036)
- Slot row: y 25.7% → 26.9%. Slot gaps → an even 0.6% (11 px). Carried over.

**countdown / live 9/10.** Nothing to fix.

**kill 8/10** (t0054)
- "Eliminated" cap: y 70.4% → 69.1%. Hotbar: +27 px right (x 81.3-99.4%). Carried over.

**matchpoint 9/10** (t0122)
- Switch Weapons is at x 42.2-57.8%, y 69.6-74.2% (t0212: 42.6-57.5%, 69.7-74.6%), which is fine. The M key still sits inside the button (x 55.4-57.2%). It should straddle the right edge at x 56.6-58.3%.

**death 8.5/10** (up from 7.5) (t0206)
- Arc stroke: 8-11 px tapering to 2 → ~13 px at 713 (~20 px at 1080) held near even. Taper only the last ~5% to ~8 px, with blunt ends.
- Arrowhead: 1.9% x 4.8% → 4% x 6.9% (77x75 px at 1080), centred at x 47.6%, with its tip at y 26.8%.
- Shape: dome → hook. Left tip at (41.6%, 38.3%), rising steeply to the head. The right half runs flat at ~y 33% out to 55.1%.
- Killfeed chip: x 81-99% → hug the text, ~x 85-99.4% (t0212). Carried over.

**death2 9/10** (t0212). The LOST card (43.6-56.4%, 13.6-22.4%) and the killer card (59.5-94.6%, 76.2-88.4%) match exactly.
- Weapon model: x 83.2-96.2%, y 62.4-93.7% → x 80.6-98%, y 67-98%. Carried over.
- M key overhang, as in matchpoint.

**results 9/10** (t0140)
- Stat labels: y 87.7% → 87.1%. Damage numbers: 91.9% → 90.6%. Button gap: 0.7% → 0.9%. Carried over.

**playmenu 8/10.** Settled. **Mascot:** skipped (none exists).

*Timing (unscored): at the 0.0 s death capture, ours already shows ROUND LOST and the killer card. In t0206 RIVALS shows neither at the death moment; they arrive by t0212.*

## Top 8 by visible impact
1. Death arrowhead to 4% x 6.9%, tip at y 26.8%, at x 47.6% (t0206).
2. Death arc as a hook with a near-even ~2.1%-of-height stroke, not a thin dome with a needle taper (t0206).
3. Death2 weapon model to x 80.6-98%, y 67-98% (t0212).
4. Vote tile 22.6% wide, name strip 20% (t0032).
5. Searching icon 3.3% wide, pill top at 9.7% (t0018).
6. Found bubble sized to its text (t0020).
7. Loadout slot row at 26.9%, gaps an even 0.6% (t0036).
8. M key straddling the Switch Weapons edge (t0212). Killfeed chip hugs its text (t0212). Results rows ~1% higher (t0140).
