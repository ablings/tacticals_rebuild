# Rooms pass 4 (rooms4): Showroom (Kit-menu camera set, y ~400), Blender kit

Status 2026-10-15: built in Blender 5.2 and exported. **Showroom only.** Mid-task scope change from Edward (via the coordinator):
RIVALS built its shooting range out of Parts (Lobby.ShootingRange is 374 Parts / 70 MeshParts, ~1,180 Parts with the 5x5 grid Texture),
so **Training is built Parts-first in Studio by another agent and is not in this kit.** Nothing in Studio was touched. All geometry
is own work (bmesh, the hub_kit / rooms2 / rooms3 helpers). No RIVALS ids, meshes or images. **No new textures.** Nothing committed.

## Files
| What | Path |
|---|---|
| Kit FBX (in place, world/Studio coordinates) | `kit/rooms4.fbx` (52 meshes: 50 Showroom + 2 markers, 28.1k tris, largest mesh 3.7k `SR_Props__dark_metal`; 0.76 MB) |
| Blender file | `kit/rooms4_kit.blend`: collections `R4_Showroom`, `R4_Markers` (exported); `PV_Proxies` (grey item stand-in on DisplayPoint) is preview-only, **not exported** |
| Manifest | `kit/rooms4_manifest.json`: as rooms3 (piece, material slot, `rgb` = Studio colour, `rgb_kit`, `material_studio`, `variant` + `variant_folder`, `cast_shadow`, `transparency`, `texture_overlay`, tris, size/centre in Studio coords) plus `can_collide` / `can_query` / `can_touch` (all **false** for the Showroom), `not_cover`, `area` |
| Generator | `tools/rooms4_kit.py` (execs rooms3_kit.py -> rooms2_kit.py -> hub_kit.py) |
| Previews | `tools/rooms4_preview.py`; `out/rooms4/bl_*.png` (6 views), contact sheet **`out/rooms4/bl_contact.jpg`**. `bl_cam` = the real Kit-menu view (CameraPoint, vertical FOV 40); `bl_cam_wide` = same camera at FOV 70 (the FOV of the survey capture `cap_showroom_cam.png`) |

Rebuild: open `kit/rooms4_kit.blend` (wm.open_mainfile, never read_homefile), `g={"__name__":"__main__"}; exec(open(".../tools/rooms4_kit.py").read(), g)`;
previews: exec rooms4_preview.py, `setup()`, `render_all()`; export `R4_Showroom` + `R4_Markers` with the hub_export.py FBX settings
(-Z forward, Y up, modifiers applied, FACE smoothing).

