# m24 grade A: positioning and layout

**Moved away from RIVALS: yes, the kill line.** "Eliminated Bot" moved up 20 capture px (30 design px). Measured as white-pixel rows, the main line is now y 484-501 (67.9-70.3 %), so its centre is at 69.1 % as asked. In t0054 the RIVALS line is y 627-649 of 900 (69.7-72.1 %), so its centre is at 70.9 %. The 69.1 % figure carried through m20-m23 was the **cap top**, and it was applied as the line centre. We were 1.0 % low and are now 1.8 % high. The test map is back to Warehouse, so the whole-frame diffs (73-85 %) are background. I compared crops instead.

**m23 fixes**
- Kill-cam gun +12 design px: **landed.** The span is x 1054-1245 (death and death2), so the right edge is at 98.2 % against t0212's 98.1 %. The bottom held at about 97.8 %, and the overlap with the killer card is unchanged.
- Kill line at 69.1 %: **landed as written, but overshot RIVALS** (see above).
- Hotbar 27 px right: **landed.** The slots are at x 1034-1261 (81.5-99.4 %), and "Pistol" moved with them (right edge 99.4 %; t0054 is 99.0 %).
- M key straddling the Switch Weapons edge: **landed.** The button is at x 42.2-57.8 % and the key at 56.9-58.7 %, so the key is centred on the edge. In t0212 the button is at 42.6-57.4 %, the key at 56.4-58.3 %, and the key/button height ratio is 0.69 in both.
- Loadout slot row at 26.9 %: **partial.** The selected outline top moved from y 182 to 186 (25.5 → 26.1 %). t0036 is 242/900 = 26.9 %.

**kill 8.5/10** (t0054)
- "Eliminated" line: move it **20 design px down**, from a centre at 746 px (69.1 %) to 766 px (70.9 %), which puts the cap top at 69.7 %. The HEADSHOT · KILL sub-line moves with it.

**loadout 8.5/10** (t0036)
- Slot row (selected outline top): move it **+9 design px**, from 282 to 291 px (26.1 → 26.9 %). The weapon tiles stay at 39.7 % (RIVALS 39.3 %), and the row-to-tile gap shrinks to about 3.5 % (RIVALS 3.3 %). The slot gaps (about 0.4 %) are close enough to RIVALS' 0.5 %.

**death 9.8/10, death2 9.8/10** (t0206, t0212): nothing to fix.

**results 9/10** (t0140): carried over and unchanged in m24.
- Stat labels 87.7 → 87.1 %. Damage numbers 91.9 → 90.6 %. Button gap 0.6 → 0.9 %.

**victory: can't judge.** m24_victory is pixel-identical to m24_results (the VICTORY / debits plate, stat card and buttons). It was captured after the cutscene, so there's no letterbox or VICTORY title to check (settled anyway). Recapture during the cutscene if the next round needs it.

**found 9/10** (no m24 capture): bubble text inset about 10 → 20 px. Carried over.

**vote 9.5, countdown / live 9, matchpoint 9.7/10:** nothing to fix. The HUD chrome hasn't moved. **searching 9, playmenu settled:** no capture. **Mascot:** none (our game has none).

*Timing (unscored): Studio slows the short holds about 6x, so the hold lengths aren't judged.*

## Top 8 by visible impact
1. Kill line 20 design px down, centre at 70.9 % (t0054). This undoes the overshoot.
2. Loadout slot row +9 design px, to 26.9 % (t0036).
3. Results rows about 1 % higher, with a 0.9 % button gap (t0140).
4. Found bubble text inset 20 px (t0022).
5. Recapture victory during the cutscene (a capture fix, not a UI change).
6. (none further; the kill-cam gun, hotbar and M key all now match within 1 capture px)
7. (none)
8. (none)

Remaining layout gap worth another round: yes
