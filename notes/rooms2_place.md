# Rooms pass 2, placement in Studio (rooms2_place): Shop + Armory + both corridors

Done 2026-10-15, only in `Tacticals_rebuild.rbxl` (studio id e1d5a8da-8b35-4181-8da9-4d5eaa59c96a, the local copy, checked with
list_roblox_studios). **Not saved**: the lead saves with File > Save to File. Nothing was touched in the live "tacticals (placeId ...)"
studio, the RIVALS place or the replica. No computer use, no Blender, no RIVALS ids. Only our own TacHub1 variants and texture ids were used.

## Files
| What | Path |
|---|---|
| Placement script (idempotent, UNDO flag, runs after place_hub1 + hub2) | `fix/place_rooms2.lua` -> `python tools/run_luau.py fix/place_rooms2.lua [UNDO]` |
| Room hook / walk checks (read-only, restores what it touches) | `fix/check_rooms2.lua` -> output `out/rooms2/check_rooms2.txt` (**0 FAILS**) |
| Hub hook re-check | `fix/check_hub1.lua` -> `out/rooms2/check_hub1.txt` (all OK, same as hub2) |
| Capture set (12 cameras: 2 per corridor, 4 per room, player height + 3/4) | `python tools/rooms2_capture.py <prefix> [names]` |
| Captures | `out/rooms2/before_*.png`, `out/rooms2/after_*.png`, sheet **`out/rooms2/before_after.jpg`** (before left, after right) |
| Tuning trials | `out/rooms2/t1_*` (first colours), `t2_*`, `t3_*` (final olive) |

Note: the "before" captures show the state at the start of this pass: the imported rooms2 meshes (default grey Plastic) on top of the
old rooms. The original lobby look without the kit is in out/survey.

UNDO was tested as a round trip (UNDO, then re-apply). It un-hid 199 instances, put the kit back in `Workspace.rooms2` with its
imported look, returned K_Scale2/K_Marker2 to it, and restored the emblem, lights, NPCs and the hub olive. A second re-run hid 0
new instances, so the script is idempotent.

## What changed
1. **Structure.** The 212 kit meshes are now in `Workspace.LobbyMap.Rooms2`, one Model per piece (33 pieces), plus
   `Rooms2.Overlays` for the sign plates. `Workspace.rooms2` is gone. **`K_Scale2` and `K_Marker2` are in
   `ServerStorage._RebuildRemoved`.** They were not destroyed. They were verified before this pass: Size 10, (0, 120, 0).
   None of `LobbyMap.Rooms`, `Rooms.Shop`, `Rooms.Armory`, `Interact`, `NPCs` or `Signs` was renamed.
