# Profile hand-off around teleports + headshot flag (2026-10-16, [DATA])

Both working copies: lobby `Tacticals_rebuild.rbxl` (studio 8ef4e21a) and match place `match_place_ref.rbxl` (studio 331cb3a0).
Install / UNDO: `fix/data_release_install.lua` (idempotent, detects the place; backups `ServerStorage._RebuildRemoved.DATA_<name>_Orig`).
- lobby: `python tools/run_luau.py fix/data_release_install.lua [UNDO]`
- match place: the same file through `execute_luau` in 331cb3a0 (run_luau.py's id is the lobby's).
- **Re-run it after** `tools/match_place_build.py` (rewrites RoundManager) in the match place. The lobby installers
  (lobby_duels, admin) don't touch the edited text, but re-running this one after them is harmless ("already in").

## Job 1: slow profile load after teleports

**Cause.** Both DataManagers called `profileStore:LoadProfileAsync("Player_"..id)` and released the profile only on
PlayerRemoving. After a teleport the destination's load found the source server's session lock still set and ProfileService's
default ForceLoad had to ask the source to release it (several DataStore round trips, up to about a minute). The menus waited the whole time.

**Fix (standard ProfileService hand-off):**
- `DataManager.ReleaseForTeleport(players [, timeout = 8])` (a Player or a list): saves and releases each profile (`profile:Release()`),
  then yields until the release saves have landed (`ListenToHopReady`) or the timeout. The destination's load then finds the lock
  free and loads at once. Safe to call twice and for players without a profile.
- **After the release**, `DataManager:Get(player)`, `DataReplicas[player]` and `Profiles[player]` stay as they were, so every
  reader and writer (PlayerStore, raw `data.X = ..`, `replica:SetValue`, the admin DataAdapter) keeps working **without errors**.
  Nothing written after the release is saved (the profile is inactive; ProfileService only warns on `:Save()`).
  `DataManager.IsReleased(player)` tells code that cares.
- The profile's release listener (`_onReleased`) ignores the release we made for a teleport (before, it **kicked** the player, which
  would have cancelled the teleport). Any other release (another server took the profile, the player is leaving) drops the data and
  kicks as before.
- Explicit `not_released_handler = "ForceLoad"` on the join load, and the **load time per player** in the console:
  `[DATA] profile loaded for <name> (<id>) in 0.42 s` (print; `warn` when 5 s or more, or FAILED). Also player attribute
  `DataLoadTime` (seconds).

**Teleport failure: choice = reload, kick only when a reload isn't safe.**
`DataManager.RestoreAfterTeleportFail(player, why)` runs when: `TeleportService.TeleportInitFailed` fires for a released player
(hooked inside DataManager), a call site's `pcall(TeleportAsync)` fails (after all its retries), or the player is still in the server
**30 s** after the release (teleport silently lost). It waits for the release save, then loads the profile again with a handler that
returns `"Cancel"` (never steals it from another server):
- loaded and `MetaData.SessionLoadCount` is exactly one more than at the release (nobody else loaded it in between): the new
  profile **adopts the data table everyone already holds** (`profile.Data = old.Data`), so the replica, the UI and every reader
  stay bound; writes made while released are kept from now on. The player plays on; console `[DATA] profile re-loaded after a failed teleport`.
- otherwise (another server holds or held it: its copy is newer, or the load failed): the new profile (if any) is released and the
  player is **kicked** with "Your teleport didn't go through and your save couldn't be reopened on this server. Please rejoin."
  There are never two live copies.
Why not always kick: failed teleports are common enough (full / shutting reserved servers, client issues) that kicking a lobby
player for them would be worse than the original bug; the reload is instant because the profile is free.

**Call sites** (all `[DATA]`, release right before TeleportAsync):
| Place | Script | Path |
|---|---|---|
| lobby | `Managers.QueueManager` deploy | pads -> match place (only when in-lobby duels are off); restore on a failed call |
| lobby | `Managers.MatchmakingManager` deliver | PLAY / global queue -> match place; restore on a failed call |
| lobby | `ServerScriptService.NewPlayerTutorial` | new player -> tutorial place (its "let the profile save its release" wait never released anything); restore after 3 failed tries |
| match | `Managers.RoundManager` backToLobby | results / leave / cancelled / admin end -> lobby; restore after 3 failed tries |
| match | `Managers.TutorialManager` | tutorial done -> lobby (TutorialDone is written before the release, so it is saved) |
The existing TeleportInitFailed handlers in QueueManager / MatchmakingManager (bay reset, notify) are unchanged.

