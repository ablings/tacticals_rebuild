-- LobbyUIController/Shop (ModuleScript)
-- The full-screen SHOP. Layout follows the familiar Roblox shooter shop (tab strip, featured offer,
-- bundle banners, item grid, currency packs) in tacticals' own look: ink glass, teal signal colour,
-- red/blue team accents. No caution tape here: gear is unlocked (and the tape cut) in the Kit room.
--
-- Currency: SCISSORS only (stored as data.Credits so the match place's saves still line up). The icon is a
-- render of the 3D scissors model (ReplicatedStorage.Repository.Scissors). Weapons are unlocked in the KIT
-- screen, where the caution tape gets cut - the shop's item cards send you there.
--
-- Hover focus (Settings > SHOP HOVER, saved in the profile as Settings.ShopHover 1..5):
--   1 Shutters  - the screen edges slide in and close around the item you point at, the rest goes dark
--   2 Spotlight - instant soft spotlight on the item, everything else dims
--   3 Lift      - the item lifts toward you and follows the mouse a little, the rest dims slightly
--   4 Scan      - targeting brackets snap onto the item and a scan line sweeps it
--   5 Off
-- Everything un-hovers instantly when the pointer leaves.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Shop = {}

local ctx -- set by Shop.Init: Config, Icons, UITheme, getData, ask, owns, toast, getSetting, setSetting, onClosed, renderStore

-------------------------------------------------------------------------------
-- Look
-------------------------------------------------------------------------------
local C = {
	Ink = Color3.fromRGB(7, 9, 12),
	Glass = Color3.fromRGB(16, 20, 26),
	Glass2 = Color3.fromRGB(26, 31, 39),
	Edge = Color3.fromRGB(58, 66, 78),
	Bone = Color3.fromRGB(233, 238, 241),
	Muted = Color3.fromRGB(138, 148, 163),
	Teal = Color3.fromRGB(40, 230, 200),
	TealDark = Color3.fromRGB(18, 120, 106),
	Red = Color3.fromRGB(230, 36, 48),
	Blue = Color3.fromRGB(36, 120, 255),
	Violet = Color3.fromRGB(176, 120, 255),
	Magenta = Color3.fromRGB(255, 90, 210),
	Go = Color3.fromRGB(141, 191, 90),
}
-- (2026-10-21, AI-tells sweep) Oswald Bold titles, Rubik body (was Gotham SSm)
local F = {
	Title = Font.new("rbxassetid://12187365977", Enum.FontWeight.Bold),
	Bold = Font.new("rbxassetid://12187365977", Enum.FontWeight.Bold),
	Body = Font.new("rbxassetid://12187365977", Enum.FontWeight.Medium),
}
local IMG = {
	Scissors = "rbxassetid://120480559804238", -- render of the 3D scissors
}
local HOVER_NAMES = { "Shutters", "Spotlight", "Lift", "Scan", "Off" }
Shop.HoverNames = HOVER_NAMES

local function new(class: string, props, children)
	local inst = Instance.new(class)
	for k, v in props or {} do if k ~= "Parent" then inst[k] = v end end
	for _, c in children or {} do c.Parent = inst end
	if props and props.Parent then inst.Parent = props.Parent end
	return inst
end
local function tw(obj, t, props, style, dir)
	local x = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
	x:Play()
	return x
end
local function corner(r) return new("UICorner", { CornerRadius = UDim.new(0, r or 8) }) end
local function stroke(col, th, tr) return new("UIStroke", { Color = col, Thickness = th or 1, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) end
local function text(props)
	local l = new("TextLabel", { BackgroundTransparency = 1, FontFace = F.Bold, TextColor3 = C.Bone, TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 20) })
	for k, v in props do if k ~= "Parent" then l[k] = v end end
	if props.Parent then l.Parent = props.Parent end
	return l
end
local function commas(n: number): string
	local s = tostring(math.floor(n))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end
local function scissorsIcon(props)
	local i = new("ImageLabel", { BackgroundTransparency = 1, Image = IMG.Scissors, ScaleType = Enum.ScaleType.Fit })
	for k, v in props do if k ~= "Parent" then i[k] = v end end
	i.Parent = props.Parent
	return i
end

-------------------------------------------------------------------------------
-- Hover focus
-------------------------------------------------------------------------------
local gui, overlay, bars, brackets, scanLine
local hovered, hoverConn, liftScale
local function hoverMode(): number
	local v = ctx and ctx.getSetting("ShopHover") or 1
	return math.clamp(math.floor(v + 0.5), 1, #HOVER_NAMES)
end

local function rectOf(obj: GuiObject, padPx: number)
	-- relative to the overlay (absorbs the top-bar inset difference)
	local p, s = obj.AbsolutePosition - overlay.AbsolutePosition, obj.AbsoluteSize
	return p - Vector2.new(padPx, padPx), s + Vector2.new(padPx * 2, padPx * 2)
end

-- place the four dark bars so they leave a hole at (p, s)
local function barGoals(p: Vector2, s: Vector2)
	local W = overlay.AbsoluteSize
	return {
		Top = { Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(W.X, math.max(0, p.Y)) },
		Bottom = { Position = UDim2.fromOffset(0, p.Y + s.Y), Size = UDim2.fromOffset(W.X, math.max(0, W.Y - p.Y - s.Y)) },
		Left = { Position = UDim2.fromOffset(0, p.Y), Size = UDim2.fromOffset(math.max(0, p.X), s.Y) },
		Right = { Position = UDim2.fromOffset(p.X + s.X, p.Y), Size = UDim2.fromOffset(math.max(0, W.X - p.X - s.X), s.Y) },
	}
end
local function edgeStart()
	local W = overlay.AbsoluteSize
	return {
		Top = { Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(W.X, 0) },
		Bottom = { Position = UDim2.fromOffset(0, W.Y), Size = UDim2.fromOffset(W.X, 0) },
		Left = { Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(0, W.Y) },
		Right = { Position = UDim2.fromOffset(W.X, 0), Size = UDim2.fromOffset(0, W.Y) },
	}
end

local function setBrackets(p: Vector2, s: Vector2, animate: boolean, from: number?)
	local L = 16
	local spots = {
		{ p, Vector2.new(1, 1) }, { p + Vector2.new(s.X, 0), Vector2.new(-1, 1) },
		{ p + Vector2.new(0, s.Y), Vector2.new(1, -1) }, { p + s, Vector2.new(-1, -1) },
	}
	local centre = p + s / 2
	for i, b in brackets do
		local at, dir = spots[i][1], spots[i][2]
		local goal = UDim2.fromOffset(at.X, at.Y)
		b.frame.Visible = true
		b.h.Position = UDim2.fromOffset(dir.X < 0 and -L or 0, dir.Y < 0 and -2 or 0)
		b.v.Position = UDim2.fromOffset(dir.X < 0 and -2 or 0, dir.Y < 0 and -L or 0)
		if animate then
			local k = from or 1.35
			local start = centre + (at - centre) * k
			b.frame.Position = UDim2.fromOffset(start.X, start.Y)
			tw(b.frame, 0.16, { Position = goal })
		else
			b.frame.Position = goal
		end
	end
end
local function hideBrackets() for _, b in brackets do b.frame.Visible = false end end

local function unhover()
	if not hovered then return end
	local card = hovered
	hovered = nil
	if hoverConn then hoverConn:Disconnect() hoverConn = nil end
	-- instant release (a very short fade so it doesn't flicker)
	for _, b in bars do tw(b, 0.07, { BackgroundTransparency = 1 }, Enum.EasingStyle.Linear) end
	hideBrackets()
	scanLine.Visible = false
	if liftScale and liftScale.Parent then tw(liftScale, 0.1, { Scale = 1 }) end
	local st = card:FindFirstChild("HoverStroke")
	if st then st.Transparency = 1 end
end

local function hover(card: GuiObject)
	if hovered == card then return end
	local wasHovering = hovered ~= nil
	local prevRect = wasHovering and { bars.Left.AbsolutePosition, bars.Left.AbsoluteSize } or nil
	if hovered then
		local st = hovered:FindFirstChild("HoverStroke")
		if st then st.Transparency = 1 end
		if liftScale and liftScale.Parent then tw(liftScale, 0.1, { Scale = 1 }) end
	end
	if hoverConn then hoverConn:Disconnect() hoverConn = nil end
	hovered = card
	local mode = HOVER_NAMES[hoverMode()]
	local st = card:FindFirstChild("HoverStroke")
	if st then st.Transparency = 0 end
	if mode == "Off" then return end

	local padPx = mode == "Shutters" and 10 or 6
	local p, s = rectOf(card, padPx)
	local goals = barGoals(p, s)
	local dark = ({ Shutters = 0.28, Spotlight = 0.42, Lift = 0.6, Scan = 0.72 })[mode]

	if mode == "Shutters" then
		-- from the screen edges (or from the last item) the shutters slide in and close around this one
		local start = wasHovering and nil or edgeStart()
		for name, b in bars do
			if start then b.Position, b.Size = start[name].Position, start[name].Size end
			b.BackgroundTransparency = dark
			tw(b, 0.2, goals[name])
		end
		setBrackets(p, s, true, 1.12)
	elseif mode == "Spotlight" then
		for name, b in bars do
			b.Position, b.Size = goals[name].Position, goals[name].Size
			b.BackgroundTransparency = 1
			tw(b, 0.12, { BackgroundTransparency = dark }, Enum.EasingStyle.Quad)
		end
		hideBrackets()
	elseif mode == "Lift" then
		for name, b in bars do
			b.Position, b.Size = goals[name].Position, goals[name].Size
			b.BackgroundTransparency = 1
			tw(b, 0.12, { BackgroundTransparency = dark }, Enum.EasingStyle.Quad)
		end
		liftScale = card:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = card })
		tw(liftScale, 0.16, { Scale = 1.06 }, Enum.EasingStyle.Back)
		hideBrackets()
	elseif mode == "Scan" then
		for name, b in bars do
			b.Position, b.Size = goals[name].Position, goals[name].Size
			b.BackgroundTransparency = 1
			tw(b, 0.1, { BackgroundTransparency = dark })
		end
		setBrackets(p, s, true, 1.5)
		scanLine.Visible = true
		scanLine.Position = UDim2.fromOffset(p.X, p.Y)
		scanLine.Size = UDim2.fromOffset(s.X, 3)
		scanLine.BackgroundTransparency = 0
		tw(scanLine, 0.45, { Position = UDim2.fromOffset(p.X, p.Y + s.Y - 3), BackgroundTransparency = 0.6 }, Enum.EasingStyle.Quad)
	end

	-- keep framing the card while the list scrolls / the lift wobbles
	hoverConn = RunService.RenderStepped:Connect(function()
		if not card.Parent or not card.Visible then unhover() return end
		local np, ns = rectOf(card, padPx)
		if (np - p).Magnitude > 0.5 or (ns - s).Magnitude > 0.5 then
			p, s = np, ns
			local g = barGoals(p, s)
			for name, b in bars do b.Position, b.Size = g[name].Position, g[name].Size end
			if mode == "Shutters" or mode == "Scan" then setBrackets(p, s, false) end
		end
		if mode == "Lift" then
			local m = UserInputService:GetMouseLocation() - Vector2.new(0, game:GetService("GuiService"):GetGuiInset().Y)
			local rel = (m - (card.AbsolutePosition + card.AbsoluteSize / 2)) / card.AbsoluteSize
			card.Rotation = math.clamp(rel.X, -0.5, 0.5) * 3
		end
	end)
end

-- every hoverable card goes through here
local function hoverable(card: GuiObject, accent: Color3?)
	new("UIStroke", { Name = "HoverStroke", Color = accent or C.Teal, Thickness = 2, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = card })
	card.MouseEnter:Connect(function() hover(card) end)
	card.MouseLeave:Connect(function()
		if hovered == card then
			card.Rotation = 0
			unhover()
		end
	end)
	return card
end

-------------------------------------------------------------------------------
-- Building blocks
-------------------------------------------------------------------------------
local tabs = {
	{ Id = "Home", Name = "Home" },
	{ Id = "Bundles", Name = "Bundles" },
	{ Id = "Arms", Name = "Arms" },
	{ Id = "Scissors", Name = "Scissors" },
}
local tab = "Home"
local content, tabButtons, scissorText = nil, {}, nil
local pending, pendingAt = nil, 0

local function data() return ctx.getData() or {} end

local function art(parent: GuiObject, itemId: string, z: number)
	local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = z, Parent = parent })
	local img = ctx.Config.Images and ctx.Config.Images[itemId]
	if img and img ~= "" then
		new("ImageLabel", { BackgroundTransparency = 1, Image = img, Size = UDim2.fromScale(1, 1), ScaleType = Enum.ScaleType.Fit, ZIndex = z, Parent = holder })
	else
		local model, view, zoom = ctx.Icons.Item(itemId)
		local icon = ctx.Icons.Viewport(holder, model, { view = view, zoom = zoom })
		parent.MouseEnter:Connect(function() icon.SetHover(true) end)
		parent.MouseLeave:Connect(function() icon.SetHover(false) end)
	end
	return holder
