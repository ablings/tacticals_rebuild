# m5 grade C: interactivity and feel

**Regressions:** none. matchpoint was captured at last. `m5_victory.png` shows the results card, not the cutscene.

**m4 fixes (b0e9d6d), checked in code and captures:**
- **Clock freeze: landed.** `RV.liveClock` (DuelHUD lines 1740-1741) holds 1:17 in kill and 1:19 in death, as RIVALS t0118/t0120 hold 1:11.
- **Killer card slide-out: landed, with one bug.** If `onKiller`/`keepCard` comes back during the 0.3 s exit (line 1825), the code snaps Position home but never cancels the out-tween. The card then finishes off-screen while still Visible. Keep the tween in `RV.kcOut` and `:Cancel()` it there. death2 is again past the 1.5 s window, so neither the hold nor the exit can be seen.
- **"Eliminated X" 4 s: in code (line 1310), but never seen.** m4 (1.6 s into RoundEnd) and m5 (clock frozen, well inside 4 s) both lack it, while the feed shows "debits > Bot". Check that `showEliminated` actually fires for bot kills.
- **Kill feed: y 68, 1.3x, right-anchored, landed (kill/death).** Row life is 5 s (line 336). RIVALS keeps the pill through the next countdown (t0118→t0124, t0210→t0214, ~7 s).

**playmenu 8, searching 8, countdown 8, live 8.** No change.

**found 7/10** (t0020)
1. "Match found / 1v1" → "Teleporting / N" in place, plus the tip bar at y 1000-1052.

**vote 6/10** (t0030/t0032)
1. Label "Arena" → "Arena [100%]".
2. Winner tile glides to the centre over 0.4 s (t0032).

**loadout 7/10** (t0036)
1. Active slot ring: 0/1 snap → 0.15 s Back pop (1.08 → 1) plus a ring fade.

**kill 7/10** (t0118-t0120)
1. Eliminated line missing: debug the trigger. Then end it at `min(4 s, Countdown start)`, because RIVALS t0122 has the ribbon with no Eliminated line. Our 3 s RoundEnd would leave it about 1 s over the ribbon.
2. Feed row life 5 s → 7 s.

**matchpoint 6/10** (t0122)
1. Round card: gone → keep WON dimmed under the ribbon at (960, 140). death2 already does this with LOST, so the two outcomes don't match.
2. Kill feed pill is gone → still up at the ribbon (same 7 s fix).
3. Switch Weapons missing at capture time. It shows in death2. Check that its 0.4 s delay fires on the won path too.

**death 6/10** (t0206)
1. HP fill stays bone under the red wash → red while the wash is up.
2. Add a damage-direction arrow toward the killer (t0206).
3. LOST card: Back pop → 0.6 s fade-in (t0208→t0210).

**death2 6/10** (t0212-t0214)
1. Capture on `Countdown` + 0.5 s. RIVALS t0212 still shows the card at 4.5 s left; ours is gone.
2. Cancel the out-tween on re-show (bug above).

**victory: can't judge** (the shot is the results screen).

**results 7/10** (t0142)
1. Play Again: "Searching..." relabel → straight to the teleport dots.

## Top 8 by visible impact
1. kill: find out why "Eliminated X" never shows, then end it at the Countdown (t0118-t0122).
2. matchpoint: dimmed WON under the ribbon, like LOST (t0122).
3. death2: capture at Countdown + 0.5 s to prove the hold and slide-out (t0212/t0214).
4. Kill feed row life 5 → 7 s (t0118-t0124).
5. Killer card: cancel the out-tween on re-show.
6. death: red HP fill + direction arrow (t0206).
7. vote: [%] label + winner glide (t0030/t0032).
8. loadout: active ring pop (t0036).

**Server notes (not scored):** RoundEnd is 3 s against RIVALS' ≥4 s post-death hold (t0206-t0210). The countdown is 3 s. The capture harness still lags about 2 s and misses the victory cutscene.
