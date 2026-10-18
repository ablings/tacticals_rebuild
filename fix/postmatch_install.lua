-- fix/postmatch_install.lua [POSTMATCH] 2026-10-18 (Edward via the UI session): RIVALS-style post-match on the match places
-- (Matchmaking / Ranked): after the results players stay on the match server (the "pseudo lobby"), with To Hub / Play Again /
-- Rematch. A series is at most 3 games; a rematch is allowed while games < 3, neither side has 2 wins, and every original
-- player is still here; it starts when every present player has voted.
-- Match place (RoundManager):
--   runSeries(first) wraps runMatchServer: runMatchServer now RETURNS the winner instead of sending everyone home; after
--   each match postMatch() runs the pseudo-lobby phase (state below) and returns "rematch" (same server, same teams) or ends.
--   MatchFlow kinds "Rematch" (toggle vote), "PlayAgain" (teleport to the hub with TeleportData AutoQueue = queue id),
--   "ToHub" (teleport to the hub).
--   State (ReplicatedStorage): PostMatch, RematchVotes, RematchNeeded, RematchAllowed, RematchReason ("Unavailable" | nil),
--   RematchStartsAt, SeriesGames, SeriesWinsA, SeriesWinsB. Player: InPseudoLobby, RematchVote.
--   MatchConfig.PostMatchTime (default 300 s): then everyone still here goes to the hub. RematchCountdown default 3 s.
-- Lobby (MatchmakingManager): a player arriving with TeleportData AutoQueue = <queue id> is queued for it a moment after
--   their profile loads (the hub half of Play Again).
-- The pseudo-lobby MAP (a lobby copy loaded after the match, pads barricaded) is phase 2: for now players respawn at their
-- team spawn with combat off. Idempotent; checks every edit first; UNDO swaps back.
local UNDO = false --@UNDO
local IS_LOBBY = workspace:FindFirstChild("LobbyMap") ~= nil
local SSS = game:GetService("ServerScriptService")
local M = SSS.ServerScripts["[Server] Init"].GameManager.Managers
local TAG = "[POSTMATCH]"
local log = {}

