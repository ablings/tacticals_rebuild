# Place split: Tutorial / Matchmaking / Ranked (design + build, 2026-10-16, [SPLIT])

Edward's decision: separate **places** in the same experience (universe 10769593848, group "gunsy funsy"), not separate experiences.
Three NEW places; the current match place "tutorial spot / matchmaking test" (81861384114744) stays as it is for now.
Facts this builds on: `notes/place_split_survey.md`. Built in the working copies only: lobby 829eb64d (installed, not saved) and the
match place 331cb3a0 (each kind tested, then UNDONE: hash-exact). Nothing saved or published.

## 1. One codebase, one switch
- **`ReplicatedStorage.PlaceKind`** (StringValue) = `"Tutorial"` / `"Matchmaking"` / `"Ranked"`. It is the **only** per-place difference.
  No value = the old combined place: every [SPLIT] edit is a no-op there.
- **`ReplicatedStorage.Modules.Shared.PlaceKind`** (new ModuleScript, server + client, no side effects; source `scripts/split/PlaceKind.lua`):
  `Get()` (kind or nil), `Is(kind)`, `TutorialAllowed()` (nil or Tutorial), `MatchAllowed(ranked)` (nil: both; Matchmaking: casual only;
  Ranked: ranked only; Tutorial: none).
- Every script and shared module (MatchCore, MatchConfig, RankedCore / RankedServer, MapRegistry, MatchState, DataManager, admin, UI)
  stays **byte-identical** in the three places: the three files are copies of one match place plus one installer run each.

