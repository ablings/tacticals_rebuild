-- test_lobby_install.lua [TESTPLACE] round 1, 2026-10-28 (notes/test_place.md): the lobby's way into the admin-only Test place.
--     python tools/test_place_build.py lobby <studio window name> [UNDO]
--   * LobbyConfig.TestPlaceId = TEST_PLACE_ID (0 = "not set up": ;testplace says so). A re-run with another id only changes the id.
--   * AdminFramework.Commands.TestPlace (new): ;testplace [shared|new] (aliases ;testmaps, ;gotest), level Admin: reserves a Test
--     server (shared = the one every admin meets in; new = a private one), saves + releases the profile, teleports. It shows in
--     the admin panel API ("commands") with its choices like every other command.
-- Idempotent; every anchor checked before any write; UNDO restores LobbyConfig (backup TEST_LobbyConfig_Orig) and removes the module.
local UNDO = false --@UNDO
local TEST_PLACE_ID = 0 --@ID
local ROUND = 1

local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local SSS = game:GetService("ServerScriptService")
local CHS = game:GetService("ChangeHistoryService")
assert(workspace:FindFirstChild("LobbyMap") ~= nil, "this is not the lobby (no Workspace.LobbyMap)")

local log = {}
local function say(...) local t = {} for _, v in ipairs({ ... }) do table.insert(t, tostring(v)) end table.insert(log, table.concat(t, " ")) end
local function fnv(s: string): string
	local h = 2166136261
	for i = 1, #s do h = bit32.bxor(h, string.byte(s, i)); h = (h * 16777619) % 4294967296 end
	return string.format("%08x", h)
end

--@EMBED_BEGIN (tools/test_place_build.py copies scripts/admin/Commands/TestPlace.lua here)
local TESTCMD_SRC = [=[
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
]=]
--@EMBED_END

local cfg = RS.Modules.Shared.Config:FindFirstChild("LobbyConfig")
local cmds = SSS:FindFirstChild("AdminFramework") and SSS.AdminFramework:FindFirstChild("Commands")
local function stateHash()
	return fnv((cfg and cfg.Source or "-") .. "|" .. tostring(cmds and cmds:FindFirstChild("TestPlace") and fnv(cmds.TestPlace.Source)) .. "|" .. tostring(SSS:GetAttribute("TestLobbyInstallRound")))
end
say("before:", stateHash())

local ANCHOR = "LobbyConfig.RankedPlaceId = 122908502889013 -- [SPLIT] Ranked place (created 2026-10-17)\n"
local function line(id: number): string
	return "-- [TESTPLACE] the admin-only Test place (notes/test_place.md): ;testplace reserves a server there. 0 = not set up yet\n"
		.. "LobbyConfig.TestPlaceId = " .. tostring(id) .. "\n"
end
local function count(s: string, needle: string): number
	local n, i = 0, 1
	while true do local a, b = s:find(needle, i, true) if not a then return n end n += 1; i = b + 1 end
end

local rec = CHS:TryBeginRecording("TESTPLACE lobby " .. (UNDO and "UNDO" or ("round " .. ROUND)))
local bin = SS:FindFirstChild("_RebuildRemoved") or Instance.new("Folder")
bin.Name = "_RebuildRemoved"; bin.Parent = SS
if UNDO then
	local bak = bin:FindFirstChild("TEST_LobbyConfig_Orig")
	local s = cfg.Source
	local a, b = s:find("%-%- %[TESTPLACE%] the admin%-only Test place[^\n]*\nLobbyConfig%.TestPlaceId = %d+\n")
	if a then cfg.Source = s:sub(1, a - 1) .. s:sub(b + 1); say("UNDO LobbyConfig.TestPlaceId") else say("LobbyConfig had no TestPlaceId") end
	if bak then say("LobbyConfig", bak.Source == cfg.Source and "matches its backup" or "WARN differs from its backup"); bak:Destroy() end
	local c = cmds and cmds:FindFirstChild("TestPlace")
	if c and c:GetAttribute("TestPlaceInstall") then c:Destroy(); say("removed Commands.TestPlace") end
	SSS:SetAttribute("TestLobbyInstallRound", nil)
else
	local stamped = SSS:GetAttribute("TestLobbyInstallRound")
	assert(stamped == nil or stamped == ROUND, "another round is installed: UNDO it first")
	local bad = {}
	if not cfg then table.insert(bad, "no LobbyConfig") end
	if not cmds then table.insert(bad, "no AdminFramework.Commands") end
	local has = cfg and cfg.Source:match("\nLobbyConfig%.TestPlaceId = (%d+)\n")
	if cfg and not has and count(cfg.Source, ANCHOR) ~= 1 then table.insert(bad, "LobbyConfig anchor found " .. count(cfg.Source, ANCHOR) .. " times") end
	if #bad > 0 then
		if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Cancel) end
		return "REFUSED (nothing written): " .. table.concat(bad, "; ")
	end
	SSS:SetAttribute("TestLobbyInstallRound", ROUND)
	if has then
		if tonumber(has) == TEST_PLACE_ID then say("LobbyConfig.TestPlaceId already", has)
		else
			cfg.Source = cfg.Source:gsub("\nLobbyConfig%.TestPlaceId = %d+\n", "\nLobbyConfig.TestPlaceId = " .. TEST_PLACE_ID .. "\n", 1)
			say("LobbyConfig.TestPlaceId", has, "->", TEST_PLACE_ID)
		end
	else
		if not bin:FindFirstChild("TEST_LobbyConfig_Orig") then local b = cfg:Clone(); b.Name = "TEST_LobbyConfig_Orig"; b:ClearAllChildren(); b.Parent = bin end
		local a, z = cfg.Source:find(ANCHOR, 1, true)
		cfg.Source = cfg.Source:sub(1, z) .. line(TEST_PLACE_ID) .. cfg.Source:sub(z + 1)
		say("LobbyConfig.TestPlaceId =", TEST_PLACE_ID, "added")
	end
	local c = cmds:FindFirstChild("TestPlace")
	if not c then
		c = Instance.new("ModuleScript"); c.Name = "TestPlace"; c:SetAttribute("TestPlaceInstall", true)
		c.Source = TESTCMD_SRC; c.Parent = cmds
		say("added AdminFramework.Commands.TestPlace")
	elseif c.Source ~= TESTCMD_SRC then c.Source = TESTCMD_SRC; say("updated AdminFramework.Commands.TestPlace")
	else say("Commands.TestPlace already in") end
end
if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
say("after:", stateHash())
return table.concat(log, "\n")
