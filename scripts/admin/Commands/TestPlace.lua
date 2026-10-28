-- AdminFramework/Commands/TestPlace [TESTPLACE] 2026-10-28 (notes/test_place.md): the admin-only Test place, where new maps are
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
