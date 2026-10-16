# Hub (command deck) + lobby-wide olive: fresh-eyes review (2026-10-16 overnight)

Reviewer: a fresh agent (not the builder). `Tacticals_rebuild.rbxl` (studio 8ef4e21a) only; nothing saved; no fix script needed.

## What I looked at
- Edit captures from the spawn disc toward each gate, a wide view, the disc and the ceiling: `out/polish/hub/rv_*.png`
  (`tools/polish_hub_capture.py rv ...`), plus the Duels top landing (`rv_landing.png`, `rv_landing2.png`).
- `fix/check_polish_hub.lua`: **0 clips** (45 visible new parts; the 8 hull-only probe overlaps are the 174-stud merged
  `H_WallLights__neon_lamp`, no ray hit), support 0 bad, all hooks present (1 SpawnLocation, fall-catch lands on the disc at 0.52,
  QueuePad 6, ExfilBarrier 1, RoomLight 43 all with Room, LobbySpin 4, LobbyScreen 10, sign texts, AssetCheck 4/4), budget 0 new
  lights / emitters / collidable / queryable, 152 olive parts with 0 on another room's recolour, 9 walk routes clear.
- Play walk (character_navigation): Duels hall -> top landing -> disc, Duels hall centre-line -> disc in one leg. Console in Play:
  the known baseline only (MatchmakingManager MemoryStore error, UIBlox FoundationProvider warnings, AssetCheck 1/1154 texture).
- Colour, measured with `tools/part_pixels.py` on `rv_toN.png`: hub bands render 83,89,51 .. 105,113,59 (G/R 1.07-1.08, a true
  olive, target 1.13); walls 88,85,75 (B-R -13, warm grey); the disc centre 142,159,88 is the brightest olive (hero, as intended).

## Verdict: logically sound, no clear bugs
Nothing blocks, clips or floats; hooks and console are at baseline.

## The "Path Blocked" long walk (Duels hall -> spawn): not an obstruction
- Reproduced twice from (-106, 16, 16): character_navigation stops at **(-96.8, 19.3, 10.4)** and reports Path Blocked. That point is
  in the Duels hall, pressed against the door wall 5 studs north of the doorway.
- The doorway is **10.8 wide** (rays at y 17/19/21, x -95.5 .. -90: jambs at z +-5.4), nothing collidable stands in it, and
  `Path.Blocked` fired **0 times** in 12 s on the 32-waypoint hall -> disc path (and on both legs), so nothing moves into the path.
- The server path from the hall is a **Success** (32 waypoints, 127 studs). It does not take the stairs: waypoint 9 is a **Jump**
  over the top-landing railing (rail top ~3.5 above the landing; JumpHeight 7.2 clears it) and a 12-stud drop onto the y 4 landing.
  With `AgentCanJump = false` the same request is **NoPath** (landing -> riser foot needs that drop; the stairs run round the
  outside and the planner never prefers them).
- **The same 108-stud trip from the hall centre-line (-104, 16, 0) succeeds in one call.** So it is not pathfinder range either:
  starting diagonally from z 16 the walker cuts the corner, pins on the door jamb, makes no progress and the tool calls that
  "Path Blocked".
- The railing holds: walking a character into it at z 0 / -6 stops at x -85.3 (no walk-through gap).
- Rule for Play walks: start long legs square to a doorway (or split at the door). Optional for Edward: a NavigationModifier /
  PathfindingModifier over the top-landing rail would stop NPC pathing from planning the jump-and-drop; players are unaffected.

## Taste notes (no change made)
1. From the disc at eye height the **hologram rings (`FX.Hologram` HoloRing1) fill ~30% of the frame** (780 of 2,560 sampled pixels in
   `rv_toN`): the cream arcs sweep across every gate view. Raise or shrink the ring set so the gate signs read first.
2. Olive Neon (`H_SpawnDisc__neon_olive`, `H_FloorLines__neon_olive`, part 84,88,48) renders 93,104,23 .. 88,98,39: blue at ~0.25-0.4
   of red, so it reads yellow-green beside the khaki bands. B 56-60 in the part colour would bring it to the band hue.
3. The cream floor lines (`H_FloorLines__neon_cream`) render only 64,72,77 in Edit (lit by nothing); judge them in Play before
   brightening.
4. The EXFIL / TRAINING floor stencil reads upside down from the NE wide view; it reads right from the disc, which is where it matters.
