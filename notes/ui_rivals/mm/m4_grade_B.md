# m4 grade B (LOOK)

**Moved away from RIVALS:** nothing.
**m3 fixes that landed:** the loadout block moved down. The header centre is at 22.4% (t0036: 22%) and the slot top at 26% (27%). The selected slot now has a bold cream ring.
**Not visible in the capture:** the 31px score-bar gaps. In `m4_live` and `m4_kill` the strip is pixel-identical to m3, with gaps of about 7px at 1920 (plates at 752-880, timer at 887-1033, plate at 1040-1167). The code (`teamBox(557)` / `teamBox(1063)`) changed, but the HUD in the shot didn't. Redeploy DuelHUD and recapture.
Every other screen looks the same as m3. `m4_matchpoint` caught the live round (1:27) again. Sizes are on a 1920x1080 canvas (ours x1.514, RIVALS x1.2).

**loadout 7/10** (t0036)
- Selected slot: 92px with a ~6px cream ring → 100px with a ~10px white ring. Slot gaps 8 → 12px.
- Header "Map: …" cap height 20 → 24px. Band 575x47 → 480x53px.
- Random card: bright ⇄ → a dimmed crossed-shuffle glyph. The gap from the slots to the cards is 56 → 35px.

**live / countdown 6/10** (t0046)
- Score strip: gaps 7 → 32px (plate to timer) and 66px (timer to plate). Plates 128 → 138px. Timer plate 84 → 74px tall, so it is shorter than the plates.
- Missions: reward icons faded ~27px → opaque 36px. Bars: faint grey 2-3px → 6px bright fill on a dark track. Title cap height 17 → 19px. The backing plate is now there and fine.
- "Pistol" cap height ~36 → ~29px (t0046 "Assault Rifle"). Hotbar: opaque slot squares → faint plates with oversized icons that overflow them.

**kill 7/10** (t0056)
- Kill feed: 259x36 gold pill with ~17px text → 367x38 with ~21px text and a 2px light outline.
- The "WON" / "ROUND" sizes now match (37 / 17px cap height). Card: add a stronger top-to-bottom gloss and a 4px drop shadow.
- Bot skull: drop the dark circle behind it and use a plain desaturated skull, as in t0056.

**death 7/10** (t0210)
- Add the faded 18px "@user" line under the killer name. Name cap height 30 → 34px.
- The same kill-feed fix as kill.

**death2 / ribbon 8/10** (t0122)
- Bar 50 → 58px tall, with square-cut slanted ends. Switch Weapons text: ~18px semibold → 24px heavy.

**vote 7/10** (t0028)
- Random: ⇄ → a ~108px crossed-shuffle glyph. Tiles touch (~5px) → 12px gutters.
- Label band: pale stripes → dark diagonal hazard stripes. Labels 21 → 26px cap height.

**found 7/10** (t0020)
- Add the tip bubble: a white rounded pill at the bottom left with 26px dark text. "Match found" cap height 30 → 36px.

**searching 8/10** (t0018)
- Icon: 33px hexagram → a 54px crossed-guns glyph. Text 17 → 22px.

**playmenu 8/10** (t0016)
- "Season 1" / "Unranked": italic → upright medium. Close X: thin → a heavy glyph with a dark outline.

**results 7/10** (t0140)
- Banner 361 → 307px wide. Level badge 27 → 41px.
- Rematch: tan fill → a dimmed dark shape with a white stroke, like the other buttons. Button gaps 5 → 12px.
- Buttons: flat → a soft vertical gloss inside the stroke.

Timing (server, unscored): the matchpoint shot still misses the ribbon, so fire the capture when the ribbon appears.

## Top 8 by visible impact
1. Score strip: deploy the 32 / 66px gaps, 138px plates and a 74px timer plate (t0046, t0056).
2. Kill feed: 367x38, 21px text, light outline (t0056, t0210).
3. Missions: opaque 36px icons and 6px bright bars (t0046).
4. Loadout: 100px selected slot with a 10px white ring, 12px gaps, 24px header (t0036).
5. Vote: shuffle glyph, 12px gutters, dark hazard stripes (t0028).
6. Results: 307px banner, stroked and dimmed Rematch, 12px gaps (t0140).
7. Found: tip bubble at the bottom left (t0020).
8. Hotbar: drop the opaque plates and let the icons overflow; "Pistol" down to 29px (t0046).
