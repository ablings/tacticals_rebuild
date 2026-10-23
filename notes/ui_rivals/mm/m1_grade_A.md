# m1 grade A: positioning and layout

Nothing moved away from RIVALS this round. These m0 fixes landed: the found screen is now a teleport-style screen, Random is the first vote tile, the loadout timer is gone, the hotbar starts at 80% (was 68%), and the killer card plus a hidden hotbar while dead. These did not land: play-menu grid height, vote score bar, loadout block offset, hint row width, score-bar gaps, Leave button, Switch Weapons y, kill feed, death2 card hold, results offsets. Note: there is no `m1_matchpoint.png`. I graded `m1_roundcard.png` (MATCH POINT + ROUND WON) instead. There is no m1 victory capture, so I can't judge it.
Units are 1920x1080 design px or screen ratios.

**playmenu 6/10.** The widths, the Ranked column and the X all still match t0016.
- Grid top: 30.3% (y 327) → 12.9% (y 139). Move the X with it (y 134).
- Missing: the "limited time" strip plus featured row (y 64-100%, t0016).

**searching 8/10.** The pill (36-64%, 10-17%) matches t0018.
- Icon: 1.7% → 3.1% of width (33 → 60 px).

**found 7/10.** The dots are centred like t0020.
- Dots: 4.8% → 5.6% of height (52 → 60 px).
- Status block: y 83-93% → 87-97% (bottom at y 1045). Right edge at 98% is correct.
- Missing: tip bar x 12.5-76.6%, y 92.5-97.5%, with a mascot at x 3-12%.

**vote 6/10.** Grid width and tile height match t0028.
- Score bar top: 7.4% → 1% (y 80 → 11). Plates: 15.1% → 7.2% wide (290 → 139 px). Gaps: 0.5% → 1.7% (32 px). Add the score digit on each plate. The grid top follows: 15.5% → 11.3%.
- Map labels: 2.0% → 3.3% of height (36 px). Label band: 4.1% → 5.2%.

**loadout 6/10.**
- Move the block down 5%. Map band y 158-204 → 212-264. Slots y 216-298 → 290-390 (slot 85 → 100 px). Choices y 351-461 → 425-548 (t0036).
- Map text: 1.8% → 2.7% of height (29 px).

**countdown / live 7/10.**
- Hint row: 37% → 23% wide (x 1467-1908). Text: 1.8% → 1.1% of height.
- Score bar: 39.2-60.8% → 37.3-62.8%. Gaps: 0.4% → 1.7% (t0046).
- Leave (x 1.6-9.4%, y 2.5-6.9%) still sits in the Roblox topbar zone (x 0-11%, y 1-5%). RIVALS has no Leave in the HUD.

**kill 6/10.**
- Switch Weapons: y 63.3-67.5% → 69.6-74.6% (y 752-806). Height 4.2% → 5% (t0122).
- Missing: "Eliminated <name>" at x 38-62%, y 69-73% (t0054).
- Kill feed: 13.5% → 19% wide (259 → 365 px). Y 9.4-12.5% → 6.3-9.8% (t0056).

**roundcard (match point) 7/10.** The card (43.6-56.4%) matches t0122.
- MATCH POINT text: 4.8% → 6.1% of height (66 px). Ribbon: y 1.1-8.4% → 1.7-10% (18-108).
- Hide "First to 2" (y 79) and the plate edges that peek out under the ribbon. Hide the hint row (t0122 keeps only two hints).

**death 7/10.** The killer card x (59.5-94.6%) matches t0210.
- Card: y 69.2-80.3% → 76.2-88.6% (y 823-957). Height 11.1% → 12.3%.
- Weapon model: rises above the card → hangs from the card's right end down to y 98%. Add the @username line under the name.

**death2 3/10.**
- The killer card is gone and the hotbar is back. Keep the card, the ROUND LOST card and Switch Weapons through the intermission, and keep the hotbar hidden (t0212).

**results 7/10.** Nothing changed. Button x (86-99.8%) matches t0140.
- VICTORY banner: 18.8% → 16% wide; y 9.7% → 10.8%.
- Name plate: y 64.3% → 70.8% (y 694 → 764). Stats end 87% → 94%.
- Buttons: bottom 94.9% → 99% (+44 px). Gaps 0.4% → 1.1%.

## Top 8 by visible impact
1. death2: hold the killer card and Switch Weapons through the intermission, hotbar hidden (t0212).
2. vote: score bar at 1% from the top, plates half as wide, digits on the plates (t0028).
3. live: hint row 37% → 23% wide; score-bar gaps; Leave out of the topbar zone (t0046).
4. kill: Switch Weapons down 6%, and add the "Eliminated <name>" line (t0054/t0122).
5. death: killer card 7% lower, weapon hanging below it (t0210).
6. loadout: whole block 5% lower, bigger map text (t0036).
7. playmenu: grid top 30% → 13%, plus the featured row (t0016).
8. results: name plate, stats and buttons about 5% lower (t0140).
