-- test_place_install.lua [TESTPLACE] round 2, 2026-10-28 (notes/test_place.md): the code of the admin-only Test place.
-- Run on an opened COPY of the match place AFTER `split_build.py place <id> Test` (that sets ReplicatedStorage.PlaceKind = "Test"
-- and routes a Test server to manager.RunTestPlace):
--     python tools/test_place_build.py place <window name> [UNDO]
-- Idempotent (a second run: every edit "already in"); UNDO puts every script back (hashes printed before / after).
-- Every anchor in every target is checked BEFORE anything is written; the round is stamped first (ServerScriptService attribute
-- TestPlaceInstallRound) and another round's install is refused. Backups: ServerStorage._RebuildRemoved.TEST_<name>_Orig.
-- What it does (all of it a no-op where PlaceKind isn't "Test", so the files can stay byte-identical with the other places):
--   RoundManager    the Test runner block (scripts/testplace/RoundManager_block.lua): admin gate, waiting area, staging maps,
--                   manager.StartTest; runMatchServer: test bots live, no stranger kick, no hop to the lobby on a cancel, the
--                   picked map only; award: a Test match pays nothing (TestMatch / TestPlace in the results); waiting deaths
--                   respawn during a match too.
--   DataManager     view-only profiles on the Test place (no session lock, never saved; a template copy for a new player).
--   LobbyManager    ProcessReceipt answers NotProcessedYet on the Test place (Roblox retries it in the lobby, where it is saved).
--   LobbyLeaderboard  no board writes from the Test place.
--   AdminFramework  Commands/TestPlace (new: ;maplist, ;testmatch); Commands/Duel ;endmatch says where players go.
--   ServerStorage.StagingMaps (empty Folder) if missing: map builders put staging maps there.
local UNDO = false --@UNDO
local ROUND = 2

local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local SSS = game:GetService("ServerScriptService")
local CHS = game:GetService("ChangeHistoryService")
assert(workspace:FindFirstChild("LobbyMap") == nil, "this is the lobby: use fix/test_lobby_install.lua")
local kind = RS:FindFirstChild("PlaceKind")
assert(UNDO or (kind and kind.Value == "Test"), "run split_build.py place <id> Test first (PlaceKind must be Test)")

local log = {}
local function say(...) local t = {} for _, v in ipairs({ ... }) do table.insert(t, tostring(v)) end table.insert(log, table.concat(t, " ")) end
local function fnv(s: string): string
	local h = 2166136261
	for i = 1, #s do h = bit32.bxor(h, string.byte(s, i)); h = (h * 16777619) % 4294967296 end
	return string.format("%08x", h)
end
local function manager(name)
	local init = SSS:FindFirstChild("ServerScripts") and SSS.ServerScripts:FindFirstChild("[Server] Init")
	local m = init and init:FindFirstChild("GameManager") and init.GameManager:FindFirstChild("Managers")
	return m and m:FindFirstChild(name)
end
local fw = SSS:FindFirstChild("AdminFramework")
local cmds = fw and fw:FindFirstChild("Commands")
local TARGETS = {
	RoundManager = function() return manager("RoundManager") end,
	DataManager = function() return SSS:FindFirstChild("Data") and SSS.Data:FindFirstChild("DataManager") end,
	LobbyManager = function() return manager("LobbyManager") end,
	LobbyLeaderboard = function() return SSS:FindFirstChild("LobbyLeaderboard") end,
	Duel = function() return cmds and cmds:FindFirstChild("Duel") end,
}
local ORDER = { "RoundManager", "DataManager", "LobbyManager", "LobbyLeaderboard", "Duel" }

local function stateHash()
	local parts = {}
	for _, n in ORDER do local s = TARGETS[n](); table.insert(parts, n .. "=" .. (s and fnv(s.Source) or "-")) end
	table.insert(parts, "TestPlaceCmd=" .. tostring(cmds and cmds:FindFirstChild("TestPlace") ~= nil))
	table.insert(parts, "StagingMaps=" .. tostring(SS:FindFirstChild("StagingMaps") ~= nil))
	table.insert(parts, "round=" .. tostring(SSS:GetAttribute("TestPlaceInstallRound")))
	local bin = SS:FindFirstChild("_RebuildRemoved")
	local baks = 0
	if bin then for _, c in bin:GetChildren() do if c.Name:match("^TEST_") then baks += 1 end end end
	table.insert(parts, "backups=" .. baks)
	return fnv(table.concat(parts, ";")), table.concat(parts, "; ")
end
local h0, d0 = stateHash()
say("before:", h0, "(" .. d0 .. ")")

--@EMBED_BEGIN (tools/test_place_build.py copies scripts/testplace/RoundManager_block.lua and scripts/admin/Commands/TestPlace.lua here)
local RM_BLOCK = [=[
-- [TESTPLACE] 2026-10-28 (notes/test_place.md): the admin-only Test place (ReplicatedStorage.PlaceKind = "Test"). Inserted into
-- RoundManager by fix/test_place_install.lua, right before manager.Start (setState, spawnPlayer, backToLobby, runMatchServer,
-- endMatchRecord, applyMapEnv and `current` are in scope). Nothing here runs unless splitFirst routes a Test server to
-- manager.RunTestPlace.
--   * Gate: every player is checked with AdminFramework.Permissions (UserId list / group rank; level TP_LEVEL or higher) on
--     arrival and again every TP.recheck s. Anyone else gets no body, the notice "ADMINS ONLY", and the reject path back to the
--     lobby (profile released first); still here after 3 notices = kicked.
--   * Waiting area: admins spawn at the place's SpawnLocation with free practice between matches (MatchState "Waiting").
--   * Test match: an admin picks the map (any ReplicatedStorage.DuelMaps map, or a staging map from ServerStorage.StagingMaps,
--     placed into Workspace on first use), the mode (1v1 / 2v2 / 3v3) and bots or the other admins (manager.StartTest, from
--     ;testmatch). It runs the normal match flow (runMatchServer) with no map vote, test bots allowed live, and pays nothing
--     (award: match.testPlace). The data layer only opens view-only copies here (DataManager [TESTPLACE]), so nothing is saved.
local TP_LEVEL = "Admin"
local TP = { admins = {}, denied = {}, spawning = {}, pending = nil, running = nil, log = {}, retry = 15, recheck = 10, notices = 3 }
manager._testPlace = nil -- true once this server runs as the Test place
manager._tp = TP

local function tpLog(line: string)
	table.insert(TP.log, ("%.1f %s"):format(os.clock(), line))
	if #TP.log > 100 then table.remove(TP.log, 1) end
end

local function tpPermissions()
	local fw = ServerScriptService:FindFirstChild("AdminFramework")
	local mod = fw and fw:FindFirstChild("Permissions")
	if not mod then return nil end
	local ok, P = pcall(require, mod)
	return ok and P or nil
end

-- (admin?, why) from the admin framework; no framework = nobody gets in
local function tpIsAdmin(p: Player): (boolean, string)
	local P = tpPermissions()
	if not P then return false, "no AdminFramework on this place" end
	local ok, lv, why = pcall(P.LevelOf, p)
	if not ok then return false, "level check failed: " .. tostring(lv) end
	return lv >= P.Value(TP_LEVEL), tostring(why) .. " = " .. P.Name(lv)
end

local function tpDeny(p: Player, why: string)
	if TP.denied[p] then return end
	local d = { why = why, tries = 0 }
	TP.denied[p] = d
	TP.admins[p] = nil
	p:SetAttribute("TestPlaceAdmin", nil)
	tpLog(p.Name .. " denied (" .. why .. ")")
	warn(("[RoundManager] [TESTPLACE] %s (%d) is not an admin (%s): back to the lobby"):format(p.Name, p.UserId, why))
	-- out of a running test match (a demoted admin), and no body: they can't play or watch from in here
	local m = current and current.byUser[p.UserId]
	if m and not m.left then m.left = true end
	p:SetAttribute("InMatch", false)
	-- (Destroy alone leaves Player.Character pointing at the dead model: clear it too)
	if p.Character then p.Character:Destroy(); p.Character = nil end
	task.spawn(function()
		while p.Parent and TP.denied[p] == d do
			d.tries += 1
			Announce:FireClient(p, "ADMINS ONLY", "This test server is for admins. Taking you back to the lobby...")
			task.wait(4)
			if not p.Parent or TP.denied[p] ~= d then break end
			if d.tries >= TP.notices then
				tpLog(p.Name .. " kicked (still here after " .. d.tries .. " notices)")
				p:Kick("This test server is for admins only.")
				break
			end
			backToLobby({ p })
			task.wait(TP.retry)
		end
	end)
end

local function tpCheck(p: Player)
	if not p.Parent or TP.denied[p] then return end
	local ok, why = tpIsAdmin(p)
	if not p.Parent or TP.denied[p] then return end
	if ok then
		if not TP.admins[p] then
			TP.admins[p] = true
			p:SetAttribute("TestPlaceAdmin", true)
			tpLog(p.Name .. " admitted (" .. why .. ")")
		end
	else
		tpDeny(p, why)
	end
end

-- // Maps: live (ReplicatedStorage.DuelMaps) + staging (ServerStorage.StagingMaps.<Id> = { MapInfo, Workspace = { models } }) ---
local function tpStagingRoot() return ServerStorage:FindFirstChild("StagingMaps") end

local function tpModes(folder: Instance, info): { string }
	local attr = folder:GetAttribute("Modes")
	if type(attr) == "string" and attr ~= "" then
		local list = {}
		for m in attr:gmatch("[^,%s]+") do table.insert(list, m) end
		return list
	end
	return type(info.Modes) == "table" and info.Modes or {}
end

-- every map an admin can test: { id, name, modes, staging }
function manager.TestMapList()
	local out, seen = {}, {}
	for _, info in MapRegistry.List() do
		seen[info.Id] = true
		table.insert(out, { id = info.Id, name = info.DisplayName or info.Id, modes = info.Modes or {}, staging = info.Folder:GetAttribute("Staging") == true })
	end
	local root = tpStagingRoot()
	for _, f in (root and root:GetChildren() or {}) do
		local mod = f:FindFirstChild("MapInfo")
		if mod and mod:IsA("ModuleScript") and not seen[f.Name] then
			local ok, info = pcall(require, mod)
			if not (ok and type(info) == "table") then info = {} end
			table.insert(out, { id = f.Name, name = info.DisplayName or f.Name, modes = tpModes(f, info), staging = true })
		end
	end
	table.sort(out, function(a, b) return a.id < b.id end)
	return out
end

-- the world-axis box of a model (GetBoundingBox is oriented like the model's pivot: convert before comparing)
local function tpWorldBox(model: Model): (Vector3, Vector3)
	local cf, size = model:GetBoundingBox()
	local h = size / 2
	local ext = Vector3.new(
		math.abs(cf.XVector.X) * h.X + math.abs(cf.YVector.X) * h.Y + math.abs(cf.ZVector.X) * h.Z,
		math.abs(cf.XVector.Y) * h.X + math.abs(cf.YVector.Y) * h.Y + math.abs(cf.ZVector.Y) * h.Z,
		math.abs(cf.XVector.Z) * h.X + math.abs(cf.YVector.Z) * h.Y + math.abs(cf.ZVector.Z) * h.Z)
	return cf.Position - ext, cf.Position + ext
end
local function tpOverlap(a0: Vector3, a1: Vector3, b0: Vector3, b1: Vector3): boolean
	return a0.X < b1.X and a1.X > b0.X and a0.Y < b1.Y and a1.Y > b0.Y and a0.Z < b1.Z and a1.Z > b0.Z
end

-- a staging map is placed on first use: copies of its Workspace models go into Workspace and a copy of its registry entry
-- (everything but the Workspace folder, attribute Staging = true) into ReplicatedStorage.DuelMaps, so the match code, the
-- clients and the map's lighting find it like any live map. The ServerStorage source stays untouched.
local function tpPlaceStaging(id: string): (boolean, string?)
	local dm = ReplicatedStorage:FindFirstChild("DuelMaps")
	if dm and dm:FindFirstChild(id) then return true end
	local root = tpStagingRoot()
	local src = root and root:FindFirstChild(id)
	local infoModule = src and src:FindFirstChild("MapInfo")
	if not infoModule then return false, "no map " .. id end
	local wsFolder = src:FindFirstChild("Workspace")
	if not wsFolder or #wsFolder:GetChildren() == 0 then return false, ("staging map %s has no Workspace folder with its map model"):format(id) end
	local okI, info = pcall(require, infoModule)
	if not (okI and type(info) == "table") then return false, ("staging map %s: MapInfo doesn't load (%s)"):format(id, tostring(info)) end
	local mainName = info.WorkspaceName or id
	if not wsFolder:FindFirstChild(mainName) then
		return false, ("staging map %s: its Workspace folder has no model named %s (MapInfo.WorkspaceName)"):format(id, mainName)
	end
	local clones = {}
	local function drop() for _, c in clones do c:Destroy() end end
	for _, c in wsFolder:GetChildren() do
		if workspace:FindFirstChild(c.Name) then drop() return false, ("Workspace already has a %s: rename the staging model"):format(c.Name) end
		table.insert(clones, c:Clone())
	end
	for _, c in clones do
		if c:IsA("Model") then
			local a0, a1 = tpWorldBox(c)
			for _, other in MapRegistry.List() do
				local om = workspace:FindFirstChild(other.WorkspaceName or other.Id)
				if om and om:IsA("Model") then
					local b0, b1 = tpWorldBox(om)
					if tpOverlap(a0, a1, b0, b1) then
						drop()
						return false, ("staging map %s overlaps %s in Workspace: build it at a free spot (notes/test_place.md)"):format(id, other.Id)
					end
				end
			end
		end
	end
	for _, c in clones do c.Parent = workspace end
	local reg = Instance.new("Folder")
	reg.Name = src.Name
	for k, v in src:GetAttributes() do reg:SetAttribute(k, v) end
	reg:SetAttribute("Staging", true)
	for _, c in src:GetChildren() do if c ~= wsFolder then c:Clone().Parent = reg end end
	if not dm then dm = Instance.new("Folder"); dm.Name = "DuelMaps"; dm.Parent = ReplicatedStorage end
	reg.Parent = dm
	tpLog("staging map " .. id .. " placed (" .. #clones .. " model(s))")
	return true
end

-- the one map of a test match (runMatchServer asks for it instead of the vote list)
function manager.TestMapsFor(first)
	local info = MapRegistry.Get(first.TestMap)
	return info and { info } or {}
end

local TP_MODES = { ["1v1"] = 1, ["2v2"] = 2, ["3v3"] = 3 }
-- start a test match: caller (an admin checked in here), map id, "1v1" / "2v2" / "3v3", "bots" / "admins" -> ok, message
function manager.StartTest(caller: Player, mapId: string, mode: string, vs: string): (boolean, string)
	if not manager._testPlace then return false, "this server isn't the Test place" end
	if not TP.admins[caller] then return false, "only an admin checked in on this Test server can start a match" end
	if TP.pending or TP.running then return false, "a test match is already running (;endmatch ends it)" end
	local n = TP_MODES[mode]
	if not n then return false, "mode must be 1v1, 2v2 or 3v3" end
	if vs ~= "bots" and vs ~= "admins" then return false, "vs must be bots or admins" end
	local entry = nil
	for _, e in manager.TestMapList() do if string.lower(e.id) == string.lower(tostring(mapId)) then entry = e end end
	if not entry then return false, ("no map %s (;maplist shows them)"):format(tostring(mapId)) end
	local okPlace, why = tpPlaceStaging(entry.id)
	if not okPlace then return false, why or "the staging map couldn't be placed" end
	local A, B = { caller.UserId }, {}
	if vs == "admins" then
		local others = {}
		for p in TP.admins do if p ~= caller and p.Parent then table.insert(others, p) end end
		if #others == 0 then return false, "no other admin on this server: use bots, or have them join with ;testplace in the lobby" end
		table.sort(others, function(x, y) return x.UserId < y.UserId end)
		for i, p in others do
			if i % 2 == 1 and #B < n then table.insert(B, p.UserId)
			elseif #A < n then table.insert(A, p.UserId)
			elseif #B < n then table.insert(B, p.UserId) end
		end
	end
	local realA, realB = #A, #B
	while #A < n do table.insert(A, "bot") end
	while #B < n do table.insert(B, "bot") end
	TP.pending = { Mode = mode, Ranked = false, Teams = { A = A, B = B }, TestPlace = true, TestMap = entry.id, By = caller.UserId }
	local note = ""
	if not table.find(entry.modes, mode) then note = (" (the map lists %s: spawns may crowd)"):format(table.concat(entry.modes, ",")) end
	tpLog(("%s started %s %s vs %s"):format(caller.Name, entry.id, mode, vs))
	return true, ("Starting a %s test match on %s%s: %d admin(s) + %d bot(s) vs %d admin(s) + %d bot(s). Nothing is saved here.%s"):format(
		mode, entry.name, entry.staging and " [STAGING]" or "", realA, n - realA, realB, n - realB, note)
end

local function tpWaiting()
	ReplicatedStorage:SetAttribute("LiveMatch", false)
	ReplicatedStorage:SetAttribute("TestMode", false)
	ReplicatedStorage:SetAttribute("InfiniteAmmo", false)
	setState("Waiting")
end

local function tpSpawnIdle()
	local runningIds = {}
	if TP.running then for _, ids in TP.running.Teams do for _, id in ids do if type(id) == "number" then runningIds[id] = true end end end end
	for _, p in Players:GetPlayers() do
		local body = p.Character
		if TP.admins[p] and not (body and body.Parent) and not TP.spawning[p] and not p:GetAttribute("InMatch") and not runningIds[p.UserId] then
			TP.spawning[p] = true
			task.spawn(function()
				spawnPlayer(p, nil)
				TP.spawning[p] = nil
			end)
		end
	end
end

function manager.RunTestPlace()
	manager._testPlace = true
	C.DuelMapVote = false -- the admin picked the map: no vote here
	ReplicatedStorage:SetAttribute("TestPlace", true)
	print(("[RoundManager] [TESTPLACE] Test place: admins only (%s+), nothing is saved here"):format(TP_LEVEL))
	Players.PlayerAdded:Connect(function(p) task.spawn(tpCheck, p) end)
	Players.PlayerRemoving:Connect(function(p) TP.admins[p] = nil; TP.denied[p] = nil; TP.spawning[p] = nil end)
	for _, p in Players:GetPlayers() do task.spawn(tpCheck, p) end
	-- a demoted admin (admin list / group rank change; Studio ;simlevel) loses access within TP.recheck s
	task.spawn(function()
		while true do
			task.wait(TP.recheck)
			for p in TP.admins do task.spawn(tpCheck, p) end
		end
	end)
	task.spawn(function()
		while true do
			tpSpawnIdle()
			task.wait(0.5)
		end
	end)
	tpWaiting()
	while true do
		local first = TP.pending
		if first then
			TP.running = first
			local ok, err = pcall(runMatchServer, first)
			if not ok then
				warn("[RoundManager] [TESTPLACE] test match failed: " .. tostring(err))
				announce("TEST MATCH FAILED", tostring(err))
			end
			if current then endMatchRecord(current) end
			for _, p in Players:GetPlayers() do
				p:SetAttribute("InMatch", false)
				p:SetAttribute("LoadoutReady", nil)
			end
			applyMapEnv(nil) -- the place's own spawns + lighting
			TP.pending, TP.running = nil, nil
			tpWaiting()
			-- fresh bodies in the waiting area (a match leaves frozen or arena bodies behind): LoadCharacter replaces the old one
			for _, p in Players:GetPlayers() do
				if TP.admins[p] and not TP.spawning[p] then
					TP.spawning[p] = true
					task.spawn(function()
						spawnPlayer(p, nil)
						TP.spawning[p] = nil
					end)
				end
			end
			tpLog("test match over: " .. tostring(first.TestMap))
		end
		task.wait(0.25)
	end
end

-- Studio-only evidence for the tests (ServerStorage.TestPlaceHook, BindableFunction)
if IS_STUDIO then
	local hook = ServerStorage:FindFirstChild("TestPlaceHook") or Instance.new("BindableFunction")
	hook.Name = "TestPlaceHook"
	hook.OnInvoke = function(cmd: string, a, b, c, d)
		if cmd == "info" then
			local admins, denied = {}, {}
			for p in TP.admins do table.insert(admins, p.Name) end
			for p, x in TP.denied do table.insert(denied, p.Name .. ": " .. x.why .. " (" .. x.tries .. " notices)") end
			return { testPlace = manager._testPlace == true, admins = admins, denied = denied, running = TP.running and TP.running.TestMap or nil,
				pending = TP.pending and TP.pending.TestMap or nil, returns = #manager._returns, log = table.concat(TP.log, " | ") }
		elseif cmd == "start" then
			return manager.StartTest(Players:GetPlayerByUserId(a), b, c or "1v1", d or "bots")
		elseif cmd == "set" then
			local old = TP[a]; TP[a] = b; return old
		elseif cmd == "maps" then
			return manager.TestMapList()
		elseif cmd == "view" then
			-- the data layer's evidence: this player's profile is a view-only copy (never saved)
			local DM = require(ServerScriptService.Data.DataManager)
			local p = Players:GetPlayerByUserId(a)
			local prof = p and DM.Profiles[p]
			return { viewOnly = DM.ViewOnly == true, viewMode = prof ~= nil and prof._view_mode == true, active = prof ~= nil and prof:IsActive() }
		end
		return "unknown " .. tostring(cmd)
	end
	hook.Parent = ServerStorage
end

]=]
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

local DM_BLOCK = [==[
-- [TESTPLACE] the admin-only Test place (ReplicatedStorage.PlaceKind = "Test", notes/test_place.md) saves nothing: profiles are
-- opened as view-only copies (ProfileService view mode: no session lock, Save / Release / listeners are no-ops), so the lobby
-- always keeps the real save and whatever happens here (test matches, admin commands, settings) is thrown away on leaving.
local TEST_PLACE = (function()
	local v = repStorage:FindFirstChild("PlaceKind")
	return v ~= nil and v:IsA("StringValue") and v.Value == "Test"
end)()
dataManager.ViewOnly = TEST_PLACE
local function deepCopy(t)
	if type(t) ~= "table" then return t end
	local c = {}
	for k, v in t do c[k] = deepCopy(v) end
	return c
end
local function noop() end
local function noConn() return { Disconnect = noop } end
-- a new player (no save yet) or a store that can't be read: a template copy that behaves like a view-only profile
local function viewStub()
	return { Data = deepCopy(Template), MetaData = { SessionLoadCount = 0, MetaTags = {} }, UserIds = {}, _view_mode = true,
		IsActive = function() return false end, Release = noop, Save = noop, Reconcile = noop, AddUserId = noop,
		ListenToRelease = noConn, ListenToHopReady = noConn }
end
local function loadViewOnly(player: Player)
	local ok, profile = pcall(profileStore.ViewProfileAsync, profileStore, "Player_" .. player.UserId)
	if ok and profile then return profile end
	if not ok then warn("[DATA] [TESTPLACE] view of " .. player.Name .. " failed (" .. tostring(profile) .. "): template copy") end
	return viewStub()
end
]==]

local EDITS = {
	-- RoundManager 1: the Test runner block, before manager.Start
	{ "RoundManager", "function manager.Start()\n", "@RM_BLOCK" },
	-- RoundManager 2: test bots on the Test place (live too; they never pay)
	{ "RoundManager",
		"\t\t\t\tif IS_STUDIO and (id == \"bot\" or (n and n <= 0)) then bots[side] += 1\n",
		"\t\t\t\t-- [TESTPLACE] test bots also on the Test place (live); a Test match never pays\n"
			.. "\t\t\t\t-- (a player who is here is never a bot: Studio's Server + Clients test gives real players ids -1, -2...)\n"
			.. "\t\t\t\tif (IS_STUDIO or first.TestPlace == true) and (id == \"bot\" or (n and n <= 0 and not Players:GetPlayerByUserId(n))) then bots[side] += 1\n" },
	-- RoundManager 3: a cancelled test match stays on the Test place
	{ "RoundManager",
		"\t\ttask.wait(5)\n\t\tbackToLobby(Players:GetPlayers())\n\t\treturn\n\tend\n\t-- strangers (not on either list) can't play here\n",
		"\t\ttask.wait(5)\n"
			.. "\t\t-- [TESTPLACE] a cancelled test match goes back to the Test place's waiting area, not the lobby\n"
			.. "\t\tif first.TestPlace ~= true then backToLobby(Players:GetPlayers()) end\n"
			.. "\t\treturn\n\tend\n\t-- strangers (not on either list) can't play here\n" },
	-- RoundManager 4: the other admins on the Test place stay (they watch / wait)
	{ "RoundManager",
		"\t\tif not expected[p.UserId] then p:Kick(\"This match server is private.\") end\n",
		"\t\t-- [TESTPLACE] admins not in the test match stay on the Test place\n"
			.. "\t\tif not expected[p.UserId] and first.TestPlace ~= true then p:Kick(\"This match server is private.\") end\n" },
	-- RoundManager 5: the match knows it is a test match
	{ "RoundManager",
		"\tlocal match = newMatch(\"match\", first.Mode, first.Ranked == true, teams)\n",
		"\tlocal match = newMatch(\"match\", first.Mode, first.Ranked == true, teams)\n"
			.. "\t-- [TESTPLACE] a Test place match: no rewards, no stats, no ELO, no history (award)\n"
			.. "\tmatch.testPlace = first.TestPlace == true or nil\n" },
	-- RoundManager 6: the admin's map, no vote list
	{ "RoundManager",
		"\tlocal maps, fallback = eligibleMaps(first.Mode)\n",
		"\tlocal maps, fallback = eligibleMaps(first.Mode)\n"
			.. "\t-- [TESTPLACE] the map the admin picked (live or staging), whatever its modes\n"
			.. "\tif first.TestPlace == true and manager.TestMapsFor then maps, fallback = manager.TestMapsFor(first), false end\n" },
	-- RoundManager 7: a Test place match pays nothing, like a bot match
	{ "RoundManager",
		"\tif match.hasBot or match.aborted then\n\t\t-- [RANKED] RatingChange and the ELO fields stay as set above (only set when ELO really changed)\n\t\tsummary.XP, summary.Scissors, summary.GunXP = 0, 0, 0\n\t\tsummary.TestMatch = match.hasBot or nil\n",
		"\t-- [TESTPLACE] a Test place match never pays either (and its profile is a view-only copy that is never saved)\n"
			.. "\tif match.hasBot or match.aborted or match.testPlace then\n\t\t-- [RANKED] RatingChange and the ELO fields stay as set above (only set when ELO really changed)\n\t\tsummary.XP, summary.Scissors, summary.GunXP = 0, 0, 0\n"
			.. "\t\tsummary.TestMatch = (match.hasBot or match.testPlace) or nil\n"
			.. "\t\tsummary.TestPlace = match.testPlace\n" },
	-- RoundManager 8: on the Test place a waiting admin who dies respawns while a test match runs too
	{ "RoundManager",
		"\t\t\t\tif not player:GetAttribute(\"InMatch\") and not ReplicatedStorage:GetAttribute(\"LiveMatch\") then\n",
		"\t\t\t\t-- [TESTPLACE] (or manager._testPlace: admins waiting beside a running test match respawn too)\n"
			.. "\t\t\t\tif not player:GetAttribute(\"InMatch\") and (not ReplicatedStorage:GetAttribute(\"LiveMatch\") or manager._testPlace) then\n" },
	-- RoundManager 9: a test bot never takes a present player's id (Studio Server + Clients players are -1, -2...)
	{ "RoundManager",
		"\t\t\tbotN += 1\n\t\t\ttable.insert(teams[side], { isBot = true, userId = -botN, name = \"TestBot\" })\n",
		"\t\t\tbotN += 1\n"
			.. "\t\t\t-- [TESTPLACE] a test bot never takes a present player's id (Studio Server + Clients players are -1, -2...)\n"
			.. "\t\t\twhile Players:GetPlayerByUserId(-botN) do botN += 1 end\n"
			.. "\t\t\ttable.insert(teams[side], { isBot = true, userId = -botN, name = \"TestBot\" })\n" },
	-- DataManager 1: the Test place switch
	{ "DataManager",
		"dataManager.key = dataKey\n",
		"dataManager.key = dataKey\n@DM_BLOCK" },
	-- DataManager 2: view-only load
	{ "DataManager",
		"\tlocal profile = profileStore:LoadProfileAsync(\"Player_\"..player.UserId, \"ForceLoad\")\n",
		"\t-- [TESTPLACE] the Test place opens a view-only copy (never saved); every other place loads + locks as before\n"
			.. "\tlocal profile = if TEST_PLACE then loadViewOnly(player) else profileStore:LoadProfileAsync(\"Player_\"..player.UserId, \"ForceLoad\")\n" },
	-- LobbyManager: no purchase is granted where nothing is saved
	{ "LobbyManager",
		"MarketplaceService.ProcessReceipt = function(info)\n",
		"MarketplaceService.ProcessReceipt = function(info)\n"
			.. "\t-- [TESTPLACE] the Test place saves nothing: leave the receipt for the lobby (Roblox retries it there)\n"
			.. "\tlocal placeKind = game:GetService(\"ReplicatedStorage\"):FindFirstChild(\"PlaceKind\")\n"
			.. "\tif placeKind and placeKind.Value == \"Test\" then return Enum.ProductPurchaseDecision.NotProcessedYet end\n" },
	-- LobbyLeaderboard: no board writes from the Test place
	{ "LobbyLeaderboard",
		"\t\t\tif data and p.UserId > 0 then\n\t\t\t\tpcall(b.ds.SetAsync,",
		"\t\t\t-- [TESTPLACE] (not from the Test place: its values are test copies)\n"
			.. "\t\t\tif data and p.UserId > 0 and not (ReplicatedStorage:FindFirstChild(\"PlaceKind\") and ReplicatedStorage.PlaceKind.Value == \"Test\") then\n\t\t\t\tpcall(b.ds.SetAsync," },
	-- Duel ;endmatch: say where everyone goes
	{ "Duel",
		"\t\t\t\treturn true, \"Ending this server's match: no rewards, everyone goes back to the lobby.\"\n",
		"\t\t\t\t-- [TESTPLACE] on the Test place everyone stays (back to its waiting area)\n"
			.. "\t\t\t\tif rm._testPlace then return true, \"Ending this test match: nobody is paid, everyone goes back to the Test place's waiting area.\" end\n"
			.. "\t\t\t\treturn true, \"Ending this server's match: no rewards, everyone goes back to the lobby.\"\n" },
}
-- resolve the embedded blocks
for _, e in EDITS do
	if e[3] == "@RM_BLOCK" then e[3] = RM_BLOCK .. e[2] end
	if e[3]:find("@DM_BLOCK", 1, true) then e[3] = e[3]:gsub("@DM_BLOCK", function() return DM_BLOCK end) end
end

local function count(s: string, needle: string): number
	local n, i = 0, 1
	while true do
		local a, b = s:find(needle, i, true)
		if not a then return n end
		n += 1; i = b + 1
	end
end

local rec = CHS:TryBeginRecording("TESTPLACE install " .. (UNDO and "UNDO" or ("round " .. ROUND)))
local bin = SS:FindFirstChild("_RebuildRemoved") or Instance.new("Folder")
bin.Name = "_RebuildRemoved"; bin.Parent = SS

local stamped = SSS:GetAttribute("TestPlaceInstallRound")
if UNDO then
	for i = #EDITS, 1, -1 do
		local e = EDITS[i]
		local s = TARGETS[e[1]]()
		if s then
			local a, b = s.Source:find(e[3], 1, true)
			if a then s.Source = s.Source:sub(1, a - 1) .. e[2] .. s.Source:sub(b + 1); say("UNDO edit", i, e[1])
			elseif s.Source:find(e[2], 1, true) then say("edit", i, e[1], "not applied")
			else say("WARN edit", i, e[1], "neither text found (backup TEST_" .. e[1] .. "_Orig kept)") end
		end
	end
	for _, n in ORDER do
		local s = TARGETS[n]()
		local bak = bin:FindFirstChild("TEST_" .. n .. "_Orig")
		if s and bak then -- (every edit of this file was undone above; the split install keeps its own [TESTPLACE] lines)
			say(n, bak.Source == s.Source and "matches its backup" or "WARN differs from its backup")
			bak:Destroy()
		end
	end
	local c = cmds and cmds:FindFirstChild("TestPlace")
	if c and c:GetAttribute("TestPlaceInstall") then c:Destroy(); say("removed Commands.TestPlace") end
	local st = SS:FindFirstChild("StagingMaps")
	if st and st:GetAttribute("TestPlaceInstall") and #st:GetChildren() == 0 then st:Destroy(); say("removed the empty ServerStorage.StagingMaps") end
	SSS:SetAttribute("TestPlaceInstallRound", nil)
else
	assert(stamped == nil or stamped == ROUND, ("round %s is installed: UNDO it with that round's file first"):format(tostring(stamped)))
	-- 1. every anchor in every target, before any write
	local plan, bad = {}, {}
	for i, e in EDITS do
		local s = TARGETS[e[1]]()
		if not s then table.insert(bad, e[1] .. " missing")
		elseif count(s.Source, e[3]) == 1 then plan[i] = "in"
		elseif count(s.Source, e[2]) == 1 then plan[i] = "apply"
		else table.insert(bad, ("edit %d %s: anchor found %d times"):format(i, e[1], count(s.Source, e[2]))) end
	end
	if not cmds then table.insert(bad, "AdminFramework.Commands missing") end
	if #bad > 0 then
		if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Cancel) end
		return "REFUSED (nothing written): " .. table.concat(bad, "; ")
	end
	-- 2. stamp the round first (an interrupted run can be redone or undone)
	SSS:SetAttribute("TestPlaceInstallRound", ROUND)
	for i, e in EDITS do
		local s = TARGETS[e[1]]()
		if plan[i] == "in" then say("edit", i, e[1], "already in")
		else
			local name = "TEST_" .. e[1] .. "_Orig"
			if not bin:FindFirstChild(name) then -- taken before this file's first edit to that script
				local b = s:Clone(); b.Name = name; b:ClearAllChildren()
				if b:IsA("BaseScript") then b.Disabled = true end
				b.Parent = bin
			end
			local a, z = s.Source:find(e[2], 1, true)
			s.Source = s.Source:sub(1, a - 1) .. e[3] .. s.Source:sub(z + 1)
			say("edit", i, e[1], "applied")
		end
	end
	local c = cmds:FindFirstChild("TestPlace")
	if not c then
		c = Instance.new("ModuleScript"); c.Name = "TestPlace"; c:SetAttribute("TestPlaceInstall", true)
		c.Source = TESTCMD_SRC; c.Parent = cmds
		say("added AdminFramework.Commands.TestPlace")
	elseif c.Source ~= TESTCMD_SRC then c.Source = TESTCMD_SRC; say("updated AdminFramework.Commands.TestPlace")
	else say("Commands.TestPlace already in") end
	if not SS:FindFirstChild("StagingMaps") then
		local st = Instance.new("Folder"); st.Name = "StagingMaps"; st:SetAttribute("TestPlaceInstall", true); st.Parent = SS
		say("added ServerStorage.StagingMaps")
	end
end
if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
local h1, d1 = stateHash()
say("after:", h1, "(" .. d1 .. ")")
return table.concat(log, "\n")
