# r12 grade A: positioning and layout

**Method.** Captures are 1268x713 with no bands, so dp = capture px x 1.514. I used fractions of W/H against `rivals_rec` (1280x720), `killcard/f` (1600x900) and `rivals_normal` (1920x1010). There are no r11 grade files, so I checked against r10_grade_A and the r11 captures.

**Moved away from RIVALS:** nothing.

**Landed since r10:** Kit row order (Contracts / Inspect / Statistics). Kit top counter now the hub's size (32 px glyph, y 0.056H in both). Kit header-to-selected gap partly (0.069 → 0.077H). Shop left price buttons at 66 px = 0.052W (rec t0068: 0.052W).

## Hub: 9.5/10
1. Player list top: 0.090 → 0.064H, with the X row at 0.104 → 0.076H. That is about 28 dp up (rec t0177, kc t0002).
2. Dock discs: tops 0.879 → 0.889H (about +11 dp) so the labels overlap the disc foot as in t0177. The Play bottom already matches (0.853H).

## Play: 9.5/10
No layout fix. The grid (0.135–0.865W), Ranked tile width (0.217W), X (0.058W, 0.020W gap), party widget (0.069W, 0.764/0.860H) and Ranked text insets all match t0016 and play.png.

## Kit: 9/10
1. Header-to-selected gap: 0.077 → 0.099H, so "Pistol" goes 455 → 470 px (rec t0058, Secondary → Handgun).
2. Selected label centre: 0.076 → 0.094W. Unselected names: 0.109 → 0.094W, centred in the panel like "Revolver" in t0058. Put the lock beside the name, not in a fixed column at 0.170W.
3. Selected row to the first list row: 0.059 → 0.069H. The row step (0.062H) already matches.
4. The bottom bar has 4 slots and RIVALS has 5 (Charm). Can't judge whether that's deliberate. If not, add the slot at the same 0.063W step.

## Missions: 9.5/10
1. First contract row: 0.093 → 0.100H below the Contracts panel top (rec t0066). That's about 7 dp.
2. Day circles: 0.047 → 0.044W in diameter. The spacing (0.056W) already matches.

## Shop: 9/10
1. 2X banner: 0.172–0.574W x 0.250H → 0.166–0.555W x 0.299H (rec t0070, Special Offer).
2. Right tile grid: start 0.600 → 0.582W, tile 0.063 → 0.066W, step 0.078 → 0.084W (t0070).
3. X: 0.039 → 0.045W (76 → 87 dp) (t0068).
4. Currency counter: y 0.049 → 0.056H, the same as the hub and Kit (t0068).

## Codes: 9/10
1. Content inset: 0.015 → 0.023W per side, matching the Missions cards (t0066).
2. Panel left: 0.285 → 0.277W and X at 0.728W, so Codes lines up with Missions. They differ by 10 px today.

## Settings: 9/10
1. Toggles: 126x61 → 104x54 dp. Toggle rows: 0.080 → 0.068H (rec t0136).
2. Value boxes: 118x64 → 110x57 dp. Steppers: 61x64 → 57x57 dp (t0136).
3. Row labels (now real Rubik): about 15 % larger than RIVALS (15.3 vs 13.1 px per character at 1280 W). Scale them by about 0.87. The description title already matches.
4. "Performance" / "Camera" section bars: can't judge, because no RIVALS Video page was captured.

## Ranked by visible impact
1. Shop: 2X banner size
2. Kit: selected-label gap and centring of the list names
3. Hub: player list up 0.026H
4. Settings: toggle and value-box size, toggle row height
5. Shop: right tile grid start and step
6. Settings: label size x0.87
7. Kit: selected-to-list gap
8. Shop: X size, counter y
9. Codes: inset and alignment with Missions
10. Hub: dock discs down
11. Missions: first contract row, day circle size
12. Kit: Charm slot (if intended)

Remaining layout gap worth another round: yes
