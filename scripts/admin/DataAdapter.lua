-- ServerScriptService/AdminFramework/DataAdapter (ModuleScript): the only way admin commands touch saved data.
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
