# m2 grade C: interactivity and feel

**Regressions: none.** Two m2 changes bring us closer to RIVALS: the hourglass now stays up through the live round (t0046), and the world dims between rounds. Two captures are mislabelled. `m2_matchpoint.png` is a live frame (1:28), and `m2_death2.png` is the SUDDEN DEATH countdown, so I graded each by what it shows. The victory cutscene is Edward's own request, so I haven't graded it.

**playmenu 8, searching 8, countdown 8, live 8.** Nothing to fix.

**found 7/10** (t0020). Unchanged since m1.
1. Keep one screen into Teleporting: "Match found / 1v1" → "Teleporting / N" in place, with no hand-over to PadUI. Add the tip bar (x 240-1470, y 1000-1052).

**vote 6/10** (t0030). The wash can't be judged from the shot because no vote has been cast at 3.3 s.
1. Code: the wash (white, 0.62) goes on *every* tile that has votes. Change it to the tile you voted for, and make it lighter on the label strip too (t0030 "Arena" strip goes pale green). Add "[%]" to the label: "Arena [100%]".
2. Voter heads at ~70 px in the tile centre (t0030: two heads, mid-tile).
3. Winner: still lands below the row → glide it to (0.5 W, 0.5 H) (t0032).

**loadout 7/10** (t0036)
1. Active slot: Back pop per step, 6 px white ring on an 84 px square. Still open.

**kill (WON) 7/10** (t0118-t0120). The dim landed. RoundEnd is 3 s, the dim starts at 1.5 s, so in our shot at 1.4 s left it's just beginning. That matches t0120.
1. "Eliminated X" is still gone in the shot. Hold it with the card until the countdown (t0118/t0120).
2. Timer: tenths (1.4) during RoundEnd → freeze the live clock (t0118-t0120 1:11).

**matchpoint (m2_death2) 7/10** (t0122). The dim holds through the countdown and Switch Weapons is in.
1. Switch Weapons still pops in the same frame as the ribbon → delay its popIn 0.4 s (t0056 → t0058).

**death 6/10** (t0206-t0210)
1. Red wash: the code flashes 0.55 → 1 over 0.8 s on Alive=false. It isn't visible in the shot. RIVALS holds it ~1.5 s with the HP bar red and a direction arrow (t0206). Change it to 0.45 → 1 over 1.5 s (Quad Out), turn the HP fill red while it shows, and add the arrow.
2. LOST: the Back pop → a 0.6 s fade-in (t0208 → t0210).
3. Pacing: the kill-cam still gets only RoundEndDelay = 3 s → ≥4 s after a death (t0206-t0210 is frozen 1:23).

**death2 4/10** (t0212-t0214). **The killer-card linger didn't land.** At ~0.8 s into the countdown the card is gone and the hotbar is back. Likely cause: `keepCard` needs `RV.kcard.Visible and state == "Countdown"` on the first frame `onKiller` goes false. The server calls `clearSpectate` before `setState("Countdown")` (MatchCore.playRound). If SpectateTarget clears even one frame while the state is still RoundEnd, the card hides, and the `Visible` check stops it ever coming back.
1. Latch it instead: when `onKiller` drops, set `RV.kcardUntil`, and keep the card while `os.clock() < kcardUntil and state ~= "Live"` (no Visible / Countdown check).
2. Exit: a hard cut → slide out right 0.3 s (t0214, gone).

**results 7/10** (t0142)
1. Play Again still relabels to "Searching..." → go straight to the teleport dots.

## Top 8 by visible impact
1. death2: fix the killer-card latch so the 1.5 s linger actually shows (t0212), then slide it out.
2. death: red wash 1.5 s + red HP + direction arrow (t0206).
3. kill: hold "Eliminated X" until the countdown (t0118/t0120).
4. death: ≥4 s kill-cam before RoundEnd ends.
5. kill: freeze the live clock during RoundEnd, tenths only in the countdown.
6. vote: wash only your tile, "[%]" label, centre heads, winner glides to the centre (t0030/t0032).
7. found: one continuous screen into Teleporting, with the tip bar.
8. matchpoint: Switch Weapons 0.4 s after the ribbon.
