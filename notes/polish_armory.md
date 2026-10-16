# Overnight polish: Armory (weapons vault)

Done 2026-10-15 night, only in `Tacticals_rebuild.rbxl` (studio 8ef4e21a). **Not saved** (the lead saves). RIVALS reference
(2e616d06) only read (a read-only survey for its weapons room at ~(109,-680,1100) and three captures); nothing written to it.
No computer use, no imports, no RIVALS ids. Built from Parts, the place's own hidden `Rooms.Armory.WeaponsDisplay` gun models
(cloned visible), `ServerStorage.PropKit` / `FeaturesKit`, the TacMetal MaterialVariant and our own `TX_grate_alpha` texture.

| What | Path |
|---|---|
| Polish script (idempotent, UNDO flag) | `fix/polish_armory.lua` -> `python tools/run_luau.py fix/polish_armory.lua [UNDO]` |
| Clip / probe / support / hook check (read-only) | `fix/check_polish_armory.lua` |
| Capture set (8 cameras incl. the hub-gate approach) | `python tools/polish_armory_capture.py <prefix> [names]`, `... ref <name> x,y,z lx,ly,lz` |
| Sheet | `python tools/polish_armory_sheet.py` -> `out/polish/armory/sheet.jpg` (BEFORE / AFTER / featured spot + bay close-up / RIVALS row) |

## Identity
Darker gunmetal weapons vault, cool and focused: the only room with a **cool blue-grey metal envelope and 6500K light**, against the
warm cream Shop. RIVALS' weapons room is the craft blueprint (dark charcoal envelope, weapons on dark perforated pegboard niches,
bright cool tube lights, loose weapons on dark tables); our theme replaces its purple with olive/sage and adds stencils.

## What changed
1. **Recolours: 40 Rooms2 `A_*` meshes (Armory-only), originals in attribute `PolishArmory_Orig`.**
   Walls gunmetal (plates 60,64,70 Metal/TacMetal, body 66,70,76, kick 46,49,54, piers/surrounds 74,79,86, upper ribbed 70,74,80,
   trims 84-106); ceiling 52,55,60, gloss 28,30,34, beams 34,36,40; floor from warm brown to cool near-black (field 48,50,53,
   border 30,32,34); gun-wall backing (was cream) 44,48,52 TacMetal; supply counter, door surround and dais plates the same family.
   Olive band, olive racks and the cream/olive floor and dais Neon rings kept as the accents.
   Neon: ceiling strips, pier capsules, bench and gun-wall lamps cool white 206,222,240; rack lamps **sage glow** 150,178,122.
2. **Lights (no new Light instances; 7 retuned, originals in `PolishArmory_Orig`).** L_BenchA/B cool 212,226,255 b0.8; L_Fill
   cooler and lower (b0.3); L_GunWall cool b3.0; **L_Dais = the hard featured key**: Angle 50 -> 26, Brightness 3 -> 9, Range 24,
   236,242,255 (measured on/off on the dais disc: +16.5 grey levels in the centre, +1.4 on the outer ring = a tight hard pool);
   Spot_ArmoryDais / Spot_GunWall tinted cool. Enabled lights in Play: 67 before and after; shadow casters 9 in LobbyMap (unchanged).
3. **New set dressing (Workspace.LobbyMap.Polish.Armory, 432 parts)**
   - `WeaponBays`: 8 weapon bays (4 per side wall) in the free wall between the pier capsule lights, y 10.35-15.05 above the olive
     band, found by a 3-height ray scan (lamp hits and uneven hits break a span; the panel sits on the most proud hit). Each bay:
     near-black backing, a **slotted rack panel** (TacMetal Part + `TX_grate_alpha` Texture, 0.9-stud tiles, bars 112,118,126 over
     16,18,20), olive frame, a near-black hood with a cool Neon strip, a sage Neon underglow, two long guns on pegs (AutoRifle /
     SemiAuto / Sniper clones, scaled to the bay, auto-flipped so the magazine hangs down), and a cream stencil plate
     "RACK W-01 / SN 4471-TAC-107" (Heavy + RobotoMono).
   - Floor stencils (transparent parts, SurfaceGui text): "WEAPONS BAY S-2 / AUTHORISED PERSONNEL ONLY" past the entry insert
     (z -84.2), "CLEAR ALL WEAPONS · NO LIVE ROUNDS PAST THIS LINE" just before the gun-wall hazard strip (z -103.6).
   - `AmmoStock` (east, by the entrance): F_Crate4A + Prop_CrateS on top + two stacked Prop_AmmoCase, stencil "7.62 NATO / LOT 0419 ·
     840 RDS" on the room-facing side.

## Logic checks
- **Walk in Play**: hub -> doorway (0,-72) -> dais side (-3.8,-91.1) -> gun-wall front (-0.2,-105.7) -> benches (21.1,-81.9) ->
  west back (-21.1,-100) -> ammo stock (21.2,-75.7) -> hub (0,-30.8): all reached.
- `check_polish_armory`: **0 clips** (rays + 97 GetPartsInPart probes). The first run found the ammo cases 0.97 inside the existing
  A_Props case; moved. Support: all floor groups on A_Floor (0.03 over 0.02), all bays have wall behind them; the crate and case on
  top report NOTHING only because the ray excludes Polish parts (they stand on the Polish crate/case below).
- `check_rooms2` **FAILS 0** (armory -> dais front clear, -> supply counter front clear, Armory_Dais reach 2.17). Note: its
  informational "armory corner (25,-75)" floor sample now lands on the new crate (4.03). `check_rooms3` routes clear, `check_hub1`
  hooks ok, `check_training` ALL OK.
- Hooks: Interact.GunWall_Kit (0,6,-110.5) and Armory_Dais (-10,2.5,-96) OpenPanel=Kit enabled; NPC_Supply (7,4.19,-110.6)
  OpenPanel=Shop; FeaturedScissors Spin=25 at (-10,3.4,-96), untouched; 5 RoomLight Armory hosts (unchanged).
- Signs/stencils face arrivals (floor text tops point -Z, the walking direction). No new collidable parts except the kit props.
- Console in Play: baseline only (MatchmakingManager MemoryStore, AssetCheck 1/1154 texture failure, UIBlox warnings).
- UNDO round trip: restored 47 originals and removed Polish.Armory; re-applied twice, identical (432 parts).

## For the lead / Edward
- The featured item is still `FeaturedScissors` (red scissors): a hook, not touched, but it reads as a joke prop in a vault.
- The A_* doorway surround (A_Door) is now gunmetal on the corridor side too; the gate-corridor pass should match it.
- The weapon bays are high (10-15) because the eye-level wall is taken by the two rack units per side; RIVALS' niches are at
  eye level. A later pass could swap the rack units for eye-level pegboard niches.
- Queued for import: nothing (no Blender kit was needed).
