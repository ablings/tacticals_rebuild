-- fix/rematch_series.lua [BESTOF3] 2026-10-23 (match places: Matchmaking + Ranked share RoundManager). Edward: "once a best of 3 is
-- decided, Rematch must be unavailable", in every mode. The series already counts games / wins (SeriesGames / SeriesWinsA / B);
-- now a side with 2 wins ends it: ReplicatedStorage RematchAllowed = false, RematchReason = "Series decided" (the UI greys / hides
-- the button), and postMatch never starts another game. "Opponent left" stays as before. Lobby pad duels have no rematch.
-- Idempotent; UNDO swaps back.
local UNDO = false --@UNDO
local RM = game:GetService("ServerScriptService"):FindFirstChild("RoundManager", true)
assert(RM, "no RoundManager")
local old = "\tlocal allowed = present == s.total and s.total > 0\n"
	.. "\tReplicatedStorage:SetAttribute(\"SeriesGames\", s.games)\n"
local new = "\tlocal allowed = present == s.total and s.total > 0\n"
	.. "\t-- [BESTOF3] (Edward 2026-10-23) a best of 3: once a side has 2 wins the series is over, no more rematches\n"
	.. "\tlocal decided = math.max(s.winsA or 0, s.winsB or 0) >= 2\n"
	.. "\tlocal reason = decided and \"Series decided\" or ((not allowed) and \"Opponent left\" or nil)\n"
	.. "\tallowed = allowed and not decided\n"
	.. "\tReplicatedStorage:SetAttribute(\"SeriesGames\", s.games)\n"
local old2 = "\tReplicatedStorage:SetAttribute(\"RematchReason\", (not allowed) and \"Opponent left\" or nil)\n"
local new2 = "\tReplicatedStorage:SetAttribute(\"RematchReason\", reason) -- [BESTOF3]\n"
local s = RM.Source:gsub("\r\n", "\n")
local out = {}
for i, e in { { old, new }, { old2, new2 } } do
	local o, n = e[1], e[2]
	if UNDO then o, n = n, o end
	local done
	if UNDO then done = not s:find(o, 1, true) else done = s:find(n, 1, true) ~= nil end
	if done then
		table.insert(out, i .. "=")
	else
		local a, b = s:find(o, 1, true)
		assert(a, "RoundManager edit " .. i .. " anchor not found")
		assert(not s:find(o, b + 1, true), "RoundManager edit " .. i .. " anchor not unique")
		s = s:sub(1, a - 1) .. n .. s:sub(b + 1)
		table.insert(out, i .. "+")
	end
end
local f, err = loadstring(s)
assert(f, "RoundManager would not parse: " .. tostring(err))
if RM.Source ~= s then RM.Source = s end
return "BESTOF3 " .. table.concat(out, " ")
