# House models: DONE (modeler, 2026-10-28)

Map **House** (Tacticals): a big two-storey modern suburban house, layout and feel inspired by a classic suburban
test-site shooter map; own models, own textures, no copied asset, logo or text. Built from `notes/maps/house_layout.json`
v1. Hand-over for the map builder: `notes/house_props.md`. Sheet: `notes/house_props_sheet.jpg`.

## Files
| File | What |
|---|---|
| `fbx/H_Furniture_kit.fbx` | all 65 furniture / dressing assemblies in a row + `K_ScaleCube` + `K_Marker`. **Import this one.** |
| `fbx/<assembly>.fbx` | one per assembly, its pivot at the origin (single re-imports; no cube / marker in these) |
| `fbx/H_House.fbx` | the house in plan coordinates: shell, roof, stairs, railings, doors, door frames, windows, skylights + cube / marker |
| `fbx/H_Exterior.fbx` | street, yards, neighbours, fences, cars, trees, poles / wires, lamps, mailbox + cube / marker |
| `house_furniture.blend` / `house.blend` / `house_exterior.blend` | the sources (collections `Kit`, `House`, `Exterior`) |
| `house_furniture.json` | per assembly: size, cover class, collision boxes, pivot, parts, tris, atlas files |
| `house_shell.json` | every house object (bbox, origin, tris, material), doors[] (hinge, yaws), windows[] (frame / glass / broken names) |
| `house_exterior.json` | every exterior object |
| `tex/H_<atlas>_{color,normal,rough,metal}.png` | 18 baked atlases (furniture 13, house Doors / Windows / Stairs, Cars); colour + normal 1024, rough / metal 512 |
| `tex/tile/T_*.png` | 18 seamless tiling textures (shell + exterior), studs per tile in `tex/tile/tiles.json` |
| `tex/sky/sky_side.png`, `sky_up.png`, `sky_dn.png` | Roblox Sky faces (side for Bk / Ft / Lf / Rt) |
| `tex/gen/*.png` | Codex-generated art: 4 prints, 2 rugs, a kid's drawing, the source sky |
| `tools/` | `build_furniture.py`, `build_house.py`, `build_exterior.py` (one run each rebuilds everything; `hcore.py` shared), `make_tiles.py`, `coverage_check.py`, `check_each.py`, `render_sheet.py`, `compose_sheet.py`, `preview_house.py` |
| `renders/check/` | blender_check results + magenta views (per furniture assembly, `House/`, `Exterior/`), `coverage_house.json` |
| `renders/preview/` | house views (`house_*.png`), culled magenta window views (`*_cull.png`) |