end

-- price pill: credits (teal), scissors (bone on ink with the scissors icon), robux (green) or owned
local function pricePill(parent, kind: string, amount: number?, onBuy, z: number, key: string?)
	key = key or tostring(kind) .. tostring(amount)
	local isConfirm = pending == key and os.clock() - pendingAt < 3
	local bg = kind == "robux" and C.Go or kind == "kit" and C.Glass2 or kind == "owned" and C.Glass2 or C.Teal
	local fg = (kind == "owned") and C.Muted or (kind == "kit") and C.Bone or C.Ink
	local b = new("TextButton", { AutoButtonColor = false, BackgroundColor3 = isConfirm and C.Go or bg, Text = "", AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -16, 0, 34), ZIndex = z, Parent = parent }, { corner(6) })
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = z, Parent = b }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6) }),
	})
	if isConfirm then
		text({ Text = "Confirm", FontFace = F.Title, TextSize = 17, TextColor3 = C.Ink, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 34), ZIndex = z, Parent = row })
	elseif kind == "owned" then
		text({ Text = "Owned", FontFace = F.Title, TextSize = 16, TextColor3 = fg, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 34), ZIndex = z, Parent = row })
	else
		if kind == "scissors" or kind == "kit" then scissorsIcon({ Size = UDim2.fromOffset(26, 26), ZIndex = z, Parent = row }) end
		local t = kind == "robux" and ("R$ " .. commas(amount)) or commas(amount)
		text({ Text = t, FontFace = F.Title, TextSize = 18, TextColor3 = fg, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 34), ZIndex = z, Parent = row })
	end
	if kind ~= "owned" and onBuy then
		b.MouseEnter:Connect(function() tw(b, 0.12, { BackgroundColor3 = (isConfirm and C.Go or bg):Lerp(Color3.new(1, 1, 1), 0.18) }) end)
		b.MouseLeave:Connect(function() tw(b, 0.12, { BackgroundColor3 = isConfirm and C.Go or bg }) end)
		b.Activated:Connect(function()
			if kind == "robux" or kind == "kit" then onBuy() return end -- Roblox shows its own confirm / the Kit screen asks
			if pending == key and os.clock() - pendingAt < 3 then
				pending = nil
				onBuy()
			else
				pending, pendingAt = key, os.clock()
				Shop.Refresh()
				task.delay(3.05, function() if pending == key then pending = nil Shop.Refresh() end end)
			end
		end)
	end
	return b
