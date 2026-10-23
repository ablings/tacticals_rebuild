# m14 grade B (LOOK)

**Moved away from RIVALS:** nothing. m13 → m14 pixel diffs on the HUD screens are tiny. Vote, victory and results are essentially unchanged.

**m13 fixes (sampled at 1268x713):** none of the LOOK fixes landed. The vignette edges are still maroon: left (68,12,13) against t0206 (105,19,22). The hotbar plates are still opaque (22,22,32). "Bot" has no stroke. The hexagram, the ⇄ glyph and the italic Season / Unranked text are all still there. The gloss items are now Settled and are dropped.

Sizes below are on the 1920 canvas.

**death 7.5/10** (t0206)
- Vignette edges (68,12,13) → about (105,19,22): raise the edge alpha. The corners are already close.
- Health bar at 0: dark plate → red-tinted empty track.

**death2 8.5/10** (t0210). The card box matches exactly (x 1143-1817, h 132).
- Handle "@matchbot_2": cap about 12 px at about 50 % → about 16 px at about 70 % white.

**live / countdown 8/10** (t0054, t0122)
- Unselected slot plates: alpha about 0.9 → about 0.3.
- Weapon icons: contained in the plate → overflowing its top by about 15 %.

**kill 8/10** (t0054)
- "Bot": add a 2 px dark stroke and go one weight heavier.
- "Eliminated": bold → regular. It currently matches the name's weight, so the name doesn't pop.

**matchpoint 8.5/10** (t0122). The ribbon size matches (604-1316).
- Ribbon text: cap about 58 px, 519 wide → about 66 px, about 600 wide.
- Letters: flat → 3 px dark drop shadow.

**results 8.5/10** (t0140). The banner, plate and buttons match in size.
- Player name on the plate: cap about 24 px → about 34 px. Level badge about 18 → about 34 px.
- Button stack: 6 px gaps and an 8 px edge margin → 12 px gaps and a 12 px margin.
- VICTORY team name: cap about 27 → about 34 px.

**found 8.5/10** (t0020)
- Tip bubble: fixed width 241-1469 (about 340 px empty on the right) → width fitted to the text + 16 px padding.
- Tip text: bold → medium/semibold. Add a small tail at the left end.

**searching 8/10** (t0018). The pill size matches (539 vs 552 wide). Hexagram → crossed-guns glyph.

**loadout 8.5/10** (t0036). The slots (97 px) and tiles (121 px) match.
- Random glyph ⇄ → crossed shuffle arrows.
- "Map: Warehouse" cap about 21 → about 26 px.

**playmenu 8/10**: "Season 1" / "Unranked" are italic → upright.

**vote 9/10** (t0032): picked tile name band, grey stripes → accent-tinted stripes.

**victory 9/10**: nothing to fix.

Timing (unscored): nothing new seen in the stills.

## Top 8 by visible impact
1. Hotbar: plate alpha about 0.3 and icons overflowing the top (t0054, t0122). This is on screen all match.
2. Vignette edges brighter red, to about (105,19,22) (t0206).
3. Kill line: "Bot" with a 2 px stroke and heavier, "Eliminated" regular (t0054).
4. MATCH POINT / SUDDEN DEATH: text about 66 px cap plus a 3 px drop shadow (t0122).
5. Results player name 34 px and badge 34 px; button gaps 12 px (t0140).
6. Tip bubble fitted to its text, medium weight, with a tail (t0020).
7. Health bar at 0: red-tinted track (t0206).
8. Glyphs and text: crossed guns (t0018), shuffle (t0036), upright Season / Unranked, killer handle 16 px.