local SERIES = [==[
-- [POSTMATCH] series + pseudo lobby (fix/postmatch_install.lua)
local series = nil
local function queueIdOf(first)
	if type(first.Queue) == "string" and first.Queue ~= "" then return first.Queue end
	return (first.Ranked == true and "R" or "") .. tostring(first.Mode)
end
local function seriesUpdate()
	local s = series
	if not s then return false end
	local present, votes = 0, 0
	for _, p in Players:GetPlayers() do
		if s.ids[p.UserId] then
			present += 1
			if s.votes[p.UserId] then votes += 1 end
		end
	end
	local allowed = s.games < 3 and s.winsA < 2 and s.winsB < 2 and present == s.total and s.total > 0
	ReplicatedStorage:SetAttribute("SeriesGames", s.games)
	ReplicatedStorage:SetAttribute("SeriesWinsA", s.winsA)
	ReplicatedStorage:SetAttribute("SeriesWinsB", s.winsB)
	ReplicatedStorage:SetAttribute("RematchAllowed", allowed)
	ReplicatedStorage:SetAttribute("RematchReason", (not allowed) and "Unavailable" or nil)
	ReplicatedStorage:SetAttribute("RematchVotes", votes)
	ReplicatedStorage:SetAttribute("RematchNeeded", present)
	return allowed and present > 0 and votes == present
end
local function postTeleport(player: Player, data)
	if IS_STUDIO then
		warn(("[RoundManager] [POSTMATCH] %s -> hub %s (skipped in Studio)"):format(player.Name, game:GetService("HttpService"):JSONEncode(data or {})))
		return
	end
	local DM = nil
	pcall(function() DM = require(game:GetService("ServerScriptService").Data.DataManager) end)
	local options = Instance.new("TeleportOptions")
	if data then options:SetTeleportData(data) end
	if DM and DM.ReleaseForTeleport then pcall(DM.ReleaseForTeleport, { player }) end
	local ok, err = pcall(TeleportService.TeleportAsync, TeleportService, LOBBY_PLACE, { player }, options)
	if not ok then
		warn("[RoundManager] [POSTMATCH] teleport failed: " .. tostring(err))
		if DM and DM.RestoreAfterTeleportFail then task.spawn(DM.RestoreAfterTeleportFail, player, tostring(err)) end
	end
end
local function postMatchFlow(player: Player, kind: string)
	local s = series
	if not (s and s.inPost) then return end
	if kind == "Rematch" then
		if not s.ids[player.UserId] then return end
		s.votes[player.UserId] = (not s.votes[player.UserId]) or nil
		player:SetAttribute("RematchVote", s.votes[player.UserId] == true or nil)
		seriesUpdate()
	elseif kind == "ToHub" then
		player:SetAttribute("InPseudoLobby", nil)
		postTeleport(player, nil)
	elseif kind == "PlayAgain" then
		player:SetAttribute("InPseudoLobby", nil)
		postTeleport(player, { AutoQueue = queueIdOf(s.first) })
	end
end
local function postMatch(): string
	local s = series
	s.votes, s.inPost = {}, true
	ReplicatedStorage:SetAttribute("PostMatch", true)
	ReplicatedStorage:SetAttribute("RematchStartsAt", nil)
	ReplicatedStorage:SetAttribute("CombatEnabled", false)
	for _, p in Players:GetPlayers() do
		p:SetAttribute("InPseudoLobby", true)
		p:SetAttribute("RematchVote", nil)
		p:SetAttribute("InMatch", false)
		local side = s.ids[p.UserId] or "A"
		task.spawn(function()
			spawnPlayer(p, spawnFrame(side, 1, nil))
			local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			if root then root.Anchored = false end
		end)
	end
	local result = "done"
	local t0 = os.clock()
	while true do
		if #Players:GetPlayers() == 0 then result = "empty" break end
		if os.clock() - t0 > (C.PostMatchTime or 300) then
			backToLobby(Players:GetPlayers())
			result = "timeout"
			break
		end
		if seriesUpdate() then
			-- everyone voted: a short countdown (a vote taken back or a leave cancels it)
			local cd = C.RematchCountdown or 3
			ReplicatedStorage:SetAttribute("RematchStartsAt", workspace:GetServerTimeNow() + cd)
			local t1, still = os.clock(), true
			while os.clock() - t1 < cd do
				if not seriesUpdate() then still = false break end
				task.wait(0.1)
			end
			ReplicatedStorage:SetAttribute("RematchStartsAt", nil)
			if still then result = "rematch" break end
		end
		task.wait(0.25)
	end
	s.inPost = false
	ReplicatedStorage:SetAttribute("PostMatch", nil)
	for _, p in Players:GetPlayers() do p:SetAttribute("InPseudoLobby", nil); p:SetAttribute("RematchVote", nil) end
	return result
end
local function runSeries(first)
	series = { first = first, games = 0, winsA = 0, winsB = 0, votes = {}, ids = {}, total = 0, inPost = false }
	for side, list in first.Teams do
		if side == "A" or side == "B" then
			for _, id in list do
				local n = tonumber(id)
				if n and n > 0 then series.ids[n] = side; series.total += 1 end
			end
		end
	end
	while true do
		series.games += 1
		seriesUpdate()
		local winner = runMatchServer(first)
		if winner == "A" then series.winsA += 1 elseif winner == "B" then series.winsB += 1 end
		seriesUpdate()
		if #Players:GetPlayers() == 0 then return end
		local r = postMatch()
		if r ~= "rematch" then return end
	end
end

]==]

