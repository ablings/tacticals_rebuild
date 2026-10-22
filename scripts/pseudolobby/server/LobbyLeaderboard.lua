-- [PSEUDOLOBBY] copied from the hub (2026-10-18) for the match places' after-match lobby; changes are tagged [PSEUDOLOBBY].
-- LobbyLeaderboard: global top 10 boards for the hub leaderboard screen.
-- Every minute: push each player's value into an OrderedDataStore per board, then read each board's top 10 and publish it as JSON
-- ({ u = userId, n = name, w = value } list, best first) in a StringValue in ReplicatedStorage. If DataStores are unavailable (e.g.
-- Studio without API access) a board falls back to the players in this server.
-- [BOARDS] 2026-10-21 (UI session, Edward: "whatever RIVALS does"): streak, kills and level boards next to wins.
--   LobbyTopWins   Stats.Wins        (store TopWins_v1, unchanged)
--   LobbyTopKills  Stats.Kills       (TopKills_v1)
--   LobbyTopStreak WinStreak         (TopStreak_v1; the current win streak)
--   LobbyTopLevel  account level     (TopXP_v1 ranks by XP; w = the level, x = the XP)
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local PlayerStore = require(ServerScriptService.Data.PlayerStore)
local okLC, LobbyConfig = pcall(function() return require(ReplicatedStorage.Modules.Shared.Config.LobbyConfig) end)

local function levelOf(xp: number): number
	if okLC and LobbyConfig and LobbyConfig.AccountLevel then
		local ok, lvl = pcall(LobbyConfig.AccountLevel, xp)
		if ok and type(lvl) == "number" then return lvl end
	end
	return 1
end

local BOARDS = {
	{ out = "LobbyTopWins", store = "TopWins_v1", get = function(d) return d.Stats and d.Stats.Wins or 0 end },
	{ out = "LobbyTopKills", store = "TopKills_v1", get = function(d) return d.Stats and d.Stats.Kills or 0 end },
	{ out = "LobbyTopStreak", store = "TopStreak_v1", get = function(d) return tonumber(d.WinStreak) or 0 end },
	{ out = "LobbyTopLevel", store = "TopXP_v1", get = function(d) return tonumber(d.XP) or 0 end, level = true },
}
for _, b in BOARDS do
	local v = ReplicatedStorage:FindFirstChild(b.out)
	if not v then
		v = Instance.new("StringValue")
		v.Name = b.out
		v.Value = "[]"
		v.Parent = ReplicatedStorage
	end
	b.value = v
	local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, b.store)
	b.ds = ok and store or nil
end

local names = {}
local function nameOf(userId)
	if names[userId] then return names[userId] end
	local p = Players:GetPlayerByUserId(userId)
	if p then names[userId] = p.DisplayName return names[userId] end
	local ok, n = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	names[userId] = ok and n or "Operator"
	return names[userId]
end

local function entry(b, uid, name, raw)
	raw = math.max(0, math.floor(tonumber(raw) or 0))
	if b.level then return { u = uid, n = name, w = levelOf(raw), x = raw } end
	return { u = uid, n = name, w = raw }
end

local function localList(b)
	local list = {}
	for _, p in Players:GetPlayers() do
		local data = PlayerStore.Get(p)
		table.insert(list, entry(b, p.UserId, p.DisplayName, data and b.get(data) or 0))
	end
	table.sort(list, function(a, c) return (a.x or a.w) > (c.x or c.w) end)
	return list
end

local function refresh(b)
	local list
	if b.ds then
		for _, p in Players:GetPlayers() do
			local data = PlayerStore.Get(p)
			if data and p.UserId > 0 then
				pcall(b.ds.SetAsync, b.ds, tostring(p.UserId), math.max(0, math.floor(tonumber(b.get(data)) or 0)))
			end
		end
		local ok, pages = pcall(b.ds.GetSortedAsync, b.ds, false, 10)
		if ok and pages then
			list = {}
			for _, e in pages:GetCurrentPage() do
				local uid = tonumber(e.key)
				if uid then table.insert(list, entry(b, uid, nameOf(uid), e.value)) end
			end
		end
	end
	if not list or #list == 0 then list = localList(b) end
	b.value.Value = HttpService:JSONEncode(list)
end

local function refreshAll()
	for _, b in BOARDS do pcall(refresh, b) end
end

task.delay(8, refreshAll)
while true do
	task.wait(60)
	refreshAll()
end