end

-- an item card. Gear is unlocked in the Kit room (where the caution tape is cut), so the button goes there.
local function itemCard(parent, id: string, order: number, size: UDim2?)
	local Config = ctx.Config
	local item = Config.Items[id]
	local rar = Config.Rarities[item.Rarity] or Config.Rarities.Standard
	local owned = ctx.owns(id)
	local card = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = order, Size = size or UDim2.new(), ZIndex = 3, Parent = parent },
		{ corner(10), stroke(rar.Color, 1, 0.55),
			new("UIGradient", { Rotation = 90, Color = ColorSequence.new(rar.Color:Lerp(C.Ink, 0.62), C.Glass) }) })
	hoverable(card, rar.Color)
	local artBox = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 1, -96), ZIndex = 4, Parent = card })
	art(artBox, id, 4)
	text({ Text = item.Name, FontFace = F.Title, TextSize = 17, Position = UDim2.new(0, 12, 1, -84), Size = UDim2.new(1, -24, 0, 20), ZIndex = 5, Parent = card })
	text({ Text = item.Rarity .. " " .. string.lower(Config.SlotNames[item.Slot] or item.Slot), FontFace = F.Bold, TextSize = 12,
		TextColor3 = rar.Color, Position = UDim2.new(0, 12, 1, -63), Size = UDim2.new(1, -24, 0, 14), ZIndex = 5, Parent = card })
	if owned then
		pricePill(card, "owned", nil, nil, 6)
	else
		-- unlocking happens in the KIT screen (the caution tape gets cut there)
		pricePill(card, "kit", item.Price, function() ctx.openKit(id) end, 6, "kit:" .. id)
	end
	return card
