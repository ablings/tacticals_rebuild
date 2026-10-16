-- ServerScriptService/ServerScripts/[Server] Init/GameManager/Managers/RoundManager (ModuleScript)
-- [MATCH] 2026-10-16 (notes/match_place_flow.md): the round rules now come from the shared MatchCore module (the same file the
-- lobby's pad duels run), and a real match plays the RIVALS flow:
--   Waiting (arrival; MatchPhase "Loading") -> Loading -> MapVote (maps of the match's mode + Random) -> Loadout (pick from
--   what you own; ends early when everyone is Ready) -> rounds (MatchCore.playMatch) -> MatchEnd (results) -> back to the lobby.
-- Original source (pass 38): ServerStorage._RebuildRemoved.MATCH_RoundManager_Orig. UNDO: fix/match_place_install.lua UNDO.
-- Server kinds (unchanged):
--   * MATCH server: the first player's TeleportData { Mode, Ranked, Teams = {A = {ids}, B = {ids}}, Loadouts } and Tutorial ~= true.
--   * TUTORIAL server: TeleportData.Tutorial (or Studio attribute StudioTutorialServer): no matches, we spawn the player.
--   * TEST server (Studio / public server without data): free practice, the first two players duel, endless rematches.
--   Studio switches: ReplicatedStorage attribute StudioSoloMatch = "1v1" / "R1v1" (solo forfeit match, as before), and
--   [MATCH] StudioTeleportData = JSON TeleportData (e.g. {"Mode":"1v1","Teams":{"A":["me"],"B":["bot"]}}): "me" = the first
--   player, "bot" or an id <= 0 = a server test bot (R15 rig, never pays); optional "StudioTimes": {"MapVoteTime": 40, ...}
--   overrides MatchConfig times. Studio only; never read in a live server.
-- Published state (old names kept; new ones from notes/lobby_duels_design.md section 6):
--   ReplicatedStorage: MatchState, StateEndsAt, PhaseEndsAt, MatchPhase, RoundNumber, RoundsToWin, CombatEnabled, LiveMatch,
--                      MatchMode, MatchRanked, ScoreA, ScoreB, TestMode, InfiniteAmmo, TeamA, TeamB, MapList, MapVotes,
--                      MapChosen, ArenaMap
--   Player:            InMatch, RoundWins, Team, MatchKills, MatchDeaths, GadgetThrows, Alive, Level, OwnedItems,
--                      KitWeapon, KitMelee, KitGadget, Loadout (= KitWeapon), LoadoutReady
--   Events.Match.MatchAnnounce (title, subtitle), Events.Match.MatchResults (summary per player)
--   ReplicatedStorage.MatchFlow (RemoteEvent): client ("Vote", mapId) / ("Pick", slot, itemId) / ("Ready") / ("Leave");
--                      server FireClient(player, nil, "Kill", {killer, victim, weapon, headshot, kind})
-- Admin (AdminFramework Duel commands): manager.MatchInfo(), manager.EndMatch(reason).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage.Modules.Shared
local MatchConfig = require(Shared.Config.MatchConfig)
local MatchCore = require(ServerScriptService.Shared.MatchCore)
local MapRegistry = require(Shared.MapRegistry)
local okLC, LobbyConfig = pcall(require, Shared.Config.LobbyConfig)
if not okLC then
	warn("[RoundManager] no LobbyConfig port: " .. tostring(LobbyConfig))
	LobbyConfig = {}
end
local Announce = ReplicatedStorage.Events.Match.MatchAnnounce
local MatchFolder = ReplicatedStorage.Events.Match
local Results = MatchFolder:FindFirstChild("MatchResults") or Instance.new("RemoteEvent")
Results.Name = "MatchResults"; Results.Parent = MatchFolder
local Flow = ReplicatedStorage:FindFirstChild("MatchFlow") or Instance.new("RemoteEvent")
Flow.Name = "MatchFlow"; Flow.Parent = ReplicatedStorage

local IS_STUDIO = RunService:IsStudio()
local C = MatchConfig
local LOBBY_PLACE = C.LobbyPlaceId or 126491009194165
local ITEMS = type(LobbyConfig.Items) == "table" and LobbyConfig.Items or {}
local DEFAULTS = LobbyConfig.DefaultLoadout or { Weapon = "Pistol", Melee = "Fists", Gadget = "Smoke" }

local manager = {}
-- the one match of this server: { kind = "match" | "test", ctx, mode, ranked, teams, byUser, maps, hasBot, aborted }
local current = nil
-- Studio evidence for the tests: return-to-lobby attempts
manager._returns = {}
manager._phaseLog = {}

-- // State ----------------------------------------------------------------------------------------
local BASE = { state = ReplicatedStorage }
local function setState(state: string, duration: number?)
	MatchCore.setState(BASE, state, duration)
	-- free practice while waiting (old rule): combat is on in Waiting
	if state == "Waiting" then ReplicatedStorage:SetAttribute("CombatEnabled", true) end
end
local function announce(title: string, subtitle: string?) Announce:FireAllClients(title, subtitle or "") end
local function json(v) return HttpService:JSONEncode(v) end

local function humanoidOf(player: Player): Humanoid?
	local c = player.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end
local function isAlive(player: Player): boolean
	local h = humanoidOf(player)
	return h ~= nil and h.Health > 0
end

-- teammates stand side by side, SpawnSpacing (4) apart, centred on the team's marker (MatchSpawns.SpawnA / SpawnB)
local function spawnFrame(team: string, slot: number, info): CFrame
	local folder = workspace:FindFirstChild(C.SpawnFolderName or "MatchSpawns")
	local part = folder and folder:FindFirstChild(team == "A" and "SpawnA" or "SpawnB")
	local base = (part and part:IsA("BasePart")) and part.CFrame or CFrame.new(0, 10, team == "A" and 20 or -20)
	local side = (slot - 1) % 2 == 0 and 1 or -1
	local step = math.floor(slot / 2) * (info and info.SpawnSpacing or 4)
	return base * CFrame.new(side * step, 3, 0)
end

local function spawnPlayer(player: Player, cframe: CFrame?)
	player:LoadCharacter()
	local character = player.Character
	if not character then return nil end
	local waited = 0
	while character:GetAttribute("Ready") ~= true and waited < 10 and character.Parent do waited += task.wait(0.1) end
	if cframe and character.Parent then character:PivotTo(cframe) end
	return character
end

-- // Profile (shared ProfileService "gameStore" with the lobby) --------------------------------------
local function dataManager()
	local ok, DM = pcall(require, ServerScriptService:WaitForChild("Data"):WaitForChild("DataManager"))
	return ok and DM or nil
end
local function profileData(player: Player)
	local DM = dataManager()
	if not DM then return nil end
	for _ = 1, 40 do
		local d = DM:Get(player)
		if d or not player.Parent then return d end
		task.wait(0.25)
	end
	return nil
end
local function owns(player: Player, id: string): boolean
	local DM = dataManager()
	local d = DM and DM:Get(player)
	return d ~= nil and type(d.Owned) == "table" and d.Owned[id] == true
end

-- // Members (a Player, or a Studio test bot) -------------------------------------------------------
local function makeBot(m, cf: CFrame)
	if m.bot then m.bot:Destroy() end
	local ok, rig = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	end)
	if not ok or not rig then
		warn("[RoundManager] test bot rig failed: " .. tostring(rig))
		return nil
	end
	rig.Name = "MatchBot_" .. m.index
	rig:SetAttribute("Team", m.team)
	rig:SetAttribute("Loadout", "Pistol")
	CollectionService:AddTag(rig, "Bot")
	local hum = rig:FindFirstChildOfClass("Humanoid")
	hum.MaxHealth = C.PlayerHealth or 150; hum.Health = hum.MaxHealth
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	rig:PivotTo(cf)
	rig.Parent = workspace
	m.bot = rig
	return rig
