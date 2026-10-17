-- ServerScriptService.LobbyParty (Script, lobby only) [PARTY] 2026-10-17: the remote side of PartyService (UI: Your Party screen,
-- party avatars by PLAY, invite popups - UI session).
-- RemoteEvent ReplicatedStorage.LobbyParty:
--   client -> server   ("Invite", target)  ("Respond", from, accept)  ("Leave")  ("Kick", member)  ("Promote", member)
--   server -> client   ("Request", from, expiresAt)       to the invited player (workspace:GetServerTimeNow() based, 15 s)
--                      ("Closed", other, reason)           to both; reason = accepted | declined | expired | cancelled | full | busy
--                      ("Sent", target, ok, reason?)       to the inviter (reason = a sentence for the toast)
--                      ("Kicked", byLeader)                to a kicked member
-- Rules: the inviter must be solo or the leader; the target must be solo, free (no duel, pad, online queue, Training,
-- cutscene, deploy) and allow it (Setting_PartyInvites: Everyone default / Friends / Nobody); max 5; one open invite per
-- inviter -> target pair; a 0.4 s rate limit.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local PartyService = require(ServerScriptService:WaitForChild("Shared"):WaitForChild("PartyService"))

local REQUEST_TIME = 15
local RATE = 0.4

local remote = ReplicatedStorage:FindFirstChild("LobbyParty") or Instance.new("RemoteEvent")
remote.Name = "LobbyParty"
remote.Parent = ReplicatedStorage

local invites = {} -- ["fromId:toId"] = { from, to, expiresAt }
local lastCall = {}
local function now() return workspace:GetServerTimeNow() end
local function key(a, b) return a.UserId .. ":" .. b.UserId end

local function busyReason(p: Player): string?
	if not p.Parent then return "left the server" end
	if p:GetAttribute("DuelMatch") or p:GetAttribute("InDuel") then return "is in a duel" end
	if p:GetAttribute("QueueMode") then return "is on a duel pad" end
	if p:GetAttribute("MM_Queue") then return "is searching for a match" end
	if p:GetAttribute("InTraining") then return "is in Training" end
	if p:GetAttribute("InCutscene") or p:GetAttribute("Deploying") then return "is busy" end
	return nil
end

local function allows(target: Player, from: Player): (boolean, string?)
	local pref = target:GetAttribute("Setting_PartyInvites") or "Everyone"
	if pref == "Nobody" then return false, "isn't taking party invites" end
	if pref == "Friends" then
		local ok, friends = pcall(target.IsFriendsWith, target, from.UserId)
		if not (ok and friends) then return false, "only takes party invites from friends" end
	end
	return true
end

local function closeInvite(k: string, reason: string)
	local inv = invites[k]
	if not inv then return end
	invites[k] = nil
	if inv.from.Parent then remote:FireClient(inv.from, "Closed", inv.to, reason) end
	if inv.to.Parent then remote:FireClient(inv.to, "Closed", inv.from, reason) end
end

remote.OnServerEvent:Connect(function(player: Player, kind: any, other: any, accept: any)
	local t = os.clock()
	if lastCall[player] and t - lastCall[player] < RATE then return end
	lastCall[player] = t

	if kind == "Leave" then
		PartyService.Leave(player, "leave")
		return
	end
	if typeof(other) ~= "Instance" or not other:IsA("Player") or other.Parent ~= Players then return end

	if kind == "Invite" then
		local target = other
		local function no(reason) remote:FireClient(player, "Sent", target, false, reason) end
		if target == player then return no("You can't invite yourself") end
		local mine = PartyService.Of(player)
		if mine and mine.leader ~= player then return no("Only the party leader can invite") end
		if mine and #mine.members >= PartyService.MaxSize then return no("Your party is full") end
		if PartyService.Of(target) then return no(target.DisplayName .. " is already in a party") end
		if invites[key(player, target)] then return no("You already invited " .. target.DisplayName) end
		local theirs = busyReason(target)
		if theirs then return no(target.DisplayName .. " " .. theirs) end
		local ok, why = allows(target, player)
		if not ok then return no(target.DisplayName .. " " .. why) end
		local k = key(player, target)
		local expiresAt = now() + REQUEST_TIME
		invites[k] = { from = player, to = target, expiresAt = expiresAt }
		remote:FireClient(target, "Request", player, expiresAt)
		remote:FireClient(player, "Sent", target, true)
		task.delay(REQUEST_TIME + 0.2, function()
			local inv = invites[k]
			if inv and inv.expiresAt == expiresAt then closeInvite(k, "expired") end
		end)

	elseif kind == "Respond" then
		local from = other
		local k = key(from, player)
		local inv = invites[k]
		if not inv then return end
		if accept ~= true then return closeInvite(k, "declined") end
		if now() > inv.expiresAt then return closeInvite(k, "expired") end
		if busyReason(player) or PartyService.Of(player) then return closeInvite(k, "busy") end
		local fromParty = PartyService.Of(from)
		if fromParty and fromParty.leader ~= from then return closeInvite(k, "cancelled") end
		if fromParty and #fromParty.members >= PartyService.MaxSize then return closeInvite(k, "full") end
		invites[k] = nil
		local ok = PartyService.Join(from, player)
		local reason = ok and "accepted" or "full"
		if from.Parent then remote:FireClient(from, "Closed", player, reason) end
		remote:FireClient(player, "Closed", from, reason)

	elseif kind == "Kick" then
		local ok = PartyService.Kick(player, other)
		if ok and other.Parent then remote:FireClient(other, "Kicked", player) end

	elseif kind == "Promote" then
		PartyService.Promote(player, other)
	end
end)

-- an invite from someone who is no longer leader (or left) is withdrawn
PartyService.Changed.Event:Connect(function()
	for k, inv in invites do
		local p = PartyService.Of(inv.from)
		if not inv.from.Parent or (p and p.leader ~= inv.from) then closeInvite(k, "cancelled") end
	end
end)

Players.PlayerRemoving:Connect(function(p)
	lastCall[p] = nil
	for k, inv in invites do
		if inv.from == p or inv.to == p then closeInvite(k, "cancelled") end
	end
end)
