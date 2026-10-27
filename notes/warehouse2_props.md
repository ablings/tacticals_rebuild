# Warehouse 2 props (modeler, 2026-10-27, round 6: less green)

Grounded, GTA-style military warehouse props for the new map "Warehouse 2". Own models, own baked textures, no sci-fi
panels, no neon, no yellow (hazard paint is black/cream). Sheet: `notes/warehouse2_props_sheet.jpg` (stand-in of the old
piece | 5-stud human | new model).

**Round 6 (Edward: "too much green", the same note as before).** Olive was on nearly every crate, the tarp, a drum, the
lamp, the toolbox, the forklift and the scale figure. Olive drab is now an accent on **one small piece only** (the ammo can). Round 6b, after the grader measured olive at 7.8% of the placed prop surface, 84% of it the long crate on every wall stack: the long crate went dark wood too (now about 1%).

| Piece | Was | Now |
|---|---|---|
| W2_Cover_Low (rifle crates, the most-placed cover, 14x) | olive wood | weathered pine, solid black stencils |
| W2_Cover_Tall (engine crate) | olive wood | dark stained wood, cream stencils |
| W2_SupplyCrate (also in the wall stack) | olive wood | grey-painted wood, cream stencils |
| W2_SteelCrate (also in the wall stack) | olive steel | gunmetal grey steel |
| W2_LongCrate (top of the wall stack) | olive wood | dark stained wood, cream stencils |
| W2_AmmoCan | olive steel | **olive kept** (70,74,52), like a real ammo can |
| W2_OilDrum_Olive | olive | renamed **W2_OilDrum_Grey**, grey-blue paint |
| PalletSacks tarp | olive canvas | grey canvas, neutral sun-bleach (the bleach had kept an olive tint) |
| HighBayLamp shade, workbench vice/toolbox/cabinet | olive-green | grey |
| Forklift body and wheel rims | olive | warm charcoal grey |
| Fire barrel bung | olive | grey steel |
| 5-stud figure on the sheet | lime shirt | slate-blue shirt |

Geometry, sizes, pivots and collision are unchanged; only the baked colours changed. The .blend now saves relative image
paths, so it opens with its atlases on either PC. On the Shadow PC run the generator with `--device CUDA`: Blender 5.2's
OptiX kernel fails there and Cycles bakes black without an error (the generator now stops on a black bake).
Map builder: `notes/warehouse2_build.md` still names `W2_OilDrum_Olive`; use `W2_OilDrum_Grey`.

Round 2 reconciles the work order with the map builder's kit brief (`briefs/kit-warehouse2.json`) and the map script
(`fix/map_warehouse2.lua`):
- the doors fit the real 20 x 14 openings;
- the oil drums are 3.0 high and black/olive, so they never look like the 3.4 red fire barrel;
- the hanging lamp is the brief's high-bay lamp;
- a plywood-on-skids tall crate was added as the second TallCrate variant;
- hazard stripes are black/cream.

Round 3 fixes the second grade:
- The wall stack had a see-through slit between its two lower crates. A dark joint block, `W2_WallJoint`, now fills it.
- Where boards crossed on crate tops, two faces shared one plane. The end boards now butt between the front and back boards, and the trims step 0.03 apart.
- Some faces were half visible but had no texture space, so they showed as black strips. The test for "buried" now samples densely over each face.
- Stacked top crates are 0.03 smaller and sunk 0.03, so there are no butt joints.
- The burnt barrel gets one tall tear, two petals and a bulge.
- The plywood crate's skids are closed at the ends.

Round 4 fixes the third grade:
- Every remaining 0.01-0.02 layer and slit is fixed: pallet, steel crate, rack decks, workbench legs and vice, forklift guard, mast, carriage, plywood skids, door back faces.
- Wood-crate corner caps are 0.06 thick. The crates' outer board plane is now 0.06 inside the cover box (0.095 on the stacked tops), within the brief's 0.1.
- Forklift wheels are lighter (18 segments).
- A new check, `tools/assembly_check.py`, tests every part of an assembly together:
  - same-facing layers under 0.03;
  - facing gaps under 0.15;
  - rays through each cover piece on a 0.01 grid.

