# Tacticals lobby layout survey (2026-10-14, read-only)

Source: Studio `Tacticals_rebuild.rbxl` (local copy), `Workspace.LobbyMap` (7,539 descendants). Nothing was written to the place.
Method: part/mesh bounding boxes, downward raycast scans (`out/survey/scan_*.json`: every walkable up-facing surface on a
2-stud grid; 1 stud for the showroom) and horizontal wall slices (`out/survey/slice_*.json`: solid intervals along X and Z
lines at y 4 / 20 / 34 / 604), plus clear-height and door-width rays. Plans: `out/survey/plan_*.png`.

Axes: +X east, +Z north (Shop is north, Armory south). **Mesh names use the opposite convention**: `U_East__*` is the WEST
end (x -158..-72, stairs + Duels base), `U_WestWall__*` is the EAST end (x 84..104, the Exfil tunnel). Keep that in mind when
reading names.

## How the map is built
- **Shell = merged MeshParts, one per material** (Blender export, `<piece>__<material>`): `Unique/` (128 MeshParts:
  U_Floor, U_Ceiling, U_Braces, U_Spine, U_Cables, U_PodCables, U_GateN/S, U_GateBulkhead, U_WestWall, U_East,
  U_DuelsShell, U_DuelWalls, U_DuelPads, U_EnergyWall, U_Shop, U_Armory, U_Exfil, U_SpawnDisc). Materials:
  armour, concrete, dark_metal, panel_metal, floor_metal, grate (DiamondPlate), steel (Metal, CanCollide false),
  emit_* (Neon, CanCollide false), glass, olive_paint, paint_bone, wood, case_poly. Collision is
  PreciseConvexDecomposition on the solid materials; 68/128 collide. Several carry a `LobbyBake` SurfaceAppearance (baked
  lighting, attribute v2 = asset id) and `GlowBase` / `PrevFidelity` attributes.
- **Hub long walls = kit modules** in `Instances/` (220 Models, 1,174 MeshParts, 474 collide), placed on a ~13.75-stud bay
  grid along z = ±41..49 at x = ±14, 28, 42, 56, 69, 83, with a door bay at x = 0:
  - ground (y 0-14): `GShop_*` (shop-front bays), `GDoor_*`, `GVent_*`
  - y 18-22: `Cradle_*`, `PodBand_*`, `PodBarrel*`, `PodCap*`, `PodHead*` (pod band along both walls)
  - y 31: `Catwalk_*` (+ `Catwalk_NDoor/SDoor`), `Pipe_*`; y 35: `Pier_*` (structural piers every bay)
  - y 39: `UPanel_*`, `UWindow_*`, `UMachine_*`; y 58: `OverBig_*`, `OverSmall_*`, `TopFill_*`
  - roof: `Gantry` x6 (y 60, x ±76..), `Strip_*` light strips (y 71, z ±24), `Bridge` x2 (y 27, x ±49, cross the hall)
- **Gameplay parts are plain Parts**: Duels pads (85 Parts), Interact (3), Exfil (5), Lights (39), FX (186), Training (566),
  Showroom markers, TimesSquare (29 Parts), NPC rigs.
- `HubProps/` (373 MeshParts, all collide) = 24 `Cluster_x_z` folders of floor props; `Clutter/` = 24 K_* crate/barrel/cart
  models (78/108 collide) along the pod bands.
- `City/` (5 MeshParts) and `TimesSquare/` (29 Parts) are non-colliding backdrops below the base.

## Spawn
- `LobbyMap.LobbySpawn` SpawnLocation at (0, 0.3, 0), 24 x 0.2 x 24, Transparency 1, Neutral, Enabled. **There are 7 identical
  copies stacked on the same spot** (all direct children of LobbyMap). One is enough; scripts don't reference it by name.
- Visual spawn disc `U_SpawnDisc__spawn_logo` (r 20, x/z -20..20). Fall-catch / training respawn point: hub spawn (0,4,0),
  hangar (112, 3.5, 0) facing +X.

