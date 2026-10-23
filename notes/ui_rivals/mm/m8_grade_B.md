# m8 grade B (LOOK)

**Moved away from RIVALS: the vote label band, partly.** The new stripes are bright green (~#4F6B35) on black, so they are loud and fight the label. In t0028 the stripes are dark grey on near-black (#101410 / #202321, very low contrast), and only the 2px tile border is green.

**Landed:**
- Vote: the band is now dark. Labels are bigger (cap ~23px, t0028 lower rows ~21px), and the band is 48px high (t0028: 46px).

**Not visible:** the death red vignette and chevron. m8_death has no red at the edges: the edge pixels match m7 and the reddish-pixel count is unchanged. The code is in place (DuelHUD ~2250), but it doesn't show at 0.0 s and death2 has already respawned. Re-shoot at about 0.5 s after death.

**Not landed:** killer "@user" line and gloss, hotbar plates, shuffle glyph, searching icon, found tip bubble, results banner and Rematch. The other HUD screens are unchanged since m7 (a pixel diff found only scene noise).

**Correction to m7 B:** the round card is already 245x95 (t0054/t0210: 247x96), so drop that fix.

Sizes are on a 1920 canvas (ours x1.514, RIVALS x1.2).

**vote 7/10** (t0028)
- Stripes: bright green → dark grey (#1E221F on #111411, about +10 luminance). Keep the green only on the tile border.
- Random: ⇄ → the crossed-shuffle glyph (~108px).
- Timer plate: pure black → dark grey #151719.

**death 7/10** (t0210, ref_rivals_rounds/death_vignette.jpg)
- Capture the vignette and chevron. Then check the edge red (about 25% of the edge width, alpha ~0.5) and the red curved chevron (~60px) on a ring around the crosshair.
- Killer card: add the faded "@user" line (18px cap, ~50% white) between the name and "eliminated you with". Name 29 → 32px.
- Card fill: flat → vertical gloss (lighter top, darker bottom ~20%).

**kill 8/10** (t0054)
- Eliminated line: caught mid-fade again, so I can't judge it at full opacity. Target: "Eliminated" in white at medium weight, and the name heavy in the accent with a dark outline.
- Card fill: flat → the left-to-right gloss shown in t0054.

**live / countdown 8/10** (t0046)
- Hotbar: 112x76 opaque dark plates → faint plates (alpha ~0.3) with the icons overflowing them. Only the selected slot has a dark plate (t0122).
- "Pistol" cap 36 → 29px.

**matchpoint 8/10** (t0122)
- Ribbon: flat red → a darker lower band with a slanted 3D bottom edge. The size already matches (715x51 vs 713x48).
- Switch Weapons: semibold → heavy weight at the same 20px cap.

**loadout 8/10** (t0036)
- Header cap 18 → 22px. Band width 575 → 480px.
- Random: ⇄ → the crossed-shuffle glyph. Selected ring 6 → 8px, white.

**searching 8/10** (t0018)
- Icon: hexagram → crossed-guns glyph.

**found 7/10** (t0020)
- Add the white tip bubble at the bottom left (26px dark text, mascot).

**results 7/10** (t0140)
- Banner 360x94 → 307x96. Name cap 23 → 29px. Level badge 27 → 43px.
- Rematch: tan fill → dimmed dark plus a stroke ("unavailable"). Button gap 5 → 12px.

**playmenu 8/10:** "Season 1" / "Unranked": italic → upright.

**death2 / victory:** nothing new to grade (death2 had already respawned; victory equals results).

Timing (unscored): the Eliminated line is again mid-fade at capture. The vignette window (1.5 s) didn't overlap the death shot.

## Top 8 by visible impact
1. Vote stripes: green → low-contrast dark grey (t0028).
2. Death vignette and chevron: make them visible in a capture and verify (death_vignette.jpg).
3. Hotbar: faint plates, overflowing icons, 29px name (t0046 / t0122).
4. Killer card: "@user" line, gloss, 32px name (t0210).
5. Results: 307px banner, dimmed Rematch, 12px gaps, bigger name and badge (t0140).
6. Shuffle glyph on vote and loadout Random; crossed-guns icon on the searching pill (t0028 / t0036 / t0018).
7. Eliminated line weight, colour and outline; round card gloss (t0054).
8. Found tip bubble; MATCH POINT ribbon depth; loadout header 22px (t0020 / t0122 / t0036).
