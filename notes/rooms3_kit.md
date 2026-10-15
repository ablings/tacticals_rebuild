# Rooms pass 3 (rooms3): Duels hall + west gate/deck, Exfil hangar + helicopter pad, Blender kit

Status 2026-10-15: built in Blender 5.2 and exported. **Not in Studio** (brief_rooms3.md: Blender only; another agent is in Studio).
Nothing in Roblox Studio was touched. All geometry is own work (bmesh, hub_kit.py / rooms2_kit.py helpers); no RIVALS ids, meshes or
images. **No new textures.** Nothing committed.

## Files
| What | Path |
|---|---|
| Kit FBX (in place, world/Studio coordinates) | `kit/rooms3.fbx` (172 meshes, 81.9k tris, largest mesh 3.3k `D_Walls__wall_plate`; 2.1 MB) |
| Blender file | `kit/rooms3_kit.blend`: collections `R3_Shell`, `R3_Hero`, `R3_Props`, `R3_Markers`, `R3_Clip` (exported); `HubContext` (hub1 kit) and `PV_Proxies` (grey stand-ins for pad plates, heli, ExfilBarrier) are preview-only, **not exported** |
| Manifest | `kit/rooms3_manifest.json`: as rooms2 (piece, material slot, `rgb` = Studio colour, `rgb_kit`, `material_studio`, `variant` + `variant_folder` MaterialService.TacHub1, `can_collide`, `collision_fidelity`, `cast_shadow`, `transparency`, `texture_overlay`, tris, size/centre in Studio coords) |
| Generator | `tools/rooms3_kit.py` (execs rooms2_kit.py, which execs hub_kit.py: same materials, bevels, UVs, axis conversion) |
| Previews | `tools/rooms3_preview.py`; `out/rooms3/bl_*.png` (16 views incl. `bl_exfil_cutcam` = the ExfilFX camera), contact sheet **`out/rooms3/bl_contact.jpg`** |

Rebuild: open `kit/rooms3_kit.blend` (wm.open_mainfile, never read_homefile), `g={"__name__":"__main__"}; exec(open(".../tools/rooms3_kit.py").read(), g)`;
previews: put `PADS` in `bpy.app.driver_namespace["R3"]`, exec rooms3_preview, `setup()`, `render_all()`; export the five R3_ collections
with the hub_export.py FBX settings (-Z forward, Y up, modifiers applied, FACE smoothing).

## Axes, scale, markers, textures
- Same convention as hub1/rooms2: authored in Studio coords, Blender (x, y, z) = (-Xs, Zs, Ys); mesh origin = bounds centre. Import 3D
  with **Insert Using Scene Position**, group Gunsy Funsy, Anchored.
- **`K_Scale3`**: 10-stud cube centred at Studio (0, 120, 0) (Size/10 = import scale). **`K_Marker3`** (Neon L): long arm x 15..25 at
  y 115-117 (+X east), upright at the west end to y 123, short arm toward +Z (z 1..5). Mirrored = axes wrong. Move both to
  `ServerStorage._RebuildRemoved` after the check.
- **Texture carrier: not needed.** Every slot uses the uploaded TacHub1 variants (`tex/asset_ids.json`) or a flat colour. Texture
  overlays from existing ids: `TX_hazard_stripe` (4x1, Top) on every `__hazard` (door/portal thresholds, mouth sill, helipad corner
  brackets, deck end), `TX_louvre` optional on lamp strips, `TX_overlay_panel_lines` optional on the pad kerbs.
