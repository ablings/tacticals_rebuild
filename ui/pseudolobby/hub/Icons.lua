-- LobbyUIController/Icons (ModuleScript, required by LobbyUIController)
-- Live 3D icons for the lobby dock, rendered in ViewportFrames: the KIT icon is your equipped
-- gun at a viewmodel angle, the rest are small models built from parts (supply crate, mission
-- clipboard, settings gear, dog tags for codes). Swap any of them for a real model later by
-- returning it from a builder below.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Icons = {}

local function p(model, size, cf, color, mat, shape)
	local part = Instance.new("Part")
	part.Anchored = true
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = mat or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if shape then part.Shape = shape end
	part.Parent = model
	return part
end

-------------------------------------------------------------------------------
-- Builders: each returns a Model
-------------------------------------------------------------------------------
-- Meshes in ReplicatedStorage.LobbyAssets.Icons (Crate, Clipboard, Gear, DogTags) replace the
-- part-built fallbacks below. Drop a better model in with the same name to swap an icon.
local function asset(name: string): Model?
	local f = ReplicatedStorage:FindFirstChild("LobbyAssets")
	f = f and f:FindFirstChild("Icons")
	local m = f and f:FindFirstChild(name)
	if not m then return nil end
	local c = m:Clone()
	c:PivotTo(CFrame.identity) -- generated meshes carry a rotated pivot; this faces them toward the camera
	return c
end

function Icons.Weapon(weaponId: string)
	local m = Instance.new("Model")
	local src = ReplicatedStorage:FindFirstChild("Repository")
	src = src and src:FindFirstChild("Weapons")
	src = src and src:FindFirstChild(weaponId)
	if src then
		for _, d in src:GetDescendants() do
			if d:IsA("BasePart") then
				local c = d:Clone()
				c:ClearAllChildren()
				c.Anchored = true
				-- lift very dark gun metal a little so it reads on the dark dock
				c.Color = c.Color:Lerp(Color3.fromRGB(200, 205, 210), 0.25)
				c.Parent = m
			end
		end
	end
	if #m:GetChildren() == 0 then -- fallback silhouette
		p(m, Vector3.new(0.2, 0.25, 1), CFrame.new(0, 0.44, -0.2), Color3.fromRGB(30, 30, 32), Enum.Material.Metal)
		p(m, Vector3.new(0.2, 0.62, 0.3), CFrame.Angles(math.rad(-12), 0, 0), Color3.fromRGB(40, 40, 42))
	end
	return m
end

function Icons.Crate()
	local a = asset("Crate")
	if a then return a end
	local m = Instance.new("Model")
	local olive, dark, stencil = Color3.fromRGB(98, 108, 66), Color3.fromRGB(58, 64, 40), Color3.fromRGB(232, 190, 70)
	p(m, Vector3.new(2.4, 1.5, 1.5), CFrame.new(0, 0, 0), olive, Enum.Material.Metal)
	p(m, Vector3.new(2.5, 0.18, 1.6), CFrame.new(0, 0.8, 0), dark, Enum.Material.Metal)
	for _, x in { -0.85, 0.85 } do
		p(m, Vector3.new(0.18, 1.56, 1.56), CFrame.new(x, 0, 0), dark, Enum.Material.DiamondPlate)
	end
	p(m, Vector3.new(0.5, 0.12, 0.3), CFrame.new(0, 0.95, 0), Color3.fromRGB(40, 40, 42), Enum.Material.Metal)
	p(m, Vector3.new(1.2, 0.3, 0.02), CFrame.new(0, 0.1, -0.76), stencil)
	p(m, Vector3.new(0.9, 0.55, 0.5), CFrame.new(0.55, 1.15, 0.2) * CFrame.Angles(0, math.rad(20), 0), Color3.fromRGB(70, 76, 50), Enum.Material.Metal)
	return m
end

