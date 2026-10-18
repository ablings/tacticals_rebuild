-- UIKit/ViewIcons (ModuleScript): live 3D icons ("viewmodels") for the menus, instead of flat images.
-- Small models built from parts (trophy, sandbags, medal, monitor, headset, gamepad, keyboard), the
-- Blender meshes in ReplicatedStorage.LobbyAssets.Icons (Crate, Clipboard, Gear, DogTags) and the real
-- weapons in ReplicatedStorage.Repository. Each is drawn in a ViewportFrame with a gentle idle sway that
-- turns toward you on hover - the same look as the lobby dock.
--   local vp = ViewIcons.Viewport(parent, ViewIcons.Build("Trophy"), { view = CFrame, zoom = 1 })
--   vp.SetHover(true) / vp.SetModel(model, view)
--   ViewIcons.Icon(parent, name, opts) -> builds + views in one call (name from ViewIcons.Views)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ViewIcons = {}

-- palette (matches the dock icons)
local OLIVE, OLIVE_D = Color3.fromRGB(98, 108, 62), Color3.fromRGB(58, 64, 38)
local GUN, STEEL = Color3.fromRGB(46, 50, 56), Color3.fromRGB(150, 156, 164)
local AMBER, BLACK = Color3.fromRGB(224, 168, 46), Color3.fromRGB(20, 20, 22)
local BRASS, SAND = Color3.fromRGB(196, 150, 60), Color3.fromRGB(176, 156, 112)
local METAL, PLASTIC, FABRIC = Enum.Material.Metal, Enum.Material.SmoothPlastic, Enum.Material.Fabric
local CYL, BALL = Enum.PartType.Cylinder, Enum.PartType.Ball
local UP = CFrame.Angles(0, 0, math.rad(90)) -- cylinder axis (X) -> vertical
local FACE = CFrame.Angles(0, math.rad(90), 0) -- cylinder axis (X) -> toward the camera (Z)

local function p(model, size, cf, color, mat, shape)
	local part = Instance.new("Part")
	part.Anchored = true
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = mat or PLASTIC
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if shape then part.Shape = shape end
	part.Parent = model
	return part
end

-------------------------------------------------------------------------------
-- Builders (front faces -Z, toward the viewport camera)
-------------------------------------------------------------------------------
local B = {}

function B.Trophy()
	local m = Instance.new("Model")
	p(m, Vector3.new(1.6, 0.35, 1.2), CFrame.new(0, -1.25, 0), GUN, METAL)
	p(m, Vector3.new(1.2, 0.3, 0.9), CFrame.new(0, -0.95, 0), OLIVE_D, METAL)
	p(m, Vector3.new(0.9, 0.04, 0.02), CFrame.new(0, -0.95, -0.46), AMBER, PLASTIC) -- name plate
	p(m, Vector3.new(0.7, 0.28, 0.28), CFrame.new(0, -0.65, 0) * UP, BRASS, METAL, CYL) -- stem
	p(m, Vector3.new(0.18, 0.55, 0.55), CFrame.new(0, -0.45, 0) * UP, BRASS, METAL, CYL)
	p(m, Vector3.new(1.4, 1.4, 1.4), CFrame.new(0, 0.25, 0), BRASS, METAL, BALL) -- cup
	p(m, Vector3.new(0.2, 1.42, 1.42), CFrame.new(0, 0.72, 0) * UP, BRASS, METAL, CYL) -- rim
	for _, s in { -1, 1 } do -- handles
		p(m, Vector3.new(0.14, 0.7, 0.7), CFrame.new(s * 0.8, 0.35, 0) * FACE, BRASS, METAL, CYL)
	end
	p(m, Vector3.new(0.5, 0.5, 0.05), CFrame.new(0, 0.2, -0.68) * CFrame.Angles(0, 0, math.rad(45)), AMBER, PLASTIC) -- star badge
	return m
end

function B.Sandbags()
	local m = Instance.new("Model")
	local rows = { { -0.9, 0, 0.9 }, { -0.45, 0.45 }, { 0 } }
	for r, xs in rows do
		for _, x in xs do
			local bag = p(m, Vector3.new(0.85, 0.42, 0.6), CFrame.new(x, -0.6 + (r - 1) * 0.4, 0) * CFrame.Angles(0, 0, math.rad((x * 7) % 5 - 2)),
				(r + math.floor(x * 10)) % 2 == 0 and SAND or SAND:Lerp(OLIVE, 0.35), FABRIC)
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = bag
		end
	end
	return m
end

