# Test place: admin-only map testing [TESTPLACE] (2026-10-28)

Edward: a TEST place "where new maps are tried before they're pushed to Matchmaking, Ranked and the lobby". Plan by the Lead,
approved by Edward (his go to publish this place and the lobby change it needs).

- **Place:** "Test", a new place in the Tacticals experience (universe 10769593848, group gunsy funsy). Place id: **see
  notes/TEST_PLACE_READY.md / notes/port_manifest.md "Live port 46"** (filled in after Publish As).
- **File:** `Test_place.rbxl` at the repo root (the published copy; staging maps live in it). Build log copies: `out/test_place/`.
- **Who gets in:** players the admin framework rates **Admin or higher** (Config.Users list: ocxa = Owner; or gunsy funsy group rank
  254+ = Admin, 255 = Owner). Everyone else is sent back to the lobby. Studio: everyone is Owner unless `;simlevel`.
- **Nothing is saved there**: no scissors, XP, stats, ELO, streaks, missions, match history, settings. The lobby keeps the real save.

## How to use it (admins)
1. In the lobby: `;testplace` (aliases `;testmaps`, `;gotest`). Goes to the **shared** Test server every admin meets in (its
   access code is kept in DataStore `TestPlace_v1`, so admins from different lobby servers land together). `;testplace new` = a
   private one for you alone. Refused while you're in a duel, on a pad, searching, or in Training (says why).
   `LobbyConfig.TestPlaceId = 0` means "not set up": the command says so.
