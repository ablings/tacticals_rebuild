-- fix/rich_notify.lua [NOTIFY] 2026-10-18 (UI session: RIVALS banner + Inbox). Hub + match places. Needs
-- ServerScriptService.Shared.RichNotify (scripts/notify/RichNotify.lua). Table notifications for:
--   Task Completed (ClaimQuest), Item Unlocked (BuyItem / BuyBundle / codes / Robux products), Code Redeemed (RedeemCode)
--   in LobbyManager (hub + the match places' copy); Level Up from match XP (match RoundManager award, hub LobbyDuelManager
--   award); Rank Up on a ranked promotion (match RoundManager, RankedServer.ApplyResult's promoted / rankAfter).
-- The handlers keep returning their { ok, msg } (the client decides whether to toast that too). Idempotent; UNDO swaps back.
local UNDO = false --@UNDO
local SSS = game:GetService("ServerScriptService")
local M = SSS.ServerScripts["[Server] Init"].GameManager.Managers
local isLobby = workspace:FindFirstChild("LobbyMap") ~= nil and not game.ServerStorage:FindFirstChild("PseudoLobby")
local T = " -- [NOTIFY]\n"
local log = {}

local LM = {
	{ "local Remotes = require(ServerScriptService.Lobby.LobbyRemotes)\n",
		"local Remotes = require(ServerScriptService.Lobby.LobbyRemotes)\nlocal RN = require(ServerScriptService.Shared.RichNotify)" .. T },
	{ "\tPlayerStore.Grant(player, itemId)\n\treturn result(true, `{item.Name} unlocked`)\n",
		"\tPlayerStore.Grant(player, itemId)\n\tRN.Item(player, itemId)" .. T .. "\treturn result(true, `{item.Name} unlocked`)\n" },
	{ "\tfor _, id in bundle.Items do\n\t\tPlayerStore.Grant(player, id)\n\tend\n",
		"\tfor _, id in bundle.Items do\n\t\tlocal had = PlayerStore.Owns(player, id)\n\t\tPlayerStore.Grant(player, id)\n\t\tif not had then RN.Item(player, id) end" .. T .. "\tend\n" },
	{ "\tPlayerStore.Increment(player, { \"Credits\" }, reward)\n\treturn result(true, `+{reward} scissors`)\n",
		"\tPlayerStore.Increment(player, { \"Credits\" }, reward)\n"
			.. "\tRN.Send(player, \"Task Completed\", (\"You've earned x%d Scissors!\"):format(reward), { kind = \"Scissors\", count = reward })" .. T
			.. "\treturn result(true, `+{reward} scissors`)\n" },
	{ "\tfor _, id in product.Items or {} do\n\t\tPlayerStore.Grant(player, id)\n\tend\n",
		"\tfor _, id in product.Items or {} do\n\t\tlocal had = PlayerStore.Owns(player, id)\n\t\tPlayerStore.Grant(player, id)\n\t\tif not had then RN.Item(player, id) end" .. T .. "\tend\n" },
	{ "\treturn result(true, `Code redeemed! {table.concat(parts, \" + \")}`)\n",
		"\tRN.Send(player, \"Code Redeemed\", table.concat(parts, \" + \"), (def.Credits and def.Credits > 0) and { kind = \"Scissors\", count = def.Credits } or nil)" .. T
			.. "\tfor _, id in def.Items or {} do if Config.Items[id] then RN.Item(player, id) end end" .. T
			.. "\treturn result(true, `Code redeemed! {table.concat(parts, \" + \")}`)\n" },
}
local RM = {
	{ "\t\t\tfor k, v in res do summary[k] = v end\n\t\t\tsummary.RatingChange = res.delta\n",
		"\t\t\tfor k, v in res do summary[k] = v end\n\t\t\tsummary.RatingChange = res.delta\n"
			.. "\t\t\tif res.promoted then pcall(function() require(ServerScriptService.Shared.RichNotify).RankUp(player, res.rankAfter) end) end" .. T },
	{ "\t\tdata.XP = (tonumber(data.XP) or 0) + summary.XP\n",
		"\t\tlocal xp0 = tonumber(data.XP) or 0\n\t\tdata.XP = xp0 + summary.XP\n"
			.. "\t\tpcall(function() require(ServerScriptService.Shared.RichNotify).LevelUp(player, xp0, data.XP) end)" .. T },
}
local LDM = {
	{ "\t\tPlayerStore.Increment(p, { \"XP\" }, summary.XP)\n",
		"\t\tlocal xpNew = PlayerStore.Increment(p, { \"XP\" }, summary.XP)\n"
			.. "\t\tif xpNew then pcall(function() require(ServerScriptService.Shared.RichNotify).LevelUp(p, xpNew - summary.XP, xpNew) end) end" .. T },
}

local function check(target, edits, label)
	for i, e in ipairs(edits) do
		assert(target.Source:find(e[2], 1, true) or target.Source:find(e[1], 1, true), label .. " edit " .. i .. ": original text not found (nothing changed)")
	end
end
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

assert(SSS:FindFirstChild("Shared") and SSS.Shared:FindFirstChild("RichNotify"), "install ServerScriptService.Shared.RichNotify first")
local jobs = { { M.LobbyManager, LM, "LobbyManager" } }
if isLobby then table.insert(jobs, { M.LobbyDuelManager, LDM, "LobbyDuelManager" })
else table.insert(jobs, { M.RoundManager, RM, "RoundManager" }) end
if not UNDO then for _, j in jobs do check(j[1], j[2], j[3]) end end
for _, j in jobs do swap(j[1], j[2], j[3]) end
return (isLobby and "lobby: " or "match: ") .. table.concat(log, ", ")
