# Match place on MatchCore: the RIVALS match flow, settings carry-over, admin (2026-10-16)

Edward's asks for the match place (place 81861384114744, "tutorial spot / matchmaking test"; PLAY's global queue teleports here):
(a) the full RIVALS flow: teleport screen (lobby side, done) -> map vote -> loadout pick -> rounds; (b) every lobby setting reflected
here; (c) the admin framework works here too. Working copy `match_place_ref.rbxl` (studio 331cb3a0); the download is kept untouched in
`backup/match_place_2026-10-16.rbxl`. **Not saved by this session** (the lead saves and ports). Studio left in Edit.
Design/contract: `notes/lobby_duels_design.md` §6; facts: `notes/lobby_duels_survey.md` §1.

## What changed

| Piece | Where (match place) | Notes |
|---|---|---|
| Round rules | `...Managers.RoundManager` **[MATCH] whole-source replacement** (`scripts/match/RoundManager.lua`; original in `ServerStorage._RebuildRemoved.MATCH_RoundManager_Orig`) | Rounds, win rules, trade-draw, timeout-by-health, forfeit, kill tally and the reward maths now come from the **shared `MatchCore`** (the lobby's file, byte-identical). RoundManager keeps only what is place-specific: server kind (match / tutorial / test), arrival + kicks, spawns (`MatchSpawns`), profile writes, the teleport back. |
| Match flow | RoundManager + new `MatchCore.runPreMatch` | **Waiting** (arrival, up to `ArrivalTimeout` 30 s; `MatchPhase = "Loading"` so the UI shows its loading card) -> **Loading** (3 s) -> **MapVote** (10 s, `MapList` = registry maps of the match's mode that are placed in this place; the UI adds Random; ends 1.5 s after everyone voted) -> `MapChosen` -> **Loadout** (15 s, ends early when every present player sent Ready) -> rounds (Countdown / Live / RoundEnd, first to 3) -> **MatchEnd** (12 s results) -> back to the lobby (`TeleportAsync` to 126491009194165, 3 tries; Studio: a warning, counted for the tests). A team that never arrives: `Cancelled` + "MATCH CANCELLED" + back to the lobby (as before). |
| Map | `ReplicatedStorage.DuelMaps.Warehouse` (Folder `DisplayName`, `Image`, `Modes = "1v1"`) + `MapInfo` (copy of the lobby's generated one, `scripts/match/MapInfo_Warehouse.lua`) | **Decision: the map stays as it is, in Workspace, at its native position** (`Workspace.Warehouse` + `MatchSpawns`). This server has one match and no other players, so there is nothing to hide: no Visual/Solid split, no client clone, no ArenaLoader. ShootableManager, DoorManager, GadgetManager and CoverController keep reading `workspace.Warehouse` unchanged. A map is playable here when `workspace:FindFirstChild(MapInfo.WorkspaceName)` exists. **Fallback:** if no placed map has the match's mode (the Warehouse is 1v1 only, but PLAY 2v2 / 3v3 also land here) every placed map is offered and `ReplicatedStorage.MapFallback = true` (warning in the log), so 2v2 / 3v3 keep playing on the Warehouse as before. Edward: confirm, or give 2v2 / 3v3 their own maps. |
| Shared modules | `ReplicatedStorage.Modules.Shared.MatchState` / `MapRegistry`, `ServerScriptService.Shared.MatchCore`, `Modules.Shared.Config.MatchConfig` (**[MATCH] replaced** by the lobby's superset: same values + the duel keys; original `MATCH_MatchConfig_Orig`) | Identical to the lobby's (same `scripts/duels/*` source). `MatchState.For(player)` returns ReplicatedStorage here, so the UI's MatchFlowUI / DuelHUD read the same names in both places. The combat managers keep reading ReplicatedStorage directly (identical behaviour here; no edits). |
| Item catalogue | `Modules.Shared.Config.LobbyConfig` (new, **subset port**, `scripts/match/LobbyConfig.lua`) | Items / Slots / DefaultLoadout / Rarities / Images, QuestStats / Quests, level curves + `AccountLevel` / `ItemLevel` / `XPForLevel`, `StartingRating`, place ids. Copied verbatim from the lobby's LobbyConfig: **keep in sync** when an item or the curve changes. Shop / bundles / Robux / queues stay lobby-only. MatchFlowUI's slot filter and the admin item / mission commands use it. |
| OwnedItems + Kit | RoundManager `setupMember` | At arrival: `Team`, `Level` (`AccountLevel(XP)`), `OwnedItems` (JSON: every Default item + profile `Owned[id] == true`), `LoadoutReady = false`, `Alive`. Starting kit: the profile's `Loadout`, else TeleportData `Loadouts[userId]`, **each slot validated** against ownership + slot, else the slot default -> `KitWeapon / KitMelee / KitGadget` + the gameplay mirror `Loadout = KitWeapon` (`MatchCore.applyKit`). The arriving player also gets a body parked frozen at the team spawn (CharacterAutoLoads is off; without a character the client's PlayerGui.HUD never appears and the old HUD scripts warn "infinite yield"). |
| MatchFlow | `ReplicatedStorage.MatchFlow` (RemoteEvent, made by RoundManager) | Client -> server: `("Vote", mapId)` (MapVote only; a map of MapList or "Random"; changeable), `("Pick", slot, itemId)` (Loadout only; slot Weapon / Melee / Gadget; `MatchCore.validPick` = catalogue item of that slot that is Default or owned in the **live profile**), `("Ready")` (Loadout; `LoadoutReady = true`), `("Leave")` (before the results: a forfeit for the leaver's side + their teleport back; after: just the teleport). **No matchId** (a leading matchId is tolerated and ignored). Server -> client: `FireClient(player, nil, "Kill", {killer, victim, weapon, headshot, kind})` to every player. |
| Kept payloads | | `Events.Match.MatchAnnounce(title, subtitle)` (same lines: MATCH FOUND, ROUND n, FIGHT, TEAM x WINS THE ROUND, DRAW, OPPONENTS LEFT, TEAM x WINS THE MATCH, MATCH CANCELLED; new: MATCH ENDED for an admin end). `Events.Match.MatchResults(summary)`: the pass 38 fields + `MeleeKills`, `Forfeit`, and `TestMatch` / `Aborted` when nothing was paid. Every old ReplicatedStorage / player attribute is still written (MatchState values Waiting / Countdown / Live / RoundEnd / MatchEnd / Tutorial unchanged; new values Loading / MapVote / Loadout / Cancelled). Rewards are written to the raw profile exactly as pass 38 did (Stats, XP, Credits, ItemXP, Ranked Elo); a match with a Studio test bot or ended by an admin pays nothing. |
| Doors | RoundManager `onRoundStart` | `DoorManager.CloseAll()` is now called each round (pass 38 never did), with `ShootableManager.ResetAll()` and `GadgetManager.ClearAll` (if present). |
| Tutorial / range | unchanged code paths | The server kind is decided exactly as before: TeleportData `Tutorial` (or Studio `StudioTutorialServer`) -> tutorial server (MatchState `Tutorial`, we spawn the player, TutorialManager auto-starts); a public server / Studio without data -> test server (Waiting + free practice, TestMode -> FiringRange + [K] kit, the first two players duel 1v1 with rematches, now on MatchCore); match TeleportData -> the new flow. TutorialManager / BotManager / RangeManager were not edited. |
| Admin framework | `ServerScriptService.AdminFramework` (+ `Commands`), `AdminCommands` (Script), `StarterPlayerScripts.AdminFeedback` | Same `scripts/admin/*` files as the lobby (no lobby [ADMIN] edits). New shared bits: `Core.Place` ("lobby" when `Workspace.LobbyMap` exists, else "match") and a command field `place`: `duelsolo`, `arenas`, `pads` are lobby-only (not registered here). `listmatches` / `endmatch` map to `RoundManager.MatchInfo()` / `EndMatch()` here (endmatch: both sides leave, "MATCH ENDED", no rewards, everyone back to the lobby). `tp` knows `spawna` / `spawnb`. `serverinfo` shows the match. The item commands (`give`, `take`, `giveall`) and `missions complete` work here now that the LobbyConfig port exists. |
| UI scripts | installed by the UI session (`python ui/deploy_ui.py <id> --match`), not by this install | MatchFlowUI, DuelHUD, the [SET] controllers, TrainingGate shim, Binds, SettingsConfig, UIKit, SettingsEffects, CombatFeedback, SettingsBridge. This session only checked they run against the server (tests). |
| Studio test switches | ReplicatedStorage attributes (Studio only, never read live) | `StudioTeleportData` = JSON TeleportData, e.g. `{"Mode":"1v1","Teams":{"A":["me"],"B":["bot"]},"StudioTimes":{"MapVoteTime":60}}` ("me" = the first player, "bot" / id <= 0 = an R15 test bot that never pays; `StudioTimes` overrides MatchConfig times). `StudioSoloMatch` and `StudioTutorialServer` as before. `ServerStorage.MatchTestHook:Invoke("info" / "phases" / "returns" / "kill", victimId, killerId, headshot / "profile", userId, patch / "config", key, value)` runs in the game's VM. **The attribute was cleared after the tests.** |

Install: `python tools/match_place_build.py --run` (embeds `scripts/duels/{MapRegistry,MatchState,MatchCore,MatchConfig}`, `scripts/match/*`,
`scripts/admin/*` into `fix/match_place_install.lua` and runs it in 331cb3a0). UNDO: `python tools/match_place_build.py --run UNDO`.
Everything the install makes carries attribute `MatchInstall = true`; UNDO restores the two `MATCH_*_Orig` backups and removes exactly those.
**UNDO tested:** install -> UNDO (RoundManager / MatchConfig back to the original hashes, 0 MatchInstall objects, backups gone) ->
reinstall (the same hashes as the first install, 24 objects) -> a second run changes nothing.

Shared module changes (both places): `MatchCore` got `ownedItems`, `ownedKit`, `mapList`, `castVote`, `waitPhase`, `runPreMatch` and
`ctx.aborted` (admin end: "MATCH ENDED" instead of "OPPONENTS LEFT"); the lobby's LobbyDuelManager doesn't call the new helpers yet
(it has its own copy of the phase steps with the arena loading in between). Admin: Core.Place / `place`, Duel / Debug / Data / Player / World
as above. **Re-run in the lobby (8ef4e21a):** `tools/lobby_duels_build.py --run` (MatchCore, LobbyDuelManager rewritten), then
`tools/admin_build.py --run` (its [ADMIN] LobbyDuelManager edit re-applied).

## Settings carry-over (b)

How the lobby stores settings: in the shared ProfileService profile (`"gameStore"`, `"studioStore"` in Studio), key **`Settings`**
(`{ Active = n, Profiles = { [n] = { <Tab> = { <Row> = value } } } }`, read with `SettingsConfig.ActiveProfile`). The match place's
DataManager loads the same profile (its empty Template never removes keys), so the data is already here at join.
The plumbing is the UI session's `ServerScriptService.SettingsBridge` (deployed with `ui/deploy_ui.py <id> --match`, it replaces the pass 43
bridge, which only set `Setting_GunHand` and `Bind_FreeCursor`): on join it waits up to 15 s for `DataManager:Get(player)` and sets, for
every row of `SettingsConfig.Rows`, **`Setting_<Row>`** (non-bind rows; the row key with non-alphanumerics stripped) or **`Bind_<Row>`**
(bind rows: the first key, nil when unbound), plus **`AimSensitivity`** = `Video.Sensitivity / 100`. These are the same attributes the lobby
sets. Nothing in RoundManager duplicates it. Verification: see the tests.

Gaps found: the bridge applies once at join (fine: the match place has no settings screen); with no profile after 15 s every row gets its
default; Studio's profile is the empty template (no `Settings`), so a real carry-over can only be seen with a seeded profile (test below).

## Tests (Play in 331cb3a0, one client "ocxa" + a server test bot; captures `out/match/` (git-ignored), sheet `notes/match_place_flow_sheet.png`)
TeleportData simulated with `StudioTeleportData = {"Mode":"1v1","Teams":{"A":["me"],"B":["bot"]}}` (+ `StudioTimes` for slow runs), so the
real `joinMatchData` -> `runMatchServer` path ran. Client calls were real `MatchFlow:FireServer` from the client VM; kills through
`MatchTestHook "kill"` (sets the same Humanoid attributes the combat managers set; the bot never shoots).
- **Phases advance** (server phase log, run 4): `1.0 Waiting(Loading) | 4.1 MapVote | 20.6 Loadout | 34.6 Countdown | 38.1 Live | 52.9 RoundEnd |
  56.0 Countdown | ... | 77.5 MatchEnd/Ended`. MapVote ended 1.5 s after the only voter voted; Loadout ended at once on Ready (Ready ->
  `LoadoutReady = true`, state Countdown 0.5 s later). With the default times (run 1) nobody voted / readied: 10 s / 15 s timeouts, Random resolved to Warehouse.
- **Vote**: `Vote "Bogus"` ignored (`MapVotes = {}`), `Vote "Random"` -> `{"Random":[281164661]}`, re-vote `Warehouse` -> `{"Warehouse":[...]}`
  (changeable); `MapChosen = Warehouse`; `MapList = [{"id":"Warehouse","name":"Warehouse","image":""}]` (02, 02b).
- **Pick**: join kit `Pistol / Fists / Smoke` (empty Studio profile -> defaults), `OwnedItems = ["Fists","Pistol","Smoke"]`, `Level` set.
  Refused: `Weapon Sniper` (not owned), `Melee Pistol` (wrong slot), `Gadget Flash` / `Frag` (not owned) - attributes unchanged, server logs
  "pick refused". After `;give me sniper` / `;give me knife` / `;give me revolver`: `Melee Knife`, `Weapon Sniper` (and in run 4 `Revolver`)
  accepted -> `KitWeapon` + `Loadout` mirror updated (03, 04); round 1 spawned with **Sniper + Knife** tools, MaxHealth 150 at `MatchSpawns.SpawnA`.
- **Rounds / results**: bot kill (headshot) -> TEAM A WINS THE ROUND 1-0; player killed by the bot -> 1-1; two more -> 3-1 MatchEnd.
  Client received, in order: ROUND n / FIGHT / TEAM x WINS THE ROUND ... TEAM A WINS THE MATCH, 4x `MatchFlow (nil, "Kill", {killer, victim,
  weapon, headshot, kind})`, and `MatchResults {Won, Score 3-1, Kills 3, Headshots 2, Deaths 1, TestMatch, XP/Scissors/GunXP 0, Saved false, ...}`.
  Player attrs at the end: `MatchKills 3, MatchDeaths 1, RoundWins 3`. DuelHUD score bar, kill feed and VICTORY card drew from it (05, 06, 08).
- **Return**: after `ResultsTime` the teleport back was attempted once ("back to the lobby: in a live game 1 player(s) now teleport to
  126491009194165 (skipped in Studio)", `MatchTestHook "returns"` = 1).
- **Leave**: `MatchFlow "Leave"` during Live -> the player's side forfeits at once (MatchEnd, OPPONENTS LEFT), their return attempted at once,
  then the end-of-match return (2 attempts).
- **Admin** (`AdminBindable "run"`, the chat path's Core.Run): `;listmatches` -> "match 1v1 Live round 1 0-0 map Warehouse [A:ocxa
  B:TestBot(bot)]"; `;serverinfo` shows the match; `;cmds` lists Data / Debug / Duel (endmatch, listmatches) / Legacy / Player / World
  (announce) - `;pads` and `;duelsolo` are "unknown command" here; `;give`, `;setlevel me 20` (Level attr 20), `;tp me spawnb` work;
  `;endmatch` during Live -> "MATCH ENDED / Ended by an admin - no rewards", MatchEnd, return attempted; a second `;endmatch` -> "no match is running".
- **Settings at join**: the UI session's SettingsBridge (deployed by `deploy_ui.py --match`) sets **54** attributes at join (`Setting_*`,
  `Bind_*`) + `AimSensitivity` from the Studio profile (defaults: no saved Settings). With a seeded test profile
  (`MatchTestHook "profile"` patching `Settings = {Active = 1, Profiles = {{Game = {Gun Hand = Left, Gameplay HUD = Minimal, Damage
  Numbers = false, ...}, Video = {Sensitivity = 150, Damage Flashing = Outline}, Hotkeys = {Reload = {"T"}, ...}}}}` and the deployed bridge
  run again for the player) -> `Setting_GunHand Left`, `Setting_GameplayHUD Minimal`, `Setting_DamageFlashing Outline`, `Bind_Reload T`,
  `AimSensitivity 1.5`. **But `Setting_DamageNumbers` stayed `true`**: see the gap below.
- **Tutorial**: `StudioTutorialServer = true` -> MatchState `Tutorial`, CombatEnabled, the player spawned, `InTutorial = true`, the
  tutorial ran (07). **Test server** (no switches): `Waiting` + free practice, TestMode + InfiniteAmmo, FiringRange with 7 dummies.
- **Install / UNDO**: see above (hash-exact).
- **Console** (server + client, run 4): no errors from the new code. Left: KitGuard's round-spawn lines (pre-existing), ~200
  "ContentId ... Asset type does not match requested type" lines from client asset loads (not from server code), the MCP's own proxy line.
  The "infinite yield PlayerGui.HUD" spam seen in run 1 is gone since arriving players get a parked body.
- **Lobby regression** (8ef4e21a, after re-running both lobby installers): a bot-vs-bot pad duel D1 ran 3-0 to MatchEnd and freed its slot;
  admin there still has duelsolo / arenas / pads (Core.Place = lobby); no errors.
- Test setup undone: `StudioTeleportData` cleared; `TutorialConfig.AutoStartInStudio` was set false for the capture run only (in Studio the
  starter tutorial auto-starts in every server kind, pre-existing) and restored to `true` (source length back to 11646).

### Gaps found (for the UI session, via the lead)
- **`SettingsConfig.clean` drops every toggle saved as OFF**: `return type(v) == "boolean" and v or nil` turns `false` into nil, so the
  default (true) wins. Affects the lobby too (same module): any toggle a player turned off comes back on at the next load. Fix:
  `if type(v) == "boolean" then return v end return nil`.
- The old `Client.GUIs.MatchHUD` / `MatchResults` still run beside DuelHUD: doubled announce text (06), a second small timer above the
  DuelHUD one (05) and a ghost "VICTORY" behind the results card (08). The results card says "Couldn't reach your save" for a test-bot
  match (`TestMatch = true`, `Saved = false`).
- The camera starts inside the wall at SpawnA (left third black in 05 / 06), like the lobby arena before UI request 8.

## Left / for the lead
- Save `match_place_ref.rbxl` (and port), then save the lobby copy: the lobby got the new MatchCore / LobbyDuelManager / admin modules.
- `Image` for the Warehouse is still "" (map art not uploaded); set it on the `DuelMaps.Warehouse` folder (both places) when Edward OKs it.
- 2v2 / 3v3 PLAY matches use the fallback (every placed map); Edward to decide.
- LobbyConfig here is a copy: keep it in sync with the lobby's items and level curve.
- Not tested: two real players (the test server rematch loop with 2 clients, friendly fire, a real disconnect mid-round, the real
  reward write: Studio's profile is not saved), a live teleport back (Studio skips it; the call is the unchanged pass 38 one).
- KitGuard logs "Pistol left their kit while alive" at each round spawn (the round's LoadCharacter replaces a living body): pre-existing
  with the old RoundManager too; harmless.
- The old client `MatchHUD` shows no status text for the new states (it only knows the old ones); the UI session's DuelHUD / MatchFlowUI
  cover them.

## Follow-up 2026-10-16 (Edward): fair loading, short intro, spawn camera

### Loading gate + Intro (match place only; the lobby duel path is unchanged)
- **Loading** now covers arrival and assets: every client's quick intro sends `MatchFlow:FireServer("Loaded")` (no matchId) once its
  assets are in; the server records it in any phase. Loading lasts until every expected real player of TeamA / TeamB has sent it, or
  arrived and then left; Studio test bots count as loaded. `ReplicatedStorage.LoadedCount / LoadedTotal` update live (5 Hz; a player who
  arrived and left drops out of the total). TeamA / TeamB are published from the TeleportData lists at the start, and each arriving
  player gets `Team` and a body parked frozen at the team spawn, so the UI's WAITING FOR OPPONENT has both sides.
- **Choice on the safety net:** `MatchConfig.MatchLoadTimeout = 60` s, then the match starts with whoever is present. If a whole team
  never arrived it is cancelled instead (`MatchState = "Cancelled"`, "MATCH CANCELLED", no match, no rewards, everyone teleported back) -
  checked at `ArrivalTimeout` (30 s; nothing can start without a team) and at the 60 s timeout. This replaces the old separate 30 s
  "Waiting" arrival phase (Waiting is still the test server's free-practice state).
- Then **Intro** (`MatchState / MatchPhase = "Intro"`, `PhaseEndsAt = now + MatchConfig.IntroTime` 2.5 s; MatchFlowUI crumbles the logo
  when the phase leaves Loading), then **MapVote with its full 10 s**. Shared MatchCore: `runPreMatch` got `opts.skipLoading` and
  `opts.introTime` (the lobby doesn't pass them); MatchConfig got `MatchLoadTimeout`, `IntroTime`.
- Tests (Play, 331cb3a0, StudioTeleportData):
  - normal (me + bot): `0.6 Loading | 4.4 Intro | 7.0 MapVote | 18.6 Loadout`: Loading ended when the client's quick intro sent Loaded
    (`LoadedCount/Total` 2/2), Intro 2.6 s, MapVote 10 s + the 1.5 s winner flash (09);
  - a teammate who never comes (`A = [me, 99999]`, `MatchLoadTimeout` 12 for the test): `1.2 Loading | 13.3 Intro | ...`, `LoadedCount
    2/3` until the timeout, then the match ran with the players present;
  - a team that never comes (`B = [99998]`, `ArrivalTimeout` 6): `1.1 Loading | 7.3 Cancelled/Ended`, teleport back attempted, no match.

### Spawn camera (both places)
- **Cause** (reproduced in Play: round 3 after dying in round 2, camera exactly at the reported (-50.75, 5.47, -34.5)): the client
  CameraController takes its starting yaw from the new body's first frame (`bindCharacter`: `yaw = atan2(-look.X, -look.Z)`). The new body
  was first seen at the default spawn (CFrame facing -Z) and pivoted to SpawnA only after `Ready`, so the camera started looking
  **backwards** (yaw 0 = -Z) while the character faced B: the view showed the wall behind SpawnA and, 2 studs to the left, the pillar
  P01's unlit (near-black) east face (10). Nothing was clipping there: `COLP_P01` matches the visual pillar exactly (5 x 10 x 5,
  0.02 apart) and the exact-triangle check below found no cut at slot 1.
- **Fix:** match place `RoundManager.spawnPlayer` pivots the new body to its spawn inside CharacterAdded, before any yield, and again
  right after `LoadCharacter` (then once more after Ready, as before). Lobby `LobbyDuelManager.onCharacterAdded` puts a duelist's new body
  in the Hold **facing its team's round spawn** (`facingHold`) instead of a bare `CFrame.new(position)`. After: round 3 camera behind the
  player looking along the spawn's facing (11); lobby duel, round after a death: camera look (-0.53, 0, 0.85) = SpawnA's facing.
- **Real visual-wall gaps (all spawns checked):** `tools/camskin_gen.lua` reads the Warehouse visual meshes' real triangles
  (`EditableMesh:RaycastLocal`; the meshes' collision hulls are far too coarse for this) and compares them with what the camera probe
  stops on. The visual walls stand 0.15-1.6 studs proud of `COLP_Wall_*` (east / west long walls 0.7, a few wall features 1.6, north /
  south 0.15-0.8); the probe stops 0.45 before a collision wall, so the camera could end up behind the drawn wall. A sweep of every
  spawn (A/B x team slots 1-3 x 24 yaws x both shoulders, hip distance 8, 0.12 near plane) found **28 / 288** such poses (all at the 2v2 /
  3v3 teammate slots by the long walls; slot 1 = 1v1 had none). **Fix:** 36 invisible skin Parts flush with the visual faces
  (CanCollide / CanQuery / CanTouch, cloned from COLP_Wall_W: Transparency 1, no shadow) in the map's own folder `Warehouse.CamSkin`
  (not CollisionProxies, so smoke / blast rays and bot cover spots are unchanged), data `fix/data/warehouse_camskin.json`, applied by
  `fix/warehouse_camskin.lua` (`python tools/camskin_build.py <studio_id> [UNDO]`): match place `Workspace.Warehouse.CamSkin`; lobby
  `ServerStorage._DuelSource.Warehouse.Warehouse.CamSkin` + `fix/duel_split_map.lua` re-run (Solid 109 -> 145 parts; the Visual layer
  also carries the 36 as invisible non-colliding parts). After: **0 / 288**. Skins touching a valve / extinguisher stay behind their
  front faces (valve fronts 0.5 proud of the skin), so the valves can still be shot.
- Lobby re-run: `lobby_duels_build.py --run` (MatchCore, LobbyDuelManager, MatchConfig) then `admin_build.py --run`; a solo pad duel
  (`;duelsolo on`, `;tp me 1v1a`) played to 3-1 MatchEnd and returned (state object gone, DuelMatch cleared); no errors.
- Test setup undone in 331cb3a0 (StudioTeleportData cleared, TutorialConfig.AutoStartInStudio back to true, length 11646).
