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
-- Phase 2 (2026-10-16, notes/lobby_duels_phase2.md): new ServerScriptService.Shared.ArenaShootables (per-arena doors / barrels /
--   valves / blasts); [DUEL] edits: CombatManager / MeleeManager WeaponFired + MeleeHit only to the match's audience
--   (MatchState.FireScoped), GadgetManager (smoke / blast rays against the arena's Solid layer, effects in the arena's FX folder,
--   FlashDetonated scoped, charges spent in real matches, ClearIn per arena), ShootableManager stub (shots / frags routed to
--   the arena: LobbyDuelManager.OnShot / Explode).
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
-- Loading (C.LoadingTime; opts.skipLoading) -> Intro (opts.introTime, optional) -> MapVote (C.MapVoteTime; skipped when C.DuelMapVote == false or no map is eligible)
-- -> MapChosen -> Loadout (C.LoadoutTime, ends early when every present player member is Ready).
-- opts.maps = the eligible maps (registry entries); opts.voters() -> number of members who can vote;
-- opts.onMapChosen(id) is called before the Loadout phase starts. Returns the chosen map id (nil = no eligible map).
function MatchCore.runPreMatch(ctx, opts)
	local C, s = ctx.config, ctx.state
	local HttpService = game:GetService("HttpService")
	-- opts.skipLoading: the caller ran its own Loading (the match place: arrival + every client's "Loaded")
	if not opts.skipLoading then
		MatchCore.setState(ctx, "Loading", C.LoadingTime or 3)
		MatchCore.waitPhase(ctx, C.LoadingTime or 3)
	end
	-- opts.introTime: a short "Intro" phase (the match place's logo crumble) before the vote; the UI ignores the name
	if opts.introTime and opts.introTime > 0 and not MatchCore.forfeitSide(ctx) then
		MatchCore.setState(ctx, "Intro", opts.introTime)
		MatchCore.waitPhase(ctx, opts.introTime)
	end
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
SOURCES.ArenaShootables = [=[-- ServerScriptService/Shared/ArenaShootables (ModuleScript): doors, fire barrels, steam valves and explosions of ONE
-- lobby duel arena (lobby duels phase 2, 2026-10-16). Per-arena port of the match place's ShootableManager + DoorManager.
-- LobbyDuelManager makes one per match (ArenaShootables.new(arena)) once the Solid layer is in Workspace; the lobby's
-- ShootableManager stub routes shots / frag blasts to the arena that contains them.
--
-- Server state lives on the arena's Solid models (they replicate, and only this match's clients have the Visual twin):
--   Interactive.<Door>   (child "Shutter")              DoorOpen (bool), DoorMoving (bool), DoorAt (server time the roll started),
--                                                       DoorHeight. The Solid shutter is tweened here (collision); the
--                                                       client tweens its Visual shutter from the same attributes.
--   Shootables.<Barrel>  (attr Shootable = "FireBarrel") Exploded (bool), FireUntil (server time, burning ground)
--   Shootables.<Valve>   (attr Shootable = "SteamValve") SteamUntil (server time; SteamMask reads it on server and client)
-- Effects: Events.Combat.Explosion goes only to this match's players + spectators (MatchState.FireScoped); burning ground,
-- steam jets and door motion are drawn by the clients' ArenaLoader. Burning players carry the match place's BurnFX.
-- Nothing here names a map: doors / shootables are found by the conventions above (the Warehouse blueprint).
--
-- arena = { id, solid (Model in Workspace), origin (Vector3), info (MapInfo), visual (template Model), state (Configuration),
--           characters () -> {Model}, isMember (Player) -> bool, rayFilter {Instance} }
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage.Modules.Shared
local Config = require(Shared.Config.ShootableConfig)
local SoundTrim = require(Shared.SoundTrim)
local MatchState = require(Shared.MatchState)
local Combat = ReplicatedStorage.Events.Combat

local FLAT = Vector3.new(1, 0, 1)
local FIRE_TEX = "rbxasset://textures/particles/fire_main.dds"
local HISS = "rbxassetid://4772620521"
local ROLL_TIME = 1.6

local ArenaShootables = {}
ArenaShootables.__index = ArenaShootables
ArenaShootables.ROLL_TIME = ROLL_TIME

local function now() return workspace:GetServerTimeNow() end

-- Does segment a->b pass through the box? (match place ShootableManager)
local function segmentHitsBox(a: Vector3, b: Vector3, cf: CFrame, size: Vector3, pad: number): (boolean, number)
	local la, lb = cf:PointToObjectSpace(a), cf:PointToObjectSpace(b)
	local d = lb - la
	local tmin, tmax = 0, 1
	local half = size / 2 + Vector3.one * pad
	for _, axis in { "X", "Y", "Z" } do
		local o, v, h = la[axis], d[axis], half[axis]
		if math.abs(v) < 1e-6 then
			if o < -h or o > h then return false, 0 end
		else
			local t1, t2 = (-h - o) / v, (h - o) / v
			if t1 > t2 then t1, t2 = t2, t1 end
			tmin, tmax = math.max(tmin, t1), math.min(tmax, t2)
			if tmin > tmax then return false, 0 end
		end
	end
	return true, tmin
end

local function flameEmitter(parent: Instance, size: number, rate: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = FIRE_TEX
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 236, 170)),
		ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 140, 40)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 30, 10)),
	})
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.6), NumberSequenceKeypoint.new(0.4, size), NumberSequenceKeypoint.new(1, size * 0.2) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(0.7, 0.45), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.35, 0.7)
	e.Speed = NumberRange.new(2, 5)
	e.SpreadAngle = Vector2.new(15, 15)
	e.Acceleration = Vector3.new(0, 7, 0)
	e.RotSpeed = NumberRange.new(-90, 90)
	e.Rotation = NumberRange.new(0, 360)
	e.EmissionDirection = Enum.NormalId.Top
	e.Rate = rate
	e.Parent = parent
	return e
end

