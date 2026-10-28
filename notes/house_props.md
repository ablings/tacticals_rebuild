# House: models (modeler, 2026-10-28, overnight, round 2)

Everything modelled for Tacticals' new map **House**: a big two-storey MODERN suburban house whose layout and feel are
inspired by a classic suburban test-site shooter map. Own models, own textures, no copied asset, logo or text. Built from
`notes/maps/house_layout.json` v1 (final, map builder commit 62781de). Sheet: `notes/house_props_sheet.jpg`.
Files and numbers in full: `art/house/DONE.md`.

## What there is
| File | What | Triangles |
|---|---|---|
| `art/house/fbx/H_Furniture_kit.fbx` (+ `fbx/<assembly>.fbx`, pivot at the origin) | 65 furniture / dressing assemblies, 79 meshes, 13 baked atlases | 28,260 unique |
| `art/house/fbx/H_House.fbx` | the house IN PLACE: shell, roof, stairs, railings, 8 doors, 8 door frames, 28 windows (frame + glass + broken glass), skylights | 24,024 |
| `art/house/fbx/H_Exterior.fbx` | street, yards, the house across, 6 neighbour houses, fences, shed, 4 cars, 15 trees, power poles + wires, lamps, mailbox | 20,470 |
| `art/house/tex/sky/sky_{side,up,dn}.png` | the sky (Roblox Sky faces) | |
Each FBX carries `K_ScaleCube` (10 studs) and `K_Marker` (long arm +X, upright +Z, short arm +Y): measure them after Import 3D.

## Coordinates
- **Furniture:** pivot = bottom centre of the union of its collision boxes (= the layout COLP box); front = Blender -Y. Blender (x, y, z) -> Studio (-x, z, y) by the pipeline page, but the FBX axis tags may give (x, z, -y): read `K_Marker`.
- **House and exterior:** built in **layout plan coordinates** (Blender x, y, z = plan x east, y north, z up). The layout maps plan to world as ORIGIN + (x, z, -y). Import with "Insert Using Scene Position", then check that `K_Marker`'s long arm points to world +X and its short arm to world -Z (plan +y = north). If not, rotate the whole import 180 degrees about Y.

## Cover heights and collision (work order PART A)
- Cover heights come from `notes/warehouse_study/movement_configs.txt` (CoverConfig waist / head rays).
  - **Low = exactly 3.4.**
  - **Tall = exactly 8.0.** The final layout puts every tall box at 8.0, so the 7.0-7.6 drafts were raised.
- Every visual mesh is art: CanCollide, CanQuery and CanTouch off. Collision = the builder's COLP boxes.
- **Multi-box pieces (grader round 1, major):** a single COLP box over the sofa, the beds or the dining set gives
  invisible cover above the seat, mattress or table top. `house_furniture.json` collision_boxes_studio has the
  accurate boxes. Using them is the builder's / Lead's call (re-run the fairness check).
- Each cover piece's art fits inside its box footprint; the box footprint = the art footprint (handles included).
- Things that rise above a 3.4 box (no collision needed):
  - the tub's floor tap (to 4.1);
  - the sink tap (to 5.0);
  - the TV on the media console;
  - the planter's fiddle tree.

| Cover piece | Size W x H x D (studs, Studio X x Y x Z) | Collision box(es) | Notes |
|---|---|---|---|
| H_Sofa_Sectional | 12 x 3.4 x 7.2 | 12x3.4x3.6 (the back + main seat) + 3.8x1.8x3.6 chaise | solid plinth, no gap under it; pivot = centre of the 12 x 7.2 footprint |
| H_Armchair | 4.2 x 3.4 x 4 | 4.2x3.4x4 | leather |
| H_KitchenIsland | 10 x 3.4 x 4.68 | same | quartz top with waterfall ends, seating overhang at +Y |
| H_DiningSet (table + 6 chairs) | 8 x 3.4 x 6.7 | table 8x2.6x4 + two chair-row boxes 6.1x3.4x1.95 | chair backs 3.4; table top 2.6 (H_DiningTable alone: low obstacle 2.6) |
| H_Bed_Double / H_Bed_Single | 7.7 x 3.4 x 10 / 4.7 x 3.4 x 8.6 | headboard box 3.4 + body box 2.4 | head at +Y against a wall |
| H_Dresser | 6 x 3.4 x 2.3 | same | |
| H_Bathtub | 7 x 3.4 x 3.6 (tap 4.1) | 7x3.4x3.6 | soaking tub on a tiled plinth, rim at 3.4 |
| H_TVConsole (+ _WithTV) | 8 x 3.4 x 2.02 | same | |
| H_KitchenBase / Sink / Hob | 4 x 3.4 x 2.46-2.58 | same | 4-wide modules: tile them in runs; hob glass flush in the top |
| H_KitchenBench | 10 x 3.4 x 3.5 | same | banquette, seat faces -Y |
| H_HallBench_3 / _8 | 3.5 / 8 x 3.4 x 2 | same | solid back board behind the slats |
| H_Planter | 3 x 3.4 x 3 | same | concrete box; the tree above is art |
| H_Bookcase | 6 x 8 x 1.6 | same | solid back panel |
| H_Fridge | 3.6 x 8 x 2.86 | same | kid's drawing under a magnet |
| H_Wardrobe / H_TallCabinet / H_Pantry | 6x8x2.5 / 3x8x2.12 / 4x8x2.46 | same | |
| H_ShelfWall | 12 x 8 x 2 | same | both faces dressed, solid spine (team A spawn wall) |
| H_OvenWall | 12 x 8 x 1.99 | same | ovens on -Y, cupboards on +Y (team B spawn wall) |
| H_SlatScreen | 6 x 8 x 2.04 | same | solid oak core between the slats |
| H_HeadboardWall | 14 x 8 x 1.5 | same | upholstered channels on -Y |
| H_DisplayColumn | 3 x 8 x 3 | same | display niches on -Y and +Y, solid core |

