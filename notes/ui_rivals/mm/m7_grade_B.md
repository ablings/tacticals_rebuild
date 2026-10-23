# m7 grade B (LOOK)

**Moved away from RIVALS:** none.
**m6 fixes that landed:**
- Missions: reward icons are now opaque red scissors (~33px). The fill is a bright blue bar (~5px) on a dark track (m7_kill, Eliminations 1/8), as in t0046.
- The dimmed WON/LOST card keeps its team fill at reduced opacity (t0122).
- The searching pill is near-opaque and nothing shows through it any more (t0018).
- The Eliminated line has grown to a ~27px cap (t0054: 30px).
- The loadout Random glyph is now dimmed.

**Not landed:** hotbar, score-bar plates, vote, tip bubble, searching icon, killer "@user" line, results banner and Rematch.
Sizes are on a 1920x1080 canvas (ours x1.514, RIVALS x1.2). The victory capture is identical to results (the cutscene wasn't caught): can't judge.

**live / countdown 8/10** (t0046)
- Hotbar: opaque squares → faint plates with icons overflowing them. "Pistol" cap 35 → 28px.
- Missions title cap 20 → 24px. Track: 2px grey → 5px dark, matching the fill height.

**kill 7/10** (t0054)
- Eliminated line: both words bold grey → "Eliminated" white medium weight, name heavy in the bright accent with a dark outline. Ours is caught mid-fade (dim green "Bot"), so I can't judge full opacity.
- Round card: 245x95 → 275x107. "WON" cap 30 → 37px, "ROUND" 12 → 16px.

**matchpoint 8/10** (t0122)
- Switch Weapons: 300x50 semibold 17px → 283x54 heavy 19px cap.
- Ribbon text cap 60 → 67px.

**death 7/10** (t0210)
- Killer name cap 27 → 34px. Add the faded 18px "@user" line under it.
- Card fill: flat → a vertical gloss (light top, darker bottom strip), as on t0210.
- LOST card: same size fix as kill.

**death2 8/10:** same as matchpoint.

**vote 6/10** (t0028). Unchanged for two rounds.
- Label band: pale stripes → dark diagonal hazard stripes under a white 23-29px cap (ours 20px).
- Random: thin ⇄ → a ~108px crossed-shuffle glyph.
- Plates 160 → 139px (reuse the HUD bar). Timer plate: flat black → dark grey.

**loadout 7/10** (t0036)
- Header cap 18 → 23px.
- Random: ⇄ → a crossed-shuffle glyph (the dimming has landed).
- Selected ring 6 → 8px.

**searching 8/10** (t0018)
- Icon: hexagram → a crossed-guns glyph.
- Timer "0:12" 20 → 23px heavy. "Searching for players." 14 → 16px.

**found 7/10** (t0020)
- Add the white tip bubble at the bottom left (26px dark text, mascot).

**results 7/10** (t0140)
- Banner 360 → 307px wide.
- Name cap 20 → 28px, level badge 24 → 40px.
- Rematch: tan fill → a dimmed dark button with a stroke. Button gaps 3 → 12px.

**playmenu 8/10:** no change. "Season 1" / "Unranked": italic → upright.

Timing (unscored): the Eliminated line is again caught mid-fade. Both RIVALS frames hold it at full opacity (t0054), and it's gone by t0056.

## Top 8 by visible impact
1. Vote: hazard-stripe bands, shuffle glyph, bigger labels, HUD plates (t0028).
2. Eliminated line: white "Eliminated" plus a heavy accent name with an outline (t0054).
3. Hotbar: faint plates, overflowing icons, 28px weapon name (t0046).
4. Round card 275x107, "WON"/"LOST" 37px (t0054 / t0210).
5. Killer card: "@user" line, 34px name, gloss fill (t0210).
6. Results: 307px banner, dimmed Rematch, 12px gaps, bigger name and badge (t0140).
7. Shuffle glyph on loadout Random; crossed-guns icon on the searching pill (t0036 / t0018).
8. Switch Weapons heavy 19px at 283x54; found tip bubble (t0122 / t0020).
