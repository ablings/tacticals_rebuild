-- lobby_duels_install.lua : lobby pad duels phase 1 (notes/lobby_duels_design.md, notes/lobby_duels_phase1.md), 2026-10-16.
-- Installs the new modules and the small [DUEL] edits in Tacticals_rebuild.rbxl (studio 8ef4e21a). Idempotent.
-- New (sources in scripts/duels/, embedded below by tools/lobby_duels_build.py - edit those files, then rebuild):
--   ReplicatedStorage.Modules.Shared.MapRegistry, ReplicatedStorage.Modules.Shared.MatchState,
--   ServerScriptService.Shared.MatchCore, ...Managers.LobbyDuelManager, StarterPlayer.StarterPlayerScripts.ArenaLoader,
--   ReplicatedStorage.Modules.Shared.Config.MatchConfig (REPLACED by the match place's superset + duel keys; original backed up).
-- [DUEL] edits (each original Source backed up once in ServerStorage._RebuildRemoved.DUEL_<name>_Orig; UNDO reverses each
-- marked edit in place by string swap, and only falls back to the backup when the edit was changed by hand):
--   TrainingGate.On (InDuel turns the combat client on), TrainingManager (no strip / hangar / training entry while InDuel),
--   LobbyFallCatch (skip InDuel), CombatManager / MeleeManager / GadgetManager (per-match CombatEnabled / InfiniteAmmo,
--   same-match damage guard, no friendly fire, kill-credit attributes, weapons for InDuel), QueueManager (pad hand-off,
--   NoMap pads, duelists never hold a pad, Studio DuelTestSolo).
-- The maps themselves: fix/duel_split_map.lua (registry + layers). Runtime objects (LobbyDuels, MatchFlow, DuelArenas,
-- Events.Match) are created by LobbyDuelManager at server start, not here.
-- UNDO: python tools/run_luau.py fix/lobby_duels_install.lua UNDO
local UNDO = false --@UNDO

local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local CHS = game:GetService("ChangeHistoryService")
local rec = CHS:TryBeginRecording("Lobby duels install" .. (UNDO and " UNDO" or ""))
local bin = SS:FindFirstChild("_RebuildRemoved") or Instance.new("Folder")
bin.Name = "_RebuildRemoved"; bin.Parent = SS
local log = {}
local function say(...) local t = {} for _, v in ipairs({ ... }) do table.insert(t, tostring(v)) end table.insert(log, table.concat(t, " ")) end
local function at(path) local o = game; for p in path:gmatch("[^%.]+") do o = o and o:FindFirstChild(p) end return o end

local MGR = "ServerScriptService.ServerScripts.[Server] Init.GameManager.Managers"
-- at() splits on dots, so the bracketed Init folder is looked up by hand
local function managers()
	local init = SSS:FindFirstChild("ServerScripts") and SSS.ServerScripts:FindFirstChild("[Server] Init")
	return init and init:FindFirstChild("GameManager") and init.GameManager:FindFirstChild("Managers")
end
local function scriptAt(path)
	if path:sub(1, #MGR) == MGR then
		local m = managers()
		return m and m:FindFirstChild(path:sub(#MGR + 2))
	end
	return at(path)
end

local SOURCES = {}
--@@BEGIN SOURCES
SOURCES.MapRegistry = [=[-- ReplicatedStorage/Modules/Shared/MapRegistry (ModuleScript): the lobby duels map registry (server + client).
-- One entry per ReplicatedStorage.DuelMaps.<Id> folder that has a MapInfo module (built by fix/duel_split_map.lua).
-- Nothing in the duel code may assume one map's layout: footprint, spawns, modes and the layers all come from here.
--   MapRegistry.List() -> { info }            every map
--   MapRegistry.Get(id) -> info?              info = MapInfo table + .Folder (the ReplicatedStorage entry)
--   MapRegistry.ForMode(mode) -> { info }     maps whose Modes include mode (the vote list; "Random" picks among these)
--   MapRegistry.HasMode(mode) -> bool         false = pads of that mode can't start an in-lobby match (NoMap)
--   MapRegistry.SlotSpacing() -> number       distance between arena slots: the biggest footprint + the longest weapon range
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapRegistry = {}
local WEAPON_RANGE = 600 -- longest gun range (Sniper); arenas must be further apart than this
local cache

local function load()
	if cache then return cache end
	local root = ReplicatedStorage:FindFirstChild("DuelMaps")
	local list = {}
	for _, f in (root and root:GetChildren() or {}) do
		local mod = f:FindFirstChild("MapInfo")
		if mod and mod:IsA("ModuleScript") then
			local ok, info = pcall(require, mod)
			if ok and type(info) == "table" then
				local entry = table.clone(info)
				entry.Id = entry.Id or f.Name
				entry.Folder = f
				table.insert(list, entry)
			else
				warn("[MapRegistry] bad MapInfo in " .. f:GetFullName() .. ": " .. tostring(info))
			end
		end
	end
	table.sort(list, function(a, b) return a.Id < b.Id end)
	cache = list
	return list
end

function MapRegistry.List() return load() end

function MapRegistry.Get(id: string?)
	for _, m in load() do if m.Id == id then return m end end
	return nil
end

function MapRegistry.ForMode(mode: string)
	local out = {}
	for _, m in load() do
		if table.find(m.Modes or {}, mode) then table.insert(out, m) end
	end
	return out
end

function MapRegistry.HasMode(mode: string): boolean
	return #MapRegistry.ForMode(mode) > 0
end

function MapRegistry.SlotSpacing(): number
	local biggest = 0
	for _, m in load() do
		local s = m.Size or Vector3.new(200, 50, 200)
		biggest = math.max(biggest, s.X, s.Z)
	end
	return math.max(1000, biggest + WEAPON_RANGE + 100)
end

return MapRegistry
]=]
SOURCES.MatchState = [=[-- ReplicatedStorage/Modules/Shared/MatchState (ModuleScript): where a player's match state lives (server + client).
--   Match place: ReplicatedStorage itself. Lobby duels: ReplicatedStorage.LobbyDuels.<matchId> (player attr DuelMatch,
--   falling back to DuelSpectate). One HUD reads both places through this.
--   MatchState.For(player) -> Instance?        the state object (nil = in the lobby, not in a match)
--   MatchState.MatchId(player) -> string?
--   MatchState.Role(player) -> "Player" | "Spectator" | nil
--   MatchState.Get(player, attr) -> any        attribute on the player's state object, else on ReplicatedStorage
--   MatchState.SameMatch(a, b) -> bool         a, b = Player or character Model (bots carry DuelMatch on the model)
--   MatchState.ArenaOf(position) -> state?     the lobby match whose arena box contains position
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local MatchState = {}

local function lobbyFolder() return ReplicatedStorage:FindFirstChild("LobbyDuels") end

function MatchState.MatchId(player: Player?): string?
	if not player then return nil end
	local id = player:GetAttribute("DuelMatch") or player:GetAttribute("DuelSpectate")
	return id and tostring(id) or nil
end

function MatchState.Role(player: Player?)
	if not player then return nil end
	if player:GetAttribute("DuelMatch") then return "Player" end
	if player:GetAttribute("DuelSpectate") then return "Spectator" end
	return nil
end

function MatchState.For(player: Player?): Instance?
	local id = MatchState.MatchId(player)
	if id then
		local f = lobbyFolder()
		return f and f:FindFirstChild(id) or nil
	end
	-- the match place keeps its single match on ReplicatedStorage
	if ReplicatedStorage:GetAttribute("MatchState") ~= nil and not lobbyFolder() then return ReplicatedStorage end
	return nil
end

function MatchState.Get(player: Player?, attr: string)
	local o = MatchState.For(player)
	if o then return o:GetAttribute(attr) end
	return ReplicatedStorage:GetAttribute(attr)
end

local function matchOf(x): string?
	if typeof(x) ~= "Instance" then return nil end
	if x:IsA("Player") then return x:GetAttribute("DuelMatch") end
	local p = Players:GetPlayerFromCharacter(x)
	if p then return p:GetAttribute("DuelMatch") end
	return x:GetAttribute("DuelMatch")
end
MatchState.MatchOf = matchOf

function MatchState.SameMatch(a, b): boolean
	return matchOf(a) == matchOf(b)
end

function MatchState.ArenaOf(position: Vector3): Instance?
	local f = lobbyFolder()
	for _, s in (f and f:GetChildren() or {}) do
		local o, size = s:GetAttribute("ArenaOrigin"), s:GetAttribute("ArenaSize")
		if typeof(o) == "Vector3" and typeof(size) == "Vector3" then
			local d = position - o
			if math.abs(d.X) <= size.X / 2 + 50 and math.abs(d.Z) <= size.Z / 2 + 50 and d.Y > -100 and d.Y < size.Y + 100 then return s end
		end
	end
	return nil
end

return MatchState
]=]
SOURCES.MatchCore = [=[-- ServerScriptService/Shared/MatchCore (ModuleScript): the round rules of a team match, shared by the lobby's pad duels
-- (one MatchCore run per match, LobbyDuelManager) and, in phase 4, the match place's RoundManager (one per server).
-- Ported from the match place RoundManager (pass 38): playRound / playMatch / win rules / forfeit / kill tally / award maths.
-- Everything place-specific comes in through a context object, so the rules don't know where they run:
--   ctx.state            Instance  the state object (lobby: ReplicatedStorage.LobbyDuels.<id>; match place: ReplicatedStorage)
--   ctx.teams            { A = {member}, B = {member} }   member = { player = Player?, bot = Model?, userId, name }
--   ctx.mode, ctx.ranked
--   ctx.config           MatchConfig
--   ctx.announce(title, subtitle)               Events.Match.MatchAnnounce to the match's players (+ spectators)
--   ctx.spawnMember(member, team, slot) -> character?   respawn + place + MaxHealth
--   ctx.setFrozen(member, frozen)
--   ctx.isPresent(member) -> bool               false once a player left / disconnected
--   ctx.onRoundStart(roundNumber)               reset the arena (shootables, doors, smoke) of THIS match
--   ctx.onKill(info)                            kill feed {killer, victim, weapon, headshot, kind}
-- Published on ctx.state (names from notes/lobby_duels_design.md section 6; PhaseEndsAt == StateEndsAt always):
--   MatchState, MatchPhase, StateEndsAt, PhaseEndsAt, CombatEnabled, RoundNumber, RoundsToWin, ScoreA, ScoreB
-- Player (member) attributes: InMatch, Team, RoundWins, MatchKills, MatchDeaths, Alive
local MatchCore = {}

local PHASE_OF = { Loading = "Loading", MapVote = "MapVote", Loadout = "Loadout", Countdown = "Playing", Live = "Playing",
	RoundEnd = "Playing", MatchEnd = "Ended", Cancelled = "Ended" }

-- // Members (a Player, or a server test bot = an R15 Model) ---------------------------------------------------------
function MatchCore.attrHolder(m) return m.player or m.bot end
function MatchCore.setAttr(m, k, v) local h = MatchCore.attrHolder(m); if h then h:SetAttribute(k, v) end end
function MatchCore.getAttr(m, k) local h = MatchCore.attrHolder(m); return h and h:GetAttribute(k) end
function MatchCore.character(m) if m.player then return m.player.Character end return m.bot end
function MatchCore.humanoid(m) local c = MatchCore.character(m); return c and c:FindFirstChildOfClass("Humanoid") end
function MatchCore.isAlive(m)
	local h = MatchCore.humanoid(m)
	return h ~= nil and h.Health > 0 and MatchCore.getAttr(m, "Alive") ~= false
end

-- // State -----------------------------------------------------------------------------------------------------------
function MatchCore.setState(ctx, state: string, duration: number?)
	local ends = duration and (workspace:GetServerTimeNow() + duration) or 0
	local s = ctx.state
	s:SetAttribute("MatchState", state)
	s:SetAttribute("StateEndsAt", ends)
	s:SetAttribute("PhaseEndsAt", ends)
	s:SetAttribute("MatchPhase", PHASE_OF[state] or state)
	s:SetAttribute("CombatEnabled", state == "Live")
end

local function score(ctx, side) return ctx.state:GetAttribute("Score" .. side) or 0 end
local function scoreLine(ctx) return `{score(ctx, "A")} - {score(ctx, "B")}` end

-- // Kill tally (victim Humanoid attributes LastAttacker / LastHitZone / LastAttackKind set by Combat / Melee) -----------
function MatchCore.newTally() return {} end
local function t(ctx, uid)
	ctx.tally[uid] = ctx.tally[uid] or { kills = 0, headshots = 0, melee = 0, deaths = 0 }
	return ctx.tally[uid]
end
local function memberById(ctx, uid)
	for _, list in ctx.teams do for _, m in list do if m.userId == uid then return m end end end
	return nil
end

-- call once per spawned character of a member (round spawns)
function MatchCore.watchCharacter(ctx, m, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 10)
	if not humanoid then return end
	humanoid.Died:Once(function()
		if ctx.over or MatchCore.character(m) ~= character then return end
		MatchCore.setAttr(m, "Alive", false)
		local mine = t(ctx, m.userId)
		mine.deaths += 1
		MatchCore.setAttr(m, "MatchDeaths", mine.deaths)
		local killerId = humanoid:GetAttribute("LastAttacker")
		local killer = type(killerId) == "number" and memberById(ctx, killerId)
		local kind = humanoid:GetAttribute("LastAttackKind") or "Gun"
		local headshot = humanoid:GetAttribute("LastHitZone") == "Head"
		if killer and killer ~= m and MatchCore.getAttr(killer, "Team") ~= MatchCore.getAttr(m, "Team") then
			local k = t(ctx, killer.userId)
			k.kills += 1
			if headshot then k.headshots += 1 end
			if kind == "Melee" then k.melee += 1 end
			MatchCore.setAttr(killer, "MatchKills", k.kills)
		end
		if ctx.onKill then
			ctx.onKill({ killer = killer and killer.userId or 0, victim = m.userId, headshot = headshot, kind = kind,
				weapon = killer and MatchCore.getAttr(killer, "Loadout") or nil })
		end
	end)
end

-- // One round. Returns "A", "B" or nil (draw), plus true if a whole team left -------------------------------------------
local function teamAlive(ctx, list) local n = 0 for _, m in list do if ctx.isPresent(m) and MatchCore.isAlive(m) then n += 1 end end return n end
local function teamPresent(ctx, list) local n = 0 for _, m in list do if ctx.isPresent(m) then n += 1 end end return n end
local function teamHealth(ctx, list)
	local h = 0
	for _, m in list do local hu = ctx.isPresent(m) and MatchCore.humanoid(m); if hu and hu.Health > 0 then h += hu.Health end end
	return h
end
function MatchCore.forfeitSide(ctx)
	if teamPresent(ctx, ctx.teams.A) == 0 then return "B" end
	if teamPresent(ctx, ctx.teams.B) == 0 then return "A" end
	return nil
end

function MatchCore.playRound(ctx, roundNumber: number)
	local C = ctx.config
	ctx.state:SetAttribute("RoundNumber", roundNumber)
	if ctx.onRoundStart then ctx.onRoundStart(roundNumber) end

	MatchCore.setState(ctx, "Countdown", C.CountdownTime + 2)
	local total, done = 0, 0
	for side, list in ctx.teams do
		for i, m in list do
			if ctx.isPresent(m) then
				total += 1
				task.spawn(function()
					local ch = ctx.spawnMember(m, side, i)
					if ch then MatchCore.setAttr(m, "Alive", true); MatchCore.watchCharacter(ctx, m, ch) end
					ctx.setFrozen(m, true)
					done += 1
				end)
			end
		end
	end
	local waited = 0
	while done < total and waited < 12 do waited += task.wait(0.1) end
	local f = MatchCore.forfeitSide(ctx); if f then return f, true end

	MatchCore.setState(ctx, "Countdown", C.CountdownTime)
	ctx.announce("ROUND " .. roundNumber, scoreLine(ctx))
	task.wait(C.CountdownTime)
	for _, list in ctx.teams do for _, m in list do ctx.setFrozen(m, false) end end
	MatchCore.setState(ctx, "Live", C.RoundTime)
	ctx.announce("FIGHT", "")

	local endsAt = os.clock() + C.RoundTime
	while os.clock() < endsAt do
		f = MatchCore.forfeitSide(ctx); if f then return f, true end
		local a, b = teamAlive(ctx, ctx.teams.A), teamAlive(ctx, ctx.teams.B)
		if a == 0 or b == 0 then
			task.wait(0.1) -- a trade kill a frame later is still a draw
			a, b = teamAlive(ctx, ctx.teams.A), teamAlive(ctx, ctx.teams.B)
			if a > 0 and b == 0 then return "A" end
			if b > 0 and a == 0 then return "B" end
			return nil
		end
		task.wait(0.05)
	end
	local ha, hb = teamHealth(ctx, ctx.teams.A), teamHealth(ctx, ctx.teams.B) -- timeout: more health left wins
	if ha > hb then return "A" end
	if hb > ha then return "B" end
	return nil
end

-- // A full team match: returns winner ("A"/"B"/nil), forfeit -------------------------------------------------------------
function MatchCore.playMatch(ctx)
	local C = ctx.config
	ctx.tally = ctx.tally or {}
	local s = ctx.state
	s:SetAttribute("ScoreA", 0); s:SetAttribute("ScoreB", 0)
	s:SetAttribute("RoundsToWin", C.RoundsToWin)
	for side, list in ctx.teams do
		for _, m in list do
			MatchCore.setAttr(m, "InMatch", true); MatchCore.setAttr(m, "RoundWins", 0); MatchCore.setAttr(m, "Team", side)
			MatchCore.setAttr(m, "MatchKills", 0); MatchCore.setAttr(m, "MatchDeaths", 0); MatchCore.setAttr(m, "GadgetThrows", 0)
			t(ctx, m.userId)
		end
	end
	local roundNumber, winner, forfeit = 0, nil, false
	while true do
		roundNumber += 1
		local w, left = MatchCore.playRound(ctx, roundNumber)
		if left then winner, forfeit = w, true; ctx.announce("OPPONENTS LEFT", "TEAM " .. w .. " WINS"); break end
		if w then
			local key = "Score" .. w
			s:SetAttribute(key, (s:GetAttribute(key) or 0) + 1)
			for _, m in ctx.teams[w] do MatchCore.setAttr(m, "RoundWins", s:GetAttribute(key)) end
			ctx.announce("TEAM " .. w .. " WINS THE ROUND", scoreLine(ctx))
			if s:GetAttribute(key) >= C.RoundsToWin then winner = w; break end
		else
			ctx.announce("DRAW", scoreLine(ctx))
		end
		MatchCore.setState(ctx, "RoundEnd", C.RoundEndDelay)
		-- a leave during the round-end pause still forfeits
		local untilT = os.clock() + C.RoundEndDelay
		while os.clock() < untilT do
			local f = MatchCore.forfeitSide(ctx)
			if f then winner, forfeit = f, true break end
			task.wait(0.1)
		end
		if forfeit then ctx.announce("OPPONENTS LEFT", "TEAM " .. winner .. " WINS"); break end
		if roundNumber >= (C.MaxRounds or 9) then -- safety: endless draws
			local a, b = score(ctx, "A"), score(ctx, "B")
			winner = a > b and "A" or b > a and "B" or nil
			break
		end
	end
	ctx.over = true
	MatchCore.setState(ctx, "MatchEnd", C.ResultsTime or 12)
	ctx.announce(winner and ("TEAM " .. winner .. " WINS THE MATCH") or "MATCH DRAWN", forfeit and "Forfeit" or "")
	return winner, forfeit
end

-- // Rewards (pure maths; the caller writes them to the profile) ---------------------------------------------------------
function MatchCore.eloDelta(R, myRating: number, theirRating: number, won: boolean?, draw: boolean?): number
	local expected = 1 / (1 + 10 ^ ((theirRating - myRating) / 400))
	local sc = draw and 0.5 or (won and 1 or 0)
	return math.floor((R.RankedK or 32) * (sc - expected) + 0.5)
end

-- returns the MatchResults summary for one member (no profile writes)
function MatchCore.summary(ctx, m, side: string, winner: string?, forfeit: boolean?, passes)
	local R = ctx.config.Rewards or {}
	local st = t(ctx, m.userId)
	local won, draw = winner == side, winner == nil
	local mult = 1
	if passes then
		if passes.DoubleCredits then mult *= 2 end
		if passes.VIP then mult *= 1.25 end
	end
	local xp = (R.XPMatch or 100) + st.kills * (R.XPKill or 50) + (won and (R.XPWin or 150) or 0)
	local scissors = math.floor(((R.ScissorsMatch or 25) + st.kills * (R.ScissorsKill or 10) + (won and (R.ScissorsWin or 50) or 0)) * mult + 0.5)
	local gunXP = (R.GunXPMatch or 50) + st.kills * (R.GunXPKill or 25)
	return {
		Won = won, Draw = draw, Mode = ctx.mode, Ranked = ctx.ranked == true,
		Score = { A = score(ctx, "A"), B = score(ctx, "B") }, Team = side,
		Kills = st.kills, Headshots = st.headshots, MeleeKills = st.melee, Deaths = st.deaths,
		XP = xp, Scissors = scissors, Multiplier = mult, GunXP = gunXP,
		Weapon = MatchCore.getAttr(m, "Loadout") or "Pistol", RatingChange = nil, Saved = false, Forfeit = forfeit == true,
	}
end

-- // Loadout ----------------------------------------------------------------------------------------------------------
-- picks = { Weapon, Melee, Gadget }; ownsFn(id) -> bool; items = LobbyConfig.Items. Sets the Kit* attributes and the
-- gameplay mirror Loadout = KitWeapon (CombatManager gives Loadout).
function MatchCore.validPick(items, ownsFn, slot: string, id: any): boolean
	if type(id) ~= "string" then return false end
	local it = items[id]
	return it ~= nil and it.Slot == slot and (it.Default == true or ownsFn(id))
end
function MatchCore.applyKit(m, kit)
	MatchCore.setAttr(m, "KitWeapon", kit.Weapon)
	MatchCore.setAttr(m, "KitMelee", kit.Melee)
	MatchCore.setAttr(m, "KitGadget", kit.Gadget)
	MatchCore.setAttr(m, "Loadout", kit.Weapon)
end

-- // Map vote: votes = { [userId] = mapId }; maps = registry entries; returns the chosen real map id -------------------------
function MatchCore.resolveVote(votes, maps): string?
	if #maps == 0 then return nil end
	local count = {}
	for _, id in votes do count[id] = (count[id] or 0) + 1 end
	local best, bestN = {}, 0
	for id, n in count do
		if n > bestN then best, bestN = { id }, n elseif n == bestN then table.insert(best, id) end
	end
	local pick = #best > 0 and best[math.random(#best)] or "Random"
	local valid = false
	for _, m in maps do if m.Id == pick then valid = true end end
	if not valid then pick = maps[math.random(#maps)].Id end -- "Random" (or nothing voted) resolves to a real map
	return pick
end

return MatchCore
]=]
SOURCES.LobbyDuelManager = [=[-- ServerScripts/[Server] Init/GameManager/Managers/LobbyDuelManager (ModuleScript)
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
]=]
SOURCES.ArenaLoader = [=[-- StarterPlayerScripts/ArenaLoader (LocalScript): lobby pad duels, client side (notes/lobby_duels_design.md section 3).
-- Loads the chosen map's Visual layer on THIS client only, while the player is in (or watching) a lobby match:
--   state = ReplicatedStorage.LobbyDuels[DuelMatch or DuelSpectate]; when it has ArenaMap + ArenaOrigin:
--   preload the meshes / SurfaceAppearances, clone ReplicatedStorage.DuelMaps.<map>.Visual to the slot origin
--   (named MapInfo.WorkspaceName), swap Lighting to the map's (local only), then MatchFlow:FireServer(id, "Loaded").
-- Unloads (destroy the clone, restore the lobby's Lighting) when the attribute clears or the state object goes away.
-- Fades: black on MatchFlow "Return" (the trip back to the pads) and a fade-in when the first round starts.
-- Nothing here names a map: everything comes from MapRegistry. Lobby players never get a clone, so they never draw an arena.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared")
local MapRegistry = require(Shared:WaitForChild("MapRegistry"))

local loaded = nil -- { id, map, clone, saved }
local busy = false

-- // Fade ----------------------------------------------------------------------------------------------------------------
local fadeGui = Instance.new("ScreenGui")
fadeGui.Name = "DuelFade"; fadeGui.IgnoreGuiInset = true; fadeGui.ResetOnSpawn = false; fadeGui.DisplayOrder = 40
local black = Instance.new("Frame")
black.Size = UDim2.fromScale(1, 1); black.BackgroundColor3 = Color3.new(0, 0, 0); black.BackgroundTransparency = 1; black.BorderSizePixel = 0
black.Parent = fadeGui
fadeGui.Parent = player:WaitForChild("PlayerGui")
local function fade(to: number, t: number)
	TweenService:Create(black, TweenInfo.new(t), { BackgroundTransparency = to }):Play()
end

-- // Lighting swap (local) ---------------------------------------------------------------------------------------------------
local function swapLighting(cfg: Instance?)
	if not cfg then return nil end
	local saved = { props = {}, moved = {}, disabled = {}, added = {} }
	for k, v in cfg:GetAttributes() do
		local ok, old = pcall(function() return (Lighting :: any)[k] end)
		if ok then saved.props[k] = old; pcall(function() (Lighting :: any)[k] = v end) end
	end
	-- the lobby's effects step aside: Atmosphere / Sky can't be disabled, so they move out (local only) and come back
	local hasAtmo = cfg:FindFirstChildOfClass("Atmosphere") ~= nil
	for _, c in Lighting:GetChildren() do
		if c:IsA("Atmosphere") and hasAtmo then
			table.insert(saved.moved, c); c.Parent = script
		elseif c:IsA("PostEffect") and c.Enabled then
			table.insert(saved.disabled, c); c.Enabled = false
		end
	end
	for _, c in cfg:GetChildren() do
		local cl = c:Clone(); cl.Parent = Lighting
		table.insert(saved.added, cl)
	end
	return saved
end
local function restoreLighting(saved)
	if not saved then return end
	for _, c in saved.added do c:Destroy() end
	for k, v in saved.props do pcall(function() (Lighting :: any)[k] = v end) end
	for _, c in saved.moved do c.Parent = Lighting end
	for _, c in saved.disabled do if c.Parent then c.Enabled = true end end
end

-- // Load / unload ----------------------------------------------------------------------------------------------------------
local function matchId(): string?
	local id = player:GetAttribute("DuelMatch") or player:GetAttribute("DuelSpectate")
	return id and tostring(id) or nil
end
local function stateOf(id: string?)
	local f = ReplicatedStorage:FindFirstChild("LobbyDuels")
	return id and f and f:FindFirstChild(id) or nil
end

local function unload()
	if not loaded then return end
	if loaded.clone then loaded.clone:Destroy() end
	restoreLighting(loaded.saved)
	loaded = nil
end

local function load(id: string, state: Instance)
	local mapId, origin = state:GetAttribute("ArenaMap"), state:GetAttribute("ArenaOrigin")
	local info = MapRegistry.Get(mapId)
	if not info or typeof(origin) ~= "Vector3" then return end
	local template = info.Folder:FindFirstChild("Visual")
	if not template then warn("[ArenaLoader] no Visual layer for " .. tostring(mapId)); return end
	busy = true
	-- preload behind the loadout screen (capped, so a slow asset can't hold the match)
	local assets = {}
	for _, d in template:GetDescendants() do
		if d:IsA("MeshPart") or d:IsA("SurfaceAppearance") then table.insert(assets, d) end
	end
	local done = false
	task.spawn(function() pcall(ContentProvider.PreloadAsync, ContentProvider, assets); done = true end)
	local t0 = os.clock()
	while not done and os.clock() - t0 < 8 do task.wait(0.1) end
	if matchId() ~= id or not state.Parent then busy = false; return end
	local clone = template:Clone()
	clone.Name = info.WorkspaceName or info.Id
	clone:PivotTo(CFrame.new(origin))
	clone:SetAttribute("DuelArena", id)
	clone.Parent = workspace
	loaded = { id = id, map = mapId, clone = clone, saved = swapLighting(info.Folder:FindFirstChild("Lighting")) }
	busy = false
	local flow = ReplicatedStorage:FindFirstChild("MatchFlow")
	if flow then flow:FireServer(id, "Loaded") end
	print(`[ArenaLoader] {mapId} loaded for {id} ({#clone:GetDescendants()} instances, preload {string.format("%.1f", os.clock() - t0)} s)`)
end

local lastPhase
local function tick()
	local id = matchId()
	local state = stateOf(id)
	if loaded and (loaded.id ~= id or not state or state:GetAttribute("ArenaMap") ~= loaded.map) then unload() end
	if not loaded and not busy and state and state:GetAttribute("ArenaMap") and state:GetAttribute("ArenaOrigin") then
		task.spawn(load, id, state)
	end
	-- fade in from black when the match first goes to its rounds
	local phase = state and state:GetAttribute("MatchPhase")
	if phase == "Playing" and lastPhase ~= "Playing" then
		black.BackgroundTransparency = 0; fade(1, 0.8)
	end
	if not id and black.BackgroundTransparency < 1 then fade(1, 0.6) end
	lastPhase = phase
end

task.spawn(function()
	local flow = ReplicatedStorage:WaitForChild("MatchFlow", 60)
	if flow then
		flow.OnClientEvent:Connect(function(_, kind)
			if kind == "Return" then fade(0, 0.5) end
		end)
	end
end)
while true do
	pcall(tick)
	task.wait(0.2)
end
]=]
SOURCES.MatchConfig = [=[-- ReplicatedStorage/Modules/Shared/Config/MatchConfig (ModuleScript)
-- Match rules. Times in seconds. [DUEL] lobby copy = the match place's MatchConfig (pass 38 superset) + the lobby duel keys
-- at the bottom (lobby duels phase 1, 2026-10-16; original lobby copy in ServerStorage._RebuildRemoved.DUEL_MatchConfig_Orig).
return {
	TestMode = true,        -- match place test servers only; ignored by lobby duels.
	PlayerHealth = 150,     -- everyone's max health in a match (lobby duels set it on every round spawn)
	RoundsToWin = 3,        -- best of 5
	CountdownTime = 3,      -- frozen at spawn before each round
	RoundTime = 90,         -- round timer; on timeout the player with more health wins (tie = draw)
	RoundEndDelay = 3,      -- pause after a round before the next countdown
	MatchEndDelay = 6,      -- pause after a match before the rematch starts
	WaitingRespawnTime = 3, -- respawn delay while waiting for an opponent (free practice)
	SpawnFolderName = "MatchSpawns", -- match place: Workspace folder with parts named SpawnA and SpawnB
	LobbyPlaceId = 126491009194165,
	ArrivalTimeout = 30,
	ResultsTime = 12,       -- results screen
	MaxRounds = 9,          -- safety cap (endless draws)
	StartingRating = 1000,
	Rewards = {             -- per match; scissors are multiplied by 2X SCISSORS (x2) and VIP (x1.25)
		XPMatch = 100, XPKill = 50, XPWin = 150,
		ScissorsMatch = 25, ScissorsKill = 10, ScissorsWin = 50,
		GunXPMatch = 50, GunXPKill = 25,
		RankedK = 32,
	},

	-- [DUEL] lobby pad duels (in-lobby matches on an arena slot; notes/lobby_duels_design.md)
	PadDuelsInLobby = true, -- false = the pads teleport to the match place as before
	DuelMapVote = true,     -- false = skip the vote (first eligible map)
	LoadingTime = 3,
	MapVoteTime = 10,
	LoadoutTime = 15,       -- ends early when everyone is Ready and Loaded
	LoadedGrace = 5,        -- extra time for a client that hasn't loaded the arena, then it counts as left
	MaxArenas = 6,          -- concurrent in-lobby matches (lead default, Edward may change)
	ArenaBaseX = 4000,      -- slot n origin = (ArenaBaseX + spacing * (n - 1), ArenaY, 0); spacing from MapRegistry
	ArenaY = 100,
	DuelRanked = false,     -- pad duels are casual only (lead default, Edward may change)
	DuelRewardCooldown = 600, -- one reward per opponent pair per 10 minutes (anti-farming; lead default)
	ReturnFade = 1,
}
]=]
--@@END SOURCES

-- new modules: { parent path, name, class, SOURCES key }
local NEW = {
	{ "ReplicatedStorage.Modules.Shared", "MapRegistry", "ModuleScript", "MapRegistry" },
	{ "ReplicatedStorage.Modules.Shared", "MatchState", "ModuleScript", "MatchState" },
	{ "ServerScriptService.Shared", "MatchCore", "ModuleScript", "MatchCore" },
	{ MGR, "LobbyDuelManager", "ModuleScript", "LobbyDuelManager" },
	{ "StarterPlayer.StarterPlayerScripts", "ArenaLoader", "LocalScript", "ArenaLoader" },
}
-- whole-source replacements (backup + restore): { path, SOURCES key }
local REPLACE = {
	{ "ReplicatedStorage.Modules.Shared.Config.MatchConfig", "MatchConfig" },
}

-- marked edits: { script path, old text, new text }. new always contains "[DUEL]".
local C_REQ_OLD = 'local RateLimiter = require(Shared.Madwork.RateLimiter)\n'
local C_REQ_NEW = C_REQ_OLD .. '-- [DUEL] lobby pad duels: per-match state (CombatEnabled / LiveMatch / InfiniteAmmo) and the same-match damage guard\nlocal MatchState = require(Shared.MatchState)\n'
local EDITS = {
	-- TrainingGate: one line turns every combat controller on for duelists
	{ "ReplicatedStorage.Modules.Shared.TrainingGate",
		'function Gate.On() return player ~= nil and player:GetAttribute("InTraining") == true end',
		'-- [DUEL] a lobby duel (InDuel) turns the combat client on as well\nfunction Gate.On() return player ~= nil and (player:GetAttribute("InTraining") == true or player:GetAttribute("InDuel") == true) end' },
	-- TrainingManager: duelists keep their guns, aren't sent to the hangar and can't enter training
	{ MGR .. ".TrainingManager",
		'\t\t\t\t\telse\n\t\t\t\t\t\tstripTools(p)',
		'\t\t\t\t\t-- [DUEL] players in a lobby duel keep their kit and stay in their arena\n\t\t\t\t\telseif not p:GetAttribute("InDuel") then\n\t\t\t\t\t\tstripTools(p)' },
	{ MGR .. ".TrainingManager",
		'local function enter(player)\n\tif player:GetAttribute("InTraining") then return end',
		'local function enter(player)\n\t-- [DUEL] no training while in a lobby duel\n\tif player:GetAttribute("InTraining") or player:GetAttribute("InDuel") then return end' },
	-- LobbyFallCatch
	{ "ServerScriptService.LobbyFallCatch",
		'if r and not pl:GetAttribute("InTraining") and r.Position.Y < -25',
		'-- [DUEL] duelists are handled by LobbyDuelManager (arena kill depth)\n\t\tif r and not pl:GetAttribute("InTraining") and not pl:GetAttribute("InDuel") and r.Position.Y < -25' },
	-- CombatManager
	{ MGR .. ".CombatManager", C_REQ_OLD, C_REQ_NEW },
	{ MGR .. ".CombatManager",
		'\tif not player:GetAttribute("InTraining") then return end -- lobby: weapons only in the training room',
		'\t-- [DUEL] lobby: weapons only in the training room or a lobby duel\n\tif not (player:GetAttribute("InTraining") or player:GetAttribute("InDuel")) then return end' },
	{ MGR .. ".CombatManager",
		'\tif ReplicatedStorage:GetAttribute("CombatEnabled") == false then return finish("combat disabled (countdown / round over)") end',
		'\t-- [DUEL] the player\'s match state (lobby duels), else ReplicatedStorage as before\n\tif MatchState.Get(player, "CombatEnabled") == false then return finish("combat disabled (countdown / round over)") end' },
	{ MGR .. ".CombatManager",
		'\tif victimHumanoid.Health <= 0 then return finish("target already dead") end\n',
		'\tif victimHumanoid.Health <= 0 then return finish("target already dead") end\n'
			.. '\t-- [DUEL] damage only inside one match (or outside any): duelists never hurt lobby players or another arena; no friendly fire\n'
			.. '\tif not MatchState.SameMatch(player, victimCharacter) then return finish("other match") end\n'
			.. '\tlocal victimOwner = Players:GetPlayerFromCharacter(victimCharacter) or victimCharacter\n'
			.. '\tif MatchState.Get(player, "LiveMatch") and player:GetAttribute("Team") and victimOwner:GetAttribute("Team") == player:GetAttribute("Team") then return finish("friendly fire") end\n' },
	{ MGR .. ".CombatManager",
		'\tvictimHumanoid:SetAttribute("LastAttacker", player.UserId)\n',
		'\tvictimHumanoid:SetAttribute("LastAttacker", player.UserId)\n\t-- [DUEL] kill credit for the match tally (pass 38 names)\n\tvictimHumanoid:SetAttribute("LastHitZone", zone)\n\tvictimHumanoid:SetAttribute("LastAttackKind", "Gun")\n' },
	{ MGR .. ".CombatManager",
		'\t\t\tif not ReplicatedStorage:GetAttribute("InfiniteAmmo") then',
		'\t\t\t-- [DUEL] per match (lobby duels: normal ammo), else ReplicatedStorage as before\n\t\t\tif not MatchState.Get(player, "InfiniteAmmo") then' },
	-- MeleeManager
	{ MGR .. ".MeleeManager",
		'local Combat = ReplicatedStorage.Events.Combat\n',
		'local Combat = ReplicatedStorage.Events.Combat\n-- [DUEL] lobby pad duels: per-match state and the same-match guard\nlocal MatchState = require(ReplicatedStorage.Modules.Shared.MatchState)\n' },
	{ MGR .. ".MeleeManager",
		'\tif not player:GetAttribute("InTraining") then return end -- lobby: melee only in the training room',
		'\t-- [DUEL] lobby: melee only in the training room or a lobby duel\n\tif not (player:GetAttribute("InTraining") or player:GetAttribute("InDuel")) then return end' },
	{ MGR .. ".MeleeManager",
		'\tif ReplicatedStorage:GetAttribute("CombatEnabled") == false then return end\n\tlocal character = player.Character',
		'\t-- [DUEL] the player\'s match state (lobby duels), else ReplicatedStorage as before\n\tif MatchState.Get(player, "CombatEnabled") == false then return end\n\tlocal character = player.Character' },
	{ MGR .. ".MeleeManager",
		'\t\tif other ~= character and otherHum and otherHum.Health > 0 and otherRoot then',
		'\t\t-- [DUEL] only targets in the same match (or outside any), never a teammate in a live match\n'
			.. '\t\tlocal otherOwner = Players:GetPlayerFromCharacter(other) or other\n'
			.. '\t\tlocal mate = MatchState.Get(player, "LiveMatch") and player:GetAttribute("Team") ~= nil and otherOwner:GetAttribute("Team") == player:GetAttribute("Team")\n'
			.. '\t\tif other ~= character and otherHum and otherHum.Health > 0 and otherRoot and MatchState.SameMatch(player, other) and not mate then' },
	{ MGR .. ".MeleeManager",
		'\tvictimHum:TakeDamage(damage)\n',
		'\t-- [DUEL] kill credit for the match tally (pass 38 names)\n\tvictimHum:SetAttribute("LastAttacker", player.UserId)\n\tvictimHum:SetAttribute("LastAttackKind", "Melee")\n\tvictimHum:SetAttribute("LastHitZone", backstab and "Back" or "Body")\n\tvictimHum:TakeDamage(damage)\n' },
	-- GadgetManager
	{ MGR .. ".GadgetManager",
		'local mapParams = RaycastParams.new()\n',
		'-- [DUEL] lobby pad duels: per-match CombatEnabled\nlocal MatchState = require(ReplicatedStorage.Modules.Shared.MatchState)\nlocal mapParams = RaycastParams.new()\n' },
	{ MGR .. ".GadgetManager",
		'\tif ReplicatedStorage:GetAttribute("CombatEnabled") == false then return end\n\tlocal cfg = GadgetConfig[gadget]',
		'\t-- [DUEL] the player\'s match state (lobby duels), else ReplicatedStorage as before\n\tif MatchState.Get(player, "CombatEnabled") == false then return end\n\tlocal cfg = GadgetConfig[gadget]' },
	-- QueueManager
	{ MGR .. ".QueueManager",
		'\t\tlocal s = playerSlot[player]\n\t\tif s and s.bay.state == "Deploying" then continue end\n',
		'\t\tlocal s = playerSlot[player]\n\t\tif s and s.bay.state == "Deploying" then continue end\n\t\t-- [DUEL] players in a lobby duel never take (or hold) a pad slot\n\t\tif player:GetAttribute("DuelMatch") then if s then release(player) end continue end\n' },
	{ MGR .. ".QueueManager",
		'local function bayIsFull(bay): boolean\n\tlocal n = #occupants(bay)\n',
		'local function bayIsFull(bay): boolean\n\tlocal n = #occupants(bay)\n'
			.. '\t-- [DUEL] a pad whose mode has no duel map never counts down (NoMap, set by LobbyDuelManager); Studio DuelTestSolo starts alone\n'
			.. '\tif bay.model:GetAttribute("NoMap") then return false end\n'
			.. '\tif IS_STUDIO and ReplicatedStorage:GetAttribute("DuelTestSolo") == true and n >= 1 then return true end\n' },
	{ MGR .. ".QueueManager",
		'\t\t\telseif now >= bay.countdownEnd then\n\t\t\t\tdeploy(bay)',
		'\t\t\telseif now >= bay.countdownEnd then\n\t\t\t\t-- [DUEL] an in-lobby match instead of the teleport (LobbyDuelManager); false = the old teleport\n\t\t\t\tif not duelHandoff(bay) then deploy(bay) end' },
	{ MGR .. ".QueueManager",
		'TeleportService.TeleportInitFailed:Connect(function(player, _, message)',
		'-- [DUEL] lobby pad duels (notes/lobby_duels_design.md): hand a full bay to LobbyDuelManager. Returns true when handled\n'
			.. '-- (started, or waiting for a free arena: the bay stays in Countdown and re-checks every second).\n'
			.. 'local function duelHandoff(bay): boolean\n'
			.. '\tlocal LDM = shared.Get and shared.Get("LobbyDuelManager")\n'
			.. '\tif not (LDM and LDM.Enabled()) then return false end\n'
			.. '\tlocal teams = { A = {}, B = {} }\n'
			.. '\tfor _, s in bay.slots do\n'
			.. '\t\tif s.occupant then table.insert(teams[s.team], { player = s.occupant, stepOff = stepOffCFrame(s) }) end\n'
			.. '\tend\n'
			.. '\tlocal ok, why = LDM.StartMatch(bay.model, bay.mode, teams)\n'
			.. '\tif not ok then\n'
			.. '\t\tbay.countdownEnd = os.clock() + 1\n'
			.. '\t\tif why ~= bay.duelWait then\n'
			.. '\t\t\tbay.duelWait = why\n'
			.. '\t\t\tfor _, p in occupants(bay) do Remotes.Notify(p, tostring(why), "bad") end\n'
			.. '\t\tend\n'
			.. '\t\tfor _, scr in bay.screens do setScreen(scr, string.upper(bay.mode) .. "  ·  BAY " .. string.format("%02d", bay.id), "  " .. tostring(why), Color3.fromRGB(235, 190, 90)) end\n'
			.. '\t\tdirty = true\n'
			.. '\t\treturn true\n'
			.. '\tend\n'
			.. '\tbay.duelWait = nil\n'
			.. '\t-- the pad is free for the next group at once while this match runs\n'
			.. '\tfor _, s in bay.slots do if s.occupant then release(s.occupant) end end\n'
			.. '\tbay.state = "Open"\n'
			.. '\tbay.cooldownUntil = os.clock() + 3\n'
			.. '\trefreshBayVisuals(bay)\n'
			.. '\tdirty = true\n'
			.. '\treturn true\n'
			.. 'end\n\n'
			.. 'TeleportService.TeleportInitFailed:Connect(function(player, _, message)' },
	{ MGR .. ".QueueManager",
		'\t\t\tcountdown = bay.state == "Countdown" and remaining(bay) or nil, occupants = occ,\n',
		'\t\t\tcountdown = bay.state == "Countdown" and remaining(bay) or nil, occupants = occ,\n\t\t\t-- [DUEL] "ARENAS FULL - WAITING" while a full bay waits for an arena; "No maps yet for 2v2" on NoMap pads\n\t\t\tduelWait = bay.duelWait, noMap = bay.model:GetAttribute("NoMapText"),\n' },
	{ MGR .. ".QueueManager",
		'\tif playerSlot[player] then return { ok = false, msg = "You\'re already queued. Leave first to switch." } end\n',
		'\tif playerSlot[player] then return { ok = false, msg = "You\'re already queued. Leave first to switch." } end\n\t-- [DUEL] not while in a lobby duel\n\tif player:GetAttribute("DuelMatch") then return { ok = false, msg = "You\'re in a duel" } end\n' },
	{ MGR .. ".QueueManager",
		'\tif playerSlot[player] then\n\t\treturn { ok = false, msg = "You\'re already queued. Leave first to switch." }\n\tend\n',
		'\tif playerSlot[player] then\n\t\treturn { ok = false, msg = "You\'re already queued. Leave first to switch." }\n\tend\n\t-- [DUEL] not while in a lobby duel\n\tif player:GetAttribute("DuelMatch") then return { ok = false, msg = "You\'re in a duel" } end\n' },
}

local function backup(s)
	local name = "DUEL_" .. s.Name .. "_Orig"
	if not bin:FindFirstChild(name) and not s.Source:find("[DUEL]", 1, true) then
		local b = s:Clone(); b.Name = name; b:ClearAllChildren()
		if b:IsA("BaseScript") then b.Disabled = true end
		b.Parent = bin
	end
end

local function folderAt(path)
	local o = path == MGR and managers() or at(path)
	if not o and path == "ServerScriptService.Shared" then
		o = Instance.new("Folder"); o.Name = "Shared"; o.Parent = SSS
	end
	return o
end

if UNDO then
	-- edits, in reverse order, by string swap
	for i = #EDITS, 1, -1 do
		local e = EDITS[i]
		local s = scriptAt(e[1])
		if s then
			local a, b = s.Source:find(e[3], 1, true)
			if a then s.Source = s.Source:sub(1, a - 1) .. e[2] .. s.Source:sub(b + 1); say("UNDO edit", i, s.Name)
			elseif s.Source:find(e[2], 1, true) then say("edit", i, s.Name, "not applied")
			else
				local bak = bin:FindFirstChild("DUEL_" .. s.Name .. "_Orig")
				if bak then s.Source = bak.Source; say("edit", i, s.Name, "changed by hand: full backup restored") else say("WARN edit", i, s.Name, "neither text found") end
			end
		end
	end
	for _, e in EDITS do
		local s = scriptAt(e[1])
		local bak = s and bin:FindFirstChild("DUEL_" .. s.Name .. "_Orig")
		if bak and not s.Source:find("[DUEL]", 1, true) then bak:Destroy() end
	end
	for _, r in REPLACE do
		local s = at(r[1])
		local bak = s and bin:FindFirstChild("DUEL_" .. s.Name .. "_Orig")
		if bak then s.Source = bak.Source; bak:Destroy(); say("restored", s.Name) end
	end
	for _, n in NEW do
		local p = folderAt(n[1])
		local s = p and p:FindFirstChild(n[2])
		if s then s:Destroy(); say("removed", n[2]) end
	end
	local sh = SSS:FindFirstChild("Shared")
	if sh and #sh:GetChildren() == 0 then sh:Destroy() end
else
	local haveSources = next(SOURCES) ~= nil
	if not haveSources then say("WARN no embedded sources: run python tools/lobby_duels_build.py first (edits only)") end
	for _, n in NEW do
		local src = SOURCES[n[4]]
		local p = folderAt(n[1])
		if src and p then
			local s = p:FindFirstChild(n[2])
			if s and s.ClassName ~= n[3] then s:Destroy(); s = nil end
			if not s then s = Instance.new(n[3]); s.Name = n[2]; s.Parent = p end
			if s.Source ~= src then s.Source = src; say("module", n[2], "written") else say("module", n[2], "up to date") end
		elseif not p then say("WARN missing parent", n[1]) end
	end
	for _, r in REPLACE do
		local s = at(r[1])
		local src = SOURCES[r[2]]
		if s and src then
			backup(s)
			if s.Source ~= src then s.Source = src; say("replaced", s.Name) end
		end
	end
	for i, e in EDITS do
		local s = scriptAt(e[1])
		if not s then say("WARN missing", e[1])
		elseif s.Source:find(e[3], 1, true) then say("edit", i, s.Name, "already in")
		else
			local a, b = s.Source:find(e[2], 1, true)
			if a then
				backup(s)
				s.Source = s.Source:sub(1, a - 1) .. e[3] .. s.Source:sub(b + 1)
				say("edit", i, s.Name, "applied")
			else say("WARN edit", i, s.Name, "anchor text not found") end
		end
	end
end
if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
return table.concat(log, "\n")
