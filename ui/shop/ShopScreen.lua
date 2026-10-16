-- UIKit/ShopScreen (ModuleScript): the lobby SHOP. RIVALS shop layout (ported from rivals_practice/ui/shop:
-- tab row with icons, wallet top centre, box spotlight that slides between cards, chunky price tags) over
-- tacticals' real content: gear (unlocked in the Kit room), bundles, scissor packs and game passes.
-- All art is live 3D (ViewIcons / the lobby Icons), no flat images. Design px at 1920x1080 -> Kit.toScale.
--   ShopScreen.Init({ Config, Icons, getData, ask, owns, openKit, getSetting, tooltip, onOpen, onClose })
--   ShopScreen.Open(tab?) / Close() / IsOpen() / Refresh() / SetTab(tab)
-- Tabs: Featured, Bundles, Arms, Scissors ("Home" is accepted for Featured).
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local GuiService = game:GetService("GuiService")

local UIKit = script.Parent
local Theme = require(UIKit:WaitForChild("Theme"))
local Kit = require(UIKit:WaitForChild("Kit"))
local ViewIcons = require(UIKit:WaitForChild("ViewIcons"))
local Tac = require(UIKit:WaitForChild("Tac")) -- pass 34 deployment-board look
local C, F, new = Theme.color, Theme.font, Kit.new

local SCISSORS_IMG = "rbxassetid://120480559804238" -- render of the 3D scissors (small price-tag glyph)
local ROBUX_IMG = "rbxasset://textures/ui/common/robux.png"

local Screen = {}
local ctx = {}
local gui, root, blur, scrim, pageHolder, walletText
local tab = "Featured"
local isOpen = false
local tabBtns = {}
local pending, pendingAt = nil, 0

local PAGE_X, PAGE_Y, PAGE_W, PAGE_H = 318, 250, 1284, 800

local function data() return ctx.getData and ctx.getData() or {} end
local function fmtN(n)
	local s = tostring(math.floor(n))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end
local function outlined(l, t)
	new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = t or 2, Transparency = 0.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = l })
	return l
end

-------------------------------------------------------------------------------
-- 3D art
-------------------------------------------------------------------------------
-- an item (gun / gadget / melee) via the lobby Icons module, which knows every item kind
local function itemArt(holder, itemId, hoverTarget)
	local model, view, zoom = ctx.Icons.Item(itemId)
	local vp = ViewIcons.Viewport(holder, model, { view = view, zoom = zoom })
	if hoverTarget then
		hoverTarget.MouseEnter:Connect(function() vp.SetHover(true) end)
		hoverTarget.MouseLeave:Connect(function() vp.SetHover(false) end)
	end
	return vp
end

-------------------------------------------------------------------------------
-- Price tag: amber (scissors) or green (Robux), number with a soft shadow, icon beside it (RIVALS)
-------------------------------------------------------------------------------
local function priceTag(parent, kind, amount, cx, y, w, h, onBuy, key)
	w, h = w or 150, h or 52
	key = key or (kind .. tostring(amount))
	local confirm = pending == key and os.clock() - pendingAt < 3
	local owned = kind == "owned"
	local grad = owned and Theme.gradient.grey or (kind == "robux" and Theme.gradient.robux or Theme.gradient.key)
	local tag = new("TextButton", { Name = "Price", Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(cx, y),
		Size = UDim2.fromOffset(w, h), BackgroundColor3 = C.white, ZIndex = 5, Parent = parent },
		{ Kit.corner(2), Kit.vgrad(confirm and Theme.gradient.robux or grad), Kit.stroke(Color3.new(0, 0, 0), 1.5, 0.6) })
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = tag },
		{ new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local text = owned and "Owned" or confirm and "Confirm" or (kind == "kit" and "Unlock " .. fmtN(amount) or fmtN(amount))
	local ts = math.floor(h * 0.62)
	local num = Kit.label({ LayoutOrder = 2, Text = text, FontFace = F.display, TextSize = ts, TextColor3 = Color3.new(0, 0, 0), TextTransparency = 0.75,
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, h), ZIndex = 6, Parent = row })
	Kit.label({ Name = "Text", Text = text, FontFace = F.display, TextSize = ts, TextColor3 = owned and C.textDark or C.white,
		Position = UDim2.fromOffset(0, -2), Size = UDim2.fromScale(1, 1), ZIndex = 7, Parent = num })
	if not owned and not confirm then
		local img = kind == "robux" and ROBUX_IMG or SCISSORS_IMG
		new("ImageLabel", { LayoutOrder = kind == "robux" and 1 or 3, BackgroundTransparency = 1, Image = img, ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromOffset(math.floor(h * 0.6), math.floor(h * 0.6)), ZIndex = 6, Parent = row })
	end
	if onBuy and not owned then
		Kit.bindButton(tag, { hover = 1.06 })
		tag.Activated:Connect(function()
			-- Robux / Kit: Roblox (or the Kit room) asks for itself. Scissors: click again to confirm.
			if kind == "robux" or kind == "kit" then onBuy() return end
			if pending == key and os.clock() - pendingAt < 3 then
				pending = nil
				onBuy()
			else
				pending, pendingAt = key, os.clock()
				Screen.Refresh()
				task.delay(3.05, function() if pending == key then pending = nil Screen.Refresh() end end)
			end
		end)
	end
	return tag
