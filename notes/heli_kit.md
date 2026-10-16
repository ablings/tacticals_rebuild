# Exfil helicopter kit (UH-60 class): built, queued for import

Built 2026-10-16 in background Blender 5.2 (Edward's open Blender scene untouched). Studio was only read (survey, dry-run check that
creates and deletes `Workspace._CheckHeliTmp` and restores CanQuery). **Nothing is placed yet: the FBX import needs the screen.**
Survey: `notes/heli_survey.md` (every hook). Reference and stud scale: `notes/heli_reference.md`.

| What | Path |
|---|---|
| Generator (headless) | `tools/heli_kit.py` -> `"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/heli_kit.py` |
| Kit | `kit/heli.blend` (collections Heli / Markers / REF), **`kit/heli.fbx`**, `kit/heli_manifest.json` (meshes, hooks, 119 check proxies) |
| Lua tables from the manifest | `python tools/heli_lua.py` (fills `--@MESH` in place_heli and `--@PROXY` in check_heli; run after every rebuild) |
| Placement (after import) | `python tools/run_luau.py fix/place_heli.lua [UNDO]` |
| Check (hooks, clips, lift sweep, camera, jump arc) | `python tools/run_luau.py fix/check_heli.lua` |
| Previews / sheet | `out/heli/bl_34front.png`, `bl_side.png`, `bl_top.png`, `bl_34rear.png`, `bl_cutscene.png`, `bl_front.png`; own reference drawings `ref_side.png`, `ref_top.png`; **`out/heli/heli_sheet.jpg`** (`python tools/heli_sheet.py`); old model `out/heli/old_34.jpg` |

## The model
UH-60 Black Hawk layout at 2.29 studs/m in length, 2.74 in height, 3.05 in width (a standing R15 must fit the cabin). Nose -Z, tail +Z,
starboard +X, exactly the old model's frame: pivot (133, -0.1, 0), mast at x 133 z 0, rotor plane y 10.2, nose z -13.62, tail z 22.75.
- Fuselage: one loft of 15 rounded-rectangle stations (pchip-smoothed, 38 rings x 31 samples), blunt nose, two-pane windscreen +
  eyebrow windows, cockpit door / lower door / gunner windows each side (near-black glass recessed 0.04 in 0.17-proud dark frames),
  door outlines as proud seams, tapering tail cone, swept pylon, stabilator below the tail-rotor disc.
- **Port cabin door open**: a real hole z -2.2..3.0, y 1.4..6.5 (world) with a dark jamb to a plain near-black cabin box (no interior
  detail); the door leaf slid aft on its rails (z 3.15..8.35), its own window. Starboard door closed (outline + window).
- Roof: transmission fairing, two engine nacelles (dark intake faces), warm-grey exhausts angled 28 deg outward-aft, mast, swashplate.
- Main rotor: 4 blades r 15.5 (chord 1.1, 1.4 deg droop, swept cream tips), hub, cuffs, bifilar absorber. Tail rotor: 4 blades r 3.6,
  on the **starboard** side, canted 20 deg (top toward the fin), hub 1.7 out on a gearbox stub.
- Fixed main wheels on stub wings just forward of the door, raked tail wheel, steps, upper + lower wire-strike cutters, pitots, blade
  antennas, cream "07" stencils (nose sides, pylon sides) and a cream band round the tail cone, red (port) / green (starboard) position
  lights on the stabilator tips and cabin shoulders, amber beacons on the pylon top and belly.
- Craft: every closed part bevelled (0.02-0.16), smooth shading + 40 deg sharp edges + WeightedNormal (face area, keep sharp) on all
  opaque meshes, overlays 0.08-0.17 proud with side walls (never flush), Z-up export with the S2B convention of the earlier kits.

## Glazing v2 (Edward: "the windows look fake", 2026-10-16)
Why v1 read fake: panes were flat near-black patches laid on the skin (decals), the same black as the trim, no seal, and the
windshield did not follow the nose. v2, in `tools/heli_kit.py` (`windows_def`, `glazing_parts`, `fuselage`, `door_leaf`):
- **Real openings in the hull.** The loft rings are sampled at 36 angles (offset half a step so the windshield centre post is one
  column); for every pane the nearest ring samples are snapped onto its edge angles and rings are inserted at its edge stations, so
  the opening is cut along true grid lines and those quads are simply not built. Asserts catch clashing snaps / overlapping panes.
