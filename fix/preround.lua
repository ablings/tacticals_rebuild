-- fix/preround.lua [PREROUND] 2026-10-21, Edward in the Shadow PC lead chat:
--  "you can switch weapons until the round starts ... its a 5 second preround but it doesn't matter if you flip through your
--   weapons you also shouldn't be able to aim in on any of these weapons or even do any melees until the round starts"
--  "you still can't shoot after killing someone or use utility you should be able to but it should be removed from the map on
--   round refresh"
--  1. MatchConfig.CountdownTime 3 -> 5 (everyone frozen at spawn, the Switch Weapons picker free to flip through).
--  2. The kit locks the moment the round goes Live (replaces [ROUNDFLOW]'s "swap until you move 2 studs / fire"): picks during the
--     countdown apply at once, picks during Live queue for the next round ([LIVEPICK]).
--  3. Gadgets can be thrown during RoundEnd too (guns already can, [ROUNDFLOW]). Gadget damage still checks the combat state
--     (Abilities), so nothing thrown after the kill hurts anyone; GadgetManager.ClearAll at the round reset removes it all.
--  No aiming / melee before Live: client gates in ui/set (CameraController.IsAiming, HotbarController); the server already refuses
--  melee and gadgets while CombatEnabled is false.
-- Both places (lobby duels share MatchCore / MatchConfig). Idempotent; UNDO = true swaps back.
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
table.insert(res, patch(RS.Modules.Shared.Config.MatchConfig, {
	{ "\tCountdownTime = 3,      -- frozen at spawn before each round\n",
	  "\tCountdownTime = 5,      -- frozen at spawn before each round ([PREROUND] was 3: Edward's 5 s pre-round)\n" },
}))
table.insert(res, patch(SSS:FindFirstChild("MatchCore", true), {
	{ "\telseif state == \"Live\" then\n\t\tlocal starts = {}\n",
	  "\telseif state == \"Live\" then\n"
	  .. "\t\t-- [PREROUND] switching is free until the round starts, then the kit is locked for the round (picks queue)\n"
	  .. "\t\tfor _, list in ctx.teams do for _, m in list do if m.player then m.player:SetAttribute(\"KitLocked\", true) end end end\n"
	  .. "\t\tlocal starts = {}\n" },
}))
-- the throw gate: the match place checks ReplicatedStorage, the lobby ([DUEL]) checks the player's duel state
local gmInst = SSS:FindFirstChild("GadgetManager", true)
local duelGate = gmInst and gmInst.Source:find("\tif MatchState.Get(player, \"CombatEnabled\") == false", 1, true) ~= nil
local GATE = duelGate and {
	"\t-- [DUEL] the player's match state (lobby duels), else ReplicatedStorage as before\n\tif MatchState.Get(player, \"CombatEnabled\") == false then return end\n",
	"\t-- [DUEL] the player's match state (lobby duels), else ReplicatedStorage as before\n"
	.. "\t-- [PREROUND] utility may be thrown during RoundEnd too (it does no damage then; cleared at the round reset)\n"
	.. "\tif MatchState.Get(player, \"CombatEnabled\") == false and MatchState.Get(player, \"MatchState\") ~= \"RoundEnd\" then return end\n",
} or {
	"\tpower = (type(power) == \"number\" and power == power) and math.clamp(power, 0, 1) or 1\n\tif ReplicatedStorage:GetAttribute(\"CombatEnabled\") == false then return end\n",
	"\tpower = (type(power) == \"number\" and power == power) and math.clamp(power, 0, 1) or 1\n"
	.. "\t-- [PREROUND] utility may be thrown during RoundEnd too (it does no damage then; cleared at the round reset)\n"
	.. "\tif ReplicatedStorage:GetAttribute(\"CombatEnabled\") == false and ReplicatedStorage:GetAttribute(\"MatchState\") ~= \"RoundEnd\" then return end\n",
}
table.insert(res, patch(gmInst, {
	GATE,
	-- the round reset: RoundManager's onRoundStart ClearAll didn't reach a smoke that popped late in RoundEnd (it stayed all round),
	-- so GadgetManager clears everything itself when each countdown starts
	{ "function manager.Start()\n\tif not Combat:FindFirstChild(\"FlashDetonated\") then\n",
	  "function manager.Start()\n"
	  .. "\t-- [PREROUND] everything thrown (also during RoundEnd) is gone when the next round's countdown starts\n"
	  .. "\tReplicatedStorage:GetAttributeChangedSignal(\"MatchState\"):Connect(function()\n"
	  .. "\t\tif ReplicatedStorage:GetAttribute(\"MatchState\") == \"Countdown\" then manager.ClearAll() end\n"
	  .. "\tend)\n"
	  .. "\tif not Combat:FindFirstChild(\"FlashDetonated\") then\n" },
	-- ClearAll left the smoke cells fading for 6 s (emitter off + Debris); on a round reset they go at once
	{ "\t\tif inst.Name == \"SmokeSource\" or inst.Name:match(\"Grenade$\") then inst:Destroy() end\n",
	  "\t\tif inst.Name == \"SmokeSource\" or inst.Name == \"SmokeCloud\" or inst.Name:match(\"Grenade$\") then inst:Destroy() end -- [PREROUND] +SmokeCloud: gone at once\n" },
	-- a smoke still flooding / holding kept adding cells after the clear: both loops stop once ClearAll took the canister away
	{ "\t\twhile #pending > 0 do\n", "\t\twhile #pending > 0 and source.Parent do -- [PREROUND] stops when the round reset removed the canister\n" },
	{ "\t\twhile os.clock() < holdUntil do\n", "\t\twhile os.clock() < holdUntil and source.Parent do -- [PREROUND] same\n" },
}))
-- 4. (Edward: "throwing gadgets auto releases way too fast you should be able to hold the gadget for 5 seconds atleast")
--    GadgetController lets a held throw go by itself at MaxHoldTime: 0.02 ([THROWNOW]) -> 5 s. Still full power on release.
table.insert(res, patch(RS.Modules.Shared.Config.GadgetConfig, {
	{ "\tMaxHoldTime = 0.02,", "\tMaxHoldTime = 5, --[[ [PREROUND] hold it up to 5 s (was 0.02) ]]" },
}))
return (UNDO and "UNDO " or "PREROUND ") .. table.concat(res, " | ")
