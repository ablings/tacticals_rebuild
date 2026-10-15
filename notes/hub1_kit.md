# Hub sample pass 1 (hub1): RIVALS-style shell kit + own textures

Status 2026-10-14: built in Blender 5.2 and exported. **Not yet in Studio** (this pass stops before Studio, per brief_hub1.md).
Nothing in Roblox Studio was touched. All geometry and textures are own work (numpy/PIL + bmesh); no RIVALS ids, meshes or images.

## Files
| What | Path |
|---|---|
| Kit FBX (in place, hub coordinates) | `kit/hub_r1.fbx` (158 meshes, 128k tris) |
| Origin modules for instancing | `kit/hub_r1_props.fbx` (P_Crate4, P_Crate3, P_LongCase, P_Drum, P_Console, P_WallLight + the markers) |
| Blender file | `kit/hub_kit.blend` (collections Shell, Hero_Props, Markers, Kit_Origin (hidden)) |
| Per-mesh manifest | `kit/hub_r1_manifest.json`: name, material, RGB, Studio material/variant, tris, size and centre in **Studio** coords |
| Generator | `tools/hub_kit.py` (geometry + materials), `tools/hub_preview.py` (Eevee cameras/lights), `tools/hub_export.py` (FBX + save) |
| Textures | `tex/hub_*.png` from `tools/make_hub_tex.py`; index `tex/textures.json`; sheet `out/hub1/tex_sheet.jpg` |
| Previews | `out/hub1/bl_*.png` (10 views), contact sheet `out/hub1/bl_contact.jpg` |

Rebuild everything: in Blender `exec(open(r".../tools/hub_kit.py").read())`, then hub_preview (`setup()`, `shot(...)`) and
hub_export (`export_all()`). Never `read_homefile`.

## Axes, scale, markers
- Authored in **Studio coordinates** (x east, y up, z north, 1 unit = 1 stud) and converted to Blender Z-up as
  Blender (x, y, z) = (-Xs, Zs, Ys) (the convention measured in the RIVALS practice; FBX default axes -Z forward, Y up).
  Every mesh's origin is its bounds centre; import with **Insert Using Scene Position**, so the identity places everything.
- **`K_Scale1`**: 10 x 10 x 10 cube centred at Studio (0, 120, 0). Measure its Size after Import 3D; the import scale is
  Size/10 (Import 3D has rescaled before, e.g. x40.56 or x16.5 when a piece is huge; the biggest piece here is the 178-stud wall
  runs / roof slabs, well under 2048, so expect ~1). Divide every placement by that factor if it is not 1.
- **`K_Marker1`** (dark-olive Neon, asymmetric L): long arm 10 studs along **+X (east)** from x 15 to 25 at y 115-117, an
  upright at the **west** end (x 15-17) up to y 123, and a short arm toward **+Z (north)** (z 1..5). Bounds centre
  (20, 119, 2). If the long arm points west or the short arm south after import, the axis mapping is mirrored: fix before placing.
- Delete both markers after the check.

## Pieces (mesh = `<piece>__<material>`, one material each so each MeshPart tints separately)
Triangles per piece (largest single mesh 11.6k, all < 20k). Neon / glass / hazard meshes have no weighted-normal modifier; all other
meshes have a WeightedNormal (face area) modifier applied on export over 0.05-0.4 stud bevels.

