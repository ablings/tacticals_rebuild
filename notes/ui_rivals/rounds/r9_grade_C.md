# r9 grade C: completeness and finish

dp = capture px ÷ 0.66. Models are not graded.

**Nothing in r9 moved us away from RIVALS.** The Ranked tile is ~15% darker (avg 117,77,39 → 99,72,34). It wasn't on the change list, but RIVALS' Ranked tile is dark too (t0016).

**Checked:**
- **Kit Contracts row:** landed. It replaces "Next unlock" and reads "0 / 10 eliminations" with the arrow button. It reuses the Reward row's seal glyph, so two stacked rows share one icon. RIVALS gives Contracts its own icon and puts it first in the stack, above Overview and Statistics (t0051).
- **Kit floor fade:** mostly landed. The mid-floor at y 620 went from ~120 grey to ~65. A lighter band of ~95 is left just under the horizon (y 552–575).
- **Career card / list:** the fills may match, but on screen they still don't. The scene behind the card is pure black, so the card reads #000 and the list reads #0D0E10. The only visible edge is still a hard step at y 552, the floor horizon. I can't see the gap. RIVALS shows a clear ~9 dp gap between Career and the list (t0051).
- **Codes:** the white input landed (~#E6E6E6), and Redeem is a lighter green.
- **Settings:** the version label landed in the right place (bottom-right of the info panel), but it reads "v0". RIVALS shows "Version 1073 · 5h 21m 40s", which includes server uptime (t0138).
- **Play:** landed, but only partly. Training went from 142,105,143 to 138,91,147. It's still greyer than 1v1 (137,80,159). The wash still reads as a flat lilac film, while RIVALS' lower tiles are as saturated as its top row (t0016).
- **Price tags:** landed. The glyph is white with a dark stroke on all 13 tags, matching RIVALS' white key (t0070).

## kit: 8.5/10
1. Contracts icon: seal → a distinct contract glyph (~30 dp). Move the row to the top of the stack (t0051).
2. Career/list: make a visible ~9 dp gap. The list's top edge must not sit on the y 552 horizon (t0051).
3. Floor: darken the remaining band at y 552–575 to match the rest of the floor.
4. Still open: cream bench bezel.

## play: 9/10
1. Lower tiles: drop the wash further, so Training and Duel Pads average about the 1v1 saturation (t0016).

## codes: 7/10
1. Still open: white gift icon, no empty-state icon. Redeem text reads grey-white on green; make the disabled state clearer (e.g. 60% alpha on the whole button).

## settings: 8.5/10
1. "v0" → "Version N · uptime" in ~14 dp grey (t0138).
2. Still open: the Hotkeys icon is dark.

## shop: 8/10
1. Still open: no type tags or tile backing on the top tiles (t0070, shop.jpg). The revolver overruns its tile (x ~1040). VIEW covers the medal. "More →" has no icon.

## missions: 9.5/10
1. Still open: both contract rows use the eliminations glyph → a ~40 dp weapon icon per row (tasks.png). The glyph is ~30 → ~38 dp.

## hub: 9/10
1. Consistency: the hub widget shows "Melee kills 0/1", but the Missions panel shows "Eliminations 0/8" in the same slot. If both were captured in one session, the two views disagree.

## What's left, ranked by visible impact
1. Kit: Career/list gap (still a hard step at y 552)
2. Kit: Contracts glyph duplicates the Reward seal; row order
3. Missions: weapon icons on the contract rows
4. Shop: type tags/backing on the top tiles; revolver overflow
5. Kit: floor band under the horizon; cream bench bezel
6. Hub vs Missions: mission list mismatch
7. Play: lower tiles still greyer than the top row
8. Codes: gift icon, empty-state icon, disabled Redeem
9. Shop: VIEW over the medal; More icon
10. Settings: "v0" → full version and uptime; Hotkeys icon
11. Missions: contract glyph ~30 → ~38 dp
