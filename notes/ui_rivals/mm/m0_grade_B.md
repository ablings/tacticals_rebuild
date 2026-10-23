# m0 grade B (LOOK)

First round, so no regressions to check. Main finding: all match-HUD text renders in a narrow semibold humanist face (Source Sans-like). RIVALS uses one heavy geometric face everywhere. Our vote tiles and Play menu already use Rubik Bold and look right. Sizes below are on a 1920x1080 canvas (ours x1.51, RIVALS x1.2).

**playmenu 8/10** (ref t0016)
- Mode labels "1v1/2v2/3v3": 61px → 84px; "Ranked" 61 → 72px.

**searching 8/10** (t0018)
- Left icon: 33px star → 60px glyph.
- Remove the grey progress line under the "Searching for players." text. RIVALS has no line there.

**found 4/10** (t0020)
- "MATCH FOUND": Source Sans with a black halo stroke → Rubik Bold/Black, no stroke, soft shadow.
- "1V1" → "1v1", 26px heavy.

**vote 6/10** (t0028)
- Tile labels: 27px → 36px heavy, with a 2px dark shadow.
- Random tile: grey "?" with drop shadow → white shuffle icon, 90px.
- Timer plate "3.3": 30px Source Sans → 36px heavy, with an hourglass icon. The empty score plates should show their "0" digits.

**loadout 5/10** (t0036)
- Weapon names: "RANDOM/PISTOL" uppercase 23px → Title case "Random/Pistol", 26px heavy, overlapping the bottom of the card.
- "Map: …" header: 23px → 31px heavy. The band should fade out at both ends.
- Selected slot stroke: 3px cream → 4px white, corner radius 8px. The Random icon should be a shuffle glyph, not ⇄.

**countdown 6/10** (t0040): same as live.

**live 5/10** (t0046)
- Score digits: 33px semibold → 43px heavy. The timer is 27px → 36px heavy and should keep the hourglass icon all the time (ours only shows it during the countdown). "ROUND 1" and "First to 2" at 15px are too small to read: shrink them further or drop them.
- Hotbar: slots are 160–190px wide with a white 2px stroke on the selected slot → about 84px squares, translucent dark, no stroke. Show the selected slot with a lighter fill instead, and let the icons overflow the frame.
- Key-hint strip: 23px text in a 45px pill → 14px text in a 36px pill. The mission reward icons should be 21px faded → 30px opaque.

**kill 5/10** (t0122, t0056)
- MATCH POINT: a tall boxed bar (720x86) with 60px text inside → a thin skewed bar (~40px tall) with ~66px heavy white text spilling past the bar on both edges.
- ROUND WON: "WON" at 39px semibold → 48px heavy.
- Switch Weapons: 21px medium → 26px heavy. Kill-feed plate text: 17px → 22px bold.

**death / death2 4/10** (t0210)
- No killer card is drawn. Add one: a ~680x135 card in the bottom right, with the name 40px heavy, "@user" 18px, and "eliminated you with X" 24px bold.
- Kill feed while dead: ~70% transparent and unreadable → opaque.
- death2 looks like plain live HUD: no kill-cam tint or vignette (ref_rivals_rounds/death_vignette).

**victory / results 6/10** (t0140; the two captures are identical)
- Banner: team name 33px → 43px heavy. Player plate name: 26px → 36px heavy.
- Buttons: add a 3px white stroke and 8px corners, with text at 38px heavy. The cream text on the green "Play Again" button is low contrast: use white.
- Stat digits: 30px → 34px heavy.

## Top 8 by visible impact
1. Use one heavy face for all HUD headings and numbers (Rubik Bold/Black), replacing the Source Sans-like face on every match screen.
2. Add the killer card on death (t0210).
3. Hotbar: smaller stroke-less slots and a 14px key-hint strip (t0046).
4. MATCH POINT as a thin skewed bar with oversized heavy text (t0122).
5. Score and timer digits at 43/36px heavy, with the hourglass always on (t0046).
6. Results buttons: white stroke, heavy 38px text, white text on Play Again (t0140).
7. Loadout: Title-case 26px weapon names and a shuffle icon (t0036).
8. MATCH FOUND: drop the halo stroke, use the heavy face, write "1v1" (t0020).
