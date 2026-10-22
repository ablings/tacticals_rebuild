-- LeaderboardScreen: the hub leaderboard board on workspace.LobbyMap.Signs.Screen_Leaderboard
-- (LocalScript; the SurfaceGui is parented into PlayerGui and adorned to the part, Front face, 940x580 canvas).
-- (2026-10-21, RIVALS 1:1) rebuilt after RIVALS' lobby boards (notes/ui_rivals/06_leaderboards.md, frames t0193 Win Streaks,
-- t0205-t0211 Most Eliminations, t0215 Most Wins, t0219-t0225 Highest Level, t0273 Ranked):
--   * a big red-gradient title (FredokaOne) with the red LIVE pill at the right of the header;
--   * the list sits in a rounded red-framed well on the dark purple-black board; #1 is a hero row (big headshot with a gold
--     "#1" tag on its corner, big name, @user and #id, a big stat badge = category icon with the number printed over it),
--     then even rows #2-#10 (headshot with a white "#N" tag, display name, @user, #id, stat badge on the right);
--   * the well scrolls: about five entries show, the board glides down through #10 and back (RIVALS scrolls to #100; we
--     publish the top 10), and a mouse wheel / drag scrolls it by hand;
--   * four chunky square icon tabs under the well (flame / elims / trophy / level) switch the category; the board cycles
--     itself Win Streaks -> Most Eliminations -> Most Wins -> Highest Level; a clicked tab pauses the cycle for 20 s;
--   * numbers count up on refresh (a tweened NumberValue per slot), rows pop in staggered on a category change.
-- Data (server LobbyLeaderboard, unchanged): StringValues in ReplicatedStorage, JSON arrays best-first, top 10, refreshed every
-- 60 s, entries { u = userId, n = display name, w = value }; LobbyTopLevel adds x = XP (ranked by XP). Any value may be
-- missing: its tab stays hidden until the value shows up. @user is looked up on the client (cached; players in the server
-- answer at once).
-- Colours / fonts: UIKit.Rivals.Theme only (RIVALS normal theme). Laid out in design px and written as Scale (Edward's rule).
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

local UIKit = ReplicatedStorage:WaitForChild("UIKit")
local RUI = UIKit:WaitForChild("Rivals")
local RTheme = require(RUI:WaitForChild("Theme"))
local RAssets = require(RUI:WaitForChild("Assets"))
local LKit = require(UIKit:WaitForChild("Kit")) -- Kit.ICONS: lbStreak / lbElims / lbWins / lbLevel, live, trophy, streakColor
local ICONS = LKit.ICONS
local RC, RF, RH = RTheme.color, RTheme.font, RTheme.hex

local W, H = 940, 580
local CYCLE, PAUSE = 11, 20 -- seconds per category (top hold + glide down + hold + glide up); pause after a tab click

-- (2026-10-21, RIVALS 1:1) board tokens, all from the Rivals Theme: the board is RIVALS' dark purple-black, the well frame and
-- tabs are its red, the titles its red gradient; #1 tag gold. Values Theme has no token for read Theme.board[name] first.
local function tok(name, default)
	local t = RTheme.board
	if t and t[name] ~= nil then return t[name] end
	return default
end
local COL = {
	boardTop = tok("boardTop", RC.panelRaised), boardBot = tok("boardBot", RC.panel),
	well = tok("well", RC.scrim), frame = RTheme.gradient.red, title = RTheme.gradient.red,
	tabFace = tok("tabFace", RC.panelRaised), tabIcon = tok("tabIcon", RC.red),
	text = RC.text, dim = RC.textDim, dimmer = tok("dimmer", RC.disabled), ink = RC.textDark,
	gold = RC.gold, own = tok("own", RC.white), shotBg = tok("shotBg", RC.track),
}
local F_CHUNKY, F_BODY, F_HEAVY = RF.chunky, RF.medium, RF.heavy

-- stat badges: the category icon with the number printed over it (white glyphs are tinted)
local CATS = {
	{ key = "streak", value = "LobbyTopStreak", title = "Win Streaks", tab = LKit.glyph("flame", ICONS.lbStreak),
		badge = (ICONS.streakColor and ICONS.streakColor ~= "") and ICONS.streakColor or ICONS.streak, tint = (ICONS.streakColor and ICONS.streakColor ~= "") and RC.white or RTheme.hex("#FF8C28") },
	{ key = "elims", value = "LobbyTopKills", title = "Most Eliminations", tab = RAssets.gen.tasks_elims or ICONS.lbElims, badge = RAssets.gen.tasks_elims, tint = RC.red },
	{ key = "wins", value = "LobbyTopWins", title = "Most Wins", tab = LKit.glyph("trophy", ICONS.lbWins), badge = LKit.glyph("trophy", ICONS.trophy), tint = RC.gold },
	{ key = "level", value = "LobbyTopLevel", title = "Highest Level", tab = LKit.glyph("level", ICONS.lbLevel), badge = RAssets.hud.levelbadge, tint = RC.white, level = true },
}

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
	if p.BorderSizePixel == nil then p.BorderSizePixel = 0 end
	return new(c, p, parent)
end
local function text(parent, pw, ph, x, y, w, h, str, font, color, align, outline)
	local l = at("TextLabel", parent, pw, ph, x, y, w, h, { BackgroundTransparency = 1, Text = str, FontFace = font, TextScaled = true,
		TextColor3 = color, TextXAlignment = align or Enum.TextXAlignment.Left, ZIndex = 3 })
	-- RIVALS' board text carries a dark outline (the numbers over icons most); fixed 940x580 canvas, so px thickness is stable
	if outline then new("UIStroke", { Color = COL.ink, Thickness = outline, Transparency = 0.15, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, l) end
	return l
end
local function grad(o, pair)
	return new("UIGradient", { Rotation = 90, Color = ColorSequence.new(pair[1], pair[2]) }, o)
end
local function corner(o, r) return new("UICorner", { CornerRadius = UDim.new(0, r) }, o) end
local function tween(o, t, props, style, dir, delay)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out, 0, false, delay or 0), props)
	tw:Play()
	return tw
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
local root = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = RC.white, BorderSizePixel = 0 }, gui)
grad(root, { COL.boardTop, COL.boardBot })

