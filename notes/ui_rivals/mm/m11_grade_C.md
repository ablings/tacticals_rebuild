# m11 grade C: interactivity and feel

**Moved away from RIVALS: no.** All three m10 fixes landed. The code was judged at 1x live (`slow()` only stretches Studio).

**m10 fixes, checked**
- **Chevron: fixed.** RenderStepped now re-resolves `RV.killerModel` from `lastDeath.killer` (or `SpectateTarget`) every frame while it is nil or unparented. If no root is found it sets transparency 1 and stays armed, so it doesn't turn itself off. m11_death draws it at (625, 247) of 1268x713, which is ~(946, 374) on the 1920 canvas. That is right on the 0.16 ring, pointing up at the killer dead ahead (t0206).
- **MatchEnd fallback: fixed.** The `state == "MatchEnd" and not resultsShown` branch now sits before `state ~= "RoundEnd"`. It runs `showResults(nil)` 1.5 s later if no summary has come.
- **Tip at Teleporting: fixed.** `tipLabel.Parent.Visible = false` runs on Teleporting, and the bar comes back if the status returns to Found.

**playmenu 8, searching 8, loadout 7, countdown 8, live 8, kill 8, results 8.** No change.

**found 7/10** (t0020)
1. The tip snaps off while the stamp, sub and backdrop fade over 0.3 s. Tween the tip Frame's BackgroundTransparency and the label's TextTransparency to 1 over the same 0.3 s, then hide it.
2. Status text "Match found / 1v1" → "Teleporting / N" once Teleporting starts (t0020). The stamp fades out at the moment RIVALS shows its status line.

**vote 7/10** (t0032)
1. Winner label "Warehouse" → "Warehouse  100%", with the % at 0.7x size after the name.

**death 7/10** (t0206, up from 6)
1. Chevron: the "▲" glyph is 0.08x0.12 of the screen → a ~270x90 px curved arc segment tangent to the 0.16 ring (t0206). The glyph reads as a cursor, not a direction ring.
2. The HP bar still reads 150 at the death moment (m11_death bottom left). Tween the fill to 0 over ~0.15 s and tint it red under the vignette (t0206).
3. The chevron's position never eases. It snaps every frame, which is fine while the killer is still. Lerp the angle (alpha ~0.25/frame) so it doesn't jitter when the killer strafes.

**death2 7/10** (t0212-t0214)
1. Still can't judge the exit. In Studio `keepCard` holds for slow(2.0) ≈ 12 s, so at +2.5 s the card is correctly still up (m11_death2). Recapture at Countdown + 2.5 s × 6 ≈ 15 s to show t0214's slide-out.

**matchpoint 8/10.** Ribbon, dimmed WON and Switch Weapons all behave.

**victory: not captured.**

**Still open from m10:** `RV.endElim()`'s `task.delay(0.32, ...)` hide has no `elimToken` guard. A kill that lands within 0.32 s of a countdown or match end gets its "Eliminated X" hidden at once. Capture `local my = elimToken` and check it in the delay.

## Top 8 by visible impact
1. Chevron glyph → ~270x90 curved arc on the ring (t0206).
2. HP fill to 0 / red at death (t0206).
3. found: "Teleporting / N" status at Teleporting (t0020).
4. found: fade the tip with the stamp (0.3 s) instead of snapping it off.
5. Token-guard `endElim`'s 0.32 s hide.
6. vote: "100%" on the winner (t0032).
7. Smooth the chevron angle (lerp) for a moving killer.
8. death2 recapture at +15 s Studio to prove the killer-card exit (t0214).

**Server/Studio notes (not scored):** RoundEnd is still 3 s vs RIVALS' ~4 s (t0206-t0210). The red wash tween (`TweenInfo.new(1.5)`) and the MatchEnd fallback delay (1.5) are not wrapped in `slow()`, so in Studio the wash ends long before the vignette. Live they match.
