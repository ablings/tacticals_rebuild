# m1 grade C: interactivity and feel

No regressions: nothing that changed since m0 moved us away from RIVALS. These m0 fixes landed: the teleport look, MATCH POINT only at the countdown with WON dimmed, the hourglass that turns red at 0 on the vote, and no clock during the pick. Note: the round has no `m1_matchpoint.png`. The MATCH POINT shot is `m1_roundcard.png`, and `m1_kill.png` is the WON card. Victory wasn't captured, so it isn't graded.

**playmenu 8, searching 8, countdown 8, live 8.** Nothing to fix.

**found 7/10** (t0020)
1. At Teleporting the gate hands over to PadUI's wordmark screen, so you see two screens. RIVALS keeps one: keep the blur and dots, and change "Match found / 1v1" → "Teleporting / N" in place.
2. Add the tip bar (x 240-1470, y 1000-1052) under the dots for the whole wait.

**vote 6/10** (t0030-t0032; m0 fixes 2 and 3 are still open)
1. Voted tile: ring only → pale wash over the whole tile, voter heads ~70 px in the tile centre, label "Map [100%]".
2. Winner: lands +120 px below the row → glide it to the screen centre (0.5 W, 0.5 H).

**loadout 7/10** (t0036)
1. Active slot: 3 px cream ring → 6 px white ring on an 84 px square, with a Back pop on each step.

**kill (WON) 6/10** (t0118-t0120)
1. "Eliminated X" fades at 2.2 s and is gone in our shot. RIVALS holds it with the card for ≥4 s (t0118 and t0120). Hold it until the countdown.
2. Timer: RoundEnd shows a tenths countdown (1.4) → freeze the live clock, as RIVALS does (1:11 in t0118-t0120). Use tenths only in Countdown (t0212 4.5).
3. World: our only change is the 0.35 s dip to black at the end → dim the world ~40 % from ~1.5 s after the kill (t0120), holding through the countdown.

**matchpoint 7/10** (t0122)
1. The world stays bright under the ribbon → keep the ~40 % dim from the fix above (t0122 is dark).
2. Switch Weapons pops in the same frame as the ribbon → delay its popIn 0.4 s (t0056 → t0058).

**death 5/10** (t0206-t0210). The retake shows the right moment: LOST and the killer card are in, the hotbar is gone.
1. Missing: RIVALS' full-screen red wash plus the red direction arrow at the death frame, fading over ~1.5 s, with the HP bar going red (t0206). The code has neither.
2. LOST: the Back pop from 1.25 → a ~0.6 s fade-in (t0208 half-transparent, t0210 solid).
3. Killer card: the slide from off-screen right → the card grows leftward from x 1020 to 952 while the head and weapon appear (t0208 → t0210). It's a small change; the slide is fine if this costs much.

**death2 4/10** (t0212-t0214)
1. The card vanishes with no exit the instant you respawn (`onKiller` needs Alive == false). RIVALS keeps it, with LOST, ~1.5 s into the countdown (t0212 at 4.5), then it's gone by 2.5 (t0214). Hold `kcard` for 1.5 s of Countdown, then slide it out right over 0.3 s.
2. The hotbar is back with the card → keep it hidden until the card leaves (t0212 has none; t0214 has it back).
3. Pacing: we're already in the countdown 2.5 s after the death. RIVALS spends ~4 s on the kill-cam (t0206-t0210 is frozen at 1:23) before respawning. RoundEnd should be ≥4 s after a death.

**results 7/10** (t0140-t0142). The outlined buttons landed.
1. Play Again still relabels to "Searching..." → go straight to the teleport screen (dots), as RIVALS does at t0142.

## Top 8 by visible impact
1. death: red death wash + direction arrow (t0206).
2. death2: hold the killer card ~1.5 s into the countdown, then slide it out; keep the hotbar hidden until it goes (t0212/t0214).
3. kill/matchpoint: dim the world ~40 % from ~1.5 s after the kill through the countdown (t0120/t0122).
4. kill: hold "Eliminated X" ≥4 s (t0118/t0120).
5. death2: ≥4 s of kill-cam before the respawn.
6. found: one continuous screen into Teleporting, with the tip bar.
7. vote: pale wash plus [%] on your tile; the winner lands at the screen centre.
8. kill: frozen live clock during RoundEnd, tenths only in the countdown.
