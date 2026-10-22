# r7 grade A: layout and proportion

**Method.** Same as r0–r6. dp = design px (menus: 713 px frame, ×1.515). Rec = `rivals_rec`, kc = `killcard\f`. Kit, Codes, Shop, Settings: the diffs against r6 are only in the background or viewmodel, so their layout is unchanged.

**Moved away from RIVALS:** nothing.

**Landed**
- Reward ×N is centred under the icon everywhere, within 0.5 px (cards 459.5/459.5, rows, hub 238/237.5). This matches t0066 and t0285.
- Sort box: 135 px = 205 dp (ref t0066: 137 px). It sits inside the panel with a 13 px right inset (ref 11). "Near Completion" fills about 0.72 of the box (kuroko 0.70).
- Play titles: cap 40 → 37 px (0.052H). Ranked cap 32 px, 0.865 of the mode titles (kc t0016: 0.87). "Duel Pads" fills 0.86 → 0.80 of its tile. The rest of the gap to 0.67 comes from the string's length. Accept it rather than shrink the type further.
- Streak art: 30 → 36 px in a 58 px disc, 0.62 (target 0.65). Close enough.

**Not landed: the ×N overlap.** The label is centred, but its top sits 3 px below the bottom of the drawn scissors, so it never overlaps the art. Measured in the cards (art 340–367, text 371–381), the rows and the hub. The 15% overlap probably landed on the icon box, which has transparent padding below the art. In t0066 and t0285 the ×1 covers the key's bottom ~20%.

## Hub: 9.5/10
1. Tracker ×N: move it up 7 px (≈10 dp) so the text top sits about 5 px inside the art (t0285). ×300 then clears the panel bottom too (now 3 px).
2. Play bottom to disc tops: 25 → 39 dp (t0285). Carried over.
3. Player list top: 0.080 → 0.062H. Carried over.

## Play: 9.5/10 (up from 9)
1. X top: 5 dp above the grid (t0016).
2. Party widget: avatar 110 → 100 dp, "+" centre 0.764 → 0.784H.

## Kit: 8.5/10
1. Slot glyph: 0.43 → 0.53 of the disc (t0058).
2. Selected slot: header to label 0.069 → 0.099H, label x 0.076 → 0.094W.
3. Viewmodel centre: 0.489 → 0.516H.

## Missions: 9/10 (up from 8.5)
1. Contract rows: the ×N stack runs into the next row. Row 1's ×100 ends at y 635, exactly where row 2's icon starts. Raise ×N by 7 px (≈10 dp) into the art's bottom fifth, as the ref rows do (t0066, row pitch 41 px in both). This fixes the collision and the overlap together.
2. Cards: apply the same 7 px lift (t0066: ×1 overlaps the key).
3. First contract row: 0.093 → 0.101H below the panel top (t0066: 72 px from the panel top; ours is 66 px).

## Shop: 9/10
1. Left price buttons: 124 → 100 dp (t0068).
2. 2X banner: 0.166–0.555W × 0.297H; right tile step 0.084W (t0070).
3. X: 77 → 87 dp.

## Codes: 9/10
1. Inset: 0.015 → 0.023W per side.

## Settings: 9.5/10
1. Toggles 127×64 → 104×51 dp; value boxes 120×65 → 104×54 dp (t0136).

## Ranked by visible impact
1. Missions contracts: lift ×N 7 px (it touches the next row's icon)
2. Missions cards and hub: lift ×N 7 px into the art's bottom fifth
3. Kit: selected-slot spacing
4. Shop: left price buttons
5. Shop: 2X banner and tile step
6. Hub: Play/dock gap
7. Kit: slot glyph 0.53
8. Missions: first contract row 0.101H
9. Settings: toggles and value boxes
10. Party widget
11. Kit viewmodel centre; hub player list
12. Shop X, Play X offset, Codes inset