function Icons.Clipboard()
	local a = asset("Clipboard")
	if a then return a end
	local m = Instance.new("Model")
	p(m, Vector3.new(1.7, 2.3, 0.08), CFrame.new(0, 0, 0), Color3.fromRGB(96, 74, 50), Enum.Material.Wood)
	p(m, Vector3.new(1.45, 1.95, 0.02), CFrame.new(0, -0.08, -0.05), Color3.fromRGB(226, 222, 206))
	p(m, Vector3.new(0.8, 0.22, 0.14), CFrame.new(0, 1.08, -0.06), Color3.fromRGB(150, 152, 156), Enum.Material.Metal)
	for i = 0, 3 do
		local y = 0.62 - i * 0.42
		local done = i < 2
		p(m, Vector3.new(0.18, 0.18, 0.02), CFrame.new(-0.5, y, -0.07), done and Color3.fromRGB(90, 160, 70) or Color3.fromRGB(120, 120, 120))
		p(m, Vector3.new(0.8, 0.07, 0.02), CFrame.new(0.12, y, -0.07), Color3.fromRGB(70, 70, 72))
	end
	p(m, Vector3.new(0.7, 0.22, 0.02), CFrame.new(0.25, -0.88, -0.07) * CFrame.Angles(0, 0, math.rad(-12)), Color3.fromRGB(190, 50, 40))
	return m
end

function Icons.Gear()
	local a = asset("Gear")
	if a then return a end
	local m = Instance.new("Model")
	local steel, darker = Color3.fromRGB(150, 156, 164), Color3.fromRGB(96, 100, 108)
	local axis = CFrame.Angles(0, math.rad(90), 0) -- cylinder axis (X) -> towards the camera (Z)
	p(m, Vector3.new(0.4, 2, 2), axis, steel, Enum.Material.Metal, Enum.PartType.Cylinder)
	p(m, Vector3.new(0.44, 0.8, 0.8), axis, darker, Enum.Material.Metal, Enum.PartType.Cylinder)
	p(m, Vector3.new(0.46, 0.42, 0.42), axis, Color3.fromRGB(40, 42, 46), Enum.Material.Metal, Enum.PartType.Cylinder)
	for i = 0, 7 do
		p(m, Vector3.new(0.4, 0.4, 0.4), CFrame.Angles(0, 0, math.rad(i * 45)) * CFrame.new(0, 1.08, 0), steel, Enum.Material.Metal)
	end
	return m
end

function Icons.DogTags()
	local a = asset("DogTags")
	if a then return a end
	local m = Instance.new("Model")
	local tag = Color3.fromRGB(196, 200, 206)
	local function plate(cf)
		p(m, Vector3.new(1.1, 1.7, 0.06), cf, tag, Enum.Material.Metal)
		for _, s in { -1, 1 } do
			p(m, Vector3.new(0.06, 1.1, 1.1), cf * CFrame.new(0, s * 0.85, 0) * CFrame.Angles(0, math.rad(90), 0), tag, Enum.Material.Metal, Enum.PartType.Cylinder)
		end
		for i = 0, 2 do
			p(m, Vector3.new(0.7, 0.07, 0.02), cf * CFrame.new(0, 0.3 - i * 0.3, -0.04), Color3.fromRGB(110, 114, 120), Enum.Material.Metal)
		end
		p(m, Vector3.new(0.07, 0.16, 0.16), cf * CFrame.new(0, 1.15, 0) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(60, 60, 62), Enum.Material.Metal, Enum.PartType.Cylinder)
	end
	plate(CFrame.new(-0.25, -0.1, 0.15) * CFrame.Angles(0, 0, math.rad(12)))
	plate(CFrame.new(0.35, -0.25, -0.1) * CFrame.Angles(0, 0, math.rad(-10)))
	for i = 0, 9 do
		local t = i / 9
		p(m, Vector3.new(0.12, 0.12, 0.12), CFrame.new(-0.5 + t * 1.2, 1.25 + math.sin(t * math.pi) * 0.55, 0), Color3.fromRGB(170, 172, 176), Enum.Material.Metal, Enum.PartType.Ball)
	end
	return m
