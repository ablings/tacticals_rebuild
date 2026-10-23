-- fix/economy_v2_lobby.lua [ECON2] 2026-10-22 (lobby only; run fix/economy_v2_config.lua first). Edward approved the economy
-- (notes/economy/scissors_economy.md section 4) and the server pieces the UI waits on:
--   LobbyManager  daily tasks one per Tier (Easy / Medium / Hard); lists holding a removed task re-roll;
--                 Request "RerollQuest" (scope "Daily", index) -> 250 scissors, a new unfinished task of the same Tier;
--                 Request "LevelUpItem" (itemId) -> 1,000 scissors, one weapon level (the Kit's "Level up now!");
--                 per-weapon contracts (WeaponStats[item].Kills 10 / 50 / 150 -> 100 / 200 / 400, paid by themselves);
--                 7-day login streak paid on the day's first join (player attributes LoginDay 1-7, LoginClaimed;
--                 ReplicatedStorage attribute LoginRewards = JSON of the 7 amounts);
--                 free daily Shop claim: RemoteFunction ReplicatedStorage.ClaimDailyFree -> { ok, reward = n, kind = "Scissors" },
--                 player attribute DailyFreeAt = unix time of the next free claim (<= now: claimable)
--   Template      Login, DailyFreeKey, Contracts (profile:Reconcile fills them for existing players)
--   LobbyDuelManager  +LevelUpReward scissors per account level gained in a pad duel; gadget throws count for tasks
--   LobbyLeaderboard  players in this server show their live value (the OrderedDataStore lags a level-up)
-- Idempotent; UNDO swaps back (the RemoteFunction stays, harmless).
local UNDO = false --@UNDO
local SSS = game:GetService("ServerScriptService")
local LM = SSS:FindFirstChild("LobbyManager", true)
local TP = SSS:FindFirstChild("Template", true)
local LDM = SSS:FindFirstChild("LobbyDuelManager", true)
local LB = SSS:FindFirstChild("LobbyLeaderboard", true)
-- (2026-10-23) also run in the MATCH places: their after-match lobby runs the hub's LobbyManager copy and the same Missions /
-- Kit / Shop UI. Pad duels (LobbyDuelManager) and the hub leaderboard (LobbyLeaderboard) only exist in the hub: skipped there.
assert(LM and TP, "LobbyManager / Template missing")

