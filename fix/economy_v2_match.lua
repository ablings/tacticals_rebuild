-- fix/economy_v2_match.lua [ECON2] 2026-10-22 (match places; run fix/economy_v2_config.lua first). Edward approved the economy
-- (notes/economy/scissors_economy.md section 4) and the server pieces the UI waits on:
--   MatchCore       live per-player MatchHeadshots / MatchMeleeKills next to MatchKills (reset with them at the match start)
--   RoundManager    +LobbyConfig.LevelUpReward scissors per account level gained at the match end (summary.LevelUpScissors)
--   Template        Login, DailyFreeKey, Contracts (same profile as the lobby)
--   MatchQuestFeed  new Script: player attributes MatchQuests (JSON) + QuestTick for the in-match Daily Tasks panel
--                   (source: scripts/match/MatchQuestFeed.server.lua, embedded below; rebuild with the snippet in its header)
-- Idempotent; UNDO swaps back and removes the Script.
local UNDO = false --@UNDO
local SSS = game:GetService("ServerScriptService")
local MCo = SSS:FindFirstChild("MatchCore", true)
local RM = SSS:FindFirstChild("RoundManager", true)
local TP = SSS:FindFirstChild("Template", true)
assert(MCo and RM and TP, "a match script is missing")
local FEED = [=[-- ServerScriptService.MatchQuestFeed (Script, match places) [ECON2] 2026-10-22: the player's daily tasks inside a match, for the
-- UI session's in-match Daily Tasks panel (RIVALS keeps it on screen and the rows tick as you get kills).
--   Player attribute MatchQuests = JSON list of today's daily entries:
--     { Id, Text, Short, Stat, Goal, Reward, Tier, Base, Progress, Claimed }
--   Player attribute QuestTick = a counter bumped whenever MatchQuests changes.
-- Progress = what the shared profile already has (Stats[Stat] - Base) + this match's live count from the match attributes
-- (MatchKills / MatchHeadshots / MatchMeleeKills / GadgetThrows). RoundManager writes the match into Stats at the end, so the live
-- part is only what hasn't been written yet. MatchesPlayed / Wins move at the match end. Paying out stays in the lobby (autopay).
-- Installed by fix/economy_v2_match.lua.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

local LobbyConfig = require(ReplicatedStorage.Modules.Shared.Config.LobbyConfig)
local DataManager = require(ServerScriptService.Data.DataManager)

local LIVE = { Kills = "MatchKills", Headshots = "MatchHeadshots", MeleeKills = "MatchMeleeKills", GadgetsThrown = "GadgetThrows" }

local function questDef(id)
	for _, q in LobbyConfig.Quests.Daily.Pool do
		if q.Id == id then return q end
	end
	return nil
end

local state = {} -- [player] = { start = { [stat] = Stats value when this match's live count began }, prev = { [attr] = last value } }

local function build(p: Player)
	local data = DataManager:Get(p)
	if type(data) ~= "table" or type(data.Quests) ~= "table" or type(data.Stats) ~= "table" then return nil end
	local q = data.Quests.Daily
	if type(q) ~= "table" or q.Key ~= os.date("!%Y-%m-%d") or type(q.List) ~= "table" then
		-- Studio only: a fresh test profile has no tasks rolled (the lobby rolls them), so show one per Tier (Demo = true)
		if not RunService:IsStudio() then return nil end
		local demo, seen = {}, {}
		for _, d in LobbyConfig.Quests.Daily.Pool do
			if not seen[d.Tier or d.Id] then seen[d.Tier or d.Id] = true; table.insert(demo, { Id = d.Id, Base = data.Stats[d.Stat] or 0, Claimed = false }) end
		end
		q = { List = demo, Demo = true }
	end
	local st = state[p]
	if not st then
		st = { start = table.clone(data.Stats), prev = {} }
		state[p] = st
	end
	local list = {}
	for _, e in q.List do
		local d = questDef(e.Id)
		if d then
			local saved = (data.Stats[d.Stat] or 0) - (e.Base or 0)
			local live = 0
			local attr = LIVE[d.Stat]
			if attr then
				local now = tonumber(p:GetAttribute(attr)) or 0
				-- a new match reset the counter: count from what the profile holds now
				if now < (st.prev[attr] or 0) then st.start[d.Stat] = data.Stats[d.Stat] or 0 end
				st.prev[attr] = now
				local written = (data.Stats[d.Stat] or 0) - (st.start[d.Stat] or 0)
				live = math.max(0, now - written)
			end
			table.insert(list, {
				Id = d.Id, Text = d.Text, Short = d.Short or d.Text, Stat = d.Stat, Goal = d.Goal, Reward = d.Reward, Tier = d.Tier,
				Base = e.Base or 0, Progress = math.clamp(saved + live, 0, d.Goal), Claimed = e.Claimed == true, Demo = q.Demo,
			})
		end
	end
	return list
end

local last = {}
local function publish(p: Player)
	local ok, list = pcall(build, p)
	if not ok or not list then return end
	local json = HttpService:JSONEncode(list)
	if json ~= last[p] then
		last[p] = json
		p:SetAttribute("MatchQuests", json)
		p:SetAttribute("QuestTick", (tonumber(p:GetAttribute("QuestTick")) or 0) + 1)
	end
end

Players.PlayerRemoving:Connect(function(p) state[p] = nil; last[p] = nil end)
while true do
	task.wait(0.5)
	for _, p in Players:GetPlayers() do task.spawn(publish, p) end
end
]=]

local edits = {
	{ MCo, "\t\t\tMatchCore.setAttr(killer, \"MatchKills\", k.kills)\n",
	  "\t\t\tMatchCore.setAttr(killer, \"MatchKills\", k.kills)\n"
	  .. "\t\t\tMatchCore.setAttr(killer, \"MatchHeadshots\", k.headshots); MatchCore.setAttr(killer, \"MatchMeleeKills\", k.melee) -- [ECON2] live task counts\n" },
	{ MCo, "MatchCore.setAttr(m, \"MatchKills\", 0); MatchCore.setAttr(m, \"MatchDeaths\", 0); MatchCore.setAttr(m, \"GadgetThrows\", 0)",
	  "MatchCore.setAttr(m, \"MatchKills\", 0); MatchCore.setAttr(m, \"MatchDeaths\", 0); MatchCore.setAttr(m, \"GadgetThrows\", 0); MatchCore.setAttr(m, \"MatchHeadshots\", 0); MatchCore.setAttr(m, \"MatchMeleeKills\", 0)" },
	{ RM, "\t\tpcall(function() require(ServerScriptService.Shared.RichNotify).LevelUp(player, xp0, data.XP) end) -- [NOTIFY]\n\t\tdata.Credits = (tonumber(data.Credits) or 0) + summary.Scissors\n",
	  "\t\tpcall(function() require(ServerScriptService.Shared.RichNotify).LevelUp(player, xp0, data.XP) end) -- [NOTIFY]\n"
	  .. "\t\tif LobbyConfig.LevelUpReward and LobbyConfig.AccountLevel then -- [ECON2] scissors per account level gained\n"
	  .. "\t\t\tlocal gained = (LobbyConfig.AccountLevel(data.XP)) - (LobbyConfig.AccountLevel(xp0))\n"
	  .. "\t\t\tif gained > 0 then summary.Scissors += gained * LobbyConfig.LevelUpReward; summary.LevelUpScissors = gained * LobbyConfig.LevelUpReward end\n"
	  .. "\t\tend\n"
	  .. "\t\tdata.Credits = (tonumber(data.Credits) or 0) + summary.Scissors\n" },
	{ TP, "\t-- // Version tracking\n",
	  "\t-- [ECON2] scissors economy v2 (lobby LobbyManager)\n"
	  .. "\tLogin = { Day = 0, LastKey = \"\" }, -- 7-day login streak: today's Day (1-7) and the UTC day it was paid\n"
	  .. "\tDailyFreeKey = \"\",                 -- UTC day of the last free Shop claim\n"
	  .. "\tContracts = {},                    -- [itemId] = highest weapon-contract tier paid\n\n"
	  .. "\t-- // Version tracking\n" },
}
local sources, out = {}, {}
for i, e in edits do
	local inst, old, new = e[1], e[2], e[3]
	local s = sources[inst] or inst.Source:gsub("\r\n", "\n")
	if UNDO then old, new = new, old end
	local done
	if UNDO then done = not s:find(old, 1, true) else done = s:find(new, 1, true) ~= nil end
	if done then
		table.insert(out, i .. "=")
	else
		local a, b = s:find(old, 1, true)
		assert(a, inst.Name .. " edit " .. i .. " anchor not found")
		assert(not s:find(old, b + 1, true), inst.Name .. " edit " .. i .. " anchor not unique")
		s = s:sub(1, a - 1) .. new .. s:sub(b + 1)
		table.insert(out, i .. "+")
	end
	sources[inst] = s
end
for inst, s in sources do
	local f, err = loadstring(s)
	assert(f, inst.Name .. " would not parse: " .. tostring(err))
	if inst.Source ~= s then inst.Source = s end
end
-- the feed Script
local feed = SSS:FindFirstChild("MatchQuestFeed")
if UNDO then
	if feed then feed:Destroy() table.insert(out, "feed removed") end
else
	assert(loadstring(FEED), "MatchQuestFeed would not parse")
	if feed and not feed:IsA("Script") then feed:Destroy() feed = nil end
	if not feed then feed = Instance.new("Script"); feed.Name = "MatchQuestFeed"; feed.Parent = SSS end
	if feed.Source ~= FEED then feed.Source = FEED; table.insert(out, "feed+") else table.insert(out, "feed=") end
end
return "ECON2 match " .. table.concat(out, " ")
