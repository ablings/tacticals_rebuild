-- fix/switch_streak.lua [SWITCH] [STREAK] 2026-10-18 (UI session, from watching live RIVALS round ends). Both places.
-- 1) Switch Weapons between rounds: MatchFlow "Pick" (slot, itemId) is also accepted during RoundEnd and Countdown
--    (match place RoundManager + hub duels LobbyDuelManager), ownership-checked like the Loadout phase. A pick in RoundEnd is
--    handed out by the next round's spawn (CombatManager gives Loadout = KitWeapon on CharacterAdded); a pick in Countdown
--    (bodies already spawned, frozen) swaps the tool at once. Gadget: GadgetManager refills on the KitGadget change.
-- 2) WinStreak: consecutive match wins, persisted (Data.WinStreak), +1 on a win, 0 on a loss, a draw keeps it; casual + ranked
--    + hub duels; bot test / admin-ended matches don't count. Player attribute WinStreak (PublicStats copies it every 2 s in
--    both places, and the award sets it at once).
-- Idempotent; UNDO swaps back.
local UNDO = false --@UNDO
local SSS = game:GetService("ServerScriptService")
local M = SSS.ServerScripts["[Server] Init"].GameManager.Managers
local isLobby = workspace:FindFirstChild("LobbyMap") ~= nil and not game.ServerStorage:FindFirstChild("PseudoLobby")
local log = {}

local PICK_EDITS = {
	{ "\telseif kind == \"Pick\" and phase == \"Loadout\" then\n",
		"\telseif kind == \"Pick\" and (phase == \"Loadout\" or phase == \"RoundEnd\" or phase == \"Countdown\") then -- [SWITCH] also between rounds\n" },
	{ "\t\tkit[a] = b\n\t\tMatchCore.applyKit(m, kit)\n\telseif kind == \"Ready\" and phase == \"Loadout\" then\n",
		"\t\tkit[a] = b\n\t\tMatchCore.applyKit(m, kit)\n"
			.. "\t\t-- [SWITCH] Countdown: the body for the next round is already out, so swap the tool now (RoundEnd: the next spawn does it)\n"
			.. "\t\tlocal character = player.Character\n"
			.. "\t\tif phase == \"Countdown\" and character and character.Parent then\n"
			.. "\t\t\tif a == \"Weapon\" then\n"
			.. "\t\t\t\tfor _, c in { player:FindFirstChildOfClass(\"Backpack\"), character } do\n"
			.. "\t\t\t\t\tfor _, t in (c and c:GetChildren() or {}) do if t:IsA(\"Tool\") and t:GetAttribute(\"WeaponId\") then t:Destroy() end end\n"
			.. "\t\t\t\tend\n"
			.. "\t\t\t\tlocal Combat = shared.Get and shared.Get(\"CombatManager\")\n"
			.. "\t\t\t\tlocal tool = Combat and Combat.GiveWeapon(player, b)\n"
			.. "\t\t\t\tlocal hum = character:FindFirstChildOfClass(\"Humanoid\")\n"
			.. "\t\t\t\tif tool and hum then hum:EquipTool(tool) end\n"
			.. "\t\t\telseif a == \"Melee\" then\n"
			.. "\t\t\t\tlocal Melee = shared.Get and shared.Get(\"MeleeManager\")\n"
			.. "\t\t\t\tif Melee and Melee.GiveMelee then Melee.GiveMelee(player) end\n"
			.. "\t\t\tend\n"
			.. "\t\tend\n"
			.. "\telseif kind == \"Ready\" and phase == \"Loadout\" then\n" },
}

local STREAK = "local ws = tonumber(%s.WinStreak) or 0; if summary.Won then ws += 1 elseif not summary.Draw then ws = 0 end"
local RM_STREAK = {
	{ "\t\tif summary.Won then add(\"Wins\", 1) end\n",
		"\t\tif summary.Won then add(\"Wins\", 1) end\n"
			.. "\t\tdo -- [STREAK] consecutive match wins (a draw keeps it)\n"
			.. "\t\t\t" .. STREAK:format("data") .. "\n"
			.. "\t\t\tdata.WinStreak = ws\n"
			.. "\t\t\tplayer:SetAttribute(\"WinStreak\", ws)\n"
			.. "\t\tend\n" },
}
local LDM_STREAK = {
	{ "\tif not match.hasBot or (IS_STUDIO and ReplicatedStorage:GetAttribute(\"StudioCareerTest\")) then -- [CAREER]\n",
		"\tif not match.hasBot and data then -- [STREAK] every duel (also inside the reward cooldown); a draw keeps it\n"
			.. "\t\t" .. STREAK:format("data") .. "\n"
			.. "\t\tPlayerStore.Set(p, { \"WinStreak\" }, ws)\n"
			.. "\t\tp:SetAttribute(\"WinStreak\", ws)\n"
			.. "\tend\n"
			.. "\tif not match.hasBot or (IS_STUDIO and ReplicatedStorage:GetAttribute(\"StudioCareerTest\")) then -- [CAREER]\n" },
}
local TPL = {
	{ "\tMatchHistory = {},",
		"\tWinStreak = 0,              -- [STREAK] consecutive match wins (fix/switch_streak.lua)\n\tMatchHistory = {}," },
}
local STATS = {
	{ "\tif player:GetAttribute(\"Wins\") ~= wins then player:SetAttribute(\"Wins\", wins) end\n",
		"\tif player:GetAttribute(\"Wins\") ~= wins then player:SetAttribute(\"Wins\", wins) end\n"
			.. "\tlocal streak = tonumber(data.WinStreak) or 0 -- [STREAK] the killer card's flame badge\n"
			.. "\tif player:GetAttribute(\"WinStreak\") ~= streak then player:SetAttribute(\"WinStreak\", streak) end\n" },
}

local function check(target, edits, label)
	for i, e in ipairs(edits) do
		assert(target.Source:find(e[2], 1, true) or target.Source:find(e[1], 1, true), label .. " edit " .. i .. ": original text not found (nothing changed)")
	end
end
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
		if s:find(e[2], 1, true) then table.insert(log, label .. " " .. i .. " already in")
		else
			local a, b = s:find(e[1], 1, true)
			s = s:sub(1, a - 1) .. e[2] .. s:sub(b + 1)
			table.insert(log, label .. " " .. i .. " applied")
		end
	end
	assert(loadstring(s), label .. " would not parse")
	target.Source = s
end

local jobs = {}
if isLobby then
	table.insert(jobs, { M.LobbyDuelManager, PICK_EDITS, "LobbyDuelManager pick" })
	table.insert(jobs, { M.LobbyDuelManager, LDM_STREAK, "LobbyDuelManager streak" })
else
	table.insert(jobs, { M.RoundManager, PICK_EDITS, "RoundManager pick" })
	table.insert(jobs, { M.RoundManager, RM_STREAK, "RoundManager streak" })
end
table.insert(jobs, { SSS.Data.DataManager.Template, TPL, "Template" })
table.insert(jobs, { SSS.PublicStats, STATS, "PublicStats" })
if not UNDO then for _, j in jobs do check(j[1], j[2], j[3]) end end
for _, j in jobs do swap(j[1], j[2], j[3]) end
return (isLobby and "lobby: " or "match: ") .. table.concat(log, ", ")
