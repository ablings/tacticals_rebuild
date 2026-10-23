# m7 grade A: positioning and layout

**Moved away from RIVALS:** the LOST card moved up with WON. It now sits at y 10.8-19.5% in death and death2. RIVALS keeps LOST at y 13.6-22.4% (t0210, t0212: 122-202/900), while WON sits at 10.8% (t0054, t0122). Give LOST its own Y and put it back to y 147-242.

**m6 fixes that landed:** the WON card is at y 10.8-19.5% (y 117-211), matching t0054 and t0122, and the faded card in matchpoint follows it. "Eliminated Bot" now sits at cap band y 70.7-73.1% and the "HEADSHOT • KILL" sub-line has moved below it, to 75.6%. The m6 width target (24%) was measured from the long name "SilkyChicken". Measured word by word, "Eliminated" is 10.3% wide here against 9.9% in t0054, so the size is about right.
**Not landed:** the death2 killer card and hotbar (fourth round), the score-bar plates, the health bar, the vote bar, the found tip bar, the search icon, the loadout slot row, the death weapon model, and the results banner and buttons.
Units are screen ratios or 1920x1080 px.

**playmenu 8/10.** Settled.

**searching 8/10.** The pill (x 36.1-64.1%) matches t0018.
- Icon: 1.7% → 3.25% wide (62 px) (t0018).

**found 7/10.** The dots and "Match found" match t0020.
- Add the tip bar at x 12.5-76.6%, y 92.6-97.4%, with the mascot at x 3-12%, y 76-100% (t0020).

**vote 7/10.** Pixel-identical to m6.
- Plates 139 px wide. Bar y 3.1% → 1% (t0028). Tile gutters 3 → 12 px.

**loadout 8/10.**
- Slot row top: 25.7% → 26.9% (y 290) (t0036).

**countdown / live 7/10.** Unchanged.
- Score plates: x 481-565/1268 (6.7% wide), y 1.8-9.5% → 7.25% wide (139 px), y 1-8.8% (y 11-95). The bar then spans x 37.25-62.75% (t0054: 596-1004/1600).
- Health bar: x 2.1-21.9%, y 93.5-96.9% → x 0.6-20.8%, y 95.2-98.7% (t0054).

**kill 8/10.**
- "Eliminated": cap band 70.7-73.1% → 69.7-72.3% (up 10 px, to y 753-781). Cap height 2.4% → 2.7% (29 px) (t0054). The capture caught a fade-in, so I can't judge opacity.
- Kill feed top: 6.7% → 6.3% (y 68).

**matchpoint 9/10.** The ribbon (x 31.4-68.6%), the faded WON card (10.8%) and Switch Weapons (y 69.6-74.2%) match t0122.

**death 7/10.** The killer card (x 59.5-94.6%, y 76.2-88.4%) matches t0210.
- LOST card: y 10.8% → 13.6% (see the top of this report).
- Weapon model: x 83.2-96.2%, y 62.4-93.7% → x 80.6-98%, y 67-98% (t0210).

**death2 5/10.** The SUDDEN DEATH ribbon and Switch Weapons are placed right.
- The killer card is gone. Keep it at x 59.5-94.7%, y 76.2-88.7% through the countdown (t0212).
- Hide the hotbar, the "Pistol" label and the hint row during the countdown (t0212 shows none).
- Faded LOST: y 10.8% → 13.6%.

**results 8/10.** Unchanged since m6.
- Banner: 18.8% → 16% wide (x 806-1114).
- Button gaps: 3 px → 11 px (1%). Height: 8.4% → 7.8% (84 px) (t0140).

**victory:** `m7_victory.png` is the results screen (it differs from `m7_results.png` by only 1.5/255), so the cutscene wasn't captured. I can't judge it, and it is settled anyway.

*Unscored timing note: round-end / kill-cam durations are server timing. Nothing new.*

## Top 8 by visible impact
1. death2: keep the killer card and hide the hotbar, weapon name and hints during the countdown (t0212).
2. LOST card back to y 13.6% (death, death2), with WON staying at 10.8% (t0210 vs t0054).
3. Score bar: 139 px plates, top at y 1% (HUD and vote) (t0054 / t0028).
4. Health bar to x 0.6-20.8%, y 95.2-98.7% (t0054).
5. found: tip bar and mascot (t0020).
6. Results: 16% banner, 1% button gaps, 7.8% button height (t0140).
7. kill: "Eliminated" up 1% and cap height 2.7% (t0054).
8. Death weapon model to x 80.6-98%; searching icon to 3.25%; loadout slots to y 26.9%.
