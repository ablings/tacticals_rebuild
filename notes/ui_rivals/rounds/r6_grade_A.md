# r6 grade A: layout and proportion

**Method.** Same as r0–r5. dp = design px (menus: 713 px frame, ×1.515; hub/kit: 785 px window). Rec = `rivals_rec`, kc = `killcard\f`. Hub, Kit, Shop, Codes, Settings: pixel-diffed against r5. No layout change, only background and art noise.

**Moved away from RIVALS**
- **Reward ×N (Missions cards, contracts).** It now sits to the right of the icon: the text centre is 21 px right of the icon centre, about one icon width. In rec t0066 and kuroko `rv_tasks_live`, ×1 is centred under the key (within 1 px) and overlaps the icon's bottom fifth. The hub tracker has the same offset, against t0285.
- **Missions dropdown box.** The text now fits, but the box grew 209 → 250 dp (ref 205) and pokes 3 px past the panel's right edge. That pushes "sorted by" left. The r5 note said to keep the box at 209.

**Landed**
- Play Ranked: cap 35 px vs mode rows 40 px, ratio 0.875. kc t0016 is 0.87.
- Dropdown text: "Near Completion" ends well clear of the ▼.
- Streak art: drawn scissors 29×30 px in a 58 px circle, 0.51 of the disc (r5 0.40).

**Not landed (or invisible):** Mode-row titles still measure 40 px cap (0.056H), the same as r5. If they were set to 100, they were already rendering at that size. "Duel Pads" still fills 0.86 of its tile (ref 0.67).

## Hub: 9.5/10
1. Tracker ×N: centre it under the icon and overlap the icon's bottom 20% (t0285).
2. Play bottom to disc tops: 25 → 39 dp (t0285).
3. Player list top: 0.080 → 0.062H.

## Play: 9/10 (up from 8.5)
1. Mode-row titles 0.056H → 0.052H. Measure the cap: 40 → 37 frame px, so set the size to about 93 if 100 gives 40 px (kc t0016). Keep Ranked at 0.87 of the new value, about 81.
2. X top: 5 dp above the grid (t0016).
3. Party widget: avatar 110 → 100 dp, "+" centre 0.764 → 0.784H.

## Kit: 8.5/10
1. Slot glyph 0.43 → 0.53 of the disc (t0058).
2. Selected slot: header to label 0.069 → 0.099H; label x 0.076 → 0.094W.
3. Viewmodel centre 0.489 → 0.516H.

## Missions: 8.5/10
1. Reward ×N: lower-right → centred on the icon x, overlapping the icon's bottom 20% (t0066). Applies to cards, contracts and streak.
2. Dropdown: box 250 → 205 dp, inside the panel with the same right inset as the Play button above. Text 23 → 20 to fit (kuroko: the text is 0.70 of the box width).
3. Streak art: the drawn art is 0.51 of the disc; scale it ×1.27 to 0.65 (37 px). The 0.78 box holds transparent padding.
4. First contract row: 0.093 → 0.101H below the panel top.

## Shop: 9/10
1. Left price buttons 124 → 100 dp (t0068).
2. 2X banner: 0.166–0.555W × 0.297H; right tile step 0.084W (t0070).
3. X 77 → 87 dp.

## Codes: 9/10
1. Inset 0.015 → 0.023W per side.

## Settings: 9.5/10
1. Toggles 127×64 → 104×51 dp; value boxes 120×65 → 104×54 dp (t0136).

## Ranked by visible impact
1. Missions/Hub: centre ×N under the icon (regression)
2. Missions: dropdown box back to 205 dp, inside the panel (regression)
3. Play: mode titles 40 → 37 px cap (frees "Duel Pads")
4. Missions: streak art 0.51 → 0.65
5. Kit: selected-slot spacing
6. Shop: left price buttons
7. Shop: 2X banner and tile step
8. Hub: Play/dock gap
9. Kit: slot glyph 0.53
10. Settings: toggles and value boxes
11. Party widget
12. Kit viewmodel centre; hub player list
13. Shop X, Play X offset, Codes inset, first contract row
