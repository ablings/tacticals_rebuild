local __TG = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("TrainingGate"))
-- StarterPlayer/StarterPlayerScripts/Client/Controllers/HealthBarController (ModuleScript)
-- Health bar, bottom left. 100 HP. When you're hit, the bar drops straight away and a pale "damage"
-- chunk drains after it; it turns red when you're low. Display only.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
RunService = __TG.RunService
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer
local controller = {}

local WIDTH, HEIGHT = 330, 18 -- the bar (design px)
local COLOR_OK = Color3.fromRGB(236, 232, 218) -- bone (pass 34)
local COLOR_LOW = Color3.fromRGB(240, 70, 60)
local LOW_AT = 0.3 -- fraction of max health
-- [UI] restyle (UI session 2026-10-16, Edward: RIVALS' aesthetics, classy, no olive / brackets on gameplay UI):
-- no plate, just the big white number with a cross and a rounded quartered bar on dark glass, like RIVALS.
-- Built in 1920x1080 design px on a UIKit canvas, then Kit.toScale (Scale only).
local Kit = require(game:GetService("ReplicatedStorage"):WaitForChild("UIKit"):WaitForChild("Kit"))
local STENCIL = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)
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
	local W, H = WIDTH + 44, 88
	frame = box(root, { Name = "Health", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromOffset(28, 1080 - 64), Size = UDim2.fromOffset(W, H),
		BackgroundTransparency = 1 })

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(20, 22)
	label.Size = UDim2.fromOffset(160, 22)
	label.FontFace = STENCIL
	label.TextSize = 19
	label.TextColor3 = FIELD
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = "HEALTH"
	label.ZIndex = 3
	label.Parent = frame

	-- medical cross beside the number
	local cross = box(frame, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(W - 112, 14), Size = UDim2.fromOffset(26, 26), BackgroundTransparency = 1, ZIndex = 3 })
	box(cross, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(26, 9), BackgroundColor3 = COLOR_OK, ZIndex = 3 })
	box(cross, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(9, 26), BackgroundColor3 = COLOR_OK, ZIndex = 3 })

	number = Instance.new("TextLabel")
	number.BackgroundTransparency = 1
	number.AnchorPoint = Vector2.new(1, 0)
	number.Position = UDim2.fromOffset(W - 18, 2)
	number.Size = UDim2.fromOffset(90, 50)
	number.FontFace = STENCIL
	number.TextSize = 46
	number.TextColor3 = COLOR_OK
	number.TextXAlignment = Enum.TextXAlignment.Right
	number.Text = "100"
	number.ZIndex = 3
	number.Parent = frame

	local back = box(frame, { Name = "Bar", Position = UDim2.fromOffset(20, 56), Size = UDim2.fromOffset(WIDTH, HEIGHT),
		BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, ClipsDescendants = true, ZIndex = 3 })
	local rc = Instance.new("UICorner") rc.CornerRadius = UDim.new(0, 5) rc.Parent = back
	trail = box(back, { Name = "Damage", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 150, 120), BackgroundTransparency = 0.25, ZIndex = 3 })
	fill = box(back, { Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = COLOR_OK, ZIndex = 4 })
	-- quarter ticks
	for i = 1, 3 do
		box(back, { Position = UDim2.new(i / 4, -2, 0, 0), Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = Color3.fromRGB(12, 14, 11), ZIndex = 5 })
	end
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
	number.Text = tostring(math.ceil(health))
	local low = shown <= LOW_AT
	-- the number flashes red for a moment when you're hit, and stays red when low
	local flash = math.clamp(1 - (os.clock() - lastHitAt) / 0.6, 0, 1)
	number.TextColor3 = low and COLOR_LOW or COLOR_OK:Lerp(COLOR_LOW, flash)
	fill.BackgroundColor3 = low and COLOR_LOW or COLOR_OK
	-- low health: the bar pulses
	fill.BackgroundTransparency = low and (0.15 + 0.15 * math.sin(os.clock() * 8)) or 0
end

-- [PAD] (Edward 2026-10-20, RIVALS) with a controller the health box sits bottom right (the hotbar takes the bottom left).
-- The NOISE meter (StealthUI, built just above this box) moves with it.
local function padLayout()
	local UIS = game:GetService("UserInputService")
	local orig = frame.Position
	local stealthOrig = {}
	local function apply(pad: boolean)
		frame.AnchorPoint = pad and Vector2.new(1, 1) or Vector2.new(0, 1)
		frame.Position = pad and UDim2.fromScale(1 - orig.X.Scale, orig.Y.Scale) or orig
		local st = localPlayer.PlayerGui:FindFirstChild("StealthUI")
		-- the meter's panel: the first GuiObject under the canvas that isn't a full-screen holder (StealthUI.Canvas.Root.Frame)
		local panels = {}
		local function dig(node)
			for _, c in node:GetChildren() do
				if c:IsA("GuiObject") then
					if c.Size.X.Scale >= 0.99 and c.Size.Y.Scale >= 0.99 then dig(c) else table.insert(panels, c) end
				end
			end
		end
		local canvas = st and st:FindFirstChild("Canvas")
		if canvas then dig(canvas) end
		for _, f in panels do
			stealthOrig[f] = stealthOrig[f] or { f.AnchorPoint, f.Position }
			local o = stealthOrig[f]
			f.AnchorPoint = pad and Vector2.new(1 - o[1].X, o[1].Y) or o[1]
			f.Position = pad and UDim2.fromScale(1 - o[2].X.Scale, o[2].Y.Scale) or o[2]
		end
	end
	local on = nil
	local function check(t)
		if t == Enum.UserInputType.MouseMovement then return end -- (2026-10-20) mouse MOVEMENT never flips back to keyboard + mouse: a resting mouse / locked cursor sends it, and hid every controller icon
		local pad = t.Name:find("Gamepad") ~= nil
		if not pad and not (t == Enum.UserInputType.Keyboard or t.Name:find("Mouse")) then return end
		if pad ~= on then on = pad; apply(pad) end
	end
	UIS.LastInputTypeChanged:Connect(check)
	check(UIS:GetLastInputType())
	localPlayer:GetAttributeChangedSignal("_ForcePad"):Connect(function() -- Studio test switch
		if RunService:IsStudio() then on = localPlayer:GetAttribute("_ForcePad") == true; apply(on) end
	end)
	localPlayer.PlayerGui.ChildAdded:Connect(function(c) if c.Name == "StealthUI" and on then task.defer(apply, true) end end)
end

function controller.Start()
	build()
	padLayout()
	RunService.RenderStepped:Connect(update)
end

return controller