-- header: title (red gradient, FredokaOne) + LIVE pill at the right (t0273)
local title = text(root, W, H, 34, 12, 680, 62, "Leaderboard", F_CHUNKY, RC.white, Enum.TextXAlignment.Left, 2.5)
grad(title, COL.title)
local live = at("ImageLabel", root, W, H, 790, 22, 118, 44, { BackgroundTransparency = 1, Image = ICONS.live, ScaleType = Enum.ScaleType.Fit, ZIndex = 3 })
local liveScale = new("UIScale", { Scale = 1 }, live)
TweenService:Create(liveScale, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.06 }):Play()

-- the well: a red frame (gradient) with the dark list inside, 6 px rim, rounded
local WX, WY, WW, WH = 24, 84, 892, 404
local rim = at("Frame", root, W, H, WX, WY, WW, WH, { BackgroundColor3 = RC.white })
grad(rim, COL.frame)
corner(rim, 20)
local wellIn = at("Frame", rim, WW, WH, 6, 6, WW - 12, WH - 12, { BackgroundColor3 = COL.well, ClipsDescendants = true })
corner(wellIn, 15)
local LW, LH = WW - 12, WH - 12 -- 880 x 392
-- a CanvasGroup so a category switch can slide + fade the list as one piece; the ScrollingFrame fills it exactly (so its
-- CanvasSize Scale means the same whether Roblox reads it against the frame or its parent)
local content = new("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0 }, wellIn)
local scroller = new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6,
	ScrollBarImageColor3 = RC.red, ScrollBarImageTransparency = 0.1, ScrollingDirection = Enum.ScrollingDirection.Y, CanvasSize = UDim2.fromScale(0, 1),
	ElasticBehavior = Enum.ElasticBehavior.Never }, content)

-- row geometry inside the canvas (design px): hero 128 tall, rows 68, 8 px top pad
local PAD, HERO_H, ROW_H = 8, 128, 68
local function rowY(i) return i == 1 and PAD or PAD + HERO_H + (i - 2) * ROW_H end

local slots = {}
local function numberSlot(slot, label)
	slot.prefix = ""
	slot.nv = new("NumberValue", { Value = 0 }, label)
	slot.nv.Changed:Connect(function(v) label.Text = slot.prefix .. fmt(v) end)
	slot.valueLabel = label
