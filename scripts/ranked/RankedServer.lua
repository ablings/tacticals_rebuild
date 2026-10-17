-- ServerScriptService/Shared/RankedServer (ModuleScript) [RANKED] 2026-10-16, notes/ranked_server.md
-- The server side of ranked, the same file in the lobby and the match place. The maths is ReplicatedStorage.Modules.Shared.RankedCore.
--   RankedServer.Record(player, mode)        the unified Ranked[key] record (lazy migration from the old shapes, written back)
--   RankedServer.EloOf(player, mode)         its Elo (StartElo if the profile isn't loaded)
--   RankedServer.ApplyResult(player, mode, oppTier, won, draw, ownTier?)   one ranked result -> the MatchResults payload fields
--   RankedServer.ApplyLeave(player, mode, oppTier, ownTier?, why?)        a leave: normal loss (x2 in placements) + LeavePenalty, no shield
--   RankedServer.MarkPending / ClearPending / SettlePending   a ranked match in progress is stored in the record (rec.Pending); a
--                                            player who disconnects keeps it and pays the leave at their next join (either place)
--   RankedServer.SetElo / Reset / Lines      admin helpers (Commands/Ranked)
--   RankedServer.ApplyAttributes(player)     RankElo, RankTier, RankDivision, RankName, RankPlaced, RankShield, ... + RankedAll
--   RankedServer.Leaderboard                 OrderedDataStore Ranked_<key>_s1 (a memory mock in Studio / when DataStores fail)
--   RankedServer.RefreshLeaderboards()       top WarlordCount -> ReplicatedStorage RankedTop / RankedCutoff (shared ladder; mirrored as
--                                            RankedTop_All / RankedCutoff_All) or RankedTop_<mode> / RankedCutoff_<mode> (per-mode ladders)
--   RankedServer.Start()                     join hooks + the refresh loop (called by ServerScriptService.RankedService)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local RankedCore = require(ReplicatedStorage.Modules.Shared.RankedCore)
local C = RankedCore.Config
local IS_STUDIO = RunService:IsStudio()
local IS_LOBBY = workspace:FindFirstChild("LobbyMap") ~= nil

local RankedServer = { Core = RankedCore, Place = IS_LOBBY and "lobby" or "match", _last = {} }

-------------------------------------------------------------------------------
-- Profile access (ProfileService "gameStore", shared by both places)
-------------------------------------------------------------------------------
local DM
local function dataManager()
	if DM then return DM end
	local ok, m = pcall(function() return require(ServerScriptService:WaitForChild("Data"):WaitForChild("DataManager")) end)
	if ok then DM = m end
	return DM
end

local function getData(player: Player, wait: boolean?)
	local dm = dataManager()
	if not dm then return nil end
	for _ = 1, (wait and 60 or 1) do
		local d = dm:Get(player)
		if d or not player.Parent then return d end
		task.wait(0.25)
	end
	return nil
end
RankedServer.GetData = getData

-- write Ranked[key] through the player's replica (the client's copy updates live; ProfileService saves it), else raw
local function writeRecord(player: Player, key: string, rec)
	local data = getData(player)
	if not data then return false end
	local dm = dataManager()
	local replica = dm and dm.DataReplicas and dm.DataReplicas[player]
	if replica then
		if type(data.Ranked) ~= "table" then replica:SetValue({ "Ranked" }, {}) end
		replica:SetValue({ "Ranked", key }, rec)
	else
		if type(data.Ranked) ~= "table" then data.Ranked = {} end
		data.Ranked[key] = rec
	end
	-- shared ladder: the old per-mode entries become mirrors of it (LobbyUIController / PlayScreen "SR", admin ;stats read
	-- Ranked[mode].Rating). A mirror is never read back as a record.
	if key == C.SharedKey and C.MirrorModes then
		for _, m in C.Modes do
			local mirror = { Mirror = key, Rating = rec.Elo, Wins = rec.Wins or 0, Losses = rec.Losses or 0 }
			local curM = data.Ranked[m]
			if type(curM) ~= "table" or curM.Mirror ~= key or curM.Rating ~= mirror.Rating or curM.Wins ~= mirror.Wins or curM.Losses ~= mirror.Losses then
				if replica then replica:SetValue({ "Ranked", m }, mirror) else data.Ranked[m] = mirror end
			end
		end
	end
	return true
