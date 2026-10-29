# House illusion pass: modeler deliveries (2026-10-29)

Work order: the world outside the House windows (brief `briefs/map-house-illusion.md`, kit `briefs/kit-house-illusion.json`).
Rebuild in one go: `python tools/make_tex.py` (system Python: numpy, PIL, scipy) then
`blender -b --factory-startup --python tools/build_illusion.py` (Blender 5.2; `-- --part far,near,mid` for a subset).
Checks: `tools/check_far.py` (360-degree sky-leak rays), `tools/check_spread.py` (kit `blender_check.py` with the mid pieces
spread apart), `tools/verify_fbx.py` (FBX read-back), `tools/preview.py` (renders). Manifest of every object (tris, bbox,
origin, material, texture, fallback colour): `house_illusion.json`. Source: `house_illusion.blend`.

## Import notes (all three files)
- FBX in cm like v2: **Import 3D at scale 0.01**, then measure `K_ScaleCube` (10 studs) and check `K_Marker` (long arm +X,
  short arm +Y in Blender), delete both. Blender (x, y, z) -> Studio (-x, z, y), same as `H_Exterior` / `H_House`.
- All art: Anchored, CanCollide / CanQuery / CanTouch off, CastShadow off (Near pieces may keep shadows). No lights, scripts, particles.
- **One material per object, every surface textured** (Import 3D keeps a TextureID). If a texture is dropped, `fallback_rgb`
  in the manifest is the average colour under that object's UVs.
- **X_ChainLink needs alpha:** move its TextureID into a SurfaceAppearance (ColorMap = the image, AlphaMode = Transparency),
  or the mesh draws as solid grey squares (vault Model Proof Check B10).
- Near pieces reuse four v2 tiles (`T_Concrete65`, `T_TrimWhite`, `T_Shingle`, `T_Gravel65`: the same images as the v2
  exterior, so the uploaded v2 ids can be reused). The UVs are in world studs / tile size like v2.
- New textures (6, all 1024 or less, own procedural art): `tex/X_Ground.png`, `X_Mesa.png`, `X_Town.png`, `X_Site.png`,
  `X_ChainLink.png` (RGBA 512), `X_Near.png`.

| # | File | Objects (MeshParts) | Tris | Placement | Notes |
|---|---|---|---|---|---|
| 1 | `fbx/X_Far.fbx` | 40 `X_Skirt_<band>_<nn>` (ground ring r 850 -> 4,000), 12 `X_Mesa1_<nn>` (23 buttes / mesas / eroded hills, r 1,180-1,320, h 60-180), 12 `X_Mesa2_<nn>` (ridge band r 1,800-2,200, h 150-320), 12 `X_Mesa3_<nn>` (range r 2,850-3,400, h 250-520) | 5,442 (skirt 1,408, ring 4,034) | **Plan place, origin = plan origin**: same pivot / CFrame as the v2 `H_Exterior` | Largest MeshPart 1,680 studs. Skirt z -1.05 at r 850 (under the v2 1,800 square at -1), drops to -1.95 by r 1,000 so the overlap never z-fights, then to -6 at r 4,000. Mesa bases sunk 12-15 under the skirt. Ring tiers 2 / 3 are continuous (no ends) and face the centre only. Sight check from 7 window eyes, 1,440 azimuths each, -3 to 14 deg: **0 rays miss below the skyline** (`renders/far_sightcheck.json`) |
| 2 | `fbx/X_Near.fbx` | `X_PorchFront_Concrete65 / _TrimWhite / _Shingle`, `X_BackStoop_Concrete65`, `X_BackStoop_Props` (rail, doormat, milk crate), `X_Driveway`, `X_FoundationStrip_Gravel65` | 226 | **Plan place, origin = plan origin** (as `H_Exterior`) | See "Near: heights" below |
| 3 | `fbx/X_Mid.fbx` | `X_TownHouse_A_<Butter/Salmon/Mint/White>`, `X_TownHouse_B_<Butter/Salmon/Mint/White>`, `X_WaterTower`, `X_Bunker`, `X_Quonset`, `X_ObservationStand`, `X_ChainLink`, `X_PoleLine` | 6,522 (one of each) | **All at the origin; pivot = bottom centre on the ground (z 0 = the ground under the piece), front = Blender -Y** (Studio -Z after the axis swap). Clone and place | Colourways are separate meshes sharing `X_Town` (UVs per band), so no tinting is needed |