2. **Look per mesh** comes from the manifest: Color, Material, MaterialVariant (TacHub1), Reflectance 0, CastShadow off on Neon and
   glass, glass Transparency 0.6, CanTouch false everywhere. The imported values are kept in the `Rooms2_Orig` attribute on each part.
   - Overlays (own ids):
     - hazard stripe 4x1 on the Top of every `__hazard` (base 10,12,10 as in hub1, not the manifest's 255);
     - grime 4x4 black 0.93 on the sides of every `__wall_kick` (0.94 on the S_/A_Props crates, cases and drums);
     - louvre 0.6x1 on the Bottom of the S_/A_Lights and corridor `neon_lamp`;
     - panel lines 20x20 on the plinth and dais `disc_plate`.
3. **Collision** comes from the manifest:
   - 149 meshes collide: 7 Box (floor slabs, inserts, gun-wall mat) and 142 PreciseConvexDecomposition.
   - 63 do not collide and are not queryable: Neon, glass, labels, screens, sign boards, hazards, ceilings, beams, lights and lines.
     They also get the `NotCover` attribute.
4. **Hooks**
   - **NPC_Quartermaster** was raised 0.21 so its feet are on the staff deck (0.06). **NPC_Supply** was lowered 0.05 onto the supply
     deck (1.00). Their original pivots are in `Rooms2_OrigPivot`. Prompts, TalkLines and OpenPanel are unchanged.
   - **CounterEmblem** was buried inside the new counter body. It is now on the cream emblem plate, at (7, 1.65, 100.27), facing -Z,
     size 3.0 x 1.1. Its decal is unchanged. The original CFrame and Size are in attributes.
   - **RoomLights** moved to the homes in rooms2_kit.md, keeping their orientation (SpotLight faces): L_Entry, L_Counter (0, 12.6, 97),
     L_Pedestals, L_Racks at y 12.6; L_Dais (-10, 18.3, -96); L_GunWall (-6, 17, -106); L_Fill (0, 13.8, -90); L_BenchA/B at y 6.0.
     Tags, the `Room` attribute and the parents are unchanged.
   - **Bench lights dimmed 1.8/1.6 -> 0.9.** At y 6 the warm pool burnt the floor to 93,91,77. The original brightness is in
     `Rooms2_OrigBright`. RoomFX only toggles Enabled, so this is safe.
   - Unchanged:
     - `Interact.*` and FeaturedScissors (Spin 25; it clears the dais cap in 12 spin poses);
     - the RoomFX centres (all 9 room lights are 6-23 studs from their centre, radius 75);
     - `Signs` (the hub SHOP/ARMORY text).
5. **Sign text plates** are solid backing plates (39,40,37, 0.1 thick) whose back face sits 0.08 proud of the board face measured by ray
   (the hub2 lesson). They carry a SurfaceGui (Front, LightInfluence 0, cream 236,232,218, GothamSSm Heavy).
   - `SignText_ShopCounter` **SUPPLY**: the counter prompt is "Browse SUPPLY" and opens the Shop. The plate sits inside the
     olive Neon outline.
   - `SignText_GunWall` **ARMORY**.
   - `SignText_Supply` **SUPPLY**: NPC_Supply is the "SUPPLY CLERK" and opens the Shop.

   If Edward swaps the NPCs, change the three words in `SIGNS`. The shop board could read QUARTERMASTER to match its NPC tag.

## Hidden (restorable; attributes `Rooms2Hidden`, `Rooms2_T/_C/_Q/_Tc/_E`, separate from the Hub1/Hub2 sets)
213 instances are hidden in total:
- `Unique`: all 25 `U_Shop__*` / `U_Armory__*`. A bounds check confirmed each whole mesh is inside |x| < 35, 62 < |z| < 116.
- `Unique`: the `U_GateN__*` / `U_GateS__*` corridor meshes. They were hidden by bounds (whole mesh inside |x| < 8, 43.8 < |z| < 66);
  none was skipped. `emit_amber` was already hidden by Hub1.
- `Rooms.Shop`: K_MilCrate x2, K_AmmoCan x2, K_Pallet, K_WeaponCase, K_Drum.
- `Rooms.Armory`: WeaponsDisplay (whole folder), K_WeaponCase x2, K_AmmoCan x2, K_MilCrate x2, K_Drum.
- `FX.FX3.CorridorFiller` x6: the old corridor floor and side panels, now inside the new lining or under the plates.
- `LobbyMap.Lights`: 4 PointLights in the void beside the corridors (x +-14.4 / +-28.1, z +-51). The two old corridor lights at
  (0, 9, +-52) are **kept** and still light the corridors.

## Tuning under Future (measured on rendered pixels, then adjusted)
| Item | Manifest | Set | Rendered (measured) |
|---|---|---|---|
| Room floor field / border / insert | 62,62,60 / 36,36,34 / 80,79,76 | **hub2 values** 76,62,50 / 46,38,30 / 94,80,66 | shadow 43,48,50; lit 46-54 neutral; under the bench lights 70,70,62 (after dimming) |
| Walkway metal plates (corridor plate, door thresholds, gun-wall mat) | 108,107,104 TacFloorPlate | **95,85,78** | 64,71,75 (cool, light) -> **52,50,48** |
| Plinth / dais disc_plate | 75,75,72 | 88,76,64 (hub2 disc) | dark neutral |
| **Olive band** (rooms, corridors **and hub**) | 120,136,66 | trial 112,126,62 -> 118,112,58 -> **111,114,57** | 104,130,62 lime -> 111,114,57 mustard -> **103,117,56** near / 74,101,56 far (olive) |
| **Olive Neon** (rings, outlines; rooms **and hub**) | 88,101,48 | **66,72,36** | dark olive glow, no lime |
| Dais centre cap disc_center | 107,122,58 | 92,90,48 | olive |
| Drums | 107,122,58 | 70,82,52 (hub2 value) | military green |

**Hub:** `APPLY_TO_HUB = true` sets the same band (111,114,57) and Neon (66,72,36) on the 20 Hub1 `__band_olive` / `__neon_olive`
meshes. The hub's previous colours are in `Rooms2_HubOrigColor`, and UNDO restores them. Measured hub gate head band: 60,78,41.
To keep the hub as it was, set `APPLY_TO_HUB = false`.

Rule of thumb from the trials: on TacConcrete under this Sky, the rendered colour is about R x0.93, G x1.03 of the base near a lamp.
Further away, the blue-green sky specular adds green. Raise R and lower G in the base to keep olive from turning lime.

## Verified (fix/check_rooms2.lua, 0 fails)
- **Gates line up:** hub gate centre x 0.00, corridor centre x 0.00, offset 0.00 (N and S). Hub gate 10.80 wide x 12.15 high.
- **Corridors:**
  - Width is 9.80 at the frames for y 3-10.5, and 9.60 at y 1 (frame plinths).
  - Width is 10.80 between the frames.
  - Clear height is 12.15 for x -2..2, and 11.96 at x 4 under the haunches.
- **Doorways** are 11.00 at y 1/6/11 with 12.16 clear height (Shop z 66.5, Armory z -65.5).
- **Floors:**
  - Hub -> corridor -> room lane: max step 0.04 for x -3/0/3, both sides.
  - Shop and Armory floor 0.02-0.03; staff deck 0.06; supply deck 1.00; gun-wall mat 0.05.
  - Visual ceilings (query rays): shop lamps 12.77, beams 12.5; armory 19.94, beams 19.8; corridor lining 12.2.
- **Walk routes** were block-cast with a 2 x 4.5 x 2 box. All are clear:
  - spawn -> N gate -> round the plinth -> shop counter front, and back to the hub;
  - spawn -> S gate -> gun wall;
  - armory -> dais front;
  - armory -> supply counter front, and back to the hub.
- **Prompt reach** from walkable floor (customer side only for the counters):
  - Shop_Counter 3.0 / 9; GunWall_Kit 3.1 / 12; Armory_Dais 1.75 / 11;
  - NPC_Quartermaster 7.0 / 9; NPC_Supply 7.1 / 9.
  - All prompts have RequiresLineOfSight false, so Shop_Counter sitting inside the counter body is fine.
- **NPCs:** feet on the decks; no overlap with the kit (deck excluded).
- `fix/check_hub1.lua` is unchanged from hub2:
  - folders, 1 LobbySpawn, AssetCheck names, QueuePad 6, ExfilBarrier, RoomLight 29, 3 OpenPanel prompts;
  - gates 10.8 x 12.15, tunnel 22 x 18, Duels door 11 x 8;
  - crane / drone: no hits. Hub fidelity 7 Box + 82 PCD.

## Issues / for the next pass
- Edit-time captures only. Judge the final light levels in Play, where RoomFX switches the room lights near the camera. The rooms read
  well lit from the Neon lamps and the 9 room lights. No extra SurfaceLights were added; the budget comment in RoomFX is ~45 enabled lights.
- The olive band is large and close to the camera in the corridors, so it still dominates the corridor views (after_n2 / n4). It
  reads olive now, but it is the strongest colour in the lobby. A further step toward 104,108,56, or a narrower band in the corridor
  kit, is Edward's call.
- The hazard strips render with a cool blue-white sheen (SmoothPlastic sky specular), as in the hub.
- The `s4_shop_east` camera (24, 5.5, 72) sits inside a green prop in the Shop's SE corner. The view is still useful; move the camera
  if it is reused.
- Collision at the corridor frame plinths is 9.6 at ankle height (PCD hull + plinth), against 9.8 designed. That is harmless
  for walking.
- The staff areas behind both counters are reachable round the counter ends, as before. Nothing blocks players from walking behind
  the NPCs.

## Lessons
- Measure the board face per sign with rays: the A_Signs mesh holds two boards at different depths (gun wall -111.60, supply -110.30).
  The olive Neon outlines sit 0.12 proud of the face, so keep the text plate inside the outline.
- Under Future the bench task lights lowered to their lamp heads doubled the floor brightness. Re-measure after moving lights and tune
  Brightness, not the floor colour (RoomFX only touches Enabled).
- PCD on frame meshes narrows openings by ~0.1 a side at the plinths: check widths at several heights, not one.
- Prompt-reach checks must exclude the staff decks behind counters, or they report the NPC's own spot (0.19).
