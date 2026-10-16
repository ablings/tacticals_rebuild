# Lap 1: fresh-reviewer Play-mode lap after the overlap fix (2026-10-15)

`Tacticals_rebuild.rbxl` only (studio 8ef4e21a-3525-484b-91af-79d7677aa213, game.Name checked). **Not saved** (the lead saves).
No computer use. The live "tacticals" studio, RIVALS and the replica were not touched. Own assets only. Play was stopped at the end.

## Files
| What | Path |
|---|---|
| Sheet (key findings, before/after) | `out/lap/lap_sheet.jpg` |
| Overlap-fix sheet, now with real after frames | `out/overlap/before_after.jpg` (12 eye-height `after_o*` frames, `python tools/overlap_capture.py after`) |
| Lap frames (Play, eye height, GUIs hidden) | `out/lap/<stop>.png` (102 stops, the stop lists are in `out/lap/stops_*.json`); after-fix frames are `fix_*.png` |
| Play capture driver | `tools/lap_capture.py <stops.json>`: needs Play running and the client helper `_G.lap` (see "How the lap was run") |
| Coplanar sweep (Play, client) | `tools/lap_zscan.lua`: rays through a 64x40 grid at every stop; flags first and second hits on the same plane (gap <= 0.012, same facing, different parts). Results: `out/lap/zscan_play.txt` (before, 62 pairs) and `zscan_play_after.txt` (after, 54) |
| Fixes (idempotent, UNDO) | `fix/lap_fix.lua` (new) + 3 new entries in `fix/overlap_fix.lua` + `fix/place_training.lua` (greys, bridges) + training scripts (trace removed) |
| Check outputs | `out/lap/check_{hub1,rooms2,rooms3,training}_lap.txt` |

## How the lap was run
- Play, one client. ScreenGuis disabled on the client only. A RenderStep binding at priority Last+10 holds a Scriptable camera
  (`_G.LAPCF`), because the game's camera controller resets the camera each frame. The character is anchored and pivoted to the
  eye position, and hidden through LocalTransparencyModifier.
- Probing: most kit meshes are **CanQuery off**, so plain rays pass through walls. During Play, every visible part was made
  queryable on the client only. Play changes are discarded when Play stops.
- `_G.pick(fx, fy)` casts a ray through a screen fraction and lists the hit stack. Used for every finding below.
- Training was entered through `Events.Training.Enter`, as the game does.

## Findings
Root-cause classes: **K-flush** (the kit authors decoration flush or coplanar), **K-gap** (kit coverage missing), **seam** (two kits
meet and neither owns the strip or plane), **survey** (placed from old or survey coordinates and not re-measured against the new
kit), **Studio-script** (a placement script measured the wrong face or hard-coded values), **old** (old geometry still visible),
**debug** (test leftovers), **rig/asset** (pre-existing model internals).

