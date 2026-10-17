-- ServerScriptService.LobbySocial (Script, lobby only) [SOCIAL] 2026-10-17: RIVALS-style "Challenge" from the player menu /
-- profile card (UI session: UIKit.PlayerCards). A 1v1 lobby duel between two players in this server, started through
-- LobbyDuelManager.StartMatch exactly like a pad duel (MapVote, Loadout, rounds, the same arenas). Spectate is NOT here:
-- Edward paused spectating.
-- RemoteEvent ReplicatedStorage.LobbySocial:
--   client -> server   ("Challenge", target)  ("Respond", from, accept)  ("Cancel", target)
--   server -> client   ("Request", from, expiresAt)            to the target (expiresAt = workspace:GetServerTimeNow() based)
--                      ("Closed", other, reason)                to both; reason = accepted | declined | expired | cancelled | busy
--                      ("Sent", target, ok, reason?)            to the sender (toast)
-- Rules: not yourself; both in the lobby and free (no duel, pad, online queue, Training, cutscene, deploy); the target's
-- Setting_ChallengeRequests ("Everyone" default / "Friends" / "Nobody"); one open challenge per sender; 10 s cooldown per
-- sender -> target pair; a request expires after REQUEST_TIME.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local REQUEST_TIME = 15
local PAIR_COOLDOWN = 10
local RATE = 0.4

local remote = ReplicatedStorage:FindFirstChild("LobbySocial") or Instance.new("RemoteEvent")
remote.Name = "LobbySocial"
remote.Parent = ReplicatedStorage

local outgoing = {} -- [sender] = { target = Player, expiresAt = number }
local lastPair = {} -- ["senderId:targetId"] = os.clock()
local lastCall = {} -- [Player] = os.clock()

local function now() return workspace:GetServerTimeNow() end

local function busyReason(p: Player): string?
	if not p.Parent then return "left the server" end
	if p:GetAttribute("DuelMatch") or p:GetAttribute("InDuel") then return "is in a duel" end
	if p:GetAttribute("QueueMode") then return "is on a duel pad" end
	if p:GetAttribute("MM_Queue") then return "is searching online" end
	if p:GetAttribute("InTraining") then return "is in Training" end
	if p:GetAttribute("InCutscene") or p:GetAttribute("Deploying") then return "is busy" end
	local c = p.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	if not (h and h.Health > 0) then return "hasn't spawned" end
	return nil
end

local function allows(target: Player, from: Player): (boolean, string?)
	local pref = target:GetAttribute("Setting_ChallengeRequests") or "Everyone"
	if pref == "Nobody" then return false, "isn't taking challenges" end
	if pref == "Friends" then
		local ok, friends = pcall(target.IsFriendsWith, target, from.UserId)
		if not (ok and friends) then return false, "only takes challenges from friends" end
	end
	return true
end

local function close(sender: Player, reason: string)
	local o = outgoing[sender]
	if not o then return end
	outgoing[sender] = nil
	if sender.Parent then remote:FireClient(sender, "Closed", o.target, reason) end
	if o.target.Parent then remote:FireClient(o.target, "Closed", sender, reason) end
end

local function startDuel(a: Player, b: Player): (boolean, string?)
	local LDM = shared.Get and shared.Get("LobbyDuelManager")
	if not (LDM and LDM.StartMatch) then return false, "duels aren't available" end
	if LDM.Enabled and not LDM.Enabled() then return false, "duels are off" end
	local function entry(p)
		local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		return { player = p, stepOff = r and r.CFrame or nil }
	end
	return LDM.StartMatch(nil, "1v1", { A = { entry(a) }, B = { entry(b) } })
end

remote.OnServerEvent:Connect(function(player: Player, kind: any, other: any, accept: any)
	local t = os.clock()
	if lastCall[player] and t - lastCall[player] < RATE then return end
	lastCall[player] = t
	if typeof(other) ~= "Instance" or not other:IsA("Player") or other.Parent ~= Players then return end

	if kind == "Challenge" then
		local target = other
		local function no(reason) remote:FireClient(player, "Sent", target, false, reason) end
		if target == player then return no("You can't challenge yourself") end
		if outgoing[player] then return no("You already have a challenge out") end
		local key = player.UserId .. ":" .. target.UserId
		if lastPair[key] and t - lastPair[key] < PAIR_COOLDOWN then return no("Wait a moment before challenging them again") end
		local mine = busyReason(player)
		if mine then return no("You can't challenge right now") end
		local theirs = busyReason(target)
		if theirs then return no(target.DisplayName .. " " .. theirs) end
		local ok, why = allows(target, player)
		if not ok then return no(target.DisplayName .. " " .. why) end
		lastPair[key] = t
		local expiresAt = now() + REQUEST_TIME
		outgoing[player] = { target = target, expiresAt = expiresAt }
		remote:FireClient(target, "Request", player, expiresAt)
		remote:FireClient(player, "Sent", target, true)
		task.delay(REQUEST_TIME + 0.2, function()
			local o = outgoing[player]
			if o and o.target == target and o.expiresAt == expiresAt then close(player, "expired") end
		end)

	elseif kind == "Respond" then
		local sender = other
		local o = outgoing[sender]
		if not (o and o.target == player) then return end
		if accept ~= true then return close(sender, "declined") end
		if now() > o.expiresAt then return close(sender, "expired") end
		if busyReason(sender) or busyReason(player) then return close(sender, "busy") end
		outgoing[sender] = nil
		local ok, why = startDuel(sender, player)
		if ok then
			remote:FireClient(sender, "Closed", player, "accepted")
			remote:FireClient(player, "Closed", sender, "accepted")
		else
			remote:FireClient(sender, "Closed", player, "busy")
			remote:FireClient(player, "Closed", sender, "busy")
			remote:FireClient(sender, "Sent", player, false, tostring(why))
		end

	elseif kind == "Cancel" then
		local o = outgoing[player]
		if o and o.target == other then close(player, "cancelled") end
	end
end)

Players.PlayerRemoving:Connect(function(p)
	lastCall[p] = nil
	if outgoing[p] then close(p, "cancelled") end
	for sender, o in outgoing do
		if o.target == p then close(sender, "cancelled") end
	end
end)
