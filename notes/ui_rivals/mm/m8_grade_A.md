# m8 grade A: positioning and layout

**Moved away from RIVALS:** nothing this round.

**m7 fixes that landed:**
- LOST card: now at y 97-160/713 (13.6-22.4%, design y 147-242), which matches t0210 and t0212. WON stays at y 77-140 (10.8-19.6%) in kill and matchpoint, matching t0054 and t0122.
- Vote name strips: they are now dark, with diagonal hatching, on all three tiles (y 246-278, 34.5-39%). The m7 strips were a flat green stripe. This now reads like t0028's black/green hatched strips.

**Not landed (pixel-checked against m7):** score plates, health bar, vote bar Y, tile gutters, found tip bar, search icon, loadout slot row, death weapon model, results banner and buttons, and "Eliminated" Y.
Units are screen ratios or 1920x1080 px.

**playmenu 8/10.** Settled.

**searching 8/10.** Unchanged.
- Icon: 1.7% → 3.25% wide (62 px) (t0018).

**found 7/10.** Unchanged.
- Add the tip bar at x 12.5-76.6%, y 92.6-97.4%, with the mascot at x 3-12%, y 76-100% (t0020).

**vote 8/10.** (up from 7) The tile block (x 12.9-87.1%, top at 12.2%, tile height 27%) matches t0028 (x 12.8-87.2%, top 11.4%, height 26.8%).
- Strip height: 4.5% → 5.2% (56 px). Name cap height: ~2.1% → 2.4% (26 px) (t0028: strip 296-343/900).
- Score bar top: y 3.1% → 1% (y 11). Plates: 8.4% wide → 7.25% (139 px) (t0028: 596-712/1600).
- Tile gutters: 3 → 10 px (0.6%) (t0028).

**loadout 8/10.**
- Slot row top: 25.7% → 26.9% (y 290) (t0036).

**countdown / live 7/10.** Unchanged.
- Score plates: x 481-565/1268 (6.7%), y 1.8-9.5% → 7.25% wide (139 px), y 1-8.8% (t0054).
- Health bar: x 2.1-21.9%, y 93.5-96.9% → x 0.6-20.8%, y 95.2-98.7% (t0054).

**kill 8/10.** WON is right.
- "Eliminated": cap band 70.7-73.1% → 69.7-72.3% (y 753-781). Cap height 2.7% (29 px) (t0054).

**matchpoint 9/10.** The ribbon, the faded WON card at 10.8% and Switch Weapons all match t0122.

**death 8/10.** (up from 7) LOST at 13.6% and the killer card (x 59.5-94.6%, y 76.2-88.4%) match t0210.
- Weapon model: x 83.2-96.2%, y 62.4-93.7% → x 80.6-98%, y 67-98% (t0210).

**death2: can't judge.** The capture shows the next live round (1-1, timer at 1:26, hotbar shown, no ribbon), so the countdown was missed. I can't check the faded LOST card at 13.6%, the kept killer card or the hidden hotbar (t0212). Recapture death2 about 1 s after the respawn.

**results 8/10.** Unchanged.
- Banner: 18.8% → 16% wide (x 806-1114).
- Button gaps: 3 → 11 px (1%). Button height: 8.4% → 7.8% (84 px) (t0140).

**victory:** Settled. It shows the results layout.

*Unscored timing note: the death2 capture landing in live play suggests a short respawn-to-round gap. That is server timing, so it's for the other session.*

## Top 8 by visible impact
1. Score bar: 139 px plates, top at y 1%, on the HUD and the vote screen (t0054 / t0028).
2. death2: recapture, then check that the killer card is kept and the hotbar is hidden in the countdown (t0212).
3. Health bar to x 0.6-20.8%, y 95.2-98.7% (t0054).
4. found: tip bar and mascot (t0020).
5. Results: 16% banner, 1% button gaps, 7.8% button height (t0140).
6. Vote: strips 5.2% tall, names 2.4% cap, 10 px gutters (t0028).
7. kill: "Eliminated" up 1%, cap height 2.7% (t0054).
8. Death weapon model to x 80.6-98%; searching icon 3.25%; loadout slots at y 26.9%.