local ROLL_OLD = [==[	local pool = table.clone(Config.Quests[scope].Pool)
	local rng = Random.new()
	local list = {}
	for _ = 1, math.min(Config.Quests[scope].Count, #pool) do
		local q = table.remove(pool, rng:NextInteger(1, #pool))
		table.insert(list, { Id = q.Id, Base = data.Stats[q.Stat] or 0, Claimed = false })
	end
]==]
local ROLL_NEW = [==[	local pool = table.clone(Config.Quests[scope].Pool)
	local rng = Random.new()
	local list = {}
	-- [ECON2] one task per Tier (Easy, Medium, Hard) when the pool has tiers; random as before otherwise
	local tiers = (pool[1] and pool[1].Tier) and { "Easy", "Medium", "Hard" } or nil
	for n = 1, math.min(Config.Quests[scope].Count, #pool) do
		local pick = {}
		for i, q in pool do if not tiers or q.Tier == tiers[n] then table.insert(pick, i) end end
		if #pick == 0 then for i in pool do table.insert(pick, i) end end
		local q = table.remove(pool, pick[rng:NextInteger(1, #pick)])
		table.insert(list, { Id = q.Id, Base = data.Stats[q.Stat] or 0, Claimed = false })
	end
]==]

local ENSURE_OLD = [==[local function ensureQuests(player: Player)
	local data = PlayerStore.Get(player)
	if not data then return end
	for _, scope in { "Daily", "Weekly" } do
		local q = data.Quests[scope]
		if not q or q.Key ~= periodKey(scope) then
]==]
local ENSURE_NEW = [==[-- [ECON2] a list holding a task that's no longer in the pool (the cover-kill tasks) is handed out again
local function staleList(scope: string, q): boolean
	for _, e in (type(q.List) == "table" and q.List or {}) do
		if not questDef(scope, e.Id) then return true end
	end
	return false
end

local function ensureQuests(player: Player)
	local data = PlayerStore.Get(player)
	if not data then return end
	for _, scope in { "Daily", "Weekly" } do
		local q = data.Quests[scope]
		if not q or q.Key ~= periodKey(scope) or staleList(scope, q) then
]==]

local BLOCK_ANCHOR = [==[LobbyManager.AutoPayQuests = autoPay
]==]
local BLOCK = [==[LobbyManager.AutoPayQuests = autoPay

-------------------------------------------------------------------------------
-- [ECON2] scissors economy v2: reroll, weapon level-up skip, weapon contracts, login streak, free daily claim
-------------------------------------------------------------------------------
local HttpService = game:GetService("HttpService")
local function dayKey(offsetDays: number?): string
	return os.date("!%Y-%m-%d", os.time() + (offsetDays or 0) * 86400)
end
local function nextDay(): number
	return (math.floor(os.time() / 86400) + 1) * 86400
end
if Config.LoginRewards then ReplicatedStorage:SetAttribute("LoginRewards", HttpService:JSONEncode(Config.LoginRewards)) end

-- swap one unfinished daily task for another of the same Tier
Remotes.Handlers.RerollQuest = function(player, scope, index)
	if scope ~= "Daily" or type(index) ~= "number" then return result(false, "Bad task") end
	ensureQuests(player)
	local data = PlayerStore.Get(player)
	local q = data and data.Quests and data.Quests.Daily
	local entry = q and q.List[index]
	local def = entry and questDef("Daily", entry.Id)
	if not def then return result(false, "That task has expired") end
	if entry.Claimed or (data.Stats[def.Stat] or 0) - (entry.Base or 0) >= def.Goal then
		return result(false, "That task is already done")
	end
	local taken, same, any = {}, {}, {}
	for _, e in q.List do taken[e.Id] = true end
	for _, d in Config.Quests.Daily.Pool do
		if not taken[d.Id] then
			table.insert(any, d)
			if d.Tier == def.Tier then table.insert(same, d) end
		end
	end
	local options = #same > 0 and same or any
	if #options == 0 then return result(false, "No other task to swap to") end
	if not PlayerStore.Spend(player, Config.RerollCost or 250) then return result(false, "Not enough scissors") end
	local pick = options[Random.new():NextInteger(1, #options)]
	PlayerStore.Set(player, { "Quests", "Daily", "List", index }, { Id = pick.Id, Base = data.Stats[pick.Stat] or 0, Claimed = false })
	return result(true, `New task: {pick.Text}`)
end

-- the Kit's "Level up now!": one weapon level for LevelUpSkipCost
Remotes.Handlers.LevelUpItem = function(player, itemId)
	local item = type(itemId) == "string" and Config.Items[itemId]
	if not item then return result(false, "Unknown item") end
	if not PlayerStore.Owns(player, itemId) then return result(false, `You don't own {item.Name} yet`) end
	local data = PlayerStore.Get(player)
	if not data then return result(false, "Still loading, try again") end
	local xp = type(data.ItemXP) == "table" and tonumber(data.ItemXP[itemId]) or 0
	local level, into, need = Config.ItemLevel(xp)
	if level >= Config.ItemLevels.Max then return result(false, `{item.Name} is already max level`) end
	if not PlayerStore.Spend(player, Config.LevelUpSkipCost or 1000) then return result(false, "Not enough scissors") end
	if type(data.ItemXP) ~= "table" then PlayerStore.Set(player, { "ItemXP" }, {}) end
	PlayerStore.Set(player, { "ItemXP", itemId }, xp + (need - into))
	return result(true, `{item.Name} is now level {level + 1}`)
end

-- per-weapon contracts: eliminations with a weapon (WeaponStats, written by the match places) pay each tier once
local function payContracts(player: Player)
	local data = PlayerStore.Get(player)
	local tiers = Config.WeaponContracts
	if not data or not tiers or type(data.WeaponStats) ~= "table" then return end
	for itemId, ws in data.WeaponStats do
		local kills = type(ws) == "table" and tonumber(ws.Kills) or 0
		local done = type(data.Contracts) == "table" and tonumber(data.Contracts[itemId]) or 0
		local tier, pay = done, 0
		for i = done + 1, #tiers do
			if kills < tiers[i].Kills then break end
			tier, pay = i, pay + tiers[i].Reward
		end
		if tier > done then
			if type(data.Contracts) ~= "table" then PlayerStore.Set(player, { "Contracts" }, {}) end
			PlayerStore.Set(player, { "Contracts", itemId }, tier)
			pay = math.floor(pay * creditMultiplier(player) + 0.5)
			PlayerStore.Increment(player, { "Credits" }, pay)
			local name = Config.Items[itemId] and Config.Items[itemId].Name or itemId
			RN.Send(player, "Contract Complete", ("%s: you've earned x%d Scissors!"):format(name, pay), { kind = "Scissors", count = pay }) -- [NOTIFY]
		end
	end
end
LobbyManager.PayContracts = payContracts

-- 7-day login streak: paid on the day's first join (or at the UTC rollover while online); a missed day starts at Day 1
local function loginStreak(player: Player)
	local data = PlayerStore.Get(player)
	local rewards = Config.LoginRewards
	if not data or not rewards then return end
	local today = dayKey(0)
	local login = type(data.Login) == "table" and data.Login or { Day = 0, LastKey = "" }
	if login.LastKey ~= today then
		local day = (login.LastKey == dayKey(-1)) and ((tonumber(login.Day) or 0) % #rewards) + 1 or 1
		login = { Day = day, LastKey = today }
		PlayerStore.Set(player, { "Login" }, login)
		local amount = rewards[day] or 0
		if amount > 0 then
			PlayerStore.Increment(player, { "Credits" }, amount)
			RN.Send(player, "Daily Login", ("Day %d: you've earned x%d Scissors!"):format(day, amount), { kind = "Scissors", count = amount }) -- [NOTIFY]
		end
	end
	player:SetAttribute("LoginDay", login.Day)
	player:SetAttribute("LoginClaimed", true)
end

-- free daily Shop claim
local function dailyFreeAt(player: Player)
	local data = PlayerStore.Get(player)
	if not data then return end
	player:SetAttribute("DailyFreeAt", data.DailyFreeKey == dayKey(0) and nextDay() or os.time())
end
local claimFree = ReplicatedStorage:FindFirstChild("ClaimDailyFree") or Instance.new("RemoteFunction")
claimFree.Name = "ClaimDailyFree"
claimFree.Parent = ReplicatedStorage
local claimBusy = {}
claimFree.OnServerInvoke = function(player)
	if claimBusy[player] then return { ok = false, msg = "Hold on" } end
	claimBusy[player] = true
	local ok, res = pcall(function()
		local data = PlayerStore.Get(player)
		if not data then return { ok = false, msg = "Still loading, try again" } end
		if data.DailyFreeKey == dayKey(0) then dailyFreeAt(player) return { ok = false, msg = "Come back tomorrow" } end
		local amount = (Config.DailyFree and Config.DailyFree.Scissors) or 100
		PlayerStore.Set(player, { "DailyFreeKey" }, dayKey(0))
		PlayerStore.Increment(player, { "Credits" }, amount)
		dailyFreeAt(player)
		RN.Send(player, "Free Reward", ("You've earned x%d Scissors!"):format(amount), { kind = "Scissors", count = amount }) -- [NOTIFY]
		return { ok = true, reward = amount, kind = "Scissors" }
	end)
	claimBusy[player] = nil
	return ok and res or { ok = false, msg = "Try again" }
end
Players.PlayerRemoving:Connect(function(p) claimBusy[p] = nil end)

local function econDaily(player: Player)
	pcall(loginStreak, player)
	pcall(dailyFreeAt, player)
end
LobbyManager.EconDaily = econDaily
]==]

local JOIN_OLD = [==[	ensureQuests(player)
	autoPay(player) -- [AUTOPAY]
	checkPasses(player)
]==]
local JOIN_NEW = [==[	ensureQuests(player)
	autoPay(player) -- [AUTOPAY]
	econDaily(player) -- [ECON2] login streak + free daily claim
	pcall(payContracts, player) -- [ECON2]
	checkPasses(player)
]==]
local LOOP_OLD = [==[				for _, p in Players:GetPlayers() do task.spawn(autoPay, p) end
			end
			for _, p in Players:GetPlayers() do
				task.spawn(ensureQuests, p)
			end
]==]
local LOOP_NEW = [==[				for _, p in Players:GetPlayers() do task.spawn(autoPay, p); task.spawn(payContracts, p) end -- [ECON2] contracts
			end
			for _, p in Players:GetPlayers() do
				task.spawn(ensureQuests, p)
				task.spawn(econDaily, p) -- [ECON2] the UTC rollover while online
			end
]==]

local TP_OLD = [==[	-- // Version tracking
]==]
local TP_NEW = [==[	-- [ECON2] scissors economy v2 (LobbyManager)
	Login = { Day = 0, LastKey = "" }, -- 7-day login streak: today's Day (1-7) and the UTC day it was paid
	DailyFreeKey = "",                 -- UTC day of the last free Shop claim
	Contracts = {},                    -- [itemId] = highest weapon-contract tier paid

	-- // Version tracking
]==]

local DUEL_OLD = [==[		local xpNew = PlayerStore.Increment(p, { "XP" }, summary.XP)
		if xpNew then pcall(function() require(ServerScriptService.Shared.RichNotify).LevelUp(p, xpNew - summary.XP, xpNew) end) end -- [NOTIFY]
		PlayerStore.Increment(p, { "Credits" }, summary.Scissors)
]==]
local DUEL_NEW = [==[		local xpNew = PlayerStore.Increment(p, { "XP" }, summary.XP)
		if xpNew then pcall(function() require(ServerScriptService.Shared.RichNotify).LevelUp(p, xpNew - summary.XP, xpNew) end) end -- [NOTIFY]
		do -- [ECON2] LevelUpReward scissors per account level gained
			local LC = require(ReplicatedStorage.Modules.Shared.Config.LobbyConfig)
			if xpNew and LC.LevelUpReward and LC.AccountLevel then
				local gained = (LC.AccountLevel(xpNew)) - (LC.AccountLevel(xpNew - summary.XP))
				if gained > 0 then summary.Scissors += gained * LC.LevelUpReward; summary.LevelUpScissors = gained * LC.LevelUpReward end
			end
		end
		PlayerStore.Increment(p, { "Credits" }, summary.Scissors)
]==]
local DUEL2_OLD = [==[			if summary.Won then PlayerStore.AddStat(p, "Wins", 1) end
		end
		summary.Saved = true
]==]
local DUEL2_NEW = [==[			if summary.Won then PlayerStore.AddStat(p, "Wins", 1) end
			local thrown = tonumber(p:GetAttribute("GadgetThrows")) or 0 -- [ECON2] gadget tasks count pad duels too
			if thrown > 0 then PlayerStore.AddStat(p, "GadgetsThrown", thrown) end
		end
		summary.Saved = true
]==]

local LB_OLD = [==[	if not list or #list == 0 then list = localList(b) end
]==]
local LB_NEW = [==[	if not list or #list == 0 then
		list = localList(b)
	else
		-- [ECON2] players in this server show their live value (the OrderedDataStore lags a level-up by a minute or more)
		for _, e in localList(b) do
			local found = false
			for i, x in list do if x.u == e.u then list[i] = e; found = true end end
			if not found then table.insert(list, e) end
		end
		table.sort(list, function(a, c) return (a.x or a.w) > (c.x or c.w) end)
		while #list > 10 do table.remove(list) end
	end
]==]

local edits = {
	{ LM, ROLL_OLD, ROLL_NEW }, { LM, ENSURE_OLD, ENSURE_NEW }, { LM, BLOCK_ANCHOR, BLOCK },
	{ LM, JOIN_OLD, JOIN_NEW }, { LM, LOOP_OLD, LOOP_NEW },
	{ TP, TP_OLD, TP_NEW, "DailyFreeKey" }, -- skip if fix/economy_v2_match.lua already added the keys (match places)
	{ LDM, DUEL_OLD, DUEL_NEW }, { LDM, DUEL2_OLD, DUEL2_NEW },
	{ LB, LB_OLD, LB_NEW },
}
local sources, out = {}, {}
for i, e in edits do
	local inst, old, new = e[1], e[2], e[3]
	if not inst then table.insert(out, i .. "-") continue end -- a hub-only script (match places)
	local s = sources[inst] or inst.Source:gsub("\r\n", "\n")
	if UNDO then old, new = new, old end
	local done
	if UNDO then done = not s:find(old, 1, true) else done = s:find(new, 1, true) ~= nil or (e[4] ~= nil and s:find(e[4], 1, true) ~= nil) end
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
return "ECON2 lobby " .. table.concat(out, " ")
