# Overnight polish: Training touch-up (quadrant codes, grid read, bin marks)

Done 2026-10-16 night, only in `Tacticals_rebuild.rbxl` (studio 8ef4e21a). **Not saved** (the lead saves). RIVALS (2e616d06) only
read (two captures of its shooting range). No computer use, no imports, no new asset ids.

Edward's brief: Training keeps his standard (the grid-tile range, Parts-first, RIVALS-level content). A **touch-up only**: clinical,
cool, even light; quadrants A-D colour-coded in the palette with floor markings, wall bands and big letters; check the white grid
doesn't blow out and the lines stay readable; signage legible; bins/crates read right. No gameplay moves.

| What | Path |
|---|---|
| Polish (idempotent, UNDO flag) | `fix/polish_training.lua` -> `python tools/run_luau.py fix/polish_training.lua [UNDO]` |
| Check (read-only) | `fix/check_polish_training.lua` (+ the existing `fix/check_training.lua`) |
| Captures (Training lights forced on, restored) | `python tools/polish_training_capture.py <prefix> [names]` -> `out/polish/training/<prefix>_*.png` |
| Sheet | `python tools/polish_training_sheet.py` -> **`out/polish/training/sheet.jpg`** |

## Quadrants (arena x/z -128..128 round the plaza; north = +z)
| | Where | Zone | Colour |
|---|---|---|---|
| A | NW (x<0, z>0) | block maze | olive 138,156,74 |
| B | NE (x>0, z>0) | towers + overwatch | cream 236,232,218 |
| C | SE (x>0, z<0) | distance field | sage 167,173,152 |
| D | SW (x<0, z<0) | cover course | warm grey 150,146,136 (letters 200,196,186: the paler warm grey vanished on the 206 walls) |
| gallery | x>128 | firing range | near-black band (34,36,32) |

## What changed
1. **Wall bands per quadrant.** The perimeter band (olive 111,114,57 Concrete, rendered lime 87,114,69) is hidden and rebuilt per
   quadrant between the four 24 x 24 corner bastions (the old band ran on through them), SmoothPlastic in the quadrant colour with
   0.3 near-black edge strips 0.06 proud, so cream / sage / warm grey still read on near-white walls. The bastion bands (one per
   corner) and the six tower bands (all three towers stand in B) take their quadrant's colour with the same near-black edges.
   The 3 gallery bands are near-black.
2. **Big letters**: 8 near-black plates 16 x 18 at y 631 (B's east wall at 636), two per quadrant on its perimeter walls, letter in
   the quadrant colour + SECTOR x + zone name. Placed by a ray scan: the whole plate is visible from the plaza corner of that
   quadrant (B's east plate from the east boulevard; NE towers hide the rest of that wall).
3. **Floor plates**: two 12 x 12 plates at each plaza exit (28 out, 13 off the boulevard axis), the quadrant on that side, letter +
   SECTOR x ZONE in near-black, reading upright as you walk out of the plaza. The diagonals off the plaza corners are full of cover.
4. **Swap bins**: a near-black floor frame with a cream edge round each of the 9 bins and a WEAPON SWAP stencil on the side facing
   the plaza/arena centre. The bins are the same Blender crate kit and paint as the 24 cover crates, so they read as more cover.
   The two plaza bins (45 degrees, 3 studs inside the plaza edge line) get a slimmer frame inside the line.
5. **Grid read**: TX_overlay_grid copies (1,332 under Range2) 58 grey / T 0.45 -> 34 / T 0.32.
6. **Field distance boards** (25/50/75/100 on the east wall, a place_training leftover) ran into the band and the cream wall line:
   lowered 1.6 (603.1..605.7). Signs only.

141 new parts, **0 lights**, 0 collidable / queryable / touchable, all NotCover. Nothing under Training moved, renamed or
re-collided (the check asserts no CFrame/Size keys except the 4 boards).

## Measurements
- **Grid blowout (Play, plaza -> SE, `play_before_qC.jpg`)**: walls render L 202 median / 216 p95 (max 222), floor 171: **no
  clipping**. Edit captures read near-white only because the capture tool forces all 19 point lights on with no exposure
  adaptation; judge Training in Play (as training_extras_done.md already said). Before, the near-floor line contrast was ~10 levels
  (161 vs 171) and the wall lines ~28 (174 vs 202); after the grid change the lines read clearly at room distance (`play_after_*`).
- Edit render ratios (part_pixels): floor 214 -> 200,213,223, walls 206 -> 212,220,227, B-R +14..+41 under the forced edit
  lights; neutral in Play. Tile greys left as Edward approved them.

## Logic checks
- `check_polish_training`: **0 clips** (141 visible; one note: a B bastion ring edge runs into a truss as the old band already did),
  support 0 bad, letter plates 8/8 fully visible from their plaza corner, floor plates all on their quadrant's side, hooks:
  EnemySpots 44 (16 gallery), Arrivals 16, TrainingArrive (0,603.3,0), Dummy template, Extras JumpPads 72 / Tightropes 24 /
  SwapBins 9 / DpsDummies 8 / Bullseyes 120, bins at their pivots, Range2 413 parts (161 collidable), budget 0/0/0/0.
- `check_training`: **ALL OK** (its "above 540 outside Training" lines now list the Polish.Training parts: informational; the
  TrainingManager rule is about players, not parts. Its 12 gallery-lane lines blocked by a fill MidBlock predate this pass).
- **Play**: walked into the ExfilBarrier from the hangar -> cutscene -> `InTraining` true, landed on the arrival ring (12.9,603.1,5.4);
  walked all four quadrants with character_navigation (A (-38,54), plaza exit, B (84,46), C (60,-64), D (-46,-34)): all Success.
  35 dummies alive; killed one -> 34 -> **35 again after 4.5 s**. At the SW bin, F + 7 -> **Sniper in hand** (Loadout Sniper,
  TrialWeapon Sniper). Console: baseline only (MatchmakingManager MemoryStore, UIBlox warnings, AssetCheck 1/1154).
- UNDO round trip: restored 1,354 instances, check_training ALL OK on the undone state, re-applied identically.

## For Edward
- B = cream is the weakest of the four on white walls; it reads through its near-black edges and the black letter plates. If you
  want a louder B, dark olive 107,122,58 would do it (one value in `QUAD`).
- Letters sit at 631 so they read from the floor and the +24 roof decks; RIVALS' range has no sector signs, this is our wayfinding.
