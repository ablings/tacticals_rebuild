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
	-- (lobby revamp Phase B, Edward OK: no white pills / neon lime) scissors prices = a dark plate with cream words; Robux = field green
	local STEEL = { Theme.hex("#30342B"), Theme.hex("#171913") }
	local steel = not owned and kind ~= "robux" and not confirm
	local grad = owned and Theme.gradient.grey or (kind == "robux" and Theme.gradient.robux or STEEL)
	local tag = new("TextButton", { Name = "Price", Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(cx, y),
		Size = UDim2.fromOffset(w, h), BackgroundColor3 = C.white, ZIndex = 5, Parent = parent },
		{ Kit.corner(7), Kit.vgrad(confirm and Theme.gradient.robux or grad), steel and Kit.stroke(Theme.hex("#E2D2AC"), 1.5, 0.45) or Kit.stroke(Color3.new(0, 0, 0), 1.5, 0.6) })
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = tag },
		{ new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local text = owned and "Owned" or confirm and "Confirm" or fmtN(amount) -- (lobby revamp: no "Unlock" word, it spilled in Montserrat)
	local ts = math.floor(h * 0.62)
	local num = Kit.label({ LayoutOrder = 2, Text = text, FontFace = F.display, TextSize = ts, TextColor3 = Color3.new(0, 0, 0), TextTransparency = 0.75,
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, h), ZIndex = 6, Parent = row })
	-- (lobby revamp, graders: a 4,000 tag looked the same with 500 in the wallet) can't afford = the number goes red and the
	-- tag dims; it still opens the Kit / confirm so you can see what it is
	local short = (kind == "scissors" or kind == "kit") and not owned and amount and (data().Credits or 0) < amount
	Kit.label({ Name = "Text", Text = text, FontFace = F.display, TextSize = ts, TextColor3 = short and Theme.hex("#FF6A5E") or (owned and Theme.hex("#1C2026") or (steel and Theme.hex("#ECE6D2") or C.white)),
		Position = UDim2.fromOffset(0, -2), Size = UDim2.fromScale(1, 1), ZIndex = 7, Parent = num })
	if short then
		new("Frame", { Name = "Short", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.6, ZIndex = 5, Parent = tag },
			{ Kit.corner(7) })
	end
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
		BackgroundColor3 = C.white, ClipsDescendants = false, Parent = pg },
		{ Kit.corner(2), Kit.stroke(rar.Color, 1, 0.75),
			new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.panelRaised, C.panel) }) })
	-- (2026-10-21, Edward: the lobby should feel alive like RIVALS) the card's own decor stays clipped to it; the 3D item breaks
	-- out over its top edge and tilts / grows on hover (RIVALS' shop tiles)
	local clip = new("Frame", { Name = "Clip", BackgroundTransparency = 1, ClipsDescendants = true, Size = UDim2.fromOffset(w, h), Parent = card }, { Kit.corner(2) })
	new("Frame", { Name = "RarityStripe", BackgroundColor3 = rar.Color, BorderSizePixel = 0, Size = UDim2.fromOffset(w, 6), ZIndex = 2, Parent = clip })
	-- olive diagonal stripe behind the art
	new("Frame", { BackgroundColor3 = rar.Color, BackgroundTransparency = 0.85, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(w * 0.62, h * 0.35), Size = UDim2.fromOffset(w * 0.3, h * 1.6), Rotation = 24, Parent = clip })
	local art = new("Frame", { Name = "Art", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(w / 2, (h - 112) / 2 - 14),
		Size = UDim2.fromOffset(w + 10, h - 96), ZIndex = 3, Parent = card })
	itemArt(art, id, card)
	local artScale = new("UIScale", { Parent = art })
	card.MouseEnter:Connect(function()
		Kit.tween(artScale, 0.18, { Scale = 1.08 }, Enum.EasingStyle.Back)
		Kit.tween(art, 0.18, { Rotation = -4 }, Enum.EasingStyle.Back)
	end)
	card.MouseLeave:Connect(function()
		Kit.tween(artScale, 0.18, { Scale = 1 })
		Kit.tween(art, 0.18, { Rotation = 0 })
	end)
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
	if y < 26 then y = 26 end -- (2026-10-21) headroom: the items break out over their cards' top edge
	local w = (PAGE_W - 16 - gap * (cols - 1)) / cols
	local h = math.floor(w * 1.12)
	for i, id in ids do
		local c, r = (i - 1) % cols, (i - 1) // cols
		itemCard(pg, hover, id, 4 + c * (w + gap), y + r * (h + gap), w, h)
	end
	return y + math.ceil(#ids / cols) * (h + gap)
end

local RENDER = {}

-- Home (UI session 2026-10-16, remade on RIVALS' Shop Home, ref_35 / the replica): floating items over their price
-- buttons (no cards), a big hero card, an offer panel that pages with a dot bar under it, and a grid of gear tiles.
-- Everything is a live 3D render.
function RENDER.Featured()
	local Config = ctx.Config
	local pg, hover = newPage()
	local d = data()
	local function float(x, y, w, h, onClick)
		local hold = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), Parent = pg })
		Kit.bindButton(hold, { hover = 1.08 })
		if onClick then hold.Activated:Connect(onClick) end
		return hold
	end
	-- left, top: scissors packs for Robux (the 3D scissors grow with the pack)
	local packs = {}
	for _, pr in Config.RobuxProducts do if pr.Credits and not pr.Bundle then table.insert(packs, pr) end end
	for i = 1, math.min(3, #packs) do
		local pr = packs[i]
		local hold = float(4 + (i - 1) * 166, 10, 158, 152, function() ctx.ask("BuyRobux", pr.Key) end)
		local n = math.min(i + 1, 4)
		for k = 1, n do
			local art = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(4 + (k - 1) * 10, (k - 1) * 4), Size = UDim2.fromOffset(150 - (n - 1) * 10, 100), Parent = hold })
			ViewIcons.Viewport(art, ViewIcons.Scissors(), { view = CFrame.Angles(0, 0, math.rad((k - (n + 1) / 2) * 22)) * ViewIcons.Views.Scissors[1], zoom = 1, still = true })
		end
		outlined(Kit.label({ Text = "+" .. fmtN(pr.Credits), FontFace = F.display, TextSize = 26, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 74), Size = UDim2.fromOffset(158, 30), ZIndex = 3, Parent = hold }), 2)
		priceTag(hold, "robux", pr.Robux, 79, 104, 116, 46, function() ctx.ask("BuyRobux", pr.Key) end)
	end
	-- left, bottom: gear you don't have, floating over its steel price
	local gear = {}
	for _, id in sortedGear() do if not ctx.owns(id) then table.insert(gear, id) end end
	for i = 1, math.min(3, #gear) do
		local id = gear[i]
		local hold = float(4 + (i - 1) * 166, 176, 158, 152, function() ctx.openKit(id) end)
		local art = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(-14, -16), Size = UDim2.fromOffset(186, 124), Parent = hold })
		itemArt(art, id, hold)
		priceTag(hold, "kit", Config.Items[id].Price, 79, 104, 154, 46, function() ctx.openKit(id) end, "kit:" .. id)
	end

	-- right: hero card (the Founder's Bundle): its items fanned out large, the title, a blue-steel view button
	local featured
	for _, pr in Config.RobuxProducts do if pr.Bundle then featured = pr end end
	if featured then
		local w, h = 750, 320
		local card = new("TextButton", { Name = "Hero", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(520, 8), Size = UDim2.fromOffset(w, h),
			BackgroundColor3 = C.white, ClipsDescendants = true, Parent = pg },
			{ Kit.corner(8), new("UIGradient", { Rotation = 35, Color = ColorSequence.new(Theme.hex("#AEB49C"), Theme.hex("#2E3328")) }) })
		local items = featured.Items or {}
		for j, id in items do
			local art = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(w * 0.5 + (j - (#items + 1) / 2) * 170, h * 0.56), Size = UDim2.fromOffset(240, 220), Parent = card })
			itemArt(art, id, card)
		end
		local sc = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(w - 250, 6), Size = UDim2.fromOffset(150, 110), Parent = card })
		ViewIcons.Icon(sc, "Scissors", { hoverTarget = card })
		outlined(Kit.label({ Text = featured.Name, FontFace = F.display, TextSize = 46, Position = UDim2.fromOffset(28, 16), Size = UDim2.fromOffset(500, 56), ZIndex = 5, Parent = card }), 2.5)
		if featured.Tag then
			new("TextLabel", { BackgroundColor3 = C.red, Text = featured.Tag, FontFace = F.display, TextSize = 20, TextColor3 = C.white, ZIndex = 5,
				Position = UDim2.fromOffset(30, 74), Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, Parent = card }, { Kit.corner(4), Kit.pad(10, 0, 10, 0) })
		end
		outlined(Kit.label({ Text = "+" .. fmtN(featured.Credits or 0) .. " scissors", FontFace = F.display, TextSize = 24, Position = UDim2.fromOffset(30, 108), Size = UDim2.fromOffset(300, 28), ZIndex = 5, Parent = card }), 2)
		local ownedAll = true
		for _, id in items do if not ctx.owns(id) then ownedAll = false end end
		if ownedAll then priceTag(card, "owned", 0, w - 105, h - 76, 170, 58)
		else priceTag(card, "robux", featured.Robux, w - 105, h - 76, 170, 58, function() ctx.ask("BuyRobux", featured.Key) end) end
		hover(card)
		Kit.bindButton(card, { hover = 1.03, press = 0.99 })
		card.Activated:Connect(function() Screen.SetTab("Bundles") end)
	end

	-- bottom left: the offer panel; its pages swap with the dot bar under it (RIVALS' Special Offer)
	local offers = {}
	for _, gp in Config.GamePasses do if not (d.Passes and d.Passes[gp.Key]) then table.insert(offers, { kind = "pass", p = gp }) end end
	for _, bd in Config.Bundles or {} do table.insert(offers, { kind = "bundle", b = bd }) end
	local so = new("Frame", { Name = "Offer", Position = UDim2.fromOffset(4, 352), Size = UDim2.fromOffset(746, 324), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.25, ClipsDescendants = true, Parent = pg }, { Kit.corner(10) })
	local slides = {}
	for i, of in offers do
		local sl = new("Frame", { Name = "Slide" .. i, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = i == 1, Parent = so })
		if of.kind == "pass" then
			local gp = of.p
			outlined(Kit.label({ Text = gp.Name, FontFace = F.display, TextSize = 52, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 58), Parent = sl }), 2)
			Kit.label({ Text = gp.Desc or "", FontFace = F.medium, TextSize = 22, TextColor3 = Theme.hex("#CFCDD3"), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true,
				Position = UDim2.fromOffset(60, 66), Size = UDim2.new(1, -120, 0, 56), Parent = sl })
			local art = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(373, 120), Size = UDim2.fromOffset(150, 120), Parent = sl })
			ViewIcons.Icon(art, "Medal", { hoverTarget = so })
			priceTag(sl, "robux", gp.Robux, 373, 246, 170, 56, function() ctx.ask("BuyPass", gp.Key) end)
		else
			local bd = of.b
			local cost, missing = Config.BundleCost(bd, ctx.owns)
			outlined(Kit.label({ Text = bd.Name, FontFace = F.display, TextSize = 46, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 12), Size = UDim2.new(1, 0, 0, 54), Parent = sl }), 2)
			local n = #bd.Items
			for j, id in bd.Items do
				local tile = new("Frame", { BackgroundColor3 = C.panel, BackgroundTransparency = 0.3, Position = UDim2.fromOffset(373 + (j - (n + 1) / 2) * 128 - 55, 84), Size = UDim2.fromOffset(110, 110), Parent = sl },
					{ Kit.corner(8), Kit.stroke((Config.Rarities[Config.Items[id].Rarity] or Config.Rarities.Standard).Color, 2, 0.2) })
				itemArt(tile, id, so)
			end
			if missing == 0 then priceTag(sl, "owned", 0, 373, 230, 190, 56)
			else priceTag(sl, "scissors", cost, 373, 230, 190, 56, function() ctx.ask("BuyBundle", bd.Id) end, "bundle:" .. bd.Id) end
		end
		table.insert(slides, sl)
	end
	if #slides > 1 then
		local DOT, GAP = 14, 26
		local dotsW = #slides * GAP + 22
		local dots = new("Frame", { Name = "Dots", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(377, 690), Size = UDim2.fromOffset(dotsW, 28),
			BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, Parent = pg }, { Kit.corner(14) })
		local dl, cur, paused = {}, 1, false
		local function show(i)
			if i == cur then return end
			cur = i
			for k, sl in slides do sl.Visible = k == i end
			for k, dt in dl do Kit.tween(dt, 0.15, { BackgroundTransparency = k == i and 0 or 0.65 }) end
		end
		for k = 1, #slides do
			local dt = new("TextButton", { Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(11 + (k - 0.5) * GAP, 14), Size = UDim2.fromOffset(DOT, DOT),
				BackgroundColor3 = C.white, BackgroundTransparency = k == 1 and 0 or 0.65, Parent = dots }, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
			Kit.bindButton(dt, { hover = 1.35 })
			dt.Activated:Connect(function() show(k) end)
			table.insert(dl, dt)
		end
		so.MouseEnter:Connect(function() paused = true end)
		so.MouseLeave:Connect(function() paused = false end)
		task.spawn(function()
			while so.Parent do
				task.wait(6)
				if so.Parent and isOpen and not paused then show(cur % #slides + 1) end
			end
		end)
	end

	-- bottom right: gear tiles in their rarity colour, floating over steel prices (2 x 3)
	local rest = {}
	for i = 4, #gear do table.insert(rest, gear[i]) end
	if #rest < 6 then for _, id in sortedGear() do if #rest >= 6 then break end; if not table.find(rest, id) and not table.find(gear, id, 1) then table.insert(rest, id) end end end
	for i = 1, math.min(6, #rest) do
		local id = rest[i]
		local item = Config.Items[id]
		local rar = Config.Rarities[item.Rarity] or Config.Rarities.Standard
		local c, r = (i - 1) % 3, (i - 1) // 3
		local hold = float(780 + c * 166, 352 + r * 168, 150, 160, function() ctx.openKit(id) end)
		-- (lobby revamp Phase B, Edward OK: no purple tiles) a dark plate with the rarity on its edge and a thin bottom bar
		local tile = new("Frame", { BackgroundColor3 = C.white, Position = UDim2.fromOffset(18, 0), Size = UDim2.fromOffset(114, 114), Parent = hold },
			{ Kit.corner(8), new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.panelRaised, C.panel) }),
				Kit.stroke(rar.Color, 2, 0.15) })
		new("Frame", { Name = "RarityBar", BackgroundColor3 = rar.Color, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6),
			Size = UDim2.fromOffset(70, 5), ZIndex = 2, Parent = tile }, { Kit.corner(2) })
		itemArt(tile, id, hold)
		if ctx.owns(id) then priceTag(hold, "owned", 0, 75, 112, 110, 42)
		else priceTag(hold, "kit", item.Price, 75, 112, 136, 42, function() ctx.openKit(id) end, "kit:" .. id) end
	end
	new("Frame", { Name = "End", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 722), Size = UDim2.fromOffset(10, 30), Parent = pg })
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
			BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, Parent = root }, { Kit.corner(8) })
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
	local pill = new("Frame", { Position = UDim2.fromOffset(70, 14), Size = UDim2.fromOffset(190, 46), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Parent = wallet }, { Kit.corner(10) })
	walletText = Kit.label({ Text = "0", FontFace = F.display, TextSize = 36, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(170, 46), Parent = pill })
	local plus = new("TextButton", { Name = "AddScissors", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(268, 17), Size = UDim2.fromOffset(40, 40), BackgroundColor3 = C.white, Parent = wallet },
		{ Kit.corner(8), Kit.vgrad(Theme.gradient.key) })
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
