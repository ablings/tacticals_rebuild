# Admin framework survey (2026-10-16, read-only, Studio 8ef4e21a + match place ref 331cb3a0)

Facts the admin framework (`notes/admin_framework.md`) is built on.

## 1. Existing admin-like code
| Thing | Where | What it did |
|---|---|---|
| `ServerScriptService.AdminCommands` (Script, 7115 chars) | lobby | Chat commands `/scissors [set] n`, `/give <name> n` (scissors), `/wipeweapons`, `/unlockall`, `/admin`. Admin = Studio, `ADMIN_IDS {281164661}`, or group rank 255 of `game.CreatorId` when the creator is a group (0 in a local file, so only the list worked). One `TextChatCommand` per command in `TextChatService.AdminCommands`; client forwards via `ReplicatedStorage.AdminRequest` (RemoteEvent, text <= 80, 0.3 s rate limit); replies via `ReplicatedStorage.AdminFeedback` (RemoteEvent `msg, good`). Wrote through `PlayerStore`. Now replaced (backup `ServerStorage._RebuildRemoved.ADMIN_AdminCommands_Orig`). |
| `StarterPlayerScripts.AdminFeedback` (LocalScript) | lobby | Hooks the TextChatCommands, `RBXSystem:DisplaySystemMessage` teal/red `[Admin]`. Replaced (backup `ADMIN_AdminFeedback_Orig`). |
| `ServerStorage._Pre43.AdminCommands` | lobby | An older copy (pass 43); ServerStorage, never runs. |
| `ServerStorage._DevTools` | lobby | Not admin: AnimTools / LobbyMerge modules, material archive, source backups (`DataManager_pre_guard` ...), scissors models. |
| `LobbyManager` `DevAddStat` handler | lobby | Studio only: `Request:InvokeServer("DevAddStat", stat, n)` -> `PlayerStore.AddStat`. Kept. |
| `LobbyManager` BuyRobux / BuyPass | lobby | Studio with product / pass id 0 grants a "TEST purchase". Kept. |
| `LobbyDuelManager` test hooks | lobby | Studio only: `_TestSolo(player, mode)`, `_TestBots(mode)`, `_TestKill`, `_TestForfeit(matchId, side)` (not Studio-gated), `_matches`, `_slots`; `ServerStorage.DuelTestHook` BindableFunction (`bots / kill / forfeit / config / removing / shot / explode / door / spawnlog / reward / matches`). |
| `DuelTestSolo` | lobby | `ReplicatedStorage` attribute. `QueueManager.bayIsFull` (`IS_STUDIO and DuelTestSolo and n >= 1`) lets one player start a pad; `LobbyDuelManager.StartMatch` fills empty places with test bots (`IS_STUDIO and DuelTestSolo`), `match.hasBot` -> `award()` pays nothing. Studio only before this pass. |
| `LobbyConfig.StudioSoloStart` | lobby | false (a Studio pad with 1 player in the server would otherwise start alone). |
| `LobbyConfig.AutoLevel = { [281164661] = 50 }` | lobby | `DataManager.PlayerAdded` raises that account's XP to level 50 on every load. A `;wipe level` on Edward therefore lasts until his next join. |
| Match place | 331cb3a0 | No admin script. `RoundManager` has a Studio solo path (`StudioSolo = true` when the place is played alone in Studio). |

## 2. Accounts and group
- Edward = user **ocxa, id 281164661**, display name **"debits"** (seen in Play: nameplate "debits @ocxa"). He owns the group.
- The separate account whose *username* is "debits" is **63563472**: not Edward, not in the group. Not given any level.
- Owning group **"gunsy funsy", id 102028987** (owner ocxa). Roles readable through `GroupService:GetGroupInfoAsync`: Member (1), Admin (254); the owner is rank 255. `GetGroupsAsync(281164661)` reports rank 1 for gunsy funsy (the API lists the owner oddly), so the explicit list is what makes Edward Owner today.
- `game.CreatorId` / `CreatorType` are 0 / User in the local file; in the published place the creator is the group, so the framework uses `game.CreatorId` when it's a group and falls back to 102028987.

