# m6 grade A: positioning and layout

**Moved away from RIVALS:** nothing.
**m5 fixes that landed:** matchpoint now keeps the faded WON card (y 13.6%) and Switch Weapons (x 42.2-57.8%, y 69.6-74.2%), like t0122. The kill feed is 3.6% tall (t0054: 3.5%). The "Eliminated Bot" line now exists.
**Not landed:** score-bar plates (85 px = 6.7%, top y 1.8%), the vote bar, the WON card y, the health bar, the found tip bar, the search icon, the death weapon model, the death2 killer card and hotbar, and the results banner and buttons.
Units are screen ratios or 1920x1080 px.

**playmenu 8/10.** Settled.

**searching 8/10.** The pill (x 36-64.2%, height 7.3%) matches t0018.
- Icon: 2% → 3.25% wide (62 px) (t0018: 583-635/1600).

**found 7/10.** The dots (x 44.9-55%, y 50%) and "Match found" (right edge 98%, y 87-91%) match t0020.
- Add the tip bar at x 12.5-76.6%, y 92.6-97.4% (x 240-1471, y 1000-1052), with the mascot at x 3-12%, y 76-100% (t0020).

**vote 7/10.** Unchanged since m5.
- Plates: 8.4% → 7.25% (139 px). Bar: y 3.1-10.9% → 1-8.8%. Reuse the HUD bar.
- Tile gutters: 3 px → 12 px (t0028).

**loadout 8/10.** The map plate (y 20.1%), slot size (5.2%) and weapon tiles (6.3% wide, y 39.7-50.9%) match t0036.
- Slot row top: 25.7% → 26.9% (y 290).

**countdown / live 7/10.**
- Plates: 6.7% → 7.25% (139 px), top y 1.8% → 1% (y 11). The bar then spans x 37.25-62.75% (t0054: 596-1004/1600, top 9/900).
- Health bar: x 2.1-22%, y 93.4-97% → x 0.6-20.9%, y 95.2-98.9% (t0054).

**kill 6/10.** The line exists, but it sits too high and is too small.
- "Eliminated Bot": cap band y 64.8-67.5% → 69.1-73% (y 746-788). Width 11.3% → about 24% (x 38.2-61.9%). Text height 2.7% → 3.9% (42 px) (t0054). The "HEADSHOT • KILL" sub-line doesn't appear in t0054. Drop it, or move it below 73%.
- WON card: y 13.6-22.3% → 10.8-19.7% (y 117-213), still. Its x (43.6-56.4%) matches t0054. LOST stays at 13.6% (t0210).
- Kill feed top: 6.7% → 6.3% (y 68).

**matchpoint 9/10.** The ribbon (x 31.4-68.6%, band y 4.6-9.1%), the faded card and Switch Weapons all match t0122. The card y follows the kill fix.

**death 8/10.** The killer card (x 59.5-94.6%, y 76.2-88.4%) and LOST (y 13.6%) match t0210.
- Weapon model: x 83.2-96.2%, y 62-93.5% → x 80.6-98%, y 67-98% (t0210).

**death2 6/10.** The ribbon, the faded LOST card and Switch Weapons match.
- Keep the killer card at x 59.5-94.7%, y 76.2-88.7% through the countdown, and keep the hotbar, "Pistol" and the hint row hidden (t0212). Missed for three rounds now.

**results 8/10.** The name plate (y 70.8-76.9%) and the button column x (86.1-99.6%) match t0140.
- Banner: 18.8% → 16% wide (x 806-1114).
- Button gaps: 3 px → 11 px (1%). Height: 8.4% → 7.8% (84 px) (t0140).

**victory:** not captured this round (settled cutscene).

*Unscored timing note: the round-end / kill-cam durations are server timing. Nothing new.*

## Top 8 by visible impact
1. death2: keep the killer card and hide the hotbar, weapon name and hints during the countdown (t0212).
2. kill: put "Eliminated <name>" at y 69-73%, 24% wide, 3.9% text height (t0054).
3. kill: WON card up to y 10.8% (t0054).
4. HUD and vote score bar: 139 px plates, top at y 1%. Lift the vote bar 2% (t0054 / t0028).
5. found: tip bar and mascot (t0020).
6. Health bar to x 0.6%, y 95.2-98.9% (t0054).
7. Results: 16% banner, 1% button gaps, 7.8% button height (t0140).
8. Searching icon to 3.25% wide; vote tile gutters to 12 px.
