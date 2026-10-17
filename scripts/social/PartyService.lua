-- ServerScriptService.Shared.PartyService (ModuleScript, lobby) [PARTY] 2026-10-17: RIVALS-style parties (Edward, through the
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
