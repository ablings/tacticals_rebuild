-- fix/kitguard_quiet.lua [KITGUARD] 2026-10-18 (UI session saw "[KitGuard] <name>'s Pistol left their kit while alive" on every
-- round reset). KitGuard logs a kit tool leaving the player while they're alive, to catch the "gun disappears" bug. False
-- alarms it now skips:
--   * a respawn: LoadCharacter removes the OLD body (AncestryChanged's child is that old character, no longer player.Character)
--     while the NEW body is alive;
--   * tools removed on purpose, flagged KitRemoved = true before Destroy: the after-match lobby strip (PseudoLobby) and the
--     Switch Weapons swap in Countdown (fix/switch_streak.lua).
-- Match places (KitGuard + RoundManager + PseudoLobby there). Run AFTER fix/switch_streak.lua (it patches the swap line that
-- file inserts; switch_streak.lua itself stays unchanged so its own idempotency check keeps working). Idempotent; UNDO swaps back.
local UNDO = false --@UNDO
local SSS = game:GetService("ServerScriptService")
local log = {}

local KG = {
	{ "\ttool.AncestryChanged:Connect(function(_, parent)\n\t\tlocal character = player.Character\n",
		"\ttool.AncestryChanged:Connect(function(child, parent)\n\t\tlocal character = player.Character\n"
			.. "\t\t-- [KITGUARD] not a loss: a respawn removing the old body, or a tool removed on purpose (KitRemoved)\n"
			.. "\t\tif child ~= tool and child:IsA(\"Model\") and child ~= character then return end\n"
			.. "\t\tif tool:GetAttribute(\"KitRemoved\") then return end\n" },
}
local RM = {
	{ "\t\t\t\t\tfor _, t in (c and c:GetChildren() or {}) do if t:IsA(\"Tool\") and t:GetAttribute(\"WeaponId\") then t:Destroy() end end\n",
		"\t\t\t\t\tfor _, t in (c and c:GetChildren() or {}) do if t:IsA(\"Tool\") and t:GetAttribute(\"WeaponId\") then t:SetAttribute(\"KitRemoved\", true); t:Destroy() end end\n" },
}
local PL = {
	{ "\t\t\tif t:IsA(\"Tool\") then t:Destroy() end\n",
		"\t\t\tif t:IsA(\"Tool\") then t:SetAttribute(\"KitRemoved\", true); t:Destroy() end -- [KITGUARD] on purpose\n" },
}

local function swap(target, edits, label)
	local s = target.Source
	if UNDO then
		for i = #edits, 1, -1 do
			local a, b = s:find(edits[i][2], 1, true)
			if a then s = s:sub(1, a - 1) .. edits[i][1] .. s:sub(b + 1); table.insert(log, label .. " undo " .. i) end
		end
		target.Source = s
		return
	end
	for i, e in ipairs(edits) do
		assert(s:find(e[2], 1, true) or s:find(e[1], 1, true), label .. " edit " .. i .. ": original text not found")
	end
	for i, e in ipairs(edits) do
		if s:find(e[2], 1, true) then table.insert(log, label .. " " .. i .. " already in")
		else local a, b = s:find(e[1], 1, true); s = s:sub(1, a - 1) .. e[2] .. s:sub(b + 1); table.insert(log, label .. " " .. i .. " applied") end
	end
	assert(loadstring(s), label .. " would not parse")
	target.Source = s
end

swap(SSS.KitGuard, KG, "KitGuard")
swap(SSS.ServerScripts["[Server] Init"].GameManager.Managers.RoundManager, RM, "RoundManager")
swap(SSS.Shared.PseudoLobby, PL, "PseudoLobby")
return table.concat(log, ", ")
