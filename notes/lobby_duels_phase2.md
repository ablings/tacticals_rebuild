# Lobby duels: phase 2 build (2026-10-16)

Phase 1: `notes/lobby_duels_phase1.md`. Design + §0 changes: `notes/lobby_duels_design.md`. UI asks: `notes/lobby_duels_ui_requests.md`.
Studio 8ef4e21a only (331cb3a0 read for the match place's ShootableManager / DoorManager source, nothing written). Not saved; Studio left in Edit.
Captures `out/duels/phase2/` (git-ignored), sheet `notes/lobby_duels_phase2_sheet.png`.

## What changed

| Goal | Done | Where |
|---|---|---|
| 1. Arena interactivity | Doors, fire barrels, steam valves, burning ground and burning players **per arena**. Server state lives on the arena's Solid models (they replicate; only that match's clients have the Visual twin): door `DoorOpen / DoorMoving / DoorAt / DoorHeight`, barrel `Exploded / FireAt / FireRadius / FireUntil`, valve `SteamUntil` (SteamMask reads it on server and client, so footstep / reload masking works in arenas). The server tweens the Solid shutter (collision) and owns damage / burn / chain reactions; ArenaLoader on the match's clients tweens the Visual shutter from the same attributes, turns the Led amber / green / red, hides the Visual barrel, draws the fire patch, plays the steam jet + hiss. Door prompt = an invisible `PanelPrompt` part placed where the Visual layer has the door's `Panel` (F, 0.25 s hold, 8 studs; only live members of that match can use it). Everything resets each round (`onRoundStart`). Found by convention (Interactive.<Door>.Shutter, Shootables.<Model> with `Shootable` attr), no map names. | new `ServerScriptService.Shared.ArenaShootables`; `LobbyDuelManager` (loadSolid, OnShot / Explode / RayFilter / FXFolder / MatchAt); `ArenaLoader` (bindDoor / bindBarrel / bindValve) |
| 2. Gadgets use the arena | `GadgetManager.mapRay` (smoke flood + flash / frag wall checks) raycasts the arena's Solid layer (`MapInfo.RayFolders`, default `CollisionProxies`, else the whole Solid). Grenades, smoke cells and flash pops go into `DuelArenas.<id>.FX`; `GadgetManager.ClearIn(folder)` clears one arena per round and at match end. Frag grenades now explode in arenas (the lobby stub had no `Explode`, so frags did nothing in the lobby); outside an arena they still do nothing. Charges are spent in real matches (`LiveMatch` on the match state) even with `GadgetConfig.InfiniteCharges` (Training keeps infinite). | [DUEL] edits 29-39 (GadgetManager), 40-41 (ShootableManager stub) |
| 3. Effects scoped to the match | Every combat FX `FireAllClients` that can fire in a duel now goes through `MatchState.FireScoped(remote, anchor, ...)`: the anchor (player / character / bot / position / match id) gives the match, and only players whose `DuelMatch` or `DuelSpectate` is that match get it; lobby / Training events go only to players in no duel. Scoped: `WeaponFired` (3 sites incl. `BotFire`), `MeleeHit`, `FlashDetonated`, `Explosion` (ArenaShootables). In the match place (no `LobbyDuels` folder) it is plain FireAllClients. Not combat, left global: `QueueState` snapshot, `LobbyRemotes.NotifyEvent`, `NotificationHandler`, `TrainingTargets` pop (Training only). Server-made effect instances (smoke cells, grenades, burn FX on bodies) still replicate as instances, but sit in the arena's FX folder or on duelists 4,000+ studs away (sounds roll off by 30-200 studs); burning ground, door motion and steam are client-drawn. | [DUEL] edits 25-28, 37; `MatchState.ScopeOf / Audience / FireScoped` |
| 4. Concurrency, 6 slots, ARENAS FULL | Two matches at once (player D1 + bot-vs-bot D2), six at once, a seventh refused, a pad holding in ARENAS FULL and starting 1.8 s after a slot freed. The QueueState rows carry `duelWait`; PadBoards / PadUI (UI session) show it. | unchanged allocator; Studio `DuelTestHook` |
| 5. Respawn flash | Every new character of a duelist is pivoted into the slot's Hold inside `CharacterAdded` before any yield (round spawns too: they used to sit at the lobby spawn until `Ready`), and a dead duelist is re-loaded into the Hold by the server 1.6 s after death, before Roblox's own auto respawn (RespawnTime 3), which then never fires. `Player.RespawnLocation` was tried first and is **ignored** by Roblox for a disabled SpawnLocation and for a team-only one (Neutral false, unused TeamColor); an enabled neutral one would also catch lobby joiners, so it was dropped. | `LobbyDuelManager.onCharacterAdded`, `BENCH_DELAY` |
| 6. Arena performance | Per-map `LightBudget` in `fix/duel_split_map.lua` (Warehouse: 2 shadow sources, as 120-degree downward SpotLights `ShadowSpot`, the 8 PointLights kept unshadowed as fill at 40 % brightness, spots at 75 %; 18 small parts and 11 big thin sheets (floor, roof, wall skins) stop casting). Re-ran the split (Visual 518 instances, Solid unchanged 165). | `fix/duel_split_map.lua` |
| 7. Reward cooldown | Saved in the profile: `data.DuelPairs = { ["<opponent ids>"] = os.time() }` written through `PlayerStore.Set` (replica + ProfileService), entries older than the cooldown pruned on each write, so it holds across lobby servers and rejoins. Same key for the pair from both sides. | `LobbyDuelManager` rewardCooling / rewardMark |
| 8. Real disconnect | Tested with `Player:Kick()` mid-round. | `manager._OnRemoving` (PlayerRemoving) |
| 9. 2v2 / 3v3 paths | Tested on a temporary runtime map `TestWH2v2` (Warehouse layers, folder attr `Modes = "2v2"`), removed afterwards; Warehouse is still 1v1 only (Edit: `DuelMaps` = Warehouse, `Modes = {"1v1"}`; 2v2 / 3v3 pads `NoMap`). | `MapRegistry` (folder name = id, folder `Modes` attr overrides MapInfo, cache drops on `DuelMaps` child added / removed, `MapRegistry.Changed`), NoMap refresh on change, test bots fill both teams to the mode's size |

