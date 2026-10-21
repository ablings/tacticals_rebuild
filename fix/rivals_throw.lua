-- fix/rivals_throw.lua [RTHROW] 2026-10-21, Edward (via the main PC): "I want RIVALS feel for throwing and the math it uses to throw the
-- grenade ... all throwables should be like this, but remember my game should still have tapping rolling the gadget on the ground and
-- holding down to throw fully".
-- RIVALS' math (read-only from the reference place: ItemLibrary add_throwable + ItemTypes.Throwable, the same for every throwable):
--   launch = (crosshair hit point - throw origin).Unit * ThrowForce, ThrowForce 100 studs/s (min = max: holding longer adds nothing),
--   no extra lift; gravity on the flight = workspace.Gravity * 0.5 * ThrowGravity, ThrowGravity 0.375 -> a fast, fairly flat arc.
--   (Its "lob" on the other button: 50 studs/s, ThrowGravity 0.75 - not ported; our tap rolls instead.)
-- Ours:
--  * GadgetConfig THROW: TapTime 0.15 (a tap ROLLS again; was 0 under THROWNOW), Min/MaxThrowSpeed 100, Min/MaxLift 0, ThrowGravity 0.375,
--    ArcPreview "Always" (the dashed arc while held). Every gadget built withThrow gets them (Smoke, Frag, Flash, Sticky, Landmine).
--  * GadgetManager: a thrown (not rolled) gadget flies under the reduced gravity (a VectorForce holding up the rest) until it first
--    touches anything that isn't the thrower; then normal gravity, so it settles. shared.TacThrowGravity(part, cfg, thrower) for Abilities.
--  * Abilities: sticky / thrown landmine get the same flight.
-- Client: ui/set/GadgetController.lua [RTHROW] aims from the head at what the crosshair hits and draws the arc with the same gravity.
-- Both places. Idempotent; UNDO = true swaps back.
local UNDO = false --@UNDO
local RS, SSS = game:GetService("ReplicatedStorage"), game:GetService("ServerScriptService")

local function patch(inst, edits)
	if not inst then return "missing" end
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

local res = {}
table.insert(res, patch(RS.Modules.Shared.Config.GadgetConfig, {
	{ "\tTapTime = 0,           -- [THROWNOW] no tap roll (was 0.2)\n",
	  "\tTapTime = 0.15,        -- [RTHROW] a tap rolls it along the ground again (THROWNOW had 0; was 0.2)\n" },
	{ "\tMinThrowSpeed = 36,    -- studs/s along the aim direction at the start of the charge ([GADGETTHROW] was 20)\n"
	  .. "\tMaxThrowSpeed = 105,   -- ...at full charge (was 58: Edward, \"the toss is very weak\")\n"
	  .. "\tMinLift = 10,          -- extra upward speed (arc height) at the start of the charge (was 8)\n"
	  .. "\tMaxLift = 22,          -- ...at full charge (was 20)\n",
	  "\t-- [RTHROW] RIVALS' throw: 100 studs/s straight at the crosshair, no lift, under ThrowGravity (was 36-105 + 10-22 lift, full gravity)\n"
	  .. "\tMinThrowSpeed = 100,\n\tMaxThrowSpeed = 100,\n\tMinLift = 0,\n\tMaxLift = 0,\n"
	  .. "\tThrowGravity = 0.375,  -- the flight falls at workspace.Gravity * 0.5 * this (RIVALS), until it first touches something\n" },
	{ "\tArcPreview = \"Tutorial\",\n", "\tArcPreview = \"Always\", -- [RTHROW] the arc while you hold (RIVALS); was \"Tutorial\"\n" },
}))

local GM = SSS:FindFirstChild("GadgetManager", true)
table.insert(res, patch(GM, {
	{ "local function throwGrenade(gadget: string, character: Model?, direction: Vector3, power: number, mode: string, side: number?",
	  "-- [RTHROW] RIVALS' flight: the part falls at workspace.Gravity * 0.5 * cfg.ThrowGravity until it first touches anything but the thrower\n"
	  .. "local function throwGravity(part: BasePart, cfg, thrower: Model?)\n"
	  .. "\tlocal k = cfg and cfg.ThrowGravity\n"
	  .. "\tif not k or not part.Parent then return end\n"
	  .. "\tlocal att = Instance.new(\"Attachment\")\n"
	  .. "\tatt.Parent = part\n"
	  .. "\tlocal vf = Instance.new(\"VectorForce\")\n"
	  .. "\tvf.Name = \"ThrowGravity\"\n"
	  .. "\tvf.Attachment0 = att\n"
	  .. "\tvf.RelativeTo = Enum.ActuatorRelativeTo.World\n"
	  .. "\tvf.ApplyAtCenterOfMass = true\n"
	  .. "\tvf.Force = Vector3.new(0, part.AssemblyMass * workspace.Gravity * (1 - 0.5 * k), 0)\n"
	  .. "\tvf.Parent = part\n"
	  .. "\tlocal conn\n"
	  .. "\tconn = part.Touched:Connect(function(hit)\n"
	  .. "\t\tif thrower and hit:IsDescendantOf(thrower) then return end\n"
	  .. "\t\tconn:Disconnect()\n"
	  .. "\t\tif vf.Parent then vf:Destroy() end\n"
	  .. "\tend)\n"
	  .. "\ttask.delay(8, function() if vf.Parent then vf:Destroy() end end)\n"
	  .. "end\n"
	  .. "shared.TacThrowGravity = throwGravity\n\n"
	  .. "local function throwGrenade(gadget: string, character: Model?, direction: Vector3, power: number, mode: string, side: number?" },
	{ "\t\tgrenade.AssemblyLinearVelocity = launchVelocity(cfg, direction, power)\n",
	  "\t\tgrenade.AssemblyLinearVelocity = launchVelocity(cfg, direction, power)\n\t\tthrowGravity(grenade, cfg, character) -- [RTHROW]\n" },
}))
local AB = SSS:FindFirstChild("Abilities", true)
table.insert(res, patch(AB, {
	{ "\tg.AssemblyLinearVelocity = launchVelocity(cfg, direction, power)\n",
	  "\tg.AssemblyLinearVelocity = launchVelocity(cfg, direction, power)\n"
	  .. "\tif shared.TacThrowGravity then shared.TacThrowGravity(g, cfg, player.Character) end -- [RTHROW]\n" },
	{ "\tmine.AssemblyLinearVelocity = mode == \"Roll\" and flat * (cfg.RollSpeed or 24) or launchVelocity(cfg, direction, power)\n",
	  "\tmine.AssemblyLinearVelocity = mode == \"Roll\" and flat * (cfg.RollSpeed or 24) or launchVelocity(cfg, direction, power)\n"
	  .. "\tif mode ~= \"Roll\" and shared.TacThrowGravity then shared.TacThrowGravity(mine, cfg, player.Character) end -- [RTHROW]\n" },
}))
return (UNDO and "UNDO " or "RTHROW ") .. table.concat(res, " | ")
