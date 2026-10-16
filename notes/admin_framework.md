# Admin command framework (2026-10-16)

Edward: "for testing purposes i need the admin commands for each test such as wiping stats level etc and changing levels of players
and stats use a more structured admin framework". Facts behind it: `notes/admin_survey.md`. Short list for Edward:
`notes/admin_cheatsheet.md`. Panel request for the UI session: `notes/admin_ui_requests.md`. Captures: `out/admin/` (git-ignored).

Built in `Tacticals_rebuild.rbxl` (Studio 8ef4e21a) only. Not saved. The match place (331cb3a0) was only read.

## 1. Layout (one module set for both places)
```
ServerScriptService
  AdminCommands            Script      entry points: chat, panel RemoteFunction, ServerStorage bindable   [ADMIN] replaced
  AdminFramework           Folder
    Config                 ModuleScript  admin ids, group id + ranks, prefix, confirm window, audit store, level curve fallback
    Permissions            ModuleScript  LevelOf(player) (server only), Studio simulated level
    Args                   ModuleScript  tokenizer + typed parsers (players, player, number, integer, boolean, choice, item, stat, level, rest)
    DataAdapter            ModuleScript  the only door to saved data: PlayerStore (lobby) or DataManager replicas (match place)
    Audit                  ModuleScript  memory log + capped DataStore copy
    Core                   ModuleScript  registry, dispatcher, permission / target / confirm rules, audit
    Commands               Folder        one ModuleScript per group, each returns a list of command defs
      Data, Player, Duel, World, Debug, Legacy
StarterPlayer.StarterPlayerScripts.AdminFeedback   LocalScript  forwards chat commands, shows replies   [ADMIN] replaced
```
Sources: `scripts/admin/` (`Commands/*.lua`, `AdminCommands.server.lua`, `AdminFeedback.client.lua`). Build + install:
`python tools/admin_build.py --run` (embeds the sources into `fix/admin_install.lua` and runs it). UNDO: `python tools/run_luau.py
fix/admin_install.lua UNDO`. UNDO tested: install -> UNDO (scripts hash-equal their `ADMIN_*_Orig` backups, AdminFramework gone,
backups removed) -> reinstall (same hashes as before) -> a second run changes nothing.

Runtime objects (made by `AdminCommands` at server start): `ReplicatedStorage.AdminFeedback` (RemoteEvent, server -> client lines),
`ReplicatedStorage.AdminRequest` (RemoteEvent, chat text -> server), `ReplicatedStorage.AdminRemote` (RemoteFunction, panel),
`TextChatService.AdminCommands` (one `TextChatCommand` per name and alias, `;name`, old names also `/name`), `ServerStorage.AdminBindable`.

## 2. Permissions
- Levels: **Owner (3) > Admin (2) > Tester (1) > None (0)**. Each command declares its minimum level.
- A player's level = the best of: `Config.Users[userId]` (explicit list), their rank in the owning group (`Config.GroupRanks`:
  rank >= 255 -> Owner, >= 254 -> Admin; a `Tester` rank line is ready to uncomment), and in **Studio always Owner**.
- Owning group: `game.CreatorId` when the place's creator is a group, else `Config.GroupId = 102028987` ("gunsy funsy", owner ocxa).
  Ranks are cached 120 s per player.
- Explicit list today: **281164661 = Owner** (Edward: username ocxa, display name "debits"). The account whose username is "debits"
  (63563472) is someone else and is deliberately not listed.
- All checks run in `Core.Run` on the server. The client only sends text; the panel's `commands` list is filtered by the server too.
- Rules applied by Core for every command:
  - level >= the command's level, else "`;cmd` needs Admin (you are Tester)" / "You're not allowed to use admin commands.";
  - a **Tester can only target themselves** (Admin+ can target others);
  - nobody can target a player whose level is higher than their own (kick / wipe an Owner as an Admin is refused);
  - **destructive** commands (`wipe`, `wipeweapons`) need the same command again with `confirm` within 10 s; on several players
    (`all`, `others`, a list) they are **Owner only**;
  - `studioOnly` commands are refused outside Studio.
- Studio permission testing: `;simlevel tester|admin|none|owner [player]` (Studio only, usable at any level so `;simlevel owner` undoes
  it). Stored as `ServerStorage` attribute `AdminSim_<userId>` (server only).

