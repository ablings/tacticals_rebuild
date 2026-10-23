# m3 grade A: positioning and layout

**Moved away from RIVALS:** nothing. **The matchpoint capture missed the ribbon again**: `m3_matchpoint.png` is a live frame (1:27). The SUDDEN DEATH ribbon in death2 (x 31.4-68.6%, bar y 4.6-9.3%) still matches t0122.
**m2 fixes that landed:** the vote plates are narrower (15.1% → 8.4%) and now carry digits; the hint row is 24.5% wide at x 74-98.6% (t0046 is 23%); the score plates hide behind the ribbon; Switch Weapons y is right (69.6-74.2%, t0212); the killer card is right (76.2-88.4%, t0210).
**Not landed:** play-menu grid top, loadout block offset, score-bar gaps, kill card y, kill feed, the Eliminated line, found tip bar, killer-card hold in death2, results banner width.
Units are screen ratios or 1920x1080 px.

**playmenu 6/10.** Width, Ranked column, avatar and X x-position all match t0016.
- Grid: y 28.3-79.8% → 12.9-64.3% (top y 139). Move the X with it: y 28.3% → 12.4%.

**searching 8/10.** The pill (36-64.2%) matches t0018. Its y is 11.2% against 9.8% there, which is fine under the currency counter.
- Icon: 2% → 3.3% wide (63 px).

**found 8/10.** The dots (x 44.9-55.1%, y 50%) and the status text match t0020.
- Add the tip bar: x 240-1471, y 998-1052, plus a mascot at x 3-12%, y 76-100% (t0020).

**vote 7/10.** Grid x (12.8-87.2%) and top (12.1%) match t0028.
- Score bar: y 3.1-10.9% → 1-8.8% (y 11-95). Gaps 6 px → 31 px (1.6%). Plates 8.4% → 7.3% (140 px).
- Tile gutters: about 3 px → 12 px. Label strip: 4.6% → 5.3% tall.

**loadout 5/10.** Still 9% high. Nothing moved since m2.
- Map band: y 11.1-15.6% → 19.7-24.4% (y 213-264), x 37.5-62.5%.
- Slots: 16.8-25.7% → 26.9-36.1%. Choices: 30.7-42.1% → 38.7-51.1% (t0036).

**countdown / live 7/10.** Missions, weapon name, hotbar and hint row all match t0046.
- Score bar: plates 6.5% → 7.3% (140 px). Gaps 0.5% → 1.6% (31 px), spanning 37.3-62.8%. y 1.8% → 1%. Use the same plate size as the vote screen.
- Health bar: x 2.1-21.9% → 0.6-20.9%, y 93.5-97% → 95.2-98.9%.
- Leave (x 1.6-9.4%, y 2.8-7.6%) overlaps the Roblox topbar zone (x 0.8-10.8%, y 1-5%, t0046). Drop it below y 6% or move it beside the gear.

**kill 6/10.** Card x and height match.
- WON card: y 13.6% → 10.8% (y 117-213, t0056). The LOST card stays at 13.6% (t0210).
- Kill feed: x 85.5-99% → 80.4-99.4%, y 10.4-13.7% → 6.3-9.8% (y 68-106) (t0056).
- Add "Eliminated <name>" at x 38-62%, y 69-73%, and the spectator eye at x 1.6-4.6%, y 90-94% (t0054).

**matchpoint: can't judge.** Recapture.

**death 8/10.** The card, avatar square and LOST card y all match t0210.
- Weapon model: x 83-96%, y 62-94% → x 80.6-98%, y 67-98% (y 726-1062).
- Kill feed: same fix as kill (y 6.3-9.8%). Add the @username line under the name.

**death2 5/10.** The ribbon and Switch Weapons are right.
- Hold the killer card at 76-88% and hide the hotbar, weapon name and hint row through the countdown (t0212).

**results 8/10.** The name plate, stats, Rematch and buttons all match t0140.
- Banner: 18.8% → 16% wide (x 806-1114). Button stack gap: 2 px → 9 px.

**victory: not captured** this round.

## Top 8 by visible impact
1. Loadout block 9% lower: band at y 213, slots at 290, choices at 418 (t0036).
2. Play-menu grid top 28% → 13% (t0016).
3. death2: hold the killer card and hide the hotbar (t0212).
4. kill: "Eliminated <name>" line, plus the WON card at y 10.8% (t0054/t0056).
5. Score bar (HUD and vote): 140 px plates, 31 px gaps, y 1% (t0046/t0028).
6. Kill feed at y 6.3-9.8%, 19% wide (t0056/t0210).
7. found: tip bar and mascot (t0020).
8. Recapture matchpoint, and check the MATCH POINT ribbon still fires (t0122).