Also: `LobbyDuelManager` makes `Events.Combat.Explosion` if missing; test bots are named `DuelBot_<id>_<index>`; Studio-only
`ServerStorage.DuelTestHook` (BindableFunction) runs test commands in the game's VM (`bots / kill / forfeit / config / door / shot /
explode / reward / spawnlog / matches / removing`): the MCP's Server `execute_luau` runs in another Lua VM, so `shared.Get` is nil there
and `require` returns a fresh, un-started copy of a manager.

Install: `python tools/lobby_duels_build.py --run` (7 sources, 41 [DUEL] edits: phase 1's 24 + 17 new). Then `fix/duel_split_map.lua` (light budget).
**UNDO tested**: install -> UNDO (41 edits reversed) -> the six edited managers hash-equal their `DUEL_<name>_Orig` backups, ArenaShootables gone,
backups removed -> reinstall -> the same hashes as before -> a second run changes nothing.

## Tests (Play, one client + server test bots, 2026-10-16)

**Arena interactivity (D1, player vs bot, while D2 bot vs bot ran in slot 2)**
- Door: `door D1 Door_North open` -> Solid shutter y 110.4 mid-roll, 115.5 at the end (+10 = OpenHeight); `DoorOpen` true, prompt "Close";
  the client's Visual shutter at 115.5 and its Led green. D2's door stayed shut.
- Valve, by a **real client shot** (`FireWeapon` from the head at `SteamValve_S1`): CombatManager -> afterShot -> ShootableManager stub ->
  `LobbyDuelManager.OnShot` -> D1's ArenaShootables. `SteamUntil` set, client jet on and hiss playing, `SteamMask.IsMasked` true at the valve;
  S2 and D2's valves untouched. The shooter's client got its `WeaponFired`.
- Barrels: D2 `FireBarrel_F1` and D1 `FireBarrel_F3` shot (server shot path): each arena's own barrel exploded (Solid Body CanCollide false),
  the D1 client hid its Visual F3, drew the fire patch (25 emitters), got **1** `Explosion` (D2's never arrived).
- Smoke (real `ThrowGadget`): 57 cells + source in `DuelArenas.D1.FX`, none in Workspace root; the canister landed by the south wall
  (z -49) and the flood stopped inside the arena (|z| <= 55.3, the wall is at 57.5); charges 3 -> 2 (LiveMatch).
- Frag (real throw, KitGadget Frag): exploded in the arena (`Explosion` 1 -> 2 on the client, the thrower took 56 from his own frag at the wall).
- Flash (real throw): `FlashDetonated` 0 -> 1.
- Scope: firing `WeaponFired` anchored on D2's bot and `Explosion` at a D2 position, and `WeaponFired` at a lobby position: the D1 client
  counters did not move (Audience: D2 = 0 players, lobby = 0 players while the only player was in D1).
**Concurrency**: D1 3-1 and D2 3-0 both reached MatchEnd, D2 freed slot 2 at once (bots only), D1 returned the player and freed slot 1
(`[LobbyDuelManager] D2 done, slot 2 free`, `D1 done, slot 1 free`). Six bot matches D1-D6 at x 4000..9000 (spacing 1000), the seventh
refused `ARENAS FULL - WAITING`; after forfeits: 0 arenas, 0 state objects, all slots free.
**ARENAS FULL with a pad** (MaxArenas 1 at runtime, slot held by a bot match): the player's 1v1 pad stayed in Countdown, QueueState row
`duelWait = "ARENAS FULL - WAITING"`, board + PadUI show it (04); the bot match forfeited -> the pad's match D8 started 1.8 s later.
**HUD (lead's check)**: after D1 returned, no score bar and no VICTORY card in the lobby (03); the next match D8 opened at 0-0 ROUND 1 with
no old card (05). Only `DuelFade` (transparent) remained in PlayerGui.
**Respawn**: client-side `CharacterAdded` first-seen root Y for every duelist character over D8 + D9 (round spawns, a bench after a death,
the 2v2 mid-round death): `43 43 43 43 43 | 19 (return to the pad) | 43 43 43 43` - always the Hold (y 40 + 3), never the lobby spawn
(y ~4). The server sees the new character at the lobby spawn for part of one server step before the deferred CharacterAdded runs;
it never reached the client. No engine auto respawn fired after a bench.
**2v2** (TestWH2v2, D9: player + bot vs 2 bots): MapList only `TestWH2v2`; `TeamA = [player, -2]`, `TeamB = [-3, -4]`; spawns side by side
4 studs apart (A (31,3,-50) / (34.4,3.2,-47.9), B mirrored); HUD 2 pips a side (06). Player killed first: round stayed Live, player
`Alive = false`, benched at y 43 anchored; one B bot down: still Live; both down: RoundEnd 1-0. Then 3-0, player kills 4, deaths 1.
Map removed -> 2v2 pads back to "No maps yet for 2v2"; Edit has only Warehouse.
**Reward cooldown**: `reward` on a fresh pair: cooling false -> mark -> `DuelPairs = {"-99": <os.time>}` in the profile, cooling true;
with `DuelRewardCooldown = 1`, 2 s later cooling false (expiry). Matches with test bots never pay (unchanged), so the full award path
with two real players is still untested. Studio's ProfileService has no API access ("data will not be saved"): the cross-server part
is by construction (profile data), not observed.
**Disconnect**: `Player:Kick()` during D10's round 1 Live -> `ocxa left D10 (disconnect)`, MatchEnd 1.1 s later (forfeit, bot side wins),
state object, arena and slot gone at 2.6 s.
**Console**: no errors from duel code. One warning per flash: GadgetManager `Get("BotManager")` is nil in the lobby (pre-existing).

## Arena cost (client, SceneAnalysisService)
Synthetic, same camera (spawn A looking down the hall), the Visual clone + two moving casters (characters force shadow maps to re-render;
with nothing moving, cached shadow maps cost 0 and the numbers mean nothing):

| | total tris / draw calls | shadow pass | arena lights' share of the shadow pass |
|---|---|---|---|
| Before (8 shadowed PointLights) | 4,408,592 / 2,375 | 4,295,733 / 2,276 | ~3.84 M |
| 2 shadowed PointLights + small parts off | 1,617,028 / 975 | 1,504,169 / 876 | ~1.05 M |
| + sheets off | 1,495,752 / 819 | 1,382,905 / 720 | ~0.96 M |
| **Shipped: 2 SpotLights 120 deg + sheets off** | **786,874 / 565** | **674,027 / 466** | **~0.25 M (-93 %)** |
| Reference: no arena light shadows | 533,164 / 419 | 420,353 / 321 | 0 (sun cascades + lobby) |

A spot light up to ~120 degrees renders one shadow frustum; a point light (and a 179-degree spot) renders a 6-face cube, so with batched
arena meshes every shadowed point light costs the whole map x6 (~480 k). Real duel, round 1, player walking (after): **595 k tris / 456 dc,
shadows 471 k / 349** vs phase 1's 991 k / 699, shadows 866 k / 593 (phase 1 was measured without movement, so its shadow figure is low).
What is left of the shadow pass is mostly the sun's cascades over the roofed arena; next lever if needed: test the arena Lighting with
the sun below the horizon or `GlobalShadows` off + ambient compensation (look change, Edward's call).

## Known gaps / next
- Props (bottles, chairs) don't break visually in arenas: PropController binds `workspace.Warehouse.Props` once at start (UI request 7).
- Camera clips into arena walls at the edge spawns (05, 06): the Visual layer doesn't collide / query and the Solid layer is transparent,
  so the camera's occlusion ignores both (UI request 8).
- Friendly-fire block for gun shots between real teammates is untested (bots don't shoot; the code path is phase 1's).
- Full reward write with two real players, and spectating (phase 3), untested. Test bots still never shoot.
- `Spectate` / `LF_LiveDuels` rows: phase 3.
