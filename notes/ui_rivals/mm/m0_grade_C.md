# m0 grade C: interactivity and feel

This is the first round, so there are no earlier fixes to check. Sources: captures m0_*, killcard f/t0016-t0214, and the code listed in the brief.

**playmenu 8/10.** Hover/press matches RIVALS: wash 0.6, 2 px ring, 0.97 scale, 0.93 press bounce. Nothing to fix.

**searching 8/10.** Clock, dot cycle and X match t0018. Nothing to fix.

**found 4/10**
1. MatchFoundGate: opaque "MATCH FOUND" stamp (Back pop 1.25 to 1) → RIVALS has no stamp (t0018 → t0020). Show the Teleporting screen straight away: three white dots ~56 px at screen centre pulsing in sequence, the world blurred and dark behind (not an opaque gradient), "Teleporting" plus a counter right-aligned at (1880, 960), Bold ~48. Keep the tip bar at the bottom left.

**vote 6/10**
1. Timer → add RIVALS' hourglass and turn the digits and hourglass red when it reaches 0.0 (t0030 white 1.5 → t0032 red 0.0). Today the timer only pulses.
2. Your vote → wash the whole tile pale (RIVALS t0026-t0030: the voted tile goes light, voters' heads sit ~70 px in the tile centre, and the name reads "Arena [100%]"). Today you get small heads at the top left and a count at the top right.
3. Winner move → end centred on the screen (t0032: tile centre at 0.5 W, 0.5 H). Today it is +120 px below the row. Can't judge the exact landing from one still.

**loadout 6/10**
1. Timer box "1.3" above the map bar → hide it. RIVALS shows no top bar and no timer during the pick (t0034-t0038); the score bar only comes back at countdown (t0040).
2. Active slot: 3 px cream ring → 6 px pure-white ring on an 84 px square that pops (Back) when the step advances (t0034/t0036).

**countdown 8/10.** Tenths with hourglass, as in t0040. Nothing to fix.

**live 8/10.** The tick pulse in the last 5 s fits. Nothing to fix.

**kill 5/10**
1. MATCH POINT ribbon fires at RoundEnd together with ROUND WON → RIVALS shows WON alone for ~4 s (t0118, t0120), then brings the ribbon in at the countdown (t0122). Remove the `RV.showMatchPoint` call in the RoundEnd branch and keep only the Countdown one.
2. When the ribbon lands → fade the WON card to ~0.5 and dim the world ~25 % (t0122).
3. Switch Weapons pops in the same frame as the ribbon. RIVALS staggers them: card, then about 2 s later the button (t0056 → t0058). Delay its popIn by 0.4 s after the ribbon.

**death / death2 can't judge.** "death" was captured during the next countdown (SUDDEN DEATH, Switch Weapons showing, full HP, hotbar up). "death2" is already live at 1:26. Neither shows the death moment. Retake at the elimination frame and +2 s against t0206-t0210 (red hit wash, kill-cam on the killer, card in, hotbar gone). The code slides the card in from the right in 0.35 s Quart and hides the hotbar, which looks right.

**victory 4/10**
1. Code: letterbox bars, a 1.6× VICTORY slam, bass + fanfare, "FINAL KILL" → none of this is in RIVALS. RIVALS plays the last round's WON + Eliminated (t0134), then ~4 s of winner camera with no UI (t0136-t0138), then the card (t0140). Replace showVictory with a HUD-less winner shot of ~4 s.

**results 7/10**
1. Buttons: flat plates → add a 3 px white outline at rest (t0140 Play Again / Leave). RIVALS puts a lot of feel into the press state.
2. Play Again shows "Searching..." on the button → go straight to the Teleporting screen, as RIVALS does at t0142.

## Top 8 by visible impact
1. Kill: ribbon only at Countdown, WON shown alone first.
2. Victory: drop the letterbox/slam for a ~4 s HUD-less winner cam.
3. Found: replace the MATCH FOUND stamp with the three-dot Teleporting screen.
4. Loadout: hide the timer box during the pick.
5. Vote: red 0.0 + hourglass on the timer.
6. Vote: pale wash, centred heads and [%] on the voted tile.
7. Kill: fade WON to 0.5 and dim the world under the ribbon.
8. Loadout: 6 px white active-slot ring with a pop on each step.
