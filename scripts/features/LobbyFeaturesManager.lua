-- Managers/LobbyFeaturesManager (server, lobby place): the lobby feature pass (notes/features_done.md).
-- Flags: Shared.Config.LobbyFeaturesConfig (or ReplicatedStorage attribute LF_<Feature>). Own code; no other script edited.
--   * Off features: geometry moved to ServerStorage._LobbyFeaturesOff (DropPits also gives the Duels floor its collision back).
--   * 3  Drop pits: anyone inside a pit shaft (LobbyMap.Features.DropPits.Pit_*.Catch, box test 10x a second) is put back at
--        DropPits.ReturnPoint (the Duels start); player attribute LF_PitReturn = server time (the client fades).
--   * 19/21 Duels data: polls QueueManager's own GetQueue handler (LobbyRemotes.Handlers.GetQueue, read-only) and
--        MatchmakingManager's MM_Counts / MM_Status; publishes ReplicatedStorage attribute LF_LiveDuels (JSON) for the screens.
--        Started matches go to every lobby server over MessagingService (topic in the config) when it is available.
--   * 20 Likes goal attributes (LF_LikesCurrent/Goal/Reward) seeded from the config; rewarded-ad remote (stub until a
--        Developer Product id is set).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local manager = {}

local ok, LF = pcall(require, ReplicatedStorage.Modules.Shared.Config.LobbyFeaturesConfig)
local okR, Remotes = pcall(require, ServerScriptService.Lobby.LobbyRemotes)

local function offFolder()
	local f = ServerStorage:FindFirstChild("_LobbyFeaturesOff")
	if not f then f = Instance.new("Folder"); f.Name = "_LobbyFeaturesOff"; f.Parent = ServerStorage end
	return f
end

-- geometry of each feature
local function geometry(map, name)
	if name == "Leaderboard" then return map:FindFirstChild("Signs") and map.Signs:FindFirstChild("Screen_Leaderboard") end
	local f = map:FindFirstChild("Features")
	return f and f:FindFirstChild(name)
end

-------------------------------------------------------------------------------- 3: drop pits
local function startPits(map)
	local pits = map.Features:FindFirstChild("DropPits")
	local back = pits and pits:FindFirstChild("ReturnPoint")
	if not back then return end
	local catches = {}
	for _, d in pits:GetDescendants() do if d:IsA("BasePart") and d.Name == "Catch" then table.insert(catches, d) end end
	local last = {}
	local function inside(part, pos)
		local rel = part.CFrame:PointToObjectSpace(pos); local h = part.Size / 2
		return math.abs(rel.X) <= h.X and math.abs(rel.Y) <= h.Y and math.abs(rel.Z) <= h.Z
	end
	local function sendBack(p, char)
		if last[p] and os.clock() - last[p] < 1 then return end
		last[p] = os.clock()
		local root = char:FindFirstChild("HumanoidRootPart")
		if root then root.AssemblyLinearVelocity = Vector3.zero end
		char:PivotTo(back.CFrame + Vector3.new(0, 3, 0))
		p:SetAttribute("LF_PitReturn", workspace:GetServerTimeNow())
	end
	Players.PlayerRemoving:Connect(function(p) last[p] = nil end)
	task.spawn(function()
		while pits.Parent and pits:IsDescendantOf(workspace) do
			task.wait(0.1)
			for _, p in Players:GetPlayers() do
				local c = p.Character; local r = c and c:FindFirstChild("HumanoidRootPart")
				if r and not p:GetAttribute("InTraining") then
					for _, k in catches do if inside(k, r.Position) then sendBack(p, c) break end end
				end
			end
		end
	end)
end

-------------------------------------------------------------------------------- 19 / 21: live duels feed
local live = {}            -- array of { k, m, r, a = {names}, b = {names}, t, s } (s = "pad" | "online" | "remote")
local function addLive(e)
	for _, x in live do if x.k == e.k then return false end end
	table.insert(live, 1, e)
	while #live > 12 do table.remove(live) end
	return true
end