end

local function isPresent(m)
	if m.left then return false end
	if m.isBot then return true end
	return m.player ~= nil and m.player.Parent ~= nil
end

local function setFrozen(m, frozen: boolean)
	local c = MatchCore.character(m)
	local root = c and c:FindFirstChild("HumanoidRootPart")
	if root then root.Anchored = frozen end
end

local function teamIds(list)
	local ids = {}
	for _, m in list do table.insert(ids, m.userId) end
	return json(ids)
end

-- the player's attributes for the vote / loadout screens and the kit they start the Loadout phase with
-- (profile Loadout, else the TeleportData Loadouts entry, each slot validated against what they own; defaults always)
local function setupMember(m, data, teleLoadout)
	local p = m.player
	p:SetAttribute("Team", m.team)
	p:SetAttribute("LoadoutReady", false)
	p:SetAttribute("Alive", true)
	if LobbyConfig.AccountLevel then p:SetAttribute("Level", (LobbyConfig.AccountLevel(data and data.XP or 0))) end
	p:SetAttribute("OwnedItems", json(MatchCore.ownedItems(ITEMS, data)))
	local wanted = (data and type(data.Loadout) == "table" and next(data.Loadout) ~= nil) and data.Loadout or teleLoadout
	MatchCore.applyKit(m, MatchCore.ownedKit(ITEMS, function(id) return owns(p, id) end, wanted, DEFAULTS))
