-- exfil_lift.lua : new helicopter lift path in StarterPlayerScripts.ExfilFX for the UH-60 kit (Edward approved, 2026-10-16).
-- The old path (x + 3.2e^2, y + 2.2e^1.5, roll) carried the heli through the east-edge gear and the rotor disc under the hangar
-- mouth. The new one, in a POSE block that fix/check_heli.lua loads and sweeps at 30 Hz:
--   spool on the pad (rotor speeds up, light on the wheels, slight nose-down) -> hover-taxi right out from under the hangar
--   mouth (rotor kept under the EXFIL sign / mouth lintel until its west edge is past the roof edge x 128.4) -> vertical climb
--   clear of the edge gear -> nose-down departure that yaws and banks right out over the open sky edge.
-- Only three marked places in ExfilFX change: the `spool` local (line ~32), the rotor spin speed (Heartbeat), and the lift
-- render step + fade wait (the jump, CabinPoint, fade length and Training entry are untouched).
-- Tacticals_rebuild.rbxl ONLY. Idempotent (re-applies from the original text). Original source backed up once in
-- ServerStorage._RebuildRemoved.ExfilFX_Orig (Disabled clone).
-- Run:  python tools/run_luau.py fix/exfil_lift.lua        UNDO: python tools/run_luau.py fix/exfil_lift.lua UNDO
local UNDO = false --@UNDO

local SS = game:GetService("ServerStorage")
local fx = game.StarterPlayer.StarterPlayerScripts:FindFirstChild("ExfilFX")
if not fx then return "ERROR StarterPlayerScripts.ExfilFX missing" end
local BAK = "ExfilFX_Orig"
local MARK = "-- [EXFIL] lift path for the UH-60 kit (Edward 2026-10-16)"
local ENDMARK = "\t-- [/EXFIL]\n"

-- single-line edits: the new line ends with its own tag so it can be found and reverted after re-tuning
local LINES = {
	{tag = "-- [EXFIL#1]",
	 old = "local lifting, liftT = false, CFrame.identity\n",
	 new = "local lifting, liftT, spool = false, CFrame.identity, 0 -- spool 0..1 ramps the rotors up during the lift -- [EXFIL#1]\n"},
	{tag = "-- [EXFIL#2]",
	 old = "\tspinA += dt * (lifting and 22 or 9); spinB += dt * (lifting and 40 or 18)\n",
	 new = "\tspinA += dt * (9 + 13 * spool); spinB += dt * (18 + 22 * spool) -- [EXFIL#2]\n"},
}

local OLD_BLOCK = [[
	RS:BindToRenderStep("ExfilLift", Enum.RenderPriority.Camera.Value + 1, function()
		local e = os.clock() - start
		local off = CFrame.new(e * e * 3.2, math.min(e, 4) ^ 1.5 * 2.2, 0) * CFrame.Angles(0, 0, -math.min(e * 0.06, 0.18))
		liftT = CFrame.new(pivot.Position) * off * CFrame.new(-pivot.Position)
		hrp.CFrame = liftT * pivot * rel
		cam.CFrame = CFrame.lookAt(Vector3.new(120, 9 + e * 1.5, -18 - e * 2), (liftT * pivot).Position)
	end)
	task.wait(2.6); fade(0, 0.6, "EXFIL  //  TRAINING ROOM")
	RS:UnbindFromRenderStep("ExfilLift"); lifting = false; liftT = CFrame.identity
]]

