# Hub sample pass 1, placement in Studio (hub1_place)

Done 2026-10-14 in `Tacticals_rebuild.rbxl` (studio id ab4d44c3-..., the LOCAL copy) only. Not saved (Edward saves).
Nothing touched in the live "tacticals (placeId ...)" studio, the RIVALS place or the replica. No RIVALS asset ids. No computer use.

## Files
| What | Path |
|---|---|
| Placement script (idempotent, UNDO flag) | `fix/place_hub1.lua` |
| Read-only checks (openings, floors, hooks, crane/drone sweep, fidelity) | `fix/check_hub1.lua` |
| Runner (stdio MCP bridge, no HTTP server) | `python tools/run_luau.py fix/place_hub1.lua [UNDO]` (run from tacticals_rebuild) |
| Capture set (9 cameras + top landing) | `python tools/hub1_capture.py before|after [names]` |
| Captures | `out/hub1/before_*.png` (taken before any change), `out/hub1/after_*.png` |
| Before / after sheet (6 cams, before left) | `out/hub1/before_after.jpg` |
| Gates + west stairs + top landing | `out/hub1/after_gates.jpg` (`after_g1_north_gate`, `after_g2_south_gate`, `after_g3_west_stairs`, `after_t1_top_landing`) |

Studio ids change on reload: update `SID` in `tools/run_luau.py` and `tools/hub1_capture.py`.
UNDO was tested (UNDO -> full re-apply round trip: 1,727 instances un-hidden and re-hidden, kit back to `Workspace.hub_r1` and back).

## What was set
**MaterialService** (new folder `MaterialService.TacHub1`; the existing `AssistantMaterials` folder with 8 variants is untouched):

| Variant | Base | StudsPerTile | Pattern | Maps (own uploads, Gunsy Funsy) |
|---|---|---|---|---|
| TacConcrete | Concrete | 12 | Organic | concrete_smooth colour/normal/rough |
| TacConcretePanels | Concrete | 20 | Regular | concrete_panels c/n/r |
| TacRibbed | Concrete | 10 | Regular | corrugated_fine c/n/r |
| TacFloorConcrete | Concrete | 20 | Organic | floor_concrete c/n/r |
| TacCorrugatedMetal | Metal | 16 | Regular | corrugated_metal c/n/r + metalness 0.85 |
| TacFloorPlate | Metal | 20 | Regular | metal_floorplate c/n/r + metalness |
| TacMetal | Metal | 10 | Regular | metal_satin c/n/r + metalness |

Overrides: **Concrete -> TacConcrete, Metal -> TacMetal** (previous values "Concrete"/"Metal" stored as attributes on the folder and
restored by UNDO). Decision: project-wide, as RIVALS does, so every plain Concrete/Metal part in the place (Shop, Armory, Training,
Exfil...) now renders smooth instead of speckled. That changes rooms outside the hub too; check them in the next room passes.

**Per mesh (156 kit MeshParts)**: Color / Material / MaterialVariant per slot from `kit/hub_r1_manifest.json`, Reflectance 0,
CastShadow off on Neon and glass, glass Transparency 0.6, CanTouch false everywhere. Two colour decisions vs the manifest:
- `band_olive` 138,156,74 -> **120,136,66** (read lime in Studio, the step hub1_kit.md proposed);
- `neon_olive` 107,122,58 -> **88,101,48** (Neon brightens; the floor ring and sign outlines glowed lime).
`hazard` base near-black 10,12,10 (the texture carries the cream stripes).

**Texture overlays** (own ids): hazard stripe 4x1 (Top/Front/Back) on every `__hazard`; grate 3x3 tint 76 on `H_Floor__grate`;
grime 4x4 black 0.93 on the four sides of every `__wall_kick`, 0.94 on crates/cases/drums; louvre 0.6x1 black 0.5 on the Bottom of
`H_CeilLights__neon_lamp`; panel lines 20x20 tint 81 (0.35) on the spawn-disc plates; trim strip 8x1 tint 70 on the side faces of the
gate / tunnel-portal / Duels-door reveal metal. In `Hub1.Overlays` (Transparency 1, no collide/query/touch, attribute NotCover):
`LaneN`/`LaneS` (centre runway marking, 27 x 3.2 at y 0.05 between the disc and each gate), `ChevN1/2`, `ChevS1/2` (4x4 cream
chevron decals pointing into the gates), and `SignText_SHOP/ARMORY/EXFIL/DUELS` (SurfaceGui, cream 236,232,218, GothamSSm Heavy,
on the dark H_Signs boards).