end

-------------------------------------------------------------------------------
-- Box spotlight (RIVALS): a huge stroke around a hole zeroes in on the hovered card, slides (with a
-- little bounce) to the next card, lets go in the gaps. Settings > Game > Shop Hover = Off disables it.
-------------------------------------------------------------------------------
local function pageSpotlight(pg, grow)
	grow = grow or 1.03
	local spotOn = not (ctx.getSetting and ctx.getSetting("ShopHover") == "Off")
	local hole = new("Frame", { Name = "SpotBox", BackgroundTransparency = 1, Visible = false, ZIndex = 10, Active = false, Size = UDim2.fromOffset(10, 10), Parent = pg }, { Kit.corner(2) })
	pcall(function() hole.Interactable = false end)
	local holeStroke = new("UIStroke", { Color = Color3.new(0, 0, 0), Transparency = 1, Thickness = 1, Parent = hole })
	local function canvasRect(pos, size)
		local cs = pg.AbsoluteCanvasSize
		local origin = pg.AbsolutePosition - pg.CanvasPosition
		return UDim2.fromScale((pos.X - origin.X) / cs.X, (pos.Y - origin.Y) / cs.Y), UDim2.fromScale(size.X / cs.X, size.Y / cs.Y)
	end
	local current
	local function spotTo(card)
		if not spotOn then return end
		holeStroke.Thickness = 4000
		hole:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, 12 * root.AbsoluteSize.Y / 1080)
		if card then
			local m = 8 * root.AbsoluteSize.Y / 1080
			local sc = card:FindFirstChildOfClass("UIScale")
			local sz = card.AbsoluteSize / (sc and sc.Scale or 1) * grow
			local centre = card.AbsolutePosition + card.AbsoluteSize / 2
			local pos, size = canvasRect(centre - sz / 2 - Vector2.new(m, m), sz + Vector2.new(m * 2, m * 2))
			if not hole.Visible or holeStroke.Transparency > 0.95 then
				hole.Position, hole.Size = canvasRect(Vector2.new(0, 0), workspace.CurrentCamera.ViewportSize)
				hole.Visible = true
				Kit.tween(hole, 0.12, { Position = pos, Size = size }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			else
				Kit.tween(hole, 0.3, { Position = pos, Size = size }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			end
			Kit.tween(holeStroke, 0.12, { Transparency = 0.45 })
		else
			local pos, size = canvasRect(Vector2.new(0, 0), workspace.CurrentCamera.ViewportSize)
			Kit.tween(hole, 0.1, { Position = pos, Size = size }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			Kit.tween(holeStroke, 0.1, { Transparency = 1 })
			task.delay(0.1, function() if not current then hole.Visible = false end end)
		end
	end
	local function setHover(card)
		if card == current then return end
		if current and current.Parent then current.ZIndex = 1 end
		current = card
		if card then card.ZIndex = 11 end
		spotTo(card)
	end
	return function(card)
		Kit.bindButton(card, { hover = grow })
		card.MouseEnter:Connect(function() setHover(card) end)
		card.MouseLeave:Connect(function() task.defer(function() if current == card then setHover(nil) end end) end)
	end
end

-------------------------------------------------------------------------------
-- Cards
-------------------------------------------------------------------------------
local function section(pg, text, y)
	outlined(Kit.label({ Text = text, FontFace = F.display, TextSize = 44, Position = UDim2.fromOffset(6, y), Size = UDim2.fromOffset(800, 52), Parent = pg }), 2)
end

-- gear card: rarity backdrop, the item in 3D, name, rarity + slot, price (unlocked in the Kit room)
local function itemCard(pg, hover, id, x, y, w, h)
	local Config = ctx.Config
	local item = Config.Items[id]
	local rar = Config.Rarities[item.Rarity] or Config.Rarities.Standard
	local owned = ctx.owns(id)
	local card = new("TextButton", { Name = id, Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = C.white, ClipsDescendants = true, Parent = pg },
		{ Kit.corner(2), Kit.stroke(rar.Color, 1, 0.75),
			new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.panelRaised, C.panel) }) })
	new("Frame", { Name = "RarityStripe", BackgroundColor3 = rar.Color, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 6), ZIndex = 2, Parent = card })
	-- olive diagonal stripe behind the art
	new("Frame", { BackgroundColor3 = rar.Color, BackgroundTransparency = 0.85, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(w * 0.62, h * 0.35), Size = UDim2.fromOffset(w * 0.3, h * 1.6), Rotation = 24, Parent = card })
	local art = new("Frame", { Name = "Art", BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(w - 20, h - 132), Parent = card })
	itemArt(art, id, card)
	outlined(Kit.label({ Text = item.Name, FontFace = F.display, TextSize = 34, Position = UDim2.fromOffset(16, h - 120), Size = UDim2.fromOffset(w - 32, 40), Parent = card }), 2)
	Kit.label({ Text = string.upper(item.Rarity .. " " .. (Config.SlotNames[item.Slot] or item.Slot)), FontFace = F.bold, TextSize = 18, TextColor3 = rar.Color,
		Position = UDim2.fromOffset(16, h - 82), Size = UDim2.fromOffset(w - 32, 22), Parent = card })
	if owned then
		priceTag(card, "owned", 0, w / 2, h - 58, w - 28, 46)
	else
		priceTag(card, "kit", item.Price, w / 2, h - 58, w - 28, 46, function() ctx.openKit(id) end, "kit:" .. id)
	end
	hover(card)
	Tac.hoverBrackets(card, Tac.brackets(card, Tac.C.line, 20, 3))
	card.Activated:Connect(function() if not owned then ctx.openKit(id) end end)
	if ctx.tooltip then
		ctx.tooltip(card, item.Name, function()
			return (item.Desc or "") .. (owned and "\nYou own this." or `\nUnlock it in the Kit room for {fmtN(item.Price)} scissors.`)
		end)
	end
	return card