## Areas

| Area | Folder(s) | World AABB (x / y / z) | Floor y | Ceiling / walls |
|---|---|---|---|---|
| Hub hall | Unique U_Floor, U_Ceiling, U_Braces, U_Spine; Instances; HubProps; Clutter; Props; FX | x -90..100, y -1.4..73, z -50..50; walkable x -86..86, z -41..41 | 0 (grate/panel/floor_metal meshes, top 0.0; spawn disc 0.6) | perimeter roof 68-73 (U_Ceiling, CanCollide **false**, also not queryable so rays read "open sky"); braces/spine 36-63 hang over the centre; kit walls on z ±44..49 up to 58-68; under-catwalk clearance 30 |
| Hub west landing + stairs | U_East (panel_metal steps, floor_metal) | x -90..-72, z -44..44 | 0 -> 2 -> 3 -> 4 riser at x -78..-72 (z -8..8, ~16 wide); landing y 4 at x -84..-80; twin stair runs along x -88..-86 climbing from y 4 at z ±40 to y 16 at z ±10 | open above; FX2.StairsLight at (-89,11,0) |
| Duels | Duels (6 pad Models), Unique U_DuelsShell/U_DuelWalls/U_DuelPads, U_East base | x -142..-88, y 16..74, z -50..50; walkable x -138..-92, z -43..43 | 15.9-16.0 (pad plates 16.3) | shell 66-74 around the edge; no queryable roof over the centre (rays reach the sky); side walls to ~70 |
| Energy wall + West deck | Unique U_EnergyWall, FX2 HeliEnd/HeliN/HeliS | wall x -155..-140; deck x -200..-155, z -30..30 | 16.0 | energy wall 16-70; deck open sky, boxed by **invisible collide walls** HeliN/HeliS (z ±30) and HeliEnd (x -200), y 16-28 |
| North gate corridor | Unique U_GateN | x -6..6, z 44..64 | -0.8..0 (grate) | clear height 12.2, width 9.8 (10.8 at the hub mouth) |
| Shop | Rooms/Shop, Unique U_Shop, Interact.Shop_Counter, NPCs.NPC_Quartermaster | x -31..31, y -2..15, z 64..112; interior ~59 x 41 (x -30..30, z ~67..108) | 0 | ceiling 13-14 |
| South gate corridor | Unique U_GateS | x -6..6, z -64..-44 | -0.8..0 | clear 12.2, width 9.8 |
| Armory | Rooms/Armory (+WeaponsDisplay, FeaturedScissors), Unique U_Armory, Interact.GunWall_Kit/Armory_Dais, NPCs.NPC_Supply | x -33..33, y -2..23, z -115..-64; interior ~61 x 45 | 0 | ceiling 22 |
| Exfil tunnel | Unique U_WestWall | x 88..104, z -11..11 | 0 | clear 18-19, width 22 |
| Exfil hangar + pad | Exfil, Heli, Unique U_Exfil | x 104..152, y -9..21, z -27..27 | 0 (floor_metal -0.1) | hangar roof 20-21 over x 104..126; pad x 126..152 open sky; walls/rail to ~18; helicopter on the pad (x 119-147, z -14..23) |
| Upper level (decor) | Instances Catwalk_*, Bridge*, PodBand_* | catwalks z ±40..46 at y 30-31 full length; bridges at x ±49 y 27 across z -43..43 | 27-31 | walkable surfaces but **no stair/ladder found** connecting them to the hub floor (scan shows nothing between y 4 and y 27 near them); treat as set dressing |
| Showroom | Showroom (6 U_Showroom MeshParts + DisplayPoint/CameraPoint/BenchTop/KeyLight/Lights/Sign) | x -31..31, y 399..427, z -19..35 | n/a (BenchTop top 404.2) | everything CanCollide **false and CanQuery false**: never walked; a camera set |
| Training | Training (Arena 209 Parts, Arrivals 16, EnemySpots 336, 12 Lights, TrainingArrive) | x -88..88, y 598..637, z -121..121 | 600 (Floor 172 x 2 x 238 at y 599) | Ceiling at 636.5, walls Wall_N/S/E/W 36 high with Glass strips; four quadrants A-D split by Div_X/Div_Z walls with windows (WindowSill attr); cover: *_Block x10, *_LowWall x12, *_Pillar x6, *_Wall x4 per quadrant; centre HubRing/HubBeam |
| City backdrop | City (5 MeshParts) | x -15..986, y -314..-53, z -650..750 | none (ground at -310) | non-colliding |
| Times Square backdrop | TimesSquare (towers, Billboards, Square, TrafficLane x5) | x 165..522, y -96..144, z -180..117 | Square at y -96 (CanCollide false) | non-colliding; 9 CityBillboard-tagged Parts with SurfaceGuis |
| Signs | Signs (6 sign Models, 30 MeshParts, no collide) | DUELS (-84,10,0) on the stair wall; SHOP (0,17,45) over N gate; ARMORY (0,17,-45) over S gate; EXFIL (89,26,0) over the tunnel; TRAINING + TRAINING_back (0..2, 626, 0) inside training | | |