-- // Construction ----------------------------------------------------------------------------------------------------------
function ArenaShootables.new(arena)
	local self = setmetatable({ arena = arena, doors = {}, barrels = {}, valves = {}, fires = {}, burning = {}, conns = {} }, ArenaShootables)
	local solid = arena.solid
	self.rayParams = RaycastParams.new()
	self.rayParams.FilterType = Enum.RaycastFilterType.Include
	self.rayParams.FilterDescendantsInstances = arena.rayFilter or { solid }

	-- doors: Interactive.<Door> with a Shutter; the prompt sits where the Visual layer has the door's Panel
	local inter = solid:FindFirstChild("Interactive")
	local vInter = arena.visual and arena.visual:FindFirstChild("Interactive")
	for _, model in (inter and inter:GetChildren() or {}) do
		local shutter = model:FindFirstChild("Shutter")
		if shutter and shutter:IsA("BasePart") then
			local vPanel = vInter and vInter:FindFirstChild(model.Name) and vInter[model.Name]:FindFirstChild("Panel")
			local panel = Instance.new("Part")
			panel.Name = "PanelPrompt"
			panel.Anchored, panel.CanCollide, panel.CanQuery, panel.CanTouch, panel.CastShadow = true, false, false, false, false
			panel.Transparency = 1
			panel.Size = vPanel and vPanel.Size or Vector3.new(1, 1, 0.3)
			panel.CFrame = vPanel and (CFrame.new(arena.origin) * vPanel.CFrame) or shutter.CFrame
			panel.Parent = model
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Open"
			prompt.ObjectText = "Shutter"
			prompt.KeyboardKeyCode = Enum.KeyCode.F
			prompt.HoldDuration = 0.25
			prompt.MaxActivationDistance = 8
			prompt.RequiresLineOfSight = false
			prompt.Parent = panel
			local door = { model = model, shutter = shutter, closedCF = shutter.CFrame, height = model:GetAttribute("OpenHeight") or 10,
				prompt = prompt, open = false, busy = false }
			model:SetAttribute("DoorHeight", door.height)
			model:SetAttribute("DoorOpen", false)
			model:SetAttribute("DoorMoving", false)
			table.insert(self.conns, prompt.Triggered:Connect(function(player)
				-- only this match's live players can work its doors
				if arena.isMember(player) and player:GetAttribute("Alive") ~= false then self:SetDoor(door, not door.open) end
			end))
			table.insert(self.doors, door)
		end
	end

	-- shootables: Shootables.<Model> with attribute Shootable (FireBarrel / SteamValve); the name is the fallback
	local shoot = solid:FindFirstChild("Shootables")
	for _, model in (shoot and shoot:GetChildren() or {}) do
		local kind = model:GetAttribute("Shootable") or (model.Name:find("FireBarrel") and "FireBarrel") or (model.Name:find("SteamValve") and "SteamValve")
		if kind == "FireBarrel" and model:FindFirstChild("Body") then
			table.insert(self.barrels, { model = model, exploded = false, saved = {} })
		elseif kind == "SteamValve" then
			local parts = {}
			for _, p in model:GetDescendants() do if p:IsA("BasePart") then table.insert(parts, p) end end
			if #parts > 0 then table.insert(self.valves, { model = model, parts = parts, used = false }) end
		end
	end
	return self
end

function ArenaShootables:Counts()
	return #self.doors, #self.barrels, #self.valves
end

-- // Doors ------------------------------------------------------------------------------------------------------------------
function ArenaShootables:SetDoor(door, open: boolean)
	if door.open == open or door.busy or self.dead then return end
	door.busy = true
	door.open = open
	door.prompt.Enabled = false
	door.model:SetAttribute("DoorAt", now())
	door.model:SetAttribute("DoorMoving", true)
	door.model:SetAttribute("DoorOpen", open)
	local goal = open and door.closedCF + Vector3.new(0, door.height, 0) or door.closedCF
	local tween = TweenService:Create(door.shutter, TweenInfo.new(ROLL_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { CFrame = goal })
	tween:Play()
	task.spawn(function()
		tween.Completed:Wait()
		if self.dead then return end
		door.model:SetAttribute("DoorMoving", false)
		door.prompt.ActionText = open and "Close" or "Open"
		door.prompt.Enabled = true
		door.busy = false
	end)
end

-- // Burning --------------------------------------------------------------------------------------------------------------------
function ArenaShootables:hurt(character: Model, amount: number, attacker: Player?, from: Vector3?, kind: string?)
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 or amount <= 0 then return end
	-- no friendly fire in a live match (your own blast still hurts you); only this match's bodies are ever passed in
	local owner = Players:GetPlayerFromCharacter(character) or character
	if attacker and owner ~= attacker and self.arena.state:GetAttribute("LiveMatch") and owner:GetAttribute("Team") ~= nil
		and owner:GetAttribute("Team") == attacker:GetAttribute("Team") then return end
	hum:SetAttribute("LastAttacker", attacker and attacker.UserId or 0)
	hum:SetAttribute("LastAttackKind", kind or "Blast")
	hum:SetAttribute("LastHitZone", nil)
	hum:TakeDamage(amount)
	local victim = Players:GetPlayerFromCharacter(character)
	if victim and from then Combat.DamageTaken:FireClient(victim, from, amount) end
	if kind ~= "Burn" and attacker and Combat:FindFirstChild("HitConfirm") and victim ~= attacker then
		Combat.HitConfirm:FireClient(attacker, "Body", amount, hum.Health <= 0)
	end
end

function ArenaShootables:ignite(character: Model, attacker: Player?, seconds: number?)
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 or self.dead then return end
	local untilT = os.clock() + (seconds or Config.Burn.Time)
	local entry = self.burning[character]
	if entry then entry.untilT = math.max(entry.untilT, untilT) return end
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("HumanoidRootPart")
	if not torso then return end
	local holder = Instance.new("Attachment")
	holder.Name = "BurnFX"
	holder.Parent = torso
	flameEmitter(holder, 2.2, 45)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 140, 50); light.Brightness = 2.5; light.Range = 12
	light.Parent = holder
	local roar = Instance.new("Sound")
	roar.SoundId = HISS; roar.PlaybackSpeed = 0.45; roar.Volume = 0.5; roar.Looped = true; roar.RollOffMaxDistance = 70
	roar.Parent = holder
	SoundTrim.Play(roar)
	character:SetAttribute("Burning", true)
	self.burning[character] = { untilT = untilT, attacker = attacker }
end

function ArenaShootables:extinguish(character: Model)
	self.burning[character] = nil
	if character.Parent then character:SetAttribute("Burning", nil) end
	for _, d in character:GetDescendants() do
		if d.Name == "BurnFX" then
			for _, e in d:GetChildren() do if e:IsA("ParticleEmitter") then e.Enabled = false end end
			Debris:AddItem(d, 1)
			d.Name = "BurnFXOff"
		end
	end
end

-- // Explosions -----------------------------------------------------------------------------------------------------------------
function ArenaShootables:wallBetween(a: Vector3, b: Vector3): boolean
	local hit = workspace:Raycast(a, b - a, self.rayParams)
	return hit ~= nil and hit.Instance.Name ~= "COLP_Floor" and math.abs(hit.Normal.Y) < 0.9
end

