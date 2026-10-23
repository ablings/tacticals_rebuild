# r21 grade A: positioning and layout

**Method.** I pixel-diffed r20 against r21 in every section at a >40 threshold, measured panel edges from column and row luminance steps, and measured the Shop tags as yellow connected components. Captures are 1268x713 with no bands. **Every fix is in 1920x1080 design px** (capture px × 1.514). Capture px appear only in brackets. I don't grade the settled items: Play grid top at y 306, no gloss, the Kit render-left layout, and the mid-slide carousel.

**Moved away from RIVALS:** nothing.

**Did the r20 fixes land?**
- **Codes panel left at x 531: LANDED.** The panel fill now starts at cap 351, which is 531 design. Missions also starts at 351, so the two left edges match exactly. In r20 the Codes panel started at 361 (547).
- **Codes content inset of 42: LANDED.** The input box starts at cap 378, so the inset is 27 cap (41 design). Missions' cards start at 379 (42). On the right, the Redeem button ends at 867 and the panel at 895, which is also a 42 inset.
- **Shop left price tags 112 wide: LANDED.** The tags went from 66 to 74 cap (100 → 112 design) and are 35 cap (53) tall. They are centred on their tiles: the tile centre and the tag centre are both at 267.5 cap.
- **Not applied (unchanged pixels):** Shop right tile width (still 80 cap = 121), Shop X and counter, Shop dot pill, Kit right block and row step, and the Hub dock discs (the badge rows are at cap 624 in both rounds). The Kit diff is only the gun render. The Hub diff is the backdrop camera.

## Hub: 9.5/10
1. Dock disc tops: y 949 → 960 design (0.879 → 0.889H, t0177). Carried over.

## Play: 9.5/10
Settled, no UI diff. No fix.

## Kit: 9.5/10
1. Right block from the level bar down: +6 design (bar top 696 → 702; the Contracts, Inspect and Statistics rows +6; t0058). Carried over.
2. Rows under the selected name: +4 design (the step from the Pistol centre to the first row centre goes 70 → 74, t0058). Carried over.

## Missions: 9.5/10
No layout fix.

## Shop: 9.5/10
1. Right grid tile width: 121 → 126 design. Keep the start at 1117 and the step at 160, so the edges are 1117–1243 / 1277–1403 / 1437–1563 (t0070). Centre the 112 tags on the wider tiles. Carried over, third round.
2. Left green Robux pills: 100 → 112 wide (cap 66 → 74), centred on the same column. They are now narrower than the yellow tags under them. In t0070 the green "232" pill and the yellow "5" pill in a column are the same width (~67 rec each).
3. Close X: 76x50 → 86x44 design. Counter centre y: 53 → 61 design (t0068). Carried over.
4. Dot pill: lift it 6 design so it sits about 14 design inside the slide bottom. Minor.

## Codes: 9.5/10 (up from 9)
1. Panel top: y 204 → 207, and right edge: 1355 → 1358, to match Missions exactly (cap top 135 vs 137, right 895 vs 897). The X follows the panel: left 1394 → 1397 and top 220 → 223. Minor. These are 2-cap offsets, at the edge of what I can measure.

## Settings: 10/10
No UI change. Still matches t0136.

## Ranked by visible impact
1. Shop: right tile width 121 → 126
2. Shop: left green pills 100 → 112, to match the tags under them
3. Shop: X size and counter y
4. Kit: right block +6
5. Kit: rows under the selected name +4
6. Hub: dock discs +11
7. Shop: dot pill up 6
8. Codes: top/right +3 to match Missions

Remaining layout gap worth another round: yes