| # | Where | What | Class | Fix / recommendation |
|---|---|---|---|---|
| F1 | Hub **E wall above the tunnel** (x 88, z -11..11, y 52-68) and **N/S walls above the gates** (x -5.7..5.7, y 52-68) | Rectangular holes in the upper wall. Sky and the TimesSquare towers (the "cream box") show through. Seen from the hub floor (`h29`, `h26`, `h27`, `h17`, `o11`). | K-gap: `hub_kit.py` `build_long_wall` / `build_east` fill the gate and tunnel bay only up to y 52. `wall_zones` adds the cornice (52-58.4), the trim (58.4-59) and the top fill (59-68) only for the zones either side. The old `OverBig_NDoor/SDoor` / `U_WestWall` used to cover the gap and were hidden by place_hub1. | **Fixed** `lap_fix` L1: 18 infill Parts (back wall, chamfer wedge, cornice top, top trim, top fill and the missing 35.8 lip) with the neighbouring meshes' colour, material and variant; no collision. **Kit:** in the generator, run the bay infill to 68 with the same profile as `wall_zones` (call `wall_zones` with a `ymin` instead of hand-written boxes). |
| F2 | Hub N/S gate signs | SHOP text right of centre, ARMORY text left of centre (`h01`, `h02`). | Studio-script: `place_hub1.lua` hard-coded the overlays at the **old** signs' x -3.75, 8.5 wide; the new kit board is x -8..8. | **Fixed** L4: centred at x 0, 14.5 wide; the `place_hub1.lua` data was corrected too. |
| F3 | **Tunnel -> hangar threshold** x 104..105, z -13..13 | 1-stud-wide, 1-stud-deep trench across the whole tunnel, with one through-hole at z -7.25. It read as a saturated blue line (`e05`). | seam: Hub1's tunnel lining ends at x 104 and Rooms3's hangar floor starts at 105. Each kit assumed the other owned the portal strip. | **Fixed** L2: floor plate x 104..105, top 0.02 (walkable, collides). A floor-slot scan of every room (0.5-stud grid) found no other trench. **Kit:** one kit owns every threshold strip and closes the floor under its own portal. |
| F4 | Duels W gate, **DECK** sign | Cream plate flashing through the text (`d12`). | Studio-script on a K-flush kit: `D_Signs__label_cream` (the placeholder text plate) is on the board's front plane. place_rooms3 measured "the board face" and put SignText_Deck exactly on that plane (x -138.920). | **Fixed** L3: overlay +0.04 x. The other 9 SignText overlays were ray-tested: clear. |
| F5 | Top landing, **NPC_DuelsOfficer** | Right arm through the stair rail (`H_Stairs__trim_light`) (`d03`). | survey: the NPC stands at its original survey spot and the new rail was built through it. | **Fixed** L5: moved 0.8 toward the door axis (z 7.9 -> 7.1); GetPartsInPart now finds nothing. |
| F6 | Showroom (Kit-menu camera) | `SR_Signs__label_cream` and `SR_Stage__dark_metal` both at z 5.550 at the bottom of the frame. | K-flush (the label plate is authored on the stage face). | **Fixed** in `overlap_fix.lua`: `SR_Stage__dark_metal` z +0.03 (the label mesh also carries the header plate, so the stage moved instead). |
| F7 | Duels door, hub side (top landing) | Lintel soffit flicker: `H_DuelsDoor__trim_metal` and `H_WallW__wall_body` both at y 24.000 (718 px, the largest pair in the sweep). | K-flush. The overlap fix handled the jambs (z) but missed the soffit (y). | **Fixed** in `overlap_fix.lua`: trim y -0.04. |
| F8 | Duels floor | `D_Lines__neon_cream` vs `neon_olive` 0.001 apart where the lines cross; cream vs `D_Pads__plate_metal` tops. | K-flush (both line meshes authored at one height; the overlap fix lifted both by the same +0.03). | **Fixed**: cream another +0.03 (Duels axis max step still 0.08, OK). |
| F9 | Training roof decks | Bridge tops (624.00) coplanar with the block tops they rest 0.5 on. | Studio-script (layout puts bridge tops = ROOF). | **Fixed** in `place_training.lua`: bridges -0.04 (top 623.96; the ends sit inside the blocks). |
| F10 | Training plaza | `Workspace._UVTest` x3: the grid-offset test cubes from step 2 floating at y 612-616 (`t02`). | debug | **Fixed** L6: moved to `ServerStorage._RebuildRemoved` (attribute `Lap_OrigParent`). |
| R1 | Hangar / helipad, looking east | TimesSquare backdrop towers (cream / black blocks) rise right behind the pad and break "floating sky base" (`e04`, `e05`). They were also what showed through F1. | old | **Recommend** (Edward to decide): hide `LobbyMap.TimesSquare` (29 Parts) UNDO-ably. Only `CityBillboard` FX use it, nothing gameplay. Otherwise lower or move it out of the pad's view cone. |
| R2 | All floors | Inlays 0.01-0.02 above their neighbours: Duels `D_Floor` border vs insert (382 px), hub, hangar and corridors (see overlap_fix "Still needs a kit change"). The corrugated walkway stripes are the material, not z-fighting: hiding the border did not change them. | K-flush | **Kit:** inlay steps >= 0.04 (or recess). Not changed in Studio (walkable collision). |
| R3 | Crates (H_Props, E_Gear, E_Props, A_Props, S_Props) | Strap / corner plates (`dark_metal`) flush with the crate faces (92 + 53 + 17 + 12 + 6 px). | K-flush | **Kit:** inflate the straps 0.03 past the crate on every face (Training's Part crates already do this, +0.06). |
| R4 | Tunnel mouth | `H_Tunnel__band_olive` vs `H_TunnelPortal__band_olive` coplanar (same colour, so barely visible). | seam (two Hub1 pieces own one plane) | **Kit:** stop the tunnel band at the portal (x 88.4). |
| R5 | Duels west wall from the deck (x -142) | `D_Walls` and `D_West` both own the x -142 plane (wall_dark, wall_kick, wall_light, 3-13 px each). Plus `D_Roof` trim vs `D_Trusses` Neon, and stair plate vs trim (14 px). | seam / K-flush | **Kit:** one owner for the x -142 plane. Small. |
| R6 | Exfil helicopter (old asset) | `U_HeliRotor__case_poly` vs `paint_bone` coplanar (397 px). | rig/asset (pre-rebuild model) | Leave, or fix in the heli model if it is ever re-exported. |
| R7 | Duels pads, Training | The PadBoard / DPS **AlwaysOnTop BillboardGuis** do not appear in MCP `screen_capture`. With AlwaysOnTop off they render. | capture tool limitation (probably) | Check the DPS readout by eye in Studio Play once. Don't trust captures for AOT GUIs. |
| R8 | Training | check_training: **12 of 64 gallery sight lines blocked** by a `MidBlock` (plaza points (14, z 0/10) -> N-lane spots). The firing line and its own lanes are clear (that check passes). A 2-cell "deck 6" at (101,113) is a block corner beyond a 3-wide bridge (under the 6-cell rule). | layout (from the density fill, which was never checked) | **Recommend**: move that MidBlock off the plaza-to-N-gallery line if plaza sight lines matter; otherwise accept. |
| - | Hub ambient | White floating specks everywhere (LobbyFX ambient particles). | design | Already queued (remove ambient particles RIVALS doesn't have). |

Not issues: NPC name labels clipped by pillars (correct occlusion); FX floor pulse bars (0.02 above the insert, purpose FX);
the ExfilBarrier ForceField pane (original); Crane/Drone/Hologram/Scissors (intended LobbyFX).
Sky-leak sweep (3,000 rays per room from 9 room centres, all visible parts queryable): no holes apart from F1, doorways and the
Duels skylight.

## Training (open items from training_extras_done.md)
| Item | Result |
|---|---|
| Tiles in Play | Before: rendered R/G 0.95, B/G 1.00-1.07 (a slight green-cyan cast; RIVALS' grey 151,153,163 is R/G 0.99, B/G 1.07). **Nudged** `neutral()`: dropped the -3 % red lean (R = v), kept B +2 % -> rendered R/G 0.98-1.00, B/G 1.00-1.06, a cool neutral. Grid lines clear. `out/lap/training_tiles_before_after.jpg`. All 19 Training lights were on; every CC effect is neutral. |
| DPS hold fix | **Works**: 8 hits x 30 at 0.25 s -> 136 DPS, cream while firing; at 2.75 s idle the same value greyed; still held at 4.0 s; at 5.0 s "0 DPS / LAST 0 · TOTAL 0" (Idle 2.5, Hold 2). Frame: `t23_dps_hold.jpg` (152 DPS, LAST 30 · TOTAL 345, greyed). Hits were driven through each dummy's `OnHit` (the event CombatManager fires). Small fencepost: n hits over (n-1) intervals reads high (136 for a true 120 DPS); it could divide by `span + interval`. |
| check_training | **ALL OK** (after the fill, colours and bridges): 44 spots, 16 arrivals, floor 17,545/17,545 free cells reachable, 6 decks (5 with access, deck 6 = 2 cells), ramps 30.96° max step 0.60. See R8 for the 12 blocked plaza sight lines. |
| Truss climbing | **All 10 trusses**: climbed from the open side, reached root y 627 (roof + 3) and stepped onto the roof in 3.6 s each, at JumpHeight 0. Approached from the roof side, the climber goes over the top and drops off behind (expected). |
| Ramps (31°) | **Both** walked up in 4.5 s, Running state the whole way, ending on the roof (y 627). |
| TX_LastTargetShot | **Removed**: the trace line deleted from `ShootableManager`, `why()` made a no-op in `TrainingTargetsManager`, installer rebuilt and re-run; no live script references it and the workspace attribute is cleared. |

## Checks (end of session)
- check_hub1: no FAIL; crane and drone sweeps no hits; officer probe now hits the stair plate (it hit the NPC itself before).
- check_rooms2: **0 FAILS**. check_rooms3: **0 FAILS** (Duels axis max step 0.08, tunnel -> pad 0.05).
- check_training: **ALL OK**.

## Lessons (for the vault)
Why overlaps happen when a Blender kit is laid over an existing map, and how to prevent them:
1. **Flush authoring is the main cause.** Bands, trims, label plates and line strips modelled on the wall or floor plane z-fight in
   Roblox. Prevention: every decor box 0.03+ proud on every face, floor inlays 0.04+, Neon lines of different colours on different
   heights, labels proud of their board.
2. **Fixing one axis leaves the other.** The jamb fix (z) left the lintel soffit (y). Check all six faces of a frame.
3. **Bay infills are hand-written exceptions, and exceptions lose features.** The gate and tunnel bays lost the cornice and the top
   fill, leaving 16-stud holes that the old map had been hiding. Prevention: build exceptions by calling the same zone function with
   a cut-out, never with hand-written boxes, and run a sky-leak ray sweep after hiding the old map.
4. **Seams between kits.** At every threshold one kit must own the strip and the plane (tunnel 104 / hangar 105 left a 1-stud trench).
5. **Studio placement scripts inherit coordinates.** Values hard-coded from the old map's survey (sign overlays, NPC spots) land
   wrong on the new kit. Re-measure against the new geometry. A script that "measures the board face" lands on whatever plate is
   flush there: offset overlays 0.04+ from the measured face.
6. **Hidden old geometry hid problems; visible old geometry creates them.** After hiding, sweep for holes. Also list everything still
   visible that isn't kit (the TimesSquare towers, test cubes).
7. **Find overlaps by rays, not eyes.** Probe in Play with every visible part made queryable on the client: most kit meshes are
   CanQuery off and plain rays pass through them. A per-stop pixel-grid sweep (first two hits on one plane) ranks the pairs by
   screen area: 62 pairs, top one 718 px.
8. **Judge colour in Play and by numbers**: mean R/G and B/G of wall and floor patches. Edit and Play differ, and so do sessions.
