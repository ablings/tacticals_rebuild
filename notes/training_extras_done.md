# Training step 2: tile look + extras (done 2026-10-15)

`Tacticals_rebuild.rbxl` only (studio e1d5a8da-...). **Not saved** (the lead saves). No computer use; Studio MCP only.
Nothing touched outside `LobbyMap.Training` (+ the scripts listed below). Own assets only (TX_overlay_grid, TX_grime_overlay).

## How to run / revert
| What | Command |
|---|---|
| Geometry (tiles, fill, extras geometry) | `python tools/training_layout.py` (plan + data) then `python tools/run_luau.py fix/place_training.lua` |
| Scripts | edit `scripts/training_extras/*.lua` → `python tools/build_training_extras.py` → `python tools/run_luau.py fix/install_training_extras.lua` |
| Revert all scripts | `python tools/run_luau.py fix/install_training_extras.lua UNDO` (restores the 3 edited scripts from `ServerStorage._TX_Originals`, deletes the 9 new modules and the 2 remotes) |
| Revert geometry | `python tools/run_luau.py fix/place_training.lua UNDO` (now also removes `Training.Extras` and `ServerStorage._TrainingExtrasOff`) |
| Switch one feature off | `TrainingConfig` value, or in Play `ReplicatedStorage:SetAttribute("TX_<Name>", false)`: AliveDummies, GalleryFill, RoomFXBox, Bullseyes, DpsDummies, JumpPads, Tightropes, SwapBins. Off = old behaviour; `TrainingExtrasManager` moves that feature's `Training.Extras.<Feature>` folder to `ServerStorage._TrainingExtrasOff` |

## Part 1: tile look (fix/place_training.lua)
- All grid-tile pieces now **SmoothPlastic, no variant, neutral greys** (was Concrete + TacConcrete, sage/teal). Values via
  `neutral(v)` (floor 214, blocks 224, low walls 232, tall 218, mid 216, perimeter 206, bastion 196, tower 204, ceiling 190;
  gallery bands 214 / 194 / 176 instead of sage / warm grey).
- **Calibration lesson:** edit-time captures (Training lights off) read every grey teal (lobby Atmosphere + sky diffuse);
  in Play (PointLights on) the same values read warm/peach. A first pass compensated for the edit look and came out pink
  in Play (`out/training/play_1_arrival_tiles_v1.png`, rendered R/G 1.18). Final values are calibrated on Play
  (rendered/input ≈ R 1.03, B 0.98) so the input leans a hair cool. **Judge tile colours in Play only.**
- Grid: TX_overlay_grid, **5x5, dark grey (58), 0.45 transparency, two copies 0.06 apart** (the art's 2-px line is too
  thin at 0.75; doubled it reads like the old Training grout). Ceiling tiles 10x10.
- **World-aligned grid:** OffsetStudsU/V per face so lines sit on world multiples of 5 and run on from box to box
  (texture origin per face measured with a UV test cube; see `gridOffsets` comment). `out/training/edit_tiles_world_grid.png`.
- **Density fill** (tools/training_layout.py `FILL`, plan-checked for overlaps/spot clearance): +8 mid blocks (8-12 tall,
  new kind `mid`), +12 low walls, +6 pillars, +2 tall walls, +6 crates in the bare NE / SE / SW / boulevard areas.
  Range2 now 245 Parts, 1,452 Textures. Pieces: low 37, crate 24, bridge 14, block 12, tall 12, pillar 9, mid 8, ...
- **Not re-verified after the final colour pass:** at the end of the session Studio's viewport rendered pure white for
  every capture, Edit and Play alike (not this change: the edit capture of an unchanged view was white too). Re-capture
  `out/training/play_*` once Studio renders again and nudge `neutral()` if needed. `fix/check_training.lua` not re-run
  after the fill (plan checks passed; Play walk tests below).

## Part 2: extras
New modules (attribute `TX_New`): `ReplicatedStorage.Modules.Shared.Config.TrainingConfig`; Managers: `TrainingExtrasManager`,
`ShootableManager` (shim: CombatManager.afterShot already calls `shared.Get("ShootableManager").OnShot`; the lobby place had
none), `TrainingTargetsManager`, `TrainingDpsManager`, `TrainingBinsManager`; Controllers: `TrainingPadsController`,
`TrainingTargetsController`, `TrainingBinsController`. Remotes created at runtime: `Events.Training.TargetPop`, `SwapWeapon`.
Geometry: `LobbyMap.Training.Extras.{JumpPads (8), Tightropes (4), SwapBins (9), DpsDummies (8 spots), Bullseyes (120)}`.

