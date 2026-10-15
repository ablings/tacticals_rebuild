# Training v2 build (Step 1: geometry) + Showroom placement

Done 2026-10-15 in `Tacticals_rebuild.rbxl` (studio e1d5a8da-..., checked with list_roblox_studios) only. **Not saved** (the lead saves).
No computer use, no Blender, no script changes. Nothing touched in the live "tacticals (placeId ...)" studio, RIVALS or the replica.
Own assets only: TX_overlay_grid 86361987736184, TX_grime_overlay, TacHub1 variants.

## Files
| What | Path |
|---|---|
| Showroom place script (idempotent, `UNDO`) | `fix/place_showroom.lua` -> `python tools/run_luau.py fix/place_showroom.lua [UNDO]` |
| Training place script (idempotent, `UNDO`) | `fix/place_training.lua` (same runner) |
| Training layout generator (overlap / clearance checks in plan; pastes the data between `--@LAYOUT_BEGIN/END`) | `tools/training_layout.py` -> `fix/training_layout.lua` (copy of the data), `out/training/layout_plan.png` |
| Training checks (read-only) | `fix/check_training.lua` |
| Captures (forces Training/Showroom RoomLight lights on, restores them after) | `python tools/training_capture.py <before/after> [names]` -> `out/training/<prefix>_*.png` |
| Before/after sheet (8 Training views + Showroom camera) | `out/training/before_after.jpg`; sign close-up `out/training/after_s2_showroom_sign.png` |

Both UNDOs were tested as a round trip (UNDO, then re-apply). Showroom: 11 instances un-hidden and re-hidden; the kit went back to
`Workspace.rooms4`. Training: 1,205 instances un-hidden; the 336 old spots and 16 old arrivals came back; the 12 old RoomLights were
re-tagged; TrainingArrive went back to (-10.05, 603.2, -110).

## Part A: Showroom
- The 50 kit meshes are in `LobbyMap.Showroom.Rooms4`, one Model per piece. They use the manifest colours, materials and variants,
  with olive tuned as in rooms3 (band 111,114,57, Neon 66,72,36). **All have CanCollide/CanQuery/CanTouch false and NotCover.**
  CastShadow is off on Neon, and the props have grime. Imported values are in `Rooms4_Orig`. `K_Scale4` (a 10-stud cube at
  (0,120,0)) and `K_Marker4` (+X arm) were correct and are now in `ServerStorage._RebuildRemoved`.
- **BenchTop check:** BenchTop's top is **404.40** (centre 404.10, size 0.6), not the 404.2 in rooms4_kit.md. So the kit table
  (SR_Stage bench_top, trim_metal, neon_cream, wall_kick, band_olive, dark_metal) moved **+0.20**. The original CFrame is in
  `Rooms4_OrigCF`. The footprint matches exactly (x -8..8, z 5..12). The dais disc and halo stay on the floor; the 0.2 gap under
  the plinth is below the FOV-40 frame. DisplayPoint is at y 406.3 and CameraPoint at 407.4 (the notes said 406 / 407.5). Both are
  untouched, and the kit still frames them.
- Hidden (Rooms4_* attributes): the 6 `U_Showroom__*` meshes and `Showroom.Sign` (the old ARMORY meshes). The new **ARMORY** text is
  on a solid backing plate (`Rooms4.SignText_Showroom`) 0.08 in front of the measured board face, inside the olive Neon frame.
- The hooks are verified unchanged (DisplayPoint, CameraPoint, BenchTop, KeyLight, Lights.*), with 6 Showroom RoomLights. The line
  from CameraPoint to DisplayPoint is clear. Capture: `after_s1_showroom_cam`. Still to do: open the Kit menu in Play and check
  the fake shadow on the table.

## Part B: Training v2 (Range2)
Everything new is in **`LobbyMap.Training.Range2`** (folders Floor, Gallery, Shell, Plaza, Blocks, Towers, Cover, Access, Lines,
Lights, Signs).
- The old geometry is hidden (Training_* attributes, `TrainingHidden`). The 12 old lights are disabled and untagged from RoomLight
  (tag kept in attribute `Training_Tags`).
- The old `Arrivals` and `EnemySpots` folders moved to `ServerStorage._RebuildRemoved.Training_Arrivals_Old` and
  `Training_EnemySpots_Old`. The scripts read every child, so they could not stay.
- `TrainingArrive` is kept and moved to the plaza centre (0, 603.3, 0), facing east. Its original CFrame is in `Training_OrigCF`.

