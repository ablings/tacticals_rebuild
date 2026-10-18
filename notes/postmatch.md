# Post-match: pseudo lobby, rematch, play again (2026-10-18, Edward via the UI session)
Design: the pseudo lobby lives on the match server itself (Matchmaking / Ranked places), so a rematch keeps everyone together.
- Phase 1 (`fix/postmatch_install.lua`, written, NOT installed yet: Studio was closed): series + post-match state machine in
  RoundManager (runSeries / postMatch / postMatchFlow), To Hub / Play Again (hub teleport with AutoQueue) / Rematch; lobby
  MatchmakingManager auto-queues on AutoQueue. Run it in the match copy (then rebuild the place copies) and in the lobby copy:
  `python tools/run_luau_at.py match fix/postmatch_install.lua` and `... lobby ...`.
- Phase 2 (todo): the pseudo-lobby MAP = a lobby copy kept in ServerStorage of the match places, moved into Workspace for the
  post-match phase, duel pads barricaded; spawn there instead of the team spawns.
- Phase 3 (todo): Play Again without the hub (the online queue from the match server).
Rules: rematch while SeriesGames < 3, no side at 2 wins, all original players present; starts when every present player voted
(3 s countdown). PostMatchTime 300 s, then the hub.
Contract (UI session): MatchFlow "Rematch" / "PlayAgain" / "ToHub"; ReplicatedStorage PostMatch, RematchVotes, RematchNeeded,
RematchAllowed, RematchReason, RematchStartsAt, SeriesGames, SeriesWinsA/B; player InPseudoLobby, RematchVote.

## Phase 2: the after-match lobby map + lobby server systems (2026-10-18, [PSEUDOLOBBY], lead)
Split agreed with the UI session: lead = map copy, barricades, spawning, server systems; UI = porting the lobby screens into the
match places, shown only while `InPseudoLobby`, PLAY in the dock = Play Again.
- **Build** (`tools/pseudolobby_build.py`, match copy only; UNDO removes everything tagged `PseudoLobbyNew`):
  - `server`: Events.Lobby (Request / QueueState / Notify), LobbyTopWins, and copies of the hub's PlayerStore, LobbyRemotes,
    LobbyCodes, LobbyManager (Shop / Kit / Missions / Robux / Passes / Settings / Codes, ProcessReceipt: the match place had none),
    VipPerks, PublicStats, LobbyLeaderboard, LobbyNPCs (runs whenever LobbyMap arrives), PartyService + LobbyParty, and
    `Shared.PseudoLobby`. Sources in `scripts/pseudolobby/` (hub copies, changes tagged [PSEUDOLOBBY]):
    Equip refused outside the pseudo lobby on a match place (no mid-round gun swap), SaveSettings calls
    `shared.SettingsApply` (SettingsBridge) so Setting_* attributes update at once, party invites refused for anyone in a match.
    Swapped for the hub's version (original kept in attribute PseudoLobbyOriginal): `DataManager.Template` (the match's had only
    ProfileVersion, so a new profile lacked Quests: LobbyManager errored) and `LobbyConfig` (older: no GamePasses / QueueById,
    TutorialPlaceId of the old combined place; LobbyPlaceId kept). Added `LobbyFeaturesConfig`.
  - `map`: the hub's `Workspace.LobbyMap` minus Training, tags QueuePad / ExfilBarrier / DuelArena / AimAssistTarget stripped,
    moved by OFFSET (0, 0, 2600) (Warehouse is inside the hub footprint), each duel pad + the Exfil hatch barricaded
    ("AVAILABLE IN THE HUB"), LobbySpawn disabled as a spawn, plus the hub's Lighting (children + properties as attributes).
    Carried as SerializationService bytes (1.94 MB), base64 in 90 KB slices through `shared` on both Studios (the bridge caps a
    result at 100 KB; HttpService is off in the match place), check copy `out/pseudolobby_map.b64`.
    Lands in `ServerStorage.PseudoLobby`.
  - `hooks` (`fix/pseudolobby_install.lua`): postMatch Show() + spawns around LobbySpawn, Hide() when the phase ends (roots
    anchored first so nobody falls), party Play Again in one TeleportAsync with TeleportData.Party.
- **Runtime**: `PseudoLobby.Show()` moves LobbyMap into Workspace, swaps the lighting, sets ReplicatedStorage.PseudoLobbyMap,
  respawns / fall-catches anyone InPseudoLobby back to LobbySpawn. No map copy = phase-1 behaviour (team spawns).
- **Hub**: `fix/party_regroup.lua` (MatchmakingManager): members re-join the leader only if the leader's own join data lists
  them (forged TeleportData joins nobody); the leader waits for everyone (25 s) and queues the party.
- **Not on the match server** (UI greys them out, "available in the hub"): queue pads / QUICK JOIN / FindMatch, Training / Exfil,
  Duels / Challenge, NewPlayerTutorial.
- **Tested 2026-10-18 03:30-03:45** (match copy, StudioTeleportData 1v1 vs bot): PostMatch -> player at (0, 3.5, 2600) on the hub
  spawn emblem, results screen over the hub; Equip ok in the pseudo lobby and refused mid-match; fall catch (y -300 -> spawn);
  Rematch 1/1 -> map back to ServerStorage, game 2 at the Warehouse team spawn, match lighting restored; no server errors.
  Not tested (needs two clients / live): party Play Again + hub regroup, purchases on the match server.