Dressing (no collision): lamps (floor / table / pendant, with separate shade / bulb meshes for a light), TV (H_TV_Screen
is its own mesh), laptop, 4 framed prints (own generated art), 2 rugs, 2 plants, fruit bowl, kettle, microwave,
coffee machine, washing machine, toilet, vanity, mirror, shower set, glass screen, towel rail, toy blocks / ball / car,
teddy, bar stool, nightstand, coffee table, side table, desk, desk chair, kitchen uppers, range hood.

## Doors (hinge naming)
- Every door is its own mesh, `Door_<id>`, with its **origin on the hinge axis at the bottom of the leaf**.
- The leaf runs along local +X from the hinge. The object's Z rotation = the layout's `leaf_yaw_deg`.
- To swing a door, rotate it about its own vertical axis: the closed yaw is in `house_shell.json` doors[].closed_yaw_deg.
- How each door is posed:
  - the room doors are ajar at the layout's 70 degrees;
  - the ensuite door (Door_EN) is closed;
  - the front and back doors are closed and locked.
- Door_Back is a glazed patio door: `Door_Back_Glass` and `Door_Back_BrokenGlass` share its origin and follow the glass convention.
- `DoorFrame_<id>`: the lining and architraves of each door opening. Outer doors have charcoal casings outside.

## Windows (glass naming)
- Each of the 28 window openings gets three meshes, all with their origin at the opening's bottom centre on the wall mid-line:
  - `<WindowId>_Frame`: black aluminium ring, mullions and a transom. Exterior windows also get a white inside sill and an outside flashing.
  - `<WindowId>_Glass`: the panes, 0.06 thick, edges buried in the frame.
  - `<WindowId>_BrokenGlass`: the shatter state, a ring of sawtooth shards left in the frame. Hide it until the glass breaks.
- This matches the systems convention (`fix/breakable_glass.lua`): a model with Shootable="Glass" holding Glass + BrokenGlass.
- Glass uses a plain material: set Transparency in Studio (about 0.7).
- The frosted windows (`frosted` in the layout) use H_GlassFrost.
- Skylight_N_Glow are the kitchen skylights' light panels: set them to Neon or white.

## Round 2 (after the model grade, FIX 6.9)
- **Shell slits at every T-junction (blocking).**
  - Cause: the walls were diced into a 6 x 6 grid, and any cell whose centre was buried was dropped whole. Part-covered cells became 0.2-1.2 wide, full-storey slits.
  - Fix: faces are now cut exactly at every neighbouring part's edge.
  - New test `art/house/tools/coverage_check.py`: 0 of 336,832 samples missing. It finds 2,724 on the round-1 build.
- **Neighbour side windows painted on (blocking, a repeated correction).**
  - Cause: two windows sharing a column (one per storey) were walked pier by pier, so the second filled the first back in.
  - Fix: the far-house walls are now the wall minus the openings, as a grid.
  - The window heads also got their underside face back (the box helper skipped bottoms).
- **Ensuite:** its rect sits inside the master bedroom's. Nested rooms now win in the room lookup and are cut out of the outer room's floor and ceiling (no more z-fighting floor). The build logs exact coplanar overlaps: 0.
- **Smaller fixes:**
  - door thresholds only where no room floor reaches;
  - roof infills start at 27 (no 0.1 overlap with the walls);
  - railings end clear of the newel and the landing wall;
  - sills 0.15 proud;
  - the front door's glass slot is a real cut;
  - fence posts 0.15 proud;
  - tree leaves one tone per mesh;
  - ground to the horizon;
  - architraves cover the door linings;
  - pivots = collision-box centres;
  - teddy / fruit bowl / towel rail lighter.

## Exterior (mobile-safe)
- Big surfaces use own seamless tiling textures (`tex/tile`, made by `tools/make_tiles.py`): grass, asphalt, concrete, render, cladding, brick, siding, fence, hedge, metal roof.
- Small props use plain colours. The 4 cars share one baked atlas. The trees are faceted low-poly in two greens.
- The far houses' windows are real openings: dark glass recessed 0.35 behind the face, with a frame ring.
- Total 20.5k triangles; the largest mesh has 2.1k.

## Upload
- Import 3D with Creator = **Gunsy Funsy** uploads the meshes and their embedded textures (the warehouse 2 method).
- Nothing was imported or uploaded by the modeler. No Studio session was opened.
- The sky images go up as Decals / images under the group, then into a Sky object:
  - `sky_side` for Bk, Ft, Lf and Rt;
  - `sky_up` for Up;
  - `sky_dn` for Dn.
