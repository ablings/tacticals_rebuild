# Systems plan: admin-only Test place [TESTPLACE] (work order "Build and publish an admin-only TEST place", 2026-10-28)

Full notes: notes/test_place.md. Places: a new place "Test" (copy of match_place_ref + split kind Test + fix/test_place_install.lua)
and the lobby (fix/test_lobby_install.lua). Matchmaking / Ranked / Tutorial unchanged (their code paths are no-ops without kind Test).

## Modules
| Module | Change |
|---|---|
| RS.Modules.Shared.PlaceKind | kind Test: casual only, no tutorial, IsTest() |
| RoundManager | Test runner (gate, waiting area, StartTest, staging maps, TestPlaceHook) + 7 small edits in runMatchServer / award / waiting deaths |
| DataManager | Test place: view-only profiles (ViewProfileAsync; template stub for a new player) |
| LobbyManager | ProcessReceipt NotProcessedYet on Test |
| LobbyLeaderboard | no board writes on Test |
| AdminFramework.Commands.TestPlace (new) | lobby ;testplace; Test ;maplist, ;testmatch |
| AdminFramework.Commands.Duel | ;endmatch text on Test |
| LobbyConfig (lobby) | TestPlaceId (0 = not set up) |

## Remotes
None added. Entry points are the admin framework's (chat ;command, AdminRemote "run", AdminBindable), which already check level
(Admin), rate (0.25 s) and arguments (typed choice args: map / mode / vs; server re-checks the map against the live list).
Gate: AdminFramework.Permissions.LevelOf on arrival and every 10 s; no framework = nobody admitted.

## Data
No schema change. Test place: nothing written (view-only copies). Lobby: DataStore `TestPlace_v1` key `SharedServer` = the shared
Test server's reserved access code (`Studio_` prefix in Studio; not player data, `-- datastore-ok`).

## Events / attributes for UI
ReplicatedStorage `TestPlace = true` on a Test server; Player `TestPlaceAdmin = true` once checked in; MatchResults gains
`TestPlace = true` (with `TestMatch = true`, XP / Scissors / GunXP 0, Saved false). MatchAnnounce("ADMINS ONLY", ...) for a refused player.

## Test hooks (Studio only)
ServerStorage.TestPlaceHook: info / start(userId, map, mode, vs) / set(key, value) (retry, recheck, notices) / maps / view(userId).
