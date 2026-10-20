-- fix/live_pick.lua [LIVEPICK] 2026-10-20 (Edward via the UI session: the Switch Weapons picker stays open after the round goes live).
-- A MatchFlow "Pick" sent while the round is Live is no longer dropped: it's validated as before and QUEUED, then applied the
-- moment the round leaves Live (RoundEnd), so the new kit arrives with the next spawn. Not applied mid-round on purpose: changing
-- KitMelee re-gives the melee at once and changing KitGadget refills the gadget charges (a free mid-fight refill).
-- Player attributes NextKitWeapon / NextKitMelee / NextKitGadget = the queued item (UI: "next round"), cleared when applied.
-- Match place: RoundManager (ReplicatedStorage MatchState). Lobby duels: LobbyDuelManager (per-match state object).
-- Idempotent; UNDO swaps back.
local UNDO = false --@UNDO
local SSS = game:GetService("ServerScriptService")

local function patch(inst, edits)
	if not inst then return "missing" end
	local s = inst.Source
	local out = {}
	for i, e in edits do
		local old, new = e[1], e[2]
		local done
		if UNDO then old, new = new, old; done = not s:find(old, 1, true) else done = s:find(new, 1, true) ~= nil end
		if done then table.insert(out, i .. "=") else
			local a, b = s:find(old, 1, true)
			assert(a, inst.Name .. " edit " .. i .. " anchor not found")
			assert(not s:find(old, b + 1, true), inst.Name .. " edit " .. i .. " anchor not unique")
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
-- // Match place: RoundManager
local RM = SSS:FindFirstChild("RoundManager", true)
if RM then
	table.insert(res, patch(RM, {
		{ "\telseif kind == \"Pick\" and (phase == \"Loadout\" or phase == \"RoundEnd\" or phase == \"Countdown\") then -- [SWITCH] also between rounds\n"
			.. "\t\tif not SLOTS[a] or not MatchCore.validPick(ITEMS, function(id) return owns(player, id) end, a, b) then\n"
			.. "\t\t\tif IS_STUDIO then print((\"[RoundManager] pick refused: %s %s %s\"):format(player.Name, tostring(a), tostring(b))) end\n"
			.. "\t\t\treturn\n"
			.. "\t\tend\n",
		  "\telseif kind == \"Pick\" and (phase == \"Loadout\" or phase == \"RoundEnd\" or phase == \"Countdown\" or phase == \"Live\") then -- [SWITCH] also between rounds ([LIVEPICK] and queued while Live)\n"
			.. "\t\tif not SLOTS[a] or not MatchCore.validPick(ITEMS, function(id) return owns(player, id) end, a, b) then\n"
			.. "\t\t\tif IS_STUDIO then print((\"[RoundManager] pick refused: %s %s %s\"):format(player.Name, tostring(a), tostring(b))) end\n"
			.. "\t\t\treturn\n"
			.. "\t\tend\n"
			.. "\t\tif phase == \"Live\" then -- [LIVEPICK] applied when the round ends (no mid-fight melee re-give / gadget refill)\n"
			.. "\t\t\tm.pendingKit = m.pendingKit or {}\n"
			.. "\t\t\tm.pendingKit[a] = b\n"
			.. "\t\t\tplayer:SetAttribute(\"NextKit\" .. a, b)\n"
			.. "\t\t\treturn\n"
			.. "\t\tend\n" },
		{ "-- // Admin (AdminFramework Commands/Duel) ----------------------------------------------------------------\n",
		  "-- [LIVEPICK] picks queued during Live are applied as soon as the round leaves Live\n"
			.. "ReplicatedStorage:GetAttributeChangedSignal(\"MatchState\"):Connect(function()\n"
			.. "\tif ReplicatedStorage:GetAttribute(\"MatchState\") == \"Live\" or not current then return end\n"
			.. "\tfor _, mem in current.byUser do\n"
			.. "\t\tif mem.pendingKit and mem.player and mem.player.Parent then\n"
			.. "\t\t\tlocal p = mem.player\n"
			.. "\t\t\tlocal kit = { Weapon = p:GetAttribute(\"KitWeapon\"), Melee = p:GetAttribute(\"KitMelee\"), Gadget = p:GetAttribute(\"KitGadget\") }\n"
			.. "\t\t\tfor slot, id in mem.pendingKit do kit[slot] = id; p:SetAttribute(\"NextKit\" .. slot, nil) end\n"
			.. "\t\t\tmem.pendingKit = nil\n"
			.. "\t\t\tMatchCore.applyKit(mem, kit)\n"
			.. "\t\tend\n"
			.. "\tend\n"
			.. "end)\n\n"
			.. "-- // Admin (AdminFramework Commands/Duel) ----------------------------------------------------------------\n" },
	}))
