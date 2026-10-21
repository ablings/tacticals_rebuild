-- fix/round_flow.lua [ROUNDFLOW] 2026-10-20, Edward from playing the live build (via the UI session):
--  1. "you should be able to change your weapon until you shoot or move" (RIVALS): a Switch Weapons pick swaps the item at once
--     from the countdown until the player first moves (> 2 studs from where the round went live) or fires; after that it queues
--     for the next round as before ([LIVEPICK]). MatchCore keeps player attribute KitLocked (cleared at each Countdown, set on
--     the first move during Live); CombatManager sets it on an accepted shot.
--  2. "make it so you can shoot even when the round ends": guns may fire during RoundEnd. The shot plays for everyone (effects,
--     smoke holes, shootables) but deals no damage and scores nothing. CombatEnabled itself stays false in RoundEnd, so melee,
--     gadgets and abilities stay off. The client gate: ui/set/WeaponController (same tag).
-- Both places. Idempotent; UNDO swaps back.
local UNDO = false --@UNDO
local SSS = game:GetService("ServerScriptService")

local function patch(name, edits)
	local inst = SSS:FindFirstChild(name, true)
	if not inst then return name .. " missing" end
	local s = inst.Source
	local out = {}
	for i, e in edits do
		local old, new = e[1], e[2]
		local done
		if UNDO then old, new = new, old; done = not s:find(old, 1, true) else done = s:find(new, 1, true) ~= nil end
		if done then table.insert(out, i .. "=") else
			local a, b = s:find(old, 1, true)
			if not a and e[3] then table.insert(out, i .. "-") else
				assert(a, name .. " edit " .. i .. " anchor not found")
				assert(not s:find(old, b + 1, true), name .. " edit " .. i .. " anchor not unique")
				s = s:sub(1, a - 1) .. new .. s:sub(b + 1)
				table.insert(out, i .. "+")
			end
		end
	end
	local f, err = loadstring(s)
	assert(f, name .. " would not parse: " .. tostring(err))
	if inst.Source ~= s then inst.Source = s end
	return name .. " " .. table.concat(out, " ")
end

local res = {}
-- // MatchCore: KitLocked bookkeeping on the state changes
table.insert(res, patch("MatchCore", {
	{ "\ts:SetAttribute(\"CombatEnabled\", state == \"Live\")\nend\n",
	  "\ts:SetAttribute(\"CombatEnabled\", state == \"Live\")\n"
	  .. "\t-- [ROUNDFLOW] Switch Weapons swaps at once until a player moves or fires: unlocked at each countdown, locked by the first\n"
	  .. "\t-- move during Live (here) or the first accepted shot (CombatManager)\n"
	  .. "\tif state == \"Countdown\" then\n"
	  .. "\t\tfor _, list in ctx.teams do for _, m in list do if m.player then m.player:SetAttribute(\"KitLocked\", nil) end end end\n"
	  .. "\telseif state == \"Live\" then\n"
	  .. "\t\tlocal starts = {}\n"
	  .. "\t\tfor _, list in ctx.teams do\n"
	  .. "\t\t\tfor _, m in list do\n"
	  .. "\t\t\t\tlocal c = m.player and m.player.Character\n"
	  .. "\t\t\t\tlocal r = c and c:FindFirstChild(\"HumanoidRootPart\")\n"
	  .. "\t\t\t\tif r then starts[m] = r.Position end\n"
	  .. "\t\t\tend\n"
	  .. "\t\tend\n"
	  .. "\t\ttask.spawn(function()\n"
	  .. "\t\t\twhile s:GetAttribute(\"MatchState\") == \"Live\" and next(starts) do\n"
	  .. "\t\t\t\tfor m, at in starts do\n"
	  .. "\t\t\t\t\tlocal c = m.player and m.player.Character\n"
	  .. "\t\t\t\t\tlocal r = c and c:FindFirstChild(\"HumanoidRootPart\")\n"
	  .. "\t\t\t\t\tif not r or m.player:GetAttribute(\"KitLocked\") then starts[m] = nil\n"
	  .. "\t\t\t\t\telseif ((r.Position - at) * Vector3.new(1, 0, 1)).Magnitude > 2 then\n"
	  .. "\t\t\t\t\t\tm.player:SetAttribute(\"KitLocked\", true)\n"
	  .. "\t\t\t\t\t\tstarts[m] = nil\n"
	  .. "\t\t\t\t\tend\n"
	  .. "\t\t\t\tend\n"
	  .. "\t\t\t\ttask.wait(0.1)\n"
	  .. "\t\t\tend\n"
	  .. "\t\tend)\n"
	  .. "\tend\n"
	  .. "end\n" },
}))

