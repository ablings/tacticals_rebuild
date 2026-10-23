# m12 grade C: interactivity and feel

**Moved away from RIVALS: no.** I judged the code at 1x live, since `slow()` only stretches Studio.

**m11 fixes, checked**
- **Arc: landed.** The holder is a square, 0.42 of the screen height, centred on screen. It rotates by `atan2(rel.X, -rel.Z)`, so a killer behind you puts the arc at the bottom, pointing down. It carries 13 segments (-36..36 deg in 6 deg steps), each tangent to a 0.168 H ring, with the point on top. `setArc(fadeT)` fades it with the vignette: full for 2/3 of the hold, then 0.5 s to clear. When no root is found, `setArc(1)` runs in the same frame, so it doesn't flicker. In m12_death it draws at about 233x79 px on the 1920 canvas, at radius 0.17 H. RIVALS t0206 is about 264x90 at 0.18 H, so the size is close.
- **Own health reads 0: correct live, not proven in the capture.** `current()` returns 0/100 for 1.5 s after `Alive` goes false, so the fill turns red and the pale damage chunk drains, which reads well. m12_death still shows **150**. The 1.5 s in HealthBarController is not wrapped in `slow()`, but the vignette is (slow(1.5) ≈ 9 s in Studio), so the capture lands after the bar has already switched to the killer's health. Live, both last 1.5 s and match.
- **endElim token guard: landed, but it leaves a hole.** The 0.32 s hide now checks `my`. The 0.3 s `TextTransparency → 1` tweens are never cancelled, though. A kill inside that window sets transparency to 0, and the running tween writes it back to 1, leaving the line Visible but invisible. The 0.4 s fade in the slow(4) path has the same problem. Keep the tweens and call `:Cancel()` on them in `showEliminated`.

**playmenu 8, searching 8, loadout 7, countdown 8, live 8, kill 8, matchpoint 8, results 8.** No change.

**found 7/10** (t0020). The m11 items are untouched (MatchFoundGate did not change).
1. The tip snaps off at Teleporting → fade it over 0.3 s together with the stamp.
2. Status "Match found / 1v1" → "Teleporting / N" once Teleporting starts.

**vote 7/10** (t0032)
1. Winner "Warehouse" → "Warehouse  100%", with the % at 0.7x size.

**death 8/10** (t0206, up from 7)
1. Arc stroke is 0.022 x 0.42 H ≈ 10 px → ~20 px, tapering to ~8 px at the tail ends (t0206 is thick near the head).
2. The point is 0.09 x 0.42 H ≈ 41 px → ~85 px wide (t0206's head is about 1/3 of the arc's width).
3. Rotation still snaps every frame → lerp the angle (alpha ~0.25 per frame, shortest path) so a strafing killer doesn't make it jitter. `ar` (DuelHUD ~2318) is computed and never used, so drop it.

**death2 7/10** (t0212-t0214)
1. Still can't judge the killer-card exit: the shot is at +2.5 s, inside Studio's slowed hold. Recapture about 15 s into the countdown.

**victory 8/10.** The cutscene is settled. The handoff to results shows the plate and buttons cleanly, and I can't judge its timing from stills.

**Studio capture note:** HealthBarController's `1.5` should use the same Studio stretch (read `_UISlowMo`, or have DuelHUD publish `deathFlashLen`) so the 0 shows in captures.

## Top 8 by visible impact
1. Arc stroke ~20 px, tapered (t0206).
2. Arc point ~85 px (t0206).
3. Cancel the Eliminated fade tweens when a new kill lands.
4. found: "Teleporting / N" status (t0020).
5. found: fade the tip with the stamp (0.3 s).
6. vote: "100%" on the winner (t0032).
7. Lerp the arc angle.
8. Stretch the health-0 hold in Studio so captures prove it; recapture death2 at +15 s.

**Server/Studio (not scored):** RoundEnd is still 3 s vs RIVALS' ~4 s. The red wash `TweenInfo.new(1.5)` and the MatchEnd fallback `1.5` are still not `slow()`-wrapped, which only matters in Studio.
