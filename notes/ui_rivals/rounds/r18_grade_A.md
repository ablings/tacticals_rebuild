# r18 grade A: positioning and layout

**Method.** I pixel-diffed r17 against r18 in every section and measured text rows by brightness profile. Captures are 1268x713 with no bands. Design px = capture px × 1.514. RIVALS `rivals_rec` frames are 1280x720, so I scale them by 0.991. Kit was checked against t0058 (Secondary / Handgun / Revolver block). I don't grade the settled items: Play grid top at y 306, gloss, the Kit render-left layout, and mid-slide carousel frames.

**Moved away from RIVALS:** nothing.

**Did the r17 fix land? Kit list: PARTLY.**
- The dotted rule is still at y 423–424. "Pistol" moved from rows 447–461 to 456–470, so it is **+9 capture px (≈ +14 design px), not +15 capture px**. It looks like the 15 was applied in design px, but my r17 numbers were in capture px.
- Rule to "Pistol" centre: 31 → 39.5 px. RIVALS t0058 is rule 465 → Handgun 510 → 45 px (×0.991 ≈ 44.6). That leaves about 5–6 px.
- "Pistol" centre to the first row centre: 44.5 → 45.5 px. t0058 is Handgun 510 → Revolver 559, so 49 px (≈ 48.6). That leaves about 3 px. The row step (44) is unchanged and fine.
- The whole list moved down 9–10 px with Pistol. Revolver now ends at y 689, and the clipped 6th row at the frame bottom is gone, which is cleaner.
- The right block (level bar 460–472, rows 576/617/658) didn't change.

**Still open, unchanged pixels:** Shop right grid (start 761, step 99) and X, hub dock discs (tops 627), Codes position (the diff is backdrop only), and Missions day circles. The Missions diff is new mission content (Win matches → Headshots) with no geometry change. The Play and Settings diffs are backdrop only.

## Hub: 9.5/10
1. Dock disc tops: 627 → 634 px (0.879 → 0.889H, t0177).

## Play: 9.5/10
Settled, no UI diff. No fix.

## Kit: 9.5/10 (up from 9)
1. "Pistol": 6 capture px lower, centre 463 → 469 (+9 design px), so rule to selected = 45 (t0058).
2. Selected to first row: +3 capture px (centre gap 45.5 → 48.5, +5 design px). Push the list down 9 px in total so the 44 px step stays.
3. Right block from the level bar down: 4 px lower (460 → 464 top; rows 576/617/658 → 580/621/662; t0058).

## Missions: 9.5/10
1. Day circles: 60 → 56 px diameter, keeping the 71.5 px step (tasks.png).

## Shop: 9.5/10
1. Right grid: start x 761 → 738, tile 80 → 83, step 99 → 106 px (t0070: 745/853/960 ×0.991).
2. Close X: 50x32 → 57x29 px. Counter y: 35 → 40 px (t0068).
3. Dot pill: lift 4 px so it sits about 9 px inside the banner bottom. Minor.

## Codes: 9/10
1. Panel left: 361 → 351 px, to line up with Missions (351–898). The X moves from 932 to 923 with it.
2. Content inset: 19 → 28 px, the same as Missions.

## Settings: 10/10
No UI change, and it still matches t0136.

## Ranked by visible impact
1. Shop: right grid start, tile and step
2. Codes: line up with Missions and match the inset
3. Kit: Pistol +6 px and list +9 px (the rest of the r17 fix; note that these are capture px)
4. Shop: X size and counter y
5. Kit: right block 4 px down
6. Hub: dock discs 7 px down
7. Missions: day circles 60 → 56
8. Shop: dot pill 4 px up

Remaining layout gap worth another round: yes
