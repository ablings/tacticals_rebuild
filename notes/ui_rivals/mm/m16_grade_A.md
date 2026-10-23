# m16 grade A: positioning and layout

**Moved away from RIVALS:** nothing. All four m15 fixes landed, and each one is closer to RIVALS. None of the other carried-over layout items moved: the loadout row, the kill cap, the ribbon offset, the M key, the death2 weapon model and the results rows are unchanged from m15. There is no m16_victory capture.

**m15 fixes, checked against the frames (measured at 1268x713):**
- Death arc (t0206): **landed.** It is now a hook with a diamond fin. The left end sits at (40.8%, 38.6%) against (41.6%, 37.1%), the right end at 54.2% against 55.1%, and the overall width is 13.4% against 13.5%. The dome is gone.
- Found tip bubble (t0022): **landed.** The bubble ends at x 48.3% with its text ending at about 47.6%, a 0.7% gap. RIVALS leaves 1%.
- Vote tile (t0032): **landed.** The inner tile is 22.6% wide and the name strip is 19.3% of the tile height.
- Searching pill (t0018): **landed.** The pill top is at 9.7%, the height is 7.3% (RIVALS 7.2%) and the width is 36.0-64.2%. The icon is 4.5% tall, which matches RIVALS' 4.4%. The star glyph is 2.1% wide against RIVALS' 3.25%, but that comes from the glyph's shape, not the layout.

**searching 9/10.** Nothing to fix.

**found 9/10** (t0022)
- Bubble text inset: 0.5% → 1.0% on both sides (about 10 → 20 px). Today "Your" starts 6 px from the bubble edge; in RIVALS it starts 17 px in at 1600.

**vote 9.5/10.** Nothing to fix.

**loadout 8/10** (t0036)
- Slot row top: y 25.7% → 26.9%. Slot gaps are uneven (0.4% / 0.6%): make both 0.6% (11 px). Carried over.

**countdown / live 9/10.** Nothing to fix.

**kill 8/10** (t0054)
- "Eliminated" cap: y 70.5% → 69.1%. Hotbar: 27 px further right (x 81.3-99.4%). Carried over.

**matchpoint 9.5/10** (t0122)
- Ribbon bar: y 4.6-9.1% → 5.3-9.8%. Text top: 1.8% → 2.2% (about 7 px down). Carried over.
- M key: x 55.4-57.2% (inside the button) → 56.6-58.3%, straddling the right edge (t0212). Carried over.

**death 9/10** (t0206). The shape is right. What remains is placement and weight:
- Whole arc: about 0.8% right and 1.3% up (+16 px, -14 px). The fin tip is at (46.4%, 28.5%); the target is (47.4%, 26.7%).
- Fin base: about 3.0% → 4.0% wide (58 → 77 px).
- Stroke: 1.5% → 1.9% of height (16 → 20 px). Ease the right tail down to end at y 32.7% (it is 30.9% now).

**death2 9/10** (t0212). The same ribbon offset as matchpoint applies.
- Weapon model: x 83.2-96.2%, y 62.4-93.7% → x 80.6-98%, y 67-98%. Carried over.

**results 9/10** (t0140)
- Stat labels: y 87.7% → 87.1%. Damage numbers: 91.9% → 90.6%. Button gap: 0.6% → 0.9%. Carried over.

**playmenu.** Settled. **Mascot:** none (our game has none), so the bubble keeps its 12.5% left inset.

*Timing (unscored): the 0.0 s death shot already shows ROUND LOST and the killer card, as in m15.*

## Top 8 by visible impact
1. Death arc 0.8% right and 1.3% up, tip at (47.4%, 26.7%) (t0206).
2. Death fin 4% wide, stroke 1.9%, right tail down to 32.7% (t0206).
3. Death2 weapon model → x 80.6-98%, y 67-98% (t0212).
4. Loadout slot row at 26.9%, with even 0.6% gaps (t0036).
5. Ribbon and text about 7 px down (t0122).
6. M key straddles the Switch Weapons right edge (t0212).
7. Kill cap at 69.1%, hotbar 27 px right (t0054).
8. Results rows about 1% higher, button gap 0.9% (t0140). Found bubble text inset 1% (t0022).

Remaining layout gap worth another round: yes