Rebuild: `"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python art/house/tools/build_<x>.py`
(about 4.5 min furniture, 3 min house, 20 s exterior on the main PC's RTX GPU; `-- --nobake` for geometry only).

## Import facts
- **Units:** the same Blender FBX exporter as Warehouse 2, so Import 3D reads centimetres: use a scale factor of **0.01**. `K_ScaleCube` must measure 10.
- **Axes:** read `K_Marker` (long arm +X, upright +Z, short arm +Y).
  - The house and exterior are in layout plan coordinates. The layout maps plan to world as ORIGIN + (x, z, -y).
  - Import with "Insert Using Scene Position". If plan +y did not land on world -Z, rotate the import 180 degrees about Y.
- **Textures:** embedded (`path_mode=COPY`, `embed_textures=True`). Import 3D with Creator = Gunsy Funsy uploads them with the meshes.
  - Glass (H_Glass, H_GlassFrost), H_Glow and plain-colour parts carry no texture: set the colour and Transparency in Studio.
- **Names in the kit FBX:** a single-mesh assembly is named `<assembly>`; a multi-part one is `<assembly>__<part>`. Repeats carry a `.001` suffix.
- **Collision:** every mesh is art (CanCollide / CanQuery / CanTouch off). Collision = the builder's layout Parts / COLP boxes.
- **Nothing was imported or uploaded by the modeler** (no Studio window was opened).

## Sizes and collision footprints
Cover heights: low **3.4**, tall **8.0** (CoverConfig waist / head rays; the final layout boxes every tall piece at 8.0).
- **Pivot:** the bottom centre of the union of the piece's collision boxes. The box footprint = the art footprint (handles included).
- **Multi-box pieces:** the sofa, the beds and the dining set list accurate multi-boxes. A single layout box over them gives invisible cover above the seat, mattress or table top.

| Piece | Size (Studio X x Y x Z) | Collision box(es): size @ centre from the pivot |
|---|---|---|
| H_Sofa_Sectional | 12 x 3.4 x 7.2 | 12x3.4x3.6 @ (0,1.7,1.8); chaise 3.8x1.8x3.6 @ (-4.1,0.9,-1.8) |
| H_Armchair | 4.2 x 3.4 x 4 | same as the size |
| H_KitchenIsland | 10 x 3.4 x 4.68 | same |
| H_DiningSet | 8 x 3.4 x 6.7 | table 8x2.6x4 @ (0,1.3,0); chair rows 6.1x3.4x1.95 @ (0,1.7,+-2.375) |
| H_Bed_Double / H_Bed_Single | 7.7 x 3.4 x 10 / 4.7 x 3.4 x 8.6 | headboard 3.4 tall + body 2.4 tall (see the json) |
| H_Dresser | 6 x 3.4 x 2.3 | same |
| H_Bathtub | 7 x 3.4 x 3.6 (floor tap to 4.1) | 7x3.4x3.6 |
| H_TVConsole (+ _WithTV) | 8 x 3.4 x 2.02 | same (the TV is art above) |
| H_KitchenBase / Sink / Hob | 4 x 3.4 x 2.46 / 2.46 / 2.58 | same (sink tap to 5.0) |
| H_KitchenBench | 10 x 3.4 x 3.5 | same |
| H_HallBench_3 / _8 | 3.5 / 8 x 3.4 x 2 | same |
| H_Planter | 3 x 3.4 x 3 (+ tree art to 8.95) | 3x3.4x3 |
| H_Bookcase | 6 x 8 x 1.6 | same |
| H_Fridge | 3.6 x 8 x 2.86 | same |
| H_Wardrobe / H_TallCabinet / H_Pantry | 6x8x2.5 / 3x8x2.12 / 4x8x2.46 | same |
| H_ShelfWall / H_OvenWall | 12 x 8 x 2 / 12 x 8 x 1.99 | same |
| H_SlatScreen / H_HeadboardWall / H_DisplayColumn | 6x8x2.04 / 14x8x1.5 / 3x8x3 | same |
Dressing (no collision) sizes are in `house_furniture.json` and `notes/house_props.md`.

## Doors: hinge naming
- `Door_<id>`, for example Door_Front, Door_Back, Door_GB, Door_MB, Door_BR2, Door_BR3, Door_UB, Door_EN.
- **Origin:** on the hinge axis at the bottom of the leaf. The leaf runs along local +X.
- **Pose:** object Z rotation = the layout's `leaf_yaw_deg`.
  - The room doors are ajar at 70 degrees.
  - Door_EN is closed.
  - The front and back doors are closed and locked.
  - The closed yaw is in `house_shell.json` doors[].closed_yaw_deg. Swing a door by rotating it about its own vertical axis.
- Door_Back is glazed: `Door_Back_Glass` and `Door_Back_BrokenGlass` share its origin.
- Door frames are `DoorFrame_<id>` (lining + architraves).

## Windows: glass naming
- Each of the 28 window openings has three meshes:
  - `<WindowId>_Frame`: black aluminium ring, mullions and a transom; exterior windows also get a white sill board inside and a flashing outside.
  - `<WindowId>_Glass`: the panes, 0.06 thick, edges buried in the frame.
  - `<WindowId>_BrokenGlass`: sawtooth shards left in the frame; hide it until the glass breaks.
- All three have their origin at the opening's bottom centre on the wall mid-line.
- For `fix/breakable_glass.lua`, put them in a model with Shootable="Glass" and name them Glass / BrokenGlass inside it (the installer's job).
- Frosted windows use H_GlassFrost.
- Skylight_N_Glass / _Trim / _Glow are the kitchen skylights. Set _Glow to Neon or white.

## Numbers
| | Meshes | Triangles | Largest mesh |
|---|---|---|---|
| Furniture (unique) | 79 | 28,260 | H_ShelfWall 3,528 |
| House | 136 | 24,024 | 2,424 |
| Exterior | 144 | 20,470 | 2,108 |

The placed map is about 100k triangles. Every piece is under 2,048 studs (the largest is the ground, 1,800).

## Proof check (the final state is in the grader section below)
- `blender_check.py`: furniture 0 FAIL in all 65 assemblies; house 0 FAIL; exterior 0 FAIL.
- `coverage_check.py`: 336,832 samples, 0 missing.
  - This is the culling-aware test for the shell. A3 is off for open shells, so blender_check could not see the round-1 slits. The test finds 2,724 misses on the round-1 build.
- Exact coplanar same-facing overlaps in the shell: 0 (logged by `build_house.py`).
- Culled magenta renders through every side of the house: `renders/preview/house_win_*_cull.png`.
- Remaining WARNs, all checked:
  - A1b on multi-part meshes;
  - A8 on parts that are buried or intended: glass vs broken glass (never shown together), frames in their reveals, closed leaves in their linings, skylight glow inside its trim.

## Grader
See the end of this file (filled in after the grade).
