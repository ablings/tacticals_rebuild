# m15 grade A: positioning and layout

**Moved away from RIVALS:** nothing. I diffed m15 against m14 at 1268x713. Vote is pixel-identical. Loadout, countdown, live, kill, death and results differ only in the world, the avatar and the mission text. The two UI changes are the MATCH POINT / SUDDEN DEATH text size and the "Eliminated" weight (a look fix). Both sit closer to RIVALS now. There is no m15_victory capture.

**m14 layout fixes:** none of them landed. The death arc is unchanged: same dome, same narrow spike at x 48.9%.

**searching 8/10** (t0018)
- Icon: 2.0% → 3.3% wide. Pill top: y 11.1% → 9.7% (the pill is 36.0-64.2% wide, against RIVALS' 35.6-64.5%, so the width already matches). Carried over.

**found 8/10** (t0020, t0022)
- The tip bubble still spans x 12.5-76.5% (y 92.6-97.3%), but its text ends at x 55.7%. In t0022 RIVALS fits the bubble to its text: it ends 1% after the text. Ours should end at about x 56.8%. Carried over.
- The dots (x 44.7-55.0%, y 47.0-52.9%) and the "Match found / 1v1" stamp (right edge 97.9%, y 87-91%) match t0020 to within 0.3%. Nothing to fix there.

**vote 9/10** (t0032)
- Tile: 25% → 22.6% wide. Name strip: 17% → 20% of tile height. Carried over.

**loadout 8/10** (t0036)
- Slot row: y 25.7% → 26.9%. Make the slot gaps an even 0.6% (11 px at 1080). Carried over.

**countdown / live 9/10.** Nothing to fix.

**kill 8/10** (t0054)
- "Eliminated" cap: y 70.5% → 69.1%. Hotbar: 27 px further right (x 81.3-99.4%). Carried over.

**matchpoint 9.5/10** (t0122, up from 9)
- The ribbon text landed. It is now x 35.0-65.2% (30.1% wide) and 5.5% tall, against t0122's x 34.5-65.6% (31.1%) and 5.6%. In m14 it was 27% wide.
- The ribbon and its text sit about 0.6% high. Our bar spans y 4.4-9.1% and our text top is at 1.8%; t0122 has 5.3-9.8% and 2.2%. Move both down about 7 px at 1080.
- The M key sits inside Switch Weapons (x 55.4-57.2%). Move it to straddle the right edge at x 56.6-58.3% (t0212). Carried over.

**death 9/10** (t0206). Unchanged from m14.
- Point: a 1.5%-wide spike → a broad fin 3.4-4% wide (about 70x75 px at 1080). Tip at y 26.7%, centre at x 47.5%, with the right flank longer than the left.
- Shape: dome → hook. The left tip goes to (41.6%, 38%). The right half stays flat at about y 31.5-32.3% out to x 55.1%.
- Stroke: 1.5-1.8% → 2.1% of height.

**death2 9/10** (t0212). The SUDDEN DEATH ribbon gets the same size result as matchpoint, with the same 0.6% offset.
- Weapon model: x 83.2-96.2%, y 62.4-93.7% → x 80.6-98%, y 67-98%. Carried over.

**results 9/10** (t0140)
- Stat labels: y 87.7% → 87.1%. Damage numbers: 91.9% → 90.6%. Button gap: 0.7% → 0.9%. Carried over.

**playmenu 8/10.** Settled. **Mascot:** none (our game has none). The tip bubble's 12.5% left inset is RIVALS' mascot gap, so I've left it as is.

*Timing (unscored): as in m14, the 0.0 s death shot already shows ROUND LOST and the killer card.*

## Top 8 by visible impact
1. Death point → a broad fin 3.4-4% wide, tip at y 26.7%, at x 47.5% (t0206).
2. Death arc → hook: steep left from (41.6%, 38%), flat right half at about y 32% (t0206).
3. Death2 weapon model → x 80.6-98%, y 67-98% (t0212).
4. Found tip bubble fitted to its text, ending at about x 56.8% (t0022).
5. Vote tile 22.6% wide, name strip 20% (t0032).
6. Searching icon 3.3% wide, pill top at 9.7% (t0018).
7. Loadout slot row at 26.9%, with even 0.6% gaps (t0036).
8. Ribbon and text down 0.6% (t0122). M key straddles the Switch Weapons edge (t0212). Results rows about 1% higher (t0140). Kill cap at 69.1% (t0054).

Remaining layout gap worth another round: yes
