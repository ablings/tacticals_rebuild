# m2 grade A: positioning and layout

**Moved away from RIVALS:** `m2_matchpoint.png` shows only the live HUD (1:28): there is no MATCH POINT ribbon and no ROUND WON card, but m1 showed both. This is either a capture-timing problem or a regression. The ribbon geometry in death2 (SUDDEN DEATH, x 31-68.5%, y 1-9%) matches t0122.
**m1 fixes that landed:** killer card y (76-88%, t0210), Switch Weapons y (69.8-74.1%, t0212), results name plate, stats and buttons (t0140), VICTORY banner y, found status block, vote grid top.
**Not landed:** play-menu grid top, vote plate width and digits, loadout block offset, hint row width, score-bar gaps, Leave, kill feed, the Eliminated line, death2 card hold.
All measurements are taken on 16:9 frames. Units are screen ratios or 1920x1080 px.

**playmenu 6/10.** Width, Ranked column and X match t0016.
- Grid: y 28.3-80% → 12.8-64% (top y 138). Move the X with it.
- Add the "Here for a limited time" strip (y 74-79%) and the featured row (y 81-100%) (t0016).

**searching 8/10.** The pill (36-64%, y 11-18%) matches t0018.
- Icon: 2% → 3.9% wide (75 px).

**found 8/10.** The dots (y 50%, 5.2% tall) and the status text (y 88-95%) match t0020.
- Missing: tip bar at x 12.5-76.6%, y 92.5-97.5%, with a mascot at x 3-12% (t0020).

**vote 6/10.** Grid top (12.2%) and tile height (27%) match t0028.
- Score bar: y 3-10.4% → 1.5-8.7%. Plates: 15.1% → 7.2% wide (139 px). Gaps: 0.4% → 1.7%.
- Add the score digit on each team plate (t0028).
- Map labels: 2.4% → 3.3% of height.

**loadout 5/10.** The whole block still sits about 9% high.
- Map band: y 11-15.5% → 20.2-24.4% (y 218-264). Slots: 16.9-25.4% → 26.9-35.9%. Choices: 30.6-42% → 39-50.7% (t0036).
- Band width: 22% → 23.5% (x 40-62.5%).

**countdown / live 7/10.** The missions panel, health bar and weapon name all match t0046.
- Hint row: x 62-99% → 76.5-99.5% (23% wide), y 95.3-98.7% → 97.6-99.6% (t0040/t0046).
- Score bar: 39.2-60.8% → 37.2-62.8%, gaps 0.4% → 1.7% (32 px).
- Leave (x 1.5-9.4%, y 2.8-7.4%) is still in the Roblox topbar zone. RIVALS has no Leave button. Hotbar y 87-94% → 91-96%.

**kill 6/10.** The card x matches.
- Add "Eliminated <name>" at x 38-62%, y 69-72.5% (t0054).
- Kill feed: x 85.5-99% → 80.4-99.5% (19% wide), y 10.4-13.7% → 6.3-9.8% (t0056).
- Card: y 13.5% → 10.7% (t0054). Add the spectator eye at x 1.5-4.5%, y 92% (t0054).

**matchpoint: can't judge.** The ribbon and card are missing from the capture. Recapture.

**death 8/10.** The card position landed.
- Add the @username line under the name. Weapon: x 82-92% → 81-98%, y 62-93% → 76-100%, so it hangs off the card's right end (t0210).
- Kill feed: y 10.4% → 6.5% (t0210).

**death2 4/10.** Switch Weapons now sits at the right y.
- Keep the killer card at 76-88%, and keep the hotbar and hint row hidden (t0212).
- ROUND LOST: faded → solid until the respawn (t0212).

**victory 3/10.** Ours already shows the results card.
- RIVALS t0136-t0138 is a winner close-up with no banner and no stats. Its only element is Skip (x 87-98.5%, y 93-99%). Move the banner, stats and buttons to results.

**results 8/10.** Plate, stats and buttons landed.
- VICTORY banner: 18.8% → 16% wide (x 42-58%) (t0140).

## Top 8 by visible impact
1. death2: hold the killer card and hide the hotbar through the intermission (t0212).
2. victory: winner close-up with only Skip; the cards wait for results (t0138).
3. loadout: whole block 9% lower (t0036).
4. playmenu: grid top 28% → 13%, plus the limited-time strip and featured row (t0016).
5. vote: plates half as wide, digits on the plates, bar at 1.5% (t0028).
6. kill: "Eliminated <name>" line plus the kill feed at 6% / 19% wide (t0054/t0056).
7. live: hint row 37% → 23% wide, score-bar gaps, drop Leave (t0046).
8. matchpoint: recapture, and check the ribbon still fires (t0122).
