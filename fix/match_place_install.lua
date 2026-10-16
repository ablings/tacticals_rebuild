-- match_place_install.lua : the match place on MatchCore (notes/match_place_flow.md), 2026-10-16. match_place_ref.rbxl (studio 331cb3a0,
-- the local working copy of place 81861384114744). Idempotent. Never saves the place.
-- Sources (embedded below by tools/match_place_build.py - edit those files, then rebuild):
--   scripts/duels/  MapRegistry, MatchState, MatchCore, MatchConfig   SHARED with the lobby: identical source in both places
--   scripts/match/  RoundManager (the [MATCH] whole-source replacement), LobbyConfig (subset port), MapInfo_Warehouse
--   scripts/admin/  the admin framework (same files as the lobby's fix/admin_install.lua, without its two lobby [ADMIN] edits)
-- New (each made by this install carries attribute MatchInstall = true; UNDO removes exactly those):
--   ReplicatedStorage.Modules.Shared.MapRegistry / MatchState, ReplicatedStorage.Modules.Shared.Config.LobbyConfig,
--   ServerScriptService.Shared.MatchCore, ReplicatedStorage.DuelMaps.Warehouse (Folder: DisplayName, Image, Modes) + MapInfo,
--   ServerScriptService.AdminFramework (+ Commands), ServerScriptService.AdminCommands (Script),
--   StarterPlayer.StarterPlayerScripts.AdminFeedback (LocalScript)
-- [MATCH] whole-source replacements (original Source backed up once as ServerStorage._RebuildRemoved.MATCH_<name>_Orig):
--   ...Managers.RoundManager (rounds on MatchCore + Loading / MapVote / Loadout, MatchFlow, admin MatchInfo / EndMatch),
--   ReplicatedStorage.Modules.Shared.Config.MatchConfig (the lobby's superset: same values + the duel keys)
-- Runtime only (made by RoundManager at server start): ReplicatedStorage.MatchFlow, Studio-only ServerStorage.MatchTestHook.
-- UNDO: python tools/match_place_build.py --run UNDO
local UNDO = false --@UNDO

local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local SP = game:GetService("StarterPlayer")
local CHS = game:GetService("ChangeHistoryService")
local rec = CHS:TryBeginRecording("Match place install" .. (UNDO and " UNDO" or ""))
local bin = SS:FindFirstChild("_RebuildRemoved") or Instance.new("Folder")
bin.Name = "_RebuildRemoved"; bin.Parent = SS
local log = {}
local function say(...) local t = {} for _, v in ipairs({ ... }) do table.insert(t, tostring(v)) end table.insert(log, table.concat(t, " ")) end
local function managers()
	local init = SSS:FindFirstChild("ServerScripts") and SSS.ServerScripts:FindFirstChild("[Server] Init")
	return init and init:FindFirstChild("GameManager") and init.GameManager:FindFirstChild("Managers")
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
--   MapRegistry.Changed  (RBXScriptSignal-like :Connect) fires when a map folder is added or removed (cache dropped)
-- Optional MapInfo keys read by the duel code (phase 2): RayFolders = { "<Solid child>" } (what smoke / blast rays hit;
-- default: CollisionProxies if the map has it, else the whole Solid layer), LightBudget (see fix/duel_split_map.lua).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapRegistry = {}
local WEAPON_RANGE = 600 -- longest gun range (Sniper); arenas must be further apart than this
local cache
local changed = Instance.new("BindableEvent")
MapRegistry.Changed = changed.Event
local watching = false
local function watch(root)
	if watching or not root then return end
	watching = true
	-- a map added or removed at runtime (e.g. a Studio test map) is picked up on the next call
	local function drop() cache = nil; changed:Fire() end
	root.ChildAdded:Connect(drop)
	root.ChildRemoved:Connect(drop)
end

local function load()
	if cache then return cache end
	local root = ReplicatedStorage:FindFirstChild("DuelMaps")
	watch(root)
	local list = {}
	for _, f in (root and root:GetChildren() or {}) do
		local mod = f:FindFirstChild("MapInfo")
		if mod and mod:IsA("ModuleScript") then
			local ok, info = pcall(require, mod)
			if ok and type(info) == "table" then
				local entry = table.clone(info)
				-- the folder is authoritative: its name is the map id, its Modes attribute ("1v1,2v2") overrides MapInfo.Modes
				-- (so a map's modes can change without regenerating MapInfo, and a copied folder is its own map)
				entry.Id = f.Name
				local modes = f:GetAttribute("Modes")
				if type(modes) == "string" and modes ~= "" then
					entry.Modes = {}
					for m in modes:gmatch("[^,%s]+") do table.insert(entry.Modes, m) end
				end
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
--   MatchState.Audience(matchId) -> {Player}    players of that match + its spectators (matchId nil = everyone NOT in a duel)
--   MatchState.FireScoped(remote, anchor, ...)  server: fire a combat FX remote only to the audience of anchor's match
--                                               (anchor = Player / character / bot Model / Vector3 / matchId string)
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

-- the match an effect belongs to: a Player / character / bot Model (DuelMatch), a position (the arena it is in) or an id
function MatchState.ScopeOf(anchor): string?
	local t = typeof(anchor)
	if t == "string" then return anchor end
	if t == "Vector3" then
		local s = MatchState.ArenaOf(anchor)
		return s and s.Name or nil
	end
	if t == "Instance" then
		local id = matchOf(anchor)
		if id then return tostring(id) end
		if anchor:IsA("BasePart") or anchor:IsA("Model") then
			local ok, pos = pcall(function() return anchor:IsA("Model") and anchor:GetPivot().Position or anchor.Position end)
			if ok then return MatchState.ScopeOf(pos) end
		end
	end
	return nil
end

-- who sees a match's effects: its players and spectators. nil = the lobby / Training: everyone not in a lobby duel.
-- (In the match place there is no LobbyDuels folder and nobody has DuelMatch, so this is every player, as before.)
function MatchState.Audience(matchId: string?): { Player }
	local out = {}
	for _, p in Players:GetPlayers() do
		if MatchState.MatchId(p) == matchId then table.insert(out, p) end
	end
	return out
end

-- RemoteEvent:FireAllClients, narrowed to the audience of anchor's match (lobby duels phase 2: no combat traffic or
-- effects cross between the lobby and an arena, or between two arenas)
function MatchState.FireScoped(remote: RemoteEvent, anchor, ...)
	if not lobbyFolder() then remote:FireAllClients(...) return end
	for _, p in MatchState.Audience(MatchState.ScopeOf(anchor)) do remote:FireClient(p, ...) end
end

return MatchState
]=]
SOURCES.MatchCore = [=[-- ServerScriptService/Shared/MatchCore (ModuleScript): the round rules of a team match, shared by the lobby's pad duels
-- (one MatchCore run per match, LobbyDuelManager) and the match place's RoundManager (one per server; [MATCH] 2026-10-16,
-- notes/match_place_flow.md: it also uses runPreMatch / castVote / ownedItems / ownedKit below).
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
--   ctx.aborted          bool      set by an admin end: the closing announce says "MATCH ENDED"
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
		if left then
			winner, forfeit = w, true
			-- ctx.aborted (an admin ended the match): no "opponents left" line
			if not ctx.aborted then ctx.announce("OPPONENTS LEFT", "TEAM " .. w .. " WINS") end
			break
		end
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
		if forfeit then
			if not ctx.aborted then ctx.announce("OPPONENTS LEFT", "TEAM " .. winner .. " WINS") end
			break
		end
		if roundNumber >= (C.MaxRounds or 9) then -- safety: endless draws
			local a, b = score(ctx, "A"), score(ctx, "B")
			winner = a > b and "A" or b > a and "B" or nil
			break
		end
	end
	ctx.over = true
	MatchCore.setState(ctx, "MatchEnd", C.ResultsTime or 12)
	if ctx.aborted then
		ctx.announce("MATCH ENDED", "Ended by an admin - no rewards")
	else
		ctx.announce(winner and ("TEAM " .. winner .. " WINS THE MATCH") or "MATCH DRAWN", forfeit and "Forfeit" or "")
	end
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

-- what a player may pick: every catalogue item that is a Default or owned (data.Owned[id] == true), sorted ids
function MatchCore.ownedItems(items, data): { string }
	local owned = {}
	for id, it in items do
		if it.Default == true or (data and type(data.Owned) == "table" and data.Owned[id] == true) then table.insert(owned, id) end
	end
	table.sort(owned)
	return owned
end
-- the kit a player starts the Loadout phase with: wanted[slot] where it is a valid pick (owned + right slot), else the
-- slot's default (defaults = { Weapon = "Pistol", Melee = "Fists", Gadget = "Smoke" })
function MatchCore.ownedKit(items, ownsFn, wanted, defaults)
	local kit = {}
	for _, slot in { "Weapon", "Melee", "Gadget" } do
		local id = type(wanted) == "table" and wanted[slot] or nil
		kit[slot] = MatchCore.validPick(items, ownsFn, slot, id) and id or defaults[slot]
	end
	return kit
end

-- // Pre-match phases (Loading -> MapVote -> Loadout), used by the match place's RoundManager --------------------------------
-- (LobbyDuelManager runs its own copy of these steps, with the arena loading and the Loaded gate in between.)
-- MapList JSON entries for the UI ({id, name, image}); the UI adds "Random" itself
function MatchCore.mapList(maps)
	local list = {}
	for _, m in maps do table.insert(list, { id = m.Id, name = m.DisplayName or m.Id, image = m.Image or "" }) end
	return list
end
-- a vote: mapId must be one of maps or "Random"; one vote per user id, changeable. Publishes MapVotes {mapId: [userId]}.
function MatchCore.castVote(ctx, userId: number, mapId: any, maps): boolean
	if ctx.state:GetAttribute("MatchState") ~= "MapVote" then return false end
	local ok = mapId == "Random"
	for _, m in maps do if m.Id == mapId then ok = true end end
	if not ok then return false end
	ctx.votes = ctx.votes or {}
	ctx.votes[userId] = mapId
	ctx.lastVote = os.clock()
	local out = {}
	for uid, id in ctx.votes do out[id] = out[id] or {}; table.insert(out[id], uid) end
	ctx.state:SetAttribute("MapVotes", game:GetService("HttpService"):JSONEncode(out))
	return true
end
-- wait up to seconds; true as soon as done() is true, false on timeout or when a whole team is gone
function MatchCore.waitPhase(ctx, seconds: number, done)
	local t0 = os.clock()
	while os.clock() - t0 < seconds do
		if done and done() then return true end
		if MatchCore.forfeitSide(ctx) then return false end
		task.wait(0.1)
	end
	return false
end
-- Loading (C.LoadingTime) -> MapVote (C.MapVoteTime; skipped when C.DuelMapVote == false or no map is eligible)
-- -> MapChosen -> Loadout (C.LoadoutTime, ends early when every present player member is Ready).
-- opts.maps = the eligible maps (registry entries); opts.voters() -> number of members who can vote;
-- opts.onMapChosen(id) is called before the Loadout phase starts. Returns the chosen map id (nil = no eligible map).
function MatchCore.runPreMatch(ctx, opts)
	local C, s = ctx.config, ctx.state
	local HttpService = game:GetService("HttpService")
	MatchCore.setState(ctx, "Loading", C.LoadingTime or 3)
	MatchCore.waitPhase(ctx, C.LoadingTime or 3)
	local maps = opts.maps or {}
	s:SetAttribute("MapList", HttpService:JSONEncode(MatchCore.mapList(maps)))
	s:SetAttribute("MapVotes", "{}")
	ctx.votes, ctx.lastVote = ctx.votes or {}, 0
	if C.DuelMapVote ~= false and #maps > 0 and not MatchCore.forfeitSide(ctx) then
		MatchCore.setState(ctx, "MapVote", C.MapVoteTime or 10)
		local voters = opts.voters and opts.voters() or 0
		MatchCore.waitPhase(ctx, C.MapVoteTime or 10, function()
			local n = 0
			for _ in ctx.votes do n += 1 end
			return voters > 0 and n >= voters and os.clock() - ctx.lastVote > 1.5
		end)
	end
	local chosen = MatchCore.resolveVote(ctx.votes, maps)
	s:SetAttribute("MapChosen", chosen)
	if MatchCore.forfeitSide(ctx) then return chosen end
	-- the winning tile flashes
	task.wait(1.5)
	if opts.onMapChosen then opts.onMapChosen(chosen) end
	MatchCore.setState(ctx, "Loadout", C.LoadoutTime or 15)
	MatchCore.waitPhase(ctx, C.LoadoutTime or 15, function()
		for _, list in ctx.teams do
			for _, m in list do
				if m.player and ctx.isPresent(m) and not m.ready then return false end
			end
		end
		return true
	end)
	return chosen
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
SOURCES.RoundManager = [=[-- ServerScriptService/ServerScripts/[Server] Init/GameManager/Managers/RoundManager (ModuleScript)
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
]=]
SOURCES.LobbyConfig = [=[-- ReplicatedStorage/Modules/Shared/Config/LobbyConfig (ModuleScript) - MATCH PLACE PORT (subset)
-- [MATCH] 2026-10-16 (notes/match_place_flow.md): the parts of the lobby's LobbyConfig the match place needs, copied verbatim:
--   Items / Slots / DefaultLoadout / Rarities / Images (OwnedItems, the Loadout pick screen, Pick validation, admin give/take),
--   QuestStats / Quests (admin ;missions), the level curves + AccountLevel / ItemLevel / XPForLevel (the Level attribute, admin),
--   StartingRating, the place ids. Shop, bundles, Robux, queues and the armory camera stay lobby-only.
-- KEEP IN SYNC with the lobby's ReplicatedStorage.Modules.Shared.Config.LobbyConfig: an item or curve change there must be
-- copied here (scripts/match/LobbyConfig.lua, then python tools/match_place_build.py --run).

local LobbyConfig = {}

LobbyConfig.MatchPlaceId = 81861384114744 -- "tutorial spot / matchmaking test" place
LobbyConfig.TutorialPlaceId = 81861384114744
LobbyConfig.LobbyPlaceId = 126491009194165
LobbyConfig.StartingCredits = 500
LobbyConfig.StartingRating = 1000

-------------------------------------------------------------------------------
-- Items (the kit). Default = everyone owns it from the start.
-------------------------------------------------------------------------------
LobbyConfig.Slots = { "Weapon", "Gadget", "Melee" }
LobbyConfig.SlotNames = { Weapon = "WEAPON", Gadget = "GADGET", Melee = "MELEE" }
LobbyConfig.DefaultLoadout = { Weapon = "Pistol", Gadget = "Smoke", Melee = "Fists" }

LobbyConfig.Rarities = {
	Standard = { Order = 1, Color = Color3.fromRGB(170, 176, 184) },
	Rare = { Order = 2, Color = Color3.fromRGB(70, 160, 255) },
	Epic = { Order = 3, Color = Color3.fromRGB(190, 100, 255) },
	Legendary = { Order = 4, Color = Color3.fromRGB(214, 58, 70) }, -- crimson (pass 34: no amber),
}

LobbyConfig.Items = {
	-- guns (WeaponConfig ids). Every gun: 150 HP to chew through, damage falls off with range.
	Pistol = { Name = "Pistol", Slot = "Weapon", Price = 0, Default = true, Rarity = "Standard",
		Desc = "12-round semi-auto. Honest at every range." },
	SilencedPistol = { Name = "Suppressed", Slot = "Weapon", Price = 1500, Rarity = "Rare",
		Desc = "Hits harder than the pistol and barely makes a sound. Fades past 30m." },
	Revolver = { Name = "Revolver", Slot = "Weapon", Price = 2500, Rarity = "Epic",
		Desc = "One headshot up close. Loses its bite fast past 12m." },
	MiniUzi = { Name = "Mini Uzi", Slot = "Weapon", Price = 2000, Rarity = "Rare",
		Desc = "Hold to spray. Shreds up close, light on your feet, weak at range." },
	AutoRifle = { Name = "Automatic Rifle", Slot = "Weapon", Price = 3000, Rarity = "Epic",
		Desc = "Full-auto all-rounder. Heavier: slower to move and reload." },
	SemiAuto = { Name = "Semi-Auto", Slot = "Weapon", Price = 3000, Rarity = "Epic",
		Desc = "Hard-hitting marksman rifle that holds its damage at long range." },
	Sniper = { Name = "Sniper", Slot = "Weapon", Price = 4000, Rarity = "Legendary",
		Desc = "Bolt-action. A headshot kills at any range. Slow, heavy, punishing to miss." },
	-- gadgets (GadgetConfig ids)
	Smoke = { Name = "Smoke", Slot = "Gadget", Price = 0, Default = true, Rarity = "Standard",
		Desc = "Blocks sight lines. Cross open ground safely." },
	Flash = { Name = "Flashbang", Slot = "Gadget", Price = 1200, Rarity = "Rare",
		Desc = "Blinds anyone looking at it." },
	Frag = { Name = "Frag", Slot = "Gadget", Price = 2000, Rarity = "Epic",
		Desc = "Flush enemies out of cover." },
	-- melee (MeleeConfig ids)
	Fists = { Name = "Fists", Slot = "Melee", Price = 0, Default = true, Rarity = "Standard",
		Desc = "Fast jabs. Lethal from behind." },
	Knife = { Name = "Knife", Slot = "Melee", Price = 800, Rarity = "Rare",
		Desc = "More damage and reach than fists." },
}

-- Card art. Paste "rbxassetid://..." per item; "" = placeholder card with the name.
LobbyConfig.Images = {}

-------------------------------------------------------------------------------
-- Quests (stats the match place increments; the lobby hands them out and pays them)
-------------------------------------------------------------------------------
LobbyConfig.QuestStats = { "MatchesPlayed", "Wins", "Kills", "Headshots", "CoverKills", "MeleeKills", "GadgetsThrown" }

LobbyConfig.Quests = {
	Daily = {
		Count = 3,
		Pool = {
			{ Id = "D_Play", Text = "Play 3 matches", Stat = "MatchesPlayed", Goal = 3, Reward = 150 },
			{ Id = "D_Win", Text = "Win 2 matches", Stat = "Wins", Goal = 2, Reward = 200 },
			{ Id = "D_Kills", Text = "Get 8 eliminations", Stat = "Kills", Goal = 8, Reward = 175 },
			{ Id = "D_Heads", Text = "Land 5 headshot kills", Stat = "Headshots", Goal = 5, Reward = 175 },
			{ Id = "D_Cover", Text = "Get 3 eliminations from cover", Stat = "CoverKills", Goal = 3, Reward = 200 },
			{ Id = "D_Melee", Text = "Get a melee elimination", Stat = "MeleeKills", Goal = 1, Reward = 175 },
			{ Id = "D_Gadget", Text = "Throw 6 gadgets", Stat = "GadgetsThrown", Goal = 6, Reward = 125 },
		},
	},
	Weekly = {
		Count = 3,
		Pool = {
			{ Id = "W_Win", Text = "Win 10 matches", Stat = "Wins", Goal = 10, Reward = 1000 },
			{ Id = "W_Play", Text = "Play 20 matches", Stat = "MatchesPlayed", Goal = 20, Reward = 750 },
			{ Id = "W_Kills", Text = "Get 50 eliminations", Stat = "Kills", Goal = 50, Reward = 900 },
			{ Id = "W_Heads", Text = "Land 25 headshot kills", Stat = "Headshots", Goal = 25, Reward = 900 },
			{ Id = "W_Cover", Text = "Get 15 eliminations from cover", Stat = "CoverKills", Goal = 15, Reward = 1000 },
		},
	},
}

-------------------------------------------------------------------------------
-- Levels
-------------------------------------------------------------------------------
LobbyConfig.ItemLevels = { First = 250, Step = 100, Max = 50 }
LobbyConfig.AccountLevels = { First = 400, Step = 150, Max = 999 }
LobbyConfig.RankedLevel = 50 -- account level that unlocks ranked queues

local function levelFrom(xp: number, curve): (number, number, number)
	xp = math.max(0, math.floor(tonumber(xp) or 0))
	local level, need = 1, curve.First
	while level < curve.Max and xp >= need do
		xp -= need
		level += 1
		need += curve.Step
	end
	if level >= curve.Max then return curve.Max, need, need end
	return level, xp, need
end

function LobbyConfig.ItemLevel(xp: number?): (number, number, number)
	return levelFrom(xp or 0, LobbyConfig.ItemLevels)
end

function LobbyConfig.AccountLevel(xp: number?): (number, number, number)
	return levelFrom(xp or 0, LobbyConfig.AccountLevels)
end

-- total XP needed to reach an account level
function LobbyConfig.XPForLevel(level: number): number
	local curve, xp = LobbyConfig.AccountLevels, 0
	for l = 1, math.min(level, curve.Max) - 1 do xp += curve.First + (l - 1) * curve.Step end
	return xp
end

return LobbyConfig
]=]
SOURCES.MapInfo_Warehouse = [=[-- MapInfo: map registry entry for the match place's own Warehouse (ReplicatedStorage.DuelMaps.Warehouse.MapInfo).
-- [MATCH] 2026-10-16 (notes/match_place_flow.md): a copy of the lobby's generated MapInfo (fix/duel_split_map.lua). In the match
-- place the map is not split: Workspace.Warehouse (WorkspaceName) is the map, at its native position, with MatchSpawns as spawns.
-- The folder's Modes attribute ("1v1") overrides Modes here, as in the lobby (MapRegistry).
return {
	Id = "Warehouse",
	DisplayName = "Warehouse",
	Image = "",
	Modes = { "1v1" },
	Size = Vector3.new(84.000, 22.000, 120.400),
	SpawnSpacing = 4,
	KillDepth = 30,
	WorkspaceName = "Warehouse",
	Dynamic = { "Interactive" },
	SourceOrigin = Vector3.new(-84.200, 0.400, 7.515),
}
]=]
SOURCES.Admin_Config = [=[-- ServerScriptService/AdminFramework/Config (ModuleScript): who is an admin and how the framework behaves.
-- Shared by the lobby and the match place (notes/admin_framework.md). Server only: never put this in ReplicatedStorage.
--
-- Levels (highest wins): Owner > Admin > Tester > None. A player's level is the best of:
--   * Users[userId] below (explicit list);
--   * their rank in the owning group (GroupRanks: rank >= the number gives that level);
--   * Studio: always StudioLevel (Owner), unless a Studio-only simulated level is set (`;simlevel`, AdminBindable "simlevel").
-- Every check runs on the server; the client only sends text.
local Config = {}

Config.Prefix = ";"            -- chat prefix for every command (";setlevel me 20")
Config.LegacyPrefix = "/"      -- the old AdminCommands names keep working with "/" (/scissors, /give, /wipeweapons, /unlockall, /admin)

-- the group that owns Tacticals: "gunsy funsy" (owner ocxa). In a published game game.CreatorId is used when the
-- creator is a group; this id is the fallback for local files (CreatorId 0) and Studio.
Config.GroupId = 102028987
Config.GroupRanks = {
	Owner = 255,  -- group owner
	Admin = 254,  -- the group's "Admin" role
	-- Tester = 200, -- uncomment and create a Tester role at this rank to grant Tester by group rank
}

-- explicit list: [userId] = "Owner" | "Admin" | "Tester"
Config.Users = {
	[281164661] = "Owner", -- Edward: username ocxa, display name "debits"; owner of gunsy funsy
	-- NOT 63563472: that is a different account whose username is "debits" (checked 2026-10-16)
}

Config.StudioLevel = "Owner"
Config.ConfirmWindow = 10      -- seconds to repeat a destructive command with "confirm"
Config.RateLimit = 0.25        -- seconds between commands per player
Config.MaxTextLength = 200
Config.GroupCacheTime = 120    -- seconds a group rank lookup is trusted

-- audit log: last AuditMemory entries in memory; a capped copy in a DataStore (skipped quietly where DataStores fail, e.g. Studio)
Config.AuditMemory = 200
Config.AuditStore = "AdminAudit_v1"
Config.AuditStoreCap = 100
Config.AuditFlushEvery = 30

-- level curve used when the place has no LobbyConfig (the match place): must match LobbyConfig.AccountLevels
Config.AccountLevels = { First = 400, Step = 150, Max = 999 }

return Config
]=]
SOURCES.Admin_Permissions = [=[-- ServerScriptService/AdminFramework/Permissions (ModuleScript): admin levels, decided on the server only.
--   Permissions.LevelOf(player) -> number, why     (0 None, 1 Tester, 2 Admin, 3 Owner; console = Owner)
--   Permissions.Name(n) / Permissions.Value("Admin")
--   Permissions.SetSimulated(userId, "None"|"Tester"|"Admin"|"Owner"|nil)   Studio only: pretend to be that level
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Config = require(script.Parent.Config)

local IS_STUDIO = RunService:IsStudio()
local Permissions = {}

local VALUES = { None = 0, Tester = 1, Admin = 2, Owner = 3 }
local NAMES = { [0] = "None", [1] = "Tester", [2] = "Admin", [3] = "Owner" }
Permissions.Values = VALUES
Permissions.Names = NAMES

function Permissions.Value(name: string?): number
	return VALUES[name or ""] or 0
end
function Permissions.Name(n: number): string
	return NAMES[n] or "None"
end
function Permissions.Parse(token: string?): string?
	if not token then return nil end
	local t = string.lower(token)
	for name in VALUES do if string.lower(name) == t then return name end end
	return nil
end

local function groupId(): number
	if game.CreatorType == Enum.CreatorType.Group and game.CreatorId ~= 0 then return game.CreatorId end
	return Config.GroupId or 0
end
Permissions.GroupId = groupId

local rankCache = {} -- [userId] = { rank, t }
local function groupRank(player: Player): number
	local gid = groupId()
	if gid == 0 or player.UserId <= 0 then return 0 end
	local c = rankCache[player.UserId]
	if c and os.clock() - c.t < (Config.GroupCacheTime or 120) then return c.rank end
	local ok, rank = pcall(player.GetRankInGroup, player, gid)
	rank = ok and tonumber(rank) or (c and c.rank) or 0
	rankCache[player.UserId] = { rank = rank, t = os.clock() }
	return rank
end
Players.PlayerRemoving:Connect(function(p) rankCache[p.UserId] = nil end)

-- the level a player really has (ignores Studio)
local function realLevel(player: Player): (number, string)
	local best, why = 0, "not on the admin list"
	local listed = Config.Users[player.UserId]
	if listed and VALUES[listed] then best, why = VALUES[listed], "admin list" end
	local rank = groupRank(player)
	for name, need in Config.GroupRanks or {} do
		if rank >= need and VALUES[name] > best then best, why = VALUES[name], ("group rank %d"):format(rank) end
	end
	return best, why
end

function Permissions.LevelOf(player: any): (number, string)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then return VALUES.Owner, "server console" end
	if IS_STUDIO then
		local sim = ServerStorage:GetAttribute("AdminSim_" .. player.UserId)
		if type(sim) == "string" and VALUES[sim] then return VALUES[sim], "Studio simulated level" end
		return VALUES[Config.StudioLevel] or VALUES.Owner, "Studio test"
	end
	return realLevel(player)
end
Permissions.RealLevel = realLevel

-- Studio only: pretend `userId` has `levelName` (nil = back to normal). The attribute lives in ServerStorage (server only).
function Permissions.SetSimulated(userId: number, levelName: string?): (boolean, string?)
	if not IS_STUDIO then return false, "simulated levels exist only in Studio" end
	if levelName ~= nil and not VALUES[levelName] then return false, "unknown level " .. tostring(levelName) end
	ServerStorage:SetAttribute("AdminSim_" .. userId, levelName)
	return true
end

return Permissions
]=]
SOURCES.Admin_Args = [=[-- ServerScriptService/AdminFramework/Args (ModuleScript): typed argument parsing for admin commands.
-- A command declares args = { { name = "player", type = "players" }, { name = "n", type = "integer", min = 1, optional = true, default = 1 } }.
-- Types:
--   players   one or more players: me, all, others, @userid, a name / display-name prefix, or a comma list ("me,bob")
--   player    exactly one player (same selectors)
--   number, integer (min / max), boolean (on/off, true/false, yes/no, 1/0), string, rest (the rest of the line)
--   choice    one of `choices` (case-insensitive)
--   item      an item id or name from the catalogue (LobbyConfig.Items), validated
--   stat      a stat setstat can change (DataAdapter.StatList), validated
--   level     None / Tester / Admin / Owner
-- Errors are plain sentences the caller sees in chat.
local Players = game:GetService("Players")
local DataAdapter = require(script.Parent.DataAdapter)
local Permissions = require(script.Parent.Permissions)

local Args = {}

-- split on spaces, keep "quoted strings" together
function Args.Tokenize(text: string): { string }
	local out = {}
	local i, n = 1, #text
	while i <= n do
		local c = string.sub(text, i, i)
		if c == " " or c == "\t" then
			i += 1
		elseif c == '"' then
			local j = string.find(text, '"', i + 1, true) or (n + 1)
			table.insert(out, string.sub(text, i + 1, j - 1))
			i = j + 1
		else
			local j = string.find(text, "[ \t]", i) or (n + 1)
			table.insert(out, string.sub(text, i, j - 1))
			i = j
		end
	end
	return out
end

local function names(list)
	local t = {}
	for _, p in list do table.insert(t, p.Name) end
	return table.concat(t, ", ")
end

local function onePart(part: string, ctx): ({ Player }?, string?)
	local t = string.lower(part)
	local caller = ctx.caller
	if t == "me" then
		if not caller then return nil, "\"me\" needs a player (the server console has none)" end
		return { caller }
	elseif t == "all" or t == "everyone" then
		return Players:GetPlayers()
	elseif t == "others" then
		local list = {}
		for _, p in Players:GetPlayers() do if p ~= caller then table.insert(list, p) end end
		if #list == 0 then return nil, "\"others\" matches nobody: you're the only player here" end
		return list
	elseif string.sub(t, 1, 1) == "@" then
		local id = tonumber(string.sub(t, 2))
		if not id then return nil, ("\"%s\" isn't a user id (use @12345)"):format(part) end
		local p = Players:GetPlayerByUserId(id)
		if not p then return nil, ("no player with user id %d in this server"):format(id) end
		return { p }
	end
	local exact, partial = {}, {}
	for _, p in Players:GetPlayers() do
		local n, d = string.lower(p.Name), string.lower(p.DisplayName)
		if n == t or d == t then table.insert(exact, p)
		elseif string.sub(n, 1, #t) == t or string.sub(d, 1, #t) == t then table.insert(partial, p) end
	end
	local list = #exact > 0 and exact or partial
	if #list == 0 then return nil, ("no player here matches \"%s\""):format(part) end
	if #list > 1 then return nil, ("\"%s\" matches %s: type more of the name"):format(part, names(list)) end
	return list
end

-- returns players, multi (true when the selector can mean several: all / others / a list)
function Args.Players(token: string, ctx): ({ Player }?, string?, boolean?)
	local out, seen, multi = {}, {}, false
	for part in string.gmatch(token, "[^,]+") do
		local t = string.lower(part)
		if t == "all" or t == "everyone" or t == "others" then multi = true end
		local list, err = onePart(part, ctx)
		if not list then return nil, err end
		for _, p in list do if not seen[p] then seen[p] = true; table.insert(out, p) end end
	end
	if #out == 0 then return nil, "nobody matches \"" .. token .. "\"" end
	if #out > 1 then multi = true end
	return out, nil, multi
end

local TRUE = { on = true, ["true"] = true, yes = true, ["1"] = true, enable = true, enabled = true }
local FALSE = { off = true, ["false"] = true, no = true, ["0"] = true, disable = true, disabled = true }

Args.Types = {}
Args.Types.players = function(tok, spec, ctx)
	local list, err, multi = Args.Players(tok, ctx)
	if not list then return nil, err end
	ctx.multiTarget = ctx.multiTarget or multi
	return list
end
Args.Types.player = function(tok, spec, ctx)
	local list, err = Args.Players(tok, ctx)
	if not list then return nil, err end
	if #list ~= 1 then return nil, ("%s needs exactly one player, \"%s\" is %d"):format(spec.name, tok, #list) end
	return list[1]
end
Args.Types.number = function(tok, spec)
	local n = tonumber(tok)
	if not n or n ~= n or n == math.huge or n == -math.huge then return nil, ("%s must be a number, not \"%s\""):format(spec.name, tok) end
	if spec.min and n < spec.min then return nil, ("%s must be at least %s"):format(spec.name, spec.min) end
	if spec.max and n > spec.max then return nil, ("%s must be at most %s"):format(spec.name, spec.max) end
	return n
end
Args.Types.integer = function(tok, spec)
	local n, err = Args.Types.number(tok, spec)
	if not n then return nil, err end
	if n ~= math.floor(n) then return nil, ("%s must be a whole number, not \"%s\""):format(spec.name, tok) end
	return n
end
Args.Types.boolean = function(tok, spec)
	local t = string.lower(tok)
	if TRUE[t] then return true end
	if FALSE[t] then return false end
	return nil, ("%s must be on or off, not \"%s\""):format(spec.name, tok)
end
Args.Types.string = function(tok) return tok end
Args.Types.rest = function(tok) return tok end -- Parse already joined the rest of the line
Args.Types.choice = function(tok, spec)
	local t = string.lower(tok)
	for _, c in spec.choices do if string.lower(c) == t then return c end end
	return nil, ("%s must be one of %s, not \"%s\""):format(spec.name, table.concat(spec.choices, " | "), tok)
end
Args.Types.item = function(tok)
	local id, err = DataAdapter.FindItem(tok)
	if not id then return nil, err end
	return id
end
Args.Types.stat = function(tok)
	local s = DataAdapter.FindStat(tok)
	if not s then return nil, ("no stat \"%s\". Stats: %s"):format(tok, table.concat(DataAdapter.StatList(), ", ")) end
	return s
end
Args.Types.level = function(tok, spec)
	local name = Permissions.Parse(tok)
	if not name then return nil, ("%s must be None, Tester, Admin or Owner"):format(spec.name) end
	return name
end

function Args.Usage(def): string
	local bits = { (def.prefix or ";") .. def.name }
	for _, a in def.args or {} do
		local label = a.name
		if a.type == "choice" then label = table.concat(a.choices, "|") end
		table.insert(bits, a.optional and ("[" .. label .. "]") or ("<" .. label .. ">"))
	end
	return table.concat(bits, " ")
end

-- tokens (without the command name) -> values (by name and by index) or nil, error
function Args.Parse(def, tokens: { string }, ctx)
	local values, specs = {}, def.args or {}
	local i = 1
	for idx, spec in specs do
		local tok = tokens[i]
		if spec.type == "rest" then
			if i <= #tokens then
				tok = table.concat(tokens, " ", i)
				i = #tokens + 1
			end
		else
			i += 1
		end
		local v
		if (tok == nil or tok == "") and spec.defaultToken then tok = spec.defaultToken end -- e.g. "me"
		if tok == nil or tok == "" then
			if not spec.optional then return nil, ("missing %s. Usage: %s"):format(spec.name, Args.Usage(def)) end
			v = spec.default
			if type(v) == "function" then v = v(ctx) end
		else
			local parser = Args.Types[spec.type]
			if not parser then return nil, "bad arg type " .. tostring(spec.type) end
			local err
			v, err = parser(tok, spec, ctx)
			if v == nil then return nil, err .. ". Usage: " .. Args.Usage(def) end
		end
		values[spec.name] = v
		values[idx] = v
	end
	if i <= #tokens then
		return nil, ("too many arguments (\"%s\"). Usage: %s"):format(table.concat(tokens, " ", i), Args.Usage(def))
	end
	return values
end

return Args
]=]
SOURCES.Admin_DataAdapter = [=[-- ServerScriptService/AdminFramework/DataAdapter (ModuleScript): the only way admin commands touch saved data.
-- Lobby: every write goes through Data.PlayerStore (Replica:SetValue -> the client's copy updates at once, the HUD listens
-- with ListenToRaw, and ProfileService saves it). Match place (no PlayerStore / LobbyConfig): the same writes go straight to
-- DataManager.DataReplicas[player]:SetValue, the level curve comes from Config.AccountLevels and items are unavailable.
-- Never pokes attributes as the source of truth; attributes (Level, Wins, Kit*) are only refreshed after a write.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Config = require(script.Parent.Config)

local DA = {}

local function try(f)
	local ok, v = pcall(f)
	return ok and v or nil
end
local dataFolder = ServerScriptService:FindFirstChild("Data")
local PlayerStore = dataFolder and dataFolder:FindFirstChild("PlayerStore") and try(function() return require(dataFolder.PlayerStore) end)
local DataManager = dataFolder and dataFolder:FindFirstChild("DataManager") and try(function() return require(dataFolder.DataManager) end)
local Template = DataManager and dataFolder.DataManager:FindFirstChild("Template") and try(function() return require(dataFolder.DataManager.Template) end)
local cfgFolder = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("Shared")
	and ReplicatedStorage.Modules.Shared:FindFirstChild("Config")
local LobbyConfig = cfgFolder and cfgFolder:FindFirstChild("LobbyConfig") and try(function() return require(cfgFolder.LobbyConfig) end)
local MatchConfig = cfgFolder and cfgFolder:FindFirstChild("MatchConfig") and try(function() return require(cfgFolder.MatchConfig) end)

DA.HasPlayerStore = PlayerStore ~= nil
DA.HasCatalogue = LobbyConfig ~= nil and type(LobbyConfig.Items) == "table"
DA.StoreKey = DataManager and DataManager.key or "?"

-- the lobby template's defaults (used when the place's Template lacks a key, e.g. the match place's empty template)
local DEFAULTS = {
	Credits = 500,
	Owned = {},
	Loadout = { Weapon = "Pistol", Gadget = "Smoke", Melee = "Fists" },
	Stats = { MatchesPlayed = 0, Wins = 0, Kills = 0, Headshots = 0, CoverKills = 0, MeleeKills = 0, GadgetsThrown = 0 },
	Quests = { Daily = { Key = "", List = {} }, Weekly = { Key = "", List = {} } },
	XP = 0, Favorites = {}, ItemXP = {}, Ranked = {}, Settings = {}, RedeemedCodes = {}, DuelPairs = {},
}

local function deepCopy(v)
	if type(v) ~= "table" then return v end
	local t = {}
	for k, x in v do t[k] = deepCopy(x) end
	return t
end
DA.Copy = deepCopy

-- a fresh copy of the default value of a top-level profile key
function DA.Default(key: string)
	if Template and Template[key] ~= nil then return deepCopy(Template[key]) end
	return deepCopy(DEFAULTS[key])
end

function DA.Get(player: Player)
	if PlayerStore then return PlayerStore.Get(player) end
	if DataManager then return DataManager:Get(player), DataManager.DataReplicas and DataManager.DataReplicas[player] end
	return nil
end

function DA.Ready(player: Player): boolean
	local data, replica = DA.Get(player)
	return data ~= nil and replica ~= nil
end

-- path = { "Stats", "Wins" }; parents that don't exist yet are created as whole tables (Replica can't set into nil)
function DA.Set(player: Player, path: { any }, value: any): boolean
	local data, replica = DA.Get(player)
	if not data or not replica then return false end
	local t = data
	for i = 1, #path - 1 do
		local nxt = t[path[i]]
		if type(nxt) ~= "table" then
			-- build the missing branch and write it in one go
			local branch, cur = {}, nil
			cur = branch
			for j = i + 1, #path - 1 do cur[path[j]] = {}; cur = cur[path[j]] end
			cur[path[#path]] = value
			local sub = table.move(path, 1, i, 1, {})
			if PlayerStore then return PlayerStore.Set(player, sub, branch) end
			replica:SetValue(sub, branch)
			return true
		end
		t = nxt
	end
	if PlayerStore then return PlayerStore.Set(player, path, value) end
	replica:SetValue(path, value)
	return true
end

function DA.Read(player: Player, path: { any })
	local t = DA.Get(player)
	for _, k in path do
		if type(t) ~= "table" then return nil end
		t = t[k]
	end
	return t
end

function DA.Increment(player: Player, path: { any }, amount: number): number?
	local cur = tonumber(DA.Read(player, path)) or 0
	local new = cur + amount
	if not DA.Set(player, path, new) then return nil end
	return new
end

-------------------------------------------------------------------------------
-- Levels (account XP curve)
-------------------------------------------------------------------------------
local function curve()
	return (LobbyConfig and LobbyConfig.AccountLevels) or Config.AccountLevels
end
function DA.MaxLevel(): number return curve().Max end
function DA.LevelOf(xp: number?): (number, number, number)
	if LobbyConfig and LobbyConfig.AccountLevel then return LobbyConfig.AccountLevel(xp or 0) end
	local c = curve()
	xp = math.max(0, math.floor(tonumber(xp) or 0))
	local level, need = 1, c.First
	while level < c.Max and xp >= need do xp -= need; level += 1; need = c.First + (level - 1) * c.Step end
	if level >= c.Max then return c.Max, need, need end
	return level, xp, need
end
function DA.XPForLevel(level: number): number
	if LobbyConfig and LobbyConfig.XPForLevel then return LobbyConfig.XPForLevel(level) end
	local c, xp = curve(), 0
	for l = 1, math.min(level, c.Max) - 1 do xp += c.First + (l - 1) * c.Step end
	return xp
end

-------------------------------------------------------------------------------
-- Items (LobbyConfig.Items; the match place has none)
-------------------------------------------------------------------------------
function DA.Items()
	return DA.HasCatalogue and LobbyConfig.Items or {}
end
-- id, item  or nil, error. Accepts the id or the display name, any case, or an unambiguous prefix.
function DA.FindItem(token: string): (string?, any)
	if not DA.HasCatalogue then return nil, "this place has no item catalogue" end
	local t = string.lower(token)
	local hits = {}
	for id, item in LobbyConfig.Items do
		local a, b = string.lower(id), string.lower(item.Name or id)
		if a == t or b == t then return id, item end
		if string.sub(a, 1, #t) == t or string.sub(b, 1, #t) == t then table.insert(hits, id) end
	end
	if #hits == 1 then return hits[1], LobbyConfig.Items[hits[1]] end
	if #hits > 1 then table.sort(hits) return nil, ("\"%s\" matches %s"):format(token, table.concat(hits, ", ")) end
	local all = {}
	for id in LobbyConfig.Items do table.insert(all, id) end
	table.sort(all)
	return nil, ("no item \"%s\". Items: %s"):format(token, table.concat(all, ", "))
end

function DA.DefaultLoadout()
	local lo = {}
	for id, item in DA.Items() do if item.Default then lo[item.Slot] = id end end
	if next(lo) == nil then return DA.Default("Loadout") end
	return lo
end

function DA.Owns(player: Player, id: string): boolean
	local item = DA.Items()[id]
	if not item then return false end
	return item.Default == true or DA.Read(player, { "Owned", id }) == true
end

-------------------------------------------------------------------------------
-- Stats that setstat can change (discovered from the profile layout)
-------------------------------------------------------------------------------
DA.Modes = { "1v1", "2v2", "3v3" }
function DA.StatList(): { string }
	local list = {}
	local stats = DA.Default("Stats") or {}
	for k in stats do table.insert(list, k) end
	for _, k in (LobbyConfig and LobbyConfig.QuestStats or {}) do if not table.find(list, k) then table.insert(list, k) end end
	table.sort(list)
	for _, m in DA.Modes do
		table.insert(list, "Rating" .. m); table.insert(list, "RankedWins" .. m); table.insert(list, "RankedLosses" .. m)
	end
	table.insert(list, "XP"); table.insert(list, "Credits")
	return list
end
-- "wins" -> { path = {"Stats","Wins"}, name = "Wins" }; "rating1v1" -> ranked entry
function DA.FindStat(token: string)
	local t = string.lower(token)
	for _, name in DA.StatList() do
		if string.lower(name) == t then
			local mode = string.match(name, "(%dv%d)$")
			if mode then
				local field = string.match(name, "^Rating") and "Rating" or (string.match(name, "^RankedWins") and "Wins" or "Losses")
				return { name = name, ranked = mode, field = field }
			end
			if name == "XP" or name == "Credits" then return { name = name, path = { name } } end
			return { name = name, path = { "Stats", name } }
		end
	end
	return nil
end
function DA.StartingRating(): number
	return (LobbyConfig and LobbyConfig.StartingRating) or (MatchConfig and MatchConfig.StartingRating) or 1000
end
function DA.SetRanked(player: Player, mode: string, field: string, value: number): boolean
	local cur = DA.Read(player, { "Ranked", mode })
	local entry = type(cur) == "table" and deepCopy(cur) or { Rating = DA.StartingRating(), Wins = 0, Losses = 0 }
	entry[field] = value
	return DA.Set(player, { "Ranked", mode }, entry)
end

-------------------------------------------------------------------------------
-- After a write: refresh the derived attributes other scripts read (PublicStats does Level / Wins every 2 s anyway)
-------------------------------------------------------------------------------
function DA.Refresh(player: Player)
	local data = DA.Get(player)
	if not data then return end
	if PlayerStore and PlayerStore.ApplyLoadoutAttributes then pcall(PlayerStore.ApplyLoadoutAttributes, player) end
	player:SetAttribute("Level", (DA.LevelOf(data.XP or 0)))
	if type(data.Stats) == "table" then player:SetAttribute("Wins", data.Stats.Wins or 0) end
end

function DA.Lobby(name: string)
	return shared.Get and (function() local ok, m = pcall(shared.Get, name) return ok and m or nil end)() or nil
end

DA.LobbyConfig = LobbyConfig
DA.MatchConfig = MatchConfig
DA.Players = Players
return DA
]=]
SOURCES.Admin_Audit = [=[-- ServerScriptService/AdminFramework/Audit (ModuleScript): every command run (or refused) is logged.
--   Audit.Log(entry)   entry = { admin, adminId, level, command, args (text), targets (text), ok, result }
--   Audit.Recent(n)    newest first, from memory (this server)
-- Memory: the last Config.AuditMemory entries. DataStore: Config.AuditStore key "log" keeps the last AuditStoreCap entries
-- across servers, flushed every AuditFlushEvery seconds. If the DataStore can't be used (Studio without API access, outages)
-- the store is switched off for this server with one warning, and the memory log keeps working.
local DataStoreService = game:GetService("DataStoreService")
local Config = require(script.Parent.Config)

local Audit = {}
local memory = {}
local pending = {}
local storeState = "unused" -- unused | ok | off: <reason>
local store

function Audit.Log(e)
	e.time = os.time()
	e.place = game.PlaceId
	table.insert(memory, e)
	while #memory > (Config.AuditMemory or 200) do table.remove(memory, 1) end
	if not string.find(storeState, "^off") then table.insert(pending, e) end
	print(("[Admin] %s (%s) %s %s -> %s %s"):format(tostring(e.admin), tostring(e.level), tostring(e.command), tostring(e.args or ""),
		e.ok and "ok" or "refused", tostring(e.result or "")))
end

function Audit.Recent(n: number?)
	local out = {}
	for i = #memory, math.max(1, #memory - (n or 10) + 1), -1 do table.insert(out, memory[i]) end
	return out
end

function Audit.StoreState(): string return storeState end

local function flush()
	if #pending == 0 or string.find(storeState, "^off") then return end
	if not store then
		local ok, s = pcall(DataStoreService.GetDataStore, DataStoreService, Config.AuditStore)
		if not ok then storeState = "off: " .. tostring(s); warn("[Admin] audit DataStore off: " .. tostring(s)); pending = {} return end
		store = s
	end
	local batch = pending
	pending = {}
	local ok, err = pcall(store.UpdateAsync, store, "log", function(old)
		local list = type(old) == "table" and old or {}
		for _, e in batch do
			table.insert(list, { t = e.time, a = e.adminId, n = e.admin, l = e.level, c = e.command, x = e.args, g = e.targets,
				ok = e.ok, r = e.result and string.sub(tostring(e.result), 1, 120), p = e.place })
		end
		while #list > (Config.AuditStoreCap or 100) do table.remove(list, 1) end
		return list
	end)
	if ok then storeState = "ok" else storeState = "off: " .. tostring(err); warn("[Admin] audit DataStore off: " .. tostring(err)) end
end

task.spawn(function()
	while true do
		task.wait(Config.AuditFlushEvery or 30)
		flush()
	end
end)
game:BindToClose(function() pcall(flush) end)

return Audit
]=]
SOURCES.Admin_Core = [=[-- ServerScriptService/AdminFramework/Core (ModuleScript): command registry and dispatcher (notes/admin_framework.md).
--   Core.LoadCommands(folder)        require every ModuleScript in Commands/ (each returns a list of command defs)
--   Core.Run(caller, text, source)   -> { ok, lines = {...}, command }   caller = Player, or nil for the server console
--   Core.Visible(level)              -> command defs this level may run (help / admin panel)
-- A command def:
--   { name = "setlevel", aliases = { "level" }, group = "Data", level = "Tester", description = "...",
--     args = { { name = "player", type = "players", defaultToken = "me" }, { name = "level", type = "integer", min = 1 } },
--     destructive = true?,        -- needs "<same command> confirm" within Config.ConfirmWindow s; on several players Owner only
--     studioOnly = true?,         -- refused outside Studio
--     place = "lobby" | "match"?,  -- only registered in that place (Core.Place: "lobby" when Workspace.LobbyMap exists)
--     run = function(ctx, args) ... return true, "message" | false, "error" end }
--   ctx = { caller, level (number), levelName, source, targets (players parsed), reply(line), Core, Data (DataAdapter) }
-- Rules applied here, never by a command: level check, Testers may only target themselves, nobody targets a player
-- with a higher level, the confirm token, the audit log.
local RunService = game:GetService("RunService")
local Config = require(script.Parent.Config)
local Permissions = require(script.Parent.Permissions)
local Args = require(script.Parent.Args)
local Audit = require(script.Parent.Audit)
local DataAdapter = require(script.Parent.DataAdapter)

local IS_STUDIO = RunService:IsStudio()
local Core = { Commands = {}, ByName = {}, Groups = {} }
-- which place this server is: the lobby (Workspace.LobbyMap) or the match / tutorial place (notes/match_place_flow.md)
Core.Place = workspace:FindFirstChild("LobbyMap") and "lobby" or "match"
Core.Permissions, Core.Args, Core.Audit, Core.Data, Core.Config = Permissions, Args, Audit, DataAdapter, Config

-- Core.Notify(player, text, kind) shows a line in that player's chat; set by the AdminCommands script (kind: true/false/"info"/"announce")
Core.Notify = function(_player, text) print("[Admin] " .. tostring(text)) end

local pendingConfirm = {} -- [callerKey .. "|" .. normalised text] = os.clock()

function Core.Register(def)
	assert(type(def.name) == "string" and type(def.run) == "function", "admin command needs name + run")
	def.name = string.lower(def.name)
	def.level = def.level or "Admin"
	assert(Permissions.Values[def.level], "bad level for " .. def.name)
	def.args = def.args or {}
	def.group = def.group or "Misc"
	-- a command for the other place is left out here (help, the panel and chat never see it)
	if def.place and def.place ~= Core.Place then return end
	if Core.ByName[def.name] then warn("[Admin] duplicate command " .. def.name .. " (later one wins)") end
	table.insert(Core.Commands, def)
	Core.ByName[def.name] = def
	for _, a in def.aliases or {} do
		a = string.lower(a)
		if Core.ByName[a] and Core.ByName[a] ~= def then warn("[Admin] alias " .. a .. " of " .. def.name .. " shadows another command") end
		Core.ByName[a] = def
	end
	Core.Groups[def.group] = Core.Groups[def.group] or {}
	table.insert(Core.Groups[def.group], def)
end

function Core.LoadCommands(folder: Instance)
	local mods = folder:GetChildren()
	table.sort(mods, function(a, b) return a.Name < b.Name end)
	for _, m in mods do
		if m:IsA("ModuleScript") then
			local ok, list = pcall(require, m)
			if not ok then warn("[Admin] command module " .. m.Name .. " failed: " .. tostring(list)) continue end
			for _, def in list do
				def.group = def.group or m.Name
				local okR, err = pcall(Core.Register, def)
				if not okR then warn("[Admin] " .. m.Name .. ": " .. tostring(err)) end
			end
		end
	end
end

function Core.Visible(level: number)
	local out = {}
	for _, def in Core.Commands do
		if Permissions.Value(def.level) <= level and (not def.studioOnly or IS_STUDIO) then table.insert(out, def) end
	end
	table.sort(out, function(a, b) if a.group ~= b.group then return a.group < b.group end return a.name < b.name end)
	return out
end

function Core.Usage(def) return Args.Usage(def) end

local function playerNames(list)
	local t = {}
	for _, p in list do table.insert(t, p.Name) end
	return table.concat(t, ",")
end

-- caller: Player or nil (console). opts.forceLevel (console bindable), opts.me (who "me" is for the console)
function Core.Run(caller: Player?, text: string, source: string?, opts)
	opts = opts or {}
	local lines = {}
	local result = { ok = false, lines = lines }
	if type(text) ~= "string" then table.insert(lines, "bad command text") return result end
	text = string.gsub(text, "^%s+", "")
	text = string.gsub(text, "%s+$", "")
	local prefix = string.sub(text, 1, 1)
	if prefix == Config.Prefix or prefix == Config.LegacyPrefix then text = string.sub(text, 2) end
	local tokens = Args.Tokenize(text)
	local name = string.lower(table.remove(tokens, 1) or "")
	local def = Core.ByName[name]
	local level, why = Permissions.LevelOf(caller)
	if opts.forceLevel then level, why = opts.forceLevel, "server console" end
	local levelName = Permissions.Name(level)
	local adminName = caller and caller.Name or "console"
	local function audit(ok, msg, targets)
		Audit.Log({ admin = adminName, adminId = caller and caller.UserId or 0, level = levelName, command = def and def.name or name,
			args = table.concat(tokens, " "), targets = targets, ok = ok, result = msg, source = source })
	end
	if name == "" then table.insert(lines, "type " .. Config.Prefix .. "cmds for the command list") return result end
	if not def then
		result.unknown = true
		table.insert(lines, ("unknown command \"%s\". Type %scmds for the list."):format(name, Config.Prefix))
		return result
	end
	result.command = def.name
	if level < Permissions.Value(def.level) then
		local msg = level == 0 and "You're not allowed to use admin commands." or
			("%s%s needs %s (you are %s)."):format(Config.Prefix, def.name, def.level, levelName)
		table.insert(lines, msg)
		audit(false, "denied: " .. levelName)
		return result
	end
	if def.studioOnly and not IS_STUDIO then
		table.insert(lines, Config.Prefix .. def.name .. " only works in Studio.")
		return result
	end
	-- trailing "confirm"
	local confirming = false
	if def.destructive and #tokens > 0 and string.lower(tokens[#tokens]) == "confirm" then
		confirming = true
		table.remove(tokens)
	end
	local ctx = { caller = caller, me = caller or opts.me, level = level, levelName = levelName, source = source, Core = Core,
		Data = DataAdapter, lines = lines, why = why }
	ctx.caller = caller or opts.me -- "me" for the console is opts.me
	function ctx.reply(line) table.insert(lines, tostring(line)) end
	local values, err = Args.Parse(def, tokens, ctx)
	if not values then
		table.insert(lines, err)
		audit(false, err)
		return result
	end
	-- who is targeted
	local targets = {}
	for _, spec in def.args do
		local v = values[spec.name]
		if spec.type == "players" and type(v) == "table" then for _, p in v do table.insert(targets, p) end
		elseif spec.type == "player" and v then table.insert(targets, v) end
	end
	ctx.targets = targets
	local targetText = #targets > 0 and playerNames(targets) or nil
	for _, p in targets do
		if p ~= caller then
			if caller and level < Permissions.Values.Admin and not def.anyTarget then
				local msg = ("Testers can only use %s%s on themselves."):format(Config.Prefix, def.name)
				table.insert(lines, msg); audit(false, msg, targetText); return result
			end
			local theirs = Permissions.LevelOf(p)
			if caller and theirs > level and not def.anyTarget then
				local msg = ("%s is %s, above you (%s)."):format(p.Name, Permissions.Name(theirs), levelName)
				table.insert(lines, msg); audit(false, msg, targetText); return result
			end
		end
	end
	if def.destructive then
		local several = ctx.multiTarget or #targets > 1
		if several and level < Permissions.Values.Owner then
			local msg = ("%s%s on several players is Owner only."):format(Config.Prefix, def.name)
			table.insert(lines, msg); audit(false, msg, targetText); return result
		end
		local key = (caller and caller.UserId or 0) .. "|" .. def.name .. " " .. string.lower(table.concat(tokens, " "))
		if not confirming then
			pendingConfirm[key] = os.clock()
			local what = def.confirmText and def.confirmText(ctx, values) or (def.name .. " " .. table.concat(tokens, " "))
			local again = Config.Prefix .. name .. (#tokens > 0 and (" " .. table.concat(tokens, " ")) or "") .. " confirm"
			table.insert(lines, ("This will %s. To go ahead type: %s   (within %d s)"):format(what, again, Config.ConfirmWindow))
			result.ok = true
			result.needsConfirm = true
			audit(true, "awaiting confirm", targetText)
			return result
		end
		local t = pendingConfirm[key]
		pendingConfirm[key] = nil
		if not t or os.clock() - t > Config.ConfirmWindow then
			local msg = t and "That confirm came too late (over " .. Config.ConfirmWindow .. " s). Run it again without confirm first."
				or "Nothing to confirm: run the command without confirm first."
			table.insert(lines, msg); audit(false, msg, targetText); return result
		end
	end
	local ok, a, b = pcall(def.run, ctx, values)
	if not ok then
		warn("[Admin] " .. def.name .. " failed: " .. tostring(a))
		table.insert(lines, "That command failed: " .. tostring(a))
		audit(false, "error: " .. tostring(a), targetText)
		return result
	end
	local good = a ~= false
	if type(b) == "string" then table.insert(lines, b) elseif type(a) == "string" then table.insert(lines, a) end
	result.ok = good
	audit(good, lines[#lines], targetText)
	return result
end

-- clean up stale confirm tokens now and then
task.spawn(function()
	while true do
		task.wait(30)
		for k, t in pendingConfirm do if os.clock() - t > Config.ConfirmWindow then pendingConfirm[k] = nil end end
	end
end)

return Core
]=]
SOURCES.Cmd_Data = [=[-- AdminFramework/Commands/Data: profile commands. Every write goes through DataAdapter (PlayerStore / the player's Replica),
-- so it saves with ProfileService and the HUD (LobbyHudController / LobbyUIController listen to the replica) updates at once.
local Players = game:GetService("Players")

local P = { name = "player", type = "players", defaultToken = "me" }
local WIPE_PARTS = { "all", "stats", "level", "inventory", "credits", "missions", "cooldowns", "settings" }

-- run fn(player) for every target whose data has loaded; returns the names done and the names skipped
local function each(ctx, list, fn)
	local done, skipped = {}, {}
	for _, p in list do
		if ctx.Data.Ready(p) then
			local note = fn(p)
			table.insert(done, note and (p.Name .. " " .. note) or p.Name)
			ctx.Data.Refresh(p)
		else
			table.insert(skipped, p.Name)
		end
	end
	if #skipped > 0 then ctx.reply("data not loaded yet for " .. table.concat(skipped, ", ") .. " (try again in a second)") end
	return done
end

local function tellTarget(ctx, p, text)
	if p ~= ctx.caller and ctx.Core.Notify then ctx.Core.Notify(p, "An admin " .. text, "info") end
end

local function levelLine(D, xp)
	local level, into, need = D.LevelOf(xp)
	return ("LV %d (%d XP, %d/%d to next)"):format(level, xp, into, need)
end

-- what each wipe part resets (profile keys back to their template defaults)
local function wipePart(D, p, part)
	local function reset(key) D.Set(p, { key }, D.Default(key)) end
	if part == "stats" or part == "all" then reset("Stats"); reset("Ranked") end
	if part == "level" or part == "all" then reset("XP"); reset("ItemXP") end
	if part == "inventory" or part == "all" then
		reset("Owned"); reset("Favorites"); reset("ItemXP"); D.Set(p, { "Loadout" }, D.DefaultLoadout())
	end
	if part == "credits" or part == "all" then reset("Credits") end
	if part == "missions" or part == "all" then reset("Quests") end
	if part == "cooldowns" or part == "all" then D.Set(p, { "DuelPairs" }, {}) end
	if part == "settings" or part == "all" then reset("Settings") end
	if part == "all" then reset("RedeemedCodes") end
	if part == "missions" or part == "all" then
		local LM = workspace:FindFirstChild("LobbyMap") and D.Lobby("LobbyManager") or nil
		if LM and LM.EnsureQuests then pcall(LM.EnsureQuests, p) end -- new missions at once (the lobby also re-rolls every 30 s)
	end
end

local function questSummary(data)
	local bits = {}
	for _, scope in { "Daily", "Weekly" } do
		local q = data.Quests and data.Quests[scope]
		local n, claimed = 0, 0
		for _, e in (q and q.List or {}) do n += 1; if e.Claimed then claimed += 1 end end
		table.insert(bits, ("%s %d (%d claimed)"):format(string.lower(scope), n, claimed))
	end
	return table.concat(bits, ", ")
end

return {
	{
		name = "stats", aliases = { "profile" }, level = "Tester",
		description = "Print a player's profile summary (level, XP, scissors, items, stats, ranked, missions, cooldowns).",
		args = { { name = "player", type = "player", defaultToken = "me" } },
		anyTarget = true, -- reading is harmless
		run = function(ctx, a)
			local D, p = ctx.Data, a.player
			local data = D.Get(p)
			if not data then return false, p.Name .. "'s data hasn't loaded yet" end
			local owned, total = 0, 0
			for id, item in D.Items() do total += 1; if D.Owns(p, id) then owned += 1 end end
			local s = data.Stats or {}
			ctx.reply(("%s (@%d): %s, %d scissors"):format(p.Name, p.UserId, levelLine(D, tonumber(data.XP) or 0), data.Credits or 0))
			ctx.reply(("items %d/%d owned, loadout %s / %s / %s"):format(owned, total, tostring(data.Loadout and data.Loadout.Weapon),
				tostring(data.Loadout and data.Loadout.Gadget), tostring(data.Loadout and data.Loadout.Melee)))
			local sb = {}
			for _, k in { "MatchesPlayed", "Wins", "Kills", "Headshots", "MeleeKills", "CoverKills", "GadgetsThrown" } do
				table.insert(sb, k .. " " .. tostring(s[k] or 0))
			end
			ctx.reply("stats: " .. table.concat(sb, ", "))
			local rb = {}
			for mode, r in (data.Ranked or {}) do
				if type(r) == "table" then table.insert(rb, ("%s SR %s W%s L%s"):format(mode, tostring(r.Rating), tostring(r.Wins or 0), tostring(r.Losses or 0))) end
			end
			local cd = 0
			for _ in (type(data.DuelPairs) == "table" and data.DuelPairs or {}) do cd += 1 end
			ctx.reply(("ranked: %s; missions: %s; duel reward cooldowns: %d"):format(#rb > 0 and table.concat(rb, ", ") or "none",
				questSummary(data), cd))
			return true
		end,
	},
	{
		name = "wipe", level = "Admin", destructive = true,
		description = "Reset profile data to the defaults: all, stats (Stats + Ranked), level (XP + gun XP), inventory (owned, loadout, favourites, gun XP), credits, missions, cooldowns, settings. Purchases (Passes, Receipts) and TutorialDone are never wiped.",
		args = { P, { name = "what", type = "choice", choices = WIPE_PARTS, optional = true, default = "all" } },
		confirmText = function(ctx, a)
			local names = {}
			for _, p in a.player do table.insert(names, p.Name) end
			return ("wipe %s of %s"):format(a.what, table.concat(names, ", "))
		end,
		run = function(ctx, a)
			local done = each(ctx, a.player, function(p)
				wipePart(ctx.Data, p, a.what)
				tellTarget(ctx, p, "wiped your " .. a.what .. " data.")
			end)
			return #done > 0, ("Wiped %s for %s."):format(a.what, table.concat(done, ", "))
		end,
	},
	{
		name = "setlevel", aliases = { "level" }, level = "Tester",
		description = "Set the account level: XP becomes exactly that level's threshold.",
		args = { P, { name = "level", type = "integer", min = 1 } },
		run = function(ctx, a)
			local D = ctx.Data
			local lv = math.min(a.level, D.MaxLevel())
			local xp = D.XPForLevel(lv)
			local done = each(ctx, a.player, function(p) D.Set(p, { "XP" }, xp); tellTarget(ctx, p, "set your level to " .. lv .. ".") end)
			return #done > 0, ("Level %d (%d XP) for %s."):format(lv, xp, table.concat(done, ", "))
		end,
	},
	{
		name = "addxp", level = "Tester", description = "Add (or with a negative number remove) account XP.",
		args = { P, { name = "xp", type = "integer" } },
		run = function(ctx, a)
			local D = ctx.Data
			local done = each(ctx, a.player, function(p)
				local cur = tonumber(D.Read(p, { "XP" })) or 0
				local new = math.max(0, cur + a.xp)
				D.Set(p, { "XP" }, new)
				return "-> " .. levelLine(D, new)
			end)
			return #done > 0, ("%+d XP: %s."):format(a.xp, table.concat(done, "; "))
		end,
	},
	{
		name = "setxp", level = "Tester", description = "Set account XP to an exact number.",
		args = { P, { name = "xp", type = "integer", min = 0 } },
		run = function(ctx, a)
			local D = ctx.Data
			local done = each(ctx, a.player, function(p) D.Set(p, { "XP" }, a.xp) end)
			return #done > 0, ("XP = %d (%s) for %s."):format(a.xp, levelLine(D, a.xp), table.concat(done, ", "))
		end,
	},
	{
		name = "setcredits", aliases = { "setscissors" }, level = "Tester", description = "Set scissors (Credits) to an exact amount.",
		args = { P, { name = "amount", type = "integer", min = 0 } },
		run = function(ctx, a)
			local done = each(ctx, a.player, function(p) ctx.Data.Set(p, { "Credits" }, a.amount); tellTarget(ctx, p, "set your scissors to " .. a.amount .. ".") end)
			return #done > 0, ("Scissors = %d for %s."):format(a.amount, table.concat(done, ", "))
		end,
	},
	{
		name = "addcredits", aliases = { "addscissors" }, level = "Tester", description = "Add (negative: take) scissors; never below 0.",
		args = { P, { name = "amount", type = "integer" } },
		run = function(ctx, a)
			local D = ctx.Data
			local done = each(ctx, a.player, function(p)
				local cur = tonumber(D.Read(p, { "Credits" })) or 0
				local new = math.max(0, cur + a.amount)
				D.Set(p, { "Credits" }, new)
				tellTarget(ctx, p, (a.amount >= 0 and "gave you %d scissors." or "took %d scissors."):format(math.abs(new - cur)))
				return "-> " .. new
			end)
			return #done > 0, ("%+d scissors: %s."):format(a.amount, table.concat(done, "; "))
		end,
	},
	{
		name = "setstat", level = "Tester",
		description = "Set a stat: MatchesPlayed, Wins, Kills, Headshots, CoverKills, MeleeKills, GadgetsThrown, Rating1v1/2v2/3v3, RankedWins<mode>, RankedLosses<mode>, XP, Credits.",
		args = { P, { name = "stat", type = "stat" }, { name = "value", type = "integer" } },
		run = function(ctx, a)
			local D, st = ctx.Data, a.stat
			local done = each(ctx, a.player, function(p)
				if st.ranked then D.SetRanked(p, st.ranked, st.field, a.value) else D.Set(p, st.path, a.value) end
			end)
			return #done > 0, ("%s = %d for %s."):format(st.name, a.value, table.concat(done, ", "))
		end,
	},
	{
		name = "give", aliases = { "grant" }, level = "Tester",
		description = "Give an item (id or name). Old form: ;give <player> <number> gives scissors.",
		args = { P, { name = "item", type = "string" } },
		run = function(ctx, a)
			local D = ctx.Data
			local amount = tonumber(a.item)
			if amount then -- the old AdminCommands /give name 500
				amount = math.floor(amount)
				local done = each(ctx, a.player, function(p)
					local cur = tonumber(D.Read(p, { "Credits" })) or 0
					D.Set(p, { "Credits" }, math.max(0, cur + amount))
					tellTarget(ctx, p, (amount >= 0 and "gave you %d scissors." or "took %d scissors."):format(math.abs(amount)))
				end)
				return #done > 0, ("Gave %d scissors to %s."):format(amount, table.concat(done, ", "))
			end
			local id, item = D.FindItem(a.item)
			if not id then return false, item end
			if item.Default then return false, id .. " is a default item: everyone always owns it" end
			local done = each(ctx, a.player, function(p)
				if D.Owns(p, id) then return "(already owned)" end
				D.Set(p, { "Owned", id }, true)
				tellTarget(ctx, p, "gave you " .. (item.Name or id) .. ".")
			end)
			return #done > 0, ("Gave %s to %s."):format(id, table.concat(done, ", "))
		end,
	},
	{
		name = "take", aliases = { "revoke" }, level = "Tester",
		description = "Take an item away (if it's equipped, that slot goes back to the default item).",
		args = { P, { name = "item", type = "item" } },
		run = function(ctx, a)
			local D, id = ctx.Data, a.item
			local item = D.Items()[id]
			if item.Default then return false, id .. " is a default item and can't be taken" end
			local def = D.DefaultLoadout()
			local done = each(ctx, a.player, function(p)
				if not D.Owns(p, id) then return "(didn't own it)" end
				D.Set(p, { "Owned", id }, nil)
				if D.Read(p, { "Loadout", item.Slot }) == id then D.Set(p, { "Loadout", item.Slot }, def[item.Slot]) end
				if D.Read(p, { "Favorites", id }) then D.Set(p, { "Favorites", id }, nil) end
			end)
			return #done > 0, ("Took %s from %s."):format(id, table.concat(done, ", "))
		end,
	},
	{
		name = "giveall", aliases = { "unlockall" }, level = "Tester", description = "Own every item in the catalogue.",
		args = { P },
		run = function(ctx, a)
			local D = ctx.Data
			if not D.HasCatalogue then return false, "this place has no item catalogue" end
			local done = each(ctx, a.player, function(p)
				local n = 0
				for id, item in D.Items() do
					if not item.Default and not D.Owns(p, id) then D.Set(p, { "Owned", id }, true); n += 1 end
				end
				return "+" .. n
			end)
			return #done > 0, ("Unlocked every item: %s."):format(table.concat(done, ", "))
		end,
	},
	{
		name = "resetcooldowns", aliases = { "resetcd" }, level = "Tester",
		description = "Clear the duel reward cooldowns (DuelPairs: one paid match per opponent pair per 10 min).",
		args = { P },
		run = function(ctx, a)
			local done = each(ctx, a.player, function(p)
				local n = 0
				for _ in (type(ctx.Data.Read(p, { "DuelPairs" })) == "table" and ctx.Data.Read(p, { "DuelPairs" }) or {}) do n += 1 end
				ctx.Data.Set(p, { "DuelPairs" }, {})
				return "(" .. n .. " cleared)"
			end)
			return #done > 0, "Duel reward cooldowns reset: " .. table.concat(done, ", ") .. "."
		end,
	},
	{
		name = "missions", aliases = { "quests" }, level = "Tester",
		description = "reset = new daily + weekly missions now; complete = every unclaimed mission finished (ready to claim).",
		args = { P, { name = "action", type = "choice", choices = { "reset", "complete" } } },
		run = function(ctx, a)
			local D = ctx.Data
			local LC = D.LobbyConfig
			local done = each(ctx, a.player, function(p)
				if a.action == "reset" then
					wipePart(D, p, "missions")
					return
				end
				if not LC or not LC.Quests then error("this place has no mission list") end
				local n = 0
				for _, scope in { "Daily", "Weekly" } do
					local q = D.Read(p, { "Quests", scope })
					for i, e in (type(q) == "table" and q.List or {}) do
						local def
						for _, d in LC.Quests[scope].Pool do if d.Id == e.Id then def = d end end
						if def and not e.Claimed then
							local stat = tonumber(D.Read(p, { "Stats", def.Stat })) or 0
							-- progress = Stats[stat] - Base; Base low enough that progress = Goal
							D.Set(p, { "Quests", scope, "List", i, "Base" }, stat - def.Goal)
							n += 1
						end
					end
				end
				return "(" .. n .. " ready to claim)"
			end)
			return #done > 0, ("Missions %s: %s."):format(a.action, table.concat(done, ", "))
		end,
	},
}
]=]
SOURCES.Cmd_Player = [=[-- AdminFramework/Commands/Player: kick, tp, heal, kill, respawn, god, speed.
-- Players in a lobby duel (attribute DuelMatch) are not teleported / respawned: that would break the match (;endmatch first).
local Players = game:GetService("Players")

local P = { name = "player", type = "players", defaultToken = "me" }

local function humanoidOf(p: Player)
	local c = p.Character
	return c and c:FindFirstChildOfClass("Humanoid"), c and c:FindFirstChild("HumanoidRootPart")
end

local function each(ctx, list, fn)
	local done, skipped = {}, {}
	for _, p in list do
		local ok, why = fn(p)
		if ok == false then table.insert(skipped, p.Name .. " (" .. tostring(why) .. ")") else table.insert(done, p.Name) end
	end
	if #skipped > 0 then ctx.reply("skipped " .. table.concat(skipped, ", ")) end
	if #done == 0 then table.insert(done, "nobody") end
	return done
end

-- god mode: an invisible ForceField (every damage path uses Humanoid:TakeDamage, which a ForceField blocks) plus a heal-back
local god = {}
local function applyGod(p: Player)
	local hum = humanoidOf(p)
	if not hum then return end
	local c = p.Character
	if not c:FindFirstChild("AdminGodField") then
		local ff = Instance.new("ForceField"); ff.Name = "AdminGodField"; ff.Visible = false; ff.Parent = c
	end
	if not hum:GetAttribute("AdminGodHooked") then
		hum:SetAttribute("AdminGodHooked", true)
		hum.HealthChanged:Connect(function(h)
			if god[p] and h > 0 and h < hum.MaxHealth then hum.Health = hum.MaxHealth end
		end)
	end
	hum.Health = hum.MaxHealth
end
local function removeGod(p: Player)
	local c = p.Character
	local ff = c and c:FindFirstChild("AdminGodField")
	if ff then ff:Destroy() end
end
local hooked = {}
local function hookPlayer(p: Player)
	if hooked[p] then return end
	hooked[p] = true
	p.CharacterAdded:Connect(function()
		task.wait() -- let the Humanoid exist
		if god[p] then applyGod(p) end
		local speed = p:GetAttribute("AdminSpeed")
		local hum = humanoidOf(p)
		if speed and hum then hum.WalkSpeed = speed end
	end)
end
Players.PlayerRemoving:Connect(function(p) god[p] = nil; hooked[p] = nil end)

-- tp destinations that aren't players: duel pads, the spawn, the hangar, or "x,y,z"
local function placeTarget(token: string): (CFrame?, string?)
	local t = string.lower(token)
	local map = workspace:FindFirstChild("LobbyMap")
	if t == "spawn" or t == "hub" then
		local sp = map and map:FindFirstChild("LobbySpawn")
		if sp then return sp.CFrame + Vector3.new(0, 4, 0), "the spawn" end
		local any = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
		if any then return any.CFrame + Vector3.new(0, 4, 0), "the spawn" end
		return CFrame.new(0, 10, 0), "the origin"
	elseif t == "spawna" or t == "spawnb" then
		-- the match place's team spawns (Workspace.MatchSpawns.SpawnA / SpawnB)
		local ms = workspace:FindFirstChild("MatchSpawns")
		local sp = ms and ms:FindFirstChild(string.sub(t, -1) == "a" and "SpawnA" or "SpawnB")
		if sp then return sp.CFrame + Vector3.new(0, 4, 0), sp.Name end
		return nil
	elseif t == "hangar" or t == "exfil" then
		return CFrame.new(112, 3.5, 0) * CFrame.Angles(0, -math.pi / 2, 0), "the hangar" -- LobbyFallCatch's HANGAR
	end
	local x, y, z = string.match(t, "^(%-?[%d%.]+),(%-?[%d%.]+),(%-?[%d%.]+)$")
	if x then return CFrame.new(tonumber(x), tonumber(y), tonumber(z)), ("%s,%s,%s"):format(x, y, z) end
	-- pads: Pad_1v1_A, "1v1a", "pad_2v2_b" ...
	local duels = map and map:FindFirstChild("Duels")
	local key = string.gsub(string.gsub(t, "^pad_?", ""), "_", "")
	for _, pad in (duels and duels:GetChildren() or {}) do
		if pad:IsA("Model") and pad:GetAttribute("QueueName") then
			local n = string.lower(string.gsub(string.gsub(pad.Name, "^Pad_", ""), "_", ""))
			if n == key then
				local zone = pad:FindFirstChild("Team1") or pad.PrimaryPart
				local pos = zone and zone:IsA("BasePart") and (zone.Position - Vector3.new(0, zone.Size.Y / 2 - 3, 0)) or pad:GetPivot().Position
				return CFrame.new(pos), pad.Name
			end
		end
	end
	return nil
end

return {
	{
		name = "kick", level = "Admin", description = "Kick a player from this server.",
		args = { { name = "player", type = "players" }, { name = "reason", type = "rest", optional = true, default = "Kicked by an admin" } },
		run = function(ctx, a)
			local done = each(ctx, a.player, function(p)
				if p == ctx.caller then return false, "not yourself" end
				p:Kick(a.reason)
			end)
			return done[1] ~= "nobody", "Kicked " .. table.concat(done, ", ") .. "."
		end,
	},
	{
		name = "tp", aliases = { "teleport", "goto" }, level = "Tester",
		description = "Teleport players to a player, a duel pad (1v1a, pad_2v2_b), spawn, hangar, spawna / spawnb (match place), or x,y,z.",
		args = { P, { name = "target", type = "string" } },
		run = function(ctx, a)
			local cf, label = placeTarget(a.target)
			if not cf then
				local list, err = ctx.Core.Args.Players(a.target, ctx)
				if not list then return false, "no place or player \"" .. a.target .. "\" (" .. tostring(err) .. ")" end
				if #list ~= 1 then return false, "tp to exactly one player" end
				local _, root = humanoidOf(list[1])
				if not root then return false, list[1].Name .. " has no character" end
				cf, label = root.CFrame * CFrame.new(0, 0, 4), list[1].Name
			end
			local done = each(ctx, a.player, function(p)
				if p:GetAttribute("DuelMatch") then return false, "in a duel" end
				local _, root = humanoidOf(p)
				if not root then return false, "no character" end
				p.Character:PivotTo(cf)
			end)
			return done[1] ~= "nobody", ("Teleported %s to %s."):format(table.concat(done, ", "), label)
		end,
	},
	{
		name = "heal", level = "Tester", description = "Full health.",
		args = { P },
		run = function(ctx, a)
			local done = each(ctx, a.player, function(p)
				local hum = humanoidOf(p)
				if not hum or hum.Health <= 0 then return false, "no living character" end
				hum.Health = hum.MaxHealth
			end)
			return done[1] ~= "nobody", "Healed " .. table.concat(done, ", ") .. "."
		end,
	},
	{
		name = "kill", level = "Tester", description = "Kill (in a duel this counts as a death in the round).",
		args = { P },
		run = function(ctx, a)
			local done = each(ctx, a.player, function(p)
				local hum = humanoidOf(p)
				if not hum then return false, "no character" end
				if god[p] then god[p] = nil; removeGod(p); p:SetAttribute("AdminGod", nil) end
				hum.Health = 0
			end)
			return done[1] ~= "nobody", "Killed " .. table.concat(done, ", ") .. "."
		end,
	},
	{
		name = "respawn", aliases = { "re", "refresh" }, level = "Tester", description = "Load a new character at the spawn.",
		args = { P },
		run = function(ctx, a)
			local done = each(ctx, a.player, function(p)
				if p:GetAttribute("DuelMatch") then return false, "in a duel" end
				task.spawn(function() p:LoadCharacter() end)
			end)
			return done[1] ~= "nobody", "Respawned " .. table.concat(done, ", ") .. "."
		end,
	},
	{
		name = "god", level = "Tester", description = "God mode on/off (invisible ForceField + heal-back; lasts through respawns).",
		args = { P, { name = "on", type = "boolean", optional = true, default = true } },
		run = function(ctx, a)
			local done = each(ctx, a.player, function(p)
				hookPlayer(p)
				god[p] = a.on or nil
				p:SetAttribute("AdminGod", a.on or nil)
				if a.on then applyGod(p) else removeGod(p) end
			end)
			return done[1] ~= "nobody", ("God %s: %s."):format(a.on and "on" or "off", table.concat(done, ", "))
		end,
	},
	{
		name = "speed", aliases = { "walkspeed", "ws" }, level = "Tester",
		description = "WalkSpeed (16 = normal; 'reset' or 0 = normal). Sets player attribute AdminSpeed.",
		args = { P, { name = "speed", type = "string", optional = true, default = "reset" } },
		run = function(ctx, a)
			local n = tonumber(a.speed)
			if a.speed ~= "reset" and (not n or n < 0 or n > 500) then return false, "speed must be 0-500 or reset" end
			if n == 0 or a.speed == "reset" then n = nil end
			local done = each(ctx, a.player, function(p)
				hookPlayer(p)
				p:SetAttribute("AdminSpeed", n)
				local hum = humanoidOf(p)
				if hum then hum.WalkSpeed = n or 16 end
			end)
			return done[1] ~= "nobody", ("Speed %s for %s."):format(n and tostring(n) or "normal", table.concat(done, ", "))
		end,
	},
}
]=]
SOURCES.Cmd_Duel = [=[-- AdminFramework/Commands/Duel: lobby pad duels (LobbyDuelManager). In a place without lobby duels these say so.
-- duelsolo sets the player attribute AdminDuelSolo (server-set; clients can't fake it). The [ADMIN] edits in QueueManager
-- (bayIsFull) and LobbyDuelManager (StartMatch) let a pad with such a player start alone and fill the empty places with
-- test bots, live as well as in Studio. A match with a test bot never pays rewards (match.hasBot, LobbyDuelManager.award).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local function ldm(ctx)
	local m = ctx.Core.Place == "lobby" and ctx.Data.Lobby("LobbyDuelManager") or nil
	if not m or not m._matches then error("this place has no lobby duels (LobbyDuelManager)") end
	return m
end

-- the match place: one match per server on ReplicatedStorage, run by RoundManager on MatchCore (MatchInfo / EndMatch)
local function roundManager(ctx)
	if ctx.Core.Place ~= "match" then return nil end
	local m = ctx.Data.Lobby("RoundManager")
	if m and m.MatchInfo then return m end
	return nil
end

local function matchConfig(ctx)
	return ctx.Data.MatchConfig or {}
end

local function describe(m)
	local mem = {}
	for side, list in m.teams do
		for _, x in list do table.insert(mem, side .. ":" .. tostring(x.name) .. (x.isBot and "(bot)" or "") .. (x.left and "(left)" or "")) end
	end
	local s = m.state
	return ("%s  %s slot %d  %s  %s-%s  [%s]"):format(m.id, m.mode, m.slot, tostring(s and s:GetAttribute("MatchState") or "?"),
		tostring(s and s:GetAttribute("ScoreA") or 0), tostring(s and s:GetAttribute("ScoreB") or 0), table.concat(mem, " "))
end

return {
	{
		name = "duelsolo", level = "Admin", place = "lobby",
		description = "on: a duel pad you stand on starts with just you; empty places get test bots; bot matches never pay. Only for matches that include you.",
		args = { { name = "on", type = "boolean" }, { name = "player", type = "players", defaultToken = "me" } },
		run = function(ctx, a)
			local names = {}
			for _, p in a.player do
				local lv = ctx.Core.Permissions.LevelOf(p)
				if lv < ctx.Core.Permissions.Values.Admin then
					ctx.reply(p.Name .. " isn't an admin: duelsolo is admins only")
				else
					p:SetAttribute("AdminDuelSolo", a.on or nil)
					table.insert(names, p.Name)
				end
			end
			if RunService:IsStudio() then
				-- Studio: also the old global switch (LobbyDuelManager._TestSolo / the DuelTestHook use it)
				ReplicatedStorage:SetAttribute("DuelTestSolo", a.on or nil)
			end
			if #names == 0 then return false, "nobody changed" end
			return true, ("Duel solo %s for %s. %s"):format(a.on and "ON" or "off", table.concat(names, ", "),
				a.on and "Stand on a pad: it counts down alone, bots fill the rest, no rewards." or "")
		end,
	},
	{
		name = "listmatches", aliases = { "matches", "duels" }, level = "Tester", description = "Running matches (lobby duels, or this match server's match).",
		run = function(ctx)
			local rm = roundManager(ctx)
			if rm then
				local i = rm.MatchInfo()
				ctx.reply(("%s  %s%s  %s  round %d  %d-%d  map %s  [%s]"):format(i.kind, tostring(i.mode or "-"), i.ranked and " ranked" or "",
					tostring(i.state or "-"), i.round, i.scoreA, i.scoreB, tostring(i.map or "-"), table.concat(i.members, " ")))
				return true, i.kind == "none" and "No match running on this server." or "1 match on this server."
			end
			local m = ldm(ctx)
			local n = 0
			for _, match in m._matches do n += 1; ctx.reply(describe(match)) end
			if n == 0 then return true, "No lobby duels running." end
			return true, n .. " match(es)."
		end,
	},
	{
		name = "endmatch", aliases = { "stopmatch" }, level = "Admin",
		description = "End a match now: a lobby duel (match id like D3, or a player in it; back to the pads) or, in the match place, this server's match (back to the lobby). Nobody is paid.",
		args = { { name = "match", type = "string", optional = true } },
		run = function(ctx, a)
			local rm = roundManager(ctx)
			if rm then
				local ok, why = rm.EndMatch("admin " .. (ctx.caller and ctx.caller.Name or "console"))
				if not ok then return false, why end
				return true, "Ending this server's match: no rewards, everyone goes back to the lobby."
			end
			local m = ldm(ctx)
			if not a.match then return false, "give a match id (;listmatches) or a player in it" end
			local id = string.upper(a.match)
			if not m._matches[id] then
				local list = ctx.Core.Args.Players(a.match, ctx)
				local p = list and list[1]
				id = p and p:GetAttribute("DuelMatch")
				if not id then return false, ("no match \"%s\" (and no player in a duel by that name)"):format(a.match) end
			end
			if not m._matches[id] then return false, "match " .. tostring(id) .. " is already over" end
			-- both sides leave: the match ends as a forfeit with nobody present, so award() pays nobody
			m._TestForfeit(id, "A")
			m._TestForfeit(id, "B")
			return true, ("Ending %s: players are being returned to the pads."):format(id)
		end,
	},
	{
		name = "arenas", level = "Tester", place = "lobby", description = "Arena slots and the duel maps (modes per map).",
		run = function(ctx)
			local m = ldm(ctx)
			local C = matchConfig(ctx)
			local sl = {}
			for n = 1, C.MaxArenas or 6 do sl[n] = n .. ":" .. tostring(m._slots[n] or "free") end
			ctx.reply("slots " .. table.concat(sl, "  "))
			local ok, MapRegistry = pcall(require, ReplicatedStorage.Modules.Shared.MapRegistry)
			if ok then
				for _, info in MapRegistry.List() do
					ctx.reply(("map %s (%s): modes %s"):format(info.Id, tostring(info.DisplayName), table.concat(info.Modes or {}, ",")))
				end
			end
			return true, ("in-lobby duels %s, solo test %s"):format(C.PadDuelsInLobby and "on" or "OFF",
				tostring(ReplicatedStorage:GetAttribute("DuelTestSolo") == true))
		end,
	},
}
]=]
SOURCES.Cmd_World = [=[-- AdminFramework/Commands/World: server-wide things.
local Players = game:GetService("Players")

return {
	{
		name = "announce", aliases = { "m", "say" }, level = "Admin", description = "A system message (and toast in the lobby) to everyone here.",
		args = { { name = "text", type = "rest" } },
		run = function(ctx, a)
			local text = string.sub(a.text, 1, 160)
			for _, p in Players:GetPlayers() do ctx.Core.Notify(p, text, "announce") end
			return true, "Announced to " .. #Players:GetPlayers() .. " player(s)."
		end,
	},
	{
		name = "pads", level = "Tester", place = "lobby", description = "Duel pads: mode, state, NoMap, who is on them.",
		run = function(ctx)
			local map = workspace:FindFirstChild("LobbyMap")
			local duels = map and map:FindFirstChild("Duels")
			if not duels then return false, "this place has no LobbyMap.Duels pads" end
			local n = 0
			for _, pad in duels:GetChildren() do
				if pad:IsA("Model") and pad:GetAttribute("QueueName") then
					n += 1
					ctx.reply(("%s  %s  bay %s  %s%s"):format(pad.Name, tostring(pad:GetAttribute("QueueName")), tostring(pad:GetAttribute("BayId")),
						(function() local h = pad:FindFirstChild("Holo"); local v = h and h:GetAttribute("BayStatus"); return type(v) == "string" and v or "" end)(),
						pad:GetAttribute("NoMap") and ("  NoMap: " .. tostring(pad:GetAttribute("NoMapText"))) or ""))
				end
			end
			return true, n .. " pad(s). tp to one with ;tp me 1v1a"
		end,
	},
}
]=]
SOURCES.Cmd_Debug = [=[-- AdminFramework/Commands/Debug: help, whoami, serverinfo, audit, simlevel (Studio).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local started = os.clock()

return {
	{
		name = "cmds", aliases = { "help", "commands", "?" }, level = "Tester",
		description = "List the commands you can use, or ;help <command> for one.",
		args = { { name = "command", type = "string", optional = true } },
		run = function(ctx, a)
			local Core = ctx.Core
			if a.command then
				local def = Core.ByName[string.lower((string.gsub(a.command, "^[;/]", "")))]
				if not def then return false, "no command \"" .. a.command .. "\"" end
				ctx.reply(Core.Usage(def) .. "   (" .. def.level .. "+" .. (def.destructive and ", needs confirm" or "") ..
					(def.aliases and #def.aliases > 0 and (", aliases " .. table.concat(def.aliases, " ")) or "") .. ")")
				ctx.reply(def.description or "")
				return true
			end
			local groups, order = {}, {}
			for _, def in Core.Visible(ctx.level) do
				if not groups[def.group] then groups[def.group] = {}; table.insert(order, def.group) end
				table.insert(groups[def.group], def.name)
			end
			for _, g in order do ctx.reply(g .. ": " .. table.concat(groups[g], ", ")) end
			return true, ("You are %s. ;help <command> for details. Players: me, all, others, @userid, name."):format(ctx.levelName)
		end,
	},
	{
		name = "whoami", level = "Tester", description = "Your admin level and why.",
		run = function(ctx)
			local p = ctx.caller
			local Perm = ctx.Core.Permissions
			local real, realWhy = 0, "-"
			if p then real, realWhy = Perm.RealLevel(p) end
			return true, ("%s (@%s): %s via %s; live level %s via %s; group %d"):format(p and p.Name or "console", p and p.UserId or 0,
				ctx.levelName, tostring(ctx.why), Perm.Name(real), realWhy, Perm.GroupId())
		end,
	},
	{
		name = "serverinfo", aliases = { "server" }, level = "Tester", description = "Place, server, players, uptime, data store.",
		run = function(ctx)
			local D = ctx.Data
			local duels = 0
			local m = ctx.Core.Place == "lobby" and D.Lobby("LobbyDuelManager") or nil
			for _ in (m and m._matches or {}) do duels += 1 end
			local rm = ctx.Core.Place == "match" and D.Lobby("RoundManager") or nil
			if rm and rm.MatchInfo then
				-- the match place: its one match
				local i = rm.MatchInfo()
				ctx.reply(("match server: %s %s, state %s"):format(i.kind, tostring(i.mode or "-"), tostring(i.state or "-")))
			end
			ctx.reply(("place %d v%d  job %s  %s"):format(game.PlaceId, game.PlaceVersion, game.JobId ~= "" and string.sub(game.JobId, 1, 8) or "studio",
				RunService:IsStudio() and "STUDIO" or (game.PrivateServerId ~= "" and "private server" or "public server")))
			return true, ("%d player(s), up %d min, profile store \"%s\", lobby duels %d, audit store %s"):format(#Players:GetPlayers(),
				math.floor((os.clock() - started) / 60), D.StoreKey, duels, ctx.Core.Audit.StoreState())
		end,
	},
	{
		name = "audit", aliases = { "log" }, level = "Admin", description = "The last admin commands run on this server.",
		args = { { name = "count", type = "integer", min = 1, max = 30, optional = true, default = 8 } },
		run = function(ctx, a)
			for _, e in ctx.Core.Audit.Recent(a.count) do
				ctx.reply(("%s %s(%s) %s %s%s -> %s"):format(os.date("!%H:%M:%S", e.time), tostring(e.admin), tostring(e.level), e.command,
					e.args or "", e.targets and (" @" .. e.targets) or "", e.ok and "ok" or ("refused: " .. tostring(e.result))))
			end
			return true
		end,
	},
	{
		name = "dump", aliases = { "rawdata" }, level = "Admin", anyTarget = true,
		description = "Raw profile JSON (one key, or the key list). Read-only.",
		args = { { name = "player", type = "player", defaultToken = "me" }, { name = "key", type = "string", optional = true } },
		run = function(ctx, a)
			local data = ctx.Data.Get(a.player)
			if not data then return false, "data not loaded" end
			if not a.key then
				local keys = {}
				for k in data do table.insert(keys, tostring(k)) end
				table.sort(keys)
				return true, "keys: " .. table.concat(keys, ", ")
			end
			local key
			for k in data do if string.lower(tostring(k)) == string.lower(a.key) then key = k end end
			if key == nil then return false, "no key " .. a.key end
			local ok, json = pcall(HttpService.JSONEncode, HttpService, data[key])
			json = ok and json or tostring(data[key])
			for i = 1, math.min(#json, 1200), 300 do ctx.reply(string.sub(json, i, i + 299)) end
			return true, ("%s.%s (%d chars)"):format(a.player.Name, tostring(key), #json)
		end,
	},
	{
		name = "simlevel", level = "None", studioOnly = true, anyTarget = true, -- None: a simulated non-admin can still undo it
		description = "Studio only: pretend to have another admin level (None to test denial). Undo with ;simlevel owner",
		args = { { name = "level", type = "level" }, { name = "player", type = "player", defaultToken = "me" } },
		run = function(ctx, a)
			local ok, err = ctx.Core.Permissions.SetSimulated(a.player.UserId, a.level ~= ctx.Core.Config.StudioLevel and a.level or nil)
			if not ok then return false, err end
			return true, ("%s now counts as %s in this Studio test."):format(a.player.Name, a.level)
		end,
	},
}
]=]
SOURCES.Cmd_Legacy = [=[-- AdminFramework/Commands/Legacy: the old ServerScriptService.AdminCommands chat commands, kept working on top of the new
-- framework (original in ServerStorage._RebuildRemoved.ADMIN_AdminCommands_Orig). Typed with "/" (old) or ";".
--   /scissors 5000 | /scissors set 0   -> addcredits me 5000 | setcredits me 0
--   /give <name> 500                   -> ;give <name> 500 (Data.give: a number = scissors)
--   /wipeweapons                       -> ;wipe me inventory (asks for confirm like every wipe)
--   /unlockall                         -> alias of ;giveall (Data)
--   /admin                             -> ;cmds
return {
	{
		name = "scissors", level = "Tester", description = "Old form: /scissors 5000 adds, /scissors set 0 sets (yours).",
		args = { { name = "amount", type = "rest" } },
		run = function(ctx, a)
			local t = ctx.Core.Args.Tokenize(a.amount)
			local cmd
			if string.lower(t[1] or "") == "set" then cmd = "setcredits me " .. tostring(t[2] or "")
			else cmd = "addcredits me " .. tostring(t[1] or "") end
			local r = ctx.Core.Run(ctx.caller, cmd, (ctx.source or "") .. "/legacy")
			for _, l in r.lines do ctx.reply(l) end
			return r.ok
		end,
	},
	{
		name = "wipeweapons", level = "Admin", destructive = true,
		description = "Old form: lock every item again (back to the default kit). Same as ;wipe me inventory.",
		confirmText = function() return "lock every item you own again (default kit)" end,
		run = function(ctx)
			local D, p = ctx.Data, ctx.caller
			if not p or not D.Ready(p) then return false, "your data hasn't loaded yet" end
			local n = 0
			for _ in (D.Read(p, { "Owned" }) or {}) do n += 1 end
			D.Set(p, { "Owned" }, {}); D.Set(p, { "ItemXP" }, {}); D.Set(p, { "Loadout" }, D.DefaultLoadout())
			D.Refresh(p)
			return true, ("Wiped %d unlocked items. You're back to the default kit."):format(n)
		end,
	},
	{
		name = "admin", level = "Tester", description = "Old form of ;cmds.",
		run = function(ctx)
			local r = ctx.Core.Run(ctx.caller, "cmds", ctx.source)
			for _, l in r.lines do ctx.reply(l) end
			return r.ok
		end,
	},
}
]=]
SOURCES.AdminCommands = [=[-- [ADMIN] ServerScriptService/AdminCommands (Script): entry points of the admin framework (notes/admin_framework.md, 2026-10-16).
-- Replaces the old chat-command script (original: ServerStorage._RebuildRemoved.ADMIN_AdminCommands_Orig); its commands still
-- work (Commands/Legacy). The framework itself is ServerScriptService.AdminFramework (Config, Permissions, Args, DataAdapter,
-- Audit, Core, Commands/*). Same files in the lobby and the match place.
-- Entry points (all end in Core.Run on the server, which checks the caller's level; the client never decides):
--   1. Chat: ";cmd args" (and the old "/scissors" etc.). TextChatService.AdminCommands holds one TextChatCommand per name /
--      alias, so the text never shows as a chat message; StarterPlayerScripts.AdminFeedback forwards it via AdminRequest.
--   2. Admin panel (UI session, notes/admin_ui_requests.md): ReplicatedStorage.AdminRemote (RemoteFunction)
--      InvokeServer("commands") / ("run", text) / ("whoami") / ("audit", n).
--   3. Studio command bar / MCP: ServerStorage.AdminBindable (BindableFunction, server only)
--      Invoke("run", text, userId)      as that player (their real level), feedback in their chat
--      Invoke("console", text, userId?) as the server console (Owner); "me" = that player
--      Invoke("simlevel", userId, "None"|"Tester"|"Admin"|nil)   Studio only
--      Invoke("audit", n) / Invoke("list")
-- Feedback: ReplicatedStorage.AdminFeedback:FireClient(player, line, kind) -> a system line in chat (AdminFeedback LocalScript).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TextChatService = game:GetService("TextChatService")

local Framework = ServerScriptService:WaitForChild("AdminFramework")
local Core = require(Framework.Core)
local Config = require(Framework.Config)
Core.LoadCommands(Framework.Commands)

local function remote(class: string, name: string)
	local r = ReplicatedStorage:FindFirstChild(name)
	if r and not r:IsA(class) then r:Destroy(); r = nil end
	if not r then r = Instance.new(class); r.Name = name; r.Parent = ReplicatedStorage end
	return r
end
local feedback = remote("RemoteEvent", "AdminFeedback")
local request = remote("RemoteEvent", "AdminRequest")
local panel = remote("RemoteFunction", "AdminRemote")

local MAX_LINES = 24
Core.Notify = function(player: Player?, text: string, kind)
	if not player then print("[Admin] " .. tostring(text)) return end
	if not player.Parent then return end
	feedback:FireClient(player, string.sub(tostring(text), 1, 400), kind)
	if kind == "announce" then
		local lobby = ReplicatedStorage:FindFirstChild("Events") and ReplicatedStorage.Events:FindFirstChild("Lobby")
		local toast = lobby and lobby:FindFirstChild("Notify")
		if toast and toast:IsA("RemoteEvent") then toast:FireClient(player, text, "info") end
	end
end

local function send(player: Player?, result)
	local kind = result.ok and true or false
	if result.needsConfirm then kind = "info" end
	for i, line in result.lines do
		if i > MAX_LINES then Core.Notify(player, ("(%d more lines)"):format(#result.lines - MAX_LINES), "info") break end
		-- the last line carries ok / error colour, the lines before it are plain output
		local k = "info"
		if i == #result.lines then k = kind end -- (not `cond and kind or "info"`: kind can be false)
		Core.Notify(player, line, k)
	end
end

-- 1. Chat ---------------------------------------------------------------------------------------------------------------------
local LEGACY = { scissors = true, give = true, wipeweapons = true, unlockall = true, admin = true }
local folder = TextChatService:FindFirstChild("AdminCommands") or Instance.new("Folder")
folder.Name = "AdminCommands"
folder:ClearAllChildren()
local made = {}
local function chatCommand(word: string)
	if made[word] or not string.match(word, "^[%w_%?]+$") then return end
	made[word] = true
	local c = Instance.new("TextChatCommand")
	c.Name = "Admin_" .. word
	c.PrimaryAlias = Config.Prefix .. word
	c.SecondaryAlias = LEGACY[word] and (Config.LegacyPrefix .. word) or ""
	c.AutocompleteVisible = false
	c.Parent = folder
end
for _, def in Core.Commands do
	chatCommand(def.name)
	for _, a in def.aliases or {} do chatCommand(string.lower(a)) end
end
folder.Parent = TextChatService

local last = {}
local function limited(player: Player): boolean
	local t = os.clock()
	if last[player] and t - last[player] < Config.RateLimit then return true end
	last[player] = t
	return false
end
Players.PlayerRemoving:Connect(function(p) last[p] = nil end)

request.OnServerEvent:Connect(function(player: Player, text: any)
	if typeof(text) ~= "string" or #text > Config.MaxTextLength or limited(player) then return end
	local result = Core.Run(player, text, "chat")
	-- non-admins typing something that isn't a command hear nothing
	if result.unknown and Core.Permissions.LevelOf(player) == 0 then return end
	send(player, result)
end)

-- A mistyped ";command" from an admin matches no TextChatCommand and would be posted as a chat message: hold it back
-- (ShouldDeliverCallback, server) and answer "unknown command" instead. Anyone else's ";..." is normal chat.
local seenMsg = {}
local function guardChannel(channel: Instance)
	if not channel:IsA("TextChannel") then return end
	channel.ShouldDeliverCallback = function(message: TextChatMessage, _target: TextSource)
		local src = message.TextSource
		local text = message.Text
		if not src or type(text) ~= "string" or not string.match(text, "^%" .. Config.Prefix .. "%a") then return true end
		local sender = Players:GetPlayerByUserId(src.UserId)
		if not sender or Core.Permissions.LevelOf(sender) == 0 then return true end
		if not seenMsg[message.MessageId] then
			seenMsg[message.MessageId] = os.clock()
			task.spawn(function() send(sender, Core.Run(sender, text, "chat")) end)
		end
		return false
	end
end
task.spawn(function()
	-- the default channels are created a moment after the server starts
	local channels = TextChatService:WaitForChild("TextChannels", 30)
	if not channels then return end
	for _, c in channels:GetChildren() do guardChannel(c) end
	channels.ChildAdded:Connect(guardChannel)
end)
task.spawn(function()
	while true do
		task.wait(60)
		for id, t in seenMsg do if os.clock() - t > 60 then seenMsg[id] = nil end end
	end
end)

-- 2. Admin panel ------------------------------------------------------------------------------------------------------------
local function describe(def)
	local args = {}
	for _, a in def.args do
		table.insert(args, { name = a.name, type = a.type, optional = a.optional == true, choices = a.choices, min = a.min, max = a.max,
			default = a.defaultToken or (type(a.default) ~= "function" and a.default or nil) })
	end
	return { name = def.name, aliases = def.aliases or {}, group = def.group, level = def.level, description = def.description or "",
		usage = Core.Usage(def), destructive = def.destructive == true, args = args }
end
panel.OnServerInvoke = function(player: Player, action: any, payload: any)
	-- only "run" is rate-limited (the panel reads whoami + commands together when it opens)
	if action == "run" and limited(player) then return { ok = false, lines = { "slow down" } } end
	local level = Core.Permissions.LevelOf(player)
	if action == "whoami" then
		return { ok = true, level = level, levelName = Core.Permissions.Name(level), prefix = Config.Prefix }
	end
	if level == 0 then return { ok = false, lines = { "You're not allowed to use admin commands." } } end
	if action == "commands" then
		local list = {}
		for _, def in Core.Visible(level) do table.insert(list, describe(def)) end
		return { ok = true, commands = list, level = level, levelName = Core.Permissions.Name(level) }
	elseif action == "run" then
		if typeof(payload) ~= "string" or #payload > Config.MaxTextLength then return { ok = false, lines = { "bad command text" } } end
		local r = Core.Run(player, payload, "panel")
		return { ok = r.ok, lines = r.lines, needsConfirm = r.needsConfirm, command = r.command }
	elseif action == "audit" then
		if level < Core.Permissions.Values.Admin then return { ok = false, lines = { "audit needs Admin" } } end
		return { ok = true, entries = Core.Audit.Recent(math.clamp(tonumber(payload) or 20, 1, 50)) }
	end
	return { ok = false, lines = { "unknown action" } }
end

-- 3. Studio command bar / MCP ------------------------------------------------------------------------------------------------
local bindable = ServerStorage:FindFirstChild("AdminBindable") or Instance.new("BindableFunction")
bindable.Name = "AdminBindable"
bindable.OnInvoke = function(action: string, a, b, c)
	if action == "run" then
		local p = Players:GetPlayerByUserId(tonumber(b) or 0) or (b == nil and Players:GetPlayers()[1])
		if not p then return { ok = false, lines = { "no such player" } } end
		local r = Core.Run(p, a, "bindable")
		if not (r.unknown and Core.Permissions.LevelOf(p) == 0) then send(p, r) end
		return r
	elseif action == "console" then
		local me = b and Players:GetPlayerByUserId(tonumber(b) or 0) or nil
		local r = Core.Run(nil, a, "console", { forceLevel = Core.Permissions.Values.Owner, me = me })
		for _, l in r.lines do print("[Admin console] " .. l) end
		return r
	elseif action == "simlevel" then
		return Core.Permissions.SetSimulated(tonumber(a) or 0, b)
	elseif action == "audit" then
		return Core.Audit.Recent(tonumber(a) or 20)
	elseif action == "list" then
		local t = {}
		for _, def in Core.Commands do table.insert(t, def.name) end
		return t
	end
	return "unknown action " .. tostring(action)
end
bindable.Parent = ServerStorage

print(("[Admin] ready: %d commands, prefix %s, group %d, data layer %s"):format(#Core.Commands, Config.Prefix,
	Core.Permissions.GroupId(), Core.Data.HasPlayerStore and "PlayerStore" or "DataManager replicas"))
]=]
SOURCES.AdminFeedback = [=[-- [ADMIN] StarterPlayerScripts/AdminFeedback (LocalScript): the chat side of the admin framework (notes/admin_framework.md).
-- Sends ";cmd ..." (and the old "/scissors" etc.) to the server, and shows the replies as system lines in chat.
-- It decides nothing: the server checks every command and the caller's level. Original: ServerStorage._RebuildRemoved.ADMIN_AdminFeedback_Orig.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local feedback = ReplicatedStorage:WaitForChild("AdminFeedback")
local request = ReplicatedStorage:WaitForChild("AdminRequest")

local function hook(cmd: Instance)
	if not cmd:IsA("TextChatCommand") then return end
	cmd.Triggered:Connect(function(_source, text: string)
		request:FireServer(text)
	end)
end
local folder = TextChatService:WaitForChild("AdminCommands")
for _, cmd in folder:GetChildren() do hook(cmd) end
folder.ChildAdded:Connect(hook)

local function escape(s: string): string
	return (string.gsub(string.gsub(string.gsub(s, "&", "&amp;"), "<", "&lt;"), ">", "&gt;"))
end

-- kind: true = done (olive), false = error (red), "info" = plain output (cream), "announce" = a server message
local COLOURS = { ok = "#B5C77A", bad = "#FF7060", info = "#ECE8DA", announce = "#8A9C4A" }
local channel
feedback.OnClientEvent:Connect(function(msg: string, kind)
	channel = channel or TextChatService:WaitForChild("TextChannels"):WaitForChild("RBXSystem")
	local key = kind == true and "ok" or (kind == false and "bad") or (kind == "announce" and "announce") or "info"
	local tag = key == "announce" and "[Server]" or "[Admin]"
	channel:DisplaySystemMessage(('<font color="%s"><b>%s</b> %s</font>'):format(COLOURS[key], tag, escape(tostring(msg))))
end)
]=]
--@@END SOURCES

local TAG = "MatchInstall"
-- a container made by this install (Folder); returns it
local function ensureFolder(parent: Instance, name: string, attrs)
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder"); f.Name = name; f:SetAttribute(TAG, true); f.Parent = parent
		say("folder", f:GetFullName(), "created")
	end
	for k, v in (attrs or {}) do f:SetAttribute(k, v) end
	return f
end
-- a script made by this install (an existing one of the same name is only overwritten when it is ours)
local function ensureScript(parent: Instance, name: string, class: string, src: string)
	local s = parent:FindFirstChild(name)
	if s and (s.ClassName ~= class or not s:GetAttribute(TAG)) then
		if s:GetAttribute(TAG) then
			s:Destroy(); s = nil
		elseif s.Source == src then
			say(class, s:GetFullName(), "up to date (made elsewhere, identical)")
			return s
		else
			say("WARN", s:GetFullName(), "exists and is not ours: skipped")
			return s
		end
	end
	if not s then s = Instance.new(class); s.Name = name; s:SetAttribute(TAG, true); s.Parent = parent end
	if s.Source ~= src then s.Source = src; say(class, s:GetFullName(), "written") else say(class, s:GetFullName(), "up to date") end
	if s:IsA("BaseScript") then s.Disabled = false end
	return s
end

local function replaceTargets()
	local m = managers()
	local cfg = RS.Modules.Shared:FindFirstChild("Config")
	return {
		{ m and m:FindFirstChild("RoundManager"), "RoundManager", "RoundManager" },
		{ cfg and cfg:FindFirstChild("MatchConfig"), "MatchConfig", "MatchConfig" },
	}
end

if UNDO then
	for _, r in replaceTargets() do
		local s, name = r[1], r[2]
		local bak = bin:FindFirstChild("MATCH_" .. name .. "_Orig")
		if s and bak then s.Source = bak.Source; bak:Destroy(); say("restored", name) elseif s then say("WARN no backup for", name) end
	end
	-- everything this install made, deepest first
	local made = {}
	for _, root in { RS, SSS, SP } do
		for _, d in root:GetDescendants() do if d:GetAttribute(TAG) then table.insert(made, d) end end
	end
	table.sort(made, function(a, b) return #a:GetFullName() > #b:GetFullName() end)
	for _, d in made do
		if d.Parent then say("removed", d:GetFullName()); d:Destroy() end
	end
else
	if next(SOURCES) == nil then error("no embedded sources: run python tools/match_place_build.py first") end
	local shared = RS.Modules.Shared
	local cfg = shared.Config
	ensureScript(shared, "MapRegistry", "ModuleScript", SOURCES.MapRegistry)
	ensureScript(shared, "MatchState", "ModuleScript", SOURCES.MatchState)
	ensureScript(cfg, "LobbyConfig", "ModuleScript", SOURCES.LobbyConfig)
	local sssShared = ensureFolder(SSS, "Shared")
	ensureScript(sssShared, "MatchCore", "ModuleScript", SOURCES.MatchCore)
	local maps = ensureFolder(RS, "DuelMaps")
	local wh = ensureFolder(maps, "Warehouse", { DisplayName = "Warehouse", Image = "", Modes = "1v1" })
	ensureScript(wh, "MapInfo", "ModuleScript", SOURCES.MapInfo_Warehouse)
	-- the admin framework
	local fw = ensureFolder(SSS, "AdminFramework")
	for _, n in { "Config", "Permissions", "Args", "DataAdapter", "Audit", "Core" } do ensureScript(fw, n, "ModuleScript", SOURCES["Admin_" .. n]) end
	local cmds = ensureFolder(fw, "Commands")
	for _, n in { "Data", "Player", "Duel", "World", "Debug", "Legacy" } do ensureScript(cmds, n, "ModuleScript", SOURCES["Cmd_" .. n]) end
	ensureScript(SSS, "AdminCommands", "Script", SOURCES.AdminCommands)
	ensureScript(SP.StarterPlayerScripts, "AdminFeedback", "LocalScript", SOURCES.AdminFeedback)
	-- [MATCH] whole-source replacements
	for _, r in replaceTargets() do
		local s, name, key = r[1], r[2], r[3]
		if not s then say("WARN missing", name)
		else
			if not bin:FindFirstChild("MATCH_" .. name .. "_Orig") and s.Source ~= SOURCES[key] then
				local b = s:Clone(); b.Name = "MATCH_" .. name .. "_Orig"; b:ClearAllChildren(); b.Parent = bin
				say("backup", b.Name)
			end
			if s.Source ~= SOURCES[key] then s.Source = SOURCES[key]; say("replaced", name) else say(name, "up to date") end
		end
	end
end
if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
return table.concat(log, "\n")
