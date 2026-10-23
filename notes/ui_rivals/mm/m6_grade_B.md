# m6 grade B (LOOK)

**Moved away from RIVALS:** none. The matchpoint/sudden-death faded round card is now desaturated grey on WON but keeps its teal on LOST. RIVALS keeps the fill colour and only fades it (t0122).
**m5 fixes that landed:** Switch Weapons now shows under the faded card (matchpoint, y 0.72 like t0122). The kill feed dropped from 48 to 41px tall (target 37). Its width is set by the content: 291px with "Bot" here, and RIVALS runs 276-366px (t0210/t0056). There's a new centre "Eliminated Bot" line at y 0.66 (t0054: 0.71).
**Not landed:** missions bars/icons, hotbar, score-bar plates, vote, loadout, tip bubble, searching icon, results banner/Rematch/gaps, killer "@user" line and name size.
All sizes are on a 1920x1080 canvas (ours x1.514, RIVALS x1.2). Victory had no capture this round.

**live / countdown 7/10** (t0046)
- Missions: bars ~3px faint → 6px bright on a dark track. Reward icons faded ~24px → opaque 34px. The lobby panel already draws opaque scissors (m6_searching), so reuse it. Title cap 15 → 18px.
- Score bar: plates 129 → 139px wide, timer plate 85 → 74px tall.
- Hotbar: opaque squares → faint plates with overflowing icons. "Pistol" cap 35 → 28px.

**kill 7/10** (t0054 / t0056)
- "Eliminated" line: grey 20px semi-faded → white 26px cap with a dark outline, name in the bright accent. Move it from y 0.66 to 0.71. Drop the "HEADSHOT • KILL" sub-line (RIVALS has none).
- Kill feed: 41 → 37px tall, add a 2px light outline.

**matchpoint 8/10** (t0122)
- Faded round card: grey → the team fill at ~50% opacity.
- Switch Weapons: 300x50 semibold 17px → 283x54 heavy 19px cap.

**death 7/10** (t0210)
- Killer name cap 26 → 30-34px. Add the faded 18px "@user" line under it.
- Card fill: flat → bright at left, fading toward the right edge.

**death2 8/10:** same as matchpoint.

**vote 6/10** (t0028)
- Label band 50 → 58px, label cap 20 → 24px. Pale stripes → dark diagonal hazard stripes.
- Random: thin ⇄ → a ~108px crossed-shuffle glyph. Tile gutters 5 → 12px.
- Plates 160 → 139px (match the HUD). Timer plate: flat black → dark grey.

**loadout 7/10** (t0036)
- Header cap 18 → 23px. Band 568x50 → 480x53px.
- Selected ring ~5 → 8px. Slot-to-card gap 55 → 35px.
- Random card: bright ⇄ → a dimmed shuffle glyph.

**searching 7/10** (t0018)
- Pill: translucent → near-opaque black. A lobby sign shows through behind "0:12" in m6.
- Icon: hexagram → a crossed-guns glyph.

**found 7/10** (t0020)
- Add the white tip bubble at the bottom left (26px dark text).

**results 7/10** (t0140)
- Banner 360 → 307px wide.
- Name cap 21 → 28px, level badge 24 → 40px.
- Rematch: tan fill → a dimmed dark button with a stroke. Button gaps 3 → 12px. Play Again 94 → 83px tall.

**playmenu 8/10:** no change. "Season 1" / "Unranked": italic → upright.

Timing (unscored): the Eliminated line was caught mid-fade. RIVALS holds it at full opacity through the WON card (t0054-t0056).

## Top 8 by visible impact
1. Missions: 6px bright bars and opaque reward icons. The lobby version already has them (t0046).
2. Eliminated line: white 26px with an outline, no sub-line, y 0.71 (t0054).
3. Vote: shuffle glyph, dark hazard stripes, 58px label band, 12px gutters (t0028).
4. Hotbar: faint plates, overflowing icons, smaller weapon name (t0046).
5. Results: 307px banner, dimmed Rematch, 12px gaps, bigger name and badge (t0140).
6. Searching pill: near-opaque, so the world doesn't bleed through (t0018).
7. Killer card: "@user" line, bigger name, fade to the right (t0210).
8. Score bar: 139px plates, 74px timer; faded round card keeps its colour (t0046 / t0122).