-- // CombatManager: RoundEnd shots (effects only) + the shot lock
local ROUNDEND_MATCH = "\tif ReplicatedStorage:GetAttribute(\"CombatEnabled\") == false then return finish(\"combat disabled (countdown / round over)\") end\n"
local ROUNDEND_LOBBY = "\tif MatchState.Get(player, \"CombatEnabled\") == false then return finish(\"combat disabled (countdown / round over)\") end\n"
table.insert(res, patch("CombatManager", {
	{ ROUNDEND_MATCH,
	  "\t-- [ROUNDFLOW] RoundEnd: guns still fire (effects for everyone) but nothing they hit counts\n"
	  .. "\tlocal roundOver = ReplicatedStorage:GetAttribute(\"MatchState\") == \"RoundEnd\"\n"
	  .. "\tif ReplicatedStorage:GetAttribute(\"CombatEnabled\") == false and not roundOver then return finish(\"combat disabled (countdown / round over)\") end\n", true },
	{ ROUNDEND_LOBBY,
	  "\t-- [ROUNDFLOW] RoundEnd: guns still fire (effects for everyone) but nothing they hit counts\n"
	  .. "\tlocal roundOver = MatchState.Get(player, \"MatchState\") == \"RoundEnd\"\n"
	  .. "\tif MatchState.Get(player, \"CombatEnabled\") == false and not roundOver then return finish(\"combat disabled (countdown / round over)\") end\n", true },
	{ "\t\tstate.lastFire = now\n",
	  "\t\tstate.lastFire = now\n\t\tplayer:SetAttribute(\"KitLocked\", true) -- [ROUNDFLOW] the first shot locks this round's kit\n" },
	{ "\t-- Valid hit: the server picks the damage\n",
	  "\tif roundOver then return finish(\"round over: the shot plays, the hit doesn't count\") end -- [ROUNDFLOW]\n\t-- Valid hit: the server picks the damage\n" },
}))

-- // Pick handlers: swap at once while unlocked (Countdown, or Live before the first move / shot); queue once locked
local LIVE_OLD = "\t\tif phase == \"Live\" then -- [LIVEPICK] applied when the round ends (no mid-fight melee re-give / gadget refill)\n"
local LIVE_NEW = "\t\tif phase == \"Live\" and player:GetAttribute(\"KitLocked\") then -- [LIVEPICK] applied when the round ends (no mid-fight melee re-give / gadget refill) ([ROUNDFLOW] only once locked)\n"
local LIVE_OLD_L = "\t\tif phase == \"Live\" then -- [LIVEPICK] applied when this match's round ends\n"
local LIVE_NEW_L = "\t\tif phase == \"Live\" and player:GetAttribute(\"KitLocked\") then -- [LIVEPICK] applied when this match's round ends ([ROUNDFLOW] only once locked)\n"
local SWAP_OLD = "\t\tif phase == \"Countdown\" and character and character.Parent then\n"
local SWAP_NEW = "\t\tif (phase == \"Countdown\" or phase == \"Live\") and character and character.Parent then -- [ROUNDFLOW] Live: not locked yet\n"
table.insert(res, patch("RoundManager", { { LIVE_OLD, LIVE_NEW, true }, { SWAP_OLD, SWAP_NEW, true } }))
table.insert(res, patch("LobbyDuelManager", { { LIVE_OLD_L, LIVE_NEW_L, true }, { SWAP_OLD, SWAP_NEW, true } }))
return table.concat(res, " | ")
