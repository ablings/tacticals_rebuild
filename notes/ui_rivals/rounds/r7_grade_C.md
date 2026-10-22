# r7 grade C: completeness and finish

dp = capture px ÷ 0.66. Models are not graded.

**One r7 change moved us away from RIVALS: the contract rows.** The ×100 under row 1's glyph now runs into row 2's glyph (capture y ~630–637), so the two reward stacks merge into one column. RIVALS keeps each row's reward inside its own row (tasks.png).

**Checked:**
- **Shop/Kit tag glyph bigger:** landed for size. It is ~22 px → ~33 dp and now matches the number's height, as the key does on tasks/shop tags (t0070). But it is **still the pale cream outline scissors**, not the filled red glyph the headers use, so r6's #1 is still open. The bigger glyph also squeezed the price text: the lower-tile "2,500" is ~10 % narrower than in r6. On Kit, "1,000" now touches the glyph, with ~2 px between them.
- **Reward glyphs bigger, ×N centred under:** landed on the mission cards. The glyph is ~45 dp against RIVALS' ~48, and ×N sits centred and overlapping its foot (tasks.png). The ~45 dp empty gap under the bar is gone. In the hub, ×N is now centred under the glyph and is no longer clipped at the panel edge (r6 showed "×10"), which is a clear fix. In the streak it is unchanged and fine.

## missions: 9/10
1. Contract reward: the glyph is ~52 dp tall and the ×N runs past a 62 dp row pitch. → Shrink the glyph to ~40 dp and let ×N overlap its bottom ~30 %, so each stack fits inside its row (tasks.png).
2. Still open: both contract rows use the eliminations glyph. → Use a ~40 dp weapon icon (tasks.png: rifle, Warper, axe).

## kit: 7/10
1. Tag: pale glyph → the filled red scissors with a dark stroke, and widen the tag ~10 dp so "1,000" gets ~6 dp of clearance.
2. Still open: no Contracts row (t0051); Career card and list merge at y 552; bright floor; cream bench bezel.

## hub: 9.5/10
1. Nothing new. ×N fits inside the panel now.

## shop: 7.5/10
1. Tags (12): pale outline → filled red glyph, ~20–24 dp, with a dark stroke. Restore the r6 number size (t0070).
2. Still open: no type tags on the top tiles; the revolver tile overruns at x 1040; "More →" has no icon; the VIEW button covers the medal on the 2X SCISSORS slide.

## play: 8.5/10
1. Unchanged: Training and Duel Pads are washed-out lilac (t0016).

## codes: 6.5/10
1. Unchanged: white gift, dark input, olive Redeem button, no empty-state icon.

## settings: 8/10
1. Unchanged: no version label (t0138), and the Hotkeys icon is dark.

## What's left, ranked by visible impact
1. Shop and Kit tags: pale outline → the filled red scissors (13 tags), with the number size restored. This is still the last part of the scissors swap.
2. Missions: contract rewards collide → ~40 dp glyph with ×N overlapping it, kept inside the row.
3. Kit: bright floor
4. Kit: Career card and list split
5. Kit: Contracts row
6. Missions: weapon icons on the contract rows
7. Kit: cream bezel, and the cramped "1,000" tag
8. Play: washed-out lower tiles
9. Shop: type tags and the revolver overflow
10. Codes: button, input and empty-state icon
11. Shop: More icon, and VIEW over the medal
12. Settings: version label and Hotkeys icon
