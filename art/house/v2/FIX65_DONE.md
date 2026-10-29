# Fix65: closed bases on the dining set and the mudroom bench (modeler, 2026-10-28)

**What was wrong.** Map grade round 3 (blocking, `captures/house/grade_1965_r3/r3_x3_DR_table_crouch.png`): the 1965
dining set stood on open legs inside solid collision boxes (table 2.6, chair seats 1.75, chair backs 3.4). From a crouch you
saw the floor under the table and every chair, while shots stopped on invisible boxes. The style card (Test Site House,
Construction) asks for a closed base on every cover piece. The same check found `H_HallBench_8` (slatted mudroom bench) open
at the front between a toe board and the seat (boots and a bag visible in a cavity inside the 1.65 seat box).
`H_KitchenBench` (booth) and `H_HallBench_3` (telephone bench) were already closed to the floor: unchanged.

**What changed (art only; every collision box, footprint and pivot unchanged).**
- `H_DiningTable`: a floor-length tablecloth in yellowed cream linen with soft pleats and an olive woven hem. It reaches 0.1 above the floor, with brass feet showing in the gap. There is dust on the top and grime at the hem, plus a coffee ring, a blot, a stain on the drop, a burn and a torn hem. The pleats only fold inward, so the cloth stays inside the old 8 x 4 x 2.6 box.
- `H_DiningChair`: the 1960s dinette chair now has a skirted seat: a cream vinyl skirt down to 0.12 and a chrome kick band at 0.08-0.26, with chrome glides. A solid cream kick panel runs from the floor up to the mustard back pad, with chrome back edges and a scuff stain. The mustard seat cushion and back pad keep their exact extents. The back top is 3.392, the same as v1. The only see-through gaps left are the 0.2 slots between neighbouring chairs and the 0.08-0.12 glide gap.
- `H_HallBench_8`: the toe board, boots and bag are gone. The front is now a closed pine panel set 0.05 back from the seat edge, with two battens.
- `H_DiningSet` takes the new table and chairs. `H_TableSetting` is rebuilt unchanged, only re-baked into the new atlas.

## Files
| File | What |
|---|---|
| `fbx/H_Furniture_fix65.fbx` | the changed assemblies at their **kit positions and names** + `K_ScaleCube` (0,40,5) + `K_Marker` (8,40,0), centimetres as the kit |
| `fbx/H_DiningSet.fbx`, `H_DiningTable.fbx`, `H_DiningChair.fbx`, `H_HallBench_8.fbx` | per assembly, pivot at the origin (replaced) |
| `tex/H_Fix65_{color,normal,rough,metal}.png` | the one new atlas for all objects in the fix FBX (1024 / 512) |
| `house_furniture.json` | the 4 entries updated (parts, tris, textures -> H_Fix65), `atlases.Fix65`, a `fix65` block |
| `house_furniture_fix65.blend` | the fix kit (collection `Kit`) |
| `tools/build_fix65.py` | one run (~20 s) rebuilds, bakes, exports and updates the json |
| `tools/crouch_render.py` | crouch-eye (2.4 studs) renders against a floor and a blue wall |

The shapes live in `build_furniture_1965.py` (`dining_table`, `dining_chair`, `pleated_rect`, `hall_bench` slat), so a
full `run_all.sh` gives the same pieces back in the `Dining` / `Storage2` atlases. Note: the `H_Dining_*` atlas in the old
kit FBX still holds the old table/chair texels; the objects in the fix FBX use only `H_Fix65`.

**Objects in H_Furniture_fix65.fbx** (they replace the kit objects one-for-one):
| Assembly | Objects | Kit pivot (Blender) | Tris |
|---|---|---|---|
| H_DiningSet | `H_DiningSet__H_DiningTable`, `H_DiningSet__H_DiningChair`, `...H_DiningChair.001` .. `.005`, `H_DiningSet__H_TableSetting` | (42.2, 0, 0) | 5,520 (was 4,668) |
| H_DiningTable | `H_DiningTable` | (54.2, 0, 0) | 964 (was 328) |
| H_DiningChair | `H_DiningChair` | (63.15, 0, 0) | 448 (was 412) |
| H_HallBench_8 | `H_HallBench_8` | (43.5, -32, 0) | 180 (was 312) |

Unique triangles of the 4 masters (table, chair, setting, bench): 3,460.

## Checks
- `footprint_diff.py`: `cover pieces (incl. variants): 42, differences: 0 (tol 0.005)`, `PASS: every collision box and every cover footprint unchanged`. The dining set's d_size is 0.001 (the chair top was 3.394 in v2 and is 3.392 in v1; now it is 3.392). The table, chair, bench and boxes are 0.000.
- `blender_check.py` per assembly (`check_each.py` on `house_furniture_fix65.blend`, magenta renders in `renders/check/<assembly>/`): **0 FAIL** on all 4. The warnings that remain:
  - A1b on the chairs, the table setting and the bench: concave assemblies with closed shells. The magenta renders show no holes.
  - A8 table + chairs + setting: the chair fronts tuck under the cloth, and the plates stand on the cloth top. These faces sit inside each other or touch; they are not overlays.
- Crouch-eye before / after, saved in `captures/house/1965/`:
  - `fix65_dining_crouch_before_after.png`: three-quarter view.
  - `fix65_dining_front_before_after.png`: from behind a chair row.
  - `fix65_hallbench8_crouch_before_after.png`.
  - The single views (front, back and side for the set and the bench, before and after for KitchenBench and HallBench_3) are in `captures/house/1965/fix65/`.

## For the map builder
Import `H_Furniture_fix65.fbx` and replace the 4 assemblies by object name. Upload the `H_Fix65` atlas and point their
SurfaceAppearance at it. The collision boxes do not change.
