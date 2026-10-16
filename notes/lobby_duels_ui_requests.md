# Lobby duels: requests to the UI session (from the duels build, 2026-10-16)

The duels session doesn't edit UI scripts (StarterGui, ReplicatedStorage.UIKit, the UI session's controllers). What the UI side
needs to show for lobby pad duels is listed here. Contract: `notes/lobby_duels_design.md` section 6 + `notes/ui_match_hud.md`.

## 1. Bugs seen in the phase 1 Play test (MatchFlowUI + DuelHUD as deployed at 16:05) - DONE by the UI session (commit 18a86d0)
Phase 2 check (2026-10-16): after a match returned, no score bar / VICTORY card in the lobby, and the next match opened clean at 0-0
ROUND 1 (`out/duels/phase2/03_*`, `05_*`).
- **MatchFlowUI `fillTeams` (line ~166) errors 93 times per match**: `_gone is not a valid member of Player`. `p._gone` on a real
  Player instance throws (only the stand-in tables have `_gone`). Use `type(p) == "table"` (or `typeof(p) ~= "Instance"`) instead.
- **DuelHUD stays up after the return to the pads**: the score bar (0 - 0, 0:00, ROUND 1) and the VICTORY card were still on screen
  in the lobby after `DuelMatch` cleared and the state object was destroyed (`out/duels/phase1/09_back_at_pads.jpg`), and the old
  card was **still there in the next match** (`10_*`, `11_*`). Hide the HUD when `MatchState.For(player)` is nil, and clear the
  results card on `MatchFlow "Return"` / a new `MatchId`.
- Kill feed shows "?" for the victim when it's a Studio test bot (negative user id, no Player): show "Test bot" or the id.
- The own-team box on MapVote / Loadout shows an empty grey circle until the headshot loads (fine) - the `Level` badge is set
  (`Level` attr), please check it shows.

## 2. Pads with no map for their mode (Edward 2026-10-16: the Warehouse is 1v1 only) - DONE by the UI session (deploy 16)
- `LobbyDuelManager` sets on each pad Model in `LobbyMap.Duels`: **`NoMap = true`** and **`NoMapText = "No maps yet for 2v2"`**
  (only when the mode has no eligible map in the registry). Those pads stay usable as queues but never count down.
- The `QueueState` snapshot rows carry the same text: `bays[i].noMap` (string or nil).
- PadUI shows "NO 2V2 MAPS YET" from `NoMap` on the pad model (seen in Play, `out/duels/phase1/12_nomap_2v2.jpg`).

## 3. "ARENAS FULL - WAITING" - DONE (PadUI + board show it; verified in phase 2, `out/duels/phase2/04_*`)
- When a full bay finishes its countdown and all `MaxArenas` (6) slots are busy, the bay stays in `Countdown` and re-checks every
  second. `QueueState` rows carry **`duelWait = "ARENAS FULL - WAITING"`** (nil otherwise); QueueManager also writes it on the
  old `Holo.Screen` and toasts it once. Request: PadBoards shows `duelWait` instead of the countdown number when set.

