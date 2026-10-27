-- fix/steam_fill_tests.lua [STEAMFILL] unit tests for SteamMask (the rules module of the steam fill). Edit mode, any match place
-- with fix/steam_fill.lua installed. Runs on FRESH module instances (clones in a temp folder: Studio's plugin VM caches require per
-- instance), on fake valves 2000 studs up (nothing in the map is touched), and removes everything after. Returns "N/N passed".
local RS = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local tmp = Instance.new("Folder")
tmp.Name = "_SteamFillTest"
local cfgFolder = Instance.new("Folder")
cfgFolder.Name = "Config"
cfgFolder.Parent = tmp
RS.Modules.Shared.Config.ShootableConfig:Clone().Parent = cfgFolder
local maskModule = RS.Modules.Shared.SteamMask:Clone()
maskModule.Parent = tmp
tmp.Parent = RS
local world = Instance.new("Folder")
world.Name = "_SteamFillTestWorld"
world.Parent = workspace

local results, passed, total = {}, 0, 0
local function check(name: string, ok: boolean, detail: any?)
	total += 1
	if ok then passed += 1 else table.insert(results, "FAIL " .. name .. (detail ~= nil and (" (" .. tostring(detail) .. ")") or "")) end
end
local function near(a: number, b: number, eps: number?) return math.abs(a - b) <= (eps or 0.05) end