end
RankedServer.WriteRecord = writeRecord

local function copy(t) local o = {} for k, v in t do o[k] = v end return o end

-- the record for a mode's ladder, migrated from the old shapes on first touch (and written back)
function RankedServer.Record(player: Player, mode: string?, wait: boolean?)
	local data = getData(player, wait)
	if not data then return nil end
	local key = RankedCore.LadderKey(mode)
	local cur = type(data.Ranked) == "table" and data.Ranked[key] or nil
	-- a shared ladder adopts the best per-mode record the first time (switching PerModeLadders off keeps progress)
	if cur == nil and not C.PerModeLadders and type(data.Ranked) == "table" then
		for _, m in C.Modes do
			local e = data.Ranked[m]
			if type(e) == "table" and not e.Mirror and (tonumber(e.Elo) or tonumber(e.Rating) or 0) > (cur and (tonumber(cur.Elo) or tonumber(cur.Rating) or 0) or -1) then cur = e end
		end
	end
	local rec, changed = RankedCore.Migrate(cur and copy(cur) or nil)
	if changed or cur == nil then writeRecord(player, key, rec) end
	return rec, key
end

function RankedServer.EloOf(player: Player, mode: string?): number
	local rec = RankedServer.Record(player, mode, true)
	return rec and rec.Elo or C.StartElo
end

