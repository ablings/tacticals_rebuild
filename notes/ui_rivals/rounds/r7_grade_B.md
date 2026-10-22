# r7 grade B: typography, readability, icons

c = digit cap height. dp = design px (capture px × 1.51). [#n] = impact rank.

## Moved away from RIVALS
- **Shop tags.** The glyph is now 24 px in a 33 px tag (0.73), which is 2.2× the digit cap. The digits shrank from about 14 px to 11 px (0.33 of the tag). In RIVALS t0068 the white key on a "5" tag is about 1.1 c and about 0.45 of the tag, and the number is the larger element. Our tag now reads glyph-first. The glyph is still a cream outline.
- **Kit counter overshot.** It is now 35×37 px, while the hub is 29×31 and the Shop is 30×30. The three counters still don't match.

## Landed
- **Hub counter** went from 22×24 to 29×31, so it matches the Shop. Pass.
- **Card glyph** went from 22×24 to 28×30. The ×N is centred, as in tasks.png. Pass, but the ×N sits about 3 px *below* the rings with no overlap. RIVALS tucks the "×1" against the bottom of the key.
- **Streak glyph** went from 30 to 36×37 in the 57 px circle, so 0.54 → 0.64. Close to the 0.70 target.

## New problems
- **Contract rows.** The glyph (29) plus ×N (11) is 41 px, the same as the row pitch, so row 1's "×100" touches row 2's glyph with a 0 px gap. The column reads as four stacked items, not two rewards.
- **Hub widget.** The glyph is still 23×23, but the centred ×N is now 34–36 px wide, 1.5× the glyph. The number dominates the icon.
- **Streak ×N** has an 8 px cap (12 dp), against 11 px on the cards. It sits on the rings, so the scissors lose their handles.

## Missions: 8/10, unchanged
- [#2] Contract reward block: glyph 28 → 22 px with ×N overlapping the glyph by 3 px, or row pitch 41 → 50 px. Keep a gap of at least 6 px between rows (tasks.png rows).
- [#4] Streak glyph 36 → 40 px. ×N cap 8 → 11 px, the same as the cards, with a 1.5 px dark stroke. Place it so it covers less than half the ring height (tasks.png streak "×1").
- [#8] Card ×N: raise it 4 px so it overlaps the ring bottoms (tasks.png card).
- [#10] Contract icons: claw → weapon silhouette.

## Hub: 7.5/10, unchanged
- [#3] Widget glyph 23 → 28 px (the same sprite size as the Missions cards). ×N cap stays at 11 px.
- [#12] Dock labels → #FFFFFF.

## Shop: 7/10 (−0.5)
- [#1] Tag: glyph 0.73 → about 0.45 of the tag height (about 1.1 c). Digits 11 → 15 px, at 0.45 of the tag. Glyph solid #FFFFFF with the dark-gold edge (t0068 "5 key" tags).
- [#5] Pack art is pixel-identical to r6. Use 2–4 overlapping solid red counter glyphs in place of the pink pile (t0084).
- [#11] Tag gradient: one style for the Shop and the Kit.

## Kit: 7.5/10, unchanged
- [#1] (same family) Counter 35×37 → 30×30, the same as the hub and Shop (t0000).
- [#6] The "1,000" tag glyph touches the last digit. Add a gap of at least 4 px and a solid white glyph. Use a dark-gold 2 px stroke on the digits.
- [#9] Slot labels → #FFFFFF.
- [#13] Inspect/Next unlock/Statistics 1.22 → 1.0 c.

## Settings: 7.5/10, unchanged
- [#7] Row label cap 30 → 27 dp, lighter weight (settings.png).

## Codes: 7/10, unchanged
- [#14] Subtitle 0.82 → 0.65 c; gift 35 → 42 dp.

## Play: 8/10, unchanged
- [#15] Shield 1.45 → 2.5 c.

## Ranked
1. Shop/Kit tags: glyph 0.73 → 0.45 of the tag, digits up to 0.45, solid white glyph. Kit counter 35 → 30 px.
2. Contract rows: the reward block collides with the next row.
3. Hub widget glyph 23 → 28 px (the ×N is wider than the icon)
4. Streak ×N 8 → 11 px cap with a stroke; glyph 36 → 40
5. Shop pack art: red glyph stack (unchanged since r5)
6. Kit tag glyph/digit gap and stroke
7. Settings row weight
8. Card ×N: tuck it 4 px up
9. Kit slot labels white
10. Contract weapon icons
11. One tag gradient
12. Dock labels white
13. Kit row sizes
14. Codes subtitle/gift
15. Play shield