- Manifest colours = hub1_place olive decisions (band 120,136,66, Neon olive 88,101,48) **plus hub2's Future compensation**
  (floor_field 76,62,50, floor_border 46,38,30, floor_insert 94,80,66, disc_plate 88,76,64, drum_olive 70,82,52) so the rooms match
  the placed hub. The kit material colour is in `rgb_kit`. (rooms2's manifest predates hub2: give it the same floor/drum values.)
- New slot `clip` (X_Clip): SmoothPlastic, **Transparency 1**, CanCollide true, Box, CastShadow false, CanQuery false.

## Footprints kept
| Space | Kit | Check |
|---|---|---|
| Duels hall | floor top **16.0**, x -140..-95, z -45..45 (walls proud ~0.3-1.2 inside) | walkable x -138..-92 in the survey: the hub1 west wall already puts the Duels face at **x -95** (see 1v1 issue below) |
| Duels door | duels-side portal on the hub wall face x -95 | **11.0 wide x 8.0** (reveal outside z +-5.5, head 24.0) |
| West gate (old energy-wall gap) | screen x -142..-140, passage x -155..-142 | **9.0 wide x 12.0** (y 16-28) at the portal and at the passage ring frames |
| West deck | floor top 16.0, x -200..-155, z -30..30; kerb + rail inside the invisible HeliN/S/End walls | |
| Hangar | x 105..126, z -27..27, floor 0, ceiling **20** (beams 18.2, lamp strips 19.3) | tunnel end **22.0 x 18.0** (cheeks z +-11, head 18) |
| Hangar mouth | x 124.6..127.6 | **52.4 wide** (cheeks z +-26.2), **17.0 high** under the rolled-up door slats (old: open to the roof at 20) |
| Pad | x 129..152, z -27..27, floor 0; side blast walls to 10.4 + rail to 13.8; open edge x 152 (kerb 1.4 + rail) | invisible clip to y 18 on the open edge and over the side walls (the old walls/rail reached ~18) |

## What is in each space (pieces = `<piece>__<material>`)
Same language as hub/rooms2: dark slab floors with darkest border + metal kerb, banded walls (kick, **olive band 7.1-9.9 above the
floor**, panelled body, dark band, ribbed upper, canted cornice), concrete piers with metal plinth/capital and RIVALS capsule lights,
cream Neon lane lines, dark-olive Neon rings, cream/near-black hazard tape, military-green kit.

**Duels (base y 16)** - `D_Walls` N/S walls x -142..-95 to y 70 (kick 16-23, band 23.1-25.9, body 26-40 with 2x2 plates per bay,
dark band 40-44, ribbed upper 44-58 with sky windows in alternate bays and lamp lines between, cornice 58-64, top fill to 70) and
the cladding over the hub wall's Duels face (x -95); corner fills x -97..-90. `D_Piers` on x -128.75/-117.5/-106.25 (N/S) and z +-37.5
(east), capsule lights at y 30.2 (`D_Lights`). `D_Door` duels-side portal (band across the head, threshold hazard, label plate).
`D_West` = the old energy wall rebuilt as a **glazed sky screen**: solid kick + band to y 26, sill, glass 27-57.6 on metal mullions
and transoms, piers at z +-26 with capsule lights, portal (cheeks, reveal, band across the head 29-31) and a DECK sign board (32.8-35.2).
`D_Pass` lined passage x -155..-142 (corrugated cladding, band, ring frames, lamp strip, cream lane lines) + deck-side end portal.
`D_Floor`/`D_Lines` slab grid, centre lane insert (gate to door) with cream lines, **centre medallion at (-114, 0)** (dark disc,
metal ring with ticks, dark-olive Neon ring broken at the lane, cream inner ring, cream arrowheads to both exits).
**`D_Pads`** per pad: metal kerb ring outside the barrier rectangle, **Team1 cells outlined in cream Neon, Team2 in olive Neon**
(RIVALS purple/gold role), cream label plates on the kerb at each cell (team/slot text by SurfaceGui), dark split markers, and a
**pylon on each PostCollide footprint** (2 x 5.6 x 2: concrete with metal plinth/cap, olive band, cream/olive Neon strips facing
their team cell, cream mode plates on the other two faces for "1V1 / 2V2 / 3V3 + A/B" SurfaceGui text). The live PadBoards
billboard keeps floating over the Holo part above it. `D_Roof` perimeter ring (y 66-70, 9-11 deep) with glossy coffers and lamp
strips, **open sky well** x -131..-104, z -36..36 framed by a fascia and an olive Neon line; `D_Trusses` three open steel trusses
across the well (x -124.5/-117.5/-110.5, chords 62.4-70, verticals + diagonals, knee brackets) with tie beams and 12 flood boxes.
`D_Base` skirt under the hall (y 0.5-16, band at 11-13). `D_Deck` deck floor + lane + underside keel, `D_DeckRail` kerb with cream
Neon + guard rails, `D_Props` crate/case/drum stacks, two lookout rangefinders on tripods, two floodlight masts.

**Exfil (base y 0)** - `E_Walls` hangar N/S/W walls (kick, band, body 10-15.4 with plates, dark band, ribbed upper, cornice to 20),
`E_Piers` x 110/116/122 with capsule lights, `E_Portal` hangar-side tunnel portal (cheeks + capsule lights, HUB label plate),
`E_Ceiling`/`E_Beams`/`E_Lights` (slab 20-21.5, I-beams on the pier lines, purlins z +-13.5, coffers, lamp strips x 107.5/119/124,
**downlight at (114, 19.25, 0) = L_Hangar's home**), `E_Mouth` (cheek columns, roll-up door guide channels, header, the rolled-up
door's two bottom slats with an olive stripe, capsule lights facing the pad), `E_Signs` EXFIL board inside the header
(y 15.4-17.9, above every cutscene sightline). `E_Floor` hangar slabs + corrugated lane with cream lines continuing the tunnel's (z
+-8.4), **mouth sill with a cream Neon light-curtain emitter strip exactly under the ExfilBarrier** (x 127.31-127.69, z -12.2..12.2)
and two metal end blocks, pad deck slabs. **`E_Helipad`** centred (137, 0): near-black disc r 6, cream ring r 6-6.7, cream "H"
(strokes along +x, read from the hangar), 16 cream edge lights, hazard corner brackets on an 17-stud square. `E_PadWalls` side blast
walls (kick, band, cap, piers, plates) + `E_Rail`, open sky edge x 152 (kerb with cream Neon line, olive edge studs, guard rail).
`E_Base` floating underside (slab -6..-1, band, chamfered keels, beam). `E_Props` north bay: tool wall, workbench with task lamp,
parts shelving, wheeled tool chest, crate stack by the mouth; south bay (behind the camera): 4 pilot lockers, bench seat, drum.
`E_Gear` on the pad: **fuel bowser** (olive tank, straps, reel, drawbar, 4 wheels) north-east, **ground power unit** (green, louvres,
panel, cable coil) south-east, drums, crates by the north mouth cheek, two floodlight masts at the open corners, tie-down eyes.
`X_Clip` invisible clip walls.

## Hooks: current position -> home / action
| Hook | Now (survey) | New home / action |
|---|---|---|
| `Duels` folder, 6 `Pad_*` Models (tag QueuePad, QueueName, PlayersPerTeam, Team1/2, Team1/2Barrier, Holo, PostCollide, BayId) | as surveyed | **Untouched.** Kit dresses around the barrier rectangles (kerb starts 0.48 outside them) and puts a pylon on each PostCollide footprint. Collision groups DuelQueued/DuelBarrier untouched. |
| **Pad_1v1_A / B Holo (-92.5, 24.5, -/+18.5) + PostCollide (-94..-92)** | inside the **hub1 west wall** (x -95..-90) | **Decision for the lead:** since hub1 the 1v1 PadBoards billboards (AlwaysOnTop false, centre x -92.5) are behind the wall face and the posts are buried. The kit puts the 1v1 pylons at **x -97.6..-95.6** (z -19.5..-17.5 / 17.5..19.5). Recommended: move each 1v1 `Holo` to **(-96.6, 24.5, -/+18.5)** and `PostCollide` to x -97.6..-95.6 (same size). The pad zones and barriers stay as they are (their last ~2 studs are inside the wall, as now). |
| Team1Plate / Team2Plate (Parts, top ~16.3) | | Optional, RIVALS pad floor: Metal 108,107,104 + Texture `TX_overlay_panel_lines` 20x20 Top, tint 81 (Team1) / 107,122,58 (Team2). |
| `NPC_DuelsOfficer` | (-86.4, 19.2, 7.9) after hub1 | Hub side, unaffected. |
| DUELS sign | hub side (H_Signs) | Unaffected. New duels-side label plate over the door (EXIT/HUB) and the DECK board over the west portal (SurfaceGui text). |
| `FX2.HeliN/HeliS/HeliEnd` (invisible deck walls) | z +-30, x -200 | **Keep.** Deck rails sit 0.6 inside them. |
| `Exfil.ExfilBarrier` (tag ExfilBarrier) | (127.5, 6.45, 0), 0.3 x 13.2 x 24 | **Untouched**; the Neon emitter strip sits under it, sill blocks at its ends (z +-12.6..13.6). |
| `Exfil.HatchPoint` / `CabinPoint` | (127, 3, 0) / (132, 4.5, 0) | Untouched; nothing of the kit near them. |
| `Heli` model (Rotor attrs, Mast/TailHub/TailAxis) | x 119-147, z -14..23, rotor y ~10 | Kept in place. Clearances: mouth slats bottom 17.0 and hangar beams 18.2 over the rotor; crates/bowser outside the rotor disc and below the tail. |
| **ExfilFX camera** `lookAt((120,9,-18),(133,4,2))` + lift path | | **Clear**: Blender ray test of the camera path for e = 0..2.6 s to the heli pivot (and +3 / -2 studs) hit **nothing** in the kit. Kept free: x 116..127, z -27..+4 of props; EXFIL board above 15.4. |
| Hangar respawn HANGAR (112, 3.5, 0) | | Open floor (lane insert top 0.03). Fall-catch rule unchanged (no floors below y -25: kit underside ends at -12). |
| RoomLight `Exfil.L_Hangar` (Room=Exfil) | (114, ~15, 0) | **(114, 19.0, 0)** under the new downlight housing. |
| RoomLight `Exfil.L_Pad` | (133, 24, 0) | Keep (open sky over the heli); optionally SurfaceLights in the two pad mast heads (149.6, 13.5-14.6, +-24.2) facing -x, same tag/attribute. RoomFX centre Exfil (150,10,0) r 75 covers hangar and pad. |
| `Lights.PointLight` (-146, 22, 0) | in the old gap | Now inside the west passage (roof 28.6): keep, or move into the passage lamp strip (-148.5, 28.1, 0). |
| `Lights.EnergyKey` x2 (x -152, y 16-68) | in the old energy wall | Hide (no energy field any more), or keep as cool fill through the glass. |
| `Lights.TargetTop` (-115, 50, 0), `FX.Shafts` (-120, 30, 0), `FX3` Duels beacons | | Keep: open well above the medallion. |
| `FX.Arcs` (-146,40,0), `FX.EnergyMotes` (x -145..-141), `FX.SparkDuels` | energy-wall effects | Hide (they belong to the energy wall that is now the glass screen) or keep motes as dust behind the glass: Edward's call. |
| LobbyFX breathing `U_EnergyWall__emit*` | | Harmless once hidden (it only tweens colour). |

## What the placement script must do (next pass, Tacticals_rebuild.rbxl only, File > Save to File only)
1. Import `kit/rooms3.fbx` (Import 3D, Gunsy Funsy, Insert Using Scene Position, Anchored); check `K_Scale3` / `K_Marker3`, then move them
   to `ServerStorage._RebuildRemoved`. Parent under a new `Workspace.LobbyMap.Rooms3` (one Model per piece). Do not rename `Duels`,
   `Exfil`, `Heli`, `Lights`, `FX`, `Unique`.
2. Per mesh from the manifest: Color = `rgb`, Material = `material_studio`, MaterialVariant = `variant`, CastShadow false on Neon/glass/clip,
   glass Transparency 0.6, **X_Clip Transparency 1 + CanQuery false**, CanTouch false everywhere, hazard Texture overlays, attribute
   `NotCover` on everything (lobby only, but cheap).
3. Collision from the manifest (112 of 172 collide): Box on floor slabs / deck / passage plates / clip; PreciseConvexDecomposition on walls,
   piers, portals, pad kerbs, pylons, railings, props. No collide (and CanQuery false) on every Neon, glass, label, sign, hazard, roof,
   trusses, lights, lines, helipad, base/underside pieces.
4. **Hide, do not delete** (Transparency 1, CanCollide/CanQuery/CanTouch false, attrs as hub1 with prefix `Rooms3_`):
   - `Unique.U_DuelsShell__*`, `U_DuelWalls__*`, `U_DuelPads__*` (visual pad meshes only; the pad Parts stay), `U_EnergyWall__*` (all,
     incl. its deck floor: replaced by D_Deck), `U_Exfil__*` (all).
   - `U_East__concrete / dark_metal / floor_metal` (kept visible by hub1 only because they carried the Duels floor: D_Floor replaces it;
     this also removes the old top-landing lip from hub1_place issue 1; hub2's LipPlate can then go). **Check by bounds first** that no
     hub-side walkable surface (landing y 4, stairs, top landing x -90..-84) is still only on U_East: the hub kit's landing/stairs collide.
   - `Unique.U_WestWall__*` east tunnel end (already hidden by hub1).
   - FX/Lights per the table above (EnergyKey, Arcs, EnergyMotes, SparkDuels) if Edward agrees.
5. **Keep**: everything in `Duels` (pads), `Exfil` (barrier, points, L_Hangar moved, L_Pad), `Heli`, FX2.HeliN/S/End, NPCs.
6. Do the 1v1 Holo/PostCollide move (above) only if the lead accepts it.
7. Verify with rays (as check_hub1.lua): Duels door 11.0 x 8.0; west portal 9.0 x 12.0 at x -141 and at the passage frames; Duels floor
   16.0 everywhere incl. under the pads (plates on top); deck 16.0; tunnel end 22.0 x 18.0 at x 105.5; hangar floor 0 at (112, 0);
   mouth 52.4 x 17.0; pad 0; ExfilBarrier still touchable from the lane (walk spawn -> tunnel -> barrier triggers the cutscene and
   the camera sees the heli); QUICK JOIN still within 40 studs of each pad pivot; every PadBoards board visible from the hall.

## Known limits / to judge in Studio
- Preview olive and drum olive read lime in Eevee (preview uses the kit colours); Studio gets the manifest's compensated values.
- Pad footprints come from the survey's rounded bounds (1-stud precision). Kerbs start 0.48 outside the barrier lines, so a 0.5-stud
  error cannot put kit under a plate; the 2v2/3v3 and 1v1/3v3 pad rectangles already overlap at their corners in the survey, so their
  kerbs and Neon cross there (per-pad 0.004 height offsets avoid z-fighting).
- The helipad is centred at x 137 (sill + barrier occupy x 125.4-129); the surveyed heli body (x 129-136) sits on its west half.
  If the heli is moved onto the H, update the ExfilFX camera constants (hooks.md).
- The 1v1 pylons stand ~2.6 studs inside the 1v1 pads' east ends (where the old PostCollide stood relative to the old wall).
- The hangar mouth is now 17 high (roll-up door header). Old hangar opening ran to the roof (20); nothing in the cutscene needs more
  than ~14.
- The deck-side of the glass screen (between x -142 and -155, outside the passage) is open air with no floor, as the energy wall was solid
  there: the HeliN/S invisible walls start at x -155, so nothing new is reachable.
