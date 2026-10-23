# r18 grade B: LOOK (type weight/size/casing, finish, icons, hierarchy)

Captures are 1268x713 (design px = capture px × 1.51). c = glyph height in capture px, measured by bright-pixel row count, so it runs a little higher than the r17 cap-height figures. I pixel-diffed r17 against r18 at a >40 threshold. Settled, so not graded: gloss, the palette, the Contracts trophy and the grey hub widget labels. [#n] = impact rank.

## Moved away from RIVALS
- None. Inside the UI, only the Missions reward labels, the Codes Redeem fill and the Kit list/render changed.

## Did the r17 fixes land?
- **Missions ×N a size up: PARTLY.** The card rewards "×100/×200/×300" grew from 11 → 13 rows (y 331–343), and they now read clearly under the scissors, as in tasks.png. The Contracts "×100" grew the same way (11 → 13). The day-circle labels ("×50" … "×400") did **not** change: still 8 rows (y 451–458), and they are hard to read over the scissors icon.
- **Redeem neutral #4A4A4A: LANDED.** The fill is now (74,74,74) = #4A4A4A, flat with no green cast, so it reads as disabled. The label is still bright, (224,224,224) ≈ 88% white. The ~60% white target did not land.
- **"2x Scissors": LANDED.** The carousel slide title reads "2x Scissors", with a lowercase x and title case, c~18. That matches the "Operator Kit" banner style.

## Hub: 8.5/10
- [#7] "Play" label c14 → c17 (killcard t0004). Unchanged.

## Play: 8.5/10
- [#8] Ranked shield: 30 px red → ~36 px white flame-shield (rivals_normal/play.png). Unchanged.

## Kit: 8.5/10
- [#3] "Career" is still Regular and reads lighter than "Pistol" and the menu labels. Change it to Bold at about the "Weapons" size (kuroko169/kit.jpg).
- [#9] The locked-row names (Suppressed, Mini Uzi …) are mid-grey, and the lock glyph is ~5 px. That is fine, but the lock could go to ~7 px so it reads (kuroko169/kit.jpg). This is minor.

## Missions: 9.5/10 (up from 9)
- [#2] Day-circle ×N labels: 8 → ~11 rows, white with a dark stroke, sitting below the scissors' foot instead of over the blades (tasks.png).
- [#10] "Near Completion" dropdown text c8 → c10. Unchanged.

## Shop: 9/10
- [#1] Top-row tile prices ("7,500", "3,000") are still about c9 against c11 for the right grid's "3,000"/"2,500" (t0070). This is now the most visible type mismatch on the page.
- [#6] The "2x Scissors" description wraps at ~x 470 into the medal art. Cap the text width at ~0.45 of the slide so it sits clear of the medal.

## Codes: 9/10 (up from 8.5)
- [#4] Redeem label (224,224,224) → ~60% white (~#9A9A9A), so the button reads disabled until a code is typed (the Settings toggles' off state is the in-family cue).
- [#11] Subtitle c11 → c9 (~0.6 of the title).

## Settings: 9.5/10
- [#5] Description body right inset ~9 px → 16 px, to match the left. Unchanged.
- [#12] "Version 0" → "Version N · uptime" (rec t0139).

## Ranked
1. Shop top-row prices → c11
2. Missions day-circle ×N → ~11 rows, below the icon
3. Kit "Career" → Bold
4. Codes Redeem label → ~60% white
5. Settings description right inset
6. Shop "2x Scissors" description width
7. Hub "Play" label c17
8. Play shield
9. Kit lock glyph size
10. Missions dropdown text
11. Codes subtitle
12. Settings version uptime

Remaining look gap worth another round: yes
