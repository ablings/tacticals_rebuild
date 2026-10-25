-- fix/survey1025_data.lua [SURVEY1025] 2026-10-25 (systems): the DATA findings of the 2026-10-25 cross-place survey
-- (roblox_hq task 20261025065116hki). Run in EVERY place (lobby, Tutorial, Matchmaking, Ranked), in Edit, after
-- fix/play_again_queue.lua, fix/switch_now.lua and fix/survey1025_security.lua:
--   python tools/run_luau_at.py <studio_id> fix/survey1025_data.lua [UNDO]
--   (2)  match DataManager = the lobby's: class-token cache (a rejoin to the same match server hit ReplicaService's "token
--              already created", got no replica, and its profile was never released on leave) + the DataManagerOwner guard
--              (a second copy required from a plugin / command bar stole the session: the 25-second kick, Corrections 10-09).
--   (2b) all   DataManager before-release hooks (dataManager.OnBeforeRelease(fn(player, profile))): run in PlayerRemoving while
--              the profile is still active, skipped on shutdown (dataManager.Closing); the profile is now released even when its
--              replica failed to build.
--   (9)  all   RankedServer.MarkPending charges another server's pending mark before writing its own (Play Again hops match
--              server -> match server; the arrival mark could overwrite the old match's unpaid leave).
--   (10) match RoundManager rewards through PlayerStore (the replica), as pad duels do, so the after-match screens see them.
--   (3)  match RoundManager + lobby LobbyDuelManager: a leave once round 1 has started is a loss (win streak 0, matches
--              played +1), written before the profile is released: the Leave button at once, a disconnect through the
--              before-release hook. One pure rule: ServerScriptService.Shared.LeaveRule (installed here, all places).
--   (13) all   LobbyLeaderboard uses Studio_-prefixed OrderedDataStores in Studio.
--   (12) all   Template gets TutorialDone / Wraps / DuelPairs (keys the code already saved without defaults).
-- Idempotent: every edit is checked before anything is written; an edit already in (or the place's own equivalent) counts as
-- applied. Edits this installer wrote are listed in each script's attribute Survey1025Edits; UNDO reverts only those (and
-- removes LeaveRule). Backups: ServerStorage._RebuildRemoved.SURVEY1025_<name>_Orig. Studio test switch: ReplicatedStorage
-- attribute StudioLeaveTest = true makes a leave count in a match with test bots (Studio only).
local UNDO = false --@UNDO
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local SS = game:GetService("ServerStorage")
local IS_MATCH = RS:FindFirstChild("PlaceKind") ~= nil
local IS_LOBBY = workspace:FindFirstChild("LobbyMap") ~= nil and not IS_MATCH
assert(IS_MATCH or IS_LOBBY, "survey1025: not the lobby (Workspace.LobbyMap) and not a split match place (ReplicatedStorage.PlaceKind)")
local WHERE = IS_LOBBY and "lobby" or "match"
local out = { (UNDO and "UNDO " or "") .. "SURVEY1025 data (" .. WHERE .. (IS_MATCH and (" " .. tostring(RS.PlaceKind.Value)) or "") .. "):" }

local function managers()
	local init = SSS:FindFirstChild("ServerScripts") and SSS.ServerScripts:FindFirstChild("[Server] Init")
	return init and init:FindFirstChild("GameManager") and init.GameManager:FindFirstChild("Managers")
end
local function manager(name) local m = managers(); return m and m:FindFirstChild(name) end
local function dataManager() local d = SSS:FindFirstChild("Data"); return d and d:FindFirstChild("DataManager") end

