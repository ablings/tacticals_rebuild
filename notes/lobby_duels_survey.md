# Lobby duels: survey (facts only, read-only, 2026-10-16)

Sources: the match place `match_place_ref.rbxl` (studio 331cb3a0, place 81861384114744, downloaded 15:24 today, the source of truth);
the lobby rebuild copy `Tacticals_rebuild.rbxl` (studio 8ef4e21a). Every script in both places was dumped to the scratchpad (packages
skipped) and read or diffed. Nothing was written to either place. The older match file (5ebdc96a, 2026-10-06) was only listed, not used.
The plan built on these facts is in `notes/lobby_duels_design.md`.

**"Garage" = `Workspace.Warehouse`.** Neither place has anything named Garage. The match place has one arena, `Warehouse`, plus `MatchSpawns`,
a `FiringRange` (237 instances, test servers only) and an `AnimRig`.

## 1. Match place: how a match runs

Boot: `ServerScriptService.ServerScripts.[Server] Init` → `ModuleLoader` starts the managers (`shared.Get("<Name>")` looks one up).
`Players.CharacterAutoLoads = false`. The place has no CollisionGroups apart from Default (`Characters` is registered at runtime by
PlayerRegistry). Streaming is off and FallenPartsDestroyHeight is -500.

### RoundManager (427 lines, pass 38): the whole match
- **Server kind** comes from the first player's `GetJoinData().TeleportData`:
  - Match server: `{Mode, Ranked, Teams = {A = {userIds}, B = {userIds}}}` and `Tutorial ~= true`.
  - Tutorial: `TeleportData.Tutorial`.
  - Test server: Studio, or no data in a public server. The first two players duel 1v1 with endless rematches, the test kit and infinite ammo.
  - The Studio switch `ReplicatedStorage.StudioSoloMatch = "1v1"/"R1v1"` plays a solo forfeit match.
