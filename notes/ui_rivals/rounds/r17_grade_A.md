# r17 grade A: positioning and layout

**Method.** I pixel-diffed r16 against r17 in every section, cropping the UI regions so the moving backdrop doesn't count. Captures are 1268x713 with no bands, and design px = capture px × 1.514. RIVALS frames are 1280x720, so I multiply them by 0.991 to compare. References: `rivals_rec` t0058 (Kit), t0068/t0070 (Shop), t0136 (Settings), t0177 (hub), and `rivals_normal/tasks.png`. Settled items I don't grade: the Play grid top (y 306), gloss, the Kit row layout, and mid-slide carousel frames.

**Moved away from RIVALS:** nothing important. The pager dots now sit inside the banner. In t0070 they sit 19 px below it (621 → 640). Our banner bottom (699) is only 14 px above the frame edge, so there is no room below it, and inside is the right trade-off.

**Did the r16 fixes land?**
- **Shop pager dots: LANDED.** The pill spans x 394–520 and y 672–694, with five dots and the active one in the middle. Its centre is x 457, and the banner centre is 457.5, so it is centred. It is fully visible and no longer clipped. It clears the View button (531) by 11 px.
- **Shop carousel slide:** the dark strip on the left is now only 6 px (211–217) and the right edge sits at 703. That fits a frame caught mid-slide, so I'm not flagging it.
- **Still open, pixels unchanged:** Kit gaps (Pistol still at y 455), Shop right grid (start 761, step 99) and X, Codes position (panel left still 361, X at 932), hub dock discs (tops at 627) and Missions day circles. The Missions diff is only the mission names. The Codes diff is only the Redeem fill (grade B's fix).

## Hub: 9.5/10
1. Dock disc tops: 627 → 634 px (0.879 → 0.889H, t0177).

## Play: 9.5/10
Settled, and there is no diff in the UI region. No fix needed.

## Kit: 9/10
1. Dotted rule to "Pistol": 31 → 46 px. Move Pistol from y 455 to 470 and push the list down by the same amount (t0058: 466→512).
2. "Pistol" to the first list row: 43 → 49 px (t0058: 512→562).
3. Right block from the level bar down: 4 px lower (bar at 466 → 470, rows at 585/626/667 → 589/630/671; t0058).

## Missions: 9.5/10
1. Day circles: 60 → 56 px diameter. Keep the 71.5 px step (tasks.png).

## Shop: 9.5/10
1. Right grid: start x 761 → 738 px, tile 80 → 83 px, step 99 → 106 px (t0070: 745/853/960 ×0.991).
2. Close X: 50x32 → 57x29 px. Counter y: 35 → 40 px (t0068).
3. Dot pill: there is only 5 px between its bottom and the banner bottom (694 vs 699), which is tight against the rounded corner region. Lift it 4 px to give a ~9 px inset (≈14 design px). This is minor.

## Codes: 9/10
1. Panel left: 361 → 351 px, to line up with Missions (351–898). The X moves from 932 to 923 with it.
2. Content inset: 19 → 28 px, the same as Missions.

## Settings: 10/10
The UI region is unchanged. The header bars, tab bar, X, 25 px sub-row indent and 92 px slider step still match t0136.

## Ranked by visible impact
1. Kit: dotted rule to selected gap (+15 px) and selected to list gap (+6 px)
2. Shop: right grid start, tile and step
3. Codes: line up with Missions and match the inset
4. Shop: X size and counter y
5. Kit: right block 4 px down
6. Hub: dock discs 7 px down
7. Missions: day circles 60 → 56
8. Shop: dot pill 4 px up

Remaining layout gap worth another round: yes