end

-- bundle banner: title, tag, its items in 3D tiles, value badge, scissors price
local function bundleCard(pg, hover, bundle, x, y, w, h)
	local Config = ctx.Config
	local cost, missing = Config.BundleCost(bundle, ctx.owns)
	local full = 0
	for _, id in bundle.Items do full += Config.Items[id].Price end
	local col = bundle.Color or C.amber
	local card = new("TextButton", { Name = bundle.Id, Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = C.white, ClipsDescendants = true, Parent = pg },
		{ Kit.corner(2), Kit.stroke(col, 1, 0.75), new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.panelRaised, C.panel) }) })
	new("Frame", { Name = "AccentBar", BackgroundColor3 = col, BorderSizePixel = 0, Size = UDim2.new(0, 8, 1, 0), ZIndex = 2, Parent = card })
	new("Frame", { BackgroundColor3 = col, BackgroundTransparency = 0.82, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(w * 0.75, h / 2), Size = UDim2.fromOffset(w * 0.25, h * 2), Rotation = 22, Parent = card })
	outlined(Kit.label({ Text = bundle.Name, FontFace = F.display, TextSize = 46, Position = UDim2.fromOffset(22, 12), Size = UDim2.fromOffset(w - 40, 56), Parent = card }), 2.5)
	if bundle.Tag then
		new("TextLabel", { BackgroundColor3 = C.amber, Text = bundle.Tag, FontFace = F.display, TextSize = 20, TextColor3 = C.textDark,
			Position = UDim2.fromOffset(24, 70), Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, Parent = card },
			{ Kit.corner(2), Kit.pad(10, 0, 10, 0) })
	end
	local tileW = math.min(120, (w - 300) / math.max(1, #bundle.Items) - 10)
	for j, id in bundle.Items do
		local tile = new("Frame", { Name = "Tile" .. j, BackgroundColor3 = C.panel, BackgroundTransparency = 0.35, Position = UDim2.fromOffset(22 + (j - 1) * (tileW + 10), h - tileW - 24),
			Size = UDim2.fromOffset(tileW, tileW), Parent = card }, { Kit.corner(2), Kit.stroke((Config.Rarities[Config.Items[id].Rarity] or Config.Rarities.Standard).Color, 1.5, 0.3) })
		itemArt(tile, id, card)
		if ctx.owns(id) then
			Kit.label({ Text = "OWNED", FontFace = F.display, TextSize = 16, TextColor3 = C.amber, TextXAlignment = Enum.TextXAlignment.Center,
				AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -2), Size = UDim2.fromOffset(tileW, 20), Parent = tile })
		end
	end
	if full > cost and missing > 0 then
		local value = math.max(2, math.floor(full / math.max(cost, 1) + 0.5))
		new("TextLabel", { BackgroundColor3 = C.red, Text = "x" .. value .. " value", FontFace = F.display, TextSize = 22, TextColor3 = C.white,
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(w - 20, 20), Size = UDim2.fromOffset(0, 34), AutomaticSize = Enum.AutomaticSize.X, Parent = card },
			{ Kit.corner(2), Kit.pad(12, 0, 12, 0) })
	end
	if missing == 0 then
		priceTag(card, "owned", 0, w - 130, h - 82, 220, 58)
	else
		priceTag(card, "scissors", cost, w - 130, h - 82, 220, 58, function() ctx.ask("BuyBundle", bundle.Id) end, "bundle:" .. bundle.Id)
	end
	hover(card)
	Tac.hoverBrackets(card, Tac.brackets(card, Tac.C.line, 20, 3))
	if ctx.tooltip then
		ctx.tooltip(card, bundle.Name, function()
			local names = {}
			for _, id in bundle.Items do table.insert(names, Config.Items[id].Name) end
			return table.concat(names, ", ") .. (missing == 0 and "\nYou own everything in it." or `\n{fmtN(cost)} scissors for the gear you don't have yet.`)
		end)
	end
	return card
end

-------------------------------------------------------------------------------
-- Pages
-------------------------------------------------------------------------------
local function sortedGear()
	local Config = ctx.Config
	local ids = {}
	for id, item in Config.Items do if not item.Default then table.insert(ids, id) end end
	table.sort(ids, function(a, b)
		local ra, rb = Config.Rarities[Config.Items[a].Rarity].Order, Config.Rarities[Config.Items[b].Rarity].Order
		if ra ~= rb then return ra > rb end
		return Config.Items[a].Price > Config.Items[b].Price
	end)
	return ids
end

local function newPage()
	for _, c in pageHolder:GetChildren() do c:Destroy() end
	local pg = new("ScrollingFrame", {
		Name = tab, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = true,
		ScrollBarThickness = 8, ScrollBarImageColor3 = C.olive, ScrollBarImageTransparency = 0.3,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = pageHolder,
	})
	return pg, pageSpotlight(pg)
end

local function gearGrid(pg, hover, ids, y, cols)
	local gap = 18
	local w = (PAGE_W - 16 - gap * (cols - 1)) / cols
	local h = math.floor(w * 1.12)
	for i, id in ids do
		local c, r = (i - 1) % cols, (i - 1) // cols
		itemCard(pg, hover, id, 4 + c * (w + gap), y + r * (h + gap), w, h)
	end
	return y + math.ceil(#ids / cols) * (h + gap)
end

local RENDER = {}

function RENDER.Featured()
	local Config = ctx.Config
	local pg, hover = newPage()
	-- featured Robux bundle (big) + scissors call-out
	local featured
	for _, p in Config.RobuxProducts do if p.Bundle then featured = p end end
	local y = 6
	-- (UI session 2026-10-16) RIVALS' home: the big featured slot is a carousel with clickable dots bottom left
	local carousel = new("Frame", { Name = "Carousel", BackgroundTransparency = 1, Position = UDim2.fromOffset(4, y), Size = UDim2.fromOffset(820, 320), Parent = pg })
	local slides = {}
	if featured then
		local w, h = 820, 320
		local card = new("TextButton", { Name = "Featured", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(w, h),
			BackgroundColor3 = C.white, ClipsDescendants = true, Parent = carousel },
			{ Kit.corner(2), Kit.stroke(C.amber, 2, 0.25), new("UIGradient", { Rotation = 0, Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, C.olive:Lerp(C.panel, 0.3)), ColorSequenceKeypoint.new(0.6, C.panel), ColorSequenceKeypoint.new(1, C.amber:Lerp(C.panel, 0.6)) }) }) })
		outlined(Kit.label({ Text = featured.Name, FontFace = F.display, TextSize = 52, Position = UDim2.fromOffset(24, 14), Size = UDim2.fromOffset(w - 48, 62), Parent = card }), 2.5)
		if featured.Tag then
			new("TextLabel", { BackgroundColor3 = C.red, Text = featured.Tag, FontFace = F.display, TextSize = 20, TextColor3 = C.white,
				Position = UDim2.fromOffset(26, 78), Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, Parent = card }, { Kit.corner(2), Kit.pad(10, 0, 10, 0) })
		end
		local x = 24
		for j, id in featured.Items or {} do
			local tile = new("Frame", { Name = "Tile" .. j, BackgroundColor3 = C.panel, BackgroundTransparency = 0.3, Position = UDim2.fromOffset(x, 122), Size = UDim2.fromOffset(150, 150), Parent = card },
				{ Kit.corner(2), Kit.stroke(C.olive, 1.5, 0.3) })
			itemArt(tile, id, card)
			x += 162
		end
		local sc = new("Frame", { Name = "Scissors", BackgroundColor3 = C.panel, BackgroundTransparency = 0.3, Position = UDim2.fromOffset(x, 122), Size = UDim2.fromOffset(150, 150), Parent = card },
			{ Kit.corner(2), Kit.stroke(C.amber, 1.5, 0.3) })
		local art = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(150, 110), Parent = sc })
		ViewIcons.Icon(art, "Scissors", { hoverTarget = card })
		outlined(Kit.label({ Text = "+" .. fmtN(featured.Credits or 0), FontFace = F.display, TextSize = 30, TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, 108), Size = UDim2.fromOffset(150, 38), Parent = sc }), 2)
		local ownedAll = true
		for _, id in featured.Items or {} do if not ctx.owns(id) then ownedAll = false end end
		if ownedAll then priceTag(card, "owned", 0, w - 130, 22, 220, 58)
		else priceTag(card, "robux", featured.Robux, w - 130, 22, 220, 58, function() ctx.ask("BuyRobux", featured.Key) end) end
		hover(card)
	Tac.hoverBrackets(card, Tac.brackets(card, Tac.C.line, 20, 3))
		table.insert(slides, card)
	end
	-- slide: the best gear you don't own yet, big
	do
		local spot
		for _, id in sortedGear() do if not ctx.owns(id) then spot = id break end end
		if spot then
			local item = Config.Items[spot]
			local rar = Config.Rarities[item.Rarity] or Config.Rarities.Standard
			local w, h = 820, 320
			local card = new("TextButton", { Name = "Spotlight", Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(w, h), BackgroundColor3 = C.white,
				ClipsDescendants = true, Visible = false, Parent = carousel },
				{ Kit.corner(2), new("UIGradient", { Rotation = 0, Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, C.panel), ColorSequenceKeypoint.new(0.55, C.panel), ColorSequenceKeypoint.new(1, rar.Color:Lerp(C.panel, 0.55)) }) }) })
			new("Frame", { BackgroundColor3 = rar.Color, BackgroundTransparency = 0.8, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(w * 0.68, h / 2), Size = UDim2.fromOffset(w * 0.22, h * 2), Rotation = 22, Parent = card })
			Kit.label({ Text = "FEATURED GEAR", FontFace = F.display, TextSize = 22, TextColor3 = rar.Color, Position = UDim2.fromOffset(24, 18), Size = UDim2.fromOffset(400, 28), Parent = card })
			outlined(Kit.label({ Text = item.Name, FontFace = F.display, TextSize = 56, Position = UDim2.fromOffset(24, 44), Size = UDim2.fromOffset(420, 66), Parent = card }), 2.5)
			Kit.label({ Text = string.upper(item.Rarity .. " " .. (Config.SlotNames[item.Slot] or item.Slot)), FontFace = F.bold, TextSize = 20, TextColor3 = rar.Color,
				Position = UDim2.fromOffset(26, 112), Size = UDim2.fromOffset(400, 24), Parent = card })
			Kit.label({ Text = item.Desc or "", FontFace = F.medium, TextSize = 20, TextColor3 = C.textDim, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
				Position = UDim2.fromOffset(26, 144), Size = UDim2.fromOffset(380, 80), Parent = card })
			local art = new("Frame", { Name = "Art", BackgroundTransparency = 1, Position = UDim2.fromOffset(400, 10), Size = UDim2.fromOffset(410, 250), Parent = card })
			itemArt(art, spot, card)
			priceTag(card, "kit", item.Price, 150, h - 64, 250, 56, function() ctx.openKit(spot) end, "kit:" .. spot)
			hover(card)
			Tac.hoverBrackets(card, Tac.brackets(card, rar.Color, 20, 3))
			card.Activated:Connect(function() ctx.openKit(spot) end)
			table.insert(slides, card)
		end
	end
	-- slides: the passes you don't have
	do
		local d = data()
		for _, gp in Config.GamePasses do
			if not (d.Passes and d.Passes[gp.Key]) then
				local w, h = 820, 320
				local card = new("TextButton", { Name = "Pass_" .. gp.Key, Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(w, h), BackgroundColor3 = C.white,
					ClipsDescendants = true, Visible = false, Parent = carousel },
					{ Kit.corner(2), new("UIGradient", { Rotation = 0, Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, C.amber:Lerp(C.panel, 0.55)), ColorSequenceKeypoint.new(0.5, C.panel), ColorSequenceKeypoint.new(1, C.panel) }) }) })
				local art = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 20), Size = UDim2.fromOffset(300, 280), Parent = card })
				ViewIcons.Icon(art, "Medal", { hoverTarget = card, zoom = 1.1 })
				Kit.label({ Text = "GAME PASS", FontFace = F.display, TextSize = 22, TextColor3 = C.amber, Position = UDim2.fromOffset(330, 26), Size = UDim2.fromOffset(300, 28), Parent = card })
				outlined(Kit.label({ Text = gp.Name, FontFace = F.display, TextSize = 60, Position = UDim2.fromOffset(330, 52), Size = UDim2.fromOffset(470, 70), Parent = card }), 2.5)
				Kit.label({ Text = gp.Desc or "", FontFace = F.medium, TextSize = 22, TextColor3 = C.textDim, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
					Position = UDim2.fromOffset(332, 130), Size = UDim2.fromOffset(460, 90), Parent = card })
				priceTag(card, "robux", gp.Robux, 450, h - 64, 240, 56, function() ctx.ask("BuyPass", gp.Key) end)
				hover(card)
				Tac.hoverBrackets(card, Tac.brackets(card, C.amber, 20, 3))
				table.insert(slides, card)
			end
		end
	end
	-- dots (bottom left, clickable) + auto-advance every 6 s (paused while the pointer is on the carousel)
	if #slides > 1 then
		local dots = new("Frame", { Name = "Dots", BackgroundTransparency = 1, Position = UDim2.fromOffset(24, 320 - 26), Size = UDim2.fromOffset(#slides * 34, 14), ZIndex = 20, Parent = carousel })
		local dotList, current, paused = {}, 1, false
		local bases = {}
		local function show(i, instant)
			if i == current and not instant then return end
			current = i
			for k, sl in slides do
				sl.Visible = k == i
				if k == i and not instant then
					bases[k] = bases[k] or sl.Position
					local b = bases[k]
					sl.Position = b + UDim2.fromScale(0.04, 0)
					Kit.tween(sl, 0.28, { Position = b }, Enum.EasingStyle.Quint)
				end
			end
			for k, dt in dotList do
				Kit.tween(dt, 0.18, { BackgroundTransparency = k == i and 0 or 0.6, Size = UDim2.fromScale(k == i and 26 / (#slides * 34) or 12 / (#slides * 34), 12 / 14) })
			end
		end
		for k = 1, #slides do
			local dt = new("TextButton", { Name = "Dot" .. k, Text = "", AutoButtonColor = false, BackgroundColor3 = C.white, BackgroundTransparency = k == 1 and 0 or 0.6,
				AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset((k - 1) * 34, 7), Size = UDim2.fromOffset(k == 1 and 26 or 12, 12), ZIndex = 21, Parent = dots },
				{ new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
			dt.Activated:Connect(function() show(k) end)
			table.insert(dotList, dt)
		end
		for _, sl in slides do
			sl.MouseEnter:Connect(function() paused = true end)
			sl.MouseLeave:Connect(function() paused = false end)
		end
		task.spawn(function()
			while carousel.Parent do
				task.wait(6)
				if not carousel.Parent then break end
				if not paused and isOpen then show(current % #slides + 1) end
			end
		end)
	end
	do -- scissors call-out
		local w, h = PAGE_W - 16 - 820 - 18, 320
		local card = new("TextButton", { Name = "GetScissors", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(4 + 820 + 18, y), Size = UDim2.fromOffset(w, h),
			BackgroundColor3 = C.white, ClipsDescendants = true, Parent = pg },
			{ Kit.corner(2), Kit.stroke(C.olive, 2, 0.3), new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.panelRaised, C.panel) }) })
		local art = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 6), Size = UDim2.fromOffset(w - 40, 170), Parent = card })
		ViewIcons.Icon(art, "Scissors", { hoverTarget = card, zoom = 1.15 })
		outlined(Kit.label({ Text = "Scissors", FontFace = F.display, TextSize = 44, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 172), Size = UDim2.fromOffset(w, 50), Parent = card }), 2)
		Kit.label({ Text = "Cut the tape on new gear in the Kit room", FontFace = F.medium, TextSize = 20, TextColor3 = C.textDim, TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(10, 220), Size = UDim2.fromOffset(w - 20, 26), Parent = card })
		local b = Kit.button("key", UDim2.fromOffset(w - 60, 52), "Get scissors")
		b.Position = UDim2.fromOffset(30, h - 66)
		b.Parent = card
		b.Activated:Connect(function() Screen.SetTab("Scissors") end)
		hover(card)
	Tac.hoverBrackets(card, Tac.brackets(card, Tac.C.line, 20, 3))
		card.Activated:Connect(function() Screen.SetTab("Scissors") end)
	end
	y += 320 + 30
	local ids = sortedGear()
	local top, more = {}, {}
	for i, id in ids do if i <= 4 then table.insert(top, id) elseif i <= 8 then table.insert(more, id) end end
	section(pg, "Top gear", y)
	y = gearGrid(pg, hover, top, y + 60, 4) + 12
	if #more > 0 then
		section(pg, "More gear", y)
		y = gearGrid(pg, hover, more, y + 60, 4)
	end
	new("Frame", { Name = "End", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(10, 40), Parent = pg })
end

function RENDER.Bundles()
	local pg, hover = newPage()
	local bundles = ctx.Config.Bundles
	local y = 6
	if bundles[1] then
		bundleCard(pg, hover, bundles[1], 4, y, PAGE_W - 16, 330)
		y += 330 + 20
	end
	local w = (PAGE_W - 16 - 20) / 2
	for i = 2, #bundles do
		local c, r = (i - 2) % 2, (i - 2) // 2
		bundleCard(pg, hover, bundles[i], 4 + c * (w + 20), y + r * (290 + 20), w, 290)
	end
	y += math.ceil((#bundles - 1) / 2) * 310
	new("Frame", { Name = "End", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(10, 40), Parent = pg })
end

function RENDER.Arms()
	local pg, hover = newPage()
	local y = gearGrid(pg, hover, sortedGear(), 6, 4)
	new("Frame", { Name = "End", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(10, 40), Parent = pg })
end

function RENDER.Scissors()
	local Config = ctx.Config
	local pg, hover = newPage()
	section(pg, "Scissor packs", 0)
	local packs = {}
	for _, p in Config.RobuxProducts do if not p.Bundle then table.insert(packs, p) end end
	local gap, w, h = 18, 0, 330
	w = (PAGE_W - 16 - gap * 3) / 4
	for i, p in packs do
		local x = 4 + ((i - 1) % 4) * (w + gap)
		local y = 60 + ((i - 1) // 4) * (h + gap)
		local card = new("TextButton", { Name = p.Key, Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
			BackgroundColor3 = C.white, ClipsDescendants = true, Parent = pg },
			{ Kit.corner(2), Kit.stroke(C.amber, 2, 0.35), new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.panelRaised, C.panel) }) })
		new("Frame", { Name = "AccentStripe", BackgroundColor3 = C.olive, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 6), ZIndex = 2, Parent = card })
		-- a pile of scissors in 3D: more for bigger packs
		local n = math.clamp(i, 1, 4)
		for k = 1, n do
			local hold = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(w / 2 + (k - (n + 1) / 2) * 34, 130 + (k % 2) * 8), Size = UDim2.fromOffset(130, 130), Parent = card })
			ViewIcons.Viewport(hold, ViewIcons.Scissors(), { view = CFrame.Angles(0, 0, math.rad((k - (n + 1) / 2) * 25)) * ViewIcons.Views.Scissors[1], zoom = 1 })
		end
		outlined(Kit.label({ Text = p.Name, FontFace = F.display, TextSize = 30, TextColor3 = C.text, Position = UDim2.fromOffset(18, 12), Size = UDim2.fromOffset(w - 36, 36), Parent = card }), 2)
		outlined(Kit.label({ Text = "+" .. fmtN(p.Credits or 0), FontFace = F.display, TextSize = 52, Position = UDim2.fromOffset(18, h - 140), Size = UDim2.fromOffset(w - 36, 60), Parent = card }), 2.5)
		if p.Tag then
			new("TextLabel", { BackgroundColor3 = C.red, Text = p.Tag, FontFace = F.display, TextSize = 18, TextColor3 = C.white, AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromOffset(w - 12, 14), Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X, Parent = card }, { Kit.corner(2), Kit.pad(8, 0, 8, 0) })
		end
		priceTag(card, "robux", p.Robux, w / 2, h - 70, w - 30, 56, function() ctx.ask("BuyRobux", p.Key) end)
		hover(card)
	Tac.hoverBrackets(card, Tac.brackets(card, Tac.C.line, 20, 3))
		card.Activated:Connect(function() ctx.ask("BuyRobux", p.Key) end)
	end
	local y = 60 + math.ceil(#packs / 4) * (h + gap) + 12
	section(pg, "Passes", y)
	y += 60
	local d = data()
	local pw = (PAGE_W - 16 - 20) / 2
	for i, p in Config.GamePasses do
		local have = d.Passes and d.Passes[p.Key]
		local x = 4 + ((i - 1) % 2) * (pw + 20)
		local yy = y + ((i - 1) // 2) * 170
		local card = new("TextButton", { Name = p.Key, Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(x, yy), Size = UDim2.fromOffset(pw, 150),
			BackgroundColor3 = C.panelRaised, BackgroundTransparency = 0.15, Parent = pg }, { Kit.corner(2), Kit.stroke(have and C.amber or C.olive, 2, 0.35) })
		local art = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(130, 130), Parent = card })
		ViewIcons.Icon(art, "Medal", { hoverTarget = card })
		outlined(Kit.label({ Text = p.Name, FontFace = F.display, TextSize = 36, Position = UDim2.fromOffset(150, 14), Size = UDim2.fromOffset(pw - 400, 44), Parent = card }), 2)
		Kit.label({ Text = p.Desc or "", FontFace = F.medium, TextSize = 20, TextColor3 = C.textDim, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(150, 60), Size = UDim2.fromOffset(pw - 400, 80), Parent = card })
		if have then priceTag(card, "owned", 0, pw - 125, 47, 210, 56)
		else priceTag(card, "robux", p.Robux, pw - 125, 47, 210, 56, function() ctx.ask("BuyPass", p.Key) end) end
		hover(card)
	Tac.hoverBrackets(card, Tac.brackets(card, Tac.C.line, 20, 3))
	end
	y += math.ceil(#Config.GamePasses / 2) * 170
	new("Frame", { Name = "End", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(10, 40), Parent = pg })
end

-------------------------------------------------------------------------------
-- Frame
-------------------------------------------------------------------------------
local TABS = { { "Featured", "Medal" }, { "Bundles", "Crate" }, { "Arms", "Weapon" }, { "Scissors", "Scissors" } }

local function build()
	gui = new("ScreenGui", { Name = "ShopUI2", IgnoreGuiInset = true, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 25, Enabled = false, Parent = Players.LocalPlayer:WaitForChild("PlayerGui") })
	gui:SetAttribute("NoStyle", true)
	blur = Lighting:FindFirstChild("MenuUIBlur") or new("BlurEffect", { Name = "MenuUIBlur", Size = 0, Parent = Lighting })
	scrim = new("Frame", { Name = "Scrim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.scrim, BackgroundTransparency = 1, Parent = gui })
	local canvas = Kit.canvas(gui)
	root = new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = canvas })

	-- tab row: dark tabs, the selected one light; a 3D icon pops out over each tab (RIVALS)
	for i, t in TABS do
		local b = new("TextButton", { Name = t[1], Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(PAGE_X + (i - 1) * 176, 170), Size = UDim2.fromOffset(164, 56),
			BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, Parent = root }, { Kit.corner(2) })
		local hold = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(82, 30), Size = UDim2.fromOffset(78, 64), ZIndex = 2, Parent = b })
		if t[2] == "Weapon" then
			local vp = ViewIcons.Viewport(hold, ViewIcons.Weapon("AutoRifle"), { view = ViewIcons.GunView, zoom = 0.95 })
			b.MouseEnter:Connect(function() vp.SetHover(true) end)
			b.MouseLeave:Connect(function() vp.SetHover(false) end)
		else
			ViewIcons.Icon(hold, t[2], { hoverTarget = b })
		end
		local l = outlined(Kit.label({ Name = "Label", Text = t[1], FontFace = F.display, TextSize = 30, TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 34), ZIndex = 3, Parent = b }), 2.5)
		Kit.bindButton(b, { hover = 1.05 })
		b.Activated:Connect(function() Screen.SetTab(t[1]) end)
		tabBtns[t[1]] = { b = b, l = l }
	end
	local close = Kit.closeButton(UDim2.fromOffset(86, 52))
	close.Position = UDim2.fromOffset(PAGE_X + PAGE_W - 86, 172)
	close.Parent = root
	close.Activated:Connect(function() Screen.Close() end)

	-- wallet (top centre): scissors + count + amber plus
	local wallet = new("Frame", { Name = "Wallet", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(960, 52), Size = UDim2.fromOffset(330, 70), Parent = root })
	local wIcon = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, -6), Size = UDim2.fromOffset(84, 84), ZIndex = 3, Parent = wallet })
	ViewIcons.Icon(wIcon, "Scissors", { zoom = 1.1 })
	local pill = new("Frame", { Position = UDim2.fromOffset(70, 14), Size = UDim2.fromOffset(190, 46), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Parent = wallet }, { Kit.corner(2) })
	walletText = Kit.label({ Text = "0", FontFace = F.display, TextSize = 36, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(170, 46), Parent = pill })
	local plus = new("TextButton", { Name = "AddScissors", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(268, 17), Size = UDim2.fromOffset(40, 40), BackgroundColor3 = C.white, Parent = wallet },
		{ Kit.corner(2), Kit.vgrad(Theme.gradient.key) })
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(22, 7), BackgroundColor3 = C.white, Parent = plus }, { Kit.corner(2) })
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(7, 22), BackgroundColor3 = C.white, Parent = plus }, { Kit.corner(2) })
	Kit.bindButton(plus, { hover = 1.12 })
	plus.Activated:Connect(function() Screen.SetTab("Scissors") end)

	pageHolder = new("Frame", { Name = "Pages", BackgroundTransparency = 1, Position = UDim2.fromOffset(PAGE_X, PAGE_Y), Size = UDim2.fromOffset(PAGE_W, PAGE_H), Parent = root })
	Kit.toScale(root)
	root.Visible = false

	GuiService.MenuOpened:Connect(function() if isOpen then root.Visible = false end end)
	GuiService.MenuClosed:Connect(function() if isOpen then Kit.open(root) end end)