local ok, err = pcall(function()
	local mask = require(maskModule)
	local Steam = require(cfgFolder.ShootableConfig).Steam
	local F = Steam.Fill
	check("config has Fill", type(F) == "table" and F.MaskRadius ~= nil)
	local BASE = Vector3.new(5000, 2000, 5000)

	local function part(name, size, pos, parent)
		local p = Instance.new("Part")
		p.Name, p.Size, p.Position, p.Anchored = name, size, pos, true
		p.Parent = parent
		return p
	end
	-- a map: floor, a long wall 10 studs east of the valve's cloud centre, a crate 8 studs north (the steam rolls round it)
	local function makeMap(name: string, fill: boolean?, origin: Vector3)
		local m = Instance.new("Model")
		m.Name = name
		if fill ~= nil then m:SetAttribute("SteamFill", fill) end
		local col = Instance.new("Folder")
		col.Name = "CollisionProxies"
		col.Parent = m
		part("COLP_Floor", Vector3.new(200, 1, 200), origin + Vector3.new(0, -0.5, 0), col)
		local sh = Instance.new("Folder")
		sh.Name = "Shootables"
		sh.Parent = m
		local v = Instance.new("Model")
		v.Name = "SteamValve_T"
		-- valve on a west-facing... the jet points +X (wheel east of the body); cloud centre = body + 0.7 + 3 studs east
		part("ValveBody", Vector3.new(1, 1, 1), origin + Vector3.new(0, 4, 0), v)
		part("Wheel", Vector3.new(0.3, 1.2, 1.2), origin + Vector3.new(0.8, 4, 0), v)
		v.Parent = sh
		m.Parent = world
		CollectionService:AddTag(v, "SteamValve")
		return m, v, col
	end

	-- 1. classic valve (map without SteamFill): today's numbers
	local _, classic = makeMap("Classic", nil, BASE)
	local now = workspace:GetServerTimeNow()
	check("classic: FillOf nil", mask.FillOf(classic) == nil)
	classic:SetAttribute("SteamUntil", now + 5)
	check("classic: radius = MaskRadius", mask.Radius(classic, now) == Steam.MaskRadius, mask.Radius(classic, now))
	local at = classic:GetPivot().Position
	check("classic: masked inside", mask.IsMasked(at + Vector3.new(Steam.MaskRadius - 1, 30, 0)))
	check("classic: not masked outside", not mask.IsMasked(at + Vector3.new(Steam.MaskRadius + 1, 0, 0)))
	check("classic: radius 0 after the hiss", mask.Radius(classic, now + 5.01) == 0)
	classic:SetAttribute("SteamUntil", now - 0.1)
	check("classic: not masked after the hiss (no fade)", not mask.IsMasked(at + Vector3.new(1, 0, 0)))
	classic:SetAttribute("SteamUntil", nil)

	-- 2. fill valve: growth, hold, fade, end
	local FILL_AT = BASE + Vector3.new(0, 0, 400)
	local fillMap, fv, col = makeMap("Fill", true, FILL_AT)
	part("Wall", Vector3.new(1, 20, 60), FILL_AT + Vector3.new(3.7 + 10, 10, 0), col)        -- long: stops the steam
	part("Crate", Vector3.new(4, 7, 4), FILL_AT + Vector3.new(3.7, 3.5, 8), col)             -- short: rolls round it
	check("fill: FillOf", mask.FillOf(fv) == F)
	local t0 = 1000
	fv:SetAttribute("SteamAt", t0)
	fv:SetAttribute("SteamUntil", t0 + F.Duration)
	check("fill: start radius", near(mask.Radius(fv, t0), F.MaskStartRadius), mask.Radius(fv, t0))
	local half = F.MaskStartRadius + (F.MaskRadius - F.MaskStartRadius) * 0.75
	check("fill: half-grown radius (ease-out)", near(mask.Radius(fv, t0 + F.GrowTime / 2), half), mask.Radius(fv, t0 + F.GrowTime / 2))
	check("fill: full radius", near(mask.Radius(fv, t0 + F.GrowTime), F.MaskRadius))
	check("fill: holds while hissing", near(mask.Radius(fv, t0 + F.Duration), F.MaskRadius))
	check("fill: covers the whole cloud while it fades", near(mask.Radius(fv, t0 + F.Duration + F.FadeTime - 0.05), F.MaskRadius), mask.Radius(fv, t0 + F.Duration + F.FadeTime - 0.05))
	check("fill: ends with the fade", mask.Radius(fv, t0 + F.Duration + F.FadeTime + 0.01) == 0)
	check("fill: nothing before it starts", mask.Radius(fv, t0 - 1) == 0)
	-- no SteamAt (an older server): start = SteamUntil - Duration
	fv:SetAttribute("SteamAt", nil)
	check("fill: SteamAt fallback", near(mask.Radius(fv, t0), F.MaskStartRadius))

	-- 3. the reach fan: walls stop it, cover doesn't
	now = workspace:GetServerTimeNow()
	fv:SetAttribute("SteamAt", now - F.GrowTime - 0.5)
	fv:SetAttribute("SteamUntil", now + 3)
	local fan = mask.Fan(fv)
	check("fan built", fan ~= nil)
	local centre = fan.centre
	local east = mask.ReachAt(fan, centre + Vector3.new(5, 0, 0))
	check("fan: wall clamps east", near(east, 10 - 0.5 - F.WallPad, 0.6), east)
	local north = mask.ReachAt(fan, centre + Vector3.new(0, 0, 5))
	check("fan: crate does not clamp north", near(north, F.Radius, 0.01), north)
	check("fan: floor found", near(fan.floorY, FILL_AT.Y, 0.01), fan.floorY)
	local floorPos = Vector3.new(centre.X, fan.floorY + 3, centre.Z)
	check("fill: masked 20 studs west", mask.IsMasked(floorPos + Vector3.new(-20, 0, 0)))
	check("fill: masked behind the crate", mask.IsMasked(floorPos + Vector3.new(0, 0, 14)))
	check("fill: not masked past the wall", not mask.IsMasked(floorPos + Vector3.new(15, 0, 0)))
	check("fill: not masked on a floor above", not mask.IsMasked(floorPos + Vector3.new(-5, F.MaskHeight + 2, 0)))
	check("fill: not masked beyond MaskRadius", not mask.IsMasked(floorPos + Vector3.new(-(F.MaskRadius + 1), 0, 0)))
	-- the fan is rebuilt for a new activation (a door opened in between counts from then)
	local before = mask.Fan(fv)
	fv:SetAttribute("SteamAt", now - F.GrowTime - 0.4)
	check("fan: rebuilt per activation", mask.Fan(fv) ~= before)

	-- 3b. a valve that carries SteamFill = true itself still finds its map's walls (the map is found by its role)
	fv:SetAttribute("SteamFill", true)
	fv:SetAttribute("SteamAt", now - F.GrowTime - 0.3)
	local own = mask.Fan(fv)
	check("valve-level SteamFill: wall still clamps", own and near(mask.ReachAt(own, own.centre + Vector3.new(5, 0, 0)), 10 - 0.5 - F.WallPad, 0.6),
		own and mask.ReachAt(own, own.centre + Vector3.new(5, 0, 0)))
	check("Inside = IsMasked", mask.Inside(fv, F, floorPos + Vector3.new(-20, 0, 0), now) == mask.IsMasked(floorPos + Vector3.new(-20, 0, 0)))
	fv:SetAttribute("SteamFill", nil)
	-- 4. one valve opted out on a fill map: classic
	fv:SetAttribute("SteamFill", false)
	check("opt-out: classic radius", mask.Radius(fv, now) == Steam.MaskRadius)
	fv:SetAttribute("SteamFill", nil)
	-- 5. Fill switched off in the config: classic everywhere
	F.Enabled = false
	check("Fill.Enabled = false: classic", mask.FillOf(fv) == nil and mask.Radius(fv, now) == Steam.MaskRadius)
	F.Enabled = true
	-- 6. reset (attributes cleared): nothing masked, radius 0
	fv:SetAttribute("SteamAt", nil)
	fv:SetAttribute("SteamUntil", nil)
	check("reset: radius 0", mask.Radius(fv, now) == 0)
	check("reset: not masked", not mask.IsMasked(floorPos))
	local _ = fillMap
end)
if not ok then table.insert(results, "ERROR " .. tostring(err)) end
for _, d in world:GetDescendants() do if CollectionService:HasTag(d, "SteamValve") then CollectionService:RemoveTag(d, "SteamValve") end end
world:Destroy()
tmp:Destroy()
return ("%d/%d passed%s"):format(passed, total, #results > 0 and (" | " .. table.concat(results, " | ")) or "")
