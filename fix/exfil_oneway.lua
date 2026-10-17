-- fix/exfil_oneway.lua (2026-10-17 overnight glitch pass; overnight_report item 5): the Exfil barrier fired from both sides,
-- so walking BACK from the pad to the hangar through it also started the cutscene. Now the barrier only starts the exfil
-- while the player moves toward the pad (the CabinPoint, +X; the HatchPoint sits on the hangar side of the barrier) (or stands still in it). Tagged "-- [EXFIL] one-way".
-- Idempotent. `python tools/run_luau.py fix/exfil_oneway.lua UNDO` restores the plain hook.
local UNDO = false --@UNDO
local fx = game:GetService("StarterPlayer").StarterPlayerScripts.ExfilFX
local src = fx.Source
local TAG = "-- [EXFIL] one-way"
local OLD = 'hook("ExfilBarrier", exfil)\n'
local NEW = 'hook("ExfilBarrier", function() ' .. TAG .. ': only when heading for the pad (walking back out never fires it)\n'
	.. '\tlocal c = player.Character; local r = c and c:FindFirstChild("HumanoidRootPart")\n'
	.. '\tlocal map = workspace:FindFirstChild("LobbyMap"); local ex = map and map:FindFirstChild("Exfil"); local hp = ex and ex:FindFirstChild("CabinPoint")\n'
	.. '\tif r and hp then\n'
	.. '\t\tlocal to = (hp.Position - r.Position) * Vector3.new(1, 0, 1)\n'
	.. '\t\tlocal v = r.AssemblyLinearVelocity * Vector3.new(1, 0, 1)\n'
	.. '\t\tif v.Magnitude > 1 and to.Magnitude > 0.1 and v:Dot(to) <= 0 then return end\n'
	.. '\tend\n'
	.. '\texfil()\n'
	.. 'end)\n'

if UNDO then
	local a, b = src:find(NEW, 1, true)
	if not a then return "not applied" end
	fx.Source = src:sub(1, a - 1) .. OLD .. src:sub(b + 1)
	return "restored the two-way barrier"
end
if src:find(TAG, 1, true) then return "already applied" end
local a, b = src:find(OLD, 1, true)
assert(a, "hook line not found")
fx.Source = src:sub(1, a - 1) .. NEW .. src:sub(b + 1)
local f, err = loadstring(fx.Source)
return f and "one-way barrier added" or ("SYNTAX " .. tostring(err))
