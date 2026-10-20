-- LobbyScreensFX (LocalScript): small signs of life on the lobby info screens.
-- A slow scan line sweeps each screen, a LIVE dot blinks in the header, and the Ranked screen
-- gets a scrolling ticker. Pure client visuals; the screens' text stays owned by the map.
local RunService = game:GetService("RunService")
local TEAL = Color3.fromRGB(255, 212, 0)
local FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local NAMES = { "Screen_Brief_East", "Screen_Brief_West", "Screen_GunWall_East", "Screen_GunWall_West", "Screen_Ranked" }
local TICKER = "RANKED UNLOCKS AT LEVEL 50     ·     WIN DUELS TO CLIMB THE LADDER     ·     NEW SEASON SOON     ·     GOOD LUCK, OPERATOR     ·     "

local signs = workspace:WaitForChild("LobbyMap", 60):WaitForChild("Signs", 30)
local fx = {}
for i, n in NAMES do
	local part = signs:WaitForChild(n, 10)
	local gui = part and part:FindFirstChild("Screen")
	local root = gui and gui:FindFirstChildOfClass("Frame")
	if root then
		local line = Instance.new("Frame")
		line.Name = "ScanLine"
		line.BorderSizePixel = 0
		line.BackgroundColor3 = Color3.new(1, 1, 1)
		line.BackgroundTransparency = 0.93
		line.Size = UDim2.new(1, 0, 0.035, 0)
		line.ZIndex = 20
		line.Parent = root
		local dot = Instance.new("Frame")
		dot.Name = "LiveDot"
		dot.AnchorPoint = Vector2.new(1, 0.5)
		dot.Position = UDim2.new(0.97, 0, 0.12, 0)
		dot.Size = UDim2.fromScale(0.022, 0.03)
		dot.SizeConstraint = Enum.SizeConstraint.RelativeYY
		dot.BackgroundColor3 = TEAL
		dot.BorderSizePixel = 0
		dot.ZIndex = 21
		dot.Parent = root
		local c = Instance.new("UICorner") c.CornerRadius = UDim.new(1, 0) c.Parent = dot
		dot.Size = UDim2.fromScale(0.035, 0.035)
		local entry = { line = line, dot = dot, phase = i * 1.7 }
		if n == "Screen_Ranked" then
			local strip = Instance.new("Frame")
			strip.Name = "Ticker"
			strip.BackgroundColor3 = Color3.fromRGB(10, 12, 16)
			strip.BackgroundTransparency = 0.2
			strip.BorderSizePixel = 0
			strip.ClipsDescendants = true
			strip.Position = UDim2.fromScale(0, 0.84)
			strip.Size = UDim2.fromScale(1, 0.12)
			strip.ZIndex = 15
			strip.Parent = root
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.FontFace = FONT
			t.TextColor3 = Color3.fromRGB(176, 120, 255)
			t.TextScaled = true
			t.TextXAlignment = Enum.TextXAlignment.Left
			t.Size = UDim2.fromScale(4, 0.8)
			t.Position = UDim2.fromScale(0, 0.1)
			t.Text = TICKER .. TICKER
			t.ZIndex = 16
			t.Parent = strip
			entry.ticker = t
		end
		table.insert(fx, entry)
	end
end

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for _, e in fx do
		local y = ((now * 0.12 + e.phase) % 1.3) - 0.15
		e.line.Position = UDim2.fromScale(0, y)
		e.dot.BackgroundTransparency = (math.sin(now * 4 + e.phase) > 0) and 0 or 0.75
		if e.ticker then
			e.ticker.Position = UDim2.fromScale(-((now * 0.04) % 2), 0.1)
		end
	end
end)