## 3. Entry points
1. **Chat**: `;command args` (prefix `Config.Prefix`). The old names keep `/`: `/scissors`, `/give`, `/wipeweapons`, `/unlockall`, `/admin`.
   Known commands never appear as chat (TextChatCommand). A mistyped `;xyz` from an admin is held back by the server
   (`TextChannel.ShouldDeliverCallback`) and answered "unknown command"; from a non-admin it's normal chat (`;)` stays a smiley).
   The sender's own bubble still shows the typo locally (Roblox echoes your own message); nobody else receives it.
2. **Admin panel** (to be built by the UI session): `ReplicatedStorage.AdminRemote:InvokeServer(action, payload)`
   - `"whoami"` -> `{ ok, level, levelName, prefix }` (anyone);
   - `"commands"` -> `{ ok, commands = { {name, aliases, group, level, description, usage, destructive, args = {name, type, optional, choices, min, max, default}} } }` (what this player may run);
   - `"run", ";setlevel me 20"` -> `{ ok, lines, needsConfirm, command }` (no chat lines; the panel shows `lines`);
   - `"audit", n` -> `{ ok, entries }` (Admin+). Only `run` is rate-limited (0.25 s).
3. **Studio command bar / MCP**: `game.ServerStorage.AdminBindable:Invoke(...)` (server only; the MCP's Server `execute_luau` runs in
   its own VM, and the bindable runs the command inside the game's VM):
   - `("run", ";stats me", userId)` as that player with their real level; replies also go to their chat;
   - `("console", ";setlevel ocxa 30", meUserId?)` as the server console (Owner); `me` = that player;
   - `("simlevel", userId, "None"|nil)` (Studio), `("audit", n)`, `("list")`.

## 4. Feedback and audit
- Replies: `AdminFeedback:FireClient(player, line, kind)`; the client prints `[Admin] line` in the RBXSystem channel: olive-green done,
  red error, cream plain output, `[Server]` for `;announce` (which also shows the lobby toast through `Events.Lobby.Notify`).
  Text is escaped for rich text. At most 24 lines per command.
- Targets other than the caller get a short line ("An admin set your scissors to 1000.").
- Audit: every run, refusal and confirm request -> `Audit.Log { time, admin, adminId, level, command, args, targets, ok, result, source }`;
  printed as `[Admin] ...` in the server output, last 200 in memory (`;audit [n]`, panel `audit`), and every 30 s appended to
  DataStore `AdminAudit_v1` key `log` (last 100). Where DataStores fail (Studio / unpublished: "You must publish this place to the
  web to access DataStore") the store switches off for that server with one warning; `;serverinfo` shows the state.

## 5. Command reference
`<player>` accepts `me`, `all`, `others`, `@userid`, a name or display-name prefix, or a comma list (`me,bob`); where it's optional the
default is `me`. Errors name the problem and show the usage.

| Group | Command (aliases) | Args | Level | Effect |
|---|---|---|---|---|
| Data | `stats` (profile) | `[player]` | Tester (any target) | Level / XP / scissors, items owned, loadout, Stats, ranked, missions, duel cooldowns |
| Data | `wipe` | `<player> [all\|stats\|level\|inventory\|credits\|missions\|cooldowns\|settings]` | Admin, confirm | Reset to template defaults. stats = Stats + Ranked; level = XP + ItemXP; inventory = Owned, Favorites, ItemXP, default Loadout; credits = 500; missions = new Daily/Weekly; cooldowns = DuelPairs; settings; all = everything + RedeemedCodes. Never: Passes, Receipts, TutorialDone |
| Data | `setlevel` (level) | `<player> <level>` | Tester | XP = the level's threshold (`XPForLevel`) |
| Data | `addxp` | `<player> <xp>` | Tester | XP +/- (never below 0) |
| Data | `setxp` | `<player> <xp>` | Tester | exact XP |
| Data | `setcredits` (setscissors) | `<player> <amount>` | Tester | exact scissors |
| Data | `addcredits` (addscissors) | `<player> <amount>` | Tester | scissors +/- (never below 0) |
| Data | `setstat` | `<player> <stat> <value>` | Tester | MatchesPlayed, Wins, Kills, Headshots, CoverKills, MeleeKills, GadgetsThrown, Rating1v1/2v2/3v3, RankedWins<mode>, RankedLosses<mode>, XP, Credits |
| Data | `give` (grant) | `<player> <item>` or `<player> <number>` | Tester | own an item (id or name, validated); a number = scissors (old `/give`) |
| Data | `take` (revoke) | `<player> <item>` | Tester | un-own; an equipped item's slot goes back to the default |
| Data | `giveall` (unlockall) | `[player]` | Tester | own every item |
| Data | `resetcooldowns` (resetcd) | `[player]` | Tester | clear the duel reward pair cooldowns (`DuelPairs`) |
| Data | `missions` (quests) | `<player> reset\|complete` | Tester | new missions now / every unclaimed mission ready to claim (Base lowered) |
| Player | `kick` | `<player> [reason]` | Admin | kick (not yourself) |
| Player | `tp` (teleport, goto) | `<player> <target>` | Tester | to a player, a pad (`1v1a`, `pad_2v2_b`), `spawn`, `hangar`, or `x,y,z`; refused for players in a duel |
| Player | `heal` | `[player]` | Tester | full health |
| Player | `kill` | `[player]` | Tester | health 0 (turns god off first) |
| Player | `respawn` (re, refresh) | `[player]` | Tester | LoadCharacter; refused in a duel |
| Player | `god` | `[player] [on\|off]` | Tester | invisible ForceField + heal-back, kept through respawns; attribute `AdminGod` |
| Player | `speed` (walkspeed, ws) | `[player] [n\|reset]` | Tester | WalkSpeed (lobby); attribute `AdminSpeed` (see UI request 2 for Training / duels) |
| Duel | `duelsolo` | `<on\|off> [player]` | Admin | sets player attribute `AdminDuelSolo` (admins only): a pad holding that player counts down alone, bots fill the rest, the match never pays. Live too. In Studio also sets `DuelTestSolo` |
| Duel | `listmatches` (matches, duels) | | Tester | running lobby duels: id, mode, slot, phase, score, members |
| Duel | `endmatch` (stopmatch) | `<matchId\|player>` | Admin | both sides forfeit: everyone back to the pads, nobody paid |
| Duel | `arenas` | | Tester | slots 1-6, maps + modes, in-lobby duels / solo switch |
| World | `announce` (m, say) | `<text>` | Admin | `[Server]` line + lobby toast to everyone |
| World | `pads` | | Tester | the 6 pads: mode, bay, status, NoMap |
| Debug | `cmds` (help, commands, ?) | `[command]` | Tester | list by group / one command's usage, level, aliases, description |
| Debug | `whoami` | | Tester | your level and why (+ your live level) |
| Debug | `serverinfo` (server) | | Tester | place, version, job, players, uptime, profile store, duels, audit store |
| Debug | `audit` (log) | `[n]` | Admin | last n commands on this server |
| Debug | `dump` (rawdata) | `[player] [key]` | Admin (any target) | raw profile JSON (key list without a key) |
| Debug | `simlevel` | `<none\|tester\|admin\|owner> [player]` | Studio only | pretend to be that level |
| Legacy | `scissors` | `<n>` / `set <n>` | Tester | old `/scissors` -> addcredits / setcredits on yourself |
| Legacy | `wipeweapons` | | Admin, confirm | old `/wipeweapons`: Owned + ItemXP cleared, default loadout |
| Legacy | `admin` | | Tester | old `/admin` = `cmds` |

## 6. Adding a command
Add a def to the right `scripts/admin/Commands/<Group>.lua` (or a new file there + an entry in `COMMANDS` in `fix/admin_install.lua`
and `FILES` in `tools/admin_build.py`), then `python tools/admin_build.py --run` and restart Play.
```lua
{
	name = "setkills", aliases = { "kills" }, level = "Tester", -- Owner | Admin | Tester | None
	description = "Set the Kills stat.",
	args = { { name = "player", type = "players", defaultToken = "me" }, { name = "n", type = "integer", min = 0 } },
	-- destructive = true,  confirmText = function(ctx, a) return "..." end,   studioOnly = true,   anyTarget = true (read-only)
	run = function(ctx, a)
		for _, p in a.player do ctx.Data.Set(p, { "Stats", "Kills" }, a.n); ctx.Data.Refresh(p) end
		return true, "Kills = " .. a.n   -- or false, "why it failed"; ctx.reply(line) for extra lines
	end,
},
```
- Write data only through `ctx.Data` (`Set / Increment / Read / Default / SetRanked / Refresh / FindItem / LevelOf / XPForLevel`);
  never poke attributes as the source of truth.
- `ctx`: `caller`, `level`, `levelName`, `targets`, `reply`, `Core` (`Core.Args.Players(token, ctx)`, `Core.Notify(player, text, kind)`,
  `Core.Permissions`), `Data`. Managers: `ctx.Data.Lobby("LobbyDuelManager")` (= `shared.Get`).
- Core does the level check, the Tester-self rule, the higher-level rule, confirm and audit: commands don't repeat them.

## 7. [ADMIN] edits to existing scripts
| Script | Edit | Why |
|---|---|---|
| `ServerScriptService.AdminCommands` | whole source replaced (backup `ADMIN_AdminCommands_Orig`, Disabled) | framework entry point |
| `StarterPlayerScripts.AdminFeedback` | whole source replaced (backup `ADMIN_AdminFeedback_Orig`) | escaping, kinds, `[Server]` |
| `Managers.QueueManager` `bayIsFull` | after the [DUEL] DuelTestSolo line: a pad with an `AdminDuelSolo` occupant counts down at n >= 1 | live duelsolo |
| `Managers.LobbyDuelManager` `StartMatch` | bots fill when `(IS_STUDIO and DuelTestSolo) or adminSolo` (a team member has `AdminDuelSolo`) | live duelsolo |

`fix/lobby_duels_install.lua` rewrites `LobbyDuelManager` from `scripts/duels/LobbyDuelManager.lua`: **re-run `fix/admin_install.lua`
after it** (or move the edit into the duel source). Its UNDO of QueueManager still finds its own text (the [ADMIN] line sits after it).

## 8. Tests (Play, one client "ocxa", 2026-10-16)
All through the real chat path (`RBXGeneral:SendAsync`, the same call the chat bar makes) or `AdminBindable "run"` (same Core.Run, replies
in chat). Captures (chat lines drawn by a Play-only overlay, because the MCP capture doesn't show the Roblox chat window):
`out/admin/01_hud_setlevel_addcredits.jpg`, `02_confirm_wipe_all.jpg`, `03_chat_typo_legacy_missions_announce.jpg`,
`04_permissions_selectors.jpg`, `05_duelsolo_endmatch.jpg`.
- **HUD refresh**: `;setlevel me 20` -> level badge, player list and `Level` attribute 50 -> 20 at once; `;addcredits me 1500` -> scissors
  pill 500 -> 2,000 (01). `;missions me complete` -> the Missions button badge 6 and the HUD missions ticked (03).
- **Every command on myself**: stats, setlevel, addxp, setxp, setcredits, addcredits, setstat (wins, kills, rating1v1, rankedwins2v2; bogus
  refused with the stat list), give (sniper, knife; "nothing" refused with the item list), take, giveall, resetcooldowns, missions
  reset/complete, wipe (all, level, credits; the other parts through all), `;resetcooldowns` (2 pairs cleared), `;addxp me -999999` (floors
  at 0), `;take` / `;give` of a default item refused, tp (pad 1v1a -> y 19 on the pad, hangar (112,3,0), x,y,z, spawn, "nowhere" refused), heal, kill
  (respawned 5 s later), respawn, god (TakeDamage(50) -> 100/100, direct Health-30 -> healed back; off -> TakeDamage(40) -> 60), speed
  (40 on the server and the client in the lobby; reset -> 16), kick me (refused: not yourself), duelsolo, listmatches, arenas, endmatch,
  announce (chat line + toast), pads, cmds / help, whoami, serverinfo, audit, dump, simlevel, legacy /scissors, /scissors set, /give
  ocxa 250, /unlockall, /wipeweapons (+confirm), /admin.
- **Wipe really resets the profile** (`;dump` before / after `;wipe me all confirm`): XP 72500 -> 0, Credits 1000 -> 500, Owned
  {Sniper} -> {}, Stats Kills 12 -> 0, Ranked {1v1 1500, 2v2 W4} -> {}, DuelPairs {-99} -> {}, Quests (completed, Base negative)
  -> freshly rolled (Base 0, unclaimed), Favorites / Settings {}; Loadout default; Passes / Receipts untouched.
- **Confirm flow** (02): `;wipe me all confirm` with nothing pending -> refused; `;wipe me all` -> "This will wipe all of ocxa. To go
  ahead type: ;wipe me all confirm (within 10 s)"; then `... confirm` -> wiped. Expiry: `;wipe me level`, 11 s wait, `... confirm` ->
  "That confirm came too late (over 10 s)".
- **Selectors**: `all` (1 player) ok; `others` with one player -> "matches nobody: you're the only player here"; `@281164661` ok;
  `@123` -> no such id; prefix `oc` and display-name prefix `DEB` ok; `zzz` refused; `me,ocxa` deduped to one; `;wipe all stats` as Owner
  -> confirm prompt; as Admin -> "on several players is Owner only".
- **Arguments**: missing, non-number, 2.5 for an integer, extra tokens, bad boolean, unknown command: each a clear line with the usage.
- **Permission denial** (04, `;simlevel`): Tester -> `;wipe` / `;kick` / `;duelsolo` / `;audit` "needs Admin (you are Tester)", `;setlevel me 3`
  allowed; Admin -> multi-target wipe refused, own wipe asks confirm; None -> "You're not allowed to use admin commands." for chat
  and for `AdminRemote run`; `;simlevel owner` restores.
- **Typo guard** (03): `;sttas me` -> "unknown command" and not delivered as chat; `hello ;)` is normal chat.
- **Panel remote**: `whoami` Owner, `commands` 35 defs with usage, `run ";setcredits me 777"` ok (HUD 777).
- **duelsolo live path** (05): `DuelTestSolo` cleared, only `AdminDuelSolo` set -> standing on Pad_1v1_A started D1 (ocxa vs TestBot)
  in 5 s; with `;duelsolo off` the same pad did not count down in 14 s (`StudioSoloStart` is false), so the QueueManager edit is what
  starts it. `;tp` / `;respawn` refused while in the duel; `;endmatch D1` / `;endmatch ocxa` -> back at the pad, slot freed, no errors.
- **UNDO** round trip (section 1).

## 9. Not tested / limits
- **Persistence**: Studio's ProfileService has no API access ("data will not be saved"), so every write was checked in the live profile
  table + replica only, not across a rejoin. The writes are the same `replica:SetValue` calls the shop and rewards use. The audit
  DataStore copy is untested for the same reason (it switches itself off in Studio).
- Group-rank levels (no second account in the group to test with); `GetRankInGroup` for the owner is assumed 255 (the explicit list
  covers Edward anyway).
- Multi-player cases: targeting another player, the higher-level rule, `others` with 2+ players, kick of a real player, notifications to
  targets, the held-back typo not reaching other clients. All coded, one client only.
- `speed` in Training / duels: `MovementController` sets WalkSpeed every frame there (UI request 2).
- `AutoLevel` puts Edward's account back to level >= 50 on every join (LobbyConfig), so a level wipe on ocxa lasts one session.

## 10. Match place (later; 331cb3a0 read-only today)
Drop in the same `AdminFramework` folder, `AdminCommands` Script and `AdminFeedback` LocalScript (the install script's NEW / REPLACE parts,
without the two lobby [ADMIN] edits). What differs there:
- **No PlayerStore and no LobbyConfig.** DataAdapter already falls back to `DataManager.DataReplicas[player]:SetValue` and
  `Config.AccountLevels` (keep it equal to LobbyConfig's curve). The match place's `DataManager` has no "already running" guard, which
  is fine: the admin Script runs in the same VM and gets the same module.
- Its `Template` is empty (only `ProfileVersion`), so wipes use DataAdapter's built-in lobby defaults. Ranked entries there are
  `{Rating, Played, Wins}`; `setstat rating1v1` keeps whatever keys exist.
- **Items**: no catalogue -> `give` / `take` / `giveall` answer "this place has no item catalogue". Port `LobbyConfig.Items` (or a small
  ItemCatalog module) to enable them.
- **Missions**: `missions complete` needs `LobbyConfig.Quests` (refused there); `reset` works (the lobby re-rolls on the next join).
- **Duel commands** need equivalents on `RoundManager` (match state lives on ReplicatedStorage attributes): `endmatch` -> end the
  server's match, `listmatches` -> the one match, `duelsolo` -> its `StudioSolo` path made admin-gated. They answer "this place has no
  lobby duels" until then. `tp` pads / spawn names: add the match spawns.
- `announce`'s toast uses `Events.Lobby.Notify` when present; the chat line works anywhere.
- Same group, same explicit list, same DataStore name for the audit (one experience).


**Confirmed by Edward (2026-10-16):** his account is ocxa (user id 281164661); it is the Owner. The username "debits" (63563472) is someone else.
