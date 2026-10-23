# m3 grade B (LOOK)

**Regressions:** none. **Landed since m2:** the score plates are hidden behind the ribbon (death2), and the vote plates are now narrow HUD plates showing "0". **Still open from m2:** the Random glyph, the vote gutters, the kill-feed size, the mission icons, the "@user" line, the results banner and buttons, the tip bubble and the italic Ranked text. Sizes are on a 1920x1080 canvas (ours x1.515, RIVALS x1.2).

**ribbon (death2) 8/10** (t0122). Width (37%) and text are right.
- Bar 50 → 58px tall, with square-cut slanted ends instead of the rounded rectangle.

**playmenu 8/10** (t0016)
- "Season 1" and "Unranked" are italic → upright, medium weight. Close X: thin glyph → heavy glyph with a dark outline.

**searching 8/10** (t0018)
- Icon: 33px hexagram → 54px crossed-guns glyph. "Searching for players." 17 → 22px.

**found 7/10** (t0020)
- "Match found" 30 → 36px cap height. "1v1" 27 → 31px. Dots 55 → 60px.
- Tip bubble still missing: a white rounded pill at the bottom left with 26px dark text.

**vote 7/10** (t0028)
- Random: ⇄ → crossed shuffle glyph, about 108px.
- Tiles touch (about 5px) → 12px gutters. Tile labels 21 → 26px cap height.
- Label band: pale light stripes → dark diagonal hazard stripes under the name. Timer plate: opaque black with 3px corners → dark grey (#2b2b2b) with 6px corners.

**loadout 6/10** (t0036)
- The whole block sits too high: header at 13% → 22% of the screen height, and the slots at 17% → 27%.
- Selected slot: 94px with a 4.5px cream stroke → 100px with an 8px white stroke. Slot gaps 8 → 12px. Header 20 → 24px cap height.
- Random card: bright ⇄ → a dimmed shuffle glyph.

**live / countdown 6/10** (t0046)
- Score-strip gaps 11 → 32px (plate to timer) and to 66px (timer to plate). The timer plate should be shorter than the score plates (74 vs 84px).
- Missions: reward icons are faded 23px → opaque 36px. Bars: faint grey 3px → 6px bright fill on a dark track. Title 15 → 19px cap height, with a dark backing plate behind the block (t0046, 8-300px).
- Hotbar: opaque grey slot squares → no plates, with oversized icons overlapping (t0046). Health bar: add a 4px dark outer frame.

**kill 7/10** (t0056)
- Kill feed: 259x33 with about 14px text → 366x36 with 22px text and a 2px light outline.
- Round card "WON" cap height 30 → 37px. Fill: flat → vertical gloss (bright top, dark bottom) plus a drop shadow.

**death 7/10** (t0210)
- Add the "@user" line (18px, faded) under the name. Name 30 → 34px cap height.
- The same kill-feed and round-card gloss fixes as kill.

**switch weapons 8/10** (t0122)
- Text: semibold, about 18px → heavy, 24px. Pill 300x50 → 283x54.

**results 7/10** (t0140)
- Banner 361 → 307px wide, name 27 → 33px cap height. Level badge 27 → 41px. Name 23 → 28px.
- Rematch: tan fill → the same white-stroked dark shape, dimmed. Button gap 5 → 12px. Buttons 258 → 250px wide.
- Buttons: flat → a soft vertical gloss inside the stroke.

## Top 8 by visible impact
1. Loadout: move the block down to 22% / 27% and use 100px slots with an 8px white stroke (t0036).
2. Live HUD: gaps of 32px and 66px in the score strip, and a shorter timer plate (t0046).
3. Missions: opaque 36px icons, 6px bright bars, a backing plate and a 19px title (t0046).
4. Kill feed 366x36 with 22px text and an outline (t0056, t0210).
5. Vote: shuffle glyph, 12px gutters, dark hazard stripes, 26px labels (t0028).
6. Round card: gloss and drop shadow, 37px "WON"/"LOST" (t0056, t0210).
7. Results: 307px banner, stroked and dimmed Rematch, 12px gaps, 41px badge (t0140).
8. Hotbar: drop the slot plates, oversized icons (t0046), plus the found-screen tip bubble (t0020).
