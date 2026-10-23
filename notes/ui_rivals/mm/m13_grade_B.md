# m13 grade B (LOOK)

**Moved away from RIVALS:** nothing new.

**m12 fixes (pixels sampled at 1268x713):**
- **Hotbar plates faint: not landed.** The unselected plates went from (7,10,17) to (11,16,22). They are still opaque near-black tiles. t0054's plates are see-through.
- **Bright red vignette: partly landed.** The corners are brighter (top-left (101,16,23) → (158,67,74)). The edges are still maroon: left (65,12,18), bottom (67,11,12). t0206 has a saturated red wash all the way round.
- **Brighter victim name: landed.** "Bot" went from (160,174,149) to (210,231,198). There's no visible dark stroke yet.
- **Killer card gloss: not landed.** The card pixels match m12 at every row. Cause: `calmOne` (DuelHUD line 2245) sets every Frame named `Gloss` to `Visible = false`. That includes the killer card gloss (line 1543) and the Play Again / Leave gloss (line 927). Rename them or exempt them.
- **Rematch outline: landed.** The edge reads (141,147,159) against the (22,25,32) fill, so the 3 px stroke survives `calmOne`.
- Also landed: the health bar shows "0" at death, and the arc is thicker and carries a triangle head.

All sizes below are on the 1920 canvas.

**death 7.5/10** (t0206, t0210)
- Vignette edge: maroon about (65,12,18) → red about (200,40,50) on all four edges, at the same alpha.
- Killer card: make the gloss draw by exempting it from `calmOne`, about 45 % white over the top 50 %, with 8 px corners (t0210).
- Health bar at 0: dark empty plate → red-tinted empty track (t0206 shows a red bar with a red sliver).

**death2 8/10**: the killer card gloss, as above. The dimmed LOST card reads correctly.

**live / countdown 8/10** (t0054)
- Unselected slot plates: alpha about 0.9 → about 0.3. The selected slot keeps its plate.
- Weapon icons: contained in the plate → overflowing its top by about 15 %.

**kill 8/10** (up from 7) (t0054)
- "Bot": add a 2 px dark stroke and go one weight heavier than "Eliminated". t0054's yellow name is heavier and outlined.
- "Eliminated": bold → regular.

**results 8/10** (t0140)
- Play Again / Leave: still flat black. The gloss exists but `calmOne` hides it → a visible top-light gradient (light grey to dark), as in t0140.
- Rematch: fine while it's available ("0/1"). Ghost it to about 40 % text opacity only when unavailable.

**matchpoint 9/10** (t0122): MATCH POINT / SUDDEN DEATH letters → a 3 px dark drop shadow.

**searching 8/10** (t0018): the hexagram is still there → crossed-guns glyph.

**loadout 8/10** (t0036): the Random glyph is still ⇄ → crossed shuffle.

**playmenu 8/10**: "Season 1" / "Unranked" are still italic → upright.

**found 9/10** (t0022): give the tip bubble a small tail at its left end.

**vote 9/10** (t0032): picked tile name band, grey stripes → accent-tinted stripes.

**victory 9/10**: nothing to fix.

Timing (unscored): nothing new seen in the stills.

## Top 8 by visible impact
1. Stop `calmOne` hiding the `Gloss` frames. This unlocks the killer card gloss and the results button gloss in one change (t0210, t0140).
2. Vignette edges a saturated red, not maroon (t0206).
3. Hotbar: faint unselected plates (alpha about 0.3) and overflowing icons (t0054).
4. Victim name: 2 px dark stroke, heavier weight; "Eliminated" regular (t0054).
5. Health bar at death: red-tinted empty track (t0206).
6. MATCH POINT / SUDDEN DEATH drop shadow (t0122).
7. Searching and shuffle glyphs (t0018 / t0036).
8. Upright Season / Unranked text; tip bubble tail; accent-tinted vote stripes.