| Piece | Tris | Meshes (materials) | What it is |
|---|---|---|---|
| H_WallN / H_WallS | 4.6k each | wall_kick, band_olive, wall_body, wall_plate, wall_dark, wall_upper, wall_light, trim_metal, trim_light, glass | Long walls x -90..88 at z +-44 (5 thick). Zones: kick 0-7 (darker split), **olive band 7.1-9.9** with metal lips, body 10-30 with 2x2 proud plates per bay, dark catwalk band 30-36, ribbed upper 36-52 with sky-slot windows every other bay (thin lamp Neon line in the others), canted cornice 52-58.4 (chamfered curve toward the room), dark top fill to the roof |
| H_Pilasters | 7.5k | wall_light, trim_metal, band_olive, beam_metal | 2.6-wide piers on the 13.75 bay grid (x +-6.875 ... +-75.625, end walls at z +-27.5), bevel 0.3 x2 segments, metal plinth, band wrap, catwalk corbel + knee brace, capital under each roof beam |
| H_WallLights | 11.7k | neon_lamp, trim_metal, dark_metal | RIVALS-manner capsule lights (metal housing, Neon capsule split by two dark straps), centre y 14.2 on every pier, flanking each gate, on the Duels plinth and west wall |
| H_BaysN / H_BaysS | 7.3k each | wall_light, trim_metal, door_leaf, band_olive, dark_metal, label_cream, neon_olive, void, trim_light | Ground bays: **service doors** (frame, 4 slatted leaves, olive stripe across the leaf at 7-10 = the datum, handle, cream label plate, olive status strip, floor hazard kerb) at bays x +-13.75, +-41.25, +-68.75; **vent bays** (louvre grille over a black void + twin pipe run with brackets at y 24-26) at the others |
| H_GateN / H_GateS | 0.8k each | wall_light, trim_metal, band_olive, plate_metal, hazard | Gate portals at x 0: cheeks x +-5.7..9.8 proud 2.6, metal reveal lining so the **clear opening stays 10.8 x 12.2**, chamfer haunches, **olive band across the door head** (y 13.2-16.2), threshold plate + hazard strip |
| H_TunnelPortal + H_Tunnel | 0.7k + 1.4k | wall_light, band_olive, trim_metal, plate_metal, door_leaf (corrugated), beam_metal, neon_lamp, neon_cream, floor_border | East portal (clear **22 x 18**, band across the head at 19.6-22.6) and tunnel lining x 88..104: corrugated cladding walls, 4 ring frames, ceiling at 19.2, two lamp strips, cream lane lines, olive band, end frame at the hangar side |
| H_WallE | 1.8k | as long walls | East wall either side of / above the tunnel |
| H_WallW + H_DuelsDoor | 2.1k + 0.5k | as walls + hazard | West wall (face x -90) above the landing; Duels door portal **11 wide x 8 clear (y 16-24)**, band across its head, threshold hazard, label plate. The wall band is re-based to 19-22 (3-6 above the y16 deck) |
| H_Riser | 0.5k | stair, trim_metal (nosings), dark_metal (grip), plate_metal (treads), wall_kick (side kerbs), neon_cream | 3 equal steps 0 -> 4 at x -78..-72, z -8..8 |
| H_Landing | 1.4k | stair, plate_metal, trim_metal, wall_kick, neon_cream, trim_light | Landing block y 4 at x -90..-78 full length, metal deck, edge cap, cream Neon line on the front face, guard railing (gap at the riser) |
| H_Stairs | 4.6k | stair, plate_metal, trim_metal, beam_metal, trim_light, band_olive | Twin runs x -90..-86, y4 at z +-40 -> y16 at z +-10 (12 x 1-stud risers, 2.5 going), metal nosings, sloped stringers, handrails; top landing y16 x -90..-84, z -10..10 with railing; plinth face carries the hub band and the DUELS sign board |
| H_Floor | 2.4k | floor_field, floor_border, floor_insert, trim_metal, grate, hazard | Slabs per bay (3 bands in z) with 0.3 dark joints, 3-wide darkest border along the walls with a metal kerb strip, corrugated-metal lane inserts N/S (x +-5.4) and E/W (z +-6), four drain grates on the diagonals, service-door hazard kerbs |
| H_FloorLines | 1.0k | neon_cream, neon_olive | Cream Neon runway lines (0.38 wide, top 0.07) both sides of every lane; dark-olive Neon ring segments (r 15.6-16 and short ticks at r 17) round the centre (RIVALS gold-ring role) |
| H_SpawnDisc (hero) | 8.1k | floor_border, plate_metal, neon_olive, disc_plate, neon_cream, disc_center, dark_metal | r 13.7 stepped base (top 0.3), metal ring r 10.9-12.15 (top 0.6) with 36 dark tick inlays and 4 cream landing-light studs on the lanes, recessed dark-olive Neon ring, 12 floor-plate sectors with gaps, cream Neon inner ring r 4.2-4.6, dark-olive centre plate with 4 cream Neon arrowheads pointing to the four exits. Top 0.6 as before |
| H_Roof | 3.3k | ceiling, ceiling_gloss, trim_metal | Roof slab y 68-73 round a **skylight** (x +-27.5, z +-20.6); glossy olive-grey coffer panels with metal lips between beams and purlins |
| H_Beams | 9.0k | beam_metal | I-section roof beams on every pier line (flanges, web, stiffeners every 8, haunch brackets into the cornice), two purlins at z +-24 |
| H_CeilLights | 1.5k | trim_metal, neon_lamp | Recessed lamp strips per bay under the purlins (y 63.7) |
| H_Skylight | 0.7k | trim_light, beam_metal, glass, neon_olive | Curb, mullion grid, glass at y 73.9, olive Neon line round the well |
| H_Catwalks | 5.4k | plate_metal, beam_metal, trim_metal, neon_lamp, trim_light | y 31 decks along both long walls (z +-40..44), fascia, kick plate, posts every 3.4 + top/mid rails, lamp Neon under the fascia per bay |
| H_Bridges | 7.8k | plate_metal, beam_metal, trim_metal, trim_light, dark_metal, neon_lamp | Bridges at x +-49, deck y 27, side stringers, cross members, railings, hanger rods to the roof beams, lamp Neon under the deck |
| H_Signs | 0.8k | sign_board, neon_olive, label_cream | Dark sign boards with dark-olive Neon outlines over the N/S gates (y 18.6-23), the tunnel (y 25.2-29.6) and on the Duels plinth (y 10.6-14.6); cream label plates. **Text goes on with SurfaceGuis in Studio** (cream, one font) |
| H_Props | 30.3k (10 meshes, max 11.6k) | crate_green (65,94,56), dark_metal, label_cream, drum_olive, case_dark, beam_metal, trim_metal, screen, neon_cream, neon_olive | Placed clusters (|z| 33-39 against the walls, by the tunnel, on the landing): military crates 4 and 3 (frame + inset panels + stencil plates), long weapon cases (split lid, ribs, olive latches), ribbed drums, two ops consoles (slanted desk, screen with cream Neon edge, olive/cream keys). Lanes and the disc stay clear |
| K_Scale1 / K_Marker1 | | | see above |

