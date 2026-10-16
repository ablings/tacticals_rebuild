-- ServerScripts/[Server] Init/GameManager/Managers/LobbyDuelManager (ModuleScript)
-- Lobby pad duels (notes/lobby_duels_design.md, phase 1 2026-10-16): a full pad bay plays its match HERE, in the lobby
-- server, on an arena slot far outside the lobby, instead of teleporting to the match place.
--   QueueManager [DUEL] hands a full bay to LobbyDuelManager.StartMatch(padModel, mode, teams) after its countdown
--   (not .Start: ModuleLoader calls .Start() once at boot).
--   Flow: Loading -> MapVote (maps of this mode + Random) -> Loadout -> rounds (MatchCore) -> MatchEnd -> back to the pads.
--   Map data comes only from MapRegistry (ReplicatedStorage.DuelMaps.<Id>.MapInfo): footprint, spawns, modes, layers.
--   Server: the map's Solid layer (invisible collision) in Workspace.DuelArenas.<matchId> at the slot origin.
--   Client: ArenaLoader clones the Visual layer for the match's players only.
--   State: ReplicatedStorage.LobbyDuels.<matchId> (Configuration) with the contract attributes; remote ReplicatedStorage.MatchFlow.
-- Lead defaults (Edward may change): casual only (never ranked); rewards = a casual match's, at most one per opponent pair per
-- 10 minutes; leaving = loss for the leaver (no rewards) and a win for the other side; vote = eligible maps + Random; 6 arenas.
-- Studio test: ReplicatedStorage attribute DuelTestSolo = true lets one player start a pad alone; the empty team gets a
-- server test bot (an R15 rig, tag Bot, DuelMatch on the model) - LobbyDuelManager._TestSolo. Never in a live server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage.Modules.Shared
local MatchConfig = require(Shared.Config.MatchConfig)
local LobbyConfig = require(Shared.Config.LobbyConfig)
local MapRegistry = require(Shared.MapRegistry)
local MatchCore = require(ServerScriptService.Shared.MatchCore)
local PlayerStore = require(ServerScriptService.Data.PlayerStore)

local IS_STUDIO = RunService:IsStudio()
local C = MatchConfig
local manager = {}

local stateFolder, arenaFolder, flow, announceEv, resultsEv
local slots = {}      -- [n] = matchId or nil
local matches = {}    -- [matchId] = match record
local byPlayer = {}   -- [Player] = { match, member }
local lastReward = {} -- [pair key] = os.clock() (anti-farming)
local counter = 0

-- // Helpers ------------------------------------------------------------------------------------------------------------
local function json(v) return HttpService:JSONEncode(v) end
local function rootOf(m)
	local c = MatchCore.character(m)
	return c and c:FindFirstChild("HumanoidRootPart")
end
local function slotOrigin(n: number): Vector3
	return Vector3.new((C.ArenaBaseX or 4000) + MapRegistry.SlotSpacing() * (n - 1), C.ArenaY or 100, 0)
end
local function holdFrame(match, i: number): CFrame
	return CFrame.new(match.origin + Vector3.new((i - 1) * 4, -60 + 3, 0))
end
local function playersOf(match, withSpectators: boolean?)
	local out = {}
	for _, list in match.teams do for _, m in list do if m.player and not m.left and m.player.Parent then table.insert(out, m.player) end end end
	if withSpectators then for p in match.spectators do if p.Parent then table.insert(out, p) end end end
	return out
end
local function fireFlow(match, kind: string, data)
	for _, p in playersOf(match, true) do flow:FireClient(p, match.id, kind, data) end
end
local function announce(match, title: string, subtitle: string?)
	for _, p in playersOf(match, true) do announceEv:FireClient(p, title, subtitle or "") end
end
local function allMembers(match)
	local out = {}
	for _, list in match.teams do for _, m in list do table.insert(out, m) end end
	return out
end
local function stripTools(player: Player)
	for _, cont in { player.Character, player:FindFirstChildOfClass("Backpack") } do
		for _, it in (cont and cont:GetChildren() or {}) do if it:IsA("Tool") then it:Destroy() end end
	end
end