end

local function section(parent, title: string, order: number)
	local h = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = order, Parent = parent })
	text({ Text = title, FontFace = F.Title, TextSize = 20, Size = UDim2.new(1, 0, 1, 0), ZIndex = 3, Parent = h })
	return h
end

local function scrollList(parent)
	local s = new("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, ScrollBarImageColor3 = C.Edge, ZIndex = 2, Parent = parent },
		{ new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 30) }) })
	s:GetPropertyChangedSignal("CanvasPosition"):Connect(function() end)
	return s
end

-------------------------------------------------------------------------------
-- Tabs
-------------------------------------------------------------------------------
local function bundleBanner(parent, bundle, order: number, big: boolean)
	local Config = ctx.Config
	local cost, missing = Config.BundleCost(bundle, ctx.owns)
	local full = 0
	for _, id in bundle.Items do full += Config.Items[id].Price end
	local col = bundle.Color or C.Teal
	local card = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = order, ZIndex = 3, ClipsDescendants = true,
		Size = big and UDim2.new(1, 0, 0, 230) or UDim2.new(), Parent = parent },
		{ corner(12), stroke(col, 1.5, 0.3), new("UIGradient", { Rotation = 20, Color = ColorSequence.new(col:Lerp(C.Ink, 0.45), C.Ink) }) })
	hoverable(card, col)
	-- big diagonal stripe of the bundle colour behind the art
	new("Frame", { BackgroundColor3 = col, BackgroundTransparency = 0.82, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.72, 0.5), Size = UDim2.new(0.28, 0, 2, 0), Rotation = 22, ZIndex = 3, Parent = card })
	text({ Text = bundle.Name, FontFace = F.Title, TextSize = big and 38 or 24, Position = UDim2.fromOffset(18, 14), Size = UDim2.new(0.6, 0, 0, big and 44 or 28), ZIndex = 5, Parent = card })
	-- the items, as small art tiles
	local row = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 18, 0, big and 66 or 48), Size = UDim2.new(0.55, 0, 0, big and 110 or 64), ZIndex = 4, Parent = card },
		{ new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }) })
	for j, id in bundle.Items do
		local tile = new("Frame", { BackgroundColor3 = C.Ink, BackgroundTransparency = 0.35, Size = UDim2.fromOffset(big and 110 or 64, big and 110 or 64), LayoutOrder = j, ZIndex = 4, Parent = row },
			{ corner(8), stroke((ctx.Config.Rarities[ctx.Config.Items[id].Rarity] or ctx.Config.Rarities.Standard).Color, 1, 0.4) })
		art(tile, id, 5)
		if big then
			text({ Text = ctx.Config.Items[id].Name, FontFace = F.Bold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center,
				Position = UDim2.new(0, 0, 1, 2), Size = UDim2.new(1, 0, 0, 14), ZIndex = 5, Parent = tile })
		end
	end
	if full > cost and missing > 0 then
		local value = math.max(2, math.floor(full / math.max(cost, 1) + 0.5))
		local badge = new("TextLabel", { BackgroundColor3 = C.Red, Text = "x" .. value .. " value", FontFace = F.Title, TextSize = 14, TextColor3 = C.Bone,
			AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -66), Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X,
			ZIndex = 6, Parent = card }, { corner(6), new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }) })
	end
	local holder = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -8, 1, 0), Size = UDim2.fromOffset(big and 220 or 170, 50), ZIndex = 6, Parent = card })
	if missing == 0 then pricePill(holder, "owned", nil, nil, 7)
	else pricePill(holder, "scissors", cost, function() ctx.ask("BuyBundle", bundle.Id) end, 7, "bundle:" .. bundle.Id) end
	return card
