# r1 grade C: completeness and finish

Design px = screen px ÷ 0.66. Placeholder models not graded.

**First:** no r1 change moved us away from RIVALS. One didn't land: the Play tiles are still square (pixel 170,238 is tile colour). ClipsDescendants ignores UICorner, so the 8 px corner must sit on each tile ImageLabel itself.

## hub: 8/10
The white header glyph matches live RIVALS (rec t0135).
1. Panel images draw ~40 % dim (scissors red 121 vs 205 in Missions; clipboard white 165 vs 246) → ImageTransparency 0; clipboard 21×30 → 32×40, full colour (hub_full calendar).

## play: 8/10
1. Corners: see above (t0016 ~7).
2. Training / Duel Pads washed (saturation 0.34/0.39 vs 0.46–0.52 top row) → same grade (play.png 4v4/5v5).

## kit: 7/10
1. The 0.35 plate helps, but the lit floor shows: a seam at Suppressed, a green stripe at Revolver → 0.15, one even plate to the bottom (t0055, kit.jpg).
2. The cream bench now forms a bezel around the slot strip (630–1291 × 1079–1189) → reframe or hide it.
3. XP bar "0 … 250" still there → centred level only (kit.jpg).
4. Reward at Level 5 is the only boxed icon → bare 40 px icon with ×1 (weapons.png).

## missions: 8/10
None of r0's fixes landed.
1. Contract rewards: "×1,000" sits under its scissors and touches the next row's icon → ×N on the icon's lower right, icon centred on its 62 px row (tasks.png).
2. Card gaps 3 → 6.
3. Card glyph ~33 → 45; reward scissors ~30 → 40, ×N overlapping (tasks.png).
4. Headshot glyph still on a white plate → bare.

## shop: 7/10
Centred tabs and tinted price outlines match kuroko shop.jpg better. r0's fixes didn't land.
1. Top-row tiles lack the weapon-type tag; the revolver overruns its tile → tags on all six; fit ≤90 % width.
2. "More →" has no icon → gun (shop.jpg).
3. VIEW covers half the medal → art ~120 left.

## codes: 6/10
The empty-state card landed (61 px, text only).
1. "Codes" cap height 32 vs Missions' 23 (RIVALS ~19) → match Missions; white gift → colour, ~40 px.
2. Dark input (51,46,53); the family's fields are white (sort dropdown, Settings values) → white, dark text.
3. Disabled Redeem: olive with pale-green text → Play lime at 50 %, white text.
4. Empty card: add a 36 px icon (Tasks cards have icons).

## settings: 8/10
1. Description pane ends 32 px above the list → align bottoms; add the grey version label bottom-right, ~15 px (rec t0138).
2. Correction to r0: RIVALS' Game controller is dark too (t0138); only Audio and Hotkeys need a ~20 % lift.
Can't judge the end-of-tab Reset row.

## Ranked by visible impact
1. Kit: plate seam
2. Kit: cream bezel
3. Play: corners
4. Play: washed tiles
5. Hub: dim icons
6. Codes: title, gift
7. Shop: tags, overflow
8. Missions: reward collision
9. Missions: gaps, icons, plate
10. Codes: input, button, card icon
11. Settings: pane, version label
12. Shop: More icon, offer art
13. Kit: XP labels, reward box; Settings: icons