end
-- one row: rw x rh design px. hero = bigger everything.
local function makeRow(i)
	local hero = i == 1
	local rh = hero and HERO_H or ROW_H
	local rw = LW - 14 -- leave the scrollbar its lane
	local holder = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, BorderSizePixel = 0 }, scroller)
	local scale = new("UIScale", { Scale = 1 }, holder)
	-- your own row: a faint white wash (RIVALS shows no special row; this only helps you find yourself)
	local wash = at("Frame", holder, rw, rh, 4, 2, rw - 8, rh - 4, { BackgroundColor3 = COL.own, BackgroundTransparency = 1 })
	corner(wash, 10)
	local shotS = hero and 104 or 54
	local shotX = hero and 16 or 18
	local shot = at("ImageLabel", holder, rw, rh, shotX, (rh - shotS) / 2 - (hero and 4 or 2), shotS, shotS, { BackgroundColor3 = COL.shotBg, BackgroundTransparency = 0.4, Image = "", ZIndex = 2 })
	corner(shot, hero and 14 or 9)
	-- "#N" tag over the headshot's lower-left corner (gold for #1)
	local tagW, tagH = hero and 64 or 40, hero and 40 or 26
	local tag = text(holder, rw, rh, shotX - (hero and 8 or 6), (rh - shotS) / 2 + shotS - tagH + (hero and 6 or 6), tagW, tagH, "#" .. i, F_CHUNKY,
		hero and COL.gold or COL.text, Enum.TextXAlignment.Left, hero and 3 or 2)
	tag.ZIndex = 4
	local nx = shotX + shotS + (hero and 22 or 16)
	local name = text(holder, rw, rh, nx, hero and 10 or 6, hero and 470 or 520, hero and 48 or 28, "-", F_CHUNKY, COL.text, nil, hero and 2 or 1.5)
	local user = text(holder, rw, rh, nx + 2, hero and 60 or 35, 420, hero and 28 or 16, "", F_BODY, COL.dim)
	local id = text(holder, rw, rh, nx + 2, hero and 88 or 51, 420, hero and 24 or 13, "", F_BODY, COL.dimmer)
	-- stat badge: icon with the number printed over it
	local bS = hero and 116 or 62
	local bx = rw - bS - (hero and 18 or 26)
	local badge = at("ImageLabel", holder, rw, rh, bx, (rh - bS) / 2, bS, bS, { BackgroundTransparency = 1, Image = "", ScaleType = Enum.ScaleType.Fit, ZIndex = 3 })
	local value = text(holder, rw, rh, bx - (hero and 14 or 16), rh / 2 - (hero and 22 or 13) + (hero and 4 or 3), bS + (hero and 28 or 32), hero and 44 or 26, "0",
		F_CHUNKY, COL.text, Enum.TextXAlignment.Center, hero and 3 or 2)
	value.ZIndex = 5
	local slot = { holder = holder, scale = scale, wash = wash, shot = shot, tag = tag, name = name, user = user, id = id, badge = badge, hero = hero, rh = rh }
	numberSlot(slot, value)
	return slot
end
for i = 1, 10 do slots[i] = makeRow(i) end
local empty = text(wellIn, LW, LH, 90, 160, 700, 64, "No one yet - be the first!", F_CHUNKY, COL.text, Enum.TextXAlignment.Center, 2)
empty.ZIndex = 6

-- lay the rows out for n entries (Scale of the current canvas height)
local canvasH = LH
local function layout(n)
	local contentH = n > 0 and (rowY(math.min(n, 10)) + (n == 1 and HERO_H or ROW_H) + PAD) or LH
	canvasH = math.max(LH, contentH)
	scroller.CanvasSize = UDim2.fromScale(0, canvasH / LH)
	for i, slot in slots do
		slot.holder.Position = UDim2.fromScale(0.5 - 7 / LW, (rowY(i) + slot.rh / 2) / canvasH)
		slot.holder.Size = UDim2.fromScale((LW - 14) / LW, slot.rh / canvasH)
	end
end

