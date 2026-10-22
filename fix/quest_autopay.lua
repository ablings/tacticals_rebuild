-- fix/quest_autopay.lua [AUTOPAY] 2026-10-21 (Edward via the UI session: "whatever RIVALS does" - RIVALS pays a finished task out on its
-- own and drops a "Task Completed" banner; no CLAIM click). LobbyManager (lobby + the match places' after-match lobby):
--  * autoPay(player): every Daily / Weekly task of the current period whose progress reached its goal and isn't claimed yet goes through
--    the existing ClaimQuest handler (same reward x pass multipliers, Claimed flag, RN.Send "Task Completed" with the Scissors count).
--  * runs on join (after ensureQuests) and every 3 s (stats arrive from matches / lobby duels); the period rollover check stays every 30 s.
-- The ClaimQuest remote still works (a click on an already-paid task says "Already claimed"). Idempotent; UNDO = true swaps back.
local UNDO = false --@UNDO
local LM = game:GetService("ServerScriptService"):FindFirstChild("LobbyManager", true)

local function patch(inst, edits)
	local s = inst.Source
	local out = {}
	for i, e in edits do
		local old, new = e[1], e[2]
		if UNDO then old, new = new, old end
		if s:find(new, 1, true) then table.insert(out, i .. "=") else
			local a, b = s:find(old, 1, true)
			assert(a, inst.Name .. " edit " .. i .. ": anchor not found")
			assert(not s:find(old, b + 1, true), inst.Name .. " edit " .. i .. ": anchor not unique")
			s = s:sub(1, a - 1) .. new .. s:sub(b + 1)
			table.insert(out, i .. "+")
		end
	end
	local f, err = loadstring(s)
	assert(f, inst.Name .. " would not parse: " .. tostring(err))
	if inst.Source ~= s then inst.Source = s end
	return inst.Name .. " " .. table.concat(out, " ")
end

return (UNDO and "UNDO " or "AUTOPAY ") .. patch(LM, {
	{ "\treturn result(true, `+{reward} scissors`)\nend\n",
	  "\treturn result(true, `+{reward} scissors`)\nend\n\n"
	  .. "-- [AUTOPAY] RIVALS: a finished task pays out by itself (the claim above: reward, Claimed, the \"Task Completed\" banner)\n"
	  .. "local function autoPay(player: Player)\n"
	  .. "\tlocal data = PlayerStore.Get(player)\n"
	  .. "\tif not data or type(data.Quests) ~= \"table\" or type(data.Stats) ~= \"table\" then return end\n"
	  .. "\tfor _, scope in { \"Daily\", \"Weekly\" } do\n"
	  .. "\t\tlocal q = data.Quests[scope]\n"
	  .. "\t\tif q and q.Key == periodKey(scope) and type(q.List) == \"table\" then\n"
	  .. "\t\t\tfor i, entry in q.List do\n"
	  .. "\t\t\t\tlocal def = questDef(scope, entry.Id)\n"
	  .. "\t\t\t\tif def and not entry.Claimed and (data.Stats[def.Stat] or 0) - (entry.Base or 0) >= def.Goal then\n"
	  .. "\t\t\t\t\tpcall(Remotes.Handlers.ClaimQuest, player, scope, i)\n"
	  .. "\t\t\t\tend\n"
	  .. "\t\t\tend\n"
	  .. "\t\tend\n"
	  .. "\tend\n"
	  .. "end\n"
	  .. "LobbyManager.AutoPayQuests = autoPay\n" },
	{ "\tensureQuests(player)\n\tcheckPasses(player)\n", "\tensureQuests(player)\n\tautoPay(player) -- [AUTOPAY]\n\tcheckPasses(player)\n" },
	{ "\t\t\ttask.wait(30)\n\t\t\tfor _, p in Players:GetPlayers() do\n\t\t\t\ttask.spawn(ensureQuests, p)\n\t\t\tend\n",
	  "\t\t\t-- [AUTOPAY] finished tasks pay out within ~3 s; the rollover check stays every 30 s\n"
	  .. "\t\t\tfor _ = 1, 10 do\n"
	  .. "\t\t\t\ttask.wait(3)\n"
	  .. "\t\t\t\tfor _, p in Players:GetPlayers() do task.spawn(autoPay, p) end\n"
	  .. "\t\t\tend\n"
	  .. "\t\t\tfor _, p in Players:GetPlayers() do\n\t\t\t\ttask.spawn(ensureQuests, p)\n\t\t\tend\n" },
})
