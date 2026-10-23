# m23 grade A: positioning and layout

**Moved away from RIVALS:** no. The test map changed from Warehouse to Practice Range, so the whole-frame diffs (75-84 % of pixels) are background. The vote diff (5.3 %) is the map tile and the loadout diff is the map name. The HUD chrome on countdown, live, kill, loadout and results hasn't moved, so those grades and fixes carry over from m22. No lobby-side captures, so those carry over too.

**m22 fix 1, the kill-cam gun scaled x1.12: landed, but it drifted left.**
- death (crop measured at 2x): the gun spans x 1046-1236, y 440-698 in capture px. That's x 82.5-97.5 %, y 61.7-97.9 %. In m22 it spanned x 1074-1244 (170 px). It's now 190 px wide, which is x1.12 and 15.0 % of the frame, so it matches t0212's 15.0 % body width. The bottom held at 97.9 %.
- The right edge slid 8 capture px left (98.1 % → 97.5 %). The scale wasn't taken about the true bottom-right, probably the mesh bounds' pivot. RIVALS' t0212 span is x 83.1-98.1 %.
- The top is at 61.7 % against t0212's 67.2 %. m22 flagged this as the accepted cost of the x1.12-1.15 option, so I'm not re-flagging it.
- The grip still clears "eliminated you with Pistol" by about 25 px. death2 shows the same placement.

**m22 fix 2, the MATCH POINT ribbon 10 design px lower: landed.** The red band moved from y 34-58 to y 41-66 (+7 capture px, which is +10.6 design px). The white title moved from y 13-52 to y 19-58. The band now sits at 5.8-9.3 % and the text at 2.7-8.1 %, inside t0122's 5.3-9.8 % band. The gap to the ROUND card (top at y 77) is 11 capture px, so they don't collide. SUDDEN DEATH (death2) moved identically.

**death 9.5/10** (t0206, t0212)
- Kill-cam gun: shift it 12 design px right (capture 8 px), from 1584-1871 to 1596-1883 px, so it spans x 83.1-98.1 % like t0212. Keep the bottom at 97.9 %.

**death2 9.5/10** (t0212)
- The same gun shift: +12 design px on x.
- M key: straddle the Switch Weapons right edge at x 56.6-58.3 %. It still sits inside the button (x 55.4-57.1 %). Carried over.

**matchpoint 9.7/10** (t0122): nothing to fix.

**loadout 8/10** (t0036)
- Slot row top: 25.7 % → 26.9 %, with even 0.6 % (11 px) gaps. Carried over.

**kill 8/10** (t0054)
- "Eliminated" cap: y 70.5 % → 69.1 %. Hotbar 27 px right (x 81.3-99.4 %). Carried over; still unchanged in m23.

**results 9/10** (t0140)
- Stat labels 87.7 % → 87.1 %. Damage numbers 91.9 % → 90.6 %. Button gap 0.6 % → 0.9 %. Carried over.

**found 9/10** (t0022, no m23 capture)
- Bubble text inset about 10 → 20 px on each side. Carried over.

**vote 9.5/10, countdown / live 9/10, victory: nothing to fix** (the cutscene is settled). **searching 9/10, playmenu settled:** no m23 capture. **Mascot:** none (our game has none).

*Timing (unscored): Studio slows the short holds about 6x, so the hold lengths aren't judged. The 0.0 s death shot already shows ROUND LOST and the killer card, as in m22.*

## Top 8 by visible impact
1. Loadout slot row at 26.9 %, with even 0.6 % gaps (t0036).
2. Kill cap at 69.1 %, hotbar 27 px right (t0054).
3. M key straddling the Switch Weapons right edge (t0212).
4. Results rows about 1 % higher, with a 0.9 % button gap (t0140).
5. Kill-cam gun 12 design px right, so its right edge returns to 98.1 % (t0212).
6. Found bubble text inset 20 px (t0022).
7. (none further; every other screen is within a few px)
8. (none)

Remaining layout gap worth another round: yes
