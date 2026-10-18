local __TG = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("TrainingGate"))
-- StarterPlayer/StarterPlayerScripts/Client/Controllers/ScopeController (ModuleScript)
-- Scoped weapons (WeaponConfig: Scope = { ... }, e.g. the sniper). Aiming raises the scope to your eye:
--   In    : the camera slides from over your shoulder into your eye (your body fades away), the
--           eyepiece's shadow closes in around the lens, and the view zooms through the glass.
--   Out   : the same path backwards - the lens goes first, then the camera slides back to the shoulder.
--   Shot  : a hard but clean kick - the view snaps up and rolls a touch, the lens jolts and flashes and
--           the FOV punches out, then it all springs back onto the target. Then the bolt is worked:
--           a small roll and dip.
--   Reload: drops the scope (it comes back up if you're still aiming when the reload is done).
--   Feel  : breathing sways the reticle a little; moving the mouse makes the scope lag behind (parallax).
--
-- CameraController reads Blend() (how far the camera has moved into the eye), Zoom() (how far the FOV
-- has gone to the scope's) and FOV(). This module runs after the cinematic layer (RenderPriority
-- Camera + 5) to add the scoped motion and draw the overlay.
--
-- Public: Blend(), Zoom(), FOV(), UsesScope(), IsScoped(), OnShot(config), OnReload(seconds)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
RunService = __TG.RunService
local UserInputService = game:GetService("UserInputService")
UserInputService = __TG.UserInputService
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared")
local WeaponConfig = require(Shared:WaitForChild("Config"):WaitForChild("WeaponConfig"))

local Get = shared.Get
local localPlayer = Players.LocalPlayer
local controller = {}

local DEFAULT = { FOV = 14, InTime = 0.3, OutTime = 0.22, Sway = 1, RecoilScale = 0.45 }
local CLICK = "rbxassetid://9117197553" -- short metal click (scope in / out, bolt)

-- // State
local p = 0               -- sequence progress: 0 = over the shoulder, 1 = fully scoped
local cfg = nil           -- the equipped weapon's Scope table
local lastCfg = DEFAULT
local blockUntil = 0      -- reloading: no scope until then
local wasWanted = false
local boltAt = nil
local flash = 0
local lensOffset, lensVel = Vector2.zero, Vector2.zero
local swayPhase = 0

-- simple damped springs for the shot motion
local springs = {
	pitch = { x = 0, v = 0, k = 140, d = 15 },
	roll = { x = 0, v = 0, k = 120, d = 13 },
	fov = { x = 0, v = 0, k = 160, d = 17 },
	lensY = { x = 0, v = 0, k = 150, d = 14 },
	lensX = { x = 0, v = 0, k = 150, d = 14 },
}
local function stepSpring(s, dt: number)
	local a = -s.x * s.k - s.v * s.d
	s.v += a * dt
	s.x += s.v * dt
end

local function clamp01(x: number): number
	return math.clamp(x, 0, 1)
end
local function smootherstep(x: number): number
	x = clamp01(x)
	return x * x * x * (x * (x * 6 - 15) + 10)
end

-- // What's in your hands (the weapon's Scope table, missing values filled from DEFAULT)
local cachedTool, cachedScope = nil, nil
local function currentScope()
	local character = localPlayer.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	if tool ~= cachedTool then
		cachedTool, cachedScope = tool, nil
		local config = tool and WeaponConfig.Get(tool:GetAttribute("WeaponId") or "")
		local scope = config and config.Scope
		if scope then
			cachedScope = setmetatable({}, { __index = function(_, k)
				local v = scope[k]
				if v == nil then return DEFAULT[k] end
				return v
			end })
		end
	end
	return cachedScope, tool
end

-- // Public
function controller.Blend(): number -- camera position: 0 = shoulder, 1 = eye
	return smootherstep(p / 0.8)
end

function controller.Zoom(): number -- FOV: 0 = normal aim, 1 = through the scope
	return smootherstep((p - 0.7) / 0.3)
end

function controller.FOV(): number
	return (cfg or lastCfg).FOV
end

function controller.UsesScope(): boolean
	return cfg ~= nil or p > 0
end

function controller.Progress(): number -- 0..1 along the raise-to-eye sequence (the spectate relay sends it)
	return p
end

function controller.IsScoped(): boolean
	return p > 0.9
end

function controller.OnShot(_config)
	if p < 0.5 then return end
	springs.pitch.v += 95
	springs.roll.v += (math.random() < 0.5 and -1 or 1) * 70
	springs.fov.v += 55
	springs.lensY.v += 1300
	springs.lensX.v += (math.random() - 0.5) * 500
	flash = 1
	boltAt = os.clock() + 0.55
end

function controller.OnReload(seconds: number)
	blockUntil = os.clock() + (seconds or 0)
end

-- // Sounds
local function click(pitch: number, volume: number)
	local s = Instance.new("Sound")
	s.SoundId = CLICK
	s.Volume = volume
	s.PlaybackSpeed = pitch
	s.Parent = workspace.CurrentCamera
	s:Play()
	s.Ended:Connect(function() s:Destroy() end)
end

-------------------------------------------------------------------------------
-- Overlay: a black eyepiece with a round lens, a duplex reticle with mil dots and a lit centre dot,
-- a faint lens tint and glare. The black around the lens is one circle with a huge stroke.
-------------------------------------------------------------------------------
local ui = {}
local function new(class: string, props, children)
	local inst = Instance.new(class)
	for k, v in props or {} do
		if k ~= "Parent" then inst[k] = v end
	end
	for _, c in children or {} do c.Parent = inst end
	if props and props.Parent then inst.Parent = props.Parent end
	return inst
end
local function circle() return new("UICorner", { CornerRadius = UDim.new(1, 0) }) end

local function buildOverlay()
	local gui = new("ScreenGui", { Name = "ScopeOverlay", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 4,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Enabled = false })
	gui:SetAttribute("NoStyle", true)
	ui.gui = gui
	-- the moment the eye meets the eyepiece: a short darkening
	ui.dark = new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
		ZIndex = 20, Parent = gui })
	-- the lens: everything outside it is the black of the scope tube
	local lens = new("Frame", { Name = "Lens", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(600, 600), ZIndex = 5, Parent = gui }, { circle() })
	ui.lens = lens
	ui.mask = new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 3000, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = lens })
	-- soft inner edge (the tube's shadow on the glass) and a dark metal rim
	ui.rings = {}
	for i, t in { 0.3, 0.46, 0.59, 0.7, 0.79, 0.86, 0.91, 0.95 } do
		local r = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1 - (i - 1) * 0.012, 1 - (i - 1) * 0.012), ZIndex = 6, Parent = lens }, { circle() })
		local s = new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 8, Transparency = t, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = r })
		table.insert(ui.rings, { stroke = s, base = t })
	end
	local rim = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1), ZIndex = 7, Parent = lens }, { circle() })
	ui.rim = new("UIStroke", { Color = Color3.fromRGB(46, 48, 52), Thickness = 2, Transparency = 0.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = rim })

	-- the glass (clipped to the circle): tint, glare, reticle, shot flash
	local glass = new("CanvasGroup", { Name = "Glass", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = lens }, { circle() })
	ui.glass = glass
	new("Frame", { Name = "Tint", BackgroundColor3 = Color3.fromRGB(176, 214, 222), BackgroundTransparency = 0.94, BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1), Parent = glass })
	local glare = new("Frame", { Name = "Glare", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.9, BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1), Parent = glass })
	new("UIGradient", { Rotation = 35, Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.22, 0.75), NumberSequenceKeypoint.new(0.4, 1), NumberSequenceKeypoint.new(1, 1) }), Parent = glare })
	ui.flash = new("Frame", { Name = "Flash", BackgroundColor3 = Color3.fromRGB(255, 244, 220), BackgroundTransparency = 1, BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = glass })

	-- reticle: thin crosshair through the middle, thick posts toward the edge, mil dots, lit centre
	local ink = Color3.fromRGB(8, 8, 10)
	local function bar(x, y, w, h)
		new("Frame", { BackgroundColor3 = ink, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, y),
			Size = UDim2.new(w[1], w[2], h[1], h[2]), ZIndex = 2, Parent = glass })
	end
	bar(0.5, 0.5, { 1, 0 }, { 0, 1.5 })          -- thin horizontal
	bar(0.5, 0.5, { 0, 1.5 }, { 1, 0 })          -- thin vertical
	bar(0.17, 0.5, { 0.34, 0 }, { 0, 6 })         -- left post
	bar(0.83, 0.5, { 0.34, 0 }, { 0, 6 })         -- right post
	bar(0.5, 0.83, { 0, 6 }, { 0.34, 0 })         -- bottom post
	bar(0.5, 0.17, { 0, 4 }, { 0.34, 0 })         -- top post (slimmer)
	for _, d in { -0.135, -0.1, -0.065, -0.03, 0.03, 0.065, 0.1, 0.135 } do
		for _, axis in { "x", "y" } do
			new("Frame", { BackgroundColor3 = ink, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
				Position = axis == "x" and UDim2.fromScale(0.5 + d, 0.5) or UDim2.fromScale(0.5, 0.5 + d),
				Size = UDim2.fromOffset(5, 5), ZIndex = 2, Parent = glass }, { circle() })
		end
	end
	local dot = new("Frame", { BackgroundColor3 = Color3.fromRGB(255, 40, 40), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(4, 4), ZIndex = 3, Parent = glass }, { circle() })
	new("Frame", { BackgroundColor3 = Color3.fromRGB(255, 60, 60), BackgroundTransparency = 0.75, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(10, 10), ZIndex = 2, Parent = glass }, { circle() })
	ui.dot = dot

	gui.Parent = localPlayer:WaitForChild("PlayerGui")
