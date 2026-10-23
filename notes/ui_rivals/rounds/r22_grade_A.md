# r22 grade A: positioning and layout

**Method.** I pixel-diffed r21 against r22 in every section at a >40 threshold, measured the dock from the red badge, label and icon rows, and measured the Shop pills, tags and tiles from colour-mask column and row profiles. Captures are 1268x713 with no bands. **Every fix is in 1920x1080 design px** (capture px × 1.514). Capture px appear only in brackets. I don't grade the settled items: Play grid top at y 306, no gloss, the Kit render-left layout, and the mid-slide carousel.

**Moved away from RIVALS:** nothing.

**Did the r21 fixes land?**
- **Hub dock discs 11 lower: LANDED.** Everything in the dock moved down 7 cap (11 design): badges 623 → 630, the Kit gun top 632 → 640, the gear 644 → 651, and the label rows 681–689 → 688–696. The badge tops sit at 0.884H. In t0177 they are at 0.885H. The Play button did not move (still cap 579–607).
- **Shop left Robux pills 112: LANDED.** They went from 64–66 to 74 cap (232–305, 338–411, 443–516), the same width as the yellow tags under them. Each pill is centred on its column.
- **Shop right tiles 126: NOT LANDED (fourth round).** The tiles are still 80 cap (738–818, 844–924, 949–1029), which is 121 design. The pixels are unchanged.
- No other UI layout change. The other diffs are the backdrop camera, the Kit gun render, the Missions third task (Headshots replaces Win matches, same layout) and grader B's Settings description wrap.

## Hub: 10/10 (up from 9.5)
No layout fix. The dock matches t0177.

## Play: 9.5/10
Settled, no UI diff. No fix.

## Kit: 9.5/10
1. Right block from the level bar down: +6 design (bar top 696 → 702; the Contracts, Inspect and Statistics rows +6; t0058). Carried over.
2. Rows under the selected name: +4 design (the step from the Pistol centre to the first row centre goes 70 → 74, t0058). Carried over.

## Missions: 9.5/10
No layout fix.

## Shop: 9.5/10
1. Right grid tile width: 121 → 126 design. Keep the start at 1117 and the step at 160, so the edges are 1117–1243 / 1277–1403 / 1437–1563 (t0070: 84 rec wide = 126 design). Centre the 112 tags on the wider tiles. Carried over, fourth round.
2. Left green Robux pills, height: 47 → 53 design (cap 31 → 35), to match the yellow tags. Keep the vertical centre. In t0070 the green "232" pill and the yellow "5" pill are the same size (~67x33 rec). The widths match now, so the height is the only difference left.
3. Close X: 76x50 → 86x44 design. Counter centre y: 53 → 61 design (t0068). Carried over.
4. Dot pill: lift it 6 design so it sits about 14 design inside the slide bottom. Minor.

## Codes: 9.5/10
1. Panel top: y 204 → 207, and right edge: 1355 → 1358, to match Missions. The X follows the panel: left 1394 → 1397 and top 220 → 223. Minor (2-cap offsets). Carried over.

## Settings: 10/10
No layout change. Still matches t0136.

## Ranked by visible impact
1. Shop: right tile width 121 → 126
2. Shop: left green pill height 47 → 53, to match the tags
3. Shop: X size and counter y
4. Kit: right block +6
5. Kit: rows under the selected name +4
6. Shop: dot pill up 6
7. Codes: top/right +3 to match Missions

Remaining layout gap worth another round: yes
