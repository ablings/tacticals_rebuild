# m25 grade A: positioning and layout

**Moved away from RIVALS: no.** Both m24 fixes landed exactly. Vote is pixel-identical to m24. The other whole-frame diffs (1-9 %) come from the background and character pose, not from UI moves. Results is row-for-row identical to m24.

**m24 fixes**
- Kill line centred at 70.9 %: **landed.** Measured as white-pixel rows, the main line is now y 497-514 of 713, down 13 capture px (about 20 design px) from 484-501. Its centre is 505.5/713 = **70.9 %** and its cap top is 69.7 %, against t0054's 627-649/900 (centre 70.9 %). The HEADSHOT · KILL sub-line moved with it (530-538) and the line is horizontally centred.
- Loadout slot row 9 design px lower: **landed.** The selected outline top went from y 186 to 192 (6 capture px, 9 design px), so 192/713 = **26.9 %**, matching t0036's 242/900 = 26.9 %. The weapon tiles held at y 283 (39.7 %). The row-to-tile gap is now 36.2 → 39.7 % = 3.5 % (RIVALS 3.3 %).

**kill 9.8/10** (t0054): nothing to fix.

**loadout 9.3/10** (t0036)
- Weapon tiles: move them **4 design px up**, top from 429 to 425 px (39.7 → 39.3 %). This closes the row-to-tile gap to 3.3 %. It's under 3 capture px, so it's optional.
- "Map: Warehouse" label: the glyph band is y 153-169 (21.5-23.7 %, about 26 design px tall). RIVALS is 190-206/900 (21.1-22.9 %, about 21 design px). Keep the top and trim the label about 5 design px (for example TextSize 26 → 21), which puts the gap to the slot row at about 4.0 % like RIVALS. That's a borderline type item, so defer to the typography grader if they disagree.

**death 9.8, death2 9.8/10** (t0206, t0212): nothing to fix. The kill-cam gun, killer card and Switch Weapons/M key are where m24 left them.

**results 9/10** (t0140): unchanged since m24, so the m24 items carry over.
- Stat labels 87.7 → 87.1 %. Damage numbers 91.9 → 90.6 %. Button gap 0.6 → 0.9 % (about 6 → 10 design px).

**vote 9.5, countdown 9, live 9, matchpoint 9.7/10:** nothing to fix. The HUD chrome, hotbar and ribbons haven't moved.

**victory: no capture** (the sheet tile is the results screen; the cutscene is settled anyway). **found 9/10, searching 9: no capture.** Found carries over the bubble text inset, about 10 → 20 px (t0022). **playmenu: settled.** **Mascot:** none (our game has none).

*Timing (unscored): Studio slows the short holds about 6x, so the hold lengths aren't judged. Round-end and kill-cam durations are server timing.*

## Top 8 by visible impact
1. Results stat rows about 1 % higher, and the button gap 0.6 → 0.9 % (t0140).
2. Found bubble text inset 10 → 20 px (t0022). Needs an m26 capture to verify.
3. Loadout map label trimmed about 5 design px, top held at 21.1-21.5 % (t0036).
4. Loadout weapon tiles 4 design px up, to 39.3 % (t0036).
5. Recapture victory, found and searching next round (a capture fix only).
6. (none; the kill line, slot row, kill-cam gun, hotbar and M key all match within 1 capture px)
7. (none)
8. (none)

Remaining layout gap worth another round: yes (small: results rows and the found inset; loadout and kill are now essentially at parity)
