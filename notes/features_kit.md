# Feature-pass prop kit (features): Blender kit for items 3, 14, 26, 27, 29, 30, 31, wall screens, Training bins + crates

Status 2026-10-15: built in Blender 5.2 (background process, own fresh file) and exported. **Blender only**: Studio not touched,
nothing imported, nothing committed. Own geometry only (bmesh + the hub_kit / rooms2 / rooms3 helpers), no RIVALS ids/meshes/images,
**no new textures** (TacHub1 variants from `tex/asset_ids.json` or flat colours).

The interactive Blender MCP was not connected (localhost:9876 refused), so the kit is built by a background Blender 5.2 run
(`--factory-startup`, scene cleared by `clear_scene()`, saved to its own file; `read_homefile` never called).

## Files
| What | Path |
|---|---|
| Kit FBX | `kit/features.fbx` (162 meshes = 160 kit + K_Scale5 + K_Marker5, 48.8k tris, largest mesh 2,820 tris; 1.46 MB) |
| Blender file | `kit/features_kit.blend` (collections `F_Kit`, `F_Markers`; every object has a `piece` custom property) |
| Manifest | `kit/features_manifest.json`: `pieces` (pivot, bounds, mount notes, screens/labels/lenses, replaces, tris, coplanar flags) and `meshes` (as rooms4 + `center_rel_pivot`, `role`) |
| Generator | `tools/features_kit.py` (execs rooms3_kit.py -> rooms2_kit.py -> hub_kit.py) |
| Previews | `tools/features_preview.py` -> `out/features/bl_<piece>.png` (28) + `bl_row.png`; sheet `tools/features_sheet.py` -> **`out/features/bl_contact.jpg`** |

Rebuild everything:
```
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/features_kit.py
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b kit/features_kit.blend --python tools/features_preview.py
python tools/features_sheet.py
```

## Axes, pivots, markers
- Same convention as hub1/rooms2-4: authored in Studio coords (x east, y up, z north), Blender (x, y, z) = (-Xs, Zs, Ys); FBX -Z forward, Y up,
  modifiers applied, FACE smoothing (hub_export.py settings). Mesh origin = bounds centre. Mesh = `<piece>__<material>`.
- **Each piece is authored at its own origin (pivot)**, then slid along +X into a row with 4-stud gaps (x 3.6 .. 299). `pieces.<P>.pivot_studio`
  is the pivot in the FBX; every mesh has `center_rel_pivot`. Placement: build a Model per piece, mesh CFrame = target CFrame * (center_rel_pivot).
- **Front = -Z** (Roblox Front face) for every wall/screen piece; wall pieces have their back at z 0 (a 0.02 gap off the wall).
- `K_Scale5` 10-stud cube at (0, 120, 0); `K_Marker5` Neon L (long arm +X x 15..25, upright +Y, short arm +Z). Import 3D with Insert Using
  Scene Position, group Gunsy Funsy, Anchored; check Size/10 and that the marker isn't mirrored, then move both to `ServerStorage._RebuildRemoved`.