-------------------------------------------------------------------------------
-- Leaderboard: OrderedDataStore per ladder (mock in Studio)
-------------------------------------------------------------------------------
local Mock = {}
Mock.__index = Mock
function Mock.new(name) return setmetatable({ name = name, data = {}, names = {} }, Mock) end
function Mock:SetAsync(key, value) self.data[tostring(key)] = value end
function Mock:GetAsync(key) return self.data[tostring(key)] end
function Mock:RemoveAsync(key) self.data[tostring(key)] = nil end
function Mock:GetSortedAsync(ascending, pageSize, minValue, maxValue)
	local list = {}
	for k, v in self.data do
		if (minValue == nil or v >= minValue) and (maxValue == nil or v <= maxValue) then table.insert(list, { key = k, value = v }) end
	end
	table.sort(list, function(a, b) if a.value == b.value then return a.key < b.key end if ascending then return a.value < b.value end return a.value > b.value end)
	-- same shape as DataStorePages: GetCurrentPage() -> { {key, value} }, IsFinished, AdvanceToNextPageAsync()
	local pages = { list = list, size = pageSize, at = 1, IsFinished = #list <= pageSize }
	function pages:GetCurrentPage()
		local out = {}
		for i = self.at, math.min(#self.list, self.at + self.size - 1) do table.insert(out, self.list[i]) end
		return out
	end
	function pages:AdvanceToNextPageAsync()
		self.at += self.size
		self.IsFinished = self.at + self.size > #self.list
	end
	return pages
end

local Leaderboard = { stores = {}, mock = IS_STUDIO, top = {}, cutoff = {}, place = {}, known = {}, nameCache = {}, lastRefresh = 0 }
RankedServer.Leaderboard = Leaderboard
Leaderboard.Mock = Mock

function Leaderboard.Name(key: string): string
	return "Ranked_" .. key .. "_" .. C.LeaderboardVersion
end

function Leaderboard.Store(key: string)
	local s = Leaderboard.stores[key]
	if s then return s end
	if not Leaderboard.mock then
		local ok, store = pcall(function() return DataStoreService:GetOrderedDataStore(Leaderboard.Name(key)) end)
		if ok then s = store else
			warn("[Ranked] leaderboard store unavailable (" .. tostring(store) .. "): using a memory mock on this server")
			Leaderboard.mock = true
		end
	end
	s = s or Mock.new(Leaderboard.Name(key))
	Leaderboard.stores[key] = s
	return s
end

-- [SECURE] 2026-10-17: the stored value also carries the last-played day and the idle days already charged, so the board
-- can show decay for players who stopped playing (decay is otherwise only applied when they join: a top player could sit
-- on #1 / Warlord forever). value = ELO * 1e6 + (LastPlayed day % 1000) * 1000 + min(Decayed, 999); it still sorts by ELO.
-- Values below 1e6 are the old plain ELO (no day: no display decay).
function Leaderboard.Encode(elo: number, lastPlayed: number?, decayed: number?): number
	local day = RankedCore.Day(lastPlayed or os.time()) % 1000
	return math.floor(math.max(elo, 0)) * 1000000 + day * 1000 + math.clamp(math.floor(decayed or 0), 0, 999)
end
function Leaderboard.Decode(v: number): (number, number?, number)
	if v < 1000000 then return v, nil, 0 end
	local elo, d, k = v // 1000000, (v // 1000) % 1000, v % 1000
	local today = RankedCore.Day()
	return elo, today - ((today - d) % 1000), k
end
-- the ELO the board shows: stored ELO minus the decay due since the last ranked match (nothing for old plain values)
function Leaderboard.Shown(v: number): number
	local elo, day, k = Leaderboard.Decode(v)
	if not day then return elo end
	local loss = RankedCore.DecayDue({ Elo = elo, LastPlayed = day * 86400, Decayed = k })
	return elo - loss
end

-- one write per ranked result / admin change (lastPlayed / decayed: the record's, for the display decay)
function Leaderboard.Write(key: string, userId: number, elo: number, name: string?, lastPlayed: number?, decayed: number?)
	if userId <= 0 then return end
	if elo < (C.LeaderboardWriteMin or 0) then
		if C.LeaderboardWriteMin > 0 then pcall(function() Leaderboard.Store(key):RemoveAsync(tostring(userId)) end) end
		return
	end
	if name then Leaderboard.nameCache[userId] = name end
	local ok, err = pcall(function() Leaderboard.Store(key):SetAsync(tostring(userId), Leaderboard.Encode(elo, lastPlayed, decayed)) end)
	if not ok then
		warn("[Ranked] leaderboard write failed: " .. tostring(err))
		if not Leaderboard.mock and tostring(err):find("publish", 1, true) then
			Leaderboard.mock = true
			Leaderboard.stores = {}
			Leaderboard.Write(key, userId, elo, name, lastPlayed, decayed)
		end
	end
end

local function resolveNames(ids: { number })
	local missing = {}
	for _, id in ids do
		if not Leaderboard.nameCache[id] then
			local p = Players:GetPlayerByUserId(id)
			if p then Leaderboard.nameCache[id] = p.Name else table.insert(missing, id) end
		end
	end
	if #missing == 0 or Leaderboard.mock then return end
	local ok, infos = pcall(function() return game:GetService("UserService"):GetUserInfosByUserIdsAsync(missing) end)
	if ok and type(infos) == "table" then
		for _, info in infos do Leaderboard.nameCache[info.Id] = info.Username end
	end
end

-- top WarlordCount (only ELO >= WarlordFrom counts toward Warlord) -> ReplicatedStorage attributes
function Leaderboard.Refresh(key: string)
	local n = C.WarlordCount
	local ok, list = pcall(function()
		local pages = Leaderboard.Store(key):GetSortedAsync(false, math.min(100, n), C.WarlordFrom)
		local out = {}
		-- [SECURE] read a margin past n (display decay can reorder the top), keep ELO >= WarlordFrom after decay, re-sort
		local want = n + math.max(25, n // 4)
		local seen = 0
		while true do
			for _, e in pages:GetCurrentPage() do
				if seen >= want then break end
				seen += 1
				local shown = Leaderboard.Shown(e.value)
				if shown >= C.WarlordFrom then table.insert(out, { userId = tonumber(e.key), elo = shown }) end
			end
			if seen >= want or pages.IsFinished then break end
			pages:AdvanceToNextPageAsync()
		end
		table.sort(out, function(a, b) return a.elo > b.elo end)
		while #out > n do table.remove(out) end
		return out
	end)
	if not ok then
		warn("[Ranked] leaderboard refresh " .. key .. " failed: " .. tostring(list))
		return false
	end
	local ids = {}
	for _, e in list do table.insert(ids, e.userId) end
	resolveNames(ids)
	local place = {}
	for i, e in list do
		e.name = Leaderboard.nameCache[e.userId] or ("@" .. e.userId)
		place[e.userId] = i
	end
	Leaderboard.top[key] = list
	Leaderboard.place[key] = place
	-- the Warlord threshold: the 200th ELO when 200+ players are at 2200+; nil = every 2200+ player is Warlord
	Leaderboard.cutoff[key] = (#list >= n) and list[n].elo or nil
	Leaderboard.known[key] = true
	local json = HttpService:JSONEncode(list)
	ReplicatedStorage:SetAttribute("RankedTop_" .. key, json)
	ReplicatedStorage:SetAttribute("RankedCutoff_" .. key, Leaderboard.cutoff[key])
	if key == C.SharedKey then
		-- the shared ladder's plain names (RankedTop_All / RankedCutoff_All above stay as mirrors: RankedScreen reads "RankedTop_" .. key)
		ReplicatedStorage:SetAttribute("RankedTop", json)
		ReplicatedStorage:SetAttribute("RankedCutoff", Leaderboard.cutoff[key])
	end
	return true
end

function RankedServer.RefreshLeaderboards()
	for _, key in RankedCore.LadderKeys() do Leaderboard.Refresh(key) end
	Leaderboard.lastRefresh = os.clock()
	ReplicatedStorage:SetAttribute("RankedLadders", HttpService:JSONEncode(RankedCore.LadderKeys()))
	ReplicatedStorage:SetAttribute("RankedRefreshedAt", workspace:GetServerTimeNow())
	ReplicatedStorage:SetAttribute("RankedMock", Leaderboard.mock or nil)
	for _, p in Players:GetPlayers() do task.spawn(RankedServer.ApplyAttributes, p) end
end

-- Info for a record on a ladder (Warlord from the cached cutoff + leaderboard place)
function RankedServer.InfoFor(key: string, rec, userId: number?)
	local place = userId and Leaderboard.place[key] and Leaderboard.place[key][userId] or nil
	-- before the first refresh of this ladder the cutoff is unknown: nobody shows as Warlord yet (math.huge)
	local cutoff = Leaderboard.cutoff[key]
	if not Leaderboard.known[key] then cutoff = math.huge end
	return RankedCore.Info(rec.Elo, cutoff, place)
end

-------------------------------------------------------------------------------
-- Player attributes for the UI
-------------------------------------------------------------------------------
-- the mode the flat Rank* attributes describe: the match's mode here, in the lobby the ranked queue you're searching, else DefaultMode
function RankedServer.CurrentMode(player: Player): string
	if not IS_LOBBY then
		return ReplicatedStorage:GetAttribute("MatchMode") or C.DefaultMode
	end
	local q = player:GetAttribute("MM_Queue")
	if type(q) == "string" then
		local okCfg, LC = pcall(require, ReplicatedStorage.Modules.Shared.Config.LobbyConfig)
		local def = okCfg and LC.QueueById and LC.QueueById(q)
		if def and def.Ranked then return def.Mode end
	end
	return C.DefaultMode
end

function RankedServer.ApplyAttributes(player: Player)
	if not player.Parent or not getData(player) then return end
	local all = {}
	for _, mode in C.Modes do
		local rec, key = RankedServer.Record(player, mode)
		if rec and not all[key] then
			local info = RankedServer.InfoFor(key, rec, player.UserId)
			all[key] = {
				elo = rec.Elo, peak = rec.Peak, tier = info.tier, rank = info.rank, division = info.division, name = info.name,
				floor = info.floor, nextFloor = info.nextFloor, nextName = info.nextName, warlord = info.warlord, place = info.place,
				placed = rec.Placed, wins = rec.Wins, losses = rec.Losses, streak = rec.Streak, shield = RankedCore.ShieldReady(rec),
			}
		end
	end
	local key = RankedCore.LadderKey(RankedServer.CurrentMode(player))
	local cur = all[key]
	if not cur then return end
	player:SetAttribute("RankMode", key)
	player:SetAttribute("RankElo", cur.elo)
	player:SetAttribute("RankPeak", cur.peak)
	player:SetAttribute("RankTier", cur.rank)
	player:SetAttribute("RankTierIndex", cur.tier)
	player:SetAttribute("RankDivision", cur.division)
	player:SetAttribute("RankName", cur.name)
	player:SetAttribute("RankFloor", cur.floor)
	player:SetAttribute("RankNextFloor", cur.nextFloor)
	player:SetAttribute("RankNextName", cur.nextName)
	player:SetAttribute("RankWarlord", cur.warlord)
	player:SetAttribute("RankPlace", cur.place)
	player:SetAttribute("RankPlaced", cur.placed)
	player:SetAttribute("RankPlacements", C.Placements)
	player:SetAttribute("RankShield", cur.shield)
	player:SetAttribute("RankedAll", HttpService:JSONEncode(all))
end

-------------------------------------------------------------------------------
-- Results
-------------------------------------------------------------------------------
-- the end of a result / leave: counts, write, leaderboard, attributes, payload
local function finish(player: Player, key: string, rec, before: number, infoBefore, delta: number, extra)
	rec.Elo = math.max(C.Floor, before + delta)
	delta = rec.Elo - before
	rec.Rating = rec.Elo
	rec.Peak = math.max(rec.Peak or 0, rec.Elo)
	if not extra.draw then
		if extra.won then
			rec.Wins = (rec.Wins or 0) + 1
			rec.Streak = math.max(0, rec.Streak or 0) + 1
		else
			rec.Losses = (rec.Losses or 0) + 1
			rec.Streak = math.min(0, rec.Streak or 0) - 1
		end
	end
	rec.LastPlayed = os.time()
	rec.Decayed = 0
	rec.Pending = nil
	writeRecord(player, key, rec)
	Leaderboard.Write(key, player.UserId, rec.Elo, player.Name)
	-- the cached cutoff may move with this write; the next refresh settles it. Warlord here uses the cached one.
	local infoAfter = RankedServer.InfoFor(key, rec, player.UserId)
	local up = infoAfter.tier > infoBefore.tier or (infoAfter.warlord and not infoBefore.warlord)
	local down = infoAfter.tier < infoBefore.tier or (infoBefore.warlord and not infoAfter.warlord)
	if player.Parent then RankedServer.ApplyAttributes(player) end
	local payload = {
		eloBefore = before, eloAfter = rec.Elo, delta = delta, shieldUsed = extra.shieldUsed == true, promoted = up, demoted = down,
		rankBefore = infoBefore.name, rankAfter = infoAfter.name, tierBefore = infoBefore.tier, tierAfter = infoAfter.tier,
		ladder = key, placed = rec.Placed, placements = C.Placements, draw = extra.draw == true, leave = extra.leave == true,
		placement = extra.placement == true, revealed = extra.placement == true and (rec.Placed or 0) >= C.Placements,
	}
	RankedServer._last[player.UserId] = payload
	print(("[Ranked] %s %s %s: %d -> %d (%+d)%s%s"):format(player.Name, key, extra.leave and "LEAVE" or (extra.draw and "draw" or (extra.won and "win" or "loss")),
		before, rec.Elo, delta, extra.shieldUsed and " shield" or "", extra.placement and (" placement " .. rec.Placed .. "/" .. C.Placements) or ""))
	return payload
end

-- placement x2 (the first Placements matches); counts the placement match. Returns delta, isPlacement
local function placement(rec, delta: number)
	if (rec.Placed or 0) >= C.Placements then return delta, false end
	if delta ~= 0 then delta = math.sign(delta) * math.clamp(math.abs(delta) * C.PlacementMultiplier, 1, 2 * C.MaxDelta) end
	rec.Placed = (rec.Placed or 0) + 1
	return delta, true
end

-- One ranked result. oppTier = the opposing team's average tier, ownTier = own team's average tier (team modes; nil / 1v1 =
-- own tier). Returns the payload fields { eloBefore, eloAfter, delta, shieldUsed, promoted, demoted, rankBefore, rankAfter,
-- tierBefore, tierAfter, ladder, placed, placements, draw, leave, placement, revealed }.
function RankedServer.ApplyResult(player: Player, mode: string, oppTier: number, won: boolean, draw: boolean?, ownTier: number?)
	local rec, key = RankedServer.Record(player, mode, true)
	if not rec then return nil end
	local now = os.time()
	local before = rec.Elo
	local infoBefore = RankedServer.InfoFor(key, rec, player.UserId)
	local delta = RankedCore.Delta(before, oppTier, won, draw, ownTier)
	local shieldUsed = false
	if not won and not draw and delta < 0 and RankedCore.ShieldReady(rec, now) then
		shieldUsed = true
		delta = 0
		rec.ShieldDay = RankedCore.Day(now)
	end
	local placed
	delta, placed = placement(rec, delta)
	return finish(player, key, rec, before, infoBefore, delta, { won = won, draw = draw, shieldUsed = shieldUsed, placement = placed })
end

-- Leaving a ranked match (Edward): the normal loss (team maths; x2 in placements) + LeavePenalty. The shield never applies.
function RankedServer.ApplyLeave(player: Player, mode: string, oppTier: number, ownTier: number?, why: string?)
	local rec, key = RankedServer.Record(player, mode, true)
	if not rec then return nil end
	local before = rec.Elo
	local infoBefore = RankedServer.InfoFor(key, rec, player.UserId)
	local delta, placed = placement(rec, RankedCore.LeaveDelta(before, oppTier, ownTier))
	delta -= C.LeavePenalty
	local payload = finish(player, key, rec, before, infoBefore, delta, { won = false, leave = true, placement = placed })
	payload.why = why
	return payload
end

-- a ranked match is starting for this player: stored in the record, so a disconnect (the profile is released at once and
-- nothing written after that is saved) still costs the leave at the next join. Cleared by ApplyResult / ApplyLeave / ClearPending.
function RankedServer.MarkPending(player: Player, mode: string, oppTier: number, ownTier: number?)
	local rec, key = RankedServer.Record(player, mode, true)
	if not rec then return false end
	rec.Pending = { mode = mode, opp = oppTier, own = ownTier, t = os.time(), job = game.JobId }
	writeRecord(player, key, rec)
	return true
end

function RankedServer.ClearPending(player: Player, mode: string?)
	local rec, key = RankedServer.Record(player, mode)
	if not rec or rec.Pending == nil then return false end
	rec.Pending = nil
	writeRecord(player, key, rec)
	return true
end

-- at join: a match left by a disconnect on another server (not this one: a reconnect to a running match is not a leave)
function RankedServer.SettlePending(player: Player)
	for _, key in RankedCore.LadderKeys() do
		local rec = RankedServer.Record(player, key ~= C.SharedKey and key or nil)
		local p = rec and rec.Pending
		if type(p) == "table" and p.job ~= game.JobId then
			RankedServer.ApplyLeave(player, p.mode or C.DefaultMode, tonumber(p.opp) or 0, tonumber(p.own), "disconnect")
		end
	end
end

-- decay owed since the last ranked match (flag DecayEnabled); applied at join
function RankedServer.ApplyDecay(player: Player)
	if not C.DecayEnabled then return end
	for _, key in RankedCore.LadderKeys() do
		local rec = RankedServer.Record(player, key ~= C.SharedKey and key or nil)
		if rec then
			local loss, days = RankedCore.DecayDue(rec)
			if loss > 0 then
				rec.Elo -= loss
				rec.Rating = rec.Elo
				rec.Decayed = (rec.Decayed or 0) + days
				writeRecord(player, key, rec)
				Leaderboard.Write(key, player.UserId, rec.Elo, player.Name, rec.LastPlayed, rec.Decayed)
				print(("[Ranked] decay %s %s: -%d (%d idle days)"):format(player.Name, key, loss, days))
			end
		end
	end
end

-------------------------------------------------------------------------------
-- Admin helpers
-------------------------------------------------------------------------------
function RankedServer.SetElo(player: Player, elo: number, mode: string?)
	local rec, key = RankedServer.Record(player, mode)
	if not rec then return nil end
	rec.Elo = RankedCore.ClampElo(elo)
	rec.Rating = rec.Elo
	rec.Peak = math.max(rec.Peak or 0, rec.Elo)
	writeRecord(player, key, rec)
	Leaderboard.Write(key, player.UserId, rec.Elo, player.Name, rec.LastPlayed, rec.Decayed)
	RankedServer.ApplyAttributes(player)
	return rec, key
end

function RankedServer.Reset(player: Player, mode: string?)
	local done = {}
	local keys = mode and { RankedCore.LadderKey(mode) } or RankedCore.LadderKeys()
	for _, key in keys do
		local rec = RankedCore.Migrate(nil)
		writeRecord(player, key, rec)
		Leaderboard.Write(key, player.UserId, rec.Elo, player.Name, rec.LastPlayed, rec.Decayed)
		table.insert(done, key)
	end
	RankedServer.ApplyAttributes(player)
	return done
end

function RankedServer.Lines(player: Player): { string }
	local out = {}
	for _, key in RankedCore.LadderKeys() do
		local rec = RankedServer.Record(player, key ~= C.SharedKey and key or nil)
		if rec then
			local info = RankedServer.InfoFor(key, rec, player.UserId)
			table.insert(out, ("%s: %s, %d ELO (peak %d), W%d L%d streak %+d, placed %d/%d, shield %s, last %s"):format(key, info.name, rec.Elo,
				rec.Peak or rec.Elo, rec.Wins or 0, rec.Losses or 0, rec.Streak or 0, rec.Placed or 0, C.Placements,
				RankedCore.ShieldReady(rec) and "ready" or "no", (rec.LastPlayed or 0) > 0 and os.date("!%Y-%m-%d", rec.LastPlayed) or "never"))
		end
	end
	return out
end

-------------------------------------------------------------------------------
-- Boot
-------------------------------------------------------------------------------
local started = false
local function onJoin(player: Player)
	if not getData(player, true) then return end
	for _, mode in C.Modes do RankedServer.Record(player, mode) end
	RankedServer.SettlePending(player)
	RankedServer.ApplyDecay(player)
	RankedServer.ApplyAttributes(player)
	player:GetAttributeChangedSignal("MM_Queue"):Connect(function() RankedServer.ApplyAttributes(player) end)
end

function RankedServer.Start()
	if started then return end
	started = true
	for _, p in Players:GetPlayers() do task.spawn(onJoin, p) end
	Players.PlayerAdded:Connect(onJoin)
	ReplicatedStorage:GetAttributeChangedSignal("MatchMode"):Connect(function()
		for _, p in Players:GetPlayers() do task.spawn(RankedServer.ApplyAttributes, p) end
	end)
	task.spawn(function()
		while true do
			RankedServer.RefreshLeaderboards()
			task.wait(C.LeaderboardRefresh)
		end
	end)
	print(("[Ranked] ready (%s, ladders %s, leaderboard %s)"):format(RankedServer.Place, table.concat(RankedCore.LadderKeys(), "/"),
		Leaderboard.mock and "mock" or "OrderedDataStore"))
end

return RankedServer
