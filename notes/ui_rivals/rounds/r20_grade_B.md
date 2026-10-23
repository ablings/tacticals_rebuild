# r20 grade B: LOOK (type weight/size/casing, finish, icons, hierarchy)

Captures are 1268x713. All sizes are **1920x1080 design px** (capture px × 1.514). g = glyph height measured by bright-pixel rows. I pixel-diffed r19 against r20 at a >40 threshold. Settled, so not graded: gloss, the palette, the Contracts trophy and the grey hub widget labels. [#n] = impact rank.

## Moved away from RIVALS
- None. Only two UI changes: Kit "Career" and the Codes Redeem label. The other diffs come from the backdrop or the rotating Kit and Shop weapon models.

## Did the r19 fixes land?
- **Kit "Career" in Bold: LANDED.** The word is now Bold and 6 px wider (capture 55 → 59 px). Height is unchanged at g ~20 (13 capture rows, y 288–300), which is within 1 px of the ~21 target. It now matches the weight of "Pistol" and the menu labels, as in kuroko169/kit.jpg.
- **Redeem a solid #9A9A9A: LANDED.** The glyph-core histogram peaks at exactly 154 (#9A9A9A), with only anti-alias spread from 150 to 159, over the #4A4A4A fill (74). In r19 the core was ~186. It now reads clearly as disabled.

## Hub: 8.5/10
- [#4] "Play" label g 21 → 26 (killcard t0004). Unchanged.

## Play: 8.5/10
- [#5] Ranked shield: 45 px red → ~55 px white flame-shield (rivals_normal/play.png). Unchanged.

## Kit: 9/10 (up from 8.5)
- [#7] Locked-row lock glyph 8 → ~11 px (kuroko169/kit.jpg). Minor.

## Missions: 10/10
- [#8] "Near Completion" dropdown text g 12 → 15 (tasks.png). Minor, unchanged.

## Shop: 9/10
- [#1] Prices on the left grid's yellow pills ("7,500"/"3,000") are still g ~11, against g 15 on the right grid (t0070). This is not landed for a second round; the crops match r19 apart from the weapon models. Let the number fill ~70% of the ~97x52 pill.
- [#3] "2x Scissors" description still wraps into the medal art. Cap its width at ~335 px so the text ends before x ~700.

## Codes: 9.5/10 (up from 9)
- [#6] Subtitle g 17 → 14 (~0.6 of the "Codes" title). Unchanged.

## Settings: 9.5/10
- [#2] Description body right inset 14 → 24 px, to match the left. Unchanged.
- [#9] "Version 0" → "Version N · uptime" (rec t0139).

## Ranked
1. Shop left-grid prices g 11 → 15 (third round open)
2. Settings description right inset
3. Shop "2x Scissors" description width
4. Hub "Play" label g 26
5. Play shield
6. Codes subtitle
7. Kit lock glyph size
8. Missions dropdown text
9. Settings version uptime

Remaining look gap worth another round: yes
