-- fix/party_queue_msgs.lua [PARTY] 2026-10-18 (UI session, from Edward's live RIVALS party test; lobby MatchmakingManager):
-- FindMatch refuses the same three cases as the Play menu's RIVALS "Whoops!" box, with its exact strings, BEFORE anything else
-- (also before the offline / Studio refusal, so the box and the reply always match):
--   "Only the party leader can join a queue!"          a non-leader party member
--   "This party is too big for this queue!"            party size > the queue's TeamSize
--   "A party member (@<Name>) is currently in a duel!" any member with InDuel / DuelMatch (lobby pad duels too)
-- The older [PARTY] checks below stay (busy on a pad / in Training, ranked level). Idempotent; UNDO swaps back.
local UNDO = false --@UNDO
local MM = game:GetService("ServerScriptService").ServerScripts["[Server] Init"].GameManager.Managers.MatchmakingManager
local OLD = "\tif not q then return { ok = false, msg = \"Unknown queue\" } end\n"
local NEW = OLD
	.. "\t-- [PARTY] RIVALS' \"Whoops!\" cases first, with the Play menu's exact strings (fix/party_queue_msgs.lua)\n"
	.. "\tdo\n"
	.. "\t\tlocal pty = PartyService.Of(player)\n"
	.. "\t\tif pty then\n"
	.. "\t\t\tif pty.leader ~= player then return { ok = false, msg = \"Only the party leader can join a queue!\" } end\n"
	.. "\t\t\tif #pty.members > q.TeamSize then return { ok = false, msg = \"This party is too big for this queue!\" } end\n"
	.. "\t\t\tfor _, m in pty.members do\n"
	.. "\t\t\t\tif m:GetAttribute(\"InDuel\") or m:GetAttribute(\"DuelMatch\") then\n"
	.. "\t\t\t\t\treturn { ok = false, msg = \"A party member (@\" .. m.Name .. \") is currently in a duel!\" }\n"
	.. "\t\t\t\tend\n"
	.. "\t\t\tend\n"
	.. "\t\tend\n"
	.. "\tend\n"
local s = MM.Source
if UNDO then
	local a, b = s:find(NEW, 1, true)
	if a then s = s:sub(1, a - 1) .. OLD .. s:sub(b + 1) end
	MM.Source = s
	return "undone"
end
if s:find(NEW, 1, true) then return "already applied" end
local a, b = s:find(OLD, 1, true)
assert(a, "FindMatch queue check not found")
assert(not s:find(OLD, b + 1, true), "queue check found twice")
s = s:sub(1, a - 1) .. NEW .. s:sub(b + 1)
assert(loadstring(s), "would not parse")
MM.Source = s
return "FindMatch party refusals in"
