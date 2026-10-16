# Overnight polish: N / S gate corridors (airlock bulkheads)

Done 2026-10-16 night, only in `Tacticals_rebuild.rbxl` (studio 8ef4e21a). **Not saved** (the lead saves). RIVALS (2e616d06) was
only read (four doorway captures: the DUELS archway, a small doorway, the market doorway, the pad-hallway mouth). No computer use,
no imports, no RIVALS ids. Parts, our own `TX_hazard_stripe` texture and the place's own `TacRibbed` / `TacCorrugatedMetal` /
`TacMetal` variants only.

| What | Path |
|---|---|
| Polish script (idempotent, UNDO flag) | `fix/polish_gates.lua` -> `python tools/run_luau.py fix/polish_gates.lua [UNDO]` |
| Check (clips incl. Shop/Armory polish, support, clearance with vs without polish, hooks, walk routes; read-only) | `fix/check_polish_gates.lua` |
| Captures (10 cameras: hub mouth, mid, wall, back from the room, sign; per corridor) | `python tools/polish_gates_capture.py <prefix> [names]`, `... ref <name> x,y,z lx,ly,lz` |
| Sheet | `python tools/polish_gates_sheet.py` -> **`out/polish/gates/sheet.jpg`** (BEFORE / AFTER per view, Play frame, RIVALS doorways) |

## Identity
Short, tight, transitional airlocks between the olive hub and the rooms. The only place with **ribbed light-grey walls between
near-black bulkhead ribs**, a near-black band, cool-white light strips and cream/near-black hazard sills. RIVALS method (its door
reveals): dark metal reveals in lighter surrounds, a stripe at the door foot, Neon strips as the light source, nothing else.

## What changed (originals in attribute `PolishGates_Orig`, typed JSON)
1. **Corridor envelope** (`Rooms2.C_CorrN` / `C_CorrS`, corridor-only meshes, 24 recolours): wall plates -> `TacRibbed` ribbed
   concrete 144,136,130 (renders neutral ~120); upper wall `TacCorrugatedMetal` 90,77,70; band (was lime olive) -> near-black
   34,30,28; ribs -> near-black Plastic 46,40,36 (the three ribs per corridor now read as bulkhead frames); trims, ceiling, floor
   plate and border neutralised; ceiling strip cool white 214,222,228; floor lines 180 -> Neon 108,108,104 (no longer the
   brightest thing). The first pass rendered blue (B-R +10..+32, Metal walls at 0.5x): every value is the neutral target divided
   by the measured render ratio (60%), and the wall plates moved off Metal. Result B-R -6..+5 on every corridor mesh.
   The far sill (`C_Corr*__hazard`) texture tint white -> cream. The corridor pipe runs' lime band -> dark olive 78,82,46.
2. **Light strips** (`Polish.Gates.<N|S>.Strip*`, 8 per corridor): Neon 0.14 x 0.3 inside the wall recess between the wall plate
   and the band (recess back at 5.40, y 6.35-6.85), one per bay. Cool white; the N corridor's last bay is warm (240,214,176).
3. **Door status lights** (`StatusLight` x4 per corridor): on the upper wall on the hub side of the two airlock ribs (z +-52,
   +-61), both walls, y 11: near-black housing, a lit olive-green GO lens (Neon 96,118,50) over an unlit red STOP lens.
4. **Hazard sills** (3 per corridor: hub end z +-49.75, under ribs z +-52 and +-61): near-black SmoothPlastic with the own hazard
   texture tinted cream, 0.06 high, in three pieces so the cream floor lines stay visible through them.
5. **Destination bay** (between the far rib and the doorway): the wall plate (both walls) and the band (the wall without the pipe)
   faced in the room's own finish. N: the Shop's `S_Walls__wall_body` cream TacConcretePanels and `wall_light`; S: the Armory's
   `A_Walls__wall_plate` gunmetal TacMetal and `wall_dark`. The Shop doorway frame `S_Door__wall_light` takes the Shop's cream
   (212,194,160) and its trim a warm 150,132,104, as the Armory frame is gunmetal since polish_armory.
6. **SHOP sign -> OUTFITTERS**: it is a text sign (`Hub1.Overlays.SignText_SHOP.Text.Label`; the old `Signs.U_Sign_SHOP` mesh was
   already hidden). Text OUTFITTERS, label Scale 0.92 x 0.7 (UNDO restores SHOP, 1 x 0.8). The ARMORY sign is unchanged.

64 new parts, 0 lights added or changed, 0 new collidable parts.

## Logic checks
- `check_polish_gates`: **0 clips** (64 probes; the first run had 12: sills over the floor-line meshes -> split around them; the
  band panel on the trim ledge -> y 7.3-9.85; strips and panels on uneven wall faces -> fixed recess x and a 0.03 gap). Support 0
  bad. **Clearance with vs without polish identical**: N body-height width 9.54 (the features-kit `F_JunctionBox` on the west
  wall, pre-existing; S 9.80), 7.86 / 8.17 at y 1-11 (pipe runs, pre-existing), clear height 12.11 (hub gate frame) in both.
  Hooks: SHOP sign OUTFITTERS, ARMORY unchanged, Shop_Counter (Shop) / GunWall_Kit / Armory_Dais (Kit) prompts enabled, 0 new
  lights, 99 enabled in Edit. Routes hub -> Shop counter front (round the featured stage), hub -> Armory dais front, both corridor
  edges: clear.
- `check_rooms2` FAILS 0, `check_rooms3` FAILS 0, `check_hub1` nothing flagged, `check_training` ALL OK, `check_polish_shop` 0
  clips, `check_polish_armory` 0 clips (20 slots ok).
- **Play walk**: hub -> N corridor (0,56) -> Shop counter front (2.0, 3.07, 95.8) -> S corridor (0,-56) -> Armory dais front
  (-3.8,-88) -> hub (0, 3.03, -21): all reached. 59 enabled lights in Play at the hub. Console: baseline only.
- UNDO round trip: restored 29 instances, 0 attributes left, sign SHOP 1 x 0.8; re-applied twice, identical (64 parts). The first
  UNDO stopped on the sign label: `encV` had no UDim2 case, so the Size was stored untyped. Fixed (UDim2 encoded; a lost Size falls
  back to the known original).

## For the lead / Edward
- The two corridors share everything but the last bay; the room preview lives in that bay, the doorway frame and the warm strips.
- `F_JunctionBox` (west wall of the N corridor, 0.7 proud at shoulder height) is why the N corridor is 9.54 wide, not 9.8.
- Queued for import: nothing.
