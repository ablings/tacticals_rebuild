-- Client/Controllers/BillboardController
-- Animates the Times-Square style billboards outside the lounge window.
-- Parts tagged "CityBillboard" carry attributes:
--   BillboardKind  = Hero | Brand | Brand2 | Ticker | Promo | Promo2 | Promo3 | Crown | Side
--   BillboardFace  = NormalId name of the face that looks toward the lobby window
-- All ad content is fictional / game-themed. Swap SLIDES/BRANDS for real promos later.

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local BillboardController = {}

local PPS = 18 -- SurfaceGui pixels per stud
-- (2026-10-21, AI-tells sweep) Oswald Bold for the big ad words, Rubik Bold for sub lines / the ticker (was GothamBlack / GothamBold)
local HEAD = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
local BODY = Font.new("rbxassetid://12187365977", Enum.FontWeight.Bold)

local SLIDES = {
	{ title = "TACTICALS", sub = "COVER  ·  PEEK  ·  WIN", a = Color3.fromRGB(255, 150, 40), b = Color3.fromRGB(150, 30, 20) },
	{ title = "1V1 NIGHT", sub = "QUEUE IN THE DEPLOYMENT WING", a = Color3.fromRGB(60, 210, 255), b = Color3.fromRGB(20, 40, 140) },
	{ title = "SMOKE OUT", sub = "NEW GADGET SKINS AT SUPPLY DEPOT", a = Color3.fromRGB(170, 170, 185), b = Color3.fromRGB(40, 40, 60) },
	{ title = "3V3 SQUADS", sub = "BRING TWO FRIENDS", a = Color3.fromRGB(255, 70, 90), b = Color3.fromRGB(80, 10, 50) },
	{ title = "HOLD THE ANGLE", sub = "WEEKLY CHALLENGES · BRIEFING ROOM", a = Color3.fromRGB(120, 255, 140), b = Color3.fromRGB(10, 70, 40) },
}
local BRANDS = {
	{ "KORVO COLA", Color3.fromRGB(230, 40, 40) },
	{ "NEONLINE", Color3.fromRGB(80, 230, 255) },
	{ "BRAWLR", Color3.fromRGB(255, 200, 40) },
	{ "HEXA AIR", Color3.fromRGB(200, 120, 255) },
	{ "GRIT & STEEL", Color3.fromRGB(255, 140, 60) },
}
local PROMOS = {
	{ "50% OFF", "CRATES TONIGHT", Color3.fromRGB(255, 60, 120) },
	{ "NEW", "PROVING GROUND", Color3.fromRGB(60, 200, 255) },
	{ "LIVE", "DUEL CAM", Color3.fromRGB(255, 70, 50) },
	{ "OPEN", "24 / 7", Color3.fromRGB(255, 210, 60) },
}
local TICKER = "  ★ LIVE DUELS EVERY NIGHT  ★  2V2 QUEUE OPEN  ★  TOP DUELIST: BUILDERMAN  ★  NEW: SMOKE GRENADE SKINS  ★  WARM-UP RANGE NOW OPEN  ★  KORVO COLA — TASTE THE FLANK  ★"

local function makeGui(part: BasePart)
	local old = part:FindFirstChild("BillboardGui_Live")
	if old then old:Destroy() end
	local g = Instance.new("SurfaceGui")
	g.Name = "BillboardGui_Live"
	g.Face = Enum.NormalId[part:GetAttribute("BillboardFace") or "Front"]
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = PPS
	g.LightInfluence = 0
	g.Brightness = 2.2
	g.ClipsDescendants = true
	g.Parent = part
	local bg = Instance.new("Frame")
	bg.Name = "BG"
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.new(0, 0, 0)
	bg.BorderSizePixel = 0
	bg.ClipsDescendants = true
	bg.Parent = g
	return g, bg
end

local function label(parent, text, size, pos, color, font)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = size
	t.Position = pos
	t.Text = text
	t.TextScaled = true
	t.FontFace = font or HEAD
	t.TextColor3 = color or Color3.new(1, 1, 1)
	t.Parent = parent
	return t