## Colours and Studio material per material slot
(From `MATS` in hub_kit.py; same as the manifest. Variants are the ones to create from tex/textures.json.)

| Slot | RGB | Studio |
|---|---|---|
| floor_field / floor_border | 62,62,60 / 36,36,34 | Concrete + TacFloorConcrete |
| floor_insert | 80,79,76 | Metal + TacCorrugatedMetal |
| plate_metal / disc_plate | 108,107,104 / 75,75,72 | Metal + TacFloorPlate |
| wall_body / wall_plate | 107,106,102 / 102,101,97 | Concrete + TacConcretePanels |
| wall_light / wall_kick / wall_dark / stair / ceiling | 120,119,115 / 88,87,83 / 79,78,74 / 94,93,89 / 112,111,107 | Concrete + TacConcrete |
| wall_upper | 141,140,134 | Concrete + TacRibbed |
| band_olive | 138,156,74 | Concrete + TacConcrete (olive) |
| trim_metal / trim_light / beam_metal / dark_metal | 108,107,104 / 124,123,119 / 67,67,65 / 48,48,46 | Metal + TacMetal |
| door_leaf | 72,72,70 | Metal + TacCorrugatedMetal |
| ceiling_gloss | 66,68,62 | SmoothPlastic (pearlescent-style) |
| neon_lamp / neon_cream / neon_olive | 161,157,145 / 180,177,166 / 107,122,58 | Neon (test 107,122,58 for a lime cast) |
| void | 10,12,10 | Neon (black) |
| glass | sky | Glass, Transparency ~0.6 |
| label_cream / sign_board | 236,232,218 / 39,40,37 | SmoothPlastic (+ SurfaceGui text) |
| hazard | white | SmoothPlastic + Texture hub_hazard_stripe (4 x 1) |
| grate | 22,23,21 | SmoothPlastic + Texture hub_grate_alpha (3 x 3, tint 70-80) |
| crate_green / case_dark / drum_olive / screen | 65,94,56 / 48,49,46 / 107,122,58 / 18,22,20 | SmoothPlastic / Metal / Glass |

