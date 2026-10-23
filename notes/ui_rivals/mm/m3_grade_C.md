# m3 grade C: interactivity and feel

**Regressions: none.** Two captures are off again. `m3_matchpoint.png` is a live frame (1:27). `m3_death2.png` is the SUDDEN DEATH countdown. There is no `m3_victory.png`, so the cutscene (Edward's request) isn't graded.

**m2 fixes, checked in code (cdc78fe):**
- Switch Weapons 0.4 s after the ribbon: **landed** (`RV.switchAt`). It shows in death2.
- Vote wash on your tile only: **landed** (`hasMe and 0.62`). It can't be seen yet because no vote has been cast at 3.0 s.
- Red death wash 1.5 s: **landed**, 0.5 → 1, Quad In. It's barely visible in the death shot, which is about 1.3 s in.
- Killer card timer latch: **landed in code, not seen.** The latch is correct: it re-arms each frame while `onKiller` is true and needs RoundEnd or Countdown, which matches MatchCore (clearSpectate, then Countdown). In death2 the card is gone and the hotbar is back. The death shot shows 1.7 s of RoundEnd left, so death2 (+2.5 s) should be about 0.8 s into the countdown, inside the 1.5 s window. Recapture at +0.5 s into the countdown. If the card is still missing, log `kcardUntil` against the state change.

**playmenu 8, searching 8, countdown 8, live 8, loadout 7.** Same as m2. Loadout still needs the active-slot Back pop.

**found 7/10** (t0020)
1. "Match found / 1v1" → "Teleporting / N" in place, plus the tip bar at x 240-1470, y 1000-1052.

**vote 6/10** (t0030/t0032)
1. Label: "Arena" → "Arena [100%]", and lighten the label strip with the wash.
2. Voter heads: ~70 px, mid-tile.
3. Winner: glide it to (0.5 W, 0.5 H) over 0.4 s (t0032).

**kill (WON) 7/10** (t0118-t0120)
1. "Eliminated X" is missing at 1.4 s left. In code it holds 2.2 s from the kill event (`showEliminated`), so it's either already gone or never fired. Tie it to the state instead: hold it until RoundEnd ends (t0118/t0120 still show it).
2. Timer: counting tenths through RoundEnd (1.4) → freeze the last live clock until the countdown (t0118-t0120 hold 1:11).
3. Dim: at 1.6 s in it hasn't started (start 1.5 s, 0.5 s tween). Start it at 1.0 s so the shot reads like t0120.

**matchpoint: can't judge.** The capture caught the live round again. Fire the shot on the ribbon's appearance, not on a timer.

**death 6/10** (t0206)
1. Turn the HP fill red while the wash is up. It is bone (150) in the shot.
2. Add a damage-direction arrow at the screen edge toward the killer (t0206).
3. LOST card: Back pop → 0.6 s fade-in (t0208 → t0210).

**death2 6/10** (t0212-t0214). Up from 4 because Switch Weapons is staggered now and the dim holds.
1. Killer card: recapture and verify the latch (see above).
2. Card exit: hard cut (`Visible = false`) → slide out right 0.3 s, Quart In (mirroring the slide-in) (t0214).

**results 7/10** (t0142)
1. Play Again: "Searching..." relabel → straight to the teleport dots.

## Top 8 by visible impact
1. death2: prove the killer-card linger in a capture at +0.5 s into the countdown (t0212).
2. kill: hold "Eliminated X" through RoundEnd (t0118/t0120).
3. death: red HP fill + direction arrow with the wash (t0206).
4. kill: freeze the live clock during RoundEnd (t0118).
5. death2: slide the killer card out, not a cut (t0214).
6. vote: "[%]" label, centred heads, winner glides to the centre (t0030/t0032).
7. found: one continuous screen into Teleporting, with the tip bar (t0020).
8. kill: start the dim at 1.0 s (t0120).

**Server notes (not scored):** the kill-cam gets RoundEndDelay = 3 s, but RIVALS holds ≥4 s after a death (t0206-t0210). The capture harness also misses matchpoint and victory.
