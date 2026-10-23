# m8 grade C: interactivity and feel

**Moved away from RIVALS:** nothing.

**m7 fixes (24c45de), checked in code:**
- **Death vignette + chevron: landed, with three gaps.** `RV.deathFlashUntil = now + 1.5`, four edge gradient strips (0.35 → 1), and a "▲" on a 0.16-height ring aimed with `atan2(rel.X, -rel.Z)`. The aim maths is right. The gaps: (a) the vignette is switched off with `Visible`, so at 1.5 s it cuts while the full-screen wash is still fading; (b) the chevron is a font glyph about 77 px, but RIVALS t0206 uses a thick curved red arc, about 270 px wide at 1920, with a head on its leading end; (c) RIVALS' red reaches about 35 % in from each side, but our side strips cover 14 %. The capture lands after the 1.5 s, so none of this shows in m8_death.
- **Round card fade at 2 s with no ribbon: landed.** It checks that the state is still Countdown with no ribbon, then fades over 0.4 s. A ribbon round keeps the dimmed card until Live (t0122). The death2 shot is already in Live (1:26), so it can't show this.
- **Killer card hold 2.0 s: landed.** `kcSince` resets on the state change, then there's a 0.3 s slide-out, so the card is gone by 2.3 s. RIVALS: still up at t0212 and gone by t0214. That's correct.

**playmenu 8, searching 8, countdown 8, live 8, loadout 7, results 7.** No change. The carried fixes are below.

**found 7/10** (t0020)
1. "Match found / 1v1" → "Teleporting / N" in place, plus the tip bar at y 1000-1052.

**vote 6/10** (t0030/t0032)
1. Label "Warehouse" → "Warehouse [100%]".
2. The winning tile glides to the centre over 0.4 s.

**kill 8/10** (t0054, t0118)
1. The capture catches the Eliminated line in its fade again. Capture at RoundEnd + 1 s.

**matchpoint 8/10** (t0122, t0214). The ribbon, dimmed WON, the pill and Switch Weapons are all right.
1. Feed pill: end it with 1.5 s of the countdown left, not at Live (t0216).

**death 6/10** (t0206)
1. Vignette exit: `Visible` cut at 1.5 s → tween the strips' transparency to 1 over the last 0.5 s, timed with the wash.
2. Chevron: a 77 px "▲" glyph → a curved red arc about 270x90 px with a head on its leading end, on a 170 px ring. It tangents the ring and rotates with the angle (t0206).
3. Side strips: 0.14 → 0.30 width, and HP fill bone → red while the vignette is up (t0206 bar is red).

**death2 7/10** (t0212-t0214)
1. The shot is in Live, so it proves neither the 2.0 s card hold nor the round card fade. Capture at Countdown + 1.0 s (card + LOST + Switch Weapons, t0212) and again at + 2.5 s (only the pill, t0214).

**victory: can't judge.** The cutscene was missed again. Capture at MatchEnd + 0.5 s.

## Top 8 by visible impact
1. Death chevron → a curved arc about 270 px wide (t0206).
2. Vignette fades out instead of cutting at 1.5 s.
3. Wider side vignette (0.30) + red HP fill (t0206).
4. vote: [%] label + winner glide (t0030/t0032).
5. found: "Teleporting" relabel + tip bar (t0020).
6. death2 captures at Countdown + 1.0 / + 2.5 s, to prove the m8 hold and fade.
7. Feed pill ends with 1.5 s left (t0216).
8. loadout: active ring pop, 1.08 → 1 over 0.15 s (t0036).

**Server notes (not scored):** RoundEnd is 3 s, but RIVALS holds about 4 s after a death (t0206-t0210). Capture lag still hides the 0-1.5 s death window, so the new vignette and chevron have never been seen in a shot. A capture at Alive=false + 0.3 s would show them.
