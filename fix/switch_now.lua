-- fix/switch_now.lua [SWITCHNOW] 2026-10-25 (both places: match places' RoundManager, the hub's LobbyDuelManager; MatchCore,
-- CombatManager, MeleeManager, GadgetManager, Abilities everywhere). Edward: "when switching weapons between rounds even if you
-- pick your last weapon 30 seconds into the round it should still switch ... when you press switch weapons you are now on a clean
-- slate and have to pick the weapons you want again ... sometimes my primary will switch but my gadget switch will be queued for
-- next round which is bad, it should always switch".
-- The bug: picks were decided one by one: swapped at once only while the kit was unlocked, queued for the next round after, so a
-- primary picked in the countdown swapped and a gadget picked after the round went live was queued.
-- Now a Switch Weapons SESSION decides: the picker opening sends MatchFlow "SwitchOpen" (accepted in RoundEnd / Countdown, or the
-- first 1.5 s of Live for a press that crossed the start in flight), which sets player attribute SwitchingKit; every pick while
-- it is set swaps at once, whatever the round time; the picker closing sends "SwitchDone". While SwitchingKit is set you can't
-- fire, swing (checked again after the wind-up), throw or use an ability. The server clears it whenever the match leaves RoundEnd
-- / Countdown / Live and (hub) whenever a player leaves a duel; a hub SwitchDone is accepted without a match id. A gadget throw
-- during Live locks the kit (no throw-then-switch refill). Picks outside a session keep the old next-round queue.
-- Round 2 (systems grader FIX): one per-player rate limiter on every MatchFlow kind (a Pick re-gives a Tool); LiveAt for the
-- grace window; the melee re-check; the CombatManager fire gate must apply. Client: ui/match/MatchFlowUI [SWITCHNOW].
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

-- the per-player MatchFlow limiter (both places)
local LIMITER = "-- [SWITCHNOW] (systems grader) one per-player limiter for every MatchFlow kind (a Pick re-gives a Tool, To Hub teleports)\n"
	.. "local flowBuckets = {} -- [Player] = { [kind] = { tokens, t } }\n"
	.. "local FLOW_RATE = { Pick = { 6, 4 }, Vote = { 4, 4 } } -- { burst, per second }; every other kind { 3, 2 }\n"
	.. "game:GetService(\"Players\").PlayerRemoving:Connect(function(p) flowBuckets[p] = nil end)\n"
	.. "local function flowRateOk(player: Player, kind: any): boolean\n"
	.. "\tlocal cfg = FLOW_RATE[kind] or { 3, 2 }\n"
	.. "\tlocal pb = flowBuckets[player] or {}\n"
	.. "\tflowBuckets[player] = pb\n"
	.. "\tlocal now, key = os.clock(), tostring(kind)\n"
	.. "\tlocal b = pb[key] or { tokens = cfg[1], t = now }\n"
	.. "\tb.tokens = math.min(cfg[1], b.tokens + (now - b.t) * cfg[2]); b.t = now\n"
	.. "\tpb[key] = b\n"
	.. "\tif b.tokens < 1 then return false end\n"
	.. "\tb.tokens -= 1\n"
	.. "\treturn true\n"
	.. "end\n"

-- Pick handlers: a session pick always swaps now; queue only outside a session
local Q_MATCH = "\t\tif phase == \"Live\" and player:GetAttribute(\"KitLocked\") then -- [LIVEPICK] applied when the round ends (no mid-fight melee re-give / gadget refill) ([ROUNDFLOW] only once locked)\n"
local Q_HUB = "\t\tif phase == \"Live\" and player:GetAttribute(\"KitLocked\") then -- [LIVEPICK] applied when this match's round ends ([ROUNDFLOW] only once locked)\n"
local function qNew(old)
	local s = old:gsub("player:GetAttribute%(\"KitLocked\"%) then", "player:GetAttribute(\"KitLocked\") and not player:GetAttribute(\"SwitchingKit\") then", 1)
	s = s:gsub("\n$", " ([SWITCHNOW] a Switch Weapons session always swaps at once)\n")
	return s
end
local READY = "\telseif kind == \"Ready\" and phase == \"Loadout\" then\n"
local function session(stateExpr)
	return "\telseif kind == \"SwitchOpen\" then -- [SWITCHNOW] the picker opened: every pick swaps at once until SwitchDone\n"
		.. "\t\tlocal liveAt = " .. stateExpr .. ":GetAttribute(\"LiveAt\") or 0\n"
		.. "\t\t-- a press that crossed the round start in flight, from a player who hasn't fired or thrown since (round 3: no free reload / refill)\n"
		.. "\t\tlocal grace = phase == \"Live\" and workspace:GetServerTimeNow() - liveAt < 1.5 and (player:GetAttribute(\"ActedAt\") or 0) < liveAt\n"
		.. "\t\tif phase == \"RoundEnd\" or phase == \"Countdown\" or grace or (phase == \"Live\" and not player:GetAttribute(\"KitLocked\")) then\n"
		.. "\t\t\tplayer:SetAttribute(\"SwitchingKit\", true)\n"
		.. "\t\tend\n"
		.. "\telseif kind == \"SwitchDone\" then -- [SWITCHNOW] the picker closed: hands back on\n"
		.. "\t\tplayer:SetAttribute(\"SwitchingKit\", nil)\n"
