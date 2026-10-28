-- fix/smoke_alarm_tests.lua [SMOKEALARM] unit tests, Edit mode, on a place where fix/smoke_alarm.lua is installed.
-- Fresh clones of SmokeAlarm + SteamMask (the plugin VM caches require per instance), fake alarms 5000 studs up (cleaned up).
-- Returns "SMOKEALARM tests: n/n" plus every failure.
local CollectionService = game:GetService("CollectionService")
local Shared = game:GetService("ReplicatedStorage").Modules.Shared
local results, fails = 0, {}
local function check(name: string, ok: any)
	results += 1
	if not ok then table.insert(fails, name) end
end

-- fresh copies, side by side with the real ones (script.Parent.Config resolves; SteamMask's require(script.Parent.SmokeAlarm)
-- must reach OUR fresh SmokeAlarm: put both clones in a folder that mirrors Shared)
local box = Instance.new("Folder")
box.Name = "_SmokeAlarmTest"
Shared.Config:Clone().Parent = box
local SA = Shared.SmokeAlarm:Clone(); SA.Parent = box
local SMk = Shared.SteamMask:Clone(); SMk.Parent = box
box.Parent = Shared
local ok, err = pcall(function()
	local SmokeAlarm = require(SA)
	local SteamMask = require(SMk)
	local cfg = SmokeAlarm.Config()
	check("config from ShootableConfig (MaskRadius 28, BlareTime 7)", cfg.MaskRadius == 28 and cfg.BlareTime == 7 and cfg.ChirpMin == 25 and cfg.ChirpMax == 40)

	local world = Instance.new("Model")
	world.Name = "_SmokeAlarmTestWorld"
	world.Parent = workspace
	local function alarmAt(name: string, at: Vector3): Model
		local m = Instance.new("Model")
		m.Name = name
		m:SetAttribute("Shootable", "SmokeAlarm")
		local base = Instance.new("Part")
		base.Name = "Base"; base.Anchored = true; base.CanCollide = false
		base.Shape = Enum.PartType.Cylinder; base.Size = Vector3.new(0.12, 1.4, 1.4)
		base.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2)
		base.Parent = m
		local cover = Instance.new("Part")
		cover.Name = "Cover"; cover.Anchored = true; cover.CanCollide = false
		cover.Shape = Enum.PartType.Cylinder; cover.Size = Vector3.new(0.34, 1.16, 1.16)
		cover.CFrame = CFrame.new(at - Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		cover.Parent = m
		m.PrimaryPart = base
		m.Parent = world
		return m
	end
	local A = Vector3.new(0, 5013, 0)      -- a ground-floor ceiling (floor at 5000)
	local B = Vector3.new(3000, 5013, 0)   -- another match's alarm far away
	local mA, mB = alarmAt("SmokeAlarm_A", A), alarmAt("SmokeAlarm_B", B)
	check("IsAlarm by attribute", SmokeAlarm.IsAlarm(mA))
	-- the map's collision: the slab the alarm hangs from (its top = the floor upstairs) and, later, a wall
	local geo = Instance.new("Folder")
	geo.Name = "Geo"
	geo.Parent = world
	local slab = Instance.new("Part")
	slab.Name = "COLP_Slab"; slab.Anchored = true; slab.Size = Vector3.new(60, 1, 60)
	slab.CFrame = CFrame.new(A + Vector3.new(0, 0.56, 0))
	slab.Parent = geo
	local live = true
	local set = SmokeAlarm.Server({ mA }, { geometry = function() return { geo } end, isLive = function() return live end })
	local setB = SmokeAlarm.Server({ mB }, nil)
	check("Server: one alarm each, tagged, AlarmPos", set:Count() == 1 and mA:HasTag(SmokeAlarm.TAG) and (mA:GetAttribute("AlarmPos") - A).Magnitude < 0.01)
	local first = set.alarms[1].nextChirp - os.clock()
	check("first chirp of a round 4..40 s away", first >= 3.9 and first <= 40.1)

	-- chirps: every gap 25..40, random, nothing while broken
	local gaps, minG, maxG = {}, math.huge, 0
	for _ = 1, 60 do
		set.alarms[1].nextChirp = 0
		set:Step()
		local g = set.alarms[1].nextChirp - os.clock()
		minG, maxG = math.min(minG, g), math.max(maxG, g)
		gaps[math.floor(g)] = true
	end
	local distinct = 0
	for _ in gaps do distinct += 1 end
	check("chirp gaps within 25..40 s (" .. string.format("%.1f..%.1f", minG, maxG) .. ")", minG >= 24.9 and maxG <= 40.1)
	check("chirp gaps randomised (" .. distinct .. " distinct seconds in 60)", distinct >= 8)
	check("Step sets ChirpAt (server time)", type(mA:GetAttribute("ChirpAt")) == "number")

	-- quiet before the shot
	local floorNear = A + Vector3.new(10, -10, 0)
	check("not blaring before the shot", not SmokeAlarm.Blaring(floorNear) and not SteamMask.IsMasked(floorNear))

	-- a bullet from below through the alarm
	local model, t = set:Hit(A + Vector3.new(-20, -9, 0), A + Vector3.new(0.3, 0.2, 0))
	check("bullet breaks it", model == mA and t ~= nil and mA:GetAttribute("AlarmBroken") == true and mA:GetAttribute("AlarmCause") == "Bullet")
	local blare = mA:GetAttribute("BlareUntil") - mA:GetAttribute("BlareAt")
	check("blares 7 s", math.abs(blare - 7) < 0.01)
	check("a second bullet does nothing", set:Hit(A + Vector3.new(-20, -9, 0), A + Vector3.new(0.3, 0.2, 0)) == nil)
	check("a bullet that misses by 2 studs does nothing (other set)", setB:Hit(B + Vector3.new(-20, -9, 0), B + Vector3.new(0, -2, 2.5)) == nil)

	-- the mask: its floor within 28 flat, never upstairs, never the other match
	check("masked: its floor, 10 studs away", SmokeAlarm.Blaring(floorNear) and SteamMask.IsMasked(floorNear))
	check("masked: its floor, 27 studs away", SteamMask.IsMasked(A + Vector3.new(27, -10, 0)))
	check("not masked: 29 studs away", not SteamMask.IsMasked(A + Vector3.new(29, -10, 0)))
	check("not masked: the floor upstairs (root 4 above the alarm)", not SteamMask.IsMasked(A + Vector3.new(5, 4, 0)))
	check("not masked: 20 below (a floor further down)", not SteamMask.IsMasked(A + Vector3.new(5, -20, 0)))
	check("not masked: next to the OTHER match's alarm", not SteamMask.IsMasked(B + Vector3.new(5, -10, 0)))
	check("Muffles: listener in the blare, source outside", SmokeAlarm.Muffles(A + Vector3.new(60, -10, 0), floorNear))
	check("Muffles: both outside", not SmokeAlarm.Muffles(A + Vector3.new(60, -10, 0), A + Vector3.new(-60, -10, 0)))
	if SteamMask.FillMuffled then
		check("FillMuffled (players' muffle + AI): listener in the blare", SteamMask.FillMuffled(A + Vector3.new(60, -10, 0), floorNear))
		check("Muffled (AI): walker in the blare", SteamMask.Muffled(floorNear, A + Vector3.new(60, -10, 0)))
		check("Muffled (AI): both outside", not SteamMask.Muffled(A + Vector3.new(60, -10, 0), A + Vector3.new(-60, -10, 0)))
	end

	-- no chirp while broken
	mA:SetAttribute("ChirpAt", nil)
	set.alarms[1].nextChirp = 0
	set:Step()
	check("no chirp while broken", mA:GetAttribute("ChirpAt") == nil)

	-- after the blare: broken and silent, mask gone
	mA:SetAttribute("BlareUntil", workspace:GetServerTimeNow() - 0.01)
	check("blare over: mask gone", not SteamMask.IsMasked(floorNear))
	check("blare over: still broken", mA:GetAttribute("AlarmBroken") == true and set:Hit(A + Vector3.new(-20, -9, 0), A) == nil)

	-- the round resets
	set:Reset()
	check("reset: whole, quiet, attributes cleared", set.alarms[1].broken == false and mA:GetAttribute("AlarmBroken") == nil
		and mA:GetAttribute("BlareUntil") == nil and mA:GetAttribute("ChirpAt") == nil)

	-- blasts: in reach and no wall; a wall stops it; out of reach does nothing
	check("blast on the floor above (through the slab): nothing", set:Blast(A + Vector3.new(0, 2.06, 3), 15) == 0)
	local wallPart = Instance.new("Part")
	wallPart.Anchored = true; wallPart.Size = Vector3.new(1, 20, 20)
	wallPart.CFrame = CFrame.new(A + Vector3.new(-4, -8, 0))
	wallPart.Parent = geo
	check("blast behind a wall: nothing", set:Blast(A + Vector3.new(-8, -8, 0), 15) == 0)
	wallPart:Destroy()
	check("blast 30 away (radius 15): nothing", set:Blast(A + Vector3.new(30, -8, 0), 15) == 0)
	check("blast in reach: breaks", set:Blast(A + Vector3.new(0, -8, 4), 15) == 1 and mA:GetAttribute("AlarmCause") == "Blast")
	set:Reset()

	-- melee: a knife from the floor can't reach the ceiling; from 2 studs under it (standing on something) it can
	local look = Vector3.new(1, 0, 0)
	check("melee from the floor (root 10 below): out of reach", set:Melee(A + Vector3.new(-1, -10, 0), look, 6, 70) == nil)
	check("melee from the floor above, straight over it (through the slab): nothing", set:Melee(A + Vector3.new(0, 4.06, 0), look, 6, 70) == nil)
	check("melee from the floor above, 3 studs off and facing it: nothing", set:Melee(A + Vector3.new(-3, 4.06, 0), look, 7, 70) == nil)
	check("melee facing away: nothing", set:Melee(A + Vector3.new(-3, -3, 0), -look, 6, 70) == nil)
	check("melee close and facing it: breaks", set:Melee(A + Vector3.new(-3, -3, 0), look, 6, 70) == mA and mA:GetAttribute("AlarmCause") == "Melee")
	set:Reset()

	-- bad input never errors
	check("bad input", set:Hit(nil :: any, A) == nil and set:Blast(nil :: any, 5) == 0 and set:Melee(A, nil :: any, 6) == nil
		and SmokeAlarm.Blaring(nil :: any) == false)

	-- a map that isn't being played: no chirps
	live = false
	mA:SetAttribute("ChirpAt", nil)
	set.alarms[1].nextChirp = 0
	set:Step()
	check("map not in play: no chirp", mA:GetAttribute("ChirpAt") == nil)
	live = true
	set:Step()
	check("map in play again: chirps", mA:GetAttribute("ChirpAt") ~= nil)

	-- the steam fill switched off must not switch the alarm's listener rule off (the hook sits before Fill's gate)
	if SteamMask.FillMuffled then
		local Steam = require(box.Config.ShootableConfig).Steam
		local was = Steam.Fill and Steam.Fill.Enabled
		set:Hit(A + Vector3.new(-20, -9, 0), A + Vector3.new(0.3, 0.2, 0))
		if Steam.Fill then Steam.Fill.Enabled = false end
		check("Fill off: listener in the blare still muffles (AI)", SteamMask.Muffled(A + Vector3.new(60, -10, 0), floorNear))
		check("Fill off: walker in the blare still masked", SteamMask.IsMasked(floorNear))
		if Steam.Fill then Steam.Fill.Enabled = was end
		set:Reset()
	end

	-- Destroy: untagged, no more chirps
	set:Destroy(); setB:Destroy()
	check("destroy: untagged", not mA:HasTag(SmokeAlarm.TAG) and set.conn.Connected == false)
	world:Destroy()
end)
box:Destroy()
if not ok then table.insert(fails, "ERROR " .. tostring(err)) end
local failed = #fails - (ok and 0 or 1)
return ("SMOKEALARM tests: %d/%d%s"):format(results - failed, results, #fails > 0 and ("\nFAIL " .. table.concat(fails, "\nFAIL ")) or "")
