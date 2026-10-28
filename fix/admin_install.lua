-- admin_install.lua : admin command framework (notes/admin_framework.md), 2026-10-16. Tacticals_rebuild.rbxl (studio 8ef4e21a). Idempotent.
-- Sources in scripts/admin/ (embedded below by tools/admin_build.py - edit those files, then rebuild):
--   ServerScriptService.AdminFramework (Folder): Config, Permissions, Args, DataAdapter, Audit, Core + Commands/{Data, Player, Duel,
--   World, Debug, Legacy}  (new)
--   ServerScriptService.AdminCommands (Script): source REPLACED by the framework's entry point (original backed up once as
--   ServerStorage._RebuildRemoved.ADMIN_AdminCommands_Orig, Disabled)
--   StarterPlayer.StarterPlayerScripts.AdminFeedback (LocalScript): source REPLACED (backup ADMIN_AdminFeedback_Orig, Disabled)
-- [ADMIN] edits (string swap; UNDO swaps back; backups ADMIN_<name>_Orig taken before the first edit):
--   QueueManager.bayIsFull: a pad with an AdminDuelSolo player counts down alone (live too)
--   LobbyDuelManager.StartMatch: test bots also fill matches that include an AdminDuelSolo player
--   NOTE: fix/lobby_duels_install.lua rewrites LobbyDuelManager from scripts/duels/: re-run this install after it.
-- Runtime only (made by AdminCommands at server start): ReplicatedStorage.AdminFeedback / AdminRequest / AdminRemote,
--   TextChatService.AdminCommands (TextChatCommands), ServerStorage.AdminBindable.
-- UNDO: python tools/run_luau.py fix/admin_install.lua UNDO
local UNDO = false --@UNDO

local SS = game:GetService("ServerStorage")
local SSS = game:GetService("ServerScriptService")
local SP = game:GetService("StarterPlayer")
local CHS = game:GetService("ChangeHistoryService")
local rec = CHS:TryBeginRecording("Admin framework install" .. (UNDO and " UNDO" or ""))
local bin = SS:FindFirstChild("_RebuildRemoved") or Instance.new("Folder")
bin.Name = "_RebuildRemoved"; bin.Parent = SS
local log = {}
local function say(...) local t = {} for _, v in ipairs({ ... }) do table.insert(t, tostring(v)) end table.insert(log, table.concat(t, " ")) end
local function managers()
	local init = SSS:FindFirstChild("ServerScripts") and SSS.ServerScripts:FindFirstChild("[Server] Init")
	return init and init:FindFirstChild("GameManager") and init.GameManager:FindFirstChild("Managers")
end