local function startDuels()
	local cfg = LF.DuelsTV
	local topic = cfg.Topic
	local MS
	if cfg.UseMessaging then
		local okMS, svc = pcall(game.GetService, game, "MessagingService"); MS = okMS and svc or nil
		if MS then   -- SubscribeAsync can yield for a long time (or for ever in Studio): never let it hold up the feed loop
			task.spawn(function()
			local okSub = pcall(function()
				MS:SubscribeAsync(topic, function(msg)
					local d = type(msg) == "table" and msg.Data
					if type(d) ~= "table" or d.j == game.JobId then return end
					if d.e then   -- a match place may send { k = key, e = true } when it ends, or { k, sc = "3 - 1" } for a score
						for i, x in live do if x.k == d.k then table.remove(live, i) break end end
					elseif d.sc then
						for _, x in live do if x.k == d.k then x.sc = tostring(d.sc) end end
					elseif type(d.m) == "string" then
						addLive({ k = tostring(d.k), m = d.m, r = d.r == true, a = d.a or {}, b = d.b or {}, t = tonumber(d.t) or os.time(), s = "remote" })
					end
				end)
			end)
			if not okSub then MS = nil end
			end)
		end
	end
	local function publish(e)
		if not MS then return end
		task.spawn(pcall, MS.PublishAsync, MS, topic, { j = game.JobId, k = e.k, m = e.m, r = e.r, a = e.a, b = e.b, t = e.t })
	end
	local function nameOf(uid)
		local p = Players:GetPlayerByUserId(uid)
		return p and p.DisplayName or ("Operator " .. tostring(uid))
	end

	-- online matches found from this server: players switch MM_Status to Found / Teleporting
	local pendingOnline = {}   -- [queueId] = { t, names }
	local function watch(p)
		p:GetAttributeChangedSignal("MM_Status"):Connect(function()
			local st = p:GetAttribute("MM_Status")
			if st ~= "Found" and st ~= "Teleporting" then return end
			local q = tostring(p:GetAttribute("MM_Queue") or "?")
			local g = pendingOnline[q]
			if not g or os.clock() - g.c > 4 then
				g = { c = os.clock(), names = {}, key = game.JobId .. ":online:" .. q .. ":" .. math.floor(os.time()) }; pendingOnline[q] = g
			end
			if table.find(g.names, p.DisplayName) then return end
			table.insert(g.names, p.DisplayName)
			for i, x in live do if x.k == g.key then table.remove(live, i) break end end
			local mode = string.gsub(q, "^R", "")
			local e = { k = g.key, m = mode, r = string.sub(q, 1, 1) == "R", a = table.clone(g.names), b = { "ONLINE OPPONENTS" }, t = os.time(), s = "online" }
			addLive(e); publish(e)
		end)
	end
	for _, p in Players:GetPlayers() do watch(p) end
	Players.PlayerAdded:Connect(watch)

	local prevState = {}
	local lastJson
	while true do
		task.wait(0.5)
		local snap
		if okR and Remotes.Handlers.GetQueue then
			local okQ, res = pcall(Remotes.Handlers.GetQueue, nil)
			snap = okQ and type(res) == "table" and res.snapshot or nil
		end
		local pads, modes = {}, {}
		for _, b in (snap and snap.bays or {}) do
			local key = b.mode .. "#" .. b.id
			if b.state == "Deploying" and prevState[key] ~= "Deploying" then
				local a, bb = {}, {}
				for _, o in b.occupants or {} do table.insert(o.t == "A" and a or bb, nameOf(o.u)) end
				local e = { k = game.JobId .. ":" .. key .. ":" .. os.time(), m = b.mode, r = b.ranked == true, a = a, b = bb, t = os.time(), s = "pad" }
				addLive(e); publish(e)
			end
			prevState[key] = b.state
			table.insert(pads, { m = b.mode, id = b.id, st = b.state, n = b.count, tot = b.total, cd = b.countdown, r = b.ranked == true })
			modes[b.mode] = modes[b.mode] or { pads = 0, online = 0 }
			modes[b.mode].pads += b.count
		end
		local okC, counts = pcall(HttpService.JSONDecode, HttpService, ReplicatedStorage:GetAttribute("MM_Counts") or "{}")
		if okC and type(counts) == "table" then
			for q, n in counts do
				local mode = string.gsub(tostring(q), "^R", "")
				modes[mode] = modes[mode] or { pads = 0, online = 0 }
				modes[mode].online += tonumber(n) or 0
			end
		end
		local keep = {}
		for _, x in live do if os.time() - x.t < cfg.MatchMinutes * 60 then table.insert(keep, x) end end
		live = keep
		local json = HttpService:JSONEncode({ live = live, pads = pads, modes = modes, studio = RunService:IsStudio() })
		if json ~= lastJson then lastJson = json; ReplicatedStorage:SetAttribute("LF_LiveDuels", json) end
	end
end

