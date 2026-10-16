# Lobby duels: phase 1 build (2026-10-16)

Design: `notes/lobby_duels_design.md` (§0 has the changes since: map registry, modes per map, lead defaults). Facts: `notes/lobby_duels_survey.md`.
UI asks: `notes/lobby_duels_ui_requests.md`. Lobby copy studio 8ef4e21a (`Tacticals_rebuild.rbxl`); match place 331cb3a0 read only.
Nothing saved by this session (the lead saves). Studio left in Edit.

## What was built
A full 1v1 pad match inside the lobby server, no teleport:
pad countdown -> Loading (3 s) -> MapVote (eligible maps + Random, 10 s) -> Loadout (15 s, the arena loads behind it) -> rounds (first to 3,
MatchCore) -> MatchEnd results (12 s) -> fade, back to the pad's step-off spot, arena unloaded, slot freed.

| Piece | Where | Notes |
|---|---|---|
| Warehouse port | `ServerStorage._DuelSource.Warehouse` (+ `MaterialService.DuelMaps_Warehouse.WH_Floor`) | **Script copy, no clipboard needed**: `tools/duel_map_port.py` serialises the tree + properties in 331cb3a0 (`tools/duel_map_export.lua`, read only) and rebuilds it in 8ef4e21a (`tools/duel_map_import.lua`). MeshParts via `AssetService:CreateMeshPartAsync` (works in Edit through the MCP), SurfaceAppearance maps set directly. 522 / 522 instances, 0 missing meshes, class counts equal to the source. Export kept in `out/duels/Warehouse_export.json`. |
| Map registry | `ReplicatedStorage.DuelMaps.Warehouse` (`MapInfo`, `Visual`, `Lighting`), `ServerStorage.DuelMaps.Warehouse.Solid` | `fix/duel_split_map.lua` (one `MAPS` entry per map; UNDO). Re-centred: origin = footprint centre at floor level (floor found from the spawn markers). Visual 516 instances / 302 parts, nothing collides; Solid 165 instances / 109 parts (107 colliders + spawns A1/B1), invisible, no shadows. `Modes = {"1v1"}`. |
| `MapRegistry` | `ReplicatedStorage.Modules.Shared` | `List / Get / ForMode / HasMode / SlotSpacing`. No duel code names a map. |
| `MatchState` | `ReplicatedStorage.Modules.Shared` | `For / MatchId / Role / Get / SameMatch / ArenaOf / MatchOf`. Outside a duel `Get` falls back to ReplicatedStorage, so Training is unchanged. |
| `MatchCore` | `ServerScriptService.Shared` | The match place RoundManager's playRound / playMatch / win rules / trade-draw / timeout-by-health / forfeit / kill tally / reward maths / Elo, behind a context object (`state, teams, announce, spawnMember, setFrozen, isPresent, onRoundStart, onKill`). Members are Players or test-bot rigs. Also `resolveVote`, `validPick`, `applyKit` (Kit* + `Loadout` mirror). |
| `LobbyDuelManager` | `...Managers` (auto-loaded) | Slot allocator for `MaxArenas` (6) at `x = 4000 + spacing*(n-1)`, y 100; state object `ReplicatedStorage.LobbyDuels.D<n>` with the contract attributes; `MatchFlow` handler (Vote / Pick / Ready / Loaded / Leave, matchId checked); per-slot `Hold` floor 60 below the arena for waiting / dead players; fall check (y < origin - KillDepth = death); rewards via `PlayerStore` with the 10-minute pair cooldown; `NoMap` / `NoMapText` on pads of modes without a map; Studio test bot. Entry point **`StartMatch(pad, mode, teams)`** (not `Start`: ModuleLoader calls `.Start()` at boot - the first test hit exactly that). |
| `ArenaLoader` | `StarterPlayer.StarterPlayerScripts` (LocalScript) | Clones the chosen map's Visual for match players only (named `MapInfo.WorkspaceName`, attr `DuelArena`), PreloadAsync capped at 8 s, local Lighting swap (attrs + Atmosphere / Bloom / ColorCorrection; the lobby's Atmosphere steps out, PostEffects disabled) and restore, `Loaded` to the server, fades. |
| `MatchConfig` | replaced | Match place superset + duel keys (`PadDuelsInLobby`, `DuelMapVote`, times, `MaxArenas`, `ArenaBaseX/Y`, `DuelRanked=false`, `DuelRewardCooldown=600`). Nothing else in the lobby required it. |
| [DUEL] edits | 7 scripts, 24 marked edits | See `fix/lobby_duels_install.lua` (list in its header). |

Install: `python tools/lobby_duels_build.py --run` (embeds `scripts/duels/*.lua` into `fix/lobby_duels_install.lua`, then runs it).
UNDO: `python tools/run_luau.py fix/lobby_duels_install.lua UNDO`, then `fix/duel_split_map.lua UNDO`.
**UNDO tested**: install -> UNDO -> every edited script's Source hash equals its `DUEL_<name>_Orig` backup, new modules gone, MatchConfig restored;
reinstall -> the same hashes as before; a second run changes nothing (idempotent).

