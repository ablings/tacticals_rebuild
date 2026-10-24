# Lobby duel spectating: turn back on (Edward, 2026-10-23, for the next session)
Edward: "turn spectating back on and test it, it should work the same way it works in matches after kills".

Found so far (read only, nothing changed):
- Client is ready: DuelHUD's spectate card ("SPECTATING" / Q / E cycle / Stop -> send("StopSpectate")), CameraController
  spectateModel(), CamSync relay all key off `DuelSpectate` = match id, the same path dead duelists use.
- `ui/hud/PlayerCards.lua` ~line 418: the "Spectate" action is left out for in-duel players ("paused by Edward") - add it back;
  `run("Spectate")` already fires LobbySocial ("Spectate", target).
- Server gap: `scripts/social/LobbySocial.server.lua` has no Spectate handler (comment: paused), and
  `scripts/duels/LobbyDuelManager.lua` keeps `match.spectators` (cleared in endMatch) but nothing adds to it.
  Needed: a manager.Spectate(player, target) / StopSpectate(player) (set DuelSpectate, add to match.spectators, bump the
  Spectators attribute, refuse if the viewer is queued / in a duel), wired from LobbySocial + DuelHUD's StopSpectate.
- Test in Studio: DuelTestHook "bots" -> spectate from the player list -> card, Q / E, camera, Stop; then the lead publishes.