end

-- // Lobby duels: LobbyDuelManager
local LDM = SSS:FindFirstChild("LobbyDuelManager", true)
if LDM then
	table.insert(res, patch(LDM, {
		{ "\telseif kind == \"Pick\" and (phase == \"Loadout\" or phase == \"RoundEnd\" or phase == \"Countdown\") then -- [SWITCH] also between rounds\n"
			.. "\t\tif a ~= \"Weapon\" and a ~= \"Melee\" and a ~= \"Gadget\" then return end\n"
			.. "\t\tif not MatchCore.validPick(LobbyConfig.Items, function(id) return PlayerStore.Owns(player, id) end, a, b) then return end\n",
		  "\telseif kind == \"Pick\" and (phase == \"Loadout\" or phase == \"RoundEnd\" or phase == \"Countdown\" or phase == \"Live\") then -- [SWITCH] also between rounds ([LIVEPICK] and queued while Live)\n"
			.. "\t\tif a ~= \"Weapon\" and a ~= \"Melee\" and a ~= \"Gadget\" then return end\n"
			.. "\t\tif not MatchCore.validPick(LobbyConfig.Items, function(id) return PlayerStore.Owns(player, id) end, a, b) then return end\n"
			.. "\t\tif phase == \"Live\" then -- [LIVEPICK] applied when this match's round ends\n"
			.. "\t\t\tm.pendingKit = m.pendingKit or {}\n"
			.. "\t\t\tm.pendingKit[a] = b\n"
			.. "\t\t\tplayer:SetAttribute(\"NextKit\" .. a, b)\n"
			.. "\t\t\tif not match.livePickWatch then\n"
			.. "\t\t\t\tmatch.livePickWatch = match.state:GetAttributeChangedSignal(\"MatchState\"):Connect(function()\n"
			.. "\t\t\t\t\tif match.state:GetAttribute(\"MatchState\") == \"Live\" then return end\n"
			.. "\t\t\t\t\tfor _, list in match.teams do\n"
			.. "\t\t\t\t\t\tfor _, mem in list do\n"
			.. "\t\t\t\t\t\t\tif mem.pendingKit and mem.player and mem.player.Parent then\n"
			.. "\t\t\t\t\t\t\t\tlocal p = mem.player\n"
			.. "\t\t\t\t\t\t\t\tlocal kit = { Weapon = p:GetAttribute(\"KitWeapon\"), Melee = p:GetAttribute(\"KitMelee\"), Gadget = p:GetAttribute(\"KitGadget\") }\n"
			.. "\t\t\t\t\t\t\t\tfor slot, id in mem.pendingKit do kit[slot] = id; p:SetAttribute(\"NextKit\" .. slot, nil) end\n"
			.. "\t\t\t\t\t\t\t\tmem.pendingKit = nil\n"
			.. "\t\t\t\t\t\t\t\tMatchCore.applyKit(mem, kit)\n"
			.. "\t\t\t\t\t\t\tend\n"
			.. "\t\t\t\t\t\tend\n"
			.. "\t\t\t\t\tend\n"
			.. "\t\t\t\tend)\n"
			.. "\t\t\tend\n"
			.. "\t\t\treturn\n"
			.. "\t\tend\n" },
	}))
end
return table.concat(res, " | ")
