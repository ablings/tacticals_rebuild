# Admin framework: requests for the UI session (2026-10-16)

From the admin framework pass (`notes/admin_framework.md`). The UI session owns StarterGui / UIKit and the [SET] / [UI] controllers,
so these are asks, not edits. Nothing here is urgent: chat commands already cover every command.

## 1. Admin panel (new)
A small RIVALS-style panel for testers, opened by a key (e.g. F2) or a HUD button **only shown when `whoami` says level >= 1**.
Server API (already live, `ReplicatedStorage.AdminRemote`, RemoteFunction):
- `InvokeServer("whoami")` -> `{ ok, level (0-3), levelName ("None"|"Tester"|"Admin"|"Owner"), prefix (";") }`
- `InvokeServer("commands")` -> `{ ok, commands = { { name, aliases, group ("Data"|"Player"|"Duel"|"World"|"Debug"|"Legacy"),
  level, description, usage (";setlevel <player> <level>"), destructive (bool), args = { { name, type, optional, choices, min, max, default } } } } }`
  Arg types: `players` / `player` (dropdown of players + me / all / others), `integer` / `number` (min / max), `boolean` (on/off
  toggle), `choice` (`choices`), `item` (the LobbyConfig.Items ids), `stat`, `level`, `string`, `rest` (free text).
- `InvokeServer("run", ";setlevel me 20")` -> `{ ok, lines = {...}, needsConfirm, command }`. When `needsConfirm` is true, show the
  line and a red CONFIRM button that sends the same text + `" confirm"` (10 s window). Only `run` is rate-limited (0.25 s).
- `InvokeServer("audit", 20)` -> `{ ok, entries = { { time, admin, level, command, args, targets, ok, result } } }` (Admin+).
The server re-checks everything; the panel never decides permissions. Suggested layout: group tabs on the left, a command list, an
args form built from `args`, a result log at the bottom. Scale-only sizes per the UI rules.

## 2. `AdminSpeed` in MovementController ([SET])
`;speed <player> <n>` sets the player attribute `AdminSpeed` (nil = normal) and the Humanoid's WalkSpeed. In the lobby that sticks;
in Training / duels `MovementController` writes WalkSpeed every frame, so the admin speed is lost there. Ask: in the WalkSpeed line
(`hum.WalkSpeed = currentSpeed * stunScale * weaponSpeedScale(...)`), use `localPlayer:GetAttribute("AdminSpeed")` as the base walk
speed when it is set (or multiply by `AdminSpeed / Config.Speeds.Walk`).

## 3. Optional: a small "ADMIN" / "TESTER" tag
Players with `AdminGod` (god mode) or `AdminDuelSolo` could show a tiny marker on their nameplate so other testers know why they
don't die / why a pad started alone. Attributes are set by the server only.
