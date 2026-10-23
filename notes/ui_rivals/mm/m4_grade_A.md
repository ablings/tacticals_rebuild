# m4 grade A: positioning and layout

**Moved away from RIVALS:** nothing.
**m3 fixes that landed:** the loadout block. The map band is now at y 20.1-24.7% (t0036: 19.6-24.4%), the slots at 25.7-34.8% (t0036: 26.9-36.1%) and the choices at 39.7-50.9% (t0036: 38.7-51.1%).
**Not landed:** score-bar gaps and size on both the HUD and the vote screen, the WON card y, the kill-feed position, the Eliminated line, the death2 killer-card hold, the found tip bar, the results banner width and button gaps, the health bar, and Leave in the topbar zone.
**The matchpoint capture missed the ribbon a third time**: `m4_matchpoint.png` is a live frame (1:27). The SUDDEN DEATH ribbon in death2 (x 31.4-68.6%) still matches t0122.
Units are screen ratios or 1920x1080 px.

**playmenu 8/10.** The grid is settled. Width, Ranked column and avatar match t0016 / `rivals_normal\play.png`. Nothing to fix.

**searching 8/10.** The pill (x 36-64.2%, y 11.2%) matches t0018.
- Icon: 2% → 3.3% wide (63 px).

**found 7/10.** The dots (x 44.9-55.1%, y 50%) and the bottom-right status text match t0020.
- Add the tip bar at x 240-1471, y 998-1052, plus the mascot at x 3-12%, y 76-100% (t0020).

**vote 7/10.** Grid x (12.8-87.2%) and top (12.1%) match t0028.
- Score bar: y 3.1-10.9% → 1-8.9% (y 11-96). Gaps 6 px → 31 px (1.6%). Plates 8.4% → 7.25% (139 px). Use the same bar as the HUD.
- Tile gutters: about 3 px → 12 px.

**loadout 8/10.** Landed, see above.
- Slot row: top y 183/713 → 26.9% (y 290). That is a 1.2% nudge down.
- Map band: x 35.9-65.1% → 37.5-62.5% (x 720-1200) (t0036).

**countdown / live 7/10.** Missions, weapon name, hotbar and hint row match t0046.
- Score bar: plates 6.6% → 7.25% (139 px), timer 7.7% (OK). Gaps 0.3% (4 px) → 1.6% (31 px), so the whole bar spans 37.3-62.8% (x 716-1206). Top y 1.8% → 1%.
- Health bar: x 2-22%, y 93.3-97% → x 0.6-20.9%, y 95.2-98.9% (t0046).
- Leave (y 2.8-7.6%) sits in the Roblox topbar zone (x 0.8-10.8%, y 1-5%, t0046). Move it below y 6%.

**kill 6/10.** Card x and size match.
- WON card: y 13.6% → 10.8% (y 117-213) (t0056). Keep LOST at 13.6% (t0210).
- Kill feed: x 85.5-99%, y 10.4-13.7% → x 80.4-99.4%, y 6.3-9.8% (y 68-106) (t0056).
- Add "Eliminated <name>" at x 38-62%, y 69-73% (t0054).

**matchpoint: can't judge.** Recapture it 0.5-1.5 s after the round-2 respawn.

**death 8/10.** The killer card (x 59.5-94.6%, y 76.2-88.4%) and the LOST card match t0210.
- Weapon model: x 83-96%, y 62-94% → x 80.6-98%, y 67-98%.
- Kill feed: same fix as kill.

**death2 5/10.** The ribbon and Switch Weapons (y 69.6-74.2%) are right.
- Hold the killer card at y 76-88% and hide the hotbar, weapon name and hint row until the countdown ends (t0212).

**results 8/10.** The name plate, stats and Rematch match t0140.
- Banner: 18.8% → 16% wide (x 806-1114).
- Button stack gaps: about 3 px → 9 px.

**victory: not captured** (settled cutscene).

*Unscored timing note: the round-end / kill-cam durations are server timing. Nothing new to report.*

## Top 8 by visible impact
1. Score bar on the HUD and vote screen: 139 px plates, 31 px gaps, y 1% (t0046 / t0028). Missed two rounds running.
2. death2: hold the killer card and hide the hotbar (t0212).
3. kill: add the "Eliminated <name>" line, and move the WON card to y 10.8% (t0054 / t0056).
4. Kill feed to y 6.3-9.8%, 19% wide (t0056 / t0210).
5. found: tip bar and mascot (t0020).
6. Recapture matchpoint and confirm the MATCH POINT ribbon fires (t0122).
7. Health bar to x 0.6%, y 95.2%. Leave out of the topbar zone (t0046).
8. Results: banner 16% wide, 9 px button gaps (t0140).
