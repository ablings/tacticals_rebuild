-- ReplicatedStorage/Modules/Shared/RankedCore (ModuleScript) [RANKED] 2026-10-16, notes/ranked_server.md
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