function ArenaShootables:Explode(position: Vector3, kind: string, attacker: Player?, source)
	local cfg = Config.Explosions[kind]
	if not cfg or self.dead then return end
	MatchState.FireScoped(Combat.Explosion, self.arena.id, position, kind)
	local gadgets = shared.Get and shared.Get("GadgetManager")
	if gadgets and gadgets.PushSmoke then gadgets.PushSmoke(position, cfg.Radius * 1.5) end
	local from = position + Vector3.new(0, 1, 0)
	for _, character in self.arena.characters() do
		local root = character:FindFirstChild("HumanoidRootPart")
		local hum = character:FindFirstChildOfClass("Humanoid")
		if root and hum and hum.Health > 0 then
			local d = (root.Position - position).Magnitude
			local head = character:FindFirstChild("Head")
			local exposed = not self:wallBetween(from, root.Position) or (head and not self:wallBetween(from, head.Position))
			if d <= cfg.Radius and exposed then
				local amount
				if d <= cfg.KillRadius then
					amount = hum.MaxHealth * 3
				else
					local t = (d - cfg.KillRadius) / (cfg.Radius - cfg.KillRadius)
					amount = cfg.MaxDamage + (cfg.MinDamage - cfg.MaxDamage) * t
				end
				self:hurt(character, amount, attacker, position, kind)
				if cfg.Ignite and hum.Health > 0 then self:ignite(character, attacker) end
			end
		end
	end
	if cfg.FireRadius then
		-- burning ground: logic here, the flames are drawn by the match's clients from FireUntil / FireAt
		local untilT = os.clock() + cfg.FireTime
		table.insert(self.fires, { position = position - Vector3.new(0, 1, 0), radius = cfg.FireRadius, untilT = untilT, attacker = attacker })
		if source then
			source:SetAttribute("FireAt", position)
			source:SetAttribute("FireRadius", cfg.FireRadius)
			source:SetAttribute("FireUntil", now() + cfg.FireTime)
		end
	end
	if cfg.Chain then
		for _, b in self.barrels do
			if not b.exploded and (b.model.Body.Position - position).Magnitude <= cfg.Radius then
				task.delay(0.12 + math.random() * 0.12, function() self:ExplodeBarrel(b, attacker) end)
			end
		end
	end
end

function ArenaShootables:ExplodeBarrel(b, attacker: Player?)
	if b.exploded or self.dead then return end
	b.exploded = true
	local position = b.model.Body.Position
	for _, p in b.model:GetDescendants() do
		if p:IsA("BasePart") then
			b.saved[p] = b.saved[p] or { p.CanCollide, p.CanQuery }
			p.CanCollide, p.CanQuery = false, false
		end
	end
	b.model:SetAttribute("Exploded", true)
	self:Explode(position, "Barrel", attacker, b.model)
end

function ArenaShootables:ActivateValve(v, shooter: Player?)
	if v.used or self.dead then return end
	v.used = true
	v.model:SetAttribute("SteamUntil", now() + Config.Steam.Duration)
end

-- // Shots: the first shootable along the bullet's path reacts --------------------------------------------------------------------
function ArenaShootables:OnShot(origin: Vector3, endPos: Vector3, shooter: Player?)
	if self.dead then return end
	-- the bullet stops at the first solid thing (walls, cover): nothing behind it reacts
	local dir = endPos - origin
	if dir.Magnitude > 0.05 then
		local hit = workspace:Raycast(origin, dir, self.rayParams)
		if hit then endPos = hit.Position + dir.Unit * 0.3 end
	end
	local best, bestT, bestKind = nil, math.huge, nil
	for _, v in self.valves do
		if not v.used then
			for _, p in v.parts do
				local hit, t = segmentHitsBox(origin, endPos, p.CFrame, p.Size, Config.Steam.HitPadding)
				if hit and t < bestT then best, bestT, bestKind = v, t, "Valve" end
			end
		end
	end
	for _, b in self.barrels do
		if not b.exploded then
			local body = b.model.Body
			local hit, t = segmentHitsBox(origin, endPos, body.CFrame, body.Size, 0.15)
			if hit and t < bestT then best, bestT, bestKind = b, t, "Barrel" end
		end
	end
	if bestKind == "Valve" then self:ActivateValve(best, shooter)
	elseif bestKind == "Barrel" then self:ExplodeBarrel(best, shooter) end
	return bestKind
end

-- // Per frame: burning players and standing in fire ----------------------------------------------------------------------------
function ArenaShootables:Step(dt: number)
	if self.dead then return end
	local clock = os.clock()
	for character, entry in self.burning do
		local hum = character:FindFirstChildOfClass("Humanoid")
		if not character.Parent or not hum or hum.Health <= 0 or clock > entry.untilT then
			self:extinguish(character)
		else
			self:hurt(character, Config.Burn.Dps * dt, entry.attacker, nil, "Burn")
		end
	end
	self.acc = (self.acc or 0) + dt
	if self.acc >= 0.2 and #self.fires > 0 then
		self.acc = 0
		for i = #self.fires, 1, -1 do
			local fire = self.fires[i]
			if clock > fire.untilT then
				table.remove(self.fires, i)
			else
				for _, character in self.arena.characters() do
					local root = character:FindFirstChild("HumanoidRootPart")
					if root then
						local off = root.Position - fire.position
						if (off * FLAT).Magnitude <= fire.radius * 0.85 and math.abs(off.Y) < 5 then self:ignite(character, fire.attacker, 1.5) end
					end
				end
			end
		end
	end
end

-- // New round: everything back (barrels whole, valves ready, doors shut, no fire) --------------------------------------------------
function ArenaShootables:ResetAll()
	for _, b in self.barrels do
		for p, s in b.saved do if p.Parent then p.CanCollide, p.CanQuery = s[1], s[2] end end
		b.saved = {}
		b.exploded = false
		b.model:SetAttribute("Exploded", nil)
		b.model:SetAttribute("FireUntil", nil)
	end
	for _, v in self.valves do
		v.used = false
		v.model:SetAttribute("SteamUntil", nil)
	end
	self.fires = {}
	for character in self.burning do self:extinguish(character) end
	for _, door in self.doors do
		door.open, door.busy = false, false
		door.shutter.CFrame = door.closedCF
		door.prompt.ActionText = "Open"
		door.prompt.Enabled = true
		door.model:SetAttribute("DoorOpen", false)
		door.model:SetAttribute("DoorMoving", false)
		door.model:SetAttribute("DoorAt", now())
	end
end

function ArenaShootables:Destroy()
	self.dead = true
	for character in self.burning do self:extinguish(character) end
	for _, c in self.conns do c:Disconnect() end
end

-- // Light helpers for LobbyDuelManager ---------------------------------------------------------------------------------------------
function ArenaShootables:Contains(position: Vector3): boolean
	local size = self.arena.info and self.arena.info.Size or Vector3.new(200, 60, 200)
	local d = position - self.arena.origin
	return math.abs(d.X) <= size.X / 2 + 20 and math.abs(d.Z) <= size.Z / 2 + 20 and d.Y > -40 and d.Y < size.Y + 60
end

