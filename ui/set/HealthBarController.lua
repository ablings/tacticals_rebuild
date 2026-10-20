local __TG = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("TrainingGate"))
-- StarterPlayer/StarterPlayerScripts/Client/Controllers/HealthBarController (ModuleScript)
-- Health bar, bottom centre (Knife Duels' look). 100 HP. When you're hit, the bar drops straight away and a pale "damage"
-- chunk drains after it; it turns red when you're low. Display only.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
RunService = __TG.RunService
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer
local controller = {}

local WIDTH, HEIGHT = 470, 12 -- the bar (design px)
local COLOR_OK = Color3.fromRGB(236, 232, 218) -- bone (pass 34)
local COLOR_LOW = Color3.fromRGB(240, 70, 60)
local LOW_AT = 0.3 -- fraction of max health
-- [UI] restyle (UI session 2026-10-16, Edward: RIVALS' aesthetics, classy, no olive / brackets on gameplay UI):
-- no plate, just the big white number with a cross and a rounded quartered bar on dark glass, like RIVALS.
-- Built in 1920x1080 design px on a UIKit canvas, then Kit.toScale (Scale only).
local Kit = require(game:GetService("ReplicatedStorage"):WaitForChild("UIKit"):WaitForChild("Kit"))
local STENCIL = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy) -- (2026-10-20, serious pass)
local FIELD = Color3.fromRGB(200, 200, 206)

local gui, fill, trail, number, frame
local shown, trailValue = 1, 1
local lastHitAt = 0

local function box(parent, props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for k, v in props do f[k] = v end
	f.Parent = parent
	return f
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "Vitals"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	local canvas = Kit.canvas(gui)
	local root = box(canvas, { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	-- (2026-10-20, Edward's screen: Knife Duels' health) bottom CENTRE: "100 HP" in white over one thin, long, rounded bar with a
	-- dark outline; no plate, no ticks, no icon. Same place with a controller (the hotbar takes a corner either way).
	local W, H = WIDTH, 58
	frame = box(root, { Name = "Health", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(960, 1080 - 56), Size = UDim2.fromOffset(W, H),
		BackgroundTransparency = 1 })
	number = Instance.new("TextLabel")
	number.BackgroundTransparency = 1
	number.Size = UDim2.fromOffset(W, 36)
	number.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
	number.TextSize = 32
	number.TextColor3 = Color3.new(1, 1, 1)
	number.Text = "100 HP"
	number.ZIndex = 6
	number.Parent = frame
	local ns = Instance.new("UIStroke") ns.Thickness = 1.5 ns.Transparency = 0.4 ns.Parent = number
	local back = box(frame, { Name = "Bar", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromOffset(0, H - 2), Size = UDim2.fromOffset(W, HEIGHT),
		BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, ZIndex = 3 })
	local rc = Instance.new("UICorner") rc.CornerRadius = UDim.new(0.5, 0) rc.Parent = back
	local bs = Instance.new("UIStroke") bs.Color = Color3.fromRGB(20, 20, 22) bs.Thickness = 2 bs.Transparency = 0.2 bs.Parent = back
	trail = box(back, { Name = "Damage", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 150, 120), BackgroundTransparency = 0.25, ZIndex = 3 })
	local tc = Instance.new("UICorner") tc.CornerRadius = UDim.new(0.5, 0) tc.Parent = trail
	fill = box(back, { Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = COLOR_OK, ZIndex = 4 })
	local fc = Instance.new("UICorner") fc.CornerRadius = UDim.new(0.5, 0) fc.Parent = fill
	Kit.toScale(root)
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
end

local function current(): (number, number)
	local character = localPlayer.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if not hum then return 0, 100 end
	return math.max(hum.Health, 0), math.max(hum.MaxHealth, 1)
end

local function update(dt)
	local health, max = current()
	local target = health / max
	if target < shown - 0.001 then
		-- took damage: snap down, the pale chunk waits a moment then drains
		if localPlayer.Character and shown > 0 and health > 0 then lastHitAt = os.clock() end
	end
	shown = target
	if os.clock() - lastHitAt > 0.45 then
		trailValue += (shown - trailValue) * math.clamp(dt * 4, 0, 1)
	end
	if trailValue < shown then trailValue = shown end -- healing: no chunk
	fill.Size = UDim2.fromScale(shown, 1)
	trail.Size = UDim2.fromScale(trailValue, 1)
	number.Text = tostring(math.ceil(health)) .. " HP"
	local low = shown <= LOW_AT
	-- the number flashes red for a moment when you're hit, and stays red when low
	local flash = math.clamp(1 - (os.clock() - lastHitAt) / 0.6, 0, 1)
	number.TextColor3 = Color3.new(1, 1, 1):Lerp(COLOR_LOW, low and 0 or flash)
	fill.BackgroundColor3 = low and COLOR_LOW or COLOR_OK
	-- low health: the bar pulses
	fill.BackgroundTransparency = low and (0.15 + 0.15 * math.sin(os.clock() * 8)) or 0
end

-- (2026-10-20, Edward: "remove the noise indicator we don't need people to know how loud they are") the NOISE meter
-- (StealthUI, built by the stealth gameplay script) is hidden here: its contents stay invisible whatever turns the ScreenGui
-- on or off (the match HUD toggles it with the rest). Noise itself still works; only the meter is gone.
local function hideNoiseMeter()
	local function hide(gui)
		for _, c in gui:GetChildren() do
			if c:IsA("GuiObject") then
				c.Visible = false
				c:GetPropertyChangedSignal("Visible"):Connect(function() if c.Visible then c.Visible = false end end)
			end
		end
		gui.ChildAdded:Connect(function(c) if c:IsA("GuiObject") then task.defer(function() c.Visible = false end) end end)
	end
	local pg = localPlayer:WaitForChild("PlayerGui")
	local st = pg:FindFirstChild("StealthUI")
	if st then hide(st) end
	pg.ChildAdded:Connect(function(c) if c.Name == "StealthUI" then hide(c) end end)
end

function controller.Start()
	build()
	hideNoiseMeter()
	RunService.RenderStepped:Connect(update)
end

return controller
