local __TG = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("TrainingGate"))
-- StarterPlayer/StarterPlayerScripts/Client/Controllers/HotbarController (ModuleScript)
-- The kit hotbar, stacked bottom-right from the bottom up:
--   [1] your gun      (bottom)  WeaponController draws / holsters it
--   [2] melee         (middle)  knife / fists. Left click to swing (server decides what it hit)
--   [3] gadget        (top)     smoke / flash / frag. Selected: left click = G (hold to aim the arc,
--                               release to throw, tap to roll). G still quick-throws from any slot.
-- Every tile shows its item as a flat white silhouette (rendered live from the real model, so new
-- weapons get an icon automatically). HotbarConfig.Images can still override any icon with a picture.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
RunService = __TG.RunService
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundTrim = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("SoundTrim"))
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService") -- [SET] Scroll Equip
ContextActionService = __TG.ContextActionService
UserInputService = __TG.UserInputService

local Shared = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("Config")
local HotbarConfig = require(Shared:WaitForChild("HotbarConfig"))
local MeleeConfig = require(Shared:WaitForChild("MeleeConfig"))
local WeaponConfig = require(Shared:WaitForChild("WeaponConfig"))
local UITheme = require(ReplicatedStorage.Modules.Shared:WaitForChild("UITheme"))
local MeleeRemote = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Combat"):WaitForChild("Melee")

local localPlayer = Players.LocalPlayer

-- [SET] Settings > Hotkeys / Controls (UI session 2026-10-16): binds and settings arrive as player attributes
local Binds = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("Binds"))
local Get = shared.Get
local controller = {}

local GUN, MELEE, GADGET = 1, 2, 3 -- slot numbers = keys 1 / 2 / 3

local smokeMode = false
local returning = false
local lastSlash = 0
local slashTrack: AnimationTrack? = nil
local slashOwner: Humanoid? = nil
local slashFor = nil

local function humanoidOf(): Humanoid?
	local c = localPlayer.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	return (h and h.Health > 0) and h or nil
end

local function heldTool(): Tool?
	local c = localPlayer.Character
	return c and c:FindFirstChildOfClass("Tool")
end

local function findTool(predicate): Tool?
	for _, container in { localPlayer.Character, localPlayer:FindFirstChildOfClass("Backpack") } do
		for _, t in (container and container:GetChildren() or {}) do
			if t:IsA("Tool") and predicate(t) then return t end
		end
	end
	return nil
end

function controller.ActiveSlot(): number
	if smokeMode then return GADGET end
	local t = heldTool()
	if t and t:GetAttribute("Melee") then return MELEE end
	if t and t:GetAttribute("WeaponId") then return GUN end
	return 0
end

local function select(slot: number)
	local hum = humanoidOf()
	if not hum then return end
	if slot == GUN then
		smokeMode = false
		local gun = findTool(function(t) return t:GetAttribute("WeaponId") ~= nil end)
		if gun and gun.Parent ~= localPlayer.Character then hum:EquipTool(gun) end
	elseif slot == GADGET then
		local Gadget = Get("GadgetController")
		if not Gadget or Gadget.GetCharges() <= 0 then return end
		hum:UnequipTools()
		smokeMode = true
	elseif slot == MELEE then
		smokeMode = false
		local knife = findTool(function(t) return t:GetAttribute("Melee") == true end)
		if knife then hum:EquipTool(knife) end
	end
end

local function faceNearestEnemy(range: number)
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local best, bestDist = nil, range
	local list = {}
	for _, p in game:GetService("Players"):GetPlayers() do if p.Character and p.Character ~= character then table.insert(list, p.Character) end end
	for _, b in game:GetService("CollectionService"):GetTagged("Bot") do table.insert(list, b) end
	for _, other in list do
		local r = other:FindFirstChild("HumanoidRootPart")
		local h = other:FindFirstChildOfClass("Humanoid")
		if r and h and h.Health > 0 then
			local d = (r.Position - root.Position).Magnitude
			if d < bestDist then best, bestDist = r, d end
		end
	end
	if best then
		local flat = (best.Position - root.Position) * Vector3.new(1, 0, 1)
		if flat.Magnitude > 0.1 then root.CFrame = CFrame.lookAt(root.Position, root.Position + flat) end
	end
end

