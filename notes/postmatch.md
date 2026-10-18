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