-- // Test bot (Studio only) ---------------------------------------------------------------------------------------------
local function makeBot(match, m)
	if m.bot then m.bot:Destroy() end
	local ok, rig = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	end)
	if not ok or not rig then
		warn("[LobbyDuelManager] test bot rig failed: " .. tostring(rig))
		return nil
	end
	rig.Name = "DuelBot_" .. match.id
	rig:SetAttribute("DuelMatch", match.id)
	rig:SetAttribute("Team", m.team)
	rig:SetAttribute("Loadout", "Pistol")
	CollectionService:AddTag(rig, "Bot")
	local hum = rig:FindFirstChildOfClass("Humanoid")
	hum.MaxHealth = C.PlayerHealth or 150; hum.Health = hum.MaxHealth
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	rig.Parent = match.arena
	m.bot = rig
	return rig
end

-- // Arena ---------------------------------------------------------------------------------------------------------------
local function spawnFrame(match, side: string, slot: number): CFrame
	local info = match.map
	local spawns = match.solid and match.solid:FindFirstChild("Spawns")
	local own = spawns and spawns:FindFirstChild(side .. slot)
	local base = spawns and spawns:FindFirstChild(side .. "1")
	if own then return own.CFrame * CFrame.new(0, 3, 0) end
	local cf = base and base.CFrame or CFrame.new(match.origin + Vector3.new(0, 1, side == "A" and 20 or -20))
	-- teammates stand side by side beside the team's marker (RoundManager's rule), spacing from MapInfo
	local s = (slot - 1) % 2 == 0 and 1 or -1
	local step = math.floor(slot / 2) * (info and info.SpawnSpacing or 4)
	return cf * CFrame.new(s * step, 3, 0)
end

local function loadSolid(match)
	local src = ServerStorage:FindFirstChild("DuelMaps") and ServerStorage.DuelMaps:FindFirstChild(match.map.Id)
	local solid = src and src:FindFirstChild("Solid")
	if not solid then warn("[LobbyDuelManager] no Solid layer for " .. match.map.Id); return end
	local clone = solid:Clone()
	clone.Name = match.map.WorkspaceName or match.map.Id
	clone:PivotTo(CFrame.new(match.origin))
	clone.Parent = match.arena
	match.solid = clone
end

-- // Players in and out of a match ---------------------------------------------------------------------------------------
local function clearPlayer(player: Player)
	for _, k in { "DuelMatch", "InDuel", "InMatch", "LoadoutReady", "Alive", "RoundWins", "MatchKills", "MatchDeaths", "OwnedItems",
		"Deploying" } do
		player:SetAttribute(k, nil)
	end
	player:SetAttribute("Team", nil)
	byPlayer[player] = nil
	pcall(PlayerStore.ApplyLoadoutAttributes, player) -- back to the equipped lobby kit
end

-- back to the lobby: off the duel, a fresh character at the pad's step-off spot (lobby health, no tools)
local function returnToLobby(match, m)
	local p = m.player
	if not p or not p.Parent or m.returned then return end
	m.returned = true
	clearPlayer(p)
	task.spawn(function()
		p:LoadCharacter()
		local c = p.Character
		local root = c and c:WaitForChild("HumanoidRootPart", 5)
		if root and m.stepOff then c:PivotTo(m.stepOff) end
	end)
end

local function setupMember(match, m)
	local p = m.player
	byPlayer[p] = { match = match, member = m }
	p:SetAttribute("QueueMode", nil)
	p:SetAttribute("DuelMatch", match.id)
	p:SetAttribute("InDuel", true)
	p:SetAttribute("Team", m.team)
	p:SetAttribute("Alive", true)
	p:SetAttribute("LoadoutReady", false)
	local data = PlayerStore.Get(p)
	p:SetAttribute("Level", (LobbyConfig.AccountLevel(data and data.XP or 0)))
	local owned = {}
	for id, it in LobbyConfig.Items do
		if it.Default == true or (data and data.Owned and data.Owned[id] == true) then table.insert(owned, id) end
	end
	table.sort(owned)
	p:SetAttribute("OwnedItems", json(owned))
	MatchCore.applyKit(m, PlayerStore.Loadout(p))
	-- park the character in the slot's hold (anchored) until the first round spawn
	local root = rootOf(m)
	if root then
		local c = p.Character
		root.Anchored = true
		c:PivotTo(holdFrame(match, m.index))
	end
end