function B.Medal()
	local m = Instance.new("Model")
	-- ribbon (olive with amber stripe)
	p(m, Vector3.new(0.9, 1.1, 0.05), CFrame.new(0, 0.55, 0.02), OLIVE, FABRIC)
	p(m, Vector3.new(0.22, 1.1, 0.06), CFrame.new(0, 0.55, 0), AMBER, FABRIC)
	p(m, Vector3.new(1, 0.16, 0.12), CFrame.new(0, 1.1, 0), STEEL, METAL)
	-- disc
	p(m, Vector3.new(0.14, 1.2, 1.2), CFrame.new(0, -0.45, 0) * FACE, BRASS, METAL, CYL)
	p(m, Vector3.new(0.16, 0.9, 0.9), CFrame.new(0, -0.45, -0.01) * FACE, BRASS:Lerp(BLACK, 0.25), METAL, CYL)
	p(m, Vector3.new(0.42, 0.42, 0.06), CFrame.new(0, -0.45, -0.1) * CFrame.Angles(0, 0, math.rad(45)), AMBER, METAL)
	return m
end

function B.Monitor()
	local m = Instance.new("Model")
	p(m, Vector3.new(2.4, 1.5, 0.14), CFrame.new(0, 0.25, 0), GUN, METAL) -- bezel
	local screen = p(m, Vector3.new(2.2, 1.3, 0.02), CFrame.new(0, 0.25, -0.08), Color3.fromRGB(40, 60, 40), Enum.Material.Neon)
	screen.Transparency = 0.15
	for i = 0, 2 do -- scan lines + a little radar sweep
		p(m, Vector3.new(1.6 - i * 0.3, 0.05, 0.02), CFrame.new(-0.2, 0.55 - i * 0.25, -0.1), AMBER, Enum.Material.Neon)
	end
	p(m, Vector3.new(0.02, 0.36, 0.36), CFrame.new(0.7, 0.05, -0.1) * FACE, OLIVE, Enum.Material.Neon, CYL)
	p(m, Vector3.new(0.18, 0.6, 0.18), CFrame.new(0, -0.75, 0.05), STEEL, METAL) -- stand
	p(m, Vector3.new(1, 0.1, 0.6), CFrame.new(0, -1.05, 0.05), GUN, METAL)
	return m
end

function B.Headset()
	local m = Instance.new("Model")
	-- band: a short arc of segments over the top
	for i = 0, 8 do
		local a = math.rad(-80 + i * 20)
		p(m, Vector3.new(0.32, 0.12, 0.34), CFrame.new(math.sin(a) * 1, math.cos(a) * 1 + 0.1, 0) * CFrame.Angles(0, 0, -a), OLIVE_D, FABRIC)
	end
	for _, s in { -1, 1 } do
		p(m, Vector3.new(0.35, 0.95, 0.95), CFrame.new(s * 1.05, -0.2, 0), GUN, METAL, CYL) -- cups
		p(m, Vector3.new(0.12, 0.75, 0.75), CFrame.new(s * 0.86, -0.2, 0), BLACK, FABRIC, CYL) -- pads
		p(m, Vector3.new(0.06, 0.5, 0.5), CFrame.new(s * 1.24, -0.2, 0), AMBER, PLASTIC, CYL)
	end
	-- boom mic
	p(m, Vector3.new(0.08, 0.08, 0.9), CFrame.new(-0.95, -0.55, -0.45) * CFrame.Angles(0, math.rad(-25), 0), STEEL, METAL)
	p(m, Vector3.new(0.2, 0.2, 0.2), CFrame.new(-0.75, -0.55, -0.85), BLACK, FABRIC, BALL)
	return m
end

function B.Gamepad()
	local m = Instance.new("Model")
	p(m, Vector3.new(2.2, 1, 0.5), CFrame.new(0, 0.1, 0), GUN, PLASTIC) -- body
	for _, s in { -1, 1 } do -- grips
		p(m, Vector3.new(0.75, 1.1, 0.5), CFrame.new(s * 0.85, -0.35, 0.02) * CFrame.Angles(0, 0, math.rad(s * 18)), GUN, PLASTIC)
	end
	for _, xy in { { -0.6, 0.25 }, { 0.3, -0.15 } } do -- sticks
		p(m, Vector3.new(0.12, 0.42, 0.42), CFrame.new(xy[1], xy[2], -0.3) * FACE, BLACK, PLASTIC, CYL)
		p(m, Vector3.new(0.06, 0.34, 0.34), CFrame.new(xy[1], xy[2], -0.37) * FACE, OLIVE, PLASTIC, CYL)
	end
	p(m, Vector3.new(0.36, 0.12, 0.06), CFrame.new(-0.25, -0.15, -0.27), BLACK) -- d-pad
	p(m, Vector3.new(0.12, 0.36, 0.06), CFrame.new(-0.25, -0.15, -0.27), BLACK)
	local cols = { AMBER, OLIVE, STEEL, Color3.fromRGB(176, 40, 32) }
	for i, off in { { 0, 0.15 }, { 0.15, 0 }, { 0, -0.15 }, { -0.15, 0 } } do -- face buttons
		p(m, Vector3.new(0.06, 0.13, 0.13), CFrame.new(0.65 + off[1], 0.25 + off[2], -0.27) * FACE, cols[i], PLASTIC, CYL)
	end
	return m