## 2. What each place keeps
| | Tutorial | Matchmaking | Ranked |
|---|---|---|---|
| Map | `Workspace.Warehouse` (**it is the tutorial map**: TutorialConfig cover parts, valves, barrels, bottles), `MatchSpawns` (Instructor at SpawnB), `SpawnLocation` | Warehouse + MatchSpawns + `DuelMaps.Warehouse` registry | same as Matchmaking |
| Stripped (moved to `ServerStorage._SplitStripped`, attr `SplitFrom`) | `ReplicatedStorage.DuelMaps` (map-vote registry) | `Workspace.FiringRange` (test servers only) | `Workspace.FiringRange` |
| Kept on purpose | FiringRange (asked for; unused by the tutorial: RangeManager only arms it on a test server) | TutorialManager code (gated off) | same |
| Server runs | `runTutorialServer` + TutorialManager auto-start | `runMatchServer`, casual (`Ranked` forced false) | `runMatchServer`, ranked forced (`Ranked = true`, RankedCore deltas via RankedServer.ApplyResult) |
| Accepts | TeleportData `{ Tutorial = true }` (Studio: always, it's the dev test) | match TeleportData with `Ranked ~= true` | match TeleportData with `Ranked == true` |
| Rejects -> lobby | any match TeleportData; no / bad TeleportData (live) | `Ranked = true`; `Tutorial = true`; no / bad TeleportData | casual; `Tutorial = true`; no / bad TeleportData |
`AnimRig` / `R15` (unreferenced dev rigs outside the walls) stay everywhere; delete later if wanted. No test server runs on a split place
(live or Studio): a public / no-data server is a reject.

## 3. Server kind on a split place (RoundManager [SPLIT])
`manager.Start`: `if PLACE_KIND then first = splitFirst() end` before the old loop (which then never runs).
`splitFirst()` waits for the first player and reads the same inputs the old loop did (`joinMatchData` incl. Studio `StudioTeleportData`,
raw `TeleportData.Tutorial`, Studio `StudioTutorialServer`, Studio `StudioSoloMatch`), then applies the table above. Result: `"tutorial"`,
a match table, or `{ SplitReject = reason }`.
**Reject (`runRejectServer(reason)`)**: warn `[RoundManager] [SPLIT] <kind> place: <reason> - sending everyone back to the lobby`,
`TestMode / LiveMatch = false`, `MatchState = "Cancelled"`, each player present or arriving gets `MatchAnnounce("WRONG SERVER", "Taking you
back to the lobby...")` and, 4 s later, `backToLobby({player})`; retried every ~20 s while still there. Studio: logged only.
`MatchTestHook:Invoke("split")` -> `{ kind, rejected, returns }`.
TutorialManager [SPLIT]: `onStart` and `wantsAutoStart` return early unless `PlaceKind.TutorialAllowed()`, so Matchmaking / Ranked never
start the tutorial (also not by Studio's `AutoStartInStudio`, the T / Y / U keys or an admin call).

## 4. Return to the lobby + data release (unchanged, in all three)
- Match / reject: `RoundManager.backToLobby` -> `[DATA] DataManager.ReleaseForTeleport(list)` -> `TeleportAsync(MatchConfig.LobbyPlaceId
  126491009194165)` x3 -> `RestoreAfterTeleportFail`. Leave, cancel, admin `;endmatch` and the results all use it.
- Tutorial: `TutorialManager.finishToLobby` writes `TutorialDone = true` (attribute `TutorialDoneSaved`), then the same release + teleport
  to `TutorialConfig.LobbyPlaceId` (126491009194165).
- The lobby side releases before every teleport too (QueueManager, MatchmakingManager, NewPlayerTutorial). The places share the
  ProfileService store, so TutorialDone / Ranked / XP written in any of them are read by the lobby.

## 5. Lobby routing (lobby [SPLIT], `fix/split_lobby_install.lua`, installed in 829eb64d)
- `LobbyConfig.TutorialPlaceId = 0` (was 81861384114744), `LobbyConfig.MatchmakingPlaceId = 0`, `LobbyConfig.RankedPlaceId = 0`, and
  `LobbyConfig.PlaceIdFor(kind)` = that id, or **`LobbyConfig.MatchPlaceId` (81861384114744) while it is 0**. So nothing changes until
  the ids are filled in, and each kind can go live on its own.
- `NewPlayerTutorial`: `TeleportAsync(Config.PlaceIdFor("Tutorial"), ...)` (still a reserved server, TeleportData `{ Tutorial = true }`).
- `QueueManager.deploy` (only when in-lobby duels are off): `placeId = PlaceIdFor(bay.ranked and "Ranked" or "Matchmaking")` for both
  ReserveServer and TeleportAsync.
- `MatchmakingManager` (PLAY): `startMatch` reserves on `PlaceIdFor(q.Ranked and "Ranked" or "Matchmaking")` and stores
  `place = placeId` in the MM_Results entry; `deliver` teleports to `tonumber(res.place) or Config.MatchPlaceId`. The reserving and the
  delivering server may differ, and an access code only works on its own place: this keeps them in step, also during a rollout where
  an old lobby server (no `place` field, reserved on MatchPlaceId) wrote the result.

## 6. Installers
| File | Where | Run | UNDO |
|---|---|---|---|
| `fix/split_place_install.lua` | an opened match-place copy | `python tools/split_build.py place <studio_id> Tutorial\|Matchmaking\|Ranked` | `... place <studio_id> UNDO` |
| `fix/split_lobby_install.lua` | the lobby | `python tools/split_build.py lobby <studio_id>` | `... lobby <studio_id> UNDO` |
- Both are idempotent (second run: all "already in") and print a state hash before / after; UNDO returns to the "before" hash.
  Backups `ServerStorage._RebuildRemoved.SPLIT_<name>_Orig`; new objects carry attribute `SplitInstall`.
- The place installer can switch kinds (stash restored, then stripped for the new kind). `split_build.py` refreshes the embedded
  PlaceKind source from `scripts/split/PlaceKind.lua` and refuses dcee58ac / 82b89850. Without Python: paste the .lua into
  `execute_luau` (Edit) after setting `local KIND = "..." --@KIND` (and `UNDO` for an undo).
- **Order:** match place: `match_place_build` -> `data_release` -> `ranked` -> **split**; lobby: `lobby_duels` -> `admin` ->
  `data_release` -> `ranked` -> **split**. The split edits change lines the data_release install wrote (lobby QueueManager /
  MatchmakingManager teleport lines) and RoundManager / TutorialManager text: **UNDO split first** before undoing or re-running any
  earlier installer on those files, then install split again. LobbyConfig with filled-in ids still counts as installed; its UNDO then
  warns and keeps the backup (put the ids back to 0 first for a clean UNDO).

## 7. For the lead: making the three places
`match_place_ref.rbxl` on disk is the **21:10 save**. If 331cb3a0 has unsaved work after that, first File > Save to File there, then
re-make the copies (they are byte copies today, md5 648f1d53...):
`cp match_place_ref.rbxl Tutorial_place.rbxl; cp match_place_ref.rbxl Matchmaking_place.rbxl; cp match_place_ref.rbxl Ranked_place.rbxl`.
Per file (one at a time; ids change on each open, so run `list_roblox_studios`):
1. File > Open from File: `Tutorial_place.rbxl` (then `Matchmaking_place.rbxl`, `Ranked_place.rbxl`).
2. `python tools/split_build.py place <its studio_id> Tutorial` (resp. `Matchmaking`, `Ranked`). Check the last line says
   `PlaceKindValue=<kind>` and no `WARN`.
3. UI: `python ui/deploy_ui.py <its studio_id> --tutorial` (resp. `--matchmaking`, `--ranked`) if the UI session asks (section 8).
4. Check `ReplicatedStorage.StudioTeleportData` / `StudioTutorialServer` / `StudioSoloMatch` are not set; File > Save to File.
5. File > Publish to Roblox As > gunsy funsy > the Tacticals experience > **"Add as a new place"**, named **"Tutorial"**
   (resp. **"Matchmaking"**, **"Ranked"**). Then File > Publish in that window and confirm "published to version N" in Activity History
   (Save As alone only saves: port lesson in notes/port_manifest.md).
6. In Creator Hub > the experience > Places > the new place > settings: leave "Allow direct access" off (a direct join is rejected
   anyway). Note the new place id.
## 8. Ids afterwards
Open the lobby working copy, `ReplicatedStorage.Modules.Shared.Config.LobbyConfig`, and set
`LobbyConfig.TutorialPlaceId`, `LobbyConfig.MatchmakingPlaceId`, `LobbyConfig.RankedPlaceId` to the three ids (the lines under the
`-- [SPLIT]` comment). Nothing else names them: the places themselves only know the lobby (126491009194165, `MatchConfig.LobbyPlaceId` /
`TutorialConfig.LobbyPlaceId`). Then save + publish the lobby. Any id left at 0 keeps that kind on 81861384114744.
The match place's own `LobbyConfig` port also lists `MatchPlaceId` / `TutorialPlaceId`, but nothing there reads them: leave it.

## 9. Admin and UI
- Admin works unchanged in all three: `Core.Place` = "match" (no `Workspace.LobbyMap`); `listmatches` / `endmatch` / `serverinfo` /
  `tp spawna` as in the match place. On a reject server `;listmatches` shows kind none. (Optional later: show PlaceKind in `;serverinfo`.)
- UI session (`ui/deploy_ui.py`, commit b06b82b already has `--tutorial` / `--matchmaking` / `--ranked`: the match-place UI set):
  - It reads the kind from `ReplicatedStorage.PlaceKind` (or `require(Modules.Shared.PlaceKind).Get()`), present in the saved file.
  - Note: `put(dir(...) ...)` is only used with `--match` in argv; with `--tutorial` etc. alone it uses `at(...)`, which errors if a parent
    folder is missing. In copies of the match place all parents exist, so it works; pass `--match` too if in doubt.
  - What differs per kind for the UI: Tutorial = MatchState "Tutorial" only (no map vote, no `DuelMaps`); Matchmaking = casual flow;
    Ranked = `MatchRanked = true`, MatchResults with the ELO fields; every kind can show `MatchState = "Cancelled"` with the
    `MatchAnnounce("WRONG SERVER", "Taking you back to the lobby...")` line (a reject).
  - Seen in the tests (UI files, not changed here): MatchFlowUI `weaponModel` gets a nil id in the Loadout phase ("Argument 1 missing
    or nil", MatchFlowUI lines 339 / 361 / 453 / 505 / 514).

## 10. Tests (2026-10-16 23:12-23:20, Play in 331cb3a0, one client "ocxa"; play lock "map")
Baseline hash before the install `93898d88` (RoundManager 99976a00, TutorialManager fe7cbda0, FiringRange in Workspace, DuelMaps in RS).
- **Matchmaking** (FiringRange stripped): casual `StudioTeleportData {"Mode":"1v1","Teams":{"A":["me"],"B":["bot"]}}` (short StudioTimes):
  Loading 0.3 / Intro 5.2 / MapVote 7.8 / Loadout 12.3 / Countdown 15.4 / Live 16.7 ... MatchEnd 31.6, 3-0 vs the bot (3 hook kills),
  `MatchRanked = false`, no tutorial started (AutoStartInStudio true), back-to-lobby attempted once. **Ranked TeleportData** -> `0.3
  Cancelled`, rejected "a ranked match was sent to the Matchmaking place", return attempted. **No TeleportData** -> rejected "no match
  TeleportData" (no test server, TestMode false).
- **Ranked** (kind switched by the installer: FiringRange restored then stripped again): `{"Mode":"1v1","Ranked":true,"BotElo":1000,...}`
  -> full flow, 3-0, **ELO 100 -> 185 (+85, Bronze 1 beating a Platinum 1 bot)**; client MatchResults `Ranked true, eloBefore 100, eloAfter 185,
  delta 85, RatingChange 85, rankBefore/After Bronze 1, ladder 1v1, TestMatch true` (a Studio test bot: no XP / credits). **Casual TeleportData**
  -> rejected "a casual match was sent to the Ranked place", ELO unchanged.
- **Tutorial** (DuelMaps stripped, FiringRange back): with the casual StudioTeleportData still set -> rejected "a match was sent to the
  Tutorial place". Cleared -> `MatchState Tutorial`, the starter tutorial auto-started; the client fired the Progress events (lines
  TakeCover / Rush / Slide / ToWall / Vault / AimShoot came in order), the Instructor was killed at AimShoot -> `TutorialDoneSaved = true`
  3.5 s later (the profile write), "Ready", `InTutorial` cleared, console `[TutorialManager] tutorial done - in a live game this teleports
  to the lobby place 126491009194165`.
- **UNDO**: hash back to **`93898d88`**, RoundManager / TutorialManager "match their backups", PlaceKind module / value, stash and backups
  gone. `StudioTeleportData` cleared; `TutorialConfig.AutoStartInStudio` untouched (true).
- **Lobby** (829eb64d, installed and left in; before `790cc368`, after `4e51facc`; second run all "already in"; UNDO -> `790cc368` with every script "matches its backup", reinstall -> `4e51facc`): Play: QueueManager and
  MatchmakingManager require fine, no errors; `PlaceIdFor` with ids 0 -> 81861384114744 for all three; with 111 / 222 / 333 -> 111 / 222 / 333.
- Not testable in Studio: the real teleports (lobby -> each place, each place -> lobby, reserved codes across lobby servers), a direct
  join to a new place, two real players, the MemoryStore queues.
