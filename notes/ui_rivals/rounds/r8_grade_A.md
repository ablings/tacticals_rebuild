# r8 grade A: layout and proportion

**Method.** Same as r0–r7. dp = design px (menus ×1.515, hub ×1.515). Rec = `rivals_rec`. Pixel diffs against r7: Play, Kit, Shop, Codes and Settings changed only in the background or viewmodel, so their layout is unchanged.

**Moved away from RIVALS (two small ones):**
- Contract-row scissors: drawn art went from 28×29 to **17×15 px**. The t0066 key in a row is 20×21 px (rows 3–4), so it went from 1.35× too big to 0.75× too small. The 40 dp box has transparent padding, so the art fills only about 0.6 of it.
- Streak ×N: the label grew from 8 to **11 px** (488–498 in a 58 px disc, 0.19). In the t0066 disc, the ×1 is about 8 px (0.15) and its bottom sits 12 px above the disc edge. Ours is 8 px above it. "×400" now fills 0.62 of the disc and looks crowded.

**Landed**
- Missions cards: ×N lifted 6 px. Its top (365) covers the art's last 3–4 px, about 12% (ref ×1: 2 px of a 22 px key, about 8%).
- Contract rows: no more collision. Row 1's ×100 ends at 624 and row 2's art starts at 638, a 14 px gap.
- Hub: ×N lifted 5 px. ×300 now clears the panel bottom by 7 px (was 3).
- Counters are one size: 11 px in the hub, cards, rows and streak. RIVALS also uses one size (card 10, row 9 px), so the rule is right. The size runs about 1.15× large.

**Not landed:** the row ×N still doesn't overlap the art. The art ends at 611 and the text starts at 614. In the hub, art and text just touch (0 px).

## Hub: 9.5/10
1. Tracker ×N: up 3 px (≈5 dp) for about 2 px of overlap (t0285).
2. Glyph: art is 25×23 px, ref key 20×20. 56 → 48 dp, or keep 56 and trim the padding.
3. Play bottom to disc tops: 25 → 39 dp. Carried over.
4. Player list top: 0.080 → 0.062H. Carried over.

## Play: 9.5/10
1. X top: 5 dp above the grid (t0016).
2. Party avatar 110 → 100 dp; "+" centre 0.764 → 0.784H.

## Kit: 8.5/10
1. Slot glyph: 0.43 → 0.53 of the disc (t0058).
2. Selected slot: header to label 0.069 → 0.099H; label x 0.076 → 0.094W.
3. Viewmodel centre: 0.489 → 0.516H.

## Missions: 9/10
1. Row reward art: 17 → 21 px drawn (box 40 → ~50 dp at the current padding, or crop the padding), then lift ×N about 4 px (≈6 dp) so it covers the art's foot by 2 px (t0066).
2. Streak ×N: 11 → 8 px; bottom 12 px above the disc edge (t0066).
3. One counter size: 11 → 9.5 px (≈14 dp) everywhere (t0066: 9–10 px).
4. First contract row: 0.093 → 0.101H below the panel top. Carried over.

## Shop: 9/10
1. Left price buttons: 124 → 100 dp (t0068).
2. 2X banner: 0.166–0.555W × 0.297H; right tile step 0.084W (t0070).
3. X: 77 → 87 dp.

## Codes: 9/10
1. Inset: 0.015 → 0.023W per side.

## Settings: 9.5/10
1. Toggles 127×64 → 104×51 dp; value boxes 120×65 → 104×54 dp (t0136).

## Ranked by visible impact
1. Kit: selected-slot spacing
2. Missions: row reward art 17 → 21 px, then ×N onto the foot
3. Shop: left price buttons 100 dp
4. Shop: 2X banner and tile step
5. Missions: streak ×N back to 8 px
6. Hub: Play/dock gap
7. Kit: slot glyph 0.53
8. Counters: 11 → 9.5 px everywhere
9. Hub: glyph art 20 px, ×N up 3 px
10. Missions: first contract row 0.101H
11. Settings: toggles and value boxes
12. Party widget; Kit viewmodel centre; hub player list
13. Shop X, Play X offset, Codes inset