| Item | Built |
|---|---|
| Footprint | arena 256 x 256 (x/z -128..128) + gallery 224 x 72 (x 128..352, z -36..36), floor top **600**, walls 48 tall, **ceiling slab at 648** (closed room) |
| Roof level | **+24** (y 624): 12 blocks + 4 bastions + 14 bridges (6 wide). The bastions are 24 tall, not the plan's 30, so all roofs are on one level |
| Decks (from the check) | maze deck 5,160 studs² (NW blocks + NW bastion; 1 ramp + 6 trusses); overwatch 1,220 (O1 + NE bastion; 1 ramp + 1 truss); O2 248 (truss); SW and SE bastions 580 each (truss) |
| Access | 2 WedgePart ramps (40 run, 31 deg) and 10 TrussParts (2x24x2) whose tops are flush with the roofs. No jump pads yet |
| Towers | 3, 8 x 8, **36 tall (y 636)** per the coordinator (headroom for pads and tightropes); TacRibbed with two olive bands |
| Cover | 25 low walls (3.5), 2 low blocks (4), 18 military-green crates (4-5, grime + metal straps), 10 tall walls (10), 3 pillars (12), 2 counters (3.5) at the firing line |
| Lines | olive Neon: firing line at x 136, 4 field lines (25/50/75/100 from the plaza edge), plaza edge. Cream Neon: lane divider. Every perimeter wall has an olive band (607-610) with a cream Neon line under it |
| Gallery | floor in 8 alternating 25-stud bands (sage / warm grey) from the firing line; 16 hanging distance boards (25..200) 16 studs above the floor, over the spots |
| Signs | 21: 16 gallery boards, 4 field boards on the east wall, a "[M] LEAVE" stencil on the plaza. **CanCollide/CanQuery/CanTouch false + NotCover** |
| Lights | 19 Neon ceiling panels with PointLights (Range 60, Brightness 1.2, no shadows), tagged **RoomLight, Room = Training**: 16 in a 4x4 grid over the arena, 3 in the gallery |
| Arrivals | 16 `Arrive` parts on a ring (r 14) round the plaza centre, facing outward, 3.2 above the plaza surface (600.1) |
| EnemySpots | **44** direct children, no sub-folders. 16 **`GallerySpot`**: attributes **`Gallery = true`**, `Distance` (25..200), `Lane` (N/S), facing -x (the firing line). 28 `Spot`: maze 5 floor + 4 roof, overwatch roof 2, bastion roofs 3, towers 3, cover 5, field 6, all facing the plaza. Every spot has `Zone`, and its centre is the surface + 3 |
| Counts | 199 Parts from the layout pass + 21 signs/trims + 19 lights; 588 grid Textures (6 faces, 5x5, black, 0.75) |
| Palette | grid tiles: Concrete + TacConcrete (towers TacRibbed); bridges and ramps: Metal + TacFloorPlate; trusses: Metal 67; olive 111,114,57; crates 65,94,56. The greys are **warm-compensated** (+12 R, -14 B) because the first capture read teal under Future. Nominal values are in the script |

NotCover (for CoverController): bridges, ramps, trusses, ceiling, and all lines, bands, signs, lights and straps. Counted as cover:
blocks, bastions, towers, walls, low walls, crates, pillars and counters. Floors count too, but cover never hits them horizontally.

## Checks (`fix/check_training.lua`: ALL OK)
- **Hooks:** 44 EnemySpots (all BaseParts, 16 with Gallery = true), 16 Arrivals, TrainingArrive, Dummy template present. Spot and
  arrival flags are correct (invisible, no collide, no query).
- **Heights:** Range2 spans y 598..650 and nothing is below 585. The only parts above y 540 outside Training are the TRAINING sign
  meshes (LobbyMap.Signs).
- **Floor:** no holes. 20,022 floor cells, 17,896 free, and **all free cells are reachable from the plaza** (2-stud flood fill with
  a 1.8 x 4.6 body probe, GetPartsInPart). Every zone is reachable.
- **Roof:** 1,947 cells (7,788 studs²) at y 624. Minimum headroom to the ceiling is **24.0**. There are 5 decks and each one has
  access. Ramp slopes were sampled (max step 0.6 per stud).
- **EnemySpots:** every spot is exactly 3 above a surface, a 4 x 5 x 2 dummy probe is free, and a player can reach it (floor flood
  fill or an accessible deck).
- **Gallery:** 64 sight lines to every gallery spot (from its own lane on the firing line, the centre of the firing line, the
  plaza, and an offset plaza point): 0 blocked. Signs never block.
- **Arrivals:** 16/16 + TrainingArrive clear, 3.2 above the floor.
- **Lights:** 19 Training RoomLights. **The 3 gallery lights are beyond RoomFX's 175 radius**, so they stay off in Play until the
  step-2 RoomFX change.

## Issues / for step 2
- **Truss climbing and the 31-deg ramps are not tested in Play** (no Play runs while Edward is on the PC). Tacticals sets JumpHeight
  to 0. Roblox climbing does not need jump, but CoverController's movement overrides should be checked: climb each truss and step
  onto the roof.
- RoomFX: the gallery lights (x 180..308) need the wider radius (training_extras_plan.md section 4). The corner lights (135 from the
  centre) are already inside 175.
- Grid textures are not offset to a world grid, so the lines do not continue from one box to the next (each box tiles from its own
  corner).
- The closed room no longer has the old arched sky windows. If Edward wants the sky back, glazed strips in the perimeter walls above
  the band would do it.
- The plaza "[M] LEAVE" stencil and distant SurfaceGuis do not render in far edit captures (LOD). The sign close-up does render.
- The `Training.Extras.*` folders (JumpPads, Tightropes, SwapBins, TargetSpots, DpsSpots) are not created; step 2 builds them. Pad
  arcs must stay under 648 - 7.
- The room is about 2x the old footprint and is lit by 19 point lights 46 studs above the floor plus ambient. Judge the brightness
  in Play.

## Lessons
- **Generate the layout outside Studio and check it in plan first** (overlaps, spot and arrival clearance), then build. The spec
  plan had bridges that missed their blocks, a 67-degree ramp, a block overlapping a bastion and a spot inside a bastion. All were
  caught before Studio.
- **Light greys turn teal under Future with the blue sky**, even in a closed room. Warm-compensate them (+12 R / -14 B), as hub2
  did for the dark floor.
- Scripts that read `folder:GetChildren()` as parts break on sub-folders. Mark groups with attributes instead (`Gallery = true`).
- Untag hidden RoomLight carriers as well as disabling them: in Play, RoomFX turns tagged lights back on.
- Read hook values like BenchTop in Studio, not from the notes (404.4, not 404.2).
