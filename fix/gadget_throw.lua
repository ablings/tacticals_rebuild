-- fix/gadget_throw.lua [GADGETTHROW] 2026-10-20, Edward: "the toss we have for throwing is very weak. all gadgets besides medkit
-- should be throwable". GadgetConfig (both places):
--   * the shared throw (THROW, every gadget's default) is much stronger: speed 20..58 -> 36..105 studs/s along the aim, lift
--     8..20 -> 10..22 (roughly twice the reach at full charge); any gadget can still override its own Min/MaxThrowSpeed
--   * the Landmine is thrown like a grenade (withThrow, no Use = "Place"): it lands, lies flat where it stops and arms there
--     (ServerScriptService.Shared.Abilities throwMine). The Medkit stays a use (Use = "Channel").
-- The client (GadgetController: per-gadget speeds + the hold / charge / throw path for the Landmine) is the UI session's half.
-- Idempotent; UNDO swaps back.
local UNDO = false --@UNDO
local GC = game:GetService("ReplicatedStorage").Modules.Shared.Config.GadgetConfig
local edits = {
	{ "\tMinThrowSpeed = 20,    -- studs/s along the aim direction at the start of the charge\n\tMaxThrowSpeed = 58,    -- ...at full charge\n\tMinLift = 8,           -- extra upward speed (arc height) at the start of the charge\n\tMaxLift = 20,          -- ...at full charge\n",
	  "\tMinThrowSpeed = 36,    -- studs/s along the aim direction at the start of the charge ([GADGETTHROW] was 20)\n\tMaxThrowSpeed = 105,   -- ...at full charge (was 58: Edward, \"the toss is very weak\")\n\tMinLift = 10,          -- extra upward speed (arc height) at the start of the charge (was 8)\n\tMaxLift = 22,          -- ...at full charge (was 20)\n" },
	{ "-- Landmine: put down just ahead of you; arms after ArmTime s; an enemy within TriggerRadius sets it off (TriggerDelay)\nGadgetConfig.Landmine = {\n\tDisplayName = \"LANDMINE\",\n\tChargesAttribute = \"MineCharges\",\n\tChargesPerRound = 1,\n\tUse = \"Place\",\n\tArmTime = 1.2,\n\tTriggerRadius = 4,\n\tTriggerDelay = 0.3,\n\tCooldown = 1,\n}\n",
	  "-- Landmine: [GADGETTHROW] thrown like a grenade; it lands, lies flat where it stops and arms after ArmTime s; an enemy within\n-- TriggerRadius sets it off (TriggerDelay)\nGadgetConfig.Landmine = withThrow({\n\tDisplayName = \"LANDMINE\",\n\tChargesAttribute = \"MineCharges\",\n\tChargesPerRound = 1,\n\tBounciness = 0.05,\n\tArmTime = 1.2,\n\tTriggerRadius = 4,\n\tTriggerDelay = 0.3,\n})\n" },
}
local s = GC.Source
local out = {}
for i, e in edits do
	local old, new = e[1], e[2]
	local done
	if UNDO then old, new = new, old; done = not s:find(old, 1, true) else done = s:find(new, 1, true) ~= nil end
	if done then table.insert(out, i .. "=") else
		local a, b = s:find(old, 1, true)
		assert(a, "edit " .. i .. " anchor not found")
		s = s:sub(1, a - 1) .. new .. s:sub(b + 1)
		table.insert(out, i .. "+")
	end
end
local f, err = loadstring(s)
assert(f, "GadgetConfig would not parse: " .. tostring(err))
if GC.Source ~= s then GC.Source = s end
return "GadgetConfig " .. table.concat(out, " ")