end

-- // Rewards (written to the raw shared profile, as pass 38 did) ------------------------------------
local function award(match, m, side: string, winner: string?, forfeit: boolean, ratings)
	local player = m.player
	local data = profileData(player)
	local summary = MatchCore.summary(match.ctx, m, side, winner, forfeit, data and data.Passes)
	local mode, ranked = match.mode, match.ranked
	if ranked then
		local other = side == "A" and "B" or "A"
		summary.RatingChange = MatchCore.eloDelta(C.Rewards or {}, ratings[side], ratings[other], summary.Won, summary.Draw)
	end
	-- a match with a Studio test bot, or one an admin ended, never pays
	if match.hasBot or match.aborted then
		summary.XP, summary.Scissors, summary.GunXP, summary.RatingChange = 0, 0, 0, nil
		summary.TestMatch = match.hasBot or nil
		summary.Aborted = match.aborted or nil
		summary.Saved = false
		Results:FireClient(player, summary)
		return
	end
	if data then
		data.Stats = data.Stats or {}
		local function add(k, n) data.Stats[k] = (data.Stats[k] or 0) + n end
		add("MatchesPlayed", 1); add("Kills", summary.Kills); add("Headshots", summary.Headshots); add("MeleeKills", summary.MeleeKills)
		add("GadgetsThrown", player:GetAttribute("GadgetThrows") or 0)
		if summary.Won then add("Wins", 1) end
		data.XP = (tonumber(data.XP) or 0) + summary.XP
		data.Credits = (tonumber(data.Credits) or 0) + summary.Scissors
		data.ItemXP = data.ItemXP or {}
		data.ItemXP[summary.Weapon] = (data.ItemXP[summary.Weapon] or 0) + summary.GunXP
		if ranked then
			data.Ranked = data.Ranked or {}
			local r = data.Ranked[mode] or { Rating = C.StartingRating or 1000, Played = 0, Wins = 0 }
			r.Rating = math.max(0, (r.Rating or 1000) + summary.RatingChange)
			r.Played = (r.Played or 0) + 1
			if summary.Won then r.Wins = (r.Wins or 0) + 1 end
			data.Ranked[mode] = r
		end
	end
	summary.Saved = data ~= nil
	Results:FireClient(player, summary)
end

