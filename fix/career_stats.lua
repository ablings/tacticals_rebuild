-- fix/career_stats.lua [CAREER] 2026-10-18 (UI session, for RIVALS' weapon Statistics + Career / Duel History): two profile
-- fields written by the match places' RoundManager, through the player's replica (PlayerStore) so the after-match lobby sees
-- them at once:
--   Data.WeaponStats[itemId] = { Kills, Headshots, Deaths, Matches, Wins }   (itemId = LobbyConfig.Items id)
--     Kills / Headshots: the item that landed the kill (Gun -> the Weapon slot, Melee -> the Melee slot, a gadget kind -> the
--     Gadget slot; map blasts credit nothing). Deaths / Matches / Wins: every item of that match's loadout.
--   Data.MatchHistory = newest first, max 20: { t, mode, ranked, map, won, draw?, forfeit?, score = {mine, theirs}, kills, deaths,
--     opponents = { {id, name} }, eloDelta?, loadout = {Weapon, Melee, Gadget} }
-- Counts: casual + ranked matches that pay (award's rules). Bot test / admin-ended matches don't; the tutorial never gets here.
-- The hub's pad duels (LobbyDuelManager) count too, every one (also inside the pair reward cooldown); ranked false, no eloDelta.
-- Studio check: ReplicatedStorage attribute StudioCareerTest = true also records bot matches (Studio only).
-- Template keys (WeaponStats = {}, MatchHistory = {}) are added to both places' DataManager.Template by this file too.
-- Idempotent; UNDO swaps back.
local UNDO = false --@UNDO
local SSS = game:GetService("ServerScriptService")
local TAG = "[CAREER]"
local log = {}

local HELPERS = [==[
-- [CAREER] weapon stats + match history (fix/career_stats.lua)
local CAREER_GADGET_KINDS = { Gadget = true, Grenade = true, Frag = true, Molotov = true, Flash = true, Smoke = true }
local function careerMember(match, uid)
	if match.byUser then return match.byUser[uid] end -- match place
	for _, list in match.teams do for _, m in list do if m.userId == uid then return m end end end -- hub duels
	return nil
end
local function careerKill(match, info)
	local killer = careerMember(match, info.killer)
	local victim = careerMember(match, info.victim)
	if not killer or killer.isBot or not victim or killer == victim or killer.team == victim.team then return end
	local slot = info.kind == "Gun" and "KitWeapon" or info.kind == "Melee" and "KitMelee"
		or (CAREER_GADGET_KINDS[info.kind] and "KitGadget") or nil
	local id = slot and MatchCore.getAttr(killer, slot)
	if type(id) ~= "string" then return end
	match.career = match.career or {}
	local mine = match.career[killer.userId] or {}
	match.career[killer.userId] = mine
	local c = mine[id] or { Kills = 0, Headshots = 0 }
	mine[id] = c
	c.Kills += 1
	if info.headshot then c.Headshots += 1 end
end
local function careerRecord(match, m, side: string, summary)
	local player = m.player
	local okPS, PS = pcall(function() return require(ServerScriptService.Data.PlayerStore) end)
	local data, replica = nil, nil
	if okPS and PS then data, replica = PS.Get(player) end
	if not data and profileData then data = profileData(player) end
	if type(data) ~= "table" then return end
	local function set(path, value)
		if replica then replica:SetValue(path, value) return end
		local t = data
		for i = 1, #path - 1 do t = t[path[i]] end
		t[path[#path]] = value
	end
	local kit = { Weapon = MatchCore.getAttr(m, "KitWeapon"), Melee = MatchCore.getAttr(m, "KitMelee"), Gadget = MatchCore.getAttr(m, "KitGadget") }
	if type(data.WeaponStats) ~= "table" then set({ "WeaponStats" }, {}) end
	local inKit, ids = {}, {}
	for _, id in kit do if type(id) == "string" then inKit[id] = true; ids[id] = true end end
	local mine = match.career and match.career[m.userId] or {}
	for id in mine do ids[id] = true end
	for id in ids do
		local old = type(data.WeaponStats[id]) == "table" and data.WeaponStats[id] or {}
		local r = {}
		for _, k in { "Kills", "Headshots", "Deaths", "Matches", "Wins" } do r[k] = tonumber(old[k]) or 0 end
		local c = mine[id]
		if c then r.Kills += c.Kills; r.Headshots += c.Headshots end
		if inKit[id] then
			r.Deaths += tonumber(summary.Deaths) or 0
			r.Matches += 1
			if summary.Won then r.Wins += 1 end
		end
		set({ "WeaponStats", id }, r)
	end
	local other = side == "A" and "B" or "A"
	local opponents = {}
	for _, o in match.teams[other] or {} do
		local name = o.player and o.player.DisplayName or o.name or "Bot"
		table.insert(opponents, { id = (o.isBot or not o.userId or o.userId < 0) and 0 or o.userId, name = name })
	end
	local score = summary.Score or {}
	local entry = {
		t = os.time(), mode = tostring(match.mode), ranked = match.ranked == true,
		map = (match.map and (match.map.DisplayName or match.map.Id)) or ReplicatedStorage:GetAttribute("ArenaMap") or "Warehouse",
		won = summary.Won == true, draw = summary.Draw == true or nil, forfeit = summary.Forfeit == true or nil,
		score = { tonumber(score[side]) or 0, tonumber(score[other]) or 0 },
		kills = tonumber(summary.Kills) or 0, deaths = tonumber(summary.Deaths) or 0,
		opponents = opponents, eloDelta = tonumber(summary.delta), loadout = kit,
	}
	local history = { entry }
	for _, e in (type(data.MatchHistory) == "table" and data.MatchHistory or {}) do
		if #history >= 20 then break end
		table.insert(history, e)
	end
	set({ "MatchHistory" }, history)
	if IS_STUDIO then -- Studio check: what was written (the command bar can't see this server's profiles)
		player:SetAttribute("CareerDebug", HttpService:JSONEncode({ ws = data.WeaponStats, n = #data.MatchHistory, last = data.MatchHistory[1], replica = replica ~= nil }))
	end
end

]==]

local RM_EDITS = {
	-- before award (it calls careerRecord) and newMatch (careerKill); profileData is defined above both
	{ "local function award(match, m, side: string, winner: string?, forfeit: boolean, ratings)\n",
		HELPERS .. "local function award(match, m, side: string, winner: string?, forfeit: boolean, ratings)\n" },
	{ "\t\tonKill = function(info)\n\t\t\tfor _, p in Players:GetPlayers() do Flow:FireClient(p, nil, \"Kill\", info) end\n",
		"\t\tonKill = function(info)\n\t\t\tfor _, p in Players:GetPlayers() do Flow:FireClient(p, nil, \"Kill\", info) end\n"
			.. "\t\t\tpcall(careerKill, match, info) -- " .. TAG .. "\n" },
	{ "\t\tsummary.Saved = false\n\t\tResults:FireClient(player, summary)\n\t\treturn\n",
		"\t\tsummary.Saved = false\n"
			.. "\t\tif IS_STUDIO and ReplicatedStorage:GetAttribute(\"StudioCareerTest\") then local okS, errS = xpcall(careerRecord, debug.traceback, match, m, side, summary) if not okS then warn(\"[CAREER] \" .. tostring(errS)) end end -- " .. TAG .. " Studio check\n"
			.. "\t\tResults:FireClient(player, summary)\n\t\treturn\n" },
	{ "\t\t-- [RANKED] the ranked record was written by RankedServer.ApplyResult above (unified record, leaderboard, attributes)\n\tend\n",
		"\t\t-- [RANKED] the ranked record was written by RankedServer.ApplyResult above (unified record, leaderboard, attributes)\n"
			.. "\t\tlocal okC, errC = pcall(careerRecord, match, m, side, summary) -- " .. TAG .. " WeaponStats + MatchHistory\n"
			.. "\t\tif not okC then warn(\"[RoundManager] [CAREER] \" .. tostring(errC)) end\n\tend\n" },
}

-- the hub's pad duels (LobbyDuelManager; UI session: "a hub pad duel is the most common one"): every duel counts, also one
-- inside the pair reward cooldown (that only stops XP / scissors farming); ranked false, no eloDelta; test-bot duels don't
local LDM_EDITS = {
	{ "local function award(match, m, side: string, winner: string?, forfeit: boolean)\n",
		HELPERS .. "local function award(match, m, side: string, winner: string?, forfeit: boolean)\n" },
	{ "\t\tonKill = function(info) fireFlow(match, \"Kill\", info) end,\n",
		"\t\tonKill = function(info) fireFlow(match, \"Kill\", info); pcall(careerKill, match, info) end, -- " .. TAG .. "\n" },
	{ "\t\tsummary.Saved = true\n\tend\n\tresultsEv:FireClient(p, summary)\nend\n",
		"\t\tsummary.Saved = true\n\tend\n"
			.. "\tif not match.hasBot or (IS_STUDIO and ReplicatedStorage:GetAttribute(\"StudioCareerTest\")) then -- " .. TAG .. "\n"
			.. "\t\tlocal okC, errC = pcall(careerRecord, match, m, side, summary)\n"
			.. "\t\tif not okC then warn(\"[LobbyDuelManager] [CAREER] \" .. tostring(errC)) end\n"
			.. "\tend\n"
			.. "\tresultsEv:FireClient(p, summary)\nend\n" },
}

local TPL_OLD ="\tRedeemedCodes = {},         -- [CODE] = os.time()\n"
local TPL_NEW = TPL_OLD
	.. "\t-- " .. TAG .. " RIVALS weapon Statistics + Career (written by the match places' RoundManager, fix/career_stats.lua)\n"
	.. "\tWeaponStats = {},           -- [itemId] = { Kills, Headshots, Deaths, Matches, Wins }\n"
	.. "\tMatchHistory = {},          -- newest first, max 20: { t, mode, ranked, map, won, score = {mine, theirs}, kills, deaths, opponents, eloDelta, loadout }\n"

local function swap(target, edits, label)
	local s = target.Source
	if UNDO then
		for i = #edits, 1, -1 do
			local a, b = s:find(edits[i][2], 1, true)
			if a then s = s:sub(1, a - 1) .. edits[i][1] .. s:sub(b + 1); table.insert(log, label .. " undo " .. i) end
		end
		target.Source = s
		return
	end
	for i, e in ipairs(edits) do
		assert(s:find(e[2], 1, true) or s:find(e[1], 1, true), label .. " edit " .. i .. ": original text not found (nothing changed)")
	end
	for i, e in ipairs(edits) do
		if s:find(e[2], 1, true) then table.insert(log, label .. " " .. i .. " already in")
		else
			local a, b = s:find(e[1], 1, true)
			s = s:sub(1, a - 1) .. e[2] .. s:sub(b + 1)
			table.insert(log, label .. " " .. i .. " applied")
		end
	end
	assert(loadstring(s), label .. " would not parse")
	target.Source = s
end

local tpl = SSS.Data.DataManager.Template
local isLobby = workspace:FindFirstChild("LobbyMap") ~= nil and not game.ServerStorage:FindFirstChild("PseudoLobby")
if not isLobby then
	local RM = SSS.ServerScripts["[Server] Init"].GameManager.Managers.RoundManager
	if not UNDO then
		for i, e in ipairs(RM_EDITS) do assert(RM.Source:find(e[2], 1, true) or RM.Source:find(e[1], 1, true), "RoundManager edit " .. i .. " not found") end
	end
	swap(RM, RM_EDITS, "RoundManager")
else
	local LDM = SSS.ServerScripts["[Server] Init"].GameManager.Managers.LobbyDuelManager
	if not UNDO then
		for i, e in ipairs(LDM_EDITS) do assert(LDM.Source:find(e[2], 1, true) or LDM.Source:find(e[1], 1, true), "LobbyDuelManager edit " .. i .. " not found") end
	end
	swap(LDM, LDM_EDITS, "LobbyDuelManager")
end
swap(tpl, { { TPL_OLD, TPL_NEW } }, "Template")
return (isLobby and "lobby: " or "match: ") .. table.concat(log, ", ")
