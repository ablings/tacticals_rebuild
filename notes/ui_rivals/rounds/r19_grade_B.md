# r19 grade B: LOOK (type weight/size/casing, finish, icons, hierarchy)

Captures are 1268x713. All sizes here are **1920x1080 design px** (capture px × 1.514). g = glyph height measured by bright-pixel rows. I pixel-diffed r18 against r19 at a >40 threshold. Settled, so not graded: gloss, the palette, the Contracts trophy and the grey hub widget labels. [#n] = impact rank.

## Moved away from RIVALS
- None. The UI changed in three places: the Missions day-circle labels, the Codes Redeem label and the Kit list (now 6 capture px lower). The other diffs are backdrop only.

## Did the r18 fixes land?
- **Day-circle ×N a size up: LANDED.** g 12 → 18 (capture 8 → 12 rows, y 448–459). "×400" is now 62 px wide (was 45). White with a dark edge, over the scissors' foot, the same way tasks.png puts "×1" over the icon foot. It reads clearly now.
- **Wider Shop top-row prices: NOT LANDED.** The crops are pixel-identical to r18. "7,500" and "3,000" are still g ~11, against g 15 for the right grid's "3,000"/"2,000".
- **Redeem label at ~60% white: PARTLY.** The glyph core went from (222) to (186), which is ~73% white. That still reads as active over the #4A4A4A fill. The value looks like TextTransparency blending into the fill. Use an opaque TextColor3 #9A9A9A (154) instead.

## Hub: 8.5/10
- [#6] "Play" label g 21 → 26 (killcard t0004). Unchanged.

## Play: 8.5/10
- [#7] Ranked shield: 45 px red → ~55 px white flame-shield (rivals_normal/play.png). Unchanged.

## Kit: 8.5/10
- [#2] "Career" is still Regular and lighter than "Pistol" and the menu labels. Change it to Bold at the "Weapons" size, g ~21 (kuroko169/kit.jpg).
- [#9] Locked-row lock glyph 8 → ~11 px (kuroko169/kit.jpg). Minor.

## Missions: 10/10 (up from 9.5)
- [#10] "Near Completion" dropdown text g 12 → 15 (tasks.png, where it is as heavy as "sorted by"). Unchanged and minor.

## Shop: 9/10
- [#1] Top-row price text g 11 → 15, to match the right grid (t0070). The pills (~97x52) have room, so keep the scissors glyph and let the number fill ~70% of the pill width.
- [#5] "2x Scissors" description wraps at x ~712 into the medal art. Cap the text width at ~0.45 of the slide (~335 px) so it ends before the medal (~700).

## Codes: 9/10
- [#3] Redeem label: opaque #9A9A9A, TextTransparency 0. The current effective value is ~#BABABA.
- [#8] Subtitle g 17 → 14 (~0.6 of the "Codes" title).

## Settings: 9.5/10
- [#4] Description body right inset 14 → 24 px, to match the left. Unchanged.
- [#11] "Version 0" → "Version N · uptime" (rec t0139).

## Ranked
1. Shop top-row prices g 11 → 15 (the r18 fix did not land)
2. Kit "Career" → Bold
3. Codes Redeem → opaque #9A9A9A
4. Settings description right inset
5. Shop "2x Scissors" description width
6. Hub "Play" label g 26
7. Play shield
8. Codes subtitle
9. Kit lock glyph size
10. Missions dropdown text
11. Settings version uptime

Remaining look gap worth another round: yes
