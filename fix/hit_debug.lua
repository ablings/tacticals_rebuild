-- fix/hit_debug.lua [HITDEBUG] 2026-10-18 (Edward: dying "fully behind a pillar"; "yes do 1 and 2"). Both places, CombatManager:
--  1) hats / accessories never count as hits: a claimed hit on a part inside an Accessory is rejected (before, "a hat = head",
--     so a brim sticking out of cover was a headshot). ServerScriptService.HitboxClean also takes accessories out of raycasts
--     (CanQuery off), so shots pass through them instead of stopping on them.
--  2) ;hitdebug: every claimed hit on a character is reported to players with the HitDebug attribute (admin command) through
--     RemoteEvent ReplicatedStorage.HitDebug: shooter, victim, part, accepted / reason, the claimed point, the shot origin, the
--     part where the server rewound it to and where it is now, how far back (ms), the lag window and the shooter's ping.
--     StarterPlayerScripts.HitDebugView draws it. Needs HitRewind with the detail return (scripts/secure/HitRewind.lua).
-- Idempotent; UNDO swaps back.
local UNDO = false --@UNDO
local CM = game:GetService("ServerScriptService").ServerScripts["[Server] Init"].GameManager.Managers.CombatManager
local T = " -- [HITDEBUG]\n"

local HELPER = [==[
-- [HITDEBUG] ;hitdebug reports (fix/hit_debug.lua)
local hitDebugRemote = ReplicatedStorage:FindFirstChild("HitDebug") or Instance.new("RemoteEvent")
hitDebugRemote.Name = "HitDebug"
hitDebugRemote.Parent = ReplicatedStorage
local function hitDebug(shooter: Player, victim: Model?, part: BasePart?, point: Vector3?, origin: Vector3?, accepted: boolean, reason: string?, detail)
	local watchers = {}
	for _, p in Players:GetPlayers() do if p:GetAttribute("HitDebug") then table.insert(watchers, p) end end
	if #watchers == 0 then return end
	local info = {
		shooter = shooter.Name, victim = victim and victim.Name or "?", part = part and part.Name or "?",
		accepted = accepted, reason = reason, point = point, origin = origin,
		rewound = detail and detail.rewound, now = (detail and detail.now) or (part and part.CFrame), size = (detail and detail.size) or (part and part.Size),
		ageMs = detail and math.floor((detail.age or 0) * 1000 + 0.5), windowMs = detail and math.floor((detail.window or 0) * 1000 + 0.5),
		pingMs = math.floor(((detail and detail.ping) or (pcall(shooter.GetNetworkPing, shooter) and shooter:GetNetworkPing()) or 0) * 1000 + 0.5),
	}
	for _, w in watchers do hitDebugRemote:FireClient(w, info) end
end

]==]

local EDITS = {
	{ "local function onFire(player: Player, shotId: any, origin: any, direction: any, hitPart: any, hitPosition: any)\n",
		HELPER .. "local function onFire(player: Player, shotId: any, origin: any, direction: any, hitPart: any, hitPosition: any)\n" },
	{ "\tif victimCharacter == character then return finish(\"hit self\") end\n",
		"\tif victimCharacter == character then return finish(\"hit self\") end\n"
			.. "\t-- hats / accessories don't count: a brim sticking out of cover is not you" .. T
			.. "\tif hitPart:FindFirstAncestorOfClass(\"Accessory\") then\n"
			.. "\t\thitDebug(player, victimCharacter, hitPart, hitPosition, origin, false, \"hit an accessory (hats don't count)\", nil)\n"
			.. "\t\treturn finish(\"hit an accessory\")\n"
			.. "\tend\n" },
	{ "\tlocal hitOk, hitGap = HitRewind.Check(player, victimCharacter, hitPart, hitPosition)\n"
		.. "\tif not hitOk then return finish((\"hit too far from target (%.1f studs)\"):format(hitGap)) end\n",
		"\tlocal hitOk, hitGap, rewindDetail = HitRewind.Check(player, victimCharacter, hitPart, hitPosition)\n"
			.. "\tif not hitOk then\n"
			.. "\t\thitDebug(player, victimCharacter, hitPart, hitPosition, origin, false, (\"not where the server had them (%.1f studs off)\"):format(hitGap), rewindDetail)" .. T
			.. "\t\treturn finish((\"hit too far from target (%.1f studs)\"):format(hitGap))\n"
			.. "\tend\n" },
	{ "\tif not WeaponUtil.IsPathClear(origin, hitPosition) then return finish(\"wall between shooter and target\") end\n",
		"\tif not WeaponUtil.IsPathClear(origin, hitPosition) then\n"
			.. "\t\thitDebug(player, victimCharacter, hitPart, hitPosition, origin, false, \"wall between shooter and target\", rewindDetail)" .. T
			.. "\t\treturn finish(\"wall between shooter and target\")\n"
			.. "\tend\n" },
	{ "\tlocal zone = WeaponUtil.GetHitZone(hitPart)\n\tlocal distance = (hitPosition - origin).Magnitude\n",
		"\tlocal zone = WeaponUtil.GetHitZone(hitPart)\n\tlocal distance = (hitPosition - origin).Magnitude\n"
			.. "\thitDebug(player, victimCharacter, hitPart, hitPosition, origin, true, zone, rewindDetail)" .. T },
}

local s = CM.Source
local log = {}
if UNDO then
	for i = #EDITS, 1, -1 do
		local a, b = s:find(EDITS[i][2], 1, true)
		if a then s = s:sub(1, a - 1) .. EDITS[i][1] .. s:sub(b + 1); table.insert(log, "undo " .. i) end
	end
	CM.Source = s
	return table.concat(log, ", ")
end
for i, e in ipairs(EDITS) do
	assert(s:find(e[2], 1, true) or s:find(e[1], 1, true), "edit " .. i .. ": original text not found (nothing changed)")
end
for i, e in ipairs(EDITS) do
	if s:find(e[2], 1, true) then table.insert(log, i .. " already in")
	else local a, b = s:find(e[1], 1, true); s = s:sub(1, a - 1) .. e[2] .. s:sub(b + 1); table.insert(log, i .. " applied") end
end
assert(loadstring(s), "would not parse")
CM.Source = s
return "CombatManager: " .. table.concat(log, ", ")
