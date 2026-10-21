-- fix/throw_instant.lua [THROWNOW] 2026-10-21, Edward: "i'm done with the charging the grenade idea no reason these objects should
-- not be thrown at full strength as quick as possible", and the frag's fuse is 2 s. GadgetConfig only (both places), no client change:
--   * TapTime 0     -> a press is never a ground roll
--   * ChargeTime    -> 0.01 s (and the tutorial's 0.45 -> 0.01): full power within the first frame
--   * MaxHoldTime   -> 0.02 s: GadgetController's Heartbeat lets it go by itself, so holding G doesn't delay the throw
--   Min/MaxThrowSpeed are kept as a range because the tutorial's marker throws solve power along it.
--   * Frag FuseTime 1.7 -> 2
-- Idempotent; UNDO swaps back.
local UNDO = false --@UNDO
local GC = game:GetService("ReplicatedStorage").Modules.Shared.Config.GadgetConfig
local edits = {
	{ "-- default \"Smoke\"). Hold G (or left click with the gadget slot selected): the throw charges the longer you\n-- hold (full power after 1s); hold it to MaxHoldTime (1.5s) and it throws by itself. Release earlier for a\n-- shorter throw. Tap: roll it along the ground. The client preview and the server\n",
	  "-- default \"Smoke\"). Press G (or left click with the gadget slot selected): [THROWNOW] it leaves your hand at full strength\n-- straight away (no charging, no ground roll; Edward 2026-10-21). The client preview and the server\n" },
	{ "\tTapTime = 0.2,         -- released quicker than this = roll instead of throw\n\tChargeTime = 0.8,      -- seconds of holding past TapTime to reach full power (full at 1.0s)\n\tMaxHoldTime = 1.5,     -- the longest you can hold a throw: it leaves your hand by itself (at full power) after this\n",
	  "\tTapTime = 0,           -- [THROWNOW] no tap roll (was 0.2)\n\tChargeTime = 0.01,     -- [THROWNOW] full power at once (was 0.8)\n\tMaxHoldTime = 0.02,    -- [THROWNOW] it leaves your hand by itself straight away, held or not (was 1.5)\n" },
	{ "\t\tChargeTime = 0.45,\n\t\tFullChargeOnly = true,\n",
	  "\t\tChargeTime = 0.01,     -- [THROWNOW] was 0.45\n\t\tFullChargeOnly = true,\n" },
	{ "\t\tBounciness = 0.15,\n\t\tFuseTime = 1.7,\n",
	  "\t\tBounciness = 0.15,\n\t\tFuseTime = 2,          -- [THROWNOW] Edward: 2 s from the throw (was 1.7)\n" },
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