end

local function renderHome(body)
	local Config = ctx.Config
	local list = scrollList(body)
	new("UIListLayout", { Padding = UDim.new(0, 16), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	-- top row: featured Robux bundle (big) + scissors call-out
	local top = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 260), LayoutOrder = 1, Parent = list })
	local featured
	for _, p in Config.RobuxProducts do if p.Bundle then featured = p end end
	if featured then
		local card = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(0.64, -8, 1, 0), ZIndex = 3, ClipsDescendants = true, Parent = top },
			{ corner(12), stroke(C.Blue, 1.5, 0.2), new("UIGradient", { Rotation = 0, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C.Red:Lerp(C.Ink, 0.55)),
				ColorSequenceKeypoint.new(0.5, C.Ink), ColorSequenceKeypoint.new(1, C.Blue:Lerp(C.Ink, 0.5)) }) }) })
		hoverable(card, C.Bone)
		text({ Text = featured.Name, FontFace = F.Title, TextSize = 36, Position = UDim2.fromOffset(20, 16), Size = UDim2.new(1, -40, 0, 40), ZIndex = 5, Parent = card })
		if featured.Tag then
			new("TextLabel", { BackgroundColor3 = C.Magenta, Text = string.lower(featured.Tag):gsub("^%l", string.upper), FontFace = F.Title, TextSize = 13, TextColor3 = C.Ink,
				Position = UDim2.fromOffset(20, 60), Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 6, Parent = card },
				{ corner(5), new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }) })
		end
		local row = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 96), Size = UDim2.new(1, -40, 0, 100), ZIndex = 4, Parent = card },
			{ new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10) }) })
		for j, id in featured.Items or {} do
			local tile = new("Frame", { BackgroundColor3 = C.Ink, BackgroundTransparency = 0.3, Size = UDim2.fromOffset(100, 100), LayoutOrder = j, ZIndex = 4, Parent = row }, { corner(8) })
			art(tile, id, 5)
		end
		local creditsTile = new("Frame", { BackgroundColor3 = C.Ink, BackgroundTransparency = 0.3, Size = UDim2.fromOffset(100, 100), LayoutOrder = 99, ZIndex = 4, Parent = row }, { corner(8) })
		scissorsIcon({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(52, 52), ZIndex = 5, Parent = creditsTile })
		text({ Text = "+" .. commas(featured.Credits or 0), FontFace = F.Title, TextSize = 20, TextColor3 = C.Bone, TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.new(0, 0, 1, -32), Size = UDim2.new(1, 0, 0, 24), ZIndex = 5, Parent = creditsTile })
		local ownedAll = true
		for _, id in featured.Items or {} do if not ctx.owns(id) then ownedAll = false end end
		local holder = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -8, 1, 0), Size = UDim2.fromOffset(220, 52), ZIndex = 6, Parent = card })
		if ownedAll then pricePill(holder, "owned", nil, nil, 7) else pricePill(holder, "robux", featured.Robux, function() ctx.ask("BuyRobux", featured.Key) end, 7) end
	end
	-- scissors call-out
	local sc = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.36, -8, 1, 0),
		ZIndex = 3, ClipsDescendants = true, Parent = top }, { corner(12), stroke(C.Teal, 1.5, 0.35),
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.Glass2, C.Ink) }) })
	hoverable(sc, C.Teal)
	scissorsIcon({ AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(120, 120), Position = UDim2.new(0.5, 0, 0, 14), Rotation = -8, ZIndex = 5, Parent = sc })
	text({ Text = "Scissors", FontFace = F.Title, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 142), ZIndex = 5, Parent = sc })
	text({ Text = "Unlock gear in the Kit room by cutting the tape.", FontFace = F.Body, TextSize = 14, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 170), ZIndex = 5, Parent = sc })
	local holder = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.new(1, 0, 0, 52), ZIndex = 6, Parent = sc })
	local b = new("TextButton", { AutoButtonColor = false, BackgroundColor3 = C.Teal, Text = "Get scissors", FontFace = F.Title, TextSize = 17, TextColor3 = C.Ink,
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -16, 0, 34), ZIndex = 7, Parent = holder }, { corner(6) })
	b.Activated:Connect(function() Shop.SetTab("Scissors") end)

	-- quick picks: the best gear (unlocked in the Kit room)
	section(list, "Top gear", 2)
	local grid1 = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = list },
		{ new("UIGridLayout", { CellSize = UDim2.new(0.25, -12, 0, 250), CellPadding = UDim2.fromOffset(14, 14), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local ids = {}
	for id, item in Config.Items do if not item.Default then table.insert(ids, id) end end
	table.sort(ids, function(a, b) return Config.Items[a].Price > Config.Items[b].Price end)
	local taped, rest = {}, {}
	for i, id in ids do if i <= 4 then table.insert(taped, id) elseif i <= 8 then table.insert(rest, id) end end
	for i, id in taped do itemCard(grid1, id, i) end
	section(list, "More gear", 4)
	local grid2 = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 5, Parent = list },
		{ new("UIGridLayout", { CellSize = UDim2.new(0.25, -12, 0, 250), CellPadding = UDim2.fromOffset(14, 14), SortOrder = Enum.SortOrder.LayoutOrder }) })
	for i, id in rest do itemCard(grid2, id, i) end
end

local function renderBundles(body)
	local list = scrollList(body)
	new("UIListLayout", { Padding = UDim.new(0, 16), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	local bundles = ctx.Config.Bundles
	if bundles[1] then bundleBanner(list, bundles[1], 1, true) end
	local grid = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = list },
		{ new("UIGridLayout", { CellSize = UDim2.new(0.5, -8, 0, 190), CellPadding = UDim2.fromOffset(16, 16), SortOrder = Enum.SortOrder.LayoutOrder }) })
	for i = 2, #bundles do bundleBanner(grid, bundles[i], i, false) end
end

local function renderArms(body)
	local Config = ctx.Config
	local list = scrollList(body)
	new("UIGridLayout", { CellSize = UDim2.new(0.2, -12, 0, 250), CellPadding = UDim2.fromOffset(14, 14), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	local ids = {}
	for id, item in Config.Items do if not item.Default then table.insert(ids, id) end end
	table.sort(ids, function(a, b)
		local ra, rb = Config.Rarities[Config.Items[a].Rarity].Order, Config.Rarities[Config.Items[b].Rarity].Order
		if ra ~= rb then return ra > rb end
		return Config.Items[a].Price > Config.Items[b].Price
	end)
	for i, id in ids do itemCard(list, id, i) end
end

local function renderScissors(body)
	local Config = ctx.Config
	local list = scrollList(body)
	new("UIListLayout", { Padding = UDim.new(0, 16), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	section(list, "Scissor packs", 1)
	local grid = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = list },
		{ new("UIGridLayout", { CellSize = UDim2.new(0.25, -12, 0, 240), CellPadding = UDim2.fromOffset(16, 16), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local packs = {}
	for _, p in Config.RobuxProducts do if not p.Bundle then table.insert(packs, p) end end
	for i, p in packs do
		local card = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = i, ZIndex = 3, ClipsDescendants = true, Parent = grid },
			{ corner(12), stroke(C.Teal, 1.5, 0.45), new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.Glass2, C.Ink) }) })
		hoverable(card, C.Teal)
		-- a pile of scissors: more for bigger packs
		local n = math.clamp(i, 1, 4)
		for k = 1, n do
			scissorsIcon({ AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(86, 86), Position = UDim2.new(0.5, (k - (n + 1) / 2) * 26, 0, 96 + (k % 2) * 6),
				Rotation = (k - (n + 1) / 2) * 16 - 8, ZIndex = 4 + k, Parent = card })
		end
		text({ Text = p.Name, FontFace = F.Title, TextSize = 18, TextColor3 = C.Muted, Position = UDim2.fromOffset(16, 14), Size = UDim2.new(1, -32, 0, 20), ZIndex = 9, Parent = card })
		text({ Text = "+" .. commas(p.Credits or 0), FontFace = F.Title, TextSize = 32, Position = UDim2.new(0, 16, 1, -88), Size = UDim2.new(1, -32, 0, 34), ZIndex = 9, Parent = card })
		if p.Tag then
			new("TextLabel", { BackgroundColor3 = C.Red, Text = p.Tag, FontFace = F.Title, TextSize = 13, TextColor3 = C.Bone, AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -12, 0, 12), Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 9, Parent = card },
				{ corner(5), new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }) })
		end
		pricePill(card, "robux", p.Robux, function() ctx.ask("BuyRobux", p.Key) end, 9)
	end
	section(list, "Passes", 3)
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 4, Parent = list },
		{ new("UIGridLayout", { CellSize = UDim2.new(0.5, -8, 0, 120), CellPadding = UDim2.fromOffset(16, 16), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local d = data()
	for i, p in Config.GamePasses do
		local have = d.Passes and d.Passes[p.Key]
		local card = new("Frame", { BackgroundColor3 = C.Glass, LayoutOrder = i, ZIndex = 3, Parent = row }, { corner(12), stroke(have and C.Go or C.Edge, 1, 0.3) })
		hoverable(card, C.Violet)
		text({ Text = p.Name, FontFace = F.Title, TextSize = 22, Position = UDim2.fromOffset(16, 14), Size = UDim2.new(1, -230, 0, 26), ZIndex = 4, Parent = card })
		text({ Text = p.Desc, FontFace = F.Body, TextSize = 14, TextColor3 = C.Muted, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(16, 46), Size = UDim2.new(1, -230, 0, 60), ZIndex = 4, Parent = card })
		local holder = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(200, 50), ZIndex = 5, Parent = card })
		if have then pricePill(holder, "owned", nil, nil, 6) else pricePill(holder, "robux", p.Robux, function() ctx.ask("BuyPass", p.Key) end, 6) end
	end
end

local RENDER = { Home = renderHome, Bundles = renderBundles, Arms = renderArms, Scissors = renderScissors }

-------------------------------------------------------------------------------
-- Frame
-------------------------------------------------------------------------------
local root
local function build()
	gui = new("ScreenGui", { Name = "ShopUI", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 20, Enabled = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
	gui:SetAttribute("NoStyle", true) -- the lobby's auto-stylers leave the shop exactly as drawn
	gui.Parent = player:WaitForChild("PlayerGui")
	root = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = gui })
	-- centre column, fixed 1240 design width, scaled to fit (scales about its top-centre)
	local col = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 20), Size = UDim2.fromOffset(1240, 800), Parent = root })
	local scale = new("UIScale", { Parent = col })
	local function rescale()
		local s = gui.AbsoluteSize
		local k = math.clamp(math.min((s.X - 40) / 1240, s.Y / 860), 0.5, 1.2)
		scale.Scale = k
		col.Size = UDim2.fromOffset(1240, math.max(400, (s.Y - 30) / k))
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(rescale)
	-- tab strip
	local strip = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 64), Parent = col },
		{ new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Center }) })
	for i, t in tabs do
		local b = new("TextButton", { AutoButtonColor = false, BackgroundColor3 = C.Glass, BackgroundTransparency = 0.1, Text = "", Size = UDim2.fromOffset(150, 52),
			LayoutOrder = i, ZIndex = 3, Parent = strip }, { corner(8) })
		local label = text({ Text = t.Name, FontFace = F.Title, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = b })
		local bar = new("Frame", { BackgroundColor3 = C.Teal, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0),
			Size = UDim2.fromOffset(0, 3), ZIndex = 5, Parent = b })
		if t.Id == "Scissors" then
			scissorsIcon({ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0), Size = UDim2.fromOffset(22, 22), ImageColor3 = C.Teal, ZIndex = 4, Parent = b })
			label.Position = UDim2.fromOffset(12, 0)
		end
		b.MouseEnter:Connect(function() if tab ~= t.Id then tw(b, 0.12, { BackgroundColor3 = C.Glass2 }) end end)
		b.MouseLeave:Connect(function() if tab ~= t.Id then tw(b, 0.12, { BackgroundColor3 = C.Glass }) end end)
		b.Activated:Connect(function() Shop.SetTab(t.Id) end)
		tabButtons[t.Id] = { b = b, label = label, bar = bar }
	end
	-- currencies + close, right side
	local right = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 6), Size = UDim2.fromOffset(420, 52), Parent = col },
		{ new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 8),
			VerticalAlignment = Enum.VerticalAlignment.Center }) })
	local function chip(order, iconFn, goTab)
		local c = new("TextButton", { AutoButtonColor = false, BackgroundColor3 = C.Glass, Text = "", Size = UDim2.fromOffset(150, 44), LayoutOrder = order, ZIndex = 3, Parent = right },
			{ corner(8), stroke(C.Edge, 1, 0.3) })
		iconFn(c)
		local t = text({ Text = "0", FontFace = F.Title, TextSize = 19, Position = UDim2.fromOffset(42, 0), Size = UDim2.new(1, -78, 1, 0), ZIndex = 4, Parent = c })
		new("TextLabel", { BackgroundColor3 = C.Teal, Text = "+", FontFace = F.Title, TextSize = 20, TextColor3 = C.Ink, AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(28, 28), ZIndex = 4, Parent = c }, { corner(6) })
		c.Activated:Connect(function() Shop.SetTab(goTab) end)
		return t
	end
	scissorText = chip(1, function(c) scissorsIcon({ Position = UDim2.fromOffset(6, 5), Size = UDim2.fromOffset(34, 34), ZIndex = 4, Parent = c }) end, "Scissors")
	local close = new("TextButton", { AutoButtonColor = false, BackgroundColor3 = C.Red, Text = "X", FontFace = F.Title, TextSize = 24, TextColor3 = C.Bone,
		Size = UDim2.fromOffset(52, 44), LayoutOrder = 3, ZIndex = 3, Parent = right }, { corner(8) })
	close.Activated:Connect(function() Shop.Close() end)
	-- a thin teal rule under the strip
	new("Frame", { BackgroundColor3 = C.Teal, BackgroundTransparency = 0.55, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 74), Size = UDim2.new(1, 0, 0, 2), Parent = col },
		{ new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }) }) })
	content = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 94), Size = UDim2.new(1, 0, 1, -110), Parent = col })

	-- hover overlay (above everything in the shop, but the bars leave a hole around the card)
	overlay = new("Frame", { Name = "HoverOverlay", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 50, Parent = gui })
	bars = {}
	for _, n in { "Top", "Bottom", "Left", "Right" } do
		bars[n] = new("Frame", { Name = n, BackgroundColor3 = C.Ink, BackgroundTransparency = 1, BorderSizePixel = 0, Active = false, ZIndex = 50, Parent = overlay })
	end
	brackets = {}
	for i = 1, 4 do
		local f = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 0), Visible = false, ZIndex = 52, Parent = overlay })
		local h = new("Frame", { BackgroundColor3 = C.Teal, BorderSizePixel = 0, Size = UDim2.fromOffset(16, 2), ZIndex = 52, Parent = f })
		local v = new("Frame", { BackgroundColor3 = C.Teal, BorderSizePixel = 0, Size = UDim2.fromOffset(2, 16), ZIndex = 52, Parent = f })
		brackets[i] = { frame = f, h = h, v = v }
	end
	scanLine = new("Frame", { BackgroundColor3 = C.Teal, BorderSizePixel = 0, Visible = false, ZIndex = 51, Parent = overlay },
		{ new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }) }) })
	for _, d in overlay:GetDescendants() do pcall(function() d.Interactable = false end) end
	pcall(function() overlay.Interactable = false end)
	rescale()
