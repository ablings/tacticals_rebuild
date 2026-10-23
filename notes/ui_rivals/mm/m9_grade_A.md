# m9 grade A: positioning and layout

**Moved away from RIVALS:** the slowed "Eliminated Bot / HEADSHOT · KILL" hold now runs into the results screen. It sits on the results name plate at y 500-545 and hides "debits". It also takes the Switch Weapons spot in matchpoint, where no Switch Weapons button shows. The slowdown is a capture setting, but the overlap is a real layering bug: hide the line when results open.

**m8 fixes that landed (pixel-checked):**
- HUD score plates: x 474-566/1268 (37.4-44.6%, 7.25% = 139 px), y 1-8.8%. They match t0208 (37.3-44.5%, y 1-8.9%) on countdown, live, kill and death.
- Health bar: x 0.6-20.4%, y 95.4-98.7%. Matches t0208 (0.6-20.9%, 95.2-98.7%).
- death2 now catches the countdown. LOST stays at 13.6%, the killer card stays at x 59.5-94.6%, y 76.2-88.4%, and the hotbar is hidden. All of that matches t0212.

**Not landed:** score plates on the vote screen, found tip bar, loadout slot row, death weapon model, results banner and buttons, Eliminated Y. The searching icon is only part-way there.

**searching 8/10.**
- Icon: ~2% → 3.25% wide (62 px) (t0018).

**found 7/10.** Unchanged.
- Add the tip bar at x 12.5-76.6%, y 92.6-97.4%, and the mascot at x 3-12%, y 76-100% (t0020).

**vote 6/10.** (down from 8, because the capture shows the map-chosen state, not the grid)
- Chosen tile: x 37.9-62.1%, y 23.6-50.1% (it stays at the grid row) → centred at x 38.5-61.1% (434 px), y 37.4-62.7% (t0032: 616-977 x 337-564/1600x900).
- Name strip: 17% → 20% of the tile height (t0032).
- Score plates: still x 460-566 (8.4%), y 3.1-10.9% → 139 px, y 1-8.8%, same as the HUD (t0032).

**loadout 8/10.** Unchanged.
- Slot row top: 25.7% → 26.9% (y 290). Header-to-slots gap: 1% → 2.5% (t0036).

**countdown / live 9/10.** (up from 7) Plates and health bar landed.
- Hotbar slots: 6.7% → 7.6% tall (82 px) (t0054). Minor.

**kill 8/10.**
- "Eliminated": cap band 70.5-73.2% → 69.7-72.3% (y 753-781) (t0054).

**matchpoint 8/10.** (down from 9) The ribbon (x 31.4-68.6%) and WON at 10.8-19.6% match t0122.
- Switch Weapons is missing: show it at x 42.6-58.3%, y 69.6-74.6% (t0122). The lingering Eliminated line sits there. Check whether the 6x slowdown also stretches the 0.4 s pop delay.

**death 8/10.**
- Weapon model: x 83.2-96.2%, y 62.1-93.7% → x 80.6-98%, y 67-98% (t0212).

**death2 8/10.** LOST, the killer card and the hidden hotbar all match t0212.
- Switch Weapons is missing here too: add it at x 42.6-58.3%, y 69.6-74.6% (t0212).
- The SUDDEN DEATH ribbon replaces the score plates, which t0122 does as well. OK.

**results 6/10.** (down from 8, because of the overlap)
- Hide the kill-feed line when results open. It covers the name plate at y 70-76%.
- Banner: 18.8% → 16% wide (x 806-1114) (t0140).
- Button gaps: 3 → 11 px (1%). Button height: 8.4% → 7.8% (84 px) (t0140).

**playmenu 8/10.** Settled.

*Unscored timing note: Eliminated now outlasts the round and reaches results under the 6x slowdown. Check the real hold length against the round-end timing (other session).*

## Top 8 by visible impact
1. Results: hide "Eliminated / HEADSHOT · KILL" when results open (it overlaps the name plate).
2. Vote: centre the chosen tile at y 37.4-62.7%, 22.6% wide (t0032).
3. Switch Weapons is missing in the matchpoint and death2 countdowns: x 42.6-58.3%, y 69.6-74.6% (t0122 / t0212).
4. Vote screen score plates: 139 px, top at y 1%, same as the HUD (t0032).
5. found: tip bar and mascot (t0020).
6. Results: 16% banner, 1% button gaps, 7.8% button height (t0140).
7. Death weapon model to x 80.6-98%, y 67-98% (t0212).
8. kill: "Eliminated" up 0.8%. Loadout slots at y 26.9%. Searching icon at 3.25%.
