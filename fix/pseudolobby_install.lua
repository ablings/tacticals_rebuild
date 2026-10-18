-- fix/pseudolobby_install.lua [PSEUDOLOBBY] 2026-10-18: post-match phase 2 on the match places (Matchmaking / Ranked).
-- Needs ServerScriptService.Shared.PseudoLobby (scripts/pseudolobby/PseudoLobby.lua) and the map copy
-- (tools/pseudolobby_build.py map); without the map every edit falls back to the phase-1 behaviour (team spawns).
-- RoundManager:
--   postMatch(): PseudoLobby.Show(), everyone spawns around the hub's LobbySpawn; PseudoLobby.Hide() when the phase ends.
--   Play Again: a party leader takes every party member still in the pseudo lobby with them, in one TeleportAsync (same hub
--   server), TeleportData { AutoQueue, Party = { Leader, Members } } (the hub re-forms it: fix/party_regroup.lua). A member who
--   presses Play Again leaves the party and goes alone.
-- SettingsBridge: shared.SettingsApply(player) re-applies the saved settings, so a Settings save in the pseudo lobby
--   (LobbyManager.SaveSettings) reaches the Setting_* attributes at once.
-- Idempotent; checks every edit first; UNDO swaps back.
local UNDO = false --@UNDO
local SSS = game:GetService("ServerScriptService")
local RM = SSS.ServerScripts["[Server] Init"].GameManager.Managers.RoundManager
local SB = SSS:FindFirstChild("SettingsBridge")
local TAG = "[PSEUDOLOBBY]"
local log = {}

local HELPERS = [==[
-- [PSEUDOLOBBY] the after-match lobby map + party Play Again (fix/pseudolobby_install.lua)
local function pseudoLobby()
	local ok, PL = pcall(function() return require(ServerScriptService.Shared.PseudoLobby) end)
	return (ok and PL and PL.Available()) and PL or nil
end
local function partyService()
	local mod = ServerScriptService:FindFirstChild("Shared") and ServerScriptService.Shared:FindFirstChild("PartyService")
	local ok, PS = pcall(function() return mod and require(mod) end)
	return ok and PS or nil
end
local function postTeleportGroup(group, data)
	if IS_STUDIO then
		warn(("[RoundManager] [PSEUDOLOBBY] %d player(s) -> hub %s (skipped in Studio)"):format(#group, game:GetService("HttpService"):JSONEncode(data or {})))
		return
	end
	local DM = nil
	pcall(function() DM = require(game:GetService("ServerScriptService").Data.DataManager) end)
	local options = Instance.new("TeleportOptions")
	if data then options:SetTeleportData(data) end
	if DM and DM.ReleaseForTeleport then pcall(DM.ReleaseForTeleport, group) end
	local ok, err = pcall(TeleportService.TeleportAsync, TeleportService, LOBBY_PLACE, group, options)
	if not ok then
		warn("[RoundManager] [PSEUDOLOBBY] teleport failed: " .. tostring(err))
		if DM and DM.RestoreAfterTeleportFail then
			for _, p in group do task.spawn(DM.RestoreAfterTeleportFail, p, tostring(err)) end
		end
	end
end
local function playAgain(player: Player, qid: string)
	local group = { player }
	local PS = partyService()
	local party = PS and PS.Of(player)
	if party and #party.members > 1 then
		if party.leader ~= player then
			PS.Leave(player, "left")
		else
			group = {}
			for _, m in party.members do
				if m.Parent and (m == player or m:GetAttribute("InPseudoLobby")) then table.insert(group, m) end
			end
		end
	end
	local ids = {}
	for _, m in group do m:SetAttribute("InPseudoLobby", nil); table.insert(ids, m.UserId) end
	postTeleportGroup(group, { AutoQueue = qid, Party = #group > 1 and { Leader = player.UserId, Members = ids } or nil })
end

]==]

local RM_EDITS = {
	{ "local function postMatchFlow(player: Player, kind: string)\n",
		HELPERS .. "local function postMatchFlow(player: Player, kind: string)\n" },
	{ "\t\tplayer:SetAttribute(\"InPseudoLobby\", nil)\n\t\tpostTeleport(player, { AutoQueue = queueIdOf(s.first) })\n",
		"\t\tplayAgain(player, queueIdOf(s.first)) -- " .. TAG .. " parties go together\n" },
	{ "\tReplicatedStorage:SetAttribute(\"CombatEnabled\", false)\n\tfor _, p in Players:GetPlayers() do\n\t\tp:SetAttribute(\"InPseudoLobby\", true)\n",
		"\tReplicatedStorage:SetAttribute(\"CombatEnabled\", false)\n"
			.. "\tlocal PL = pseudoLobby() -- " .. TAG .. " the hub copy, if this place has one\n"
			.. "\tif PL and not PL.Show() then PL = nil end\n"
			.. "\tfor i, p in Players:GetPlayers() do\n\t\tp:SetAttribute(\"InPseudoLobby\", true)\n" },
	{ "\t\ttask.spawn(function()\n\t\t\tspawnPlayer(p, spawnFrame(side, 1, nil))\n",
		"\t\tlocal plcf = PL and PL.SpawnCFrame(i)\n\t\ttask.spawn(function()\n\t\t\tspawnPlayer(p, plcf or spawnFrame(side, 1, nil))\n" },
	{ "\ts.inPost = false\n\tReplicatedStorage:SetAttribute(\"PostMatch\", nil)\n",
		"\ts.inPost = false\n\tif PL then PL.Hide() end -- " .. TAG .. "\n\tReplicatedStorage:SetAttribute(\"PostMatch\", nil)\n" },
}

local SB_EDITS = {
	{ "Players.PlayerAdded:Connect(apply)\n",
		"Players.PlayerAdded:Connect(apply)\nshared.SettingsApply = apply -- " .. TAG .. " LobbyManager.SaveSettings re-applies after a save\n" },
}

local function run(target, edits, label)
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
	local f, err = loadstring(s)
	assert(f, label .. " would not parse: " .. tostring(err))
	target.Source = s
end

assert(not workspace:FindFirstChild("LobbyMap"), "this is the lobby: the pseudo lobby is for the match places")
-- check both before writing either
if not UNDO then
	for i, e in ipairs(RM_EDITS) do assert(RM.Source:find(e[2], 1, true) or RM.Source:find(e[1], 1, true), "RoundManager edit " .. i .. " not found (is postmatch_install in?)") end
	assert(SB, "SettingsBridge missing")
end
run(RM, RM_EDITS, "RoundManager")
if SB then run(SB, SB_EDITS, "SettingsBridge") end
return table.concat(log, ", ")
