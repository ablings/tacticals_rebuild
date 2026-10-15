# Hub polish pass 2 (hub2), Studio only, after the switch to Future

Done 2026-10-15 in `Tacticals_rebuild.rbxl` (studio id e1d5a8da-..., confirmed by list_roblox_studios) only. **Not saved** (lead saves).
No computer use, no Blender, nothing touched in the live "tacticals (placeId ...)" studio, the RIVALS place or the replica. No RIVALS ids.

## Files
| What | Path |
|---|---|
| Fix script (idempotent, UNDO flag; runs after place_hub1.lua) | `fix/hub2.lua` -> `python tools/run_luau.py fix/hub2.lua [UNDO]` |
| Capture set (same 10 cameras as hub1) | `python tools/hub2_capture.py <prefix> [names]` -> `out/hub2/<prefix>_*.png` |
| Captures | `out/hub2/after_*.png`; lip close-up `out/hub2/after_t2_lip.jpg`; `pre_*` = Future before this pass |
| Compare sheet (hub1 after left, hub2 right, 10 cams) | `out/hub2/compare.jpg` |
| Diagnostics | `d0_*` (EnvironmentDiffuseScale 0), `s0_*` (EnvironmentSpecularScale 0), `e1..e3_*` colour trials |

UNDO tested (UNDO -> re-apply round trip: 266 instances un-hidden and re-hidden, tags back, colours/roughness/sign plates back,
Hub2Add removed and rebuilt). `fix/check_hub1.lua` re-run at the end: every hook OK (folders, 1 LobbySpawn, AssetCheck names, QueuePad 6,
ExfilBarrier, RoomLight 29, prompts, NPCs, openings 10.8 x 12.15 / 22 x 18 / 11 x 8, crane and drone sweeps no hits).

## What changed
1. **Floor navy -> neutral dark grey.** Cause measured: under Future the floor picks up blue sky *specular* (floor 62,62,60 rendered
   32,53,72; with EnvironmentSpecularScale 0 it was 23,30,36). Fix, kept local to the floor (global Lighting untouched):
   - `TacFloorConcrete.RoughnessMap` -> our concrete_smooth roughness (rougher; original id kept in attribute `Hub2_OrigR`).
   - Warm-compensated colours: floor_field 76,62,50, floor_border 46,38,30, floor_insert 94,80,66, grate 30,26,22, spawn disc
     floor_border 46,38,30 and disc_plate 88,76,64. Rendered floor now ~38-46 neutral (c1 39,44,50 far / 40,44,45 near), RIVALS' 36-62.
   Originals per part in `Hub2_OrigColor` (manifest values).
2. **Drums**: drum_olive 107,122,58 -> **70,82,52** (military-green family beside the 65,94,56 crates). No more lime.
3. **Sign text**: the SignText carriers were invisible plates within 0.1 of the board (EXFIL's sat 0.08 *behind* the board face), so
   text dropped out by depth fighting. Now each carrier is a **solid backing plate** (SmoothPlastic 39,40,37, 0.1 thick) whose back
   sits 0.08 proud of the board face measured by ray; SurfaceGui Front, LightInfluence 0, MaxDistance 0. SHOP / ARMORY / EXFIL /
   DUELS show in every recapture.
4. **Stray old FX / lights hidden** (Hub2Hidden + Hub2_* attributes, separate from Hub1's set). The floating "letters" were the old
   pod-cradle stickers (FX.Decals at z +-36.8, y 16-21) and the wall stickers at z +-43:
   FX.Decals 48 parts (96 inst.), FX.Steam 8 (in the wall), FX3.SkyWindow 8 + FlightHUD 6 (inside / over the band), FX3.Beacon 14
   (inside the cornice; the 4 Duels-hall beacons kept), FX4.RunLight 24 (old cradles, floating), FX2.Thruster 24 + StairsLight (inside
   walls / plinth), old `Lights` folder: PointLight x9, SpotLight x6, Rim x4 (inside the new wall / cornice band). Kept: Lights.SpawnTop
   (the shadowed key on the disc), Lights.WalkFill x2 (bridge decks), FX3.Ticker, FX.Hologram, FX2 Chevrons/SpawnRipple, HullMarks
   (outside the shell). **LobbyBeacon / LobbyRun tags removed** from the hidden parts (stored in `Hub2_Tags`, UNDO re-adds) because
   LobbyFX rewrites their Transparency every frame and would make them reappear in play.
5. **New lamp lights** in `Hub1.Hub2Add.Lights` (invisible carriers, NotCover, **not** tagged RoomLight: RoomFX has no hub centre and
   would switch them off):
   - 12 ceiling-strip SurfaceLights (H_CeilLights rows z +-24, y 63.55, every other bay x +-13.75/41.25/68.75), Bottom, warm white
     255,241,208, Brightness 1.0, Range 60, Angle 120; **4 shadowed** (the strips at x +-13.75 over the disc).
   - 12 wall-capsule SurfaceLights (piers x +-20.6/48.1/75.6 both walls, y 14.2, lens z +-41.45), 255,228,190, Brightness 0.8,
     Range 24, Angle 120, no shadows.
   Hub light count: 22 old enabled -> 3 old + 24 new; shadowed lights in the hub: 5 (4 strips + SpawnTop).
6. **Top-landing lip**: `Hub2Add.LipPlate` metal kerb plate (Metal + TacFloorPlate, 108,107,104) x -85.9..-84.3, z -8.7..8.7, top 16.62,
   over the old U_East__dark_metal lip (x -85.1..-84.5, top 16.53), with 0.8-deep WedgePart ramps on the walkway side and both ends
   (verified 16.54 -> 16.08). Collides, NotCover. Route stairs -> Duels door clear (check_hub1 west route OK).

## Left / for the next pass
- **Floor colours are a compensation for the sky specular.** If the lead changes the Sky (two Sky objects still: `Sky` with
  CelestialBodiesShown true and `Lobby_Sky`), EnvironmentSpecularScale or the floor variant maps, re-measure and retune (rendered target
  36-62 neutral). A cleaner long-term fix is a rougher own floor roughness map (0.8+) uploaded under Gunsy Funsy.
- Other up-facing metal (riser/landing/stair treads TacFloorPlate 108, catwalk decks) still has a slight cool cast; not retuned.
- The **dark-olive Neon floor ring / sign outlines (88,101,48) and the olive head bands on the gates (120,136,66)** still read lime-ish
  under Future (see c1, g1). Out of this brief; next step 112,126,62 for the band, ~70,80,40 for the Neon.
- The twin-pipe runs in the vent bays (H_BaysN/S, y 24-26) end in a bracket that reads like an "E" from the floor. That is kit
  geometry (one mesh per material), so it needs a Blender change (run the pipes into the piers or add end flanges).
- FlightHUD screens and sky windows were decent dressing; re-home them onto the new bay panels if Edward wants more screens.
- Edit-time captures; judge final light levels in Play (RoomFX lights switch on near the camera there).
