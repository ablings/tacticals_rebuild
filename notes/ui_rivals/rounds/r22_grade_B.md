# r22 grade B: LOOK (type weight/size/casing, finish, icons, hierarchy)

Captures are 1268x713. All sizes are in **1920x1080 design px** (capture px × 1.514; rec px × 1.5). I pixel-diffed r21 against r22 at a >40 threshold, then cropped each changed area. I don't grade the settled items: gloss, the palette, the Contracts trophy and the grey hub widget labels. [#n] = impact rank.

## Moved away from RIVALS
- None. The only UI change is in the Settings description. The other diffs come from the backdrop camera, the character in the Codes backdrop and the Kit gun render. The Shop "2x Scissors" crop is identical to r21.

## Did the r21 fix land?
- **Settings description right inset 24: LANDED.** The panel runs from cap 723 to 1066 (1095–1614). The body now wraps to 3 lines, and the widest line ends at cap 999. "game" no longer fits on line 1, so the text box's right edge is now at most ~1050 cap, i.e. ≥24 design inside the panel. In r21, line 1 ran to cap 1055 (an inset of ~17). The left inset is 18 cap (27 design), so the two sides now nearly match, as in t0136.

## Hub: 8.5/10
- [#4] "Play" label g 21 → 26 (killcard t0004). Unchanged.

## Play: 8.5/10
- [#5] Ranked shield: 45 px red → ~55 px white flame-shield (rivals_normal/play.png). Unchanged.

## Kit: 9/10
- [#7] Locked-row lock glyph 8 → ~11 px (kuroko169/kit.jpg). Minor.

## Missions: 10/10
- [#8] "Near Completion" dropdown text g 12 → 15 (tasks.png). Minor.

## Shop: 9.5/10
- [#2] "2x Scissors" description: "match" still ends at x ~710, against the ribbon at ~724. Cap the width at ~335 so the text wraps after "from every" (rivals_rec t0070). Unchanged.
- [#9] Left-tag height 53 → 51, to match the right grid. Minor.

## Codes: 9.5/10
- [#6] Subtitle g 17 → 14 (~0.6 of the "Codes" title). Unchanged.

## Settings: 9.5/10
Now that the inset is fixed, a side-by-side crop against rec t0136 shows three new look gaps:
- [#1] Description body weight: Bold → Medium/SemiBold. RIVALS' body ("Changes the volume of just finishers…") is visibly lighter than its title. Ours is as heavy as the toggle labels, so the panel has no title/body weight contrast.
- [#3] Description body size: line pitch 33 → ~29, and glyph height with descenders 26 → ~24 (t0136: 19 / 16 rec). Smaller type also gives each line more room before the 24 inset.
- [#3b] Description title right inset: "Optimized Lighting" ends at x 1602, 12 from the panel edge (1614). Keep it at least 24 in, e.g. with TextScaled and a max width that ends at 1590. RIVALS' "Finisher Volume" sits ~45 clear. The gap only shows with long titles.
- [#10] "Version 0" → "Version N · uptime" (rec t0139).

## Ranked
1. Settings description body weight Bold → Medium
2. Shop "2x Scissors" description width ~335
3. Settings body size (pitch 33 → 29) and title right inset ≥24
4. Hub "Play" label g 26
5. Play Ranked shield
6. Codes subtitle g 14
7. Kit lock glyph ~11
8. Missions dropdown text g 15
9. Shop left-tag height 51
10. Settings version uptime

The r21 fix landed cleanly. What remains is type-weight and spacing polish. The body weight change is the one you would notice at a glance.

Remaining look gap worth another round: yes
