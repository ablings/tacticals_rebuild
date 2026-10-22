# r5 grade C: completeness and finish

dp = capture px ÷ 0.66. Models not graded.

**One r5 change moved us away from RIVALS. Missions sort:** "Near Completion" now overflows its box, and the ▼ draws on top of the "o" ("Completi▼n"). RIVALS keeps the text clear of the arrow (tasks.png).

**Checked:**
- **Filled scissors:** only partly landed. The hub and Kit headers now use one filled, upright red scissors, and so do the missions streak, cards and rows. The shop header still has the old tilted, hollow red/grey scissors. Every yellow price tag (shop and Kit) still uses the pale outline glyph.
- **Kit level-up tag:** landed. The gradient runs (250,241,86) → (244,212,16), which matches t0051. "1,000" reads. The glyph next to it is still the pale outline one and washes out.
- **Near Completion:** the default is right, but the text clips (see above).
- **Streak (r4 Missions 1):** fixed. The glyph fills ~70 % of the disc and ×N overlaps it.

## missions: 8.5/10
1. Sort box: the text is ~171 dp wide in a ~209 dp box, and the arrow overlaps it. RIVALS has ~139 dp of text and the ▼ in its own ~30 dp slot (tasks.png). → Make the text 18 → 15 dp, or widen the box to 240 dp, and pad 12 dp before the arrow.
2. Contract rows still all use the eliminations glyph. → Use the Fists and Pistol icons, ~40 dp (tasks.png).
3. Card rewards are still ~30 dp with ×N underneath. RIVALS uses ~45 dp with ×N overlapping (tasks.png).

## kit: 7/10
1. Price-tag glyph: pale outline on yellow. → Use the filled scissors with a 1.5 px dark stroke.
2. Still no Contracts row above Overview/Statistics (t0051).
3. Still open: the Career card and the list merge at y 552, the floor is bright, and the cream bench frames the action bar.

## hub: 9/10
1. The header is fixed. The mission-row ×N sits under the glyph instead of overlapping it, which is minor.

## shop: 7/10
1. Header scissors: still tilted and hollow, so it no longer matches the hub. → Use the hub's filled, upright 36 dp glyph.
2. Price-tag glyphs are pale outlines (12 tags). → Use the filled glyph with a dark stroke (t0070).
3. Still open: no type tags; the revolver overruns at x 1040; "More →" has no icon; VIEW covers the medal.

## play: 8.5/10
1. Unchanged: Training and Duel Pads are still washed-out lilac next to the saturated top row (t0016).

## codes: 6.5/10
1. Unchanged: the white gift, dark input, olive Redeem, and no icon on the empty card.

## settings: 8/10
1. Unchanged: no grey version label at the bottom right (t0138), and the Hotkeys icon is dark.

## What's left, ranked by visible impact
1. Missions: sort text clipped by the arrow (regression)
2. Finish the scissors swap: shop header, plus all price-tag glyphs in the shop and Kit
3. Kit: bright floor
4. Kit: card/list split
5. Kit: Contracts row
6. Missions: weapon icons on contract rows
7. Missions: card reward size and overlapping ×N
8. Kit: cream bezel
9. Play: washed-out lower tiles
10. Shop: tags, overflow
11. Codes: button, input
12. Shop: More icon, VIEW over the medal
13. Settings: version label, Hotkeys icon