## Doorways / openings (all measured with rays)
| Opening | Centre | Size (w x clear h) | Connects |
|---|---|---|---|
| N gate mouth / corridor | x 0, z 44..64 | 10.8 at mouth, 9.8 in the corridor, 12.2 high, ~20 long | Hub <-> Shop |
| Shop doorway | x 0, z ~64-67 | 11.0 wide | corridor <-> Shop |
| S gate mouth / corridor | x 0, z -44..-64 | 10.8 / 9.8, 12.2 high | Hub <-> Armory |
| Armory doorway | x 0, z ~-64..-67 | 11.0 wide | corridor <-> Armory |
| Exfil tunnel | x 88..104, z -11..11 | 22 wide, 18 high | Hub <-> hangar |
| Hangar to pad | x ~126 | full width 52 (z -26..26); **ExfilBarrier** (127.5, 6.4, 0) 0.3 x 13.2 x 24, CanCollide false, CanTouch true, Transparency 0.2: touching it starts the exfil cutscene | hangar <-> pad / heli |
| West riser | x -78..-72, z -8..8 | ~16 wide, 3 steps 0 -> 4 | Hub <-> landing |
| Stairs | x -88..-86, z ±10..±40 | ~4 wide each (two runs, mirrored N/S) | landing y4 <-> top landing y16 (x -90..-86, z -8..8) |
| Duels door | x ~-90, z -5.5..5.5, y 16 | 11.0 wide, 8 clear (y 16 -> 24) | top landing <-> Duels |
| Energy-wall gap | x -155..-140, z -4.5..4.5, y 16 | 9.0 wide, 12 high (16 -> 28) | Duels <-> West deck |

No doors/gates animate; there are no door parts to keep. All openings are holes in the merged meshes.

## Walkable vs walls/trim (what collides)
- Walkable floors: U_Floor__grate/panel_metal/floor_metal (hub, top y 0), U_SpawnDisc, U_GateN/S__grate, U_Shop__floor_metal,
  U_Armory__floor_metal / grate, U_WestWall__floor_metal (tunnel), U_Exfil__floor_metal, U_East__panel_metal (riser/stair
  treads) + U_East__floor_metal/concrete (landing, duels base y 16), U_EnergyWall__floor_metal (west deck), duel Team*Plate
  Parts (16.3), Training.Arena.Floor (y 600).
- Walls: U_*__concrete / dark_metal / panel_metal / armour (collide), Instances kit modules (partly collide: 474 of 1,174
  pieces), Training Wall_* + Div_* + cover blocks (collide, used by the cover system).