## Textures (tex/, own, procedural, seamless, 512-1024 px; full list with uses and StudsPerTile in tex/textures.json)
Smooth concrete (colour/normal/rough, 12 spt), concrete panels with offset seams and bolts (20), corrugated metal sheet with metalness
(16), fine corrugation normal-only (10), metal floor plate with tread inserts (20), sealed floor concrete with saw cuts and trowel
roughness (20), satin brushed metal (10) + `hub_metalness_085.png`; overlays: panel lines (20 x 20), training grid (5 x 5), bar grate
alpha (3 x 3) + normal, trim strip (8 x 1), grime (4), hazard stripe cream/near-black (4 x 1), runway lane marking (16 x 4), chevron
decal, ceiling louvre. Colour maps are near-white so Part colour sets the tone (replica lesson).
UVs on the meshes are box-projected at **1 UV unit = 10 studs** (world scale). In the Blender previews each material's mapping is
scaled by 10 / StudsPerTile. **Check in Studio** how MaterialVariant StudsPerTile scales on these MeshParts (read back one wall and
one floor at player height); if the tiling is off, change StudsPerTile, not the UVs.

## How the kit maps to the current hub parts (layout.md / hooks.md names)
| Current | Replaced by |
|---|---|
| Unique `U_Floor__*` (floor_metal, grate, panel_metal, dark_metal) | H_Floor, H_FloorLines |
| Unique `U_SpawnDisc__spawn_logo` | H_SpawnDisc |
| Unique `U_Ceiling`, `U_Braces`, `U_Spine`, `U_Cables`; Instances `Gantry`, `Strip_*`, `TopFill_*`, `OverBig_*`, `OverSmall_*` | H_Roof, H_Beams, H_Skylight, H_CeilLights, cornice/top fill in H_Wall* |
| Instances ground `GShop_*`, `GDoor_*`, `GVent_*` | H_BaysN/S |
| Instances `Cradle_*`, `PodBand_*`, `PodBarrel*`, `PodCap*`, `PodHead*`, `Pier_*`, `UPanel_*`, `UWindow_*`, `UMachine_*`, `Pipe_*` | H_WallN/S zones, H_Pilasters, H_WallLights, vent-bay pipes |
| Instances `Catwalk_*` (+NDoor/SDoor), `Bridge` x2 | H_Catwalks, H_Bridges |
| Unique `U_GateN`, `U_GateS` (hub mouth part only) | H_GateN, H_GateS. The corridor beyond z +-49 stays as is |
| Unique `U_WestWall` (= EAST end, tunnel) | H_TunnelPortal, H_Tunnel, H_WallE |
| Unique `U_East` (= WEST end: riser, landing, stairs, duels base wall) | H_Riser, H_Landing, H_Stairs, H_WallW, H_DuelsDoor (Duels hall itself not in this pass) |
| HubProps `Cluster_x_z`, Clutter `K_*` | H_Props (placed) / hub_r1_props.fbx modules |
| Signs SHOP/ARMORY/EXFIL/DUELS models | keep the Signs folder; mount their text on the H_Signs boards (SurfaceGui) |

## What the placement script must do (next pass, in Tacticals_rebuild.rbxl only)
1. Import `kit/hub_r1.fbx` (Import 3D, group Gunsy Funsy, Insert Using Scene Position, Anchored). Measure `K_Scale1` and
   `K_Marker1`; correct scale/axes if needed; delete them.
2. Parent the new meshes under `Workspace.LobbyMap.Unique` (or a new `LobbyMap.Hub1` folder) **without renaming any LobbyMap
   folder**. **Hide, do not delete** the old shell meshes: Transparency 1, CanCollide false, CanQuery false, CanTouch false on the
   replaced `Unique/` meshes and `Instances/` models in the table above (keep them for rollback). Keep `U_SpawnDisc__spawn_logo` and
   the four AssetCheck names present (hidden) so AssetCheck does not report MISSING.
3. Materials: create the MaterialVariants from tex/textures.json (upload images under Gunsy Funsy), set MaterialService overrides
   Concrete -> TacConcrete, Metal -> TacMetal; per mesh set Color + Material + MaterialVariant from `kit/hub_r1_manifest.json`.
   Neon meshes Material Neon; add the Texture objects (hazard, grate, lane marking, louvre on lamp strips).