local MATCH_EDITS = {
	-- runMatchServer returns the winner instead of sending everyone home (postMatch decides)
	{ "\tendMatchRecord(match)\n\tbackToLobby(Players:GetPlayers())\nend\n",
		"\tendMatchRecord(match)\n\t-- " .. TAG .. " the series decides what happens next (rematch / pseudo lobby / hub)\n\treturn winner, forfeit\nend\n" },
	-- the new MatchFlow kinds
	{ "local KINDS = { Vote = true, Pick = true, Ready = true, Leave = true, Loaded = true }\n",
		SERIES .. "local KINDS = { Vote = true, Pick = true, Ready = true, Leave = true, Loaded = true, Rematch = true, PlayAgain = true, ToHub = true } -- " .. TAG .. " +Rematch/PlayAgain/ToHub\n" },
	{ "\tlocal match = current\n\tlocal m = match and match.byUser[player.UserId]\n",
		"\tif kind == \"Rematch\" or kind == \"PlayAgain\" or kind == \"ToHub\" then postMatchFlow(player, kind) return end -- " .. TAG .. "\n"
			.. "\tlocal match = current\n\tlocal m = match and match.byUser[player.UserId]\n" },
	-- the match server runs a series
	{ "pcall(runMatchServer, first)", "pcall(runSeries, first) -- " .. TAG .. " series + pseudo lobby\n\t\t\t" },
}

local LOBBY_EDITS = {
	{ "function MatchmakingManager.Start()\n",
		"function MatchmakingManager.Start()\n"
			.. "\t-- " .. TAG .. " Play Again from a match place: TeleportData AutoQueue = <queue id> queues the player on arrival\n"
			.. "\tlocal function autoQueue(player: Player)\n"
			.. "\t\tlocal ok, td = pcall(function() return player:GetJoinData().TeleportData end)\n"
			.. "\t\tlocal qid = ok and type(td) == \"table\" and td.AutoQueue\n"
			.. "\t\tif type(qid) ~= \"string\" or not Config.QueueById(qid) then return end\n"
			.. "\t\ttask.spawn(function()\n"
			.. "\t\t\tPlayerStore.Wait(player)\n"
			.. "\t\t\ttask.wait(3)\n"
			.. "\t\t\tif player.Parent and not searching[player] then\n"
			.. "\t\t\t\tlocal res = Remotes.Handlers.FindMatch(player, qid)\n"
			.. "\t\t\t\tif type(res) == \"table\" and res.msg then Remotes.Notify(player, res.msg, res.ok and \"info\" or \"bad\") end\n"
			.. "\t\t\tend\n"
			.. "\t\tend)\n"
			.. "\tend\n"
			.. "\tPlayers.PlayerAdded:Connect(autoQueue)\n"
			.. "\tfor _, p in Players:GetPlayers() do autoQueue(p) end\n" },
}

local target = IS_LOBBY and M.MatchmakingManager or M.RoundManager
local edits = IS_LOBBY and LOBBY_EDITS or MATCH_EDITS
local s = target.Source
if UNDO then
	for i = #edits, 1, -1 do
		local a, b = s:find(edits[i][2], 1, true)
		if a then s = s:sub(1, a - 1) .. edits[i][1] .. s:sub(b + 1); table.insert(log, "undo " .. i) end
	end
	target.Source = s
	return table.concat(log, "\n")
end
for i, e in ipairs(edits) do
	assert(s:find(e[2], 1, true) or s:find(e[1], 1, true), "edit " .. i .. ": original text not found (nothing changed)")
end
for i, e in ipairs(edits) do
	if s:find(e[2], 1, true) then table.insert(log, "edit " .. i .. " already in")
	else
		local a, b = s:find(e[1], 1, true)
		s = s:sub(1, a - 1) .. e[2] .. s:sub(b + 1)
		table.insert(log, "edit " .. i .. " applied")
	end
end
local f, err = loadstring(s)
assert(f, "would not parse: " .. tostring(err))
target.Source = s
return (IS_LOBBY and "lobby: " or "match: ") .. table.concat(log, ", ")