-------------------------------------------------------------------------------------------------------------------------------
-- ServerScriptService.Shared.LeaveRule (new module, every place)
-------------------------------------------------------------------------------------------------------------------------------
local LEAVE_RULE = [====[-- ServerScriptService.Shared.LeaveRule [SURVEY1025] (fix/survey1025_data.lua, 2026-10-25): the leave rule of a match, one pure
-- function for both entry points (the match places' RoundManager and the lobby's pad duels, LobbyDuelManager).
-- Systems 7c: a casual leave is a loss once a round has started, so nobody keeps a win streak by quitting (ranked pays its
-- ELO leave in RankedServer on top). Not a leave: before round 1 starts, a decided match the leaver won or drew, the results,
-- an admin end, a match with a Studio test bot (ReplicatedStorage.StudioLeaveTest overrides that in Studio), a shutdown.
-- Each leave is charged once (the caller keeps `charged`).
local LeaveRule = {}

-- s = { real, aborted, roundStarted, over, lost, resulted, closing, charged } -> true when this leave costs the loss
function LeaveRule.Costs(s): boolean
	if type(s) ~= "table" then return false end
	if s.real ~= true or s.aborted or s.closing or s.charged or s.resulted then return false end
	if s.roundStarted ~= true then return false end
	if s.over then return s.lost == true end -- the Victory beat: only the losing side's leave costs
	return true
end

-- the loss itself: win streak 0, matches played +1, through PlayerStore (the replica: the client sees it, ProfileService saves
-- it); raw writes only when there is no replica
function LeaveRule.WriteLoss(player: Player): boolean
	local okPS, PS = pcall(function() return require(game:GetService("ServerScriptService").Data.PlayerStore) end)
	if not okPS or type(PS) ~= "table" then return false end
	local data, replica = PS.Get(player)
	if type(data) ~= "table" then return false end
	if replica then
		if type(data.Stats) ~= "table" then PS.Set(player, { "Stats" }, {}) end
		PS.Increment(player, { "Stats", "MatchesPlayed" }, 1)
		PS.Set(player, { "WinStreak" }, 0)
	else
		if type(data.Stats) ~= "table" then data.Stats = {} end
		data.Stats.MatchesPlayed = (tonumber(data.Stats.MatchesPlayed) or 0) + 1
		data.WinStreak = 0
	end
	player:SetAttribute("WinStreak", 0)
	return true
end

-- state -> the loss written (true) or nothing to charge (false)
function LeaveRule.Apply(player: Player, s, why: string?): boolean
	if not LeaveRule.Costs(s) then return false end
	local ok = LeaveRule.WriteLoss(player)
	print(("[LeaveRule] %s left (%s): %s"):format(player.Name, tostring(why), ok and "loss written (streak 0, played +1)" or "no profile data"))
	return ok
end

return LeaveRule
]====]