4. Collision: CanCollide true (PreciseConvexDecomposition or Box where boxy) on floors, plate decks, riser/landing/stairs, walls
   (kick/body/plates/pilasters/gate cheeks/portal), service-door frames, landing and stair railings, props. CanCollide false on every
   Neon, glass, ceiling/roof/beams/skylight, ceiling lights, wall lights, signs, cornice and upper zones above y 36, bridge rods.
   Catwalks/bridges are set dressing (no stairs to them): collide is optional.
5. Keep every hook from hooks.md: `LobbyMap.LobbySpawn` (delete the 6 duplicates; **raise it to y ~0.65** so it sits on the disc
   top 0.6), fall-catch SPAWN (0,4,0) and HANGAR (112,3.5,0) stay walkable, `LobbyMap.FX` / `Heli` / `NPCs` / `Duels` / `Exfil` /
   `Training` / `Showroom` / `Signs` / `Interact` untouched, Shop/Armory openings 10.8 x 12.2 and the 22 x 18 tunnel and 11 x 8 Duels
   door unchanged (verify with rays), ExfilBarrier untouched, NPC_DuelsOfficer at (-88,19.2,8.5) stands on the new top landing (y16).
6. LobbyFX conflicts to check: its 12 floor pulse parts at y 0.03 (x +-27..85, z +-6) sit exactly on the E/W lane insert top (0.03):
   raise the pulses to ~0.08 or drop the insert. `Props.Crane` sweeps at y 57 (clear of the cornice only at |z| < 40) and
   `Props.Drone` loops at y ~22 under the bridges (bridge bottom 24.8): check both still clear. LobbyFX also flickers
   `K_GShop__emit_amber` / `K_PodHead*__emit_cyan`: hidden old meshes are harmless; if deleted later, make sure it uses FindFirstChild.
7. Lighting per rivals_style.md 4.4; SurfaceLights inside the lamp strips and wall lights; a few shadowed warm spots on the disc.
   Room lights must carry the `RoomLight` tag + `Room` attribute or RoomFX leaves them off.

## Known limits / to judge in Studio
- Olive band 138,156,74 reads slightly lime under a bright warm key in Eevee; judge in Studio and step toward 120,136,66 if needed.
- Floor in the previews is lit by strong fill and reads lighter than RIVALS'; the Studio pass sets value by rendered pixels.
- Sky shows through the gate corridors and the tunnel in the previews only because those rooms are not in the Blender scene.
- Duels hall, energy wall, shop/armory interiors and hangar are not in this pass.
- Haunch prisms smooth-shade a little round under weighted normals (reads as a rolled haunch); fine at distance.

## Texture upload FBX (for Import 3D under Gunsy Funsy)
- `kit/hub_r1_tex.fbx` (12.3 MB, textures **embedded**): **16 texture sets**, one 4 x 4-stud quad each named `TX_<name>`, laid in a
  grid at Studio y 200 (x 200..218, z 0..18), away from the hub. Each quad's Principled material is wired to its images so Import 3D
  makes a SurfaceAppearance per quad: 7 PBR sets (concrete_smooth, concrete_panels, floor_concrete, corrugated_fine: colour + normal +
  roughness; corrugated_metal, metal_floorplate, metal_satin: + metalness `hub_metalness_085.png`) and 9 overlay/decal sets (colour
  only, alpha wired where the PNG has alpha; grate_alpha also carries its normal). All images <= 1024 px.
- `kit/hub_r1_tex_map.json`: quad name -> files per slot, intended MaterialVariant / Texture use, StudsPerTile, quad position.
  After import, read each quad's SurfaceAppearance ColorMap/NormalMap/RoughnessMap/MetalnessMap ids, build the MaterialVariants and
  Texture objects from them, then delete the quads.
- Verified by re-importing the FBX into a scratch Blender scene (since removed): all 16 quads came back with every map linked and
  packed at full size. Generator: `tools/hub_tex_fbx.py` (`build()`, `verify()`); quads live in the `TexQuads` collection of
  hub_kit.blend.
