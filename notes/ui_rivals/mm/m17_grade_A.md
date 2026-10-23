# m17 grade A: positioning and layout

**Moved away from RIVALS:** one part of the death arc. When the arc was nudged up, the fin tip and the right tail went up with it. Both were already too high or too flat, so both now sit further from t0206 than in m16 (details below). Nothing else moved. A frame diff of m16 against m17 shows the death arc is the only UI change. The found tip text differs only because a different tip was drawn. There is no m17_victory capture.

**m16 fixes, checked against t0206 (red mask, measured at 1268x713 against 1600x900):**
- **Stroke ~24 px: landed.** The stroke is 15-16 px at 713 (2.1-2.2 % H, about 23-24 px on the 1080 canvas). RIVALS is 2.0 %, so it is close enough.
- **Fin ~105 px: size landed, shape and seat not.** It is still a rotated square, about 65 px across at 713 (about 98 px on the 1080 canvas). It is centred on the bend, so it hangs about 13 px (about 20 px on the canvas) below the lower edge of the stroke. In RIVALS the fin is a triangle that sits **on top of** the stroke and does not reach below it.
- **Arc 0.8 % right, 1.3 % up: partly landed.** The left end is (41.3 %, 37.2 %) against (41.6 %, 37.1 %), which is on target. The overall width is 13.7 % against 13.5 %. The bottom is 38.4 %, which matches exactly. Two points miss:
  - The fin tip is at (46.9 %, 25.0 %) against (47.4 %, 26.7 %). It overshot by 1.7 % (about 18 px too high) and is 0.5 % short in x. The cause is the bigger diamond centred on the bend.
  - The right tail ends at y 29.7 % against 32.7 %. It is 3.0 % too high (about 32 px). In m16 it was 31.7 %. The tail still rises or runs flat, where RIVALS arches over and drops.

**death 8.5/10** (t0206)
- Fin: a diamond centred on the bend → a triangle with its base on the top edge of the stroke and nothing below the stroke. Apex at (47.4 %, 26.7 %), i.e. (910, 288) px. Base about 85-100 px.
- Right half: flat or rising → arched down, so the tail ends at (55.1 %, 32.7 %), i.e. (1058, 353) px. The highest point of the stroke's upper edge should sit just right of the fin, at about y 31 %.
- Keep the left end, the bottom edge and the 24 px stroke as they are.

**death2 9/10** (t0212). This shot carries the same items as matchpoint.
- Weapon model: x 83.2-96.2 %, y 62.4-93.7 % → x 80.6-98 %, y 67-98 %. Carried over.

**matchpoint 9.5/10** (t0122)
- Ribbon: y 4.6-9.1 % → 5.3-9.8 %, and the text top about 7 px lower. Carried over.
- M key: inside the button → straddling the Switch Weapons right edge, x 56.6-58.3 % (t0212). Carried over.

**loadout 8/10** (t0036)
- Slot row top: 25.7 % → 26.9 %, with both gaps at 0.6 % (11 px). Carried over.

**kill 8/10** (t0054)
- "Eliminated" cap: y 70.5 % → 69.1 %. Hotbar 27 px further right (x 81.3-99.4 %). Carried over.

**results 9/10** (t0140)
- Stat labels: 87.7 % → 87.1 %. Damage numbers: 91.9 % → 90.6 %. Button gap: 0.6 % → 0.9 %. Carried over.

**found 9/10** (t0022)
- Bubble text inset: about 10 → 20 px on each side. Carried over.

**searching 9/10, vote 9.5/10, countdown / live 9/10.** Nothing to fix. **playmenu:** settled. **Mascot:** none, so the bubble keeps its inset.

*Timing (unscored): the 0.0 s death shot already shows ROUND LOST and the killer card, as in m16.*

## Top 8 by visible impact
1. Death fin: a triangle seated on top of the stroke, apex at (47.4 %, 26.7 %), with no overhang below (t0206).
2. Death right tail arched down to end at (55.1 %, 32.7 %) (t0206).
3. Death2 weapon model → x 80.6-98 %, y 67-98 % (t0212).
4. Loadout slot row at 26.9 %, even 0.6 % gaps (t0036).
5. Ribbon and its text about 7 px lower (t0122).
6. M key straddling the Switch Weapons right edge (t0212).
7. Kill cap at 69.1 %, hotbar 27 px right (t0054).
8. Results rows about 1 % higher with a 0.9 % button gap (t0140); found bubble text inset 20 px (t0022).

Remaining layout gap worth another round: yes
