-- fix/rematch_early.lua [REMATCHEARLY] 2026-10-21, found by the overnight playtest: the results screen (DuelHUD) shows Rematch as
-- live the moment the match ends (RematchAllowed is set then), but RoundManager.postMatchFlow only counted a vote once
-- postMatch() had started (after ResultsTime), so a Rematch press during the results was silently dropped and the button looked
-- broken. Now a Rematch vote is taken from Victory / MatchEnd on, and postMatch() keeps the votes cast during the results.
-- Match places (RoundManager). Idempotent; UNDO swaps back.
local UNDO = false --@UNDO
local RM = game:GetService("ServerScriptService"):FindFirstChild("RoundManager", true)
assert(RM, "no RoundManager")
local edits = {
	{ "\tlocal s = series\n\tif not (s and s.inPost) then return end\n\tif kind == \"Rematch\" then\n",
	  "\tlocal s = series\n"
	  .. "\t-- [REMATCHEARLY] Rematch also counts while the results show (the button is live from the match end)\n"
	  .. "\tlocal ended = ReplicatedStorage:GetAttribute(\"MatchState\") == \"Victory\" or ReplicatedStorage:GetAttribute(\"MatchState\") == \"MatchEnd\"\n"
	  .. "\tif not (s and (s.inPost or (kind == \"Rematch\" and ended))) then return end\n"
	  .. "\tif kind == \"Rematch\" then\n" },
	{ "\ts.votes, s.inPost = {}, true\n",
	  "\ts.votes, s.inPost = s.votes or {}, true -- [REMATCHEARLY] keep votes cast during the results\n" },
	{ "\t\tp:SetAttribute(\"InPseudoLobby\", true)\n\t\tp:SetAttribute(\"RematchVote\", nil)\n",
	  "\t\tp:SetAttribute(\"InPseudoLobby\", true)\n\t\tp:SetAttribute(\"RematchVote\", s.votes[p.UserId] == true or nil) -- [REMATCHEARLY]\n" },
}
local s = RM.Source
local out = {}
for i, e in edits do
	local old, new = e[1], e[2]
	local done
	if UNDO then old, new = new, old; done = not s:find(old, 1, true) else done = s:find(new, 1, true) ~= nil end
	if done then table.insert(out, i .. "=") else
		local a, b = s:find(old, 1, true)
		assert(a, "edit " .. i .. " anchor not found")
		assert(not s:find(old, b + 1, true), "edit " .. i .. " anchor not unique")
		s = s:sub(1, a - 1) .. new .. s:sub(b + 1)
		table.insert(out, i .. "+")
	end
end
local f, err = loadstring(s)
assert(f, "RoundManager would not parse: " .. tostring(err))
if RM.Source ~= s then RM.Source = s end
return "RoundManager " .. table.concat(out, " ")
