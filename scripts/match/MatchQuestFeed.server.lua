-- ServerScriptService.MatchQuestFeed (Script, match places) [ECON2] 2026-10-22: the player's daily tasks inside a match, for the
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
