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
| Sheet | `out/polish/shop/sheet.jpg` (gitignored, like all of out/): real BEFORE (polish undone) / AFTER / RIVALS captures |
| Show a Studio window for captures | `pwsh -NoProfile -File tools/show_studio.ps1 tacticals|rivals` |

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

## Round 2 (lead review, real captures once the windows were shown)
Captures work after `tools/show_studio.ps1`; the sheet now has real BEFORE (polish UNDOne in the same session) / AFTER / RIVALS frames
(RIVALS market hall and UGC shop stage captured read-only, plus the old shelving capture). The round-1 ray-render frames were dropped.
- **(a) Cold ceiling**: the panels, gloss panels, ceiling trims, beams and strip housings were Concrete/Metal picking up the blue sky
  specular. Now Plastic in warm values: panels 206,194,170, gloss 150,136,112, trims 92,78,62, beams 70,56,42, housings 58,48,38 /
  120,104,84. Strip Neon 214,180,138 (218,168,108 read lemon-yellow). 19 recolours in total, originals in `PolishShop_Orig`.
- **(b) Boards**: rebuilt larger (6.0 x 4.05, over the olive band between the pier and the capsule light, back face 0.08 off the band
  trim) with real content, all in Scale: olive header bar ("01 FIELD STOCK", "02 REQUISITION"), four item rows with prices
  (near-black on cream, ruled lines), footer line. A picture light on top of each (Neon strip + the SurfaceLight that used to be the
  separate shelf wash) lights the board and the shelves. **The "blank white rectangles" were the first capture after the script
  re-created the SurfaceGuis**: the GUI texture is not drawn yet in that frame. A second capture shows the text; in Play the boards
  exist from load. Capture once to warm up after every re-run.
- **(c) QUARTERMASTER**: full from the entrance. At the lead camera it is cut ("QUARTERMASTI") **identically with the polish undone**
  (before_lead.png), so it is not from this pass. It is not occlusion (rays to the tag are clear), not MaxDistance (100 changes
  nothing) and not the tag width (240 px cut at the same screen x). It is the NPC's own `Tag` BillboardGui (hook, not touched); left
  for the lead.
- **(d) Pools**: measured on the wood top in an edit-time Future capture, pendants on vs off: **+13..44 grey levels** under the two
  pendants (Brightness 4, range 14), the centre (emitter) unchanged. The centre pendant was removed because it hid the SUPPLY sign
  from the entrance; the remaining two cast the pools (one with shadows), the east one glows only.
- Lights now: **4 new** (2 pendant spots, 2 board picture lights), all RoomLight Room=Shop. Shadow casters in LobbyMap: 9.
- Re-checked after round 2: check_polish_shop 0 clips, hooks as before. (Play walk, check_rooms2/3/hub1/training were run in round 1;
  round 2 only moved things above head height and recoloured.)
- Lesson: twice a sed edit that appended a comment to a Luau line (`... then  -- note`, `... do -- note`, `...; -- note s.Parent = host`)
  commented out the rest of the line: once a parse error, once silently unparented lights. Put comments on their own line.

## Round 3 (2026-10-15 night): UGC / COSMETIC shop (Edward 22:55)
Script `fix/polish_shop3.lua` (run AFTER `fix/polish_shop.lua`; a re-run of polish_shop.lua rebuilds Polish.Shop and drops Round3,
so re-run polish_shop3 afterwards). Idempotent; every touched property of an existing instance is stored once in attribute
`PolishShop3_Orig` (typed JSON; the NPC talk lines in `PolishShop3_Orig_TalkLines`). New pieces in `Workspace.LobbyMap.Polish.Shop.Round3`
(1,226 Parts, most of them camo blotches). UNDO: `python tools/run_luau.py fix/polish_shop3.lua UNDO` (run before polish_shop UNDO).
Sheet: `python tools/polish_shop3_sheet.py` -> `out/polish/shop/sheet3.jpg` (round 2 | round 3 per view, detail views, RIVALS UGC
stage / market hall / market refs). Blueprint: RIVALS presents cosmetics as **lit exhibits, not stock**.

