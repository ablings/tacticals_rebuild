# m5 grade A: positioning and layout

**Moved away from RIVALS:** nothing.
**m4 fixes that landed:** the score-bar gaps are now 20/1268 = 1.6% (31 px) on both the HUD and the vote screen, matching t0056 / t0028. The kill feed moved up to x 81.4-99%, y 6.7-11.2% (t0056: x 80.4-99.4%, y 6.3-9.8%), which is close. **m5_matchpoint now shows the ribbon**: MATCH POINT at x 31.4-68.6% with the band at y 4.6-9.3%, against t0122's x 31.4-68.6% and y 5-9.8%.
**Not landed:** score-bar plate width and top y, the vote plate size, the WON card y, the Eliminated line, the death2 hold, the found tip bar, the results banner and button gaps, the health bar, and the killer-card weapon model.
Units are screen ratios or 1920x1080 px.

**playmenu 8/10.** Settled grid. Nothing to fix.

**searching 8/10.** The pill (x 36-64.2%, y 11.1%) matches t0018.
- Icon: 2% → 3.3% wide (63 px).

**found 7/10.**
- Add the tip bar at x 240-1471, y 998-1052, plus the mascot at x 3-12%, y 76-100% (t0020).

**vote 7/10.** The gaps landed. Grid x 12.8-87.2% and top 12.1% match t0028.
- Plates: 8.4% → 7.25% wide (139 px). Bar top: y 3.1% → 1% (y 11). Bar bottom: 10.9% → 8.8%. Reuse the HUD bar exactly.
- Tile gutters: 3 px → 12 px (t0028 has about 10/1600).

**loadout 8/10.** Unchanged and close to t0036.
- Slot row: top 25.7% → 26.9% (y 290).

**countdown / live 7/10.** The gaps landed.
- Plates: 85/1268 = 6.7% → 7.25% (139 px), which makes the bar span 37.25-62.75% (x 715-1205). Top: y 1.8% → 1% (t0056: y 9/900).
- Health bar: x 2.1-21.9%, y 93.5-96.9% → x 0.6-20.9%, y 95.2-98.9% (t0056).

**kill 7/10.** The kill feed is nearly there.
- WON card: y 13.6-22.4% → 10.8-19.7% (y 117-213), which leaves a 2% gap under the score bar (t0056). Keep LOST at 13.6% (t0210).
- Kill feed: height 4.5% → 3.5% (38 px), top 6.7% → 6.3% (y 68), left edge 81.4% → 80.4% (t0056).
- Add "Eliminated <name>" at x 38-62%, y 69-73% (t0054).

**matchpoint 8/10.** The ribbon's x and height match t0122.
- t0122 also keeps Switch Weapons (x 42.6-58.3%, y 69.7-74.6%) and the faded round card at y 10.8% under the ribbon. Our frame has neither, while death2 has both. Check that Switch Weapons and the card show on a won round too.

**death 8/10.** The killer card (x 59.5-94.6%, y 76.2-88.4%) and the LOST card (y 13.6%) match t0210.
- Weapon model: x 83-96%, y 62-94% → x 80.6-98%, y 67-98% (t0210).

**death2 6/10.** The ribbon, the faded LOST card and Switch Weapons (x 42.2-57.8%, y 69.6-74.2%) are right.
- Keep the killer card at y 76-88%, and hide the hotbar, weapon name and hint row until the countdown ends (t0212).

**results 8/10.** The name plate (x 39.7-60.3%, y 70.8-76.9%), the stats and the button column x (86-99.7%) match t0140.
- Banner: 18.8% → 16% wide (x 806-1114). y 10.7% is OK.
- Button stack gaps: 3 px → 11 px (1%) (t0140: 9/900). Button height: 8.6% → 7.8% (84 px).

**victory: settled.** `m5_victory.png` shows the results screen, not the cutscene.

*Unscored timing note: the round-end / kill-cam durations are server timing. Nothing new.*

## Top 8 by visible impact
1. death2: keep the killer card and hide the hotbar during the countdown (t0212). Missed for two rounds.
2. kill: move the WON card up to y 10.8% and add the "Eliminated <name>" line (t0056 / t0054).
3. Score-bar plates at 139 px with the top at y 1%, on both the HUD and the vote screen. On the vote screen also shrink the 8.4% plates and lift the bar 2% (t0056 / t0028).
4. found: tip bar and mascot (t0020).
5. Health bar to x 0.6%, y 95.2-98.9% (t0056).
6. Results: banner 16% wide, 1% button gaps (t0140).
7. Kill feed height 3.5%, top at 6.3% (t0056).
8. matchpoint: Switch Weapons and the faded round card on a won round (t0122).
