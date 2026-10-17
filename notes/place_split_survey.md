# Place split: survey (facts only, read-only, 2026-10-16)

Sources: match place working copy `match_place_ref.rbxl` (studio 331cb3a0, place 81861384114744 "tutorial spot / matchmaking
test") and lobby working copy `Tacticals_rebuild.rbxl` (studio 829eb64d). Read by script / grep; nothing written.
The design built on these facts: `notes/place_split.md`.

## 1. One place, three server kinds (match place `Managers.RoundManager`, `manager.Start`)
The kind is decided from the **first player's** `GetJoinData().TeleportData`, polled every 0.5 s until a player is there:
| Order | Condition | Kind |
|---|---|---|
| 1 | `joinMatchData`: TeleportData is a table with `Teams` (table) and `Mode` (string) **and `Tutorial ~= true`**; Studio: `ReplicatedStorage.StudioTeleportData` (JSON) | **match** (`runMatchServer`; `Ranked` = `first.Ranked == true`) |
| 2 | TeleportData `Tutorial == true`, or Studio attribute `StudioTutorialServer` | **tutorial** (`runTutorialServer`) |
| 3 | Studio attribute `StudioSoloMatch` = "1v1" / "R1v1" | solo forfeit match (ranked when the R prefix) |
| 4 | `game.PrivateServerId == ""` (public server) or Studio | **test** server (`runTestServer`: Waiting + free practice, `TestMode` + `InfiniteAmmo` -> FiringRange, first two players duel 1v1 with rematches) |
| - | a reserved server whose first player has no / bad data | **keeps polling forever** (nothing happens; no return to the lobby) |
- `runTutorialServer`: `MatchState = "Tutorial"`, `CombatEnabled = true`, `TestMode = false`, spawns every player without a body every
  1 s (CharacterAutoLoads is off) at the `SpawnLocation` (-53.2, 0.6, -38.5), next to `MatchSpawns.SpawnA`.
- `runMatchServer` (Loading / Intro / MapVote / Loadout / rounds / MatchEnd / back to the lobby) has **no check of `Ranked`**: it plays
  whatever the TeleportData says. Strangers are kicked; a missing team = Cancelled + back to the lobby.
- `backToLobby(players)`: `[DATA]` `DataManager.ReleaseForTeleport(list)` then `TeleportAsync(LOBBY_PLACE, list)` x3, restore on failure.
  Studio: a warning only, counted in `manager._returns` (`MatchTestHook "returns"`). `LOBBY_PLACE = MatchConfig.LobbyPlaceId` (126491009194165).

## 2. Tutorial pieces (match place)
- **`Managers.TutorialManager`** (1537 lines): a scripted 1v1 vs the Instructor (a BotManager bot). **Its map is the Warehouse**:
  cover parts come from `Workspace.Warehouse.CollisionProxies` (`COLP_P01`, `COLP_C07`, `COLP_L07`, ...; `TutorialConfig` names them), line
  of sight raycasts that folder, tutorial 3 uses `Warehouse.Shootables` (SteamValve_S1, FireBarrel_F1) and a `Bottle` prop through
  ShootableManager. BotManager puts the Instructor at `MatchSpawns.SpawnB`. **There is no separate tutorial map**: the tutorial place
  needs the Warehouse, MatchSpawns and SpawnLocation.
- Start: `Remotes.Tutorial.Start` (key T / Y / U; live only when `MatchState == "Waiting"` and alone; Studio any time) and
  **auto-start** (`wantsAutoStart`): Studio -> `TutorialConfig.AutoStartInStudio` (true today, so Play in Studio starts the tutorial in
  **every** server kind, also during match tests); live -> TeleportData `Tutorial == true`.
- Done (`finishToLobby`): writes **`TutorialDone = true`** into the raw profile (`DataManager:Get`), player attribute `TutorialDoneSaved`
  (retries 20 x 0.5 s), "Taking you to the lobby...", then `[DATA]` `ReleaseForTeleport(player)` + `TeleportAsync(TutorialConfig.LobbyPlaceId
  = 126491009194165)` x3, restore after 3 failures. Studio: a warning "tutorial done - in a live game this teleports ...".
- `TutorialConfig` (ReplicatedStorage.Modules.Shared.Config): `AutoStartInStudio = true`, `AutoStartDelay 2`, `LobbyPlaceId`, `ReadyHold 4`,
  lines, kits, cover names.
- Client: `TutorialController` (+ attributes `InTutorial`, `TutorialActive`, `TutorialPillar*`, `GadgetMode`, `GadgetZone`, `MoveTarget`)
  read by CoverController / GadgetController / WeaponController (the same files in both places).
- **`Workspace.FiringRange`** (237 instances, x ~ -37..190, east of the Warehouse) + `ServerStorage.RangeAssets`: **test servers only**
  (`RangeManager` spawns its dummies and rack prompts only when `ReplicatedStorage.TestMode == true`, which only `runTestServer` sets;
  `RangeManager.Start` returns when the folder is missing). The tutorial does not use it.
- **`Workspace.AnimRig`** (-153.8, 3, -59.8) and **`Workspace.R15`** (-26.1, 1, -46.5): character rigs outside the Warehouse walls,
  **not referenced by any script** (dev / animation rigs).
- `Lighting.TutorialArenaOriginalLighting` (Configuration): a stored copy, not read by scripts.

## 3. Place ids
| Where | Key | Value | Read by |
|---|---|---|---|
| lobby `LobbyConfig` | `MatchPlaceId` | 81861384114744 | QueueManager.deploy (ReserveServer + TeleportAsync), MatchmakingManager.startMatch (ReserveServer) + deliver (TeleportAsync) |
| lobby `LobbyConfig` | `TutorialPlaceId` | 81861384114744 (same place) | NewPlayerTutorial |
| lobby `LobbyConfig` | `SendNewPlayersToTutorial` | true | NewPlayerTutorial |
| match `LobbyConfig` (subset port) | `MatchPlaceId`, `TutorialPlaceId`, `LobbyPlaceId` | 8186.., 8186.., 126491009194165 | nobody in the match place reads the place ids |
| match `MatchConfig` (shared, both places) | `LobbyPlaceId` | 126491009194165 | RoundManager.backToLobby |
| match `TutorialConfig` | `LobbyPlaceId` | 126491009194165 | TutorialManager.finishToLobby |
Also `game.PlaceId` in ProfileService (session lock), AdminFramework Audit / `;serverinfo`, and `From = game.PlaceId` in the lobby's
TeleportData (nobody reads `From`). No other hard-coded place ids in either place (backups in ServerStorage excluded).
**MatchPlaceId == TutorialPlaceId == 81861384114744**: one place serves both, told apart only by the TeleportData.

## 4. Lobby senders
- **`ServerScriptService.NewPlayerTutorial`** (38 lines): on join (never in Studio, only when `SendNewPlayersToTutorial`), waits for the
  profile; a profile without `TutorialDone` and with XP 0 is sent: `TeleportOptions.ShouldReserveServer = true`, TeleportData
  `{ Tutorial = true }`, 1.5 s wait, `[DATA]` release, `TeleportAsync(Config.TutorialPlaceId)` x3, restore after 3 failures. The player
  is sent again on every join until the tutorial place writes TutorialDone. Nothing else in the lobby teleports to the tutorial (no
  replay button / admin command).
- **`Managers.QueueManager`** (686 lines; [DUEL] [ADMIN] [DATA]): lobby pads. **Pads now duel in the lobby** (`duelHandoff` ->
  LobbyDuelManager arenas); `deploy(bay)` (ReserveServer + TeleportAsync to `Config.MatchPlaceId`, TeleportData `{Mode, Ranked = bay.ranked,
  BayId, Teams, Loadouts, From}`) only runs when in-lobby duels are off. `bay.ranked` = pad attr `Ranked` or `LobbyConfig.IsRankedBay`;
  `RankedBays` is empty today (all pads casual). Studio: notify + reset, no teleport.
- **`Managers.MatchmakingManager`** (475 lines; [MM] [RANKED] [DATA]): PLAY's global queues `LobbyConfig.Queues` = 1v1 / 2v2 / 3v3 casual
  and R1v1 / R2v2 / R3v3 ranked (`q.Ranked`). The queue-lease holder runs `startMatch(q, group, matchId)`: **`ReserveServer(Config.MatchPlaceId)`**
  and writes `{m, code, q, mode, ranked, teams}` to `MM_Results` per player. **Every** lobby server then `deliver`s its own searchers:
  `TeleportAsync(Config.MatchPlaceId, {player}, options)` with `ReservedServerAccessCode = res.code` and TeleportData `{Mode, Ranked, Queue,
  MatchId, Teams, Loadouts, From, Online}`. The reserving server and the delivering server can be **different servers**, so they must agree
  on the place (a reserved access code only works for the place it was reserved on). Studio: "match found", no teleport.
- TeleportInitFailed handlers in QueueManager / MatchmakingManager (bay reset / notify) and DataManager (restore).

## 5. Data
- One ProfileService store `"gameStore"` (`"studioStore"` in Studio) for every place; the match place's DataManager Template reconciles
  nothing, so lobby keys survive. `TutorialDone` is a plain profile key written by the tutorial place, read by NewPlayerTutorial.
- `[DATA]` hand-off (notes/data_release.md): every TeleportAsync is preceded by `DataManager.ReleaseForTeleport` and followed by
  `RestoreAfterTeleportFail` on failure, in all five call sites (lobby: QueueManager, MatchmakingManager, NewPlayerTutorial; match:
  RoundManager.backToLobby, TutorialManager.finishToLobby). Re-run `fix/data_release_install.lua` after anything that rewrites RoundManager.
- Ranked (notes/ranked_server.md): RoundManager `award` -> `RankedServer.ApplyResult` when `match.ranked` and not aborted (Studio test bots
  count when `RankedCore.Config.StudioBotRanked`). Casual pays XP / credits only.

## 6. Admin and UI in the match place
- `ServerScriptService.AdminFramework` + `AdminCommands`, `Core.Place` = "lobby" when `Workspace.LobbyMap` exists, else "match"; match
  commands `listmatches` / `endmatch` -> `RoundManager.MatchInfo / EndMatch`, `tp spawna / spawnb` (MatchSpawns), `serverinfo`
  (place id + private / public). Nothing in it depends on the place id.
- UI (UI session, `ui/deploy_ui.py <id> --match`): MatchFlowUI, DuelHUD, LoadingScreen, [SET] controllers, SettingsBridge. The UI session
  already added `--tutorial` / `--matchmaking` / `--ranked` targets (commit b06b82b) that deploy the match-place set and expect
  `ReplicatedStorage.PlaceKind`.
- Managers in the match place: Event, Leaderboard, Combat, Round, Gadget, Movement, Bot, Tutorial, Melee, Door, Shootable, Range (+ KitGuard,
  SettingsBridge, RankedService Scripts).
