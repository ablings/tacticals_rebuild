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

## Round 2 (2026-10-15 night): swap-ready weapon slots, eye-level niches, navy -> gunmetal
Script `fix/polish_armory2.lua` (run after `polish_armory.lua`; UNDO flag; originals in attribute `PolishArmory2_Orig`, typed JSON).
New parts in `Polish.Armory.Round2` (455 parts, 400 of them the 20 placeholder rifles) + `FeaturedScissors.WeaponSlot_Featured_1`;
config `ServerStorage.ArmoryWeaponSlots`. Swap guide: **`notes/armory_weapon_slots.md`**. Sheet: `python tools/polish_armory2_sheet.py`
-> `out/polish/armory/sheet2.jpg` (round 1 | round 2 | close-ups, RIVALS row). Not saved.

1. **Weapon slots (20).** Featured 1 (inside the FeaturedScissors hook, scissors hidden, Spin/pivot kept), GunWall 9 (on the three
   existing rails), RackW/RackE 8 (eye-level niches), Bench 2. Each slot = Model + invisible Anchor (PrimaryPart, Attachment Mount)
   + attributes, one weld-free `Weapon` clone of `Display_AutoRifle`. `ArmoryWeaponSlots.Apply()` fits any catalogue model
   (scale to MaxLength, muzzle along the anchor, magazine down, rest on the anchor line).
2. **Baked weapons hidden** (isolated per material mesh, checked by capture): `A_GunWall__case_dark / drum_olive / dark_metal` (the
   12 rifles; rails, posts and backing stay), `A_Benches__case_dark` (bench guns), `A_Displays__dark_metal / drum_olive` (the two
   guns in the glass case; the case keeps its ammo blocks, too shallow for a rifle slot), all of `A_Racks` (the two low rack units
   per side with vertical rifles).
3. **Eye level.** Pegboard niches (y 0.95-6.5, 7.5-8.3 wide) where the rack units stood: near-black backing, Plastic pegboard with
   the own `TX_grate_alpha` at 0.6-stud tiles (light bars), olive top frame, side cheeks, a hood with a Neon strip, a ledge with a
   sage glow lip and a stencil plate `RACK W-1 · SN 4471-TAC-211`, two rifles per niche on pegs (1.45x). The round-1 high bays keep
   their slotted panels as **ammo lockers** (guns and pegs hidden, stencil `LOCKER W-01 / AMMO · SEALED`).
4. **Navy -> gunmetal (measured).** Cause: every surface was blue, not just metal: cool lights (212,226,255), cool Neon
   (206,222,240) and the blue sky diffuse (`EnvironmentDiffuseScale` 1) add blue that dominates dark colours (floor 30,32,34
   rendered 33,49,66: ratio 1.10/1.54/1.95). Fix: lights and Neon to neutral (L_* 240,236,226, fill 196,186,170, dais key
   255,250,240, strips 214,212,204), ceiling / ceiling trim / beams / light housings / upper wall / trims to **Plastic**, and the
   envelope colours divided by the measured per-channel render ratio (60% of the full correction, then hand-tuned where lit faces
   went brown). `tools/part_pixels.py` (camera rays per pixel -> part -> mean rendered colour) and `tools/neutralise.py` do the
   measuring. Blue minus red, entry view: floor +33 -> +5, wall body +42 -> +9, upper wall +43 -> +7, kick +33 -> +4, ceiling trim
   +39 -> 0, beams +29 -> +7, gun-wall backing +38 -> 0, light housings +35 -> +4.
5. **Review leftovers.** Gun wall filled (9 slots). `NPC_Supply.Tag` 160 x 34 px -> Scale 3.6 x 0.72 (studs), offset 3.2 -> 2.0
   (centre y ~7.9, well under the SUPPLY sign at 11.1-12.5; no more clipped letter). Kelly-green crates (`A_Props / A_Benches /
   A_Supply__crate_green`, AmmoStock `F_Crate4A__crate_green`, 65,94,56) -> 78,82,46 (dark olive under neutral light). Bench,
   display-case, dais and supply metal got the same blue correction.

