-- party_install.lua : [PARTY] RIVALS-style parties (scripts/social/PartyService.lua + LobbyParty.server.lua), 2026-10-17.
-- Built by tools/party_build.py (sources embedded below). Lobby only. Idempotent; UNDO swaps every edit back and removes the
-- new objects. Every edit is checked before anything changes.
--   python tools/party_build.py --run lobby [UNDO]
-- New (attribute PartyInstall = true): ServerScriptService.Shared.PartyService, ServerScriptService.LobbyParty (Script)
-- [PARTY] edits in Managers.MatchmakingManager (backup ServerStorage._RebuildRemoved.PARTY_MatchmakingManager_Orig):
--   leader-only FindMatch (party fits the team size, members free), the entry carries the party (n, p, average rating / tier),
--   partyPick packs whole parties into team A / B, results for every member, the leader's MM_* state mirrored to the members,
--   the whole party teleports together, a roster change cancels the search.
-- ORDER: after secure_install (it edits lines [SECURE] wrote).
local UNDO = false --@UNDO

local SS = game:GetService("ServerStorage")
local SSS = game:GetService("ServerScriptService")
local CHS = game:GetService("ChangeHistoryService")
local TAG = "PartyInstall"
local SOURCES = {}
--@@BEGIN SOURCES
SOURCES.PartyService = [=[-- ServerScriptService.Shared.PartyService (ModuleScript, lobby) [PARTY] 2026-10-17: RIVALS-style parties (Edward, through the
-- UI session's Your Party screen). Parties live in this lobby server; the whole party queues online together (leader only,
-- MatchmakingManager [PARTY]) and teleports together onto the same team.
-- Player attributes on every member (everyone in the server sees them): PartyId (string), PartyLeader (UserId),
-- PartyMembers (JSON array of UserIds, leader first); all nil when solo.
--   PartyService.Of(player) -> party? { id, leader = Player, members = { Player } (leader first) }
--   PartyService.Members(player) -> { Player }   the party (leader first), or { player } when solo
--   PartyService.Join(leader, player) / Leave(player, why?) / Kick(leader, member) / Promote(leader, member)
--   PartyService.Changed  BindableEvent: :Fire(partyId, leaderOrNil, why) after every roster change
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local PartyService = {}
PartyService.MaxSize = 5
PartyService.Changed = Instance.new("BindableEvent")

local parties = {} -- [id] = party
local byPlayer = {} -- [Player] = party

local function publish(party)
	local ids = {}
	for _, m in party.members do table.insert(ids, m.UserId) end
	local json = HttpService:JSONEncode(ids)
	for _, m in party.members do
		m:SetAttribute("PartyId", party.id)
		m:SetAttribute("PartyLeader", party.leader.UserId)
		m:SetAttribute("PartyMembers", json)
	end
end

local function clearAttrs(p: Player)
	p:SetAttribute("PartyId", nil)
	p:SetAttribute("PartyLeader", nil)
	p:SetAttribute("PartyMembers", nil)
end

function PartyService.Of(player: Player)
	return byPlayer[player]
end

function PartyService.Members(player: Player)
	local party = byPlayer[player]
	if not party then return { player } end
	return table.clone(party.members)
end

function PartyService.IsLeader(player: Player): boolean
	local party = byPlayer[player]
	return party ~= nil and party.leader == player
end

-- player joins leader's party (a new party when the leader is solo). Returns ok, reason sentence.
function PartyService.Join(leader: Player, player: Player): (boolean, string?)
	if byPlayer[player] then return false, player.DisplayName .. " is already in a party" end
	local party = byPlayer[leader]
	if party and party.leader ~= leader then return false, "Only the party leader can invite" end
	if party and #party.members >= PartyService.MaxSize then return false, "Your party is full" end
	if not party then
		party = { id = HttpService:GenerateGUID(false), leader = leader, members = { leader } }
		parties[party.id] = party
		byPlayer[leader] = party
	end
	table.insert(party.members, player)
	byPlayer[player] = party
	publish(party)
	PartyService.Changed:Fire(party.id, party.leader, "join")
	return true
end

-- a member leaves (also used for disconnects and kicks). The next member becomes leader; a party of 1 dissolves.
function PartyService.Leave(player: Player, why: string?)
	local party = byPlayer[player]
	if not party then return false end
	byPlayer[player] = nil
	local i = table.find(party.members, player)
	if i then table.remove(party.members, i) end
	if player.Parent then clearAttrs(player) end
	local oldLeader = party.leader
	if party.leader == player then party.leader = party.members[1] end
	if #party.members <= 1 then
		for _, m in party.members do byPlayer[m] = nil; clearAttrs(m) end
		parties[party.id] = nil
		PartyService.Changed:Fire(party.id, nil, why or "dissolved")
		return true
	end
	publish(party)
	PartyService.Changed:Fire(party.id, party.leader, why or "leave")
	if oldLeader ~= party.leader then PartyService.Changed:Fire(party.id, party.leader, "promote") end
	return true
end

function PartyService.Kick(leader: Player, member: Player): (boolean, string?)
	local party = byPlayer[leader]
	if not party or party.leader ~= leader then return false, "Only the party leader can kick" end
	if member == leader or byPlayer[member] ~= party then return false, "They're not in your party" end
	PartyService.Leave(member, "kick")
	return true
end

function PartyService.Promote(leader: Player, member: Player): (boolean, string?)
	local party = byPlayer[leader]
	if not party or party.leader ~= leader then return false, "Only the party leader can promote" end
	if byPlayer[member] ~= party or member == leader then return false, "They're not in your party" end
	local i = table.find(party.members, member)
	table.remove(party.members, i)
	table.insert(party.members, 1, member)
	party.leader = member
	publish(party)
	PartyService.Changed:Fire(party.id, party.leader, "promote")
	return true
end

Players.PlayerRemoving:Connect(function(p)
	if byPlayer[p] then PartyService.Leave(p, "left") end
end)

return PartyService
]=]
SOURCES.LobbyParty = [=[-- ServerScriptService.LobbyParty (Script, lobby only) [PARTY] 2026-10-17: the remote side of PartyService (UI: Your Party screen,
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
]=]
--@@END SOURCES
assert(workspace:FindFirstChild("LobbyMap"), "lobby only")
local rec = CHS:TryBeginRecording("PARTY install" .. (UNDO and " UNDO" or ""))
local bin = SS:FindFirstChild("_RebuildRemoved") or Instance.new("Folder")
bin.Name = "_RebuildRemoved"; bin.Parent = SS
local log = {}
local function say(...) local t = {} for _, v in ipairs({ ... }) do table.insert(t, tostring(v)) end table.insert(log, table.concat(t, " ")) end
local mm = SSS.ServerScripts["[Server] Init"].GameManager.Managers.MatchmakingManager
local shared = SSS:WaitForChild("Shared")

local PICK = [==[
-- [PARTY] the next match out of the pool, keeping parties whole: entries (oldest first) packed into team A / B, need / 2
-- players each (entry.v.n players, entry.v.p their ids). Ranked: every pair inside each other's window (RankedCore.PairOk).
-- Returns the picked entries and the teams as user id lists (nil teams = all solo: splitTeams balances them as before).
local function partyPick(pool, need: number, q, now: number)
	local function size(e) return math.max(1, math.floor(tonumber(e.v.n) or 1)) end
	local function ids(e) return type(e.v.p) == "table" and e.v.p or { e.v.u } end
	local function tierOf(e) return tonumber(e.v.k) or RankedCore.TierOf(e.v.r or 0) end
	if need == 1 then
		for _, e in pool do if size(e) == 1 then return { e }, nil end end
		return nil
	end
	local cap = need // 2
	for i, anchor in pool do
		if size(anchor) <= cap then
			local group, fill, teamOf = { anchor }, { A = size(anchor), B = 0 }, { [anchor] = "A" }
			for j, e in pool do
				if j ~= i then
					local s = size(e)
					local side = (fill.A + s <= cap and "A") or (fill.B + s <= cap and "B") or nil
					if side and q.Ranked then
						for _, g in group do
							if not RankedCore.PairOk(tierOf(g), now - (g.v.t or now), tierOf(e), now - (e.v.t or now), q.Mode) then side = nil break end
						end
					end
					if side then
						table.insert(group, e)
						teamOf[e] = side
						fill[side] += s
						if fill.A == cap and fill.B == cap then
							local allSolo = true
							for _, g in group do if size(g) > 1 then allSolo = false end end
							if allSolo then return group, nil end
							local teams = { A = {}, B = {} }
							for _, g in group do for _, u in ids(g) do table.insert(teams[teamOf[g]], u) end end
							return group, teams
						end
					end
				end
			end
		end
	end
	return nil
end

]==]

local START_HOOK = [==[
	-- [PARTY] a roster change cancels the party's online search; a player who left a searching party loses the mirrored state
	PartyService.Changed.Event:Connect(function()
		for player, s in searching do
			if s.status == "Searching" and s.p then
				local now = {}
				for _, m in PartyService.Members(player) do table.insert(now, m.UserId) end
				if table.concat(now, ",") ~= table.concat(s.p, ",") then
					if leaveQueue(s) then
						stop(player)
						Remotes.Notify(player, "Your party changed: search cancelled", "info")
					end
				end
			end
		end
		for _, p in Players:GetPlayers() do
			if p:GetAttribute("MM_Queue") and not searching[p] then
				local party = PartyService.Of(p)
				if not (party and searching[party.leader]) then setState(p, nil, nil) end
			end
		end
	end)
]==]

local EDITS = {
	{ "local RankedServer = require(ServerScriptService.Shared.RankedServer)\n",
		"local RankedServer = require(ServerScriptService.Shared.RankedServer)\n"
			.. "-- [PARTY] parties queue together (ServerScriptService.Shared.PartyService)\n"
			.. "local PartyService = require(ServerScriptService.Shared.PartyService)\n" },
	{ "local function setState(player: Player, queue: string?, status: string?)\n\tplayer:SetAttribute(\"MM_Queue\", queue)\n\tplayer:SetAttribute(\"MM_Status\", status)\n\tif not status then player:SetAttribute(\"MM_Since\", nil) end\nend\n",
		"local function setState(player: Player, queue: string?, status: string?)\n"
			.. "\t-- [PARTY] the leader's search state shows on every member too\n"
			.. "\tlocal targets = (PartyService.IsLeader(player) and PartyService.Members(player)) or { player }\n"
			.. "\tfor _, p in targets do\n"
			.. "\t\tp:SetAttribute(\"MM_Queue\", queue)\n"
			.. "\t\tp:SetAttribute(\"MM_Status\", status)\n"
			.. "\t\tif not status then p:SetAttribute(\"MM_Since\", nil) elseif p ~= player then p:SetAttribute(\"MM_Since\", player:GetAttribute(\"MM_Since\")) end\n"
			.. "\tend\n"
			.. "end\n" },
	{ "\tif q.Ranked and not canRanked(player) then\n\t\treturn { ok = false, msg = `Ranked unlocks at level {Config.RankedLevel}` }\n\tend\n\tlocal key = tostring(player.UserId)\n",
		"\tif q.Ranked and not canRanked(player) then\n\t\treturn { ok = false, msg = `Ranked unlocks at level {Config.RankedLevel}` }\n\tend\n"
			.. "\t-- [PARTY] only the leader queues, for the whole party (it must fit one team, and everyone must be free)\n"
			.. "\tlocal party = PartyService.Of(player)\n"
			.. "\tlocal partyIds, partyR = nil, nil\n"
			.. "\tif party then\n"
			.. "\t\tif party.leader ~= player then return { ok = false, msg = \"Only the party leader can queue\" } end\n"
			.. "\t\tif #party.members > q.TeamSize then return { ok = false, msg = `Your party is too big for {string.upper(q.Mode)}` } end\n"
			.. "\t\tpartyIds, partyR = {}, 0\n"
			.. "\t\tfor _, m in party.members do\n"
			.. "\t\t\tif m ~= player and (m:GetAttribute(\"QueueMode\") or m:GetAttribute(\"DuelMatch\") or m:GetAttribute(\"InTraining\")) then\n"
			.. "\t\t\t\treturn { ok = false, msg = m.DisplayName .. \" is busy\" }\n"
			.. "\t\t\tend\n"
			.. "\t\t\tif q.Ranked and not canRanked(m) then return { ok = false, msg = m.DisplayName .. ` hasn't unlocked ranked (level {Config.RankedLevel})` } end\n"
			.. "\t\t\ttable.insert(partyIds, m.UserId)\n"
			.. "\t\t\tpartyR += ratingOf(m, q.Mode)\n"
			.. "\t\tend\n"
			.. "\t\tpartyR = partyR / #party.members\n"
			.. "\tend\n"
			.. "\tlocal key = tostring(player.UserId)\n" },
	{ "\tentry.k = RankedCore.TierOf(entry.r)\n",
		"\tentry.k = RankedCore.TierOf(entry.r)\n"
			.. "\t-- [PARTY] a party entry: n players, p their ids (leader first), queued at the party's average rating / tier\n"
			.. "\tif partyIds then entry.n = #partyIds; entry.p = partyIds; entry.r = partyR; entry.k = RankedCore.TierOf(partyR) end\n" },
	{ "status = \"Searching\", rating = entry.r, tier = entry.k }\n",
		"status = \"Searching\", rating = entry.r, tier = entry.k, n = entry.n, p = entry.p } -- [PARTY] n, p\n" },
	{ "return { u = player.UserId, j = game.JobId, r = s.rating, k = s.tier, t = s.since }, s.since\n",
		"return { u = player.UserId, j = game.JobId, r = s.rating, k = s.tier, t = s.since, n = s.n, p = s.p }, s.since -- [PARTY] n, p\n" },
	{ "local function startMatch(q, group, matchId: string): boolean\n",
		PICK .. "local function startMatch(q, group, matchId: string, packed): boolean -- [PARTY] packed teams\n" },
	{ "teams = splitTeams(group, q.Ranked), place = placeId }\n",
		"teams = packed or splitTeams(group, q.Ranked), place = placeId } -- [PARTY] packed\n" },
	{ "\tfor _, e in group do\n\t\tpcall(function() results:SetAsync(tostring(e.v.u), result, RESULT_TTL) end)\n\tend\n",
		"\t-- [PARTY] every member of every picked entry gets the result\n"
			.. "\tfor _, e in group do\n"
			.. "\t\tfor _, uid in (type(e.v.p) == \"table\" and e.v.p or { e.v.u }) do\n"
			.. "\t\t\tpcall(function() results:SetAsync(tostring(uid), result, RESULT_TTL) end)\n"
			.. "\t\tend\n"
			.. "\tend\n" },
	{ "\t\t\tlocal group = pickGroup(pool, need, q.Ranked, now, q.Mode)\n",
		"\t\t\tlocal group, packed = partyPick(pool, need, q, now) -- [PARTY] parties stay whole\n" },
	{ "\t\t\tif #claimed == need then\n\t\t\t\tif not startMatch(q, claimed, matchId) then\n",
		"\t\t\tif #claimed == #group then -- [PARTY] entries, not players\n\t\t\t\tif not startMatch(q, claimed, matchId, packed) then\n" },
	{ "\t\tLoadouts = { [tostring(player.UserId)] = PlayerStore.Loadout(player) },\n",
		"\t\tLoadouts = partyLoadouts, -- [PARTY] every member's loadout\n" },
	{ "\tlocal options = Instance.new(\"TeleportOptions\")\n\toptions.ReservedServerAccessCode = res.code\n\toptions:SetTeleportData({\n\t\tMode = res.mode,\n",
		"\t-- [PARTY] the whole party goes in one teleport\n"
			.. "\tlocal partyGroup, partyLoadouts = {}, {}\n"
			.. "\tfor _, m in PartyService.Members(player) do\n"
			.. "\t\tif m.Parent then table.insert(partyGroup, m); partyLoadouts[tostring(m.UserId)] = PlayerStore.Loadout(m) end\n"
			.. "\tend\n"
			.. "\tlocal options = Instance.new(\"TeleportOptions\")\n\toptions.ReservedServerAccessCode = res.code\n\toptions:SetTeleportData({\n\t\tMode = res.mode,\n" },
	{ "\tDataManager.ReleaseForTeleport(player)\n",
		"\tfor _, m in partyGroup do DataManager.ReleaseForTeleport(m) end -- [PARTY]\n" },
	{ "\tlocal ok, err = pcall(TeleportService.TeleportAsync, TeleportService, placeId, { player }, options)\n\tif not ok then\n\t\ttask.spawn(DataManager.RestoreAfterTeleportFail, player, tostring(err))\n",
		"\tlocal ok, err = pcall(TeleportService.TeleportAsync, TeleportService, placeId, partyGroup, options) -- [PARTY]\n\tif not ok then\n"
			.. "\t\tfor _, m in partyGroup do task.spawn(DataManager.RestoreAfterTeleportFail, m, tostring(err)) end -- [PARTY]\n" },
	{ "function MatchmakingManager.Start()\n",
		"function MatchmakingManager.Start()\n" .. START_HOOK },
}

local function module(parent, name, class, src)
	local m = parent:FindFirstChild(name)
	if m and not m:GetAttribute(TAG) then error(name .. " exists and is not ours") end
	if not m then m = Instance.new(class); m.Name = name; m:SetAttribute(TAG, true); m.Parent = parent; say("new", m:GetFullName()) end
	m.Source = src
end

if UNDO then
	local s = mm.Source
	for i = #EDITS, 1, -1 do
		local e = EDITS[i]
		local a, b = s:find(e[2], 1, true)
		if a then s = s:sub(1, a - 1) .. e[1] .. s:sub(b + 1); say("UNDO edit", i) end
	end
	mm.Source = s
	for _, x in { shared:FindFirstChild("PartyService"), SSS:FindFirstChild("LobbyParty") } do
		if x and x:GetAttribute(TAG) then x:Destroy(); say("removed", x.Name) end
	end
else
	local s = mm.Source
	for i, e in ipairs(EDITS) do
		assert(s:find(e[2], 1, true) or s:find(e[1], 1, true), "edit " .. i .. ": original text not found (nothing changed)")
	end
	module(shared, "PartyService", "ModuleScript", SOURCES.PartyService)
	module(SSS, "LobbyParty", "Script", SOURCES.LobbyParty)
	if not bin:FindFirstChild("PARTY_MatchmakingManager_Orig") and not s:find("[PARTY]", 1, true) then
		local b = mm:Clone(); b.Name = "PARTY_MatchmakingManager_Orig"; b:ClearAllChildren(); b.Parent = bin
	end
	for i, e in ipairs(EDITS) do
		if s:find(e[2], 1, true) then say("edit", i, "already in")
		else
			local a, b = s:find(e[1], 1, true)
			s = s:sub(1, a - 1) .. e[2] .. s:sub(b + 1)
			say("edit", i, "applied")
		end
	end
	local f, err = loadstring(s)
	assert(f, "MatchmakingManager would not parse: " .. tostring(err))
	mm.Source = s
end
if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
return table.concat(log, "\n")
