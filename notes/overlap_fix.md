# Overlap sweep (overlap_fix), Studio only

Done 2026-10-15 in `Tacticals_rebuild.rbxl` (studio id 8ef4e21a-3525-484b-91af-79d7677aa213) only. **Not saved** (the lead saves).
Nothing touched in Training, the live "tacticals (placeId ...)" studio, RIVALS or the replica. No computer use, no Blender.

## Files
| What | Path |
|---|---|
| Fix script (idempotent, UNDO flag) | `fix/overlap_fix.lua` -> `python tools/run_luau.py fix/overlap_fix.lua [UNDO]` |
| Analysis (offline, no Blender) | `tools/overlap/`: `kitdump.py` re-runs `tools/*_kit.py` with stub bpy/bmesh/mathutils and records every primitive in Studio coordinates; `zf.py` finds coplanar same-facing faces (<= 0.03 apart) that are not buried in other geometry; `vol.py` room air volumes (only faces seen from a room count); `foreign.py` kit geometry visible in a room it doesn't belong to; `gen.py` builds the fix table; `verify.py` applies it to the primitives for a re-check; `probe.py` ray probes through screen pixels (`DM=Server` works while someone is in Play); `oldov.lua` visible old parts intersecting the kit |
| Checks | `out/overlap/check_{hub1,rooms2,rooms3}_{before,after}.txt` |
| Sheet | `out/overlap/before_after.jpg` (see the capture note below) |

Generated primitives were checked against Studio: all 600+ kit MeshParts match their generator bounds (only the known SR_Stage +0.2 lift
and lathe approximations differ), so the offline geometry is the placed geometry.

## Found and fixed
Visible coincident faces (same plane, same facing, different look) went from **3,534 to 713 sq studs**. All wall cases are fixed. What is
left is floor inlays 0.01-0.02 apart (see the kit list below).

| Where | What | Fix |
|---|---|---|
| **Duels hall, east wall** (worst case, ~850 sq studs) | The hub W wall's back face (x -95: wall_body, wall_dark, wall_upper) sat exactly on the Duels east cladding (D_Walls__wall_body at x -95). That gave flickering panels all over the wall. | All `H_WallW__*` meshes were scaled in x about the hub face x -90, so the back face is now at -94.96 (the hub face doesn't move). |
| Duels door, hall side | The `H_DuelsDoor__*` portal back was also at x -95, the same plane as the wall and the cladding. | Scaled about x -90 to -94.93. |
| Duels doorway jambs (z +-5.5) | `H_DuelsDoor__trim_metal`, `H_WallW__band_olive` and `H_WallW__wall_body` were all on the same plane. | Trim scaled in z to 5.43, band to 5.47 (now stacked). |
| Duels door frame (D_Door) | Band and trim were flush with the frame wall on both cheek faces. | Both scaled toward the centre line (inner faces 5.46 / 5.43), and the lintel trim lowered 0.04. |
| Duels west gate + passage (D_West, D_Pass) | Band and trim were flush with the wall on the jambs and on the Pass-side face. Passage plate vs D_Base top (y 16). | Inner faces moved 0.04 / 0.07 into the opening. D_West band x -0.03, trim x -0.06. D_Pass band y -0.04. D_Base__wall_dark y -0.04. |
| Duels floor | D_Lines Neon was 0.008 above the floor trim. | D_Lines y +0.03. |
| **Tunnel mouth** (hub E wall) | Hub wall jambs (`H_WallE` body, kick, band, trim at z +-11) were on the same plane as `H_TunnelPortal__wall_light`. Portal band, portal trim and the tunnel band were also on that plane. | Portal wall inner faces to 10.96; portal band and trim, and `H_Tunnel__band_olive`, to 10.93; `H_Tunnel__door_leaf` 11.2 -> 11.16. |
| Tunnel end (E_Portal) | Band and trim were flush with the wall on the jambs; band vs trim at x 105; lintel. | Band to 10.96, trim to 10.93 and x -0.04, lintel trim y -0.04. |
| Hangar mouth | The E_Mouth wall top was on the same plane as the E_Ceiling top (seen from the pad); door leaf vs band at y 17. | E_Mouth__wall_light y +0.04, E_Mouth__band_olive y -0.04. |
| **Hub N/S gates** | The olive band was flush with the cheek on both side faces; lintel trim underside flush with the gate soffit (y 12.2). | Band scaled in x so its inner face is 0.04 into the opening; trim y -0.04. |
| Shop / Armory door frames | Band flush with the frame ends (x +-9.8); lintel trim flush (y 12.2). | Band grown to +-9.84; trim y -0.04. |
| Hub vent bays | Door leaf on the same plane as the wall kick trim (z +-43.25); label plates flush with the wall plates. | Door leaf 0.04 toward the hub, labels 0.03. |
| Hub catwalks | Edge trim flush with the wall-plate tops (y 29.4); beam top flush with the deck plate (y 31). | Trim y +0.03, beam y -0.04. |
| Hub skylight / stairs | Skylight Neon flush with the roof gloss and the beams (y 68); stair nosing trim 0.02 under the plate tops. | Neon y +0.03; stair trim y +0.03. |
| Shop displays | Trim flush with the plinth top (y 1.2). | Trim y +0.03. |
| Showroom backdrop | Header band flush with the wall ends (x +-13.4). | Grown to +-13.44. |
| Hangar / pad | E_Lines Neon on the dark-metal sill (0.02). | E_Lines y +0.02. |
| **Old geometry** | `Props.Rotor` (2 old wall fans, 8 meshes) were buried in the new hub E wall face at x 88. These were the only visible old parts that cut into the kit (`oldov.lua`: every other visible old part is clear, apart from the heli skids on the pad, which is intended, and the ExfilBarrier foot under the floor). | Hidden (attributes `OverlapHidden` + `Overlap_T/_C/_Q/_Tc`). LobbyFX only re-pivots them, so the hide holds in play. |
| Old FX3 beacons in the Duels hall (x4) | The coloured dots were floating 1.8 studs off the new wall where the D_Piers stand. | Hidden and untagged `LobbyBeacon` (LobbyFX rewrites the Transparency of tagged beacons). The tag is kept in `Overlap_Tags`. |

