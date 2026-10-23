# r23 grade B: LOOK (type weight/size/casing, finish, icons, hierarchy)

Captures are 1268x713. All sizes are in **1920x1080 design px** (capture px × 1.514; rec px × 1.5). I pixel-diffed r22 against r23 at a >40 threshold. Outside Settings, every diff is the backdrop camera, the Kit gun render or the Codes character. I also checked the description block against rec t0136 at matched scale. I don't grade the settled items: gloss, the palette, the Contracts trophy and the grey hub widget labels. [#n] = impact rank.

## Moved away from RIVALS
- None.

## Did the r22 fix land?
- **Settings description body Bold 34 → Medium 30: LANDED.** The body is now visibly lighter than the title, as in t0136. It wraps to 2 lines. Line pitch is 33 → 30 (RIVALS 29), x-height is 15 (RIVALS 13.5), and the left edge is 1122, the same as RIVALS. The widest line ends at 1552, well inside the 24 inset.
- **Title right inset (#3b): LANDED.** "Optimized Lighting" now ends at 1578, which is 36 inside the panel edge (it was 12). The glyph height went 41 → 38 (RIVALS 36).

## Hub: 8.5/10
- [#4] "Play" label g 21 → 26 (killcard t0004). Carried over.

## Play: 8.5/10
- [#5] Ranked shield: 45 px red → ~55 px white flame-shield (rivals_normal/play.png). Carried over.

## Kit: 9/10
- [#8] Locked-row lock glyph 8 → ~11 (kuroko169/kit.jpg). Minor.

## Missions: 10/10
- [#9] "Near Completion" dropdown text g 12 → 15 (tasks.png). Minor.

## Shop: 9.5/10
- [#2] "2x Scissors" description: width unchanged from r22. Cap it at ~335 so it wraps after "from every" (rivals_rec t0070). Carried over.
- [#10] Left-tag height 53 → 51. Minor.

## Codes: 9.5/10
- [#7] Subtitle g 17 → 14 (~0.6 of the title). Carried over.

## Settings: 9.5/10
Body weight is fixed. With title/body contrast back, three smaller gaps show in the t0136 side-by-side:
- [#1] Title-to-body gap: the step from the title baseline to the first body baseline is 62 → ~45. Lift the body ~15 (first baseline y 276 → 261). Ours floats loose under the title, while RIVALS' body tucks right under it.
- [#3] Description title weight: Heavy/Black → Bold. "Finisher Volume" has visibly thinner strokes and tighter letters than our "Optimized Lighting". Ours reads one weight heavier than the toggle labels, so the title shouts.
- [#6] Body text colour: luminance ~192 → ~210 (t0136 body is near-white grey, ~#D2D2D2). Ours looks dim against the panel.
- [#11] "Version 0" → "Version N · uptime" (rec t0139). Carried over.

## Ranked
1. Settings body lifted ~15 (title baseline → body baseline 45)
2. Shop "2x Scissors" description width ~335
3. Settings description title Heavy → Bold
4. Hub "Play" label g 26
5. Play Ranked shield
6. Settings body colour ~210
7. Codes subtitle g 14
8. Kit lock glyph ~11
9. Missions dropdown text g 15
10. Shop left-tag height 51
11. Settings version uptime

Both r22 fixes landed cleanly, and the panel now has a proper title/body hierarchy. What's left is spacing and weight polish. The body gap is the most visible of these.

Remaining look gap worth another round: yes
