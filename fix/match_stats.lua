-- fix/match_stats.lua [STATS] 2026-10-20 (Edward's RIVALS results card via the UI session): MatchResults summary gains
--   Assists      enemies who damaged a victim during that life, other than the killer
--   DamageDealt  total damage this player dealt to enemies this match (whole HP, the health actually removed)
--   DamageTaken  total damage this player took this match
-- MatchCore (both places): each match character's Humanoid.HealthChanged drops are credited to its LastAttacker (every damage
-- source sets it before applying damage); heals are ignored. Idempotent; UNDO swaps back.
local UNDO = false --@UNDO
local MC = game:GetService("ServerScriptService"):FindFirstChild("MatchCore", true)
assert(MC, "no MatchCore")

local edits = {
	{ "\tctx.tally[uid] = ctx.tally[uid] or { kills = 0, headshots = 0, melee = 0, deaths = 0 }\n",
	  "\tctx.tally[uid] = ctx.tally[uid] or { kills = 0, headshots = 0, melee = 0, deaths = 0, assists = 0, dealt = 0, taken = 0 } -- [STATS]\n" },
	{ "\tlocal humanoid = character:FindFirstChildOfClass(\"Humanoid\") or character:WaitForChild(\"Humanoid\", 10)\n\tif not humanoid then return end\n",
	  "\tlocal humanoid = character:FindFirstChildOfClass(\"Humanoid\") or character:WaitForChild(\"Humanoid\", 10)\n\tif not humanoid then return end\n"
	  .. "\t-- [STATS] damage dealt / taken and assist credit: each health drop goes to the LastAttacker (set before every hit)\n"
	  .. "\tlocal lastHealth = humanoid.Health\n"
	  .. "\tlocal hitters = {} -- [attacker userId] = true: enemies who damaged this body during this life\n"
	  .. "\thumanoid.HealthChanged:Connect(function(h)\n"
	  .. "\t\tlocal delta = lastHealth - h\n"
	  .. "\t\tlastHealth = h\n"
	  .. "\t\tif delta <= 0 or ctx.over or MatchCore.character(m) ~= character then return end\n"
	  .. "\t\tt(ctx, m.userId).taken += delta\n"
	  .. "\t\tlocal aid = humanoid:GetAttribute(\"LastAttacker\")\n"
	  .. "\t\tlocal attacker = type(aid) == \"number\" and aid ~= 0 and memberById(ctx, aid)\n"
	  .. "\t\tif attacker and attacker ~= m and MatchCore.getAttr(attacker, \"Team\") ~= MatchCore.getAttr(m, \"Team\") then\n"
	  .. "\t\t\tt(ctx, attacker.userId).dealt += delta\n"
	  .. "\t\t\thitters[attacker.userId] = true\n"
	  .. "\t\tend\n"
	  .. "\tend)\n" },
	{ "\t\t\tMatchCore.setAttr(killer, \"MatchKills\", k.kills)\n\t\tend\n",
	  "\t\t\tMatchCore.setAttr(killer, \"MatchKills\", k.kills)\n\t\tend\n"
	  .. "\t\t-- [STATS] assists: every other enemy who damaged this body during this life\n"
	  .. "\t\tfor uid in hitters do\n"
	  .. "\t\t\tif not (killer and uid == killer.userId) then t(ctx, uid).assists += 1 end\n"
	  .. "\t\tend\n" },
	{ "\t\tKills = st.kills, Headshots = st.headshots, MeleeKills = st.melee, Deaths = st.deaths,\n",
	  "\t\tKills = st.kills, Headshots = st.headshots, MeleeKills = st.melee, Deaths = st.deaths,\n"
	  .. "\t\tAssists = st.assists or 0, DamageDealt = math.floor((st.dealt or 0) + 0.5), DamageTaken = math.floor((st.taken or 0) + 0.5), -- [STATS]\n" },
}

local s = MC.Source
local out = {}
for i, e in edits do
	local old, new = e[1], e[2]
	local done
	if UNDO then old, new = new, old; done = not s:find(old, 1, true) else done = s:find(new, 1, true) ~= nil end
	if done then table.insert(out, i .. "=") else
		local a, b = s:find(old, 1, true)
		assert(a, "edit " .. i .. " anchor not found")
		assert(not s:find(old, b + 1, true), "edit " .. i .. " anchor not unique")
		s = s:sub(1, a - 1) .. new .. s:sub(b + 1)
		table.insert(out, i .. "+")
	end
end
local f, err = loadstring(s)
assert(f, "MatchCore would not parse: " .. tostring(err))
if MC.Source ~= s then MC.Source = s end
return "MatchCore " .. table.concat(out, " ")
