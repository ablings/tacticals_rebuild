# r23 grade A: positioning and layout

**Method.** I pixel-diffed r22 against r23 in every section at a >40 threshold, then measured the Shop tiles and tags and the Settings description from colour-mask row and column profiles. Captures are 1268x713 with no bands. **Every fix is in 1920x1080 design px** (capture px × 1.514). Capture px appear only in brackets. I don't grade the settled items: Play grid top at y 306, no gloss, the Kit render-left layout, and the mid-slide carousel.

**Moved away from RIVALS:** nothing.

**Did the r22 fixes land?**
- **Shop right tiles 126: LANDED.** The tiles are now 83 cap (738–820, 844–926, 949–1031), which is 126 design. The start is still 1117 and the step is still 160. The 112 tags (74 cap) are centred on the tiles: the tile centre is 779 cap and the tag centre is 778.5.
- **Settings description title 24 clear: LANDED.** "Optimized Lighting" now ends at cap 1042 (it was 1058), and the panel edge is at 1066. That leaves 24 cap = 36 design, which is past the 24 minimum and closer to RIVALS' ~45 (t0136). The glyph height went from 28 to 26 cap, so the title was scaled down slightly. The body now wraps to 2 lines and ends at cap 1025, with ≥24 clear.
- **Correction to my r22 Shop fix 2:** the left green pills measure 34 cap (cap 317–350 at x 234 and x 302), and that is unchanged since r22. The yellow tags are 35 cap and the right-grid tags are 35. The pills are 51 design against 53 for the tags. That 2-design gap is too small to act on, so I'm dropping the fix.
- No other UI change. The other diffs are the backdrop camera (hub, Play, Shop, Settings), the Kit gun render, the Missions task rotation (same layout) and the character behind the Codes panel. The hub dock is pixel-identical apart from the backdrop.

## Hub: 10/10
No fix. The dock still matches t0177.

## Play: 9.5/10
Settled, no UI diff. No fix.

## Kit: 9.5/10
1. Right block from the level bar down: +6 (bar top 696 → 702; the Contracts, Inspect and Statistics rows +6; t0058). Carried over.
2. Rows under the selected name: +4 (the step from the Pistol centre to the first row centre goes 70 → 74, t0058). Carried over.

## Missions: 9.5/10
No layout fix.

## Shop: 10/10 (up from 9.5)
1. Close X: 76x50 → 86x44. Counter centre y: 53 → 61 (t0068). Carried over.
2. Dot pill: lift it 6 so it sits about 14 inside the slide bottom. Minor.

## Codes: 9.5/10
1. Panel top: y 204 → 207, and right edge: 1355 → 1358, to match Missions. The X follows the panel: left 1394 → 1397 and top 220 → 223. Minor. Carried over.

## Settings: 10/10
Both inset fixes landed. The layout matches t0136.

## Ranked by visible impact
1. Shop: X 86x44 and counter y 61
2. Kit: right block +6
3. Kit: rows under the selected name +4
4. Shop: dot pill up 6
5. Codes: top/right +3 to match Missions

Both r22 fixes landed. Every remaining gap is 3–10 design px, and none of them changes how a screen reads.

Remaining layout gap worth another round: no