## Pieces
| Piece | Item | What | Mount / pivot | Screen / lens / label |
|---|---|---|---|---|
| F_TVArmWall | 26 | wall plate (4 bolts), 3 knuckles with olive collars, two twin-plate arm segments + spine + cable, tilt head, TV (bezel 0.1 proud, olive band, cream LED, cream under-glow, rear vents) | back z 0, TV front at z -5.78 | `__screen` 6.66 x 3.66 (visible 6.56 x 3.56), Face Front |
| F_TVArmCeil | 26 | ceiling plate, drop pole with olive band, swivel knuckle, yoke, TV | plate top y 0, TV centre y -4.6 | `__screen` Front |
| F_TVArmCeilDual | 26 | same, two TVs back to back (over pads) | as above | `__screen` Front + `__screen_b` Back |
| F_Screen16x9 | 18/19/4 | heavy bezel housing, chamfered corner caps, olive datum strip, cream under-light, header block with a cream plate between olive Neon ticks, side vents | back z 0 | `__screen` 16.12 x 9.12 (visible 16 x 9) Front; header `__label_cream` 9.0 x 1.05 |
| F_Screen12x4 | 21 | same frame, wide strip (DUELS sign screen) | back z 0 | `__screen` 12.12 x 4.12 Front; header 6.7 x 1.05 |
| F_Container20 / F_Container10 | 27 | shipping container 16 / 8 x 7.5 x 7: corrugation ribs (sides, closed end, roof), corner posts + castings, rails, door leaves with 4 lock bars + keepers + handles, cream stencil + ID plates | floor, doors at +X | colour options in manifest: olive drab 88,98,58 (default) / sage / warm grey / near-black |
| F_PipeStraight / F_PipeElbow / F_PipeValve / F_PipeRun | 27 | r 0.45 pipe, bolted flanges (r 0.63), olive band + cream flow ring; elbow bend r 1.5; gate valve with bonnet + olive handwheel + tag plate; run = 2 pipes x 16 on 3 wall brackets with clamp rings | axis X; ports in the manifest `mount` | valve tag `__label_cream` |
| F_PowerBox | 27 | wall cabinet 3.2 x 4.4: door, hinges, handle, louvre, warning plate + hazard strip, olive/cream status lights, conduit to y 4.5 | back z 0, centre y 0 | `__label_cream` (lightning decal / text) |
| F_JunctionBox | 27 | 1.4 box, lid, 4 screws, label, conduit stubs | back z 0 | |
| F_Intercom | 27 | plate, panel, speaker grille slats, mini screen in a bezel, olive call button with ring, label strip, conduit | back z 0 | `__screen` 0.8 x 0.3 Front |
| F_RewardStand | 14 | lathe plinth (dark base with olive feet, concrete body, olive band, two cream rings, metal cap), display top, cream Neon inset ring, olive floor ring, floating cream halo r 1.9 at y 7.6, front name plate | floor; **display top y 3.5, spin anchor (0, 6, 0)** (LobbySpin tag on the model) | `__label_cream` 2.1 x 0.8 Front |
| F_PitRim | 3 | 12 x 12 dark rim (top y 0.04) round a 10 x 10 hole, hazard inlays (top 0.08), inner metal lip, grate ledge at y -0.95..-0.8, shaft liner to y -8, olive Neon warning line, void bottom | hole centred on the origin, floor top y 0 | cut a 10 x 10 floor hole; teleporter `From` part inside the shaft (e.g. y -6) |
| F_TrussSpot | 29 | half-ring clamp (for a r 0.3 tube along X through the origin) + block + bolt, stem with olive band, yoke, can with 4 cooling fins, 4 barn doors | can aims -Y; rotate to aim | `__lens_warm` (SpotLight Face Bottom, 255,241,208) |
| F_Truss10 | 29 | 1.2 x 1.2 box truss, 10 long, zigzag diagonals, end plates | axis X | |
| F_BeaconMast | 30 | base plate + bolts, tapered 12-stud mast with olive/cream aviation bands, beacon head (housing, caged lens dome, cap, lightning rod) | base y 0 | `__lens_amber` (amber 255,170,40 or red 220,40,40; PointLight, slow pulse) |
| F_BeaconWall | 30 | wall plate, arm + diagonal brace, same head | back z 0, lens at (0, ~1.1, -1) | `__lens_amber` |
| F_HoloEmitter | 31 | stepped base, olive band, 3 fins, cream Neon ring, emitter lens, olive floor ring, **optional** `__holo_cone` shell (r 0.6 -> 2.4, to y 5.5) | base y 0; hologram centre (0, 3.5, 0) | `__holo_lens`; cone: Neon cream Transparency 0.85, or delete and use a Beam |
| F_SwapBin | Training | see below | | front `__label_cream` 1.6 x 0.8 (WEAPONS text) |
| F_Crate4A/B/C, F_Crate5A/B/C | Training | see below | | stencil `__label_cream` |

FX pieces (29-31) use Edward's effect theme colours in the manifest: olive Neon 66,72,36, olive band 111,114,57, warm white 255,241,208,
cream 236,232,218. Everything else uses the rooms3 Studio colours (band 120,136,66, Neon olive 88,101,48, crate 65,94,56).

