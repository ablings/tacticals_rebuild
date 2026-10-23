# m1 grade B (LOOK)

**Regressions:** none. The font fix landed: every frame is now Rubik. The killer card, results buttons, Match found and vote hourglass all moved closer to RIVALS. Several m0 type fixes are still open (loadout casing, MATCH POINT bar, key hints, missions). Sizes are on a 1920x1080 canvas (ours x1.51, RIVALS x1.2).

**playmenu 8/10** (t0016)
- Mode labels "1v1/2v2/3v3": 68 → 74px. Tile corners: about 6 → 2px (RIVALS tiles are almost square).

**searching 8/10** (t0018)
- Left icon: 33px star → 60px glyph.
- Grey progress line under "Searching for players." is still there. Remove it.

**found 8/10** (t0020)
- "1v1" line: 36 → 43px.
- Missing element: the tip bubble at the bottom left (white rounded pill, 26px dark text).

**vote 6/10** (t0028)
- Random icon: ⇄ → crossed shuffle glyph, about 90px.
- Score plates are empty → show the "0" digit, 43px heavy, as RIVALS does.
- Tiles touch → 12px gutters. Timer plate: opaque black square → translucent dark grey with 6px corners. Labels 27 → 34px.

**loadout 5/10** (t0036)
- Weapon names: still "RANDOM/PISTOL" uppercase → Title case "Random/Pistol", 26px heavy, overlapping the bottom of the card.
- Random card: ⇄ → a dimmed shuffle glyph.
- Selected slot: 3px cream stroke → 5px white, with 8px corners. Header 26 → 31px.

**countdown / live 5/10** (t0046)
- Timer plate: two lines, "1:20" with "ROUND 1" below → one line, hourglass plus "1:25" at 36px heavy (the hourglass shows only below 10 s now). Remove "First to 2" at 15px.
- Score plates: 9 → 32px gap between plates, digits 30 → 36px cap height.
- Hotbar: drop the 2px white stroke on the selected slot and use a lighter fill. Slots 114x76 → about 84x72. Key-hint strip: text 21 → 13px, pill 45 → 36px tall.
- Missions: title 21 → 26px, rows 20 → 23px, progress bars 3px grey → 5px filled, reward icons 23px faded → 36px opaque.

**kill / roundcard 6/10** (t0056, t0122)
- MATCH POINT / SUDDEN DEATH: boxed 720x86 bar with end caps and the text inside → a thin skewed bar about 36px tall, with 72px heavy text spilling above and past it. Slivers of the score plates and "First to 2" show under our bar; hide them fully.
- Kill-feed plate: text 17 → 22px bold, plate 36 → 38px tall.
- Switch Weapons: text 23 → 26px heavy with a top gloss gradient. The M key cap should overlap the right edge. Move it from y 65% to 72%.

**death 7/10** (t0210)
- Killer card: size and name are right. Move it down: top 69% → 76% of the screen height.
- Add a "@user" line (18px, faded) under the name. "eliminated you with" text: 23px medium → 24px bold.
- Card fill: flat → horizontal gradient with gloss, plus a drop shadow.

**death2** shows Sudden Death (see kill). Can't judge the kill-cam tint.

**results 8/10** (t0140)
- Player plate name: 27 → 36px heavy. Level badge: 27 → 36px.
- Banner name: 33 → 38px. Banner 360x95 → 307x96, narrower.
- Buttons: flat dark → a light-to-dark vertical gloss. Rematch should use the same stroked button shape.

## Top 8 by visible impact
1. MATCH POINT / SUDDEN DEATH: thin skewed bar with oversized text overflowing it (t0122).
2. Live timer on one line with an hourglass. Drop "ROUND 1" and "First to 2". Wider gaps between the score plates (t0046).
3. Hotbar: no stroke on the selected slot. Key hints at 13px in a 36px pill (t0046).
4. Loadout: Title-case weapon names and a shuffle icon (t0036).
5. Vote: shuffle icon, "0" digits on the score plates, 12px tile gutters (t0028).
6. Missions panel: bigger type, filled progress bars, opaque reward icons (t0046).
7. Killer card: move down, add the @user line, gloss (t0210).
8. Results: plate name 36px, gloss on the buttons (t0140).
