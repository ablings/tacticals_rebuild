# m7 grade C: interactivity and feel

**Moved away from RIVALS:** nothing.

**m6 fixes (b1ad1f6), checked in code and captures:**
- **Feed pill held: landed.** The round-ending pill is up at matchpoint and under SUDDEN DEATH in death2, like t0214. It now overshoots a little. The countdown is 5 s, so a kill fades about 8.4 s later, at Live. RIVALS' pill is still up at t0214 (2.5 s left) and gone by t0216 (0.5 s left).
- **Killer card exit token: landed and correct.** The 0.3 s delay only clears its own exit (`kcardExitN == exitN`). A stale timer can't hide a card that came back.
- **2.5 s hold: in code, can't see it in captures.** death2 already shows Switch Weapons and the hotbar, so the card is gone. RIVALS t0212 (0.5 s into the countdown) still shows the card, and by t0214 (2.5 s in) it's gone. Our slide starts at 2.5 s and ends at 2.8 s, which is just past RIVALS' latest bound.

**playmenu 8, searching 8, countdown 8, live 8.** No change.

**found 7/10** (t0020)
1. "Match found / 1v1" → "Teleporting / N" in place, plus the tip bar at y 1000-1052 (carried over).

**vote 6/10** (t0030/t0032)
1. Label "Arena" → "Arena [100%]".
2. Winner tile glides to the centre over 0.4 s (t0032).

**loadout 7/10** (t0036)
1. Active slot ring: 0/1 snap → 0.15 s Back pop (1.08 → 1) plus a ring fade.

**kill 8/10** (t0054, t0118)
1. The Eliminated line now sits at y 72%. The capture again catches it in the fade, so its size can't be judged. Capture at RoundEnd + 1 s.

**matchpoint 8/10** (t0122, t0214). The pill now shows, WON is dimmed and Switch Weapons is up.
1. Feed row: end at Countdown with 1.5 s left, not at Live (t0214/t0216). Or use a flat 9.5 s life.

**death 6/10** (t0206)
1. Red wash: 0.5 fading over 1.5 s → hold the 0.45 wash about 1.0 s, then fade over 1.0 s, with a radial vignette (red edges) (t0206).
2. Damage-direction arrow: a red chevron about 120 px wide on a 180 px ring around the crosshair, pointing at the killer (t0206).
3. HP fill bone → red while the wash is up.

**death2 7/10** (t0212-t0214)
1. Round card in a non-deciding countdown: shown until Live, then cut → leaves with the killer card, about 2.0 s in, with a 0.25 s fade. At t0214 LOST is gone and only the pill stays. Keep the dimmed card under MATCH POINT / SUDDEN DEATH (t0122).
2. Killer card hold: 2.5 → 2.0 s, so it's gone by t0214's 2.5 s mark.
3. Capture at Countdown + 1.0 s. That proves the card, a full LOST card and Switch Weapons together (t0212).

**victory: can't judge.** The shot is the results screen; the cutscene was missed. Capture at MatchEnd + 0.5 s.

**results 7/10** (t0142)
1. Play Again: "Searching..." relabel → straight to the teleport dots.

## Top 8 by visible impact
1. Death: a held red vignette plus a damage-direction arrow (t0206).
2. Round card leaves about 2 s into a normal countdown with a 0.25 s fade (t0214).
3. vote: [%] label + winner glide (t0030/t0032).
4. death2 capture at Countdown + 1 s, to prove the killer card hold (t0212).
5. Killer card hold 2.5 → 2.0 s (t0214).
6. found: "Teleporting" relabel + tip bar (t0020).
7. Feed pill ends at 1.5 s left, not at Live (t0216).
8. loadout: active ring pop (t0036).

**Server notes (not scored):** RoundEnd is 3 s, but RIVALS holds about 4 s after a death (t0206-t0210). The 5 s countdown matches (t0212 reads 4.5). Capture lag still hides the 0-1.5 s windows (red wash, Eliminated at full size).
