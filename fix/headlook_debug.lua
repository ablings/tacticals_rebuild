-- fix/headlook_debug.lua [POSE] 2026-10-18: HeadLookController (owns your own neck) uses AimPoseController's head pitch while
-- the gun is raised. Studio-only test switch, same as AimPoseController's: player attribute DebugForceRaised = true counts as
-- raised (simulated input can't hold aim). Never in a live server. Both places. Idempotent; UNDO swaps back.
local UNDO = false --@UNDO
local m = game.StarterPlayer.StarterPlayerScripts.Client.Controllers.HeadLookController
local OLD = "\tlocal facingCamera = Camera and Camera.IsFacingCamera and Camera.IsFacingCamera()\n"
local NEW = OLD .. "\tif game:GetService(\"RunService\"):IsStudio() and localPlayer:GetAttribute(\"DebugForceRaised\") == true then facingCamera = true end -- [POSE] Studio test switch\n"
local s = m.Source
if UNDO then
	local a, b = s:find(NEW, 1, true)
	if a then m.Source = s:sub(1, a - 1) .. OLD .. s:sub(b + 1) end
	return "undone"
end
if s:find(NEW, 1, true) then return "already applied" end
local a, b = s:find(OLD, 1, true)
assert(a, "facingCamera line not found")
s = s:sub(1, a - 1) .. NEW .. s:sub(b + 1)
assert(loadstring(s), "would not parse")
m.Source = s
return "HeadLookController: Studio raise switch in"