### Hidden (Transparency 1, no collide/query/touch/shadow; lights/guis disabled), never deleted
- Polish.Shop: counter goods (uniforms, ammo can, ledger, RATIONS box) and the four separate top edges; the shelf goods (ammo,
  rations, canteens, uniforms, med kits); `Boards` (FIELD STOCK / REQUISITION + their 2 picture lights); `StockClusters`; `EntryBins`;
  the A-frame's old QUARTERMASTER / RATIONS gui.
- Rooms2: `S_Displays` (cream pedestals with rifles, crates), `S_Racks` (gun rack), `S_Props` (crates/drums), the back-shelf stock
  (`S_Shelves__crate_green/drum_olive/case_dark/label_cream`), the plinth's upper drum, gun and column (`S_Plinth__dark_metal,
  trim_metal, trim_light, neon_cream, case_dark, drum_olive`; the low base ring stays). `Rooms.Shop.K_*` kit props.
  **No guns remain in the Shop.** 262 parts hidden.

### Built (Round3)
- `OutfitWalls`: 2 bays per side wall between the piers (z 81.6-87.6, 92.2-98.2; wall face 29.7, backdrop 0.43 off for the trims),
  dark-olive fabric backdrop in a wood frame, 4 mannequins per side on wood plinths with cream name plates (name + R$ price):
  W WOODLAND RECON / DESERT RAIDER / URBAN OPS / OLIVE DRAB, E ALPINE / NIGHT OPS / TIGER STRIPE / SKY PILOT. Mannequins are R15-
  proportioned Parts (feet, boots, lower/upper legs, lower/upper torso, belt, arms angled 7 degrees, hands, neck, faceless head via
  SpecialMesh Head); camo from deterministic blotch parts on the four faces of each limb (tiger = horizontal stripes); gear from Parts
  + SpecialMesh Sphere (helmet with rim, beret with badge, boonie, cap, goggles, plate carrier with pouches, gaiter, sleeve patch).
  One wash bar per side (Neon strip + SurfaceLight) over both bays.
- `HeadgearWalls`: the entrance bays (wall face 29.4) carry a HEADGEAR wall: two wood shelves, six head forms per side with helmets,
  berets, boonies and caps (gear built at mannequin size, then ScaleTo(0.8) about the head top).
- `GlassCases` (where the supply bins stood, x +-11.8 z 76): wood cabinet, felt bed, warm Neon glow strip, glass hood with metal posts;
  W "DOG TAGS" (3 tag pairs with ball chains, a beret), E "PATCHES & INSIGNIA" (SKY / TAC / AIR patches, sergeant chevrons, pilot wings).
- `Screens`: FEATURED (west, x -14.6) and NEW DROPS (east, x 15.2) on the back wall where the boards were, raised to y 8.95-12.0 so
  the outfitter's tag no longer sits over them; near-black bezel, self-lit SurfaceGui (LightInfluence 0), Scale only.
- `FeaturedStage`: a low dais (r 3.0, top 1.63) on the plinth's base ring, olive Neon ring, a turntable 0.16 over it with the featured
  mannequin SKY RANGER ELITE (multi-camo, helmet, goggles, plate carrier, gaiter, gloves); the model `FeaturedOutfit` has `Spin = 12`
  (RoomFX turns it about its pivot on the stage axis; the 0.15 bob never touches the dais). Rope line on 6 posts (near-black, olive
  rope), open toward the entrance. Key: a truss can hung from the z 79-80 ceiling beam, SpotLight angle 26, b4.5, shadows on.
- `Checkout`: one continuous olive fascia + cream line under the four wood runs (now one walnut tone); a CHECKOUT screen on the counter.
- `ShelfGoods`: folded camo shirts (stacks of 2-3) on the wood wall-shelf units instead of supply goods.
- `AFrameText`: OUTFITTERS / NEW / DROPS DAILY / UNIFORMS · CAMO / TAGS · PATCHES (adorned to the old slate).

### Taste fixes from review_shop.md
1. Tag over a board: `NPC_Quartermaster.Tag` text OUTFITTER, size in Scale (= studs on a BillboardGui) 4.2 x 0.9 instead of 160 x 34 px
   (a pixel-sized tag covered ~10 studs of back wall seen from the entrance), offset 3.2 -> 2.55; the screens sit above it.
2. Spotlight blocking the sign: `Features.Spotlights.Spot_ShopCounter` moved (3,11.1,97.6) -> (7.5,11.6,95.0), out of the entrance ->
   sign sightline, re-aimed as the stage rim light (angle 34, b2.2). Sign text SUPPLY -> OUTFITTERS.
3. Walls reading white: wall body 206,182,146, plate 200,176,140, kick 172,148,116, fascia/piers 212,194,160.
4. Cool ceiling: the faces seen between the strips are `S_Ceiling__trim_metal` (found by a camera ray through the pixel); it rendered
   77,77,72 at 92,78,62 (render/colour ~0.84 / 0.99 / 1.16 under the sky ambient); now 132,100,68 -> renders 118,103,79 (tan).
5. Lime pendant shades: shade near-black SmoothPlastic, top/cap dark olive 78,88,48; pendant spots 4 -> 2.6 (light moves to the products).
6. Plank-like countertop: one walnut tone + one continuous fascia across all runs.
- NPC prompt ObjectText OUTFITTER, cosmetic TalkLines; Shop_Counter prompt "Browse outfits / CHECKOUT". OpenPanel values unchanged
  (counter = Shop; NPC = Kit: Edward to confirm whether the outfitter should open Shop).

### Logic checks
- Play walk (character_navigation x3): hub -> door (0,72) -> counter front (2.4,96.9) -> west outfit wall (-23,90) -> west staff side
  (-12.5,104.7) -> east staff side (18.4,104.5) -> east outfit wall (23,84) -> east glass case (11.8,73) -> hub (0.1,31.7): all reached.
- Hooks: Shop_Counter prompt in range (5.0 of 9) and **E opened ShopUI2** (Scrim + Canvas visible); NPC_Quartermaster OpenPanel=Kit,
  prompt enabled; FeaturedOutfit turns in Play (pivot rotates). check_rooms2 **FAILS 0** (Shop_Counter reach 3.00, NPC 7.62);
  check_rooms3 routes clear (its old-Holo note on Pad_1v1 Team2 predates this pass); check_hub1 all ok; check_training ALL OK.
- `check_polish_shop` (extended for Round3): **0 clips** after fixes (first run 13: backdrops/frames in the wall trims, wash arms in
  the band, plinth kicks and post bases touching the floor trim, the dais in the plinth rim, the key rod in a beam). Every Round3 floor
  group's lowest point is 0.02-0.03 over the floor (glass-case kick raised to clear the entrance insert at 0.03).
- Lights: 3 new (2 wash SurfaceLights, 1 key SpotLight) and 3 switched off (the 2 board picture lights, L_Pedestals' invisible
  PointLight) = **net 0**; shadow casters 10 in LobbyMap (+1, the stage key). Enabled in Play at the counter: 73 (lobby-wide issue).
- Console in Play: baseline only (MatchmakingManager MemoryStore, AssetCheck 1/1154, UIBlox warnings).
- UNDO round trip: UNDO restored 314 instances (0 attributes left; sign SUPPLY, tag 160x34 QUARTERMASTER, displays visible, spot back
  at (3,11.1,97.6), talk lines restored), then applied twice: identical (1,226 parts, 313 originals tagged). The first UNDO run missed
  the TalkLines attribute (stored apart from the property JSON); fixed in the script and restored by hand.
- Queued for import: nothing (Parts, SpecialMesh primitives and SurfaceGuis only; no Blender kit needed).

### Open / for the lead
- 1,226 parts in Round3, ~900 of them camo blotches. If the part count matters, an own camo texture (one Texture per limb) would
  replace them; the upload goes under the Gunsy Funsy group.
- Mannequins read clean but blocky close up; a Blender mannequin kit (rounded limbs, own camo UVs) is the next quality step.
- The outfitter NPC still opens Kit.