-- // The match ------------------------------------------------------------------------------------------------------------
local function isPresent(m)
	if m.left then return false end
	if m.bot ~= nil or m.isBot then return true end
	return m.player ~= nil and m.player.Parent ~= nil and m.player:GetAttribute("DuelMatch") ~= nil
end

local function spawnMember(match, m, side: string, slot: number)
	local cf = spawnFrame(match, side, slot)
	if m.isBot then
		local rig = makeBot(match, m)
		if rig then rig:PivotTo(cf) end
		return rig
	end
	local p = m.player
	m.spawning = true
	p:LoadCharacter()
	local character = p.Character
	if not character then m.spawning = false; return nil end
	local waited = 0
	while character:GetAttribute("Ready") ~= true and waited < 10 and character.Parent do waited += task.wait(0.1) end
	local hum = character:FindFirstChildOfClass("Humanoid")
	if hum then hum.MaxHealth = C.PlayerHealth or 150; hum.Health = hum.MaxHealth end
	if character.Parent then character:PivotTo(cf) end
	m.spawning = false
	return character
end

local function setFrozen(m, frozen: boolean)
	local root = rootOf(m)
	if root then root.Anchored = frozen end
end

local function memberList(match, side)
	local ids = {}
	for _, m in match.teams[side] do table.insert(ids, m.userId) end
	return json(ids)
end

local function award(match, m, side: string, winner: string?, forfeit: boolean)
	local p = m.player
	local data = PlayerStore.Get(p)
	local summary = MatchCore.summary(match.ctx, m, side, winner, forfeit, data and data.Passes)
	summary.MatchId = match.id
	-- one reward per opponent pair per DuelRewardCooldown (anti-farming); a match with a test bot never pays
	local others = {}
	for s, list in match.teams do if s ~= side then for _, o in list do table.insert(others, o.userId) end end end
	table.sort(others)
	local key = p.UserId .. ">" .. table.concat(others, ",")
	local cooling = lastReward[key] and os.clock() - lastReward[key] < (C.DuelRewardCooldown or 600)
	if match.hasBot or cooling or not data then
		summary.XP, summary.Scissors, summary.GunXP = 0, 0, 0
		summary.RewardCooldown = cooling or nil
		summary.TestMatch = match.hasBot or nil
	else
		lastReward[key] = os.clock()
		PlayerStore.Increment(p, { "XP" }, summary.XP)
		PlayerStore.Increment(p, { "Credits" }, summary.Scissors)
		if type(data.ItemXP) == "table" then PlayerStore.Increment(p, { "ItemXP", summary.Weapon }, summary.GunXP) end
		if type(data.Stats) == "table" then
			PlayerStore.AddStat(p, "MatchesPlayed", 1)
			if summary.Kills > 0 then PlayerStore.AddStat(p, "Kills", summary.Kills) end
			if summary.Headshots > 0 then PlayerStore.AddStat(p, "Headshots", summary.Headshots) end
			if summary.MeleeKills > 0 then PlayerStore.AddStat(p, "MeleeKills", summary.MeleeKills) end
			if summary.Won then PlayerStore.AddStat(p, "Wins", 1) end
		end
		summary.Saved = true
	end
	resultsEv:FireClient(p, summary)
end

local function endMatch(match)
	if match.ended then return end
	match.ended = true
	fireFlow(match, "Return", {})
	task.wait(C.ReturnFade or 1)
	for _, m in allMembers(match) do
		if m.player then returnToLobby(match, m) end
	end
	for p in match.spectators do if p.Parent then p:SetAttribute("DuelSpectate", nil) end end
	task.wait(0.5)
	if match.arena then match.arena:Destroy() end
	if match.state then match.state:Destroy() end
	slots[match.slot] = nil
	matches[match.id] = nil
	print(`[LobbyDuelManager] {match.id} done, slot {match.slot} free`)
end

local function waitPhase(match, seconds: number, done)
	local t0 = os.clock()
	while os.clock() - t0 < seconds do
		if done and done() then return true end
		if MatchCore.forfeitSide(match.ctx) then return false end
		task.wait(0.1)
	end
	return false
end