end

function B.Keyboard()
	local m = Instance.new("Model")
	local tilt = CFrame.Angles(math.rad(-55), 0, 0)
	p(m, Vector3.new(2.6, 0.18, 1.1), tilt, GUN, METAL)
	for r = 0, 3 do
		for c = 0, 9 do
			local k = (r == 1 and c == 2) or (r == 2 and (c == 1 or c == 2 or c == 3)) -- WASD in amber
			p(m, Vector3.new(0.2, 0.1, 0.2), tilt * CFrame.new(-1.08 + c * 0.24, 0.12, -0.36 + r * 0.24), k and AMBER or Color3.fromRGB(70, 74, 64), PLASTIC)
		end
	end
	p(m, Vector3.new(1.2, 0.1, 0.18), tilt * CFrame.new(0, 0.12, 0.6), Color3.fromRGB(70, 74, 64), PLASTIC) -- space bar
	return m
end

function B.Grenade()
	local m = Instance.new("Model")
	p(m, Vector3.new(1.1, 1.1, 1.1), CFrame.new(0, 0, 0), OLIVE, METAL, BALL)
	for i = -1, 1 do -- segment grooves
		p(m, Vector3.new(0.04, 1.1, 1.1), CFrame.new(i * 0.25, 0, 0) * FACE * FACE, OLIVE_D, METAL, CYL)
	end
	p(m, Vector3.new(0.18, 0.32, 0.32), CFrame.new(0, 0.6, 0) * UP, GUN, METAL, CYL) -- fuse
	p(m, Vector3.new(0.12, 0.85, 0.2), CFrame.new(0.22, 0.3, 0) * CFrame.Angles(0, 0, math.rad(-8)), STEEL, METAL) -- spoon
	p(m, Vector3.new(0.05, 0.3, 0.3), CFrame.new(-0.18, 0.67, 0) * FACE, BRASS, METAL, CYL) -- pin ring
	return m
end

-- Blender meshes (Crate, Clipboard, Gear, DogTags) from LobbyAssets.Icons
local function asset(name)
	local f = ReplicatedStorage:FindFirstChild("LobbyAssets")
	f = f and f:FindFirstChild("Icons")
	local src = f and f:FindFirstChild(name)
	if not src then return nil end
	local c = src:Clone()
	c:PivotTo(CFrame.identity)
	return c
end
for _, n in { "Crate", "Clipboard", "Gear", "DogTags" } do
	B[n] = function() return asset(n) or B.Medal() end
end

-- a real item from ReplicatedStorage.Repository.<folder>.<id>, as plain anchored parts
local function fromRepository(folder, id)
	local m = Instance.new("Model")
	local src = ReplicatedStorage:FindFirstChild("Repository")
	src = src and src:FindFirstChild(folder)
	src = src and src:FindFirstChild(id)
	if src then
		for _, d in src:GetDescendants() do
			if d:IsA("BasePart") then
				local c = d:Clone()
				c:ClearAllChildren()
				c.Anchored = true
				c.Color = c.Color:Lerp(Color3.fromRGB(200, 205, 210), 0.2) -- lift dark metal so it reads on dark panels
				c.Parent = m
			end
		end
	end
	return m
end
local function orFallback(m)
	if #m:GetChildren() > 0 then return m end
	m:Destroy()
	return B.Medal()
end
function ViewIcons.Weapon(id) return orFallback(fromRepository("Weapons", id)) end
function ViewIcons.Melee(id) return orFallback(fromRepository("Melee", id)) end

-- the 3D scissors (ReplicatedStorage.Repository.Scissors), the game's currency
function ViewIcons.Scissors()
	local m = Instance.new("Model")
	local src = ReplicatedStorage:FindFirstChild("Repository")
	src = src and src:FindFirstChild("Scissors")
	if src then
		for _, d in (src:IsA("BasePart") and { src } or src:GetDescendants()) do
			if d:IsA("BasePart") then
				local c = d:Clone()
				c:ClearAllChildren()
				c.Anchored = true
				c.Parent = m
			end
		end
	end
	return orFallback(m)
