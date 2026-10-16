-- fix/exfil_leave_hooks.lua (2026-10-16, for the UI session's RIVALS-style Training UI; Edward: gameplay UI RIVALS-like)
-- Three small ExfilFX edits, each line tagged "-- [EXFIL] leave":
--   1. BindableEvent PlayerGui.ExfilFade.LeaveTraining calls leave() (next to QuickEnter); the UI's corner button fires it.
--   2. The M key reads the player's bind: Binds.Matches(player, "LeaveTraining", input, Enum.KeyCode.M).
--   3. The old olive LEAVE [M] button never shows (syncLeave keeps it hidden); the UI's button and hint strip replace it.
-- Idempotent. `python tools/run_luau.py fix/exfil_leave_hooks.lua UNDO` restores the three spots.
local UNDO = false --@UNDO
local fx = game:GetService("StarterPlayer").StarterPlayerScripts.ExfilFX
local src = fx.Source
local TAG = "-- [EXFIL] leave"

local OLD_M = "\tif input.KeyCode == Enum.KeyCode.M and inTraining() then task.spawn(leave) end"
local NEW_M = '\tif Binds.Matches(player, "LeaveTraining", input, Enum.KeyCode.M) and inTraining() then task.spawn(leave) end ' .. TAG .. " (bind)"
local OLD_SYNC = "local function syncLeave() leaveBtn.Visible = inTraining() end"
local NEW_SYNC = "local function syncLeave() leaveBtn.Visible = false end " .. TAG .. " (the UI's corner button replaces it)"
local REQ = 'local Binds = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("Binds")) ' .. TAG .. " (require)"
local EVT = 'do local lv = Instance.new("BindableEvent"); lv.Name = "LeaveTraining"; lv.Parent = gui; lv.Event:Connect(function() if inTraining() then task.spawn(leave) end end) end ' .. TAG .. " (event)"

local function swap(s, a, b)
	local i, j = s:find(a, 1, true)
	assert(i, "not found: " .. a:sub(1, 70))
	return s:sub(1, i - 1) .. b .. s:sub(j + 1)
end
local function dropLine(s, needle)
	local out = {}
	for line in (s .. "\n"):gmatch("(.-)\n") do
		if not line:find(needle, 1, true) then table.insert(out, line) end
	end
	if out[#out] == "" then table.remove(out) end
	return table.concat(out, "\n")
end

if UNDO then
	if not src:find(TAG, 1, true) then return "not applied" end
	src = swap(src, NEW_M, OLD_M)
	src = swap(src, NEW_SYNC, OLD_SYNC)
	src = dropLine(src, TAG .. " (require)")
	src = dropLine(src, TAG .. " (event)")
	fx.Source = src
	return "restored leave hooks"
end

if src:find(TAG, 1, true) then return "already applied" end
src = swap(src, OLD_M, NEW_M)
src = swap(src, OLD_SYNC, NEW_SYNC)
-- the require goes right after the Training events line (line 7)
local anchor = 'local TR = game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("Training")'
local i, j = src:find(anchor, 1, true)
assert(i, "anchor TR not found")
local eol = src:find("\n", j, true)
src = src:sub(1, eol) .. REQ .. "\n" .. src:sub(eol + 1)
-- the event goes right after the QuickEnter BindableEvent line
local qi, qj = src:find('quick.Name = "QuickEnter"; quick.Parent = gui', 1, true)
assert(qi, "QuickEnter not found")
local qeol = src:find("\n", qj, true)
src = src:sub(1, qeol) .. EVT .. "\n" .. src:sub(qeol + 1)
fx.Source = src
return "leave hooks added"