return ArenaShootables
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
-- Studio test: ReplicatedStorage attribute DuelTestSolo = true lets one player start a pad alone; empty places on both teams
-- get server test bots (R15 rigs, tag Bot, DuelMatch on the model) - LobbyDuelManager._TestSolo / _TestBots. Never live.
-- Phase 2 (2026-10-16): per-arena doors / barrels / valves (ArenaShootables), gadget rays + FX per arena (RayFilter / FXFolder,
-- read by the [DUEL] GadgetManager / ShootableManager edits), effects only to the match's audience (MatchState.FireScoped),
-- no duelist character is ever seen at the lobby spawn (every new character is pivoted to the Hold before it can replicate,
-- and a dead duelist is re-spawned into the Hold by the server before Roblox's own auto respawn), the reward cooldown
-- per opponent pair is saved in the profile (DuelPairs), test maps can be added at runtime (MapRegistry.Changed).
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
local ArenaShootables = require(ServerScriptService.Shared.ArenaShootables)
local PlayerStore = require(ServerScriptService.Data.PlayerStore)

local IS_STUDIO = RunService:IsStudio()
local C = MatchConfig
local manager = {}

local stateFolder, arenaFolder, flow, announceEv, resultsEv
local slots = {}      -- [n] = matchId or nil
local matches = {}    -- [matchId] = match record
local byPlayer = {}   -- [Player] = { match, member }
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
local HOLD_DEPTH = 60
local function holdFrame(match, i: number): CFrame
	return CFrame.new(match.origin + Vector3.new((i - 1) * 4, -HOLD_DEPTH + 3, 0))
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
	rig.Name = "DuelBot_" .. match.id .. "_" .. m.index
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

-- the hold, but facing the member's round spawn: the client camera takes its starting yaw from a new body's first frame,
-- so a body first seen facing -Z (CFrame.new) started every round looking backwards ([MATCH] spawn camera, 2026-10-16)
local function facingHold(match, m): CFrame
	local cf = holdFrame(match, m.index)
	if match.solid and m.team then
		cf = CFrame.new(cf.Position) * spawnFrame(match, m.team, table.find(match.teams[m.team], m) or 1).Rotation
	end
	return cf
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
	-- what smoke floods and blasts treat as walls: MapInfo.RayFolders, else CollisionProxies, else the whole Solid layer
	local filter = {}
	for _, name in (match.map.RayFolders or { "CollisionProxies" }) do
		local f = clone:FindFirstChild(name)
		if f then table.insert(filter, f) end
	end
	match.rayFilter = #filter > 0 and filter or { clone }
	match.shoot = ArenaShootables.new({
		id = match.id, solid = clone, origin = match.origin, info = match.map, state = match.state,
		visual = match.map.Folder and match.map.Folder:FindFirstChild("Visual"), rayFilter = match.rayFilter,
		characters = function()
			local out = {}
			for _, list in match.teams do
				for _, m in list do
					local c = not m.left and MatchCore.character(m)
					if c and c.Parent then table.insert(out, c) end
				end
			end
			return out
		end,
		isMember = function(p) local r = byPlayer[p]; return r ~= nil and r.match == match end,
	})
	local d, b, v = match.shoot:Counts()
	print(`[LobbyDuelManager] {match.id} arena {match.map.Id}: {d} doors, {b} barrels, {v} valves`)
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
	-- if anything replaced the character meanwhile, place the current one
	if p.Character and p.Character ~= character then character = p.Character end
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

-- one reward per opponent pair per DuelRewardCooldown, kept in the profile so it holds across lobby servers:
-- data.DuelPairs = { ["<opponent ids sorted, comma separated>"] = os.time() of the last paid match }. Entries older than the
-- cooldown are dropped on every write, so the table stays a handful of keys.
local function pairKey(match, side: string): string
	local others = {}
	for s, list in match.teams do if s ~= side then for _, o in list do table.insert(others, o.userId) end end end
	table.sort(others)
	return table.concat(others, ",")
end
local function rewardCooling(data, key: string): boolean
	local pairs_ = data and type(data.DuelPairs) == "table" and data.DuelPairs
	local last = pairs_ and pairs_[key]
	return type(last) == "number" and os.time() - last < (C.DuelRewardCooldown or 600)
end
local function rewardMark(p: Player, data, key: string)
	local keep = {}
	local cd = C.DuelRewardCooldown or 600
	for k, t in (type(data.DuelPairs) == "table" and data.DuelPairs or {}) do
		if type(t) == "number" and os.time() - t < cd then keep[k] = t end
	end
	keep[key] = os.time()
	PlayerStore.Set(p, { "DuelPairs" }, keep)
end
manager._rewardCooling, manager._rewardMark, manager._pairKey = rewardCooling, rewardMark, pairKey

local function award(match, m, side: string, winner: string?, forfeit: boolean)
	local p = m.player
	local data = PlayerStore.Get(p)
	local summary = MatchCore.summary(match.ctx, m, side, winner, forfeit, data and data.Passes)
	summary.MatchId = match.id
	-- one reward per opponent pair per DuelRewardCooldown (anti-farming); a match with a test bot never pays
	local key = pairKey(match, side)
	local cooling = rewardCooling(data, key)
	if match.hasBot or cooling or not data then
		summary.XP, summary.Scissors, summary.GunXP = 0, 0, 0
		summary.RewardCooldown = cooling or nil
		summary.TestMatch = match.hasBot or nil
	else
		rewardMark(p, data, key)
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
	if match.shoot then match.shoot:Destroy() end
	local gadgets = shared.Get and shared.Get("GadgetManager")
	if gadgets and gadgets.ClearIn and match.fx then pcall(gadgets.ClearIn, match.fx) end
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

	-- test bots fill every empty place up to the mode's team size (Studio + DuelTestSolo only)
	local size = tonumber(string.match(mode, "^(%d+)v")) or 1
	for _, side in { "A", "B" } do
		while #teams[side] < size and IS_STUDIO and ReplicatedStorage:GetAttribute("DuelTestSolo") == true do
			table.insert(teams[side], { bot = true })
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
	hold.Size = Vector3.new(40, 1, 12); hold.CFrame = CFrame.new(match.origin + Vector3.new(6, -HOLD_DEPTH, 0))
	hold.Parent = arena
	-- server effects of this arena (smoke cells, grenades, flash pops) live here and are cleared per round
	local fx = Instance.new("Folder"); fx.Name = "FX"; fx.Parent = arena
	match.fx = fx

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
			-- this arena only: barrels whole, valves ready, doors shut, no fire, no smoke / grenades left
			if match.shoot then match.shoot:ResetAll() end
			local gadgets = shared.Get and shared.Get("GadgetManager")
			if gadgets and gadgets.ClearIn then pcall(gadgets.ClearIn, match.fx) end
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

-- a player disconnects: not present any more (their side forfeits if nobody is left on it); nothing to send back
function manager._OnRemoving(p: Player)
	local rec = byPlayer[p]
	if rec then
		rec.member.left = true; rec.member.returned = true; byPlayer[p] = nil
		print(`[LobbyDuelManager] {p.Name} left {rec.match.id} (disconnect)`)
	end
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
manager._spawnLog = {} -- Studio test evidence: where each duelist character first appeared (respawn flash check)
-- Roblox's own respawn (CharacterAutoLoads, RespawnTime 3) would load a dead duelist at the lobby spawn and could replace the
-- next round's character. Player.RespawnLocation is no help (tested: a disabled or team-only SpawnLocation is ignored, an
-- enabled neutral one would catch lobby joiners). So: (1) every new character of a duelist is pivoted into the Hold inside
-- CharacterAdded, before any yield (often before it is even parented), so its first replicated frame is already there;
-- (2) BENCH_DELAY after a death the server loads the dead duelist itself (into the Hold), well before RespawnTime, so the
-- auto respawn never fires for that death (the dead character is gone).
local BENCH_DELAY = 1.6
local function onCharacterAdded(player: Player, character: Model)
	local rec = byPlayer[player]
	if not rec or rec.member.returned then return end
	local match, m = rec.match, rec.member
	local first = character:GetPivot().Position
	local parented = character.Parent ~= nil
	-- no yield before the pivot
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then root.Anchored = true end
	character:PivotTo(facingHold(match, m))
	if IS_STUDIO then
		table.insert(manager._spawnLog, { name = player.Name, match = match.id, at = first, round = m.spawning == true,
			parented = parented, holdY = match.origin.Y - HOLD_DEPTH, auto = m.benching ~= true and m.spawning ~= true })
	end
	m.benching = nil
	local hum = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	if hum then
		hum.Died:Once(function()
			task.delay(BENCH_DELAY, function()
				if byPlayer[player] ~= rec or m.returned or m.spawning or player.Character ~= character then return end
				-- cleared by onCharacterAdded (it runs deferred, after LoadCharacter returns)
				m.benching = true
				pcall(player.LoadCharacter, player)
			end)
		end)
	end
	if m.spawning then return end -- a round spawn: spawnMember places it
	if not root then
		root = character:WaitForChild("HumanoidRootPart", 5)
		if not root or byPlayer[player] ~= rec then return end
		root.Anchored = true
		character:PivotTo(facingHold(match, m))
	end
	player:SetAttribute("Alive", false)
	task.delay(0.6, function() if byPlayer[player] == rec and not m.spawning then stripTools(player) end end)
