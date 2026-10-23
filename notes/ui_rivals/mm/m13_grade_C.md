# m13 grade C: interactivity and feel

**Moved away from RIVALS: no.** Durations are read from the code at 1x live (`slow()` and HealthBarController's `_UISlowMo` only stretch Studio).

**m12 fixes, checked**
- **Arc eases toward the killer: landed, with two gaps.** `arrow.Rotation += d * 0.25` takes the shortest way round, so a strafing killer no longer makes it jitter. (a) The 0.25 is per frame, so the ease is 4x faster at 240 fps than at 60 (RIVALS players run 221-241 fps, t0028/t0032). (b) `arrow.Rotation` is never reset, so on your next death the arc starts where the last killer was and swings up to 180 deg over ~0.15 s. RIVALS t0206 shows the arc already pointing at the killer. `ar` is still computed and unused.
- **Eliminated fade cancels (RV.elimFade): landed for the 4 s path.** The cancel runs before `TextTransparency = 0`, and the 0.45 s hide is token-guarded. `RV.endElim`'s 0.3 s tweens are still not stored, so a kill inside that window still ends up Visible but invisible. That's unlikely during a countdown, but it's the same hole.
- **Vote [N%]: landed and matches t0028** ("Arena [100%]", same size as the name, during voting only). The chosen card shows the bare name, as RIVALS does in t0032, so my m12 ask for "100%" on the winner card was wrong. The voting grid isn't in the capture, so this is judged from code.
- **Match found tip fade: landed.** The bubble and its text fade over 0.3 s with the stamp, and they reset to opaque if the status returns.
- **Own health 0: now proven.** m13_death reads "0" with an empty bar, matching t0206.

**playmenu 8, searching 8, loadout 7, countdown 8, live 8, kill 8, matchpoint 8, results 8, victory 8.** No change.

**found 8/10** (t0020, up from 7)
1. Status "Match found / 1v1" → "Teleporting / N" once Teleporting starts. Carried over.

**vote 8/10** (t0028, up from 7)
1. Moving your vote double-counts you until the server catches up: `total += 1` while the server still lists you on the old map, so 1v1 shows 67%, not 100%, for one round trip. Skip the +1 when any `votes[id]` already holds your UserId.

**death 8.5/10** (t0206, up from 8)
1. Snap the arc on the first frame of each death: set `RV.arcSnap = true` in the Alive handler and assign `Rotation = deg(ang)` once before easing.
2. Make the ease frame-rate independent: `alpha = 1 - 0.75^(dt*60)`, with dt from RenderStepped.
3. Arc head: the ▲ floats about 4 px above the arc and is about 38 px wide → seat it on the arc, about 85 px wide and leaning left like t0206's shark-fin head. Stroke is about 15 px → about 24 px at the centre.

**death2 7/10** (t0212-t0214)
1. The killer-card exit still can't be judged: +2.5 s falls inside Studio's slowed hold. Recapture about 15 s in.

**kill 8/10**
1. Store `RV.endElim`'s tweens in `RV.elimFade` too, so `showEliminated` cancels them.

## Top 8 by visible impact
1. Arc head: big, seated, leaning (t0206).
2. Snap the arc to the new killer on each death (t0206).
3. Frame-rate-independent arc ease.
4. found: "Teleporting / N" status (t0020).
5. Arc stroke about 24 px at the centre (t0206).
6. vote: no transient 67% when changing your vote (t0028).
7. Cancel `endElim`'s tweens via `RV.elimFade`.
8. Recapture death2 at +15 s to judge the killer-card exit; drop the unused `ar`.

**Server/Studio (not scored):** RoundEnd is still 3 s vs RIVALS' ~4 s. The red wash `TweenInfo.new(1.5)` and the MatchEnd fallback `1.5` are still not `slow()`-wrapped, which only matters in Studio. The console stayed clean.