-------------------------------------------------------------------------------------------------------------------------------
-- edits: { where = "lobby" | "match" | "all", id, old, new, already = text that means "the place has its own equivalent" }
-------------------------------------------------------------------------------------------------------------------------------
local PATCHES = {
	{ key = "DataManager", find = dataManager, edits = {
		-- (2) the lobby's copy, edit by edit (the result is the lobby's source byte for byte, plus 2b below)
		{ id = "d2a", where = "match", already = [====[local classTokens = {}]====],
			old = [====[local dataManager = {}
dataManager.Profiles = {}
]====],
			new = [====[local dataManager = {}
local classTokens = {} -- ReplicaService errors if the same class token is created twice
dataManager.Profiles = {}
]====] },
		{ id = "d2b", where = "match", already = [====[LC.AutoLevel[player.UserId]]====],
			old = [====[		profile:Reconcile()

		-- [DATA] a release made for a teleport keeps the player (DataManager._onReleased)
]====],
			new = [====[		profile:Reconcile()
		-- dev accounts start at a fixed account level (LobbyConfig.AutoLevel)
		local okCfg, LC = pcall(require, repStorage.Modules.Shared.Config.LobbyConfig)
		local want = okCfg and LC.AutoLevel and LC.AutoLevel[player.UserId]
		if want then profile.Data.XP = math.max(tonumber(profile.Data.XP) or 0, LC.XPForLevel(want)) end

		-- [DATA] a release made for a teleport keeps the player (DataManager._onReleased)
]====] },
		{ id = "d2c", where = "match", already = [====[ClassToken = token;]====],
			old = [====[			local dataReplica = ReplicaService.NewReplica({
				ClassToken = ReplicaService.NewClassToken("PlayerProfile_"..player.UserId);
]====],
			new = [====[			local token = classTokens[player.UserId] or ReplicaService.NewClassToken("PlayerProfile_"..player.UserId)
			classTokens[player.UserId] = token
			local dataReplica = ReplicaService.NewReplica({
				ClassToken = token;
]====] },
		{ id = "d2d", where = "match", already = [====[GetAttribute("DataManagerOwner")]====],
			old = [====[end)

for _, player in Players:GetPlayers() do
]====],
			new = [====[end)

-- Only the first copy of this module loads profiles. Requiring it again from somewhere else
-- (the command bar, a plugin, a test tool) makes a second copy; if that copy also loaded profiles
-- it would steal the session from the real one and the player would get kicked ~25s later.
-- The idle copy has its own empty Profiles table, so read live data through the real one (e.g. PlayerStore).
if not runService:IsRunning() then return dataManager end -- never mark the place while editing
if serverScriptService:GetAttribute("DataManagerOwner") then
	warn("[DataManager] already running in another context; this copy will not load profiles")
	return dataManager
end
serverScriptService:SetAttribute("DataManagerOwner", game.JobId ~= "" and game.JobId or "studio")

for _, player in Players:GetPlayers() do
]====] },
		-- (2b) before-release hooks, release without a replica, shutdown flag (every place)
		{ id = "d2e", where = "all",
			old = [====[local function PlayerAdded(player : Player)
]====],
			new = [====[-- [SURVEY1025] before-release hooks (Systems 3: a penalty that must survive a disconnect is written in the data layer's
-- before-release hook, not in a manager's own PlayerRemoving handler, whose order against this module's isn't guaranteed: a
-- write after the release is silently lost). fn(player, profile) runs synchronously (don't yield) in PlayerRemoving while the
-- profile is still active, before the replica goes and the profile is released. Skipped on a shutdown (dataManager.Closing)
-- and for a profile already released for a teleport.
dataManager.BeforeRelease = dataManager.BeforeRelease or {}
function dataManager.OnBeforeRelease(fn)
	table.insert(dataManager.BeforeRelease, fn)
end
local function runBeforeRelease(player: Player, profile)
	if dataManager.Closing or not (profile and profile:IsActive()) then return end
	for _, fn in dataManager.BeforeRelease do
		local ok, err = pcall(fn, player, profile)
		if not ok then warn("[DataManager] before-release hook: " .. tostring(err)) end
	end
end

local function PlayerAdded(player : Player)
]====] },
		{ id = "d2f", where = "all",
			old = [====[	if profile and replica then
		replica:Destroy()
		dataManager.DataReplicas[player] = nil
		profile:Release()
	end
end
]====],
			new = [====[	-- [SURVEY1025] before-release hooks first (leave penalties); then release even without a replica (a replica that failed
	-- to build used to keep the profile locked until the server closed)
	if profile then runBeforeRelease(player, profile) end
	if replica then
		replica:Destroy()
		dataManager.DataReplicas[player] = nil
	end
	if profile then profile:Release() end
end
]====] },
		{ id = "d2g", where = "all",
			old = [====[game:BindToClose(function()
	for player, profile in dataManager.Profiles do
]====],
			new = [====[game:BindToClose(function()
	dataManager.Closing = true -- [SURVEY1025] a shutdown is not a leave: before-release hooks skip
	for player, profile in dataManager.Profiles do
]====] },
	} },
	{ key = "RankedServer", find = function() local s = SSS:FindFirstChild("Shared"); return s and s:FindFirstChild("RankedServer") end, edits = {
		{ id = "d9", where = "all",
			old = [====[function RankedServer.MarkPending(player: Player, mode: string, oppTier: number, ownTier: number?)
	local rec, key = RankedServer.Record(player, mode, true)
	if not rec then return false end
]====],
			new = [====[function RankedServer.MarkPending(player: Player, mode: string, oppTier: number, ownTier: number?)
	local rec, key = RankedServer.Record(player, mode, true)
	if not rec then return false end
	-- [SURVEY1025] (9) a mark left by ANOTHER server (a disconnect there, or Play Again's hop from one match server straight to
	-- the next) is charged first, as SettlePending at join would: overwriting it let the old match's leave go unpaid whenever
	-- this arrival mark ran before the join's SettlePending (their order is only timing)
	local old = rec.Pending
	if type(old) == "table" and old.job ~= game.JobId then
		RankedServer.ApplyLeave(player, old.mode or C.DefaultMode, tonumber(old.opp) or 0, tonumber(old.own), "disconnect")
		rec, key = RankedServer.Record(player, mode, true)
		if not rec then return false end
	end
]====] },
	} },
	{ key = "RoundManager", find = function() return manager("RoundManager") end, edits = {
		{ id = "d10", where = "match",
			old = [====[	if data then
		data.Stats = data.Stats or {}
		local function add(k, n) data.Stats[k] = (data.Stats[k] or 0) + n end
		add("MatchesPlayed", 1); add("Kills", summary.Kills); add("Headshots", summary.Headshots); add("MeleeKills", summary.MeleeKills)
		add("GadgetsThrown", player:GetAttribute("GadgetThrows") or 0)
		if summary.Won then add("Wins", 1) end
		do -- [STREAK] consecutive match wins (a draw keeps it)
			local ws = tonumber(data.WinStreak) or 0; if summary.Won then ws += 1 elseif not summary.Draw then ws = 0 end
			data.WinStreak = ws
			player:SetAttribute("WinStreak", ws)
		end
		local xp0 = tonumber(data.XP) or 0
		data.XP = xp0 + summary.XP
		pcall(function() require(ServerScriptService.Shared.RichNotify).LevelUp(player, xp0, data.XP) end) -- [NOTIFY]
		if LobbyConfig.LevelUpReward and LobbyConfig.AccountLevel then -- [ECON2] scissors per account level gained
			local gained = (LobbyConfig.AccountLevel(data.XP)) - (LobbyConfig.AccountLevel(xp0))
			if gained > 0 then summary.Scissors += gained * LobbyConfig.LevelUpReward; summary.LevelUpScissors = gained * LobbyConfig.LevelUpReward end
		end
		data.Credits = (tonumber(data.Credits) or 0) + summary.Scissors
		data.ItemXP = data.ItemXP or {}
		data.ItemXP[summary.Weapon] = (data.ItemXP[summary.Weapon] or 0) + summary.GunXP
]====],
			new = [====[	if data then
		-- [SURVEY1025] (10) every reward write through PlayerStore (the replica), as pad duels do: the after-match screens get the
		-- new scissors / XP / streak at once and ProfileService saves them. Raw writes only when there is no replica.
		local okPS, PS = pcall(function() return require(ServerScriptService.Data.PlayerStore) end)
		local replica = nil
		if okPS and type(PS) == "table" then
			local _, r = PS.Get(player)
			replica = r
		end
		local function set(path, v)
			if replica then PS.Set(player, path, v) return end
			local t = data
			for i = 1, #path - 1 do t = t[path[i]] end
			t[path[#path]] = v
		end
		local function inc(path, n)
			n = tonumber(n) or 0
			if replica then PS.Increment(player, path, n) return end
			local t = data
			for i = 1, #path - 1 do t = t[path[i]] end
			t[path[#path]] = (tonumber(t[path[#path]]) or 0) + n
		end
		if type(data.Stats) ~= "table" then set({ "Stats" }, {}) end
		inc({ "Stats", "MatchesPlayed" }, 1); inc({ "Stats", "Kills" }, summary.Kills); inc({ "Stats", "Headshots" }, summary.Headshots); inc({ "Stats", "MeleeKills" }, summary.MeleeKills)
		inc({ "Stats", "GadgetsThrown" }, player:GetAttribute("GadgetThrows") or 0)
		if summary.Won then inc({ "Stats", "Wins" }, 1) end
		do -- [STREAK] consecutive match wins (a draw keeps it)
			local ws = tonumber(data.WinStreak) or 0; if summary.Won then ws += 1 elseif not summary.Draw then ws = 0 end
			set({ "WinStreak" }, ws)
			player:SetAttribute("WinStreak", ws)
		end
		local xp0 = tonumber(data.XP) or 0
		local xp1 = xp0 + (tonumber(summary.XP) or 0)
		set({ "XP" }, xp1)
		pcall(function() require(ServerScriptService.Shared.RichNotify).LevelUp(player, xp0, xp1) end) -- [NOTIFY]
		if LobbyConfig.LevelUpReward and LobbyConfig.AccountLevel then -- [ECON2] scissors per account level gained
			local gained = (LobbyConfig.AccountLevel(xp1)) - (LobbyConfig.AccountLevel(xp0))
			if gained > 0 then summary.Scissors += gained * LobbyConfig.LevelUpReward; summary.LevelUpScissors = gained * LobbyConfig.LevelUpReward end
		end
		inc({ "Credits" }, summary.Scissors)
		if type(data.ItemXP) ~= "table" then set({ "ItemXP" }, {}) end
		if summary.Weapon ~= nil then inc({ "ItemXP", summary.Weapon }, summary.GunXP) end
]====] },
		{ id = "d3a", where = "match",
			old = [====[local function backToLobby(players)
]====],
			new = [====[-- [SURVEY1025] (3) a leave once round 1 has started is a loss (win streak 0, matches played +1; ranked also pays its ELO leave
-- above), written before the profile is released: the Leave button writes it at once (onFlow), a disconnect through
-- DataManager's before-release hook. The rule itself: ServerScriptService.Shared.LeaveRule.
local okLR, LeaveRule = pcall(function() return require(ServerScriptService.Shared.LeaveRule) end)
local function leaveState(match, m)
	local ctx = match.ctx
	local wt = ReplicatedStorage:GetAttribute("WinnerTeam")
	return {
		real = match.kind == "match" and (not match.hasBot or (IS_STUDIO and ReplicatedStorage:GetAttribute("StudioLeaveTest") == true)),
		aborted = match.aborted or (ctx and ctx.aborted), roundStarted = match.roundStarted == true, over = ctx and ctx.over,
		lost = wt ~= nil and wt ~= m.team, resulted = match.resulted, charged = m.leaveCharged or m.leaveSettled,
	}
end
local function casualLeave(match, m, why: string)
	if not (okLR and type(LeaveRule) == "table" and match and m and m.player) then return end
	if LeaveRule.Apply(m.player, leaveState(match, m), why) then m.leaveCharged = true end
end
manager._LeaveState = function(userId) -- Studio tests: the rule's inputs for a member of the current match
	local m = current and current.byUser[userId]
	return m and leaveState(current, m) or nil
end
task.spawn(function()
	local okDM, DM = pcall(function() return require(ServerScriptService:WaitForChild("Data"):WaitForChild("DataManager")) end)
	if not (okDM and type(DM) == "table" and DM.OnBeforeRelease) then
		warn("[RoundManager] [SURVEY1025] no DataManager before-release hook: a disconnect can't be charged")
		return
	end
	DM.OnBeforeRelease(function(player: Player)
		local match = current
		local m = match and match.byUser and match.byUser[player.UserId]
		if m and m.player == player then casualLeave(match, m, "disconnect") end
	end)
end)

local function backToLobby(players)
]====] },
		{ id = "d3b", where = "match",
			old = [====[		onRoundStart = function()
			-- the map's barrels / valves, smoke and doors back to the start of a round
]====],
			new = [====[		onRoundStart = function()
			match.roundStarted = true -- [SURVEY1025] (3) from here a leave is a loss
			-- the map's barrels / valves, smoke and doors back to the start of a round
]====] },
		{ id = "d3c", where = "match",
			old = [====[			rankedLeave(match, m, "leave")
]====],
			new = [====[			rankedLeave(match, m, "leave")
			casualLeave(match, m, "leave") -- [SURVEY1025] (3) once round 1 started: streak 0, played +1 (before backToLobby releases)
			m.leaveSettled = true -- [SURVEY1025] this leave was judged now (free or not): a later disconnect never re-judges it
]====] },
	} },
	{ key = "LobbyDuelManager", find = function() return manager("LobbyDuelManager") end, edits = {
		{ id = "d3d", where = "lobby",
			old = [====[-- a player disconnects: not present any more (their side forfeits if nobody is left on it); nothing to send back
function manager._OnRemoving(p: Player)
]====],
			new = [====[-- [SURVEY1025] (3) a leave once round 1 has started is a loss (win streak 0, matches played +1), written before the profile is
-- released: HUD Leave at once (leave below), a disconnect through DataManager's before-release hook (PlayerRemoving order isn't
-- guaranteed; _OnRemoving may already have dropped byPlayer, so the hook looks the member up in `matches`).
local okLR, LeaveRule = pcall(function() return require(ServerScriptService.Shared.LeaveRule) end)
local function leaveState(match, m)
	local ctx = match.ctx
	local wt = match.state and match.state:GetAttribute("WinnerTeam")
	return {
		real = not match.hasBot or (IS_STUDIO and ReplicatedStorage:GetAttribute("StudioLeaveTest") == true),
		aborted = match.aborted or (ctx and ctx.aborted), roundStarted = match.roundStarted == true, over = ctx and ctx.over,
		lost = wt ~= nil and wt ~= m.team, resulted = match.resulted or match.ended, charged = m.leaveCharged or m.leaveSettled,
	}
end
local function casualLeave(match, m, why: string)
	if not (okLR and type(LeaveRule) == "table" and match and m and m.player) then return end
	if LeaveRule.Apply(m.player, leaveState(match, m), why) then m.leaveCharged = true end
end
-- the player's CURRENT duel only (DuelMatch): a duel they already left (returnToLobby clears DuelMatch: Leave, never loaded,
-- forfeit) is settled, and an old duel still running must not be charged for a quit from the next one. _OnRemoving leaves
-- DuelMatch set, so a disconnect is found whichever PlayerRemoving handler runs first.
local function memberOf(player: Player)
	local match = matches[player:GetAttribute("DuelMatch")]
	if not match then return nil, nil end
	for _, list in match.teams do
		for _, m in list do if m.player == player and not m.leaveSettled then return match, m end end
	end
	return nil, nil
end
task.spawn(function()
	local okDM, DM = pcall(function() return require(ServerScriptService:WaitForChild("Data"):WaitForChild("DataManager")) end)
	if not (okDM and type(DM) == "table" and DM.OnBeforeRelease) then
		warn("[LobbyDuelManager] [SURVEY1025] no DataManager before-release hook: a disconnect can't be charged")
		return
	end
	DM.OnBeforeRelease(function(player: Player)
		local match, m = memberOf(player)
		if match then casualLeave(match, m, "disconnect") end
	end)
end)

-- a player disconnects: not present any more (their side forfeits if nobody is left on it); nothing to send back
function manager._OnRemoving(p: Player)
]====] },
		{ id = "d3e", where = "lobby",
			old = [====[local function leave(player: Player)
	local rec = byPlayer[player]
	if not rec then return end
	rec.member.left = true
]====],
			new = [====[local function leave(player: Player)
	local rec = byPlayer[player]
	if not rec then return end
	rec.member.left = true
	casualLeave(rec.match, rec.member, "leave") -- [SURVEY1025] (3)
	rec.member.leaveSettled = true -- [SURVEY1025] judged now (free or not): a later disconnect never re-judges it
]====] },
		{ id = "d3f", where = "lobby",
			old = [====[		onRoundStart = function()
			-- this arena only: barrels whole, valves ready, doors shut, no fire, no smoke / grenades left
]====],
			new = [====[		onRoundStart = function()
			match.roundStarted = true -- [SURVEY1025] (3) from here a leave is a loss
			-- this arena only: barrels whole, valves ready, doors shut, no fire, no smoke / grenades left
]====] },
		{ id = "d3g", where = "lobby",
			old = [====[	local winner, forfeit = MatchCore.playMatch(ctx)
	for side, list in match.teams do
]====],
			new = [====[	local winner, forfeit = MatchCore.playMatch(ctx)
	match.resulted = true -- [SURVEY1025] (3) results from here: no leave costs anything any more
	for side, list in match.teams do
]====] },
		{ id = "d3h", where = "lobby",
			old = [====[function manager._TestForfeit(matchId: string, side: string)
	local match = matches[matchId]
	if not match then return false end
]====],
			new = [====[function manager._TestForfeit(matchId: string, side: string)
	local match = matches[matchId]
	if not match then return false end
	match.aborted = true -- [SURVEY1025] (3) admin ;endmatch ends a duel through here: an admin end is not a leave
	if match.ctx then match.ctx.aborted = true end
]====] },
	} },
	{ key = "LobbyLeaderboard", find = function() return SSS:FindFirstChild("LobbyLeaderboard") end, edits = {
		{ id = "d13", where = "all",
			old = [====[	local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, b.store)
]====],
			new = [====[	-- [SURVEY1025] (13) Studio writes its own boards (Studio_TopWins_v1 ...), as profiles / matchmaking / ranked already do
	local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, (game:GetService("RunService"):IsStudio() and "Studio_" or "") .. b.store)
]====] },
	} },
	{ key = "Template", find = function() local d = dataManager(); return d and d:FindFirstChild("Template") end, edits = {
		{ id = "d12", where = "all",
			old = [====[	Contracts = {},                    -- [itemId] = highest weapon-contract tier paid
]====],
			new = [====[	Contracts = {},                    -- [itemId] = highest weapon-contract tier paid

	-- [SURVEY1025] (12) keys the code already saved without a default (Reconcile now fills them in for every profile)
	TutorialDone = false,              -- the starter tutorial is finished (set by the Tutorial place, read by NewPlayerTutorial)
	Wraps = { Owned = {}, Equipped = {}, Favorites = {} }, -- [WRAPS] WrapManager: owned / equipped / starred wraps
	DuelPairs = {},                    -- [pair key] = os.time() of the last paid pad duel vs that opponent (reward cooldown)
]====] },
	} },
}

-------------------------------------------------------------------------------------------------------------------------------
-- the source edits: work out every new source first (assert), then write
-------------------------------------------------------------------------------------------------------------------------------
local writes = {}
for _, P in PATCHES do
	local applicable = {}
	for _, e in P.edits do if e.where == "all" or e.where == WHERE then table.insert(applicable, e) end end
	if #applicable == 0 then
		table.insert(out, P.key .. " n/a")
		continue
	end
	local inst = P.find()
	assert(inst and inst:IsA("LuaSourceContainer"), "survey1025: " .. P.key .. " not found")
	local src = inst.Source:gsub("\r\n", "\n")
	local mine = {}
	for id in string.gmatch(inst:GetAttribute("Survey1025Edits") or "", "[^,]+") do mine[id] = true end
	local s = src
	for _, e in applicable do
		if UNDO then
			if not mine[e.id] then
				table.insert(out, P.key .. " " .. e.id .. " not mine")
			elseif not s:find(e.new, 1, true) then
				-- the recorded edit's text isn't there: a later version of this installer changed it. Stop rather than forget
				-- the id (forgetting it would leave the old text in with nothing able to undo it): UNDO with the installer
				-- version that wrote it (git), then re-run.
				error("survey1025: " .. P.key .. " " .. e.id .. " is recorded as installed but its text differs: UNDO with the version that installed it")
			else
				local a, b = s:find(e.new, 1, true)
				assert(not s:find(e.new, b + 1, true), "survey1025: " .. P.key .. " " .. e.id .. " new text not unique (UNDO)")
				s = s:sub(1, a - 1) .. e.old .. s:sub(b + 1)
				mine[e.id] = nil
				table.insert(out, P.key .. " " .. e.id .. " -")
			end
		elseif s:find(e.new, 1, true) then
			table.insert(out, P.key .. " " .. e.id .. " =")
		elseif e.already and s:find(e.already, 1, true) then
			table.insert(out, P.key .. " " .. e.id .. " = (own)")
		else
			local a, b = s:find(e.old, 1, true)
			assert(a, "survey1025: " .. P.key .. " " .. e.id .. " anchor not found")
			assert(not s:find(e.old, b + 1, true), "survey1025: " .. P.key .. " " .. e.id .. " anchor not unique")
			s = s:sub(1, a - 1) .. e.new .. s:sub(b + 1)
			mine[e.id] = true
			table.insert(out, P.key .. " " .. e.id .. " +")
		end
	end
	if s ~= src then
		local f, err = loadstring(s)
		assert(f, "survey1025: " .. P.key .. " would not parse: " .. tostring(err))
	end
	local ids = {}
	for id in mine do table.insert(ids, id) end
	table.sort(ids)
	table.insert(writes, { inst = inst, src = src, s = s, ids = table.concat(ids, ",") })
end

-- the LeaveRule module
local shared = SSS:FindFirstChild("Shared")
assert(shared, "survey1025: ServerScriptService.Shared not found")
local lr = shared:FindFirstChild("LeaveRule")
assert(loadstring(LEAVE_RULE), "survey1025: LeaveRule would not parse")
if lr then assert(lr:IsA("ModuleScript") and lr:GetAttribute("Survey1025"), "survey1025: a LeaveRule this installer didn't make is already here") end

local function backup(inst)
	local folder = SS:FindFirstChild("_RebuildRemoved")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "_RebuildRemoved"
		folder.Parent = SS
	end
	local name = "SURVEY1025_" .. inst.Name .. "_Orig"
	if folder:FindFirstChild(name) then return end
	local b = inst:Clone()
	b.Name = name
	if b:IsA("BaseScript") then b.Disabled = true end
	b.Parent = folder
end
for _, w in writes do
	if w.s ~= w.src then
		if not UNDO then backup(w.inst) end
		w.inst.Source = w.s
	end
	w.inst:SetAttribute("Survey1025Edits", w.ids ~= "" and w.ids or nil)
end
if UNDO then
	if lr then lr:Destroy(); table.insert(out, "LeaveRule -") else table.insert(out, "LeaveRule already out") end
elseif not lr then
	lr = Instance.new("ModuleScript")
	lr.Name = "LeaveRule"
	lr:SetAttribute("Survey1025", true)
	lr.Source = LEAVE_RULE
	lr.Parent = shared
	table.insert(out, "LeaveRule +")
elseif lr.Source ~= LEAVE_RULE then
	lr.Source = LEAVE_RULE
	table.insert(out, "LeaveRule ~")
else
	table.insert(out, "LeaveRule =")
end

return table.concat(out, " | ")