Not issues: H_WallW's flush trim faces seen on the upper Duels east wall (above the cladding, design). D_Props/E_Lights reaching just
past their room volumes. Crane/drone sweeps: no hits.

## Hooks / checks (out/overlap/check_*_after.txt vs _before)
- check_rooms2 and check_rooms3: **0 FAILS** both. check_hub1: all hooks present, and the crane / drone sweeps have no hits.
- Expected small changes, because decor now stands 0.04-0.07 proud into the openings on each side:
  - widths: gates at y 11.5: 9.40 -> 9.32; tunnel 22.00 -> 21.86; Duels door 11.00 -> 10.86; D_Door 11.00 -> 10.86; west portal
    9.00 -> 8.86; tunnel end 22.00 -> 21.86;
  - clear heights: 12.15 -> 12.11 (gates and corridors); 12.16 -> 12.12 (doors); 7.97 -> 7.93 (Duels door); 16.96 -> 16.92 (hangar mouth).
  - Duels axis max step 0.06 -> 0.08 (the D_Lines lift).
- No room footprint, door position or hook part was moved. UNDO round trip tested: 46 parts restored and 12 un-hidden, then a re-apply.
  A second apply changes nothing.

## Still needs a kit (Blender) change
1. **Floor inlays 0.01-0.02 above their neighbours**, all floor-level, and they can shimmer at grazing angles:
   - H_Floor field 0.00 vs border 0.02 (221 sq studs, the largest remaining);
   - E/D/S/A/D_Deck floor border vs insert 0.01;
   - corridor and passage walkway plates vs border 0.02;
   - H_Floor grate vs trim 0.02;
   - door plates vs room border 0.02;
   - S_Counter plate vs floor trim.

   Not moved in Studio because they are walkable collision. A raise there also created new coincidences (insert +0.02 met the trim at
   0.05). Fix in the generators: make every inlay step >= 0.04, or recess it 0.04.
2. **Bands and trims authored flush with their wall** (the `band_olive`/`trim_*` boxes share faces with `wall_light`). In Studio each merged
   mesh can only be scaled as a whole, so one side of a frame was fixed by moving the decor proud. The other side is now recessed 0.03-0.05,
   so the band stops short there:
   - outer gate cheek sides;
   - the outer D_Door / D_Pass cheek faces;
   - tunnel portal outer faces.

   In the generators, inflate decor boxes 0.03 past the wall on every face.
3. Hub W wall and Duels kit both own the x -95 plane. In the kit, give D_Walls the whole east face (or start the hub wall at -94.95).
4. Small leftovers: SR_Backdrop band inner bay face (x +-11, ~8 sq studs); SR_Shell trim bottoms at the floor; prop label plates 0.02 off
   crate faces (S_/A_/H_Props, Shelves; small).

## Capture note
- **2026-10-15 lap1:** the viewport renders again; the 12 `after_o*` frames were retaken and `out/overlap/before_after.jpg` rebuilt with real
  after frames (o1/o2 before vs after, then the other 10 after). Follow-ups from the Play lap (3 more nudges here, rest in `fix/lap_fix.lua`): notes/lap1.md.
The **Studio viewport rendered pure white** for every screen_capture after the Training agent's playtest ended. Lighting, CC, Atmosphere
and the GUIs checked normal, so it is the editor viewport itself, and that needs a click in Studio (no computer use here).
- `before_o1_duels_eastwall` and `before_o2_duels_door` were taken before that and show the Duels-wall problem.
- The "after" side of the sheet is the ray-probe evidence: the same pixels re-probed show the surfaces now separated.
- Retake both sides once the viewport renders: `python tools/overlap_capture.py after` (12 eye-height cameras: Duels wall/door/west gate,
  passage, tunnel mouth from both sides, N gate cheek, corridor, vent bays, Exfil portal, old rotor, beacons). Then rebuild the sheet.
