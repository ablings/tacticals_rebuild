-- fix/economy_v2_config.lua [ECON2] 2026-10-22, Edward approved notes/economy/scissors_economy.md section 4 ("go on the economy
-- proposal") and the server pieces in the lead's chat ("yes"). Shared config, BOTH places (each has its own LobbyConfig copy; the
-- match places' MatchConfig + the lobby's MatchConfig copy for pad duels):
--   prices      Legendary 7,500 (Sniper, Riot Shield)
--   Robux packs 1,000 / 49, 2,200 / 99, 5,500 / 229, 12,500 / 499 R$ (keys unchanged)
--   daily tasks one Easy / Medium / Hard a day paying 100 / 200 / 300; every task has a Short label for the in-match panel.
--               The cover-kill tasks are gone: nothing counts CoverKills (cover state is client-only), so they could never finish.
--   weekly      Count 0: weekly tasks are replaced by per-weapon contracts (WeaponContracts)
--   new         QuestTierRewards, LoginRewards (7-day streak), DailyFree, RerollCost, LevelUpSkipCost, LevelUpReward
--   per match   10 + 5 / elimination + 15 for a win (MatchConfig.Rewards)
-- No balance migration. Idempotent; UNDO swaps back.
local UNDO = false --@UNDO
local RS = game:GetService("ReplicatedStorage")
local Cfg = RS.Modules.Shared.Config
local LC, MC = Cfg:FindFirstChild("LobbyConfig"), Cfg:FindFirstChild("MatchConfig")
assert(LC and MC, "LobbyConfig / MatchConfig missing")

