# Rooms pass 3, placement in Studio (rooms3_place): Duels hall + west deck, Exfil hangar + helipad

Done 2026-10-15. All work was in `Tacticals_rebuild.rbxl` only: studio id 8ef4e21a-3525-484b-91af-79d7677aa213, the local copy, confirmed
with list_roblox_studios.

**Not saved.** The lead saves with File > Save to File.

Nothing was touched in:
- the live "tacticals (placeId ...)" studio;
- the RIVALS place;
- the replica.

No computer use, no Blender, no RIVALS ids. Only our own TacHub1 variants and texture ids were used.

## Files
| What | Path |
|---|---|
| Placement script (idempotent, UNDO flag; runs after place_hub1, hub2, place_rooms2) | `fix/place_rooms3.lua` -> `python tools/run_luau.py fix/place_rooms3.lua [UNDO]` |
| Hook / walk / camera checks (read-only, restores what it touches) | `fix/check_rooms3.lua` -> `out/rooms3/check_rooms3.txt` (**0 FAILS**) |
| Re-checks | `out/rooms3/check_hub1.txt` (all OK, same as rooms2 apart from the expected owner changes), `out/rooms3/check_rooms2.txt` (**0 FAILS**) |
| Capture set (10 cameras: Duels door/pads/1v1 boards/energy wall/deck; Exfil tunnel end/hangar/pad/ExfilFX camera) | `python tools/rooms3_capture.py <prefix> [names]` |
| Captures | `out/rooms3/before_*.png`, `out/rooms3/after_*.png`, sheet **`out/rooms3/before_after.jpg`** (before left, after right) |
| Diagnostic: ExfilBarrier briefly set to Transparency 1 for two shots, then restored to 0.2 (no attribute left) | `out/rooms3/t1_e1_tunnel_end.png`, `t1_e4_cutcam.png` |
| Hub cross-check after hiding U_East | `out/rooms3/r3_g3_west_stairs.png`, `r3_t1_top_landing.png`, `r3_c3_riser_east.png` (compare `out/hub2/after_*`) |

The "before" captures show the state at the start of this pass: the imported rooms3 meshes (default grey Plastic) on top of the old
Duels / Exfil shell.

### UNDO round trip
UNDO was tested as a round trip: UNDO, then re-apply, then re-apply again.
- UNDO un-hid 71 instances and put the kit back in `Workspace.rooms3` (172 meshes, imported look).
- It returned K_Scale3/K_Marker3 to `Workspace.rooms3`.
- It put back L_Hangar (y 15), both 1v1 Holo/PostCollide parts, the LobbySpark tag, the EnergyKey lights, U_East and the hub2 LipPlate.
- After UNDO, no `Rooms3_*` attribute was left anywhere.
- The re-apply hid 67 + 4 instances. A second re-apply hid 0, so the script is idempotent. The check gave 0 FAILS afterwards.

## What changed
1. **Structure.** The 170 kit meshes are now in `Workspace.LobbyMap.Rooms3`, one Model per piece (33 pieces). It also holds
   `Rooms3.Overlays` (sign plates) and `Rooms3.D_DoorFill` (doorway plate, see 5).
   - `Workspace.rooms3` is gone.
   - **`K_Scale3` / `K_Marker3` are in `ServerStorage._RebuildRemoved`.** They were not destroyed. They were verified at (0, 120, 0),
     Size 10, and at (20, 119, 2).
   - `Duels`, `Exfil`, `Heli`, `Lights`, `FX` and `Unique` were not renamed.
2. **Look per mesh** comes from the manifest, with the tuned values:
   - **Olive:** band 111,114,57 and Neon 66,72,36 (manifest 120,136,66 / 88,101,48).
   - **Floors:** 76,62,50 / 46,38,30 / 94,80,66, as in the manifest (hub2 compensation).
   - **Walkway plates:** D_Pass, D_Floor and E_Floor `plate_metal` at 95,85,78.
   - **Disc centre** 92,90,48; **drums** 70,82,52; **hazard base** 10,12,10 (the texture carries the stripes).
   - Reflectance 0. CastShadow is off on Neon, glass and clip. Glass has Transparency 0.6.
   - **X_Clip** has Transparency 1 and CanQuery false.
   - CanTouch is false on every mesh, and every mesh has the `NotCover` attribute.
   - The imported values are kept in `Rooms3_Orig`.
   - Overlays (own ids):
     - hazard stripe 4x1 on the Top of every `__hazard`;
     - grime on the sides of every `wall_kick` (0.93) and of the D_/E_ props and gear crates, cases and drums (0.94);
     - louvre on the Bottom of the D_Lights, E_Lights and D_Pass lamps;
     - panel lines 20x20 on the D_Pads kerbs.
