# m4 grade C: interactivity and feel

**Regressions:** none. Two shots are off again: `m4_matchpoint.png` is a live frame (1:27), and `m4_death2.png` is the SUDDEN DEATH countdown. There's no victory capture.

**m3 fixes, checked in code (828f39a):**
- **Killer-card hold: the logic is correct.** `DuelHUD.client.lua` lines 1807-1809:
  - `RV.kcardShown` latches true whenever `onKiller` is true. It clears only on Live, MatchEnd or Victory, so losing `SpectateTarget` early in RoundEnd no longer drops the card.
  - `kcSince` is stamped on the first frame of each state change. `keepCard` stays true for all of RoundEnd and for `os.clock() - kcSince < 1.5` into the Countdown.
  - The hotbar stays hidden for the same span (lines 1822-1823), which matches t0212.
  - This block sits after the `gui.Enabled` early return, but Countdown counts as `playing`, so the stamp isn't missed.
  - Small edge case: a `MatchPhase == "Finisher"` while MatchState is still RoundEnd would keep the card up. The VictoryScreen disables the GUI, which covers it.
  - **Not visible yet, as expected.** The death shot shows 1.7 s of RoundEnd left. death2 (+2.5 s, plus the ~2 s capture lag) lands about 2.8 s into the 3 s countdown, past the 1.5 s window. The missing card in death2 doesn't prove a bug.
- **Card exit:** still a hard cut (`Visible = false`, line 1817). The m3 fix (slide out) has not landed.
- **"Eliminated X" hold, frozen RoundEnd clock, dim at 1.0 s:** none landed. The kill shot shows "1.4" counting and no Eliminated line. The code still uses `task.delay(2.2)` (line 1305).
- **Loadout:** the block drop and the 5 px ring landed. The active slot still snaps (`edge.Transparency` 0/1, MatchFlowUI line 744).

**playmenu 8, searching 8, countdown 8, live 8.** No change.

**loadout 7/10** (t0036)
1. Active slot ring: snap → a 0.15 s Back pop (scale 1.08 → 1) and a fade of the ring 1 → 0 when the step moves.

**found 7/10** (t0020)
1. "Match found / 1v1" → "Teleporting / N" in place, plus the tip bar at x 240-1470, y 1000-1052.

**vote 6/10** (t0030/t0032)
1. Label: "Arena" → "Arena [100%]", with the label strip lightening along with the wash.
2. Winner: glide it to (0.5 W, 0.5 H) over 0.4 s (t0032).

**kill (WON) 7/10** (t0118-t0120)
1. "Eliminated X": the 2.2 s timer → hold it while state == RoundEnd (t0118/t0120).
2. Clock: counting tenths in RoundEnd → freeze the last live value (t0118 holds 1:11).
3. Dim: start it at 1.0 s instead of 1.5 s (t0120).

**matchpoint: can't judge.** Trigger the shot on the ribbon's appearance.

**death 6/10** (t0206)
1. The red wash is gone at capture time and the HP fill is bone. Turn the HP fill red while the wash is up.
2. Add a damage-direction arrow at the screen edge toward the killer (t0206).
3. LOST card: Back pop → 0.6 s fade-in (t0208 → t0210).

**death2 6/10** (t0212-t0214). The logic is right but can't be seen yet.
1. Capture: fire it on `MatchState → Countdown` + 0.5 s, not death + 2.5 s.
2. Card exit: hard cut → slide out right 0.3 s, Quart In (mirroring the slide-in; t0214). Re-show the hotbar after the slide ends.

**results 7/10** (t0142)
1. Play Again: "Searching..." relabel → straight to the teleport dots.

## Top 8 by visible impact
1. death2: re-time the capture to Countdown + 0.5 s to prove the hold (t0212).
2. kill: hold "Eliminated X" through RoundEnd (t0118/t0120).
3. death2: slide the killer card out instead of a cut (t0214).
4. death: red HP fill + direction arrow (t0206).
5. kill: freeze the clock during RoundEnd (t0118).
6. vote: "[%]" label + winner glides to the centre (t0030/t0032).
7. found: Teleporting continuation + tip bar (t0020).
8. loadout: active slot ring pops instead of snapping (t0036).

**Server notes (not scored):** the countdown is 3 s, so the 1.5 s hold covers half of it. RIVALS' post-death hold is ≥4 s (t0206-t0210) against our 3 s RoundEndDelay. The capture harness still misses matchpoint and victory and lags about 2 s.
