# Lag test, 2026-10-30 (main PC, systems session): what low-end devices can and can't handle

Report only: nothing in the game was changed or published. Work order: Lead's plan, approved by Edward.

## Summary for Edward (5 lines)
1. **Match maps are fine on low-end phones at graphics 1-3**: every map draws 21-135k triangles in 21-118 draw calls, with no shadows; 1v1 vs 3v3 adds only ~10k triangles.
2. **The lobby hub is the heaviest scene**: 1.1-1.2M triangles and ~1,450-1,490 draw calls at graphics 10+ (over Roblox's ~1M comfort line), plus 42 lights near the spawn. At graphics 1 it falls to 115k / 122.
3. **Shadows are the single biggest cost**: from graphics 10, shadows multiply triangles 4-19x and draw calls 7-15x in every scene.
4. **Two download/memory costs to fix before they ship**: the new animation pass carries 100k animation-source objects to every player (+107 MB), and every match server sends all four maps to every player (StreamingEnabled off).
5. **Hitches**: a frag or barrel explosion freezes 0.25-0.32 s and match start 0.36-0.5 s *even on this fast PC*: on a low-end phone that's roughly a 1-2 s freeze. The cheapest fixes are listed below (top 10).

## What was tested, and how
- **Builds** (copied after `git pull` at 05:16, in `out/lagtest/`, not committed: `out/` is ignored):
  - lobby = `Tacticals_main_ported.rbxl` as of port 51 (04:32; hash 81d28696);
  - match maps = `out/anim_final/Test_anim.rbxl` (the Test place + the final animation pass + 140 new clips; hash b419d09e; per
    notes/ANIM_TEST_DONE.md it is NOT published and does NOT have the new gun meshes yet).
- **Studio Play (solo)** with the Test place's Studio hook (`ServerStorage.TestPlaceHook "start"`): every map in 3v3 vs bots,
  House also in 1v1. Effects fired through the game's own test hooks and remotes: frag and smoke grenades (the real
  `ThrowGadget` remote), both steam valves per Warehouse map, 10 House windows blasted, House smoke alarms (blast), barrels (frags).
- **Numbers** read by script (`tools/lagtest/`): `Stats.RenderBreakdown` (triangles / draw calls of the view, per pass),
  `Stats.FrameRateManager` (Batches = every draw call including the shadow passes; Indices / 3 = every triangle drawn, shadows
  included), `Stats:GetMemoryUsageMbForTag`, instance / part counts, a RenderStepped frame-time sampler (average, 1 % low,
  p99.9, max), and a static census of every folder (parts, shadow casters, lights, emitters, textures, meshes, GUIs).
- **Graphics quality**: `settings().Rendering.QualityLevel` = Level01 / 03 / 05 / 10 / 21, read back each time. The in-game slider's
  1 / 3 / 5 / 10 map to roughly levels 1 / 5 / 10 / 21; level 3 was added because the shadow passes start between 5 and 10.
- **CPU throttle** (stand-in for a weak device): `tools/lagtest/throttle.py` pins the Studio process to N logical cores and
  hard-caps its CPU time with a Windows job object (`JOB_OBJECT_CPU_RATE_CONTROL_HARD_CAP`). Tiers: tablet = 2 cores at 60 %
  (1.2 desktop cores), mid phone = 2 x 30 % (0.6 core), low phone = 1 x 25 % (0.25 core). Test PC: Ryzen 9 7950X3D, RTX 5070 Ti,
  64 GB. The GPU can't be throttled: GPU load is judged from the draw call and triangle counts instead.

### What could NOT be measured, and why (read the numbers with this in mind)
- **True FPS above 60**: every Studio here is capped at 60 fps (HQ ClientSettings) and an unfocused Studio window renders at
  15 fps. With the window on the stage, House held **60.0 fps avg / 54.6 1 %-low at graphics 1 and 3** (1268x737); then
  another agent's window took the foreground and the rest of that run fell back to the 15 fps cap. So frame-time results below
  are against a fixed 15 fps yardstick: what matters is whether a tier keeps up with it, and how big each hitch is in ms.
