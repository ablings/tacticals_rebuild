-- LeaderboardScreen: the hub leaderboard board on workspace.LobbyMap.Signs.Screen_Leaderboard
-- (LocalScript; the SurfaceGui is parented into PlayerGui and adorned to the part, Front face, 940x580 canvas).
-- (2026-10-21) Rewritten after RIVALS' lobby board (notes/ui_rivals/06_leaderboards.md changes 1-5):
--   * four category tabs (Wins / Elims / Streak / Level) with flat icons and a red LIVE pill; the board cycles
--     itself every 8 s with a slide + fade, a clicked tab pauses the cycle for 20 s;
--   * #1 is a hero row (big headshot, name, big number, the only comic-yellow on the board: the "1" badge);
--     #2-#10 sit in two columns; your own row is field green; an empty list says "No one yet - be the first!";
--   * numbers count up on refresh (a tweened NumberValue per slot), rows pop in staggered on a category change.
-- Data (server LobbyLeaderboard, 2026-10-21): StringValues in ReplicatedStorage, JSON arrays best-first, top 10,
-- refreshed every 60 s, entries { u = userId, n = name, w = value }; LobbyTopLevel adds x = XP (ranked by XP).
-- Any value may be missing: its tab stays hidden until the value shows up.
-- (2026-10-21) Look: Oswald Bold headings, Rubik body, cream / tan / field green on near-black plates; chunky
-- shapes with a darker offset "lip" frame instead of strokes. No Gotham, no hairline UIStroke, no left accent bar.
-- Everything is laid out in design px and written as Scale (Edward's rule: Position/Size in Scale, never Offset).
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local map = workspace:WaitForChild("LobbyMap", 60)
local signs = map and map:WaitForChild("Signs", 30)
local part = signs and signs:WaitForChild("Screen_Leaderboard", 30)
if not part then return end
local playerGui = player:WaitForChild("PlayerGui", 30)
if not playerGui then return end

local W, H = 940, 580
local CYCLE, PAUSE = 8, 20 -- seconds between categories; pause after a tab click

local COL = {
	fieldHi = Color3.fromRGB(141, 191, 90),   -- #8DBF5A
	fieldLo = Color3.fromRGB(76, 122, 46),    -- #4C7A2E
	fieldLip = Color3.fromRGB(40, 66, 24),
	cream = Color3.fromRGB(236, 230, 210),    -- #ECE6D2
	tan = Color3.fromRGB(226, 210, 172),      -- #E2D2AC
	tanLip = Color3.fromRGB(168, 150, 108),
	plate = Color3.fromRGB(24, 26, 21),
	plateLip = Color3.fromRGB(5, 5, 4),
	bgTop = Color3.fromRGB(20, 22, 18),
	bgBot = Color3.fromRGB(8, 9, 7),
	ink = Color3.fromRGB(20, 22, 17),
	muted = Color3.fromRGB(150, 146, 130),
	yellow = Color3.fromRGB(255, 212, 0),     -- #FFD400, rank 1 only
	yellowLip = Color3.fromRGB(176, 140, 0),
	shotBg = Color3.fromRGB(54, 56, 48),
}
local FONT_H = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
local FONT_B = Font.new("rbxassetid://12187365977", Enum.FontWeight.Regular)
local FONT_BB = Font.new("rbxassetid://12187365977", Enum.FontWeight.Bold)

local CATS = {
	{ key = "wins", value = "LobbyTopWins", tab = "WINS", title = "MOST WINS", unit = "WINS", icon = "rbxassetid://120316362189428" },
	{ key = "elims", value = "LobbyTopKills", tab = "ELIMS", title = "MOST ELIMS", unit = "ELIMS", icon = "rbxassetid://83789042758416" },
	{ key = "streak", value = "LobbyTopStreak", tab = "STREAK", title = "WIN STREAK", unit = "IN A ROW", icon = "rbxassetid://139831914155940" },
	{ key = "level", value = "LobbyTopLevel", tab = "LEVEL", title = "HIGHEST LEVEL", unit = "XP", icon = "rbxassetid://81711657935672", level = true },
}
local LIVE_ICON = "rbxassetid://85639052729616" -- 256x96 red LIVE pill

local function new(c, p, parent)
	local o = Instance.new(c)
	for k, v in p do o[k] = v end
	o.Parent = parent
	return o
end
-- a GuiObject placed in design px (x, y, w, h) inside a parent of design size pw x ph, written as Scale
local function at(c, parent, pw, ph, x, y, w, h, p)
	p = p or {}
	p.Position = UDim2.fromScale(x / pw, y / ph)
	p.Size = UDim2.fromScale(w / pw, h / ph)
	if p.BorderSizePixel == nil and c ~= "UIScale" then p.BorderSizePixel = 0 end
	return new(c, p, parent)
end
local function text(parent, pw, ph, x, y, w, h, str, font, color, align)
	return at("TextLabel", parent, pw, ph, x, y, w, h, { BackgroundTransparency = 1, Text = str, FontFace = font, TextScaled = true,
		TextColor3 = color, TextXAlignment = align or Enum.TextXAlignment.Left, ZIndex = 3 })
end
local function tween(o, t, props, style, dir, delay)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out, 0, false, delay or 0), props)
	tw:Play()
	return tw
