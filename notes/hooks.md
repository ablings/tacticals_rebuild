# Gameplay hooks a lobby rebuild must keep (survey 2026-10-14, read-only)

All live scripts were dumped to `out/survey/src/*.lua` (107 files; library packages skipped) and grepped for LobbyMap paths,
tags, attributes, prompts, touch parts, hard-coded coordinates and Lighting. Workspace itself has no scripts (only the NPC
`Animate` LocalScripts). Rule of thumb: **keep `Workspace.LobbyMap` and every folder/part name below; geometry under
`Unique/`, `Instances/`, `HubProps/`, `Clutter/` is free to replace** (only AssetCheck and a few FX look into it).

## 1. Must keep (breaks gameplay if renamed / moved)

| Hook | Script(s) | Looks up | Keep |
|---|---|---|---|
| Duel queue pads | `ServerScriptService.DuelPads` (server, loop), `...Managers.QueueManager` (server, matchmaking + teleport), `StarterPlayerScripts.PadBoards` (client boards) | CollectionService tag **`QueuePad`** on Models; `workspace.LobbyMap.Duels` children that are Models with attribute **`QueueName`** (1v1/2v2/3v3) and **`PlayersPerTeam`**; children **`Team1`**, **`Team2`** (zone Parts, box test in CFrame space), **`Team1Barrier` / `Team2Barrier`** (CanCollide/Transparency toggled), **`Holo`** (board anchor, proximity < NEAR, also `platform` for step-off/look direction), `Platform` optional. QueueManager writes attributes Mode/BayId/TeamSize, QueueZone/Team on zones, BayStatus on Holo, creates `Slot` parts | Folder `LobbyMap.Duels`; 6 Models `Pad_<mode>_<A/B>` with those attributes + tag; zone Parts sized 9-11 x 10 x 9-11 at y 21 (floor 16); barriers around each zone; Holo part beside each pad. Collision groups **`DuelQueued`** (set on queued characters) and **`DuelBarrier`** (on the barrier Parts) must exist and stay non-collidable with each other. Pads' world positions can move but stay walkable and within 40 studs of the pad pivot for QUICK JOIN. |
| Exfil -> Training | `StarterPlayerScripts.ExfilFX` (client) | tag **`ExfilBarrier`** (Touched by own character); `LobbyMap.Exfil` + **`Exfil.HatchPoint`**, **`Exfil.CabinPoint`** (CFrames); `LobbyMap.Heli` (all BaseParts lifted; parts with attribute **`Rotor`** = "Main"/"Tail"; Heli attributes **`Mast`**, **`TailHub`**, **`TailAxis`** Vector3s); hard-coded camera `lookAt((120,9,-18),(133,4,2))` (start shot); since 2026-10-16 the lift is the `--[[POSE]]` block (`LIFT_T`, `liftPose(e)` about CabinPoint, `liftCam(e)`), swept by `fix/check_heli.lua` straight from the source | ExfilBarrier part (tag, CanTouch), HatchPoint/CabinPoint, Heli model with rotor attributes. If the heli moves, update the camera constants in ExfilFX. Also creates `PlayerGui.ExfilFade.QuickEnter` used by `LobbyUIController` (PLAY > TRAINING). |
| Training room | `...Managers.TrainingManager` (server) | `LobbyMap.Training`; **`Training.Arrivals`** children (random spawn CFrames) or **`Training.TrainingArrive`**; **`Training.EnemySpots`** children (336 x 1-stud Parts; dummy pivot = spot.Y - 3 + height/2); parents dummies to `Training`; constants **`FLOOR_Y = 600`** (fell out if y < 585; non-training players above y 540 are sent to the hangar), **`HANGAR = CFrame(112, 3.5, 0)`** | Training floor at y ~600, enclosed; Arrivals + EnemySpots folders; nothing non-training at y > 540. `ServerStorage.RangeAssets.Dummy` template. |
| Hangar / fall catch | `ServerScriptService.LobbyFallCatch`, TrainingManager | hard-coded HANGAR (112, 3.5, 0) facing +X, SPAWN (0, 4, 0); anyone below **y -25** (and above -2000) is put back: x > 95 -> hangar, else spawn | Hangar floor walkable at (112, ~0, 0); hub spawn walkable at (0, 0, 0); no legit floors below y -25 in the lobby. |
| Shop / Kit prompts | `LobbyUIController` (client, `ProximityPromptService.PromptTriggered`) | any ProximityPrompt with attribute **`OpenPanel`** opens that panel ("Shop", "Kit", "Play"); attribute `Teleport == "Range"` shows a toast | `Interact.Shop_Counter` (3,3,101.8) prompt "Browse SUPPLY" OpenPanel=Shop d9; `Interact.GunWall_Kit` (0,6,-110.5) "Customise KIT" OpenPanel=Kit d12; `Interact.Armory_Dais` (-10,2.5,-96) "Customise KIT" OpenPanel=Kit d11. Names are not looked up, only the attribute: positions free. |
| NPCs | `ServerScriptService.LobbyNPCs` (idle anim on every Humanoid under `LobbyMap.NPCs`), `StarterPlayerScripts.LobbyLabels` (speech bubble from prompt attribute **`TalkLines`** "a|b|c" over the NPC's `Head`), LobbyUIController (OpenPanel) | `LobbyMap.NPCs` (WaitForChild 30); each NPC: Humanoid, Head, HumanoidRootPart.ProximityPrompt with TalkLines + OpenPanel | NPC_Quartermaster (10,3,106.7) in the SHOP but OpenPanel=**Kit** with kit lines; NPC_Supply (7,4.2,-110.6) in the ARMORY but OpenPanel=**Shop** with stock lines; NPC_DuelsOfficer (-88,19.2,8.5) at the top of the stairs, OpenPanel=Play. **The first two look swapped** (Edward to confirm before the rebuild places them). |
| Showroom (Kit menu viewer) | `LobbyUIController.Armory` (client) | `LobbyMap.Showroom` (fallback `LobbyMap.Armory`), **`DisplayPoint`** (item centre), **`CameraPoint`** (camera CFrame), **`BenchTop`** (table top Y for the fake shadow) | Folder + 3 marker parts; the room around them is only seen through that camera (currently at y 399-427, non-colliding, non-queryable). Lights tagged RoomLight Room=Showroom. |
| Spawn | Roblox | `LobbyMap.LobbySpawn` SpawnLocation (0,0.3,0) 24x24 | One SpawnLocation; delete the 6 duplicate copies. Fall-catch SPAWN is (0,4,0). |
| Cover system (training) | `CoverController` (client), CombatManager raycasts | any CanCollide part without attribute `NotCover` is cover; shots raycast against the map | Training cover blocks/walls must collide; give `NotCover` to anything that shouldn't be cover. Lobby is gun-free (TrainingManager strips tools outside training). |

## 2. Visual hooks (break effects only; easy to re-wire)

| Hook | Script | Looks up |
|---|---|---|
| Room lights on near camera | `StarterPlayerScripts.RoomFX` | tag **`RoomLight`** (29 Parts) + attribute **`Room`** in {Shop, Armory, Exfil, Training, Showroom}; hard-coded centres Shop (0,6,89), Armory (0,8,-91), Exfil (150,10,0), Training (0,606,0) r175, Showroom (0,410,8); radius 75. Lights outside the list stay off! Also spins any Model with attribute **`Spin`** (Armory.FeaturedScissors, 25 deg/s). Lighting budget comment: ~45 enabled lights. |
| Lobby ambience | `StarterPlayerScripts.LobbyFX` | needs `LobbyMap.FX` (WaitForChild, infinite); tags `LobbySpin` (attr spin, bob), `LobbySpark` (children Sparks/Flash), `LobbyScroll` (Textures), `LobbyRipple` (Decal), `LobbyRotor` (attr base CFrame, speed), `LobbySky` (child "Sky" image, attr dir), `LobbyHUD` (Radar/Alt/Spd/Hdg/Oat/Bar1-6 labels), `LobbyTicker` (T0/T1), `LobbyBeacon` (attr kind nav/strobe), `LobbyRun` (attrs A, B, spd, ph), `LobbyCartUI` (Bar); MeshPart names `K_PodHead__emit_cyan`, `K_PodHeadR__emit_cyan`, `U_EnergyWall__emit*` (breathing), `K_GShop__emit_amber` (flicker); `LobbyMap.Props.Crane` (attr x, PivotTo (x,57,z sweep ±34)) and `Props.Drone` (loops the hall, radius 62 x 26 at y ~22); creates 12 floor pulse parts at x ±27..85, z ±6, y 0.03 in FX; low-end mode disables `Lighting.Lobby_DOF`, shrinks `Lighting.Lobby_Bloom`, sets workspace attributes LobbyFXLow / LobbyFXfps. |
| Heli rotor idle | `StarterPlayerScripts.HeliRotorFX` | `LobbyMap.Heli` (WaitForChild, infinite) children with attrs `SpinAxis`/`SpinCenter`/`RPS` (none currently: inert) |
| Pad boards | `StarterPlayerScripts.PadBoards` | Duels models with `BayId` (set by QueueManager) and `Holo`; hides `Holo.Display` BillboardGui |
| City billboards | `Client.Controllers.BillboardController` | tag **`CityBillboard`** + attributes `BillboardKind` (Hero, Brand, Brand2, Ticker, Promo, Promo2, Promo3, Crown, Side), `BillboardFace`. Builds a runtime `BillboardGui_Live` on each tagged part (draws even on a Transparency-1 part). Since backdrop_sky (2026-10-16) **no part carries the tag** (parked in `Backdrop_Tags` on the hidden TimesSquare parts): the controller runs with nothing to do. |
| World blur / grade | `WorldMoodFX`, `ReplicatedStorage.Modules.Shared.UITheme`, ShopScreen, MissionsScreen, Armory UI, Explosion/FlashController, LoadingScreen | create their own effects in Lighting at runtime: `UIWorldBlur`, `UIWorldGrade`, `MenuUIBlur`, `TransitionBlur`, `ArmoryBackgroundBlur` (removes `ArmoryBlur`), `LoadingBlur`, flash CC/blur. No script sets Lighting properties (Brightness, ClockTime, Ambient...) and nothing applies `ServerStorage.LobbyMap_V2_Lighting`; only **`Lobby_DOF`** and **`Lobby_Bloom`** are looked up by name. |
| Asset check | `StarterPlayerScripts.AssetCheck` + `ServerScriptService.AssetCheckServer` | preloads every MeshPart/SurfaceAppearance/Decal/Texture under LobbyMap and reports `Unique.U_Floor__floor_metal`, `U_Floor__grate`, `U_Floor__dark_metal`, `U_SpawnDisc__spawn_logo` fetch status (diagnostic only; reports MISSING if renamed) |

## 3. Referenced but already missing (dead / dormant code: no need to rebuild, but don't be surprised)
- `LobbyMap.Deployment.Bays` (PadFX, BayBoards, QueueManager's first choice), `LobbyMap.Command.ScreenRing` (QUEUE STATUS
  screen), `LobbyMap.Range` (LobbyRangeClient + server LobbyRange / `RangeScore`), `LobbyMap.Labels` (floating station labels),
  `LobbyMap.Screens` (LobbyTickers), `LobbyMap.Signs.Screen_Leaderboard` (LeaderboardScreen: global top-10 board, data still
  published to `ReplicatedStorage.LobbyTopWins` every minute), `Signs.Screen_Brief_East/West`, `Screen_GunWall_East/West`,
  `Screen_Ranked` (LobbyScreensFX), `Heli.HeliTrigger` (old "range isn't open" toast). If the rebuild adds a leaderboard
  screen, name it `LobbyMap.Signs.Screen_Leaderboard` (Front face) and LeaderboardScreen lights up again.
- Several WaitForChild calls without timeout will hang silently if a folder is missing: `LobbyMap.FX` (LobbyFX),
  `LobbyMap.Heli` (HeliRotorFX), `LobbyMap.NPCs` has a 30 s timeout.

## 4. Other runtime facts
- Remotes: `ReplicatedStorage.Events.Lobby.{Request, QueueState, Notify}`, `Events.Training.{Enter, Leave}`,
  `ReplicatedStorage.RangeScore`, `AssetCheckReport` (created at runtime), `LobbyTopWins` StringValue.
- Player attributes used across lobby scripts: InTraining, QueueMode, Deploying, MM_Status, MM_Queue, VIP.
- `NewPlayerTutorial` teleports new players to `Config.TutorialPlaceId` (not in Studio); QueueManager teleports full bays to
  `Config.MatchPlaceId`. Neither depends on map geometry.
- Workspace.StreamingEnabled is off, so scripts' streaming-safe tag hooks are not exercised; turning streaming on in the
  rebuild would break the many direct `WaitForChild`/`FindFirstChild` paths above.

## Changes made by the rebuild (keep in sync)
- 2026-10-15 rooms3_place: `Duels.Pad_1v1_A/B.Holo` moved (-92.8, 24.5, -/+18.75) -> (-100.5, 24.5, -/+18.5) and `PostCollide`
  (-92.8, 18.4, -/+18.75) -> (-96.6, 18.4, -/+18.5) (hub1 west wall buried them). Originals in attribute `Rooms3_OrigCF`; UNDO via
  `fix/place_rooms3.lua UNDO`. Holo also steers QueueManager.stepOffCFrame (dir Holo -> zone): re-check landing spots if it moves again.
- `Exfil.L_Hangar` (114, 15, 0) -> (114, 19, 0). `FX.SparkDuels` untagged LobbySpark (kept in `Rooms3_Tags`).
- 2026-10-15 place_training (notes/training_build.md): the new room is in `Training.Range2`. The old Arena and its 12 lights are
  hidden (Training_* attributes; the lights are untagged RoomLight). `Training.Arrivals` (16 on a ring round (0,600,0)) and
  `Training.EnemySpots` (44; 16 `GallerySpot` with `Gallery = true`, `Distance`, `Lane`) are new folders. The originals are in
  `ServerStorage._RebuildRemoved.Training_*_Old`. `TrainingArrive` moved (-10.05,603.2,-110) -> (0,603.3,0) facing +x (original in
  `Training_OrigCF`). There are 19 new RoomLight Training lights. UNDO via `fix/place_training.lua UNDO`.
- 2026-10-15 place_showroom: the kit is in `Showroom.Rooms4`. The old `U_Showroom__*` meshes and `Showroom.Sign` are hidden
  (Rooms4_* attributes). The hook parts are untouched; the kit table moved +0.2 to BenchTop's real top (404.4).
- 2026-10-15 overlap_fix (notes/overlap_fix.md): 46 kit meshes nudged/scaled <= 0.07 (originals in Overlap_OrigCF/Overlap_OrigSize); openings ~0.14 narrower (decor proud). Props.Rotor hidden; 4 Duels FX3 beacons hidden + untagged LobbyBeacon (Overlap_Tags). UNDO via `fix/overlap_fix.lua UNDO`.
- 2026-10-15 lap_fix (notes/lap1.md): `NPCs.NPC_DuelsOfficer` moved z 7.9 -> 7.1 (arm was in the stair rail; original in `Lap_OrigCF`).
  New `Hub1.LapFix` folder: 18 non-colliding wall infill Parts (gate/tunnel bays y 52-68) + `TunnelThreshold` floor plate (x 104..105,
  collides, top 0.02). SignText_SHOP/ARMORY re-centred, SignText_Deck +0.04 x. `Workspace._UVTest` x3 -> `ServerStorage._RebuildRemoved`.
  Training: bridges -0.04, tile greys R lean dropped (place_training). TX_LastTargetShot trace removed from the Training scripts.
  UNDO via `fix/lap_fix.lua UNDO` (+ overlap_fix UNDO for the 3 lap mesh nudges: H_DuelsDoor__trim_metal y, D_Lines__neon_cream y, SR_Stage__dark_metal z).
- 2026-10-15 particles_fix (notes/particles.md): 65 ambient effects under `LobbyMap.FX` (all but `FX.Hologram`) + `Duels.SkyBeam`
  disabled (originals in `PFX_OrigEnabled`); `LobbySpark` removed from SparkBridgeA/B/Gantry (`PFX_Tags`). LobbyFX: floor pulses and
  spark bursts gated by `[PFX]` flag `workspace.PFX_AmbientFX` (false); original source in `ServerStorage._RebuildRemoved.PFX_LobbyFX_Orig`.
  UNDO via `fix/particles_fix.lua UNDO`.
- 2026-10-15 features (notes/features_done.md): `LobbyMap.Signs.Screen_Leaderboard` now exists (LeaderboardScreen lights up). New
  `LobbyMap.Features` (DropPits, screens, Wayfinding, Spotlights, Beacons, InteractFX, VentPuffs). **Duels floor collision moved**:
  `Rooms3.D_Floor.D_Floor__floor_border/__floor_field` CanCollide false (`LF_OrigCollide`), collision = `Features.DropPits.FloorProxy`
  (two holes at x -117..-111, z +-12..22). Screens are found by tag `LobbyScreen` + attribute `Screen`. New remote (only with an ad product id):
  `Events.Lobby.LF_WatchAd`; attributes `ReplicatedStorage.LF_LiveDuels / LF_Likes* / LF_AdReady`, player `LF_PitReturn`.
  UNDO via `fix/install_features.lua UNDO`.
- 2026-10-15 place_features_kit (notes/features_kit_place.md): the screen parts are now the kit `__screen` MeshParts (same names, tag
  `LobbyScreen` + `Screen` kept; `Signs.Screen_Leaderboard` is a MeshPart with `LF_New`). Drop-pit holes 8 x 10 (x -118..-110); the Duels
  floor meshes are hidden (`FK_FloorHidden`), look = `Features.DropPits.FloorSlabs`. Beacons: tag `LF_Beacon` on the kit lens. New
  `Features.RewardStand` (LobbySpin on `RewardModel.SpinRoot`), `LobbyMap.IndustrialProps`. Swap bins: PrimaryPart = `F_SwapBin__crate_green`
  (PromptAt moved onto it). Training crates: Parts hidden, kit `KitCrate` models carry the collision. UNDO via `fix/place_features_kit.lua UNDO`.
- 2026-10-15 polish_shop3 (notes/polish_shop.md round 3): `Features.Spotlights.Spot_ShopCounter` moved to (7.5,11.6,95.0) and re-aimed at the
  Shop stage (original pivot in `PolishShop3_Orig`). `NPCs.NPC_Quartermaster` (not renamed or moved): Tag text OUTFITTER, Tag size Scale 4.2 x 0.9,
  offset 2.55; prompt ObjectText OUTFITTER, cosmetic TalkLines (original in `PolishShop3_Orig_TalkLines`); OpenPanel unchanged (Kit).
  `Interact.Shop_Counter` prompt text "Browse outfits / CHECKOUT", OpenPanel=Shop unchanged. New Spin model
  `Polish.Shop.Round3.FeaturedStage.FeaturedOutfit` (Spin=12). `Rooms.Shop.L_Pedestals` light disabled. UNDO via `fix/polish_shop3.lua UNDO`.
- 2026-10-15 polish_armory2 (notes/armory_weapon_slots.md): `Rooms.Armory.FeaturedScissors` keeps its name, pivot and `Spin`, but its
  scissors MeshParts are hidden and it now contains `WeaponSlot_Featured_1` (Anchor + Weapon). New `ServerStorage.ArmoryWeaponSlots`
  ModuleScript (edit-time only, nothing requires it at runtime). `NPCs.NPC_Supply.Tag` Size/StudsOffset changed (`PolishArmory2_Orig`).
  UNDO via `fix/polish_armory2.lua UNDO`.
- 2026-10-16 polish_duels (notes/polish_duels.md): **`StarterPlayerScripts.PadBoards` source edited** (team colours: new `TEAM_A`/`TEAM_B`
  cream/olive replace RED/BLUE in 3 team uses; original in `ServerStorage._RebuildRemoved.PolishDuels_PadBoards_Orig`). `Rooms3.D_Lines__neon_cream/olive`
  hidden; `FX.SparkBridgeA/B/SparkGantry` lights disabled; `Lights.TargetTop` retuned; Duels `Holo.Display` CountA/CountB colours. Nothing under
  `LobbyMap.Duels` moved or renamed; new parts in `Polish.Duels` collide with nothing. UNDO via `fix/polish_duels.lua UNDO`.
- 2026-10-16 polish_armory3 (notes/polish_armory.md round 3): the 9 `WeaponSlot_GunWall_n` Anchors moved down 0.46 and `Gap` 0.1 -> 0.04
  (originals `PolishArmory3_OrigY/OrigGap`); new `Polish.Armory.Round3` (featured backdrop: 2 collidable parts at (-15.4,-103.7), pegs, pin caps).
  Hooks untouched (FeaturedScissors, prompts). UNDO via `fix/polish_armory3.lua UNDO`.
- 2026-10-16 polish_exfil (notes/polish_exfil.md): Rooms3 `E_*__band_olive` / `E_*__neon_olive` recoloured amber and `Exfil.L_Hangar` light
  colour daylight (`PolishExfil_Orig`); new `Polish.Exfil` (8 collidable parts: cargo dolly at (133.2,-23.1), drum truck at (132.6,22.3)).
  ExfilBarrier / HatchPoint / CabinPoint / L_Pad / Heli / X_Clip untouched; ExfilFX camera path and lift sweep clear. UNDO via `fix/polish_exfil.lua UNDO`.
- 2026-10-16 polish_duels2 (notes/polish_duels.md round 2): Polish.Duels lanes/frames recoloured, old mode plates hidden, new ones in
  `Polish.Duels.Round2`; `Features.Wayfinding.Chevrons` (Duels bars) and `Rooms3.D_Pads__label_cream` recoloured (`PolishDuels2_Orig`).
  Nothing under `LobbyMap.Duels` touched. UNDO via `fix/polish_duels2.lua UNDO` (before polish_duels UNDO).
- 2026-10-16 polish_gates (notes/polish_gates.md): `Hub1.Overlays.SignText_SHOP` label text SHOP -> OUTFITTERS; `Rooms2.C_CorrN/C_CorrS`,
  `S_Door__wall_light/trim_metal` and the corridor `F_PipeRun__band_olive` recoloured (`PolishGates_Orig`); new `Polish.Gates` (64 parts,
  none collide). UNDO via `fix/polish_gates.lua UNDO`.

- 2026-10-16 polish_gates2 (notes/review_gates.md): `IndustrialProps.F_JunctionBox` (N corridor) `__dark_metal` / `__trim_light` now CanCollide +
  CanQuery, Box fidelity, NotCover (`PolishGates2_Orig`). UNDO via `fix/polish_gates2.lua UNDO`.
- 2026-10-16 polish_exfil2 (notes/polish_exfil.md round 2): the round-1 `Polish.Exfil.Windsock` hidden (`PolishExfil2_Orig`); new `Polish.Exfil.Round2`
  (windsock on the kerb at (152.25, 1.4, 24.8), base + pole collide, behind the clip wall; container stencil carriers). Hooks untouched.
- 2026-10-16 polish_olive (notes/polish_hub.md): 152 olive-painted parts recoloured lobby-wide (`PolishOlive_Orig`), incl. `Features.Wayfinding`
  label edge and the features-kit screens' bands. No names, tags or positions changed. UNDO via `fix/polish_olive.lua UNDO`.
- 2026-10-16 polish_hub (notes/polish_hub.md): Hub1 envelope / lamps / skylight colours, `FX.Hologram` decal / beam / ring colours and its PointLight
  colour, `Features.Wayfinding.Stencil_SHOP` text OUTFITTERS and Size 8.4 wide (`PolishHub_Orig`); new `Polish.Hub` (banners, sign bars, sun-shaft
  Beams; nothing collides or is queryable, no lights). UNDO via `fix/polish_hub.lua UNDO` (before polish_olive UNDO).
- 2026-10-16 polish_training (notes/polish_training.md): Range2 `Shell.WallBand` x5 hidden (rebuilt per quadrant in `Polish.Training.Bands`),
  gallery bands / `Blocks.Band` / `Towers.Band` recoloured, grid Textures 34 / T 0.32, the 4 east-wall field `Signs.DistSign` lowered 1.6
  (`PolishTraining_Orig`). New `Polish.Training` (letters, floor plates, bin marks: nothing collides / queries / touches, NotCover). No EnemySpots,
  Arrivals, Extras or cover moved. UNDO via `fix/polish_training.lua UNDO`.
- 2026-10-16 polish_showroom (notes/polish_showroom.md): `Showroom.KeyLight` SpotLight retuned (part untouched); `Showroom.Lights.Pendant1-4`
  **moved** (rim + background light) and retuned, `Lights.Fill` retuned (tags / Room kept); `Rooms4.SR_Props` hidden, `SR_Stage` / `SR_Signs__label_cream`
  recoloured (`PolishShowroom_Orig`). DisplayPoint / CameraPoint / BenchTop untouched. New `Polish.Showroom` (cyclorama, lamp cans). UNDO via
  `fix/polish_showroom.lua UNDO`.
- 2026-10-16 polish_showroom2 (notes/polish_showroom.md, round 2): Showroom as an armory nook. `Polish.Showroom` (round 1 cyc + lamp
  cans) **hidden**; `Showroom.KeyLight` SpotLight and `Lights.Pendant1-4` / `Fill` **moved / retuned again** (tags, Room, names kept);
  `Rooms4.SR_Stage` recoloured (`PolishShowroom2_Orig`). New `Polish.Showroom2` (wall at z 21, cheeks x +-15, pegboard, window, vent,
  rack, crates, bench dressing) + **2 new RoomLight Room=Showroom parts** (`Showroom2.Lights.WorkLight`, `.BulkheadLamp`): 8 Showroom
  RoomLights. DisplayPoint / CameraPoint / BenchTop / KeyLight part untouched. UNDO via `fix/polish_showroom2.lua UNDO`.
- 2026-10-16 polish_final (notes/polish_final.md): colours of 39 olive Neon parts, `FX.Hologram.HoloRing1/2` Size + Transparency, 6 `Lights.PointLight`
  lights (y 6, |z| 51) and 9 `TimesSquare` SurfaceLights Enabled false, 2 Textures on `Hub1.H_DuelsDoor.H_DuelsDoor__trim_metal` Transparency 1
  (`PolishFinal_Orig`). No names, tags, positions or hooks changed; nothing created. Run after polish_olive. UNDO via `fix/polish_final.lua UNDO`.
- 2026-10-16 no_panel_prompts (notes/npc_dialogue_only.md): **`Client.Controllers.LobbyUIController` source edited** (world-prompt handler: the
  OpenPanel test also needs prompt attribute `NPC_OpensPanel ~= false`; marked `-- [NPC] dialogue-only (Edward 2026-10-16)`; backup
  `ServerStorage._RebuildRemoved.NPC_LobbyUIController_Orig`). `NPC_Quartermaster` / `NPC_Supply` prompts: `NPC_OpensPanel = false` (talk only,
  TalkLines + OpenPanel attributes kept). `Interact.Shop_Counter` / `GunWall_Kit` / `Armory_Dais` prompts: Enabled false (`NoPanel_Orig`) +
  `NPC_OpensPanel = false`; their OpenPanel attributes (Shop / Kit / Kit) kept. NPC_DuelsOfficer (Play) untouched. UNDO via `fix/no_panel_prompts.lua UNDO`.
- 2026-10-16 backdrop_sky (notes/backdrop_sky.md): `LobbyMap.TimesSquare` hidden (parts/SurfaceGuis, `Backdrop_Orig`) and its 9 `CityBillboard` tags
  removed (`Backdrop_Tags`); new `Polish.Backdrop` (326 Parts: HangarDeck, CommsIsland, LandingPad, FuelDepot, Cables, Clouds; nothing collides,
  queries, touches or casts shadows; no lights). UNDO via `fix/backdrop_sky.lua UNDO`.
- 2026-10-16 exfil_lift (notes/heli_kit.md, Lift path): **`StarterPlayerScripts.ExfilFX` source edited** in three marked places: `spool` local
  (`-- [EXFIL#1]`), rotor spin `9 + 13*spool` / `18 + 22*spool` (`-- [EXFIL#2]`), and the lift render step replaced by the `-- [EXFIL] lift path for the
  UH-60 kit (Edward 2026-10-16)` ... `-- [/EXFIL]` block with the POSE block; fade now waits `LIFT_T` = 2.9 s (was 2.6), fade length / jump / CabinPoint /
  Training entry unchanged. Backup `ServerStorage._RebuildRemoved.ExfilFX_Orig` (Disabled). If the heli, CabinPoint or the pad change, re-tune the POSE
  numbers in `fix/exfil_lift.lua`, re-run it, and `check_heli.lua` must give RESULT fails 0. UNDO via `fix/exfil_lift.lua UNDO`.
- 2026-10-16 lobby_duels phase 1 (notes/lobby_duels_phase1.md): **in-lobby pad duels**. New: `ReplicatedStorage.DuelMaps.<MapId>` (map registry:
  `MapInfo`, `Visual`, `Lighting`), `ServerStorage.DuelMaps.<MapId>.Solid`, `ServerStorage._DuelSource.Warehouse` (the script-ported match-place
  Warehouse + MatchSpawns), `MaterialService.DuelMaps_Warehouse` (WH_Floor variant), modules `Modules.Shared.MapRegistry` / `MatchState`,
  `ServerScriptService.Shared.MatchCore`, `Managers.LobbyDuelManager`, `StarterPlayerScripts.ArenaLoader`. `Modules.Shared.Config.MatchConfig`
  **replaced** by the match place's superset + duel keys (`PadDuelsInLobby` etc.). Runtime (made at server start): `ReplicatedStorage.LobbyDuels`,
  `ReplicatedStorage.MatchFlow`, `Events.Match.MatchAnnounce/MatchResults`, `Workspace.DuelArenas`; pad Models get `NoMap` / `NoMapText`.
  **[DUEL] source edits** (backups `ServerStorage._RebuildRemoved.DUEL_<name>_Orig`): TrainingGate.On (+InDuel), TrainingManager (no strip/hangar/entry
  while InDuel), LobbyFallCatch, CombatManager / MeleeManager / GadgetManager (per-match CombatEnabled / InfiniteAmmo via MatchState, same-match
  damage guard, no friendly fire, LastHitZone / LastAttackKind, kit for InDuel), QueueManager (duelHandoff at countdown end, NoMap pads never count
  down, duelists never hold a pad, JoinPad/QuickJoin refuse duelists, snapshot `duelWait` / `noMap`, Studio `DuelTestSolo`). Player attrs used:
  DuelMatch, InDuel, Alive, LoadoutReady, OwnedItems, MatchDeaths. Arenas live at x >= 4000, y 100 (holds at y 40): nothing of the lobby may be
  built there. UNDO via `fix/lobby_duels_install.lua UNDO`, then `fix/duel_split_map.lua UNDO`.
- 2026-10-16 lobby_duels phase 2 (notes/lobby_duels_phase2.md): new `ServerScriptService.Shared.ArenaShootables`; **17 more [DUEL] edits**:
  CombatManager / MeleeManager (`WeaponFired`, `MeleeHit` via `MatchState.FireScoped`), GadgetManager (`mapRay` uses
  `LobbyDuelManager.RayFilter`, effects parented by `fxParent` into `DuelArenas.<id>.FX`, `FlashDetonated` scoped, charges spent when
  `LiveMatch`, new `ClearIn(folder)`), **`Managers.ShootableManager` stub** (OnShot routes arena shots to `LobbyDuelManager.OnShot`; new
  `Explode` for frags in arenas; backup `DUEL_ShootableManager_Orig`). `MapRegistry`: folder name = map id, folder attr `Modes` overrides
  MapInfo. `fix/duel_split_map.lua` re-run with `LightBudget` (Visual: `ArenaLights` keep their PointLights unshadowed + 2 `ShadowSpot`
  SpotLights). Runtime: `DuelArenas.<id>.FX`, `PanelPrompt` parts on Solid doors, Solid model attrs (DoorOpen / Exploded / SteamUntil...),
  profile key `DuelPairs`, Studio-only `ServerStorage.DuelTestHook`. Arena slot x 4000..9000, y 100, holds y 40: still nothing of the lobby there.
  UNDO via `fix/lobby_duels_install.lua UNDO` (41 edits), then `fix/duel_split_map.lua UNDO`.
- 2026-10-16 admin framework (notes/admin_framework.md, survey notes/admin_survey.md): **`ServerScriptService.AdminCommands` source replaced**
  by the framework entry point and **`StarterPlayerScripts.AdminFeedback` source replaced** (backups `ServerStorage._RebuildRemoved.ADMIN_AdminCommands_Orig`
  / `ADMIN_AdminFeedback_Orig`, Disabled). New `ServerScriptService.AdminFramework` (Config, Permissions, Args, DataAdapter, Audit, Core, Commands/*).
  **[ADMIN] edits**: `QueueManager.bayIsFull` (a pad with an `AdminDuelSolo` player counts down alone; line after the [DUEL] DuelTestSolo line),
  `LobbyDuelManager.StartMatch` (test bots also fill a match that includes an `AdminDuelSolo` player; live too, never pays); backups
  `ADMIN_QueueManager_Orig` / `ADMIN_LobbyDuelManager_Orig`. **`fix/lobby_duels_install.lua` rewrites LobbyDuelManager: re-run `fix/admin_install.lua` after it.**
  Runtime: `ReplicatedStorage.AdminFeedback / AdminRequest / AdminRemote`, `TextChatService.AdminCommands` (TextChatCommands `;name`, legacy `/name`),
  `ServerStorage.AdminBindable`, a `ShouldDeliverCallback` on every TextChannel (holds back admins' mistyped `;commands`; nothing else sets it),
  player attributes `AdminDuelSolo`, `AdminGod`, `AdminSpeed`, character `AdminGodField` ForceField, Studio-only `ServerStorage` attributes
  `AdminSim_<userId>`, DataStore `AdminAudit_v1`. Profile writes only through PlayerStore. UNDO via `fix/admin_install.lua UNDO` (tested hash-exact).
- 2026-10-16 match place on MatchCore (notes/match_place_flow.md; **match place** `match_place_ref.rbxl`, studio 331cb3a0, not the lobby):
  **`Managers.RoundManager` and `Modules.Shared.Config.MatchConfig` sources replaced** ([MATCH]; backups `ServerStorage._RebuildRemoved.MATCH_RoundManager_Orig`
  / `MATCH_MatchConfig_Orig`). New (attribute `MatchInstall`): `Modules.Shared.MapRegistry` / `MatchState`, `Modules.Shared.Config.LobbyConfig` (subset
  port: keep in sync with the lobby's items / level curve), `ServerScriptService.Shared.MatchCore`, `ReplicatedStorage.DuelMaps.Warehouse` (+ MapInfo; the
  map itself stays `Workspace.Warehouse` + `MatchSpawns`, names unchanged), `ServerScriptService.AdminFramework` / `AdminCommands`, `StarterPlayerScripts.AdminFeedback`.
  Runtime: `ReplicatedStorage.MatchFlow`, Studio-only `ServerStorage.MatchTestHook`; new ReplicatedStorage attrs `MatchPhase`, `PhaseEndsAt`, `TeamA/B`,
  `RoundsToWin`, `MapList/MapVotes/MapChosen`, `ArenaMap`, `MapFallback`; new MatchState values Loading / MapVote / Loadout / Cancelled; player attrs
  `Level`, `OwnedItems`, `KitWeapon/KitMelee/KitGadget`, `LoadoutReady`, `Alive`, `MatchDeaths`. Studio switch `ReplicatedStorage.StudioTeleportData` (JSON).
  Tutorial / test-server / FiringRange paths and TutorialManager / BotManager / RangeManager untouched; every script that looks up `workspace.Warehouse`
  still finds it. Shared changes also re-installed in the lobby (MatchCore helpers + `ctx.aborted`; admin `Core.Place` + `place = "lobby"` on duelsolo /
  arenas / pads). UNDO via `python tools/match_place_build.py --run UNDO` (tested hash-exact).
- 2026-10-16 match place follow-up (notes/match_place_flow.md "Follow-up"): **new map folder `Warehouse.CamSkin`** (36 invisible collide /
  query / touch Parts flush with the visual walls) in the match place's `Workspace.Warehouse` and the lobby's `ServerStorage._DuelSource.Warehouse.Warehouse`
  (so the lobby arena's Solid layer has them after `fix/duel_split_map.lua`); anything that enumerates the map's colliders by folder still sees only
  `CollisionProxies`. UNDO `python tools/camskin_build.py <id> UNDO` (+ re-split in the lobby). Match place: MatchFlow "Loaded", new MatchState values
  Intro / Cancelled, ReplicatedStorage `LoadedCount / LoadedTotal`; MatchConfig `MatchLoadTimeout`, `IntroTime`. Lobby: duelist bodies wait in the Hold
  facing their round spawn (LobbyDuelManager `facingHold`).

- 2026-10-16 data_release (notes/data_release.md; **both places**): **[DATA] source edits** (backups `ServerStorage._RebuildRemoved.DATA_<name>_Orig`):
  `Data.DataManager` (LoadProfileAsync "ForceLoad" + `[DATA] profile loaded ... in X s` log, player attr `DataLoadTime`; new
  `DataManager.ReleaseForTeleport(players)` / `RestoreAfterTeleportFail(player, why)` / `IsReleased(player)`, `DataManager.Released`;
  a teleport release no longer kicks; TeleportInitFailed / 30 s auto-reload; kick with a message only if the reload isn't safe).
  Release before every TeleportAsync: lobby QueueManager.deploy, MatchmakingManager.deliver, NewPlayerTutorial; match RoundManager.backToLobby,
  TutorialManager. `CombatManager`: **`HitConfirm(zone, damage, killed, headshot)`**, the new 4th client argument is true for a critical
  (gun Head-zone) headshot. Any code that teleports a player must call `DataManager.ReleaseForTeleport` first. UNDO via
  `fix/data_release_install.lua UNDO` (each place). Re-run the install after `tools/match_place_build.py` (it rewrites RoundManager).
- 2026-10-16 mech_dive (**both places**): **`Client.Controllers.CoverController` source edited** (UI session's [SET] file; 3 edits marked
  `-- [MECH] dive only from jump (Edward 2026-10-16)`, diff in `fix/mech_dive.diff`): the double-tap-Space jump dive now needs a real hop
  started by onJumpKey within `Config.DiveDoubleTap`, no vault in progress and `IsHopping()` (new local `lastHopAt`). Before, any two
  Space taps dived: out of a vault (JumpDive even cut the vault short), from cover, or after a refused hop. Backup
  `ServerStorage._RebuildRemoved.MECH_CoverController_Orig`. UNDO via `fix/mech_dive_install.lua UNDO` (tested hash-exact, both places).
