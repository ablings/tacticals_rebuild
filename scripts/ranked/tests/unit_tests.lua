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

-- 6. migration from both old shapes
local r = RC.Migrate({ Rating = 1000, Wins = 3, Losses = 2 })
eq("lobby shape 1000 -> Elo", r.Elo, 100); eq("lobby wins", r.Wins, 3); eq("lobby losses", r.Losses, 2); eq("lobby V", r.V, 1)
r = RC.Migrate({ Rating = 1350, Wins = 5, Losses = 1 })
eq("lobby 1350 -> 450", r.Elo, 450); eq("peak", r.Peak, 450); eq("mirror Rating", r.Rating, 450)
r = RC.Migrate({ Rating = 1100, Played = 7, Wins = 4 })
eq("match shape 1100 -> 200", r.Elo, 200); eq("match wins", r.Wins, 4); eq("match losses = Played - Wins", r.Losses, 3)
r = RC.Migrate({ Rating = 870, Played = 3, Wins = 0 })
eq("match shape below start -> floor", r.Elo, 100); eq("losses 3", r.Losses, 3)
r = RC.Migrate(nil)
eq("new player", r.Elo, 100); eq("new placed", r.Placed, 0); eq("new streak", r.Streak, 0)
local v1 = { V = 1, Elo = 812, Rating = 812, Peak = 900, Placed = 0, Wins = 9, Losses = 4, Streak = 2, ShieldDay = 0, LastPlayed = 5, Decayed = 0 }
local same, changed = RC.Migrate(v1)
eq("unified record unchanged", same.Elo, 812); eq("unified not changed", changed, false); eq("peak kept", same.Peak, 900)
v1.Rating = 1500
same, changed = RC.Migrate(v1)
eq("external Rating write -> Elo follows", same.Elo, 1500); eq("... changed", changed, true); eq("... peak", same.Peak, 1500)
C.MigrateOldRating = false
eq("MigrateOldRating off -> start", RC.Migrate({ Rating = 1600 }).Elo, 100)
C.MigrateOldRating = true
C.Placements = 10
eq("placements on: old 4 matches -> placed 4", RC.Migrate({ Rating = 1000, Wins = 2, Losses = 2 }).Placed, 4)
C.Placements = 0

-- 7. shield and decay flags
local t0 = 20000 * 86400
local rec = { Elo = 500, Placed = 0, ShieldDay = 0 }
eq("shield off by default", RC.ShieldReady(rec, t0), false)
C.ShieldEnabled = true
eq("shield on, 500", RC.ShieldReady(rec, t0), true)
rec.ShieldDay = RC.Day(t0)
eq("shield used today", RC.ShieldReady(rec, t0), false)
eq("shield next day", RC.ShieldReady(rec, t0 + 86400), true)
eq("no shield at Elite", RC.ShieldReady({ Elo = 1600, Placed = 0, ShieldDay = 0 }, t0), false)
C.ShieldEnabled = false
local d = { Elo = 2500, LastPlayed = t0 - 10 * 86400, Decayed = 0 }
eq("decay off by default", (RC.DecayDue(d, t0)), 0)
C.DecayEnabled = true
local loss, days = RC.DecayDue(d, t0)
eq("decay 10 idle days, 7 free -> 3 x 50", loss, 150); eq("decay days", days, 3)
d.Decayed = 3
eq("decay already charged", (RC.DecayDue(d, t0)), 0)
eq("decay stops at 2200", (RC.DecayDue({ Elo = 2230, LastPlayed = t0 - 10 * 86400, Decayed = 0 }, t0)), 30)
eq("no decay below 2200", (RC.DecayDue({ Elo = 2100, LastPlayed = t0 - 30 * 86400, Decayed = 0 }, t0)), 0)
C.DecayEnabled = false

-- 8. ladder key
eq("per-mode key", RC.LadderKey("2v2"), "2v2")
C.PerModeLadders = false
eq("shared key", RC.LadderKey("2v2"), "All")
C.PerModeLadders = true

clone:Destroy()
return ("RankedCore unit tests: %d passed, %d failed (Edward's 11 checks: %d/11)\n%s"):format(pass, fail, edward, table.concat(fails, "\n"))
