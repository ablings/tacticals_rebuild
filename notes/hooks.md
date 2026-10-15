# Gameplay hooks a lobby rebuild must keep (survey 2026-10-14, read-only)

All live scripts were dumped to `out/survey/src/*.lua` (107 files; library packages skipped) and grepped for LobbyMap paths,
tags, attributes, prompts, touch parts, hard-coded coordinates and Lighting. Workspace itself has no scripts (only the NPC
`Animate` LocalScripts). Rule of thumb: **keep `Workspace.LobbyMap` and every folder/part name below; geometry under
`Unique/`, `Instances/`, `HubProps/`, `Clutter/` is free to replace** (only AssetCheck and a few FX look into it).

## 1. Must keep (breaks gameplay if renamed / moved)

| Hook | Script(s) | Looks up | Keep |
|---|---|---|---|
| Duel queue pads | `ServerScriptService.DuelPads` (server, loop), `...Managers.QueueManager` (server, matchmaking + teleport), `StarterPlayerScripts.PadBoards` (client boards) | CollectionService tag **`QueuePad`** on Models; `workspace.LobbyMap.Duels` children that are Models with attribute **`QueueName`** (1v1/2v2/3v3) and **`PlayersPerTeam`**; children **`Team1`**, **`Team2`** (zone Parts, box test in CFrame space), **`Team1Barrier` / `Team2Barrier`** (CanCollide/Transparency toggled), **`Holo`** (board anchor, proximity < NEAR, also `platform` for step-off/look direction), `Platform` optional. QueueManager writes attributes Mode/BayId/TeamSize, QueueZone/Team on zones, BayStatus on Holo, creates `Slot` parts | Folder `LobbyMap.Duels`; 6 Models `Pad_<mode>_<A/B>` with those attributes + tag; zone Parts sized 9-11 x 10 x 9-11 at y 21 (floor 16); barriers around each zone; Holo part beside each pad. Collision groups **`DuelQueued`** (set on queued characters) and **`DuelBarrier`** (on the barrier Parts) must exist and stay non-collidable with each other. Pads' world positions can move but stay walkable and within 40 studs of the pad pivot for QUICK JOIN. |
| Exfil -> Training | `StarterPlayerScripts.ExfilFX` (client) | tag **`ExfilBarrier`** (Touched by own character); `LobbyMap.Exfil` + **`Exfil.HatchPoint`**, **`Exfil.CabinPoint`** (CFrames); `LobbyMap.Heli` (all BaseParts lifted; parts with attribute **`Rotor`** = "Main"/"Tail"; Heli attributes **`Mast`**, **`TailHub`**, **`TailAxis`** Vector3s); hard-coded camera `lookAt((120,9,-18),(133,4,2))` | ExfilBarrier part (tag, CanTouch), HatchPoint/CabinPoint, Heli model with rotor attributes. If the heli moves, update the camera constants in ExfilFX. Also creates `PlayerGui.ExfilFade.QuickEnter` used by `LobbyUIController` (PLAY > TRAINING). |
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
| City billboards | `Client.Controllers.BillboardController` | tag **`CityBillboard`** + attributes `BillboardKind` (Hero, Brand, Brand2, Ticker, Promo, Promo2, Promo3, Crown, Side), `BillboardFace` |
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
