# m12 grade B (LOOK)

**Moved away from RIVALS:** the hotbar plates. In t0054 the unselected slots are faint and see-through. m12 made them darker, going from (17,24,34) to (12,15,24), so they read as more opaque black tiles. The change is small but in the wrong direction.

**m11 fixes:**
- **Red arc: landed.** It is a curved arc on the ring with a tip, not the ▲ glyph any more. It is too thin (see death).
- **Held-weapon name: landed.** "Pistol" went from 94 to 85 px wide on 1268, a cap of about 33 px on 1920. "Assault Rifle" in t0054 is about 31 px.
- **Vignette edge: partly landed.** Bottom-centre went from (81,7,8) to (54,6,4) and the left from (94,8,17) to (65,8,17), so the scene shows through more. The edge is still dark maroon, though. RIVALS' edge in t0206 is a bright, translucent red wash.
- **Killer card gloss: not visible.** The card pixels are identical to m11 at every row: (77,133,88) at the top, (37,66,44) at the bottom. The `Gloss` frame (DuelHUD line 1541) is in the code but doesn't show in the capture. It also has no `corner(8)`, so once it draws its top corners would be square.
- **Health bar at the death moment: not landed.** m12_death still shows a full bone bar reading "150". RIVALS t0206 has an empty red bar.

All sizes below are on the 1920 canvas.

**death 7/10** (t0206, t0210)
- Arc: stroke about 6 px → about 18 px, with an arrowhead about 45 px wide at the arc's end. Keep the width at about 13.7 % W (t0206).
- Vignette edge colour: dark maroon about (100,15,15) → saturated red about (200,40,50) at the same alpha, so it reads as a red wash rather than a darkening (t0206).
- Killer card: make the top gloss actually draw (about 28 % white over the top 50 %), with an 8 px top corner (t0210).

**death2 8/10**: needs the card gloss. The dimmed LOST card (grey text on green) is fine.

**live / countdown 8/10** (t0054)
- Unselected slot plates: about 0.9 opaque near-black → alpha about 0.3, so the floor shows through. The selected slot keeps the dark plate. At the moment the selected slot is the lightest tile, which is the opposite of t0054.
- Weapon icons: inside the plate → overflowing the plate top by about 15 % (t0054's rifle and knife).

**kill 7/10** (t0054)
- Victim "Bot": muted green at the same weight as "Eliminated" → brighter, heavier and with a 2 px dark stroke. It is currently dimmer than "Eliminated", which inverts the hierarchy.
- "Eliminated": bold → regular.

**results 8/10** (t0140)
- Play Again / Leave: flat black → a top-light vertical gradient (light grey to dark), with a 3 px white stroke and about 12 px corners.
- Rematch: solid plate with bright text → ghosted, with about 40 % text opacity and a faint stroke (t0140 "unavailable").

**victory 9/10**: nothing new to fix.

**matchpoint 9/10** (t0122): MATCH POINT / SUDDEN DEATH glyphs → a 3 px dark drop shadow under the letters.

**searching 8/10** (t0018): the hexagram is still there → crossed-guns glyph.

**loadout 8/10** (t0036): the Random glyph is still ⇄ → crossed shuffle.

**playmenu 8/10**: "Season 1" / "Unranked" are still italic → upright.

**found 9/10** (t0022): give the tip bubble a small tail at its left end.

**vote 9/10** (t0032): the picked tile's name band uses grey stripes → accent-tinted stripes.

Timing (unscored): nothing new.

## Top 8 by visible impact
1. Arc stroke about 18 px with a 45 px arrowhead (t0206).
2. Vignette edge as a bright translucent red, not maroon (t0206).
3. Hotbar: faint unselected plates and overflowing icons. This also reverses this round's darkening (t0054).
4. Killer card gloss that actually renders, with rounded corners (t0210).
5. Kill line: heavy, bright, stroked victim name and a regular "Eliminated" (t0054).
6. Results: glossy Play Again / Leave and a ghosted Rematch (t0140).
7. Health bar empties at the death moment (t0206).
8. Searching / shuffle glyphs, upright Season text and the MATCH POINT shadow.
