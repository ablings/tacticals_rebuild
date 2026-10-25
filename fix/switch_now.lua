-- fix/switch_now.lua [SWITCHNOW] 2026-10-25 (both places: match places' RoundManager, the hub's LobbyDuelManager; MatchCore,
-- CombatManager, MeleeManager, GadgetManager, Abilities everywhere). Edward: "when switching weapons between rounds even if you
-- pick your last weapon 30 seconds into the round it should still switch ... when you press switch weapons you are now on a clean
-- slate and have to pick the weapons you want again ... sometimes my primary will switch but my gadget switch will be queued for
-- next round which is bad, it should always switch".
-- The bug: [ROUNDFLOW]/[LIVEPICK] decided per PICK: a pick swapped at once only until you first moved / fired (KitLocked), so a
-- primary picked before moving swapped and a gadget picked after was queued for the next round.
-- Now a Switch Weapons SESSION decides: the picker opening sends MatchFlow "SwitchOpen" (accepted in RoundEnd / Countdown, or
-- Live before KitLocked, the same gate the button has), which sets player attribute SwitchingKit; every pick while it is set
-- swaps at once, whatever the round time or KitLocked; the picker closing sends "SwitchDone" (attribute cleared). While
-- SwitchingKit is set you can't fire, swing, throw or use an ability (no free fighting while "unarmed"; your view is blurred and
-- pulled into first person on your screen, ui/match/MatchFlowUI [SWITCHNOW]). The match moving on (not RoundEnd / Countdown /
-- Live) clears it. A gadget throw during Live now also sets KitLocked (no throw-then-switch refill). Picks outside a session
-- keep the old [LIVEPICK] queue (nothing in the UI sends those any more).
-- Idempotent; checks every edit; UNDO swaps back.
local UNDO = false --@UNDO
local SSS = game:GetService("ServerScriptService")
local IS_HUB = workspace:FindFirstChild("LobbyMap") ~= nil and game:GetService("ReplicatedStorage"):FindFirstChild("PlaceKind") == nil

local function patch(inst, edits)
	if not inst then return "missing" end
	local s = inst.Source:gsub("\r\n", "\n")
	local out = {}
	for i, e in edits do
		local old, new = e[1], e[2]
		local done
		if UNDO then old, new = new, old; done = not s:find(old, 1, true) else done = s:find(new, 1, true) ~= nil end
		if done then table.insert(out, i .. "=") else
			local a, b = s:find(old, 1, true)
			if not a and e[3] then table.insert(out, i .. "-") else
				assert(a, inst.Name .. " edit " .. i .. " anchor not found")
				assert(not s:find(old, b + 1, true), inst.Name .. " edit " .. i .. " anchor not unique")
				s = s:sub(1, a - 1) .. new .. s:sub(b + 1)
				table.insert(out, i .. "+")
			end
		end
	end
	local f, err = loadstring(s)
	assert(f, inst.Name .. " would not parse: " .. tostring(err))
	if inst.Source ~= s then inst.Source = s end
	return inst.Name .. " " .. table.concat(out, " ")
end
local function find(name) local i = SSS:FindFirstChild(name, true); assert(i, "no " .. name); return i end
local res = {}

-- Pick handlers: a session pick always swaps now; queue only outside a session
local Q_MATCH = "\t\tif phase == \"Live\" and player:GetAttribute(\"KitLocked\") then -- [LIVEPICK] applied when the round ends (no mid-fight melee re-give / gadget refill) ([ROUNDFLOW] only once locked)\n"
local Q_HUB = "\t\tif phase == \"Live\" and player:GetAttribute(\"KitLocked\") then -- [LIVEPICK] applied when this match's round ends ([ROUNDFLOW] only once locked)\n"
local function qNew(old)
	local s = old:gsub("player:GetAttribute%(\"KitLocked\"%) then", "player:GetAttribute(\"KitLocked\") and not player:GetAttribute(\"SwitchingKit\") then", 1)
	s = s:gsub("\n$", " ([SWITCHNOW] a Switch Weapons session always swaps at once)\n")
	return s
end
local READY = "\telseif kind == \"Ready\" and phase == \"Loadout\" then\n"
local SESSION = "\telseif kind == \"SwitchOpen\" then -- [SWITCHNOW] the picker opened: every pick swaps at once until SwitchDone\n"
	.. "\t\tif phase == \"RoundEnd\" or phase == \"Countdown\" or (phase == \"Live\" and not player:GetAttribute(\"KitLocked\")) then\n"
	.. "\t\t\tplayer:SetAttribute(\"SwitchingKit\", true)\n"
	.. "\t\tend\n"
	.. "\telseif kind == \"SwitchDone\" then -- [SWITCHNOW] the picker closed: hands back on\n"
	.. "\t\tplayer:SetAttribute(\"SwitchingKit\", nil)\n"
if IS_HUB then
	table.insert(res, patch(find("LobbyDuelManager"), { { Q_HUB, qNew(Q_HUB) }, { READY, SESSION .. READY } }))