Round 5 fixes the fourth grade:
- A generator bug triangulated concave side panels before their normals existed. That left flipped triangles on the forklift sides (the cab looked boxed in, and a wedge clipped the back tyres) and on the pegboard wrenches. Normals are now computed first, and `assembly_check.py` gained a test for it.
- Crate lids now sit 0.09 under the frame top instead of 0.22, so the crates no longer read as an open tray.
- Also small: tarp 0.03 higher over the sacks, pegboard ends, skid and post offsets, forklift guard.
- After the PASS:
  - the forklift stencils sit on one flat side panel (no letters fall into the cab);
  - the half-open curtain has slats on its yard side too;
  - every mesh ships as triangles, so the importer can't flip a concave or non-planar quad.

## Files (all under `art/warehouse2/`)
| What | Path |
|---|---|
| Generator (one run rebuilds everything, about 2 min on the RTX GPU) | `tools/build_props.py` (Blender 4.5 or 5.2, headless; about 2 min on the main PC, about 25 min on the Shadow PC); stencils `tools/make_decals.py` (PIL) |
| Kit file | `warehouse2_props.blend`: collection `Kit` holds the assemblies below, `Markers` holds the scale cube and marker |
| FBX, whole kit | `fbx/W2_Props_kit.fbx`: all assemblies in a row, plus `K_ScaleCube` (10 studs) and `K_Marker` (long arm +X, upright +Z, short arm +Y). **Import this one once.** |
| FBX, one per assembly | `fbx/<assembly>.fbx`: the pivot (below) at the origin. Each re-embeds its atlas, so use these only for single re-imports. |
| Textures (11 atlases) | `tex/W2_<atlas>_{color,normal}.png` at 1024, `_rough` and `_metal` at 512; stencil sources in `tex/decals/` |
| Placement JSON | `warehouse2_props.json`, per assembly: size, pivot, extents from the pivot, parts with offsets, tris, atlas, collision, what it replaces |
| Check outputs | `renders/check/<assembly>/check_*.jpg` (magenta views); `renders/check/per_assembly.json`, `assembly_check.txt`, `zero_uv.txt`, `texel_density.txt` |
| Sheet tiles | `renders/<assembly>.png` |
| Other tools | `tools/render_sheet.py`, `compose_sheet.py`, `check_each.py`, `assembly_check.py` (layers, gaps, see-through), `zero_uv_check.py`, `texel_density.py`, `preview_wb.py`, `contact.py` |

**Axes:** Blender (x, y, z) -> Studio (-x, z, y), per the Tacticals pipeline page. 1 unit = 1 stud. The front of every prop is Blender -Y. Sizes below are Studio X x Y(up) x Z.

**Verify on the first import:** the FBX's own axis tags read as (x, z, -y), which differs from the pipeline mapping by 180°. `K_Marker` settles it (proof check B2). Measure `K_ScaleCube` too (B1).

**Pivot:** the bottom centre of the assembly's first, gameplay part. That is:
- the barrel axis, for the barrels;
- the crate centre, for the crates;
- the wall centre, for the stack;
- the opening centre on the wall's inside face, for the doors.

Put the pivot on the floor top at the old piece's centre. Old centres are in `notes/warehouse_study/warehouse_dump.json`.

**Doors, for the map builder (one kit owns each seam plane):**
- The door mesh replaces the stand-in Parts that `fix/map_warehouse2.lua` builds for each door: `Jamb_*`, `Head_*`, `Drum_*`, `BottomBar_*`, `Guide_*`.
- Remove those Parts when the mesh goes in.
- The mesh guides run x ±10.0 to ±10.6 and y -0.62 to +0.08 (0.7 deep). The housing is z 14.0-16.2 and 2.4 deep into the room.
- If the wall's reveal (the 1.5-deep jamb through the wall) is kept as Parts, start it behind y +0.08. Otherwise its x = ±10.0 / ±10.6 faces share planes with the mesh guides.

## Props: size, what it replaces, collision
For every visual mesh, set **CanCollide, CanQuery and CanTouch off** (art only). Gameplay collision stays on the existing invisible `COLP_*` Parts. Cover art is exactly its proxy box, never bigger.