end

-- // Arena lookups for the [DUEL] edits in GadgetManager / ShootableManager --------------------------------------------------------
local function matchAt(position: Vector3)
	if typeof(position) ~= "Vector3" then return nil end
	for _, match in matches do
		if match.shoot and match.shoot:Contains(position) then return match end
	end
	return nil
end
manager.MatchAt = matchAt
-- the instances a smoke flood / blast ray should hit at this position (nil = not in an arena: the caller's own map)
function manager.RayFilter(position: Vector3)
	local m = matchAt(position)
	return m and m.rayFilter or nil
end
-- where a server effect created at this position goes (nil = Workspace as before)
function manager.FXFolder(position: Vector3)
	local m = matchAt(position)
	return m and m.fx or nil
end
-- a shot fired inside an arena: that arena's barrels / valves react. Returns true when it was an arena shot.
function manager.OnShot(origin: Vector3, endPos: Vector3, shooter: Player?): boolean
	local m = matchAt(origin)
	if not m then return false end
	if m.shoot then m.shoot:OnShot(origin, endPos, shooter) end
	return true
end
-- a blast (frag grenade) inside an arena; outside every arena nothing happens (the lobby has no explosions)
function manager.Explode(position: Vector3, kind: string, attacker: Player?): boolean
	local m = matchAt(position)
	if not (m and m.shoot) then return false end
	m.shoot:Explode(position, kind, attacker)
	return true
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

	local combat = events:FindFirstChild("Combat")
	if combat and not combat:FindFirstChild("Explosion") then
		local r = Instance.new("RemoteEvent"); r.Name = "Explosion"; r.Parent = combat
	end
	flow.OnServerEvent:Connect(onFlow)
	local function hook(p: Player)
		p.CharacterAdded:Connect(function(c) onCharacterAdded(p, c) end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in Players:GetPlayers() do hook(p) end
	Players.PlayerRemoving:Connect(function(p) manager._OnRemoving(p) end)

	-- pads whose mode has no map can't start an in-lobby match (NoMap; PadBoards shows "No maps yet for <mode>").
	-- Re-checked whenever the registry changes (a map added or removed at runtime).
	local function refreshPads()
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
	end
	task.spawn(refreshPads)
	MapRegistry.Changed:Connect(function() task.defer(refreshPads) end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		for _, match in matches do if match.shoot then match.shoot:Step(dt) end end
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
-- Studio only: a bot-vs-bot match on the next free slot (concurrency / ARENAS FULL / team-size tests)
function manager._TestBots(mode: string?)
	if not IS_STUDIO then return false, "Studio only" end
	ReplicatedStorage:SetAttribute("DuelTestSolo", true)
	return manager.StartMatch(nil, mode or "1v1", { A = {}, B = {} })
end
-- Studio only: kill a member as if `killerUserId` shot them (sets the same Humanoid attributes the combat managers set)
function manager._TestKill(matchId: string, victimUserId: number, killerUserId: number?, headshot: boolean?)
	local match = matches[matchId]
	if not match then return false, "no match" end
	for _, list in match.teams do
		for _, m in list do
			if m.userId == victimUserId then
				local hum = MatchCore.humanoid(m)
				if not hum then return false, "no humanoid" end
				hum:SetAttribute("LastAttacker", killerUserId or 0)
				hum:SetAttribute("LastAttackKind", "Gun")
				hum:SetAttribute("LastHitZone", headshot and "Head" or "Body")
				hum.Health = 0
				return true
			end
		end
	end
	return false, "no member " .. tostring(victimUserId)
end
-- Studio only: every member of one side leaves (forfeit)
function manager._TestForfeit(matchId: string, side: string)
	local match = matches[matchId]
	if not match then return false end
	for _, m in match.teams[side] do m.left = true; if m.player then returnToLobby(match, m) end end
	return true
end
manager._matches = matches
manager._slots = slots

-- Studio only: test commands from the MCP / command bar, which run in another Lua VM (no shared.Get, a different require
-- cache). ServerStorage.DuelTestHook:Invoke(cmd, ...) runs them in the game's VM. Never created in a live server.
local function testHook(cmd: string, a, b, c, d)
	if cmd == "bots" then return manager._TestBots(a)
	elseif cmd == "kill" then return manager._TestKill(a, b, c, d)
	elseif cmd == "forfeit" then return manager._TestForfeit(a, b)
	elseif cmd == "config" then local old = C[a]; C[a] = b; return old
	elseif cmd == "removing" then local p = Players:GetPlayerByUserId(a); if p then manager._OnRemoving(p) end; return p ~= nil
	elseif cmd == "shot" then return manager.OnShot(a, b, c and Players:GetPlayerByUserId(c) or nil)
	elseif cmd == "explode" then return manager.Explode(a, b, c and Players:GetPlayerByUserId(c) or nil)
	elseif cmd == "door" then
		local m = matches[a]
		for _, door in (m and m.shoot and m.shoot.doors or {}) do if door.model.Name == b then m.shoot:SetDoor(door, c == true); return true end end
		return false
	elseif cmd == "spawnlog" then
		local out = {}
		for _, e in manager._spawnLog do table.insert(out, string.format("%s %s %s first y=%.1f x=%.0f parented=%s", e.name, e.match, e.round and "round" or (e.auto and "AUTO" or "bench"), e.at.Y, e.at.X, tostring(e.parented))) end
		return table.concat(out, " | ")
	elseif cmd == "reward" then
		local p = Players:GetPlayerByUserId(a)
		local data = p and PlayerStore.Get(p)
		if not data then return "no profile" end
		local before = rewardCooling(data, b)
		if c then rewardMark(p, data, b) end
		return { coolingBefore = before, coolingAfter = rewardCooling(PlayerStore.Get(p), b), pairs = PlayerStore.Get(p).DuelPairs }
	elseif cmd == "matches" then
		local out = {}
		for id, m in matches do
			local mem = {}
			for side, list in m.teams do for _, x in list do table.insert(mem, side .. ":" .. x.name .. "(" .. x.userId .. ")" .. (x.left and "L" or "")) end end
			table.insert(out, string.format("%s slot %d %s origin %s state %s score %s-%s [%s]", id, m.slot, m.mode, tostring(m.origin),
				tostring(m.state and m.state:GetAttribute("MatchState")), tostring(m.state and m.state:GetAttribute("ScoreA")),
				tostring(m.state and m.state:GetAttribute("ScoreB")), table.concat(mem, " ")))
		end
		local sl = {}
		for n = 1, C.MaxArenas or 6 do sl[n] = slots[n] or "-" end
		table.insert(out, "slots: " .. table.concat(sl, " "))
		return table.concat(out, " | ")
	end
	return "unknown " .. tostring(cmd)
end
if IS_STUDIO then
	task.defer(function()
		local hook = ServerStorage:FindFirstChild("DuelTestHook") or Instance.new("BindableFunction")
		hook.Name = "DuelTestHook"
		hook.OnInvoke = testHook
		hook.Parent = ServerStorage
	end)
end

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
-- Phase 2: the arena's moving / reacting pieces follow the server state on the Solid layer (ArenaShootables):
--   doors (DoorOpen / DoorMoving / DoorAt: the Visual shutter tweens like the server's, the Led turns amber / green / red),
--   fire barrels (Exploded hides the Visual barrel; FireAt / FireRadius / FireUntil draw the burning ground here),
--   steam valves (SteamUntil: the jet + hiss play on the Visual valve). All local: only this match's clients see them.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ROLL_TIME = 1.6 -- = ArenaShootables.ROLL_TIME (server shutter tween)
local SMOKE_TEX = "rbxasset://textures/particles/smoke_main.dds"
local FIRE_TEX = "rbxasset://textures/particles/fire_main.dds"
local HISS = "rbxassetid://4772620521"

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

-- // Dynamic pieces: follow the Solid layer's state attributes -------------------------------------------------------------------
local function seq(...)
	local pts = {}
	for _, p in { ... } do table.insert(pts, NumberSequenceKeypoint.new(p[1], p[2])) end
	return NumberSequence.new(pts)
end
local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	for k, v in props do (e :: any)[k] = v end
	e.Parent = parent
	return e
end

local function bindDoor(solidModel: Model, visModel: Model, conns)
	local shutter = visModel:FindFirstChild("Shutter")
	if not (shutter and shutter:IsA("BasePart")) then return end
	local closed = shutter.CFrame
	local led = visModel:FindFirstChild("Led")
	local tween
	local function apply()
		local open = solidModel:GetAttribute("DoorOpen") == true
		local moving = solidModel:GetAttribute("DoorMoving") == true
		local h = solidModel:GetAttribute("DoorHeight") or 10
		local goal = open and closed + Vector3.new(0, h, 0) or closed
		if tween then tween:Cancel(); tween = nil end
		local left = ROLL_TIME - (workspace:GetServerTimeNow() - (solidModel:GetAttribute("DoorAt") or 0))
		if moving and left > 0.03 then
			tween = TweenService:Create(shutter, TweenInfo.new(left, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { CFrame = goal })
			tween:Play()
		else
			shutter.CFrame = goal
		end
		if led and led:IsA("BasePart") then
			led.Color = moving and Color3.fromRGB(255, 170, 30) or open and Color3.fromRGB(60, 230, 90) or Color3.fromRGB(255, 60, 40)
			led.Material = Enum.Material.Neon
		end
	end
	for _, a in { "DoorOpen", "DoorMoving", "DoorAt" } do table.insert(conns, solidModel:GetAttributeChangedSignal(a):Connect(apply)) end
	apply()
end

local function firePatch(at: Vector3, r: number): Part
	-- burning ground (the match place's ShootableManager.spawnFire, drawn locally)
	local fire = Instance.new("Part")
	fire.Name = "FirePatch"; fire.Anchored = true; fire.CanCollide = false; fire.CanQuery = false; fire.CanTouch = false
	fire.Transparency = 1; fire.Size = Vector3.new(r * 2, 0.2, r * 2); fire.Position = at - Vector3.new(0, 1.3, 0)
	for i = 1, 11 do
		local ang = (i / 11) * math.pi * 2 + math.random() * 0.5
		local dist = i == 1 and 0 or r * (0.25 + math.random() * 0.65)
		local a = Instance.new("Attachment")
		a.Position = Vector3.new(math.cos(ang) * dist, 0.15, math.sin(ang) * dist)
		a.Parent = fire
		local sz = 2.4 + math.random() * 1.6
		emitter(a, { Texture = FIRE_TEX, LightEmission = 1, LightInfluence = 0, Rate = 22,
			Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 236, 170)), ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 140, 40)), ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 30, 10)) }),
			Size = seq({ 0, sz * 0.6 }, { 0.4, sz }, { 1, sz * 0.2 }), Transparency = seq({ 0, 0.25 }, { 0.7, 0.45 }, { 1, 1 }),
			Lifetime = NumberRange.new(0.35, 0.7), Speed = NumberRange.new(2, 5), SpreadAngle = Vector2.new(15, 15),
			Acceleration = Vector3.new(0, 7, 0), RotSpeed = NumberRange.new(-90, 90), Rotation = NumberRange.new(0, 360),
			EmissionDirection = Enum.NormalId.Top })
	end
	emitter(fire, { Texture = SMOKE_TEX, Color = ColorSequence.new(Color3.fromRGB(35, 32, 30)), Size = seq({ 0, 2 }, { 1, 9 }),
		Transparency = seq({ 0, 0.55 }, { 1, 1 }), Lifetime = NumberRange.new(2.5, 4), Speed = NumberRange.new(3, 6),
		Acceleration = Vector3.new(0.4, 2, 0), SpreadAngle = Vector2.new(25, 25), EmissionDirection = Enum.NormalId.Top, Rate = 7, LightInfluence = 1 })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 130, 45); light.Brightness = 4; light.Range = r * 3; light.Shadows = false
	light.Parent = fire
	local roar = Instance.new("Sound")
	roar.SoundId = HISS; roar.PlaybackSpeed = 0.38; roar.Volume = 0.8; roar.Looped = true
	roar.RollOffMinDistance = 8; roar.RollOffMaxDistance = 140; roar.Parent = fire
	roar.TimePosition = 0.08
	roar:Play()
	return fire
