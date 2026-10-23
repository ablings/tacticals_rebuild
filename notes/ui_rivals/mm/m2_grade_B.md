# m2 grade B (LOOK)

**Regressions:** none. Landed since m1: the ribbon redesign, the one-line hourglass timer, Title-case loadout names, the killer card at 76%, the searching pill's progress line removed, and no stroke on the selected hotbar slot. Sizes are on a 1920x1080 canvas (ours x1.515, RIVALS x1.2).

**kill / death2 ribbon 8/10** (t0122). This is now the right idea: heavy white text spilling above a red bar, at 37% of the screen width.
- The score plates show through behind the letters (tan, black and green slivers). Hide the plates while the ribbon is up, as RIVALS does.
- Bar: rounded rectangle → a trapezoid with square-cut, inward-slanted ends and a darker red bottom third. Height 48 → 52px.
- Text cap height 56 → 62px.

**playmenu 8/10** (t0016)
- Ranked tile: "Season 1" and "Unranked" are italic → upright, medium weight (RIVALS "Unlocked at Level 100"). Close X: thin glyph → heavy glyph with a dark outline.

**searching 8/10** (t0018)
- Left icon: 33px hexagram → 54px crossed-guns glyph.

**found 7/10** (t0020)
- "Match found": 30 → 40px cap height, with a soft dark drop shadow. "1v1": 28 → 34px.
- The tip bubble is still missing: a white rounded pill at the bottom left with 26px dark text.

**vote 6/10** (t0028). None of m1's fixes landed.
- Random icon: ⇄ arrows → crossed shuffle glyph, 108px.
- Score plates: empty and 291px wide → the 138px HUD plates with the "0" digit in a heavy face.
- Tiles touch → 12px gutters. Timer plate: opaque black with 3px corners → dark grey with 6px corners.

**loadout 7/10** (t0036)
- Random card: bright ⇄ → a dimmed shuffle glyph.
- Selected slot stroke: 4.5px cream → 8px white. Slots 91 → 100px.
- Header: 28 → 31px.

**live / countdown 6/10** (t0046)
- Score-plate gaps: 8 → 32px (still open).
- Key-hint strip: text about 21 → 13px, pill 42 → 34px tall (still open). Weapon name "Pistol": 42 → 34px tall.
- Missions: reward icons 23px faded → 36px opaque. Bars 4.5 → 6px. Title 23 → 26px.

**kill 7/10** (t0122, t0210)
- Kill-feed text: about 15 → 22px bold. The plate size is right.
- Round card "WON": 33 → 38px cap height. Add a vertical gloss (bright top, dark bottom) and a drop shadow, as in t0210 "LOST".

**death 7/10** (t0210)
- Add the "@user" line (18px, faded) under the name.
- Card: hard right edge → a gradient that fades out behind the gun.

**results / victory 8/10** (t0140)
- Banner: 360 → 307px wide. Name: 33 → 38px.
- Level badge: 27 → 43px.
- Buttons: flat → vertical gloss. Rematch: tan fill → the same stroked shape, dimmed. Stack gap 6 → 12px.

## Top 8 by visible impact
1. Ribbon: hide the score plates behind it, and cut the bar as a trapezoid (t0122).
2. Vote: shuffle glyph, narrow HUD-style plates with "0", 12px gutters (t0028).
3. Live HUD: 32px gaps between the score plates (t0046).
4. Key-hint strip at 13px in a 34px pill. "Pistol" label 34px (t0046).
5. Kill-feed text 22px bold (t0122).
6. Missions: opaque 36px reward icons, 6px bars (t0046).
7. Killer card: @user line, fade-out edge (t0210).
8. Results: banner 307px, 43px badge, glossed buttons, stroked Rematch (t0140).