**Collision** (89 colliding, 67 not):
- Box: floor field / border / insert, tunnel floor + plate, landing block + deck (flat slabs).
- PreciseConvexDecomposition: everything else that collides (walls with openings, gates, portal, tunnel lining, bays, riser, stairs,
  disc, railings, pilasters, props).
- No collide and no query: every Neon, glass, void, hazard, label, screen, wall_upper/wall_dark (y >= 30), the cornice
  (`H_Wall*__wall_light`) and y36 trims, H_Roof, H_Beams, H_Skylight, H_CeilLights, H_WallLights, H_Signs, H_FloorLines,
  H_Catwalks, H_Bridges (set dressing, no stairs to them).

**Structure**: kit moved to new folder `Workspace.LobbyMap.Hub1`, one Model per piece (`Hub1.H_WallN`, ...). No LobbyMap folder
renamed. `K_Scale1` / `K_Marker1` moved to `ServerStorage._RebuildRemoved` (not destroyed). `Workspace.hub_r1_tex` moved to
`ServerStorage.hub_r1_tex` (keeps the 16 uploaded image ids referenced).

## What was hidden (restorable)
Transparency 1, CanCollide/CanQuery/CanTouch false; Decals/Textures Transparency 1; Lights / ParticleEmitters / Beams / SurfaceGuis
Enabled false. Originals stored per instance as attributes `Hub1_T`, `Hub1_C`, `Hub1_Q`, `Hub1_Tc`, `Hub1_E` + `Hub1Hidden`.
1,727 instances in total:
- `Unique`: all `U_Floor__*`, `U_Ceiling__*`, `U_Braces__*`, `U_Spine__*`, `U_Cables__*`, `U_PodCables__*`, `U_WestWall__*`
  (east tunnel end), `U_GateBulkhead__*` (east upper wall), `U_SpawnDisc__spawn_logo`; from `U_East` only the hub-side pieces
  `panel_metal` (old riser/stair treads), `emit_amber`, `emit_cyan`, `steel`; `U_GateN__emit_amber`, `U_GateS__emit_amber`
  (hub-face strips now inside the new wall).
- `Instances`: all 220 kit modules. `HubProps`: all 24 clusters. `Clutter`: all 24 K_* models (their 6 LobbyCartUI SurfaceGuis disabled).
- `Signs`: `U_Sign_SHOP`, `U_Sign_ARMORY`, `U_Sign_EXFIL`, `U_Sign_DUELS` (folder and names kept; their text now lives on the
  new boards). TRAINING signs untouched.

Deliberately **kept visible**: `U_East__concrete / dark_metal / floor_metal` (one mesh each also carries the Duels floor y16 and the
Duels base walls x < -90), the `U_GateN/S` corridor meshes (the corridor beyond the hub mouth stays as is, hub1_kit.md), everything of
Shop / Armory / Exfil / Duels / EnergyWall.

## Spawn, z-fight, crane, drone, NPC
- `LobbyMap.LobbySpawn`: 1 kept, the 6 duplicates moved to `ServerStorage._RebuildRemoved`. Kept one at (0, 0.7, 0): its 0.2-thick
  bottom sits on the disc top 0.6 (CanCollide false, Transparency 1 as before; original position in attribute `Hub1_OrigPos`).
- Floor-pulse z-fight: the pulses are created by `StarterPlayerScripts.LobbyFX` at a hard-coded y 0.03 (0.06 tall, so the bottom face
  sat on the field top 0.00 and the insert top 0.03 cut through it while it fades). Edited that one constant to **0.08**
  (pulse 0.05..0.11). Done with ScriptEditorService:UpdateSourceAsync, exact-string swap, reversed by UNDO.
- Crane (`Props.Crane`, x 21.25, y 57, z +-34): 41-pose sweep against Hub1 (all parts made queryable for the test) -> **no hits**.
- Drone (`Props.Drone`): at the original loop centre y 22 (+-3) it hit `H_Bridges` (beam/trim/lamp undersides at 24.8-25) on 52 of
  200 poses. Edited the two loop-centre constants in LobbyFX **22 -> 20** (top of model now <= 24.0). Re-sweep: **no hits**.
  The same script edit is reversed by UNDO. (Alternative if Edward prefers scripts untouched: raise H_Bridges by 2.5.)
- `NPC_DuelsOfficer` stood at x -88, half inside the new Duels-door cheek (cheek x -87.8..-95, z 5.8..8.8). Nudged by (+1.6, 0, -0.6)
  to (-86.4, 19.19, 7.9), still on the y16 top landing, facing unchanged; original pivot in attribute `Hub1_OrigPivot` (UNDO restores).

