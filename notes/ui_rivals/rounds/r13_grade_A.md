# r13 grade A: positioning and layout

**Method.** Captures are 1268x713 with no bands, so dp = capture px x 1.514. I compared fractions of W/H against `rivals_rec` (1280x720) and `killcard/f` (1600x900), and checked each r12_grade_A fix against r12 vs r13.

**Moved away from RIVALS:** nothing.

**Landed:** Settings row labels. "Optimized Lighting" went from 282 to 237 px wide (x0.84). That is 13.2 px per character, or 13.3 at 1280 W. RIVALS t0136 "Finisher Volume" is 13.1. This now matches, and the label still sits 0.026W right of the icon, as in t0136.

**Not landed (expected, since only the label size changed):** every other r12 layout fix. I spot-checked these in r13: Kit "Pistol" is still at y 455, the Shop 2X banner is still 0.172–0.575W x 0.250H, the Shop X is still 0.039W, and the counter is still at y 0.049H. All are unchanged.

## Hub: 9.5/10
1. Player list top: 0.090 → 0.064H, with the X row at 0.076H (rec t0177, kc t0002).
2. Dock discs: tops 0.879 → 0.889H so the labels overlap the disc foot (t0177).

## Play: 9.5/10
No layout fix. The grid top (y 306) is settled, and the tile widths, X and party widget match t0016.

## Kit: 9/10
1. Header-to-selected gap: "Pistol" 455 → 470 px (0.099H) (rec t0058).
2. List names: centre at 0.094W rather than the current right-leaning 0.109W, with the lock beside the name (t0058, "Revolver").
3. Selected row to the first list row: 0.059 → 0.069H.
4. Bottom bar: 4 slots vs RIVALS 5 (Charm). Can't judge whether that's intended.

## Missions: 9.5/10
1. First contract row: +7 dp (0.093 → 0.100H below the panel top) (rec t0066).
2. Day circles: 0.047 → 0.044W in diameter.

## Shop: 9/10
1. 2X banner: 0.172–0.575W x 0.250H → 0.166–0.555W x 0.299H (rec t0070).
2. Right grid: start 0.600 → 0.582W, tile 0.063 → 0.066W, step 0.078 → 0.084W (t0070).
3. X: 0.039 → 0.045W (t0068).
4. Counter: y 0.049 → 0.056H, the same as the hub and Kit (t0068).

## Codes: 9/10
1. Content inset: 0.015 → 0.023W per side (t0066 Missions cards).
2. Panel left: 0.285 → 0.277W, so it lines up with Missions.

## Settings: 9.5/10 (up from 9)
1. Toggles: 83x41 capture px (126x61 dp) → 69x36 (104x54 dp) (rec t0136, "Mute Other Finishers").
2. Toggle-only rows: 57 → 48 px tall, with the row step 63 → 52 px (0.088 → 0.073H) (t0136).
3. Value boxes: 118x64 → 110x57 dp. Steppers: 61x64 → 57x57 dp (t0136).
4. Section bars ("Performance" / "Camera"): can't judge, because no RIVALS Video page was captured.

## Ranked by visible impact
1. Shop: 2X banner size
2. Kit: selected-label gap and centring of the list names
3. Hub: player list up 0.026H
4. Settings: toggle size and toggle-row height
5. Shop: right grid start and step
6. Settings: value box and stepper size
7. Kit: selected-to-list gap
8. Shop: X size, counter y
9. Codes: inset and alignment with Missions
10. Hub: dock discs down
11. Missions: first contract row, day circles
12. Kit: Charm slot (if intended)

Remaining layout gap worth another round: yes