local function run(match)
	local ctx = match.ctx
	local s = match.state
	-- 1. Loading
	MatchCore.setState(ctx, "Loading", C.LoadingTime or 3)
	waitPhase(match, C.LoadingTime or 3)

	-- 2. Map vote (maps of this mode only; the UI adds Random)
	local maps = MapRegistry.ForMode(match.mode)
	local list = {}
	for _, m in maps do table.insert(list, { id = m.Id, name = m.DisplayName or m.Id, image = m.Image or "" }) end
	s:SetAttribute("MapList", json(list))
	s:SetAttribute("MapVotes", "{}")
	if C.DuelMapVote ~= false and not MatchCore.forfeitSide(ctx) then
		MatchCore.setState(ctx, "MapVote", C.MapVoteTime or 10)
		local everyone = #playersOf(match)
		waitPhase(match, C.MapVoteTime or 10, function()
			local n = 0
			for _ in match.votes do n += 1 end
			return n >= everyone and everyone > 0 and os.clock() - match.lastVote > 1.5
		end)
	end
	local chosen = MatchCore.resolveVote(match.votes, maps)
	match.map = MapRegistry.Get(chosen)
	s:SetAttribute("MapChosen", chosen)
	task.wait(1.5) -- the winning tile flashes

	-- 3. Loadout; the arena loads behind it
	loadSolid(match)
	s:SetAttribute("ArenaMap", chosen)
	s:SetAttribute("ArenaSize", match.map.Size)
	s:SetAttribute("ArenaOrigin", match.origin)
	fireFlow(match, "Arena", { map = chosen, origin = match.origin })
	MatchCore.setState(ctx, "Loadout", C.LoadoutTime or 15)
	local function allSet(needReady)
		for _, m in allMembers(match) do
			if m.player and isPresent(m) and (not m.loaded or (needReady and not m.ready)) then return false end
		end
		return true
	end
	waitPhase(match, C.LoadoutTime or 15, function() return allSet(true) end)
	if not allSet(false) then
		waitPhase(match, C.LoadedGrace or 5, function() return allSet(false) end)
		for _, m in allMembers(match) do
			if m.player and isPresent(m) and not m.loaded then
				warn(`[LobbyDuelManager] {m.name} never loaded the arena: counts as left`)
				m.left = true
				returnToLobby(match, m)
			end
		end
	end

	-- 4-6. Rounds (MatchCore) and results
	local winner, forfeit = MatchCore.playMatch(ctx)
	for side, list in match.teams do
		for _, m in list do
			if m.player and isPresent(m) then task.spawn(award, match, m, side, winner, forfeit) end
		end
	end
	local t0 = os.clock()
	while os.clock() - t0 < (C.ResultsTime or 12) and #playersOf(match) > 0 do task.wait(0.25) end
	endMatch(match)
end

-- // Public ----------------------------------------------------------------------------------------------------------------
function manager.Enabled(): boolean
	return C.PadDuelsInLobby == true and stateFolder ~= nil
end

-- why a pad of this mode can't start an in-lobby match right now (nil = it can)
function manager.Blocked(mode: string): string?
	if not MapRegistry.HasMode(mode) then return "No maps yet for " .. mode end
	return nil
end