end

-------------------------------------------------------------------------------
-- Viewport wrapper
-------------------------------------------------------------------------------
-- opts.view: rotation applied to the model (how it faces the camera); opts.zoom: >1 = closer
-- Returns { Frame, SetModel(model, view), SetHover(bool) }
function Icons.Viewport(parent: Instance, model: Model, opts)
	opts = opts or {}
	local vpf = Instance.new("ViewportFrame")
	vpf.BackgroundTransparency = 1
	vpf.Size = UDim2.fromScale(1, 1)
	vpf.Ambient = Color3.fromRGB(150, 150, 158)
	vpf.LightColor = Color3.fromRGB(255, 244, 228)
	vpf.LightDirection = Vector3.new(-0.6, -1, -0.8)
	vpf.Parent = parent

	local world = Instance.new("WorldModel")
	world.Parent = vpf
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.Parent = vpf
	vpf.CurrentCamera = cam

	local ctl = { Frame = vpf }
	local current, baseView, hover, hoverT = nil, CFrame.identity, false, 0

	function ctl.SetModel(newModel: Model, view: CFrame?)
		if current then current:Destroy() end
		current = newModel
		baseView = view or opts.view or CFrame.identity
		newModel.Parent = world
		-- centre on the origin so rotations turn it in place, then fit the camera to it
		local cf, size = newModel:GetBoundingBox()
		for _, d in newModel:GetDescendants() do
			if d:IsA("BasePart") then d.CFrame = CFrame.new(-cf.Position) * d.CFrame end
		end
		newModel.WorldPivot = CFrame.identity
		local radius = size.Magnitude / 2
		local dist = radius / math.tan(math.rad(cam.FieldOfView / 2)) / (opts.zoom or 1)
		cam.CFrame = CFrame.lookAt(Vector3.new(0, 0, -dist), Vector3.zero)
		newModel:PivotTo(baseView)
	end

	function ctl.SetHover(on: boolean)
		hover = on
	end

	ctl.SetModel(model, opts.view)

	-- gentle idle sway; turns further toward you when hovered
	local t0 = math.random() * 10
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		if not vpf.Parent then conn:Disconnect() return end
		if not current then return end
		hoverT += ((hover and 1 or 0) - hoverT) * math.min(1, dt * 10)
		local t = os.clock() + t0
		local sway = CFrame.Angles(math.sin(t * 0.9) * 0.05, math.sin(t * 0.6) * 0.12 + hoverT * 0.45, 0)
		current:PivotTo(sway * baseView)
	end)
	return ctl
end

-- Viewmodel angle for guns: barrel pointing up-left like a held weapon.
-- (Guns in Repository have the barrel along -Z and up along +Y.)
Icons.GunView = CFrame.Angles(0, math.rad(-90), 0) * CFrame.Angles(math.rad(28), 0, 0) * CFrame.Angles(0, 0, math.rad(-8))

-------------------------------------------------------------------------------
-- Item icons (used on the KIT / SHOP cards)
-------------------------------------------------------------------------------
local function cloneTool(folderName: string, id: string)
	local m = Instance.new("Model")
	local src = ReplicatedStorage:FindFirstChild("Repository")
	src = src and src:FindFirstChild(folderName)
	src = src and src:FindFirstChild(id)
	if src then
		for _, d in src:GetDescendants() do
			if d:IsA("BasePart") then
				local c = d:Clone()
				c:ClearAllChildren()
				c.Anchored = true
				c.Color = c.Color:Lerp(Color3.fromRGB(200, 205, 210), 0.2)
				c.Parent = m
			end
		end
	end
	return m
end