local function backToLobby(players)
	local list = {}
	for _, p in players do if p.Parent then table.insert(list, p) end end
	table.insert(manager._returns, { t = os.clock(), n = #list })
	if IS_STUDIO then
		warn("[RoundManager] back to the lobby: in a live game " .. #list .. " player(s) now teleport to " .. LOBBY_PLACE .. " (skipped in Studio)")
		return
	end
	if #list == 0 then return end
	for attempt = 1, 3 do
		local ok, err = pcall(TeleportService.TeleportAsync, TeleportService, LOBBY_PLACE, list)
		if ok then return end
		warn("[RoundManager] back to lobby failed (" .. attempt .. "): " .. tostring(err))
		task.wait(3)
	end
end

-- // A match on MatchCore ------------------------------------------------------------------------------
-- maps this place can play for a mode: registry maps of that mode that are placed in this place's Workspace
-- (the match place keeps its map at its native position; MapInfo.WorkspaceName). If none has the mode (the
-- Warehouse is 1v1 only, but PLAY 2v2 / 3v3 also lands here), every placed map, so a match never stalls.
local function eligibleMaps(mode: string)
	local placed, forMode = {}, {}
	for _, info in MapRegistry.List() do
		if workspace:FindFirstChild(info.WorkspaceName or info.Id) then
			table.insert(placed, info)
			if table.find(info.Modes or {}, mode) then table.insert(forMode, info) end
		end
	end
	if #forMode > 0 then return forMode, false end
	if #placed > 0 then warn(("[RoundManager] no map for %s: playing on every placed map (%d)"):format(mode, #placed)) end
	return placed, true
end

-- teams = { A = { member... }, B = {...} }, member = { player | isBot, userId, name }
local function newMatch(kind: string, mode: string, ranked: boolean, teams)
	local match = { kind = kind, mode = mode, ranked = ranked, teams = { A = {}, B = {} }, byUser = {} }
	local idx = 0
	for _, side in { "A", "B" } do
		for _, e in teams[side] do
			idx += 1
			local m = { player = e.player, isBot = e.isBot, userId = e.userId, name = e.name, team = side, index = idx }
			if m.isBot then match.hasBot = true end
			table.insert(match.teams[side], m)
			match.byUser[m.userId] = m
		end
	end
	ReplicatedStorage:SetAttribute("TeamA", teamIds(match.teams.A))
	ReplicatedStorage:SetAttribute("TeamB", teamIds(match.teams.B))
	ReplicatedStorage:SetAttribute("RoundsToWin", C.RoundsToWin)
	ReplicatedStorage:SetAttribute("RoundNumber", 0)
	match.ctx = {
		state = ReplicatedStorage, teams = match.teams, mode = mode, ranked = ranked, config = C, tally = MatchCore.newTally(),
		announce = announce,
		isPresent = isPresent,
		setFrozen = setFrozen,
		spawnMember = function(m, side, i)
			local cf = spawnFrame(side, i, match.map)
			if m.isBot then return makeBot(m, cf) end
			return spawnPlayer(m.player, cf)
		end,
		onRoundStart = function()
			-- the map's barrels / valves, smoke and doors back to the start of a round
			local Shootables = shared.Get and shared.Get("ShootableManager")
			if Shootables and Shootables.ResetAll then Shootables.ResetAll() end
			local Gadgets = shared.Get and shared.Get("GadgetManager")
			if Gadgets and Gadgets.ClearAll then Gadgets.ClearAll() end
			local Doors = shared.Get and shared.Get("DoorManager")
			if Doors and Doors.CloseAll then Doors.CloseAll() end
		end,
		onKill = function(info)
			for _, p in Players:GetPlayers() do Flow:FireClient(p, nil, "Kill", info) end
		end,
	}
	current = match
	return match
end

local function endMatchRecord(match)
	for _, list in match.teams do
		for _, m in list do
			if m.bot then m.bot:Destroy(); m.bot = nil end
		end
	end
	if current == match then current = nil end
end

local function joinMatchData(player: Player)
	local ok, data = pcall(function() return player:GetJoinData().TeleportData end)
	if ok and type(data) == "table" and type(data.Teams) == "table" and type(data.Mode) == "string" and data.Tutorial ~= true then return data end
	-- [MATCH] Studio only: simulated TeleportData (ReplicatedStorage attribute StudioTeleportData, JSON)
	local fake = IS_STUDIO and ReplicatedStorage:GetAttribute("StudioTeleportData")
	if type(fake) == "string" and fake ~= "" then
		local okJ, d = pcall(HttpService.JSONDecode, HttpService, fake)
		if okJ and type(d) == "table" and type(d.Teams) == "table" and type(d.Mode) == "string" then
			d.StudioTest = true
			-- optional phase lengths for a slow test, e.g. "StudioTimes": {"MapVoteTime": 40, "LoadoutTime": 60}
			for k, v in (type(d.StudioTimes) == "table" and d.StudioTimes or {}) do
				if type(C[k]) == "number" and type(v) == "number" then C[k] = v end
			end
			for side, ids in d.Teams do
				for i, id in ids do if id == "me" then ids[i] = player.UserId end end
			end
			return d
		end
		warn("[RoundManager] StudioTeleportData is not valid JSON TeleportData")
	end
	return nil
end

local function loadoutFromTeleport(first, userId: number)
	local l = type(first.Loadouts) == "table" and (first.Loadouts[userId] or first.Loadouts[tostring(userId)]) or nil
	return type(l) == "table" and l or nil
end

local function runMatchServer(first)
	ReplicatedStorage:SetAttribute("TestMode", false)
	ReplicatedStorage:SetAttribute("LiveMatch", true)
	ReplicatedStorage:SetAttribute("InfiniteAmmo", false)
	ReplicatedStorage:SetAttribute("MatchMode", first.Mode)
	ReplicatedStorage:SetAttribute("MatchRanked", first.Ranked == true)
	ReplicatedStorage:SetAttribute("ScoreA", 0); ReplicatedStorage:SetAttribute("ScoreB", 0)
	-- who's expected on each side (user ids from the lobby's matchmaker); Studio: "bot" / ids <= 0 are test bots
	local expected, bots = {}, { A = 0, B = 0 }
	for side, ids in first.Teams do
		if side == "A" or side == "B" then
			for _, id in ids do
				local n = tonumber(id)
				if IS_STUDIO and (id == "bot" or (n and n <= 0)) then bots[side] += 1
				elseif n then expected[n] = side end
			end
		end
	end
	setState("Waiting", first.StudioSolo and 2 or (C.ArrivalTimeout or 30))
	-- the arrival wait shows the UI's loading card
	ReplicatedStorage:SetAttribute("MatchPhase", "Loading")
	announce("MATCH FOUND", "Waiting for everyone to load in...")
	local deadline = os.clock() + ((first.StudioSolo or first.StudioTest) and 2 or (C.ArrivalTimeout or 30))
	local function present()
		local teams = { A = {}, B = {} }
		for _, p in Players:GetPlayers() do
			local side = expected[p.UserId]
			if side then table.insert(teams[side], p) end
		end
		return teams
	end
	local total = 0; for _ in expected do total += 1 end
	while os.clock() < deadline do
		local t = present()
		if #t.A + #t.B >= total then break end
		task.wait(0.5)
	end
	local arrived = present()
	if (#arrived.A + bots.A == 0 or #arrived.B + bots.B == 0) and not first.StudioSolo then
		setState("Cancelled", 5)
		announce("MATCH CANCELLED", "The other team didn't make it. Back to the lobby - no penalty.")
		task.wait(5)
		backToLobby(Players:GetPlayers())
		return
	end
	-- strangers (not on either list) can't play here
	for _, p in Players:GetPlayers() do
		if not expected[p.UserId] then p:Kick("This match server is private.") end
	end

	local teams, botN = { A = {}, B = {} }, 0
	for _, side in { "A", "B" } do
		for _, p in arrived[side] do table.insert(teams[side], { player = p, userId = p.UserId, name = p.Name }) end
		for _ = 1, bots[side] do
			botN += 1
			table.insert(teams[side], { isBot = true, userId = -botN, name = "TestBot" })
		end
	end
	local match = newMatch("match", first.Mode, first.Ranked == true, teams)
	local ratings = { A = 0, B = 0 }
	for side, list in match.teams do
		local sum, n = 0, 0
		for _, m in list do
			if m.player then
				local d = profileData(m.player)
				setupMember(m, d, loadoutFromTeleport(first, m.userId))
				-- CharacterAutoLoads is off: a body parked (frozen) at the team spawn behind the vote / loadout screens, so the
				-- client's PlayerGui (HUD) exists from the start; round 1 loads a fresh one
				task.spawn(function()
					spawnPlayer(m.player, spawnFrame(m.team, table.find(match.teams[m.team], m) or 1, nil))
					setFrozen(m, true)
				end)
				local r = d and d.Ranked and d.Ranked[first.Mode]
				sum += (r and r.Rating) or (C.StartingRating or 1000); n += 1
			end
		end
		ratings[side] = n > 0 and sum / n or (C.StartingRating or 1000)
	end
	local maps, fallback = eligibleMaps(first.Mode)
	match.maps = maps
	ReplicatedStorage:SetAttribute("MapFallback", fallback or nil)
	MatchCore.runPreMatch(match.ctx, {
		maps = maps,
		voters = function()
			local n = 0
			for _, list in match.teams do for _, m in list do if m.player and isPresent(m) then n += 1 end end end
			return n
		end,
		onMapChosen = function(id)
			match.map = MapRegistry.Get(id)
			ReplicatedStorage:SetAttribute("ArenaMap", id)
		end,
	})
	local winner, forfeit = MatchCore.playMatch(match.ctx)
	local everyone = {}
	for side, list in match.teams do
		for _, m in list do
			if m.player and m.player.Parent then
				table.insert(everyone, m.player)
				if not m.left then task.spawn(award, match, m, side, winner, forfeit, ratings) end
			end
		end
	end
	local t0 = os.clock()
	while os.clock() - t0 < (C.ResultsTime or 12) and #Players:GetPlayers() > 0 do task.wait(0.25) end
	endMatchRecord(match)
	backToLobby(Players:GetPlayers())
end

-- the old test flow (Studio / no match data): free practice, first two players duel (on MatchCore), endless rematches
local function runTestServer()
	if C.TestMode then ReplicatedStorage:SetAttribute("TestMode", true); ReplicatedStorage:SetAttribute("InfiniteAmmo", true) end
	while true do
		setState("Waiting")
		for _, p in Players:GetPlayers() do
			if not p:GetAttribute("InMatch") and not p.Character then task.spawn(spawnPlayer, p, nil) end
		end
		local list = {}
		for _, p in Players:GetPlayers() do if not p:GetAttribute("InTutorial") then table.insert(list, p) end end
		if #list >= 2 then
			local match = newMatch("test", "1v1", false, {
				A = { { player = list[1], userId = list[1].UserId, name = list[1].Name } },
				B = { { player = list[2], userId = list[2].UserId, name = list[2].Name } },
			})
			ReplicatedStorage:SetAttribute("ScoreA", 0); ReplicatedStorage:SetAttribute("ScoreB", 0)
			MatchCore.playMatch(match.ctx)
			endMatchRecord(match)
			task.wait(C.MatchEndDelay)
			for _, p in { list[1], list[2] } do if p.Parent then p:SetAttribute("InMatch", false) end end
		else
			task.wait(1)
		end
	end
end

-- a starter-tutorial server (pass 39 fix): no matches, but CharacterAutoLoads is off in this place, so WE spawn
-- the player (and respawn them after a death). Combat on for the shooting step; MatchState "Tutorial" hides the
-- "Waiting for an opponent" line.
local function runTutorialServer()
	ReplicatedStorage:SetAttribute("MatchState", "Tutorial")
	ReplicatedStorage:SetAttribute("StateEndsAt", 0)
	ReplicatedStorage:SetAttribute("CombatEnabled", true)
	ReplicatedStorage:SetAttribute("TestMode", false)
	while true do
		for _, p in Players:GetPlayers() do
			if not p.Character then task.spawn(spawnPlayer, p, nil) end
		end
		task.wait(1)
	end
end

local function hookWaitingDeaths(player: Player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid then
			humanoid.Died:Once(function()
				if not player:GetAttribute("InMatch") and not ReplicatedStorage:GetAttribute("LiveMatch") then
					task.delay(C.WaitingRespawnTime, function()
						if player.Parent and not player:GetAttribute("InMatch") and not isAlive(player) then spawnPlayer(player, nil) end
					end)
				end
			end)
		end
	end)
end

-- // MatchFlow remote (no matchId in the match place; a leading matchId is tolerated and ignored) -------------
local KINDS = { Vote = true, Pick = true, Ready = true, Leave = true }
local SLOTS = { Weapon = true, Melee = true, Gadget = true }
local function onFlow(player: Player, kind: any, a: any, b: any, c: any)
	if not KINDS[kind] and KINDS[a] then kind, a, b = a, b, c end
	local match = current
	local m = match and match.byUser[player.UserId]
	if kind == "Leave" then
		local phase = ReplicatedStorage:GetAttribute("MatchState")
		if m and not m.left then
			-- a leave before the results is a forfeit for the leaver's side (MatchCore sees them as not present)
			m.left = true
			player:SetAttribute("InMatch", false)
			print(("[RoundManager] %s left the match (%s)"):format(player.Name, tostring(phase)))
		end
		backToLobby({ player })
		return
	end
	if not m or m.left then return end
	local phase = ReplicatedStorage:GetAttribute("MatchState")
	if kind == "Vote" then
		MatchCore.castVote(match.ctx, player.UserId, a, match.maps or {})
	elseif kind == "Pick" and phase == "Loadout" then
		if not SLOTS[a] or not MatchCore.validPick(ITEMS, function(id) return owns(player, id) end, a, b) then
			if IS_STUDIO then print(("[RoundManager] pick refused: %s %s %s"):format(player.Name, tostring(a), tostring(b))) end
			return
		end
		local kit = { Weapon = player:GetAttribute("KitWeapon"), Melee = player:GetAttribute("KitMelee"), Gadget = player:GetAttribute("KitGadget") }
		kit[a] = b
		MatchCore.applyKit(m, kit)
	elseif kind == "Ready" and phase == "Loadout" then
		m.ready = true
		player:SetAttribute("LoadoutReady", true)
	end
end

-- // Admin (AdminFramework Commands/Duel) ----------------------------------------------------------------
function manager.MatchInfo()
	local s = ReplicatedStorage
	local info = { kind = current and current.kind or "none", state = s:GetAttribute("MatchState"), mode = s:GetAttribute("MatchMode"),
		ranked = s:GetAttribute("MatchRanked") == true, scoreA = s:GetAttribute("ScoreA") or 0, scoreB = s:GetAttribute("ScoreB") or 0,
		round = s:GetAttribute("RoundNumber") or 0, map = s:GetAttribute("MapChosen"), members = {} }
	for side, list in (current and current.teams or {}) do
		for _, m in list do
			table.insert(info.members, side .. ":" .. tostring(m.name) .. (m.isBot and "(bot)" or "") .. (m.left and "(left)" or ""))
		end
	end
	return info
end
-- both sides forfeit at once: the match ends, nobody is paid, everyone goes back to the lobby (match servers)
function manager.EndMatch(reason: string?)
	local match = current
	if not match then return false, "no match is running on this server" end
	match.aborted = true
	match.ctx.aborted = true
	for _, list in match.teams do for _, m in list do m.left = true end end
	print("[RoundManager] match ended: " .. tostring(reason or "admin"))
	return true
end

-- Studio only: test commands in the game's VM (the MCP's Server execute_luau runs in another VM)
local function testHook(cmd: string, a, b, c)
	if cmd == "info" then return manager.MatchInfo()
	elseif cmd == "returns" then return #manager._returns
	elseif cmd == "phases" then return table.concat(manager._phaseLog, " | ")
	elseif cmd == "kill" then
		-- a = victim userId, b = killer userId, c = headshot
		local m = current and current.byUser[a]
		local hum = m and MatchCore.humanoid(m)
		if not hum then return false, "no member / humanoid " .. tostring(a) end
		hum:SetAttribute("LastAttacker", b or 0)
		hum:SetAttribute("LastAttackKind", "Gun")
		hum:SetAttribute("LastHitZone", c and "Head" or "Body")
		hum.Health = 0
		return true
	elseif cmd == "profile" then
		local p = Players:GetPlayerByUserId(a)
		local DM = dataManager()
		local d = p and DM and DM:Get(p)
		if not d then return "no profile" end
		if type(b) == "table" then for k, v in b do d[k] = v end end
		return d
	elseif cmd == "config" then local old = C[a]; C[a] = b; return old
	end
	return "unknown " .. tostring(cmd)
end

function manager.Start()
	Flow.OnServerEvent:Connect(onFlow)
	local function onJoin(player: Player)
		hookWaitingDeaths(player)
		player:SetAttribute("InMatch", false); player:SetAttribute("RoundWins", 0)
	end
	Players.PlayerAdded:Connect(onJoin)
	for _, p in Players:GetPlayers() do onJoin(p) end
	if IS_STUDIO then
		-- test evidence: every MatchState / MatchPhase change with its time since the server started
		local t0 = os.clock()
		ReplicatedStorage:GetAttributeChangedSignal("MatchState"):Connect(function()
			task.defer(function() table.insert(manager._phaseLog, ("%.1f %s/%s"):format(os.clock() - t0, tostring(ReplicatedStorage:GetAttribute("MatchState")),
				tostring(ReplicatedStorage:GetAttribute("MatchPhase")))) end)
		end)
		local hook = ServerStorage:FindFirstChild("MatchTestHook") or Instance.new("BindableFunction")
		hook.Name = "MatchTestHook"
		hook.OnInvoke = testHook
		hook.Parent = ServerStorage
	end
	task.spawn(function()
		-- decide what kind of server this is from the first player's join data
		-- nil = undecided, false = test server, table = match data
		local first = nil
		while first == nil do
			for _, p in Players:GetPlayers() do
				local d = joinMatchData(p)
				if d then first = d break end
				local ok, td = pcall(function() return p:GetJoinData().TeleportData end)
				local studioTut = IS_STUDIO and ReplicatedStorage:GetAttribute("StudioTutorialServer") == true
				-- starter-tutorial server
				if (ok and type(td) == "table" and td.Tutorial == true) or studioTut then first = "tutorial" break end
				-- Studio-only test switch: ReplicatedStorage attribute StudioSoloMatch = "1v1" (or "R1v1" for ranked) plays a
				-- solo match whose other team never arrives (you win by forfeit) - exercises loadout, rewards, results, return
				local solo = IS_STUDIO and ReplicatedStorage:GetAttribute("StudioSoloMatch")
				if type(solo) == "string" and solo ~= "" then
					first = { Mode = (solo:gsub("^R", "")), Ranked = solo:sub(1, 1) == "R", Teams = { A = { p.UserId }, B = {} }, StudioSolo = true }
					break
				end
				if game.PrivateServerId == "" or IS_STUDIO then first = false break end
			end
			if first == nil then task.wait(0.5) end
		end
		if first == "tutorial" then runTutorialServer()
		elseif first then
			local ok, err = pcall(runMatchServer, first)
			if not ok then
				warn("[RoundManager] match failed: " .. tostring(err))
				backToLobby(Players:GetPlayers())
			end
		else runTestServer() end
	end)
end

return manager
