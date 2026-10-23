# r14 grade A: positioning and layout

**Method.** The captures are 1268x713 with no bands, so dp = capture px x 1.514. I measured pixel runs in r13 vs r14 and compared them as fractions of W/H against `rivals_rec` t0068/t0070 (Shop) and t0136 (Settings), and `killcard/f` t0002 (hub). Play, Kit, Missions and Codes have the same layout as in r13 (the diffs are only in the world background, and Codes is pixel-identical).

**Moved away from RIVALS:** nothing. In the Shop, the page dots are no longer on screen because the taller banner now runs to y 711. That matches RIVALS t0068, where the Special Offer card is cut off by the scroll frame, so it is fine as long as our page scrolls.

**Landed (all the r13 fixes that were targeted):**
- Settings toggles: 83x41 → 70x36 capture px (106x54 dp). Target 104x54. ✓
- Toggle rows: now 48–49 px tall, with the step 63 → 54 px (0.076H). Target 0.073H. ✓
- Value boxes: 73x37 px (110x56 dp). Steppers: 37x37 (56x56 dp). Targets 110x57 and 57x57. ✓
- Hub player list: the X row moved from y 74 to 56 and the debits row from 99 to 81. That is 18 px, or 27 dp up, against a target of 28. The panel top is now 0.065H (target 0.064). ✓
- Shop 2X banner: 493x213 px (746x323 dp). Target 747x323. ✓ Its left edge stayed at 218 px, though (see below).

## Hub: 9.5/10
1. Dock discs: tops 0.879 → 0.889H (t0177). Still open from r13.

## Play: 9.5/10
No change and no fix needed. The grid top is settled.

## Kit: 9/10 (unchanged)
1. "Pistol": y 455 → 470 px (0.099H below the top) (rec t0058).
2. List names: centre 0.109 → 0.094W, with the lock beside the name (t0058).
3. Selected row to the first list row: 0.059 → 0.069H.

## Missions: 9.5/10 (unchanged)
1. First contract row +7 dp. Day circles 0.047 → 0.044W.

## Shop: 9.5/10 (up from 9)
1. Banner x: 218 → 211 px (0.172 → 0.166W left edge, 0.561 → 0.555W right edge), keeping the width (t0070: 212–710 of 1280).
2. Banner vs grid top: RIVALS puts the banner 0.015H above the right grid (t0068: 607 vs 618). Ours has them flush (498/497). Move the banner top to 486 px, or the grid down 11 px.
3. Right grid: start 0.600 → 0.582W, tile 0.063 → 0.066W, step 0.078 → 0.084W (t0070). Still open.
4. X: 50 → 57 px (0.039 → 0.045W). Counter: y 0.049 → 0.056H (t0068). Still open.

## Codes: 9/10 (unchanged)
1. Content inset: 0.015 → 0.023W. Panel left: 0.285 → 0.277W, to line up with Missions.

## Settings: 10/10 layout on the Video page (up from 9.5)
1. Optional: toggle-row height 48 → 52 px. RIVALS t0136 "Mute Other Finishers" has about 9 px of padding above and below the toggle, and we have 6. I can't verify the step, because t0136 has no two toggle rows next to each other.
2. Slider rows already match: we step 92–93 px (0.130H), RIVALS 94–96 (0.131H).

## Ranked by visible impact
1. Kit: "Pistol" gap and list-name centring
2. Shop: right grid start, tile and step
3. Shop: banner 7 px left and 11 px above the grid
4. Shop: X size, counter y
5. Kit: selected-to-list gap
6. Codes: inset and Missions alignment
7. Hub: dock discs down
8. Missions: first row, day circles
9. Settings: toggle-row padding (optional)

Remaining layout gap worth another round: yes