Logic checks: `check_polish_armory` (extended: slots, baked meshes) **0 clips** (186 probes; the first runs found niche ends in the
pier plinth at z -88.4 and hoods in the band trim, and two gun-wall optics in the frame trim: fixed), 20 slots ok, 0 joints, 0 baked
meshes visible, 0 new lights (67 enabled in Play, as before), 10 shadow casters. `check_rooms2` FAILS 0, `check_rooms3` routes
clear, `check_hub1` hooks ok, `check_training` ALL OK. Play walk (x3-4): doorway (0,-74) -> west niches (-27,-85), (-27,-96) ->
gun-wall front (-2,-104.5) -> east niches (27,-95), (27,-84) -> dais side (-4,-91): all reached. Hooks in Play: **E at the dais
opened the Kit panel (ArmoryUI.Armory), E at the gun wall opened it too**; NPC_Supply prompt enabled (OpenPanel=Shop, unchanged);
FeaturedScissors turned 25 deg in 1 s with the rifle on the axis. Console: baseline only. UNDO round trip: restored 452
instances (colours, scissors, racks, tag, lights), 0 attributes left; re-applied twice, identical (455 parts).

## Round 3 (2026-10-16 night): three small fixes from review_armory2
**Re-run order: `fix/polish_armory.lua` -> `fix/polish_armory2.lua` -> `fix/polish_armory3.lua`** (armory2 rebuilds the slots, so
armory3 must follow it). UNDO: `python tools/run_luau.py fix/polish_armory3.lua UNDO` (restores the 9 gun-wall anchors and Gap, refits,
removes `Polish.Armory.Round3`). Sheet: `out/polish/armory/sheet3.jpg` (before / after: gun wall, dais, entry).
1. **Featured rifle lost on its dais:** the crate stack behind it is part of the room-wide merged `A_Props__crate_green` mesh, so it
   can't move alone. A dark freestanding backdrop (`Round3.FeaturedBackdrop`: 6 x 5.8 warm near-black Plastic panel, dark-olive Neon
   edges, plinth with a FEATURED · WPN 01 stencil) stands on the dais' far side (235 deg, r 9.4, at (-15.4,-103.7)), outside the rope
   posts (r 6.4) and the floor ring lines (end r 8.6). Panel and plinth collide (2 parts). The spinning rifle now reads against it from
   the entrance and the dais approach.
2. **Gun-wall rifles seated:** each `WeaponSlot_GunWall_n` Anchor moved down by the placeholder's magazine drop (0.46: lowest body point
   = butt pad, above the magazine foot) and `Gap` 0.1 -> 0.04; originals in `PolishArmory3_OrigY` / `PolishArmory3_OrigGap`. The stock
   rests at rail-top height against the rail face, the magazine hangs in front of the rail, two pegs per slot (`Round3.GunWallPegs`,
   fitted by ray to the body underside) carry the handguard and stock. `ArmoryWeaponSlots.Apply()` still works unchanged (tested: 20/20,
   0 failures, GunWall_5 moved 0.000 after a re-Apply).
3. **"Bolt heads":** the old baked guns left 8 support pins in `A_GunWall__trim_metal` (merged with the rails, 0.8 proud, tips z -110.98
   at x -13.6/-9.2/-4.7/-0.3, y 4.2/7.7/11.2). Each tip has a 0.22 x 0.34 cap in the wall-plate material and colour (darkened 20%).
   The two round dots at (-6.7,8.0) / (-5.7,8.0) are rivets of our own `TacConcretePanels` texture, not old hardware: left as they are.
Checks: check_polish_armory 0 clips (188 probes; one first-run clip, the plinth on the floor ring lines at r 7.6, fixed by moving out),
20 slots ok, 0 lights; Play walk to the backdrop front (-14,-98) and the gun-wall front behind it (-11.6,-106.2); Spin 25.1 deg/s.
The lime band was left alone (lobby-wide decision for the final lap).