-- teams = { A = { {player = Player, stepOff = CFrame} }, B = {...} }. Returns ok, reason.
function manager.StartMatch(padModel: Instance?, mode: string, teams)
	local why = manager.Blocked(mode)
	if why then return false, why end
	local slot
	for n = 1, C.MaxArenas or 6 do if not slots[n] then slot = n break end end
	if not slot then return false, "ARENAS FULL - WAITING" end
	for _, list in teams do
		for _, e in list do
			if e.player:GetAttribute("DuelMatch") then return false, e.player.Name .. " is already in a duel" end
		end
	end
	counter += 1
	local id = "D" .. counter
	slots[slot] = id
	local match = { id = id, slot = slot, mode = mode, origin = slotOrigin(slot), teams = { A = {}, B = {} }, votes = {}, lastVote = 0,
		spectators = {}, pad = padModel }
	matches[id] = match

	-- test bot for an empty team (Studio + DuelTestSolo only)
	for _, side in { "A", "B" } do
		if #teams[side] == 0 and IS_STUDIO and ReplicatedStorage:GetAttribute("DuelTestSolo") == true then
			teams[side] = { { bot = true } }
			match.hasBot = true
		end
	end

	local state = Instance.new("Configuration")
	state.Name = id
	for k, v in { MatchId = id, MatchMode = mode, MatchRanked = C.DuelRanked == true, LiveMatch = true, InfiniteAmmo = false,
		CombatEnabled = false, ScoreA = 0, ScoreB = 0, RoundNumber = 0, RoundsToWin = C.RoundsToWin, Spectators = 0, Slot = slot } do
		state:SetAttribute(k, v)
	end
	match.state = state
	local arena = Instance.new("Folder")
	arena.Name = id
	arena.Parent = arenaFolder
	match.arena = arena
	-- the slot's hold: an invisible floor 60 under the arena where waiting / dead players stand (anchored)
	local hold = Instance.new("Part")
	hold.Name = "Hold"; hold.Anchored = true; hold.Transparency = 1; hold.CastShadow = false; hold.CanQuery = false; hold.CanTouch = false
	hold.Size = Vector3.new(40, 1, 12); hold.CFrame = CFrame.new(match.origin + Vector3.new(6, -60, 0))
	hold.Parent = arena

	local idx = 0
	for side, list in teams do
		for i, e in list do
			idx += 1
			local m
			if e.bot then
				m = { isBot = true, userId = -idx, name = "TestBot", team = side, index = idx }
			else
				m = { player = e.player, userId = e.player.UserId, name = e.player.Name, team = side, stepOff = e.stepOff, index = idx }
			end
			table.insert(match.teams[side], m)
		end
	end
	state:SetAttribute("TeamA", memberList(match, "A"))
	state:SetAttribute("TeamB", memberList(match, "B"))
	state.Parent = stateFolder
	for _, list in match.teams do for _, m in list do if m.player then setupMember(match, m) end end end

	match.ctx = {
		state = state, teams = match.teams, mode = mode, ranked = C.DuelRanked == true, config = C, tally = MatchCore.newTally(),
		announce = function(title, sub) announce(match, title, sub) end,
		spawnMember = function(m, side, i) return spawnMember(match, m, side, i) end,
		setFrozen = setFrozen,
		isPresent = isPresent,
		onRoundStart = function()
			-- this arena only: smoke / grenades / shootables per arena are phase 2 (ArenaShootables / ArenaDoors)
		end,
		onKill = function(info) fireFlow(match, "Kill", info) end,
	}
	task.spawn(function()
		local ok, err = pcall(run, match)
		if not ok then
			warn("[LobbyDuelManager] match " .. id .. " failed: " .. tostring(err))
			endMatch(match)
		end
	end)
	print(`[LobbyDuelManager] {id} started: {mode} slot {slot} at {match.origin}`)
	return true
end

-- a player leaves their match (HUD LEAVE / disconnect): forfeit for their side if nobody is left on it
local function leave(player: Player)
	local rec = byPlayer[player]
	if not rec then return end
	rec.member.left = true
	returnToLobby(rec.match, rec.member)
end
manager.Leave = leave

-- // MatchFlow remote -------------------------------------------------------------------------------------------------------
local function onFlow(player: Player, matchId: any, kind: any, a: any, b: any)
	local rec = byPlayer[player]
	if not rec or type(matchId) ~= "string" or rec.match.id ~= matchId then return end
	local match, m = rec.match, rec.member
	local phase = match.state and match.state:GetAttribute("MatchState")
	if kind == "Vote" and phase == "MapVote" then
		local okId = a == "Random"
		for _, mp in MapRegistry.ForMode(match.mode) do if mp.Id == a then okId = true end end
		if not okId then return end
		match.votes[player.UserId] = a
		match.lastVote = os.clock()
		local out = {}
		for uid, id in match.votes do out[id] = out[id] or {}; table.insert(out[id], uid) end
		match.state:SetAttribute("MapVotes", json(out))
	elseif kind == "Pick" and phase == "Loadout" then
		if a ~= "Weapon" and a ~= "Melee" and a ~= "Gadget" then return end
		if not MatchCore.validPick(LobbyConfig.Items, function(id) return PlayerStore.Owns(player, id) end, a, b) then return end
		local kit = { Weapon = player:GetAttribute("KitWeapon"), Melee = player:GetAttribute("KitMelee"), Gadget = player:GetAttribute("KitGadget") }
		kit[a] = b
		MatchCore.applyKit(m, kit)
	elseif kind == "Ready" and phase == "Loadout" then
		m.ready = true
		player:SetAttribute("LoadoutReady", true)
	elseif kind == "Loaded" then
		m.loaded = true
	elseif kind == "Leave" then
		leave(player)
	end