local SOURCES = {}
--@@BEGIN SOURCES
SOURCES.Config = [=[-- ServerScriptService/AdminFramework/Config (ModuleScript): who is an admin and how the framework behaves.
-- Shared by the lobby and the match place (notes/admin_framework.md). Server only: never put this in ReplicatedStorage.
--
-- Levels (highest wins): Owner > Admin > Tester > None. A player's level is the best of:
--   * Users[userId] below (explicit list);
--   * their rank in the owning group (GroupRanks: rank >= the number gives that level);
--   * Studio: always StudioLevel (Owner), unless a Studio-only simulated level is set (`;simlevel`, AdminBindable "simlevel").
-- Every check runs on the server; the client only sends text.
local Config = {}

Config.Prefix = ";"            -- chat prefix for every command (";setlevel me 20")
Config.LegacyPrefix = "/"      -- the old AdminCommands names keep working with "/" (/scissors, /give, /wipeweapons, /unlockall, /admin)

-- the group that owns Tacticals: "gunsy funsy" (owner ocxa). In a published game game.CreatorId is used when the
-- creator is a group; this id is the fallback for local files (CreatorId 0) and Studio.
Config.GroupId = 102028987
Config.GroupRanks = {
	Owner = 255,  -- group owner
	Admin = 254,  -- the group's "Admin" role
	-- Tester = 200, -- uncomment and create a Tester role at this rank to grant Tester by group rank
}

-- explicit list: [userId] = "Owner" | "Admin" | "Tester"
Config.Users = {
	[281164661] = "Owner", -- Edward: username ocxa, display name "debits"; owner of gunsy funsy
	-- NOT 63563472: that is a different account whose username is "debits" (checked 2026-10-16)
}

Config.StudioLevel = "Owner"
Config.ConfirmWindow = 10      -- seconds to repeat a destructive command with "confirm"
Config.RateLimit = 0.25        -- seconds between commands per player
Config.MaxTextLength = 200
Config.GroupCacheTime = 120    -- seconds a group rank lookup is trusted

-- audit log: last AuditMemory entries in memory; a capped copy in a DataStore (skipped quietly where DataStores fail, e.g. Studio)
Config.AuditMemory = 200
Config.AuditStore = "AdminAudit_v1"
Config.AuditStoreCap = 100
Config.AuditFlushEvery = 30

-- level curve used when the place has no LobbyConfig (the match place): must match LobbyConfig.AccountLevels
Config.AccountLevels = { First = 400, Step = 150, Max = 999 }

return Config
]=]
SOURCES.Permissions = [=[-- ServerScriptService/AdminFramework/Permissions (ModuleScript): admin levels, decided on the server only.
--   Permissions.LevelOf(player) -> number, why     (0 None, 1 Tester, 2 Admin, 3 Owner; console = Owner)
--   Permissions.Name(n) / Permissions.Value("Admin")
--   Permissions.SetSimulated(userId, "None"|"Tester"|"Admin"|"Owner"|nil)   Studio only: pretend to be that level
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Config = require(script.Parent.Config)

local IS_STUDIO = RunService:IsStudio()
local Permissions = {}

local VALUES = { None = 0, Tester = 1, Admin = 2, Owner = 3 }
local NAMES = { [0] = "None", [1] = "Tester", [2] = "Admin", [3] = "Owner" }
Permissions.Values = VALUES
Permissions.Names = NAMES

function Permissions.Value(name: string?): number
	return VALUES[name or ""] or 0
end
function Permissions.Name(n: number): string
	return NAMES[n] or "None"
end
function Permissions.Parse(token: string?): string?
	if not token then return nil end
	local t = string.lower(token)
	for name in VALUES do if string.lower(name) == t then return name end end
	return nil
end

local function groupId(): number
	if game.CreatorType == Enum.CreatorType.Group and game.CreatorId ~= 0 then return game.CreatorId end
	return Config.GroupId or 0
end
Permissions.GroupId = groupId

local rankCache = {} -- [userId] = { rank, t }
local function groupRank(player: Player): number
	local gid = groupId()
	if gid == 0 or player.UserId <= 0 then return 0 end
	local c = rankCache[player.UserId]
	if c and os.clock() - c.t < (Config.GroupCacheTime or 120) then return c.rank end
	local ok, rank = pcall(player.GetRankInGroup, player, gid)
	rank = ok and tonumber(rank) or (c and c.rank) or 0
	rankCache[player.UserId] = { rank = rank, t = os.clock() }
	return rank
end
Players.PlayerRemoving:Connect(function(p) rankCache[p.UserId] = nil end)

-- the level a player really has (ignores Studio)
local function realLevel(player: Player): (number, string)
	local best, why = 0, "not on the admin list"
	local listed = Config.Users[player.UserId]
	if listed and VALUES[listed] then best, why = VALUES[listed], "admin list" end
	local rank = groupRank(player)
	for name, need in Config.GroupRanks or {} do
		if rank >= need and VALUES[name] > best then best, why = VALUES[name], ("group rank %d"):format(rank) end
	end
	return best, why
end

function Permissions.LevelOf(player: any): (number, string)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then return VALUES.Owner, "server console" end
	if IS_STUDIO then
		local sim = ServerStorage:GetAttribute("AdminSim_" .. player.UserId)
		if type(sim) == "string" and VALUES[sim] then return VALUES[sim], "Studio simulated level" end
		return VALUES[Config.StudioLevel] or VALUES.Owner, "Studio test"
	end
	return realLevel(player)
end
Permissions.RealLevel = realLevel

-- Studio only: pretend `userId` has `levelName` (nil = back to normal). The attribute lives in ServerStorage (server only).
function Permissions.SetSimulated(userId: number, levelName: string?): (boolean, string?)
	if not IS_STUDIO then return false, "simulated levels exist only in Studio" end
	if levelName ~= nil and not VALUES[levelName] then return false, "unknown level " .. tostring(levelName) end
	ServerStorage:SetAttribute("AdminSim_" .. userId, levelName)
	return true
end

return Permissions
]=]
SOURCES.Args = [=[-- ServerScriptService/AdminFramework/Args (ModuleScript): typed argument parsing for admin commands.
-- A command declares args = { { name = "player", type = "players" }, { name = "n", type = "integer", min = 1, optional = true, default = 1 } }.
-- Types:
--   players   one or more players: me, all, others, @userid, a name / display-name prefix, or a comma list ("me,bob")
--   player    exactly one player (same selectors)
--   number, integer (min / max), boolean (on/off, true/false, yes/no, 1/0), string, rest (the rest of the line)
--   choice    one of `choices` (case-insensitive)
--   item      an item id or name from the catalogue (LobbyConfig.Items), validated
--   stat      a stat setstat can change (DataAdapter.StatList), validated
--   level     None / Tester / Admin / Owner
-- Errors are plain sentences the caller sees in chat.
local Players = game:GetService("Players")
local DataAdapter = require(script.Parent.DataAdapter)
local Permissions = require(script.Parent.Permissions)

local Args = {}

-- split on spaces, keep "quoted strings" together
function Args.Tokenize(text: string): { string }
	local out = {}
	local i, n = 1, #text
	while i <= n do
		local c = string.sub(text, i, i)
		if c == " " or c == "\t" then
			i += 1
		elseif c == '"' then
			local j = string.find(text, '"', i + 1, true) or (n + 1)
			table.insert(out, string.sub(text, i + 1, j - 1))
			i = j + 1
		else
			local j = string.find(text, "[ \t]", i) or (n + 1)
			table.insert(out, string.sub(text, i, j - 1))
			i = j
		end
	end
	return out
end

local function names(list)
	local t = {}
	for _, p in list do table.insert(t, p.Name) end
	return table.concat(t, ", ")
end

local function onePart(part: string, ctx): ({ Player }?, string?)
	local t = string.lower(part)
	local caller = ctx.caller
	if t == "me" then
		if not caller then return nil, "\"me\" needs a player (the server console has none)" end
		return { caller }
	elseif t == "all" or t == "everyone" then
		return Players:GetPlayers()
	elseif t == "others" then
		local list = {}
		for _, p in Players:GetPlayers() do if p ~= caller then table.insert(list, p) end end
		if #list == 0 then return nil, "\"others\" matches nobody: you're the only player here" end
		return list
	elseif string.sub(t, 1, 1) == "@" then
		local id = tonumber(string.sub(t, 2))
		if not id then return nil, ("\"%s\" isn't a user id (use @12345)"):format(part) end
		local p = Players:GetPlayerByUserId(id)
		if not p then return nil, ("no player with user id %d in this server"):format(id) end
		return { p }
	end
	local exact, partial = {}, {}
	for _, p in Players:GetPlayers() do
		local n, d = string.lower(p.Name), string.lower(p.DisplayName)
		if n == t or d == t then table.insert(exact, p)
		elseif string.sub(n, 1, #t) == t or string.sub(d, 1, #t) == t then table.insert(partial, p) end
	end
	local list = #exact > 0 and exact or partial
	if #list == 0 then return nil, ("no player here matches \"%s\""):format(part) end
	if #list > 1 then return nil, ("\"%s\" matches %s: type more of the name"):format(part, names(list)) end
	return list
end

-- returns players, multi (true when the selector can mean several: all / others / a list)
function Args.Players(token: string, ctx): ({ Player }?, string?, boolean?)
	local out, seen, multi = {}, {}, false
	for part in string.gmatch(token, "[^,]+") do
		local t = string.lower(part)
		if t == "all" or t == "everyone" or t == "others" then multi = true end
		local list, err = onePart(part, ctx)
		if not list then return nil, err end
		for _, p in list do if not seen[p] then seen[p] = true; table.insert(out, p) end end
	end
	if #out == 0 then return nil, "nobody matches \"" .. token .. "\"" end
	if #out > 1 then multi = true end
	return out, nil, multi
end

local TRUE = { on = true, ["true"] = true, yes = true, ["1"] = true, enable = true, enabled = true }
local FALSE = { off = true, ["false"] = true, no = true, ["0"] = true, disable = true, disabled = true }

Args.Types = {}
Args.Types.players = function(tok, spec, ctx)
	local list, err, multi = Args.Players(tok, ctx)
	if not list then return nil, err end
	ctx.multiTarget = ctx.multiTarget or multi
	return list
end
Args.Types.player = function(tok, spec, ctx)
	local list, err = Args.Players(tok, ctx)
	if not list then return nil, err end
	if #list ~= 1 then return nil, ("%s needs exactly one player, \"%s\" is %d"):format(spec.name, tok, #list) end
	return list[1]
end
Args.Types.number = function(tok, spec)
	local n = tonumber(tok)
	if not n or n ~= n or n == math.huge or n == -math.huge then return nil, ("%s must be a number, not \"%s\""):format(spec.name, tok) end
	if spec.min and n < spec.min then return nil, ("%s must be at least %s"):format(spec.name, spec.min) end
	if spec.max and n > spec.max then return nil, ("%s must be at most %s"):format(spec.name, spec.max) end
	return n
end
Args.Types.integer = function(tok, spec)
	local n, err = Args.Types.number(tok, spec)
	if not n then return nil, err end
	if n ~= math.floor(n) then return nil, ("%s must be a whole number, not \"%s\""):format(spec.name, tok) end
	return n
end
Args.Types.boolean = function(tok, spec)
	local t = string.lower(tok)
	if TRUE[t] then return true end
	if FALSE[t] then return false end
	return nil, ("%s must be on or off, not \"%s\""):format(spec.name, tok)
end
Args.Types.string = function(tok) return tok end
Args.Types.rest = function(tok) return tok end -- Parse already joined the rest of the line
Args.Types.choice = function(tok, spec)
	local t = string.lower(tok)
	for _, c in spec.choices do if string.lower(c) == t then return c end end
	return nil, ("%s must be one of %s, not \"%s\""):format(spec.name, table.concat(spec.choices, " | "), tok)
end
Args.Types.item = function(tok)
	local id, err = DataAdapter.FindItem(tok)
	if not id then return nil, err end
	return id
end
Args.Types.stat = function(tok)
	local s = DataAdapter.FindStat(tok)
	if not s then return nil, ("no stat \"%s\". Stats: %s"):format(tok, table.concat(DataAdapter.StatList(), ", ")) end
	return s
end
Args.Types.level = function(tok, spec)
	local name = Permissions.Parse(tok)
	if not name then return nil, ("%s must be None, Tester, Admin or Owner"):format(spec.name) end
	return name
end

function Args.Usage(def): string
	local bits = { (def.prefix or ";") .. def.name }
	for _, a in def.args or {} do
		local label = a.name
		if a.type == "choice" then label = table.concat(a.choices, "|") end
		table.insert(bits, a.optional and ("[" .. label .. "]") or ("<" .. label .. ">"))
	end
	return table.concat(bits, " ")
end

-- tokens (without the command name) -> values (by name and by index) or nil, error
function Args.Parse(def, tokens: { string }, ctx)
	local values, specs = {}, def.args or {}
	local i = 1
	for idx, spec in specs do
		local tok = tokens[i]
		if spec.type == "rest" then
			if i <= #tokens then
				tok = table.concat(tokens, " ", i)
				i = #tokens + 1
			end
		else
			i += 1
		end
		local v
		if (tok == nil or tok == "") and spec.defaultToken then tok = spec.defaultToken end -- e.g. "me"
		if tok == nil or tok == "" then
			if not spec.optional then return nil, ("missing %s. Usage: %s"):format(spec.name, Args.Usage(def)) end
			v = spec.default
			if type(v) == "function" then v = v(ctx) end
		else
			local parser = Args.Types[spec.type]
			if not parser then return nil, "bad arg type " .. tostring(spec.type) end
			local err
			v, err = parser(tok, spec, ctx)
			if v == nil then return nil, err .. ". Usage: " .. Args.Usage(def) end
		end
		values[spec.name] = v
		values[idx] = v
	end
	if i <= #tokens then
		return nil, ("too many arguments (\"%s\"). Usage: %s"):format(table.concat(tokens, " ", i), Args.Usage(def))
	end
	return values
end

return Args
]=]
SOURCES.DataAdapter = [=[-- ServerScriptService/AdminFramework/DataAdapter (ModuleScript): the only way admin commands touch saved data.
-- Lobby: every write goes through Data.PlayerStore (Replica:SetValue -> the client's copy updates at once, the HUD listens
-- with ListenToRaw, and ProfileService saves it). Match place (no PlayerStore / LobbyConfig): the same writes go straight to
-- DataManager.DataReplicas[player]:SetValue, the level curve comes from Config.AccountLevels and items are unavailable.
-- Never pokes attributes as the source of truth; attributes (Level, Wins, Kit*) are only refreshed after a write.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Config = require(script.Parent.Config)

local DA = {}

local function try(f)
	local ok, v = pcall(f)
	return ok and v or nil
end
local dataFolder = ServerScriptService:FindFirstChild("Data")
local PlayerStore = dataFolder and dataFolder:FindFirstChild("PlayerStore") and try(function() return require(dataFolder.PlayerStore) end)
local DataManager = dataFolder and dataFolder:FindFirstChild("DataManager") and try(function() return require(dataFolder.DataManager) end)
local Template = DataManager and dataFolder.DataManager:FindFirstChild("Template") and try(function() return require(dataFolder.DataManager.Template) end)
local cfgFolder = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("Shared")
	and ReplicatedStorage.Modules.Shared:FindFirstChild("Config")
local LobbyConfig = cfgFolder and cfgFolder:FindFirstChild("LobbyConfig") and try(function() return require(cfgFolder.LobbyConfig) end)
local MatchConfig = cfgFolder and cfgFolder:FindFirstChild("MatchConfig") and try(function() return require(cfgFolder.MatchConfig) end)

DA.HasPlayerStore = PlayerStore ~= nil
DA.HasCatalogue = LobbyConfig ~= nil and type(LobbyConfig.Items) == "table"
DA.StoreKey = DataManager and DataManager.key or "?"

-- the lobby template's defaults (used when the place's Template lacks a key, e.g. the match place's empty template)
local DEFAULTS = {
	Credits = 500,
	Owned = {},
	Loadout = { Weapon = "Pistol", Gadget = "Smoke", Melee = "Fists" },
	Stats = { MatchesPlayed = 0, Wins = 0, Kills = 0, Headshots = 0, CoverKills = 0, MeleeKills = 0, GadgetsThrown = 0 },
	Quests = { Daily = { Key = "", List = {} }, Weekly = { Key = "", List = {} } },
	XP = 0, Favorites = {}, ItemXP = {}, Ranked = {}, Settings = {}, RedeemedCodes = {}, DuelPairs = {},
}

local function deepCopy(v)
	if type(v) ~= "table" then return v end
	local t = {}
	for k, x in v do t[k] = deepCopy(x) end
	return t
end
DA.Copy = deepCopy

-- a fresh copy of the default value of a top-level profile key
function DA.Default(key: string)
	if Template and Template[key] ~= nil then return deepCopy(Template[key]) end
	return deepCopy(DEFAULTS[key])
end

function DA.Get(player: Player)
	if PlayerStore then return PlayerStore.Get(player) end
	if DataManager then return DataManager:Get(player), DataManager.DataReplicas and DataManager.DataReplicas[player] end
	return nil
end

function DA.Ready(player: Player): boolean
	local data, replica = DA.Get(player)
	return data ~= nil and replica ~= nil
end

-- path = { "Stats", "Wins" }; parents that don't exist yet are created as whole tables (Replica can't set into nil)
function DA.Set(player: Player, path: { any }, value: any): boolean
	local data, replica = DA.Get(player)
	if not data or not replica then return false end
	local t = data
	for i = 1, #path - 1 do
		local nxt = t[path[i]]
		if type(nxt) ~= "table" then
			-- build the missing branch and write it in one go
			local branch, cur = {}, nil
			cur = branch
			for j = i + 1, #path - 1 do cur[path[j]] = {}; cur = cur[path[j]] end
			cur[path[#path]] = value
			local sub = table.move(path, 1, i, 1, {})
			if PlayerStore then return PlayerStore.Set(player, sub, branch) end
			replica:SetValue(sub, branch)
			return true
		end
		t = nxt
	end
	if PlayerStore then return PlayerStore.Set(player, path, value) end
	replica:SetValue(path, value)
	return true
end

function DA.Read(player: Player, path: { any })
	local t = DA.Get(player)
	for _, k in path do
		if type(t) ~= "table" then return nil end
		t = t[k]
	end
	return t
end

function DA.Increment(player: Player, path: { any }, amount: number): number?
	local cur = tonumber(DA.Read(player, path)) or 0
	local new = cur + amount
	if not DA.Set(player, path, new) then return nil end
	return new
end

-------------------------------------------------------------------------------
-- Levels (account XP curve)
-------------------------------------------------------------------------------
local function curve()
	return (LobbyConfig and LobbyConfig.AccountLevels) or Config.AccountLevels
end
function DA.MaxLevel(): number return curve().Max end
function DA.LevelOf(xp: number?): (number, number, number)
	if LobbyConfig and LobbyConfig.AccountLevel then return LobbyConfig.AccountLevel(xp or 0) end
	local c = curve()
	xp = math.max(0, math.floor(tonumber(xp) or 0))
	local level, need = 1, c.First
	while level < c.Max and xp >= need do xp -= need; level += 1; need = c.First + (level - 1) * c.Step end
	if level >= c.Max then return c.Max, need, need end
	return level, xp, need
end
function DA.XPForLevel(level: number): number
	if LobbyConfig and LobbyConfig.XPForLevel then return LobbyConfig.XPForLevel(level) end
	local c, xp = curve(), 0
	for l = 1, math.min(level, c.Max) - 1 do xp += c.First + (l - 1) * c.Step end
	return xp
end

-------------------------------------------------------------------------------
-- Items (LobbyConfig.Items; the match place has none)
-------------------------------------------------------------------------------
function DA.Items()
	return DA.HasCatalogue and LobbyConfig.Items or {}
end
-- id, item  or nil, error. Accepts the id or the display name, any case, or an unambiguous prefix.
function DA.FindItem(token: string): (string?, any)
	if not DA.HasCatalogue then return nil, "this place has no item catalogue" end
	local t = string.lower(token)
	local hits = {}
	for id, item in LobbyConfig.Items do
		local a, b = string.lower(id), string.lower(item.Name or id)
		if a == t or b == t then return id, item end
		if string.sub(a, 1, #t) == t or string.sub(b, 1, #t) == t then table.insert(hits, id) end
	end
	if #hits == 1 then return hits[1], LobbyConfig.Items[hits[1]] end
	if #hits > 1 then table.sort(hits) return nil, ("\"%s\" matches %s"):format(token, table.concat(hits, ", ")) end
	local all = {}
	for id in LobbyConfig.Items do table.insert(all, id) end
	table.sort(all)
	return nil, ("no item \"%s\". Items: %s"):format(token, table.concat(all, ", "))
end

function DA.DefaultLoadout()
	local lo = {}
	for id, item in DA.Items() do if item.Default then lo[item.Slot] = id end end
	if next(lo) == nil then return DA.Default("Loadout") end
	return lo
end

function DA.Owns(player: Player, id: string): boolean
	local item = DA.Items()[id]
	if not item then return false end
	return item.Default == true or DA.Read(player, { "Owned", id }) == true
end

-------------------------------------------------------------------------------
-- Stats that setstat can change (discovered from the profile layout)
-------------------------------------------------------------------------------
DA.Modes = { "1v1", "2v2", "3v3" }
function DA.StatList(): { string }
	local list = {}
	local stats = DA.Default("Stats") or {}
	for k in stats do table.insert(list, k) end
	for _, k in (LobbyConfig and LobbyConfig.QuestStats or {}) do if not table.find(list, k) then table.insert(list, k) end end
	table.sort(list)
	for _, m in DA.Modes do
		table.insert(list, "Rating" .. m); table.insert(list, "RankedWins" .. m); table.insert(list, "RankedLosses" .. m)
	end
	table.insert(list, "XP"); table.insert(list, "Credits")
	return list
end
-- "wins" -> { path = {"Stats","Wins"}, name = "Wins" }; "rating1v1" -> ranked entry
function DA.FindStat(token: string)
	local t = string.lower(token)
	for _, name in DA.StatList() do
		if string.lower(name) == t then
			local mode = string.match(name, "(%dv%d)$")
			if mode then
				local field = string.match(name, "^Rating") and "Rating" or (string.match(name, "^RankedWins") and "Wins" or "Losses")
				return { name = name, ranked = mode, field = field }
			end
			if name == "XP" or name == "Credits" then return { name = name, path = { name } } end
			return { name = name, path = { "Stats", name } }
		end
	end
	return nil
end
function DA.StartingRating(): number
	return (LobbyConfig and LobbyConfig.StartingRating) or (MatchConfig and MatchConfig.StartingRating) or 1000
end
function DA.SetRanked(player: Player, mode: string, field: string, value: number): boolean
	local cur = DA.Read(player, { "Ranked", mode })
	local entry = type(cur) == "table" and deepCopy(cur) or { Rating = DA.StartingRating(), Wins = 0, Losses = 0 }
	entry[field] = value
	return DA.Set(player, { "Ranked", mode }, entry)
end

-------------------------------------------------------------------------------
-- After a write: refresh the derived attributes other scripts read (PublicStats does Level / Wins every 2 s anyway)
-------------------------------------------------------------------------------
function DA.Refresh(player: Player)
	local data = DA.Get(player)
	if not data then return end
	if PlayerStore and PlayerStore.ApplyLoadoutAttributes then pcall(PlayerStore.ApplyLoadoutAttributes, player) end
	player:SetAttribute("Level", (DA.LevelOf(data.XP or 0)))
	if type(data.Stats) == "table" then player:SetAttribute("Wins", data.Stats.Wins or 0) end
end

function DA.Lobby(name: string)
	return shared.Get and (function() local ok, m = pcall(shared.Get, name) return ok and m or nil end)() or nil
end

DA.LobbyConfig = LobbyConfig
DA.MatchConfig = MatchConfig
DA.Players = Players
return DA
]=]
SOURCES.Audit = [=[-- ServerScriptService/AdminFramework/Audit (ModuleScript): every command run (or refused) is logged.
--   Audit.Log(entry)   entry = { admin, adminId, level, command, args (text), targets (text), ok, result }
--   Audit.Recent(n)    newest first, from memory (this server)
-- Memory: the last Config.AuditMemory entries. DataStore: Config.AuditStore key "log" keeps the last AuditStoreCap entries
-- across servers, flushed every AuditFlushEvery seconds. If the DataStore can't be used (Studio without API access, outages)
-- the store is switched off for this server with one warning, and the memory log keeps working.
local DataStoreService = game:GetService("DataStoreService")
local Config = require(script.Parent.Config)

local Audit = {}
local memory = {}
local pending = {}
local storeState = "unused" -- unused | ok | off: <reason>
local store

function Audit.Log(e)
	e.time = os.time()
	e.place = game.PlaceId
	table.insert(memory, e)
	while #memory > (Config.AuditMemory or 200) do table.remove(memory, 1) end
	if not string.find(storeState, "^off") then table.insert(pending, e) end
	print(("[Admin] %s (%s) %s %s -> %s %s"):format(tostring(e.admin), tostring(e.level), tostring(e.command), tostring(e.args or ""),
		e.ok and "ok" or "refused", tostring(e.result or "")))
end

function Audit.Recent(n: number?)
	local out = {}
	for i = #memory, math.max(1, #memory - (n or 10) + 1), -1 do table.insert(out, memory[i]) end
	return out
end

function Audit.StoreState(): string return storeState end

local function flush()
	if #pending == 0 or string.find(storeState, "^off") then return end
	if not store then
		local ok, s = pcall(DataStoreService.GetDataStore, DataStoreService, Config.AuditStore)
		if not ok then storeState = "off: " .. tostring(s); warn("[Admin] audit DataStore off: " .. tostring(s)); pending = {} return end
		store = s
	end
	local batch = pending
	pending = {}
	local ok, err = pcall(store.UpdateAsync, store, "log", function(old)
		local list = type(old) == "table" and old or {}
		for _, e in batch do
			table.insert(list, { t = e.time, a = e.adminId, n = e.admin, l = e.level, c = e.command, x = e.args, g = e.targets,
				ok = e.ok, r = e.result and string.sub(tostring(e.result), 1, 120), p = e.place })
		end
		while #list > (Config.AuditStoreCap or 100) do table.remove(list, 1) end
		return list
	end)
	if ok then storeState = "ok" else storeState = "off: " .. tostring(err); warn("[Admin] audit DataStore off: " .. tostring(err)) end
end

task.spawn(function()
	while true do
		task.wait(Config.AuditFlushEvery or 30)
		flush()
	end
end)
game:BindToClose(function() pcall(flush) end)

return Audit
]=]
SOURCES.Core = [=[-- ServerScriptService/AdminFramework/Core (ModuleScript): command registry and dispatcher (notes/admin_framework.md).
--   Core.LoadCommands(folder)        require every ModuleScript in Commands/ (each returns a list of command defs)
--   Core.Run(caller, text, source)   -> { ok, lines = {...}, command }   caller = Player, or nil for the server console
--   Core.Visible(level)              -> command defs this level may run (help / admin panel)
-- A command def:
--   { name = "setlevel", aliases = { "level" }, group = "Data", level = "Tester", description = "...",
--     args = { { name = "player", type = "players", defaultToken = "me" }, { name = "level", type = "integer", min = 1 } },
--     destructive = true?,        -- needs "<same command> confirm" within Config.ConfirmWindow s; on several players Owner only
--     studioOnly = true?,         -- refused outside Studio
--     place = "lobby" | "match"?,  -- only registered in that place (Core.Place: "lobby" when Workspace.LobbyMap exists)
--     run = function(ctx, args) ... return true, "message" | false, "error" end }
--   ctx = { caller, level (number), levelName, source, targets (players parsed), reply(line), Core, Data (DataAdapter) }
-- Rules applied here, never by a command: level check, Testers may only target themselves, nobody targets a player
-- with a higher level, the confirm token, the audit log.
local RunService = game:GetService("RunService")
local Config = require(script.Parent.Config)
local Permissions = require(script.Parent.Permissions)
local Args = require(script.Parent.Args)
local Audit = require(script.Parent.Audit)
local DataAdapter = require(script.Parent.DataAdapter)

local IS_STUDIO = RunService:IsStudio()
local Core = { Commands = {}, ByName = {}, Groups = {} }
-- which place this server is: the lobby (Workspace.LobbyMap) or the match / tutorial place (notes/match_place_flow.md)
Core.Place = workspace:FindFirstChild("LobbyMap") and "lobby" or "match"
Core.Permissions, Core.Args, Core.Audit, Core.Data, Core.Config = Permissions, Args, Audit, DataAdapter, Config

-- Core.Notify(player, text, kind) shows a line in that player's chat; set by the AdminCommands script (kind: true/false/"info"/"announce")
Core.Notify = function(_player, text) print("[Admin] " .. tostring(text)) end

local pendingConfirm = {} -- [callerKey .. "|" .. normalised text] = os.clock()

function Core.Register(def)
	assert(type(def.name) == "string" and type(def.run) == "function", "admin command needs name + run")
	def.name = string.lower(def.name)
	def.level = def.level or "Admin"
	assert(Permissions.Values[def.level], "bad level for " .. def.name)
	def.args = def.args or {}
	def.group = def.group or "Misc"
	-- a command for the other place is left out here (help, the panel and chat never see it)
	if def.place and def.place ~= Core.Place then return end
	if Core.ByName[def.name] then warn("[Admin] duplicate command " .. def.name .. " (later one wins)") end
	table.insert(Core.Commands, def)
	Core.ByName[def.name] = def
	for _, a in def.aliases or {} do
		a = string.lower(a)
		if Core.ByName[a] and Core.ByName[a] ~= def then warn("[Admin] alias " .. a .. " of " .. def.name .. " shadows another command") end
		Core.ByName[a] = def
	end
	Core.Groups[def.group] = Core.Groups[def.group] or {}
	table.insert(Core.Groups[def.group], def)
end

function Core.LoadCommands(folder: Instance)
	local mods = folder:GetChildren()
	table.sort(mods, function(a, b) return a.Name < b.Name end)
	for _, m in mods do
		if m:IsA("ModuleScript") then
			local ok, list = pcall(require, m)
			if not ok then warn("[Admin] command module " .. m.Name .. " failed: " .. tostring(list)) continue end
			for _, def in list do
				def.group = def.group or m.Name
				local okR, err = pcall(Core.Register, def)
				if not okR then warn("[Admin] " .. m.Name .. ": " .. tostring(err)) end
			end
		end
	end
end

function Core.Visible(level: number)
	local out = {}
	for _, def in Core.Commands do
		if Permissions.Value(def.level) <= level and (not def.studioOnly or IS_STUDIO) then table.insert(out, def) end
	end
	table.sort(out, function(a, b) if a.group ~= b.group then return a.group < b.group end return a.name < b.name end)
	return out
end

function Core.Usage(def) return Args.Usage(def) end

local function playerNames(list)
	local t = {}
	for _, p in list do table.insert(t, p.Name) end
	return table.concat(t, ",")
end

-- caller: Player or nil (console). opts.forceLevel (console bindable), opts.me (who "me" is for the console)
function Core.Run(caller: Player?, text: string, source: string?, opts)
	opts = opts or {}
	local lines = {}
	local result = { ok = false, lines = lines }
	if type(text) ~= "string" then table.insert(lines, "bad command text") return result end
	text = string.gsub(text, "^%s+", "")
	text = string.gsub(text, "%s+$", "")
	local prefix = string.sub(text, 1, 1)
	if prefix == Config.Prefix or prefix == Config.LegacyPrefix then text = string.sub(text, 2) end
	local tokens = Args.Tokenize(text)
	local name = string.lower(table.remove(tokens, 1) or "")
	local def = Core.ByName[name]
	local level, why = Permissions.LevelOf(caller)
	if opts.forceLevel then level, why = opts.forceLevel, "server console" end
	local levelName = Permissions.Name(level)
	local adminName = caller and caller.Name or "console"
	local function audit(ok, msg, targets)
		Audit.Log({ admin = adminName, adminId = caller and caller.UserId or 0, level = levelName, command = def and def.name or name,
			args = table.concat(tokens, " "), targets = targets, ok = ok, result = msg, source = source })
	end
	if name == "" then table.insert(lines, "type " .. Config.Prefix .. "cmds for the command list") return result end
	if not def then
		result.unknown = true
		table.insert(lines, ("unknown command \"%s\". Type %scmds for the list."):format(name, Config.Prefix))
		return result
	end
	result.command = def.name
	if level < Permissions.Value(def.level) then
		local msg = level == 0 and "You're not allowed to use admin commands." or
			("%s%s needs %s (you are %s)."):format(Config.Prefix, def.name, def.level, levelName)
		table.insert(lines, msg)
		audit(false, "denied: " .. levelName)
		return result
	end
	if def.studioOnly and not IS_STUDIO then
		table.insert(lines, Config.Prefix .. def.name .. " only works in Studio.")
		return result
	end
	-- trailing "confirm"
	local confirming = false
	if def.destructive and #tokens > 0 and string.lower(tokens[#tokens]) == "confirm" then
		confirming = true
		table.remove(tokens)
	end
	local ctx = { caller = caller, me = caller or opts.me, level = level, levelName = levelName, source = source, Core = Core,
		Data = DataAdapter, lines = lines, why = why }
	ctx.caller = caller or opts.me -- "me" for the console is opts.me
	function ctx.reply(line) table.insert(lines, tostring(line)) end
	local values, err = Args.Parse(def, tokens, ctx)
	if not values then
		table.insert(lines, err)
		audit(false, err)
		return result
	end
	-- who is targeted
	local targets = {}
	for _, spec in def.args do
		local v = values[spec.name]
		if spec.type == "players" and type(v) == "table" then for _, p in v do table.insert(targets, p) end
		elseif spec.type == "player" and v then table.insert(targets, v) end
	end
	ctx.targets = targets
	local targetText = #targets > 0 and playerNames(targets) or nil
	for _, p in targets do
		if p ~= caller then
			if caller and level < Permissions.Values.Admin and not def.anyTarget then
				local msg = ("Testers can only use %s%s on themselves."):format(Config.Prefix, def.name)
				table.insert(lines, msg); audit(false, msg, targetText); return result
			end
			local theirs = Permissions.LevelOf(p)
			if caller and theirs > level and not def.anyTarget then
				local msg = ("%s is %s, above you (%s)."):format(p.Name, Permissions.Name(theirs), levelName)
				table.insert(lines, msg); audit(false, msg, targetText); return result
			end
		end
	end
	if def.destructive then
		local several = ctx.multiTarget or #targets > 1
		if several and level < Permissions.Values.Owner then
			local msg = ("%s%s on several players is Owner only."):format(Config.Prefix, def.name)
			table.insert(lines, msg); audit(false, msg, targetText); return result
		end
		local key = (caller and caller.UserId or 0) .. "|" .. def.name .. " " .. string.lower(table.concat(tokens, " "))
		if not confirming then
			pendingConfirm[key] = os.clock()
			local what = def.confirmText and def.confirmText(ctx, values) or (def.name .. " " .. table.concat(tokens, " "))
			local again = Config.Prefix .. name .. (#tokens > 0 and (" " .. table.concat(tokens, " ")) or "") .. " confirm"
			table.insert(lines, ("This will %s. To go ahead type: %s   (within %d s)"):format(what, again, Config.ConfirmWindow))
			result.ok = true
			result.needsConfirm = true
			audit(true, "awaiting confirm", targetText)
			return result
		end
		local t = pendingConfirm[key]
		pendingConfirm[key] = nil
		if not t or os.clock() - t > Config.ConfirmWindow then
			local msg = t and "That confirm came too late (over " .. Config.ConfirmWindow .. " s). Run it again without confirm first."
				or "Nothing to confirm: run the command without confirm first."
			table.insert(lines, msg); audit(false, msg, targetText); return result
		end
	end
	local ok, a, b = pcall(def.run, ctx, values)
	if not ok then
		warn("[Admin] " .. def.name .. " failed: " .. tostring(a))
		table.insert(lines, "That command failed: " .. tostring(a))
		audit(false, "error: " .. tostring(a), targetText)
		return result
	end
	local good = a ~= false
	if type(b) == "string" then table.insert(lines, b) elseif type(a) == "string" then table.insert(lines, a) end
	result.ok = good
	audit(good, lines[#lines], targetText)
	return result
end

-- clean up stale confirm tokens now and then
task.spawn(function()
	while true do
		task.wait(30)
		for k, t in pendingConfirm do if os.clock() - t > Config.ConfirmWindow then pendingConfirm[k] = nil end end
	end
end)

return Core
]=]
SOURCES.Cmd_Data = [=[-- AdminFramework/Commands/Data: profile commands. Every write goes through DataAdapter (PlayerStore / the player's Replica),
-- so it saves with ProfileService and the HUD (LobbyHudController / LobbyUIController listen to the replica) updates at once.
local Players = game:GetService("Players")

local P = { name = "player", type = "players", defaultToken = "me" }
local WIPE_PARTS = { "all", "stats", "level", "inventory", "credits", "missions", "cooldowns", "settings" }

-- run fn(player) for every target whose data has loaded; returns the names done and the names skipped
local function each(ctx, list, fn)
	local done, skipped = {}, {}
	for _, p in list do
		if ctx.Data.Ready(p) then
			local note = fn(p)
			table.insert(done, note and (p.Name .. " " .. note) or p.Name)
			ctx.Data.Refresh(p)
		else
			table.insert(skipped, p.Name)
		end
	end
	if #skipped > 0 then ctx.reply("data not loaded yet for " .. table.concat(skipped, ", ") .. " (try again in a second)") end
	return done
end

local function tellTarget(ctx, p, text)
	if p ~= ctx.caller and ctx.Core.Notify then ctx.Core.Notify(p, "An admin " .. text, "info") end
end

local function levelLine(D, xp)
	local level, into, need = D.LevelOf(xp)
	return ("LV %d (%d XP, %d/%d to next)"):format(level, xp, into, need)
end

-- what each wipe part resets (profile keys back to their template defaults)
local function wipePart(D, p, part)
	local function reset(key) D.Set(p, { key }, D.Default(key)) end
	if part == "stats" or part == "all" then reset("Stats"); reset("Ranked") end
	if part == "level" or part == "all" then reset("XP"); reset("ItemXP") end
	if part == "inventory" or part == "all" then
		reset("Owned"); reset("Favorites"); reset("ItemXP"); D.Set(p, { "Loadout" }, D.DefaultLoadout())
	end
	if part == "credits" or part == "all" then reset("Credits") end
	if part == "missions" or part == "all" then reset("Quests") end
	if part == "cooldowns" or part == "all" then D.Set(p, { "DuelPairs" }, {}) end
	if part == "settings" or part == "all" then reset("Settings") end
	if part == "all" then reset("RedeemedCodes") end
	if part == "missions" or part == "all" then
		local LM = workspace:FindFirstChild("LobbyMap") and D.Lobby("LobbyManager") or nil
		if LM and LM.EnsureQuests then pcall(LM.EnsureQuests, p) end -- new missions at once (the lobby also re-rolls every 30 s)
	end
end

local function questSummary(data)
	local bits = {}
	for _, scope in { "Daily", "Weekly" } do
		local q = data.Quests and data.Quests[scope]
		local n, claimed = 0, 0
		for _, e in (q and q.List or {}) do n += 1; if e.Claimed then claimed += 1 end end
		table.insert(bits, ("%s %d (%d claimed)"):format(string.lower(scope), n, claimed))
	end
	return table.concat(bits, ", ")
end

return {
	{
		name = "stats", aliases = { "profile" }, level = "Tester",
		description = "Print a player's profile summary (level, XP, scissors, items, stats, ranked, missions, cooldowns).",
		args = { { name = "player", type = "player", defaultToken = "me" } },
		anyTarget = true, -- reading is harmless
		run = function(ctx, a)
			local D, p = ctx.Data, a.player
			local data = D.Get(p)
			if not data then return false, p.Name .. "'s data hasn't loaded yet" end
			local owned, total = 0, 0
			for id, item in D.Items() do total += 1; if D.Owns(p, id) then owned += 1 end end
			local s = data.Stats or {}
			ctx.reply(("%s (@%d): %s, %d scissors"):format(p.Name, p.UserId, levelLine(D, tonumber(data.XP) or 0), data.Credits or 0))
			ctx.reply(("items %d/%d owned, loadout %s / %s / %s"):format(owned, total, tostring(data.Loadout and data.Loadout.Weapon),
				tostring(data.Loadout and data.Loadout.Gadget), tostring(data.Loadout and data.Loadout.Melee)))
			local sb = {}
			for _, k in { "MatchesPlayed", "Wins", "Kills", "Headshots", "MeleeKills", "CoverKills", "GadgetsThrown" } do
				table.insert(sb, k .. " " .. tostring(s[k] or 0))
			end
			ctx.reply("stats: " .. table.concat(sb, ", "))
			local rb = {}
			for mode, r in (data.Ranked or {}) do
				if type(r) == "table" then table.insert(rb, ("%s SR %s W%s L%s"):format(mode, tostring(r.Rating), tostring(r.Wins or 0), tostring(r.Losses or 0))) end
			end
			local cd = 0
			for _ in (type(data.DuelPairs) == "table" and data.DuelPairs or {}) do cd += 1 end
			ctx.reply(("ranked: %s; missions: %s; duel reward cooldowns: %d"):format(#rb > 0 and table.concat(rb, ", ") or "none",
				questSummary(data), cd))
			return true
		end,
	},
	{
		name = "wipe", level = "Admin", destructive = true,
		description = "Reset profile data to the defaults: all, stats (Stats + Ranked), level (XP + gun XP), inventory (owned, loadout, favourites, gun XP), credits, missions, cooldowns, settings. Purchases (Passes, Receipts) and TutorialDone are never wiped.",
		args = { P, { name = "what", type = "choice", choices = WIPE_PARTS, optional = true, default = "all" } },
		confirmText = function(ctx, a)
			local names = {}
			for _, p in a.player do table.insert(names, p.Name) end
			return ("wipe %s of %s"):format(a.what, table.concat(names, ", "))
		end,
		run = function(ctx, a)
			local done = each(ctx, a.player, function(p)
				wipePart(ctx.Data, p, a.what)
				tellTarget(ctx, p, "wiped your " .. a.what .. " data.")
			end)
			return #done > 0, ("Wiped %s for %s."):format(a.what, table.concat(done, ", "))
		end,
	},
	{
		name = "setlevel", aliases = { "level" }, level = "Tester",
		description = "Set the account level: XP becomes exactly that level's threshold.",
		args = { P, { name = "level", type = "integer", min = 1 } },
		run = function(ctx, a)
			local D = ctx.Data
			local lv = math.min(a.level, D.MaxLevel())
			local xp = D.XPForLevel(lv)
			local done = each(ctx, a.player, function(p) D.Set(p, { "XP" }, xp); tellTarget(ctx, p, "set your level to " .. lv .. ".") end)
			return #done > 0, ("Level %d (%d XP) for %s."):format(lv, xp, table.concat(done, ", "))
		end,
	},
	{
		name = "addxp", level = "Tester", description = "Add (or with a negative number remove) account XP.",
		args = { P, { name = "xp", type = "integer" } },
		run = function(ctx, a)
			local D = ctx.Data
			local done = each(ctx, a.player, function(p)
				local cur = tonumber(D.Read(p, { "XP" })) or 0
				local new = math.max(0, cur + a.xp)
				D.Set(p, { "XP" }, new)
				return "-> " .. levelLine(D, new)
			end)
			return #done > 0, ("%+d XP: %s."):format(a.xp, table.concat(done, "; "))
		end,
	},
	{
		name = "setxp", level = "Tester", description = "Set account XP to an exact number.",
		args = { P, { name = "xp", type = "integer", min = 0 } },
		run = function(ctx, a)
			local D = ctx.Data
			local done = each(ctx, a.player, function(p) D.Set(p, { "XP" }, a.xp) end)
			return #done > 0, ("XP = %d (%s) for %s."):format(a.xp, levelLine(D, a.xp), table.concat(done, ", "))
		end,
	},
	{
		name = "setcredits", aliases = { "setscissors" }, level = "Tester", description = "Set scissors (Credits) to an exact amount.",
		args = { P, { name = "amount", type = "integer", min = 0 } },
		run = function(ctx, a)
			local done = each(ctx, a.player, function(p) ctx.Data.Set(p, { "Credits" }, a.amount); tellTarget(ctx, p, "set your scissors to " .. a.amount .. ".") end)
			return #done > 0, ("Scissors = %d for %s."):format(a.amount, table.concat(done, ", "))
		end,
	},
	{
		name = "addcredits", aliases = { "addscissors" }, level = "Tester", description = "Add (negative: take) scissors; never below 0.",
		args = { P, { name = "amount", type = "integer" } },
		run = function(ctx, a)
			local D = ctx.Data
			local done = each(ctx, a.player, function(p)
				local cur = tonumber(D.Read(p, { "Credits" })) or 0
				local new = math.max(0, cur + a.amount)
				D.Set(p, { "Credits" }, new)
				tellTarget(ctx, p, (a.amount >= 0 and "gave you %d scissors." or "took %d scissors."):format(math.abs(new - cur)))
				return "-> " .. new
			end)
			return #done > 0, ("%+d scissors: %s."):format(a.amount, table.concat(done, "; "))
		end,
	},
	{
		name = "setstat", level = "Tester",
		description = "Set a stat: MatchesPlayed, Wins, Kills, Headshots, CoverKills, MeleeKills, GadgetsThrown, Rating1v1/2v2/3v3, RankedWins<mode>, RankedLosses<mode>, XP, Credits.",
		args = { P, { name = "stat", type = "stat" }, { name = "value", type = "integer" } },
		run = function(ctx, a)
			local D, st = ctx.Data, a.stat
			local done = each(ctx, a.player, function(p)
				if st.ranked then D.SetRanked(p, st.ranked, st.field, a.value) else D.Set(p, st.path, a.value) end
			end)
			return #done > 0, ("%s = %d for %s."):format(st.name, a.value, table.concat(done, ", "))
		end,
	},
	{
		name = "give", aliases = { "grant" }, level = "Tester",
		description = "Give an item (id or name). Old form: ;give <player> <number> gives scissors.",
		args = { P, { name = "item", type = "string" } },
		run = function(ctx, a)
			local D = ctx.Data
			local amount = tonumber(a.item)
			if amount then -- the old AdminCommands /give name 500
				amount = math.floor(amount)
				local done = each(ctx, a.player, function(p)
					local cur = tonumber(D.Read(p, { "Credits" })) or 0
					D.Set(p, { "Credits" }, math.max(0, cur + amount))
					tellTarget(ctx, p, (amount >= 0 and "gave you %d scissors." or "took %d scissors."):format(math.abs(amount)))
				end)
				return #done > 0, ("Gave %d scissors to %s."):format(amount, table.concat(done, ", "))
			end
			local id, item = D.FindItem(a.item)
			if not id then return false, item end
			if item.Default then return false, id .. " is a default item: everyone always owns it" end
			local done = each(ctx, a.player, function(p)
				if D.Owns(p, id) then return "(already owned)" end
				D.Set(p, { "Owned", id }, true)
				tellTarget(ctx, p, "gave you " .. (item.Name or id) .. ".")
			end)
			return #done > 0, ("Gave %s to %s."):format(id, table.concat(done, ", "))
		end,
	},
	{
		name = "take", aliases = { "revoke" }, level = "Tester",
		description = "Take an item away (if it's equipped, that slot goes back to the default item).",
		args = { P, { name = "item", type = "item" } },
		run = function(ctx, a)
			local D, id = ctx.Data, a.item
			local item = D.Items()[id]
			if item.Default then return false, id .. " is a default item and can't be taken" end
			local def = D.DefaultLoadout()
			local done = each(ctx, a.player, function(p)
				if not D.Owns(p, id) then return "(didn't own it)" end
				D.Set(p, { "Owned", id }, nil)
				if D.Read(p, { "Loadout", item.Slot }) == id then D.Set(p, { "Loadout", item.Slot }, def[item.Slot]) end
				if D.Read(p, { "Favorites", id }) then D.Set(p, { "Favorites", id }, nil) end
			end)
			return #done > 0, ("Took %s from %s."):format(id, table.concat(done, ", "))
		end,
	},
	{
		name = "giveall", aliases = { "unlockall" }, level = "Tester", description = "Own every item in the catalogue.",
		args = { P },
		run = function(ctx, a)
			local D = ctx.Data
			if not D.HasCatalogue then return false, "this place has no item catalogue" end
			local done = each(ctx, a.player, function(p)
				local n = 0
				for id, item in D.Items() do
					if not item.Default and not D.Owns(p, id) then D.Set(p, { "Owned", id }, true); n += 1 end
				end
				return "+" .. n
			end)
			return #done > 0, ("Unlocked every item: %s."):format(table.concat(done, ", "))
		end,
	},
	{
		name = "resetcooldowns", aliases = { "resetcd" }, level = "Tester",
		description = "Clear the duel reward cooldowns (DuelPairs: one paid match per opponent pair per 10 min).",
		args = { P },
		run = function(ctx, a)
			local done = each(ctx, a.player, function(p)
				local n = 0
				for _ in (type(ctx.Data.Read(p, { "DuelPairs" })) == "table" and ctx.Data.Read(p, { "DuelPairs" }) or {}) do n += 1 end
				ctx.Data.Set(p, { "DuelPairs" }, {})
				return "(" .. n .. " cleared)"
			end)
			return #done > 0, "Duel reward cooldowns reset: " .. table.concat(done, ", ") .. "."
		end,
	},
	{
		name = "missions", aliases = { "quests" }, level = "Tester",
		description = "reset = new daily + weekly missions now; complete = every unclaimed mission finished (ready to claim).",
		args = { P, { name = "action", type = "choice", choices = { "reset", "complete" } } },
		run = function(ctx, a)
			local D = ctx.Data
			local LC = D.LobbyConfig
			local done = each(ctx, a.player, function(p)
				if a.action == "reset" then
					wipePart(D, p, "missions")
					return
				end
				if not LC or not LC.Quests then error("this place has no mission list") end
				local n = 0
				for _, scope in { "Daily", "Weekly" } do
					local q = D.Read(p, { "Quests", scope })
					for i, e in (type(q) == "table" and q.List or {}) do
						local def
						for _, d in LC.Quests[scope].Pool do if d.Id == e.Id then def = d end end
						if def and not e.Claimed then
							local stat = tonumber(D.Read(p, { "Stats", def.Stat })) or 0
							-- progress = Stats[stat] - Base; Base low enough that progress = Goal
							D.Set(p, { "Quests", scope, "List", i, "Base" }, stat - def.Goal)
							n += 1
						end
					end
				end
				return "(" .. n .. " ready to claim)"
			end)
			return #done > 0, ("Missions %s: %s."):format(a.action, table.concat(done, ", "))
		end,
	},
}
]=]
SOURCES.Cmd_Player = [=[-- AdminFramework/Commands/Player: kick, tp, heal, kill, respawn, god, speed.
-- Players in a lobby duel (attribute DuelMatch) are not teleported / respawned: that would break the match (;endmatch first).
local Players = game:GetService("Players")

local P = { name = "player", type = "players", defaultToken = "me" }

local function humanoidOf(p: Player)
	local c = p.Character
	return c and c:FindFirstChildOfClass("Humanoid"), c and c:FindFirstChild("HumanoidRootPart")
end

local function each(ctx, list, fn)
	local done, skipped = {}, {}
	for _, p in list do
		local ok, why = fn(p)
		if ok == false then table.insert(skipped, p.Name .. " (" .. tostring(why) .. ")") else table.insert(done, p.Name) end
	end
	if #skipped > 0 then ctx.reply("skipped " .. table.concat(skipped, ", ")) end
	if #done == 0 then table.insert(done, "nobody") end
	return done
end

-- god mode: an invisible ForceField (every damage path uses Humanoid:TakeDamage, which a ForceField blocks) plus a heal-back
local god = {}
local function applyGod(p: Player)
	local hum = humanoidOf(p)
	if not hum then return end
	local c = p.Character
	if not c:FindFirstChild("AdminGodField") then
		local ff = Instance.new("ForceField"); ff.Name = "AdminGodField"; ff.Visible = false; ff.Parent = c
	end
	if not hum:GetAttribute("AdminGodHooked") then
		hum:SetAttribute("AdminGodHooked", true)
		hum.HealthChanged:Connect(function(h)
			if god[p] and h > 0 and h < hum.MaxHealth then hum.Health = hum.MaxHealth end
		end)
	end
	hum.Health = hum.MaxHealth
end
local function removeGod(p: Player)
	local c = p.Character
	local ff = c and c:FindFirstChild("AdminGodField")
	if ff then ff:Destroy() end
end
local hooked = {}
local function hookPlayer(p: Player)
	if hooked[p] then return end
	hooked[p] = true
	p.CharacterAdded:Connect(function()
		task.wait() -- let the Humanoid exist
		if god[p] then applyGod(p) end
		local speed = p:GetAttribute("AdminSpeed")
		local hum = humanoidOf(p)
		if speed and hum then hum.WalkSpeed = speed end
	end)
end
Players.PlayerRemoving:Connect(function(p) god[p] = nil; hooked[p] = nil end)

-- tp destinations that aren't players: duel pads, the spawn, the hangar, or "x,y,z"
local function placeTarget(token: string): (CFrame?, string?)
	local t = string.lower(token)
	local map = workspace:FindFirstChild("LobbyMap")
	if t == "spawn" or t == "hub" then
		local sp = map and map:FindFirstChild("LobbySpawn")
		if sp then return sp.CFrame + Vector3.new(0, 4, 0), "the spawn" end
		local any = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
		if any then return any.CFrame + Vector3.new(0, 4, 0), "the spawn" end
		return CFrame.new(0, 10, 0), "the origin"
	elseif t == "spawna" or t == "spawnb" then
		-- the match place's team spawns (Workspace.MatchSpawns.SpawnA / SpawnB)
		local ms = workspace:FindFirstChild("MatchSpawns")
		local sp = ms and ms:FindFirstChild(string.sub(t, -1) == "a" and "SpawnA" or "SpawnB")
		if sp then return sp.CFrame + Vector3.new(0, 4, 0), sp.Name end
		return nil
	elseif t == "hangar" or t == "exfil" then
		return CFrame.new(112, 3.5, 0) * CFrame.Angles(0, -math.pi / 2, 0), "the hangar" -- LobbyFallCatch's HANGAR
	end
	local x, y, z = string.match(t, "^(%-?[%d%.]+),(%-?[%d%.]+),(%-?[%d%.]+)$")
	if x then return CFrame.new(tonumber(x), tonumber(y), tonumber(z)), ("%s,%s,%s"):format(x, y, z) end
	-- pads: Pad_1v1_A, "1v1a", "pad_2v2_b" ...
	local duels = map and map:FindFirstChild("Duels")
	local key = string.gsub(string.gsub(t, "^pad_?", ""), "_", "")
	for _, pad in (duels and duels:GetChildren() or {}) do
		if pad:IsA("Model") and pad:GetAttribute("QueueName") then
			local n = string.lower(string.gsub(string.gsub(pad.Name, "^Pad_", ""), "_", ""))
			if n == key then
				local zone = pad:FindFirstChild("Team1") or pad.PrimaryPart
				local pos = zone and zone:IsA("BasePart") and (zone.Position - Vector3.new(0, zone.Size.Y / 2 - 3, 0)) or pad:GetPivot().Position
				return CFrame.new(pos), pad.Name
			end
		end
	end
	return nil
end

return {
	{
		name = "kick", level = "Admin", description = "Kick a player from this server.",
		args = { { name = "player", type = "players" }, { name = "reason", type = "rest", optional = true, default = "Kicked by an admin" } },
		run = function(ctx, a)
			local done = each(ctx, a.player, function(p)
				if p == ctx.caller then return false, "not yourself" end
				p:Kick(a.reason)
			end)
			return done[1] ~= "nobody", "Kicked " .. table.concat(done, ", ") .. "."
		end,
	},
	{
		name = "tp", aliases = { "teleport", "goto" }, level = "Tester",
		description = "Teleport players to a player, a duel pad (1v1a, pad_2v2_b), spawn, hangar, spawna / spawnb (match place), or x,y,z.",
		args = { P, { name = "target", type = "string" } },
		run = function(ctx, a)
			local cf, label = placeTarget(a.target)
			if not cf then
				local list, err = ctx.Core.Args.Players(a.target, ctx)
				if not list then return false, "no place or player \"" .. a.target .. "\" (" .. tostring(err) .. ")" end
				if #list ~= 1 then return false, "tp to exactly one player" end
				local _, root = humanoidOf(list[1])
				if not root then return false, list[1].Name .. " has no character" end
				cf, label = root.CFrame * CFrame.new(0, 0, 4), list[1].Name
			end
			local done = each(ctx, a.player, function(p)
				if p:GetAttribute("DuelMatch") then return false, "in a duel" end
				local _, root = humanoidOf(p)
				if not root then return false, "no character" end
				p.Character:PivotTo(cf)
			end)
			return done[1] ~= "nobody", ("Teleported %s to %s."):format(table.concat(done, ", "), label)
		end,
	},
	{
		name = "heal", level = "Tester", description = "Full health.",
		args = { P },
		run = function(ctx, a)
			local done = each(ctx, a.player, function(p)
				local hum = humanoidOf(p)
				if not hum or hum.Health <= 0 then return false, "no living character" end
				hum.Health = hum.MaxHealth
			end)
			return done[1] ~= "nobody", "Healed " .. table.concat(done, ", ") .. "."
		end,
	},
	{
		name = "kill", level = "Tester", description = "Kill (in a duel this counts as a death in the round).",
		args = { P },
		run = function(ctx, a)
			local done = each(ctx, a.player, function(p)
				local hum = humanoidOf(p)
				if not hum then return false, "no character" end
				if god[p] then god[p] = nil; removeGod(p); p:SetAttribute("AdminGod", nil) end
				hum.Health = 0
			end)
			return done[1] ~= "nobody", "Killed " .. table.concat(done, ", ") .. "."
		end,
	},
	{
		name = "respawn", aliases = { "re", "refresh" }, level = "Tester", description = "Load a new character at the spawn.",
		args = { P },
		run = function(ctx, a)
			local done = each(ctx, a.player, function(p)
				if p:GetAttribute("DuelMatch") then return false, "in a duel" end
				task.spawn(function() p:LoadCharacter() end)
			end)
			return done[1] ~= "nobody", "Respawned " .. table.concat(done, ", ") .. "."
		end,
	},
	{
		name = "god", level = "Tester", description = "God mode on/off (invisible ForceField + heal-back; lasts through respawns).",
		args = { P, { name = "on", type = "boolean", optional = true, default = true } },
		run = function(ctx, a)
			local done = each(ctx, a.player, function(p)
				hookPlayer(p)
				god[p] = a.on or nil
				p:SetAttribute("AdminGod", a.on or nil)
				if a.on then applyGod(p) else removeGod(p) end
			end)
			return done[1] ~= "nobody", ("God %s: %s."):format(a.on and "on" or "off", table.concat(done, ", "))
		end,
	},
	{
		name = "speed", aliases = { "walkspeed", "ws" }, level = "Tester",
		description = "WalkSpeed (16 = normal; 'reset' or 0 = normal). Sets player attribute AdminSpeed.",
		args = { P, { name = "speed", type = "string", optional = true, default = "reset" } },
		run = function(ctx, a)
			local n = tonumber(a.speed)
			if a.speed ~= "reset" and (not n or n < 0 or n > 500) then return false, "speed must be 0-500 or reset" end
			if n == 0 or a.speed == "reset" then n = nil end
			local done = each(ctx, a.player, function(p)
				hookPlayer(p)
				p:SetAttribute("AdminSpeed", n)
				local hum = humanoidOf(p)
				if hum then hum.WalkSpeed = n or 16 end
			end)
			return done[1] ~= "nobody", ("Speed %s for %s."):format(n and tostring(n) or "normal", table.concat(done, ", "))
		end,
	},
}
]=]
SOURCES.Cmd_Duel = [=[-- AdminFramework/Commands/Duel: lobby pad duels (LobbyDuelManager). In a place without lobby duels these say so.
-- duelsolo sets the player attribute AdminDuelSolo (server-set; clients can't fake it). The [ADMIN] edits in QueueManager
-- (bayIsFull) and LobbyDuelManager (StartMatch) let a pad with such a player start alone and fill the empty places with
-- test bots, live as well as in Studio. A match with a test bot never pays rewards (match.hasBot, LobbyDuelManager.award).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local function ldm(ctx)
	local m = ctx.Core.Place == "lobby" and ctx.Data.Lobby("LobbyDuelManager") or nil
	if not m or not m._matches then error("this place has no lobby duels (LobbyDuelManager)") end
	return m
end

-- the match place: one match per server on ReplicatedStorage, run by RoundManager on MatchCore (MatchInfo / EndMatch)
local function roundManager(ctx)
	if ctx.Core.Place ~= "match" then return nil end
	local m = ctx.Data.Lobby("RoundManager")
	if m and m.MatchInfo then return m end
	return nil
end

local function matchConfig(ctx)
	return ctx.Data.MatchConfig or {}
end

local function describe(m)
	local mem = {}
	for side, list in m.teams do
		for _, x in list do table.insert(mem, side .. ":" .. tostring(x.name) .. (x.isBot and "(bot)" or "") .. (x.left and "(left)" or "")) end
	end
	local s = m.state
	return ("%s  %s slot %d  %s  %s-%s  [%s]"):format(m.id, m.mode, m.slot, tostring(s and s:GetAttribute("MatchState") or "?"),
		tostring(s and s:GetAttribute("ScoreA") or 0), tostring(s and s:GetAttribute("ScoreB") or 0), table.concat(mem, " "))
end

return {
	{
		name = "duelsolo", level = "Admin", place = "lobby",
		description = "on: a duel pad you stand on starts with just you; empty places get test bots; bot matches never pay. Only for matches that include you.",
		args = { { name = "on", type = "boolean" }, { name = "player", type = "players", defaultToken = "me" } },
		run = function(ctx, a)
			local names = {}
			for _, p in a.player do
				local lv = ctx.Core.Permissions.LevelOf(p)
				if lv < ctx.Core.Permissions.Values.Admin then
					ctx.reply(p.Name .. " isn't an admin: duelsolo is admins only")
				else
					p:SetAttribute("AdminDuelSolo", a.on or nil)
					table.insert(names, p.Name)
				end
			end
			if RunService:IsStudio() then
				-- Studio: also the old global switch (LobbyDuelManager._TestSolo / the DuelTestHook use it)
				ReplicatedStorage:SetAttribute("DuelTestSolo", a.on or nil)
			end
			if #names == 0 then return false, "nobody changed" end
			return true, ("Duel solo %s for %s. %s"):format(a.on and "ON" or "off", table.concat(names, ", "),
				a.on and "Stand on a pad: it counts down alone, bots fill the rest, no rewards." or "")
		end,
	},
	{
		name = "listmatches", aliases = { "matches", "duels" }, level = "Tester", description = "Running matches (lobby duels, or this match server's match).",
		run = function(ctx)
			local rm = roundManager(ctx)
			if rm then
				local i = rm.MatchInfo()
				ctx.reply(("%s  %s%s  %s  round %d  %d-%d  map %s  [%s]"):format(i.kind, tostring(i.mode or "-"), i.ranked and " ranked" or "",
					tostring(i.state or "-"), i.round, i.scoreA, i.scoreB, tostring(i.map or "-"), table.concat(i.members, " ")))
				return true, i.kind == "none" and "No match running on this server." or "1 match on this server."
			end
			local m = ldm(ctx)
			local n = 0
			for _, match in m._matches do n += 1; ctx.reply(describe(match)) end
			if n == 0 then return true, "No lobby duels running." end
			return true, n .. " match(es)."
		end,
	},
	{
		name = "endmatch", aliases = { "stopmatch" }, level = "Admin",
		description = "End a match now: a lobby duel (match id like D3, or a player in it; back to the pads) or, in the match place, this server's match (back to the lobby). Nobody is paid.",
		args = { { name = "match", type = "string", optional = true } },
		run = function(ctx, a)
			local rm = roundManager(ctx)
			if rm then
				local ok, why = rm.EndMatch("admin " .. (ctx.caller and ctx.caller.Name or "console"))
				if not ok then return false, why end
				-- [TESTPLACE] on the Test place everyone stays (back to its waiting area)
				if rm._testPlace then return true, "Ending this test match: nobody is paid, everyone goes back to the Test place's waiting area." end
				return true, "Ending this server's match: no rewards, everyone goes back to the lobby."
			end
			local m = ldm(ctx)
			if not a.match then return false, "give a match id (;listmatches) or a player in it" end
			local id = string.upper(a.match)
			if not m._matches[id] then
				local list = ctx.Core.Args.Players(a.match, ctx)
				local p = list and list[1]
				id = p and p:GetAttribute("DuelMatch")
				if not id then return false, ("no match \"%s\" (and no player in a duel by that name)"):format(a.match) end
			end
			if not m._matches[id] then return false, "match " .. tostring(id) .. " is already over" end
			-- both sides leave: the match ends as a forfeit with nobody present, so award() pays nobody
			m._TestForfeit(id, "A")
			m._TestForfeit(id, "B")
			return true, ("Ending %s: players are being returned to the pads."):format(id)
		end,
	},
	{
		name = "arenas", level = "Tester", place = "lobby", description = "Arena slots and the duel maps (modes per map).",
		run = function(ctx)
			local m = ldm(ctx)
			local C = matchConfig(ctx)
			local sl = {}
			for n = 1, C.MaxArenas or 6 do sl[n] = n .. ":" .. tostring(m._slots[n] or "free") end
			ctx.reply("slots " .. table.concat(sl, "  "))
			local ok, MapRegistry = pcall(require, ReplicatedStorage.Modules.Shared.MapRegistry)
			if ok then
				for _, info in MapRegistry.List() do
					ctx.reply(("map %s (%s): modes %s"):format(info.Id, tostring(info.DisplayName), table.concat(info.Modes or {}, ",")))
				end
			end
			return true, ("in-lobby duels %s, solo test %s"):format(C.PadDuelsInLobby and "on" or "OFF",
				tostring(ReplicatedStorage:GetAttribute("DuelTestSolo") == true))
		end,
	},
}
]=]
SOURCES.Cmd_World = [=[-- AdminFramework/Commands/World: server-wide things.
local Players = game:GetService("Players")

return {
	{
		name = "announce", aliases = { "m", "say" }, level = "Admin", description = "A system message (and toast in the lobby) to everyone here.",
		args = { { name = "text", type = "rest" } },
		run = function(ctx, a)
			local text = string.sub(a.text, 1, 160)
			for _, p in Players:GetPlayers() do ctx.Core.Notify(p, text, "announce") end
			return true, "Announced to " .. #Players:GetPlayers() .. " player(s)."
		end,
	},
	{
		name = "pads", level = "Tester", place = "lobby", description = "Duel pads: mode, state, NoMap, who is on them.",
		run = function(ctx)
			local map = workspace:FindFirstChild("LobbyMap")
			local duels = map and map:FindFirstChild("Duels")
			if not duels then return false, "this place has no LobbyMap.Duels pads" end
			local n = 0
			for _, pad in duels:GetChildren() do
				if pad:IsA("Model") and pad:GetAttribute("QueueName") then
					n += 1
					ctx.reply(("%s  %s  bay %s  %s%s"):format(pad.Name, tostring(pad:GetAttribute("QueueName")), tostring(pad:GetAttribute("BayId")),
						(function() local h = pad:FindFirstChild("Holo"); local v = h and h:GetAttribute("BayStatus"); return type(v) == "string" and v or "" end)(),
						pad:GetAttribute("NoMap") and ("  NoMap: " .. tostring(pad:GetAttribute("NoMapText"))) or ""))
				end
			end
			return true, n .. " pad(s). tp to one with ;tp me 1v1a"
		end,
	},
}
]=]
SOURCES.Cmd_Debug = [=[-- AdminFramework/Commands/Debug: help, whoami, serverinfo, audit, simlevel (Studio).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local started = os.clock()

return {
	{
		name = "cmds", aliases = { "help", "commands", "?" }, level = "Tester",
		description = "List the commands you can use, or ;help <command> for one.",
		args = { { name = "command", type = "string", optional = true } },
		run = function(ctx, a)
			local Core = ctx.Core
			if a.command then
				local def = Core.ByName[string.lower((string.gsub(a.command, "^[;/]", "")))]
				if not def then return false, "no command \"" .. a.command .. "\"" end
				ctx.reply(Core.Usage(def) .. "   (" .. def.level .. "+" .. (def.destructive and ", needs confirm" or "") ..
					(def.aliases and #def.aliases > 0 and (", aliases " .. table.concat(def.aliases, " ")) or "") .. ")")
				ctx.reply(def.description or "")
				return true
			end
			local groups, order = {}, {}
			for _, def in Core.Visible(ctx.level) do
				if not groups[def.group] then groups[def.group] = {}; table.insert(order, def.group) end
				table.insert(groups[def.group], def.name)
			end
			for _, g in order do ctx.reply(g .. ": " .. table.concat(groups[g], ", ")) end
			return true, ("You are %s. ;help <command> for details. Players: me, all, others, @userid, name."):format(ctx.levelName)
		end,
	},
	{
		name = "whoami", level = "Tester", description = "Your admin level and why.",
		run = function(ctx)
			local p = ctx.caller
			local Perm = ctx.Core.Permissions
			local real, realWhy = 0, "-"
			if p then real, realWhy = Perm.RealLevel(p) end
			return true, ("%s (@%s): %s via %s; live level %s via %s; group %d"):format(p and p.Name or "console", p and p.UserId or 0,
				ctx.levelName, tostring(ctx.why), Perm.Name(real), realWhy, Perm.GroupId())
		end,
	},
	{
		name = "serverinfo", aliases = { "server" }, level = "Tester", description = "Place, server, players, uptime, data store.",
		run = function(ctx)
			local D = ctx.Data
			local duels = 0
			local m = ctx.Core.Place == "lobby" and D.Lobby("LobbyDuelManager") or nil
			for _ in (m and m._matches or {}) do duels += 1 end
			local rm = ctx.Core.Place == "match" and D.Lobby("RoundManager") or nil
			if rm and rm.MatchInfo then
				-- the match place: its one match
				local i = rm.MatchInfo()
				ctx.reply(("match server: %s %s, state %s"):format(i.kind, tostring(i.mode or "-"), tostring(i.state or "-")))
			end
			ctx.reply(("place %d v%d  job %s  %s"):format(game.PlaceId, game.PlaceVersion, game.JobId ~= "" and string.sub(game.JobId, 1, 8) or "studio",
				RunService:IsStudio() and "STUDIO" or (game.PrivateServerId ~= "" and "private server" or "public server")))
			return true, ("%d player(s), up %d min, profile store \"%s\", lobby duels %d, audit store %s"):format(#Players:GetPlayers(),
				math.floor((os.clock() - started) / 60), D.StoreKey, duels, ctx.Core.Audit.StoreState())
		end,
	},
	{
		name = "audit", aliases = { "log" }, level = "Admin", description = "The last admin commands run on this server.",
		args = { { name = "count", type = "integer", min = 1, max = 30, optional = true, default = 8 } },
		run = function(ctx, a)
			for _, e in ctx.Core.Audit.Recent(a.count) do
				ctx.reply(("%s %s(%s) %s %s%s -> %s"):format(os.date("!%H:%M:%S", e.time), tostring(e.admin), tostring(e.level), e.command,
					e.args or "", e.targets and (" @" .. e.targets) or "", e.ok and "ok" or ("refused: " .. tostring(e.result))))
			end
			return true
		end,
	},
	{
		name = "dump", aliases = { "rawdata" }, level = "Admin", anyTarget = true,
		description = "Raw profile JSON (one key, or the key list). Read-only.",
		args = { { name = "player", type = "player", defaultToken = "me" }, { name = "key", type = "string", optional = true } },
		run = function(ctx, a)
			local data = ctx.Data.Get(a.player)
			if not data then return false, "data not loaded" end
			if not a.key then
				local keys = {}
				for k in data do table.insert(keys, tostring(k)) end
				table.sort(keys)
				return true, "keys: " .. table.concat(keys, ", ")
			end
			local key
			for k in data do if string.lower(tostring(k)) == string.lower(a.key) then key = k end end
			if key == nil then return false, "no key " .. a.key end
			local ok, json = pcall(HttpService.JSONEncode, HttpService, data[key])
			json = ok and json or tostring(data[key])
			for i = 1, math.min(#json, 1200), 300 do ctx.reply(string.sub(json, i, i + 299)) end
			return true, ("%s.%s (%d chars)"):format(a.player.Name, tostring(key), #json)
		end,
	},
	{
		name = "simlevel", level = "None", studioOnly = true, anyTarget = true, -- None: a simulated non-admin can still undo it
		description = "Studio only: pretend to have another admin level (None to test denial). Undo with ;simlevel owner",
		args = { { name = "level", type = "level" }, { name = "player", type = "player", defaultToken = "me" } },
		run = function(ctx, a)
			local ok, err = ctx.Core.Permissions.SetSimulated(a.player.UserId, a.level ~= ctx.Core.Config.StudioLevel and a.level or nil)
			if not ok then return false, err end
			return true, ("%s now counts as %s in this Studio test."):format(a.player.Name, a.level)
		end,
	},
}
]=]
SOURCES.Cmd_Legacy = [=[-- AdminFramework/Commands/Legacy: the old ServerScriptService.AdminCommands chat commands, kept working on top of the new
-- framework (original in ServerStorage._RebuildRemoved.ADMIN_AdminCommands_Orig). Typed with "/" (old) or ";".
--   /scissors 5000 | /scissors set 0   -> addcredits me 5000 | setcredits me 0
--   /give <name> 500                   -> ;give <name> 500 (Data.give: a number = scissors)
--   /wipeweapons                       -> ;wipe me inventory (asks for confirm like every wipe)
--   /unlockall                         -> alias of ;giveall (Data)
--   /admin                             -> ;cmds
return {
	{
		name = "scissors", level = "Tester", description = "Old form: /scissors 5000 adds, /scissors set 0 sets (yours).",
		args = { { name = "amount", type = "rest" } },
		run = function(ctx, a)
			local t = ctx.Core.Args.Tokenize(a.amount)
			local cmd
			if string.lower(t[1] or "") == "set" then cmd = "setcredits me " .. tostring(t[2] or "")
			else cmd = "addcredits me " .. tostring(t[1] or "") end
			local r = ctx.Core.Run(ctx.caller, cmd, (ctx.source or "") .. "/legacy")
			for _, l in r.lines do ctx.reply(l) end
			return r.ok
		end,
	},
	{
		name = "wipeweapons", level = "Admin", destructive = true,
		description = "Old form: lock every item again (back to the default kit). Same as ;wipe me inventory.",
		confirmText = function() return "lock every item you own again (default kit)" end,
		run = function(ctx)
			local D, p = ctx.Data, ctx.caller
			if not p or not D.Ready(p) then return false, "your data hasn't loaded yet" end
			local n = 0
			for _ in (D.Read(p, { "Owned" }) or {}) do n += 1 end
			D.Set(p, { "Owned" }, {}); D.Set(p, { "ItemXP" }, {}); D.Set(p, { "Loadout" }, D.DefaultLoadout())
			D.Refresh(p)
			return true, ("Wiped %d unlocked items. You're back to the default kit."):format(n)
		end,
	},
	{
		name = "admin", level = "Tester", description = "Old form of ;cmds.",
		run = function(ctx)
			local r = ctx.Core.Run(ctx.caller, "cmds", ctx.source)
			for _, l in r.lines do ctx.reply(l) end
			return r.ok
		end,
	},
}
]=]
SOURCES.Cmd_Ranked = [=[-- AdminFramework/Commands/Ranked: ranked ELO commands [RANKED] 2026-10-16 (notes/ranked_server.md).
-- They go through ServerScriptService.Shared.RankedServer (installed by fix/ranked_install.lua): the unified Ranked record,
-- the leaderboard write and the Rank* attributes, in both places.
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function server()
	local s = ServerScriptService:FindFirstChild("Shared") and ServerScriptService.Shared:FindFirstChild("RankedServer")
	if not s then return nil end
	local ok, m = pcall(require, s)
	return ok and m or nil
end
local function core()
	local s = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules.Shared:FindFirstChild("RankedCore")
	if not s then return nil end
	local ok, m = pcall(require, s)
	return ok and m or nil
end
local NOT_INSTALLED = "The ranked system isn't installed in this place (fix/ranked_install.lua)."
local MODES = { "1v1", "2v2", "3v3" }

return {
	{
		name = "setelo", level = "Tester", description = "Set a player's ranked ELO (never below 100). Mode defaults to 1v1.",
		args = { { name = "player", type = "player" }, { name = "elo", type = "integer", min = 0, max = 100000 },
			{ name = "mode", type = "choice", choices = MODES, optional = true, default = "1v1" } },
		run = function(ctx, a)
			local RS = server()
			if not RS then return false, NOT_INSTALLED end
			if not ctx.Data.Ready(a.player) then return false, a.player.Name .. "'s data hasn't loaded yet" end
			local rec, key = RS.SetElo(a.player, a.elo, a.mode)
			if not rec then return false, "couldn't write " .. a.player.Name .. "'s ranked record" end
			local info = RS.InfoFor(key, rec, a.player.UserId)
			if a.player ~= ctx.caller and ctx.Core.Notify then ctx.Core.Notify(a.player, ("An admin set your %s ELO to %d."):format(key, rec.Elo), "info") end
			return true, ("%s %s: %d ELO = %s."):format(a.player.Name, key, rec.Elo, info.name)
		end,
	},
	{
		name = "rankreset", level = "Admin", destructive = true,
		description = "Reset a player's ranked record (one mode, or every ladder) to a new player's: 100 ELO, no wins / losses.",
		args = { { name = "player", type = "player" }, { name = "mode", type = "choice", choices = MODES, optional = true } },
		confirmText = function(_, v) return ("reset %s's ranked record (%s)"):format(v.player.Name, v.mode or "every ladder") end,
		run = function(ctx, a)
			local RS = server()
			if not RS then return false, NOT_INSTALLED end
			if not ctx.Data.Ready(a.player) then return false, a.player.Name .. "'s data hasn't loaded yet" end
			local done = RS.Reset(a.player, a.mode)
			return true, ("Ranked reset for %s: %s."):format(a.player.Name, table.concat(done, ", "))
		end,
	},
	{
		name = "rankinfo", aliases = { "elo" }, level = "Tester", anyTarget = true,
		description = "Show a player's ranked records (ELO, rank, peak, wins / losses, placements, shield) and the Warlord cutoff.",
		args = { { name = "player", type = "player", defaultToken = "me" } },
		run = function(ctx, a)
			local RS = server()
			if not RS then return false, NOT_INSTALLED end
			if not ctx.Data.Ready(a.player) then return false, a.player.Name .. "'s data hasn't loaded yet" end
			ctx.reply(a.player.Name .. " ranked:")
			for _, line in RS.Lines(a.player) do ctx.reply(line) end
			local bits = {}
			for _, key in RS.Core.LadderKeys() do
				local cut = RS.Leaderboard.cutoff[key]
				local top = RS.Leaderboard.top[key]
				table.insert(bits, ("%s %d at 2200+, cutoff %s"):format(key, top and #top or 0, cut and tostring(cut) or "none"))
			end
			return true, "Warlord: " .. table.concat(bits, "; ") .. (RS.Leaderboard.mock and " (mock store)" or "")
		end,
	},
	{
		name = "simrank", level = "Tester", anyTarget = true,
		description = "Print the ELO change for A (eloA) beating or losing to B (eloB), and B's side of it. Changes nothing.",
		args = { { name = "eloA", type = "integer", min = 0, max = 100000 }, { name = "eloB", type = "integer", min = 0, max = 100000 },
			{ name = "result", type = "choice", choices = { "win", "loss" } } },
		run = function(_, a)
			local RC = core()
			if not RC then return false, NOT_INSTALLED end
			local won = a.result == "win"
			local ea, eb = RC.ClampElo(a.eloA), RC.ClampElo(a.eloB)
			local da = RC.Delta(ea, RC.TierOf(eb), won)
			local db = RC.Delta(eb, RC.TierOf(ea), not won)
			local ia, ib = RC.Info(ea), RC.Info(eb)
			return true, ("A %s (%d) %s vs B %s (%d): A %+d -> %d, B %+d -> %d"):format(ia.name, ea, won and "wins" or "loses", ib.name, eb,
				da, math.max(RC.Config.Floor, ea + da), db, math.max(RC.Config.Floor, eb + db))
		end,
	},
}
]=]
SOURCES.Cmd_TestPlace = [=[-- AdminFramework/Commands/TestPlace [TESTPLACE] 2026-10-28 (notes/test_place.md): the admin-only Test place, where new maps are
-- tried before they are pushed to Matchmaking, Ranked and the lobby. One file for both places:
--   lobby       ;testplace [shared|new]   reserve a Test server and go there (LobbyConfig.TestPlaceId; 0 = not set up yet).
--                                          shared (default): the one Test server every admin meets in (its access code is kept in
--                                          the DataStore TestPlace_v1, so admins from different lobby servers land together);
--                                          new: a fresh private one for you alone.
--   Test place  ;maplist                   every map you can test: live maps (ReplicatedStorage.DuelMaps) + staging maps
--                                          (ServerStorage.StagingMaps, which no live place ever votes on)
--               ;testmatch <map> [1v1|2v2|3v3] [bots|admins]   start a match on that map now: you + test bots, or every admin
--                                          here split into two teams (bots fill the empty places). Nothing is saved on this place.
-- The Test place commands only exist where ReplicatedStorage.PlaceKind is "Test"; the match-side work is RoundManager's
-- (manager.StartTest / manager.TestMapList, fix/test_place_install.lua). Every check runs on the server (Core: level Admin).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local DataStoreService = game:GetService("DataStoreService")

local IS_STUDIO = RunService:IsStudio()
local kindValue = ReplicatedStorage:FindFirstChild("PlaceKind")
local IS_TEST_PLACE = kindValue ~= nil and kindValue:IsA("StringValue") and kindValue.Value == "Test"

-- // Lobby: go to the Test place ------------------------------------------------------------------------------------
local function lobbyConfig()
	local cfg = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("Shared")
	cfg = cfg and cfg:FindFirstChild("Config") and cfg.Config:FindFirstChild("LobbyConfig")
	if not cfg then return nil end
	local ok, LC = pcall(require, cfg)
	return ok and LC or nil
end

-- the shared Test server's access code (one per experience): reserved once, then reused. A reserved server's code stays valid,
-- so every admin who goes "shared" lands in the same running Test server (a new one starts there when it was empty).
local SHARED_KEY = "SharedServer"
local codeStore = nil
local function sharedStore()
	if codeStore ~= nil then return codeStore or nil end
	local ok, ds = pcall(function() return DataStoreService:GetDataStore((IS_STUDIO and "Studio_" or "") .. "TestPlace_v1") end) -- datastore-ok (an access code, not player data)
	codeStore = ok and ds or false
	return codeStore or nil
end
local function reserve(placeId: number, shared: boolean): (string?, string?)
	local ds = shared and sharedStore() or nil
	if ds then
		local ok, code = pcall(ds.GetAsync, ds, SHARED_KEY)
		if ok and type(code) == "string" and code ~= "" then return code end
	end
	local ok, code = pcall(TeleportService.ReserveServer, TeleportService, placeId)
	if not ok or type(code) ~= "string" then return nil, tostring(code) end
	if ds then pcall(ds.SetAsync, ds, SHARED_KEY, code) end
	return code
end

local going = {} -- [player] = true while a teleport is under way (a second press waits for it)
Players.PlayerRemoving:Connect(function(p) going[p] = nil end)

-- why this player can't leave for the Test place right now (nil = they can)
local function busyReason(p: Player): string?
	if p:GetAttribute("DuelMatch") or p:GetAttribute("InMatch") then return "You're in a duel: finish or leave it first." end
	if p:GetAttribute("QueueMode") then return "Step off the duel pad first." end
	if p:GetAttribute("MM_Status") then return "Cancel your match search first." end
	if p:GetAttribute("InTraining") then return "Leave Training first." end
	return nil
end

local function goToTest(ctx, p: Player, placeId: number, shared: boolean)
	going[p] = true
	local code, err = reserve(placeId, shared)
	if not code then
		going[p] = nil
		ctx.Core.Notify(p, "Couldn't reserve a Test server: " .. tostring(err), false)
		return
	end
	if not p.Parent then going[p] = nil return end
	-- the profile is saved and released first, so nothing is lost and the Test place's view-only copy reads the latest save
	local DM = nil
	local dmMod = ServerScriptService:FindFirstChild("Data") and ServerScriptService.Data:FindFirstChild("DataManager")
	if dmMod then pcall(function() DM = require(dmMod) end) end
	if DM and DM.ReleaseForTeleport then pcall(DM.ReleaseForTeleport, { p }) end
	local opts = Instance.new("TeleportOptions")
	opts.ReservedServerAccessCode = code
	opts:SetTeleportData({ TestPlace = true, From = "lobby" }) -- informational only: the Test place trusts nothing in it
	local ok, terr = pcall(TeleportService.TeleportAsync, TeleportService, placeId, { p }, opts)
	if not ok then
		if DM and DM.RestoreAfterTeleportFail then task.spawn(DM.RestoreAfterTeleportFail, p, tostring(terr)) end
		ctx.Core.Notify(p, "Teleport to the Test place failed: " .. tostring(terr), false)
	end
	task.delay(15, function() going[p] = nil end)
end

local lobbyCommands = {
	{
		name = "testplace", aliases = { "testmaps", "gotest" }, level = "Admin", place = "lobby",
		description = "Go to the admin-only Test place to try maps before they go live (nothing is saved there). shared = the Test server every admin meets in; new = a private one.",
		args = { { name = "server", type = "choice", choices = { "shared", "new" }, optional = true, default = "shared" } },
		run = function(ctx, a)
			local p = ctx.caller
			if not p then return false, "run this as a player (it teleports you)" end
			local LC = lobbyConfig()
			local placeId = LC and tonumber(LC.TestPlaceId) or 0
			if placeId == 0 then return false, "The Test place isn't set up yet (LobbyConfig.TestPlaceId = 0)." end
			local why = busyReason(p)
			if why then return false, why end
			if going[p] then return false, "Already on your way to the Test place..." end
			local shared = (a.server or "shared") ~= "new"
			if IS_STUDIO then
				return true, ("Studio: in a live lobby this reserves %s Test server on place %d and teleports you (skipped in Studio)."):format(shared and "the shared" or "a new", placeId)
			end
			task.spawn(goToTest, ctx, p, placeId, shared)
			return true, ("Taking you to the %s Test server..."):format(shared and "shared" or "new private")
		end,
	},
}

-- // Test place: pick a map, start a match -------------------------------------------------------------------------
local function roundManager(ctx)
	local m = ctx.Data.Lobby("RoundManager")
	if m and m.StartTest then return m end
	error("the Test place code isn't installed (fix/test_place_install.lua)")
end

-- every map id at server start (live + staging) for the panel's dropdown; the command re-checks against the live list
local function mapIds(): { string }
	local ids, seen = {}, {}
	for _, root in { ReplicatedStorage:FindFirstChild("DuelMaps"), ServerStorage:FindFirstChild("StagingMaps") } do
		for _, f in (root and root:GetChildren() or {}) do
			if f:FindFirstChild("MapInfo") and not seen[f.Name] then seen[f.Name] = true; table.insert(ids, f.Name) end
		end
	end
	table.sort(ids)
	return ids
end

local testCommands = {
	{
		name = "maplist", aliases = { "maps", "testmaps", "stagingmaps" }, level = "Admin", place = "match",
		description = "Every map you can test here: live maps and staging maps (staging = only on this Test place, never voted on in Matchmaking / Ranked / the lobby).",
		run = function(ctx)
			local rm = roundManager(ctx)
			for _, e in rm.TestMapList() do
				ctx.reply(("%s%s  (%s)  modes %s"):format(e.id, e.staging and "  [STAGING]" or "", tostring(e.name), table.concat(e.modes, ",")))
			end
			return true, "Start one with ;testmatch <map> [1v1|2v2|3v3] [bots|admins]"
		end,
	},
	{
		name = "testmatch", aliases = { "tm", "playmap" }, level = "Admin", place = "match",
		description = "Start a test match on any map (live or staging) now: you + test bots, or every admin here in two teams (bots fill the gaps). Nothing is saved on this place.",
		args = {
			{ name = "map", type = "choice", choices = mapIds() },
			{ name = "mode", type = "choice", choices = { "1v1", "2v2", "3v3" }, optional = true, default = "1v1" },
			{ name = "vs", type = "choice", choices = { "bots", "admins" }, optional = true, default = "bots" },
		},
		run = function(ctx, a)
			if not ctx.caller then return false, "run this as a player (you play in the match)" end
			local rm = roundManager(ctx)
			return rm.StartTest(ctx.caller, a.map, a.mode or "1v1", a.vs or "bots")
		end,
	},
}

-- only the Test place gets the match-side commands (Core also drops a command whose `place` doesn't match this server)
if IS_TEST_PLACE then return testCommands end
return lobbyCommands
]=]
SOURCES.AdminCommands = [=[-- [ADMIN] ServerScriptService/AdminCommands (Script): entry points of the admin framework (notes/admin_framework.md, 2026-10-16).
-- Replaces the old chat-command script (original: ServerStorage._RebuildRemoved.ADMIN_AdminCommands_Orig); its commands still
-- work (Commands/Legacy). The framework itself is ServerScriptService.AdminFramework (Config, Permissions, Args, DataAdapter,
-- Audit, Core, Commands/*). Same files in the lobby and the match place.
-- Entry points (all end in Core.Run on the server, which checks the caller's level; the client never decides):
--   1. Chat: ";cmd args" (and the old "/scissors" etc.). TextChatService.AdminCommands holds one TextChatCommand per name /
--      alias, so the text never shows as a chat message; StarterPlayerScripts.AdminFeedback forwards it via AdminRequest.
--   2. Admin panel (UI session, notes/admin_ui_requests.md): ReplicatedStorage.AdminRemote (RemoteFunction)
--      InvokeServer("commands") / ("run", text) / ("whoami") / ("audit", n).
--   3. Studio command bar / MCP: ServerStorage.AdminBindable (BindableFunction, server only)
--      Invoke("run", text, userId)      as that player (their real level), feedback in their chat
--      Invoke("console", text, userId?) as the server console (Owner); "me" = that player
--      Invoke("simlevel", userId, "None"|"Tester"|"Admin"|nil)   Studio only
--      Invoke("audit", n) / Invoke("list")
-- Feedback: ReplicatedStorage.AdminFeedback:FireClient(player, line, kind) -> a system line in chat (AdminFeedback LocalScript).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TextChatService = game:GetService("TextChatService")

local Framework = ServerScriptService:WaitForChild("AdminFramework")
local Core = require(Framework.Core)
local Config = require(Framework.Config)
Core.LoadCommands(Framework.Commands)

local function remote(class: string, name: string)
	local r = ReplicatedStorage:FindFirstChild(name)
	if r and not r:IsA(class) then r:Destroy(); r = nil end
	if not r then r = Instance.new(class); r.Name = name; r.Parent = ReplicatedStorage end
	return r
end
local feedback = remote("RemoteEvent", "AdminFeedback")
local request = remote("RemoteEvent", "AdminRequest")
local panel = remote("RemoteFunction", "AdminRemote")

local MAX_LINES = 24
Core.Notify = function(player: Player?, text: string, kind)
	if not player then print("[Admin] " .. tostring(text)) return end
	if not player.Parent then return end
	feedback:FireClient(player, string.sub(tostring(text), 1, 400), kind)
	if kind == "announce" then
		local lobby = ReplicatedStorage:FindFirstChild("Events") and ReplicatedStorage.Events:FindFirstChild("Lobby")
		local toast = lobby and lobby:FindFirstChild("Notify")
		if toast and toast:IsA("RemoteEvent") then toast:FireClient(player, text, "info") end
	end
end

local function send(player: Player?, result)
	local kind = result.ok and true or false
	if result.needsConfirm then kind = "info" end
	for i, line in result.lines do
		if i > MAX_LINES then Core.Notify(player, ("(%d more lines)"):format(#result.lines - MAX_LINES), "info") break end
		-- the last line carries ok / error colour, the lines before it are plain output
		local k = "info"
		if i == #result.lines then k = kind end -- (not `cond and kind or "info"`: kind can be false)
		Core.Notify(player, line, k)
	end
end

-- 1. Chat ---------------------------------------------------------------------------------------------------------------------
local LEGACY = { scissors = true, give = true, wipeweapons = true, unlockall = true, admin = true }
local folder = TextChatService:FindFirstChild("AdminCommands") or Instance.new("Folder")
folder.Name = "AdminCommands"
folder:ClearAllChildren()
local made = {}
local function chatCommand(word: string)
	if made[word] or not string.match(word, "^[%w_%?]+$") then return end
	made[word] = true
	local c = Instance.new("TextChatCommand")
	c.Name = "Admin_" .. word
	c.PrimaryAlias = Config.Prefix .. word
	c.SecondaryAlias = LEGACY[word] and (Config.LegacyPrefix .. word) or ""
	c.AutocompleteVisible = false
	c.Parent = folder
end
for _, def in Core.Commands do
	chatCommand(def.name)
	for _, a in def.aliases or {} do chatCommand(string.lower(a)) end
end
folder.Parent = TextChatService

local last = {}
local function limited(player: Player): boolean
	local t = os.clock()
	if last[player] and t - last[player] < Config.RateLimit then return true end
	last[player] = t
	return false
end
Players.PlayerRemoving:Connect(function(p) last[p] = nil end)

request.OnServerEvent:Connect(function(player: Player, text: any)
	if typeof(text) ~= "string" or #text > Config.MaxTextLength or limited(player) then return end
	local result = Core.Run(player, text, "chat")
	-- non-admins typing something that isn't a command hear nothing
	if result.unknown and Core.Permissions.LevelOf(player) == 0 then return end
	send(player, result)
end)

-- A mistyped ";command" from an admin matches no TextChatCommand and would be posted as a chat message: hold it back
-- (ShouldDeliverCallback, server) and answer "unknown command" instead. Anyone else's ";..." is normal chat.
local seenMsg = {}
local function guardChannel(channel: Instance)
	if not channel:IsA("TextChannel") then return end
	channel.ShouldDeliverCallback = function(message: TextChatMessage, _target: TextSource)
		local src = message.TextSource
		local text = message.Text
		if not src or type(text) ~= "string" or not string.match(text, "^%" .. Config.Prefix .. "%a") then return true end
		local sender = Players:GetPlayerByUserId(src.UserId)
		if not sender or Core.Permissions.LevelOf(sender) == 0 then return true end
		if not seenMsg[message.MessageId] then
			seenMsg[message.MessageId] = os.clock()
			task.spawn(function() send(sender, Core.Run(sender, text, "chat")) end)
		end
		return false
	end
end
task.spawn(function()
	-- the default channels are created a moment after the server starts
	local channels = TextChatService:WaitForChild("TextChannels", 30)
	if not channels then return end
	for _, c in channels:GetChildren() do guardChannel(c) end
	channels.ChildAdded:Connect(guardChannel)
end)
task.spawn(function()
	while true do
		task.wait(60)
		for id, t in seenMsg do if os.clock() - t > 60 then seenMsg[id] = nil end end
	end
end)

-- 2. Admin panel ------------------------------------------------------------------------------------------------------------
local function describe(def)
	local args = {}
	for _, a in def.args do
		table.insert(args, { name = a.name, type = a.type, optional = a.optional == true, choices = a.choices, min = a.min, max = a.max,
			default = a.defaultToken or (type(a.default) ~= "function" and a.default or nil) })
	end
	return { name = def.name, aliases = def.aliases or {}, group = def.group, level = def.level, description = def.description or "",
		usage = Core.Usage(def), destructive = def.destructive == true, args = args }
end
panel.OnServerInvoke = function(player: Player, action: any, payload: any)
	-- only "run" is rate-limited (the panel reads whoami + commands together when it opens)
	if action == "run" and limited(player) then return { ok = false, lines = { "slow down" } } end
	local level = Core.Permissions.LevelOf(player)
	if action == "whoami" then
		return { ok = true, level = level, levelName = Core.Permissions.Name(level), prefix = Config.Prefix }
	end
	if level == 0 then return { ok = false, lines = { "You're not allowed to use admin commands." } } end
	if action == "commands" then
		local list = {}
		for _, def in Core.Visible(level) do table.insert(list, describe(def)) end
		return { ok = true, commands = list, level = level, levelName = Core.Permissions.Name(level) }
	elseif action == "run" then
		if typeof(payload) ~= "string" or #payload > Config.MaxTextLength then return { ok = false, lines = { "bad command text" } } end
		local r = Core.Run(player, payload, "panel")
		return { ok = r.ok, lines = r.lines, needsConfirm = r.needsConfirm, command = r.command }
	elseif action == "audit" then
		if level < Core.Permissions.Values.Admin then return { ok = false, lines = { "audit needs Admin" } } end
		return { ok = true, entries = Core.Audit.Recent(math.clamp(tonumber(payload) or 20, 1, 50)) }
	end
	return { ok = false, lines = { "unknown action" } }
end

-- 3. Studio command bar / MCP ------------------------------------------------------------------------------------------------
local bindable = ServerStorage:FindFirstChild("AdminBindable") or Instance.new("BindableFunction")
bindable.Name = "AdminBindable"
bindable.OnInvoke = function(action: string, a, b, c)
	if action == "run" then
		local p = Players:GetPlayerByUserId(tonumber(b) or 0) or (b == nil and Players:GetPlayers()[1])
		if not p then return { ok = false, lines = { "no such player" } } end
		local r = Core.Run(p, a, "bindable")
		if not (r.unknown and Core.Permissions.LevelOf(p) == 0) then send(p, r) end
		return r
	elseif action == "console" then
		local me = b and Players:GetPlayerByUserId(tonumber(b) or 0) or nil
		local r = Core.Run(nil, a, "console", { forceLevel = Core.Permissions.Values.Owner, me = me })
		for _, l in r.lines do print("[Admin console] " .. l) end
		return r
	elseif action == "simlevel" then
		return Core.Permissions.SetSimulated(tonumber(a) or 0, b)
	elseif action == "audit" then
		return Core.Audit.Recent(tonumber(a) or 20)
	elseif action == "list" then
		local t = {}
		for _, def in Core.Commands do table.insert(t, def.name) end
		return t
	end
	return "unknown action " .. tostring(action)
end
bindable.Parent = ServerStorage

print(("[Admin] ready: %d commands, prefix %s, group %d, data layer %s"):format(#Core.Commands, Config.Prefix,
	Core.Permissions.GroupId(), Core.Data.HasPlayerStore and "PlayerStore" or "DataManager replicas"))
]=]
SOURCES.AdminFeedback = [=[-- [ADMIN] StarterPlayerScripts/AdminFeedback (LocalScript): the chat side of the admin framework (notes/admin_framework.md).
-- Sends ";cmd ..." (and the old "/scissors" etc.) to the server, and shows the replies as system lines in chat.
-- It decides nothing: the server checks every command and the caller's level. Original: ServerStorage._RebuildRemoved.ADMIN_AdminFeedback_Orig.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local feedback = ReplicatedStorage:WaitForChild("AdminFeedback")
local request = ReplicatedStorage:WaitForChild("AdminRequest")

local function hook(cmd: Instance)
	if not cmd:IsA("TextChatCommand") then return end
	cmd.Triggered:Connect(function(_source, text: string)
		request:FireServer(text)
	end)
end
local folder = TextChatService:WaitForChild("AdminCommands")
for _, cmd in folder:GetChildren() do hook(cmd) end
folder.ChildAdded:Connect(hook)

local function escape(s: string): string
	return (string.gsub(string.gsub(string.gsub(s, "&", "&amp;"), "<", "&lt;"), ">", "&gt;"))
end

-- kind: true = done (olive), false = error (red), "info" = plain output (cream), "announce" = a server message
local COLOURS = { ok = "#B5C77A", bad = "#FF7060", info = "#ECE8DA", announce = "#8A9C4A" }
local channel
feedback.OnClientEvent:Connect(function(msg: string, kind)
	channel = channel or TextChatService:WaitForChild("TextChannels"):WaitForChild("RBXSystem")
	local key = kind == true and "ok" or (kind == false and "bad") or (kind == "announce" and "announce") or "info"
	local tag = key == "announce" and "[Server]" or "[Admin]"
	channel:DisplaySystemMessage(('<font color="%s"><b>%s</b> %s</font>'):format(COLOURS[key], tag, escape(tostring(msg))))
end)
]=]
--@@END SOURCES

local MODULES = { "Config", "Permissions", "Args", "DataAdapter", "Audit", "Core" }
-- [RANKED] Ranked = ;setelo / ;rankreset / ;rankinfo / ;simrank (needs fix/ranked_install.lua for RankedServer)
-- [TESTPLACE] TestPlace = ;testplace (lobby) / ;maplist, ;testmatch (Test place only)
local COMMANDS = { "Data", "Player", "Duel", "World", "Debug", "Legacy", "Ranked", "TestPlace" }
local REPLACE = {
	{ function() return SSS:FindFirstChild("AdminCommands") end, "AdminCommands", "Script", SSS },
	{ function() return SP.StarterPlayerScripts:FindFirstChild("AdminFeedback") end, "AdminFeedback", "LocalScript", SP.StarterPlayerScripts },
}

local EDITS = {
	{ "QueueManager",
		'\tif IS_STUDIO and ReplicatedStorage:GetAttribute("DuelTestSolo") == true and n >= 1 then return true end\n',
		'\tif IS_STUDIO and ReplicatedStorage:GetAttribute("DuelTestSolo") == true and n >= 1 then return true end\n'
			.. '\t-- [ADMIN] ;duelsolo on: a pad holding a player the admin framework flagged AdminDuelSolo (server-set) counts down alone; bots fill the rest, no rewards\n'
			.. '\tif n >= 1 then for _, p in occupants(bay) do if p:GetAttribute("AdminDuelSolo") == true then return true end end end\n' },
	{ "LobbyDuelManager",
		'\tfor _, side in { "A", "B" } do\n\t\twhile #teams[side] < size and IS_STUDIO and ReplicatedStorage:GetAttribute("DuelTestSolo") == true do\n',
		'\t-- [ADMIN] ;duelsolo on: bots also fill a match that includes a player flagged AdminDuelSolo by the admin framework (live too; never pays)\n'
			.. '\tlocal adminSolo = false\n'
			.. '\tfor _, list in teams do for _, e in list do if e.player and e.player:GetAttribute("AdminDuelSolo") == true then adminSolo = true end end end\n'
			.. '\tfor _, side in { "A", "B" } do\n\t\twhile #teams[side] < size and ((IS_STUDIO and ReplicatedStorage:GetAttribute("DuelTestSolo") == true) or adminSolo) do\n' },
}

local function backup(s, tagged)
	local name = "ADMIN_" .. s.Name .. "_Orig"
	if not bin:FindFirstChild(name) and not s.Source:find(tagged, 1, true) then
		local b = s:Clone(); b.Name = name; b:ClearAllChildren()
		if b:IsA("BaseScript") then b.Disabled = true end
		b.Parent = bin
	end
end

if UNDO then
	for i = #EDITS, 1, -1 do
		local e = EDITS[i]
		local m = managers()
		local s = m and m:FindFirstChild(e[1])
		if s then
			local a, b = s.Source:find(e[3], 1, true)
			if a then s.Source = s.Source:sub(1, a - 1) .. e[2] .. s.Source:sub(b + 1); say("UNDO edit", i, s.Name)
			elseif s.Source:find(e[2], 1, true) then say("edit", i, s.Name, "not applied")
			else say("WARN edit", i, s.Name, "neither text found (changed by hand? backup ADMIN_" .. s.Name .. "_Orig kept)") end
			local bak = bin:FindFirstChild("ADMIN_" .. s.Name .. "_Orig")
			if bak and not s.Source:find("[ADMIN]", 1, true) then bak:Destroy() end
		end
	end
	for _, r in REPLACE do
		local s = r[1]()
		local bak = bin:FindFirstChild("ADMIN_" .. r[2] .. "_Orig")
		if s and bak then s.Source = bak.Source; bak:Destroy(); say("restored", r[2]) end
	end
	local fw = SSS:FindFirstChild("AdminFramework")
	if fw then fw:Destroy(); say("removed AdminFramework") end
else
	if next(SOURCES) == nil then error("no embedded sources: run python tools/admin_build.py first") end
	local fw = SSS:FindFirstChild("AdminFramework")
	if fw and not fw:IsA("Folder") then fw:Destroy(); fw = nil end
	if not fw then fw = Instance.new("Folder"); fw.Name = "AdminFramework"; fw.Parent = SSS end
	local function write(parent, name, src)
		local s = parent:FindFirstChild(name)
		if s and not s:IsA("ModuleScript") then s:Destroy(); s = nil end
		if not s then s = Instance.new("ModuleScript"); s.Name = name; s.Parent = parent end
		if s.Source ~= src then s.Source = src; say("module", name, "written") else say("module", name, "up to date") end
	end
	for _, n in MODULES do write(fw, n, SOURCES[n]) end
	local cf = fw:FindFirstChild("Commands") or Instance.new("Folder")
	cf.Name = "Commands"; cf.Parent = fw
	for _, n in COMMANDS do write(cf, n, SOURCES["Cmd_" .. n]) end
	for _, r in REPLACE do
		local s = r[1]()
		if not s then s = Instance.new(r[3]); s.Name = r[2]; s.Parent = r[4]; say("created", r[2]) end
		backup(s, "[ADMIN]")
		if s.Source ~= SOURCES[r[2]] then s.Source = SOURCES[r[2]]; say("replaced", r[2]) else say(r[2], "up to date") end
		if s:IsA("BaseScript") then s.Disabled = false end
	end
	for i, e in EDITS do
		local m = managers()
		local s = m and m:FindFirstChild(e[1])
		if not s then say("WARN missing", e[1])
		elseif s.Source:find(e[3], 1, true) then say("edit", i, s.Name, "already in")
		else
			local a, b = s.Source:find(e[2], 1, true)
			if a then
				backup(s, "[ADMIN]")
				s.Source = s.Source:sub(1, a - 1) .. e[3] .. s.Source:sub(b + 1)
				say("edit", i, s.Name, "applied")
			else say("WARN edit", i, s.Name, "anchor text not found") end
		end
	end
end
if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
return table.concat(log, "\n")
