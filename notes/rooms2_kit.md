# Rooms pass 2 (rooms2): Shop + Armory + corridors, Blender kit

Status 2026-10-15: built in Blender 5.2 and exported. **Not in Studio** (brief_rooms2.md: Blender only). Nothing in Roblox
Studio was touched. All geometry is own work (bmesh, hub_kit.py helpers); no RIVALS ids, meshes or images. No new textures.

## Files
| What | Path |
|---|---|
| Kit FBX (in place, world/Studio coordinates) | `kit/rooms2.fbx` (214 meshes, 128.8k tris, largest mesh 7.0k; 3.1 MB) |
| Blender file | `kit/rooms2_kit.blend`: collections `R2_Shell`, `R2_Hero`, `R2_Props`, `R2_Markers` (exported) and `HubContext` (the hub1 kit, for previews only, **not exported**) |
| Manifest | `kit/rooms2_manifest.json`: per mesh name, piece, material slot, `rgb` (Studio colour), `material_studio`, `variant` (+ `variant_folder` = MaterialService.TacHub1), `can_collide`, `collision_fidelity`, `cast_shadow`, `transparency`, `texture_overlay`, tris, size/centre in Studio coords |
| Generator | `tools/rooms2_kit.py` (execs hub_kit.py's helpers, so materials, bevels, UVs and the axis conversion are identical to hub1) |
| Previews | `tools/rooms2_preview.py`; `out/rooms2/bl_*.png` (15 views), contact sheet **`out/rooms2/bl_contact.jpg`** |

Rebuild: open `kit/rooms2_kit.blend` (wm.open_mainfile, never read_homefile), then
`g={"__name__":"__main__"}; exec(open(".../tools/rooms2_kit.py").read(), g)`, previews with rooms2_preview (`setup()`, `render_all()`),
export selection of the four R2_ collections with the same FBX settings as hub_export.py (-Z forward, Y up, modifiers applied).

## Axes, scale, markers (same convention as hub1)
- Authored in Studio coords, Blender (x, y, z) = (-Xs, Zs, Ys); each mesh origin = its bounds centre. Import 3D with
  **Insert Using Scene Position**, group Gunsy Funsy, Anchored.
- **`K_Scale2`**: 10-stud cube centred at Studio (0, 120, 0). Import scale = Size/10; divide placements by it if not 1.
- **`K_Marker2`** (Neon L): long arm x 15..25 at y 115-117 (+X east), upright at the west end to y 123, short arm toward +Z (z 1..5).
  If the long arm points west or the short arm south, the axes are mirrored. Delete both after the check.
- **Texture carrier: not needed.** Every material uses the already-uploaded TacHub1 variants (tex/asset_ids.json) or a flat colour.
  Optional Texture overlays use existing ids: `TX_hazard_stripe` (4x1, Top) on every `__hazard`, `TX_louvre` (0.6x1, black 0.5,
  Bottom) on `*_Lights__neon_lamp` strips, `TX_grime_overlay` (4x4, black 0.93) on `__wall_kick`, `TX_overlay_panel_lines` (20x20,
  tint 81) on the plinth/dais `disc_plate`.

## Footprints kept (from layout.md, slice_y4.json, plan_shop/plan_armory; within ~1 stud of the survey)
| Space | Interior | Ceiling | Opening |
|---|---|---|---|
| North corridor `C_CorrN` | x -5.4..5.4 (ring frames 4.9 -> **9.8 clear**), z 49..64 (hub wall back face -> shop door wall) | frames 12.2 (**12.2 clear**), lining 13.0 | |
| Shop doorway `S_Door` | through z 64..69 | | **11.0 wide** (x +-5.5) x 12.2, corner haunches above 11.2 |
| Shop | x -30..30, z 69..110.5, floor 0 | **13.5** (beams 12.5) | |
| South corridor `C_CorrS` | as north, z -64..-49 | 12.2 | |
| Armory doorway `A_Door` | through z -67..-64 | | **11.0** x 12.2; olive band across the head |
| Armory | x -31..31, z -112.5..-67, floor 0 | **22** (beams 19.8) | |

The hub-side gate mouths (H_GateN/S) are from hub1 and unchanged. Corridor floor top 0 (plate) replaces the old grate at -0.8..0.

## What is in each room (pieces = `<piece>__<material>`)
Same banded language as the hub: dark slab floor with darkest border + metal kerb, wall kick 0-7 (darker split, proud panels),
**olive band 7.1-9.9** with metal lips wrapping every pier, door cheek, rack frame and the gun wall, concrete piers with metal
plinths/capitals carrying I-beams, glossy coffers with recessed lamp strips, capsule wall lights on piers, cream Neon lane lines
from each doorway, dark-olive Neon rings round the hero piece, cream hazard strips at thresholds/counters, military-green crates.

**Shop (ceiling 13.5)** - `S_Walls`, `S_Piers` (small capsule lights at y 11.15), `S_Door`, `S_Floor` + `S_Lines` (corrugated lane
insert z 69..81 with cream lines, cream + olive Neon rings round the plinth), `S_Ceiling` / `S_Beams` / `S_Lights` (beams on x +-10,
+-20, purlins on z 79.5/90/100, 6 lamp strips, 4 round downlight housings), **`S_Plinth`** featured item plinth at (0, 88): stepped
ring base, olive Neon ring, metal ring with tick inlays, column with cream Neon band, cradle + featured rifle, 4 cream-capped
stanchions. **`S_Counter`** service counter x -10..16, front face z 100.6, top 3.75: kick, 10 front panels with metal ribs, olive
stripe, cream emblem plate (x 7), two terminals, end returns, staff deck plate behind. `S_Shelves`: storage shelving with stock
(back wall x -18.8..-11.2, 11.2..18.8, low unit -8.6..1.4) + 3 lockers behind the NPC (x 2.6..8.75). `S_Displays`: proud display
cases on both side walls (stock west, rifles east) + 3 pedestals at x -18 (z 79, 85.5, 92). `S_Racks`: two double-sided rifle
racks at x 22 (z 78..84, 88..94). `S_Signs`: dark board with olive Neon outline over the counter bay (x -6..6, y 10.3..12.05) + cream
label plate. `S_Props`: crate/drum/case stacks in the corners.

**Armory (ceiling 22)** - `A_Walls` (kick, band, panelled body 10-15.5, dark band, ribbed upper 16.6-20.2 with lamp lines, cornice),
`A_Piers` (full RIVALS capsule lights at y 13.4), `A_Door`, `A_Floor`/`A_Lines`, `A_Ceiling`/`A_Beams`/`A_Lights` (2.2-deep beams on
x +-10.33, +-20.67, purlins on z -78.4/-89.75/-101.1, 6 lamp strips, L_Fill pendant, gun-wall washer bar). **`A_GunWall`** back wall
x -16.6..4.1, y 0..15: concrete frame with band wrap, light panelled back, battens, 3 peg rails x 4 rifles with cream tags, lamp
line under the head, sign board above (y 15.6..18.6) and a metal floor mat + hazard in front. **`A_Dais`** featured display at
(-10, -96): stepped ring base, olive + cream Neon rings, 8 floor-plate sectors, tick inlays, dark-olive centre cap (top 1.32),
4 stanchions, and the hood above (y 18.5..19.6) on rods. **`A_Supply`**: raised deck (top 1.0) x 4.6..18.6, z -112.5..-107.6,
counter x 5..18.6 front face z -105 (top 3.75) with terminal + emblem, shelving x 12.4..18.4, two lockers, SUPPLY sign board
(x 5.6..17.6, y 10.7..12.9). `A_Racks`: wall rifle racks in the two middle bays of both side walls. `A_Benches`: two workbenches
with olive drawer units, rifle + can on top and a task lamp. `A_Displays`: glass-topped weapons case x 2..12.5, z -97.4..-94.6.
`A_Props`: crate/drum/case stacks in the four corners.

Sign text goes on with SurfaceGuis in Studio (cream 236,232,218, GothamSSm Heavy, as hub1): SHOP board "SUPPLY", ARMORY board over
the gun wall "ARMORY", supply board "SUPPLY". (Which word goes where depends on Edward's NPC swap decision; boards are blank.)

## Hooks: current position -> home in the new layout
| Hook | Now | New home / action |
|---|---|---|
| `NPCs.NPC_Quartermaster` (OpenPanel=Kit) | (10, 0, 106.7) | **Unchanged.** Stands behind the counter on the staff deck (plate top **0.06**: raise the model 0.06 or leave the 0.06 sink). Lockers behind it end at z 109.4. |
| `Interact.Shop_Counter` (OpenPanel=Shop, 4x4x4) | (3, 3, 101.8) | **Unchanged**; now inside the counter body (front face z 100.6). Reach is from the front. |
| `Rooms.Shop.CounterEmblem` | (5..9, 1..3, 103) | Inside the counter now: move to the cream emblem plate on the counter front (7, 1.65, 100.3) facing -Z, or hide. |
| `NPCs.NPC_Supply` (OpenPanel=Shop) | (7, ~1, -110.6) | **Unchanged.** Stands on the supply deck (top **1.0**); counter in front (z -105..-107.6); lockers behind end at z -111.6. If its feet are not at 1.0, pivot it to the deck top. |
| `Interact.GunWall_Kit` (OpenPanel=Kit) | (0, 6, -110.5) | **Unchanged**; just in front of the gun wall face (z -110.6) at its right third. |
| `Interact.Armory_Dais` (OpenPanel=Kit) | (-10, 2.5, -96) | **Unchanged**, over the dais centre. |
| `Rooms.Armory.FeaturedScissors` (Spin) | (-10, 2..5, -96) | **Unchanged**; floats over the dais centre cap (top 1.32). Keep the `Spin` attribute and the folder path. |
| RoomLight `L_Entry` (Shop) | (0, ~11.5, 74) | (0, 12.6, 74) under the downlight housing |
| RoomLight `L_Counter` (Shop) | (4, ~11.5, 97) | **(0, 12.6, 97)** (moved 4 west: a lamp strip runs at x 5) |
| RoomLight `L_Pedestals` (Shop) | (-18, ~11.5, 85) | (-17.5, 12.6, 85) |
| RoomLight `L_Racks` (Shop) | (22, ~11.5, 86) | (22, 12.6, 86) |
| RoomLight `L_Dais` (Armory) | (-10, ~19, -96) | (-10, 18.3, -96) just under the hood's lamp ring, pointing down |
| RoomLight `L_GunWall` (Armory) | (0, ~17.5, -106) | (-6, 17.0, -106) under the washer bar (gun wall centre is x -6.25) |
| RoomLight `L_Fill` (Armory) | (0, 14, -90) | (0, 13.8, -90) under the pendant housing |
| RoomLight `L_BenchA` / `L_BenchB` | (12, ~8.5, -83) / (20, ~8.5, -87) | (12, 6.0, -83) / (20, 6.0, -87.5) under the bench task-lamp heads (head y 6.2) |
All L_* keep tag `RoomLight` + attribute `Room` (Shop / Armory); RoomFX centres Shop (0,6,89) and Armory (0,8,-91) are inside the
new rooms (radius 75), so nothing in RoomFX changes. Optionally add SurfaceLights inside the lamp strips (tagged the same way).

## What the placement script must do (next pass, Tacticals_rebuild.rbxl only, File > Save to File only)
1. Import `kit/rooms2.fbx` (Import 3D, Gunsy Funsy, Insert Using Scene Position, Anchored); check `K_Scale2` / `K_Marker2`, then move
   them to `ServerStorage._RebuildRemoved`. Parent the meshes under a new `Workspace.LobbyMap.Rooms2` (one Model per piece). Do not
   rename `LobbyMap.Rooms`, `Rooms.Shop`, `Rooms.Armory`, `Interact`, `NPCs`.
2. Per mesh from the manifest: Color = `rgb` (band_olive already 120,136,66 and neon_olive 88,101,48 = the hub1_place decisions),
   Material = `material_studio`, MaterialVariant = `variant` (from MaterialService.TacHub1; empty = plain, the Concrete/Metal overrides
   apply), CastShadow false on Neon/glass, glass Transparency 0.6, CanTouch false everywhere, Texture overlays as listed above.
3. Collision from the manifest (149 of 214 collide): Box on the floor slabs / plates / inserts; PreciseConvexDecomposition on walls,
   piers, door portals, corridor lining, counters, supply deck, plinth, dais, racks, shelves, displays, benches, props. No collide (and
   CanQuery false) on every Neon, glass, label, screen, sign board, hazard, ceiling / beams / lights / lines pieces.
4. **Hide, do not delete** (Transparency 1, CanCollide/CanQuery/CanTouch false, attrs as hub1 `Hub1_*` but prefix `Rooms2_`):
   - `Unique.U_Shop__*` and `Unique.U_Armory__*` (all; check by bounds that nothing outside x -35..35, |z| 64..116 shares those meshes).
   - The corridor parts of `Unique.U_GateN__*` / `U_GateS__*` (hub1 left them visible). They are shared meshes with the hub mouth:
     hide by **bounds** (whole mesh inside |x| < 8, 44 < |z| < 66), as in hub1's lesson.
   - `Rooms.Shop`: K_MilCrate x2, K_AmmoCan x2, K_Pallet, K_WeaponCase, K_Drum (and CounterEmblem unless moved).
   - `Rooms.Armory`: `WeaponsDisplay` (all 105), K_WeaponCase x2, K_AmmoCan x2, K_MilCrate x2, K_Drum.
5. **Keep**: `Rooms.Shop.L_*`, `Rooms.Armory.L_*` (move to the homes above), `Rooms.Armory.FeaturedScissors`, all of `Interact`
   and `NPCs`, `Signs` (hub-side SHOP/ARMORY text already on the hub boards).
6. Verify with rays (as check_hub1.lua): corridor 9.8 clear at the frames / ~10.3 between them (kick panels), 12.2 high; doorways 11.0 x 12.2; shop
   floor 0 and ceiling 13.5 (beams 12.5); armory floor 0, ceiling 22; supply deck 1.0; walk spawn -> N gate -> shop counter and
   spawn -> S gate -> gun wall / dais / supply counter; every prompt within its MaxActivationDistance from the walkable floor.

## Known limits / to judge in Studio
- Olive reads lime in the Eevee previews (they use the hub's 138,156,74 material); Studio gets 120,136,66 from the manifest.
- Preview floors read lighter than RIVALS' because of the strong preview fill; set value by rendered pixels in Studio.
- Rifles are stylised own models (stock, grip, receiver, mag, handguard, barrel, optic; ~200-260 tris each)
  (A_Racks is the heaviest mesh family, 14.7k over 7 meshes, max 7.0k).
- Survey walls were read from a 1-stud slice; shop/armory faces may be off by up to ~1 stud from the old meshes. Check the old
  U_Shop/U_Armory outer faces after hiding (nothing should poke through the new walls).
- The gun wall covers the back-wall pier line at x -10.33 (a metal corbel carries the beam above it).
- The corridor ring-frame haunches narrow the corridor above y 10.9 (as the hub gate haunches do).