end
-- (2026-10-21) chunky plate: a face plus a darker lip frame offset `lip` px below it (replaces UIStroke borders).
-- The holder is centred (AnchorPoint 0.5) so its UIScale pops from the middle. Children of .face use design size w x h.
local function chunky(parent, pw, ph, x, y, w, h, lip, class)
	local total = h + lip
	local holder = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale((x + w / 2) / pw, (y + total / 2) / ph),
		Size = UDim2.fromScale(w / pw, total / ph), BackgroundTransparency = 1, BorderSizePixel = 0 }, parent)
	local lipF = new("Frame", { Position = UDim2.fromScale(0, lip / total), Size = UDim2.fromScale(1, h / total), BorderSizePixel = 0, ZIndex = 1 }, holder)
	local face = new(class or "Frame", { Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, h / total), BorderSizePixel = 0, ZIndex = 2 }, holder)
	if class == "TextButton" then face.Text = "" face.AutoButtonColor = false end
	new("UICorner", { CornerRadius = UDim.new(0, 6) }, lipF) -- fixed 940x580 canvas, so a px radius stays the same size
	new("UICorner", { CornerRadius = UDim.new(0, 6) }, face)
	local grad = new("UIGradient", { Rotation = 90, Color = ColorSequence.new(COL.fieldHi, COL.fieldLo), Enabled = false }, face)
	local scale = new("UIScale", { Scale = 1 }, holder)
	return { holder = holder, face = face, lip = lipF, grad = grad, scale = scale, w = w, h = h }
end
local function setLook(pl, faceColor, lipColor, green, faceT)
	pl.grad.Enabled = green
	pl.face.BackgroundColor3 = green and Color3.new(1, 1, 1) or faceColor
	pl.face.BackgroundTransparency = faceT or 0
	pl.lip.BackgroundColor3 = green and COL.fieldLip or lipColor
	pl.lip.BackgroundTransparency = faceT or 0
end
local function fmt(n)
	local s = tostring(math.floor((tonumber(n) or 0) + 0.5))
	local neg = s:sub(1, 1) == "-"
	if neg then s = s:sub(2) end
	s = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if s:sub(1, 1) == "," then s = s:sub(2) end
	return (neg and "-" or "") .. s
end

-- ---------------------------------------------------------------- board
local old = playerGui:FindFirstChild("LeaderboardGui")
if old then old:Destroy() end
local gui = new("SurfaceGui", { Name = "LeaderboardGui", Adornee = part, Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
	CanvasSize = Vector2.new(W, H), LightInfluence = 0, Brightness = 1.25, MaxDistance = 120, ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, playerGui)
local root = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, gui)
new("UIGradient", { Rotation = 90, Color = ColorSequence.new(COL.bgTop, COL.bgBot) }, root)

