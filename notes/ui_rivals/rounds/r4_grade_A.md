# r4 grade A: layout and proportion

**Method.** Same as r0–r3. dp = design px. Hub and Kit are measured on the full 785 px window, the menus on the 713 px 16:9 frame. Text sizes are cap heights measured from pixels.

**Moved away from RIVALS. Two of these came from my own r3 fixes, which were wrong.**
- **Kit discs.** Raising them 13 dp went the wrong way. My r3 fix said "raise", but the numbers needed the discs lower. The bar top now cuts the discs at 0.73 of their height (r3: 0.59, t0058: 0.42–0.48). The labels no longer overlap the discs at all; in t0058 they overlap the disc's lower fifth.
- **Play bottom-row titles.** At 81 they are 0.85 of the top row's size. In t0016 the bottom row is the same size as the top: 4v4 45 px vs 1v1 46 px. My r3 "fill ≤50%" rule compared label lengths, not sizes. "Ranked" also got smaller without being on the change list. It went from 1.0 to 0.79 of 1v1; t0016 is 0.89.

**Landed:** Missions panel bottoms. Circles are at 0.619H (t0066: 0.615), Daily bottom at 0.684H (0.685), Contracts top at 0.708H.

## Hub: 9.5/10
1. Gap from Play to the disc tops is still 25 dp. Target 39 dp, so move Play and the party widget up 14 dp (t0285).
2. Player list top 0.080 → 0.062H (t0285).

## Play: 8.5/10
1. Mode titles: bottom row = top row size; Ranked = 0.89 × the 1v1 size; all titles ×0.93. Top row is 0.055H, t0016 is 0.051H.
2. X top 0 → 5 dp above the grid top (t0016).
3. Party widget, still open: avatar 109 → 96 dp, "+" centre 0.766 → 0.784H (t0016).

## Kit: 8/10
1. Lower the discs and glyphs 23 dp from r4, which puts them 10 dp below r3. The bar then cuts each disc at 0.42 and the labels overlap its lower 0.2 (t0058). Slot glyph 0.45 → 0.5 of the disc.
2. Selected slot, open since r1: header to label 0.069 → 0.099H; label centre 0.076 → 0.094W (t0058).
3. Viewmodel centre 0.482 → 0.516H (t0058).

## Missions: 8.5/10
1. **Rule gap.** Cards to rule is 34–35 frame px (0.049H). t0066 is 41 px of 720 (0.057H). Move only the rule down 9 dp. The rule-to-circle gap then drops 0.036 → 0.031H, which matches t0066.
2. **Reward art.** "Rewards at 0.7" did not show up as a size change: the visible scissors are still about 0.45 of the circle, because the image has transparent padding. Target: drawn art 0.65 of the disc, centred at 0.45 of its height, with ×N centred at 0.72 so it overlaps the art's lower third (t0066).
3. First contract row 0.093 → 0.101H below the panel top (t0066).

## Shop: 9/10 (unchanged)
1. Left price buttons 124 → 100 dp (t0068).
2. 2X banner 0.172–0.575W × 0.250H → 0.166–0.555W × 0.297H; right tile step 0.078 → 0.084W (t0070).
3. X 77 → 87 dp (t0068).

## Codes: 9/10
1. Inset 0.015 → 0.023W per side (t0066).

## Settings: 9.5/10
1. Toggles 126×64 → 104×51 dp; value boxes 120×65 → 104×54 dp (t0136).

Party "+" disc: can't judge, because it is lost against this round's darker backdrop.

## Ranked by visible impact
1. Kit: discs back down 23 dp (regression)
2. Play: one title size for both rows, Ranked at 0.89 (regression)
3. Missions: reward art at 0.65 of the disc, ×N overlapping
4. Missions: rule down 9 dp
5. Kit: selected slot
6. Shop: left price buttons
7. Shop: 2X banner, right tile step
8. Hub: Play/dock gap
9. Settings: toggles, value boxes
10. Party widget
11. Kit: viewmodel centre
12. Hub: player list
13. Shop X; Play X offset; Codes inset; Missions first contract row
