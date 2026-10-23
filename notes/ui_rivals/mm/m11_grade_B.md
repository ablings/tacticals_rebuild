# m11 grade B (LOOK)

**Moved away from RIVALS:** nothing.

**m10 fixes that landed:**
- Rematch is now a dark fill and Play Again leads.
- The killer card shows "@matchbot_2" under the name.
- Match found has the white tip bubble (1228x53 on the 1920 canvas, against RIVALS' 1178x54) and a heavier ~38px caption.
- The MATCH POINT ribbon now matches t0122: the text overflows the top of the bar, and the width is 0.372 W in both.
- The vote tile has its accent border.

**Partly landed:** the vignette edge. Bottom-centre went from (86,7,10) to (76,6,8), but the bottom ~12 % and the left edge are still near-opaque dark red. RIVALS' edge is translucent, and the scene shows through it (death_vignette.jpg).

**Not landed:**
- killer-card gloss
- hotbar plates
- kill-line weights
- shuffle glyph
- searching icon (still a hexagram)
- italic "Season 1" / "Unranked"

Sizes are on a 1920 canvas (ours x1.514, RIVALS x1.2).

**death 8/10** (t0210, death_vignette.jpg)
- Vignette edge alpha ~0.8 → ~0.45 so the scene reads through the bottom and left bands.
- Killer card: flat green → vertical gloss, lighter in the top 40 % (t0210's card shades from top-left).
- "@handle": lowercase grey → uppercase, ~17px, ~55 % white (t0210 "@XMANFREE10").

**death2 8/10**: needs the same card fixes as death.

**results 8/10** (t0140)
- Rematch: solid dark with bright white text → ~40 % opacity text and a faint 2px stroke, so it reads as secondary/ghosted like t0140.
- Play Again / Leave: flat dark → subtle top-light gradient (t0140's buttons are glossy grey).

**kill 8/10** (t0054)
- Victim "Bot": same weight as "Eliminated" → heavy weight, brighter, 2px dark stroke.
- "Eliminated": semibold → regular.

**live / countdown 8/10** (t0054)
- Hotbar: opaque plates → alpha ~0.3, icons overflowing the plate top, dark plate on the selected slot only.
- "Pistol": cap ~42 → ~34px ("Assault Rifle" in t0054).

**matchpoint 9/10** (t0122)
- MATCH POINT letters: plain → 3px dark drop shadow/stroke under the glyphs.

**found 9/10** (t0022)
- Tip bubble: plain bar → a small tail at its left end (t0022's speech bubble). Tip text bold → semibold.

**vote 9/10** (t0032)
- Picked tile's name band: grey stripes → accent-tinted stripes.

**loadout 8/10** (t0036)
- Random glyph: ⇄ → crossed shuffle.
- Selected ring: cream 6px → white 7px.
- "Map: Warehouse" cap ~20 → 23px.

**searching 8/10** (t0018): hexagram → crossed-guns glyph.

**playmenu 8/10**: "Season 1" / "Unranked": italic → upright.

Timing (unscored): MATCH POINT caught the ROUND WON card mid-fade (dimmed), which is fine. No lingering kill line.

## Top 8 by visible impact
1. Death vignette: translucent edges (alpha ~0.45), so the scene reads through (death_vignette.jpg).
2. Hotbar: faint plates, overflowing icons, 34px weapon name (t0054).
3. Killer card: vertical gloss and an uppercase @handle (t0210).
4. Kill line: heavy, stroked victim name; regular "Eliminated" (t0054).
5. Results: ghosted Rematch text with a faint stroke, and glossy Play Again / Leave (t0140).
6. Searching crossed-guns icon and Random shuffle glyph (t0018 / t0036).
7. MATCH POINT glyph shadow (t0122).
8. Found bubble tail; vote accent stripes; upright Season / Unranked text.