local NEW_BLOCK = "\t" .. MARK .. [==[: spool on the pad, hover-taxi right out from under
	-- the hangar mouth, vertical climb clear of the edge gear, nose-down departure yawing + banking right over the open sky edge.
	-- liftPose(e) = offset about the CabinPoint position (world axes); fix/check_heli.lua loads the POSE block and sweeps it.
	--[[POSE]]
	local LIFT_T = 2.9 -- s of lift before the fade (the heli keeps flying through the 0.6 s fade)
	local function S(a, b, e) local t = math.clamp((e - a) / (b - a), 0, 1); return t * t * (3 - 2 * t) end
	local function liftPose(e)
		local t = math.max(e - 1.75, 0)
		local d = 6.5 * t * t + 2 * t -- departure distance along the heading
		local yaw = math.rad(6) * S(0.5, 1.4, e) + math.rad(62) * S(1.75, 3.2, e) -- nose (-Z) swings right toward +X, tail away from the NE lamp
		local pos = Vector3.new(11.7 * S(0.35, 1.4, e), 0.5 * S(0, 0.5, e) + 2.6 * S(0.3, 1.1, e) + 10 * S(1.15, 2.05, e) + 3 * t, -2 * S(0.35, 1.4, e))
			+ Vector3.new(math.sin(yaw), 0, -math.cos(yaw)) * d
		local pitch = math.rad(2.5) * (S(0, 0.5, e) - S(0.9, 1.4, e)) + math.rad(13) * S(1.75, 2.6, e) -- nose down
		local roll = math.rad(2) * (S(0.35, 0.7, e) - S(0.9, 1.4, e)) + math.rad(16) * S(1.8, 2.7, e) -- starboard down
		return CFrame.new(pos) * CFrame.Angles(0, -yaw, 0) * CFrame.Angles(-pitch, 0, 0) * CFrame.Angles(0, 0, -roll)
	end
	local function liftCam(e) -- dolly from the start shot out through the hangar mouth to the pad's SW corner, clear of the roof edge
		return Vector3.new(120, 9, -18):Lerp(Vector3.new(130, 7, -21.5), S(0.2, 2.2, e)) + Vector3.new(0, 1.5 * S(2, 3.5, e), 0)
	end
	--[[/POSE]]
	RS:BindToRenderStep("ExfilLift", Enum.RenderPriority.Camera.Value + 1, function()
		local e = os.clock() - start
		spool = S(0, 0.8, e)
		liftT = CFrame.new(pivot.Position) * liftPose(e) * CFrame.new(-pivot.Position)
		hrp.CFrame = liftT * pivot * rel
		cam.CFrame = CFrame.lookAt(liftCam(e), (liftT * pivot).Position)
	end)
	task.wait(LIFT_T); fade(0, 0.6, "EXFIL  //  TRAINING ROOM")
	RS:UnbindFromRenderStep("ExfilLift"); lifting = false; liftT = CFrame.identity; spool = 0
]==] .. ENDMARK

local log = {}
local function say(s) table.insert(log, s) end

-- revert every marked edit in place (works whatever POSE numbers an earlier run applied)
local function revert(src)
	local n = 0
	local a = src:find("\t" .. MARK, 1, true)
	if a then
		local _, b = src:find(ENDMARK, a, true)
		if not b then return nil, "block start marker without end marker" end
		src = src:sub(1, a - 1) .. OLD_BLOCK .. src:sub(b + 1); n += 1
	end
	for _, L in LINES do
		local t = src:find(L.tag, 1, true)
		if t then
			local ls = t; while ls > 1 and src:sub(ls - 1, ls - 1) ~= "\n" do ls -= 1 end
			local le = src:find("\n", t, true) or #src
			src = src:sub(1, ls - 1) .. L.old .. src:sub(le + 1); n += 1
		end
	end
	return src, n
end

local store = SS:FindFirstChild("_RebuildRemoved")
local src, n = revert(fx.Source)
if not src then return "ERROR " .. n .. ": nothing changed" end

if UNDO then
	if n > 0 then fx.Source = src; say(("ExfilFX: %d marked edits reverted in place"):format(n)) else say("ExfilFX not patched") end
	local bak = store and store:FindFirstChild(BAK)
	if bak then
		if bak.Source == fx.Source then bak:Destroy(); say("ExfilFX equals the backup; backup removed")
		else say("WARNING ExfilFX differs from the backup (other edits since?); backup kept in _RebuildRemoved." .. BAK) end
	end
	return "UNDO exfil_lift:\n" .. table.concat(log, "\n")
end

-- apply on the original text
local a, b = src:find(OLD_BLOCK, 1, true)
if not a then return "ERROR lift block anchor not found in ExfilFX: nothing changed" end
for _, L in LINES do if not src:find(L.old, 1, true) then return "ERROR line anchor not found: " .. L.old end end
if not store then store = Instance.new("Folder"); store.Name = "_RebuildRemoved"; store.Parent = SS end
if not store:FindFirstChild(BAK) then
	local bak = fx:Clone(); bak.Name = BAK; bak.Disabled = true; bak.Source = src; bak.Parent = store
	say("backup ServerStorage._RebuildRemoved." .. BAK)
end
local new = src:sub(1, a - 1) .. NEW_BLOCK .. src:sub(b + 1)
for _, L in LINES do local s, e = new:find(L.old, 1, true); new = new:sub(1, s - 1) .. L.new .. new:sub(e + 1) end
local f, err = loadstring(new)
if not f then return "ERROR patched source does not compile: " .. tostring(err) .. " (nothing changed)" end
fx.Source = new
say(("ExfilFX patched (%s; %d earlier edits reverted first): spool local, rotor spin ramp, lift POSE block + LIFT_T fade wait"):format(
	n > 0 and "re-applied" or "first apply", n))
return "exfil_lift:\n" .. table.concat(log, "\n")