- **Glass conforms and sits recessed 0.045** behind the skin (the cut quads offset along the surface normal), a **dark matte shell
  0.45 behind** (no interior, no sky), dark jamb walls, and a **raised seal** round each opening (0.06 proud, 0.10 wide, trim colour).
- **Layout (UH-60):** two-piece windshield wrapping the nose with a centre post (z -11.30..-9.40), overhead roof windows over the
  pilots, cockpit door windows, chin windows low on the nose, gunner windows just behind the cockpit, two windows in the closed
  starboard cabin door and two in the open port door leaf (cut through the 0.16 leaf the same way). Cockpit door outlines and the
  starboard cabin door outline stay as proud seams.
- **Nose re-lofted** sharper and lower (tip at z -13.62, y ~2.2; raked windshield line), still inside the old footprint (z >= -14.1).
- Glass in Studio: Glass 40,48,52, T 0.25, Reflectance 0.3 (place_heli applies Transparency/Reflectance/CastShadow from the
  manifest). Eevee close-ups in a light sky: `out/heli/ev_cockpit.png`, `ev_cockpit_match.png` (same camera as the old capture
  `out/heli/old_cockpit.jpg`), `ev_cabin_stbd.png`, `ev_door_port.png`, `ev_34front.png`; v1 workbench renders kept in `out/heli/v1/`.
- Check (proxies, 147 + discs): 0 fails, same results as v1 (static clips 0, lift clear to e 1.95, camera/jump arc clear).

## Pieces, triangles, colours (10,183 tris, 21 meshes; glazing v2)
| Mesh | Tris | Colour (base) | Studio | Collision |
|---|---|---|---|---|
| HX_Body__olive | 2,614 | 84,90,50 military olive | SmoothPlastic | **CanCollide, Hull** (the only collider), CanQuery |
| HX_Body__olive_dark | 428 | 64,70,40 (fairing, nacelles) | SmoothPlastic | off (query on) |
| HX_Body__trim_dark | 2,348 | 30,32,30 (window seals + jambs, door seams, door jamb, tyres, antennas, cutters) | SmoothPlastic | off |
| HX_Body__glass | 228 | 40,48,52 dark blue-grey | **Glass, Transparency 0.25, Reflectance 0.3**, no shadow (alt: SmoothPlastic R 0.35 T 0.25) | off |
| HX_Body__glass_back | 228 | 14,16,16 matte | SmoothPlastic, no shadow: the dark shell 0.45 behind each pane | off |
| HX_Body__metal | 1,413 | 160,154,142 warm grey (exhausts, mast, struts, hubs, rails, steps) | Metal (+ TacMetal variant if present) | off |
| HX_Body__cream | 530 | 236,232,218 (07 stencils, band) | SmoothPlastic | off, no shadow |
| HX_Body__cabin | 18 | 24,26,23 plain dark cabin volume | SmoothPlastic | off |
| HX_Body__nav_red / nav_green / nav_amber | 116 each | 255,60,40 / 60,255,110 / 255,170,40 | Neon | off |
| HX_Door__olive / __glass / __glass_back / __trim_dark | 172 / 16 / 16 / 96 | as body | | leaf Hull collide |
| HX_RotorMain__blade / __cream / __metal | 272 / 224 / 796 | 34,36,34 / cream tips / warm grey | | off; **Rotor = Main** |
| HX_RotorTail__blade / __cream / __metal | 176 / 176 / 84 | same | | off; **Rotor = Tail** |
Max per mesh 2,590 (limit 20k). The olive (84,90,50) is well below the lobby olive band (renders ~138,130,60), so it reads drab
olive, not lime; measure the render after placing and lift towards 92,98,56 if it reads near-black under the pad light.

## Import steps for the lead (needs the screen and Edward's OK; coordinate with the UI session)
1. Studio 8ef4e21a (Tacticals_rebuild.rbxl), **Import 3D**: file `C:/Users/aroki/Documents/tacticals_rebuild/kit/heli.fbx`;
   **Creator = the Gunsy Funsy group**; tick **Insert Using Scene Position** and **Anchored**; leave normals as authored; Import.
   It arrives near the world origin above the hub (the FBX is authored around the heli pivot; the cube K_Scale7 sits at (0, 60, 0)).
   Close the Import Queue panel afterwards.