## Hooks verified (fix/check_hub1.lua)
- Folders present: FX, Heli, NPCs, Duels, Exfil, Training, Showroom, Signs, Interact, Props, Unique, Instances, HubProps, Clutter (+ Hub1).
- LobbySpawn count 1, enabled. AssetCheck names `U_Floor__floor_metal`, `U_Floor__grate`, `U_Floor__dark_metal`,
  `U_SpawnDisc__spawn_logo` present (hidden).
- Tags: QueuePad 6, ExfilBarrier 1 (127.5, 6.45, 0, CanTouch on, untouched), RoomLight 29. HatchPoint/CabinPoint ok. 3 OpenPanel
  prompts (Shop, Kit, Kit) intact. NPCs at their spots (DuelsOfficer nudged, above).
- Openings (rays on collision geometry): N and S gates **10.80 wide** (y 1 and 6; 9.40 at y 11.5 = the chamfer haunches), clear
  height **12.15**; tunnel **22.0 x 18.0** at the portal (19.2 inside, 18.3 at the hangar end); Duels door **11.0 x 8.0**.
- Floors: spawn disc 0.52-0.6; hub field 0 / insert 0.03; riser 0 -> 1.33 -> 2.7 -> 4.0 (3 steps); landing 4.0; stairs 4 -> 16 in
  1-stud risers both runs; top landing 16.0; Duels floor 15.92 (old U_East); hangar (112, 0) floor -0.15 (fall catch ok);
  spawn (0, 4, 0) lands on the disc.

## Issues / for the next pass
1. **Old U_East__dark_metal still collides on the top landing** (a ~0.5-stud lip at x ~ -85.5, z -7.5..7.5, top 16.6, visible as a
   dark wedge in `after_t1_top_landing`). It shares one mesh with the Duels hall, so it cannot be hidden alone. Fix when the Duels hall
   is rebuilt, or add an invisible step/ramp. The route stairs -> door (x -86..-90) is clear.
2. LobbyFX hosts tied to the old shell still sit where the old geometry was: `FX.FX4.RunLight` x24 (pod cradles, y 17), `FX2.Thruster`
   x24, `FX3.HullMark` / `SkyWindow` / `FlightHUD` / `Beacon`, `FX.Steam` (z +-44, now in the wall face), `FX.Decals` wall stickers
   at z -43.4. Rule was "FX untouched": re-home or retire them with the next pass.
3. Lights in `LobbyMap.Lights` were not moved; some (SpotLight 69,48,-42; Rim -86,40,+-38) now sit at/inside the new cornice/catwalk
   band. Step 7 of hub1_kit.md (SurfaceLights in lamp strips / wall lights, RoomLight tag + Room attribute) is still to do.
4. The Concrete/Metal overrides change every room. Training (Plastic grid) is unaffected; Shop/Armory/Exfil walls will look smoother.
5. Olive still reads strong at the gate head bands (y 13.2-16.2 block + band); judge in play with Future lighting. Next step down would
   be 112,126,62.
6. Old hub sign models are hidden; the new text is SurfaceGui on the boards (the SHOP/ARMORY text sits on the left 8.5 studs of each
   board because the cream label plate covers the right part).
7. `Lighting.Technology` is still ShadowMap; set Future offline (`tools/set_technology.py`) before judging lighting. Edit-time
   captures are darker than play (RoomFX lights only come on near the camera).
8. The crane now hangs from the new roof beam line x 20.6 (old Gantry track hidden): reads fine at distance.

## Lessons
- execute_luau cannot read `MaterialService.Use2022Materials` (RobloxScript capability); `GetBaseMaterialOverride` works.
- `CollisionFidelity` on MeshParts can be set from the MCP context but applies asynchronously (reads back Default for a moment).
- Decals/Textures render on Transparency-1 carrier parts: easy way to place floor markings and sign text without touching kit meshes.
- A 16x4 lane texture over a 10-wide insert repeats its edge lines 2.6 times (looked like a zebra crossing): size StudsPerTileV to the
  strip width. Decal arrows: arrow pointed along the part's local -X here; rotate the carrier, not the image.
- Hide old shell meshes by **bounds**, not by name: U_East and U_GateN/S also carry rooms outside the hub.
- Sweeping scripted movers (crane/drone) needs the target parts queryable; non-colliding visual parts are CanQuery false, so the
  check script flips CanQuery temporarily and restores it.
- Files edited by tools in tacticals_rebuild are CRLF; Python string patches must normalise line endings.