- **Studio Device Emulator**: not used. It needs clicks in Studio's Device menu and this session had no desktop-control tool.
  It only changes screen size, DPI and touch input, not device power, so it would not change the costs above; the UI scale at
  phone sizes is the UI designer's check (notes/ui_survey_r2.md already lists the phone regressions).
- **2-client run** (`multiplayer.py`): did not start (0 test windows, twice): the player-count box next to Play needs a click
  that this session couldn't make. So **per-process client vs server memory and network in/out per player were not measured**.
  In solo Play the client and server share one process (plus Studio's own plugins), so the memory numbers below are per
  category for the whole process; `LuaHeap` (~810-850 MB) and `Script` (~278 MB) are mostly Studio's own plugins.
- **Throttled tiers** throttle the whole solo Play process (client + server + Studio editor), so they overstate the load a
  real phone's client would have, by about 2x.
- **Load time to playable**: measured in Studio only (no download): lobby character ready at **17.0 s** client time; a real
  phone adds the download of everything not streamed.

## Tables per place, by device tier
Columns are measured at the graphics level that tier usually runs (Roblox's automatic graphics on a low-end phone sits around
1-3, mid phones 3-5, tablets 5-10, desktops 10-21). "View" = the main pass; "All" = every pass including shadows.

### Lobby (StreamingEnabled on; client 93,860 instances at spawn; 86 enabled lights, 10 shadowed; 1,622 shadow casters)
| View | Low phone (q1-3) | Mid phone (q5) | Tablet (q10) | Desktop (q21) |
|---|---|---|---|---|
| Hub, long axis | 115k tris / 122 draws | 115k / 125 | **793k / 902** | **1,185k / 1,448** |
| Spawn (snapshot, q21) | - | - | - | **1,119k / 1,492**, 179k / 286 in view, 42 lights in 150 studs |
| Armory (kit room) | 85k / 171 | 85k / 180 | 422k / 706 | 583k / 947 |
| Gun wall | 66k / 125 | 66k / 132 | 329k / 543 | 475k / 779 |
| Training | 30k / 62 | 30k / 73 | 117k / 174 | 203k / 233 |
| CPU (hub, q1, 15 fps yardstick) | low-phone tier: froze (no answer in 90 s) | mid-phone tier: **0.6 fps** | tablet tier: 15.0 fps (holds) | 15.0 fps (holds) |
| Join | max frame 208 ms in the first 20 s; character ready 17 s | | | |

### Match maps (StreamingEnabled off: all four maps are in Workspace for every client; client 165k instances)
| Map (3v3, spawn view) | Low phone (q1-3) | Mid phone (q5) | Tablet (q10) | Desktop (q21) | Lights near |
|---|---|---|---|---|---|
| House | 39k / 83-86 | 39k / 94 | 354k / 851 | 508k / 1,204 | 37 |
| House 1v1 | 28k / 79 | 28k / 82 | 301k / 831 | 430k / 1,176 | 37 |
| Warehouse | 135k / 103 | 130k / 105 | **707k / 510** | **949k / 701** | 11 |
| Warehouse 2 | 44k / 118 | 46k / 148 | 240k / 333 | 539k / 553 | 32 |
| Arena | 21k / 21 | 21k / 24 | 109k / 176 | 402k / 534 | 0 |
| CPU (House 3v3, q1) | low-phone tier: **11.7 fps avg, 1 % low 4.3 fps** (p99 232 ms) | | (tablet tier holds 15 in the lobby test) | 60.0 fps / 1 % low 54.6 (staged, q1 and q3) | |

### Spikes (worst single frame; baseline frame 66.7 ms at the 15 fps cap, 16.7 ms at 60)
| Event | House | Warehouse | Warehouse 2 | Arena |
|---|---|---|---|---|
| Match start -> Live (map env, backdrop, spawns) | 500 ms (360 ms staged at 60 fps) | 384 ms | 390 ms | 428 ms |
| Frag explosion | **322 ms** (3v3), 159 ms (1v1) | 70 ms | **250 ms** | 70 ms |
| Window glass (10 panes blasted) | 87 ms | - | - | - |
| Steam valves (both) | - | 69 ms (none) | 69 ms (none) | - |
| Smoke grenade | 93 ms (3v3), 198 ms (1v1) | 90 ms | 88 ms | 82 ms |

### Memory by category (solo Play process, MB; Studio's plugins inflate LuaHeap / Script / Internal)
| Category | Lobby | House 3v3 | Warehouse 3v3 | Warehouse 2 3v3 | Arena 3v3 |
|---|---|---|---|---|---|
| GraphicsTexture | 131 | 146 (148 after fx) | 154 | 149 | 134 |
| Animation | **14** | **122** | 121 | 121 | 121 |
| Gui | 195 | 113 | 110 | 112 | 112 |
| Instances | 150 | 155 | 156 | 156 | 156 |
| BaseParts | 132 | 62 | 61 | 62 | 62 |
| Sounds | 27 | 38 | 38 | 38 | 39 |
| GraphicsParticles | 16 | 12 -> 15 after fx | 15 | 15 | 15 |
| Meshes + parts (graphics) | 31 | 11 | 10 | 10 | 10 |
The +107 MB Animation in the match build is the animation pass's 217 source clips (see cost 2).

## Low-end phones: CAN / CAN'T
**CAN handle (at graphics 1-3)**
- All four match maps in 1v1 and 3v3: 21-135k triangles, 21-118 draw calls, no shadow passes.
- Training (30k / 62), the Armory and gun wall (66-85k / 125-171).
- Smoke grenades, steam fill, window glass breaking: no frame over ~100 ms on this PC.
- House's illusion backdrop (far field only in Workspace during House; 0 lights, no shadows past the near field).
- The particle load: 7 enabled emitters in the lobby (rate 8 total), none ambient in the match maps.

**CAN'T handle (or at risk)**
- **The lobby hub and spawn at graphics 5+ on a weak GPU**: 1.1-1.2M triangles and ~1,450-1,490 draw calls at q21, 793k / 902 at
  q10. At q1 it is 115k / 122 and fine.
- **The lobby on a weak CPU**: at 0.6 desktop core the hub fell to 0.6 fps, at 0.25 core it froze (overstated ~2x by the solo
  process, but the lobby is clearly the heaviest CPU scene: 94k client instances, 28k server primitives).
- **Explosions and match start**: 0.25-0.5 s freezes on a top desktop CPU become multi-second freezes on a phone.
- **House on the low-phone CPU tier**: 11.7 fps average, 4.3 fps 1 % low.
- **Memory headroom**: the match build adds +107 MB of animation data and 100k objects per player if the source clips ship;
  2-3 GB phones are the first to crash on memory.

## Top 10 costs, ranked, with the cheapest fix for each
| # | Cost | Measured | Cheapest fix |
|---|---|---|---|
| 1 | **Shadow passes** at graphics 10+ | x4-19 triangles, x7-15 draw calls in every view; lobby 1,622 shadow casters / 10 shadowed lights; Warehouse 2 673 casters / 12 shadowed lights; Warehouse 949k at q21 | `CastShadow = false` on small, thin and interior dressing (trims, props, signs, cables; the vault's office practice cut 881k -> 134k this way), and `Shadows = false` on all but the few key lights per view |
| 2 | **Animation source clips in ReplicatedStorage** (final animation pass, not shipped yet) | `Repository.AnimationSources`: 217 KeyframeSequences, 95,364 Poses = **101,615 objects**; client Animation memory 14 -> 122 MB | Publish the clips under the group and ship only the Animation ids; move `AnimationSources` to ServerStorage (or strip it) in every published build. Add it to the port read-back |
| 3 | **Lobby hub / spawn view** | 1,185k tris / 1,448 batches (q21); 42 enabled lights within 150 studs of spawn (budget ~40) | With 1: fewer shadowed lights in the hub; lights only where they light something ([[Map Proof Check]] 6) |
| 4 | **All four match maps in Workspace, StreamingEnabled off** (match places + Test) | every client gets 6,357 map objects, 2,516 parts, 82 lights, 1,410 Textures for maps that aren't being played | Park the maps not picked in ServerStorage at match start (the map env code already moves House's backdrop the same way), or turn StreamingEnabled on for the match places |
| 5 | **Hidden old lobby still in Workspace** | `LobbyMap.Instances` 220 old kit models = 1,174 invisible MeshParts + 1,012 SurfaceAppearances; `LobbyMap.HubProps` 373 invisible MeshParts; all replicated to every player | Move both folders to ServerStorage (UNDO-able, as `_RebuildRemoved`); nothing visible changes |
| 6 | **Explosion and match-start hitches** | frag 250-322 ms (House, Warehouse 2), match start 360-500 ms on a 7950X3D | Profile `ShootableManager.Explode` (blast test per window, alarms, chain, fire) and the map-env switch; spread the per-window work over frames and pre-create the explosion FX at match start |
| 7 | **Duel maps replicated in the lobby** | `ReplicatedStorage.DuelMaps` 5,284 objects, 78 lights, 1,399 Textures to every lobby player, duelling or not | Keep them in ServerStorage and copy the picked map in only for the duel (or to the duellists' clients) |
| 8 | **Tiled Texture objects** | lobby 2,696 (Training alone 2,424), Arena 1,389 | MaterialVariants or one texture per surface instead of many tiled Texture layers; they add triangles per layer |
| 9 | **In-world GUIs** | lobby 376 SurfaceGuis / BillboardGuis with 1,583 elements; the hub view's UI pass had 258 draw calls in Edit | `MaxDistance` on every BillboardGui, SurfaceGuis on far screens off, static text baked into decals |
| 10 | **New guns built from many meshes** (not in the build yet) | 790-2,566 tris each (fine) but 8-22 separate meshes per gun; with the holstered kit on every body that is ~30-60 draw calls per body, 6 bodies in 3v3 | Merge each gun's non-moving parts into one mesh (keep only the animated parts separate); holstered guns use a merged low version |
Already fixed: the lobby's AssetCheck preload diagnostic (preloaded every lobby asset on join) is parked by port 51 (SURVEY1025).
The House illusion backdrop is cheap (far field 5.4k tris, mid 21.8k, only in Workspace during House).

## Proposed per-quality knobs (client-side, one module reading the player's graphics level)
| Graphics level | Shadows | Lights | Effects | Other |
|---|---|---|---|---|
| 1-3 (low phone) | none (Roblox already drops the shadow passes here) | turn off lights tagged `LowQualityOff` (fills, decor) | particles x0.3 with a per-emitter cap; explosion without debris parts; glass shards x0.3; steam cloud particles x0.5 | BillboardGui MaxDistance 40; other bodies' breathing / fidget layers only within 30 studs (`MaxBodies` 4) |
| 4-6 (mid phone) | key lights only | <= 25 enabled near the camera | particles x0.6 | MaxDistance 80; `MaxBodies` 8 |
| 7-10 (tablet / low PC) | key lights + big silhouettes | all | x1 | all GUIs |
| 11-21 (desktop) | as built | as built | as built | as built |
Keep each knob a config value with a flag, so a level never shows MORE than as built.

## Raw data and tools
- Raw logs (copied from out/lagtest/): `notes/lag_test_1030_data/` (census, render sweeps, solo runs, FPS run, CPU tiers).
- Tools: `tools/lagtest/` (`run.py` Luau runner, `census.lua`, `render_sweep.lua`, `sampler.lua`, `snap_client.lua`,
  `snap_server.lua`, `tm.lua`, `fx_server.lua`, `fx_client.lua`, `throttle.py`, `run_map.sh`, `fps_run.sh`, `tiers.sh`).
- Open: the 2-client run (per-process memory, network per player) and Device Emulator pass need a session with desktop control
  (set the player count box to 2 once; then `multiplayer.py start`), and a staged FPS run where no other agent takes the
  foreground.

## Follow-up: in-game Performance settings (2026-10-30)
Edward: "now with the in game settings what can we turn off to lower this". Built: notes/perf_settings_1030.md (5 rows in
Settings > Video > Performance, all off by default). Graphics 21: lobby hub 1,993k tris / 2,318 batches -> 186k / 162 with all on;
House 304k / 648 -> 76k / 180. Not live yet: ships with the next port.
