# m18 grade A: positioning and layout

**Moved away from RIVALS:** nothing. A frame diff of m17 against m18 shows the death arc is the only UI change. The other diffs are the character, the scene, Daily Missions values, and the vote tile caught before its outline drew, which is capture timing. There are no m18 found, searching or playmenu captures, so those keep their m17 grades.

**m17 fixes, checked against t0206 (red mask, 1268x713 against 1600x900):**
- **Right tail arched down: landed.** The tail end is (54.4 %, 32.3 %) against (55.1 %, 32.7 %), down from 29.9 % in m17. The tip column at x 54 is y 31.8-33.9 against RIVALS' 31.9-33.8, which is a match. Two small misses remain:
  - The tail is 0.7 % short in x (about 13 px).
  - The middle of the right half sits about 1 % high. At x 50-51 % the stroke is y 30.2-32.3 against RIVALS' 30.8-33.1.
- **Fin lower: landed, slightly past the target.** The apex is (47.1 %, 27.2 %) against (47.4 %, 26.7 %). m17 had it 1.7 % too high; it is now 0.5 % too low (about 5 px) and 0.3 % to the left (about 6 px). It is still a diamond (settled). It hangs to y 34.5 % against RIVALS' 33.4-33.9 % there, so it reaches about 10 px below.
- The size now matches. The mask covers 3580 px against 3505 for t0206 scaled to our frame, and the stroke is about 2.1-2.4 % H.
- The left end (41.4 %, 37.0 %) and the bottom (38.4 %) are still on target.

**death 9/10** (t0206)
- Fin diamond: move it up 0.5 % and right 0.3 % (about 5 px up, 6 px right), so the apex sits at (910, 288) px and the overhang below the stroke drops to about 5 px.
- Right half middle: lower it by about 0.8 % (about 9 px) at x 49-52 %, so the upper edge there sits at about 30.8-31.2 % (333-337 px). Keep the tail end height.
- Tail end: extend it 0.7 % (about 13 px) to x 55.1 % (1058 px).

**death2 9/10** (t0212). Same items as matchpoint.
- Weapon model: x 83.2-96.2 %, y 62.4-93.7 % → x 80.6-98 %, y 67-98 %. Carried over.

**matchpoint 9.5/10** (t0122)
- Ribbon and its text: about 0.7 % (7 px) lower, y 5.3-9.8 %. Carried over (no diff in the ribbon area).
- M key: from inside the button → straddling the Switch Weapons right edge, x 56.6-58.3 % (t0212). Carried over.

**loadout 8/10** (t0036)
- Slot row top: 25.7 % → 26.9 %, with even 0.6 % (11 px) gaps. Carried over.

**kill 8/10** (t0054)
- "Eliminated" cap: y 70.5 % → 69.1 %. Hotbar 27 px right (x 81.3-99.4 %). Carried over.

**results 9/10** (t0140)
- Stat labels: 87.7 % → 87.1 %. Damage numbers: 91.9 % → 90.6 %. Button gap: 0.6 % → 0.9 %. Carried over.

**found 9/10** (t0022, no m18 capture)
- Bubble text inset: about 10 → 20 px on each side. Carried over.

**vote 9.5/10, countdown / live 9/10, victory: nothing to fix** (the cutscene is settled). **searching 9/10, playmenu settled:** no m18 capture. **Mascot:** none.

*Timing (unscored): the 0.0 s death shot already shows ROUND LOST and the killer card, as in m17.*

## Top 8 by visible impact
1. Death2 weapon model → x 80.6-98 %, y 67-98 % (t0212).
2. Loadout slot row at 26.9 %, with even 0.6 % gaps (t0036).
3. Kill cap at 69.1 %, hotbar 27 px right (t0054).
4. Death arc right half: middle about 9 px lower, tail about 13 px longer, to (55.1 %, 32.7 %) (t0206).
5. Death fin diamond about 5 px up and 6 px right, apex at (47.4 %, 26.7 %) (t0206).
6. Ribbon and its text about 7 px lower (t0122).
7. M key straddling the Switch Weapons right edge (t0212).
8. Results rows about 1 % higher with a 0.9 % button gap (t0140); found bubble text inset 20 px (t0022).

Remaining layout gap worth another round: yes
