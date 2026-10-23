-- fix/revolver_two_hits.lua [REVOLVER2] 2026-10-23 (both places). Edward: the Revolver's ability "drops you into a cover spot you
-- don't want"; it should only activate after TWO CONSECUTIVE Revolver hits. ServerScriptService.Shared.Abilities: the Knockback
-- (ForceCover on the victim) now needs the 2nd hit in a row on the same target, no aim needed; a miss or a hit on someone else resets.
-- CombatManager reports every accepted shot (Abilities.ShotFired) so misses count. Same edits as scripts/abilities/Abilities.lua.
-- The cursor ring is the UI session's (ui/set/HUD.lua, RevolverReady). Idempotent; UNDO swaps back.
local UNDO = false --@UNDO
local SSS = game:GetService("ServerScriptService")
local AB = SSS:FindFirstChild("Abilities", true)
local CM = SSS:FindFirstChild("CombatManager", true)
assert(AB and AB:IsA("ModuleScript") and CM, "Abilities / CombatManager missing")
local edits = {
	{ AB, [==[--   guns   Revolver Knockback Shot   a fully aimed-in hit sends the target dashing into the nearest cover (aim cancelled)
]==], [==[--   guns   Revolver Knockback Shot   2 Revolver hits in a row on one target send it dashing into the nearest cover [REVOLVER2]
]==] },
	{ AB, [==[local knockAt = setmetatable({}, { __mode = "k" })
]==], [==[local knockAt = setmetatable({}, { __mode = "k" })
-- [REVOLVER2] 2026-10-23: Revolver shots fired per shooter (CombatManager calls A.ShotFired for every accepted shot) and each
-- shooter's last Revolver hit { victim, shot }: the Knockback needs two hits in a row on the same target
local revShots = setmetatable({}, { __mode = "k" })
local revLast = setmetatable({}, { __mode = "k" })
function A.ShotFired(shooter: Player, config)
	if config and config.Knockback then revShots[shooter] = (revShots[shooter] or 0) + 1 end
end
]==] },
	{ AB, [==[	-- Revolver Knockback Shot: a fully aimed-in hit sends the target dashing into the nearest cover
	local aimed = type(extra) == "table" and extra.aimed == true
	local raised = shooter.Character and shooter.Character:GetAttribute("AimRaised")
	if config.Knockback and aimed and raised ~= false and now - (knockAt[victim] or 0) > 0.3 then
		knockAt[victim] = now
		push(victim, "ForceCover", { from = origin, lockout = config.Knockback.Lockout })
	end
]==], [==[	-- Revolver Knockback Shot [REVOLVER2] (Edward 2026-10-23: it kept dropping people into cover they didn't want): the SECOND
	-- CONSECUTIVE Revolver hit on the same target sends it dashing into the nearest cover; no aim needed. A miss in between (every
	-- shot counts through A.ShotFired) or a hit on someone else starts the count again. Was: any fully aimed-in hit.
	if config.Knockback then
		local shot = revShots[shooter] or 0
		local last = revLast[shooter]
		if last and last.victim == victim and last.shot == shot - 1 and now - (knockAt[victim] or 0) > 0.3 then
			knockAt[victim] = now
			revLast[shooter] = nil
			push(victim, "ForceCover", { from = origin, lockout = config.Knockback.Lockout })
		else
			revLast[shooter] = { victim = victim, shot = shot }
		end
	end
]==] },
	{ CM, [==[		player:SetAttribute("KitLocked", true) -- [ROUNDFLOW] the first shot locks this round's kit
]==], [==[		player:SetAttribute("KitLocked", true) -- [ROUNDFLOW] the first shot locks this round's kit
		Abilities.ShotFired(player, config) -- [REVOLVER2] every shot counts toward the Revolver's two-hits-in-a-row
]==] },
}
local sources, out = {}, {}
for i, e in edits do
	local inst, old, new = e[1], e[2], e[3]
	local s = sources[inst] or inst.Source:gsub("\r\n", "\n")
	if UNDO then old, new = new, old end
	local done
	if UNDO then done = not s:find(old, 1, true) else done = s:find(new, 1, true) ~= nil end
	if done then
		table.insert(out, i .. "=")
	else
		local a, b = s:find(old, 1, true)
		assert(a, inst.Name .. " edit " .. i .. " anchor not found")
		assert(not s:find(old, b + 1, true), inst.Name .. " edit " .. i .. " anchor not unique")
		s = s:sub(1, a - 1) .. new .. s:sub(b + 1)
		table.insert(out, i .. "+")
	end
	sources[inst] = s
end
for inst, s in sources do
	local f, err = loadstring(s)
	assert(f, inst.Name .. " would not parse: " .. tostring(err))
	if inst.Source ~= s then inst.Source = s end
end
return "REVOLVER2 " .. table.concat(out, " ")
