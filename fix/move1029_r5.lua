-- fix/move1029_r5.lua [MOVE1029R5] (live port 51, 2026-10-30): on top of fix/move_rework_1029.lua round 4.
-- 1) CombatManager: the server facing gate only FLAGS (player attribute FacingFlags, Studio print); no recheck wait, no refusal.
--    Port-51 systems grade: the client's turn reaches the server 0.17-0.43 s after the shot remote, so the refusal (after the
--    ammo was spent) ate honest peek shots; the wait also put the hit rewind outside its window. The client gate + FaceYaw stay.
-- 2) CombatManager: after the one-frame FaceYaw wait the shooter must still be alive.
-- 3) MovementManager: a refused pull-up puts the body back where the SERVER saw it (was: the client's claimed start = a teleport).
-- Every anchor is checked in every script before anything is written; round stamp CoverConfig MoveRework1029R5; re-run = "=";
-- UNDO reverts exactly these edits.
local UNDO = false --@UNDO
local ROUND = 1
local RS, SSS = game:GetService("ReplicatedStorage"), game:GetService("ServerScriptService")
local cc = RS:FindFirstChild("CoverConfig", true)
assert(cc and cc:GetAttribute("MoveRework1029Round") == 4, "MOVE1029R5: needs MOVE1029 round 4 installed")
local st = cc:GetAttribute("MoveRework1029R5")
assert(st == nil or st == ROUND, "MOVE1029R5: another round is installed: " .. tostring(st))
local function boundary(s, a, b)
	if s:sub(a, a):match("[%w_]") and s:sub(a - 1, a - 1):match("[%w_%.:]") then return false end
	if s:sub(b, b):match("[%w_]") and s:sub(b + 1, b + 1):match("[%w_]") then return false end
	return true
end
local EDITS = {
	{ "CombatManager", [========[
		local gateOk, gateWhy = HitRewind.FireGate(player, character, direction, nil, gateDist)
		if not gateOk and gateWhy ~= "still turning to the peek" then
			task.wait(HitRewind.FacingRecheck())
			if getEquippedWeapon(player) ~= tool then return finish("weapon gone during the facing recheck") end
			gateOk, gateWhy = HitRewind.FireGate(player, character, direction, HitRewind.FacingRecheck(), gateDist)
		end
		if not gateOk then return finish("peek gate: " .. tostring(gateWhy)) end
]========], [========[
		-- [MOVE1029R5] flag only (port 51 grade: the client's turn reaches the server 0.17-0.43 s after its shot remote, so a
		-- refusal ate honest peek shots, after their ammo was spent). The client still holds a shot until the body faces the aim,
		-- and FaceYaw turns the body on every screen before the damage; a shot far off the facing is counted, not refused.
		local gateOk, gateWhy = HitRewind.FireGate(player, character, direction, 0.5, gateDist)
		if not gateOk then
			player:SetAttribute("FacingFlags", (player:GetAttribute("FacingFlags") or 0) + 1)
			if RunService:IsStudio() then print(("[CombatManager] facing flag (shot allowed) for %s: %s"):format(player.Name, tostring(gateWhy))) end
		end
]========] },
	{ "CombatManager", [========[
			if getEquippedWeapon(player) ~= tool then return finish("weapon gone before the hit") end
]========], [========[
			if getEquippedWeapon(player) ~= tool then return finish("weapon gone before the hit") end
			local shooterHum = character:FindFirstChildOfClass("Humanoid") -- [MOVE1029R5] still alive after the frame
			if not shooterHum or shooterHum.Health <= 0 then return finish("shooter died before the hit") end
]========] },
	{ "MovementManager", [========[
		if not ok then refusePullUp(player, character, a, why or "?") elseif IS_STUDIO then
]========], [========[
		if not ok then refusePullUp(player, character, root.Position, why or "?") elseif IS_STUDIO then -- [MOVE1029R5] back to where the server saw it, never the claimed point
]========] },
}
local scripts, out = {}, {}
for _, e in EDITS do
	local s = scripts[e[1]]
	if not s then
		local inst = SSS:FindFirstChild(e[1], true)
		assert(inst and inst:IsA("ModuleScript"), "MOVE1029R5: no " .. e[1])
		s = { inst = inst, crlf = inst.Source:find("\r\n", 1, true) ~= nil, src = inst.Source:gsub("\r\n", "\n") }
		s.orig = s.src
		scripts[e[1]] = s
	end
	local from, to = e[2], e[3]
	if UNDO then from, to = e[3], e[2] end
	-- an edit whose new text holds its anchor counts as "already in" when the new text is there (else it re-applies every run)
	local a, b = nil, nil
	if not (to:find(from, 1, true) and s.src:find(to, 1, true)) then a, b = s.src:find(from, 1, true) end
	if a then
		assert(not s.src:find(from, b + 1, true), "MOVE1029R5: anchor twice in " .. e[1])
		assert(boundary(s.src, a, b), "MOVE1029R5: anchor inside a token in " .. e[1])
		s.src = s.src:sub(1, a - 1) .. to .. s.src:sub(b + 1)
		table.insert(out, e[1] .. (UNDO and " -" or " +"))
	elseif s.src:find(to, 1, true) then
		table.insert(out, e[1] .. " =")
	else
		error("MOVE1029R5: anchor not found in " .. e[1] .. " (nothing written)")
	end
end
for _, s in scripts do
	if s.src ~= s.orig then s.inst.Source = s.crlf and s.src:gsub("\n", "\r\n") or s.src end
end
cc:SetAttribute("MoveRework1029R5", if UNDO then nil else ROUND)
return "MOVE1029R5 " .. (UNDO and "UNDO" or "round " .. ROUND) .. ": " .. table.concat(out, " ")
