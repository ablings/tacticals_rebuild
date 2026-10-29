-- fix/house_illusion.lua [ILLUSION] 2026-10-29: the world outside House's windows (companion installer to fix/map_house.lua;
-- run AFTER it and after fix/map_sky.lua). Edward: "the house map looks like a floating object from the windows inside the
-- house ... make it feel like a complete map outside the windows when it actually isn't".
-- Why each piece (vault 03 Map Building/Backdrops and World Illusion.md): the 1965 exterior stopped at an 1800-stud ground square
-- with low wedge mesas that read as roofs, an empty plain between the near houses and the edge, and the place's blue sky; from
-- the upper windows the town looked like an object on a table.
-- Builds (art only: Anchored, CanCollide / CanQuery / CanTouch off; nothing touches collision proxies, barriers, doors, windows,
-- spawns or lights):
--   1. ServerStorage.HouseIllusionKit from the Import 3D models X_Far / X_Near / X_Mid (art/house/illusion, modeler 2026-10-29),
--      once; K_ScaleCube / K_Marker parked in ServerStorage._HouseIllusionImport (UNDO).
--   2. HouseExterior.Illusion_Near: front porch + canopy, back stoop, driveway, gravel strip at the house foot (plan place).
--   3. ServerStorage.MapBackdrops.HouseFarField (attribute MapBackdrop): the mid field (test-town houses, water tower, hangar,
--      bunkers, viewing stand, chain-link, pole lines, CastShadow off) and the far field (ground skirt to r 4,000 + three mesa
--      tiers to r 3,400). fix/map_sky.lua moves it into Workspace only while House is the loaded map (it would otherwise sit
--      round Arena / the Warehouses).
--   4. The v2 wedge mesas (Ext_Mesas_MesaRock, r 470-800) hidden (Transparency 1, HiddenReason): the new tiers replace them.
--   5. House's MapInfo (DuelMaps.House, or StagingMaps.House): Lighting.Sky (our six faces) + the tuned Atmosphere, and
--      Backdrop = { "HouseFarField" }. Edits the current source (other installers' lines kept); the original Atmosphere line is kept in attribute Illusion_OrigAtmo (UNDO).
-- Idempotent (rebuilds 2-5 each run). UNDO removes 2, 3 and 5's edit, shows 4 again, puts the kit's imports back in Workspace.
local UNDO = false --@UNDO

local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local ORIGIN = Vector3.new(-650, 1.2, -450) -- = fix/map_house.lua ORIGIN (live spot); plan (x, y, z) -> world ORIGIN + (x, z, -y)
local YAW = math.pi -- Import 3D lands plan geometry at Studio (-x, z, y): turned 180 degrees about the plan origin (as H_Exterior)
local GROUND_Y = ORIGIN.Y - 1 -- the v2 desert ground (plan z -1)

-- the sky (art/house/sky/make_sky.py) and the atmosphere tuned on the window captures (notes/house_build.md "Illusion pass")
local SKY = {
	SkyboxBk = "rbxassetid://102446141162442", SkyboxDn = "rbxassetid://113972147749161", SkyboxFt = "rbxassetid://122853852962734", --@SKYIDS1
	SkyboxLf = "rbxassetid://80899676313805", SkyboxRt = "rbxassetid://92696806015951", SkyboxUp = "rbxassetid://116963117272298", --@SKYIDS2
	CelestialBodiesShown = true, SunAngularSize = 9, MoonAngularSize = 7, StarCount = 0,
}
local ATMO = { Density = 0.25, Offset = 0.3, Haze = 0.7, Glare = 0.3, Color = { 222, 198, 158 }, Decay = { 150, 120, 90 } } --@ATMO
-- (r3: Color was 214,196,166; the horizon band read 13 less red / 15 more blue than the far ground)

-- each piece's average texture colour (art/house/illusion/house_illusion.json fallback_rgb): shows while textures load
local FALLBACK = {
	["X_BackStoop_Concrete65"] = {155, 148, 136},
	["X_BackStoop_Props"] = {66, 52, 40},
	["X_Bunker"] = {142, 136, 121},
	["X_ChainLink"] = {168, 169, 162},
	["X_Driveway"] = {151, 145, 132},
	["X_FoundationStrip_Gravel65"] = {117, 109, 96},
	["X_Mesa1_01"] = {175, 134, 99},
	["X_Mesa1_02"] = {173, 133, 98},
	["X_Mesa1_03"] = {175, 135, 101},
	["X_Mesa1_04"] = {173, 133, 99},
	["X_Mesa1_05"] = {174, 134, 100},
	["X_Mesa1_06"] = {175, 134, 99},
	["X_Mesa1_07"] = {174, 134, 100},
	["X_Mesa1_08"] = {173, 134, 101},
	["X_Mesa1_09"] = {175, 133, 98},
	["X_Mesa1_10"] = {174, 135, 100},
	["X_Mesa1_11"] = {172, 133, 100},
	["X_Mesa1_12"] = {175, 134, 100},
	["X_Mesa2_01"] = {194, 169, 139},
	["X_Mesa2_02"] = {194, 169, 139},
	["X_Mesa2_03"] = {195, 169, 139},
	["X_Mesa2_04"] = {196, 170, 140},
	["X_Mesa2_05"] = {196, 170, 140},
	["X_Mesa2_06"] = {194, 169, 139},
	["X_Mesa2_07"] = {195, 169, 140},
	["X_Mesa2_08"] = {194, 169, 139},
	["X_Mesa2_09"] = {195, 169, 139},
	["X_Mesa2_10"] = {195, 170, 140},
	["X_Mesa2_11"] = {196, 171, 140},
	["X_Mesa2_12"] = {196, 171, 140},
	["X_Mesa3_01"] = {208, 191, 165},
	["X_Mesa3_02"] = {209, 192, 166},
	["X_Mesa3_03"] = {209, 192, 165},
	["X_Mesa3_04"] = {208, 192, 165},
	["X_Mesa3_05"] = {209, 192, 165},
	["X_Mesa3_06"] = {208, 191, 165},
	["X_Mesa3_07"] = {208, 191, 165},
	["X_Mesa3_08"] = {209, 192, 165},
	["X_Mesa3_09"] = {208, 191, 165},
	["X_Mesa3_10"] = {208, 192, 165},
	["X_Mesa3_11"] = {209, 192, 165},
	["X_Mesa3_12"] = {208, 191, 165},
	["X_ObservationStand"] = {132, 124, 109},
	["X_PoleLine"] = {81, 72, 58},
	["X_PorchFront_Concrete65"] = {156, 150, 138},
	["X_PorchFront_Shingle"] = {93, 86, 77},
	["X_PorchFront_TrimWhite"] = {212, 208, 193},
	["X_Quonset"] = {135, 132, 116},
	["X_Skirt_1_01"] = {200, 177, 137},
	["X_Skirt_1_02"] = {200, 177, 137},
	["X_Skirt_1_03"] = {200, 177, 137},
	["X_Skirt_1_04"] = {200, 177, 137},
	["X_Skirt_1_05"] = {200, 177, 137},
	["X_Skirt_1_06"] = {200, 177, 137},
	["X_Skirt_1_07"] = {200, 177, 137},
	["X_Skirt_1_08"] = {200, 177, 137},
	["X_Skirt_2_01"] = {208, 190, 157},
	["X_Skirt_2_02"] = {209, 190, 158},
	["X_Skirt_2_03"] = {209, 190, 158},
	["X_Skirt_2_04"] = {208, 190, 157},
	["X_Skirt_2_05"] = {208, 190, 157},
	["X_Skirt_2_06"] = {209, 190, 158},
	["X_Skirt_2_07"] = {209, 190, 158},
	["X_Skirt_2_08"] = {208, 190, 157},
	["X_Skirt_2_09"] = {208, 190, 157},
	["X_Skirt_2_10"] = {209, 190, 158},
	["X_Skirt_2_11"] = {209, 190, 158},
	["X_Skirt_2_12"] = {208, 190, 157},
	["X_Skirt_2_13"] = {208, 190, 157},
	["X_Skirt_2_14"] = {209, 190, 158},
	["X_Skirt_2_15"] = {209, 190, 158},
	["X_Skirt_2_16"] = {208, 190, 157},
	["X_Skirt_3_01"] = {213, 195, 165},
	["X_Skirt_3_02"] = {213, 195, 165},
	["X_Skirt_3_03"] = {213, 195, 165},
	["X_Skirt_3_04"] = {213, 195, 165},
	["X_Skirt_3_05"] = {213, 195, 165},
	["X_Skirt_3_06"] = {213, 195, 165},
	["X_Skirt_3_07"] = {213, 195, 165},
	["X_Skirt_3_08"] = {213, 195, 165},
	["X_Skirt_3_09"] = {213, 195, 165},
	["X_Skirt_3_10"] = {213, 195, 165},
	["X_Skirt_3_11"] = {213, 195, 165},
	["X_Skirt_3_12"] = {213, 195, 165},
	["X_Skirt_3_13"] = {213, 195, 165},
	["X_Skirt_3_14"] = {213, 195, 165},
	["X_Skirt_3_15"] = {213, 195, 165},
	["X_Skirt_3_16"] = {213, 195, 165},
	["X_TownHouse_A_Butter"] = {165, 154, 129},
	["X_TownHouse_A_Mint"] = {152, 153, 136},
	["X_TownHouse_A_Salmon"] = {161, 149, 134},
	["X_TownHouse_A_White"] = {160, 153, 137},
	["X_TownHouse_B_Butter"] = {169, 158, 127},
	["X_TownHouse_B_Mint"] = {150, 155, 137},
	["X_TownHouse_B_Salmon"] = {164, 146, 130},
	["X_TownHouse_B_White"] = {164, 157, 142},
	["X_WaterTower"] = {164, 160, 149},
}

local out = {}
local function say(s) table.insert(out, s) end
local function folder(parent, name)
	local f = parent:FindFirstChild(name)
	if not f then f = Instance.new("Folder"); f.Name = name; f.Parent = parent end
	return f
end
local function artFlags(inst, shadow)
	local list = inst:GetDescendants(); if inst:IsA("BasePart") then table.insert(list, inst) end
	for _, d in list do
		if d:IsA("BasePart") then
			d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false
			d.CastShadow = shadow and true or false
			d.Massless = true
		end
	end
end

-- ===================================================================================================== 1. kit from the imports
local kit = SS:FindFirstChild("HouseIllusionKit")
local park = SS:FindFirstChild("_HouseIllusionImport")
if UNDO then
	if kit then for _, m in kit:GetChildren() do m.Parent = workspace end kit:Destroy() end
	if park then for _, p in park:GetChildren() do local home = workspace:FindFirstChild(p:GetAttribute("From") or "") if home then p.Parent = home end end park:Destroy() end
else
	for _, n in { "X_Far", "X_Near", "X_Mid" } do
		local m = workspace:FindFirstChild(n)
		if m and m:IsA("Model") then
			kit = kit or folder(SS, "HouseIllusionKit")
			park = park or folder(SS, "_HouseIllusionImport")
			local old = kit:FindFirstChild(n); if old then old.Parent = park; old.Name = n .. "_old" end
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") and (d.Name == "K_ScaleCube" or d.Name == "K_Marker") then
					d:SetAttribute("From", n); d.Name = n .. "_" .. d.Name; d.Parent = park
				end
			end
			for _, d in m:GetDescendants() do
				if d:IsA("MeshPart") then
					local c = FALLBACK[d.Name]
					if c then d.Color = Color3.fromRGB(c[1], c[2], c[3]) end
					-- an alpha card: Import 3D's TextureID ignores alpha, so the image moves into a SurfaceAppearance (proof check B10)
					if d.Name == "X_ChainLink" and d.TextureID ~= "" and not d:FindFirstChildOfClass("SurfaceAppearance") then
						local sa = Instance.new("SurfaceAppearance"); sa.ColorMap = d.TextureID; sa.AlphaMode = Enum.AlphaMode.Transparency
						sa.Parent = d; d.TextureID = ""
					end
				end
			end
			artFlags(m, false)
			m.Parent = kit
			say("kit " .. n .. " from Workspace")
		end
	end
	assert(kit and kit:FindFirstChild("X_Far") and kit:FindFirstChild("X_Near") and kit:FindFirstChild("X_Mid"),
		"house_illusion: no ServerStorage.HouseIllusionKit (import art/house/illusion/fbx/X_*.fbx first: scale 0.01, gunsy funsy)")
end

-- ===================================================================================================== 2-4. placement
local ext = workspace:FindFirstChild("HouseExterior")
local staged = SS:FindFirstChild("StagingMaps") and SS.StagingMaps:FindFirstChild("House")
if not ext and staged then ext = staged:FindFirstChild("HouseExterior", true) end
assert(ext, "house_illusion: no HouseExterior (run fix/map_house.lua first)")
local oldNear = ext:FindFirstChild("Illusion_Near"); if oldNear then oldNear:Destroy() end
local store = folder(SS, "MapBackdrops")
local oldFar = store:FindFirstChild("HouseFarField") or workspace:FindFirstChild("HouseFarField")
if oldFar then oldFar:Destroy() end
for _, d in ext:GetDescendants() do
	if d:IsA("BasePart") and d.Name:match("^Ext_Mesas_") then
		if UNDO then
			if d:GetAttribute("HiddenReason") == "illusion: replaced by the far mesa tiers" then d.Transparency = 0; d:SetAttribute("HiddenReason", nil) end
		else
			d.Transparency = 1; d.CastShadow = false; d:SetAttribute("HiddenReason", "illusion: replaced by the far mesa tiers")
		end
	end
end

for _, d in ext:GetDescendants() do
	if d:IsA("MeshPart") and d.Name:match("^Mast_") then
		d.RenderFidelity = UNDO and Enum.RenderFidelity.Automatic or Enum.RenderFidelity.Precise
		-- round 3 (grade r2): graphics quality 1 draws normal-size parts only to ~250 studs; the masts stood at ~362 and vanished.
		-- Moved in along their own bearing to ~245 (plan), still framed by the same windows; the v2 spot is kept for UNDO.
		local MOVE = { Mast_South = Vector2.new(36, -240), Mast_NE = Vector2.new(178, 170) }
		local to = MOVE[d.Name]
		if to then
			local orig = d:GetAttribute("Illusion_OrigCF")
			if UNDO then
				if orig then d.CFrame = orig; d:SetAttribute("Illusion_OrigCF", nil) end
			else
				if not orig then d:SetAttribute("Illusion_OrigCF", d.CFrame); orig = d.CFrame end
				d.CFrame = orig.Rotation + Vector3.new(ORIGIN.X + to.X, orig.Position.Y, ORIGIN.Z - to.Y)
			end
		end
	elseif d:IsA("BasePart") and d.Name == "Dummy_Ext_Fence" then
		if UNDO then
			if d:GetAttribute("HiddenReason") == "illusion: in spawn A's first look" then d.Transparency = 0; d:SetAttribute("HiddenReason", nil) end
		else
			d.Transparency = 1; d.CastShadow = false; d:SetAttribute("HiddenReason", "illusion: in spawn A's first look")
		end
	end
end

-- 5 (UNDO side first, so UNDO can return before building)
local function mapInfos()
	local t = {}
	local dm = RS:FindFirstChild("DuelMaps")
	if dm and dm:FindFirstChild("House") and dm.House:FindFirstChild("MapInfo") then table.insert(t, dm.House.MapInfo) end
	if staged and staged:FindFirstChild("MapInfo") then table.insert(t, staged.MapInfo) end
	return t
end
if UNDO then
	for _, mi in mapInfos() do
		local src = mi.Source:gsub("[^\n]*%-%- %[ILLUSION%][^\n]*\n", "")
		local o = mi:GetAttribute("Illusion_OrigAtmo")
		if o then src = src:gsub("\t\tAtmosphere = %b{},", function() return o end, 1) end
		mi.Source = src
		mi:SetAttribute("Illusion_OrigAtmo", nil); mi:SetAttribute("Illusion_OrigSource", nil)
	end
	return "UNDO: Illusion_Near, HouseFarField, MapInfo edit removed; v2 mesas shown; imports back in Workspace"
end

local place = CFrame.new(ORIGIN) * CFrame.Angles(0, YAW, 0)
local near = kit.X_Near:Clone()
near.Name = "Illusion_Near"
near:PivotTo(place)
artFlags(near, true)
near.Parent = ext

local farField = Instance.new("Model")
farField.Name = "HouseFarField"
farField:SetAttribute("MapBackdrop", true)
farField:SetAttribute("Builder", "house_illusion")
farField:SetAttribute("Indoor", false) -- outdoor set: MapAudit SKY knows what it is (grade r1)
local far = kit.X_Far:Clone()
far.Name = "Far"
far:PivotTo(place)
artFlags(far, false)
far.Parent = farField

-- mid field: plan (x, y) of each piece's bottom centre, the way its front (Studio -Z of the piece) faces
local FACE = { N = 0, S = math.pi, E = -math.pi / 2, W = math.pi / 2 }
local MID = {
	-- test town: a westward street off the cul-de-sac (y -68), an east cross street, a row behind, two south of the houses across
	{ "X_TownHouse_A_Butter", -175, -28, "S" }, { "X_TownHouse_B_White", -240, -30, "S" }, { "X_TownHouse_A_Mint", -305, -27, "S" },
	{ "X_TownHouse_B_Salmon", -372, -30, "S" },
	{ "X_TownHouse_B_Mint", -185, -112, "N" }, { "X_TownHouse_A_White", -252, -110, "N" }, { "X_TownHouse_A_Salmon", -318, -112, "N" },
	{ "X_TownHouse_B_Butter", -388, -110, "N" },
	{ "X_TownHouse_A_Salmon", 185, 58, "S" }, { "X_TownHouse_B_Mint", 252, 60, "S" }, { "X_TownHouse_A_White", 320, 57, "S" },
	{ "X_TownHouse_B_Butter", 190, -18, "N" }, { "X_TownHouse_A_Mint", 258, -20, "N" }, { "X_TownHouse_B_White", 326, -18, "N" },
	{ "X_TownHouse_B_Salmon", -165, 198, "S" }, { "X_TownHouse_A_Butter", -95, 205, "S" }, { "X_TownHouse_B_White", -25, 200, "S" },
	{ "X_TownHouse_A_Mint", 110, 195, "S" },
	{ "X_TownHouse_A_White", -190, -215, "N" }, { "X_TownHouse_B_Butter", -122, -222, "N" },
	-- the test site round the town
	{ "X_WaterTower", 60, 262, "S" } --[[ r3: was (70, 430): culled at quality 1 past ~250 ]], { "X_Quonset", 360, 175, "W" },
	{ "X_Bunker", 185, -300, "N" }, { "X_Bunker", -265, -335, "E" }, { "X_Bunker", 300, -218, "W" }, { "X_Bunker", -455, 150, "E" },
	{ "X_ObservationStand", 250, -380, "S" }, -- (grade r1: at 125,-445 it stood half inside the Arena wall)
	{ "X_ChainLink", 185, -265, "N" }, { "X_ChainLink", 185, -335, "N" }, { "X_ChainLink", 150, -300, "E" }, { "X_ChainLink", 220, -300, "E" },
	{ "X_ChainLink", 330, 225, "N" }, { "X_ChainLink", 390, 225, "N" },
	-- round 2: the west plain read empty from BR3_W / LR_W (a flat floor straight to the buttes)
	{ "X_TownHouse_A_Mint", -455, -27, "S" }, { "X_TownHouse_B_White", -520, -112, "N" }, { "X_TownHouse_B_Salmon", -250, 85, "S" },
	{ "X_TownHouse_A_Butter", -320, 80, "S" }, { "X_Quonset", -580, 45, "E" }, { "X_ChainLink", -540, 100, "N" }, { "X_ChainLink", -600, 100, "N" },
	{ "X_Bunker", -660, -150, "E" }, { "X_ObservationStand", -420, 320, "W" }, { "X_PoleLine", -500, 230, "E" },
	-- round 3 (grade r1): blockers on the sight lines to the other maps of the place. Two hangars in front of the Arena's north
	-- wall (plan -27..127, -393..-507); two nearer buttes (far-tier mesas scaled down, { size, kit "X_Far" }) between the house and
	-- Warehouse / Warehouse 2 (plan ~ 480..660, 0..-520; Warehouse2Exterior is 62 tall)
	{ "X_Quonset", 10, -320, "E" }, { "X_Quonset", 91.3, -322, "E" }, { "X_TownHouse_B_White", 300, -120, "W" }, -- (r3: 9-stud gap between the hangars: now butted; a big hangar between the near butte's two rock masses)
	{ "X_Mesa1_03", 440, -120, "E", Vector3.new(330, 100, 130), "X_Far" }, { "X_Mesa1_08", 440, -400, "E", Vector3.new(320, 80, 140), "X_Far" },
	{ "X_Quonset", 372, -145, "N", Vector3.new(68, 46, 124), nil, "fills a butte gap" },
	{ "X_Mesa1_11", 470, -78, "E", Vector3.new(70, 22, 55), "X_Far", "low rock at the near butte's foot (r3: a shed showed past it from the glass)" }, -- a big aircraft hangar in the gap between the near butte's two rock masses
	-- pole lines running out to the horizon (the piece's 8 poles lie along its local X)
	{ "X_PoleLine", 425, 130, "N" }, { "X_PoleLine", -485, -76, "N" }, { "X_PoleLine", 30, 385, "E" }, { "X_PoleLine", -60, -405, "E" },
}
local mid = Instance.new("Model"); mid.Name = "Mid"; mid.Parent = farField
local boxes, clashes = {}, {}
for i, e in MID do
	local src = kit[e[6] or "X_Mid"]:FindFirstChild(e[1], true)
	if not src then say("mid: no " .. e[1]) continue end
	local p = src:Clone()
	p.Name = e[1] .. "_" .. i
	local yaw = FACE[e[4]]
	-- bottom 0.3 into the ground so nothing floats on the slight skirt / ground seam
	if e[5] then p.Size = e[5] end
	-- landmarks and big silhouettes keep their full mesh at graphics quality 1 (grade r1: the masts and the water tower vanished)
	if p.Name:match("^X_WaterTower") or p.Name:match("^X_Quonset") or p.Name:match("^X_Mesa") then p.RenderFidelity = Enum.RenderFidelity.Precise end
	-- bottom 0.3 into the ground (a scaled butte 3: its base is uneven) so nothing floats on the slight skirt / ground seam
	local sink = e[6] == "X_Far" and 3 or 0.3
	p.CFrame = CFrame.new(ORIGIN.X + e[2], GROUND_Y - sink + p.Size.Y / 2, ORIGIN.Z - e[3]) * CFrame.Angles(0, yaw, 0)
	p.Parent = mid
	local turned = (e[4] == "E" or e[4] == "W")
	local hx, hy = (turned and p.Size.Z or p.Size.X) / 2, (turned and p.Size.X or p.Size.Z) / 2
	local b = { e[2] - hx, e[3] - hy, e[2] + hx, e[3] + hy, p.Name, e[7] } -- e[7]: a deliberate fill inside a butte's box (its two rock masses leave a gap)
	for _, o in boxes do
		if b[1] < o[3] and o[1] < b[3] and b[2] < o[4] and o[2] < b[4] and not (p.Name:match("ChainLink") or o[5]:match("ChainLink")) and not ((p.Name:match("^X_Mesa") or e[7]) and (o[5]:match("^X_Mesa") or o[6])) then -- buttes may merge into one landform
			table.insert(clashes, b[5] .. " x " .. o[5])
		end
	end
	table.insert(boxes, b)
end
-- the existing exterior's footprint (plan, from the v2 set): nothing of the mid field may stand in it
local core = { -125, -150, 125, 130 }
for _, b in boxes do
	if b[1] < core[3] and core[1] < b[3] and b[2] < core[4] and core[2] < b[4] then table.insert(clashes, b[5] .. " x v2 town") end
end
artFlags(farField, false)
farField.Parent = store

-- 5. MapInfo: sky, atmosphere, backdrop
local function c3(t) return ("Color3.fromRGB(%d, %d, %d)"):format(t[1], t[2], t[3]) end
local skyParts = {}
for _, k in { "SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp" } do table.insert(skyParts, ("%s = %q"):format(k, SKY[k])) end
local skyLine = ("\t\tSky = { %s, CelestialBodiesShown = %s, SunAngularSize = %s, MoonAngularSize = %s, StarCount = %s }, -- [ILLUSION] fix/house_illusion.lua\n")
	:format(table.concat(skyParts, ", "), tostring(SKY.CelestialBodiesShown), SKY.SunAngularSize, SKY.MoonAngularSize, SKY.StarCount)
local atmoLine = ("\t\tAtmosphere = { Density = %s, Offset = %s, Haze = %s, Glare = %s, Color = %s, Decay = %s },")
	:format(ATMO.Density, ATMO.Offset, ATMO.Haze, ATMO.Glare, c3(ATMO.Color), c3(ATMO.Decay))
local nInfo = 0
for _, mi in mapInfos() do
	-- edit the CURRENT source (other installers edit MapInfo too, e.g. fix/house_wallcover.lua's WallCover line): drop this
	-- installer's own [ILLUSION] lines, keep the original Atmosphere line once (attribute Illusion_OrigAtmo) for UNDO
	local first = mi:GetAttribute("Illusion_OrigSource") or mi.Source -- (round-1 copies stored the whole source)
	if not mi:GetAttribute("Illusion_OrigAtmo") then
		local a = first:match("\t\tAtmosphere = %b{},")
		assert(a, "house_illusion: MapInfo has no Atmosphere line")
		mi:SetAttribute("Illusion_OrigAtmo", a)
	end
	mi:SetAttribute("Illusion_OrigSource", nil)
	local src = mi.Source:gsub("[^\n]*%-%- %[ILLUSION%][^\n]*\n", "")
	local s, n1 = src:gsub("\t\tAtmosphere = %b{},", function() return atmoLine end, 1)
	assert(n1 == 1, "house_illusion: MapInfo has no Atmosphere line")
	local n2
	s, n2 = s:gsub("(\t\tBloom = %b{},\n)", "%1" .. skyLine:gsub("%%", "%%%%"), 1)
	assert(n2 == 1, "house_illusion: MapInfo has no Bloom line")
	local n3
	s, n3 = s:gsub("(\tDynamic = %b{},\n)", "%1\tBackdrop = { \"HouseFarField\" }, -- [ILLUSION] far + mid field, in Workspace only while House is loaded\n\tHide = { \"Baseplate\", \"R15\", \"AnimRig\" }, -- [ILLUSION] look only, while House is loaded: the place floor drew a grey line at the horizon (fix/map_sky.lua)\n", 1)
	assert(n3 == 1, "house_illusion: MapInfo has no Dynamic line")
	assert(loadstring(s), "house_illusion: MapInfo would not parse")
	mi.Source = s
	nInfo += 1
end

local tris = 0 -- (counted from the manifest by the build log, not here)
local nMid = #mid:GetChildren()
local nFar = 0 for _, d in far:GetDescendants() do if d:IsA("BasePart") then nFar += 1 end end
local nNear = 0 for _, d in near:GetDescendants() do if d:IsA("BasePart") then nNear += 1 end end
say(("near %d parts in HouseExterior.Illusion_Near; far %d + mid %d in ServerStorage.MapBackdrops.HouseFarField; MapInfo edited %d; sky %s")
	:format(nNear, nFar, nMid, nInfo, SKY.SkyboxUp:match("://0$") and "NOT SET (ids 0)" or "set"))
if #clashes > 0 then say("MID CLASHES: " .. table.concat(clashes, "; ")) else say("mid field: 0 footprint clashes") end
return table.concat(out, "\n")