## 3. Data layer (lobby)
- `ServerScriptService.Data.DataManager`: ProfileService store `gameStore` (`studioStore` in Studio), key `Player_<userId>`, `profile:Reconcile()` with `DataManager.Template`; one `ReplicaService` replica per player (class `PlayerProfile_<userId>`, data = the profile table, replicated to that player only). Guard: only the first copy loads profiles (`ServerScriptService` attribute `DataManagerOwner`), so the admin Script must require the same module instance (same VM: fine; the MCP's own VM is not).
- `ServerScriptService.Data.PlayerStore`: `Wait / Get / Set(path, v) / Increment / Credits / Spend / Owns / Grant / AddStat / Loadout / ApplyLoadoutAttributes`. Every write is `replica:SetValue(path, v)`: the replica writes the profile table (so ProfileService saves it) and replicates the change.
- `SessionData.GetData` (polls DataManager). `Leaderstats` makes empty `DataFolder` and `leaderstats` folders: **there are no leaderstats values**.
- Template fields: `Credits` 500 (scissors), `Owned {}`, `Loadout {Weapon Pistol, Gadget Smoke, Melee Fists}`, `Stats {MatchesPlayed, Wins, Kills, Headshots, CoverKills, MeleeKills, GadgetsThrown}`, `Quests {Daily, Weekly = {Key, List = {Id, Base, Claimed}}}`, `XP`, `Favorites`, `ItemXP {[item] = xp}`, `Ranked {[mode] = {Rating, Wins, Losses}}`, `Passes`, `Receipts`, `Settings`, `RedeemedCodes`, `ProfileVersion`.
  Not in the template but written: `DuelPairs {["<opponent ids>"] = os.time()}` (lobby duel reward cooldown, `LobbyDuelManager.rewardMark`), `TutorialDone` (set by the tutorial place).
- The match place writes `Ranked[mode] = {Rating, Played, Wins}` (different keys from the lobby template's `Losses`); both sides read only `Rating`.
- Missions = `Quests`: progress = `Stats[q.Stat] - entry.Base`; claimable when >= `Goal`. `LobbyManager.EnsureQuests(player)` rolls new ones when `Key` isn't the current day / week (every 30 s for everyone online).
- Items: `LobbyConfig.Items` (12: Pistol, Fists, Smoke are `Default`; AutoRifle, MiniUzi, Revolver, SemiAuto, SilencedPistol, Sniper, Knife, Flash, Frag).
- Settings: `LobbyManager` `SaveSettings` handler -> `SettingsConfig.Sanitize`.

## 4. Level curve
`LobbyConfig.AccountLevels = { First = 400, Step = 150, Max = 999 }`: level 1 -> 2 costs 400 XP, each next level 150 more. `AccountLevel(xp)` -> level, xp into it, xp for the next; `XPForLevel(n)` = total XP to reach n (L2 400, L20 33,250, L50 196,000). Ranked unlocks at 50 (`RankedLevel`, any level in Studio). Gun levels: `ItemLevels { First 250, Step 100, Max 50 }` on `ItemXP`.
The match place has no LobbyConfig; its RoundManager adds XP directly to the profile.

## 5. What refreshes the UI after a data change
- Client `Registry.PlayerData` holds the replica; `LobbyHudController` (`replica:ListenToRaw -> refresh`) and `LobbyUIController` (`ListenToRaw -> LobbyUI.Refresh`) redraw scissors, level, missions, kit on **any** replica write. So a `PlayerStore.Set` is enough; no remote is needed.
- `PublicStats` (server, every 2 s) copies `Level` and `Wins` to player attributes (nameplates, player list, pad slots). The framework also sets them at once after a write.
- `PlayerStore.ApplyLoadoutAttributes` -> `KitWeapon / KitGadget / KitMelee` attributes (gameplay reads these).
- Toasts: `ReplicatedStorage.Events.Lobby.Notify` (RemoteEvent `text, kind`), `LobbyRemotes.Notify / NotifyAll`.

## 6. Other facts used
- `MovementController` (client, [SET]) drives `WalkSpeed` every frame only while the combat client is on (Training / duels); in the lobby a server-set WalkSpeed sticks (checked: 40 on the client).
- Every damage path (`CombatManager`, `MeleeManager`, `ArenaShootables`) uses `Humanoid:TakeDamage`, which a ForceField blocks.
- Chat: TextChatService with default channels `RBXGeneral` / `RBXSystem`, created a moment after server start. No script sets `ShouldDeliverCallback`; `VipChatTag` sets the client `OnIncomingMessage`.
- `shared.Get(name)` (ModuleLoader) returns the running managers (LobbyManager, LobbyDuelManager, ...) to any server Script.
- Studio: ProfileService "API services unavailable - data will not be saved"; DataStores need a published place.
