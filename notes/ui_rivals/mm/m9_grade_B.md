# m9 grade B (LOOK)

**Moved away from RIVALS: the death vignette is now far too strong.** In m9_death the red reaches about 40% in from each side, is fully saturated at the left and bottom-left edges, and tints the centre. In death_vignette.jpg the red is soft (alpha ~0.4), stays in the outer ~20% band, and leaves the centre clear.

**Landed:** the vote label stripes are dark grey now (seen on the chosen tile). The Eliminated line is caught at full opacity.
**Not landed:** chevron (none visible), killer "@user" line and gloss, hotbar plates, shuffle glyph, searching icon, found tip bubble, results banner and Rematch.

Sizes are on a 1920 canvas (ours x1.514, RIVALS x1.2).

**death 6/10** (death_vignette.jpg, t0210)
- Vignette: alpha ~0.85 → ~0.45 at the edge. Clear the centre: no red inside the middle 60% of width and 55% of height.
- Killer card: add the "@user" line (18px cap, ~50% white). "eliminated you with": regular ~21px → bold ~24px.
- Card fill: flat → vertical gloss. The size already matches (674x132 vs 676x134).

**results 6/10** (t0140)
- Bug: the "Eliminated Bot / HEADSHOT · KILL" line is still drawn over the name plate. Clear it when the match ends.
- Banner 360x94 → 307x96. Rematch: tan → dimmed dark with a stroke. Button gap 5 → 12px.

**vote 7/10** (t0032 map chosen)
- The chosen tile sits high (top y 254) → centre it on the screen (top ~403, centre y 540).
- Chosen state: add the 2px accent border, and switch the band from grey to accent stripes. This is the "picked" cue in t0032; keep grey for unpicked tiles.

**kill 8/10** (t0054)
- Victim name: same weight as "Eliminated", no outline → heavy weight with a 2px dark stroke (the accent colour stays ours).

**matchpoint 7/10** (t0122)
- The kill line is still on screen under the ribbon. RIVALS has cleared it by then; hide it when the countdown starts.
- Ribbon: flat → a darker lower band with a slanted bottom edge. Switch Weapons isn't in this frame, so I can't judge it.

**live / countdown 8/10** (t0046 / t0122)
- Hotbar: opaque 112x76 plates → faint plates (alpha ~0.3) with the icons overflowing them, dark plate on the selected slot only. "Pistol" cap 35 → 29px.

**loadout 8/10** (t0036)
- Header cap 18 → 23px. Random: ⇄ → crossed-shuffle glyph. Selected ring: cream 6px → white 7px.

**found 7/10** (t0022)
- Add the white tip bubble at the bottom left (26px dark text). "Match found" cap 30 → 36px at black weight.

**searching 8/10** (t0018): icon hexagram → crossed-guns glyph.

**playmenu 8/10:** "Season 1" / "Unranked": italic → upright.

**death2 8/10:** the killer card is held under SUDDEN DEATH like t0210. Same card fixes as death.

Timing (unscored): the slowed holds make the kill line linger into matchpoint and results. Check that it isn't only a 6x-slowdown artefact before fixing the code.

## Top 8 by visible impact
1. Death vignette: halve the alpha, clear the centre, keep the red in the outer ~20% (death_vignette.jpg).
2. Results: kill line drawn over the name plate. Clear it at match end (t0140).
3. Vote chosen tile: centre it vertically; accent border and stripes when picked (t0032).
4. Hotbar: faint plates, overflowing icons, 29px name (t0046 / t0122).
5. Killer card: "@user" line, bold 24px weapon line, gloss (t0210).
6. Results: 307px banner, dimmed Rematch, 12px gaps (t0140).
7. Shuffle glyph on loadout Random; crossed-guns icon on the searching pill (t0036 / t0018).
8. Found tip bubble and heavier caption; heavy outlined victim name; MATCH POINT ribbon depth (t0022 / t0054 / t0122).