end

local function gradient(frame, a, b, rot)
	local g = frame:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient")
	g.Color = ColorSequence.new(a, b)
	g.Rotation = rot or 90
	g.Parent = frame
	return g
end

-- Big rotating ad with a wipe transition
local function runHero(part)
	local _, bg = makeGui(part)
	local idx = 0
	local function build(slide, holder)
		local f = Instance.new("Frame")
		f.Size = UDim2.fromScale(1, 1)
		f.BorderSizePixel = 0
		f.BackgroundColor3 = Color3.new(1, 1, 1)
		gradient(f, slide.a, slide.b, 120)
		label(f, slide.title, UDim2.fromScale(0.9, 0.42), UDim2.fromScale(0.05, 0.2))
		label(f, slide.sub, UDim2.fromScale(0.84, 0.13), UDim2.fromScale(0.08, 0.66), Color3.fromRGB(255, 245, 225), BODY)
		local bar = Instance.new("Frame")
		bar.Size = UDim2.new(0.5, 0, 0, 6)
		bar.Position = UDim2.fromScale(0.25, 0.85)
		bar.BackgroundColor3 = Color3.new(1, 1, 1)
		bar.BorderSizePixel = 0
		bar.Parent = f
		f.Parent = holder
		return f
	end
	local current
	while part.Parent do
		idx = idx % #SLIDES + 1
		local nxt = build(SLIDES[idx], bg)
		nxt.Position = UDim2.fromScale(1, 0)
		TweenService:Create(nxt, TweenInfo.new(0.6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0, 0) }):Play()
		if current then
			local c = current
			TweenService:Create(c, TweenInfo.new(0.6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Position = UDim2.fromScale(-1, 0) }):Play()
			task.delay(0.7, function() c:Destroy() end)
		end
		current = nxt
		task.wait(6)
	end
end

-- Logo that cross-fades between fictional brands and pulses
local function runBrand(part, offset)
	local _, bg = makeGui(part)
	local i = offset
	local t = label(bg, "", UDim2.fromScale(0.9, 0.7), UDim2.fromScale(0.05, 0.15))
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = t
	while part.Parent do
		i = i % #BRANDS + 1
		local b = BRANDS[i]
		t.Text = b[1]
		t.TextColor3 = b[2]
		stroke.Color = b[2]:Lerp(Color3.new(1, 1, 1), 0.5)
		bg.BackgroundColor3 = b[2]:Lerp(Color3.new(0, 0, 0), 0.85)
		t.TextTransparency = 1
		TweenService:Create(t, TweenInfo.new(0.5), { TextTransparency = 0 }):Play()
		task.wait(4.5)
		TweenService:Create(t, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		task.wait(0.45)
	end
end

-- Scrolling news ticker
local function runTicker(part)
	local _, bg = makeGui(part)
	bg.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
	local h = part.Size.Y * PPS
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = bg
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.FontFace = BODY
	t.TextSize = math.floor(h * 0.7)
	t.TextColor3 = Color3.fromRGB(255, 196, 70)
	t.Text = TICKER
	t.AutomaticSize = Enum.AutomaticSize.X
	t.Size = UDim2.new(0, 0, 1, 0)
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Parent = holder
	local t2 = t:Clone()
	t2.Parent = holder
	local x = 0
	local speed = 90 -- pixels per second
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		if not part.Parent then conn:Disconnect() return end
		local w = t.AbsoluteSize.X
		if w <= 0 then w = #TICKER * h * 0.45 end
		x -= speed * dt
		if x <= -w then x += w end
		t.Position = UDim2.new(0, x, 0, 0)
		t2.Position = UDim2.new(0, x + w, 0, 0)
	end)
end

