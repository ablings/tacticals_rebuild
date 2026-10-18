-- fix/party_regroup.lua [PSEUDOLOBBY] 2026-10-18 (lobby, MatchmakingManager; after fix/postmatch_install.lua): the hub half of a
-- party's Play Again. The match place teleports the party together with TeleportData { AutoQueue, Party = { Leader, Members } }
-- (fix/pseudolobby_install.lua). Here each member re-joins the leader's party, then the leader queues for everyone (leader-only
-- queue, [PARTY]).
-- Trust: TeleportData can be forged by a client, so a member is only put in a party the LEADER's own join data names them in
-- (a forged "Party = { Leader = <someone> }" alone joins nobody).
-- Idempotent; UNDO swaps back.
local UNDO = false --@UNDO
local MM = game:GetService("ServerScriptService").ServerScripts["[Server] Init"].GameManager.Managers.MatchmakingManager
local TAG = "[PSEUDOLOBBY]"
local OLD = "\t\tlocal qid = ok and type(td) == \"table\" and td.AutoQueue\n"
	.. "\t\tif type(qid) ~= \"string\" or not Config.QueueById(qid) then return end\n"
	.. "\t\ttask.spawn(function()\n"
	.. "\t\t\tPlayerStore.Wait(player)\n"
	.. "\t\t\ttask.wait(3)\n"
local NEW = "\t\tlocal qid = ok and type(td) == \"table\" and td.AutoQueue\n"
	.. "\t\tif type(qid) ~= \"string\" or not Config.QueueById(qid) then return end\n"
	.. "\t\t-- " .. TAG .. " a party that pressed Play Again together re-forms here, then its leader queues for everyone\n"
	.. "\t\tlocal pty = type(td.Party) == \"table\" and type(td.Party.Members) == \"table\" and td.Party or nil\n"
	.. "\t\tlocal leaderId = pty and tonumber(pty.Leader)\n"
	.. "\t\tif leaderId == player.UserId then partyClaims[player.UserId] = pty end\n"
	.. "\t\ttask.spawn(function()\n"
	.. "\t\t\tPlayerStore.Wait(player)\n"
	.. "\t\t\tif leaderId and leaderId ~= player.UserId then\n"
	.. "\t\t\t\tlocal t0 = os.clock()\n"
	.. "\t\t\t\tlocal leader = game:GetService(\"Players\"):GetPlayerByUserId(leaderId)\n"
	.. "\t\t\t\twhile not (leader and partyClaims[leaderId]) and os.clock() - t0 < 20 and player.Parent do\n"
	.. "\t\t\t\t\ttask.wait(0.5); leader = game:GetService(\"Players\"):GetPlayerByUserId(leaderId)\n"
	.. "\t\t\t\tend\n"
	.. "\t\t\t\tlocal claim = partyClaims[leaderId]\n"
	.. "\t\t\t\tif leader and claim and table.find(claim.Members, player.UserId) and player.Parent then\n"
	.. "\t\t\t\t\tlocal PS = require(game:GetService(\"ServerScriptService\").Shared.PartyService)\n"
	.. "\t\t\t\t\tpcall(PS.Join, leader, player)\n"
	.. "\t\t\t\t\treturn -- the leader queues the party\n"
	.. "\t\t\t\tend\n"
	.. "\t\t\t\t-- no matching leader claim: queue alone like a solo Play Again\n"
	.. "\t\t\telseif leaderId then\n"
	.. "\t\t\t\tlocal t0 = os.clock()\n"
	.. "\t\t\t\tlocal function allIn()\n"
	.. "\t\t\t\t\tfor _, id in pty.Members do\n"
	.. "\t\t\t\t\t\tlocal p = game:GetService(\"Players\"):GetPlayerByUserId(tonumber(id) or 0)\n"
	.. "\t\t\t\t\t\tif p ~= player and (not p or p:GetAttribute(\"PartyLeader\") ~= player.UserId) then return false end\n"
	.. "\t\t\t\t\tend\n"
	.. "\t\t\t\t\treturn true\n"
	.. "\t\t\t\tend\n"
	.. "\t\t\t\twhile os.clock() - t0 < 25 and player.Parent and not allIn() do task.wait(0.5) end\n"
	.. "\t\t\t\tpartyClaims[player.UserId] = nil\n"
	.. "\t\t\tend\n"
	.. "\t\t\ttask.wait(3)\n"
local OLD2 = "\tlocal function autoQueue(player: Player)\n"
local NEW2 = "\tlocal partyClaims = {} -- " .. TAG .. " [leaderId] = the leader's own TeleportData.Party (members check against it)\n"
	.. "\tlocal function autoQueue(player: Player)\n"

local s = MM.Source
if UNDO then
	local a, b = s:find(NEW, 1, true); if a then s = s:sub(1, a - 1) .. OLD .. s:sub(b + 1) end
	a, b = s:find(NEW2, 1, true); if a then s = s:sub(1, a - 1) .. OLD2 .. s:sub(b + 1) end
	MM.Source = s
	return "undone"
end
if s:find(NEW, 1, true) and s:find(NEW2, 1, true) then return "already applied" end
assert(s:find(OLD, 1, true), "autoQueue body not found (is fix/postmatch_install.lua in?)")
assert(s:find(OLD2, 1, true), "autoQueue not found")
local a, b = s:find(OLD, 1, true); s = s:sub(1, a - 1) .. NEW .. s:sub(b + 1)
a, b = s:find(OLD2, 1, true); s = s:sub(1, a - 1) .. NEW2 .. s:sub(b + 1)
local f, err = loadstring(s)
assert(f, "would not parse: " .. tostring(err))
MM.Source = s
return "party Play Again regroups in the hub"
