# r14 grade B: LOOK (type weight/size/casing, finish, icons, hierarchy)

Captures are 1268x713 (design px = capture px × 1.51). c = cap height in capture px. I checked against r13_grade_B and r13 vs r14 side by side. [#n] = impact rank. Text is real Rubik. Gloss, palette and the Contracts trophy are settled, so I don't grade them.

## Moved away from RIVALS
- None.

## Did the r13 fixes land?
- **Settings section headers 61 → 48: NOT landed.** "Performance" spans x 215–481 (266 px) and "Camera" spans 215–370 in both r13 and r14, with the same cap height (~c28). Only their y moved: Camera went from 352 to 331 because the rows above got shorter. Check whether TextScaled or a UITextSizeConstraint overrides the new TextSize, or whether the change went to the right-hand description title instead. That title is also unchanged at 790–1059.
- **Compact Settings controls: landed.** Toggles went from 83x41 to 69x36. Toggle rows went from 58 to 48 tall (step 64 → 54). Steppers went from 40x42 to 37x36, and value boxes from 79x42 to 73x36. The rows now read with the same density as kuroko169/settings.jpg, where the toggle is about 1/3 of the row height smaller than the label block. The arrow glyphs in the steppers kept their size, so they now look heavier. That's fine, because RIVALS' are bold too.
- Carried over and unchanged: Shop banner casing, Codes Redeem fill, Hub widget label grey, Shop tile price sizes, Missions ×N size, Kit "Career" weight.

## Hub: 8.5/10
- [#5] Widget row labels ("Play matches"…) ~#D0D0D0 → #FFFFFF ("Play duels", killcard t0004).
- [#10] Play label c14 → c17 (t0004).

## Play: 8.5/10
- [#11] Ranked shield: 30 px red → ~36 px white flame-shield (rivals_normal/play.png).

## Kit: 8.5/10
- [#8] "Career" Regular c12 → Bold c10 (kuroko169/kit.jpg). It is the only Regular-weight label on the screen.

## Missions: 9/10
- [#7] Reward "×100" c8 → c12, tucked over the scissors' foot (tasks.png).
- [#12] "Near Completion" dropdown text c8 → c10.

## Shop: 8.5/10
- [#2] "FOUNDER'S BUNDLE" → "Founder's Bundle" and "2X SCISSORS" → "2x Scissors". RIVALS uses Title Case ("Season Pass", "Special Offer", rec t0070). Flagged for the third round.
- [#6] Top-row tile prices c8 ("7,500", "3,000") → c11, the same as the right grid (t0070).

## Codes: 8/10
- [#4] Redeem fill: olive-grey ~#5C6258 → neutral #4A4A4A, and the label's dark outline → no outline or a 1 px soft edge. It still reads as a styled active button.
- [#13] Subtitle c11 → c9 (~0.6 of the c14 title, t0070).

## Settings: 8.5/10 (unchanged: controls got better, headers did not move)
- [#1] Section headers "Performance" / "Camera": still c28, 1.9× the c15 rows → c22 (1.4×, kuroko169/settings.jpg). Header bar height 57 → ~46 px to match.
- [#9] Description body's first line ends 9 px from the panel's right edge; the left inset is 16 px → 16 px.
- [#14] "Version 0" → "Version N · uptime" (rec t0139).

## Ranked
1. Settings section headers c28 → c22 (fix the override first)
2. Shop banner titles → Title Case
3. (settled: Contracts glyph)
4. Codes Redeem fill neutral, no outline
5. Hub widget labels → white
6. Shop top-row prices → c11
7. Missions ×N → c12
8. Kit "Career" → Bold c10
9. Settings description right inset
10. Hub Play label c17
11. Play shield
12. Missions dropdown text
13. Codes subtitle
14. Settings version uptime

Remaining look gap worth another round: yes