| Assembly | Size (studs) | Tris | Replaces | Collision |
|---|---|---|---|---|
| W2_FireBarrel (barrel + fuel puddle) | barrel **2.1 x 3.4 x 2.1** on the pivot; the puddle spreads 1.5-2.1 around it | 1,476 | `Shootables/FireBarrel_F1-F4.Look` | keep the existing `Body` cylinder Part (2.1 x 3.0, the shootable hit part) centred on the pivot |
| W2_FireBarrel_Burnt (torn drum + blown lid) | drum about 2.5 x 3.0 x 2.5 (petals, one tear); the lid lies 2.6 away | 1,952 | the FireBarrel's Look after it blows (same pivot) | none, or the Body cylinder if it should stay low cover |
| W2_OilDrum_Grey / _Black | 2.1 x **3.0** x 2.1 | 1,192 | new clutter (kit brief OilDrum), not shootable | none |
| W2_Cover_Low (2 stacked pine rifle crates) | **6 x 3.37 x 2**: the top crate is 0.035 smaller per side and sunk 0.03, within the brief's 0.1 | 1,112 | `Visuals/Arena_L01-L14` | existing `COLP_Lxx` 6 x 3.4 x 2 |
| W2_Cover_Tall (dark wood engine crate) | **5 x 7 x 4** | 348 | `Visuals/Arena_C01-C10` | existing `COLP_Cxx` 5 x 7 x 4 |
| W2_Cover_TallPly (plywood crate on skids, ends closed) | **5 x 7 x 4** | 396 | `Arena_C` variant 2 (kit brief TallCrate) | existing `COLP_Cxx` |
| W2_Cover_Wall (the stacked set: supply + steel crate under a long crate, plus the dark joint block) | **10 x 6.97 x 3** | 1,356 | `Visuals/Arena_W01-W04` | existing `COLP_Wxx` 10 x 7 x 3 |
| W2_SupplyCrate / W2_SteelCrate / W2_LongCrate (loose) | 5 x 3.5 x 3 / 5 x 3.5 x 3 / 10 x 3.5 x 3 | 532 / 256 / 556 | dressing | a box of the same size if placed in the play area |
| W2_AmmoCan | 2.4 x 1.19 x 1.8 | 92 | `Visuals/Arena_PropCrate01-04` (2.4 x 1.2 x 1.8) | none |
| W2_RollDoor_Open (guides, drum housing, bottom bar, control box) | 23.6 x 16.3 x 2.6 around a **20 x 14** opening; back faces 0.02-0.11 into the wall | 420 | the end openings (kit brief RollUpDoor; the old Warehouse Shutter was 16 x 9) | none: walls, headers and OutOfBounds collide |
| W2_RollDoor_HalfOpen (curtain down to 7.0) | same | 992 | same | optional box 20.6 x 7.6 x 0.5 at the curtain, else none |
| W2_Pallet | 4 x 0.6 x 3.4 | 240 | `Props/Pallet` | none |
| W2_PalletSacks (pallet, 18 sacks, grey tarp) | 4.06 x 2.1 x 3.52 | 3,384 | `Props/Pallet` + `Cardboard` piles | a box of that size in the play area |
| W2_Tyre / W2_TyreStack (3) | 2.4 x 0.86 x 2.4 / 2.5 x 2.5 x 2.5 | 784 / 2,352 | new clutter | none / a cylinder 2.5 x 2.5 |
| W2_ShelfRack (rack + boxes as a separate mesh) | 8 x 8 x 2.5 | 600 | new wall storage for the yards or hall walls | box 8 x 8 x 2.5; **keep it out of the play area** (the old cabinet was 0.65 x 3 x 2; the hall metrics would drift) |
| W2_Workbench (vice, toolbox, pegboard tools, clamp lamp) | 6 x 4.75 x 2.4 | 688 | `Props/Workbench` | box 6 x 2.86 x 2.4 in the play area; the `WorkLight` SpotLight goes at the clamp lamp head |
| W2_HighBayLamp (bell, lens, rod: 3 meshes) | bell 2.6 x 1.8 x 2.6, rod 4 long | 948 | kit brief HighBayLamp (the old flat light strips) | none; SpotLight down from the lens (0.17 above the rim); scale the rod on its length |
| W2_Forklift (body, mast, forks, steering wheel, 4 wheels: all separate) | 3.44 x 6.05 x 10.27 incl. forks (7.2 to the fork face) | 3,604 | yard dressing (kit brief Forklift) | none: behind the map's own collider |