3. **Collision** comes from the manifest:
   - 112 meshes collide: 14 Box (floor slabs, deck, passage plates) and 98 PreciseConvexDecomposition.
   - The other 58 do not collide and are not queryable.
   - **One change from the manifest:** `X_Clip__clip` uses **PCD, not Box**. A single Box around the whole clip mesh (the open edge plus
     both side walls) filled the pad: x 127.6..152.6, z +-28.6, y 1.4..18. It blocked the walk round the barrier and stood 0.25 in
     front of the ExfilBarrier. With PCD the clip slabs stay separate.
4. **Hooks.**
   - `Exfil.L_Hangar` moved to (114, 19.0, 0) under the downlight. Orientation, tag and `Room` are unchanged; the original is in
     `Rooms3_OrigCF`.
   - `L_Pad`, `ExfilBarrier`, `HatchPoint`, `CabinPoint`, `Heli` and `FX2.HeliN/S/End` are untouched.
   - Everything in `Duels` is untouched apart from the 1v1 fix below.
5. **Doorway plate (new, needed).**
   - **Problem:** the hub1 west wall has **no floor through the Duels door** (x -95..-90). The old `U_East__floor_metal` and
     `U_DuelsShell` carried it, and hiding them left a 4.8-stud hole at y 16 (found by the axis profile).
   - **Fix:** `Rooms3.D_DoorFill.DoorThreshold` is a Part at x -95.3..-90.0, z +-5.6, top 16.0.
     - Its east edge meets the hub top-landing plate edge, measured at x -90.00, so the surfaces do not overlap and cannot z-fight.
     - Metal + TacFloorPlate, 95,85,78. It collides and has `NotCover`.
     - The script builds it before the U_East check, so a fresh run sees it.
6. **Sign text** uses solid backing plates (39,40,37, 0.1 thick) whose back sits 0.08 proud of the board face, measured by ray along x.
   SurfaceGui Front, LightInfluence 0, cream text.
   - `SignText_Deck` **DECK** is over the west portal and faces the hall (board face x -139.10).
   - `SignText_Exfil` **EXFIL** is in the hangar header and faces the tunnel (board face x 123.90).
   - Not done: the per-cell team/slot label text and the pylon "1V1 / 2V2 / 3V3" text from rooms3_kit.md. The live PadBoards boards carry
     the mode, so this was left for a later pass.

## Hidden (restorable; attributes `Rooms3Hidden`, `Rooms3_T/_C/_Q/_Tc/_E`, `Rooms3_Tags`, separate from the Hub1/Hub2/Rooms2 sets)
71 instances are hidden in total.
- `Unique` (41 meshes): all `U_DuelsShell__*` (6), `U_DuelWalls__*` (5), `U_DuelPads__*` (8, visual pad meshes only), `U_EnergyWall__*`
  (10, incl. its deck floor), `U_Exfil__*` (9), and `U_East__concrete / dark_metal / floor_metal`.
- **U_East was hidden only after a ray check** of the hub side (x -91..-66, z -45..45). Every hub point where U_East was the top surface
  was checked:
  - On the route, nothing is lost. The landing is 4.47 -> 4.00 on H_Landing, the stair top 16.00 on H_Stairs, and the doorway is on the
    new plate.
  - Hiding it also removes the old riser side ramps at |z| 9-10, outside the hub riser cheeks (open hub floor at 0 there, not on the
    route). The g3 recapture shows the riser is cleaner.
