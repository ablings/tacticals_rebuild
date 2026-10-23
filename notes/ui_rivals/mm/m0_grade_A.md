# m0 grade A: positioning and layout

First round, so there are no earlier fixes to check for regressions. All positions below are in 1920x1080 design px or screen ratios. RIVALS frames are under `killcard\f\`.

**playmenu 6/10.** The grid width (13.4-86.5%), the Ranked column (21.7%) and the close X all match t0016.
- Grid: centred vertically, top at 30% (y 327) → top-anchored at 12.9% (y 139), as in t0016.
- Missing: the "Here for a limited time only" strip and the featured row under the grid (y 64-100%, t0016).

**searching 8/10.** The pill matches t0018: 36-64% across, 10-17% down.
- Icon: 39 px → 72 px (3.75% of width).
- Title text: 1.7% → 2% of height (22 px). Optional: drop the progress bar, which RIVALS doesn't have.

**found 3/10.** RIVALS has no "Match found" card. t0020 goes straight to the teleport screen.
- Replace the centred title with: three dots at the screen centre (~60 px each); a tip bar along the bottom (x 240-1470, y 1000-1052) with a mascot to its left; and "Teleporting / N", right-aligned at x 1880, y 950-1030.

**vote 6/10.** The grid width matches t0028 (12.8-87.3%).
- Score bar: top at 7.4% → 1% (y 80 → 10). Team plates are 15% wide → 7.3% (288 → 139 px). Plate gaps 0.4% → 1.6% (31 px). Show the score digit on both plates (t0028).
- Map labels: text 2.2% → 3.3% of height (36 px); label band 4.2% → 5.3% (57 px). Tile gaps 5 → 12 px.
- Random: last tile with "?" → first (leftmost) tile with a shuffle icon (t0028).

**loadout 6/10.** t0036 shows no score bar or timer at all.
- Timer plate (y 7-14%): remove it, or show the standard HUD score bar at 1% from the top.
- Whole block: move down about 5%. Map band y 161-203 → 212-264, band 25% wide, text 1.9% → 2.9% (31 px). Slot row y 216-300 → 290-390. Weapon choices y 351-461 → 420-551.
- Gap from slots to choices: 4.7% → 2.8% of height.

**countdown / live 6/10.**
- Hotbar: x 68-98% → 79-99.4% (x 1513-1908). Inactive slots 161 → ~77 px wide with no backing box; active slot 190 → 156 px (t0046).
- Key-hint row: 37% → 23% of width (x 1467-1908); text 1.8% → 1.2% of height (13 px).
- Score bar: spans 39-61% → 37.3-62.8%, with 8 → 31 px gaps (t0040). "Leave" (top-left, x 30-180, y 30-83) sits where the Roblox topbar goes (x 0-11%, y 1-5%). RIVALS has no Leave button in the HUD, so move it into settings or below y 6%.

**kill 6/10.** The ribbon and ROUND WON card match t0122 (31-69% and 43.6-56.4% across).
- Switch Weapons: y 63-67.5% → 69.6-74.6% (y 752-806), size 298x54.
- Missing: the centred "Eliminated <name>" line at x 38-62%, y 69-73% (t0054).
- MATCH POINT text: 4.8% → 6.3% of height (68 px), and the ribbon must hide "First to 2", which shows at y 79. Kill feed: 13.5% → 18% wide (x 1563-1908, y 68-106), text 1.4% → 2%.

**death 3/10.**
- Missing: the killer card, bottom right, x 1142-1818, y 823-958 (59.5-94.7%, 76-89%), with the weapon model past its right edge (t0210).
- While dead: hide the hotbar and hint row; RIVALS keeps only the health bar (t0210).

**death2 3/10.**
- The killer card should stay up through the intermission, at least 2.5 s (t0212). Ours is already back in the round 3 live HUD with no card.

**victory 5/10.** t0136-t0138 is a cinematic with no UI, and the card only comes in at t0140. Ours shows the results card straight away.
- Add a 2-4 s victory beat with no UI before the card.

**results 7/10.** The button column matches t0140 (86.3-99.5% across).
- Card: VICTORY banner 18.8% → 16% wide. Name plate y 694 → 764 (70.7%), stats down to 95.6%.
- Buttons: bottom edge 94.5% → 99.1% (+50 px); height 77 → 84 px. Stat digits 2.5% → 3.3% of height (36 px).

## Top 8 by visible impact
1. Killer card missing from death and death2 (t0210/t0212).
2. Match found → teleport layout (dots, tip bar, status) (t0020).
3. Hotbar and hint row are 1.6x too wide and start at 68% instead of 79% (t0046).
4. Vote score bar too low and team plates twice too wide (t0028).
5. Kill: Switch Weapons too high, and the "Eliminated <name>" line is missing (t0054/t0122).
6. Leave button clashes with the Roblox topbar zone (t0040).
7. Loadout block about 5% too high, map text too small, no timer plate in RIVALS (t0036).
8. Results card and buttons sit 5-6% too high (t0140).
