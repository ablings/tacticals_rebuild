# r15 grade A: positioning and layout

**Method.** I diffed r14 against r15 in every section. Captures are 1268x713, and dp = px × 1.514. RIVALS frames are 1280x720 (×0.991 to compare with ours). References: `rivals_rec` t0058 (Kit), t0068/t0070 (Shop), t0136 (Settings), t0177 (hub), and `rivals_normal/tasks.png`.

**Moved away from RIVALS:** nothing.

**What changed since r14 (all of it layout-neutral or better):**
- The Settings section header text is smaller ("Performance" spans 215–425, down from 215–481). The bars stayed 57 px tall. That's B's lens, and the bars now read less crowded.
- The Shop banner titles are in Title Case. Their positions didn't change.
- The Missions card names changed, but the grid is the same.
- The "+" social button now sits in a dark disc on Play, Missions and Codes. That matches the dark disc behind the "+" in tasks.png. ✓
- Everything else is the same as in r14. None of the r14 layout fixes landed: Kit gaps, Shop grid and banner, Shop X, Codes inset, dock discs and day circles are all still open.

## Hub: 9.5/10
1. Dock disc tops: 627 → 634 px (0.879 → 0.889H, t0177). The labels already match (0.961 vs 0.960H).

## Play: 9.5/10
The grid top is settled. No fix needed.

## Kit: 9/10
The layout keeps the render on the left of each row and centres the name in the rest of the row. That is deliberate, so I don't grade name centring.
1. Dotted rule to the selected name ("Pistol"): 31 → 46 px (0.043 → 0.064H, t0058: 466→512 of 720). Move Pistol from y 455 to 470, and push the list down by the same amount.
2. Selected name to the first list row: 43 → 49 px (0.060 → 0.069H, t0058: 512→562). The list step is fine (44 vs 45).
3. Right panel block from the level bar down: ~4 px too high. The Statistics button bottom is at 0.970H, and RIVALS has it at 0.975H (t0058: 702/720). Move the bar from 466 to 470 and the action rows from 585/626/667 to 589/630/671. The 41 px step already matches.

## Missions: 9.5/10
These all match tasks.png: panel aspect 1.55, cards 0.226H square, the dotted rule at 0.72 of the panel, the circle centres at 0.861, and the Contracts gap at 0.022H.
1. Day circles: 60 → 56 px diameter (0.084 → 0.079H). Keep the 71.5 px step.

## Shop: 9.5/10
1. Right grid: start x 761 → 738 px (0.600 → 0.582W). Tile 80 → 84 px. Step 99 → 106 px (t0070: 745/853/960, tiles 84 wide).
2. Special offer banner: left edge 218 → 211 px, keeping the right edge at 710 (t0070: 212–710).
3. Banner top 498 → 486 px, so it sits 0.015H above the grid top (497), as in t0070 (407 vs 418).
4. Close X: 50x32 → 57x29 px. Counter y: 35 → 40 px (t0068: X 921–979, counter y 40).

## Codes: 9/10
1. Panel left: 361 → 351 px (0.285 → 0.277W), to line up with the Missions panel (351–898). The X moves from 932 to 923 with it.
2. Content inset: 19 → 28 px (0.015 → 0.022W), the same as Missions.

## Settings: 10/10 (Video page)
- These match t0136 within 1%: the tab bar (201–761 vs 203–775 ×0.991), the X (89x44 vs 89x46), the main panel width (0.402W both), the right edge of the description panel lining up with the X, the 25 px sub-row indent, and the 92 px slider step.
- Can't judge the header-bar height, because RIVALS has no section-header bars in t0136 or kuroko169/settings.jpg.

## Ranked by visible impact
1. Kit: dotted rule to selected gap (+15 px) and selected to list gap (+6 px)
2. Shop: right grid start, tile and step
3. Shop: banner 7 px left and 12 px up
4. Codes: line up with Missions and match the inset
5. Shop: X size and counter y
6. Kit: right block 4 px down
7. Hub: dock discs 7 px down
8. Missions: day circles 60 → 56

Remaining layout gap worth another round: yes