end

local function bindBarrel(solidModel: Model, visModel: Model, conns)
	local saved = {}
	for _, p in visModel:GetDescendants() do if p:IsA("BasePart") then saved[p] = p.Transparency end end
	local fire
	local function apply()
		local gone = solidModel:GetAttribute("Exploded") == true
		for p, t in saved do p.Transparency = gone and 1 or t end
		for _, g in visModel:GetDescendants() do if g:IsA("SurfaceGui") then g.Enabled = not gone end end
		local untilT = solidModel:GetAttribute("FireUntil")
		local at = solidModel:GetAttribute("FireAt")
		local left = untilT and (untilT - workspace:GetServerTimeNow()) or 0
		if fire and (left <= 0 or not gone) then
			for _, e in fire:GetDescendants() do if e:IsA("ParticleEmitter") then e.Rate = 0 end end
			local snd = fire:FindFirstChildOfClass("Sound")
			if snd then TweenService:Create(snd, TweenInfo.new(1.2), { Volume = 0 }):Play() end
			Debris:AddItem(fire, 2)
			fire = nil
		end
		if not fire and gone and left > 0 and typeof(at) == "Vector3" then
			fire = firePatch(at, solidModel:GetAttribute("FireRadius") or 6)
			fire.Parent = visModel
			local mine = fire
			task.delay(left, function() if fire == mine then apply() end end)
		end
	end
	for _, a in { "Exploded", "FireUntil" } do table.insert(conns, solidModel:GetAttributeChangedSignal(a):Connect(apply)) end
	apply()