## Job 2: critical-headshot flag on HitConfirm

`Events...Combat.HitConfirm` (server -> shooter) was `(zone, damage, killed)`. It now has a **4th argument `headshot`** (boolean):
`HitConfirm:FireClient(shooter, zone, damage, killed, headshot)`.
- `headshot = true` when the shot hit the **Head** zone and the gun's `Damage.Head` beats its `Damage.Body` (the 2x crit every gun has
  in WeaponConfig). That is exactly the rule that gives the extra damage, so it can't disagree with the damage number.
- Only `CombatManager` (gun shots) sets it. Melee (`MeleeManager`: a backstab still sends zone `"Head"`), frag / barrel damage
  (`ShootableManager`, `ArenaShootables`: zone `"Body"`) send no 4th argument, i.e. `nil` = not a headshot.
- Backward compatible: old listeners `function(zone, damage, killed)` ignore the extra argument.
- **For the UI session:** draw the crit crosshair / hit marker when the 4th argument is `true`
  (`HitConfirm.OnClientEvent:Connect(function(zone, damage, killed, headshot) ... end)`); do not use `zone == "Head"` (melee backstabs send it too).

## Tests (2026-10-16, Play, one client "ocxa"; ProfileService ran on its mock store: "Roblox API services unavailable")
The lead UNDO'd the first install before publishing; re-installed in both places, then tested. Driver: a Studio-only Script made in
the running server (`DataTestHook` BindableFunction, gone when Play stops) calling the game VM's own DataManager; counter key
`DataTestCounter` in the mock profile.
- **Join log** (both): `[DATA] profile loaded for ocxa (281164661) in 0.00 s`, `DataLoadTime = 0`.
- **Release then writes** (both): `ReleaseForTeleport` returned true in 0.05 s (hop-ready reached), `IsActive` false, player still
  in the server, same data table. Then a raw write (`data.X += n`), `replica:SetValue` and `profile:Save()`: **no errors**
  (ScriptContext.Error list empty); Save only warns `Attempted saving an inactive profile`. *Mock caveat:* ProfileService's mock
  store keeps a reference to the data table, so `GetOffline` shows post-release writes there; a real DataStore serialises at the
  release save, and the inactive profile is out of the autosave list, so nothing later is written.
- **Teleport failure** (both): release -> real `TeleportAsync` (errors in Studio: "Request Context Failure") -> restore:
  `restored = true` in 0.11-0.15 s, profile active again, `SessionLoadCount` +1, writes made while released kept, later writes OK.
  Also `RestoreAfterTeleportFail` called directly as the TeleportInitFailed hook calls it ("simulated TeleportInitFailed"): restored.
- **30 s auto-restore** (match): released and left alone: still released at t+20 s, active again at t+33 s
  (`teleport failed for ocxa (still here 30 s after the release)`, `profile re-loaded after a failed teleport`).
- **Kick case** (match): `SessionLoadCount` at the release tampered so the reload looks like another server loaded it in between:
  `restored = false`, the player was kicked, no errors. First run showed the replica wasn't destroyed on that path; fixed (the kick
  path destroys it now) and re-installed in both places. The re-run couldn't check the counts after the kick: kicking the only
  player ended the Studio session.
- **Headshot flag** (both): real `FireWeapon` shots from the client at a dummy (match: `FiringRange.RangeDummy`; lobby: Training
  `DpsDummy`, after `Training.Enter`). The client received `HitConfirm(Head, 60, false, true)`, `(Body, 30, false, false)`,
  `(Limb, 20, false, false)`, 4 arguments each.
- **Install / UNDO**: both places: install -> second run all "already in" -> UNDO (every script "matches its backup", backups
  removed) -> install again. All edited scripts compile.
- Lobby shots logged `[ModuleLoader:Server] Get("BotManager") returned nil` (the lobby has no BotManager; not from this change).

## Not tested (Studio can't)
- A real teleport (lobby <-> match, tutorial), a real `TeleportInitFailed`, and the real DataStore. So the actual speed-up in the
  destination's load is untested; watch the `[DATA] profile loaded ... in X s` lines in the live console (the destination should
  now show well under a second instead of up to ~1 min).
- The real "another server loaded it" race (only simulated by tampering the load count), group teleports with several players
  (the code releases every player and waits for all of them), the call sites themselves (QueueManager / Matchmaking /
  NewPlayerTutorial / RoundManager / TutorialManager skip teleports in Studio before reaching the new lines: checked by
  compile + reading only).
- The lobby kick path and the lobby 30 s auto-restore (same code as the match place's, which was tested).