-- tabs under the well: four chunky squares (red rim, dark face, red glyph; the shown one fills red with a white glyph)
local TS, TG = 72, 18
local tabsX = (W - (4 * TS + 3 * TG)) / 2
local tabBar = at("Frame", root, W, H, tabsX, 498, 4 * TS + 3 * TG, TS, { BackgroundTransparency = 1 })
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(TG / (4 * TS + 3 * TG), 0), SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Center }, tabBar)
local tabs = {}
for i, cat in CATS do
	local b = new("TextButton", { Size = UDim2.fromScale(TS / (4 * TS + 3 * TG), 1), BackgroundColor3 = RC.white, AutoButtonColor = false, Text = "",
		LayoutOrder = i, Visible = false, BorderSizePixel = 0 }, tabBar)
	grad(b, COL.frame)
	corner(b, 12)
	local face = at("Frame", b, TS, TS, 5, 5, TS - 10, TS - 10, { BackgroundColor3 = COL.tabFace })
	corner(face, 8)
	local icon = at("ImageLabel", face, TS - 10, TS - 10, 10, 10, TS - 30, TS - 30, { BackgroundTransparency = 1, Image = cat.tab, ImageColor3 = COL.tabIcon, ScaleType = Enum.ScaleType.Fit, ZIndex = 3 })
	local scale = new("UIScale", { Scale = 1 }, b)
	tabs[cat] = { button = b, face = face, icon = icon, scale = scale }
end

-- ---------------------------------------------------------------- data + render
local data = {}   -- [cat.key] = decoded list
local avail = {}  -- [cat] = StringValue
local cur = nil
local shots, users = {}, {}
local token = 0

local function setShot(slot, u)
	if slot.u == u then return end
	slot.u = u
	slot.shot.Image = (u and shots[u]) or ""
	if not u or shots[u] then return end
	task.spawn(function()
		local ok, url = pcall(Players.GetUserThumbnailAsync, Players, math.max(1, u), Enum.ThumbnailType.HeadShot,
			slot.hero and Enum.ThumbnailSize.Size150x150 or Enum.ThumbnailSize.Size60x60)
		if ok and url then
			shots[u] = url
			if slot.u == u then slot.shot.Image = url end
		end
	end)
end
-- @username: from the player if they are here, else one cached lookup per user id
local function setUser(slot, u)
	if not u then slot.user.Text = "" return end
	local p = Players:GetPlayerByUserId(u)
	if p then users[u] = p.Name end
	if users[u] then slot.user.Text = "@" .. users[u] return end
	slot.user.Text = ""
	if users[u] == false then return end
	users[u] = false -- in flight
	task.spawn(function()
		local ok, nm = pcall(Players.GetNameFromUserIdAsync, Players, u)
		users[u] = ok and nm or nil
		if ok and nm then
			for _, s in slots do if s.u == u then s.user.Text = "@" .. nm end end
		end
	end)
end

