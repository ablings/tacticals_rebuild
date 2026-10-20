-- fix/mm_failreason.lua [MMFAIL] (2026-10-19, for the UI session's MATCH FOUND screen, Edward: a found ranked game clears
-- the screen; a fall-through must restore it with a reason). Lobby only (MatchmakingManager). Run in Edit mode.
-- Player attribute MM_FailReason (string): set just BEFORE MM_Status drops to nil when a found match fails to start
-- (TeleportAsync error, TeleportInitFailed); cleared when the next search starts (any non-nil MM_Status).
-- MM_Status order on a match: Searching -> Found -> (1.2 s) Teleporting; a failure -> nil (queue cancelled, never left at
-- Teleporting). A ReserveServer failure happens before Found (the player simply stays Searching). Studio: Found -> nil after 2.5 s.
-- Idempotent (each edit checks whether it is already in); UNDO = true takes the [MMFAIL] lines out again.
local UNDO = false --@UNDO
local m = game:GetService("ServerScriptService"):FindFirstChild("MatchmakingManager", true)
assert(m, "MatchmakingManager not found (lobby only)")
local EDITS = {
	{ "\t\tp:SetAttribute(\"MM_Status\", status)\n",
	  "\t\tp:SetAttribute(\"MM_Status\", status)\n\t\tif status then p:SetAttribute(\"MM_FailReason\", nil) end -- [MMFAIL] a new search clears the last failure\n" },
	{ "\t\tRemotes.Notify(player, \"Couldn't join the match server. Try again.\", \"bad\")\n",
	  "\t\tfor _, pm in partyGroup do pm:SetAttribute(\"MM_FailReason\", \"Couldn't join the match server\") end -- [MMFAIL]\n\t\tRemotes.Notify(player, \"Couldn't join the match server. Try again.\", \"bad\")\n" },
	{ "\t\t\tRemotes.Notify(player, \"Teleport failed: \" .. tostring(message), \"bad\")\n",
	  "\t\t\tplayer:SetAttribute(\"MM_FailReason\", \"Teleport failed: \" .. tostring(message)) -- [MMFAIL]\n\t\t\tRemotes.Notify(player, \"Teleport failed: \" .. tostring(message), \"bad\")\n" },
}
local src = m.Source:gsub(string.char(13), "")
local log = {}
for i, e in ipairs(EDITS) do
	local from, to = e[1], e[2]
	if UNDO then from, to = e[2], e[1] end
	if src:find(to, 1, true) then
		table.insert(log, "edit " .. i .. (UNDO and " already out" or " already in"))
	else
		local a, b = src:find(from, 1, true)
		assert(a, "edit " .. i .. ": anchor not found (nothing changed)")
		assert(not src:find(from, b + 1, true), "edit " .. i .. ": anchor not unique")
		src = src:sub(1, a - 1) .. to .. src:sub(b + 1)
		table.insert(log, "edit " .. i .. (UNDO and " removed" or " applied"))
	end
end
local fn, err = loadstring(src)
assert(fn, "would not parse: " .. tostring(err))
m.Source = src
return "MMFAIL: " .. table.concat(log, ", ")
