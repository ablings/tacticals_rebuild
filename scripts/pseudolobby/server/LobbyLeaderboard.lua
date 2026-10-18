-- [PSEUDOLOBBY] copied from the hub (2026-10-18) for the match places' after-match lobby; changes are tagged [PSEUDOLOBBY].
-- LobbyLeaderboard: global top 10 by Wins for the hub leaderboard screen.
-- Every minute: push each player's Stats.Wins into an OrderedDataStore, then read the top 10 and
-- publish it as JSON in ReplicatedStorage.LobbyTopWins. If DataStores are unavailable (e.g. Studio
-- without API access) it falls back to the players in this server.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")
local out = game.ReplicatedStorage:WaitForChild("LobbyTopWins")
local PlayerStore = require(ServerScriptService.Data.PlayerStore)

local okStore, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, "TopWins_v1")
local names = {}

local function nameOf(userId)
	if names[userId] then return names[userId] end
	local p = Players:GetPlayerByUserId(userId)
	if p then names[userId] = p.DisplayName return names[userId] end
	local ok, n = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	names[userId] = ok and n or "Operator"
	return names[userId]
end

local function localList()
	local list = {}
	for _, p in Players:GetPlayers() do
		local data = PlayerStore.Get(p)
		table.insert(list, { u = p.UserId, n = p.DisplayName, w = data and data.Stats and data.Stats.Wins or 0 })
	end
	table.sort(list, function(a, b) return a.w > b.w end)
	return list
end

local function refresh()
	local list
	if okStore and store then
		for _, p in Players:GetPlayers() do
			local data = PlayerStore.Get(p)
			if data and data.Stats and p.UserId > 0 then
				pcall(store.SetAsync, store, tostring(p.UserId), data.Stats.Wins or 0)
			end
		end
		local ok, pages = pcall(store.GetSortedAsync, store, false, 10)
		if ok and pages then
			list = {}
			for _, e in pages:GetCurrentPage() do
				local uid = tonumber(e.key)
				if uid then table.insert(list, { u = uid, n = nameOf(uid), w = e.value }) end
			end
		end
	end
	if not list or #list == 0 then list = localList() end
	out.Value = HttpService:JSONEncode(list)
end

task.delay(8, refresh)
while true do
	task.wait(60)
	pcall(refresh)
end
