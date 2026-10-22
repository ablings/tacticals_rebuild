# r5 grade A: layout and proportion

**Method.** Same as r0–r4. dp = design px. Hub and Kit are measured on the 785 px window, menus on the 713 px frame. Text sizes are cap heights from pixels. Rec = `rivals_rec`, kc = `killcard\f`.

**Moved away from RIVALS**
- **Play, Ranked title.** It now matches 1v1 (40 = 40 frame px, ratio 1.0). In r4 it was 0.80. kc t0016 is 41 vs 47, so 0.87. "One size" was meant only for the two mode rows. Ranked went past the target and is now further off.
- **Missions sort dropdown.** "Near Completion" (r4: "Default") runs under the ▼ arrow and is clipped ("Completio▼n"). In rec t0066, "Most Played" ends clear of the arrow.

**Landed**
- Kit discs: the bar top now cuts each disc at 0.49 of its height. Rec t0058 is about 0.5, and the labels overlap the disc's lower tenth there too. Disc 73 dp (ref 75), step 121 dp (ref 121).
- Play mode rows: Training, Duel Pads and 1v1 all measure 40 px.
- Missions rule: cards to rule 0.056H (t0066: 0.057), rule to circles 0.029H (0.031).

**Not landed:** Missions streak art. The drawn scissors measure 25×24 px inside a 57 px circle, which is 0.44 of the disc. r4 was about 0.45. Its position is right (centre 0.44, ×N at 0.72), but the size has not changed visibly.

## Hub: 9.5/10 (unchanged)
1. Play bottom to disc tops: 25 → 39 dp. Raise Play and the party widget 14 dp (rec t0285).
2. Player list top 0.080 → 0.062H (t0285).

## Play: 8.5/10
1. Ranked title 107 → 93 dp (0.87 × 1v1).
2. All titles ×0.93: 1v1 is 0.056H, kc t0016 is 0.052H. This also eases "Duel Pads", which fills 0.87 of its tile width (kc t0016 "Gargoyle Tower": 0.67).
3. X top: level with the grid → 5 dp above it (t0016).
4. Party widget: avatar 110 → 100 dp, "+" centre 0.764 → 0.784H (t0016).

## Kit: 8.5/10
1. Slot glyph 0.43 → 0.53 of the disc (t0058).
2. Selected slot, open since r1: header to label 0.069 → 0.099H, label centre x 0.076 → 0.094W (t0058).
3. Viewmodel centre 0.489 → 0.516H (t0058).
4. Labels: bottom inset from the bar edge 8 → 12 dp (t0058).

## Missions: 8.5/10
1. Dropdown: keep the box at 209 dp (ref 205). Fit the text left of the arrow: a shorter label, or text ×0.85 with an 8 dp gap before the ▼ (t0066).
2. Streak art: scale the image ×1.5 so the drawn bounding box is 0.65 of the disc, about 37 frame px / 56 dp. Measure the drawn pixels, not the ImageLabel (t0066).
3. First contract row 0.093 → 0.101H below the panel top (t0066).

## Shop: 9/10 (unchanged)
1. Left price buttons 124 → 100 dp (t0068).
2. 2X banner 0.172–0.575W × 0.250H → 0.166–0.555W × 0.297H; right tile step 0.078 → 0.084W (t0070).
3. X 77 → 87 dp (t0068).

## Codes: 9/10 (unchanged)
1. Inset 0.015 → 0.023W per side (t0066).

## Settings: 9.5/10 (unchanged)
1. Toggles 127×64 → 104×51 dp; value boxes 120×65 → 104×54 dp (t0136).

## Ranked by visible impact
1. Play: Ranked 107 → 93 dp (regression)
2. Missions: dropdown text clipped under the arrow (regression)
3. Missions: streak art ×1.5 so the drawn art is 0.65 of the disc
4. Play: all titles ×0.93 (frees "Duel Pads")
5. Kit: selected slot spacing
6. Shop: left price buttons
7. Shop: 2X banner, right tile step
8. Hub: Play/dock gap
9. Kit: slot glyph 0.53
10. Settings: toggles, value boxes
11. Party widget (Play, hub)
12. Kit: viewmodel centre
13. Hub: player list
14. Shop X; Play X offset; Codes inset; first contract row; Kit label inset