function Icons.Fist()
	local m = Instance.new("Model")
	local glove, wrap, pad = Color3.fromRGB(62, 64, 56), Color3.fromRGB(176, 152, 110), Color3.fromRGB(40, 42, 38)
	p(m, Vector3.new(1, 0.9, 0.7), CFrame.new(0, 0, 0), glove, Enum.Material.Fabric) -- back of hand
	for i = 0, 3 do -- curled fingers
		p(m, Vector3.new(0.23, 0.36, 0.5), CFrame.new(-0.36 + i * 0.24, 0.5, -0.12), glove, Enum.Material.Fabric)
		p(m, Vector3.new(0.21, 0.1, 0.3), CFrame.new(-0.36 + i * 0.24, 0.7, -0.15), pad, Enum.Material.SmoothPlastic) -- knuckle guard
	end
	p(m, Vector3.new(0.28, 0.5, 0.3), CFrame.new(0.58, 0.12, -0.3) * CFrame.Angles(0, 0, math.rad(-25)), glove, Enum.Material.Fabric) -- thumb
	p(m, Vector3.new(0.85, 0.5, 0.62), CFrame.new(0, -0.68, 0.02), wrap, Enum.Material.Fabric) -- wrist wrap
	return m
end

function Icons.Grenade(kind: string)
	local m = Instance.new("Model")
	local up = CFrame.Angles(0, 0, math.rad(90)) -- cylinder axis (X) -> vertical
	local metal = Color3.fromRGB(70, 72, 76)
	if kind == "Frag" then
		p(m, Vector3.new(1.1, 1.1, 1.1), CFrame.new(0, 0, 0), Color3.fromRGB(86, 96, 58), Enum.Material.Metal, Enum.PartType.Ball)
		for i = -1, 1 do -- segment grooves
			p(m, Vector3.new(0.04, 1.08, 1.08), CFrame.new(i * 0.25, 0, 0) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(60, 68, 40), Enum.Material.Metal, Enum.PartType.Cylinder)
		end
	else
		local body = kind == "Flash" and Color3.fromRGB(48, 50, 54) or Color3.fromRGB(110, 118, 112)
		p(m, Vector3.new(1.3, 0.7, 0.7), up, body, Enum.Material.Metal, Enum.PartType.Cylinder)
		p(m, Vector3.new(0.18, 0.72, 0.72), up * CFrame.new(0.25, 0, 0), kind == "Flash" and Color3.fromRGB(230, 170, 40) or Color3.fromRGB(80, 170, 90), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		if kind == "Flash" then
			for i = 0, 5 do -- vent holes
				local a = math.rad(i * 60)
				p(m, Vector3.new(0.12, 0.18, 0.04), CFrame.new(math.sin(a) * 0.35, -0.25, -math.cos(a) * 0.35) * CFrame.Angles(0, -a, 0), Color3.fromRGB(16, 16, 18))
			end
		end
	end
	-- fuse, spoon and pin (shared)
	local topY = kind == "Frag" and 0.55 or 0.65
	p(m, Vector3.new(0.18, 0.32, 0.32), CFrame.new(0, topY + 0.05, 0) * up, metal, Enum.Material.Metal, Enum.PartType.Cylinder)
	p(m, Vector3.new(0.12, 0.85, 0.2), CFrame.new(0.22, topY - 0.25, 0) * CFrame.Angles(0, 0, math.rad(-8)), Color3.fromRGB(150, 152, 156), Enum.Material.Metal)
	p(m, Vector3.new(0.05, 0.3, 0.3), CFrame.new(-0.18, topY + 0.12, 0) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(196, 170, 90), Enum.Material.Metal, Enum.PartType.Cylinder)
	return m
end

-- (2026-10-19, UI session) the new gadgets (Edward's weapon design): drawn in the same part style
function Icons.Sticky()
	local m = Instance.new("Model")
	local up = CFrame.Angles(0, 0, math.rad(90))
	p(m, Vector3.new(1.05, 1.05, 1.05), CFrame.new(0, 0, 0), Color3.fromRGB(150, 44, 36), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	p(m, Vector3.new(0.62, 0.62, 0.62), CFrame.new(-0.42, -0.18, -0.2), Color3.fromRGB(120, 220, 70), Enum.Material.SmoothPlastic, Enum.PartType.Ball) -- the glue
	p(m, Vector3.new(0.34, 0.34, 0.34), CFrame.new(-0.58, -0.46, 0.02), Color3.fromRGB(120, 220, 70), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	p(m, Vector3.new(0.18, 0.32, 0.32), CFrame.new(0, 0.6, 0) * up, Color3.fromRGB(70, 72, 76), Enum.Material.Metal, Enum.PartType.Cylinder)
	p(m, Vector3.new(0.05, 0.3, 0.3), CFrame.new(-0.18, 0.67, 0) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(196, 170, 90), Enum.Material.Metal, Enum.PartType.Cylinder)
	return m
end
function Icons.Landmine()
	local m = Instance.new("Model")
	local up = CFrame.Angles(0, 0, math.rad(90))
	p(m, Vector3.new(0.28, 1.7, 1.7), up, Color3.fromRGB(86, 96, 58), Enum.Material.Metal, Enum.PartType.Cylinder) -- the disc
	p(m, Vector3.new(0.14, 1.1, 1.1), CFrame.new(0, 0.2, 0) * up, Color3.fromRGB(64, 72, 44), Enum.Material.Metal, Enum.PartType.Cylinder) -- pressure plate
	p(m, Vector3.new(0.1, 0.4, 0.4), CFrame.new(0, 0.3, 0) * up, Color3.fromRGB(40, 42, 38), Enum.Material.Metal, Enum.PartType.Cylinder)
	p(m, Vector3.new(0.14, 0.14, 0.14), CFrame.new(0.55, 0.2, -0.3), Color3.fromRGB(255, 50, 40), Enum.Material.Neon, Enum.PartType.Ball) -- armed light
	return m
end
function Icons.Medkit()
	local m = Instance.new("Model")
	p(m, Vector3.new(1.5, 1.05, 0.55), CFrame.new(0, 0, 0), Color3.fromRGB(236, 234, 228), Enum.Material.SmoothPlastic) -- the case
	p(m, Vector3.new(0.5, 0.16, 0.06), CFrame.new(0, 0, -0.29), Color3.fromRGB(210, 40, 40), Enum.Material.SmoothPlastic) -- the cross
	p(m, Vector3.new(0.16, 0.5, 0.06), CFrame.new(0, 0, -0.29), Color3.fromRGB(210, 40, 40), Enum.Material.SmoothPlastic)
	p(m, Vector3.new(0.6, 0.12, 0.16), CFrame.new(0, 0.62, 0), Color3.fromRGB(60, 62, 66), Enum.Material.SmoothPlastic) -- handle
	p(m, Vector3.new(1.52, 0.08, 0.57), CFrame.new(0, 0.2, 0), Color3.fromRGB(190, 188, 182), Enum.Material.SmoothPlastic) -- lid seam
	return m
end

-- Returns model, view, zoom for any LobbyConfig item id
local GRENADES = { Smoke = true, Flash = true, Frag = true }
local NEW_GADGETS = { StickyGrenade = "Sticky", Landmine = "Landmine", Medkit = "Medkit" }
function Icons.Item(itemId: string)
	if GRENADES[itemId] then
		return Icons.Grenade(itemId), CFrame.Angles(math.rad(18), math.rad(30), math.rad(-10)), 1.05
	elseif NEW_GADGETS[itemId] then
		return Icons[NEW_GADGETS[itemId]](), CFrame.Angles(math.rad(22), math.rad(30), math.rad(-8)), 1.05
	elseif itemId == "Fists" then
		return Icons.Fist(), CFrame.Angles(math.rad(14), math.rad(30), math.rad(8)), 1.05
	end
	-- (2026-10-20) the Riot Shield's plate lies in XY facing -Z (the icon camera's side): show its face, not the melee side view
	if itemId == "RiotShield" then
		local s = cloneTool("Melee", itemId)
		if #s:GetChildren() > 0 then return s, CFrame.Angles(math.rad(8), math.rad(-28), 0), 1 end
		s:Destroy()
	end
	local melee = cloneTool("Melee", itemId)
	if #melee:GetChildren() > 0 then
		return melee, CFrame.Angles(0, math.rad(-90), 0) * CFrame.Angles(math.rad(38), 0, 0), 1
	end
	melee:Destroy()
	return Icons.Weapon(itemId), Icons.GunView, 0.95
end

-------------------------------------------------------------------------------
-- Cosmetic slot icons (armory bottom bar) and the locked-item rig
-------------------------------------------------------------------------------
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- cylinder axis (X) -> vertical

function Icons.SprayCan()
	local m = Instance.new("Model")
	p(m, Vector3.new(1.8, 0.8, 0.8), UPRIGHT, Color3.fromRGB(58, 62, 66), Enum.Material.Metal, Enum.PartType.Cylinder)
	p(m, Vector3.new(0.8, 0.82, 0.82), CFrame.new(0, -0.15, 0) * UPRIGHT, Color3.fromRGB(200, 196, 180), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	p(m, Vector3.new(0.18, 0.66, 0.66), CFrame.new(0, 0.98, 0) * UPRIGHT, Color3.fromRGB(150, 152, 156), Enum.Material.Metal, Enum.PartType.Cylinder)
	p(m, Vector3.new(0.4, 0.5, 0.5), CFrame.new(0, 1.2, 0) * UPRIGHT, Color3.fromRGB(200, 60, 48), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	p(m, Vector3.new(0.14, 0.14, 0.2), CFrame.new(0, 1.3, -0.24), Color3.fromRGB(30, 30, 32))
	return m
end

function Icons.WrapRoll()
	local m = Instance.new("Model")
	local camo = { Color3.fromRGB(86, 96, 58), Color3.fromRGB(120, 104, 70), Color3.fromRGB(52, 58, 40) }
	p(m, Vector3.new(1.2, 1.5, 1.5), CFrame.new(0, 0.3, 0), camo[1], Enum.Material.Fabric, Enum.PartType.Cylinder)
	p(m, Vector3.new(1.3, 0.5, 0.5), CFrame.new(0, 0.3, 0), Color3.fromRGB(40, 40, 42), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	p(m, Vector3.new(1.18, 0.06, 1.3), CFrame.new(0, -0.45, -0.6) * CFrame.Angles(math.rad(-20), 0, 0), camo[1], Enum.Material.Fabric)
	local spots = { { -0.3, -0.5, 1 }, { 0.25, -0.65, 2 }, { -0.1, -0.85, 3 }, { 0.35, -0.95, 3 }, { -0.4, 0.6, 2 }, { 0.2, 0.75, 3 } }
	for _, sp in spots do
		if sp[2] < 0 then
			p(m, Vector3.new(0.35, 0.07, 0.3), CFrame.new(sp[1], -0.45, sp[2] - 0.1) * CFrame.Angles(math.rad(-20), 0, 0), camo[sp[3]], Enum.Material.Fabric)
		else
			p(m, Vector3.new(0.4, 0.3, 0.06), CFrame.new(sp[1], sp[2] - 0.05, -0.74), camo[sp[3]], Enum.Material.Fabric)
		end
	end
	return m
end

function Icons.Skull()
	local m = Instance.new("Model")
	local bone, dark = Color3.fromRGB(226, 220, 204), Color3.fromRGB(26, 24, 22)
	p(m, Vector3.new(1.5, 1.45, 1.5), CFrame.new(0, 0.2, 0), bone, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	p(m, Vector3.new(0.9, 0.5, 0.8), CFrame.new(0, -0.5, -0.25), bone, Enum.Material.SmoothPlastic)
	for _, x in { -0.32, 0.32 } do
		p(m, Vector3.new(0.42, 0.42, 0.3), CFrame.new(x, 0.12, -0.62), dark, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	end
	p(m, Vector3.new(0.18, 0.22, 0.1), CFrame.new(0, -0.18, -0.7), dark)
	for i = -2, 2 do
		p(m, Vector3.new(0.04, 0.32, 0.04), CFrame.new(i * 0.14, -0.55, -0.66), dark)
	end
	return m
end

function Icons.Clapper()
	local m = Instance.new("Model")
	local black, white = Color3.fromRGB(26, 27, 29), Color3.fromRGB(236, 236, 236)
	p(m, Vector3.new(2, 1.4, 0.14), CFrame.new(0, -0.2, 0), black)
	for i = 0, 2 do
		p(m, Vector3.new(1.7, 0.05, 0.02), CFrame.new(0, -0.05 - i * 0.35, -0.08), Color3.fromRGB(140, 140, 140))
	end
	local bar = CFrame.new(-1, 0.65, 0) * CFrame.Angles(0, 0, math.rad(14)) * CFrame.new(1, 0, 0)
	p(m, Vector3.new(2.05, 0.32, 0.16), bar, black)
	for i = 0, 4 do
		p(m, Vector3.new(0.18, 0.33, 0.02), bar * CFrame.new(-0.8 + i * 0.4, 0, -0.09) * CFrame.Angles(0, 0, math.rad(-35)), white)
	end
	p(m, Vector3.new(2.05, 0.3, 0.16), CFrame.new(0, 0.42, 0), black)
	for i = 0, 4 do
		p(m, Vector3.new(0.18, 0.31, 0.02), CFrame.new(-0.8 + i * 0.4, 0.42, -0.09) * CFrame.Angles(0, 0, math.rad(35)), white)
	end
	return m
end

-- Hazard tape crossed over the item with a heavy padlock, facing the camera (-Z).
function Icons.LockRig()
	local m = Instance.new("Model")
	local yellow, black = Color3.fromRGB(236, 190, 40), Color3.fromRGB(22, 22, 24)
	for _, ang in { 36, -36 } do
		local base = CFrame.Angles(0, 0, math.rad(ang))
		local n = 14
		for i = 0, n - 1 do
			local x = -6.3 + i * 0.9 + 0.45
			p(m, Vector3.new(0.92, 0.9, 0.06), base * CFrame.new(x, 0, ang > 0 and -0.05 or -0.12), i % 2 == 0 and yellow or black, Enum.Material.SmoothPlastic)
		end
	end
	local steel, dark = Color3.fromRGB(70, 74, 80), Color3.fromRGB(18, 18, 20)
	p(m, Vector3.new(1.9, 1.6, 0.7), CFrame.new(0, -0.3, -0.5), steel, Enum.Material.Metal)
	p(m, Vector3.new(1.94, 0.22, 0.72), CFrame.new(0, 0.22, -0.5), yellow, Enum.Material.SmoothPlastic)
	for _, x in { -0.62, 0.62 } do
		p(m, Vector3.new(0.8, 0.26, 0.26), CFrame.new(x, 0.85, -0.5) * UPRIGHT, Color3.fromRGB(170, 174, 180), Enum.Material.Metal, Enum.PartType.Cylinder)
	end
	p(m, Vector3.new(1.5, 0.26, 0.26), CFrame.new(0, 1.25, -0.5), Color3.fromRGB(170, 174, 180), Enum.Material.Metal, Enum.PartType.Cylinder)
	p(m, Vector3.new(0.3, 0.3, 0.1), CFrame.new(0, -0.2, -0.86), dark, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	p(m, Vector3.new(0.12, 0.4, 0.06), CFrame.new(0, -0.45, -0.86), dark)
	return m
end

return Icons
