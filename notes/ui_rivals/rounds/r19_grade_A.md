# r19 grade A: positioning and layout

**Method.** I pixel-diffed r18 against r19 in every section at a >40 threshold and measured rows and columns by colour and brightness profile. Captures are 1268x713 with no bands. **Every fix below is in 1920x1080 design px** (capture px × 1.514). Capture px appear only in brackets as the measurement. RIVALS `rivals_rec` frames are scaled by 0.991. I don't grade the settled items: Play grid top at y 306, no gloss, the Kit render-left layout, and the mid-slide carousel.

**Moved away from RIVALS:** nothing.

**Did the r18 fixes land?**
- **Kit names: LANDED.** "Pistol" moved from rows 456–470 to 462–476 [+6 cap = +9 design], and the whole list moved with it. The rule (y 423.5 cap) to the Pistol centre is now 45.5 cap. t0058 has 44.6, so that gap is closed. I measure the rule to the Pistol cap top as 38 cap (58 design), not 30 design. The handoff number doesn't match, but the result matches RIVALS. Pistol centre to the Suppressed centre is now 46 cap. t0058 has 48.6, so about 4 design px are left. The step stays at about 44 cap, which is fine.
- **Shop top-row price tags wider: DID NOT LAND.** The tags are pixel-identical to r18: x 235–300 / 341–406 / 447–512 cap, y 430–464, which is 100x53 design each. The tag-to-tile width ratio, 66/97 = 0.68, already equals RIVALS t0070 (57/84 = 0.68). Widening is only needed if B's larger price text goes in.
- **Not applied (unchanged pixels):** Kit right block, Shop right grid and X, Codes alignment, and Hub dock. The Missions diff is the ×N labels and the Codes diff is the Redeem label (B's lens). The Play and Settings diffs are backdrop only.

## Hub: 9.5/10
1. Dock disc tops: y 949 → 960 design (0.879 → 0.889H, t0177).

## Play: 9.5/10
Settled, no UI diff. No fix.

## Kit: 9.5/10
1. Rows under the selected name: +4 design px (Pistol centre to the first row centre 70 → 74 design, t0058). Keep the step.
2. Right block from the level bar down: +6 design px (bar top 696 → 702; Contracts, Inspect and Statistics rows +6; t0058).

## Missions: 9.5/10
No layout fix. Day circles measure about 86 design px (57 cap), which is within 2 px of tasks.png. I withdraw last round's 60 → 56.

## Shop: 9.5/10
1. Right grid: start x 1152 → 1117, tile width 121 → 126, column step 150 → 160 design (t0070: 745/853/960).
2. Close X: 76x48 → 86x44 design. Counter centre y: 53 → 61 design (t0068).
3. Top-row price tags: only if the text goes up to the right grid's size, widen from 100 → 112 design to match the right grid tags. Keep the height at 53 and the centres on the tiles (t0070).
4. Dot pill: lift by 6 design px so it sits about 14 design px inside the slide bottom. Minor.

## Codes: 9/10
1. Panel left: x 547 → 531 design, to line up with Missions. The X moves with it (1411 → 1397).
2. Content inset: 29 → 42 design, the same as Missions.

## Settings: 10/10
No UI change, and it still matches t0136.

## Ranked by visible impact
1. Shop: right grid start, tile and step
2. Codes: line up with Missions and match the inset
3. Shop: X size and counter y
4. Kit: right block +6 design
5. Kit: rows under the selected name +4 design
6. Hub: dock discs +11 design
7. Shop: top tags 112 wide, only together with bigger price text
8. Shop: dot pill up 6

Remaining layout gap worth another round: yes