else
	local RM = SSS.ServerScripts["[Server] Init"].GameManager.Managers.RoundManager
	local K_OLD = "local KINDS = { Vote = true, Pick = true, Ready = true, Leave = true, Loaded = true, Rematch = true, PlayAgain = true, ToHub = true }"
	local K_NEW = "local KINDS = { Vote = true, Pick = true, Ready = true, Leave = true, Loaded = true, Rematch = true, PlayAgain = true, ToHub = true, SwitchOpen = true, SwitchDone = true }"
	table.insert(res, patch(RM, { { Q_MATCH, qNew(Q_MATCH) }, { READY, SESSION .. READY }, { K_OLD, K_NEW } }))
end

-- MatchCore: the match moving on ends any session (both places share MatchCore)
local LOCK_RESET = "\tif state == \"Countdown\" then\n\t\tfor _, list in ctx.teams do for _, m in list do if m.player then m.player:SetAttribute(\"KitLocked\", nil) end end end\n"
table.insert(res, patch(find("MatchCore"), { { LOCK_RESET,
	"\t-- [SWITCHNOW] a Switch Weapons session lives through RoundEnd / Countdown / Live only\n"
	.. "\tif type(ctx.teams) == \"table\" and state ~= \"RoundEnd\" and state ~= \"Countdown\" and state ~= \"Live\" then\n"
	.. "\t\tfor _, list in ctx.teams do for _, m in list do if m.player then m.player:SetAttribute(\"SwitchingKit\", nil) end end end\n"
	.. "\tend\n" .. LOCK_RESET } }))

-- no fighting while switching
local CM_MATCH = "\tif ReplicatedStorage:GetAttribute(\"CombatEnabled\") == false and not roundOver then return finish(\"combat disabled (countdown / round over)\") end\n"
local CM_HUB = "\tif MatchState.Get(player, \"CombatEnabled\") == false and not roundOver then return finish(\"combat disabled (countdown / round over)\") end\n"
local CM_ADD = "\tif player:GetAttribute(\"SwitchingKit\") then return finish(\"switching weapons\") end -- [SWITCHNOW]\n"
table.insert(res, patch(find("CombatManager"), { { CM_MATCH, CM_MATCH .. CM_ADD, true }, { CM_HUB, CM_HUB .. CM_ADD, true } }))
local MM_MATCH = "\tif ReplicatedStorage:GetAttribute(\"CombatEnabled\") == false then return end\n\tlocal character = player.Character\n"
local MM_HUB = "\tif MatchState.Get(player, \"CombatEnabled\") == false then return end\n"
local MM_ADD = "\tif player:GetAttribute(\"SwitchingKit\") then return end -- [SWITCHNOW] no swings while switching weapons\n"
table.insert(res, patch(find("MeleeManager"), IS_HUB and { { MM_HUB, MM_HUB .. MM_ADD } } or { { MM_MATCH, (MM_MATCH:gsub("\tlocal character", MM_ADD .. "\tlocal character", 1)) } }))
local GM_MATCH = "\tif ReplicatedStorage:GetAttribute(\"CombatEnabled\") == false and ReplicatedStorage:GetAttribute(\"MatchState\") ~= \"RoundEnd\" then return end\n"
local GM_HUB = "\tif MatchState.Get(player, \"CombatEnabled\") == false and MatchState.Get(player, \"MatchState\") ~= \"RoundEnd\" then return end\n"
local GM_ADD_MATCH = "\tif player:GetAttribute(\"SwitchingKit\") then return end -- [SWITCHNOW] no throws while switching weapons\n"
	.. "\tif ReplicatedStorage:GetAttribute(\"MatchState\") == \"Live\" then player:SetAttribute(\"KitLocked\", true) end -- [SWITCHNOW] a live throw locks the kit (no refill by switching)\n"
local GM_ADD_HUB = "\tif player:GetAttribute(\"SwitchingKit\") then return end -- [SWITCHNOW] no throws while switching weapons\n"
	.. "\tif MatchState.Get(player, \"MatchState\") == \"Live\" then player:SetAttribute(\"KitLocked\", true) end -- [SWITCHNOW] a live throw locks the kit (no refill by switching)\n"
table.insert(res, patch(find("GadgetManager"), IS_HUB and { { GM_HUB, GM_HUB .. GM_ADD_HUB } } or { { GM_MATCH, GM_MATCH .. GM_ADD_MATCH } }))
local AB_OLD = "local function combatOn(player: Player): boolean\n\treturn stateOf(player, \"CombatEnabled\") ~= false\nend\n"
local AB_NEW = "local function combatOn(player: Player): boolean\n\treturn stateOf(player, \"CombatEnabled\") ~= false and not player:GetAttribute(\"SwitchingKit\") -- [SWITCHNOW]\nend\n"
table.insert(res, patch(find("Abilities"), { { AB_OLD, AB_NEW } }))
return "SWITCHNOW " .. table.concat(res, " | ")