end

local function layout()
	local vs = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	local d = math.min(vs.X, vs.Y) * 0.94
	ui.size = d
	ui.mask.Thickness = math.max(vs.X, vs.Y) * 1.6
	for _, r in ui.rings do r.stroke.Thickness = math.max(3, d * 0.0075) end
end

-------------------------------------------------------------------------------
-- Per frame
-------------------------------------------------------------------------------
local function update(dt: number)
	dt = math.min(dt, 1 / 20)
	local Camera = Get("CameraController")
	if not Camera then return end
	local scope, tool = currentScope()
	cfg = scope
	if scope then lastCfg = scope end

	-- do we want the scope up?
	local reloading = (tool and tool:GetAttribute("Reloading") == true) or os.clock() < blockUntil
	local want = scope ~= nil and Camera.IsAiming() and not reloading
	-- [SPEC] (2026-10-18, Edward: spectating 1:1) watching someone: their scope progress (CameraController's _SpecScope)
	local spec = localPlayer:GetAttribute("_SpecScope")
	if typeof(spec) == "number" then want = false; wasWanted = false end
	if want and not wasWanted and p < 0.2 then click(0.75, 0.25) end
	if not want and wasWanted and p > 0.5 then click(0.9, 0.18) end
	wasWanted = want

	-- move along the sequence (put away fast if the gun itself is gone)
	local s = scope or lastCfg
	if typeof(spec) == "number" then
		p = math.clamp(spec, 0, 1)
	elseif want then
		p = math.min(1, p + dt / s.InTime)
	else
		p = math.max(0, p - dt / (scope and s.OutTime or 0.12))
	end

	-- shot springs and the bolt
	for _, sp in springs do stepSpring(sp, dt) end
	flash = math.max(0, flash - dt * 9)
	if boltAt and os.clock() >= boltAt then
		boltAt = nil
		if p > 0.5 then
			springs.roll.v += 38
			springs.pitch.v -= 22
			springs.lensX.v += 380
			click(0.62, 0.3)
			task.delay(0.16, function() click(0.7, 0.26) end)
		end
	end

	-- overlay visibility: the eyepiece closes in over the last stretch of the sequence
	local o = clamp01((p - 0.62) / 0.38)
	if not ui.gui then return end
	ui.gui.Enabled = o > 0.001
	if o <= 0.001 then
		lensOffset, lensVel = Vector2.zero, Vector2.zero
		return
	end
	if not ui.size then layout() end

	-- parallax: the scope trails the mouse a little, plus a soft walking bob
	local md = UserInputService:GetMouseDelta()
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local speed = root and (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude or 0
	swayPhase += dt * (1 + speed * 0.12)
	local target = Vector2.new(-md.X, -md.Y) * 0.9
	if target.Magnitude > 34 then target = target.Unit * 34 end
	local bob = Vector2.new(math.sin(swayPhase * 1.7) * 3, math.abs(math.sin(swayPhase * 1.7)) * 4) * math.clamp(speed / 10, 0, 1)
	lensVel += ((target + bob) - lensOffset) * dt * 180 - lensVel * math.min(1, dt * 16)
	lensOffset += lensVel * dt

	-- the eyepiece: starts wider than the screen and closes to the lens; a short black at the eye moment
	local e = smootherstep(o)
	local d = ui.size * (1 + (1 - e) * 1.1)
	local shake = Vector2.new(springs.lensX.x, springs.lensY.x) * 0.4
	ui.lens.Size = UDim2.fromOffset(d, d)
	ui.lens.Position = UDim2.new(0.5, lensOffset.X + shake.X, 0.5, lensOffset.Y + shake.Y)
	ui.mask.Transparency = 1 - math.min(1, e * 1.4)
	ui.dark.BackgroundTransparency = 1 - math.sin(math.min(o, 0.85) / 0.85 * math.pi) * 0.92
	ui.glass.GroupTransparency = 1 - clamp01((o - 0.55) / 0.45)
	ui.rim.Transparency = 1 - clamp01((o - 0.5) / 0.5) * 0.8
	for _, r in ui.rings do r.stroke.Transparency = 1 - (1 - r.base) * e end
	ui.flash.BackgroundTransparency = 1 - flash * 0.55

	-- scoped motion on the camera: breathing sway, the shot kick and the bolt (only while scoped)
	local cam = workspace.CurrentCamera
	local k = e
	local sway = (cfg or lastCfg).Sway
	local t = os.clock()
	local breathPitch = (math.sin(t * 1.25) * 0.07 + math.sin(t * 0.53) * 0.04) * sway
	local breathYaw = (math.sin(t * 0.81 + 1.3) * 0.08) * sway
	local movePitch = math.sin(swayPhase * 3.4) * 0.12 * math.clamp(speed / 10, 0, 1)
	cam.CFrame = cam.CFrame * CFrame.Angles(
		math.rad((breathPitch + movePitch + springs.pitch.x * 0.23) * k),
		math.rad(breathYaw * k),
		math.rad(springs.roll.x * 0.4 * k))
	cam.FieldOfView = math.clamp(cam.FieldOfView + springs.fov.x * k, 5, 120)
end

function controller.Start()
	buildOverlay()
	layout()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
	__TG.CharacterAdded:Connect(function()
		p, blockUntil, boltAt, flash = 0, 0, nil, 0
	end)
	RunService:BindToRenderStep("ScopeController", Enum.RenderPriority.Camera.Value + 5, update)
end

return controller