## Training swap bin + cover crates (Edward's addition) - 1:1 swap data
Read from `fix/place_training.lua` (EXTRAS.bins + LAYOUT crate entries) and `scripts/training_extras/TrainingBins*.lua`.
- **Bin (9 in Training)**: old Model `Training.Extras.SwapBins.SwapBin` = Body 3 x 2.5 x 3 (centre y +1.25), Lid 3.2 x 0.35 x 3.2 (centre
  2.67, top 2.845), Stripe 3.06 x 0.3 x 3.06 Neon cream (centre 1.8), `PromptAt` Attachment at Body local (0, 1.6, 0), `BinPrompt`
  ProximityPrompt (F, attr TrainingBin), Model attr TrainingBin, PrimaryPart = Body; the script points -Z at the room centre (CFrame.lookAt).
  `F_SwapBin` keeps those exact volumes: **body mesh `F_SwapBin__crate_green` bounds exactly 3 x 2.5 x 3, centre (0, 1.25, 0)**, lid
  `__dark_metal` (lid + handles + latch), stripe `__neon_cream` 0.03 proud, corner posts 0.07 proud, front plate on -Z. Lid top is clear for the
  prompt. Swap: keep the Model, its attribute and the prompt; make the body mesh the PrimaryPart and parent `PromptAt` to it at (0, 1.6, 0),
  so `GetPivot()` (TrainingBinsManager.nearBin) and the prompt position do not change. Body + lid collide/query, no NotCover (as before).
- **Crates**: Training has **20 crates 4 x 4 x 4 and 4 crates 5 x 5 x 5** (`Range2.Cover.Crate` Parts + 2 `CrateStrap` decor Parts each).
  Three variants per size: **A** strapped (2 wrap straps 0.05 proud, 8 corner caps 0.09 proud, stencils), **B** framed (12 edge bars 0.06 proud,
  strap over the top 0.1 proud, X braces), **C** ribbed (plank ribs 0.04 proud, corner posts 0.08, lid frame 0.12, grab handles).
  **Body mesh `F_Crate<s><v>__crate_green` bounds are exactly s x s x s** (bottom y 0), CanCollide + CanQuery on, **no NotCover** (crates are
  cover), CollisionFidelity Box. Every other crate mesh is decor: CanCollide/CanQuery/CanTouch off + NotCover, like the old CrateStrap.
  Swap 1:1: crate Part CFrame (centre) -> piece pivot = Part CFrame * (0, -s/2, 0); hide the Part and its 2 straps (UNDO-able); rotate
  variants A/B/C round the 24 spots (and a random 90-degree yaw) so it doesn't tile. Grid/grime Textures stay off the meshes (the kit
  carries the look); the grid-tile Parts architecture is unchanged.

## Collision policy (manifest `can_collide` / `can_query` / `not_cover`)
- Decor material meshes never collide: Neon, lenses, screens, labels, hazard, grate, trim_cream, holo, halo.
- Solid (structure meshes collide): containers (Box), pipes, power box, reward stand, holo emitter, beacon mast (Hull).
- Pit rim: only the rim and the shaft liner collide (the grate ledge does NOT, so fallers can't land on it).
- Wall/ceiling TVs, screens, intercom, junction box, spot, truss, wall beacon: no collision (above head height or flat on walls).

## Checks
- Every mesh < 20k tris (largest 2,820, `F_PipeRun__trim_metal`); whole kit 48.8k tris.
- `coplanar_check()` in the generator runs on every piece before it is moved: same-facing axis-aligned faces of different materials within
  **0.029** with overlapping extents. **0 flags** after the fixes (first run had 15 pieces flagged: decor bottoms at 0.02 on the floor plane,
  castings flush with post tops, strap vs edge-bar 0.02, intercom bezel 0.01-0.025, lens 0.02 under the can, collar = spine). Rules applied:
  decoration 0.03-0.12 past its body on every face, floor rings/inlays 0.04 proud, decor bottoms lifted 0.04 off the floor plane, screens
  0.06-0.08 behind their bezel face, lenses 0.04-0.05 recessed.
- Radial (lathe) faces are not covered by the checker; they were authored with >= 0.03 radial steps (mast bands ~0.03-0.04).

## Lessons (for the vault: roblox-build-workflow 6 Blender Modelling Method)
- Run a coplanar checker inside the generator, per piece, before finalize: it caught 15 pieces' worth of 0.00-0.025 flush faces that look
  fine in previews. Make the tolerance the rule itself (0.029 for "0.03+").
- Stacked decor on one body needs **distinct** offsets (strap 0.05, caps 0.09; bars 0.06, strap 0.1): two decor layers at the same
  inflation are coplanar with each other even when both clear the body.
- When a mesh is the collision body of a 1:1 Part swap, give decor that shares its colour its own material slot (`crate_trim`), or the
  merged mesh's bounds grow and Box collision no longer matches the Part.
- If the Blender MCP socket is down, `blender.exe -b --factory-startup --python <generator>` builds, exports and renders the same kit headless.
