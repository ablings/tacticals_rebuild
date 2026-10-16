# Feature pass: script + screen side (done 2026-10-15)

Edward's picks 3, 4, 18, 19, 20, 21, 23 and the effects 29-32 restyled to our theme (brief: `notes/brief_features.md`).
`Tacticals_rebuild.rbxl` only (studio 8ef4e21a-...). **Not saved** (the lead saves). No computer use, no Blender. Own code only.
Items 14, 26 and 27 (reward stand, TV arm kit, industrial props) are the parallel Blender kit pass and are not in here.

## How to run / revert
| What | Command |
|---|---|
| Install / re-install (idempotent) | edit `scripts/features/*.lua` → `python tools/build_features.py` → `python tools/run_luau.py fix/install_features.lua` |
| Revert everything | `python tools/run_luau.py fix/install_features.lua UNDO`: deletes the 4 modules (attribute `LF_New`), `LobbyMap.Features`, `Signs.Screen_Leaderboard`, `ServerStorage._LobbyFeaturesOff`, and gives the two Duels floor meshes their collision back (from `LF_OrigCollide`). Tested: UNDO then re-install, same log. |
| Switch one feature off | `ReplicatedStorage.Modules.Shared.Config.LobbyFeaturesConfig` (`Enabled = false`), or `ReplicatedStorage:SetAttribute("LF_<Name>", false)` before Play. Names: DropPits, TrainingScreen, Leaderboard, DuelsTV, LikesBoard, AdBoard, DuelsSign, Wayfinding, Spotlights, Beacons, InteractFX, VentPuffs. Off = `LobbyFeaturesManager` moves that geometry to `ServerStorage._LobbyFeaturesOff`; DropPits off also restores the floor collision first. Tested with DropPits + VentPuffs off: both folders moved, the floor collides again, standing where the pit was holds (root y 19.03). |

**No existing game script was edited.** QueueManager is read through its own `LobbyRemotes.Handlers.GetQueue`, matchmaking through
`MM_Counts` / `MM_Status`, Training through the `InTraining` attribute, and the leaderboard through the part its script already waits for.
The installer still has the `[FEAT]` edit/UNDO machinery (empty `EDITS`). One **check** script got a marked `[FEAT]` change:
`fix/check_rooms3.lua` skips points inside the drop-pit footprints in the "Duels hall floor gap" grid, because the pits are holes on purpose.

## New code (all own; `scripts/features/`)
| Module | Where | Does |
|---|---|---|
| `LobbyFeaturesConfig` | ReplicatedStorage.Modules.Shared.Config | flags + values; `C.On(name)` (attribute `LF_<name>` wins); `C.Features` list |
| `LobbyFeaturesManager` | Managers (server) | off-switching; drop-pit catch; duels feed `ReplicatedStorage.LF_LiveDuels` (JSON); likes attributes; rewarded-ad remote (only when a product id is set) |
| `LobbyScreensController` | Client.Controllers | builds the screen UIs: SurfaceGui in PlayerGui, `Adornee` = any Part tagged `LobbyScreen` with attribute `Screen` (Training / DuelsTV / DuelsSign / Likes / Ad). **Scale only** (audited in Play: 0 GuiObjects with Offset). The ad prompt (`LF_WatchAd` attribute) fires `Events.Lobby.LF_WatchAd`. |
| `LobbyFeaturesFXController` | Client.Controllers | beacon pulse (tag `LF_Beacon`), vent puffs (tag `LF_VentPuff`), black fade on a pit return (player attribute `LF_PitReturn`) |

Geometry: `scripts/features/_geometry.lua` (in the installer). Every new part is non-colliding / non-query / no-touch unless stated.

## Features
### 3 Drop pits → Duels start
- Two 6 x 10 pits in the Duels hall, in the centre columns between the 1v1 and 2v2 rows: x -117..-111, z 12..22 and z -22..-12.
  Each has 6-stud walkways either side (the check routes at x -108 / -120 to the 3v3 pads stay clear).
