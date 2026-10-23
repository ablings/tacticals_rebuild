# m5 grade B (LOOK)

**Moved away from RIVALS:** the kill feed. Width improved (259 → 338px, target 365px), but height overshot: 36 → 48px against 37px (t0056 / t0210). Scale the width only.
**m4 fixes that landed:** score-bar gaps now ~30px (t0046: 31px both sides; my m4 "66px" was wrong). Matchpoint captured: ribbon 715x50px vs 713x52px (t0122).
**Not landed:** missions bars/icons, hotbar, Random glyph, tip bubble, searching icon, results banner, Rematch, "@user" line, plain skull.
Sizes are on a 1920x1080 canvas (ours x1.514, RIVALS x1.2).

**live / countdown 7/10** (t0046)
- Score plates 129 → 139px wide. Timer plate 85 → 73px tall, shorter than the plates.
- Missions: bars faint grey 2-3px → 6px bright fill on a dark track. Reward icons faded ~23px → opaque 36px. Title cap 17 → 20px.
- Hotbar: opaque dark squares → faint plates with icons that overflow them. "Pistol" cap height ~36 → ~29px.

**kill 7/10** (t0056)
- Kill feed: 338x48 → 365x38, with a 2px light outline.
- Enemy skull: dark disc → plain desaturated (t0056 / t0210).

**matchpoint 8/10** (t0122)
- "MATCH POINT" cap height 56 → 62px. Bar ends: square → slanted, with a top gloss.
- Add Switch Weapons under the faded card (t0122).

**death 7/10** (t0210)
- Killer name cap height 26 → 34px. Add the faded 18px "@user" line. Card: flat fill → a top-light vertical gradient.
- Own-plate skull and kill feed: as kill.

**death2 8/10** (t0122)
- Switch Weapons: text ~20px semibold → 24px heavy, plate 50 → 58px tall.

**vote 7/10** (t0028)
- Score plates 160x85 → 139x85, to match the HUD bar.
- Random: thin ⇄ → a ~108px crossed-shuffle glyph. Tile gutters 5 → 12px.
- Label band 48 → 56px tall. Pale stripes → dark diagonal hazard stripes.

**loadout 7/10** (t0036)
- Header cap height 18 → 23px. Band 553x50 → 480x53px.
- Selected ring ~6 → 10px white. Empty slots: opaque → faint translucent.
- Random card: bright ⇄ → a dimmed shuffle glyph. The slot-to-card gap is 59 → 38px.

**found 7/10** (t0020)
- Add the white tip bubble bottom left (26px dark text). Text cap 30 → 36px.

**searching 8/10** (t0018)
- Icon: hexagram → a 54px crossed-guns glyph.

**playmenu 8/10:** no change since m4. "Season 1" / "Unranked": italic → upright.

**results / victory 7/10** (t0140)
- Banner 360 → 307px wide. Name cap 23 → 30px, level badge 27 → 42px.
- Rematch: tan fill → a dimmed dark button with a white stroke. Button gaps 5 → 11px.

Timing (unscored): no "Eliminated" line in the kill shot, so the 4 s hold can't be judged.

## Top 8 by visible impact
1. Missions: 6px bright bars and opaque 36px reward icons (t0046).
2. Kill feed: 48 → 38px tall, with a light outline (t0056 / t0210).
3. Hotbar: faint plates with overflowing icons, smaller weapon name (t0046).
4. Score bar: 139px plates, 73px timer plate; vote plates the same size (t0046 / t0028).
5. Vote: shuffle glyph, 12px gutters, dark hazard stripes (t0028).
6. Results: 307px banner, dimmed Rematch, 11px gaps, larger name and badge (t0140).
7. Killer card: "@user" line, a 34px name, gradient (t0210).
8. Found: tip bubble (t0020).
