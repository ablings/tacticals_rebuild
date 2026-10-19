-- fix/aim_raised.lua [POSE] 2026-10-18 (Edward: "if on my screen i am fully behind a pillar i shouldn't have my arm slightly
-- sticking out on her screen"). Both places, CombatManager: the AimPitch remote also carries whether the gun is RAISED
-- (AimRaised character attribute, true / false). Other clients' AimPoseController only bends someone's waist / arms / head
-- for the aim while that's true, exactly like the owner's own screen; before, everyone else treated a drawn gun as raised,
-- so a lowered gun behind cover could be bent level (out of cover) on their screens only. Old clients that don't send it
-- leave AimRaised unset (= the old behaviour). Idempotent; UNDO swaps back.
local UNDO = false --@UNDO
local CM = game:GetService("ServerScriptService").ServerScripts["[Server] Init"].GameManager.Managers.CombatManager
local OLD = "local function onAimPitch(player: Player, pitch: any)\n"
	.. "\tif not aimLimiter:CheckRate(player) then return end\n"
	.. "\tif type(pitch) ~= \"number\" or pitch ~= pitch then return end\n"
	.. "\tlocal character = player.Character\n"
	.. "\tif character then\n"
	.. "\t\tcharacter:SetAttribute(\"AimPitch\", math.floor(math.clamp(pitch, -75, 75) + 0.5))\n"
	.. "\tend\n"
	.. "end\n"
local NEW = "local function onAimPitch(player: Player, pitch: any, raised: any)\n"
	.. "\tif not aimLimiter:CheckRate(player) then return end\n"
	.. "\tif type(pitch) ~= \"number\" or pitch ~= pitch then return end\n"
	.. "\tlocal character = player.Character\n"
	.. "\tif character then\n"
	.. "\t\tcharacter:SetAttribute(\"AimPitch\", math.floor(math.clamp(pitch, -75, 75) + 0.5))\n"
	.. "\t\t-- [POSE] whether the gun is raised, so everyone bends the aim pose exactly when the owner's own screen does\n"
	.. "\t\tif type(raised) == \"boolean\" then character:SetAttribute(\"AimRaised\", raised) end\n"
	.. "\tend\n"
	.. "end\n"
local s = CM.Source
if UNDO then
	local a, b = s:find(NEW, 1, true)
	if a then CM.Source = s:sub(1, a - 1) .. OLD .. s:sub(b + 1) end
	return "undone"
end
if s:find(NEW, 1, true) then return "already applied" end
local a, b = s:find(OLD, 1, true)
assert(a, "onAimPitch not found")
s = s:sub(1, a - 1) .. NEW .. s:sub(b + 1)
assert(loadstring(s), "would not parse")
CM.Source = s
return "CombatManager: AimRaised"