local DAILY_OLD = [==[	Daily = {
		Count = 3,
		Pool = {
			{ Id = "D_Play", Text = "Play 3 matches", Stat = "MatchesPlayed", Goal = 3, Reward = 150 },
			{ Id = "D_Win", Text = "Win 2 matches", Stat = "Wins", Goal = 2, Reward = 200 },
			{ Id = "D_Kills", Text = "Get 8 eliminations", Stat = "Kills", Goal = 8, Reward = 175 },
			{ Id = "D_Heads", Text = "Land 5 headshot kills", Stat = "Headshots", Goal = 5, Reward = 175 },
			{ Id = "D_Cover", Text = "Get 3 eliminations from cover", Stat = "CoverKills", Goal = 3, Reward = 200 },
			{ Id = "D_Melee", Text = "Get a melee elimination", Stat = "MeleeKills", Goal = 1, Reward = 175 },
			{ Id = "D_Gadget", Text = "Throw 6 gadgets", Stat = "GadgetsThrown", Goal = 6, Reward = 125 },
		},
	},
	Weekly = {
		Count = 3,
]==]
local DAILY_NEW = [==[	-- [ECON2] one task per Tier a day (Easy / Medium / Hard -> LobbyConfig.QuestTierRewards). Short = the in-match panel label.
	Daily = {
		Count = 3,
		Pool = {
			{ Id = "D_Play", Text = "Play 3 matches", Short = "Play matches", Stat = "MatchesPlayed", Goal = 3, Tier = "Easy", Reward = 100 },
			{ Id = "D_Gadget", Text = "Throw 6 gadgets", Short = "Throw gadgets", Stat = "GadgetsThrown", Goal = 6, Tier = "Easy", Reward = 100 },
			{ Id = "D_Kills", Text = "Get 8 eliminations", Short = "Eliminations", Stat = "Kills", Goal = 8, Tier = "Medium", Reward = 200 },
			{ Id = "D_Melee", Text = "Get a melee elimination", Short = "Melee eliminations", Stat = "MeleeKills", Goal = 1, Tier = "Medium", Reward = 200 },
			{ Id = "D_Win", Text = "Win 2 matches", Short = "Win matches", Stat = "Wins", Goal = 2, Tier = "Hard", Reward = 300 },
			{ Id = "D_Heads", Text = "Land 5 headshot kills", Short = "Headshot kills", Stat = "Headshots", Goal = 5, Tier = "Hard", Reward = 300 },
		},
	},
	-- [ECON2] weekly tasks are replaced by per-weapon contracts (LobbyConfig.WeaponContracts); Count 0 hands out none
	Weekly = {
		Count = 0,
]==]
local W_COVER = [==[		{ Id = "W_Cover", Text = "Get 15 eliminations from cover", Stat = "CoverKills", Goal = 15, Reward = 1000 },
]==]

local TAIL_OLD = "\nreturn LobbyConfig\n"
local TAIL_NEW = [==[

-------------------------------------------------------------------------------
-- [ECON2] scissors economy v2 (notes/economy/scissors_economy.md section 4, Edward 2026-10-22)
-------------------------------------------------------------------------------
LobbyConfig.QuestTierRewards = { Easy = 100, Medium = 200, Hard = 300 }
-- 7-day login streak: paid automatically on the day's first join; missing a day starts again at Day 1
LobbyConfig.LoginRewards = { 50, 50, 100, 100, 150, 150, 400 }
-- one free Shop claim per UTC day (ReplicatedStorage.ClaimDailyFree)
LobbyConfig.DailyFree = { Scissors = 100 }
LobbyConfig.RerollCost = 250        -- swap one unfinished daily task for another of the same Tier
LobbyConfig.LevelUpSkipCost = 1000  -- the Kit's "Level up now!": one weapon level
LobbyConfig.LevelUpReward = 100     -- scissors per account level gained
-- per-weapon contracts (replace the weekly tasks): eliminations with that weapon -> scissors, paid automatically
LobbyConfig.WeaponContracts = {
	{ Kills = 10, Reward = 100 },
	{ Kills = 50, Reward = 200 },
	{ Kills = 150, Reward = 400 },
	-- 500 eliminations: a cosmetic, once cosmetics exist
}

return LobbyConfig
]==]

local edits = {
	{ LC, "Sniper = { Name = \"Sniper\", Slot = \"Weapon\", Price = 4000,", "Sniper = { Name = \"Sniper\", Slot = \"Weapon\", Price = 7500," },
	{ LC, "RiotShield = { Name = \"Riot Shield\", Slot = \"Melee\", Price = 3000,", "RiotShield = { Name = \"Riot Shield\", Slot = \"Melee\", Price = 7500," },
	{ LC, "Name = \"Pocket\", Credits = 500, Robux = 49 }", "Name = \"Pocket\", Credits = 1000, Robux = 49 }" },
	{ LC, "Name = \"Pouch\", Credits = 1200, Robux = 99,", "Name = \"Pouch\", Credits = 2200, Robux = 99," },
	{ LC, "Name = \"Toolkit\", Credits = 3000, Robux = 229,", "Name = \"Toolkit\", Credits = 5500, Robux = 229," },
	{ LC, "Name = \"Vault\", Credits = 7500, Robux = 499,", "Name = \"Vault\", Credits = 12500, Robux = 499," },
	{ LC, DAILY_OLD, DAILY_NEW },
	{ LC, W_COVER, "" },
	{ LC, TAIL_OLD, TAIL_NEW },
	{ MC, "ScissorsMatch = 25, ScissorsKill = 10, ScissorsWin = 50,", "ScissorsMatch = 10, ScissorsKill = 5, ScissorsWin = 15, -- [ECON2] was 25 / 10 / 50" },
}

local sources, out = {}, {}
for i, e in edits do
	local inst, old, new = e[1], e[2], e[3]
	local s = sources[inst] or inst.Source:gsub("\r\n", "\n")
	if new == "" then
		-- a deletion (W_Cover): forward removes the line; UNDO puts it back after W_Heads
		local has = s:find(old, 1, true) ~= nil
		if not UNDO and has then
			local a, b = s:find(old, 1, true)
			s = s:sub(1, a - 1) .. s:sub(b + 1)
			table.insert(out, i .. "+")
		elseif UNDO and not has then
			local anchor = "Stat = \"Headshots\", Goal = 25, Reward = 900 },\n"
			local a, b = s:find(anchor, 1, true)
			assert(a, "edit " .. i .. ": W_Heads anchor not found")
			s = s:sub(1, b) .. old .. s:sub(b + 1)
			table.insert(out, i .. "+")
		else
			table.insert(out, i .. "=")
		end
		sources[inst] = s
		continue
	end
	if UNDO then old, new = new, old end
	-- forward: done once the new text is there; UNDO: done once the edited text is gone (the old tail is inside the new one)
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
return "ECON2 config " .. table.concat(out, " ")