## 4. In-duel HUD inputs (DuelHUD deployed by the UI session; it works against these in the phase 1 test)
- Round banner + timer + score: state object `MatchState`, `RoundNumber`, `StateEndsAt`, `ScoreA/ScoreB`, `RoundsToWin`, player `Team`.
- `ReplicatedStorage.Events.Match.MatchAnnounce(title, subtitle)` (created at runtime by LobbyDuelManager, sent only to that
  match's players + spectators): "ROUND n", "FIGHT", "TEAM A WINS THE ROUND", "TEAM A WINS THE MATCH", "OPPONENTS LEFT".
- `Events.Match.MatchResults(summary)` at MatchEnd, payload as the match place + `MatchId`, `MeleeKills`, `Forfeit`, and
  `RewardCooldown = true` (same opponents within 10 min: XP / Scissors / GunXP are 0) or `TestMatch = true` (Studio bot).
- Kill feed: `MatchFlow` server -> client `(matchId, "Kill", {killer, victim, weapon, headshot, kind})`.
- Team pips: `TeamA` / `TeamB` JSON + each player's `Alive`. **Studio test bots have negative user ids** (-1, -2...).
- A LEAVE button sending `MatchFlow:FireServer(matchId, "Leave")` (forfeit, back to the pads at once).
- `MatchFlow "Return"` = the 1 s fade cue before the trip back (ArenaLoader already fades to black on it).

## 5. Client controllers that still read global match attributes
- `WeaponController` line ~244 reads `ReplicatedStorage:GetAttribute("CombatEnabled")` (global, nil in the lobby). The server
  rejects shots outside `Live` per match, so it's safe, but the client still plays the shot locally in countdowns. Request: read
  `MatchState.Get(player, "CombatEnabled")` (`ReplicatedStorage.Modules.Shared.MatchState`). Same for any HUD that reads
  `MatchState`/`StateEndsAt` on ReplicatedStorage.
- `CoverController` (lines ~101 and ~345) looks for `workspace.Warehouse` (Props / Shootables / `COLP_Floor`). The duel clone is
  named `MapInfo.WorkspaceName` ("Warehouse" for this map) and carries attribute `DuelArena = <matchId>`, so it works today,
  but future maps won't be called Warehouse: please find the map as the Workspace child with attribute `DuelArena` (fallback
  `workspace.Warehouse` for the match place).
- `NameplatesController` (deployed by the UI session): hide plates of players whose `DuelMatch` differs from the local player's
  (design section 3). Not visible today anyway (arenas are 4,000+ studs away), so low priority.

## 6. Buttons to hide while `InDuel` (design section 4)
- PLAY / Training / Exfil entry points and pad side buttons while `InDuel == true` (the server refuses them anyway).

## 7. Phase 2 (2026-10-16): props don't break in arenas
- `PropController.Start` binds `workspace:WaitForChild("Warehouse", 30).Props` once at join. In the lobby the arena clone appears
  minutes later (and is re-made per match), so props never break there. Request: (re)bind when a Workspace child with attribute
  `DuelArena` appears (Props folder inside it), and drop the entries when it is destroyed. Server side nothing is needed (props are
  client-only visuals; the shots arrive as `WeaponFired`, now sent only to the match's players + spectators).

## 8. Phase 2: the camera clips into arena walls
- At the edge spawns the third-person camera goes inside the wall (`out/duels/phase2/05_*`, `06_*`: half the screen black). In an arena the
  Visual layer is CanCollide / CanQuery false (client clone) and the collision is the Solid layer under `workspace.DuelArenas.<id>`, all
  Transparency 1, which the camera's occlusion test most likely skips (not verified in its source). Request (CameraController): while `InDuel` / `DuelSpectate`, include the match's Solid
  layer (`workspace.DuelArenas[MatchState.MatchId(player)]`) in the occlusion ray even though it is transparent (ignore `Hold`, `FX`).

## 9. Phase 2 contract additions (no UI work required)
- Combat FX remotes (`WeaponFired`, `MeleeHit`, `FlashDetonated`, `Explosion`) now reach only the players + spectators of the match the
  effect belongs to (and lobby / Training effects only players in no duel). Nothing changes in their payloads.
- Arena state for anything that wants to show it: Solid models under `workspace.DuelArenas.<id>.<WorkspaceName>` carry
  `DoorOpen / DoorMoving / DoorAt` (Interactive), `Exploded / FireUntil` (barrels), `SteamUntil` (valves). ArenaLoader already draws them.
- Door prompt: ProximityPrompt "Open" / "Close", object text "Shutter", key F, 0.25 s hold, on an invisible `PanelPrompt` part.
  Restyle through the prompt UI if wanted.