-- full = category changed: numbers count from 0 and every row pops in; otherwise numbers count from where they stand
-- and only rows whose player changed pop.
local function render(full)
	local list = (cur and data[cur.key]) or {}
	empty.Visible = #list == 0
	layout(#list)
	local n = 0
	for i, slot in slots do
		local e = list[i]
		slot.holder.Visible = e ~= nil
		if e then
			n += 1
			local u = tonumber(e.u)
			local changed = slot.u ~= u
			slot.name.Text = tostring(e.n or "Player")
			setShot(slot, u)
			setUser(slot, u)
			slot.id.Text = u and ("#" .. tostring(u)) or ""
			slot.wash.BackgroundTransparency = (u ~= nil and u == player.UserId) and 0.9 or 1
			slot.badge.Image = cur.badge or ""
			slot.badge.ImageColor3 = cur.tint or RC.white
			-- (2026-10-22, Edward: level numbers like RIVALS) the level board's number in the seal's style, the others keep the ink edge
			if cur.level and LKit.levelNumber then LKit.levelNumber(slot.valueLabel)
			else
				local vs = slot.valueLabel:FindFirstChildOfClass("UIStroke")
				if vs then vs.Color = COL.ink end
				slot.valueLabel.FontFace = F_CHUNKY
			end
			slot.prefix = ""
			local target = tonumber(e.w) or 0
			if full then slot.nv.Value = 0 end
			if full or slot.nv.Value ~= target then
				tween(slot.nv, full and 0.9 or 0.7, { Value = target }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, full and (n - 1) * 0.04 or 0)
			else
				slot.valueLabel.Text = fmt(target)
			end
			if full or changed then
				slot.scale.Scale = full and 0 or 0.9
				tween(slot.scale, 0.32, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, full and (n - 1) * 0.045 or 0)
			end
		else
			slot.u = nil
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
		local face = on and RC.red or COL.tabFace
		local fg = on and RC.white or COL.tabIcon
		if instant then
			t.face.BackgroundColor3 = face t.icon.ImageColor3 = fg
		else
			tween(t.face, 0.15, { BackgroundColor3 = face })
			tween(t.icon, 0.15, { ImageColor3 = fg })
		end
	end
end

-- auto-scroll: hold at the top, glide down to the last row, hold, glide back (RIVALS' boards page through their list)
local scrollNV = new("NumberValue", { Value = 0 }, scroller)
local function applyScroll()
	local span = math.max(0, scroller.AbsoluteCanvasSize.Y - scroller.AbsoluteWindowSize.Y)
	scroller.CanvasPosition = Vector2.new(0, scrollNV.Value * span)
end
scrollNV.Changed:Connect(applyScroll)
local scrollTween
local function scrollTo(v, t)
	if scrollTween then scrollTween:Cancel() end
	scrollTween = tween(scrollNV, t, { Value = v }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
end
local handUntil = 0 -- a hand scroll (wheel / drag) holds the auto-scroll for a while
scroller.InputChanged:Connect(function(io)
	if io.UserInputType == Enum.UserInputType.MouseWheel or io.UserInputType == Enum.UserInputType.Touch then
		handUntil = os.clock() + PAUSE
		if scrollTween then scrollTween:Cancel() end
	end
end)

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
	if same then scrollTo(0, 0.4) return end -- the clicked tab restarts its own page from the top
	local function show()
		if my ~= token then return end
		title.Text = cat.title
		if scrollTween then scrollTween:Cancel() end
		scrollNV.Value = 0
		applyScroll()
		content.Position = UDim2.fromScale(40 / LW, 0)
		content.GroupTransparency = 1
		render(true)
		tween(content, 0.22, { Position = UDim2.fromScale(0, 0), GroupTransparency = 0 })
	end
	if first then
		show()
	else
		-- quick slide out to the left + fade, then in from the right
		tween(content, 0.16, { Position = UDim2.fromScale(-40 / LW, 0), GroupTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
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
	tabs[cat].button.Visible = true
	parse(cat)
	v.Changed:Connect(function()
		parse(cat)
		if cur == cat then render(false) end
	end)
	-- start on Win Streaks like RIVALS when it is there; else whatever turns up first
	if not cur or (cat == CATS[1] and os.clock() - lastSwitch < 2) then setCat(cat) end
end

for cat, t in tabs do
	-- (2026-10-21) world clicks reach the buttons (SurfaceGui in PlayerGui); a click pauses the cycle 20 s
	t.button.Activated:Connect(function()
		pausedUntil = os.clock() + PAUSE
		setCat(cat)
		t.scale.Scale = 0.92
		tween(t.scale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	t.button.MouseEnter:Connect(function() tween(t.scale, 0.12, { Scale = 1.06 }) end)
	t.button.MouseLeave:Connect(function() tween(t.scale, 0.12, { Scale = 1 }) end)
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
	local phase = 0 -- 0 top hold, 1 gliding down / bottom hold, 2 gliding up
	while gui.Parent do
		task.wait(0.25)
		local now = os.clock()
		local t = now - lastSwitch
		if now >= handUntil then
			local list = (cur and data[cur.key]) or {}
			local scrolls = #list > 5
			if t < 0.5 then
				phase = 0
			elseif scrolls and phase == 0 and t >= 2.5 then
				phase = 1
				scrollTo(1, 3.5)
			elseif scrolls and phase == 1 and t >= 7.5 then
				phase = 2
				scrollTo(0, 1.2)
			end
		end
		if cur and t >= CYCLE and now >= pausedUntil and now >= handUntil then
			local c = nextCat()
			if c and c ~= cur then setCat(c) else lastSwitch = now phase = 0 end
		end
	end
end)