-------------------------------------------------------------------------------- [FEAT] 14: top-player reward stand
-- LobbyMap.Features.RewardStand (fix/place_features_kit.lua): labels named TopName / TopWins (SurfaceGui on the kit name
-- plate) and BoardName (BillboardGui over the halo) show #1 of ReplicatedStorage.LobbyTopWins ({u, n, w} JSON list that
-- ServerScriptService.LobbyLeaderboard publishes every minute; the same data the leaderboard screen draws).
local function startRewardStand(map) -- [FEAT]
	local stand = map.Features:FindFirstChild("RewardStand") -- [FEAT]
	local value = ReplicatedStorage:FindFirstChild("LobbyTopWins") or ReplicatedStorage:WaitForChild("LobbyTopWins", 30) -- [FEAT]
	if not (stand and value) then return end -- [FEAT]
	local cfg = LF.RewardStand -- [FEAT]
	local function render() -- [FEAT]
		local okJ, list = pcall(HttpService.JSONDecode, HttpService, value.Value) -- [FEAT]
		local top = okJ and type(list) == "table" and list[1] or nil -- [FEAT]
		local name = top and string.upper(tostring(top.n or "OPERATOR")) or cfg.Empty -- [FEAT]
		local wins = top and (tostring(tonumber(top.w) or 0) .. " WINS") or "" -- [FEAT]
		for _, d in stand:GetDescendants() do -- [FEAT]
			if d:IsA("TextLabel") then -- [FEAT]
				if d.Name == "TopName" or d.Name == "BoardName" then d.Text = name -- [FEAT]
				elseif d.Name == "TopWins" or d.Name == "BoardWins" then d.Text = wins end -- [FEAT]
			end -- [FEAT]
		end -- [FEAT]
		stand:SetAttribute("TopUserId", top and tonumber(top.u) or 0) -- [FEAT]
	end -- [FEAT]
	value.Changed:Connect(render) -- [FEAT]
	render() -- [FEAT]
end -- [FEAT]

-------------------------------------------------------------------------------- 20: likes + rewarded ad
local function startLikes()
	for attr, v in { LF_LikesCurrent = LF.LikesBoard.Current, LF_LikesGoal = LF.LikesBoard.Goal, LF_LikesReward = LF.LikesBoard.Reward } do
		if ReplicatedStorage:GetAttribute(attr) == nil then ReplicatedStorage:SetAttribute(attr, v) end
	end
end

local function startAds(map)
	local cfg = LF.AdBoard
	local ready = (cfg.DevProductId or 0) > 0
	ReplicatedStorage:SetAttribute("LF_AdReady", ready)
	local board = map.Features:FindFirstChild("AdBoard")
	for _, d in (board and board:GetDescendants() or {}) do if d:IsA("ProximityPrompt") then d.Enabled = ready end end
	if not ready then return end   -- documented stub: no Developer Product for the reward yet
	local lobby = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Lobby")
	local ev = lobby:FindFirstChild("LF_WatchAd")
	if not ev then ev = Instance.new("RemoteEvent"); ev.Name = "LF_WatchAd"; ev.Parent = lobby end
	local AdService = game:GetService("AdService")
	local last = {}
	Players.PlayerRemoving:Connect(function(p) last[p] = nil end)
	ev.OnServerEvent:Connect(function(p)
		if last[p] and os.clock() - last[p] < cfg.Cooldown then return end
		last[p] = os.clock()
		local okReward, reward = pcall(AdService.CreateAdRewardFromDevProductId, AdService, cfg.DevProductId)
		if not okReward then
			if okR then Remotes.Notify(p, "Ads aren't available right now.", "bad") end
			return
		end
		-- the reward is granted through the place's ProcessReceipt for that Developer Product
		local okShow, result = pcall(AdService.ShowRewardedVideoAdAsync, AdService, p, reward)
		if okR and not okShow then Remotes.Notify(p, "No ad to show right now. Try again later.", "bad")
		elseif okR then Remotes.Notify(p, "Ad: " .. tostring(result), "info") end
	end)
end

function manager.Start()
	if not ok then warn("[LobbyFeatures] config missing: every feature off"); return end
	local map = workspace:WaitForChild("LobbyMap", 30)
	if not map then return end
	map:WaitForChild("Features", 10)
	for _, name in LF.Features do
		local g = geometry(map, name)
		if g and not LF.On(name) then
			if name == "DropPits" then   -- give the Duels floor meshes their own collision back before the proxies leave
				for _, d in map:GetDescendants() do
					if d:IsA("BasePart") and d:GetAttribute("LF_OrigCollide") ~= nil then d.CanCollide = d:GetAttribute("LF_OrigCollide") end
					-- [FEAT] fix/place_features_kit.lua hides the Duels floor meshes (the kit slab floor with the pit holes lives
					-- in DropPits): show them again when the pits are off
					if d:IsA("BasePart") and d:GetAttribute("FK_FloorHidden") then d.Transparency = d:GetAttribute("FK_OrigT") or 0 end -- [FEAT]
				end
			end
			g.Parent = offFolder()
		end
	end
	if not map:FindFirstChild("Features") then return end
	if LF.On("DropPits") then startPits(map) end
	if LF.On("LikesBoard") then startLikes() end
	if LF.On("AdBoard") then startAds(map) end
	if LF.On("DuelsTV") or LF.On("DuelsSign") then task.spawn(startDuels) end
	if LF.On("RewardStand") then task.spawn(startRewardStand, map) end -- [FEAT]
end

return manager
