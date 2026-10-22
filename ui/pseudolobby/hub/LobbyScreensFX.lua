-- LobbyScreensFX (LocalScript): small signs of life on the lobby info screens.
-- A slow scan line sweeps each screen, a LIVE dot breathes in the header, and the Ranked screen
-- gets a scrolling ticker. Pure client visuals; the screens' text stays owned by the map.
-- (2026-10-21, RIVALS pass) field-green dot with a soft sine breathe (was a hard yellow blink), Rubik ticker in cream on a
-- near-black strip (was Gotham violet), ticker gap bullets.
local RunService = game:GetService("RunService")
local GREEN = Color3.fromRGB(141, 191, 90)
local CREAM = Color3.fromRGB(236, 230, 210)
local FONT = Font.new("rbxassetid://12187365977", Enum.FontWeight.Bold)
local NAMES = { "Screen_Brief_East", "Screen_Brief_West", "Screen_GunWall_East", "Screen_GunWall_West", "Screen_Ranked" }
local TICKER = "RANKED UNLOCKS AT LEVEL 50     •     WIN DUELS TO CLIMB THE LADDER     •     NEW SEASON SOON     •     GOOD LUCK, OPERATOR     •     "

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
		line.BackgroundTransparency = 0.94
		line.Size = UDim2.fromScale(1, 0.035)
		line.ZIndex = 20
		line.Parent = root
		local dot = Instance.new("Frame")
		dot.Name = "LiveDot"
		dot.AnchorPoint = Vector2.new(1, 0.5)
		dot.Position = UDim2.fromScale(0.97, 0.12)
		dot.Size = UDim2.fromScale(0.035, 0.035)
		dot.SizeConstraint = Enum.SizeConstraint.RelativeYY
		dot.BackgroundColor3 = GREEN
		dot.BorderSizePixel = 0
		dot.ZIndex = 21
		dot.Parent = root
		local c = Instance.new("UICorner") c.CornerRadius = UDim.new(1, 0) c.Parent = dot
		local entry = { line = line, dot = dot, phase = i * 1.7 }
		if n == "Screen_Ranked" then
			local strip = Instance.new("Frame")
			strip.Name = "Ticker"
			strip.BackgroundColor3 = Color3.fromRGB(10, 12, 10)
			strip.BackgroundTransparency = 0.15
			strip.BorderSizePixel = 0
			strip.ClipsDescendants = true
			strip.Position = UDim2.fromScale(0, 0.84)
			strip.Size = UDim2.fromScale(1, 0.12)
			strip.ZIndex = 15
			strip.Parent = root
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.FontFace = FONT
			t.TextColor3 = CREAM
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
		e.dot.BackgroundTransparency = 0.1 + 0.45 * (0.5 + 0.5 * math.sin(now * 2.6 + e.phase))
		if e.ticker then
			e.ticker.Position = UDim2.fromScale(-((now * 0.04) % 2), 0.1)
		end
	end
end)