- **TeleportData intake.** The lobby sends `{Mode, Ranked, BayId, Teams, Loadouts, From}`. QueueManager pads add BayId. MatchmakingManager
  (PLAY) adds `Queue, MatchId, Online`. **RoundManager reads only `Mode, Ranked, Teams`.** `Loadouts` (equipped kit, validated
  against Owned by the lobby's `PlayerStore.Loadout`) is ignored. **TeleportData never carries owned items.** The match place reads the
  shared profile itself (`DataManager:Get(player)`), since both places use the same ProfileService store `"gameStore"` (`"studioStore"` in Studio).
- **Arrival:** `MatchState = "Waiting"`, then it waits up to `ArrivalTimeout` (30 s) for every expected user id.
  - A team missing: "MATCH CANCELLED", then back to the lobby with no penalty.
  - Strangers are kicked.
- **Loadout:** `applyOwnedLoadout(player, profileData)` takes `data.Loadout` per slot if `data.Owned[id]` or it's the default.
  - Defaults: `{Weapon = "Pistol", Melee = "Fists", Gadget = "Smoke"}`.
  - It sets the player attributes **`Loadout` (the weapon id)**, `KitMelee`, `KitGadget`. There is no pick screen and no `KitWeapon`.
- **Rounds (`playMatch` / `playRound`):**
  - `ScoreA/B = 0`. Players get `InMatch = true`, `Team = "A"/"B"`, `RoundWins`, `MatchKills = 0`, `GadgetThrows = 0`.
  - Per round:
    1. `ShootableManager.ResetAll()` and `GadgetManager.ClearAll()`.
    2. `MatchState = "Countdown"`.
    3. `player:LoadCharacter()`, wait for character attr `Ready`, `PivotTo(spawnFrame(team, i))`, and anchor the root (frozen).
    4. Countdown of 3 s: announce "ROUND n".
    5. Unfreeze, `MatchState = "Live"` (90 s), announce "FIGHT".
  - Win check every 0.05 s:
    - A team with nobody present forfeits.
    - A team with nobody alive loses, re-checked 0.1 s later for trades, so a trade is a draw.
    - On timeout the team with more total health wins; equal health is a draw.
  - After a round: `RoundEnd` (3 s). First to `RoundsToWin = 3` (best of 5) wins, with a safety cap of `MaxRounds = 9`.
  - At the end: `MatchState = "MatchEnd"` (`ResultsTime` 12 s).
- **`spawnFrame(team, slot)`:** `MatchSpawns.SpawnA/SpawnB` CFrame. Teammates stand side by side, 4 studs apart, at +3 y.
- **Deaths:** `hookDeaths` counts kills, headshots, melee and deaths from the victim Humanoid attributes `LastAttacker` (userId, 0 = bot),
  `LastHitZone`, `LastAttackKind`, set by CombatManager, MeleeManager and ShootableManager. Teamkills don't count.
  **Dead players stay dead until the next round** (no auto respawn: CharacterAutoLoads is off).
- **Rewards (`award`)** use `MatchConfig.Rewards`:
  - XP: 100/match + 50/kill + 150/win.
  - Scissors (`data.Credits`): 25 + 10/kill + 50/win, x2 with the `DoubleCredits` pass and x1.25 with VIP.
  - Gun XP: 50 + 25/kill, to `data.ItemXP[weapon]`.
  - `data.Stats` (MatchesPlayed, Kills, Headshots, MeleeKills, GadgetsThrown, Wins).
  - Ranked: Elo, K 32, `data.Ranked[mode]`.
  - It writes the raw profile table and sends `Events.Match.MatchResults:FireClient(player, summary)`.
- **Back to lobby:** `TeleportService:TeleportAsync(LobbyPlaceId 126491009194165, players)`, 3 attempts (Studio: a warn only).

### Published state (what the HUD reads today)
- ReplicatedStorage attributes:
  - `MatchState`: Waiting / Countdown / Live / RoundEnd / MatchEnd / Tutorial.
  - `StateEndsAt` (server time), `RoundNumber`, `CombatEnabled` (true in Live and Waiting).
  - `LiveMatch`, `MatchMode`, `MatchRanked`, `ScoreA`, `ScoreB`, `TestMode`, `InfiniteAmmo`.
- Player attributes: `InMatch`, `RoundWins`, `Team`, `MatchKills`, `GadgetThrows`, `Loadout`, `KitMelee`, `KitGadget`,
  `SmokeCharges/FlashCharges/FragCharges`.
- Character attributes: `Ready`, `Stance`, `AimPitch`, `GunHand`. Humanoid attributes: `LastAttacker`, `LastHitZone`, `LastAttackKind`.
- Remotes:
  - `Events.Match.MatchAnnounce(title, subtitle)` and `Events.Match.MatchResults(summary)`. `MatchResults` is created at runtime.
  - `Events.Combat.*` (FireWeapon, ReloadWeapon, HitConfirm, WeaponFired, AimPitch (unreliable), SetGunHand, DamageTaken, ThrowGadget,
    SelectWeapon, Melee, MeleeHit, FlashDetonated, Explosion).
  - `Events.Movement.SetStance`, `Events.Bot.RequestPractice`, `Events.Tutorial.*`, `Events.Range.SetKit/Teleport`.
- Client readers: `Client.GUIs.MatchHUD` (MatchState/StateEndsAt, RoundWins, MatchAnnounce) and `StarterPlayerScripts.MatchResults`.

### Other managers
| Manager | What it does | Map / global assumptions |
|---|---|---|
| CombatManager (415) | Server-authoritative guns: ammo, fire rate, reload, shot validation, damage by hit zone. Gives the `Loadout` gun on every CharacterAdded once `Ready`. | `WeaponUtil.IsPathClear` = **`workspace:Raycast`** (walls block shots). `CombatEnabled` / `LiveMatch` / `InfiniteAmmo` read **globally from ReplicatedStorage**. No friendly fire when `LiveMatch`. `WeaponFired` goes to every client. Longest range: 600 (Sniper). |
| GadgetManager (665) | Smoke / Flash / Frag. **Grenades are server-simulated physics parts in `workspace`** (`SetNetworkOwner(nil)`). Smoke = invisible `SmokeCloud` cell Parts flooding outward, stopped by walls. | `mapRay` raycasts `Warehouse.CollisionProxies` (Include filter) in `workspace`. `ClearAll()` deletes **every** smoke/grenade in workspace (one match per server). `FlashDetonated` goes to every client. Charges via `KitGadget`, `InfiniteCharges` unless `LiveMatch`. |
| ShootableManager (538) | Fire barrels (explode: hides the barrel parts server-side, saves Transparency/CanCollide/CanQuery, burn DoT, fire patches), steam valves (emitters + `SteamUntil` attr, masks noise), props make noise. `ResetAll()` per round. | Hard-wired to `workspace.Warehouse` (`Shootables`, `Props`, `CollisionProxies`); fire Parts go into `workspace`; `Explosion` goes to every client. |
| DoorManager (61) | `Warehouse.Interactive.Door_*`: ProximityPrompt on `Panel` tweens `Shutter` up `OpenHeight` (10) in 1.6 s; Led red/green. `CloseAll()` exists but **RoundManager doesn't call it**. | `workspace:WaitForChild("Warehouse")`. |
| MeleeManager (131) | Melee tools, backstabs, wall check by `workspace:Raycast`; no friendly fire when `LiveMatch`. | Global `CombatEnabled`. |
| MovementManager (28) | `SetStance` → character attr `Stance`. Speed is client-driven. | none |
| PlayerRegistry (249) | Blocky R15 normalisation, no overhead names, `MaxHealth = MatchConfig.PlayerHealth` (150), accessories non-colliding/non-query, `Characters` collision group, ragdoll on death, character attr `Ready`. | none |
| EventManager (21) | Empty `Start()`. | none |
| BotManager (1224), TutorialManager (1532), RangeManager (208) | Practice bots, the starter tutorial, firing range: **not needed for pad duels.** | `MatchSpawns`, `FiringRange`, `Instructor` |
| DataManager (113) | ProfileService `"gameStore"` + ReplicaService. Template `ProfileVersion` only (it reconciles nothing, so it never wipes lobby keys). | none |
| KitGuard (84) | Re-gives a missing gun/melee to live match players after 3 s; logs where a tool went. | `LiveMatch`, `InMatch` |
| SettingsBridge (34) | Applies lobby settings in the match. | none |

`MatchConfig`: `PlayerHealth 150, RoundsToWin 3, CountdownTime 3, RoundTime 90, RoundEndDelay 3, MatchEndDelay 6, ArrivalTimeout 30,
ResultsTime 12, MaxRounds 9, StartingRating 1000, Rewards {...}, LobbyPlaceId, SpawnFolderName "MatchSpawns"`.

## 2. The Warehouse: what it needs and what it costs

`Workspace.Warehouse` (Model, no PrimaryPart): **518 instances, 302 BaseParts (209 Part + 93 MeshPart), all anchored.**
- Bounding box **84 x 22 x 120.4**, centre/pivot (-84.2, 9.4, 7.5).
- Floor top at y ~0. It relies on the place's `Baseplate` (2048 x 16 x 2048, top y 0, visible, collides) **and** its own `COLP_Floor` proxy.
- Assets:
  - 93 unique MeshIds; 86 SurfaceAppearances (44 unique texture maps); no Textures/Decals.
  - 30 SurfaceGui + TextLabel (26 of them are crate labels drawn on the invisible proxies).
  - 11 lights: 8 `ArenaLights` PointLights, br 1.84, range 40, **shadows on**; 2 door beacons; 1 workbench SpotLight.
  - No particles, no scripts.
- Triangles: not readable from Luau in Edit (SceneAnalysisService needs Play). To be measured in phase 1 (design §9).

| Child | Instances | Parts | Collide / Query / Touch | Notes |
|---|---|---|---|---|
| `Visuals` (Model) | 167 | 87 MeshParts (80 SA) | 0 / 0 / 0 | the look; pure visuals |
| `CollisionProxies` | 94 | 42 Parts, Transparency 1, Concrete, CastShadow false | 42 / 42 / 42 | `COLP_Floor`, `COLP_Ceiling`, walls `COLP_Wall_*`, crates `C01-10`, `L01-14`, pillars `P01-06`, `W01-04`; 26 crate SurfaceGuis ("LOT C03 // FRAGILE") |
| `Props` | 159 | 115 Parts | 49 / 0 / 49 | Chair x4, Extinguisher x2, Pallet x6, PaintCan x3, Workbench, Table, Apple, Bottle x14, Cardboard x11; 1 SpotLight. Shots pass through (never cover); the client shows them breaking |
| `Shootables` | 54 | 32 Parts + 4 MeshParts | 8 / 8 / 8 | FireBarrel_F1-F4, SteamValve_S1-S2 (tags `FireBarrel`, `SteamValve`) |
| `Interactive` | 22 | 12 Parts + 2 MeshParts | 8 / 6 / 4 | Door_North / Door_South: `Shutter` (MeshPart 16x9x0.45, collides), `Panel` + ProximityPrompt, `Led`, `Beacon` (PointLight), 2 `Bollard`, `OutOfBounds` (18x20x1, invisible, collides), attr `OpenHeight` = 10 |
| `ArenaLights` | 16 | 8 Parts | 0 | 8 PointLights |

- **Everything that collides, queries or touches = 107 parts** (CollisionProxies 42, Props 49, Interactive 8, Shootables 8), 2 of them MeshParts
  (the shutters). **Visible parts: 226.**
- `Workspace.MatchSpawns`: `SpawnA` (-53.25, 0.6, -42.5) and `SpawnB` (-115.25, 0.6, 57.5), facing each other.
- Lighting:
  - Brightness 2, ClockTime 13, Ambient (72,76,84), OutdoorAmbient (78,82,90), ExposureCompensation -0.1.
  - Children: Sky, Atmosphere, Bloom, `MapGrade` (ColorCorrection), `TutorialArenaOriginalLighting` (Configuration).
  - Technology isn't readable by plugin script.
- Client code that names the map: `CoverController` (`workspace.Warehouse` Props/Shootables excluded from cover; `COLP_Floor` top for
  obstacle boxes). Its server-side users are listed in the table above.

## 3. Lobby side (rebuild copy)

- `Workspace.LobbyMap`: 16,983 instances; Workspace has 7,644 BaseParts.
  - Every lobby part is inside x -200..621, y -312..649, z -415..332.
  - Streaming off, FallenPartsDestroyHeight -500, `CharacterAutoLoads = true`.
  - CollisionGroups: Default, DuelBarrier, DuelQueued (`Characters` is registered at runtime by PlayerRegistry).
  - ReplicatedStorage attribute `InfiniteAmmo = true` (Training).
- **Pads:** 6 Models in `LobbyMap.Duels` (tag `QueuePad`):
  - `Pad_1v1_A/B` (-99, 21, ±18.75), `Pad_2v2_A/B` (-130.6, 21, ±20), `Pad_3v3_A/B` (-114, 21, ±35.4). Duels floor y 16.
  - `ServerScriptService.DuelPads` (loop, 0.2 s): team zone counts, barriers, `DuelQueued` collision group. Visual only.
  - **`QueueManager`** (637 lines) does the real queue:
    1. It adapts each pad into a bay (`Mode`, `BayId`, `TeamSize`, invisible `Slot` parts).
    2. Standing in a team zone takes a slot (`QueueMode` attr); stepping off releases it.
    3. When full: `Countdown` (`LobbyConfig.CountdownTime` = 5 s). Anyone leaving cancels.
    4. Then `deploy(bay)`: `Deploying = true`, root anchored, then **ReserveServer + TeleportAsync to `LobbyConfig.MatchPlaceId`
       (81861384114744)** with TeleportData `{Mode, Ranked, BayId, Teams, Loadouts, From}`.
  - In Studio, deploy only notifies and resets after 2.5 s.
  - Failure, or still here after 20 s: `resetBay`.
  - Remote handlers: `QuickJoin`, `JoinPad`, `LeaveQueue`, `GetQueue`. The `QueueState` snapshot broadcast goes to every client.
  - Ranked bays are supported (`LobbyConfig.RankedBays` / `Ranked` attr, level gate).
- **PLAY:** `MatchmakingManager` (MemoryStore, cross-server) teleports with `{Mode, Ranked, Queue, MatchId, Teams, Loadouts, From, Online}`.
  Player attrs `MM_Queue`, `MM_Status`, `MM_Since`. **Unchanged by this project.**
- Client: `PadBoards` (boards from QueueState), `PadUI` (pad side button, hides when `InTraining`/`Deploying`), `LobbyHudController`
  (To Duels button, hides on `InTraining`/`Deploying`), `LobbyScreensController` (the **DuelsTV** / DuelsSign screens read
  `ReplicatedStorage.LF_LiveDuels` JSON, published by `LobbyFeaturesManager` from QueueManager's `GetQueue` + MM_Counts).
- **Remotes:** `Events.Lobby.{Request (RemoteFunction, `LobbyRemotes.Handlers[action]`), QueueState, Notify}`, `Events.Training.{Enter, Leave}`,
  `Events.Combat.*` (same set as the match place), `Events.Movement.SetStance`. There is **no `Events.Match`** in the lobby.
- **Data:** the same `DataManager` (`"gameStore"`); the lobby's Template has the real keys:
  - `Credits 500`, `Owned {}`, `Loadout {Weapon, Gadget, Melee}`, `Stats`, `Quests`, `XP`, `Favorites`, `ItemXP`, `Ranked`, `Passes`,
    `Receipts`, `Settings`, `RedeemedCodes`.
  - `PlayerStore` writes through the Replica, so the UI updates live: `Get / Set / Increment / Spend / Owns / Grant / AddStat / Loadout / ApplyLoadoutAttributes`.
  - `ApplyLoadoutAttributes` sets **`KitWeapon`**, `KitGadget`, `KitMelee`. The match place uses `Loadout` for the weapon.
  - `LobbyConfig.Items[id]` has `Slot` and `Default`.

### Combat in the lobby (Training)
The lobby already runs the match place's combat stack, gated to the Training room.
- Server managers: `CombatManager`, `GadgetManager`, `MeleeManager`, `MovementManager`, `PlayerRegistry`. Each one is a few lines off the
  match place's copy (diffed):
  - CombatManager: lobby `onReload` returns unless `InTraining`; `SelectWeapon` checks `PlayerStore.Owns`; **no friendly-fire block and
    no `LastHitZone`/`LastAttackKind`** (pass 38 added those only to the match place).
  - MeleeManager: lobby melee needs `InTraining`; no friendly-fire block, no `LastAttacker`.
  - GadgetManager: lobby charges are infinite (no `LiveMatch` check).
  - PlayerRegistry: no `MaxHealth = 150` in the lobby.
  - The lobby's `MatchConfig` lacks the pass 38 fields (`Rewards`, `ResultsTime`...).
- **The lobby's `ShootableManager` is an 11-line stub** (feeds Training bullseyes). There is no DoorManager, RoundManager, KitGuard or bots.
- **Client:** every combat controller (Camera, Cover, Weapon, Hotbar, Gadget, Movement, Scope, Flash, Explosion, Footstep, AimPose,
  HeadLook, HealthBar, Prop, CinematicCamera) gets its RunService/UIS/CAS signals through **`ReplicatedStorage.Modules.Shared.TrainingGate`**.
  `Gate.On()` = `LocalPlayer.InTraining == true`. **It is the single on/off switch for the whole combat client.**
- `TrainingManager`:
  - `Enter`/`Leave` respawn (`LoadCharacter` + `PivotTo`) into the room or back to the hangar.
  - Its 0.3 s safety loop **strips every Tool from anyone not `InTraining`** ("no guns in the lobby, ever") and sends anyone not in
    training **above y 540** to the hangar.
  - `LobbyFallCatch` puts anyone not in training **below y -25 (and above -2000)** back at the hub spawn or the hangar.
- `NameplatesController` shows lobby nameplates (it hides them in training).

## 4. What differs, in short
| Topic | Match place | Lobby |
|---|---|---|
| Weapon attr | `Loadout` | `KitWeapon` (mirror); CombatManager still gives `Loadout` |
| Combat gate | global `ReplicatedStorage.CombatEnabled` / `LiveMatch` | `InTraining` (server) + `TrainingGate` (client) |
| Friendly fire, kill credit attrs | yes (pass 38) | no |
| Health | 150 | 100 (Roblox default) |
| Shootables / doors | full managers on `workspace.Warehouse` | stub / none |
| Respawn | manual (`CharacterAutoLoads` off) | automatic (on) |
| Infinite ammo | off in matches | `ReplicatedStorage.InfiniteAmmo = true` globally |
| Match remotes | `Events.Match.*` | none |
