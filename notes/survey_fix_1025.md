# SURVEY1025: security + data fixes from the 2026-10-25 systems survey (for the lead, port 43)

Source: roblox_hq task 20261025065116hki (cross-place survey, FIX 6.5/10). Findings fixed here: **1, 6, 7, 8** (security) and
**2, 3, 9, 10, 12, 13** (data). Left alone on purpose: 4, 5, 11, 14-21. Nothing saved into any repo place, nothing published.

## Files
| File | What |
|---|---|
| `fix/survey1025_security.lua` | findings 1, 6, 8, 7 |
| `fix/survey1025_data.lua` | findings 2 (+2b hooks), 9, 10, 3, 13, 12; installs `ServerScriptService.Shared.LeaveRule` |
| `fix/survey1025_tests.lua` | unit tests (leave rule, every case) + a check that each fix is in the place: `python tools/ranked_test.py --survey1025 <studio_id>` |

Both installers: run in **every** place (lobby, Tutorial, Matchmaking, Ranked), Edit mode, `python tools/run_luau_at.py <id> <file> [UNDO]`.
They detect the place themselves (lobby = `Workspace.LobbyMap` and no `ReplicatedStorage.PlaceKind`; match place = `PlaceKind`) and skip
edits that don't belong there ("n/a"). Every edit is checked before anything is written (assert = nothing changed). Second run: all
`=`. An edit the place already has its own way counts as applied (`= (own)`, e.g. the lobby's SelectWeapon check). The script attribute
`Survey1025Edits` lists the edits this installer wrote; **UNDO reverts only those** (so UNDO never touches the lobby's own code).
Backups: `ServerStorage._RebuildRemoved.SURVEY1025_<name>_Orig`. AssetCheck goes to `ServerStorage._Survey1025Disabled`.

## Run order (port 43)
- **Matchmaking / Ranked / Tutorial:** split_build -> deploy_ui -> `play_again_queue.lua` -> `switch_now.lua` -> **`survey1025_security.lua`
  -> `survey1025_data.lua`** -> `ranked_test.py --survey1025 <id>` (28 passed, 0 failed) -> save.
- **Lobby:** `switch_now.lua` -> **`survey1025_security.lua` -> `survey1025_data.lua`** -> `ranked_test.py --survey1025 <id>` (30 passed) -> save.
- Suggested `port_prep.sh` lines after the SWITCHNOW one (not added: port_prep is yours):
  `python tools/run_luau_at.py "$ID" fix/survey1025_security.lua` and `... fix/survey1025_data.lua`.

**Heads-up, PLAYQUEUE (not mine, found while testing):** a place saved with PLAYQUEUE **round 1** (the port-42 Matchmaking / Ranked
files) refuses round 2 and round 3: `RoundManager edit 3 anchor not found` (the ToHub edit's text changed), *after* it already rewrote the
MatchmakingManager module. Undo round 1 with the old installer first, then install the new one (vault lesson "UNDO with the OLD installer"):
`git show 8e951ba:fix/play_again_queue.lua > out/pq_r1.lua; python tools/run_luau_at.py <id> out/pq_r1.lua UNDO`, then `fix/play_again_queue.lua`.
Checked on a copy of port-42 Matchmaking at 03:20: round 1 UNDO -> round 3 `1+ .. 10+` -> SWITCHNOW -> SURVEY1025 all `+`.

## What each fix changes
| # | Places | Script | Change |
|---|---|---|---|
| 1 | lobby | MatchmakingManager `FindMatch` | refuses a caller with `InMatch` / `DuelMatch` / `InDuel`: "You're in a match right now!" (it only checked the party, so a solo pad duelist could search online mid-duel and be teleported out). The match places' copy is untouched: PLAYQUEUE took FindMatch off the Request remote there and Play Again calls it during the results, when InMatch is still set on purpose. |
| 6 | all (lobby: own) | CombatManager `SelectWeapon` | `PlayerStore.Owns` check, as the lobby has had since pass 37. |
| 8 | all | LobbyManager `ProcessReceipt` | grant -> receipt -> **wait until a save holding it has landed** (ProfileService `MetaTagsLatest.ReceiptSeq`, retries `Save()` every 6 s, 20 s cap) -> `PurchaseGranted`; otherwise `NotProcessedYet` and Roblox asks again (the Receipts entry turns the retry into a save check, never a second grant). A profile released for a teleport -> `NotProcessedYet` (the next server grants). Studio-only `ServerStorage.ReceiptTestHook:Invoke(userId, purchaseId, productKey)` drives a fake receipt through the real handler. |
| 7 | lobby | AssetCheckServer + StarterPlayerScripts.AssetCheck | parked in `ServerStorage._Survey1025Disabled` (UNDO restores). |
| 2 | match | DataManager | now the lobby's file byte for byte (class-token cache, AutoLevel, DataManagerOwner guard). After both installers the DataManager hash is the same in every place (d5247dcf). |
| 2b | all | DataManager | `dataManager.OnBeforeRelease(fn(player, profile))`: hooks run in PlayerRemoving while the profile is active, before the replica goes; skipped on shutdown (`dataManager.Closing`, set in BindToClose) and for a profile released for a teleport. The profile is now released even if its replica never got built (it used to stay locked until the server closed). |
| 9 | all | RankedServer `MarkPending` | a pending mark from another JobId is charged (`ApplyLeave`, "disconnect") before the new mark is written. |
| 10 | match | RoundManager `award` | every reward write through `PlayerStore.Set / Increment` (raw only with no replica), so the after-match screens show the new scissors / XP / streak at once. Same numbers as before. |
| 3 | match RoundManager, lobby LobbyDuelManager | + `Shared.LeaveRule` | a leave **once round 1 has started** = loss: `WinStreak 0`, `Stats.MatchesPlayed +1`. The Leave button writes it at once (before `backToLobby` releases); a disconnect through the DataManager before-release hook. Free: before round 1 (loading / vote / loadout), a decided match the leaver won or drew (Victory beat), the results, an admin end, a Studio bot match, a shutdown. Charged once (Leave then disconnect = one loss). Applies to ranked too (the streak is the same field; ranked's ELO leave is unchanged and separate). Studio switch: `ReplicatedStorage.StudioLeaveTest = true` makes bot matches count. |
| 3 (round 2) | match, lobby | RoundManager, LobbyDuelManager | (systems grader round 1) a Leave is **settled** the moment it is judged (`m.leaveSettled`), free or not, so a later disconnect never re-judges it once the match has reached round 1 (was: a 2v2 player who left during loadout and then quit the game was charged). The lobby's disconnect hook only looks at the player's **current** duel (`DuelMatch`; `returnToLobby` clears it on Leave / never-loaded / forfeit), never an older duel still running. `_TestForfeit` (admin `;endmatch`) sets `match.aborted`: an admin end is not a leave. |
| 13 | all | LobbyLeaderboard | OrderedDataStores `Studio_TopWins_v1` etc. in Studio. |
| 12 | all | DataManager.Template | `TutorialDone = false`, `Wraps = { Owned, Equipped, Favorites }`, `DuelPairs = {}`. ProfileVersion stays 1 (adding defaults needs no migration; Reconcile fills them in). |

## Tests (2026-10-25, main PC, my own copies in `out/survey_fix_1025/`, one Studio of mine at a time, never a repo place)
Copies: lobby from the survey's verified port-42 copy (md5 dbcacfff = `Tacticals_main_ported.rbxl`; the live file had a newer .lock),
Matchmaking / Tutorial from the port-42 files.
- **Offline:** every anchor applied to the survey dumps of all four places: each found exactly once, second pass all applied, match
  DataManager == lobby DataManager.
- **Installers** in lobby, Matchmaking, Tutorial: install `+`, re-run all `=`, UNDO -> state hash back to the before-hash
  (lobby 55f11dea, Matchmaking 64e830d3, Tutorial fe60d53f), reinstall. Also on top of PLAYQUEUE round 3 + SWITCHNOW round 2 (24d6d57).
- **Unit:** `ranked_test.py --survey1025`: match 28/28, lobby 30/30 (after round 2).
- **Round 2 (after the grader's FIX):** fresh lobby copy with SWITCHNOW: install / re-run / UNDO -> before-hash 946dd9f1 / reinstall.
  Play 2v2 (me + bot vs 2 bots): Leave during Loading (free, streak 9 kept), the duel runs on into round 1, then the before-release hooks
  -> nothing charged. 1v1: `_OnRemoving` first, then the hooks twice in round 1 -> one `(disconnect)` loss. Fresh Ranked copy: round-1
  UNDO -> PLAYQUEUE r3 -> SWITCHNOW -> mine (re-run `=`, UNDO, reinstall), 28/28; Play ranked leave in round 1 -> `[Ranked] LEAVE` and
  the loss (streak 6 -> 0, played +1). Consoles clean (`out/survey_fix_1025/*_console.txt`).
- Smaller grader items done: SelectWeapon fails closed if PlayerStore can't load (match places; the lobby keeps its own pass-37 line);
  `receiptSaved` also needs the profile still active; UNDO stops with an error instead of forgetting an edit whose text changed.
- **Play, Matchmaking** (solo + test bot, `StudioLeaveTest`): Leave in round 1 -> streak 5 -> 0, played 0 -> 1, one `[LeaveRule] ... (leave)`;
  then a disconnect of the same player -> no second charge, profile `IsActive` false and replica gone after leave. Fresh match, replica
  destroyed, disconnect mid-round -> `[LeaveRule] ... (disconnect)` written raw. Ranked mark from "OTHER-SERVER" -> charged once (ELO
  1000 -> 944, losses +1), a same-server re-mark -> no change. Fake receipt "Credits500" -> `PurchaseGranted` after the save landed
  (0.11 s, mock store), credits +1000; same receipt again -> `PurchaseGranted`, no credits; profile released for a teleport ->
  `NotProcessedYet`, credits unchanged (then restored). Paying solo forfeit match (StudioSoloMatch) -> credits / streak / played / wins
  written and the HUD showed the new scissors at once. Console: no errors (only the pre-existing "Asset type does not match" preload lines).
- **Play, lobby** (solo pad duel vs a test bot via `DuelTestHook "solo"`): FindMatch before a duel -> "Online matchmaking is offline here"
  (normal, unpublished copy); **mid-duel -> refused "You're in a match right now!"** (also for R1v1). Leave in round 1 -> streak 4 -> 0,
  played +1. Leave during Loading -> nothing charged. `_OnRemoving` first, then the before-release hooks twice -> found in `matches`, charged
  once. Fake receipt "Credits1200" -> granted once, `MetaTagsLatest.ReceiptSeq` saved. Kick with the replica destroyed -> profile released.
  AssetCheck no longer runs. Console clean.
- **Not done, and why:**
  - Studio server + 2 players: `multiplayer.py start` opened only a Server window: the player-count box next to Play is 0, and changing it
    needs a click in Studio (not allowed while the lead works). In the match places Studio test players have ids <= 0, which RoundManager
    treats as bots anyway, so the match-place tests are solo with a bot and `StudioLeaveTest`. Every fix here is per player.
  - Rejoining the same match server (the token cache): Studio can't rejoin a player. The match DataManager is now byte-identical to the
    lobby's, which has run live with that code. Live two-account check after port 43: leave a match server and rejoin it -> no "token
    already created" error, scissors still shown.

## Open / notes
- Systems grader round 1: FIX 7.5 (major: lobby 2v2 free leave re-charged on disconnect; fixed in round 2 above).
- Systems grader round 2: **PASS 8.8** (lobby replayed in its own copy: 2v2 free leave, two duels at once, receipts, kick; installers re-run / UNDO exact).
  Open minors: `_TestForfeit` now also flags an admin end, so the Studio "forfeit" test hook announces "Ended by an admin" (rewards unchanged);
  better to set the flag in `;endmatch` itself later. Shutdown ordering: check one live server migration with a match running after port 43.
- A shutdown that kicks players before BindToClose runs could charge a mid-round player a loss (ordering of PlayerRemoving vs BindToClose
  at shutdown is not guaranteed). Rare; documented.
- Old Studio_ leaderboard data: none (the Studio boards start empty; the live boards are untouched).
- The repo's `scripts/` copies are not updated (finding 4; `scripts/` is the lead's). After port 43, pull the live sources back.
