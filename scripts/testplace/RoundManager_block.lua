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

