# m20 grade A: positioning and layout

**Moved away from RIVALS:** yes, one side effect. The bigger kill-cam pistol now covers the end of the killer card text. "eliminated you with Pis|tol" is cut at about x 81 % in both death (0.0 s) and death2. In t0212 the gun sits clear of "eliminated you with Uzi", whose text ends at x 81.3 %. A frame diff of m19 against m20 shows the gun is the only UI change. The other diffs are the scene, the character pose, Daily Missions values and the timer. The death arc is pixel-identical to m19 (settled). There are no lobby-side captures, so those grades carry over from m17.

**m19 fix, the kill-cam weapon model bigger and lower: landed on size and height, but it overshoots the bottom and right.**
- m19 was x 83.2-96.2 %, y 62.4-93.7 % (13.0 x 31.3 %).
- m20 is x 80.8-96.2 %, y 66.2-100 %, clipped at the screen bottom (15.4 x 33.8 % or more).
- t0212 is x 80.6-98 %, y 67-98 % (17.4 x 31 %).
- The top and the left extreme now match. But the grip runs off the screen, where RIVALS keeps about 2 % of margin. The right edge is 1.8 % short. At card height (y 76-88 %) our left edge is about 81 %, where RIVALS' is about 83.4 %. RIVALS' leftmost point (the barrel) sits above the card top. Ours sits inside the card.

**death2 8.5/10** (t0212)
- Weapon model: anchor its bottom-right at (98 %, 98 %), i.e. (1882, 1058) px, and scale about 0.92. Or tilt the barrel up so it is the leftmost point and sits above the card top (y < 76 %, 821 px). Target: no gun pixel left of x 83 % (1594 px) between y 76-88 %, so "with Pistol" stays readable.

**death 9/10** (t0206)
- The same gun overlap cuts the weapon name. The same fix applies; the arc is settled.

**matchpoint 9.5/10** (t0122)
- Ribbon and its text about 7 px lower, y 5.3-9.8 %. Carried over.
- M key: straddle the Switch Weapons right edge, x 56.6-58.3 % (t0212). Carried over (m20 still has it inside the button).

**loadout 8/10** (t0036)
- Slot row top: 25.7 % → 26.9 %, with even 0.6 % (11 px) gaps. Carried over (no UI diff).

**kill 8/10** (t0054)
- "Eliminated" cap: y 70.5 % → 69.1 %. Hotbar 27 px right (x 81.3-99.4 %). Carried over.

**results 9/10** (t0140)
- Stat labels 87.7 % → 87.1 %. Damage numbers 91.9 % → 90.6 %. Button gap 0.6 % → 0.9 %. Carried over (only the pose changed).

**found 9/10** (t0022, no m20 capture)
- Bubble text inset about 10 → 20 px on each side. Carried over.

**vote 9.5/10, countdown / live 9/10, victory: nothing to fix** (the cutscene is settled). **searching 9/10, playmenu settled:** no m20 capture. **Mascot:** none.

*Timing (unscored): the 0.0 s death shot already shows ROUND LOST and the killer card, as in m19.*

## Top 8 by visible impact
1. Kill-cam gun: bottom-right at (98 %, 98 %), scale about 0.92, and keep it clear of x < 83 % at card height so the weapon name reads (t0212).
2. Loadout slot row at 26.9 %, with even 0.6 % gaps (t0036).
3. Kill cap at 69.1 %, hotbar 27 px right (t0054).
4. Ribbon and its text about 7 px lower (t0122).
5. M key straddling the Switch Weapons right edge (t0212).
6. Results rows about 1 % higher, with a 0.9 % button gap (t0140).
7. Found bubble text inset 20 px (t0022).
8. Nothing else open on this lens.

Remaining layout gap worth another round: yes
