-- ranked_install.lua : Edward's ranked ELO server system (notes/ranked_server.md), 2026-10-16. Built by tools/ranked_build.py
-- from scripts/ranked/* + scripts/admin/Commands/Ranked.lua (sources embedded below). Idempotent; the place is detected
-- (lobby = Workspace.LobbyMap exists):
--   lobby       python tools/ranked_build.py --run lobby        (studio 829eb64d)
--   match place python tools/ranked_build.py --run match        (studio 331cb3a0)
--   UNDO        add UNDO to either line
-- New (attribute RankedInstall = true): ReplicatedStorage.Modules.Shared.RankedCore, ServerScriptService.Shared.RankedServer,
--   ServerScriptService.RankedService (Script), ServerScriptService.AdminFramework.Commands.Ranked (when the framework is there).
-- [RANKED] edits (string swap; UNDO swaps back; backups ServerStorage._RebuildRemoved.RANKED_<name>_Orig before the first edit):
--   match: Managers.RoundManager (RankedCore deltas instead of the K32 Elo, payload in MatchResults, record via RankedServer;
--          v3 2026-10-17: team tier blend, pending mark at the match start, leave penalty on Leave / disconnect)
--   lobby: Managers.MatchmakingManager (ranked window / pair rule from RankedCore, tier in the queue entry; v3: the mode's window),
--          Data.DataManager.Template (Ranked comment), Data.PlayerStore (PlayerStore.Ranked)
-- ORDER: match place: match_place_build -> data_release -> THIS -> split. Lobby: lobby_duels -> admin -> data_release -> THIS -> split
-- (UNDO split first: notes/place_split.md section 6). tools/match_place_build.py rewrites RoundManager: re-run this after it.
-- Changing an edit's text: UNDO with the OLD file first (git show <commit>:fix/ranked_install.lua), then install the new one.
local UNDO = false --@UNDO

local SS = game:GetService("ServerStorage")
local SSS = game:GetService("ServerScriptService")
local RS = game:GetService("ReplicatedStorage")
local CHS = game:GetService("ChangeHistoryService")
local IS_LOBBY = workspace:FindFirstChild("LobbyMap") ~= nil
local TAG = "RankedInstall"
local rec = CHS:TryBeginRecording("RANKED install" .. (UNDO and " UNDO" or ""))
local bin = SS:FindFirstChild("_RebuildRemoved") or Instance.new("Folder")
bin.Name = "_RebuildRemoved"; bin.Parent = SS
local log = { "place: " .. (IS_LOBBY and "lobby" or "match") }
local function say(...) local t = {} for _, v in ipairs({ ... }) do table.insert(t, tostring(v)) end table.insert(log, table.concat(t, " ")) end
local function manager(name)
	local init = SSS:FindFirstChild("ServerScripts") and SSS.ServerScripts:FindFirstChild("[Server] Init")
	local m = init and init:FindFirstChild("GameManager") and init.GameManager:FindFirstChild("Managers")
	return m and m:FindFirstChild(name)
end

local SOURCES = {}
--@@BEGIN SOURCES
SOURCES.RankedCore = [=[-- ReplicatedStorage/Modules/Shared/RankedCore (ModuleScript) [RANKED] 2026-10-16, notes/ranked_server.md
-- Edward's ranked rules v2 (notes/ranked_design.md; reference implementation tools/ranked_table.py, commit b7ddd07)
-- + Edward's answers 2026-10-17 (v3): one shared ladder, Season 1 reset to 100, 10 placements x2, daily shield, decay at
-- Elite+, leave = loss + 25, per-mode queue windows, team ELO from (own tier + own team's average tier) / 2.
-- Read-only maths shared by the server (both places) and the UI: the ladder, the ELO change per match, the matchmaking
-- window and the config flags. No side effects, no services beyond what require needs: safe to require from the client.
--
--   RankedCore.Config                          the flags (notes/ranked_server.md section 5)
--   RankedCore.LadderKey(mode)                 the Ranked[...] key / leaderboard of a mode ("All" with the shared ladder)
--   RankedCore.TierOf(elo)                     0..20 (0 = Bronze 1 ... 20 = Commander 3; 2200+ stays 20)
--   RankedCore.Info(elo, cutoff?, place?)      { elo, tier, rank, rankName, division, name, floor, nextFloor, nextName, warlord, place }
--   RankedCore.Gain(myTier, oppTier) / Loss(myTier, oppTier)   ELO won / lost (1..100), exactly tools/ranked_table.py
--   RankedCore.TeamTier(myTier, ownTeamTier?)                  effective tier in a team: (own + own team's average) / 2
--   RankedCore.Delta(myElo, oppTier, won, draw?, ownTeamTier?) signed ELO change (oppTier = the other team's average tier)
--   RankedCore.LeaveDelta(myElo, oppTier, ownTeamTier?)        the normal loss of a leave (negative; LeavePenalty added by the server)
--   RankedCore.Window(waitedSeconds, mode?)   matchmaking window in tiers (1v1: 2 at 0 s, 6 at 5 min, 18 at 60 min; 2v2 x2, 3v3 x4 faster)
--   RankedCore.PairOk(tierA, waitedA, tierB, waitedB, mode?)   each inside the other's window
--   RankedCore.PartyTier(elos)                 a party's queue tier (the average tier)
--   RankedCore.PickGroup(pool, need, now, mode?) ranked matchmaker pick over { {v = {t = joinedAt, k = tier, n = size?}} } (oldest first)
--   RankedCore.Migrate(entry)                  the unified record of this season from anything stored (pure)
--   RankedCore.IsWarlord(elo, cutoff)          2200+ and (cutoff == nil or elo >= cutoff)

local RankedCore = {}

RankedCore.Config = {
	-- Edward 2026-10-17: ONE shared rank across 1v1 / 2v2 / 3v3 (Ranked.All, one Warlord top 200). true = a ladder per mode.
	PerModeLadders = false,
	SharedKey = "All",
	Modes = { "1v1", "2v2", "3v3" },
	DefaultMode = "1v1",            -- per-mode ladders only: the ladder the flat player attributes show when not queued
	MirrorModes = true,             -- shared ladder: also write Ranked[<mode>] = { Mirror = "All", Rating, Wins, Losses } for old "SR" readers

	Floor = 100,                     -- Bronze 1: never below
	TierSize = 100,
	WarlordFrom = 2200,              -- 2200+: top WarlordCount by ELO are Warlord, others stay Commander 3
	WarlordCount = 200,
	MinDelta = 1, MaxDelta = 100,
	DrawDelta = 0,                   -- a drawn match changes nothing (Edward: draws stay 0)

	-- Start / reset (Edward 2026-10-17: everyone starts Season 1 at Bronze 1 = 100; old ratings do NOT carry over).
	-- A record whose S (season) is not Season starts again at StartElo (the old numbers are kept in rec.Prev); bumping
	-- Season resets everyone again. MigrateOldRating (off) would map an old 1000-based Rating as StartElo + (Rating - OldStart).
	Season = 1,
	StartElo = 100,
	MigrateOldRating = false,
	OldStart = 1000,
	MigrateScale = 1,

	-- Placements (Edward: 10, rank hidden, x2, from 100, revealed after match 10): the first Placements ranked matches
	-- multiply the change by PlacementMultiplier and the UI hides the emblem until RankPlaced >= Placements.
	Placements = 10,
	PlacementMultiplier = 2,

	-- Daily shield (Edward: on): the first ranked loss of each UTC day costs 0 ELO while below ShieldBelowElo (Elite 1).
	-- Never covers a leave; not used during placements.
	ShieldEnabled = true,
	ShieldBelowElo = 1600,

	-- Decay (Edward: Elite and up, after 7 idle days -25 per idle day, never below Elite 1): above DecayFromElo, after
	-- DecayIdleDays without a ranked match, lose DecayPerDay per further idle day, never below DecayFromElo. Applied at join.
	DecayEnabled = true,
	DecayFromElo = 1600,
	DecayIdleDays = 7,
	DecayPerDay = 25,

	-- Leaving a ranked match (Leave button or disconnect, from the match's start until its results): the normal loss
	-- (x2 in placements) + LeavePenalty. The shield never applies.
	LeavePenalty = 25,

	-- Team modes (Edward): each player's effective tier = (own tier + own team's average tier) / 2, against the other team's
	-- average tier, through the normal Gain / Loss. Even teams = the solo numbers. "Blend" (or "AverageTier" = own tier only).
	TeamOpponent = "Blend",

	-- Leaderboard: an OrderedDataStore per ladder, Ranked_<key>_<LeaderboardVersion>, written on every ranked result (all
	-- ELOs, so the board and the cutoff are complete); both places refresh the top WarlordCount every LeaderboardRefresh s.
	LeaderboardVersion = "s1",       -- a new store per season: the old Ranked_<mode>_v1 boards are not read
	LeaderboardRefresh = 120,
	LeaderboardWriteMin = 0,         -- write only ELOs >= this (0 = all)

	-- Matchmaking window, in tiers: Window0 at 0 s, linear to Window5 at Time5, then linear to WindowMax at TimeMax (1v1).
	-- Team modes widen faster (Edward): waited time x WindowSpeed[mode] (2v2: full spread at 30 min, 3v3 at 15 min).
	Window0 = 2, Window5 = 6, Time5 = 300, WindowMax = 18, TimeMax = 3600,
	WindowSpeed = { ["1v1"] = 1, ["2v2"] = 2, ["3v3"] = 4 },

	-- Studio only: a ranked match against a Studio test bot changes ELO (so the flow can be tested); live bot matches never pay.
	StudioBotRanked = true,
	StudioBotElo = nil,              -- the bot's ELO in Studio (nil = the same as the player's)
}
local C = RankedCore.Config

RankedCore.Ranks = {
	{ Name = "Bronze", Win = 30, Loss = 10 },
	{ Name = "Silver", Win = 28, Loss = 12 },
	{ Name = "Gold", Win = 25, Loss = 15 },
	{ Name = "Platinum", Win = 21, Loss = 18 },
	{ Name = "Diamond", Win = 17, Loss = 21 },
	{ Name = "Elite", Win = 13, Loss = 23 },
	{ Name = "Commander", Win = 10, Loss = 25 },
}
RankedCore.WarlordName = "Warlord"
RankedCore.MaxTier = #RankedCore.Ranks * 3 - 1 -- 20

-- floors by tier: tier t (0..20) starts at (t + 1) * 100
RankedCore.Tiers = {}
for t = 0, RankedCore.MaxTier do
	local r = RankedCore.Ranks[t // 3 + 1]
	RankedCore.Tiers[t] = { Tier = t, Rank = r.Name, Division = t % 3 + 1, Name = r.Name .. " " .. (t % 3 + 1), Floor = (t + 1) * C.TierSize }
end

function RankedCore.LadderKey(mode: string?): string
	if not C.PerModeLadders then return C.SharedKey end
	return mode or C.DefaultMode
end

function RankedCore.LadderKeys(): { string }
	if not C.PerModeLadders then return { C.SharedKey } end
	return table.clone(C.Modes)
end

function RankedCore.ClampElo(elo: number): number
	return math.max(C.Floor, math.floor((tonumber(elo) or C.StartElo) + 0.5))
end

function RankedCore.TierOf(elo: number): number
	return math.clamp(math.floor((tonumber(elo) or C.Floor) / C.TierSize) - 1, 0, RankedCore.MaxTier)
end

function RankedCore.IsWarlord(elo: number, cutoff: number?): boolean
	return elo >= C.WarlordFrom and (cutoff == nil or elo >= cutoff)
end

-- everything the UI shows for an ELO. cutoff = ReplicatedStorage RankedCutoff (nil = fewer than 200 at 2200+),
-- place = leaderboard position if known
function RankedCore.Info(elo: number, cutoff: number?, place: number?)
	elo = RankedCore.ClampElo(elo)
	local t = RankedCore.TierOf(elo)
	local tier = RankedCore.Tiers[t]
	local nxt = RankedCore.Tiers[t + 1]
	local info = {
		elo = elo, tier = t, rank = tier.Rank, rankIndex = t // 3 + 1, division = tier.Division, name = tier.Name,
		floor = tier.Floor, nextFloor = nxt and nxt.Floor or C.WarlordFrom, nextName = nxt and nxt.Name or RankedCore.WarlordName,
		warlord = false, place = place,
	}
	if RankedCore.IsWarlord(elo, cutoff) then
		info.warlord = true
		info.rank = RankedCore.WarlordName
		info.division = 0
		info.name = place and (RankedCore.WarlordName .. " #" .. place) or RankedCore.WarlordName
		info.floor = cutoff or C.WarlordFrom
		info.nextFloor = nil
		info.nextName = nil
	end
	return info
end

-- Python's round(): halves go to the even integer (tools/ranked_table.py is the reference; 8 of the 882 tier-vs-tier
-- results differ from a half-up round)
local function pyRound(x: number): number
	local f = math.floor(x)
	local d = x - f
	if d > 0.5 then return f + 1 end
	if d < 0.5 then return f end
	return (f % 2 == 0) and f or f + 1
end
RankedCore._pyRound = pyRound

-- the base for a tier: the rank values, interpolated by tier between ranks (tier 0 = Bronze 1 ... 20 = Commander 3)
local function base(key: string, tier: number): number
	local r = tier / 3
	local i = math.min(math.floor(r), 5)
	local R = RankedCore.Ranks
	if r < 6 then
		local a, b = R[i + 1][key], R[i + 2][key]
		return a + (b - a) * (r - i)
	end
	return R[7][key]
end

local function clampDelta(v: number): number
	return math.max(C.MinDelta, math.min(C.MaxDelta, pyRound(v)))
end

-- ELO gained for beating oppTier (tiers may be fractional for a team average)
function RankedCore.Gain(me: number, opp: number): number
	local d = (opp - me) / 3
	local w = base("Win", me)
	local v
	if d >= 0 then v = w * (2 ^ 0.5) ^ d else v = w * (0.4 ^ 0.5) ^ -d end
	return clampDelta(v)
end

-- ELO lost for losing to oppTier
function RankedCore.Loss(me: number, opp: number): number
	local d = (opp - me) / 3
	local l = base("Loss", me)
	local v
	if d >= 0 then
		v = l * (0.5 ^ 0.5) ^ d
	else
		-- lost to someone weaker: straight line to 60 at 2 ranks below, then to 100 at 6 ranks below
		local g = -d
		if g <= 2 then v = l + (60 - l) * g / 2 else v = 60 + 40 * (g - 2) / 4 end
	end
	return clampDelta(v)
end

-- a player's effective tier in a team match: (own tier + own team's average tier) / 2 (1v1 / no team tier: own tier)
function RankedCore.TeamTier(me: number, ownTeam: number?): number
	if ownTeam == nil or C.TeamOpponent ~= "Blend" then return me end
	return (me + ownTeam) / 2
end

-- signed change for one player: myElo vs an opponent tier (the other team's average tier; ownTeam = own team's average)
function RankedCore.Delta(myElo: number, oppTier: number, won: boolean, draw: boolean?, ownTeam: number?): number
	if draw then return C.DrawDelta end
	local me = RankedCore.TeamTier(RankedCore.TierOf(myElo), ownTeam)
	if won then return RankedCore.Gain(me, oppTier) end
	return -RankedCore.Loss(me, oppTier)
end

-- the normal loss of a leave (negative); RankedServer.ApplyLeave doubles it in placements and adds -LeavePenalty
function RankedCore.LeaveDelta(myElo: number, oppTier: number, ownTeam: number?): number
	return RankedCore.Delta(myElo, oppTier, false, false, ownTeam)
end

-- the average tier of a list of ELOs
function RankedCore.AverageTier(elos: { number }): number
	if #elos == 0 then return 0 end
	local s = 0
	for _, e in elos do s += RankedCore.TierOf(e) end
	return s / #elos
end

-- a party's queue tier: the average tier of its members (Edward: "a team queues at its average tier")
function RankedCore.PartyTier(elos: { number }): number
	return RankedCore.AverageTier(elos)
end

-- matchmaking window (tiers either side) after waiting `waited` seconds in a mode's queue (team modes widen faster)
function RankedCore.Window(waited: number, mode: string?): number
	local t = math.max(0, waited or 0) * ((mode and C.WindowSpeed and C.WindowSpeed[mode]) or 1)
	if t <= C.Time5 then return C.Window0 + (C.Window5 - C.Window0) * t / C.Time5 end
	if t >= C.TimeMax then return C.WindowMax end
	return C.Window5 + (C.WindowMax - C.Window5) * (t - C.Time5) / (C.TimeMax - C.Time5)
end

-- a pair is valid only if each is inside the other's window
function RankedCore.PairOk(tierA: number, waitedA: number, tierB: number, waitedB: number, mode: string?): boolean
	local gap = math.abs(tierA - tierB)
	return gap <= RankedCore.Window(waitedA, mode) + 1e-9 and gap <= RankedCore.Window(waitedB, mode) + 1e-9
end

-- Ranked pick. pool = queue entries oldest first, each { v = { t = joinedAt (server time), k = tier, n = players (1) } };
-- a party entry carries n > 1 and k = its average tier (PartyTier). The longest-waiting entry anchors; the others are
-- taken oldest first ("quickest match first") as long as every pair in the group is valid in this mode's window and the
-- players fit. Returns the entries whose sizes add up to `need` players, or nil.
function RankedCore.PickGroup(pool, need: number, now: number, mode: string?)
	local function tierOf(e) return tonumber(e.v.k) or RankedCore.TierOf(e.v.r or C.StartElo) end
	local function size(e) return math.max(1, math.floor(tonumber(e.v.n) or 1)) end
	local total = 0
	for _, e in pool do total += size(e) end
	if total < need then return nil end
	for i, anchor in pool do
		local group, n = { anchor }, size(anchor)
		if n == need then return group end
		if n < need then
			for j, e in pool do
				if j ~= i and n + size(e) <= need then
					local ok = true
					for _, g in group do
						if not RankedCore.PairOk(tierOf(g), now - (g.v.t or now), tierOf(e), now - (e.v.t or now), mode) then ok = false break end
					end
					if ok then
						table.insert(group, e)
						n += size(e)
						if n == need then return group end
					end
				end
			end
		end
	end
	return nil
end

-- today's day number (UTC) for the shield / decay
function RankedCore.Day(t: number?): number
	return (t or os.time()) // 86400
end

-- The unified record: { V = 1, S = season, Elo, Peak, Placed, Wins, Losses, Streak, ShieldDay, LastPlayed, Decayed,
-- Rating (= Elo, mirror for the old readers), Pending (a ranked match in progress, RankedServer.MarkPending), Prev }.
-- A record of another season (every v2 record had none) starts again at StartElo with the old numbers in Prev; the old
-- shapes ({ Rating, Wins, Losses } / { Rating, Played, Wins }) and nil start fresh too (MigrateOldRating off).
-- Returns record, changed.
function RankedCore.Migrate(entry)
	if type(entry) == "table" and entry.V == 1 and tonumber(entry.Elo) and entry.S == C.Season then
		-- Rating is a mirror of Elo for the old readers; if something else wrote Rating (old code, ;setstat), Elo follows it
		local r = tonumber(entry.Rating)
		local changed = r ~= entry.Elo
		if r and changed then
			entry.Elo = RankedCore.ClampElo(r)
			entry.Peak = math.max(tonumber(entry.Peak) or 0, entry.Elo)
		end
		entry.Rating = entry.Elo
		return entry, changed
	end
	local old = type(entry) == "table" and entry or {}
	-- a v1 record of another season: everything starts again
	local reset = old.V == 1
	local elo = C.StartElo
	local rating = tonumber(old.Rating)
	local carry = C.MigrateOldRating and not reset and not old.Mirror
	if carry and rating then
		elo = C.StartElo + (rating - C.OldStart) * C.MigrateScale
	end
	elo = RankedCore.ClampElo(elo)
	local wins, losses = 0, 0
	if carry then
		wins = tonumber(old.Wins) or 0
		losses = tonumber(old.Losses) or math.max(0, (tonumber(old.Played) or 0) - wins)
	end
	local prev = nil
	if next(old) ~= nil and not old.Mirror then
		prev = { S = tonumber(old.S) or 0, Elo = tonumber(old.Elo) or tonumber(old.Rating), Peak = tonumber(old.Peak),
			Wins = tonumber(old.Wins), Losses = tonumber(old.Losses) }
	end
	return {
		V = 1,
		S = C.Season,
		Prev = prev,
		Elo = elo,
		Rating = elo,
		Peak = elo,
		Placed = math.min(C.Placements, wins + losses),
		Wins = wins,
		Losses = losses,
		Streak = 0,
		ShieldDay = 0,
		LastPlayed = 0,
		Decayed = 0,
	}, true
end

-- shield available right now for this record (flag on, placed, below Elite, not used today)
function RankedCore.ShieldReady(rec, now: number?): boolean
	if not C.ShieldEnabled or type(rec) ~= "table" then return false end
	if (rec.Placed or 0) < C.Placements then return false end
	return (rec.Elo or 0) < C.ShieldBelowElo and (rec.ShieldDay or 0) ~= RankedCore.Day(now)
end

-- decay owed now (idempotent: rec.Decayed counts idle days already charged since LastPlayed). Returns ELO to remove, days
function RankedCore.DecayDue(rec, now: number?)
	if not C.DecayEnabled or type(rec) ~= "table" or (rec.LastPlayed or 0) <= 0 then return 0, 0 end
	if (rec.Elo or 0) <= C.DecayFromElo then return 0, 0 end
	local idle = RankedCore.Day(now) - RankedCore.Day(rec.LastPlayed)
	local days = math.max(0, idle - C.DecayIdleDays) - (rec.Decayed or 0)
	if days <= 0 then return 0, 0 end
	local loss = math.min(days * C.DecayPerDay, rec.Elo - C.DecayFromElo)
	return loss, days
end

return RankedCore
]=]
SOURCES.RankedServer = [=[-- ServerScriptService/Shared/RankedServer (ModuleScript) [RANKED] 2026-10-16, notes/ranked_server.md
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
]=]
SOURCES.RankedService = [=[-- ServerScriptService/RankedService (Script) [RANKED] 2026-10-16, notes/ranked_server.md
-- Boots ServerScriptService.Shared.RankedServer in this place (lobby or match place): join migration + Rank* attributes,
-- decay (flag), and the leaderboard refresh (RankedTop_<ladder> / RankedCutoff_<ladder> every ~2 min).
-- Studio only: ServerStorage.RankedTestHook (BindableFunction) drives the tests from the MCP (the MCP's own VM has its own
-- module cache, so it can't call this VM's RankedServer directly).
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local RankedServer = require(ServerScriptService:WaitForChild("Shared"):WaitForChild("RankedServer"))
local RankedCore = RankedServer.Core

RankedServer.Start()

if RunService:IsStudio() then
	local hook = ServerStorage:FindFirstChild("RankedTestHook") or Instance.new("BindableFunction")
	hook.Name = "RankedTestHook"
	hook.Parent = ServerStorage
	local function who(id) return Players:GetPlayerByUserId(tonumber(id) or 0) or Players:GetPlayers()[1] end
	hook.OnInvoke = function(cmd, a, b, c)
		if cmd == "attrs" then
			local p, out = who(a), {}
			for k, v in p:GetAttributes() do if k:sub(1, 4) == "Rank" then out[k] = v end end
			return out
		elseif cmd == "raw" then
			local d = RankedServer.GetData(who(a))
			return d and d.Ranked and d.Ranked[b]
		elseif cmd == "setraw" then
			return RankedServer.WriteRecord(who(a), b, c)
		elseif cmd == "record" then
			return (RankedServer.Record(who(a), b))
		elseif cmd == "last" then
			return RankedServer._last[who(a).UserId]
		elseif cmd == "config" then
			local old = RankedCore.Config[a]
			RankedCore.Config[a] = b
			return old
		elseif cmd == "seed" then
			-- a = ladder key, b = count, c = top elo: b fake entries from c down in steps of 1
			local store = RankedServer.Leaderboard.Store(a)
			for i = 1, b do RankedServer.Leaderboard.Write(a, 900000000 + i, c - (i - 1), "Fake" .. i) end
			return store.data ~= nil
		elseif cmd == "clearboard" then
			RankedServer.Leaderboard.stores[a] = nil
			RankedServer.Leaderboard.known[a] = nil
			return true
		elseif cmd == "refresh" then
			RankedServer.RefreshLeaderboards()
			local key = a or RankedCore.Config.DefaultMode
			local top = RankedServer.Leaderboard.top[key]
			return { count = top and #top or 0, cutoff = RankedServer.Leaderboard.cutoff[key], first = top and top[1], mock = RankedServer.Leaderboard.mock }
		elseif cmd == "apply" then
			-- a = userId, b = mode, c = { oppElo | oppTier, won, draw, ownTier? }
			local opp = tonumber(c.oppTier) or RankedCore.TierOf(c.oppElo)
			return RankedServer.ApplyResult(who(a), b, opp, c.won == true, c.draw == true, tonumber(c.ownTier))
		elseif cmd == "leave" then
			-- a = userId, b = mode, c = { oppElo | oppTier, ownTier? }
			local opp = tonumber(c.oppTier) or RankedCore.TierOf(c.oppElo)
			return RankedServer.ApplyLeave(who(a), b, opp, tonumber(c.ownTier), "test")
		elseif cmd == "pending" then
			-- a = userId, b = mode, c = { oppTier, ownTier?, job? }: mark; job = "other" fakes a match on another server
			local p = who(a)
			RankedServer.MarkPending(p, b, tonumber(c.oppTier) or 0, tonumber(c.ownTier))
			if c.job then
				local rec, key = RankedServer.Record(p, b)
				rec.Pending.job = c.job
				RankedServer.WriteRecord(p, key, rec)
			end
			return (RankedServer.Record(p, b)).Pending
		elseif cmd == "settle" then
			RankedServer.SettlePending(who(a))
			return RankedServer._last[who(a).UserId]
		elseif cmd == "decay" then
			RankedServer.ApplyDecay(who(a))
			RankedServer.ApplyAttributes(who(a))
			return (RankedServer.Record(who(a), b))
		end
		return "unknown " .. tostring(cmd)
	end
end
]=]
SOURCES.Cmd_Ranked = [=[-- AdminFramework/Commands/Ranked: ranked ELO commands [RANKED] 2026-10-16 (notes/ranked_server.md).
-- They go through ServerScriptService.Shared.RankedServer (installed by fix/ranked_install.lua): the unified Ranked record,
-- the leaderboard write and the Rank* attributes, in both places.
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function server()
	local s = ServerScriptService:FindFirstChild("Shared") and ServerScriptService.Shared:FindFirstChild("RankedServer")
	if not s then return nil end
	local ok, m = pcall(require, s)
	return ok and m or nil
end
local function core()
	local s = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules.Shared:FindFirstChild("RankedCore")
	if not s then return nil end
	local ok, m = pcall(require, s)
	return ok and m or nil
end
local NOT_INSTALLED = "The ranked system isn't installed in this place (fix/ranked_install.lua)."
local MODES = { "1v1", "2v2", "3v3" }

return {
	{
		name = "setelo", level = "Tester", description = "Set a player's ranked ELO (never below 100). Mode defaults to 1v1.",
		args = { { name = "player", type = "player" }, { name = "elo", type = "integer", min = 0, max = 100000 },
			{ name = "mode", type = "choice", choices = MODES, optional = true, default = "1v1" } },
		run = function(ctx, a)
			local RS = server()
			if not RS then return false, NOT_INSTALLED end
			if not ctx.Data.Ready(a.player) then return false, a.player.Name .. "'s data hasn't loaded yet" end
			local rec, key = RS.SetElo(a.player, a.elo, a.mode)
			if not rec then return false, "couldn't write " .. a.player.Name .. "'s ranked record" end
			local info = RS.InfoFor(key, rec, a.player.UserId)
			if a.player ~= ctx.caller and ctx.Core.Notify then ctx.Core.Notify(a.player, ("An admin set your %s ELO to %d."):format(key, rec.Elo), "info") end
			return true, ("%s %s: %d ELO = %s."):format(a.player.Name, key, rec.Elo, info.name)
		end,
	},
	{
		name = "rankreset", level = "Admin", destructive = true,
		description = "Reset a player's ranked record (one mode, or every ladder) to a new player's: 100 ELO, no wins / losses.",
		args = { { name = "player", type = "player" }, { name = "mode", type = "choice", choices = MODES, optional = true } },
		confirmText = function(_, v) return ("reset %s's ranked record (%s)"):format(v.player.Name, v.mode or "every ladder") end,
		run = function(ctx, a)
			local RS = server()
			if not RS then return false, NOT_INSTALLED end
			if not ctx.Data.Ready(a.player) then return false, a.player.Name .. "'s data hasn't loaded yet" end
			local done = RS.Reset(a.player, a.mode)
			return true, ("Ranked reset for %s: %s."):format(a.player.Name, table.concat(done, ", "))
		end,
	},
	{
		name = "rankinfo", aliases = { "elo" }, level = "Tester", anyTarget = true,
		description = "Show a player's ranked records (ELO, rank, peak, wins / losses, placements, shield) and the Warlord cutoff.",
		args = { { name = "player", type = "player", defaultToken = "me" } },
		run = function(ctx, a)
			local RS = server()
			if not RS then return false, NOT_INSTALLED end
			if not ctx.Data.Ready(a.player) then return false, a.player.Name .. "'s data hasn't loaded yet" end
			ctx.reply(a.player.Name .. " ranked:")
			for _, line in RS.Lines(a.player) do ctx.reply(line) end
			local bits = {}
			for _, key in RS.Core.LadderKeys() do
				local cut = RS.Leaderboard.cutoff[key]
				local top = RS.Leaderboard.top[key]
				table.insert(bits, ("%s %d at 2200+, cutoff %s"):format(key, top and #top or 0, cut and tostring(cut) or "none"))
			end
			return true, "Warlord: " .. table.concat(bits, "; ") .. (RS.Leaderboard.mock and " (mock store)" or "")
		end,
	},
	{
		name = "simrank", level = "Tester", anyTarget = true,
		description = "Print the ELO change for A (eloA) beating or losing to B (eloB), and B's side of it. Changes nothing.",
		args = { { name = "eloA", type = "integer", min = 0, max = 100000 }, { name = "eloB", type = "integer", min = 0, max = 100000 },
			{ name = "result", type = "choice", choices = { "win", "loss" } } },
		run = function(_, a)
			local RC = core()
			if not RC then return false, NOT_INSTALLED end
			local won = a.result == "win"
			local ea, eb = RC.ClampElo(a.eloA), RC.ClampElo(a.eloB)
			local da = RC.Delta(ea, RC.TierOf(eb), won)
			local db = RC.Delta(eb, RC.TierOf(ea), not won)
			local ia, ib = RC.Info(ea), RC.Info(eb)
			return true, ("A %s (%d) %s vs B %s (%d): A %+d -> %d, B %+d -> %d"):format(ia.name, ea, won and "wins" or "loses", ib.name, eb,
				da, math.max(RC.Config.Floor, ea + da), db, math.max(RC.Config.Floor, eb + db))
		end,
	},
}
]=]
--@@END SOURCES

-------------------------------------------------------------------------------
-- [RANKED] edits: { getScript, place ("lobby" | "match" | "both"), old text, new text }
-------------------------------------------------------------------------------
local EDITS = {
	-- match RoundManager
	{ function() return manager("RoundManager") end, "match",
		'local MatchCore = require(ServerScriptService.Shared.MatchCore)\n',
		'local MatchCore = require(ServerScriptService.Shared.MatchCore)\n'
			.. '-- [RANKED] Edward\'s ranked ELO (notes/ranked_server.md): maths in RankedCore, records / leaderboard / attributes in RankedServer\n'
			.. 'local RankedCore = require(Shared.RankedCore)\n'
			.. 'local RankedServer = require(ServerScriptService.Shared.RankedServer)\n' },
	{ function() return manager("RoundManager") end, "match",
		'\tif ranked then\n'
			.. '\t\tlocal other = side == "A" and "B" or "A"\n'
			.. '\t\tsummary.RatingChange = MatchCore.eloDelta(C.Rewards or {}, ratings[side], ratings[other], summary.Won, summary.Draw)\n'
			.. '\tend\n',
		'\t-- [RANKED] RankedCore ELO instead of the K32 Elo: your own rank vs the other team\'s average tier (ratings[side] = average tier).\n'
			.. '\t-- Payload fields eloBefore / eloAfter / delta / shieldUsed / promoted / demoted (+ rankBefore / rankAfter / ladder ...) join\n'
			.. '\t-- the summary; RatingChange (old field) = delta. Live: a bot or admin-ended match changes nothing; Studio test bots do\n'
			.. '\t-- when RankedCore.Config.StudioBotRanked.\n'
			.. '\tif ranked and not match.aborted and (not match.hasBot or (IS_STUDIO and RankedCore.Config.StudioBotRanked)) then\n'
			.. '\t\tlocal other = side == "A" and "B" or "A"\n'
			.. '\t\t-- v3 (Edward 2026-10-17): your tier blends with your own team\'s average tier, (own + team) / 2\n'
			.. '\t\tlocal res = RankedServer.ApplyResult(player, mode, ratings[other] or 0, summary.Won == true, summary.Draw == true, ratings[side])\n'
			.. '\t\tif res then\n'
			.. '\t\t\tfor k, v in res do summary[k] = v end\n'
			.. '\t\t\tsummary.RatingChange = res.delta\n'
			.. '\t\tend\n'
			.. '\tend\n' },
	{ function() return manager("RoundManager") end, "match",
		'\t\tsummary.XP, summary.Scissors, summary.GunXP, summary.RatingChange = 0, 0, 0, nil\n',
		'\t\t-- [RANKED] RatingChange and the ELO fields stay as set above (only set when ELO really changed)\n'
			.. '\t\tsummary.XP, summary.Scissors, summary.GunXP = 0, 0, 0\n' },
	{ function() return manager("RoundManager") end, "match",
		'\t\tif ranked then\n'
			.. '\t\t\tdata.Ranked = data.Ranked or {}\n'
			.. '\t\t\tlocal r = data.Ranked[mode] or { Rating = C.StartingRating or 1000, Played = 0, Wins = 0 }\n'
			.. '\t\t\tr.Rating = math.max(0, (r.Rating or 1000) + summary.RatingChange)\n'
			.. '\t\t\tr.Played = (r.Played or 0) + 1\n'
			.. '\t\t\tif summary.Won then r.Wins = (r.Wins or 0) + 1 end\n'
			.. '\t\t\tdata.Ranked[mode] = r\n'
			.. '\t\tend\n',
		'\t\t-- [RANKED] the ranked record was written by RankedServer.ApplyResult above (unified record, leaderboard, attributes)\n' },
	{ function() return manager("RoundManager") end, "match",
		'\t\t\t\tlocal r = d and d.Ranked and d.Ranked[first.Mode]\n'
			.. '\t\t\t\tsum += (r and r.Rating) or (C.StartingRating or 1000); n += 1\n'
			.. '\t\t\tend\n'
			.. '\t\tend\n'
			.. '\t\tratings[side] = n > 0 and sum / n or (C.StartingRating or 1000)\n'
			.. '\tend\n',
		'\t\t\t\t-- [RANKED] the side\'s average TIER from the unified record (lazy migration of the old Rating); casual: 0\n'
			.. '\t\t\t\tsum += first.Ranked == true and RankedCore.TierOf(RankedServer.EloOf(m.player, first.Mode)) or 0; n += 1\n'
			.. '\t\t\tend\n'
			.. '\t\tend\n'
			.. '\t\tratings[side] = n > 0 and sum / n or nil\n'
			.. '\tend\n'
			.. '\t-- [RANKED] a side of Studio test bots only: StudioTeleportData BotElo, else RankedCore.Config.StudioBotElo, else the other side\'s tier\n'
			.. '\tfor _, side in { "A", "B" } do\n'
			.. '\t\tif ratings[side] == nil then\n'
			.. '\t\t\tlocal bot = (IS_STUDIO and tonumber(first.BotElo)) or RankedCore.Config.StudioBotElo\n'
			.. '\t\t\tratings[side] = bot and RankedCore.TierOf(bot) or ratings[side == "A" and "B" or "A"] or 0\n'
			.. '\t\tend\n'
			.. '\tend\n' },
	-- match RoundManager v3 (Edward 2026-10-17): leaving a ranked match = the normal loss + LeavePenalty (no shield)
	{ function() return manager("RoundManager") end, "match",
		'local function backToLobby(players)\n',
		'-- [RANKED] v3 leave penalty (Edward 2026-10-17, notes/ranked_server.md): from the match\'s start until its results, a\n'
			.. '-- Leave costs the normal loss (team maths, x2 in placements) + RankedCore.Config.LeavePenalty, never shielded. A\n'
			.. '-- disconnect pays the same at the next join (RankedServer.MarkPending at the start, SettlePending at join).\n'
			.. 'local function rankedPays(match)\n'
			.. '\treturn match.ranked and not match.aborted and (not match.hasBot or (IS_STUDIO and RankedCore.Config.StudioBotRanked))\n'
			.. 'end\n'
			.. 'local function rankedLeave(match, m, why: string)\n'
			.. '\tif not (match and m and m.player) or m.penalized or match.resulted or not match.ratings or not rankedPays(match) then return end\n'
			.. '\tm.penalized = true\n'
			.. '\tlocal other = m.team == "A" and "B" or "A"\n'
			.. '\tRankedServer.ApplyLeave(m.player, match.mode, match.ratings[other] or 0, match.ratings[m.team], why)\n'
			.. 'end\n'
			.. '\n'
			.. 'local function backToLobby(players)\n' },
	{ function() return manager("RoundManager") end, "match",
		'\tlocal maps, fallback = eligibleMaps(first.Mode)\n',
		'\t-- [RANKED] v3 the match is on: keep the tiers for a leave, and mark it in each player\'s record (a disconnect pays at the next join)\n'
			.. '\tmatch.ratings = ratings\n'
			.. '\tif rankedPays(match) then\n'
			.. '\t\tfor side, list in match.teams do\n'
			.. '\t\t\tfor _, m in list do\n'
			.. '\t\t\t\tif m.player then task.spawn(RankedServer.MarkPending, m.player, match.mode, ratings[side == "A" and "B" or "A"] or 0, ratings[side]) end\n'
			.. '\t\t\tend\n'
			.. '\t\tend\n'
			.. '\tend\n'
			.. '\tlocal maps, fallback = eligibleMaps(first.Mode)\n' },
	{ function() return manager("RoundManager") end, "match",
		'\tlocal winner, forfeit = MatchCore.playMatch(match.ctx)\n',
		'\tlocal winner, forfeit = MatchCore.playMatch(match.ctx)\n'
			.. '\t-- [RANKED] v3 results from here: no leave penalty any more; players still here who are not paid below (admin end,\n'
			.. '\t-- live bot match) get the pending mark cleared (the paid ones: RankedServer.ApplyResult clears it)\n'
			.. '\tmatch.resulted = true\n'
			.. '\tfor _, list in match.teams do\n'
			.. '\t\tfor _, m in list do\n'
			.. '\t\t\tif m.player and m.player.Parent and not m.penalized and (m.left or not rankedPays(match)) then\n'
			.. '\t\t\t\ttask.spawn(RankedServer.ClearPending, m.player, match.mode)\n'
			.. '\t\t\tend\n'
			.. '\t\tend\n'
			.. '\tend\n' },
	{ function() return manager("RoundManager") end, "match",
		'\t\t\tm.left = true\n'
			.. '\t\t\tplayer:SetAttribute("InMatch", false)\n',
		'\t\t\tm.left = true\n'
			.. '\t\t\tplayer:SetAttribute("InMatch", false)\n'
			.. '\t\t\t-- [RANKED] v3 leaving a ranked match: normal loss + LeavePenalty (before backToLobby releases the profile)\n'
			.. '\t\t\trankedLeave(match, m, "leave")\n' },
	-- lobby MatchmakingManager
	{ function() return manager("MatchmakingManager") end, "lobby",
		'local Remotes = require(ServerScriptService.Lobby.LobbyRemotes)\n',
		'local Remotes = require(ServerScriptService.Lobby.LobbyRemotes)\n'
			.. '-- [RANKED] Edward\'s ranked window (notes/ranked_server.md): RankedCore maths, RankedServer records\n'
			.. 'local RankedCore = require(ReplicatedStorage.Modules.Shared.RankedCore)\n'
			.. 'local RankedServer = require(ServerScriptService.Shared.RankedServer)\n' },
	{ function() return manager("MatchmakingManager") end, "lobby",
		'local function ratingOf(player: Player, mode: string): number\n'
			.. '\tlocal data = PlayerStore.Get(player)\n'
			.. '\tlocal r = data and data.Ranked and data.Ranked[mode]\n'
			.. '\treturn (r and r.Rating) or Config.StartingRating\n'
			.. 'end\n',
		'local function ratingOf(player: Player, mode: string): number\n'
			.. '\t-- [RANKED] the unified record\'s Elo (lazy migration of the old Rating)\n'
			.. '\treturn RankedServer.EloOf(player, mode)\n'
			.. 'end\n' },
	{ function() return manager("MatchmakingManager") end, "lobby",
		'\tlocal entry = { u = player.UserId, j = game.JobId, r = ratingOf(player, q.Mode), t = now }\n',
		'\tlocal entry = { u = player.UserId, j = game.JobId, r = ratingOf(player, q.Mode), t = now }\n'
			.. '\t-- [RANKED] the tier rides in the queue entry (k) for RankedCore\'s window\n'
			.. '\tentry.k = RankedCore.TierOf(entry.r)\n' },
	{ function() return manager("MatchmakingManager") end, "lobby",
		'\tsearching[player] = { queue = q.Id, key = key, since = now, refreshed = os.clock(), status = "Searching", rating = entry.r }\n',
		'\t-- [RANKED] tier kept with the search (the refresh below re-creates an expired entry with it)\n'
			.. '\tsearching[player] = { queue = q.Id, key = key, since = now, refreshed = os.clock(), status = "Searching", rating = entry.r, tier = entry.k }\n' },
	{ function() return manager("MatchmakingManager") end, "lobby",
		'\t\t\t\t\t\treturn { u = player.UserId, j = game.JobId, r = s.rating, t = s.since }, s.since\n',
		'\t\t\t\t\t\t-- [RANKED] k = tier\n'
			.. '\t\t\t\t\t\treturn { u = player.UserId, j = game.JobId, r = s.rating, k = s.tier, t = s.since }, s.since\n' },
	{ function() return manager("MatchmakingManager") end, "lobby",
		'\tif not ranked then\n'
			.. '\t\treturn table.move(pool, 1, need, 1, {})\n'
			.. '\tend\n',
		'\tif not ranked then\n'
			.. '\t\treturn table.move(pool, 1, need, 1, {})\n'
			.. '\tend\n'
			.. '\t-- [RANKED] Edward\'s window (RankedCore.Window: 1v1 2 tiers at 0 s, 6 at 5 min, 18 at 60 min; 2v2 twice and 3v3 four times\n'
			.. '\t-- as fast) and the pair rule (every pair inside each other\'s window), oldest first; a party entry (v.n players)\n'
			.. '\t-- queues at its average tier (v.k). The old rating-gap pick below is no longer reached.\n'
			.. '\tdo return RankedCore.PickGroup(pool, need, now, mode) end\n' },
	{ function() return manager("MatchmakingManager") end, "lobby",
		'local function pickGroup(pool, need: number, ranked: boolean, now: number)\n',
		'-- [RANKED] mode = the queue\'s mode (RankedCore.Window widens faster in 2v2 / 3v3)\n'
			.. 'local function pickGroup(pool, need: number, ranked: boolean, now: number, mode: string?)\n' },
	{ function() return manager("MatchmakingManager") end, "lobby",
		'\t\t\tlocal group = pickGroup(pool, need, q.Ranked, now)\n',
		'\t\t\t-- [RANKED] the queue\'s mode for the window\n'
			.. '\t\t\tlocal group = pickGroup(pool, need, q.Ranked, now, q.Mode)\n' },
	-- lobby Template + PlayerStore
	{ function() local d = SSS:FindFirstChild("Data") return d and d:FindFirstChild("DataManager") and d.DataManager:FindFirstChild("Template") end, "lobby",
		'\tRanked = {},                -- [mode] = { Rating, Wins, Losses } for the ranked queues\n',
		'\t-- [RANKED] [ladder key] = { V, Elo, Peak, Placed, Wins, Losses, Streak, ShieldDay, LastPlayed, Decayed, Rating (= Elo, mirror) };\n'
			.. '\t-- created / migrated from the old { Rating, Wins, Losses } / { Rating, Played, Wins } by ServerScriptService.Shared.RankedServer\n'
			.. '\tRanked = {},\n' },
	{ function() local d = SSS:FindFirstChild("Data") return d and d:FindFirstChild("PlayerStore") end, "lobby",
		'\nreturn PlayerStore\n',
		'\n-- [RANKED] the unified ranked record of a mode\'s ladder (lazy migration): ServerScriptService.Shared.RankedServer\n'
			.. 'function PlayerStore.Ranked(player: Player, mode: string?)\n'
			.. '\treturn require(game:GetService("ServerScriptService").Shared.RankedServer).Record(player, mode)\n'
			.. 'end\n'
			.. '\nreturn PlayerStore\n' },
}

local function backup(s)
	local name = "RANKED_" .. s.Name .. "_Orig"
	if not bin:FindFirstChild(name) and not s.Source:find("[RANKED]", 1, true) then
		local b = s:Clone(); b.Name = name; b:ClearAllChildren()
		if b:IsA("BaseScript") then b.Disabled = true end
		b.Parent = bin
		say("backup", name)
	end
end
local function applies(e) return e[2] == "both" or (e[2] == "lobby") == IS_LOBBY end

-- new scripts (ours = attribute RankedInstall)
local function ensureFolder(parent, name)
	local f = parent:FindFirstChild(name)
	if not f then f = Instance.new("Folder"); f.Name = name; f.Parent = parent end
	return f
end
local function ensureScript(parent, name, class, src)
	local s = parent:FindFirstChild(name)
	if s and (s.ClassName ~= class) then
		if s:GetAttribute(TAG) then s:Destroy(); s = nil else say("WARN", s:GetFullName(), "exists and is not ours: skipped"); return s end
	end
	if not s then s = Instance.new(class); s.Name = name; s:SetAttribute(TAG, true); s.Parent = parent; say("created", s:GetFullName()) end
	if not s:GetAttribute(TAG) and s.Source ~= src then
		-- the admin installers also write Commands.Ranked (same file): take it over
		s:SetAttribute(TAG, true)
	end
	if s.Source ~= src then s.Source = src; say(class, s:GetFullName(), "written") else say(class, s:GetFullName(), "up to date") end
	if s:IsA("BaseScript") then s.Disabled = false end
	return s
end

if UNDO then
	for i = #EDITS, 1, -1 do
		local e = EDITS[i]
		local s = applies(e) and e[1]()
		if s then
			local a, b = s.Source:find(e[4], 1, true)
			if a then s.Source = s.Source:sub(1, a - 1) .. e[3] .. s.Source:sub(b + 1); say("UNDO edit", i, s.Name)
			elseif s.Source:find(e[3], 1, true) then say("edit", i, s.Name, "not applied")
			else say("WARN edit", i, s.Name, "neither text found (changed by hand? backup RANKED_" .. s.Name .. "_Orig kept)") end
			local bak = bin:FindFirstChild("RANKED_" .. s.Name .. "_Orig")
			if bak and not s.Source:find("[RANKED]", 1, true) then
				say(s.Name, bak.Source == s.Source and "matches its backup" or "WARN differs from its backup")
				bak:Destroy()
			end
		end
	end
	local made = {}
	for _, root in { RS, SSS } do
		for _, d in root:GetDescendants() do if d:GetAttribute(TAG) then table.insert(made, d) end end
	end
	for _, d in made do say("removed", d:GetFullName()); d:Destroy() end
else
	if next(SOURCES) == nil then error("no embedded sources: run python tools/ranked_build.py first") end
	ensureScript(RS.Modules.Shared, "RankedCore", "ModuleScript", SOURCES.RankedCore)
	ensureScript(ensureFolder(SSS, "Shared"), "RankedServer", "ModuleScript", SOURCES.RankedServer)
	ensureScript(SSS, "RankedService", "Script", SOURCES.RankedService)
	local fw = SSS:FindFirstChild("AdminFramework")
	if fw then ensureScript(ensureFolder(fw, "Commands"), "Ranked", "ModuleScript", SOURCES.Cmd_Ranked)
	else say("WARN no AdminFramework: ranked admin commands not installed") end
	for i, e in EDITS do
		local s = applies(e) and e[1]()
		if not applies(e) then -- other place
		elseif not s then say("WARN missing script for edit", i)
		elseif s.Source:find(e[4], 1, true) then say("edit", i, s.Name, "already in")
		else
			local a, b = s.Source:find(e[3], 1, true)
			if a then
				backup(s)
				s.Source = s.Source:sub(1, a - 1) .. e[4] .. s.Source:sub(b + 1)
				say("edit", i, s.Name, "applied")
			else say("WARN edit", i, s.Name, "anchor text not found") end
		end
	end
end
if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
return table.concat(log, "\n")