2. On the Test place you spawn in its waiting area (free practice).
   - `;maplist` (`;maps`): every map, live ones and `[STAGING]` ones, with their modes.
   - `;testmatch <map> [1v1|2v2|3v3] [bots|admins]` (`;tm`): starts now. `bots` = you + test bots vs test bots (bots stand still: they
     are targets, not AI). `admins` = every admin on the server split into two teams, bots fill the empty places. Any map with any
     mode (a map whose MapInfo doesn't list the mode says "spawns may crowd"). No map vote, normal match flow otherwise.
   - `;endmatch`: stops it; everyone goes back to the waiting area. One match at a time per Test server.
   - Leave (the match HUD's Leave button) = back to the lobby.
3. The admin panel API lists both commands with their choices (map / mode / vs dropdowns) like every other command
   (`AdminRemote "commands"`). There is no on-screen admin panel in the game yet (UI request in notes/admin_ui_requests.md).

## Stage a new map (map builders)
A staging map exists only in `Test_place.rbxl`: no live place ever votes on it, and the lobby never sees it.
1. `cp Test_place.rbxl out/<map>/Test_place_stage.rbxl`, open it (File > Open, or Start-Process), note the window name.
2. Build the map there with its usual installer (e.g. `fix/map_<map>.lua`, the match-place path that makes
   `ReplicatedStorage.DuelMaps.<Id>` + `Workspace.<WorkspaceName>`). **Build it at a free spot**: the Test place refuses a staging map
   whose box overlaps a map already in Workspace (Warehouse near the origin, Arena around x -600, Warehouse 2 around z -350).
3. `python tools/test_place_build.py stage <window name> <MapId> [ExtraModel1,ExtraModel2]` (e.g. `stage Test_place_stage.rbxl House
   HouseExterior`): moves the DuelMaps entry to `ServerStorage.StagingMaps.<Id>` and its Workspace model(s) into a `Workspace`
   folder inside it. `... UNDO` moves it back. Layout:
   ```
   ServerStorage.StagingMaps.<Id>     (Folder; attributes = the DuelMaps entry's, e.g. Modes "1v1,2v2")
     MapInfo                          (ModuleScript, same keys as live maps: DisplayName, WorkspaceName, Modes, Lighting, ...)
     Workspace                        (Folder: the model named MapInfo.WorkspaceName, with its MatchSpawns, + extra models)
   ```
4. Check in Studio Play: `;maplist` shows it `[STAGING]`; `;testmatch <Id> 1v1 bots`. Then save the file, copy it over
   `Test_place.rbxl`, and publish the Test place (Publish As > gunsy funsy > tacticals > Test > Overwrite > Grant Permissions).
   Only Test changes: Matchmaking / Ranked / the lobby stay as they are.
- On first use in a server the Test place copies the staging models into Workspace and a registry copy into
  `ReplicatedStorage.DuelMaps` (attribute `Staging`), so its lighting, spawns and the match code work like a live map.
- Known limit: managers that scan maps only at server start (shootables, doors, steam) may not arm a staging map's props.

## Promote a map to the live places
Promotion = install the map the normal way where it should go live, then publish those places (Edward's go):
1. Match places: run the map installer in `match_place_ref.rbxl` (as Warehouse 2 in live port 44), save, then build Matchmaking /
   Ranked from it (`tools/port_prep.sh`), publish, read back.
2. Lobby pad duels: the map's lobby path + `fix/duel_split_map.lua ONLY = "<Id>"` in `Tacticals_rebuild.rbxl` (as live port 45).
3. Remove it from the Test place's staging: in a Test place copy delete `ServerStorage.StagingMaps.<Id>`, or keep it and rebuild the
   Test place (below), which then has it live like every other map.

## Rebuild the Test place from the match working copy (after match-place changes)
`cp match_place_ref.rbxl out/test_place/Test_place.rbxl`, open it, then:
```
python tools/split_build.py place <studio id> Test        # PlaceKind = Test, FiringRange stripped, Test routing
python tools/test_place_build.py place Test_place.rbxl    # the Test code (idempotent; UNDO = the same + UNDO)
python ui/deploy_ui.py <studio id> --matchmaking          # the casual match UI, as the Matchmaking place
python tools/run_luau_at.py <studio id> fix/switch_now.lua
```
(not `fix/play_again_queue.lua`: Play Again must not queue testers into live matchmaking). Move every
`ServerStorage.StagingMaps.*` across from the old `Test_place.rbxl` first (copy/paste in Explorer, or re-run each map's installer +
`stage`). Check: `out/test_place/pre.lua` (no Studio test marks, compile all ok), save, copy to `Test_place.rbxl`, publish.

## How it works (code)
| Piece | Where | What |
|---|---|---|
| `PlaceKind` | RS.Modules.Shared (scripts/split/PlaceKind.lua) | kind `Test`: `MatchAllowed` casual only, no tutorial, `IsTest()` |
| split routing | fix/split_place_install.lua | a Test server skips TeleportData (`{ TestPlace = true }`) -> `manager.RunTestPlace` |
| Test runner | RoundManager (scripts/testplace/RoundManager_block.lua via fix/test_place_install.lua) | gate (arrival + every 10 s), waiting area, `StartTest`, staging placement (overlap check on world-axis boxes), Studio hook `ServerStorage.TestPlaceHook` |
| match flow | RoundManager edits | test bots live on Test only, no stranger kick, a cancel stays, the picked map only, `award` pays nothing (`TestMatch`, `TestPlace` in the results) |
| no saves | DataManager edit | `ViewProfileAsync` copies (no lock, never saved); new player = template copy |
| purchases | LobbyManager edit | ProcessReceipt -> NotProcessedYet on Test (Roblox retries in the lobby) |
| boards | LobbyLeaderboard edit | no board writes from Test |
| commands | AdminFramework.Commands.TestPlace (scripts/admin/Commands/TestPlace.lua) | lobby `;testplace`; Test `;maplist`, `;testmatch` |
| lobby | fix/test_lobby_install.lua | `LobbyConfig.TestPlaceId` + the command module |
The gate's level is `TP_LEVEL = "Admin"` at the top of the block.

## Tests (2026-10-28, out/test_place/Test_place.rbxl, Studio Play)
- Install: split Test, then test_place_install (13 edits + module + StagingMaps); UNDO back to the exact before-hash; reinstall;
  second run all "already in" (same hash).
- One client (Studio Owner): admitted, waiting area. Matches, each to the results and back to Waiting: Warehouse 2 **staged**
  (`[STAGING]` in `;maplist`, placed on first use) 1v1 vs bot; Arena 2v2 (me + bot vs 2 bots); Warehouse 3v3 (mode warning shown);
  Arena 1v1. Client results: `TestMatch true, TestPlace true, XP 0, Scissors 0, GunXP 0, Saved false`. Profile before = after every
  match (XP 0, Wins 0, Kills 0, MatchesPlayed 0, WinStreak 0, MatchHistory 0); `TestPlaceHook "view"`: viewOnly / viewMode true,
  active false. No map vote (Intro -> Loadout).
- Refusals: unknown map, 4v4, `admins` alone, a second `;testmatch` while one runs; `;endmatch` -> waiting area, nobody paid.
- Gate: `;simlevel none me` -> within the recheck: body removed, "ADMINS ONLY" notice, back-to-lobby x2 (Studio logs it), kicked
  "This test server is for admins only." (console in out/test_place/console_gate.txt).
- Two players (Studio server + 2 clients), lobby entry: see notes/port_manifest.md "Live port 46".
