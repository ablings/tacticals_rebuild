# r25 grade B: LOOK (fresh full pass)

Captures are 1268x713. All sizes are in **1920x1080 design px**: ours are capture px × 1.514, killcard frames × 1.2, and rivals_rec frames × 1.5. The UI didn't change since r24, so I re-measured ink on every section against its RIVALS frame. I don't grade the settled items: gloss, the palette, the Contracts trophy, the grey hub widget labels and the red Ranked shield. [#n] = impact rank.

## Moved away from RIVALS
- None. No UI changed.

## Carried items retired after re-measuring
- **Hub "Play" label**: our ink is 65 wide; RIVALS is 64 (killcard t0010, measured on the width the claim tag leaves clear). It already matches, so drop the "g 26" item.
- **Missions "Near Completion" text**: our ink is 148 wide; RIVALS is 149 (tasks.png). It matches, so drop it.
- **Shop left-tag 53 → 51**: you can't see a 2 px change. Dropped.

## Hub: 9/10
- [#1] **Bottom-nav labels are ~15% too small (new).** Our "Missions" ink is 80 wide. RIVALS "Backpack" (also 8 letters) is 95 (killcard t0004), and "Weapons" is 88 against our 7-letter equivalents. Target: label size g ~21 → ~25, with the same Bold weight and baseline. Icons (~84) and the bar already match.
- I measured the Daily Missions widget and it's fine. The title is 23 tall vs 24. The rows are 21 tall vs 18, so ours are already a touch larger.

## Play: 9.5/10
- Grid width 1402 vs 1404 and aspect 2.52 vs 2.53, mode labels "1v1" 135 wide vs 133 (rivals_normal/play.png). Nothing new; the shield is settled.

## Kit: 9/10
- [#5] Locked-row lock glyph 8 → ~11 (kuroko169/kit.jpg). Carried, minor.
- [#6] The bottom action bar matches kit.jpg: Leave X, slashed boxes and label weight. Behind it, the workbench edge in the scene reads as a light-grey bezel round the bar (~600x100). RIVALS' bar sits on a dark, blurred scene. This is a camera/backdrop issue, not UI: lower the camera or darken the bench lip.

## Missions: 9.5/10
- [#7] The contract row icons are flat white glyphs (~42). RIVALS uses small coloured item renders at the same ~42 (tasks.png: Assault Rifle, Warper, Battle Axe). Use the Kit list's weapon renders instead. Minor.
- Card height (244 vs 245), section gaps (61/88 vs 61/83) and row pitch (62 vs 62) all match.

## Shop: 9.5/10
- [#2] **Bottom-right grid price tags are too big (new).** Ours are 112x50. RIVALS is ~100x38 (rivals_rec t0070: "25", "250", "3" tags). That's shorter than its top crate tags, which are ~99x47 and which ours (112x53) roughly match. Target: bottom-grid tags 100x38 with the price text scaled to match, overlapping the tile bottom by the same ~1/4.
- Tabs (144 wide) match t0070.

## Codes: 9.5/10
- [#3] Subtitle g 17 → 14 (~0.6 of the title; Tasks/Settings panel family). Carried.

## Settings: 10/10
- [#4] "Version 0" → "Version N · uptime" (rec t0136/t0139). Carried; it's text, not look.

## Ranked
1. Hub nav labels g ~21 → ~25
2. Shop bottom-grid price tags 112x50 → 100x38
3. Codes subtitle g 14
4. Settings version + uptime
5. Kit lock glyph ~11
6. Kit bench lip reading as a bezel (scene)
7. Missions contract icons → coloured renders

The fresh pass found two real misses, the nav label size and the bottom-grid shop tags. It also retired three carried items that already match. A player will see both new items: the nav labels are on screen all the time in the hub.

Remaining look gap worth another round: yes