- **Energy-wall FX:**
  - `FX.Arcs` (16 Beams);
  - `FX.EnergyMotes` (emitter);
  - `FX.SparkDuels` (Sparks + Flash). Its **`LobbySpark` tag was removed** and kept in `Rooms3_Tags`, because LobbyFX calls `Emit()` on
    tagged sparks and that works even on a disabled emitter.
  - `Lights.EnergyKey` x2 (SurfaceLights).

  No hook needs any of them (grep: only LobbyFX's tag loop).
- **hub2 `Hub2Add.LipPlate` + 3 ramps**: they covered the old U_East lip, which is gone now. The floor under them without them is 16.00
  everywhere. Note: re-running `fix/hub2.lua` rebuilds Hub2Add and shows them again. If that happens, re-run place_rooms3 or drop the lip
  from hub2.lua.
- **Kept:**
  - `Lights.TargetTop`, `Lights.PointLight` (-146, 22, 0), now inside the passage;
  - `FX.Shafts`, `FX.DustDuels`, the 4 FX3 Duels beacons and `Duels.SkyBeam`.

## The 1v1 fix (Holo + PostCollide)
| | before | now |
|---|---|---|
| `Pad_1v1_A/B.Holo` | (-92.8, 24.5, -/+18.75), inside the hub1 west wall | **(-100.5, 24.5, -/+18.5)** |
| `Pad_1v1_A/B.PostCollide` | (-92.8, 18.4, -/+18.75), buried in the wall | **(-96.6, 18.4, -/+18.5)**, inside the kit pylon x -97.6..-95.6, same size |

Names, children, attributes, tags and collision groups are unchanged. Only the CFrame position changed, and the original is in
`Rooms3_OrigCF`.

**Why not (-96.6, 24.5, +-18.5) for the Holo, as rooms3_kit.md proposed:**
1. **Visibility.** The PadBoards billboard is 11 x 6 and faces the camera. Centred at x -96.6 it is only 1.6 studs from the wall face
   (x -95). The ray test shows 40 % of the board behind the wall from the pads, the door threshold and the hall centre. At -100.5 every
   viewpoint sees **100 %** of it: door threshold (-96.5, 20.5, 0), inside the door, hall centre, west portal, and both team cells of the
   pad (15 rays each).
2. **Step-off.** QueueManager's `stepOffCFrame` places a leaving or kicked player at `zone + unit(zone - Holo) * (half + 4)`. Holo is
   `bay.screens[1]`, so the Holo position steers where players land.

   | Holo at | Team2 lands at | Result |
   |---|---|---|
   | -96.6 | (-102.97, -33.10) | **inside the 3v3_A Team1 zone**, so the player joins that queue |
   | old -92.8 | (-106.9, -30.7) | inside the same zone already (pre-existing bug) |
   | -100.5 | (-96.49, -/+33.19); Team1 at (-96.24, -/+4.30) | free floor in no zone; the body box is clear |

The PostCollide stays on the pylon footprint, as the kit designed. The board now floats over the pad's centre line, about 4 studs west of
the pylon and ~8 studs above the floor.

**Script grep** (out/survey/src, 107 files):
- Only QueueManager and PadBoards read `Holo`. Nothing reads `PostCollide`. PadFX and DuelPads do not use Holo; PadFX looks for the
  missing `LobbyMap.Deployment`.
- QueueManager:
  - `holo:SetAttribute("BayStatus")`;
  - `bay.platform` = Holo, used only for its position / CFrame. In the step-off fallback and QUICK JOIN look direction, both paths are
    relative to the zones.
  - `stepOffCFrame`, as above.
- PadBoards:
  - `drawBoard` adorns the board to Holo (`StudsOffsetWorldSpace` 0, 2.6, 0);
  - the NEAR = 20 JOIN-button distance is measured to `Holo.Position`.
  - From the hall, NEAR now covers more of the hall around the 1v1 pads, which is still sensible.
- No script hard-codes Holo coordinates.

**Visual check:** `after_d3_1v1_boards` (hall centre looking at the door) and `after_d4_1v1_pad` (standing by the 1v1 A pad) show both
1v1 boards whole. `after_d1_door_hall` and `after_d2_pads_34` show them from the door and from above.

## Verified (fix/check_rooms3.lua, 0 FAILS)
- **Openings:**
  - Duels door 10.90-11.00 x 7.97.
  - West portal 8.90-9.00 x 11.75 (PCD hull; design 12).
  - Passage 9.80 x 12.28 at 5 stations.
  - Tunnel end 21.90-22.00 x 17.97.
  - Hangar mouth 51.00 x 16.96: the 52.4 is between the cheeks, and the roll-up door guide channels (0.7 each) stand inside them.
- **Floors:**
  - Duels hall walkable 16.03-16.34, no gaps (team plates 16.34).
  - Deck 16.02.
  - Hangar 0.02-0.12; pad 0.02.
  - Axis hub top landing -> door -> hall -> passage -> deck: max step 0.06 after the doorway plate.
  - Tunnel -> hangar -> pad at z -6/0/6: max step 0.05.
  - The kit is never above the team plates in the cell cores (16.03-16.14). On the 1v1 cells' east rims the wall cladding is at x -95.25,
    because the cells reach x -94.5, as in the survey.
- **Walk routes** (block cast 2 x 4.5 x 2), all clear:
  - hub top landing -> Duels door -> hall;
  - hall -> all 12 team cells;
  - hall -> west portal -> passage -> deck, and back to the top landing;
  - hub -> east tunnel -> hangar respawn;
  - hangar -> barrier face;
  - hangar -> pad round the barrier (z -18), and pad -> hub.
- **ExfilBarrier:** tag + CanTouch. A character walking along +x at z -10/-5/0/5/10 meets no obstacle before the barrier.
- **Hangar respawn** (112, 3.5, 0): floor 0.03; body box clear (precise test). The lowest kit point is -12, above the fall-catch line at -25.
- **ExfilFX camera:**
  - The start shot `lookAt((120,9,-18),(133,4,2))` is clear.
  - The lift path, e = 0..2.6 s, camera to the cabin target and to +3 / -2 studs from it, is clear of all visible geometry.
  - Heli lift sweep, the heli parts moved by the lift transform: no overlap with visible kit for e 0.2..2.6.
- **Duels hooks:**
  - QueuePad 6; every pad has 8 barriers in `DuelBarrier`.
  - DuelQueued x DuelBarrier is non-collidable.
  - Pad pivots are 19-40 studs from the Duels door. QUICK JOIN needs within 40 of the pivot, and players can stand next to every pad.
- **Exfil hooks:**
  - L_Hangar / L_Pad are 37 / 22 from the RoomFX Exfil centre (r 75).
  - Heli attributes Mast / TailHub / TailAxis are present, with 6 Rotor parts.
  - FX2.HeliN/S/End are present and collide.
- `check_hub1`:
  - every hook OK; Duels door 11 x 8.00 at x -89 / -92, now floored at 16 (plate);
  - crane / drone no hits;
  - hub fidelity unchanged (7 Box + 82 PCD).
- `check_rooms2`: 0 FAILS.

## Issues / for the lead
- **1v1 board position** differs from rooms3_kit.md (see above). If Edward wants the board over the pylon, it must be at least ~5.5 studs
  from the wall (x <= -100.5) to stay whole, so the pylon would have to move into the hall. Change `HOLO_POS` in the script.
- **Pre-existing QueueManager step-off spots** (not caused by this pass, reported by the check):
  - 2v2 Team2 leavers land inside the 3v3 Team2 zones (-120.9, -/+33.4).
  - 3v3 leavers are placed at z -/+45.1, inside the hall walls (no floor at x -127.4). This was already so with the old walls at z +-44.9.
  - The fix belongs in QueueManager (clamp to the hall, or test the landing spot). Alternatively, move the 2v2/3v3 Holo parts the same
    way, but it is a script issue.
- **2v2 boards** are 67-93 % visible: the Holo at x -137.4 is 3.6 from the glass screen and piers. Same cause as the 1v1. Moving them to
  x ~-133 would fix it, but that is outside this brief.
- **Holo beams float in the sky** (pre-existing): every Holo's two Attachments have local offsets equal to their old world coordinates.
  - The Beams draw at e.g. (-193, 45..48, -/+37) for the 1v1 pads, (-275, 45, -/+40) for 2v2 and (-228, 45, -/+57) for 3v3: over the deck
    and the sky.
  - Moving the Holo moved them by the same delta.
  - Fix later by setting each Attachment's local Position to (0, -3.8, 0) / (0, -1, 0), or by disabling the Beams. Not done: Duels children
    were to stay untouched.
- **Cream rectangle behind the heli** in the Exfil views: it is TimesSquare's `BuildingBack` billboard area (x ~174). CityBillboard
  images load at runtime, so it is blank cream in edit captures. It was visible before too (before_e4). The wider mouth now frames it.
  Check in Play.
- **NPC_DuelsOfficer** (-86.4, 19.2, 7.9) stands in the 2-3 stud gap between the hub-side door portal cheek (x -88, z 5-9) and the
  stair rail. This is hub1 layout, not changed here. Players coming off the stairs pass beside it.
- **Pad north side:** a walk along z 24.5 meets the ground power unit (E_Gear at 134.6, 24.9). Players use the south side or the centre,
  and the heli tail sits over z 14-23.
- The before captures show the default-grey import, so the original Duels / Exfil look is in out/survey.
- Edit-time captures only. Judge the light levels in Play (RoomFX switches L_Hangar / L_Pad near the camera).

## Lessons
- **Check every walkable seam between kits, not only the surfaces you hide.** The doorway through the hub wall belonged to neither kit.
  Its floor was an old mesh (U_East / U_DuelsShell) that the hub pass kept "because it carried the Duels floor". A floor profile along the
  route axis (x step 1 or 0.5) catches this. A grid check limited to the hub side did not.
- **Box fidelity on a multi-slab mesh is one box around all of it.** For clip meshes made of several walls, use PCD (or split the mesh).
  The walk-round-the-barrier route caught it.
- **Billboards need clearance from walls equal to half their width.** A camera-facing BillboardGui swings its edges into a wall from
  oblique views. Ray-sample the whole board (5 x 3 grid), not its centre.
- **Moving a hook part can change gameplay through relative maths.** Holo = `bay.screens[1]` steers QueueManager's step-off direction.
  Simulate the formula and test the landing spot against the other zones and the geometry.
- **Overlap tests:** `GetPartBoundsInBox` reports every big mesh whose AABB covers the point (walls spanning the hall). For "is the body
  free" use `GetPartsInPart` with a temporary part, which follows the real collision geometry.
- **LobbyFX `LobbySpark`:** `Emit()` fires even on a disabled emitter. Untag (and keep the tag in an attribute for UNDO) as well as disable.
