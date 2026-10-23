# m14 grade C: interactivity and feel

**Did anything move away from RIVALS? No.** I read the durations from the code at 1x, as they run live. `slow()` only stretches them in Studio. The console stayed clean through the whole Studio match.

**m13 fixes, checked in code**
- **The arc's dt-based ease landed and is correct.** It now uses `d * (1 - exp(-17*dt))`. At 60 fps that gives 0.247 per frame, the same feel as the old 0.25, and it now behaves the same at 240 fps. It still takes the shortest way round.
- **The arc snap (RV.arcSnap) landed and is correct.** The Alive handler sets it. RenderStepped uses it up only on the first frame that has both a resolved killer root and a camera. If the kill event arrives late, the snap stays armed and the arc stays hidden (`setArc(1)`) until then. So each death opens pointing at its own killer, as in t0206, with no swing over from the last killer. m14_death shows the head now big and seated on the arc.
- **The endElim fade can be cancelled.** It landed, with one narrow leftover. `RV.endElim` now stores its 0.3 s tweens in `RV.elimFade`, and `showEliminated` cancels them. The leftover: endElim overwrites `RV.elimFade` without first cancelling what is already there. Suppose the 4 s hold's 0.4 s fade is running when the countdown calls endElim, and a kill lands in the next 0.3 s. That kill cancels only endElim's tweens. The orphaned 0.4 s tween keeps fading the new line. This can only happen in a window of under 0.1 s, so it is cosmetic.
- **The vote total counts each voter once.** It landed and is correct. The `voters` set de-duplicates by UserId, and your pending `_MyVote` adds you once. Each tile drops you from tiles you have left. So a 1v1 vote change now reads 100 % / 50 % straight away, with no 67 % round-trip blip (t0028 "Arena [100%]").

**playmenu 8, searching 8, loadout 7, countdown 8, live 8, kill 8.5, matchpoint 8, results 8, victory 8.** No change in feel (kill is up 0.5 for the cancellable endElim).

**found 8/10** (t0020)
1. Status "Match found / 1v1" → "Teleporting / N" once `MM_Status` = Teleporting. MatchFoundGate still fades the stamp out instead of changing its text. Carried over 2 rounds.

**vote 9/10** (t0028, up from 8). Nothing left on feel.

**death 9/10** (t0206, up from 8.5)
1. Arc head: an upright ▲, about 66 px wide at 1920 → RIVALS' shark-fin head, about 85 px, leaning left (the trailing side), its base sitting on the stroke.
2. Remove the unused `local ar` from the RenderStepped loop. It is computed every frame and never read.

**death2 7/10** (t0212-t0214)
1. I still can't judge the killer-card exit. The +2.5 s shot falls inside Studio's slowed hold. Recapture at about +15 s.

**kill 8.5/10**
1. In `RV.endElim`, cancel any existing `RV.elimFade` before replacing it: `if RV.elimFade then for _, tw in RV.elimFade do tw:Cancel() end end`. This closes the orphaned-tween window.

## Top 8 by visible impact
1. found: "Teleporting / N" status (t0020).
2. Arc head: a larger fin that leans left (t0206).
3. Recapture death2 at +15 s to judge the killer-card exit (t0212-t0214).
4. endElim cancels the old `RV.elimFade` before overwriting it.
5. Drop the unused `ar` from the arc loop.
6. (No further feel fixes: vote, the arc ease and the arc snap are all settled as of m14.)

**Server/Studio (not scored):** RoundEnd is still 3 s against RIVALS' ~4 s. Two Studio-only gaps are unchanged: the red wash `TweenInfo.new(1.5)` and the MatchEnd fallback `1.5` are not wrapped in `slow()`.