end

local function bindValve(solidModel: Model, visModel: Model, conns)
	local body = visModel:FindFirstChild("ValveBody")
	local wheel = visModel:FindFirstChild("Wheel")
	if not (body and body:IsA("BasePart")) then return end
	local out = wheel and (wheel.Position - body.Position) * Vector3.new(1, 0, 1) or Vector3.new(1, 0, 0)
	out = out.Magnitude > 0.01 and out.Unit or Vector3.new(1, 0, 0)
	local att = Instance.new("Attachment")
	att.Name = "SteamJet"
	att.WorldCFrame = CFrame.lookAt(body.Position + out * 0.7, body.Position + out * 2)
	att.Parent = body
	local jet = emitter(att, { Texture = SMOKE_TEX, Color = ColorSequence.new(Color3.fromRGB(240, 242, 245)), LightInfluence = 1,
		Size = seq({ 0, 0.35 }, { 0.5, 1.6 }, { 1, 2.6 }), Transparency = seq({ 0, 0.25 }, { 0.6, 0.6 }, { 1, 1 }),
		Lifetime = NumberRange.new(0.35, 0.6), Speed = NumberRange.new(22, 30), Drag = 3, SpreadAngle = Vector2.new(6, 6),
		EmissionDirection = Enum.NormalId.Front, Rate = 110, RotSpeed = NumberRange.new(-60, 60), Rotation = NumberRange.new(0, 360), Enabled = false })
	local wisp = emitter(att, { Texture = SMOKE_TEX, Color = ColorSequence.new(Color3.fromRGB(225, 228, 232)), LightInfluence = 1,
		Size = seq({ 0, 0.5 }, { 1, 2 }), Transparency = seq({ 0, 0.6 }, { 1, 1 }), Lifetime = NumberRange.new(0.8, 1.3),
		Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(40, 40), Acceleration = Vector3.new(0, 3, 0),
		EmissionDirection = Enum.NormalId.Front, Rate = 18, Enabled = false })
	local hiss = Instance.new("Sound")
	hiss.SoundId = HISS; hiss.PlaybackSpeed = 1.35; hiss.Looped = true; hiss.Volume = 0.9
	hiss.RollOffMinDistance = 10; hiss.RollOffMaxDistance = 160; hiss.Parent = att
	local token
	local function apply()
		local untilT = solidModel:GetAttribute("SteamUntil")
		local left = untilT and (untilT - workspace:GetServerTimeNow()) or 0
		local on = left > 0
		jet.Enabled, wisp.Enabled = on, on
		if on and not hiss.IsPlaying then hiss.TimePosition = 0.08; hiss:Play() elseif not on then hiss:Stop() end
		local t = {}
		token = t
		if on then task.delay(left, function() if token == t then apply() end end) end
	end
	table.insert(conns, solidModel:GetAttributeChangedSignal("SteamUntil"):Connect(apply))
	apply()
end

-- the server's Solid layer of this match (Workspace.DuelArenas.<id>.<WorkspaceName>); doors / barrels / valves follow it
local function bindDynamic(id: string, info, clone: Model)
	local conns = {}
	task.spawn(function()
		local arenas = workspace:WaitForChild("DuelArenas", 10)
		local folder = arenas and arenas:WaitForChild(id, 10)
		local solid = folder and folder:WaitForChild(info.WorkspaceName or info.Id, 10)
		if not solid or not loaded or loaded.clone ~= clone then return end
		local n = 0
		for _, f in { "Interactive", "Shootables" } do
			local sf, vf = solid:FindFirstChild(f), clone:FindFirstChild(f)
			for _, sm in (sf and vf and sf:GetChildren() or {}) do
				local vm = vf:FindFirstChild(sm.Name)
				if vm then
					local kind = sm:GetAttribute("Shootable")
					if sm:FindFirstChild("Shutter") then bindDoor(sm, vm, conns); n += 1
					elseif kind == "FireBarrel" then bindBarrel(sm, vm, conns); n += 1
					elseif kind == "SteamValve" then bindValve(sm, vm, conns); n += 1 end
				end
			end
		end
		clone:SetAttribute("DynamicBound", n)
		print(`[ArenaLoader] {id}: {n} dynamic pieces follow the server`)
	end)
	return conns
end

local function unload()
	if not loaded then return end
	for _, c in loaded.conns or {} do c:Disconnect() end
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
	loaded.conns = bindDynamic(id, info, clone)
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

	-- [MATCH] the match place (notes/match_place_flow.md): Loading waits for every client's "Loaded", then a short Intro
	MatchLoadTimeout = 60,  -- safety: start with whoever is present (a team with nobody = cancelled, no rewards)
	IntroTime = 2.5,        -- the logo crumble between Loading and MapVote
}
]=]
--@@END SOURCES

