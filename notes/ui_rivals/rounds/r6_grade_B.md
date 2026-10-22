# r6 grade B: typography, readability, icons

c = anchor cap height. dp = design px (capture px × 1.51). [#n] = impact rank.

## Moved away from RIVALS
- Nothing regressed. One new inconsistency: the three top counters no longer match. The Shop glyph is 30×32 px (2.46 c), but the hub is still 22×24 (1.85 c) and the Kit is 26×27 (1.8 c).

## Landed
- **Reward ×N moved to the lower-right corner.** The hub widget, Missions cards and contract rows read as scissors again: both blades and the left ring are clear. Pass. The "×" still clips the right ring by about 3 px.
- **Shop top counter** now uses the solid red glyph. It's bigger than the old outline glyph (26×18 → 30×32) and the right shape. Pass.

## Partly landed
- **Streak glyph** went from 24×24 to 31×31 in the 57 px circle, so 0.42 → 0.54 of the circle. The target is 0.70 (40 px). The ×N is still small and has no stroke.

## Not landed
- **"Shop's scissors images"**: in the capture, the pack art (×1,000 / ×2,200 / ×5,500) and the price-tag glyphs are pixel-identical to r5. The packs are still the pink pile with white blades, and the tags are still cream outlines at 0.85 c. Either the change didn't deploy or it isn't on this screen.

## Missions: 8/10 (+0.5)
- [#3] Streak glyph 31 → 40 px; ×N bold, ~15 dp with a 1.5 px dark stroke (tasks.png "×1").
- [#4] Card and row glyph is still 22×24 against a 20 dp title, so 24 → 32 px capture (2.4 c). Nudge ×N +3 px right/down so it overlaps only the bottom-right quarter (tasks.png).
- [#9] Contract rows still use the Eliminations claw → the weapon silhouette.
- [#12] Empty days → dim "Day N".

## Shop: 7.5/10, unchanged
- [#2] Pack art: pink pile → a stack of the solid red glyph (2–4 overlapping), matching the counter. RIVALS' key packs are a pile of the same key icon (t0084).
- [#5] Tag glyph cream outline → solid #FFFFFF at ~1.0 c, with strokes at least as heavy as the digit stems; keep the dark-gold edge (t0068).
- [#11] Tag fill flat #F0D800 → the Kit tag gradient.

## Hub: 7.5/10 (+0.5)
- [#1] Counter glyph 22×24 → match the Shop's 30×32 (2.46 c). The same sprite and size on every counter (t0000).
- [#13] Dock labels → #FFFFFF.

## Kit: 7.5/10, unchanged
- [#1] (same fix) Counter glyph 26×27 → 30×32.
- [#6] Tag "1,000": dark-gold 2 px stroke, digits 0.40 × the tag height; glyph pure white (as #5).
- [#8] Slot labels #D3D2D7 → #FFFFFF.
- [#10] Inspect/Next unlock/Statistics 1.22 → 1.0 c; row icons 2.2 → 2.7 c.

## Settings: 7.5/10, unchanged
- [#7] Row labels lighter weight, cap 30 → 27 dp (settings.png).
- [#14] Row icons → 1.8 c.

## Codes: 7/10, unchanged
- [#15] Subtitle 0.82 → 0.65 c; gift 35 → 42 dp.

## Play: 8/10, unchanged
- [#16] Shield 1.45 → 2.5 c.

## Ranked
1. One counter glyph size everywhere: hub and Kit 22–26 px → the Shop's 30×32
2. Shop pack art → a stack of the solid red glyph (the "Shop images" change isn't visible)
3. Streak glyph 0.54 → 0.70 of the circle; bold, stroked ×N
4. Card and row reward glyph 24 → 32 px; ×N only on the bottom-right quarter
5. Tag glyph solid white, heavier, 1.0 c
6. Kit tag digit stroke
7. Settings row weight
8. Kit slot labels white
9. Contract weapon icons
10. Kit row sizes
11. One tag gradient
12. Dim "Day N"
13. Dock labels white
14. Settings icons
15. Codes subtitle/gift
16. Play shield