end

-- // Characters: dead / respawned duelists go to the hold, never into the lobby ------------------------------------------------
local function onCharacterAdded(player: Player, character: Model)
	local rec = byPlayer[player]
	if not rec or rec.member.spawning or rec.member.returned then return end
	local match = rec.match
	local root = character:WaitForChild("HumanoidRootPart", 5)
	if not root or byPlayer[player] ~= rec then return end
	player:SetAttribute("Alive", false)
	root.Anchored = true
	character:PivotTo(holdFrame(match, rec.member.index))
	task.delay(0.6, function() if byPlayer[player] == rec and not rec.member.spawning then stripTools(player) end end)
end

-- fell out of the arena: counts as a death
local function fallCheck()
	for _, match in matches do
		if match.state and match.state:GetAttribute("MatchState") == "Live" then
			for _, m in allMembers(match) do
				local root = rootOf(m)
				local hum = MatchCore.humanoid(m)
				if root and hum and hum.Health > 0 and not root.Anchored and root.Position.Y < match.origin.Y - (match.map and match.map.KillDepth or 30) then
					hum.Health = 0
				end
			end
		end
	end
end

function manager.Start()
	stateFolder = ReplicatedStorage:FindFirstChild("LobbyDuels") or Instance.new("Folder")
	stateFolder.Name = "LobbyDuels"; stateFolder.Parent = ReplicatedStorage
	arenaFolder = workspace:FindFirstChild("DuelArenas") or Instance.new("Folder")
	arenaFolder.Name = "DuelArenas"; arenaFolder.Parent = workspace
	flow = ReplicatedStorage:FindFirstChild("MatchFlow") or Instance.new("RemoteEvent")
	flow.Name = "MatchFlow"; flow.Parent = ReplicatedStorage
	local events = ReplicatedStorage:WaitForChild("Events")
	local mf = events:FindFirstChild("Match") or Instance.new("Folder")
	mf.Name = "Match"; mf.Parent = events
	announceEv = mf:FindFirstChild("MatchAnnounce") or Instance.new("RemoteEvent")
	announceEv.Name = "MatchAnnounce"; announceEv.Parent = mf
	resultsEv = mf:FindFirstChild("MatchResults") or Instance.new("RemoteEvent")
	resultsEv.Name = "MatchResults"; resultsEv.Parent = mf

	flow.OnServerEvent:Connect(onFlow)
	local function hook(p: Player)
		p.CharacterAdded:Connect(function(c) onCharacterAdded(p, c) end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in Players:GetPlayers() do hook(p) end
	Players.PlayerRemoving:Connect(function(p)
		local rec = byPlayer[p]
		if rec then rec.member.left = true; rec.member.returned = true; byPlayer[p] = nil end
	end)

	-- pads whose mode has no map can't start an in-lobby match (NoMap; PadBoards shows "No maps yet for <mode>")
	task.spawn(function()
		local map = workspace:WaitForChild("LobbyMap", 30)
		local duels = map and map:FindFirstChild("Duels")
		for _, pad in (duels and duels:GetChildren() or {}) do
			local mode = pad:IsA("Model") and pad:GetAttribute("QueueName")
			if mode then
				local blocked = C.PadDuelsInLobby == true and manager.Blocked(mode) or nil
				pad:SetAttribute("NoMap", blocked ~= nil or nil)
				pad:SetAttribute("NoMapText", blocked)
			end
		end
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.2 then return end
		acc = 0
		fallCheck()
	end)
	print(`[LobbyDuelManager] ready: {#MapRegistry.List()} map(s), {C.MaxArenas or 6} arena slots, spacing {MapRegistry.SlotSpacing()}`)
end

-- Studio only: start a duel for one player against a test bot without the pads (the pad path also works with DuelTestSolo)
function manager._TestSolo(player: Player, mode: string?)
	if not IS_STUDIO then return false, "Studio only" end
	ReplicatedStorage:SetAttribute("DuelTestSolo", true)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return manager.StartMatch(nil, mode or "1v1", { A = { { player = player, stepOff = root and root.CFrame or CFrame.new(0, 4, 0) } }, B = {} })
end
manager._matches = matches

return manager
