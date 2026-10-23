# r26 grade B: LOOK

Captures are 1268x713. All sizes are in **1920x1080 design px**: ours are capture px × 1.514 and killcard frames × 1.2. Settled items are not graded: gloss, the palette, the Contracts trophy, the grey hub widget labels, the Ranked shield asset, and the Shop right-grid tags at 112. I diffed r25 against r26 for every section. Only the hub dock labels changed in the UI; the other differences are the backdrop and the Kit turntable. [#n] = impact rank.

## Moved away from RIVALS
- None.

## r25 fix check: hub dock labels g 21 → 23. It landed and it's right.
- Ink, r25 → r26 (design px): Missions 80 → 85 wide, Settings 79 → 86, Shop 45 → 50, Kit 26 → 29. Cap height is 18.
- Same-word check against RIVALS (killcard t0004): RIVALS "Shop" is **49 wide, 18 tall**; ours is **50 wide, 18 tall**. That's a match.
- **Correction to r25:** my "→ ~25" target compared "Missions" with "Backpack". Different letters have different widths (Backpack's are wider), so that comparison was wrong. Going to 25 would overshoot "Shop" by ~4 px (~8%). **Keep 23.**
- Dock pitch is 121 against RIVALS' 121, and labels overlap the icon bottoms the same way. The dock is done.

## Hub: 10/10
- No look gaps left that I can see.

## Play: 9.5/10
- Unchanged. Grid and labels match rivals_normal/play.png. The shield is settled.

## Kit: 9/10
- [#3] Locked-row lock glyph ~8 → ~11 (kuroko169/kit.jpg). Carried, minor.
- [#4] The bench lip still reads as a light-grey bezel (~1200x200 band) behind the bottom action bar. RIVALS' bar sits on a dark scene. Scene/camera, not UI. Carried.

## Missions: 9.5/10
- [#5] Contract row icons are flat white glyphs (~42). RIVALS uses coloured item renders at ~42 (tasks.png). Carried, minor.

## Shop: 9.5/10
- No change. The right-grid tags are settled at 112. Tabs and the crate tags match rec t0070.

## Codes: 9.5/10
- [#1] The subtitle is unchanged: cap ~20 against a title cap of ~26 (0.76). The Tasks/Settings panel family runs ~0.6, so the target is g 17 → 14. Carried.

## Settings: 10/10
- [#2] "Version 0" → "Version N · uptime" (rec t0136/t0139). Carried; it's text more than look.

## Ranked
1. Codes subtitle g 17 → 14
2. Settings version + uptime string
3. Kit lock glyph ~11
4. Kit bench lip bezel (scene)
5. Missions contract icons → coloured renders

The r25 headline fix landed. Measured on the same word, the dock labels now match RIVALS. The remaining items are small and carried; none is something a player notices at a glance.

Remaining look gap worth another round: no