local function slash(quick: boolean?, fKey: boolean?)
	local hum = humanoidOf()
	local tool = heldTool()
	local weapon = quick and MeleeConfig.QuickMelee or (tool and MeleeConfig.Weapons[tool:GetAttribute("MeleeId") or ""])
	if not hum or not weapon or os.clock() - lastSlash < weapon.Cooldown then return end
	lastSlash = os.clock()
	-- swinging from cover (or mid-loop round a pillar) steps you off the wall, and if someone's right
	-- next to you, you turn to face them first
	local Cover = Get("CoverController")
	if Cover and Cover.LeaveCover then Cover.LeaveCover() end
	faceNearestEnemy(MeleeConfig.FaceRange or 4)
	if slashOwner ~= hum or slashFor ~= weapon then
		slashOwner = hum
		slashFor = weapon
		slashTrack = nil
		local animator = hum:FindFirstChildOfClass("Animator")
		local id = weapon.Animation
		-- (pass 40) published to the group: the source carries its asset id
		local pub = id == "" and weapon.AnimationSource and ReplicatedStorage.Repository.AnimationSources:FindFirstChild(weapon.AnimationSource)
		if pub and pub:GetAttribute("PublishedId") then id = pub:GetAttribute("PublishedId") end
		if id == "" and RunService:IsStudio() then
			local src = ReplicatedStorage.Repository.AnimationSources:FindFirstChild(weapon.AnimationSource)
			local ok, temp = pcall(function() return game:GetService("KeyframeSequenceProvider"):RegisterKeyframeSequence(src) end)
			id = ok and temp or ""
		end
		if animator and id ~= "" then
			local a = Instance.new("Animation") a.AnimationId = id
			local ok, track = pcall(animator.LoadAnimation, animator, a)
			if ok then track.Priority = Enum.AnimationPriority.Action4 slashTrack = track end
		end
	end
	if slashTrack then slashTrack:Play(0.05) end
	-- whoosh (local, quiet: melee doesn't give you away)
	local swish = Instance.new("Sound")
	swish.SoundId = "rbxassetid://12222216"
	swish.Volume = 0.35
	swish.PlaybackSpeed = weapon == MeleeConfig.Weapons.Fists and 1.3 or 1
	swish.Parent = hum.Parent and hum.Parent:FindFirstChild("HumanoidRootPart") or workspace
	SoundTrim.Play(swish)
	game:GetService("Debris"):AddItem(swish, 2)
	MeleeRemote:FireServer((quick or fKey) and "Quick" or nil)
end

-- [F] quick melee: the gun in your hands becomes a club; with the knife/fists out it's their normal attack.
-- Nothing with a smoke/flash ready or empty-handed.

local function quickMelee()
	if smokeMode then return end
	local tool = heldTool()
	if not tool then return end
	if tool:GetAttribute("Melee") then
		slash(false, true)
	elseif tool:GetAttribute("WeaponId") then
		slash(true)
	end
end

-- // UI: stacked tiles ---------------------------------------------------------------------------------
-- The kit is a column of see-through grey tiles in the bottom-right corner, stacked on top of each other:
-- gun at the bottom, melee above it, gadget on top. Each tile's item is a big lit 3D render of the real
-- model that spills out over the tile's edges. The one in your hands goes dark with a black fade toward
-- its bottom, its item grows a little, and its name shows big beside it. The gun's tile carries the ammo
-- (magazine big, reserve small, a bullets icon); the gadget's carries how many are left.
-- Renders come from the real models, so a new gun gets its tile art automatically; HotbarConfig.Images
-- can still swap any item for a picture. Type and text edges match the lobby armory (Builder Sans).
local TweenService = game:GetService("TweenService")
local HUD = require(script.Parent.Parent:WaitForChild("GUIs"):WaitForChild("HUD"))

local UI_FONT = "rbxasset://fonts/families/BuilderSans.json"
local FONT = Font.new(UI_FONT, Enum.FontWeight.Bold)
local FONT_HEAVY = Font.new(UI_FONT, Enum.FontWeight.ExtraBold)
local FONT_MED = Font.new(UI_FONT, Enum.FontWeight.Medium)
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local SUB = Color3.fromRGB(196, 194, 182) -- pass 34 (lobby training copy): bone / olive / gunmetal
local RED = Color3.fromRGB(255, 90, 100)
local BLUE = Color3.fromRGB(200, 214, 150)

-- [UI] restyle (UI session 2026-10-16, Edward: RIVALS' aesthetics, classy, no olive / corner brackets on gameplay UI):
-- RIVALS' row of dark glass tiles, the held one bigger and lighter with a soft white edge, white type, the big 3D items
-- spilling over the tiles. Built in 1920x1080 design px on a UIKit canvas, then Kit.toScale (Scale only).
local TILE = Vector2.new(186, 124)                             -- one tile (design px)
local GAP = 14                                                 -- between tiles
local RENDER = Vector2.new(244, 160)                           -- the item's render box: bigger than the tile, so it spills out
local RENDER_LIFT = -10                                        -- the render sits this far above the tile's centre
local TILE_GREY, TILE_T = Color3.fromRGB(0, 0, 0), 0.55       -- a tile: dark glass
local HELD_FILL, HELD_T = Color3.fromRGB(120, 120, 126), 0.45  -- the one in your hands: lighter glass
local BONE = Color3.fromRGB(255, 255, 255)
local STENCIL = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)
local UIKitFolder = ReplicatedStorage:WaitForChild("UIKit")
local Kit = require(UIKitFolder:WaitForChild("Kit"))
local ICON_FOV = 30
local TI = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local POP = TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local slots = {}
local column, heldName, heldStroke
local shownActive = nil

-- // Item renders -------------------------------------------------------------------------------------
local function p(model, size, cf, color, shape, material)
	local part = Instance.new("Part")
	part.Anchored = true
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if shape then part.Shape = shape end
	part.Parent = model
	return part
end

local function skinColor(): Color3
	local char = localPlayer.Character
	local hand = char and (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm"))
	return hand and hand.Color or Color3.fromRGB(234, 184, 146)
end

-- stand-ins for items with no visible model. Drawn facing -X (they're turned to the camera later).
local METAL = Color3.fromRGB(176, 182, 194)
local BUILDERS = {}
function BUILDERS.Fists(m)
	local skin = skinColor()
	for i = 0, 3 do
		local z = -0.45 + i * 0.3
		p(m, Vector3.new(0.5, 0.42, 0.25), CFrame.new(0, 0.2, z), skin)
		p(m, Vector3.new(0.25, 0.25, 0.25), CFrame.new(0, 0.41, z), skin, Enum.PartType.Ball)
	end
	p(m, Vector3.new(0.5, 0.42, 1.18), CFrame.new(0.04, -0.18, 0), skin:Lerp(Color3.new(0, 0, 0), 0.08))
	p(m, Vector3.new(0.5, 0.24, 0.7), CFrame.new(-0.06, -0.1, -0.3) * CFrame.Angles(math.rad(12), 0, 0), skin:Lerp(Color3.new(1, 1, 1), 0.06))
	p(m, Vector3.new(0.5, 0.5, 0.72), CFrame.new(0.04, -0.6, 0.12), skin:Lerp(Color3.new(0, 0, 0), 0.12))
end
local GRENADE = {
	Smoke = { body = Color3.fromRGB(96, 110, 102), band = Color3.fromRGB(228, 232, 238) },
	Flash = { body = Color3.fromRGB(64, 70, 82), band = Color3.fromRGB(80, 160, 255) },
	Frag = { body = Color3.fromRGB(82, 96, 60), band = Color3.fromRGB(60, 70, 44) },
}
local function grenade(m, kind)
	local look = GRENADE[kind]
	local up = CFrame.Angles(0, 0, math.rad(90)) -- cylinders stand up
	if kind == "Frag" then
		p(m, Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, 0, 0), look.body, Enum.PartType.Ball)
		p(m, Vector3.new(0.34, 0.5, 0.5), CFrame.new(0, 0.72, 0) * up, METAL, Enum.PartType.Cylinder, Enum.Material.Metal)
	else
		local w = kind == "Flash" and 0.78 or 0.95
		p(m, Vector3.new(1.55, w, w), CFrame.new(0, 0, 0) * up, look.body, Enum.PartType.Cylinder)
		p(m, Vector3.new(0.22, w + 0.02, w + 0.02), CFrame.new(0, 0.1, 0) * up, look.band, Enum.PartType.Cylinder)
		if kind == "Flash" then
			p(m, Vector3.new(0.12, w + 0.02, w + 0.02), CFrame.new(0, -0.45, 0) * up, look.band, Enum.PartType.Cylinder)
		end
		p(m, Vector3.new(0.22, w * 0.7, w * 0.7), CFrame.new(0, 0.88, 0) * up, METAL, Enum.PartType.Cylinder, Enum.Material.Metal)
	end
	p(m, Vector3.new(0.12, 1.0, 0.14), CFrame.new(0, 0.4, 0.58) * CFrame.Angles(math.rad(10), 0, 0), METAL, nil, Enum.Material.Metal)
	p(m, Vector3.new(0.08, 0.36, 0.36), CFrame.new(0, 1.04, -0.4), METAL, Enum.PartType.Cylinder, Enum.Material.Metal)
end
BUILDERS.Smoke = function(m) grenade(m, "Smoke") end
BUILDERS.Flash = function(m) grenade(m, "Flash") end
BUILDERS.Frag = function(m) grenade(m, "Frag") end

-- three-quarter "held" pose: barrel out to the left, angled toward you and up, top tipped into view
local POSE_GUN = CFrame.Angles(0, 0, math.rad(-15)) * CFrame.Angles(math.rad(12), 0, 0) * CFrame.Angles(0, math.rad(108), 0)
local POSE_DRAWN = CFrame.Angles(math.rad(10), 0, 0) * CFrame.Angles(0, math.rad(90 + 24), 0) * CFrame.Angles(0, 0, math.rad(-6))
local CORNERS = { Vector3.new(1, 1, 1), Vector3.new(1, 1, -1), Vector3.new(1, -1, 1), Vector3.new(1, -1, -1),
	Vector3.new(-1, 1, 1), Vector3.new(-1, 1, -1), Vector3.new(-1, -1, 1), Vector3.new(-1, -1, -1) }

local function iconModel(kind: string, id: string): Model
	local m = Instance.new("Model")
	local repo = ReplicatedStorage:FindFirstChild("Repository")
	local src
	if kind == "Gun" then
		local cfg = WeaponConfig.Get(id)
		src = repo and repo.Weapons:FindFirstChild(cfg and cfg.ToolName or id)
	elseif kind == "Melee" and repo and repo:FindFirstChild("Melee") then
		src = repo.Melee:FindFirstChild(id)
	end
	if src then
		for _, d in src:GetDescendants() do
			if d:IsA("BasePart") and d.Transparency < 0.9 then
				local c = d:Clone()
				for _, k in c:GetChildren() do
					if not k:IsA("DataModelMesh") then k:Destroy() end
				end
				c.Anchored = true
				-- lift the dark gunmetal so it reads on the dark glass
				c.Color = c.Color:Lerp(Color3.new(1, 1, 1), 0.3)
				c.Parent = m
			end
		end
	end
	local pose = POSE_GUN
	if #m:GetChildren() == 0 and BUILDERS[id] then
		BUILDERS[id](m)
		pose = POSE_DRAWN
		m:SetAttribute("Drawn", true)
	end
	-- centre on the origin, then pose
	local cf = m:GetBoundingBox()
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then d.CFrame = pose * (CFrame.new(-cf.Position) * d.CFrame) end
	end
	-- re-centre on the posed shape's world-axis bounds
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			local h = d.Size / 2
			for _, s in CORNERS do
				local w = d.CFrame:PointToWorldSpace(h * s)
				lo, hi = lo:Min(w), hi:Max(w)
			end
		end
	end
	local mid = (lo + hi) / 2
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then d.CFrame = d.CFrame - mid end
	end
	return m
end

-- camera on +Z looking at the origin, far enough back that the item fills `fill` of the box
local function fitCamera(model: Model, box: Vector2, fill: number): CFrame
	local tH = math.tan(math.rad(ICON_FOV / 2))
	local aspect = box.X / box.Y
	local d = 0
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local h = part.Size / 2
			for _, s in CORNERS do
				local w = part.CFrame:PointToWorldSpace(h * s)
				d = math.max(d, w.Z + math.abs(w.X) / (tH * aspect * fill), w.Z + math.abs(w.Y) / (tH * fill))
			end
		end
	end
	return CFrame.lookAt(Vector3.new(0, 0, d * 1.04), Vector3.zero)
end

local function paintFlat(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Color = WHITE
			d.Material = Enum.Material.SmoothPlastic
			if d:IsA("MeshPart") then d.TextureID = "" end
		elseif d:IsA("SpecialMesh") then
			d.TextureId = ""
		end
	end
end

local function viewport(parent, offset: Vector2, z: number)
	local v = Instance.new("ViewportFrame")
	v.BackgroundTransparency = 1
	v.Size = UDim2.fromScale(1, 1)
	v.Position = UDim2.fromOffset(offset.X, offset.Y)
	v.ZIndex = z
	local cam = Instance.new("Camera")
	cam.FieldOfView = ICON_FOV
	cam.Parent = v
	v.CurrentCamera = cam
	v.Parent = parent
	return v
end

-- the tile's item: a soft drop shadow under the lit render (same as the armory's renders)
local function makeRender(parent: GuiObject)
	local box = Instance.new("Frame")
	box.Name = "Item"
	box.BackgroundTransparency = 1
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.new(0.5, 0, 0.5, RENDER_LIFT)
	box.Size = UDim2.fromOffset(RENDER.X, RENDER.Y)
	box.ZIndex = 4
	local scale = Instance.new("UIScale")
	scale.Scale = 0.92
	scale.Parent = box
	local shadow = viewport(box, Vector2.new(3, 5), 4)
	shadow.Ambient, shadow.LightColor = BLACK, BLACK
	shadow.ImageTransparency = 0.45
	local main = viewport(box, Vector2.zero, 5)
	main.Ambient = Color3.fromRGB(190, 190, 198)
	main.LightColor = Color3.fromRGB(255, 255, 255)
	main.LightDirection = Vector3.new(0.35, -0.85, -0.6)
	local picture = Instance.new("ImageLabel") -- optional picture override (HotbarConfig.Images)
	picture.Name = "Picture"
	picture.BackgroundTransparency = 1
	picture.ScaleType = Enum.ScaleType.Fit
	picture.Size = UDim2.fromScale(1, 1)
	picture.ZIndex = 6
	picture.Visible = false
	picture.Parent = box
	box.Parent = parent

	local shown
	local function set(kind: string, id: string)
		local key = kind .. ":" .. id
		if shown == key then return end
		shown = key
		local model = iconModel(kind, id)
		local camCF = fitCamera(model, RENDER, model:GetAttribute("Drawn") and 0.7 or 0.92)
		for _, v in { shadow, main } do
			for _, c in v:GetChildren() do
				if c:IsA("Model") then c:Destroy() end
			end
			local copy = v == main and model or model:Clone()
			if v ~= main then paintFlat(copy) end
			copy.Parent = v
			v.CurrentCamera.CFrame = camCF
		end
	end
	return { box = box, scale = scale, set = set, main = main, shadow = shadow, picture = picture }
end

-- a UI-only mesh from ReplicatedStorage.UIIcons as a flat white silhouette (nil when it isn't there)
local function meshIcon(parent: GuiObject, name: string, size: Vector2, z: number): ViewportFrame?
	local folder = ReplicatedStorage:FindFirstChild("UIIcons")
	local src = folder and folder:FindFirstChild(name)
	if not src then return nil end
	local m = Instance.new("Model")
	for _, part in (src:IsA("BasePart") and { src } or src:GetDescendants()) do
		if part:IsA("BasePart") then
			local c = part:Clone()
			for _, k in c:GetChildren() do
				if not k:IsA("DataModelMesh") then k:Destroy() end
			end
			c.Anchored = true
			c.Parent = m
		end
	end
	if #m:GetChildren() == 0 then return nil end
	local cf = m:GetBoundingBox()
	for _, part in m:GetChildren() do part.CFrame = CFrame.new(-cf.Position) * part.CFrame end
	paintFlat(m)
	local v = viewport(parent, Vector2.zero, z)
	v.Size = UDim2.fromOffset(size.X, size.Y)
	v.Ambient, v.LightColor = WHITE, BLACK
	m.Parent = v
	v.CurrentCamera.CFrame = fitCamera(m, size, 0.96)
	return v
end

-- // Tiles ------------------------------------------------------------------------------------------------
local function text(parent: Instance, font: Font, size: number, color: Color3, z: number): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.FontFace = font
	t.TextSize = size
	t.TextColor3 = color
	t.ZIndex = z
	t.Parent = parent
	return t
end
-- the armory's subtle dark edge, for text that sits over the world
local function shade(t: GuiObject, thick: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = BLACK
	s.Thickness = thick or 1.5
	s.Transparency = 0.45
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = t
	return s
end
local function round(f: GuiObject, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = f
end

local function makeTile(i: number)
	-- a row, left to right: 1 gun, 2 melee, 3 gadget; anchored bottom-centre so the held one grows upwards
	local tile = Instance.new("Frame")
	tile.Name = "Slot" .. i
	tile.AnchorPoint = Vector2.new(0.5, 1)
	tile.Position = UDim2.fromOffset((i - 1) * (TILE.X + GAP) + TILE.X / 2, TILE.Y)
	tile.Size = UDim2.fromOffset(TILE.X, TILE.Y)
	tile.BackgroundColor3 = TILE_GREY
	tile.BackgroundTransparency = TILE_T
	tile.BorderSizePixel = 0
	tile.ZIndex = 1
	local grow = Instance.new("UIScale")
	grow.Scale = 0.86
	grow.Parent = tile
	-- held: a black fade toward the bottom of the tile
	local fade = Instance.new("Frame")
	fade.Name = "Fade"
	fade.Size = UDim2.fromScale(1, 1)
	fade.BackgroundColor3 = BLACK
	fade.BackgroundTransparency = 1
	fade.BorderSizePixel = 0
	fade.ZIndex = 2
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.35, 0.85), NumberSequenceKeypoint.new(1, 0.1),
	})
	g.Parent = fade
	fade.Parent = tile
	round(tile, 10)
	round(fade, 10)
	-- the held one gets a soft white edge
	local edge = Instance.new("UIStroke")
	edge.Color = WHITE
	edge.Thickness = 2
	edge.Transparency = 1
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = tile

	-- slot key, top left
	local keyBox = Instance.new("Frame")
	keyBox.Name = "KeyBox"
	keyBox.Position = UDim2.fromOffset(8, 6)
	keyBox.Size = UDim2.fromOffset(20, 22)
	keyBox.BackgroundTransparency = 1
	keyBox.BorderSizePixel = 0
	keyBox.ZIndex = 9
	keyBox.Parent = tile
	local key = text(keyBox, STENCIL, 18, SUB, 10)
	key.TextXAlignment = Enum.TextXAlignment.Left
	key.Name = "Key"
	key.Size = UDim2.fromScale(1, 1)
	key.Text = tostring(i)
	shade(key, 1)

	-- bottom left: big number, small number, bullets
	local count = Instance.new("Frame")
	count.Name = "Count"
	count.BackgroundTransparency = 1
	count.AnchorPoint = Vector2.new(0, 1)
	count.Position = UDim2.new(0, 10, 1, -6)
	count.Size = UDim2.fromOffset(TILE.X - 20, 40)
	count.ZIndex = 9
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 5)
	list.Parent = count
	local big = text(count, STENCIL, 40, WHITE, 9)
	big.Name = "Big"
	big.LayoutOrder = 1
	big.AutomaticSize = Enum.AutomaticSize.X
	big.Size = UDim2.fromOffset(0, 40)
	big.TextYAlignment = Enum.TextYAlignment.Bottom
	shade(big, 1.5)
	local small = text(count, STENCIL, 21, SUB, 9)
	small.Name = "Small"
	small.LayoutOrder = 2
	small.AutomaticSize = Enum.AutomaticSize.X
	small.Size = UDim2.fromOffset(0, 24)
	small.TextYAlignment = Enum.TextYAlignment.Bottom
	local pad = Instance.new("UIPadding")
	pad.PaddingBottom = UDim.new(0, 3)
	pad.Parent = small
	shade(small, 1)
	local bullets = Instance.new("Frame")
	bullets.Name = "Bullets"
	bullets.LayoutOrder = 3
	bullets.BackgroundTransparency = 1
	bullets.Size = UDim2.fromOffset(20, 24)
	bullets.Visible = false
	bullets.ZIndex = 9
	bullets.Parent = count
	count.Parent = tile

	local icon = makeRender(tile)
	tile.Parent = column
	return { tile = tile, fade = fade, key = key, keyBox = keyBox, big = big, small = small, bullets = bullets, icon = icon,
		edge = edge, grow = grow, title = "", selected = nil, empty = nil }
end

-- the gun tile's bullets icon: the mesh render, or three drawn rounds if the mesh isn't there
local function addBullets(holder: Frame)
	holder.Visible = true
	if meshIcon(holder, "Bullets", Vector2.new(20, 19), 9) then return end
	for n = 0, 2 do
		local b = Instance.new("Frame")
		b.BackgroundColor3 = WHITE
		b.BorderSizePixel = 0
		b.Position = UDim2.fromOffset(2 + n * 6, 3)
		b.Size = UDim2.fromOffset(4, 15)
		b.ZIndex = 9
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = b
		b.Parent = holder
	end
end

-- // Build -------------------------------------------------------------------------------------------
local function keycap(parent: Instance, key: string, order: number)
	local cap = Instance.new("TextLabel")
	cap.LayoutOrder = order
	cap.AutomaticSize = Enum.AutomaticSize.X
	cap.Size = UDim2.fromOffset(22, 22)
	cap.BackgroundColor3 = BLACK
	cap.BackgroundTransparency = 0.42 -- dark glass, like the tiles
	cap.BorderSizePixel = 0
	round(cap, 6)
	cap.FontFace = FONT
	cap.TextSize = 14
	cap.TextColor3 = WHITE
	cap.Text = key
	local pad = Instance.new("UIPadding") pad.PaddingLeft = UDim.new(0, 7) pad.PaddingRight = UDim.new(0, 7) pad.Parent = cap
	cap.Parent = parent
	return cap
end

local function buildUI()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hotbar"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Global -- every item draws over every tile, so they can spill onto the next one
	local canvas = Kit.canvas(gui) -- [UI] 1920x1080 design canvas

	-- quick controls (very bottom right): just text + keycaps, no box
	local hints = Instance.new("Frame")
	hints.Name = "Controls"
	hints.AnchorPoint = Vector2.new(1, 1)
	hints.Position = UDim2.fromScale(1 - 22 / 1920, 1 - 14 / 1080)
	hints.AutomaticSize = Enum.AutomaticSize.X
	hints.Size = UDim2.fromOffset(0, 26)
	hints.BackgroundTransparency = 1
	local hlist = Instance.new("UIListLayout")
	hlist.FillDirection = Enum.FillDirection.Horizontal
	hlist.VerticalAlignment = Enum.VerticalAlignment.Center
	hlist.SortOrder = Enum.SortOrder.LayoutOrder
	hlist.Padding = UDim.new(0, 6)
	hlist.Parent = hints
	-- [SET] the quick-controls strip uses Tacticals' names and your binds (rebuilt when a bind changes)
	local HINTS = {
		{ "Leave", "LeaveTraining", "M" }, { "Take Cover", "TakeCover", "Q" }, { "Gun Bash", "GunBash", "F" }, { "Throw Gadget", "ThrowGadget", "G" },
		{ "Reload", "Reload", "R" },
	}
	local function keyName(action, fallback)
		local k = Binds.Key(localPlayer, action, nil)
		if not k then return fallback end
		local short = { MouseButton1 = "M1", MouseButton2 = "M2", MouseButton3 = "M3", LeftShift = "Shift", LeftControl = "Ctrl",
			LeftAlt = "Alt", One = "1", Two = "2", Three = "3", Four = "4", Five = "5", Six = "6", Seven = "7", Eight = "8", Nine = "9", Zero = "0" }
		return short[k.Name] or k.Name
	end
	local function buildHints()
		for _, c in hints:GetChildren() do if not c:IsA("UIListLayout") then c:Destroy() end end
		for i, entry in HINTS do
			if entry[2] == "LeaveTraining" and localPlayer:GetAttribute("InTraining") ~= true then continue end -- only in Training
			local label = text(hints, FONT, 16, WHITE, 1)
			label.LayoutOrder = i * 10
			label.AutomaticSize = Enum.AutomaticSize.X
			label.Size = UDim2.fromOffset(0, 22)
			label.Text = (i > 1 and "    " or "") .. entry[1]
			shade(label, 1)
			keycap(hints, keyName(entry[2], entry[3]), i * 10 + 1)
		end
	end
	buildHints()
	for _, entry in HINTS do Binds.Changed(localPlayer, entry[2], buildHints) end
	localPlayer:GetAttributeChangedSignal("InTraining"):Connect(buildHints)
	hints.Parent = canvas
	-- Settings > Game > Gameplay HUD "Minimal": in a match only the tiles (ammo) and health stay, so the key hints go
	local function minimalHints()
		local inMatch = localPlayer:GetAttribute("InDuel") == true or localPlayer:GetAttribute("InMatch") == true
		hints.Visible = not (inMatch and localPlayer:GetAttribute("Setting_GameplayHUD") == "Minimal")
	end
	for _, a in { "InDuel", "InMatch", "Setting_GameplayHUD" } do localPlayer:GetAttributeChangedSignal(a):Connect(minimalHints) end
	minimalHints()

	column = Instance.new("Frame")
	column.Name = "Tiles"
	column.AnchorPoint = Vector2.new(1, 1)
	column.Position = UDim2.fromOffset(1920 - 30, 1080 - 64)
	column.Size = UDim2.fromOffset(3 * TILE.X + 2 * GAP, TILE.Y)
	column.BackgroundTransparency = 1
	column.Parent = canvas

	-- name of what's in your hands: big stencil type above the row, an olive bar at its right end
	heldName = text(column, STENCIL, 56, BONE, 10)
	heldName.Name = "HeldName"
	heldName.AnchorPoint = Vector2.new(1, 1)
	heldName.Position = UDim2.new(1, -4, 0, -12)
	heldName.Size = UDim2.fromOffset(520, 62)
	heldName.TextXAlignment = Enum.TextXAlignment.Right
	heldName.TextTransparency = 1
	heldStroke = shade(heldName, 2)
	heldStroke.Transparency = 1

	for i = 1, 3 do
		slots[i] = makeTile(i)
	end
	addBullets(slots[GUN].bullets)
	Kit.toScale(column, Vector2.new(3 * TILE.X + 2 * GAP, TILE.Y)) -- [UI] Scale only
	column.Position = UDim2.fromScale((1920 - 30) / 1920, (1080 - 64) / 1080)
	column.Size = UDim2.fromScale((3 * TILE.X + 2 * GAP) / 1920, TILE.Y / 1080)
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
end

local function setArt(slot, kind: string, id: string)
	local images = HotbarConfig.Images or {}
	local image = images[id] or ""
	local ic = slot.icon
	ic.picture.Image = image
	ic.picture.Visible = image ~= ""
	ic.main.Visible = image == ""
	ic.shadow.Visible = image == ""
	if image == "" then ic.set(kind, id) end
end

-- "AUTOMATIC RIFLE" -> "Automatic Rifle"
local function titleCase(s: string): string
	return (string.gsub(string.lower(s), "(%a)([%w']*)", function(a, b) return string.upper(a) .. b end))
end

local function amount(n: number?): string
	if not n then return "" end
	if n == math.huge or n >= 1e6 then return "∞" end
	return tostring(math.floor(n + 0.5))
end

local function refreshUI()
	local active = controller.ActiveSlot()
	local gun = findTool(function(t) return t:GetAttribute("WeaponId") ~= nil end)
	local gunId = gun and gun:GetAttribute("WeaponId") or (localPlayer:GetAttribute("Loadout") or WeaponConfig.DefaultWeapon)
	local gunConfig = WeaponConfig.Get(gunId)
	local Gadget = Get("GadgetController")
	local charges = Gadget and Gadget.GetCharges() or 0

	-- gun: magazine (big), reserve (small), bullets
	local g = slots[GUN]
	g.title = titleCase((gunConfig and gunConfig.DisplayName) or gunId)
	setArt(g, "Gun", gunId)
	local current, reserve, reloading = HUD.GetAmmo()
	if gun and gun:GetAttribute("Ammo") then current = gun:GetAttribute("Ammo") end
	if gun and gun:GetAttribute("Reserve") then reserve = gun:GetAttribute("Reserve") end
	g.big.Text = amount(current)
	g.big.TextColor3 = reloading and SUB or (current == 0 and RED or WHITE)
	g.small.Text = reloading and "RELOADING" or amount(reserve)
	g.small.TextColor3 = reloading and BLUE or SUB
	g.bullets.Visible = not reloading

	-- gadget: how many are left
	local d = slots[GADGET]
	d.title = titleCase(Gadget and Gadget.GetGadgetName() or "Gadget")
	setArt(d, "Gadget", localPlayer:GetAttribute("KitGadget") or "Smoke")
	d.big.Text = charges == math.huge and "" or amount(charges)
	d.big.TextColor3 = charges <= 0 and RED or WHITE
	d.small.Text = ""

	-- melee
	local melee = findTool(function(t) return t:GetAttribute("Melee") == true end)
	local meleeId = melee and melee:GetAttribute("MeleeId") or localPlayer:GetAttribute("KitMelee") or MeleeConfig.Default
	local meleeCfg = meleeId and MeleeConfig.Weapons[meleeId]
	local mel = slots[MELEE]
	mel.title = titleCase(meleeCfg and meleeCfg.DisplayName or "Melee")
	setArt(mel, "Melee", meleeId or "Fists")
	mel.big.Text = ""
	mel.small.Text = ""

	-- the held item's name slides in beside its tile
	if active ~= shownActive then
		shownActive = active
		if active > 0 then
			heldName.Text = string.upper(slots[active].title)
			heldName.TextTransparency = 1
			heldStroke.Transparency = 1
			TweenService:Create(heldName, TweenInfo.new(0.22, Enum.EasingStyle.Quint), { TextTransparency = 0 }):Play()
			TweenService:Create(heldStroke, TI, { Transparency = 0.45 }):Play()
		else
			TweenService:Create(heldName, TI, { TextTransparency = 1 }):Play()
			TweenService:Create(heldStroke, TI, { Transparency = 1 }):Play()
		end
	elseif active > 0 then
		heldName.Text = string.upper(slots[active].title)
	end

	for i, sl in slots do
		local on = i == active
		local empty = i == GADGET and charges <= 0
		if sl.selected ~= on or sl.empty ~= empty then
			sl.selected, sl.empty = on, empty
			TweenService:Create(sl.tile, TI, { BackgroundColor3 = on and HELD_FILL or TILE_GREY, BackgroundTransparency = on and HELD_T or TILE_T }):Play()
			TweenService:Create(sl.grow, POP, { Scale = on and 1 or 0.86 }):Play()
			TweenService:Create(sl.edge, TI, { Transparency = on and 0.35 or 1 }):Play()
			TweenService:Create(sl.fade, TI, { BackgroundTransparency = on and 0 or 1 }):Play()
			TweenService:Create(sl.icon.scale, POP, { Scale = on and 1.08 or 0.92 }):Play()
			local tint = empty and Color3.fromRGB(90, 96, 80) or (on and Color3.fromRGB(236, 232, 218) or Color3.fromRGB(200, 198, 186))
			TweenService:Create(sl.icon.main, TI, { ImageColor3 = tint, ImageTransparency = empty and 0.4 or 0 }):Play()
			TweenService:Create(sl.icon.shadow, TI, { ImageTransparency = empty and 0.8 or 0.45 }):Play()
			sl.key.TextColor3 = on and BONE or SUB
		end
	end
end

function controller.Start()
	buildUI()
	-- F is also the door key: next to a door panel (its prompt is showing) F works the door instead
	local promptsShown = 0
	local PPS = game:GetService("ProximityPromptService")
	PPS.PromptShown:Connect(function(prompt)
		if prompt.KeyboardKeyCode == MeleeConfig.QuickMelee.Key then promptsShown += 1 end
	end)
	PPS.PromptHidden:Connect(function(prompt)
		if prompt.KeyboardKeyCode == MeleeConfig.QuickMelee.Key then promptsShown = math.max(promptsShown - 1, 0) end
	end)
	-- [SET] Gun Bash, slot keys: Settings > Hotkeys (rebound when they change)
	local function slotKeys()
		return {
			Binds.Key(localPlayer, "EquipGun", HotbarConfig.Keys[1]),
			Binds.Key(localPlayer, "EquipMelee", HotbarConfig.Keys[2]),
			Binds.Key(localPlayer, "EquipGadget", HotbarConfig.Keys[3]),
		}
	end
	local function bindQuickMelee()
		ContextActionService:UnbindAction("QuickMelee")
		ContextActionService:BindActionAtPriority("QuickMelee", function(_, state)
			if promptsShown > 0 then return Enum.ContextActionResult.Pass end
			if state == Enum.UserInputState.Begin then quickMelee() end
			return Enum.ContextActionResult.Sink
		end, false, 2500, Binds.Key(localPlayer, "GunBash", MeleeConfig.QuickMelee.Key), Enum.KeyCode.ButtonR1)
	end
	bindQuickMelee()
	Binds.Changed(localPlayer, "GunBash", bindQuickMelee)
	-- [TOUCH] mobile: Gun Bash + the three equip circles (gun / melee / gadget)
	task.spawn(function()
		local ok, IA = pcall(function() return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("InputActions", 15)) end)
		if not ok or not IA then return end
		IA.Bind("QuickMelee", function(state) if state == Enum.UserInputState.Begin then quickMelee() end end)
		for slot, action in { [GUN] = "Equip1", [MELEE] = "Equip2", [GADGET] = "Equip3" } do
			IA.Bind(action, function(state)
				if state ~= Enum.UserInputState.Begin then return end
				-- the gun itself is drawn by WeaponController's Equip1 hook (its holster toggle); here only leave gadget mode
				if slot == GUN then smokeMode = false return end
				select(slot)
			end)
		end
	end)
	-- the kit can change mid-session (tutorial 2 swaps smoke for flash): keep the gadget slot current
	for _, attribute in { "KitGadget", "SmokeCharges", "FlashCharges", "Loadout", "KitMelee" } do
		localPlayer:GetAttributeChangedSignal(attribute):Connect(function() task.defer(refreshUI) end)
	end
	local function bindSlots()
		ContextActionService:UnbindAction("HotbarSlots")
		local keys = slotKeys()
		ContextActionService:BindActionAtPriority("HotbarSlots", function(_, state, input)
			if state ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
			local slot = table.find(keys, input.KeyCode)
			if slot == 1 then
				smokeMode = false
				return Enum.ContextActionResult.Pass -- WeaponController draws / holsters the gun
			end
			if slot then select(slot) end
			return Enum.ContextActionResult.Sink
		end, false, 2500, table.unpack(keys))
	end
	bindSlots()
	for _, a in { "EquipGun", "EquipMelee", "EquipGadget" } do Binds.Changed(localPlayer, a, bindSlots) end
	-- [SET] Game > Controls > Scroll Equip: the mouse wheel steps gun -> melee -> gadget
	local lastScroll = 0
	UserInputService.InputChanged:Connect(function(input, gp)
		if gp or input.UserInputType ~= Enum.UserInputType.MouseWheel then return end
		if localPlayer:GetAttribute("Setting_ScrollEquip") == false or os.clock() - lastScroll < 0.15 then return end
		local Cam = Get("CameraController")
		if Cam and Cam.IsMouseFree and Cam.IsMouseFree() then return end
		lastScroll = os.clock()
		local order = { GUN, MELEE, GADGET }
		local i = table.find(order, controller.ActiveSlot()) or 1
		for step = 1, 3 do
			local nextSlot = order[(i - 1 + (input.Position.Z < 0 and step or -step)) % 3 + 1]
			local before = controller.ActiveSlot()
			select(nextSlot)
			if controller.ActiveSlot() ~= before then break end
		end
	end)

	-- Left click with the melee (2) or gadget (3) out (above the gun's fire binding)
	ContextActionService:BindActionAtPriority("HotbarUse", function(_, state)
		local Cam = Get("CameraController") -- (pass 45) cursor freed: clicks are for the UI
		if Cam and Cam.IsMouseFree and Cam.IsMouseFree() then return Enum.ContextActionResult.Pass end
		local slot = controller.ActiveSlot()
		if slot == 3 then
			local Gadget = Get("GadgetController")
			if state == Enum.UserInputState.Begin then Gadget.Press()
			elseif state == Enum.UserInputState.End then Gadget.Release() end
			return Enum.ContextActionResult.Sink
		elseif slot == 2 then
			if state == Enum.UserInputState.Begin then slash() end
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, 2500, Enum.UserInputType.MouseButton1)

	RunService.Heartbeat:Connect(function()
		-- out of smokes in slot 2: back to the gun
		if smokeMode then
			local Gadget = Get("GadgetController")
			if not humanoidOf() then
				smokeMode = false
			elseif Gadget and Gadget.GetCharges() <= 0 then
				if not returning then
					returning = true
					task.delay(0.6, function()
						returning = false
						if smokeMode and Gadget.GetCharges() <= 0 then select(1) end
					end)
				end
			elseif heldTool() then
				smokeMode = false -- something got equipped (e.g. 1)
			end
		end
		refreshUI()
	end)
	__TG.CharacterAdded:Connect(function() smokeMode = false end)
end

return controller