end
B.Scissors = ViewIcons.Scissors

function ViewIcons.Build(name)
	local f = B[name]
	return f and f() or B.Medal()
end

-- default viewing angle + zoom per icon
local GUN_VIEW = CFrame.Angles(0, math.rad(-90), 0) * CFrame.Angles(math.rad(28), 0, 0) * CFrame.Angles(0, 0, math.rad(-8))
ViewIcons.GunView = GUN_VIEW
ViewIcons.Views = {
	Trophy = { CFrame.Angles(math.rad(10), math.rad(20), 0), 1.05 },
	Sandbags = { CFrame.Angles(math.rad(18), math.rad(25), 0), 1.1 },
	Medal = { CFrame.Angles(math.rad(6), math.rad(-15), math.rad(4)), 1.05 },
	Monitor = { CFrame.Angles(math.rad(6), math.rad(-22), 0), 1.05 },
	Headset = { CFrame.Angles(math.rad(10), math.rad(25), 0), 1.05 },
	Gamepad = { CFrame.Angles(math.rad(-20), math.rad(18), 0), 1.08 },
	Keyboard = { CFrame.Angles(math.rad(8), math.rad(-15), 0), 1.08 },
	Crate = { CFrame.Angles(math.rad(16), math.rad(28), 0), 1.1 },
	Clipboard = { CFrame.Angles(math.rad(8), math.rad(-18), math.rad(6)), 1.05 },
	Gear = { CFrame.Angles(math.rad(10), math.rad(25), 0), 1.1 },
	DogTags = { CFrame.Angles(math.rad(6), math.rad(-15), 0), 1.05 },
	Grenade = { CFrame.Angles(math.rad(18), math.rad(30), math.rad(-10)), 1.05 },
	Scissors = { CFrame.Angles(0, 0, math.rad(80)) * CFrame.Angles(math.rad(-90), 0, 0), 1.0 }, -- model lies flat: flat side to the camera, blades pointing sideways
}

-------------------------------------------------------------------------------
-- Viewport
-------------------------------------------------------------------------------
-- opts.view: rotation (how the model faces the camera); opts.zoom: >1 = closer; opts.still: no sway
function ViewIcons.Viewport(parent, model, opts)
	opts = opts or {}
	local vpf = Instance.new("ViewportFrame")
	vpf.Name = "ViewIcon"
	vpf.BackgroundTransparency = 1
	vpf.Size = UDim2.fromScale(1, 1)
	vpf.Ambient = Color3.fromRGB(150, 150, 150)
	vpf.LightColor = Color3.fromRGB(255, 240, 220)
	vpf.LightDirection = Vector3.new(-0.6, -1, -0.8)
	vpf.ZIndex = opts.zIndex or 1
	vpf.Parent = parent
	local world = Instance.new("WorldModel")
	world.Parent = vpf
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.Parent = vpf
	vpf.CurrentCamera = cam

	local ctl = { Frame = vpf }
	local current, baseView, hover, hoverT = nil, CFrame.identity, false, 0
	function ctl.SetModel(newModel, view)
		if current then current:Destroy() end
		current = newModel
		baseView = view or opts.view or CFrame.identity
		newModel.Parent = world
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
	function ctl.SetHover(on) hover = on end
	ctl.SetModel(model, opts.view)

	if not opts.still then
		local t0 = math.random() * 10
		local conn
		conn = RunService.RenderStepped:Connect(function(dt)
			if not vpf.Parent then conn:Disconnect() return end
			if not current or not vpf.Visible then return end
			hoverT += ((hover and 1 or 0) - hoverT) * math.min(1, dt * 10)
			local t = os.clock() + t0
			current:PivotTo(CFrame.Angles(math.sin(t * 0.9) * 0.05, math.sin(t * 0.6) * 0.12 + hoverT * 0.45, 0) * baseView)
		end)
	end
	return ctl
end

-- build + view a named icon; hoverTarget (a GuiObject) turns it toward you while the pointer is over it
function ViewIcons.Icon(parent, name, opts)
	opts = opts or {}
	local v = ViewIcons.Views[name] or { CFrame.identity, 1 }
	local ctl = ViewIcons.Viewport(parent, ViewIcons.Build(name), { view = opts.view or v[1], zoom = opts.zoom or v[2], zIndex = opts.zIndex, still = opts.still })
	local target = opts.hoverTarget
	if target then
		target.MouseEnter:Connect(function() ctl.SetHover(true) end)
		target.MouseLeave:Connect(function() ctl.SetHover(false) end)
	end
	return ctl
end

return ViewIcons
