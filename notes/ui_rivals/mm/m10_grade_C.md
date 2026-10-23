# m10 grade C: interactivity and feel

**Moved away from RIVALS: no.** All three m9 fixes landed. The chevron is still missing.

**m9 fixes, checked (code at 1x live)**
- **1790 error: fixed.** The Countdown branch now calls `RV.endElim()` (it returns early when `elimL` is hidden, then fades both lines over 0.3 s), and Victory/MatchEnd call it too. m10_matchpoint shows the RenderStepped callback now runs to the end: no "Eliminated Bot", WON dimmed, and Switch Weapons up. m10_results has no Eliminated overlap. That fits a clean console. I could only judge it from the shots, not from the log.
- **Vignette: fixed.** `fadeT = clamp(1 - remaining / (len/3))` holds GroupTransparency 0 for 1.0 s, then fades linearly over 0.5 s (t0206 → t0208). The chevron's TextTransparency follows the same fadeT.
- **Chosen map centred: fixed.** In m10_vote the tile's centre is (634, 356.5), the exact centre of 1268x713. The 0.4 s Quart glide is unchanged.

**playmenu 8, searching 8, loadout 7, countdown 8, live 8, kill 8.** No change.

**found 7/10** (t0020)
1. "Match found / 1v1" → "Teleporting / N", plus a tip bar at y 1000-1052.

**vote 7/10** (t0032, up from 6)
1. Winner label "Practice Range" → "Practice Range  100%", in a smaller 0.7x weight after the name.

**matchpoint 8/10** (t0122, up from 5)
1. Nothing broken. Switch Weapons pops in 0.4 s after the ribbon, as before.

**death 6/10** (t0206)
1. **The chevron still never draws** (none in m10_death, with the killer dead ahead). Likely cause: the `Alive` attribute handler reads `lastDeath.killer`, but `lastDeath` is set by the death remote (line 255), which can arrive after `Alive` replicates. Then `killerModel` is nil or stale, and `arrow.Visible = false`. Fix: resolve `RV.killerModel` again in RenderStepped while `flash` is on and `killerModel` is nil (or also set it from the death event). Then it lands at ~(960, 367).
2. Chevron "▲" glyph → a ~270x90 px curved arc on the 0.16 ring, tangent to it (t0206).
3. HP bar still reads 150 at the death moment. Set the fill to 0, red under the vignette (t0206).

**death2 7/10** (t0212-t0214)
1. The keep/exit code runs now, so the 2.0 s hold is real. Recapture at Countdown + 2.5 s × 6 to show the slide-out (t0214: card gone).

**results 8/10** (t0140)
1. Code finding: in the state branch, `elseif state ~= "RoundEnd"` comes before `elseif state == "MatchEnd" and not resultsShown`. That makes the fallback results card unreachable, so if the summary never arrives, no results show. Move the MatchEnd branch above it.

**victory: not captured.**

## Top 8 by visible impact
1. Make the killer chevron draw: resolve the killer model lazily, not only at the `Alive` change (t0206).
2. Chevron as a ~270x90 curved arc (t0206).
3. HP fill to 0 / red at death (t0206).
4. Make the MatchEnd fallback results reachable (branch order).
5. death2 recapture to prove the killer-card exit (t0214).
6. vote: "100%" on the winner (t0032).
7. found: "Teleporting" + tip bar (t0020).
8. `endElim`'s 0.32 s hide isn't token-guarded. Guard it so a kill landing inside that window doesn't get hidden.

**Server/Studio notes (not scored):** RoundEnd is 3 s vs RIVALS' ~4 s after a death (t0206-t0210). The red wash tween (1.5 s) is still not wrapped in `slow()`, so in Studio it ends ~7.5 s before the vignette. Live they match.