-- tabs (hidden until their StringValue exists; the list layout closes the gaps)
local tabBar = at("Frame", root, W, H, 20, 14, 790, 58, { BackgroundTransparency = 1 })
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(10 / 790, 0), SortOrder = Enum.SortOrder.LayoutOrder }, tabBar)
local tabs = {}
for i, cat in CATS do
	local holder = new("Frame", { Size = UDim2.fromScale(190 / 790, 1), BackgroundTransparency = 1, LayoutOrder = i, Visible = false }, tabBar)
	local pl = chunky(holder, 190, 58, 0, 0, 190, 52, 6, "TextButton")
	pl.holder.Position = UDim2.fromScale(0.5, 0.5) -- fill the list slot
	pl.holder.Size = UDim2.fromScale(1, 1)
	local icon = at("ImageLabel", pl.face, 190, 52, 14, 8, 36, 36, { BackgroundTransparency = 1, Image = cat.icon, ScaleType = Enum.ScaleType.Fit, ZIndex = 3 })
	local label = text(pl.face, 190, 52, 60, 8, 118, 36, cat.tab, FONT_H, COL.cream)
	tabs[cat] = { slot = holder, pl = pl, icon = icon, label = label }
end

-- LIVE pill (pulses gently)
local live = at("ImageLabel", root, W, H, 822, 20, 100, 38, { BackgroundTransparency = 1, Image = LIVE_ICON, ScaleType = Enum.ScaleType.Fit, ZIndex = 3 })
local liveScale = new("UIScale", { Scale = 1 }, live)
TweenService:Create(liveScale, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.07 }):Play()

-- content: title, hero, rows. A CanvasGroup so a category switch can slide + fade it as one piece.
local CW, CH = 940, 504
local CONTENT_POS = UDim2.fromScale(0, 76 / H)
local content = new("CanvasGroup", { Position = CONTENT_POS, Size = UDim2.fromScale(1, CH / H), BackgroundTransparency = 1, BorderSizePixel = 0 }, root)
local titleIcon = at("ImageLabel", content, CW, CH, 20, 8, 34, 34, { BackgroundTransparency = 1, Image = "", ImageColor3 = COL.tan, ScaleType = Enum.ScaleType.Fit, ZIndex = 3 })
local title = text(content, CW, CH, 64, 2, 520, 46, "LEADERBOARD", FONT_H, COL.cream)
text(content, CW, CH, 600, 14, 320, 26, "TOP 10", FONT_BB, COL.muted, Enum.TextXAlignment.Right)

local slots = {}
local function numberSlot(slot, label, prefix)
	slot.prefix = prefix or ""
	slot.nv = new("NumberValue", { Value = 0 }, label)
	slot.nv.Changed:Connect(function(v) label.Text = slot.prefix .. fmt(v) end)
	slot.valueLabel = label
end

