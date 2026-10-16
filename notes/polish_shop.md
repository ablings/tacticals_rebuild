# Overnight polish: Shop (quartermaster store)

Done 2026-10-15 night, only in `Tacticals_rebuild.rbxl` (studio 8ef4e21a). **Not saved** (the lead saves). RIVALS reference
(2e616d06) was only looked at through existing captures (`out/style/raw`); nothing was written to it. No computer use, no imports,
no RIVALS ids. Built from Parts plus the place's own `ServerStorage.PropKit` / `FeaturesKit` models and stock materials.

| What | Path |
|---|---|
| Polish script (idempotent, UNDO flag) | `fix/polish_shop.lua` -> `python tools/run_luau.py fix/polish_shop.lua [UNDO]` |
| Clip / support / hook check (read-only) | `fix/check_polish_shop.lua` |
| Capture set (6 player-height cameras) | `python tools/polish_shop_capture.py <prefix>` |
| Raycast albedo render (fallback when captures are blank) | `python tools/ray_render.py <out.png> cx,cy,cz lx,ly,lz [W H FOV]` |
| Sheet | `out/polish/shop/sheet.jpg` (gitignored, like all of out/) |

## Identity
Warm, inviting quartermaster store: the only room with **warm 3000K pools, wood and a cream envelope**. Cream dominant, olive kept as
the trim band, near-black floor kept (RIVALS language), no particles, nothing kid-like.

## What changed
1. **Recolours (15 Rooms2 `S_*` meshes, Shop-only; originals in attribute `PolishShop_Orig`)**
   - Walls: kick 178,170,150; plate 206,199,180; upper body 190,183,164; fascia + pier faces + display frames 212/206 cream.
     The olive band and metal trims are untouched.
   - Ceiling warmed (128,120,106 / gloss 74,64,52).
   - Counter: cream body 222,216,198 and front plates 232,226,208, dark warm kick 70,64,56 (olive stripe kept).
   - Back shelving frames `S_Shelves__beam_metal` -> **Wood** 132,92,58.
   - Lamps: ceiling strips, display lamps and rack lamps -> warm Neon 228,186,128 (were blue-white).
2. **Lights**: the 4 `Rooms.Shop.L_*` PointLights tinted 255,184,120 and brightened (0.30-0.55 -> 0.45-0.70); the counter truss spot
   tinted 255,196,140. **5 new lights**, all on `RoomLight` hosts with `Room=Shop` (RoomFX switches them with the room):
   3 pendant SpotLights over the service run (one with shadows), 2 SurfaceLight shelf washes over the back shelving.
3. **New set dressing (Workspace.LobbyMap.Polish.Shop, 289 parts)**
   - `CounterPendants`: 4 olive drum pendants on cords with a warm Neon diffuser (the 4th, over the east terminal, glows only).
   - `Counter`: wood countertop in 4 runs that leave the KitEmitter_ShopCounter hook and the two terminals on their metal plates,
     olive front edge; on top: folded uniforms, an ammo can, an open requisition ledger with pencil, a stencilled RATIONS box.
   - `WallShelfW` / `WallShelfE`: wood shelf units by the counter ends (west 4.8 wide, east 3.6), 4 shelves of ammo cans, ration
     boxes, canteens, folded uniforms and med kits, olive shelf lips with cream price tags, a warm Neon strip under the top.
   - `ShelfWash`: two bracketed warm strip lights over the back shelves.
   - `Boards`: two cream price/stock boards with an olive number tab ("01 FIELD STOCK", "02 REQUISITION") flanking the SUPPLY sign,
     on the free wall between the piers (x 11.25) and the capsule lights (x 18.75), 0.08 off the wall.
   - `StockClusters`: pallet + three small crates (west, by the counter end), a big crate with a small one on top and an ammo case (east).
   - `EntryBins`: two open wood merchandise bins on stands by the entrance (FIELD RATIONS, CANTEENS) with placards.
   - `AFrame`: a slate A-frame board "QUARTERMASTER / OPEN / DAILY ISSUE" by the doorway, turned to face players coming in.
   - `CounterMat`: olive customer mat with a warm-grey border in front of the counter; it stops at z 99.35 so the hazard strip at the
     counter foot stays visible.

## Logic checks
- **Walkability (Play, character_navigation)**: hub -> shop counter front (3, 97) -> round the west counter end into the staff area
  (-12, 105.7) -> round the east end (18.4, 104.5) -> entrance bin (12.9, 72.7) -> back to the hub (0, 30.9): all reached.
- `check_rooms2`: **0 FAILS** (routes spawn -> N gate -> shop counter and back clear; Shop_Counter reach 3.0/9; NPC_Quartermaster
  reach 7.62/9, was 7.0). `check_rooms3`: 0 FAILS. `check_hub1`: unchanged. `check_training`: ALL OK.
- `check_polish_shop`: **0 clips** after fixes (first runs found the countertop buried in both terminals and the mat over the counter
  hazard strip; both fixed). Every floor-standing group rests on the floor (bottom 0.03 over floor 0.02-0.03).
- Overlays: price tags, plates and edges sit 0.07-0.12 proud of their faces; board back face 0.08 off the wall; mat field 0.04
  proud of its border.
- Lights: every new light sits in a visible fixture (pendant diffuser, wash housing); no light is behind a wall. Shadow-casting
  lights in LobbyMap: 9 (one new).
- Hooks: Interact.Shop_Counter OpenPanel=Shop enabled; NPC_Quartermaster in place (OpenPanel=Kit, unchanged); KitEmitter and
  Spot_ShopCounter untouched (spot only tinted).
- Console in Play: same as the baseline (MatchmakingManager MemoryStore error, AssetCheck 1 texture failure, UIBlox warnings);
  nothing new. Play stopped.
- UNDO round trip tested (restored 20 originals, removed Polish.Shop), then re-applied twice: identical result (idempotent).

## Problems / for the lead or Edward
- **All screen_capture frames came back blank white** in both the rebuild and the RIVALS studio for the whole session (the Studio
  windows are minimised or covered: see "A minimised Studio window renders blank white"). Without computer use this could not be
  fixed, so the sheet uses the last real Studio captures of the Shop (rooms2 pass) as BEFORE, and **raycast albedo renders**
  (`tools/ray_render.py`, no lighting) for before/after layout. **The warm light, Neon and the cream values have not been judged
  on rendered pixels**: re-capture with `python tools/polish_shop_capture.py after` once the window is restored and tune
  (likely candidates: cream walls may read too bright near the pendants; the warm Neon strip colour).
- **Light budget**: in Play at the counter 74 lights were enabled in Workspace before trimming (66 before this pass), well over
  the ~45 comment in RoomFX. This pass adds 5. The overall count is a lobby-wide issue for the final lap.
- Queued for import: nothing (no Blender asset was needed; the props are Parts and existing kit models).
