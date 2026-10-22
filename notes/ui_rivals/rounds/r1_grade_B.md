# r1 grade B: typography, readability, icons

c = the section's anchor cap height. dp = design px. [#n] = rank by visible impact (1 highest).

## Moved away from RIVALS
- Missions contracts: "×N" now sits 9 dp below the scissors, so each 62 dp reward stack fills the 62 dp row pitch. "×1,000" ends 2–5 dp above row 2's icon and reads as row 2's. RIVALS overlaps "×1" on the key and leaves ~19 dp (tasks.png).
- Shop yellow tags: digits shrank 18 → 15 dp.

## Shop price change: closer
White heavy sans without a black outline is RIVALS' price style (t0083.9–t0087, t0068). Still off: our edge is a hard 1 px stroke ~55 % darker than the fill (#3E7318 on #ADFA52); RIVALS' is ~13 % darker (#99C74A on #9AF91F), so its digits read plain white.

## Shop: 6.5/10 (c = price cap)
- [#2] Edge → UIStroke Transparency 0.75. Yellow behind digits #F7E67C → #F8EC00/#EFD700 gradient, so white keeps contrast.
- [#3] One price size: green 0.39 → 0.34 × tag height (20 → 17 dp), yellow 0.29 → 0.34 (15 → 18 dp) (t0068: 0.33/0.36).
- [#6] Icon-to-digit gap 0.95 (Founder's 1.1) → 0.7 c (RIVALS 0.64–0.77). Yellow-tag scissors: full colour, 1.25 c → flat white, 0.6 c tall, 0.5 c after digits (t0068 key).
- [#12] "VIEW" keeps the cartoon face → Rubik ExtraBold "View". "FOUNDER'S BUNDLE"/"2X SCISSORS" → Title Case.

## Missions: 7/10 (c = card title, 20 dp)
Landed: grey labels (#C1C1C3; RIVALS #C3C2C2), "/ N" at count size, card scissors 1.3 → 1.85 c.
- [#1] Contracts: overlap "×N" 6 dp onto the icon. Stack 62 → 47 dp, 15 dp clear to the next row.
- [#10] Card icons 1.77 → 2.4 c (47 dp). Header icon gap 0.5 → 1.0 title cap.
- [#13] Card "×N": 0.46 c gap → 0.3-cap overlap; 0.85 → 0.94 c.
- [#15] Contract numerator 1.25 → 1.38 row caps.

## Hub: 5.5/10 (c = task label, 17 dp)
- [#4] Reward scissors at half brightness (#6A2E2E; panel #CE4C4C) → opaque, 1.6 → 2.0 c, "×N" overlapping 0.25 c (killcard t0000).
- [#7] Labels #FAFAF8 → #C4C5C9; header 1.0 → 1.12 c (t0000).
- [#9] Counter scissors: thin 1.7 → filled 2.7 digit caps; digits-to-plus 1.6 → 2.4 caps (hub_full).
- [#17] Dock labels #CFCFD1 → #FFFFFF.

## Play: 8/10, unchanged
- [#16] Shield 1.45 → 2.5 c; "0 / 10" 0.59 → 0.68 c; "Ranked" 61 → 53 dp.

## Kit: 6/10, unchanged
- [#8] Slot labels #CFCFD1, 20 dp → #FFFFFF, 15 dp.
- [#14] Inspect/Next unlock/Statistics 1.22 → 1.0 c; row icons 2.2 → 2.7 c.

## Codes: 6.5/10 (c = "Codes", 32 dp)
Redeem landed: Rubik Bold, 0.33 × button height (RIVALS Play 0.30). Disabled, it renders #DAEACF; enabled should be #FFFFFF.
- [#11] Title 32 → 23 dp (= "Daily Missions"); gift 42 → 46 dp. "Redeemed" 0.62 c → title size plus icon (tasks.png "Contracts").

## Settings: 7/10
- [#5] Selected tab "Video": black, bottom cut by the bar → white, 1.5 dp black stroke (Shop "Home"; settings.png "Audio").
- [#18] Row icons 1.15–1.5 → 1.8 c on every row; gap 1.0–1.2 → 0.85 c.