end

function Shop.Init(context)
	ctx = context
	local ok, err = pcall(build) -- (pass 43) a failed build is retried on the next Open
	if not ok then
		warn("[Shop] building the shop failed: " .. tostring(err))
		if gui then gui:Destroy() gui = nil end
	end
end

function Shop.IsOpen(): boolean return gui ~= nil and gui.Enabled end

function Shop.SetTab(id: string)
	tab = id
	pending = nil
	Shop.Refresh()
end

function Shop.Refresh()
	if not gui or not gui.Enabled then return end
	unhover()
	local d = data()
	scissorText.Text = commas(d.Credits or 0)
	for id, t in tabButtons do
		local on = id == tab
		t.b.BackgroundColor3 = on and C.Bone or C.Glass
		t.label.TextColor3 = on and C.Ink or C.Bone
		t.bar.Size = UDim2.fromOffset(on and 0 or 0, 3)
	end
	local keep = content:FindFirstChildWhichIsA("ScrollingFrame", true)
	local scroll = keep and keep.CanvasPosition
	for _, c in content:GetChildren() do c:Destroy() end
	-- (pass 43) a failed draw must never leave the shop half-built behind the blur
	local ok, err = pcall(RENDER[tab] or RENDER.Home, content)
	if not ok then
		warn("[Shop] drawing the " .. tostring(tab) .. " tab failed: " .. tostring(err))
		for _, c in content:GetChildren() do c:Destroy() end
		local ok2, err2 = pcall(RENDER.Home, content)
		if not ok2 then
			warn("[Shop] Home failed too: " .. tostring(err2))
			if ctx and ctx.toast then ctx.toast("The shop hit a problem. Try again in a moment.", "bad") end
			task.defer(Shop.Close)
			return
		end
		tab = "Home"
	end
	if scroll then
		local s = content:FindFirstChildWhichIsA("ScrollingFrame", true)
		if s then s.CanvasPosition = scroll end
	end
end

function Shop.Open(startTab: string?)
	if startTab then tab = startTab end
	if not gui or not gui.Parent or not content then -- (pass 43) never built, or built half-way: build again
		if gui then gui:Destroy() end
		local ok, err = pcall(build)
		if not ok then
			warn("[Shop] building the shop failed: " .. tostring(err))
			if gui then gui:Destroy() gui = nil end
			if ctx and ctx.toast then ctx.toast("The shop hit a problem. Try again in a moment.", "bad") end
			return
		end
	end
	gui.Enabled = true
	local hud = player.PlayerGui:FindFirstChild("LobbyUI")
	if hud then hud.Enabled = false end
	ctx.UITheme.ShowBackdrop("Shop", 1)
	root.Position = UDim2.fromOffset(0, 24)
	root.Visible = true
	tw(root, 0.32, { Position = UDim2.fromOffset(0, 0) })
	Shop.Refresh()
end

function Shop.Close()
	if not gui or not gui.Enabled then return end
	unhover()
	gui.Enabled = false
	local hud = player.PlayerGui:FindFirstChild("LobbyUI")
	if hud then hud.Enabled = true end
	ctx.UITheme.HideBackdrop("Shop")
	if ctx.onClosed then ctx.onClosed() end
end

return Shop