-- new modules: { parent path, name, class, SOURCES key }
local NEW = {
	{ "ReplicatedStorage.Modules.Shared", "MapRegistry", "ModuleScript", "MapRegistry" },
	{ "ReplicatedStorage.Modules.Shared", "MatchState", "ModuleScript", "MatchState" },
	{ "ServerScriptService.Shared", "MatchCore", "ModuleScript", "MatchCore" },
	{ "ServerScriptService.Shared", "ArenaShootables", "ModuleScript", "ArenaShootables" },
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
	-- phase 2 (2026-10-16)
	{ MGR .. ".CombatManager",
		'\tCombat.WeaponFired:FireAllClients(bot, origin, endPos, victimCharacter ~= nil)\n',
		'\t-- [DUEL] effects only to the audience of this match (lobby players and other arenas never get them)\n\tMatchState.FireScoped(Combat.WeaponFired, bot, bot, origin, endPos, victimCharacter ~= nil)\n' },
	{ MGR .. ".CombatManager",
		'\t\tCombat.WeaponFired:FireAllClients(player, origin, (wallResult :: RaycastResult).Position, false)\n',
		'\t\t-- [DUEL] effects only to the audience of this match (lobby players and other arenas never get them)\n\t\tMatchState.FireScoped(Combat.WeaponFired, player, player, origin, (wallResult :: RaycastResult).Position, false)\n' },
	{ MGR .. ".CombatManager",
		'\tCombat.WeaponFired:FireAllClients(player, origin, endPos, victimCharacter ~= nil)\n',
		'\t-- [DUEL] effects only to the audience of this match (lobby players and other arenas never get them)\n\tMatchState.FireScoped(Combat.WeaponFired, player, player, origin, endPos, victimCharacter ~= nil)\n' },
	{ MGR .. ".MeleeManager",
		'\tif melee then melee:FireAllClients(character, victimRoot.Position, quick and "Quick" or tool:GetAttribute("MeleeId"), backstab) end\n',
		'\t-- [DUEL] effects only to the audience of this match (lobby players and other arenas never get them)\n\tif melee then MatchState.FireScoped(melee, character, character, victimRoot.Position, quick and "Quick" or tool:GetAttribute("MeleeId"), backstab) end\n' },
	{ MGR .. ".GadgetManager",
		'local function mapRay(a: Vector3, b: Vector3): RaycastResult?\n\tlocal folder = mapFolder()\n\tif folder then\n\t\tmapParams.FilterType = Enum.RaycastFilterType.Include\n\t\tmapParams.FilterDescendantsInstances = { folder }\n',
		'local function mapRay(a: Vector3, b: Vector3): RaycastResult?\n\t-- [DUEL] inside a lobby duel arena: that arena\'s Solid walls (LobbyDuelManager.RayFilter), else the map as before\n\tlocal LDM = shared.Get and shared.Get("LobbyDuelManager")\n\tlocal arenaFilter = LDM and LDM.RayFilter and LDM.RayFilter(a)\n\tlocal folder = arenaFilter or mapFolder()\n\tif folder then\n\t\tmapParams.FilterType = Enum.RaycastFilterType.Include\n\t\tmapParams.FilterDescendantsInstances = arenaFilter or { folder }\n' },
	{ MGR .. ".GadgetManager",
		'local function smokeEmitter(name: string, parent: Instance): ParticleEmitter\n',
		'-- [DUEL] server effects inside a lobby duel arena go into that arena\'s FX folder (cleared per round), else Workspace\nlocal function fxParent(position: Vector3): Instance\n\tlocal LDM = shared.Get and shared.Get("LobbyDuelManager")\n\treturn LDM and LDM.FXFolder and LDM.FXFolder(position) or workspace\nend\n\nlocal function smokeEmitter(name: string, parent: Instance): ParticleEmitter\n' },
	{ MGR .. ".GadgetManager",
		'\tpart:SetAttribute("Radius", 0)\n\tpart.Parent = workspace\n',
		'\tpart:SetAttribute("Radius", 0)\n\t-- [DUEL] the arena\'s FX folder in a lobby duel\n\tpart.Parent = fxParent(position)\n' },
	{ MGR .. ".GadgetManager",
		'\tsource.Position = position + Vector3.new(0, 0.4, 0)\n\tsource.Parent = workspace\n',
		'\tsource.Position = position + Vector3.new(0, 0.4, 0)\n\t-- [DUEL] the arena\'s FX folder in a lobby duel\n\tsource.Parent = fxParent(position)\n' },
	{ MGR .. ".GadgetManager",
		'\tholder.Position = position\n\tholder.Parent = workspace\n',
		'\tholder.Position = position\n\t-- [DUEL] the arena\'s FX folder in a lobby duel\n\tholder.Parent = fxParent(position)\n' },
	{ MGR .. ".GadgetManager",
		'\tring.Position = position\n\tring.Parent = workspace\n',
		'\tring.Position = position\n\t-- [DUEL] the arena\'s FX folder in a lobby duel\n\tring.Parent = fxParent(position)\n' },
	{ MGR .. ".GadgetManager",
		'\t\tgrenade.CustomPhysicalProperties = PhysicalProperties.new(2, 0.6, 0.2, 1, 1)\n\t\tgrenade.Parent = workspace\n',
		'\t\tgrenade.CustomPhysicalProperties = PhysicalProperties.new(2, 0.6, 0.2, 1, 1)\n\t\t-- [DUEL] the arena\'s FX folder in a lobby duel\n\t\tgrenade.Parent = fxParent(start)\n' },
	{ MGR .. ".GadgetManager",
		'\t\tgrenade.CFrame = CFrame.new(origin + direction * 1.5)\n\t\tgrenade.Parent = workspace\n',
		'\t\tgrenade.CFrame = CFrame.new(origin + direction * 1.5)\n\t\t-- [DUEL] the arena\'s FX folder in a lobby duel\n\t\tgrenade.Parent = fxParent(origin)\n' },
	{ MGR .. ".GadgetManager",
		'\tCombat.FlashDetonated:FireAllClients(position)\n',
		'\t-- [DUEL] effects only to the audience of this match (lobby players and other arenas never get them)\n\tMatchState.FireScoped(Combat.FlashDetonated, position, position)\n' },
	{ MGR .. ".GadgetManager",
		'\tif not GadgetConfig.InfiniteCharges then player:SetAttribute(cfg.ChargesAttribute, charges - 1) end\n',
		'\t-- [DUEL] a real match (LiveMatch on the player\'s match state) always spends charges\n\tif not GadgetConfig.InfiniteCharges or MatchState.Get(player, "LiveMatch") == true then player:SetAttribute(cfg.ChargesAttribute, charges - 1) end\n' },
	{ MGR .. ".GadgetManager",
		'-- Refill the kit\'s gadget; the other gadget types are empty\n',
		'-- [DUEL] clear one lobby duel arena (new round / match end): its smoke cells and live grenades only\nfunction manager.ClearIn(folder: Instance)\n\tfor i = #cells, 1, -1 do if cells[i].part:IsDescendantOf(folder) then removeCell(cells[i]) end end\n\tfor _, inst in folder:GetChildren() do inst:Destroy() end\nend\n\n-- Refill the kit\'s gadget; the other gadget types are empty\n' },
	{ MGR .. ".ShootableManager",
		'function manager.OnShot(origin: Vector3, endPos: Vector3, shooter: Player?)\n\tlocal targets = shared.Get and shared.Get("TrainingTargetsManager")\n',
		'function manager.OnShot(origin: Vector3, endPos: Vector3, shooter: Player?)\n\t-- [DUEL] a shot inside a lobby duel arena: that arena\'s barrels / valves react (LobbyDuelManager -> ArenaShootables)\n\tlocal LDM = shared.Get and shared.Get("LobbyDuelManager")\n\tif LDM and LDM.OnShot and LDM.OnShot(origin, endPos, shooter) then return end\n\tlocal targets = shared.Get and shared.Get("TrainingTargetsManager")\n' },
	{ MGR .. ".ShootableManager",
		'\nreturn manager',
		'\n-- [DUEL] frag grenades (GadgetManager) and blasts: only inside a lobby duel arena (the lobby itself has no explosions)\nfunction manager.Explode(position: Vector3, kind: string, attacker: Player?)\n\tlocal LDM = shared.Get and shared.Get("LobbyDuelManager")\n\tif LDM and LDM.Explode then LDM.Explode(position, kind, attacker) end\nend\n\nreturn manager' },
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
