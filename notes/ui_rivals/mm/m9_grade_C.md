# m9 grade C: interactivity and feel

**Moved away from RIVALS: yes. The m9 "Eliminated ends at the countdown" code throws every frame in the Countdown.**
The Studio console (match_place_ref) repeats `DuelHUD:1790: attempt to index nil with 'Visible'`, which is `if elimL.Visible` in the
Countdown branch of the HUD's RenderStepped. The error aborts the rest of that callback, and `lastState = state` never runs, so it
fires again on every frame. You can see the damage in m9_matchpoint (compare m8_matchpoint):
- "Eliminated Bot" is still up under MATCH POINT;
- WON isn't dimmed (`dimRoundCard` never runs);
- Switch Weapons is missing;
- the killer-card keep/exit logic below it never runs either.

The working tree already moves this into `RV.endElim()` and also calls it on Victory/MatchEnd, but that change is uncommitted. Verify in m10 that the console is clean.

**m8 fixes, checked in code (at 1x live)**
- **Vignette fade-out: half landed.** It's a CanvasGroup now, so the strips fade together. But `GroupTransparency = p^2` starts fading from the very first frame. RIVALS holds the red fully at t0206 and has it gone by t0208. The chevron isn't in the CanvasGroup (it's parented to `dgui`), so at 1.5 s it still cuts at full opacity. Also, the red wash's 1.5 s tween isn't wrapped in `slow()`, so in Studio it ends ~8 s before the vignette (Studio only).
- **Bigger chevron: not RIVALS yet.** It's still the "▲" glyph, now in a 0.08x0.12 box (~154x130 px, the glyph ~100 px). RIVALS t0206 uses a ~270x90 curved arc. m9_death has the killer dead ahead, so the chevron should sit at about (960, 367) at 1920. Nothing is drawn there. Check that `botModel(k)` returns the bot.
- **Eliminated at the countdown: broken** (see above).
- **Killer card hold: can't credit.** m9_death2 (SUDDEN DEATH + LOST + card) looks like t0212. But during that Countdown the keep/exit code never ran (the 1790 error), so the card stays up because it's frozen, not because of the 2.0 s timer.

**playmenu 8, searching 8, loadout 7, countdown 8, live 8, kill 8.** No change.

**found 7/10** (t0020)
1. "Match found / 1v1" → "Teleporting / N", plus a tip bar at y 1000-1052.

**vote 6/10** (t0030/t0032)
1. "Warehouse" → "Warehouse [100%]"; the winning tile glides to the centre over 0.4 s.

**matchpoint 5/10** (t0122, down from 8)
1. Fix the 1790 error (endElim). Then Eliminated fades within 0.3 s, WON dims and Switch Weapons pops in 0.4 s after the ribbon.

**death 6/10** (t0206)
1. Vignette curve: `p^2` from 0 → hold `GroupTransparency` 0 for 1.0 s, then go linearly to 1 over the last 0.5 s.
2. Put KillerArrow inside the `vig` CanvasGroup so it fades with it.
3. Chevron → a curved arc image ~270x90 px on the 0.16 ring, tangent to it (t0206). Also make it draw at all.

**death2 6/10** (t0212-t0214)
1. Once the error is fixed, recapture at Countdown + 1 s and + 2.5 s × 6 slow-mo. That shows whether the hold ends by itself and the exit slide runs (t0214: gone).

**results 7/10** (t0140)
1. "Eliminated Bot / HEADSHOT · KILL" sits over the name plate (y 500-550). In Studio slow(4) = 24 s; live it's 4 s. Hide it on Victory/MatchEnd (in the working tree; verify).

**victory: not captured.**

## Top 8 by visible impact
1. Fix `DuelHUD:1790` (commit `RV.endElim`): it restores the dimmed card, Switch Weapons and the Eliminated fade (t0122).
2. Draw the chevron at all; it's missing in m9_death.
3. Chevron as a ~270x90 curved arc (t0206).
4. Vignette holds 1.0 s, then fades 0.5 s; chevron fades inside the group (t0206 → t0208).
5. End Eliminated on Victory/MatchEnd (results overlap).
6. death2 recapture to prove the 2.0 s killer-card hold and exit (t0212/t0214).
7. vote: [%] label + winner glide (t0030/t0032).
8. found: "Teleporting" + tip bar (t0020); HP fill red while the vignette is up (t0206).

**Server notes (not scored):** RoundEnd 3 s vs RIVALS ~4 s after a death (t0206-t0210). In Studio, wrap the red wash tween in `slow()` too, so the shots match the live timing.