### Edited existing scripts (all lines marked `[TX]`; originals in `ServerStorage._TX_Originals`)
| Script | Lines (after edit) | Change | Revert |
|---|---|---|---|
| `...Managers.TrainingManager` | 10-13 | `ENEMIES = TX.AliveDummies` (35) if on | UNDO, or `TX_AliveDummies=false` |
| | 32-36 | `freeSpot`: BaseParts from GetDescendants; free `Gallery = true` spots first | UNDO / `TX_GalleryFill=false` (descendant scan stays) |
| | 95-96 | gallery dummy respawns after 1 s (arena 2 s) | as above |
| `StarterPlayerScripts.RoomFX` | 6-10, 29-30 | Training lights: inside box x -140..364, y 588..660, z -140..140 instead of r 175 sphere | UNDO / `TX_RoomFXBox=false` |
| `Client.Controllers.WeaponController` | 260-262 | no-shooting-mid-hop rule skipped while `TrainingPadsController.IsPadFlight()` | UNDO / `TX_JumpPads=false` |
CombatManager, WeaponUtil, CoverController, HUD, TrainingGate: unchanged.

### Design notes
- **No collaterals:** bullseyes are invisible Ball parts with **CanQuery on** (face = camera-facing BillboardGui, Scale-only).
  The shooter's own ray stops on the first thing; a bullseye hit sends no character → no dummy damage; CombatManager's
  `IsPathClear` refuses a dummy hit through a live bullseye; server pop test requires the client ray's entry into the ball
  to be at/before the claimed end point and a server ray to reach the ball first. Popped = CanQuery off for 3 s.
- DPS dummies: dark olive, 1e6 HP, Dead state disabled, own `OnHit`; readout = damage in the rolling ≤3 s window ending at
  the last hit / span; greys after 2.5 s idle, resets after 2 s more.
- Pads (client, gated): ballistic arc to `LandAt`, apex ≤ ceiling 648 − 4 (root); the controller follows the planned arc
  each frame (air control and the first grounded frame otherwise ate ~15 % of the rise and the first test fell short).
- Bins: F prompt → picker (Scale-only UI, 1-7 / click, Esc / F / walk away closes). Owned gun = normal swap; unowned =
  TRIAL (`TrialWeapon` attribute, "TRIAL · X" tag), ends on leaving Training (Loadout restored) or picking another bin.
  Server checks InTraining, 4/s, within 12 of a bin, id in Loadout. **No PlayerStore writes** (only `PlayerStore.Owns` is
  read; `Loadout` is a session attribute, never saved).
- Studio-only trace: `workspace` attribute `TX_LastTargetShot` (ShootableManager/TrainingTargetsManager, only when
  `RunService:IsStudio()`). Harmless; delete the `why(...)` lines if unwanted.

## Play tests (Studio Play, 1 client; Enter via `Events.Training.Enter` as the game does)
| Test | Result |
|---|---|
| Dummies | **35** TrainingEnemy alive, **16/16 gallery spots filled**, 8 DPS dummies |
| Lights | 19/19 Training lights on at the arrival, at the gallery end (x 336) and the SW corner (3 gallery lights on); after Leave **0**; camera at Showroom CameraPoint **0** (Kit-menu camera emulated, not opened through the UI) |
| Bullseye in front of dummy | client ray hit the Bullseye → trace "popped", **dummy HP 150 unchanged**; next shot (bullseye down) hit the dummy (150→120) |
| Dummy in front of bullseye | dummy 150→120, trace "no target on the shot", bullseye not popped |
| Respawn | bullseye up again (face on, CanQuery on) after 3 s |
| DPS | Pistol 30 every 0.25 s → readout 60 → 120 → 119 DPS, "LAST 30 · TOTAL 240", HP stays 1e6 (hold logic was then fixed so it freezes greyed instead of decaying; re-check) |
| Jump pad | pad at (30,52) → tower top: apex root y 644 (ceiling 648), landed on the tower top (root 639) |
| Shot mid-air | a real mouse click during a pad flight (client gravity lowered to stretch the flight): shot accepted (AckShot/Ammo moved) while **Freefall at y 636.5**; state Running after landing |
| Tightrope | stood on rope b4→o2 at y 624 (FloorMaterial Fabric), walked 67 studs along it in 5.3 s without falling (`play_2_tightrope.png`) |
| Bin | F at the plaza bin opened the picker (`play_3_bin_picker.png`: Pistol IN HAND, others TRIAL); 7 → **Sniper in hand, Loadout Sniper, TrialWeapon Sniper** (`play_4_bin_trial.png`); Leave → tools [], Loadout nil, TrialWeapon nil |
| Console | no errors from the new code; pre-existing: MatchmakingManager MemoryStore error, `Get("BotManager") returned nil` per shot (ShootableManager warning is gone) |

## Known issues / to do
- Final tile colours + bullseye/DPS-hold fixes not seen in a frame (white viewport, above). Re-capture and eyeball.
- Shots emulated through the FireWeapon remote (same raycast as `computeShot`) for the collateral tests; this desyncs the
  client's shotId for a few clicks in that session only.
- Normal "no shooting mid-hop" after landing verified by code/state only, not by a timed click.
- Kit menu not opened through the UI (camera at CameraPoint emulated).
- Truss climbing / 31° ramps still untested in Play (from step 1). `fix/check_training.lua` should be re-run after the fill.
- Bullseyes are CanQuery: a camera spherecast can bump on one (they sit ≥10 above any walkable surface, so rare).