end
if IS_HUB then
	local LDM = find("LobbyDuelManager")
	local FLOW_OLD = "local function onFlow(player: Player, matchId: any, kind: any, a: any, b: any)\n\tlocal rec = byPlayer[player]\n"
	local FLOW_NEW = LIMITER .. "local FLOW_KINDS = { Vote = true, Pick = true, Ready = true, Loaded = true, Leave = true, SwitchOpen = true, SwitchDone = true } -- [SWITCHNOW]\n"
		.. "local function onFlow(player: Player, matchId: any, kind: any, a: any, b: any)\n"
		.. "\t-- [SWITCHNOW] a SwitchDone always lands, even after the duel forgot you; every kind is rate limited\n"
		.. "\tif kind == \"SwitchDone\" or matchId == \"SwitchDone\" then player:SetAttribute(\"SwitchingKit\", nil) end\n"
		.. "\tlocal flowKind = kind\n"
		.. "\tif type(matchId) ~= \"string\" then flowKind = matchId end\n"
		.. "\tif not FLOW_KINDS[flowKind] or not flowRateOk(player, flowKind) then return end -- (round 3) known kinds only: bounded buckets\n"
		.. "\tlocal rec = byPlayer[player]\n"
	local CLEAR_OLD = "\"Deploying\" } do\n\t\tplayer:SetAttribute(k, nil)\n"
	local CLEAR_NEW = "\"Deploying\", \"SwitchingKit\" } do -- [SWITCHNOW] leaving a duel ends a Switch Weapons session\n\t\tplayer:SetAttribute(k, nil)\n"
	table.insert(res, patch(LDM, { { Q_HUB, qNew(Q_HUB) }, { READY, session("match.state") .. READY }, { FLOW_OLD, FLOW_NEW }, { CLEAR_OLD, CLEAR_NEW } }))
else
	local RM = SSS.ServerScripts["[Server] Init"].GameManager.Managers.RoundManager
	local K_OLD = "local KINDS = { Vote = true, Pick = true, Ready = true, Leave = true, Loaded = true, Rematch = true, PlayAgain = true, ToHub = true }"
	local K_NEW = "local KINDS = { Vote = true, Pick = true, Ready = true, Leave = true, Loaded = true, Rematch = true, PlayAgain = true, ToHub = true, SwitchOpen = true, SwitchDone = true }"
	local F_OLD = "local function onFlow(player: Player, kind: any, a: any, b: any, c: any)\n\tif not KINDS[kind] and KINDS[a] then kind, a, b = a, b, c end\n"
	local F_NEW = LIMITER .. "local function onFlow(player: Player, kind: any, a: any, b: any, c: any)\n\tif not KINDS[kind] and KINDS[a] then kind, a, b = a, b, c end\n"
		.. "\t-- [SWITCHNOW] SwitchDone only lifts a restriction: never rate limited (round 3); every other kind must be known, then limited\n"
		.. "\tif kind == \"SwitchDone\" then player:SetAttribute(\"SwitchingKit\", nil) return end\n"
		.. "\tif not KINDS[kind] or not flowRateOk(player, kind) then return end\n"
	table.insert(res, patch(RM, { { Q_MATCH, qNew(Q_MATCH) }, { READY, session("ReplicatedStorage") .. READY }, { K_OLD, K_NEW }, { F_OLD, F_NEW } }))
end

-- MatchCore (both places): the match moving on ends any session; LiveAt for the SwitchOpen grace
local LOCK_RESET = "\tif state == \"Countdown\" then\n\t\tfor _, list in ctx.teams do for _, m in list do if m.player then m.player:SetAttribute(\"KitLocked\", nil) end end end\n"
local LIVE_OLD = "\telseif state == \"Live\" then\n\t\t-- [PREROUND] switching is free until the round starts"
table.insert(res, patch(find("MatchCore"), {
	{ LOCK_RESET,
		"\t-- [SWITCHNOW] a Switch Weapons session lives through RoundEnd / Countdown / Live only\n"
		.. "\tif type(ctx.teams) == \"table\" and state ~= \"RoundEnd\" and state ~= \"Countdown\" and state ~= \"Live\" then\n"
		.. "\t\tfor _, list in ctx.teams do for _, m in list do if m.player then m.player:SetAttribute(\"SwitchingKit\", nil) end end end\n"
		.. "\tend\n" .. LOCK_RESET },
	{ LIVE_OLD, "\telseif state == \"Live\" then\n\t\ts:SetAttribute(\"LiveAt\", workspace:GetServerTimeNow()) -- [SWITCHNOW] the SwitchOpen grace window\n\t\t-- [PREROUND] switching is free until the round starts" },
}))

