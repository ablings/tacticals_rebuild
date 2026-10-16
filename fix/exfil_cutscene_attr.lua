-- fix/exfil_cutscene_attr.lua (2026-10-16, for the UI session's HUD hide; Edward wants a clean cutscene)
-- ExfilFX sets player attribute InCutscene = true when the exfil cutscene starts and clears it when control returns. The
-- clear is in two places: right after controls(true), and again in the busy reset delay as a safety net. The UI hides the
-- lobby HUD, dock, PLAY row, bars, hotbar and pad JOIN boxes while it is set.
-- Idempotent. `python tools/run_luau.py fix/exfil_cutscene_attr.lua UNDO` removes the three marked lines.
local UNDO = false --@UNDO
local fx = game:GetService("StarterPlayer").StarterPlayerScripts.ExfilFX
local src = fx.Source
local TAG = "-- [EXFIL] InCutscene"

if UNDO then
	local out = {}
	for line in (src .. "\n"):gmatch("(.-)\n") do
		if not line:find(TAG, 1, true) then table.insert(out, line) end
	end
	-- the split adds one empty element for the trailing newline we appended
	if out[#out] == "" then table.remove(out) end
	fx.Source = table.concat(out, "\n")
	return "removed InCutscene lines"
end

if src:find(TAG, 1, true) then return "already applied" end

local function insertAfter(s, anchor, add)
	local a, z = s:find(anchor, 1, true)
	assert(a, "anchor not found: " .. anchor)
	local eol = s:find("\n", z, true) or #s
	return s:sub(1, eol) .. add .. "\n" .. s:sub(eol + 1)
end

src = insertAfter(src, "\tbusy = true; controls(false); hum.AutoRotate = false",
	'\tplayer:SetAttribute("InCutscene", true) ' .. TAG .. " start (UI hides the lobby HUD)")
src = insertAfter(src, "\tcam.CameraType = Enum.CameraType.Custom; controls(true)",
	'\tplayer:SetAttribute("InCutscene", nil) ' .. TAG .. " end")
src = insertAfter(src, "\ttask.delay(1.5, function() busy = false end)",
	'\ttask.delay(1.5, function() if player:GetAttribute("InCutscene") then player:SetAttribute("InCutscene", nil) end end) ' .. TAG .. " safety")
fx.Source = src
return "InCutscene set/cleared in ExfilFX"