-- hero row (#1): 900x120 face
do
	local pl = chunky(content, CW, CH, 20, 54, 900, 120, 7)
	setLook(pl, COL.cream, COL.tanLip, false)
	local badge = chunky(pl.face, 900, 120, 16, 14, 84, 84, 7)
	setLook(badge, COL.yellow, COL.yellowLip, false)
	for _, f in { badge.face, badge.lip } do f.ZIndex = 3 end
	local one = text(badge.face, 84, 84, 0, 4, 84, 76, "1", FONT_H, COL.ink, Enum.TextXAlignment.Center)
	one.ZIndex = 4
	local shot = at("ImageLabel", pl.face, 900, 120, 118, 10, 100, 100, { BackgroundColor3 = COL.tan, Image = "", ZIndex = 3 })
	new("UICorner", { CornerRadius = UDim.new(0, 8) }, shot)
	local name = text(pl.face, 900, 120, 236, 16, 420, 54, "-", FONT_H, COL.ink)
	local sub = text(pl.face, 900, 120, 238, 74, 400, 28, "#1 ON THE BOARD", FONT_BB, COL.ink)
	sub.TextTransparency = 0.35
	local value = text(pl.face, 900, 120, 640, 8, 240, 72, "0", FONT_H, COL.ink, Enum.TextXAlignment.Right)
	local unit = text(pl.face, 900, 120, 600, 80, 280, 28, "", FONT_BB, COL.ink, Enum.TextXAlignment.Right)
	unit.TextTransparency = 0.25
	local slot = { pl = pl, shot = shot, name = name, unit = unit, hero = true }
	numberSlot(slot, value)
	slots[1] = slot
end

-- rows #2-#10: two columns of five (the last cell holds the footer line). 440x54 faces.
for i = 2, 10 do
	local col = (i - 2) // 5
	local r = (i - 2) % 5
	local pl = chunky(content, CW, CH, 20 + col * 460, 190 + r * 62, 440, 54, 5)
	local rank = text(pl.face, 440, 54, 6, 8, 46, 38, tostring(i), FONT_H, COL.tan, Enum.TextXAlignment.Center)
	local shot = at("ImageLabel", pl.face, 440, 54, 58, 5, 44, 44, { BackgroundColor3 = COL.shotBg, Image = "", ZIndex = 3 })
	new("UICorner", { CornerRadius = UDim.new(0, 6) }, shot)
	local name = text(pl.face, 440, 54, 114, 11, 206, 32, "-", FONT_BB, COL.cream)
	local value = text(pl.face, 440, 54, 324, 8, 104, 38, "0", FONT_H, COL.cream, Enum.TextXAlignment.Right)
	local slot = { pl = pl, shot = shot, name = name, rank = rank }
	numberSlot(slot, value)
	slots[i] = slot
end
local footer = text(content, CW, CH, 480, 190 + 4 * 62 + 12, 440, 30, "UPDATES EVERY MINUTE", FONT_B, COL.muted, Enum.TextXAlignment.Center)
local empty = text(content, CW, CH, 120, 200, 700, 64, "No one yet - be the first!", FONT_H, COL.cream, Enum.TextXAlignment.Center)

-- ---------------------------------------------------------------- data + render
local data = {}   -- [cat.key] = decoded list
local avail = {}  -- [cat] = StringValue
local cur = nil
local shots = {}
local token = 0

local function setShot(slot, u)
	if slot.user == u then return end
	slot.user = u
	slot.shot.Image = (u and shots[u]) or ""
	if not u or shots[u] then return end
	task.spawn(function()
		local ok, url = pcall(Players.GetUserThumbnailAsync, Players, math.max(1, u), Enum.ThumbnailType.HeadShot,
			slot.hero and Enum.ThumbnailSize.Size150x150 or Enum.ThumbnailSize.Size60x60)
		if ok and url then
			shots[u] = url
			if slot.user == u then slot.shot.Image = url end
		end
	end)
end

local function styleSlot(slot, own)
	local pl = slot.pl
	if slot.hero then
		setLook(pl, COL.cream, COL.tanLip, own)
		return
	end
	setLook(pl, COL.plate, COL.plateLip, own, own and 0 or 0.08)
	local fg = own and COL.ink or COL.cream
	slot.name.TextColor3 = fg
	slot.valueLabel.TextColor3 = fg
	slot.rank.TextColor3 = own and COL.ink or COL.tan
end

-- full = category changed: numbers count from 0 and every row pops in; otherwise numbers count from where they stand
-- and only rows whose player changed pop.
local function render(full)
	local list = (cur and data[cur.key]) or {}
	empty.Visible = #list == 0
	footer.Visible = #list > 0
	local n = 0
	for i, slot in slots do
		local e = list[i]
		slot.pl.holder.Visible = e ~= nil
		if e then
			n += 1
			local u = tonumber(e.u)
			local changed = slot.user ~= u
			slot.name.Text = string.upper(tostring(e.n or "OPERATOR"))
			styleSlot(slot, u ~= nil and u == player.UserId)
			setShot(slot, u)
			slot.prefix = cur.level and "LV " or ""
			if slot.hero then
				slot.unit.Text = cur.level and (fmt(e.x) .. " XP") or cur.unit
			end
			local target = tonumber(e.w) or 0
			if full then slot.nv.Value = 0 end
			if full or slot.nv.Value ~= target then
				tween(slot.nv, full and 0.9 or 0.7, { Value = target }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, full and (n - 1) * 0.04 or 0)
			else
				slot.valueLabel.Text = slot.prefix .. fmt(target)
			end
			if full or changed then
				slot.pl.scale.Scale = full and 0 or 0.9
				tween(slot.pl.scale, 0.32, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, full and (n - 1) * 0.045 or 0)
			end
		else
			slot.user = nil
			slot.shot.Image = ""
		end
	end
end

local function parse(cat)
	local v = avail[cat]
	if not v then return end
	local ok, list = pcall(HttpService.JSONDecode, HttpService, v.Value)
	data[cat.key] = (ok and type(list) == "table") and list or {}
end

local function paintTabs(instant)
	for cat, t in tabs do
		local on = cat == cur
		local face = on and COL.cream or COL.plate
		local lip = on and COL.tanLip or COL.plateLip
		local fg = on and COL.ink or COL.cream
		if instant then
			t.pl.face.BackgroundColor3 = face t.pl.lip.BackgroundColor3 = lip t.label.TextColor3 = fg t.icon.ImageColor3 = fg
		else
			tween(t.pl.face, 0.15, { BackgroundColor3 = face })
			tween(t.pl.lip, 0.15, { BackgroundColor3 = lip })
			tween(t.label, 0.15, { TextColor3 = fg })
			tween(t.icon, 0.15, { ImageColor3 = fg })
		end
	end
end

local lastSwitch, pausedUntil = os.clock(), 0
local function setCat(cat)
	if not cat or not avail[cat] then return end
	token += 1
	local my = token
	lastSwitch = os.clock()
	local first = cur == nil
	local same = cur == cat
	cur = cat
	paintTabs(first)
	if same then return end
	local function show()
		if my ~= token then return end
		title.Text = cat.title
		titleIcon.Image = cat.icon
		content.Position = CONTENT_POS + UDim2.fromScale(40 / W, 0)
		content.GroupTransparency = 1
		render(true)
		tween(content, 0.22, { Position = CONTENT_POS, GroupTransparency = 0 })
	end
	if first then
		show()
	else
		-- quick slide out to the left + fade, then in from the right
		tween(content, 0.16, { Position = CONTENT_POS - UDim2.fromScale(40 / W, 0), GroupTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.17, show)
	end
end

local function nextCat()
	if not cur then return nil end
	local idx = table.find(CATS, cur) or 1
	for step = 1, #CATS do
		local c = CATS[(idx - 1 + step) % #CATS + 1]
		if avail[c] then return c end
	end
	return nil
end

local function attach(cat, v)
	if avail[cat] or not (v and v:IsA("StringValue")) then return end
	avail[cat] = v
	tabs[cat].slot.Visible = true
	parse(cat)
	v.Changed:Connect(function()
		parse(cat)
		if cur == cat then render(false) end
	end)
	if not cur then setCat(cat) end
end

for cat, t in tabs do
	-- (2026-10-21) world clicks are optional (SurfaceGui in PlayerGui, so they do reach the buttons); a click pauses the cycle 20 s
	t.pl.face.Activated:Connect(function()
		pausedUntil = os.clock() + PAUSE
		setCat(cat)
		t.pl.scale.Scale = 0.94
		tween(t.pl.scale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	t.pl.face.MouseEnter:Connect(function() tween(t.pl.scale, 0.12, { Scale = 1.04 }) end)
	t.pl.face.MouseLeave:Connect(function() tween(t.pl.scale, 0.12, { Scale = 1 }) end)
end

-- each value waits on its own (30 s), and a value that turns up later still attaches
for _, cat in CATS do
	task.spawn(function() attach(cat, ReplicatedStorage:WaitForChild(cat.value, 30)) end)
end
ReplicatedStorage.ChildAdded:Connect(function(ch)
	for _, cat in CATS do
		if ch.Name == cat.value then attach(cat, ch) end
	end
end)

render(true) -- empty state until the first value arrives
task.spawn(function()
	while gui.Parent do
		task.wait(0.5)
		local now = os.clock()
		if cur and now - lastSwitch >= CYCLE and now >= pausedUntil then
			local c = nextCat()
			if c and c ~= cur then setCat(c) else lastSwitch = now end
		end
	end
end)