2. Confirm by script: 21 `HX_*` MeshParts + `K_Scale7` + `K_Marker7` under one import Model. `K_Scale7.Size` / 10 = the import scale
   (earlier Tacticals kits came in at 1, 11.4, 20, 31; never assume). `fix/place_heli.lua` measures it and detects a 180-degree turn
   from K_Marker7; it also prints the largest deviation of any mesh from its manifest position (should be < 0.05).
3. `python tools/run_luau.py fix/place_heli.lua` (run it twice if the first report looks odd: it undoes and re-applies).
4. `python tools/run_luau.py fix/check_heli.lua` -> expect `mode kit`, RESULT fails 0 (KIT placed meshes block).
5. Captures from the hangar (e.g. `screen_capture` camera (112, 12, -26) -> (133, 4, 3), like `out/heli/old_34.jpg`) and the ExfilFX
   start camera (120, 9, -18) -> (133, 4, 2); sample the olive.
6. Play test (`python tools/play_lock.py take map` first; release after): walk into the barrier: jump arc into the port door, the
   lift, fade, arrival in Training; LEAVE back to the hangar.
7. Save (File > Save to File) when the UI session agrees.

## What place_heli does (order, idempotent, UNDO)
1. Undo any previous run (kit back to `ServerStorage.heli_import` with import CFrame/size, old meshes back, attributes restored).
2. Find the import by `K_Scale7` (Workspace or ServerStorage), scale + turn from the markers.
3. Move the 13 old `U_Heli*` meshes to `ServerStorage._RebuildRemoved.Heli_Old` (not deleted; they would otherwise still be lifted by
   ExfilFX). Heli Model, its name, WorldPivot and `Mast` unchanged.
4. Place the 21 meshes in `LobbyMap.Heli.HX` at pivot + manifest centre with manifest size and style; anchored; CanTouch false;
   `NotCover` + `HeliKit` attributes; `Rotor` on the rotor meshes.
5. `TailHub` -> (134.7, 9.4, 20.6), `TailAxis` -> (-0.940, -0.342, 0) (originals in `HeliKit_OrigTailHub/Axis`).
6. Markers to `ServerStorage._RebuildRemoved`; the empty import Model is removed.
UNDO: `python tools/run_luau.py fix/place_heli.lua UNDO`.

## Check results (dry run, 2026-10-16, before import)
- Hooks (old model): Mast / TailHub / TailAxis present, 4 Main + 2 Tail rotor parts, no SpinAxis children, no HeliTrigger, no CanTouch,
  HatchPoint / CabinPoint / ExfilBarrier unchanged.
- **New kit (119 z-sliced AABB proxies + the two rotor discs)**: static clips 0 (pad, hangar roof, E_Gear crates, Polish props);
  lowest point 0.08 (the starboard main tyre sits on the pad's cream Neon outline, contact only); camera never inside the heli and no
  map part between camera and cabin for e = 0..2.6; the jump arc from the barrier to HatchPoint clear of the heli; lift sweep clear for
  e < 1.95.
- First proxy run found two real problems, fixed in the kit: the stabilator's port tip reached the crate stack at the north wall
  (x 127.7-130.5, z >= 21.6): stabilator moved forward to z 19.7..21.45; the rotor disc grazed the EXFIL sign board (x 124, y 15.35)
  at e 1.3-1.4 because the lift rolls the disc up on the hangar side: rotor radius 16 -> 15.5.
- **Warn only (not caused by the new model):** from e ~2.0 the ExfilFX path (x + 3.2e^2, y + 2.2e^1.5) carries the heli through the
  east-edge gantry (`Rooms3.E_Gear` lamp / beams at x ~140-150, y ~14). The old model's tail rotor does the same at e 2.2. Fix, if
  wanted, is in ExfilFX (steeper climb or fade at e 2.0), not in the model.
- Old model dry run: static clips 0, its skids touch the pad markings.

## Notes for Edward / later
- Old Huey-like model kept in `ServerStorage._RebuildRemoved.Heli_Old` after placing.
- The heli only has one collider (body Hull, the door leaf Hull); the cabin is filled for physics, which is fine: ExfilFX anchors and
  CFrames the player.
- If the open-door look should change (door closed until the cutscene), the leaf is its own mesh pair (`HX_Door__*`).
