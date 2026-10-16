# Feature props kit: placed in Studio (2026-10-15)

`Tacticals_rebuild.rbxl` only (studio 8ef4e21a-...). **Not saved** (the lead saves). No computer use. Own assets only (kit/features.fbx
meshes, TacHub1 variants, own hazard/grate texture ids; reward model = the game's own `Repository.Weapons.Sniper`).
Kit: `notes/features_kit.md`, `kit/features_manifest.json`. Before/after: **`out/features_kit/before_after.jpg`** (23 views at eye height,
`before_*.png` / `after_*.png` in the same folder).

## How to run / revert
| What | Command |
|---|---|
| Place (idempotent: every run first undoes the last) | `python tools/build_features_kit.py` (manifest + `scripts/features_kit/place_body.lua` -> `fix/place_features_kit.lua`) then `python tools/run_luau.py fix/place_features_kit.lua` |
| Revert everything | `python tools/run_luau.py fix/place_features_kit.lua UNDO` (tested: restores 130 moved instances, removes 95 new, unhides 192, returns the meshes to `ServerStorage.features` with their import look) |
| Order | **after** `fix/install_features.lua` and `fix/place_training.lua`. Re-running either of those rebuilds what this placed on (LobbyMap.Features / Training extras): re-run this afterwards (stale stash entries are dropped automatically). |
| Captures / sheet | `python tools/features_kit_capture.py <prefix> [names]`, `python tools/features_kit_sheet.py` |

Bookkeeping: new instances carry `FK_New`; moved/removed originals are recorded in `ServerStorage._FeaturesKitRemoved.Records`
(ObjectValue + From; attachments keep their local CFrame); hidden-in-place parts carry `FK_Hidden` (+ `FK_T/C/Q/Tc`); moved/resized
parts `FK_OrigCF/FK_OrigSize`; the two Duels floor meshes `FK_FloorHidden/FK_OrigT/FK_OrigQ`.

## What was done
1. **Templates**: `ServerStorage.FeaturesKit` = 28 piece Models (meshes styled from the manifest: colour/material/variant/collision/
   NotCover/fidelity; hazard + grate overlays). PrimaryPart = the collision body (or the largest mesh), PivotOffset = the piece pivot.
   `K_Scale5` / `K_Marker5` -> `ServerStorage._RebuildRemoved`. `ServerStorage.features` is left empty (UNDO refills it).
2. **Screens** (the kit `__screen` mesh *is* the screen now: same name, `LobbyScreen` tag + `Screen` attribute; temp plate + TempBezel/
   TempLip removed UNDO-ably). Flush-mounted with a wall-protrusion scan (7 x 5 rays over the footprint), all clearance-clear:
   | Screen | Kit | Where |
   |---|---|---|
   | Leaderboard (`LobbyMap.Signs.Screen_Leaderboard`, name/path kept, `LF_New` so install_features can replace it) | F_Screen16x9 scaled (0.54, 0.593, 0.7): face 8.70 x 5.41 (= the 940:580 canvas) | north wall x -55.5 |
   | Likes | same frame | north wall x 55 |
   | DuelsTV, Ad | F_TVArmWall x1.3 (face 8.66 x 4.76, arm 7.5 out at y 12.7-18.5) | south wall x -55.5 / 55 |
   | Training | F_TVArmWall x1.3 | hub east wall by the Exfil tunnel, z -22.3 -> -21 (bay centre between pilasters) |
   | DuelsSign | F_Screen12x4 (0.75, 0.6, 0.7), centre y 5.6 -> 5.95 | stair-core wall x -84: frame 4.1..8.6 clears the landing (top 4.0); header sits on the olive band |
   Frame width: the hub bays are 11 wide between pilasters; 0.57 scale clipped a pilaster (scan showed a 1.45 standoff), 0.54 fits.
3. **Reward stand (14)**: F_RewardStand x1.25 at (-15, 0, -24), name plate facing the spawn (ahead-left of the spawn view, clear of the
   Armory lane and the vents; reads in `after_r1_stand_spawn`). `LobbyMap.Features.RewardStand`: SurfaceGui on the plate (Title / TopName /
   TopWins) + BillboardGui over the halo (Header / BoardName / BoardWins), Scale-only. Reward model = `Repository.Weapons.Sniper` parts
   (scripts stripped, scaled to 4.25 long, welded to an anchored `SpinRoot` tagged **LobbySpin**, `spin` 40, `bob` true; LobbyFX spins a
   BasePart's CFrame, so the tag is on the root part, not the Model). Code: **[FEAT]** `LobbyFeaturesConfig.RewardStand` (flag, texts,
   in `C.Features`) + `LobbyFeaturesManager.startRewardStand` (reads `ReplicatedStorage.LobbyTopWins`, #1 name + wins, on change).
   Off -> the folder goes to `_LobbyFeaturesOff` like every feature.
4. **Drop pits (3)**: holes widened 6 x 10 -> **8 x 10** (x -118..-110, z +-12..22) so the kit rim (scaled 0.8 in X) fits and 5+ stud
   walkways stay either side (3v3 route at x -108 clears the rim by 0.2). The one-piece `D_Floor__floor_field/__floor_border` meshes are
   hidden (Transparency 1, CanQuery off) and replaced by 9 non-colliding **slabs** in the same material/variant/colour (`DropPits.FloorSlabs`;
   field top 16.0, border frame top 16.03) with the holes cut **0.1 wider** than the walkable hole so the slab edges hide behind the kit
   lip/liner (no coplanar faces). Collision stays on the 5 `FloorProxy` slabs, resized to the new holes; `Catch` resized to 8 x 16 x 10;
   KEEP CLEAR stencils moved 0.75 back off the rim. The kit rim/liner have **no collision** (the manifest's Box fidelity on a frame would
   have closed the hole). Old Void/Rim/Lip/Shaft parts removed. [FEAT] in the manager: DropPits off also shows the floor meshes again.
5. **Fixtures**: 7 spotlights -> F_TrussSpot clamped at the old rod top, tilted toward the target (max 60 deg); the original SpotLight is
   re-parented to an `Aim` attachment on the kit lens, pointed exactly at the old target. 4 beacons -> F_BeaconMast x0.5 (7.2 tall) on the old
   base points; PointLight, `LF_Beacon` tag, `Phase` and colour moved to the kit lens (the FX pulse runs on it). 3 hologram cones ->
   F_HoloEmitter (shop counter x0.45, gun wall x0.8 replacing the olive Ring, dais x0.6), kit cone shell deleted, the Beam + its attachments
   re-parented to the kit lens (A0 at the emitter top). Emitters CanQuery off (never block the prompts' line of sight).
6. **Industrial props** (`LobbyMap.IndustrialProps`, all clearance-clear, flush to ribs/bands): hangar 1 x F_Container20 (olive drab,
   north pocket by the tunnel mouth at (117, 0, 13.5), doors toward the tunnel; found by a GetPartsInPart grid search: the rest of the
   hangar edge is E_Gear / E_PadWalls / the heli, the south side is the diagonal hangar->pad route); tunnel: 2 pipe runs (y 8.8-11.7),
   2 power boxes, junction box, intercom; Shop corridor: pipe run under the rib caps, intercom, junction box; Armory corridor: pipe run,
   intercom. v1 had a warm-grey 20 + stacked 10 (read white, walled off the hangar) and a power box in the Armory corridor (check_rooms2
   flagged the corridor under 9.5 wide): both taken out.
7. **Training**: 9 bins -> F_SwapBin meshes inside the same Model (TrainingBin attr + BinPrompt kept; `PromptAt` re-parented to the kit body,
   same local CFrame; PrimaryPart = kit body, PivotOffset identity -> pivot unchanged, 0 moved). 24 crates (20 x 4, 4 x 5) -> F_Crate A/B/C in
   turn with a seeded 90-degree yaw; kit body = exact Part box (checked: size+centre error < 0.01); old Crate + 48 straps hidden in place.

## Play test (Studio Play, 1 client)
| Test | Result |
|---|---|
| Screens | 6 SurfaceGuis adorned to the kit faces (LeaderboardGui 940x580 on Signs.Screen_Leaderboard; LF_* canvases from the mesh sizes); LF Offset audit 0 |
| Screens update | Training screen "1 OPERATOR TRAINING NOW / DEBITS (YOU)" after Enter; DuelsTV live; standing on Pad_1v1_B -> `LF_LiveDuels` 1v1 pads 1 |
| Reward stand | TopName / BoardName = DEBITS, "0 WINS"; SpinRoot rotating; 23 reward parts |
| Pits | beside pit: stands (root 19.03, Concrete); on the rim strip: stands; over pit 1 and 2: falls and is returned to (-99, 19.13, 0) in ~0.5 s |
| Bins | F prompt on the kit bin opened the picker; Sniper / AutoRifle given as TRIAL; Leave clears it |
| Crates | ray hits `F_Crate4A__crate_green` at the old crate face (z -54), no NotCover |
| Beacons | 4 tagged lenses in workspace |
| Console | no new errors (pre-existing: MatchmakingManager MemoryStore, UIBlox FoundationProvider warnings, AssetCheck "1/1146 Texture failure" seen in both runs; not traced) |
| Checks (Edit, final) | check_rooms2 FAILS 0; check_rooms3 FAILS 0 (32 pit points skipped by the [FEAT] rule: bigger holes); check_training ALL OK; check_hub1 informational, no new hits |

## Known issues / to do
- Studio's viewport went **pure white** for ~15 min mid-session (Edit and Play; not content: an UNDO didn't fix it) and then came back by
  itself. If it happens again, wait / re-capture rather than chasing the scene.
- Leaderboard off-switch moves only `Signs.Screen_Leaderboard`; its frame model `Signs.F_Screen16x9_Leaderboard` stays (empty frame).
- Pipe runs on the tunnel/corridor walls are visual only above head height; the corridor junction box stands 0.25 off the recessed panel
  (flush to the band beside it).
- Training crate kit green (65,94,56) reads lighter than the old dark crates in Edit captures; judge in Play (Training lights).
- Reward stand shows #1 of the leaderboard data; the reward model is fixed (Sniper), not per player.
