# m6 grade C: interactivity and feel

**Regressions:** none. No victory capture this round.

**m5 fixes (2bb3475), checked in code and captures:**
- **Killer card exit cancel: landed.** `RV.kcardExit:Cancel()` runs on re-show (DuelHUD ~1827). One edge case is left. If the card leaves, comes back and leaves again inside 0.3 s, the first `task.delay(0.3)` sees the second exit's `kcardLeaving = true`. It then hides the card and snaps it home early, which cuts the second slide short. Fix: give each exit a token and check it in the delay. death2 is again past the 1.5 s hold, so the slide can't be seen.
- **Feed pills 7 s: in code, but still gone at matchpoint.** RIVALS keeps the pill longer than 7 s: from the death at about t0205, the pill is still up at t0214 (2.5 s left), so ≥9 s. With our 3 s RoundEnd plus a 3 s countdown, 7 s ends before the next round goes live.
- **Eliminated X: confirmed.** m6_kill catches it in the 0.4 s fade (about 4 s in), with the dim on. RIVALS t0118-t0120 match.
- **Round-end dim works.** Mean luminance falls from 112 (live) to 67 (kill / matchpoint / death2), about 40%. RIVALS dims at t0120-t0122 too.
- **Matchpoint: WON is dimmed under the ribbon and Switch Weapons shows.** Both m5 fixes are visible now and match t0122.

**playmenu 8, searching 8, countdown 8, live 8.** No change.

**found 7/10** (t0020)
1. "Match found / 1v1" → "Teleporting / N" in place, plus the tip bar at y 1000-1052 (carried over).

**vote 6/10** (t0030/t0032)
1. Label "Arena" → "Arena [100%]".
2. Winner tile glides to the centre over 0.4 s (t0032).

**loadout 7/10** (t0036)
1. Active slot ring: 0/1 snap → 0.15 s Back pop (1.08 → 1) plus a ring fade.

**kill 8/10** (key/t0054, t0118)
1. Eliminated line: about 24 px glyphs at y 713 → about 34 px (x1.4) at y 768, as in t0054, where "Eliminated SilkyChicken" is about 456 px wide. RIVALS has it as the second loudest element after the round card. Ours reads as a caption.

**matchpoint 7/10** (t0122)
1. Kill feed pill gone → still up under the ribbon. Change the row life to "until Live + 1 s, at least 7 s", or simply 10 s (t0122, t0214).

**death 6/10** (t0206)
1. Red wash: 0.5 fading over 1.5 s → hold the 0.45 wash about 1.0 s, then fade over 1.0 s. Add a radial vignette (the edges redder than the centre, as t0206). The capture can't see it yet.
2. Damage-direction arrow toward the killer: a red chevron about 120 px wide on a 180 px ring around the crosshair (t0206).
3. HP fill bone → red while the wash is up.

**death2 6/10** (t0212-t0214)
1. Capture on `Countdown` + 0.5 s. RIVALS t0212 shows the killer card, a full LOST card and Switch Weapons at 4.5 s left. At t0214 (2.5 s) the card and LOST are gone, but the feed pill stays.
2. Give each killer card exit a token (the race above).

**victory: can't judge** (no capture).

**results 7/10** (t0142)
1. Play Again: "Searching..." relabel → straight to the teleport dots.

## Top 8 by visible impact
1. Kill feed row: stays until the next round goes live (≥9 s, t0122/t0214).
2. Eliminated line x1.4 and down to y 768 (t0054).
3. Death: a held red vignette plus a damage-direction arrow (t0206).
4. death2: capture at Countdown + 0.5 s to prove the killer card hold and slide (t0212).
5. Killer card exit: a token in the 0.3 s delay.
6. vote: [%] label + winner glide (t0030/t0032).
7. found: "Teleporting" relabel + tip bar (t0020).
8. loadout: active ring pop (t0036).

**Server notes (not scored):** RoundEnd is 3 s, but RIVALS holds about 4 s after a death (t0206-t0210). Capture lag (2-4 s) still hides the 0-1.5 s windows (red wash, killer card hold).
