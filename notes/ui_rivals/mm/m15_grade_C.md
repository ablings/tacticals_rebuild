# m15 grade C: interactivity and feel

**Did anything move away from RIVALS? No.** I judged durations from the code at 1x (live). `slow()` only stretches them in Studio. The console stayed clean through the whole Studio match. There is no m15_victory capture, so victory carries its m14 score.

**m14 fixes, checked in code (de9441e)**
- **endElim now cancels the running fade before replacing it.** This landed and is correct (DuelHUD l.1323). The orphaned 0.4 s hold-fade window is closed.
- **The unused `local ar` was removed from the arc loop.** Landed.
- **"Eliminated" is regular weight and the name bold.** It uses `<font weight="regular">` on an FB (Bold) label with RichText on. That is valid, and m15_kill shows the split. The 0.25 s Back pop (1.4 → 1) still drives it, so the feel is unchanged.
- **"Teleporting / N" is now settled** (brief) and is no longer flagged.
- **The arc head is not changed.** It is still the upright ▲ (m15_death).

**playmenu 8, searching 8, found 8, vote 9, loadout 7, countdown 8, live 8, matchpoint 8, results 8, victory 8 (m14, not recaptured).** These have no feel changes and nothing new to fix.

**kill 9/10** (t0054-t0056, up from 8.5). The Eliminated pop, 4 s hold and fade now cancel cleanly in every order. Nothing left on feel.

**death 9/10** (t0206)
1. Arc head: an upright ▲, about 66 px at 1920 → RIVALS' shark-fin head, about 85 px. It should lean toward the trailing (left) side, with its base sitting on the stroke. This is carried over from m14 and is the one remaining visible feel/finish item on the death moment.

**death2 7.5/10** (t0212-t0214)
1. Can't judge the killer-card exit. The +2.5 s shot lands in the next countdown (SUDDEN DEATH) with the card still up. That matches the settled 2.0 s carry into the countdown, but the slide-out itself is not in frame. Recapture at about +15 s (or about 2.5 s after the countdown starts) to see the exit.

## Top fixes by visible impact
1. Death arc head: a ~85 px fin leaning left, seated on the stroke (t0206).
2. Recapture death2 after the killer-card exit to confirm the slide-out (t0212-t0214).

(No further feel fixes. Vote share, arc ease and snap, Eliminated cancellation, and the found hand-off are all settled.)

**Server/Studio (not scored):** RoundEnd is still 3 s against RIVALS' ~4 s. Two Studio-only gaps are unchanged: the red wash `TweenInfo.new(1.5)` and the MatchEnd fallback `1.5` are not wrapped in `slow()`. The Eliminated hide delays (0.32 / 0.45 s) are also not slowed, but they follow 0.3 / 0.4 s tweens that are not slowed either, so they stay consistent.

Remaining feel gap worth another round: no
