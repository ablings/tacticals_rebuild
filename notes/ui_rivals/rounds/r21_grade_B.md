# r21 grade B: LOOK (type weight/size/casing, finish, icons, hierarchy)

Captures are 1268x713. All sizes are **1920x1080 design px** (capture px × 1.514). g = digit glyph height in bright-pixel rows. I pixel-diffed r20 against r21 at a >40 threshold. Settled, so not graded: gloss, the palette, the Contracts trophy and the grey hub widget labels. [#n] = impact rank.

## Moved away from RIVALS
- None. The UI changed in two places: the Shop left-grid tags and the Codes panel position and inset. The other diffs are the backdrop and the rotating Kit and Shop weapon models.

## Did the r20 fix land?
- **Shop left-grid prices on 112-wide tags: LANDED.** The left tags went from 100 to 112 wide (66 → 74 cap), the same as the right grid. Their digits went from g ~11 (7 cap rows) to g ~17 (11 cap rows), and the strings are 62 wide (41 cap). The right grid reads 17 / 62, so "7,500" now reads the same size as "3,000" on the right, as in t0070. The tags are still centred under their tiles (tile centre 268.5, tag centre 268 cap). One leftover: the left tags are 53 tall and the right ones 50–51. You only see it side by side.
- Codes (grader A's layout fix) also landed. The look is unchanged, and the content inset now matches on the left and right (42 / 42). That is cleaner than r20 (29 / 29).

## Hub: 8.5/10
- [#3] "Play" label g 21 → 26 (killcard t0004). Unchanged.

## Play: 8.5/10
- [#4] Ranked shield: 45 px red → ~55 px white flame-shield (rivals_normal/play.png). Unchanged.

## Kit: 9/10
- [#6] Locked-row lock glyph 8 → ~11 px (kuroko169/kit.jpg). Minor.

## Missions: 10/10
- [#7] "Near Completion" dropdown text g 12 → 15 (tasks.png). Minor, unchanged.

## Shop: 9.5/10 (up from 9)
- [#2] The "2x Scissors" description still runs up to the medal ribbon: "match" ends at x ~710 and the ribbon starts at ~724. Cap the width at ~335 so the text ends by x ~690 and wraps after "from every" (rivals_rec t0070: description sits clear of the art).
- [#8] Left-tag height 53 → 51, to match the right grid. Minor.

## Codes: 9.5/10
- [#5] Subtitle g 17 → 14 (~0.6 of the "Codes" title). Unchanged.

## Settings: 9.5/10
- [#1] Description body right inset 14 → 24 px, to match the left (t0136). Unchanged.
- [#9] "Version 0" → "Version N · uptime" (rec t0139).

## Ranked
1. Settings description right inset
2. Shop "2x Scissors" description width
3. Hub "Play" label g 26
4. Play shield
5. Codes subtitle
6. Kit lock glyph size
7. Missions dropdown text
8. Shop left-tag height 53 → 51
9. Settings version uptime

All of these are small polish items. The one fix that changed how the Shop reads at a glance has landed.

Remaining look gap worth another round: yes
