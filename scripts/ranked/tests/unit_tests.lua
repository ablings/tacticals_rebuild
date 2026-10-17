-- RankedCore unit tests [RANKED] (notes/ranked_server.md). Run: python tools/ranked_test.py [lobby|match]
-- (prepends FIXTURE = scripts/ranked/tests/fixture_v2.lua and runs this in Edit against a fresh clone of the installed RankedCore).
local src = game:GetService("ReplicatedStorage").Modules.Shared:FindFirstChild("RankedCore")
assert(src, "RankedCore not installed")
local clone = src:Clone()
local RC = require(clone)
local C = RC.Config
local pass, fail, fails = 0, 0, {}
local function eq(name, got, want)
	if got == want then pass += 1 else fail += 1; table.insert(fails, ("%s: got %s want %s"):format(name, tostring(got), tostring(want))) end
end

-- 1. the 11 checks of tools/ranked_table.py (Edward's examples), exactly
local function T(r) return r * 3 end
eq("Bronze 1 beats Bronze 1", RC.Gain(0, 0), 30)
eq("Bronze 1 beats Gold 1", RC.Gain(0, T(2)), 60)
eq("Bronze 1 loses to Bronze 1", RC.Loss(0, 0), 10)
eq("Bronze 1 loses to Gold 1", RC.Loss(0, T(2)), 5)
eq("Gold 1 beats Gold 1", RC.Gain(T(2), T(2)), 25)
eq("Gold 1 beats Bronze 1", RC.Gain(T(2), 0), 10)
eq("Gold 1 loses to Gold 1", RC.Loss(T(2), T(2)), 15)
eq("Gold 1 loses to Bronze 1", RC.Loss(T(2), 0), 60)
eq("Commander beats Commander", RC.Gain(T(6), T(6)), 10)
eq("Commander loses to Commander", RC.Loss(T(6), T(6)), 25)
eq("Commander loses to Diamond (max 60)", RC.Loss(T(6), T(4)), 60)
local edward = pass
-- the lead's v2 in-between examples
eq("Gold 2 beats Gold 1", RC.Gain(7, 6), 20)
eq("Gold 2 loses to Gold 1", RC.Loss(7, 6), 23)
eq("Gold 2 beats Gold 3", RC.Gain(7, 8), 27)

-- 2. every tier vs every tier = the Python reference (882 values, incl. its half-to-even rounding)
local tableBad = 0
for m = 0, 20 do
	for o = 0, 20 do
		local i = m * 21 + o + 1
		if RC.Gain(m, o) ~= FIXTURE.gain[i] then tableBad += 1; if tableBad < 5 then table.insert(fails, ("gain %d vs %d: %d want %d"):format(m, o, RC.Gain(m, o), FIXTURE.gain[i])) end end
		if RC.Loss(m, o) ~= FIXTURE.loss[i] then tableBad += 1; if tableBad < 5 then table.insert(fails, ("loss %d vs %d: %d want %d"):format(m, o, RC.Loss(m, o), FIXTURE.loss[i])) end end
	end
end
eq("full 21x21 table mismatches", tableBad, 0)
eq("pyRound 2.5", RC._pyRound(2.5), 2); eq("pyRound 3.5", RC._pyRound(3.5), 4); eq("pyRound 2.4999", RC._pyRound(2.4999), 2)

-- 3. clamp 1..100 and the floor
eq("clamp max: Bronze 1 beats Commander 3", RC.Gain(0, 20), 100)
eq("clamp min: Commander 3 beats Bronze 1", RC.Gain(20, 0), 1)
eq("clamp max: Commander 3 loses to Bronze 1", RC.Loss(20, 0), 100)
eq("clamp min: Bronze 1 loses to Commander 3", RC.Loss(0, 20), 1)
eq("floor: 105 loses 10 -> 100", math.max(C.Floor, 105 + RC.Delta(105, 0, false)), 100)
eq("ClampElo 40", RC.ClampElo(40), 100)
eq("Delta win sign", RC.Delta(700, 6, true), 25)
eq("Delta loss sign", RC.Delta(700, 6, false), -15)
eq("Delta draw", RC.Delta(700, 6, false, true), 0)
eq("Delta team avg tier 7 (Gold 2 avg) for Gold 1 win", RC.Delta(700, RC.AverageTier({ 700, 900 }), true), RC.Gain(6, 7))

-- 4. ladder
local function nm(elo, cut, place) return RC.Info(elo, cut, place).name end
eq("100", nm(100), "Bronze 1"); eq("399", nm(399), "Bronze 3"); eq("400", nm(400), "Silver 1"); eq("700", nm(700), "Gold 1")
eq("1000", nm(1000), "Platinum 1"); eq("1300", nm(1300), "Diamond 1"); eq("1600", nm(1600), "Elite 1"); eq("1900", nm(1900), "Commander 1")
eq("2100", nm(2100), "Commander 3"); eq("2199", nm(2199), "Commander 3"); eq("0 -> floor", nm(0), "Bronze 1")
eq("2500 below cutoff 2600", nm(2500, 2600), "Commander 3"); eq("2500 no cutoff", nm(2500, nil), "Warlord")
eq("2650 cutoff 2600 place 12", nm(2650, 2600, 12), "Warlord #12"); eq("2199 never Warlord", nm(2199, nil), "Commander 3")
eq("tier 2500", RC.TierOf(2500), 20); eq("division Gold 2", RC.Info(850).division, 2); eq("Warlord division", RC.Info(2300).division, 0)
eq("next floor Gold 1", RC.Info(700).nextFloor, 800); eq("next name Commander 3", RC.Info(2150).nextName, "Warlord")

-- 5. matchmaking window (tiers)
eq("window 0 s", RC.Window(0), 2); eq("window 150 s", RC.Window(150), 4); eq("window 5 min", RC.Window(300), 6)
eq("window 32.5 min", RC.Window(1950), 12); eq("window 60 min", RC.Window(3600), 18); eq("window 2 h", RC.Window(7200), 18)
eq("pair Bronze1-Bronze3 t0", RC.PairOk(0, 0, 2, 0), true)
eq("pair Bronze1-Gold1 t0", RC.PairOk(0, 0, 6, 0), false)
eq("pair Bronze1-Gold1 both 5 min", RC.PairOk(0, 300, 6, 300), true)
eq("pair Bronze1-Gold1 one waited (B at 0 s)", RC.PairOk(0, 300, 6, 0), false)
eq("pair Bronze1-Commander1 60 min", RC.PairOk(0, 3600, 18, 3600), true)
eq("pair Bronze1-Commander1 50 min", RC.PairOk(0, 3000, 18, 3000), false)
local now = 10000
local pool = {
	{ key = "a", v = { u = 1, t = now - 400, k = 0 } },   -- Bronze 1, 6.7 min
	{ key = "b", v = { u = 2, t = now - 10, k = 9 } },    -- Platinum 1, 10 s
	{ key = "c", v = { u = 3, t = now - 350, k = 6 } },   -- Gold 1, 5.8 min
}
local g = RC.PickGroup(pool, 2, now)
eq("pick a+c (both waited, 6 tiers)", g and (g[1].key .. g[2].key), "ac")
pool[3].v.t = now - 5
g = RC.PickGroup(pool, 2, now)
eq("pick none (c just joined: its window is 2)", g, nil)
eq("pick solo (need 1)", RC.PickGroup(pool, 1, now)[1].key, "a")
local team = { { key = "a", v = { t = now - 20, k = 3 } }, { key = "b", v = { t = now - 20, k = 4 } }, { key = "c", v = { t = now - 20, k = 9 } },
	{ key = "d", v = { t = now - 20, k = 4 } }, { key = "e", v = { t = now - 20, k = 2 } } }
g = RC.PickGroup(team, 4, now)
local keys = {} for _, e in g or {} do table.insert(keys, e.key) end
eq("2v2 pick every pair valid (a b d e)", table.concat(keys), "abde")


-- 6. Season 1 reset (Edward 2026-10-17: everyone starts at Bronze 1 = 100, old ratings do NOT carry over)
eq("default: MigrateOldRating off", C.MigrateOldRating, false); eq("default: Season 1", C.Season, 1)
local r = RC.Migrate({ Rating = 1350, Wins = 5, Losses = 1 })
eq("reset: lobby 1350 -> 100", r.Elo, 100); eq("reset wins 0", r.Wins, 0); eq("reset losses 0", r.Losses, 0); eq("reset placed 0", r.Placed, 0)
eq("reset season", r.S, 1); eq("reset keeps Prev Elo", r.Prev and r.Prev.Elo, 1350); eq("reset LastPlayed 0", r.LastPlayed, 0)
r = RC.Migrate({ Rating = 1690, Played = 10, Wins = 6 })
eq("reset: match shape 1690 -> 100", r.Elo, 100); eq("reset: match shape peak 100", r.Peak, 100)
local v2 = { V = 1, Elo = 825, Rating = 825, Peak = 900, Placed = 0, Wins = 7, Losses = 4, Streak = 1, ShieldDay = 0, LastPlayed = 5, Decayed = 0 }
local same, changed = RC.Migrate(v2)
eq("reset: v2 record (no season) -> 100", same.Elo, 100); eq("... changed", changed, true); eq("... Prev peak", same.Prev.Peak, 900)
eq("reset: mirror entry -> fresh, no Prev", RC.Migrate({ Mirror = "All", Rating = 800 }).Prev, nil)
r = RC.Migrate(nil)
eq("new player", r.Elo, 100); eq("new placed", r.Placed, 0); eq("new streak", r.Streak, 0); eq("new S", r.S, 1)
local v3 = { V = 1, S = 1, Elo = 812, Rating = 812, Peak = 900, Placed = 10, Wins = 9, Losses = 4, Streak = 2, ShieldDay = 0, LastPlayed = 5, Decayed = 0 }
same, changed = RC.Migrate(v3)
eq("season-1 record unchanged", same.Elo, 812); eq("season-1 not changed", changed, false); eq("peak kept", same.Peak, 900)
v3.Rating = 1500
same, changed = RC.Migrate(v3)
eq("external Rating write -> Elo follows", same.Elo, 1500); eq("... changed", changed, true); eq("... peak", same.Peak, 1500)
C.Season = 2
eq("season bump resets a season-1 record", RC.Migrate({ V = 1, S = 1, Elo = 1500, Rating = 1500 }).Elo, 100)
C.Season = 1
-- the old carry-over still works as an option
C.MigrateOldRating = true
r = RC.Migrate({ Rating = 1000, Wins = 3, Losses = 2 })
eq("carry: lobby shape 1000 -> 100", r.Elo, 100); eq("carry wins", r.Wins, 3); eq("carry losses", r.Losses, 2); eq("carry V", r.V, 1)
eq("carry: lobby 1350 -> 450", RC.Migrate({ Rating = 1350, Wins = 5, Losses = 1 }).Elo, 450)
r = RC.Migrate({ Rating = 1100, Played = 7, Wins = 4 })
eq("carry: match shape 1100 -> 200", r.Elo, 200); eq("carry: losses = Played - Wins", r.Losses, 3)
eq("carry: below start -> floor", RC.Migrate({ Rating = 870, Played = 3, Wins = 0 }).Elo, 100)
eq("carry: placements 4 of old matches", RC.Migrate({ Rating = 1000, Wins = 2, Losses = 2 }).Placed, 4)
eq("carry never applies to a v2 record", RC.Migrate({ V = 1, Elo = 900, Rating = 900 }).Elo, 100)
C.MigrateOldRating = false

-- 7. placements, shield, decay, leave (Edward's numbers are the defaults now)
eq("placements 10", C.Placements, 10); eq("placement x2", C.PlacementMultiplier, 2)
eq("shield on", C.ShieldEnabled, true); eq("shield below 1600", C.ShieldBelowElo, 1600)
eq("decay on", C.DecayEnabled, true); eq("decay from 1600", C.DecayFromElo, 1600); eq("decay 7 days", C.DecayIdleDays, 7); eq("decay 25/day", C.DecayPerDay, 25)
eq("leave +25", C.LeavePenalty, 25); eq("draw 0", C.DrawDelta, 0)
local t0 = 20000 * 86400
eq("shield not in placements", RC.ShieldReady({ Elo = 500, Placed = 3, ShieldDay = 0 }, t0), false)
local rec = { Elo = 500, Placed = 10, ShieldDay = 0 }
eq("shield ready placed, 500", RC.ShieldReady(rec, t0), true)
rec.ShieldDay = RC.Day(t0)
eq("shield used today", RC.ShieldReady(rec, t0), false)
eq("shield next day", RC.ShieldReady(rec, t0 + 86400), true)
eq("no shield at Elite 1", RC.ShieldReady({ Elo = 1600, Placed = 10, ShieldDay = 0 }, t0), false)
eq("shield at Diamond 3", RC.ShieldReady({ Elo = 1599, Placed = 10, ShieldDay = 0 }, t0), true)
C.ShieldEnabled = false
eq("shield flag off", RC.ShieldReady({ Elo = 500, Placed = 10, ShieldDay = 0 }, t0), false)
C.ShieldEnabled = true
local d = { Elo = 2000, LastPlayed = t0 - 10 * 86400, Decayed = 0 }
local loss, days = RC.DecayDue(d, t0)
eq("decay 10 idle days, 7 free -> 3 x 25", loss, 75); eq("decay days", days, 3)
eq("decay 7 idle days -> 0", (RC.DecayDue({ Elo = 2000, LastPlayed = t0 - 7 * 86400, Decayed = 0 }, t0)), 0)
eq("decay 8 idle days -> 25", (RC.DecayDue({ Elo = 2000, LastPlayed = t0 - 8 * 86400, Decayed = 0 }, t0)), 25)
d.Decayed = 3
eq("decay already charged", (RC.DecayDue(d, t0)), 0)
eq("decay stops at Elite 1 (1630 -> -30)", (RC.DecayDue({ Elo = 1630, LastPlayed = t0 - 30 * 86400, Decayed = 0 }, t0)), 30)
eq("no decay at 1600", (RC.DecayDue({ Elo = 1600, LastPlayed = t0 - 30 * 86400, Decayed = 0 }, t0)), 0)
eq("no decay below Elite (Diamond 3)", (RC.DecayDue({ Elo = 1599, LastPlayed = t0 - 30 * 86400, Decayed = 0 }, t0)), 0)
eq("no decay never played", (RC.DecayDue({ Elo = 2000, LastPlayed = 0, Decayed = 0 }, t0)), 0)
C.DecayEnabled = false
eq("decay flag off", (RC.DecayDue({ Elo = 2000, LastPlayed = t0 - 30 * 86400, Decayed = 0 }, t0)), 0)
C.DecayEnabled = true
eq("leave delta = the normal loss (Gold 1 vs Gold 1)", RC.LeaveDelta(700, 6), -15)
eq("leave delta 2v2 blend (Commander+Bronze vs Plat)", RC.LeaveDelta(1900, 9, 9), -50)

-- 8. one shared ladder
eq("PerModeLadders off", C.PerModeLadders, false)
eq("shared key 1v1", RC.LadderKey("1v1"), "All"); eq("shared key 2v2", RC.LadderKey("2v2"), "All"); eq("shared key 3v3", RC.LadderKey("3v3"), "All")
eq("shared key nil", RC.LadderKey(nil), "All"); eq("one ladder", #RC.LadderKeys(), 1); eq("ladder All", RC.LadderKeys()[1], "All")
C.PerModeLadders = true
eq("per-mode key (switch back)", RC.LadderKey("2v2"), "2v2")
C.PerModeLadders = false
eq("leaderboard season store version", C.LeaderboardVersion, "s1")

-- 9. team ELO (Edward: effective tier = (own tier + own team's average tier) / 2 vs the other team's average tier)
local CMD, BRZ, PLAT = 1900, 100, 1000 -- Commander 1, Bronze 1, Platinum 1
local own = RC.AverageTier({ CMD, BRZ })   -- 9
local opp = RC.AverageTier({ PLAT, PLAT }) -- 9
eq("2v2 Commander (+Bronze) vs Plat+Plat win", RC.Delta(CMD, opp, true, false, own), 8)
eq("2v2 Commander (+Bronze) vs Plat+Plat loss", RC.Delta(CMD, opp, false, false, own), -50)
eq("2v2 Bronze (+Commander) vs Plat+Plat win", RC.Delta(BRZ, opp, true, false, own), 45)
eq("2v2 Bronze (+Commander) vs Plat+Plat loss", RC.Delta(BRZ, opp, false, false, own), -8)
eq("2v2 Plat vs Commander+Bronze win (even: solo numbers)", RC.Delta(PLAT, own, true, false, opp), RC.Gain(9, 9))
local evenBad = 0
for t = 0, 20 do
	for o = 0, 20 do
		local e = (t + 1) * 100
		if RC.Delta(e, o, true, false, t) ~= RC.Gain(t, o) or RC.Delta(e, o, false, false, t) ~= -RC.Loss(t, o) then evenBad += 1 end
	end
end
eq("even teams = the solo numbers (441 tier pairs)", evenBad, 0)
eq("3v3 Gold1+Gold1+Gold1 vs Gold1 x3 = solo", RC.Delta(700, RC.AverageTier({ 700, 700, 700 }), true, false, RC.AverageTier({ 700, 700, 700 })), 25)
eq("draw stays 0 in a team", RC.Delta(CMD, opp, false, true, own), 0)
eq("TeamTier blend", RC.TeamTier(18, 9), 13.5); eq("TeamTier 1v1 (no team)", RC.TeamTier(18, nil), 18)
eq("Python reference: fixture team checks", FIXTURE.team and table.concat(FIXTURE.team, ","), "8,50,45,8")

-- 10. per-mode queue windows (Edward: full spread at 60 / 30 / 15 min; the +-2-rank point at 5 / 2.5 / 1.25 min)
eq("1v1 window 5 min", RC.Window(300, "1v1"), 6); eq("1v1 window 60 min", RC.Window(3600, "1v1"), 18)
eq("2v2 window 2.5 min", RC.Window(150, "2v2"), 6); eq("2v2 window 30 min", RC.Window(1800, "2v2"), 18)
eq("2v2 window 0 s", RC.Window(0, "2v2"), 2); eq("2v2 window 75 s", RC.Window(75, "2v2"), 4)
eq("3v3 window 1.25 min", RC.Window(75, "3v3"), 6); eq("3v3 window 15 min", RC.Window(900, "3v3"), 18)
eq("3v3 window 2 h", RC.Window(7200, "3v3"), 18); eq("2v2 window 16.25 min", RC.Window(975, "2v2"), 12)
eq("pair Bronze1-Commander1 2v2 30 min", RC.PairOk(0, 1800, 18, 1800, "2v2"), true)
eq("pair Bronze1-Commander1 2v2 25 min", RC.PairOk(0, 1500, 18, 1500, "2v2"), false)
eq("pair Bronze1-Commander1 3v3 15 min", RC.PairOk(0, 900, 18, 900, "3v3"), true)
eq("pair Bronze1-Commander1 1v1 30 min", RC.PairOk(0, 1800, 18, 1800, "1v1"), false)
eq("pair Bronze1-Gold1 2v2 both 2.5 min", RC.PairOk(0, 150, 6, 150, "2v2"), true)
-- a team queues at its average tier: a party entry (n players, k = PartyTier)
eq("PartyTier Commander1 + Bronze1", RC.PartyTier({ 1900, 100 }), 9)
local partyPool = {
	{ key = "P", v = { t = now - 60, k = RC.PartyTier({ 1900, 100 }), n = 2 } }, -- Commander + Bronze party, avg Platinum 1
	{ key = "x", v = { t = now - 50, k = 0 } },  -- Bronze 1 solo (9 tiers off: not yet)
	{ key = "y", v = { t = now - 40, k = 9 } },  -- Platinum 1
	{ key = "z", v = { t = now - 30, k = 10 } }, -- Platinum 2
}
g = RC.PickGroup(partyPool, 4, now, "2v2")
keys = {} for _, e in g or {} do table.insert(keys, e.key) end
eq("2v2 pick: party (avg Plat 1) + two Plats", table.concat(keys), "Pyz")
eq("2v2 pick: a party of 3 can't fill 4 with one solo", RC.PickGroup({ { key = "Q", v = { t = now, k = 3, n = 3 } } }, 4, now, "2v2"), nil)
eq("1v1 pick solo (need 1)", RC.PickGroup({ { key = "s", v = { t = now, k = 5 } } }, 1, now, "1v1")[1].key, "s")

clone:Destroy()
return ("RankedCore unit tests: %d passed, %d failed (Edward's 11 checks: %d/11)\n%s"):format(pass, fail, edward, table.concat(fails, "\n"))