- Trims / non-colliding: every `emit_*` (Neon), every `steel` (Metal), U_Ceiling (all), U_Spine, U_Cables, Gantry, Strip_*,
  Over*/UMachine, Signs, City, TimesSquare, Showroom, Lights, FX (3 of 188 collide: the invisible HeliEnd/HeliN/HeliS).
- Meshes vs Parts: architecture is MeshParts throughout (Unique + Instances + HubProps + Clutter + Signs + Heli + Showroom +
  City); Parts are gameplay markers/zones, lights, FX hosts, duel pads, the whole Training arena and TimesSquare.

## How areas connect / player route
Spawn (0,0,0) in the hub centre. North through the N gate corridor to the Shop; south through the S gate to the Armory;
east through the 22-wide tunnel to the hangar and the helicopter pad; west up the 3-step riser, the twin stairs to y 16,
through the Duels door into the duel hall (six queue pads), and on through the energy-wall gap to the fenced west deck
(dead end, view out). No in-world stairs to the catwalks.

## Training (y ~600) and Showroom (y ~400): how they are reached
- **Training: teleport by respawn, not by a pad.** `StarterPlayerScripts.ExfilFX` hooks `Touched` on every part tagged
  `ExfilBarrier` (= `LobbyMap.Exfil.ExfilBarrier`): anchors the player, jumps them to `Exfil.HatchPoint`, tweens to
  `Exfil.CabinPoint`, lifts the `Heli` (rotor parts by attribute `Rotor` = Main/Tail around `Heli` attributes
  Mast/TailHub/TailAxis) with a scripted camera at (120,9,-18), fades to black, then fires `ReplicatedStorage.Events.Training.Enter`.
  Server `ServerScriptService.ServerScripts.[Server] Init.GameManager.Managers.TrainingManager` sets player attribute
  `InTraining`, `LoadCharacter()`s and pivots to a random `Training.Arrivals` child (fallback `Training.TrainingArrive`).
  The PLAY menu's TRAINING card uses `PlayerGui.ExfilFade.QuickEnter` (fade only, same Enter event).
  Leaving: LEAVE button / [M] -> `Events.Training.Leave` -> respawn at HANGAR (112, 3.5, 0).
  Enemies: `ServerStorage.RangeAssets.Dummy` clones placed at random `Training.EnemySpots` parts (24 alive), parented to
  `LobbyMap.Training`.
- **Showroom: camera only.** `LobbyUIController.Armory` (Kit menu) finds `LobbyMap.Showroom` (fallback `LobbyMap.Armory`) and
  sets a Scriptable camera from `CameraPoint` looking at `DisplayPoint`, placing item models there; `BenchTop` gives the table
  height for the fake shadow. The player body never moves.

## Lighting / environment (static, for reference)
Lighting: Brightness 1, ClockTime 0 (night), Exposure +0.6, Ambient (54,56,54), OutdoorAmbient (64,66,63), GlobalShadows on,
ShadowSoftness 0.2, EnvDiffuse 0.45 / EnvSpecular 0.8. Children: Sky, Lobby_Sky, SunRays, **two Atmospheres** (`Atmosphere`
density 0.3 + `Lobby_Atmosphere` density 0.3 haze 1.6; only one can apply - remove the duplicate in the rebuild),
Lobby_Bloom (0.5 / 22 / 1.6), Lobby_CC (contrast 0.22, sat -0.12), Lobby_DOF. `ServerStorage.LobbyMap_V2_Lighting` exists
but no live script applies it. Workspace: FallenPartsDestroyHeight -500, StreamingEnabled **off**, gravity 196.2.
Captures in Edit look very dark: the room lights (`RoomLight` tag) are switched on by a client script only near the camera.

## Leftovers worth knowing
`ServerStorage` holds LobbyMap_Old (14,679 desc.), LobbyMap_V1, LobbyMap_V2, RoqerWorld (old bunker lobby), RoomKit,
PropKit, _ArmoryKitArchive, TrainingDummy, RangeAssets (needed: Dummy), plus script backups (_Pre43, _Pre45...).