The Training builders (perimeter banded walls with sky openings, windowed dividers, hub gantry + TRAINING board, floor/arrival pads,
ceiling with the 12 light homes, 128 cover pieces + exact X_T_ collision boxes from the survey) are still in `rooms4_kit.py` behind
`BUILD_TRAINING = False`. They are **not** in the .blend or the FBX, and were never run (untested). They are only a reference for the Parts build, e.g. the `COVER`
table (each surveyed Arena cover part's box, from the y604 ray slice / 2-stud scan) and the window centres of the four dividers.

## Axes, scale, markers, textures
- Same convention as hub1/rooms2/rooms3: authored in Studio coords, Blender (x, y, z) = (-Xs, Zs, Ys), mesh origin = bounds centre.
  Import 3D with **Insert Using Scene Position**, group Gunsy Funsy, Anchored.
- **`K_Scale4`**: 10-stud cube centred at Studio (0, 120, 0) (Size/10 = import scale). **`K_Marker4`** (Neon L): long arm x 15..25 at
  y 115-117 (+X east), upright at the west end to y 123, short arm toward +Z (z 1..5). Mirrored = axes wrong. After the check, move both to
  `ServerStorage._RebuildRemoved`.
- Every slot uses the TacHub1 variants (`tex/asset_ids.json`) or a flat colour. Two new flat slots: `bench_top` (150,147,140
  SmoothPlastic, no texture, so the Kit menu's fake item shadow reads cleanly) and `range_grey` (Training only, not exported).
- Manifest colours = rooms3's (hub1_place olive + hub2 Future floor compensation). Kit colour is in `rgb_kit`.

## What is in the Showroom (x -31..31, z -19..35, floor top 400, ceiling 427: the surveyed bounds)
Framed for the Kit-menu camera: CameraPoint (0, 407.5, -5) looking at DisplayPoint (0, 406, 8), FOV 40 (Armory.lua `tr.reveal` fov 40).
At FOV 40 the frame is the bench top (lower half), the display bay behind the item, and the wing walls with the racks at the edges.
- `SR_Stage`: **display table on the BenchTop footprint** (x -8..8, z 5..12), **top flat at y 404.2** (= the survey's BenchTop top, used
  by `Armory.UpdateShadow` as `tableTopY`), metal edge band, cream Neon underglow on the camera-facing edge, concrete body with an
  olive datum band, metal plinth; a metal dais disc r 10.5 (top 400.35) with an olive Neon halo; `SR_Lines` cream Neon ring on the floor.
- `SR_Backdrop` (face z 33): RIVALS display wall. Central bay x -11..11 recessed 0.6 with a dark back panel and 2 x 4 metal display
  tiles, two vertical white light slots (x +-9.9), olive Neon outline + floor cove line, concrete pilasters (x +-11..13.4) with capsule
  lights and the olive band, header with band; banded wings (kick, olive band 407.1-409.9, plates, dark band, ribbed upper, cornice).
- `SR_Signs`: label plate on the table front (item name, optional), **sign board in the bay at y 412.4-414.8** (olive Neon frame,
  cream plate for a SurfaceGui "ARMORY" / "KIT"); it sits in the top of the FOV-40 frame, clear of the item (item top ~409.8 at SHOW_FIT 7.5).
- `SR_Props`: rifle racks either side of the bay (x +-14.6..21.6, rooms2 `wall_rack` lifted to y 400), long case + ammo cans (west),
  two crates + can (east), at the frame edges.
- `SR_Shell` side + front walls with piers and capsule lights, `SR_Ceiling` / `SR_Beams` (slab 427, beams x +-12, purlins z 8/22,
  coffers), `SR_Lights` lamp troughs x +-21 and the **fixtures at the light Parts**: pendants at Pendant1-4 (+-4, 413.5, 8.5),
  (-20, 413.5, 12), (20, 413.5, 11), a lamp box at Fill (0, 418.6, 18) and at KeyLight (-3, 414.8, -1). None of them are in the FOV-40 frame.
- `SR_Floor` slab grid with border + metal kerb (top 400).

## Hooks: keep / hide (placement pass, Tacticals_rebuild.rbxl only, File > Save to File only)
| Hook | Action |
|---|---|
| `LobbyMap.Showroom` folder | **Keep the name** (LobbyUIController.Armory looks it up; fallback `Armory`). Parent the kit Models inside it (e.g. `Showroom.Rooms4`). |
| `Showroom.DisplayPoint` (0, 406, 8), `CameraPoint` (0, 407.5, -5), `BenchTop` (x -8..8, top 404.2, z 5..12) | **Untouched, exactly as they are** (position, size, orientation). The kit table top is built at 404.2 on the BenchTop footprint. **Check**: `BenchTop.Position.Y + Size.Y/2` = 404.2 +- 0.05; if not, move the `SR_Stage` model by the difference (do not move BenchTop). |
| `Showroom.KeyLight`, `Showroom.Lights.Pendant1-4`, `Lights.Fill` (RoomLight, Room=Showroom) | **Keep** (RoomFX centre Showroom (0, 410, 8)); the kit fixtures sit at their positions. |
| `U_Showroom__*` (6 MeshParts) and the `Sign` model (U_Sign_ARMORY__*) | **Hide, do not delete** (Transparency 1, CanCollide/CanQuery/CanTouch false, attrs as hub1 with prefix `Rooms4_`). The new sign board takes the SurfaceGui text. |

Per mesh from the manifest: Color = `rgb`, Material = `material_studio`, MaterialVariant = `variant`; **CanCollide false, CanQuery
false, CanTouch false on everything** (never walked; as the old Showroom), attribute `NotCover`; CastShadow false on Neon/glass;
hazard overlay none in this kit. Then K_Scale4 / K_Marker4 check and move to `ServerStorage._RebuildRemoved`.

Verify: open the Kit menu (Play) and screenshot: item centred in the bay, sign board above it, fake shadow lying on the table top
(no z-fighting, no floating), wings and racks at the frame edges, nothing between CameraPoint and DisplayPoint (the kit has nothing at
z < 5 below y 413 except the camera-side floor).

## Known limits / to judge in Studio
- CameraPoint's exact orientation was not in the survey; the previews assume it looks at DisplayPoint (Armory.lua builds the view
  basis from `CameraPoint.CFrame`). If it is level instead, the frame moves up ~1.5 studs at the backdrop: still inside the bay.
- Eevee preview is darker and more contrasty than Studio Future; the room's real look depends on the 6 RoomLight Parts.
- The glossy ceiling coffers reflect the preview sky in `bl_overview` (Eevee screen-space). Not in the game frame.