- `D_Floor__floor_border` and `D_Floor__floor_field` are single meshes covering the hall, so their **collision is replaced**: CanCollide off
  (original in `LF_OrigCollide`), 5 invisible proxy slabs (`Features.DropPits.FloorProxy`, top 16.03 = the mesh's top, same material)
  cover the hall minus the two holes. Visual: black `Void` plate + cream rim + olive Neon lip (flush), dark shaft walls below, and a
  "KEEP CLEAR" floor stencil in front of each pit. **The floor mesh still draws over the hole**; the Blender rim kit needs a floor cut
  (or a re-exported D_Floor with openings) to be a real opening.
- `Pit_n.Catch` (6 x 16 x 10 under the floor) is box-tested by the server 10x a second; anyone inside (not in Training) is put at
  `DropPits.ReturnPoint` (-99, 16.1, 0) + 3, facing into the hall, velocity zeroed; the client fades from black (0.6 s).
### 4 Training entrance screen
- `Features.TrainingScreen.Screen_Training`: 10 x 6.2, hub east wall by the Exfil tunnel (x 87.4, y 15.6, z -22.3), facing the hub.
- Lists everyone with `InTraining == true` (headshot + name, 2 x 4 cards, "+N MORE"), "N OPERATORS TRAINING NOW" or "RANGE OPEN · NOBODY
  INSIDE RIGHT NOW", footer "BOARD THE HELI AT EXFIL >". Updates on the attribute, joins and leaves.
### 18 Leaderboard
- `LobbyMap.Signs.Screen_Leaderboard` (10 x 6.17 = the 940:580 canvas), north wall x -55.5, y 15.6, Front face into the hub. The existing
  `StarterPlayerScripts.LeaderboardScreen` finds it and draws `ReplicatedStorage.LobbyTopWins` (from `ServerScriptService.LobbyLeaderboard`;
  Studio: local fallback list). Its UI is the old Offset code on a FixedSize canvas, left untouched (not ours; converting it would be an edit).
### 19 Live duels TV
- `Features.DuelsTV.Screen_DuelsTV`: south wall x -55.5, opposite the leaderboard. Rows: "MATCH FOUND · n" for pads counting down, then
  live matches "MODE | team A VS team B | LIVE · m:ss" (max 5), footer "IN QUEUE 1V1 n · 2V2 n · 3V3 n" (pads + online).
- Data: the manager polls `GetQueue` every 0.5 s; a bay switching to `Deploying` logs a match (names by team). Online matches found from
  this server are logged from `MM_Status` = Found/Teleporting. Entries live `MatchMinutes` (6) and are shared with every lobby server over
  MessagingService topic `TacLiveDuels_v1` (subscribe runs in its own thread: it never returns in Studio). **Scores/ends are not known in the
  lobby**: the match place can publish `{k = key, sc = "3 - 1"}` or `{k = key, e = true}` on the same topic and the TV shows/clears it
  (key = the `k` the lobby published; would need to be passed in TeleportData to be useful).
### 20 Likes goal + rewarded ad
- `Features.LikesBoard.Screen_Likes` (north wall x 55): "LIKE THE GAME", `current / goal LIKES`, olive bar + %, reward line ("GOAL REACHED!"
  at 100 %). **No API gives a game's like count inside a server**, so the numbers are Edward's: config `LikesBoard.Current/Goal/Reward`, or at
  runtime `ReplicatedStorage` attributes `LF_LikesCurrent` / `LF_LikesGoal` / `LF_LikesReward` (the board updates live).
- `Features.AdBoard.Screen_Ad` (south wall x 55) + `PromptSpot` prompt. Roblox's rewarded-video API **is present** in this Studio:
  `AdService:CreateAdRewardFromDevProductId(id)` works on the server (returned `AdReward {type = DevProduct}`),
  `GetAdAvailabilityNowAsync(Enum.AdFormat.RewardedVideo)` is **client-only** ("Local player is not available" on the server) and returned
  `InternalError` in Studio, `ShowRewardedVideoAdAsync(player, reward)` is server-side. It needs a **Developer Product** whose receipt grants the
  reward (ProcessReceipt) plus Roblox's ad eligibility. `AdBoard.DevProductId = 0` → **stub**: board says COMING SOON / "REWARDED ADS ARE NOT
  SET UP IN THIS PLACE YET", prompt disabled, no remote. Set the id → the remote `Events.Lobby.LF_WatchAd` appears, the prompt turns on, the
  client shows availability. Untested end to end (ads don't play in Studio).
### 21 DUELS sign live strip
- `Features.DuelsSign.Screen_DuelsSign` 9 x 2.4 under the hub DUELS sign (stair-core wall x -84, y 5.6, facing the hub). Three cells: mode,
  total in queue (big), "n PADS / n ONLINE".
### 23 Wayfinding
- Cream floor chevrons (3 per set, flush, 0.05 thick): Duels x -30 / -56 (→ -x), Exfil x 30 / 62 (→ +x), Shop z 27 (→ +z), Armory z -27 (→ -z),
  Exfil hall x 117 (→ heli), Duels hall door x -103 (2, → pads).
- Floor stencils (Oswald, cream, Front-face SurfaceGui on a flat part so the top of the text points along the walking direction):
  DUELS, EXFIL · TRAINING, SHOP, ARMORY, TRAINING (exfil), KEEP CLEAR x2.
- Label plate "TRAINING · BOARD THE HELI" (7.2 x 1.3, cream on near-black, olive Neon edge) on the Exfil hall south wall (116, 13, -25.8).
### 29-32 Effects (our theme: olive / cream / warm white; no purple; no ambient particles)
- **29 Spotlights** (7): dark housing + warm-white lens + yoke + rod to the structure (rod lengths measured with the kit made queryable).
  4 under the two hub bridges (x ±48.75, y 23.4, z ±7) aimed at the spawn hologram (range 60, 28°, one with shadows); Shop counter;
  Armory gun wall; Armory dais (shadows). Every beam path checked clear to its target.
- **30 Beacons** (4): amber on the hangar mouth top corners (126, 21.6, ±26.4); red on the tops of the two existing hangar gear posts
  (149.6, 15, ±25). Neon ball + PointLight (range 9); client pulse: quick rise, slow fall, dark half the 2.6 s cycle, phases offset
  (sampled in Play: colour/brightness cycling 0 → 1.4).
- **31 Interactables**: hologram cones (camera-facing Beam, cream → olive, 0.72-0.8 transparent) on the Shop counter, Armory gun wall (with an
  olive floor ring at the prompt spot) and Armory dais; 3 sparkle emitters (rate 2.5, tiny, cream/olive) around the same three.
- **32 Vent puffs**: 4 of the real hub floor-vent grilles (H_Bays louvres at x -55 / 55 north, -27.5 / 27.5 south, y 3.5): Rate 0 emitters,
  the client emits 3-5 soft warm-grey puffs every 6-12 s. (The old `FX.Steam` emitters at the same vents stay disabled by particles_fix.)
- These 10 effects are new emitters/beams outside `LobbyMap.FX`; a re-run of `fix/particles_fix.lua` would list them as UNCLASSIFIED (it only
  reports; it does not disable them). They are purpose-bound (fixtures/interactables/vents) by Edward's pick.

## Play tests (Studio Play, 1 client) — evidence in `out/features/`
| Test | Result |
|---|---|
| Console | no errors from the new modules (pre-existing: MatchmakingManager MemoryStore "publish this place", UIBlox warnings) |
| Screens built | 5 `LF_*` SurfaceGuis + `LeaderboardGui`, each adorned to its part; Offset audit **0** |
| 18 Leaderboard | `LeaderboardGui` shows TOP OPERATORS / BY WINS, #1 DEBITS 0 WINS, #2-#10 "—" (`play_screens_ui_v1.jpg`) |
| 19/21 queue change | standing on Pad_1v1_A: snapshot `Countdown n1 cd5..1`, sign/TV feed `1v1 pads = 1`; on deploy the TV listed `1V1 DEBITS VS — LIVE · 0:04`. On Pad_2v2_B: TV `2V2 PAD 02 MATCH FOUND · 2`, footer `IN QUEUE 1V1 0 · 2V2 1 · 3V3 0`, sign `2V2 1 / 1 PADS`. 3v3: `play_duels_queue.jpg` (sign 3V3 1, TV two live rows) |
| 4 Training screen | before: "RANGE OPEN · NOBODY INSIDE RIGHT NOW"; after `Events.Training.Enter`: "1 OPERATOR TRAINING NOW / DEBITS (YOU)" |
| 3 Drop pit | beside the pit (-108, 17): stands at root y 19.03 on the proxy (FloorMaterial Concrete). Over the pit: root y 19.3 → 18.0 → 16.1 → 12.2 → **returned to (-99, 19.13, 0) after 0.61 s**, `LF_PitReturn` set |
| 20 Likes | attribute 640 → "640 / 1,000 LIKES", bar 64 % (`play_screens_ui_v1.jpg`) |
| 20 Ad | stub: COMING SOON, prompt Enabled false, `LF_AdReady` false; API probe results above |
| 30 Beacons | 4 tagged; colour/brightness sampled every 0.45 s cycle as designed |
| Flags | DropPits + VentPuffs off: geometry in `_LobbyFeaturesOff`, floor collision back |
| Checks (Edit, after the final install) | `check_rooms2` FAILS 0; `check_rooms3` FAILS 0 (16 pit points skipped, `[FEAT]`); `check_training` ALL OK; `check_hub1` informational, no flags |

**Captures:** Studio's 3D viewport rendered **pure white** for every capture from the first install on, in Edit and in Play, also after a full
UNDO (so not caused by this pass; the Training session hit the same thing). 2D UI renders, so the screen UIs were captured by cloning each
SurfaceGui into a ScreenGui: `out/features/play_screens_ui_v1.jpg` (all six screens; v1 still had the "▸" glyph and the tag/dot overlap that
were fixed after it) and `out/features/play_duels_queue.jpg` (TV + sign + Training after those fixes; the sign's sub-label wrap seen there was fixed after it: no wrap, "n PADS / n ONLINE"). A ViewportFrame preview of the 3D
placement also came out empty. **No eye-height world captures (`play_*.png`) exist yet**: re-capture chevrons, stencils, pits, spotlights,
beacons, cones and puffs once Studio renders again (likely needs a Studio restart, which was out of bounds here: nothing is saved).

## Known issues / to do
- World captures (above). Placement was checked by rays instead: screens sit between pilasters (scan at y 11/15.6/19.5), spotlight beams
  reach their targets, beacons have open sky above, the exfil plate sits on the wall/pier face.
- Pit floor mesh draws over the opening (see 3). Pit rims/void are Parts until the Blender rim kit.
- Mouth beacon bases touch `E_Mouth__wall_light`'s collision hull (visual top is 21.54; base sits on it). Cosmetic.
- Stencil text orientation follows from the Front-face maths (UpVector = walking direction); confirm by eye on the first working capture.
- Duels TV can't show scores (no result channel from the match place yet); "VS —" for a solo Studio deploy.
- MessagingService untested across servers (Studio); the TV works locally without it.
- LeaderboardScreen's UI uses Offset (existing code); convert it to Scale only if Edward wants that rule applied to old screens too.
- Screens are temporary dark plates (`TempBezel` / `TempLip` children). For the TV kit: re-parent the screen part (keep its tag `LobbyScreen` +
  attribute `Screen`, or for the leaderboard its name/path), delete the temp children, size the part to the kit's screen face.