-- Small flashing promo panels
local function runPromo(part, offset)
	local _, bg = makeGui(part)
	local big = label(bg, "", UDim2.fromScale(0.9, 0.5), UDim2.fromScale(0.05, 0.1))
	local small = label(bg, "", UDim2.fromScale(0.86, 0.24), UDim2.fromScale(0.07, 0.64), nil, BODY)
	local i = offset
	while part.Parent do
		i = i % #PROMOS + 1
		local p = PROMOS[i]
		big.Text, small.Text = p[1], p[2]
		gradient(bg, p[3], p[3]:Lerp(Color3.new(0, 0, 0), 0.7), 90)
		bg.BackgroundColor3 = Color3.new(1, 1, 1)
		for _ = 1, 3 do -- blink in
			bg.BackgroundTransparency = 0.6
			task.wait(0.08)
			bg.BackgroundTransparency = 0
			task.wait(0.08)
		end
		task.wait(3.5 + offset * 0.3)
	end
end

-- Crown sign with chasing marquee bulbs
local function runCrown(part)
	local _, bg = makeGui(part)
	bg.BackgroundColor3 = Color3.fromRGB(20, 6, 6)
	local t = label(bg, "TACTICALS", UDim2.fromScale(0.86, 0.6), UDim2.fromScale(0.07, 0.2), Color3.fromRGB(255, 70, 50))
	local bulbs = {}
	local n = 28
	for i = 1, n do
		local d = Instance.new("Frame")
		d.Size = UDim2.fromOffset(10, 10)
		d.AnchorPoint = Vector2.new(0.5, 0.5)
		local top = i <= n / 2
		local k = top and (i - 1) or (i - 1 - n / 2)
		d.Position = UDim2.fromScale(0.03 + 0.94 * k / (n / 2 - 1), top and 0.08 or 0.92)
		d.BorderSizePixel = 0
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = d
		d.Parent = bg
		bulbs[i] = d
	end
	local step = 0
	while part.Parent do
		step += 1
		for i, d in bulbs do
			d.BackgroundColor3 = ((i + step) % 3 == 0) and Color3.fromRGB(255, 230, 150) or Color3.fromRGB(70, 40, 20)
		end
		t.TextColor3 = (step % 20 < 10) and Color3.fromRGB(255, 70, 50) or Color3.fromRGB(255, 160, 60)
		task.wait(0.12)
	end
end

-- Tall vertical sign: letters light up one by one
local function runSide(part)
	local _, bg = makeGui(part)
	bg.BackgroundColor3 = Color3.fromRGB(8, 8, 16)
	local word = "DUEL"
	local letters = {}
	for i = 1, #word do
		letters[i] = label(bg, word:sub(i, i), UDim2.fromScale(0.8, 0.22), UDim2.fromScale(0.1, 0.03 + (i - 1) * 0.24), Color3.fromRGB(40, 40, 60))
	end
	local hue = 0
	while part.Parent do
		for i = 1, #letters do
			hue = (hue + 0.07) % 1
			letters[i].TextColor3 = Color3.fromHSV(hue, 0.8, 1)
			task.wait(0.25)
		end
		task.wait(0.6)
		for i = 1, #letters do
			letters[i].TextColor3 = Color3.fromRGB(40, 40, 60)
		end
		task.wait(0.2)
	end
end

local RUNNERS = {
	Hero = runHero,
	Brand = function(p) runBrand(p, 0) end,
	Brand2 = function(p) runBrand(p, 2) end,
	Ticker = runTicker,
	Promo = function(p) runPromo(p, 0) end,
	Promo2 = function(p) runPromo(p, 1) end,
	Promo3 = function(p) runPromo(p, 2) end,
	Crown = runCrown,
	Side = runSide,
}

local started = setmetatable({}, { __mode = "k" })

local function attach(part)
	if started[part] or not part:IsA("BasePart") then return end
	local kind = part:GetAttribute("BillboardKind")
	local fn = RUNNERS[kind]
	if not fn then return end
	started[part] = true
	task.spawn(fn, part)
end

function BillboardController.Start()
	for _, p in CollectionService:GetTagged("CityBillboard") do
		attach(p)
	end
	CollectionService:GetInstanceAddedSignal("CityBillboard"):Connect(attach)
end

return BillboardController