Whole set:
- 33 unique meshes, 18,288 unique triangles; 24,472 as laid out.
- The biggest mesh is 3,144 triangles.
- The forklift is built from a 2.5 t counterbalance truck's real proportions at 1 stud = 0.35 m: 1.15 m wide, 2.5 m to the fork face, 1.6 m wheelbase, 2.1 m guard. So it is longer than the kit brief's 4 x 7 x 8 box, on purpose.

## Textures to upload (group Gunsy Funsy)
Import 3D with Creator = Gunsy Funsy uploads the meshes and the embedded textures together, as one SurfaceAppearance per atlas. If the textures go up by hand, there are 44 images in `art/warehouse2/tex/`:
- the atlases: `W2_{Barrels, CratesCover, CratesWood, CratesPly, CratesSteel, Door, DoorCurtain, ClutterA, Rack, ClutterB, Forklift}`;
- each atlas has `_color`, `_normal`, `_rough` and `_metal`.

After uploading, grant the universe access (the group has Asset Privacy on). Nothing was imported or uploaded by the modeler.

## Not in this round (the kit brief lists them for the modeler; the work order did not)
JerseyBarrier, PrecastBlockWall, PalletStack, BoxTrailer, Container20, FencePanelScreened, Bollard, ElectricalCabinet.
- The map builder's brief puts concrete jersey barriers and block walls on the L and W covers, where the work order put crates.
- The crate sets above fit the L and W boxes exactly. Which one goes where is the director's call.

## How it is built (for the next modeler)
- **Geometry:** low-poly closed shells per prop.
- **Textures:** one atlas per prop family, baked in Cycles from layered procedural materials:
  - plank grooves and grain from a helper UV;
  - edge chips from a Bevel-node edge mask;
  - rust patches and streaks, AO dirt and dust on top faces;
  - stencils are PIL masks projected through extra UV layers (CLIP extension) and baked into the colour map. The extra UVs are then deleted, so one UV map ships.
- **Buried faces** (wholly inside another part of the same mesh) keep their geometry, so meshes stay closed, but get zero UV area. Every mesh is now 36-70 px per stud; the cover crates went from about 20 to 41-50.
- **Stacked crates** rest on their top and bottom battens.
  - The upper crate is an instance scaled 0.035 smaller per side, sunk 0.03 into the lower one. That gives no butt joint, and no shared plane on the sides.
  - The corner blocks sit 0.03 inside the batten plane.
  - On every face, the end boards butt between the front and back boards, so boards never cross in one plane.
  - The trims step back from the frame plane: cleats 0.03, bands 0.06, braces 0.09.
- **Proof check:**
  - `blender_check.py`: 0 FAIL, both per assembly and for the whole kit.
  - The 44 WARN are concave lathes (A1b), plus parts sitting inside or edge-on to others (A8, with no shared visible area).
  - `assembly_check.py` (results in `renders/check/assembly_check.txt`):
    - see-through: 0 rays pass any cover piece (0.01 grid, 0.11 in from the box);
    - broken (flipped) caps: 0.000 sq studs (6.9 on the round-4 build);
    - layers: 1.05 sq studs left over the whole kit;
    - facing gaps: 6.4 sq studs left over the whole kit.
  - What is left is deliberate or hidden:
    - the sealed cavity between stacked crates (inner bar faces);
    - drawer reveals on the workbench;
    - the spacing between rack boxes, between sacks, and between tyre and body on the forklift;
    - the dark joint seam in the wall stack, 0.09 deep with the filler behind it;
    - specks under 0.02 sq studs.
  - Lessons:
    - Inside-tests by ray parity need several directions: a ray through a quad's diagonal counts twice.
    - Grid samples must have barycentric weights that sum to 1.
    - In bmesh, call `normal_update()` before triangulating a new n-gon.
    - A whole-object volume test misses flipped cap triangles. Test each plane of each loose part for faces of both orientations.
  - `zero_uv_check.py`: visible area of faces with no texture space: 0.000.
  - `texel_density.txt`: 36-70 px per stud.