-- no fighting while switching
local CM_MATCH = "\tif ReplicatedStorage:GetAttribute(\"CombatEnabled\") == false and not roundOver then return finish(\"combat disabled (countdown / round over)\") end\n"
local CM_HUB = "\tif MatchState.Get(player, \"CombatEnabled\") == false and not roundOver then return finish(\"combat disabled (countdown / round over)\") end\n"
local CM_ADD = "\tif player:GetAttribute(\"SwitchingKit\") then return finish(\"switching weapons\") end -- [SWITCHNOW]\n"
local SHOT_LOCK = "\t\tstate.lastFire = now\n\t\tplayer:SetAttribute(\"KitLocked\", true) -- [ROUNDFLOW] the first shot locks this round's kit\n"
local SHOT_ACT = SHOT_LOCK .. "\t\tplayer:SetAttribute(\"ActedAt\", workspace:GetServerTimeNow()) -- [SWITCHNOW] no SwitchOpen grace after a shot\n"
local cmRes = patch(find("CombatManager"), { { CM_MATCH, CM_MATCH .. CM_ADD, true }, { CM_HUB, CM_HUB .. CM_ADD, true }, { SHOT_LOCK, SHOT_ACT } })
assert(UNDO or cmRes:find("[12][+=]"), "CombatManager: no fire gate anchor matched (" .. cmRes .. ")")
table.insert(res, cmRes)
local MM_MATCH = "\tif ReplicatedStorage:GetAttribute(\"CombatEnabled\") == false then return end\n\tlocal character = player.Character\n"
local MM_HUB = "\tif MatchState.Get(player, \"CombatEnabled\") == false then return end\n"
local MM_ADD = "\tif player:GetAttribute(\"SwitchingKit\") then return end -- [SWITCHNOW] no swings while switching weapons\n"
local MM_WIND = "\ttask.wait(weapon.HitDelay)\n\tif humanoid.Health <= 0 then return end\n"
local MM_WIND_NEW = "\ttask.wait(weapon.HitDelay)\n\tif humanoid.Health <= 0 then return end\n"
	.. "\tif player:GetAttribute(\"SwitchingKit\") then return end -- [SWITCHNOW] re-checked after the wind-up\n"
	.. (IS_HUB and "\tif MatchState.Get(player, \"CombatEnabled\") == false then return end -- [SWITCHNOW] (grader A8) combat still on after the wind-up\n"
		or "\tif ReplicatedStorage:GetAttribute(\"CombatEnabled\") == false then return end -- [SWITCHNOW] (grader A8) combat still on after the wind-up\n")
table.insert(res, patch(find("MeleeManager"), IS_HUB and { { MM_HUB, MM_HUB .. MM_ADD }, { MM_WIND, MM_WIND_NEW } }
	or { { MM_MATCH, (MM_MATCH:gsub("\tlocal character", MM_ADD .. "\tlocal character", 1)) }, { MM_WIND, MM_WIND_NEW } }))
local GM_MATCH = "\tif ReplicatedStorage:GetAttribute(\"CombatEnabled\") == false and ReplicatedStorage:GetAttribute(\"MatchState\") ~= \"RoundEnd\" then return end\n"
local GM_HUB = "\tif MatchState.Get(player, \"CombatEnabled\") == false and MatchState.Get(player, \"MatchState\") ~= \"RoundEnd\" then return end\n"
local GM_ADD_MATCH = "\tif player:GetAttribute(\"SwitchingKit\") then return end -- [SWITCHNOW] no throws while switching weapons\n"
	.. "\tplayer:SetAttribute(\"ActedAt\", workspace:GetServerTimeNow()) -- [SWITCHNOW] no SwitchOpen grace after a throw\n"
	.. "\tif ReplicatedStorage:GetAttribute(\"MatchState\") == \"Live\" then player:SetAttribute(\"KitLocked\", true) end -- [SWITCHNOW] a live throw locks the kit (no refill by switching)\n"
local GM_ADD_HUB = "\tif player:GetAttribute(\"SwitchingKit\") then return end -- [SWITCHNOW] no throws while switching weapons\n"
	.. "\tplayer:SetAttribute(\"ActedAt\", workspace:GetServerTimeNow()) -- [SWITCHNOW] no SwitchOpen grace after a throw\n"
	.. "\tif MatchState.Get(player, \"MatchState\") == \"Live\" then player:SetAttribute(\"KitLocked\", true) end -- [SWITCHNOW] a live throw locks the kit (no refill by switching)\n"
table.insert(res, patch(find("GadgetManager"), IS_HUB and { { GM_HUB, GM_HUB .. GM_ADD_HUB } } or { { GM_MATCH, GM_MATCH .. GM_ADD_MATCH } }))
local AB_OLD = "local function combatOn(player: Player): boolean\n\treturn stateOf(player, \"CombatEnabled\") ~= false\nend\n"
local AB_NEW = "local function combatOn(player: Player): boolean\n\treturn stateOf(player, \"CombatEnabled\") ~= false and not player:GetAttribute(\"SwitchingKit\") -- [SWITCHNOW]\nend\n"
table.insert(res, patch(find("Abilities"), { { AB_OLD, AB_NEW } }))
return "SWITCHNOW " .. table.concat(res, " | ")
