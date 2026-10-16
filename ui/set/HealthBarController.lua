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

local WIDTH, HEIGHT = 300, 14
local COLOR_OK = Color3.fromRGB(236, 232, 218) -- bone (pass 34)
local COLOR_LOW = Color3.fromRGB(240, 70, 60)
local LOW_AT = 0.3 -- fraction of max health

local gui, fill, trail, number, frame
local shown, trailValue = 1, 1
local lastHitAt = 0

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "Vitals"
	gui.ResetOnSpawn = false
	frame = Instance.new("Frame")
	frame.Name = "Health"
	frame.AnchorPoint = Vector2.new(0, 1)
	frame.Position = UDim2.new(0, 22, 1, -62) -- (the noise meter sits under it)
	frame.Size = UDim2.fromOffset(WIDTH, 48)
	frame.BackgroundTransparency = 1
	frame.Parent = gui

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromOffset(120, 18)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 12
	label.TextColor3 = Color3.fromRGB(160, 164, 148)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = "HEALTH"
	label.Parent = frame

	number = Instance.new("TextLabel")
	number.BackgroundTransparency = 1
	number.AnchorPoint = Vector2.new(1, 0)
	number.Position = UDim2.new(1, 0, 0, -8)
	number.Size = UDim2.fromOffset(120, 28)
	number.Font = Enum.Font.GothamBlack
	number.TextSize = 26
	number.TextColor3 = COLOR_OK
	number.TextXAlignment = Enum.TextXAlignment.Right
	number.Text = "100"
	number.Parent = frame

	local back = Instance.new("Frame")
	back.Name = "Bar"
	back.Position = UDim2.fromOffset(0, 24)
	back.Size = UDim2.fromOffset(WIDTH, HEIGHT)
	back.BackgroundColor3 = Color3.fromRGB(14, 16, 12)
	back.BackgroundTransparency = 0.3
	back.BorderSizePixel = 0
	back.ClipsDescendants = true
	local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 1) c.Parent = back
	back.Parent = frame

	trail = Instance.new("Frame")
	trail.Name = "Damage"
	trail.Size = UDim2.fromScale(1, 1)
	trail.BackgroundColor3 = Color3.fromRGB(255, 150, 120)
	trail.BackgroundTransparency = 0.25
	trail.BorderSizePixel = 0
	local tc = Instance.new("UICorner") tc.CornerRadius = UDim.new(0, 3) tc.Parent = trail
	trail.Parent = back

	fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = COLOR_OK
	fill.BorderSizePixel = 0
	local fc = Instance.new("UICorner") fc.CornerRadius = UDim.new(0, 3) fc.Parent = fill
	fill.Parent = back

	-- quarter ticks
	for i = 1, 3 do
		local tick = Instance.new("Frame")
		tick.Position = UDim2.new(i / 4, -1, 0, 0)
		tick.Size = UDim2.new(0, 2, 1, 0)
		tick.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
		tick.BackgroundTransparency = 0.4
		tick.BorderSizePixel = 0
		tick.ZIndex = 3
		tick.Parent = back
	end

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

function controller.Start()
	build()
	RunService.RenderStepped:Connect(update)
end

return controller