## Test (Play, one client + server test bot; captures `out/duels/phase1/` (git-ignored), sheet `notes/lobby_duels_phase1_sheet.png`)
`ReplicatedStorage.DuelTestSolo = true` (Studio only) lets one player start a pad; the empty team gets an R15 test bot (tag `Bot`,
`DuelMatch` on the model, negative user id). The real pad path was used (QueueManager countdown -> `duelHandoff` -> `StartMatch`).
- **Phases + MatchFlowUI** (the UI session's, unchanged): pad countdown (01), Loading (02), MapVote Warehouse + Random (03), a vote sent
  through `MatchFlow:FireServer(id, "Vote", "Warehouse")` showed the voter on the tile (04), Loadout with Map: Warehouse and the owned
  kit (05). Pick validation: `Pick Weapon Sniper` (not owned) and `Pick Melee Pistol` (wrong slot) were both refused.
- **Arena only on the duelist client**: client `workspace.Warehouse` (attr `DuelArena = D1`) 516 instances at (4000, 100, 0), Lighting
  swapped (ClockTime 13, Brightness 2); server `workspace.DuelArenas.D1` = Hold + Solid (+ the bot). After the match: 0 clones,
  Lighting back to the lobby's (ClockTime 12, Brightness 3, `Lobby_Atmosphere`), `LobbyDuels` and `DuelArenas` empty.
- **Lobby can't see it**: the server-replicated arena has **0 visible non-character parts** (all Solid parts are Transparency 1).
  10 = the arena slot seen from 70 studs with the Visual clone removed (= what any lobby client has): sky and the duelist's own
  character only. 11 = from the lobby's east edge toward the slot: lobby backdrop only. (MCP Play is one client, so a true third
  client wasn't possible; this is the same content a lobby client receives.)
- **Rounds**: round 1 in the arena with the DuelHUD, 150 HP, Pistol + Fists given by the [DUEL] CombatManager / MeleeManager gates (06).
  Kills set the pass 38 victim attributes (bot kill credited to the player, round won, kill feed) (07); player deaths credited to
  the bot. Score went 1-0, 1-1, 1-2, 2-2, 3-2 -> MatchEnd. `MatchKills 3`, `MatchDeaths 2`, headshots 2.
  Announce sequence received by the client: ROUND n / FIGHT / TEAM x WINS THE ROUND ... TEAM A WINS THE MATCH. MatchFlow events:
  Arena, Kill x5, Return.
- **Results** (08): `MatchResults` `{Won=true, Score 3-2, Kills 3, Deaths 2, Headshots 2, TestMatch=true, XP 0, Scissors 0, MatchId D1}`
  (a match with a test bot never pays).
- **Back to the pads** (09): `DuelMatch/InDuel/Team` cleared, character at the pad's step-off spot, 100 HP, no tools, the slot freed.
- **Leave mid-match** (match D2, during Live): `MatchFlow "Leave"` -> back at the pad within 1 s, the bot side won by forfeit, the state
  object and arena gone 1.8 s later, slot freed.
- **NoMap** (12): standing on a 2v2 pad with DuelTestSolo on: queued, **no countdown**, PadUI shows "NO 2V2 MAPS YET".
- **Server checks**: `WeaponUtil.IsPathClear(A1 -> B1)` blocked by `COLP_P01`; centre -> outside blocked by `COLP_Wall_W`; floor ray hits
  `COLP_Floor` at y 100.0.
- **Console**: no errors from the duel code. The only errors were the UI's MatchFlowUI `_gone` (93x, UI request 1).

### Cost (client, in the arena, SceneAnalysisService)
- Visual clone: 516 instances, 302 parts (93 MeshParts), 11 lights. Server Solid: 165 instances, 109 parts, all invisible.
- Round 1 view: **opaque 123,884 tris / 80 draw calls; shadows 866,473 tris / 593 draw calls; total 990,779 / 699.**
  The shadow pass is 87 %: the 8 `ArenaLights` PointLights have Shadows on. Phase 2: shadows on 2-3 lights only (vault 7.7c), expect ~3x less.

## Known gaps (phase 2+)
- **Death respawn flash**: the dead duelist's auto respawn (`RespawnTime` 3) can land at the lobby spawn for one tick before the Hold
  pivot; in the test it coincided with the next round's `LoadCharacter` and was replaced at once. Design risk §8 stands; "soft death" if it shows.
- The dead character's HumanoidRootPart falls through the arena floor during the ragdoll (cosmetic, the round already ended).
- Doors don't open and barrels / valves don't react (no `ArenaDoors` / `ArenaShootables`; the Panel prompts were stripped). Dynamic
  follow of Visual parts on Solid twins not built (MapInfo.Dynamic lists the folders).
- Gadgets: `mapRay` still looks for `workspace.Warehouse` (server has none -> the Exclude fallback); `ClearAll` per arena, grenade /
  burn damage same-match guard, `FlashDetonated` / `WeaponFired` / `Explosion` still go to every client (`FireMatch` narrowing).
  `GadgetConfig.InfiniteCharges` applies in duels.
- `MatchFlow "Spectate"` is ignored (phase 3); `LF_LiveDuels` has no in-lobby rows yet.
- The reward cooldown is per lobby server (in memory), not global.
- Not tested: 2v2/3v3 (no map for them), two matches at once, ARENAS FULL (needs MaxArenas 1 + 2 clients), a real disconnect, shot
  validation by real client shots (kills were applied server-side with the same attributes the managers set).
- `Players:CreateHumanoidModelFromDescription` test bot is a standing dummy; it never shoots.

## For the lead
- Nothing to copy by hand: the Warehouse came over by script.
- Save the place (the edits and the registry are in Edit; the 16:04 save predates the QueueManager countdown edit and the `StartMatch` rename).
- The map image (`ui/art/map_warehouse.png`) is not uploaded; set `Image` in `fix/duel_split_map.lua` MAPS and re-run when Edward OKs it.
