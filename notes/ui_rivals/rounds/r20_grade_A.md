# r20 grade A: positioning and layout

**Method.** I pixel-diffed r19 against r20 in every section at a >40 threshold, grouped the changed rows, and measured the Shop right grid by its purple fill and yellow tags. Captures are 1268x713 with no bands. **Every fix is in 1920x1080 design px** (capture px × 1.514). Capture px appear only in brackets. `rivals_rec` frames are scaled by 0.991. I don't grade the settled items: Play grid top at y 306, no gloss, the Kit render-left layout, and the mid-slide carousel.

**Moved away from RIVALS:** nothing.

**Did the r19 fixes land?**
- **Shop right grid start and step: LANDED.** The tile left edges moved from 761/860/959 to 738/844/949 cap. That is 1117 / 1278 / 1437 design, a 160 step, which matches t0070 (745/853/960 rec). The gutter to the Special Offer slide is 34 cap, and t0070 has 35. Rows, y and tag widths (74 cap = 112 design) are unchanged and fine.
- **Shop tile width: DID NOT LAND.** The tiles are still 80 cap wide (121 design) against t0070's 84 rec (126 design). So the gaps between tiles are now 39 design, where RIVALS has 34.
- **Not applied (unchanged pixels):** Shop X and counter, Kit right block and rows, Codes alignment and inset, and the Hub dock discs. The Kit diff is only the spinning gun render. The Codes diff is the backdrop character. The Hub, Play, Missions and Settings diffs are backdrop only.

## Hub: 9.5/10
1. Dock disc tops: y 949 → 960 design (0.879 → 0.889H, t0177). Carried over.

## Play: 9.5/10
Settled, no UI diff. No fix.

## Kit: 9.5/10
1. Right block from the level bar down: +6 design (bar top 696 → 702; Contracts, Inspect and Statistics rows +6; t0058). Carried over.
2. Rows under the selected name: +4 design (Pistol centre to the first row centre 70 → 74, t0058). Keep the step.

## Missions: 9.5/10
No layout fix.

## Shop: 9.5/10
1. Right grid tile width: 121 → 126 design. Keep the start at 1117 and the step at 160, so the edges are 1117–1243 / 1277–1403 / 1437–1563 (t0070). The right edge then sits about 9 design inside the banner's right edge (1572). Centre the tags on the wider tiles, keeping them 112 wide.
2. Close X: 76x50 → 86x44 design. Counter centre y: 53 → 61 design (t0068). Carried over.
3. Dot pill: lift it 6 design so it sits about 14 design inside the slide bottom. Minor.

## Codes: 9/10
1. Panel left: x 547 → 531 design, to line up with Missions. The X moves with it (1411 → 1397). Carried over.
2. Content inset: 29 → 42 design, the same as Missions.

## Settings: 10/10
No UI change, and it still matches t0136.

## Ranked by visible impact
1. Codes: line up with Missions and match the inset
2. Shop: tile width 121 → 126 (finishes the r19 grid fix)
3. Shop: X size and counter y
4. Kit: right block +6
5. Kit: rows under the selected name +4
6. Hub: dock discs +11
7. Shop: dot pill up 6

Remaining layout gap worth another round: yes