end

function Screen.Refresh()
	if not gui or not isOpen then return end
	local d = data()
	walletText.Text = fmtN(d.Credits or 0)
	for name, t in tabBtns do
		local on = name == tab
		t.b.BackgroundColor3 = on and C.white or Color3.new(0, 0, 0)
		t.b.BackgroundTransparency = on and 0 or 0.35
		t.l.TextColor3 = on and C.textDark or C.text
		local st = t.l:FindFirstChildOfClass("UIStroke")
		if st then st.Enabled = not on end
	end
	local keep = pageHolder:FindFirstChildWhichIsA("ScrollingFrame")
	local scroll = keep and keep.Name == tab and keep.CanvasPosition
	RENDER[tab]()
	Kit.toScale(pageHolder, Vector2.new(PAGE_W, PAGE_H))
	if scroll then
		local s = pageHolder:FindFirstChildWhichIsA("ScrollingFrame")
		if s then task.defer(function() s.CanvasPosition = scroll end) end
	end
end

function Screen.SetTab(t)
	if t == "Home" then t = "Featured" end
	if not RENDER[t] then t = "Featured" end
	tab = t
	pending = nil
	Screen.Refresh()
end

local function setOpen(on)
	if on == isOpen then return end
	isOpen = on
	Kit.tween(blur, 0.25, { Size = on and Theme.blur or 0 })
	Kit.tween(scrim, 0.25, { BackgroundTransparency = on and Theme.alpha.scrim or 1 })
	if on then
		gui.Enabled = true
		if ctx.onOpen then ctx.onOpen() end
		Screen.Refresh()
		Kit.open(root)
	else
		Kit.close(root, function() if not isOpen then gui.Enabled = false end end)
		if ctx.onClose then ctx.onClose() end
	end
end

function Screen.Init(context)
	ctx = context or {}
	if not gui then build() end
end
function Screen.Open(startTab)
	if startTab then
		tab = startTab == "Home" and "Featured" or startTab
		if not RENDER[tab] then tab = "Featured" end
	end
	if isOpen then Screen.Refresh() else setOpen(true) end
end
function Screen.Close() if gui then setOpen(false) end end
function Screen.IsOpen() return isOpen end

return Screen
