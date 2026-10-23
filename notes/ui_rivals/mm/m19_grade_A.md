# m19 grade A: positioning and layout

**Moved away from RIVALS:** nothing big, but the right half of the death arc went past its target. A frame diff of m18 against m19 shows the death arc is the only UI change. The other diffs are the character pose (results, kill, countdown), the scene, Daily Missions values, and the vote tile outline, which is capture timing. There are no m19 found, searching or playmenu captures, so those keep their m18 grades.

**m18 arc nudges, checked against t0206 (red mask, both at 1268x713):**
- **Fin 5 px up, 6 px right: landed, slightly past the target.** The apex is (47.6 %, 26.4 %) against (47.5 %, 26.6 %). It moved about 0.8 % up when 0.5 % was asked, so it now sits about 0.25 % (3 px) high. x matches. It hangs to 33.9 % against 33.5 %, so the overhang is down to about 4 px. It is still a diamond (settled).
- **Right half middle lower: landed at x 50-51 %, past the target from x 52 % on.** Our upper edge is 31.0 / 31.4 % at x 50 / 51 % against 30.9 / 31.3 %, which is a match. At x 52-54 % it is 31.7 / 32.0 / 32.3 % against 31.3 / 31.6 / 31.8 %, so it is about 0.45 % (5 px) low. Our right half is now a straight falling line; RIVALS holds flat to x 53 % and only bends down at the tail.
- **Tail extended: landed, about 4 px long.** The end is x 55.4 % against 55.1 %. The tip column is y 32.4-34.4 % against 32.5-33.7 %, so the tip bottom is about 0.7 % (7 px) low.
- **Found this round (also in m18):** the left half rises too steeply. Upper edge at x 43 / 45 % is 33.9 / 31.7 % against 35.2 / 33.4 %, about 1.3-1.7 % (14-18 px) high. RIVALS' left half is a gentle convex bow; ours is a concave hook. The left end (36.6-37.7 %) still matches.

**death 9/10** (t0206)
- Left half: lower the upper edge at x 43-45 % (826-864 px) by 14-18 px, to 380 px at x 43 % and 361 px at x 45 %, keeping the left end. This makes one convex bow into the fin.
- Right half: raise x 52-54 % (998-1037 px) by about 5 px, to 338 / 341 / 343 px, so it holds flat and then curves down. Keep x 50-51 % and the tail-end height (351 px).
- Tail: trim about 4 px (to x 1058 px) and taper the tip bottom from 371 → 364 px. Fin apex 3 px down to y 288 px.

**death2 9/10** (t0212)
- Weapon model: x 83.2-96.2 %, y 62.4-93.7 % → x 80.6-98 %, y 67-98 %. Carried over.

**matchpoint 9.5/10** (t0122)
- Ribbon and its text: about 7 px lower, y 5.3-9.8 %. Carried over.
- M key: straddle the Switch Weapons right edge, x 56.6-58.3 % (t0212). Carried over.

**loadout 8/10** (t0036)
- Slot row top: 25.7 % → 26.9 %, with even 0.6 % (11 px) gaps. Carried over (no UI diff).

**kill 8/10** (t0054)
- "Eliminated" cap: y 70.5 % → 69.1 %. Hotbar 27 px right (x 81.3-99.4 %). Carried over.

**results 9/10** (t0140)
- Stat labels: 87.7 % → 87.1 %. Damage numbers: 91.9 % → 90.6 %. Button gap: 0.6 % → 0.9 %. Carried over (only the pose changed).

**found 9/10** (t0022, no m19 capture)
- Bubble text inset: about 10 → 20 px on each side. Carried over.

**vote 9.5/10, countdown / live 9/10, victory: nothing to fix** (the cutscene is settled). **searching 9/10, playmenu settled:** no m19 capture. **Mascot:** none.

*Timing (unscored): the 0.0 s death shot already shows ROUND LOST and the killer card, as in m18.*

## Top 8 by visible impact
1. Death2 weapon model → x 80.6-98 %, y 67-98 % (t0212).
2. Death arc left half 14-18 px lower at x 43-45 %, as one convex bow (t0206).
3. Loadout slot row at 26.9 %, with even 0.6 % gaps (t0036).
4. Kill cap at 69.1 %, hotbar 27 px right (t0054).
5. Death arc right half: x 52-54 % about 5 px higher, tail 4 px shorter with a tapered tip; fin 3 px down (t0206).
6. Ribbon and its text about 7 px lower (t0122).
7. M key straddling the Switch Weapons right edge (t0212).
8. Results rows about 1 % higher with a 0.9 % button gap (t0140); found bubble text inset 20 px (t0022).

Remaining layout gap worth another round: yes