## Mid pieces
| Piece | Size (x, y, z) | Tris | Atlas | Notes |
|---|---|---|---|---|
| X_TownHouse_A_* | 44.1 x 29.9 x 16.2 (walls 40 x 26, eave 10.4, ridge 13.9 + chimney) | 370 each | X_Town | one storey, low gable, fieldstone plinth, 10 real window / door openings (recessed dark 2-over-2 glass, white frames), chimney west |
| X_TownHouse_B_* | 39.8 x 32.0 x 26.1 (walls 36 x 28, ridge 24) | 490 each | X_Town | two storeys, 13 openings, door hood, chimney west |
| X_WaterTower | 23.2 x 23.2 x 70.6 | 972 | X_Site | 4 tapered legs on footings, 4 levels of X bracing, riser + ladder, 20-sided tank with our own stencil "T-7" front and back, catwalk with rails, cone roof, rod to 70 |
| X_Bunker | 37.1 x 24.9 x 17.5 (block 30 x 20 x 10; antenna to 17) | 258 | X_Site | battered walls, deep slit window (front), recessed olive blast door (east side), roof slab, vent, two sandbag walls |
| X_Quonset | 41.2 x 81.2 x 22.3 | 380 | X_Site | 20-segment corrugated half cylinder on a slab, inset end walls, recessed hangar doors + our own "B-4" (front, -Y), personnel door + 2 windows (back), roof vents |
| X_ObservationStand | 31.2 x 10.2 x 14.4 | 354 | X_Site | 4-tier timber bleacher on posts, back rail, sloped corrugated shade roof on 6 steel posts, front = -Y |
| X_ChainLink | 60.3 x 0.3 x 8.5 | 52 | X_ChainLink (alpha) | double-sided diamond-mesh card (each side its own face), 5 posts, top rail. **SurfaceAppearance AlphaMode Transparency** |
| X_PoleLine | 438 x 6.6 x 30.5 | 1,066 | X_Site | 8 poles 60 apart along X (-210..210), crossarms, insulators, 2 transformer cans, 3 sagging wires per span, guy wires at both ends |

## Near: heights and what they cover
Each near piece **contains the v2 house's own step / canopy boxes** (`H_House` Shell_R: front step x -1.5..7.5 y -34..-31
z -1..0, canopy x -1.5..8 y -35.5..-30.98 z 11.2..11.8, back step x -7.5..1.5 y 31..34 z -1..0) with >= 0.13 margin, so those
are buried whether or not you hide them, and sits >= 0.13 above the v2 exterior's yard slabs, so nothing z-fights.
- X_PorchFront: stoop x -3..9 y -34.3..-30.95 top **z 0.15** (0.15 sill over the floor, so it covers the v2 step top at 0), two
  steps down to the v2 path (tops -0.17, -0.50; path -0.82), posts at x -2.55 / 8.55, canopy x -3.2..9.2 y -36.2..-30.95
  **z 10.9..12.0** (shingle top, white fascia). Below z 13.5 (FY_S window at 14) and clear of the door strip y -30.5..-30.
- X_BackStoop: slab x -7.65..1.65 y 30.95..34.3 top 0.15, steps (-0.15, -0.45) down to the v2 patio (-0.75); iron rail on
  the west side, doormat in front of the door, a wooden milk crate with our own "MESA DAIRY 7" east of the door.
- X_Driveway: x 15.9..30.1 y -56.1..-30.95, top **z -0.69** (brief said -0.95, which is 0.13 *under* the v2
  `Ext_Yard_Concrete65` driveway at -0.82 and would be invisible). The v2 wagon parked on it (`Car_Wagon`, tyres at -0.82)
  sinks 0.13 into the new slab: invisible, or raise the car 0.13. If you hide the v2 yard concrete instead, lower this to -0.95.
- X_FoundationStrip_Gravel65: 1.5-wide gravel ring round the house foot, top -0.72 at the wall (0.05 inside it) falling to
  -0.92 at 1.5 out (under the v2 dry lawn at -0.85), mitred corners; breaks at the porch, the driveway and the v2 back patio
  (x -14..16), each end 0.08 into its neighbour.

## Checks run
- `blender_check.py` (mid spread apart): **97 objects, 12,190 tris, 0 FAIL**, 11 WARN, all `A1b` on `X_Mesa1_*` (two mesas per
  object point faces at each other); every loose part has positive volume in the FBX read-back. Per collection: Mid 14 objects
  0 FAIL 0 WARN, Near 7 objects 0 FAIL 0 WARN. Renders: `renders/check*/check_*.jpg`.
- FBX read-back: cube 10.000, every origin exact, sizes within 0.008, one UV map and one material per object: PASS.
- Previews (culling on, magenta world): `renders/mid_*.jpg`, `renders/near_*.jpg` (with the v2 house and exterior linked
  read-only), `renders/far_pano_*_sheet.jpg`.
