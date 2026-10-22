-- UIKit/ShopScreen (ModuleScript): the lobby SHOP.
-- (2026-10-21, RIVALS 1:1) a straight port of the RIVALS replica's Shop (rivals_practice/ui/shop/ShopController.client.lua,
-- frames t0068-t0106) over tacticals' own content: scissor packs, gear (unlocked in the Kit room), the scissors bundles, the
-- Founder's Bundle and the game passes (VIP, 2X SCISSORS). Colours, gradients and fonts all come from UIKit.Rivals.Theme;
-- UIKit.Kit stays the engine (toScale, canvas, bindButton, busy / shake / pop / countTo, the RIVALS red X).
-- All art is live 3D (ViewIcons / the lobby Icons). Design px at 1920x1080 -> Kit.toScale (Scale only).
--   ShopScreen.Init({ Config, Icons, getData, ask, owns, openKit, getSetting, tooltip, toast, onOpen, onClose })
--   ShopScreen.Open(tab?) / Close() / IsOpen() / Refresh() / SetTab(tab)
-- Tabs: Featured, Bundles, Arms, Scissors ("Home" is accepted for Featured).
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local GuiService = game:GetService("GuiService")

local UIKit = script.Parent
local Rivals = UIKit:WaitForChild("Rivals")
local Theme = require(Rivals:WaitForChild("Theme")) -- (2026-10-21, RIVALS 1:1) every colour / gradient / font
local RK = require(Rivals:WaitForChild("Kit")) -- (2026-10-21, RIVALS 1:1) RIVALS look primitives: label, corner, vgrad, stroke
local Assets = require(Rivals:WaitForChild("Assets"))
local Toast = require(Rivals:WaitForChild("Toast"))
local Kit = require(UIKit:WaitForChild("Kit")) -- engine + motion (its closeButton is RIVALS' red X, tagged Nonapplicable)
local ViewIcons = require(UIKit:WaitForChild("ViewIcons"))
local C, F, G, new = Theme.color, Theme.font, Theme.gradient, Kit.new
-- (2026-10-21, RIVALS 1:1) the replica's four Rubik weights (FX ExtraBold numbers / titles, FB Bold labels, FS SemiBold tags,
-- FM Medium lines), all on Theme's Rubik family
local FX = F.display
local FB = Font.new(F.display.Family, Enum.FontWeight.Bold)
local FS = F.heavy
local FM = F.medium
local BLACK, WHITE = C.textDark, C.white
local CENTER = Enum.TextXAlignment.Center

local function asset(name)
	for _, set in Assets do
		if type(set) == "table" and set[name] then return set[name] end
	end
	return ""
end
-- (2026-10-21, RIVALS 1:1) scissors = our "keys": every scissors price is RIVALS' yellow key button with the red scissors render
-- on the right of the number; Robux = the lime button with RIVALS' white Robux glyph on the left
local SCISSORS_IMG = "rbxassetid://120480559804238"
local ROBUX_IMG = asset("cur_robux") ~= "" and asset("cur_robux") or "rbxasset://textures/ui/common/robux.png"

local Screen = {}
local ctx = {}
local gui, root, body, blur, scrim, pageHolder, walletText, walletPill, canvasF, loader
local tab = "Featured"
local isOpen = false
local tabBtns = {}
-- (2026-10-21, RIVALS pass) pages are built once (at join) and kept: each priceTag registers an update() on the page being
-- built, Refresh runs those in place. A page is only rebuilt on a tab switch / open, and only when what you own changed.
local pages = {} -- tab -> { pg, updaters, post, sig, dirty }
local curPage -- the page RENDER is filling right now
local ready = false -- all pages built (the shop opens behind the loading dots until then)
local buying = false -- one purchase in flight at a time (no double buys)
local pending -- (2026-10-21, RIVALS 1:1) a Robux buy whose prompt is up: { spec, credits, at }; Refresh waits for it to land
local shownCredits
local openDetail -- forward: the detail card (defined below the cards)

-- (2026-10-21, RIVALS 1:1) the replica's geometry: tab row at y 275 (centred), page window x 318 y 370, 1300 wide; the
-- content column is 12..1254 inside it (RIVALS 330-1572 on screen)
local PAGE_X, PAGE_Y, PAGE_W, PAGE_H = 318, 370, 1300, 710
local TAB_Y, TAB_W, TAB_H, TAB_STEP = 275, 144, 48, 156

local function data() return ctx.getData and ctx.getData() or {} end
local function fmtN(n)
	local s = tostring(math.floor(n))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end
-- the replica's text outline: a black glyph stroke (Contextual), never a frame border
local function stroke(l, t, a)
	new("UIStroke", { Color = BLACK, Thickness = t or 2, Transparency = a or 0.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = l })
	return l
end
-- Kit.shake reads the current Position as its base, so a second shake mid-shake would drift: one at a time
local function shakeOnce(g)
	if g:GetAttribute("Shaking") then return end
	g:SetAttribute("Shaking", true)
	Kit.shake(g)
	task.delay(0.25, function() g:SetAttribute("Shaking", nil) end)
end
-- what the pages were built from: owned gear + passes (+ the hover setting); a change marks pages dirty
local function ownedSig()
	local d, parts = data(), {}
	if ctx.Config then for id in ctx.Config.Items do if ctx.owns(id) then table.insert(parts, id) end end end
	for k, v in d.Passes or {} do if v then table.insert(parts, "P:" .. k) end end
	table.sort(parts)
	return table.concat(parts, ",") .. "|" .. tostring(ctx.getSetting and ctx.getSetting("ShopHover"))
end
local function rarityColor(id)
	local Config = ctx.Config
	local item = Config.Items[id]
	return ((item and Config.Rarities[item.Rarity]) or Config.Rarities.Standard).Color
end

-------------------------------------------------------------------------------
-- (2026-10-21, RIVALS 1:1) shared RIVALS pieces
-------------------------------------------------------------------------------
-- feature-card title: heavy white (Rubik ExtraBold) with a dark outline and a soft drop shadow under it
local function heavyTitle(parent, text, ts, x, y, w, h, z, align)
	z = z or 5
	RK.label({ Name = "TitleShadow", Text = text, FontFace = FX, TextSize = ts, TextColor3 = BLACK, TextTransparency = 0.55, TextXAlignment = align,
		Position = UDim2.fromOffset(x, y + math.max(2, math.floor(ts * 0.07))), Size = UDim2.fromOffset(w, h), ZIndex = z, Parent = parent })
	return stroke(RK.label({ Name = "Title", Text = text, FontFace = FX, TextSize = ts, TextXAlignment = align,
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), ZIndex = z + 1, Parent = parent }), 2.5, 0.5)
end
-- gold bundle titles: the key gradient on the words, a glare sweeping across every 3 s and stars twinkling (replica sparkle)
local function goldTitle(l)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(G.key[1], G.key[2]), Parent = l })
	local shine = RK.label({ Name = "Glimmer", Text = l.Text, FontFace = l.FontFace, TextSize = l.TextSize, TextXAlignment = l.TextXAlignment, Size = UDim2.fromScale(1, 1), ZIndex = l.ZIndex + 1, Parent = l })
	local g = new("UIGradient", { Rotation = 15, Offset = Vector2.new(-1, 0), Parent = shine, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.28, 1),
		NumberSequenceKeypoint.new(0.42, 0.25), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(0.58, 0.25), NumberSequenceKeypoint.new(0.72, 1), NumberSequenceKeypoint.new(1, 1) }) })
	local star = asset("rank_star")
	task.spawn(function()
		local rng = Random.new()
		task.wait(rng:NextNumber(0, 2))
		while l.Parent do
			if isOpen then
				g.Offset = Vector2.new(-1, 0)
				Kit.tween(g, 0.9, { Offset = Vector2.new(1, 0) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			end
			task.wait(3)
		end
	end)
	task.spawn(function()
		local rng = Random.new()
		while l.Parent do
			if isOpen and l.Visible and star ~= "" and l.AbsoluteSize.X > 0 and rng:NextNumber() < 0.35 then
				local fx = math.clamp(l.TextBounds.X / l.AbsoluteSize.X, 0.1, 1)
				local sp = new("ImageLabel", { BackgroundTransparency = 1, Image = star, ImageColor3 = G.key[1], AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(rng:NextNumber(0.02, 0.98) * fx, rng:NextNumber(0.2, 0.8)), Size = UDim2.fromScale(1, rng:NextNumber(0.3, 0.5)), ZIndex = l.ZIndex + 2, Parent = l },
					{ new("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Height }) })
				local sc = new("UIScale", { Scale = 0, Parent = sp })
				Kit.tween(sc, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
				Kit.tween(sp, 0.6, { Rotation = 90 }, Enum.EasingStyle.Linear)
				task.delay(0.3, function() Kit.tween(sc, 0.25, { Scale = 0 }); Kit.tween(sp, 0.25, { ImageTransparency = 1 }) end)
				task.delay(0.6, function() sp:Destroy() end)
			end
			task.wait(0.12)
		end
	end)
	return l
end
-- the red "x4 VALUE" badge with its pointer, sat just above a price button
local function valueTag(parent, cx, y, text, w, h, ts, z)
	h, z = h or 32, z or 6
	local t = new("Frame", { Name = "Value", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(cx, y), Size = UDim2.fromOffset(w or 116, h),
		BackgroundColor3 = C.badge, BorderSizePixel = 0, ZIndex = z, Parent = parent }, { RK.corner(5) })
	local p = math.floor(h * 0.38)
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45, Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(p, p), BackgroundColor3 = C.badge,
		BorderSizePixel = 0, ZIndex = z - 1, Parent = t })
	RK.label({ Text = text, FontFace = FS, TextSize = ts or math.floor(h * 0.6), TextXAlignment = CENTER, Size = UDim2.fromScale(1, 1), ZIndex = z + 1, Parent = t })
	return t
end
-- item tile (Design System): near-black at the top -> the rarity colour at the bottom, a 2 px stroke in the rarity colour
local function rarityTile(parent, col, x, y, w, h, z, class)
	local t = new(class or "Frame", { Name = "Tile", BackgroundColor3 = WHITE, BorderSizePixel = 0, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), ZIndex = z or 1, Parent = parent },
		{ RK.corner(6), new("UIGradient", { Rotation = 90, Color = ColorSequence.new(col:Lerp(BLACK, 0.85), col) }), new("UIStroke", { Color = col:Lerp(WHITE, 0.15), Thickness = 2 }) })
	if t:IsA("TextButton") then t.Text, t.AutoButtonColor = "", false end
	return t
end
-- owned = RIVALS' black check (t0099): two black bars with a thin white edge, no plate
local function checkMark(parent, s, props)
	local h = new("Frame", { Name = "Check", BackgroundTransparency = 1, Size = UDim2.fromOffset(s, s), ZIndex = 7, Parent = parent })
	for k, v in props or {} do h[k] = v end
	local th = math.max(3, math.floor(s * 0.17))
	for _, b in { { 0.34, 0.6, 0.36, 45 }, { 0.6, 0.47, 0.64, -50 } } do
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(s * b[1], s * b[2]), Size = UDim2.fromOffset(math.floor(s * b[3]), th), Rotation = b[4],
			BackgroundColor3 = BLACK, BorderSizePixel = 0, ZIndex = h.ZIndex + 1, Parent = h }, { RK.corner(2), RK.stroke(WHITE, 1.5, 0.3) })
	end
	return h
end
-- "×N" count under a render (RIVALS extras: "×20" keys)
local function countLabel(parent, n, x, y, w, h, ts, z)
	return stroke(RK.label({ Name = "Count", Text = "×" .. fmtN(n), FontFace = FX, TextSize = ts, TextXAlignment = CENTER, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), ZIndex = z or 4, Parent = parent }), 2, 0.25)
end

-------------------------------------------------------------------------------
-- 3D art
-------------------------------------------------------------------------------
-- renders on light tiles: viewport lit like the hub dock (ambient ~220 + a camera-side key light)
local function lit(vp)
	if vp and vp.Frame then
		vp.Frame.Ambient = Color3.fromRGB(220, 220, 226)
		vp.Frame.LightColor = WHITE
		vp.Frame.LightDirection = Vector3.new(0.45, -0.7, 0.55)
	end
	return vp
end
-- an item (gun / gadget / melee) via the lobby Icons module, which knows every item kind
local function itemArt(holder, itemId, hoverTarget, zoomMul)
	local model, view, zoom = ctx.Icons.Item(itemId)
	local vp = ViewIcons.Viewport(holder, model, { view = view, zoom = (zoom or 1) * (zoomMul or 1) })
	if hoverTarget then
		hoverTarget.MouseEnter:Connect(function() vp.SetHover(true) end)
		hoverTarget.MouseLeave:Connect(function() vp.SetHover(false) end)
	end
	return vp
end
-- RIVALS' bundle banners are ONE posed render of the bundle's items, big and cropped by the card edge. Ours: one live
-- viewport holding all the items fanned out, each scaled to the same size, zoomed in so the card (ClipsDescendants) crops them.
local function sceneArt(holder, ids, zoom)
	local scene = Instance.new("Model")
	local n = #ids
	for j, id in ids do
		local ok, m, view = pcall(ctx.Icons.Item, id)
		if ok and m and m:IsA("Model") and #m:GetChildren() > 0 then
			local _, size = m:GetBoundingBox()
			pcall(function() m:ScaleTo(m:GetScale() * 3.2 / math.max(size.Magnitude, 0.05)) end)
			local o = j - (n + 1) / 2
			m:PivotTo(CFrame.Angles(0, 0, math.rad(-o * 12)) * (view or CFrame.identity))
			local cf = m:GetBoundingBox()
			m:TranslateBy(Vector3.new(o * 2.1, -math.abs(o) * 0.45, math.abs(o) * 0.8) - cf.Position)
			m.Parent = scene
		elseif ok and m then
			m:Destroy()
		end
	end
	if #scene:GetChildren() == 0 then
		scene:Destroy()
		scene = ViewIcons.Build("Crate")
	end
	return ViewIcons.Viewport(holder, scene, { view = CFrame.Angles(math.rad(6), math.rad(-10), 0), zoom = zoom or 1.3 })
end
-- (2026-10-21, RIVALS 1:1) a hovered tile only grows (its bindButton); the live render also turns toward you. The round-3
-- lift / tilt / squash and the rocking stickers are gone (RIVALS has neither).
local function turnOnHover(target, vp)
	if not vp then return end
	target.MouseEnter:Connect(function() vp.SetHover(true) end)
	target.MouseLeave:Connect(function() vp.SetHover(false) end)
	target.SelectionGained:Connect(function() vp.SetHover(true) end)
	target.SelectionLost:Connect(function() vp.SetHover(false) end)
end
-- the scissors pile (n renders fanned out) used for the packs
local function scissorsPile(holder, n, w, h, z, step)
	for k = 1, n do
		local a = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset((k - 1) * step, (k - 1) * 3), Size = UDim2.fromOffset(w - (n - 1) * step, h - (n - 1) * 3), ZIndex = z, Parent = holder })
		lit(ViewIcons.Viewport(a, ViewIcons.Scissors(), { view = CFrame.Angles(0, 0, math.rad((k - (n + 1) / 2) * 22)) * ViewIcons.Views.Scissors[1], zoom = 1.2, still = true, zIndex = z }))
	end
end

-------------------------------------------------------------------------------
-- (2026-10-21, RIVALS 1:1) Price button = the replica's priceTag: a 6 px rounded block with RIVALS' vertical gradient (lime
-- Theme.gradient.robux / yellow Theme.gradient.key) and a faint dark edge; the number is Rubik ExtraBold white over a soft
-- shadow copy; Robux glyph LEFT of the number, the scissors render RIGHT of it (RIVALS' key buttons: "5 [key]").
-- Built once with both faces; update() flips it in place. Owned (RIVALS t0099): the button goes, a black check sits there.
-- live = { owned = fn, amount = fn, ts, isz, z, noHover }. onBuy(tag) runs on click (Kit prices open the Kit room).
-------------------------------------------------------------------------------
local function priceTag(parent, kind, amount, cx, y, w, h, onBuy, live)
	w, h, live = w or 102, h or 46, live or {}
	local isRobux = kind == "robux"
	local tag = new("TextButton", { Name = "Price", Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(cx, y),
		Size = UDim2.fromOffset(w, h), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = live.z or 5, Parent = parent })
	RK.corner(6).Parent = tag
	local grad = RK.vgrad(isRobux and G.robux or G.key)
	grad.Parent = tag
	local edge = RK.stroke(BLACK, 1.5, 0.6)
	edge.Parent = tag
	local z = tag.ZIndex
	local row = new("Frame", { Name = "BuyRow", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = z, Parent = tag },
		{ new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local ts = live.ts or math.floor(h * 0.72)
	local isz = live.isz or math.floor(h * (isRobux and 0.62 or 0.8))
	-- children draw above their parent: the parent label is the shadow, the white number is its child nudged up 2 px
	local shadow = RK.label({ Name = "Num", LayoutOrder = 2, Text = "0", FontFace = FX, TextSize = ts, TextColor3 = BLACK, TextTransparency = 0.75,
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, h), ZIndex = z + 1, Parent = row })
	local txt = RK.label({ Name = "Text", Text = "0", FontFace = FX, TextSize = ts, Position = UDim2.fromOffset(0, -2), Size = UDim2.fromScale(1, 1), ZIndex = z + 2, Parent = shadow })
	new("ImageLabel", { Name = "Currency", LayoutOrder = isRobux and 1 or 3, BackgroundTransparency = 1, Image = isRobux and ROBUX_IMG or SCISSORS_IMG,
		ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromOffset(isz, isz), ZIndex = z + 1, Parent = row })
	local check = checkMark(tag, math.floor(h * 0.9), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Visible = false, ZIndex = z + 2 })
	-- can't afford: it still opens the Kit / the detail card; nothing changes at rest, a press only shakes the button
	local st = { own = nil, short = false, amount = nil }
	local function update()
		local own = kind == "owned" or (live.owned and live.owned()) and true or false
		local amt = live.amount and live.amount() or amount or 0
		if own ~= st.own then
			tag.BackgroundTransparency = own and 1 or 0
			grad.Enabled, edge.Enabled = not own, not own
			row.Visible, check.Visible = not own, own
			if own and st.own == false then Kit.pop(check, 1.4) end -- just bought: the check lands
			st.own = own
		end
		if amt ~= st.amount then
			st.amount = amt
			shadow.Text = fmtN(amt)
			txt.Text = shadow.Text
		end
		st.short = (kind == "scissors" or kind == "kit") and not own and (data().Credits or 0) < amt
	end
	update()
	if curPage then table.insert(curPage.updaters, update) end
	if onBuy and kind ~= "owned" then
		if not live.noHover then Kit.bindButton(tag, { hover = 1.06 }) end
		tag.Activated:Connect(function()
			update()
			if st.own then return end
			if st.short then
				shakeOnce(tag)
				task.delay(0.25, function() onBuy(tag) end)
				return
			end
			onBuy(tag)
		end)
	end
	return tag, update, row
end

-------------------------------------------------------------------------------
-- Box spotlight (RIVALS, the replica's pageSpotlight): a huge stroke around a hole zeroes in on the hovered card, slides
-- (with a little bounce) to the next card, lets go in the gaps. Settings > Game > Shop Hover = Off disables it.
-------------------------------------------------------------------------------
local function pageSpotlight(pg, grow)
	grow = grow or 1.03
	local spotOn = not (ctx.getSetting and ctx.getSetting("ShopHover") == "Off")
	local hole = new("Frame", { Name = "SpotBox", BackgroundTransparency = 1, Visible = false, ZIndex = 10, Active = false, Size = UDim2.fromOffset(10, 10), Parent = pg }, { RK.corner(12) })
	pcall(function() hole.Interactable = false end)
	local holeStroke = new("UIStroke", { Color = BLACK, Transparency = 1, Thickness = 1, Parent = hole })
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

-- (2026-10-21, RIVALS 1:1) the hover reveal (replica Bundles / Season Pass): while the card is hovered its contents show,
-- the idle layer (value badge + price) hides and the big render fades back to 0.82
local function hoverReveal(card, contents, idle, vp, shade)
	contents.Visible = false
	local function on(v)
		contents.Visible = v
		if idle then idle.Visible = not v end
		if shade then shade.Visible = v end
		if vp then
			Kit.tween(vp.Frame, 0.12, { ImageTransparency = v and 0.82 or 0 })
			vp.SetHover(v)
		end
	end
	card.MouseEnter:Connect(function() on(true) end)
	card.MouseLeave:Connect(function() on(false) end)
	card.SelectionGained:Connect(function() on(true) end)
	card.SelectionLost:Connect(function() on(false) end)
end

-------------------------------------------------------------------------------
-- What the detail card shows for each kind of buy. buy() returns ctx.ask's result: the same ask("BuyBundle" / "BuyRobux" /
-- "BuyPass") calls as before; Robux ones make Roblox show its own prompt.
-------------------------------------------------------------------------------
local function bundleValue(items, cost)
	local full = 0
	for _, id in items do
		local it = ctx.Config.Items[id]
		if it then full += it.Price end
	end
	if cost > 0 and full > cost then return math.max(2, math.floor(full / cost + 0.5)) end
	return nil
end
local function bundleSpec(bd)
	local Config = ctx.Config
	local s = { id = bd.Id, title = bd.Name, noun = "Bundle", tag = bd.Tag, items = bd.Items, kind = "scissors", color = bd.Color,
		amount = function() return (Config.BundleCost(bd, ctx.owns)) end,
		owned = function() local _, m = Config.BundleCost(bd, ctx.owns) return m == 0 end,
		buy = function() return ctx.ask("BuyBundle", bd.Id) end }
	s.value = function() return bundleValue(bd.Items, s.amount()) end
	return s
end
local function founderSpec(pr)
	return { id = pr.Key, title = pr.Name, noun = "Bundle", tag = pr.Tag, items = pr.Items or {}, kind = "robux", color = pr.Color or C.redDark, credits = pr.Credits,
		amount = function() return pr.Robux end,
		owned = function()
			for _, id in pr.Items or {} do if not ctx.owns(id) then return false end end
			return true
		end,
		buy = function() return ctx.ask("BuyRobux", pr.Key) end }
end
local function packSpec(pr)
	return { id = pr.Key, title = pr.Name or ("+" .. fmtN(pr.Credits or 0)), noun = "Pack", tag = pr.Tag, kind = "robux", icon = "Scissors", credits = pr.Credits, color = C.gold,
		amount = function() return pr.Robux end,
		buy = function() return ctx.ask("BuyRobux", pr.Key) end }
end
local function passSpec(gp)
	return { id = gp.Key, title = gp.Name, noun = "Pass", desc = gp.Desc, kind = "robux", icon = "Medal", color = G.grey[2],
		amount = function() return gp.Robux end,
		owned = function() local d = data() return d.Passes and d.Passes[gp.Key] and true or false end,
		buy = function() return ctx.ask("BuyPass", gp.Key) end }
end
local function founderProduct()
	local featured
	for _, pr in ctx.Config.RobuxProducts do if pr.Bundle then featured = pr end end
	return featured
end

-- (2026-10-21, RIVALS 1:1) RIVALS' "Purchase Complete" banner (t0099): the UIKit.Notify pill (the same RIVALS banner the
-- server's RichNotify drives), queued with the others; Rivals Toast if Notify isn't there
local function purchaseComplete(spec)
	local sub
	if spec.credits and not (spec.items and #spec.items > 0) then
		sub = ("You've earned ×%s Scissors!"):format(fmtN(spec.credits))
	else
		local name = spec.title or "item"
		local noun = spec.noun and not string.upper(name):find(string.upper(spec.noun), 1, true) and (" " .. spec.noun) or ""
		sub = ('You\'ve earned the "%s"%s!'):format(name, noun)
	end
	local n = { title = "Purchase Complete", sub = sub, icon = "check" }
	if spec.items and spec.items[1] then n.reward = { kind = "Item", id = spec.items[1] }
	elseif spec.credits then n.reward = { kind = "Scissors", count = spec.credits } end
	local ok, Notify = pcall(function() return require(UIKit:FindFirstChild("Notify")) end)
	if ok and type(Notify) == "table" and Notify.Push then
		Notify.Push(n)
	else
		pcall(Toast.show, { title = n.title, text = sub, icon = "check" })
	end
end

-------------------------------------------------------------------------------
-- Cards
-------------------------------------------------------------------------------
-- (2026-10-21, RIVALS 1:1) a row of a bundle's items as rarity tiles with the render spilling over the top, the name on the
-- tile's foot and a black check on the ones you own (replica skinTile / weaponItem). Returns the next x.
local function contentsRow(parent, ids, x, y, sz, gap, z, ups)
	local Config = ctx.Config
	for _, id in ids do
		local item = Config.Items[id]
		if item then
			local t = rarityTile(parent, rarityColor(id), x, y, sz, sz, z)
			local art = new("Frame", { Name = "Art", BackgroundTransparency = 1, Position = UDim2.fromOffset(-sz * 0.08, -sz * 0.16), Size = UDim2.fromOffset(sz * 1.16, sz * 1.04), ZIndex = z + 1, Parent = t })
			lit(itemArt(art, id, t, 1.1)).Frame.ZIndex = z + 1
			stroke(RK.label({ Text = item.Name, FontFace = FB, TextSize = math.clamp(math.floor(sz * 0.18), 13, 24), TextXAlignment = CENTER,
				Position = UDim2.fromOffset(-10, sz * 0.76), Size = UDim2.fromOffset(sz + 20, sz * 0.22), ZIndex = z + 2, Parent = t }), 1.5, 0.3)
			local chk = checkMark(t, math.floor(sz * 0.34), { Position = UDim2.fromOffset(sz * 0.62, 3), Visible = ctx.owns(id), ZIndex = z + 3 })
			if ups then table.insert(ups, function() chk.Visible = ctx.owns(id) end) end
			x += sz + gap
		end
	end
	return x
end
-- the scissors a Robux bundle adds, as a RIVALS extra: the render with "×N" across its foot
local function extraScissors(parent, n, x, y, sz, z)
	new("ImageLabel", { BackgroundTransparency = 1, Image = SCISSORS_IMG, ScaleType = Enum.ScaleType.Fit, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(sz, sz), ZIndex = z, Parent = parent })
	countLabel(parent, n, x - 10, y + sz * 0.68, sz + 20, sz * 0.5, math.floor(sz * 0.5), z + 1)
end

-- (2026-10-21, RIVALS 1:1) a Bundles-tab card (replica B list, t0068.4s): the bundle colour with the 35° dark-to-light wash,
-- the big posed render cropped by the card, the gold sparkling title top left (the hero: white, 56), and bottom right the
-- "xN VALUE" badge over the price. Hover: the spotlight closes in and the card reveals its contents + a bigger price.
-- big = the 1242x399 hero (contents always shown).
local function bundleCard(pg, hover, spec, x, y, w, h, big)
	local ups = curPage and curPage.updaters
	local card = new("TextButton", { Name = spec.id or spec.title, Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = spec.color or C.panelRaised, BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 1, Parent = pg },
		{ RK.corner(8), new("UIGradient", { Rotation = 35, Color = ColorSequence.new(BLACK, WHITE), Transparency = NumberSequence.new(0.55, 0) }) })
	local scene = new("Frame", { Name = "Scene", BackgroundTransparency = 1, Position = UDim2.fromOffset(w * (big and 0.42 or 0.3), -h * 0.12), Size = UDim2.fromOffset(w * (big and 0.6 or 0.75), h * 1.26), ZIndex = 2, Parent = card })
	local vp = lit(sceneArt(scene, spec.items or {}, 1.3))
	vp.Frame.ZIndex = 2
	local ts = big and 56 or (w > 500 and 40 or 38)
	local title = heavyTitle(card, spec.title, ts, 24, big and 20 or 18, w - 48, ts + 8, 7)
	if not big then goldTitle(title) end
	local pw = w > 1000 and 208 or (w > 500 and 200 or 155)
	local cx = w - 20 - pw / 2
	local priceKind = spec.kind == "robux" and "robux" or "scissors"
	local function view() openDetail(spec) end
	if big then
		-- the hero: contents always on, the red tag pill top right (RIVALS' timer pill), the price bottom right
		local nx = contentsRow(card, spec.items or {}, 46, 120, 128, 18, 4, ups)
		if spec.credits then extraScissors(card, spec.credits, nx + 10, 150, 96, 4) end
		if spec.tag then
			new("TextLabel", { Name = "Tag", BackgroundColor3 = C.badge, BorderSizePixel = 0, Text = spec.tag, FontFace = FM, TextSize = 28, TextColor3 = WHITE, AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromOffset(w - 24, 26), Size = UDim2.fromOffset(0, 49), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 7, Parent = card }, { RK.corner(5), RK.pad(18, 0, 18, 0) })
		end
		priceTag(card, priceKind, spec.amount(), cx, 266, pw, 66, view, { owned = spec.owned, amount = spec.amount, ts = 46, isz = 40, z = 9, noHover = true })
	else
		local idle = new("Frame", { Name = "Idle", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = card })
		local value = spec.value and spec.value()
		if value then valueTag(idle, cx, h - 85 - 46, "x" .. value .. " VALUE", w > 500 and 150 or 116, 32, 19, 6) end
		priceTag(idle, priceKind, spec.amount(), cx, h - 85, pw, 64, view, { owned = spec.owned, amount = spec.amount, ts = 44, isz = 40, z = 8, noHover = true })
		local f = new("Frame", { Name = "Contents", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = card })
		local small = w < 500
		contentsRow(f, spec.items or {}, small and 16 or 52, small and 76 or 84, small and 80 or 96, small and 8 or 16, 4, ups)
		local bw = w > 500 and 205 or 170
		priceTag(f, priceKind, spec.amount(), w - 20 - bw / 2, h - 88, bw, 68, view, { owned = spec.owned, amount = spec.amount, ts = 46, isz = 42, z = 8, noHover = true })
		hoverReveal(card, f, idle, vp)
	end
	hover(card)
	card.Activated:Connect(function() if not (spec.owned and spec.owned()) then view() end end)
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
local function endPad(pg, y)
	new("Frame", { Name = "End", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(10, 40), Parent = pg })
end
-- RIVALS' section header bar ("Finishers", t0099): a dark bar fading out to the right, a 3D icon and a Bold title
local function headerBar(pg, text, iconName, y)
	local bar = new("Frame", { Name = "Header_" .. text, Position = UDim2.fromOffset(12, y), Size = UDim2.fromOffset(1242, 62), BackgroundColor3 = BLACK,
		BackgroundTransparency = Theme.alpha.header, BorderSizePixel = 0, Parent = pg }, { RK.corner(8),
		new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.55, 0.3), NumberSequenceKeypoint.new(1, 1) }) }) })
	local ic = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 4), Size = UDim2.fromOffset(54, 54), ZIndex = 2, Parent = bar })
	ViewIcons.Icon(ic, iconName, { zoom = 1, zIndex = 2 })
	RK.label({ Text = text, FontFace = FB, TextSize = 38, Position = UDim2.fromOffset(76, 0), Size = UDim2.fromOffset(800, 62), ZIndex = 2, Parent = bar })
end

local RENDER = {}

-- Home (RIVALS ref_35 / t0070, the replica's Home): left, the crates rows (scissor packs for Robux, then gear for scissors) as
-- bare renders over their price buttons; right, the Season Pass card (our Founder's Bundle); bottom left, the Special Offer
-- carousel with its page dots; bottom right, 3x2 rarity item tiles with the price overlapping each tile's foot.
function RENDER.Featured(pg, hover)
	local Config = ctx.Config
	local d = data()
	local P = curPage
	local function hold(x, y, w, h, grow, onClick)
		local b = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), Parent = pg })
		Kit.bindButton(b, { hover = grow })
		if onClick then b.Activated:Connect(onClick) end
		return b
	end
	-- crates row: scissor packs (the pile grows with the pack, "×N" across its foot), lime Robux price under each
	local packs = {}
	for _, pr in Config.RobuxProducts do if pr.Credits and not pr.Bundle then table.insert(packs, pr) end end
	for i = 1, math.min(3, #packs) do
		local pr = packs[i]
		local function open() openDetail(packSpec(pr)) end
		local h = hold(79 + (i - 1) * 163 - 80, 22, 160, 148, 1.08, open)
		local pile = new("Frame", { Name = "Pile", BackgroundTransparency = 1, Position = UDim2.fromOffset(2, -4), Size = UDim2.fromOffset(156, 104), ZIndex = 2, Parent = h })
		scissorsPile(pile, math.min(i + 1, 4), 156, 104, 2, 10)
		countLabel(h, pr.Credits, 60, 62, 100, 40, 32, 4)
		priceTag(h, "robux", pr.Robux, 80, 102, 102, 46, open, { noHover = true })
	end
	-- boxes row: gear you don't have yet as bare renders over yellow scissors prices (opens the Kit room)
	local gear = {}
	for _, id in sortedGear() do if not ctx.owns(id) then table.insert(gear, id) end end
	for i = 1, math.min(3, #gear) do
		local id = gear[i]
		local h = hold(79 + (i - 1) * 163 - 80, 182, 160, 148, 1.08, function() ctx.openKit(id) end)
		local art = new("Frame", { Name = "Art", BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 0), Size = UDim2.fromOffset(132, 104), ZIndex = 2, Parent = h })
		turnOnHover(h, lit(itemArt(art, id, nil, 1.15)))
		priceTag(h, "kit", Config.Items[id].Price, 80, 102, 102, 46, function() ctx.openKit(id) end, { owned = function() return ctx.owns(id) end, noHover = true })
	end

	-- the Season Pass card (749x321 at 519,6): our Founder's Bundle. Grey 35° wash (or the bundle colour), one big render
	-- cropped by the card, the heavy white title + shadow, the LIMITED pill, the lime price where RIVALS has its eye button.
	-- Hover: the spotlight closes in, a dark shade rises and the bundle's contents show (RIVALS' pass showcase).
	local featured = founderProduct()
	if featured then
		local spec = founderSpec(featured)
		local w, h = 749, 321
		local top, bottom = G.grey[1], G.grey[2]:Lerp(BLACK, 0.45)
		if featured.Color then top, bottom = featured.Color:Lerp(WHITE, 0.25), featured.Color:Lerp(BLACK, 0.55) end
		local card = new("TextButton", { Name = "Hero", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(519, 6), Size = UDim2.fromOffset(w, h),
			BackgroundColor3 = WHITE, BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 1, Parent = pg },
			{ RK.corner(6), new("UIGradient", { Rotation = 35, Color = ColorSequence.new(top, bottom) }) })
		local scene = new("Frame", { Name = "Scene", BackgroundTransparency = 1, Position = UDim2.fromOffset(w * 0.18, -h * 0.06), Size = UDim2.fromOffset(w * 0.74, h * 1.16), ZIndex = 2, Parent = card })
		local vp = lit(sceneArt(scene, spec.items, 1.2))
		vp.Frame.ZIndex = 2
		local shade = new("Frame", { Name = "Shade", BackgroundColor3 = BLACK, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 3, Parent = card },
			{ new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.85), NumberSequenceKeypoint.new(0.55, 0.8), NumberSequenceKeypoint.new(1, 0.25) }) }) })
		heavyTitle(card, featured.Name, 46, 32, 18, 520, 56, 7)
		if featured.Tag then
			new("TextLabel", { Name = "Tag", BackgroundColor3 = C.badge, BorderSizePixel = 0, Text = featured.Tag, FontFace = FM, TextSize = 26, TextColor3 = WHITE, AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromOffset(w - 24, 24), Size = UDim2.fromOffset(0, 44), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 7, Parent = card }, { RK.corner(5), RK.pad(16, 0, 16, 0) })
		end
		local contents = new("Frame", { Name = "Contents", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = card })
		local nx = contentsRow(contents, spec.items, 40, 96, 100, 14, 5, P and P.updaters)
		if spec.credits then extraScissors(contents, spec.credits, nx + 6, 110, 80, 5) end
		hoverReveal(card, contents, nil, vp, shade)
		local function open() openDetail(spec) end
		priceTag(card, "robux", featured.Robux, 650, 216, 200, 82, open, { owned = spec.owned, ts = 56, isz = 48, z = 9 })
		hover(card)
		card.Activated:Connect(open)
	end

	-- Special Offer (750x324 at 0,363): a dark panel holding the offer slides (passes you don't own, then the bundles). Each
	-- slide = its colour, a big render, the heavy title (gold + sparkle for bundles), the red value badge and RIVALS' lime
	-- "Special Offer / VIEW" button, which opens the detail card. Slides change every 6 s (paused under the pointer) or from
	-- the page dots under the panel.
	local offers = {}
	for _, gp in Config.GamePasses do if not (d.Passes and d.Passes[gp.Key]) then table.insert(offers, passSpec(gp)) end end
	for _, bd in Config.Bundles or {} do table.insert(offers, bundleSpec(bd)) end
	local so = new("Frame", { Name = "SpecialOffer", Position = UDim2.fromOffset(0, 363), Size = UDim2.fromOffset(750, 324), BackgroundColor3 = C.panel,
		BackgroundTransparency = 0.25, BorderSizePixel = 0, ClipsDescendants = true, Parent = pg }, { RK.corner(8) })
	local slides = {}
	for i, spec in offers do
		local isPass = spec.items == nil
		local col = isPass and C.panelRaised or (spec.color or C.panelRaised)
		local sl = new("TextButton", { Name = "Slide" .. i, Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = col, BorderSizePixel = 0,
			ClipsDescendants = true, Visible = i == 1, ZIndex = 2, Parent = so }, { RK.corner(8),
			new("UIGradient", { Rotation = 35, Color = ColorSequence.new(BLACK, WHITE), Transparency = NumberSequence.new(0.55, 0) }) })
		local art = new("Frame", { Name = "Art", BackgroundTransparency = 1, Position = UDim2.fromOffset(isPass and 330 or 250, isPass and -10 or -30), Size = UDim2.fromOffset(isPass and 300 or 500, isPass and 300 or 384), ZIndex = 3, Parent = sl })
		local vp = isPass and lit(ViewIcons.Icon(art, "Medal", { zoom = 1, zIndex = 3 })) or lit(sceneArt(art, spec.items, 1.25))
		vp.Frame.ZIndex = 3
		turnOnHover(sl, vp)
		local t = heavyTitle(sl, spec.title, 46, 32, 22, 680, 60, 5)
		if not isPass then goldTitle(t) end
		if isPass and spec.desc then
			stroke(RK.label({ Text = spec.desc, FontFace = FM, TextSize = 24, TextColor3 = C.textDim, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
				Position = UDim2.fromOffset(34, 90), Size = UDim2.fromOffset(400, 110), ZIndex = 5, Parent = sl }), 1.5, 0.5)
		end
		local value = spec.value and spec.value()
		if value then valueTag(sl, 600, 164, "x" .. value .. " VALUE", 190, 40, 24, 8) end
		local viewBtn = new("TextButton", { Name = "View", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(475, 214), Size = UDim2.fromOffset(250, 80), BackgroundColor3 = WHITE,
			BorderSizePixel = 0, ZIndex = 7, Parent = sl }, { RK.corner(6), RK.vgrad(G.robux), RK.stroke(G.robux[2]:Lerp(BLACK, 0.55), 1.5, 0.4) })
		RK.label({ Text = "Special Offer", FontFace = FB, TextSize = 19, TextColor3 = G.robux[2]:Lerp(BLACK, 0.6), TextXAlignment = CENTER, Position = UDim2.fromOffset(0, 6), Size = UDim2.fromOffset(250, 22), ZIndex = 8, Parent = viewBtn })
		stroke(RK.label({ Text = "VIEW", FontFace = FX, TextSize = 48, TextXAlignment = CENTER, Position = UDim2.fromOffset(0, 24), Size = UDim2.fromOffset(250, 52), ZIndex = 8, Parent = viewBtn }), 2, 0.4)
		Kit.bindButton(viewBtn, { hover = 1.05 })
		viewBtn.Activated:Connect(function() openDetail(spec) end)
		sl.Activated:Connect(function() openDetail(spec) end)
		table.insert(slides, sl)
	end
	if #slides > 1 then
		-- page dots (replica): a dark pill with one dot per slide, the current one white and bigger; a hovered dot grows and the
		-- pill stretches to fit (laid out by hand in Scale after toScale, P.post); clicking a dot shows that slide
		local N, PADX, GAP, DH = #slides, 12, 26.5, 32
		local W0 = PADX * 2 + GAP * (N - 1) + 16 + 11 * (N - 1)
		local dots = new("Frame", { Name = "Dots", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(375, 699), Size = UDim2.fromOffset(W0, DH),
			BackgroundColor3 = BLACK, BackgroundTransparency = 0.45, BorderSizePixel = 0, Parent = pg }, { RK.corner(16) })
		local ds, sel, kx, paused = {}, 1, nil, false
		for k = 1, N do
			local f = new("TextButton", { Name = "Dot" .. k, Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(11, 11),
				Position = UDim2.fromOffset(0, DH / 2), BackgroundColor3 = C.track, BorderSizePixel = 0, Parent = dots }, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
			ds[k] = { f = f, v = new("NumberValue", { Value = k == 1 and 16 or 11 }), hover = false }
		end
		local function layout()
			if not kx then return end
			local W = PADX * 2 + GAP * (N - 1)
			for _, st in ds do W += st.v.Value end
			dots.Size = UDim2.fromScale(W * kx, dots.Size.Y.Scale)
			local x = PADX
			for k, st in ds do
				local s = st.v.Value
				st.f.Size = UDim2.fromScale(s / W, s / DH)
				st.f.Position = UDim2.fromScale((x + s / 2) / W, 0.5)
				st.f.BackgroundColor3 = k == sel and WHITE or C.track
				x += s + GAP
			end
		end
		local function target(k)
			local st = ds[k]
			local base = k == sel and 16 or 11
			Kit.tween(st.v, 0.15, { Value = st.hover and base + 6 or base }, Enum.EasingStyle.Quad)
		end
		local function setDotHover(k)
			for j, st in ds do
				local on = j == k
				if st.hover ~= on then st.hover = on; target(j) end
			end
		end
		-- the slide moves out one way while the next comes in from the other (t0071), 0.25 s, in Scale
		local function show(i, dir)
			if i == sel then return end
			dir = dir or (i > sel and 1 or -1)
			local old, nw, prev = slides[sel], slides[i], sel
			sel = i
			target(prev); target(i); layout()
			nw.Position = UDim2.fromScale(dir * 1.03, 0)
			nw.Visible = true
			Kit.tween(nw, 0.25, { Position = UDim2.fromScale(0, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			Kit.tween(old, 0.25, { Position = UDim2.fromScale(-dir * 1.03, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			task.delay(0.26, function() if slides[sel] ~= old then old.Visible = false end end)
		end
		dots.MouseLeave:Connect(function() setDotHover(nil) end)
		for k, st in ds do
			st.v.Changed:Connect(layout)
			st.f.MouseEnter:Connect(function() setDotHover(k) end)
			st.f.Activated:Connect(function() show(k) end)
		end
		so.MouseEnter:Connect(function() paused = true end)
		so.MouseLeave:Connect(function() paused = false end)
		if P then table.insert(P.post, function() kx = dots.Size.X.Scale / W0; layout() end) end
		task.spawn(function()
			while so.Parent do
				task.wait(6)
				if so.Parent and isOpen and tab == "Featured" and not paused then show(sel % N + 1, 1) end
			end
		end)
	end

	-- item tiles (3x2 at 801 + col*162, 381 + row*159): 126 rarity tiles, the render spilling over the top, the yellow scissors
	-- price overlapping the foot
	local rest = {}
	for i = 4, #gear do table.insert(rest, gear[i]) end
	if #rest < 6 then
		for _, id in sortedGear() do
			if #rest >= 6 then break end
			if not table.find(rest, id) and not table.find(gear, id, 1) then table.insert(rest, id) end
		end
	end
	for i = 1, math.min(6, #rest) do
		local id = rest[i]
		local c, r = (i - 1) % 3, (i - 1) // 3
		local h = hold(801 + c * 162, 381 + r * 159, 126, 152, 1.06, function() ctx.openKit(id) end)
		rarityTile(h, rarityColor(id), 0, 0, 126, 126, 1)
		local art = new("Frame", { Name = "Art", BackgroundTransparency = 1, Position = UDim2.fromOffset(-8, -24), Size = UDim2.fromOffset(142, 140), ZIndex = 3, Parent = h })
		turnOnHover(h, lit(itemArt(art, id, nil, 1.1)))
		priceTag(h, "kit", Config.Items[id].Price, 63, 108, 100, 44, function() ctx.openKit(id) end, { owned = function() return ctx.owns(id) end, noHover = true })
		if ctx.tooltip then
			local item = Config.Items[id]
			ctx.tooltip(h, item.Name, function() return item.Desc or "" end)
		end
	end
	endPad(pg, 740)
end

-- Bundles (t0068.4s): the Founder's Bundle as the 1242x399 hero, then the scissors bundles in RIVALS' 3-wide / 2-wide rows
function RENDER.Bundles(pg, hover)
	local Config = ctx.Config
	local y = 2
	local featured = founderProduct()
	if featured then
		bundleCard(pg, hover, founderSpec(featured), 12, y, 1242, 399, true)
		y = 444
	end
	local list = Config.Bundles or {}
	local i, row = 1, 0
	while i <= #list do
		local cols = row % 2 == 0 and 3 or 2
		local w, step = cols == 3 and 389 or 602, cols == 3 and 426.5 or 640
		for c = 0, cols - 1 do
			local bd = list[i]
			if not bd then break end
			bundleCard(pg, hover, bundleSpec(bd), 12 + c * step, y, w, 262, false)
			i += 1
		end
		y += 299
		row += 1
	end
	endPad(pg, y)
end

-- Arms: the Daily-shop grid (t0094-t0099): 5 rarity tiles per row with a 6 px gap, the name across the top, the render
-- spilling out, the yellow scissors price overlapping the foot (opens the Kit room), the white tooltip on hover
function RENDER.Arms(pg, hover)
	local Config = ctx.Config
	local cols, gap = 5, 6
	local w, h = (1242 - gap * (cols - 1)) / cols, 190
	for i, id in sortedGear() do
		local item = Config.Items[id]
		local c, r = (i - 1) % cols, (i - 1) // cols
		local card = rarityTile(pg, rarityColor(id), 12 + c * (w + gap), 26 + r * (h + 34), w, h, 1, "TextButton")
		card.Name = id
		local art = new("Frame", { Name = "Art", BackgroundTransparency = 1, Position = UDim2.fromOffset(w * 0.06, 8), Size = UDim2.fromOffset(w * 0.88, h - 24), ZIndex = 3, Parent = card })
		turnOnHover(card, lit(itemArt(art, id, nil, 1.15)))
		stroke(RK.label({ Text = item.Name, FontFace = FB, TextSize = 26, TextXAlignment = CENTER, Position = UDim2.fromOffset(8, 6), Size = UDim2.fromOffset(w - 16, 32), ZIndex = 4, Parent = card }), 2, 0.3)
		priceTag(card, "kit", item.Price, w / 2, h - 30, 130, 46, function() ctx.openKit(id) end, { owned = function() return ctx.owns(id) end, z = 6, noHover = true })
		hover(card)
		card.Activated:Connect(function() if not ctx.owns(id) then ctx.openKit(id) end end)
		if ctx.tooltip then
			ctx.tooltip(card, item.Name, function()
				return (item.Desc or "") .. (ctx.owns(id) and "\nYou own this." or `\nUnlock it in the Kit room for {fmtN(item.Price)} scissors.`)
			end)
		end
	end
	endPad(pg, 26 + math.ceil(#sortedGear() / cols) * (h + 34))
end

-- Scissors = RIVALS' Keys tab (t0084.0s): 3-wide then 2-wide gold cards (the biggest pack red), a giant cropped scissors
-- render as the backdrop, the name and a huge "+ N" top left, the lime Robux price bottom right (a pack's Tag as the red
-- badge over it). Then a "Passes" header bar and the passes as Season-Pass-grey 602-wide cards.
function RENDER.Scissors(pg, hover)
	local Config = ctx.Config
	local packs = {}
	for _, p in Config.RobuxProducts do if not p.Bundle then table.insert(packs, p) end end
	local y, i, row = 4, 1, 0
	while i <= #packs do
		local cols = row % 2 == 0 and 3 or 2
		local w, step = cols == 3 and 389 or 602, cols == 3 and 426.5 or 640
		for c = 0, cols - 1 do
			local p = packs[i]
			if not p then break end
			local top = i == #packs and #packs > 1
			local spec = packSpec(p)
			local card = new("TextButton", { Name = p.Key, Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(12 + c * step, y), Size = UDim2.fromOffset(w, 262),
				BackgroundColor3 = WHITE, BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 1, Parent = pg }, { RK.corner(8),
				RK.vgrad(top and { C.red, C.redDark:Lerp(BLACK, 0.3) } or { C.gold, C.gold:Lerp(BLACK, 0.45) }) })
			local back = new("Frame", { Name = "Backdrop", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(w * 0.62, 150),
				Size = UDim2.fromOffset(w * 1.05, w * 1.05), ZIndex = 2, Parent = card })
			local bvp = lit(ViewIcons.Viewport(back, ViewIcons.Scissors(), { view = CFrame.Angles(0, 0, math.rad(-35)) * ViewIcons.Views.Scissors[1], zoom = 1.15, zIndex = 2 }))
			turnOnHover(card, bvp)
			stroke(RK.label({ Text = p.Name, FontFace = FX, TextSize = 36, Position = UDim2.fromOffset(24, 18), Size = UDim2.fromOffset(w - 40, 46), ZIndex = 4, Parent = card }), 2, 0.45)
			stroke(RK.label({ Text = "+ " .. fmtN(p.Credits or 0), FontFace = FX, TextSize = 64, Position = UDim2.fromOffset(24, 58), Size = UDim2.fromOffset(w - 40, 76), ZIndex = 4, Parent = card }), 2.5, 0.45)
			local pw = w > 500 and 200 or 155
			if p.Tag then valueTag(card, w - 20 - pw / 2, 177 - 46, string.upper(p.Tag), w > 500 and 150 or 130, 32, 19, 6) end
			local function open() openDetail(spec) end
			priceTag(card, "robux", p.Robux, w - 20 - pw / 2, 177, pw, 64, open, { ts = 42, isz = 38, z = 8, noHover = true })
			hover(card)
			card.Activated:Connect(open)
			i += 1
		end
		y += 300
		row += 1
	end
	headerBar(pg, "Passes", "Medal", y + 10)
	y += 10 + 62 + 30
	for k, gp in Config.GamePasses do
		local spec = passSpec(gp)
		local c, r = (k - 1) % 2, (k - 1) // 2
		local w, h = 602, 262
		local card = new("TextButton", { Name = gp.Key, Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(12 + c * 640, y + r * 300), Size = UDim2.fromOffset(w, h),
			BackgroundColor3 = WHITE, BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 1, Parent = pg },
			{ RK.corner(8), new("UIGradient", { Rotation = 35, Color = ColorSequence.new(G.grey[1], G.grey[2]:Lerp(BLACK, 0.45)) }) })
		local art = new("Frame", { Name = "Art", BackgroundTransparency = 1, Position = UDim2.fromOffset(w * 0.5, -h * 0.12), Size = UDim2.fromOffset(h * 1.25, h * 1.25), ZIndex = 2, Parent = card })
		turnOnHover(card, lit(ViewIcons.Icon(art, "Medal", { zoom = 1.1, zIndex = 2 })))
		heavyTitle(card, gp.Name, 40, 24, 18, w - 48, 48, 5)
		stroke(RK.label({ Text = gp.Desc or "", FontFace = FM, TextSize = 22, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(26, 74), Size = UDim2.fromOffset(w * 0.52, 110), ZIndex = 5, Parent = card }), 1.5, 0.45)
		local function open() if not spec.owned() then openDetail(spec) end end
		priceTag(card, "robux", gp.Robux, w - 120, 177, 200, 64, open, { owned = spec.owned, ts = 42, isz = 38, z = 8, noHover = true })
		hover(card)
		card.Activated:Connect(open)
	end
	endPad(pg, y + math.ceil(#Config.GamePasses / 2) * 300)
end

-------------------------------------------------------------------------------
-- (2026-10-21, RIVALS 1:1) Detail card = the replica's offer popup (t0074): the shop page hides behind a 0.35 black dim
-- (wallet dimmed under it), an 818x551 box in the item's colour (dark gradient) at 551,231 with the 76 px title top left
-- (gold + sparkle for bundles), the contents as rarity tiles / the pack or pass art; UNDER the box the red X (251x110 at
-- 676,845) and the price (251x110 at 1117,845) with the "xN VALUE" badge over it. It appears at once (no pop-in, RIVALS).
-- Buy: the price shows Kit.busy's three dots (t0073.4s) until ctx.ask returns, then the card closes and the "Purchase
-- Complete" banner drops in (scissors at once; Robux once the purchase lands, see Refresh), or the button shakes (refused).
-------------------------------------------------------------------------------
local detail -- { layer, update }
local function closeDetail()
	if detail then
		local d = detail
		detail = nil
		d.layer:Destroy()
		if body then body.Visible = true end
	end
end
openDetail = function(spec)
	closeDetail()
	if not canvasF then return end
	local items = spec.items or {}
	local layer = new("Frame", { Name = "ShopDetail", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 30, Parent = canvasF })
	local dim = new("TextButton", { Name = "Dim", Text = "", AutoButtonColor = false, BackgroundColor3 = BLACK, BackgroundTransparency = 0.35, BorderSizePixel = 0,
		Position = UDim2.fromOffset(-2000, -2000), Size = UDim2.fromOffset(1920 + 4000, 1080 + 4000), Parent = layer })
	dim:AddTag("Nonapplicable")
	local W, H = 818, 551
	local tint = spec.color or C.panelRaised
	local box = new("Frame", { Name = "Card", Position = UDim2.fromOffset(551, 231), Size = UDim2.fromOffset(W, H), BackgroundColor3 = WHITE, BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 2, Parent = layer },
		{ RK.corner(6), new("UIGradient", { Rotation = 90, Color = ColorSequence.new(tint:Lerp(BLACK, 0.25), tint:Lerp(BLACK, 0.55)) }) })
	local title = heavyTitle(box, spec.title or "", 76, 52, 34, 740, 90, 3)
	if #items > 0 and spec.kind ~= "robux" then goldTitle(title) end
	local updaters = {}
	if #items > 0 then
		-- the bundle's items: rarity tiles 125 (names on their foot, a check on the ones you own), extras below
		local sz = math.min(125, (W - 60) / #items - 20)
		contentsRow(box, items, 30, 160, sz, 20, 2, updaters)
		if spec.credits then extraScissors(box, spec.credits, 60, 330, 120, 2) end
	else
		-- a pack / pass: its 3D art in the middle, "×N" or the description under it
		local art = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(W / 2, 128), Size = UDim2.fromOffset(300, 200), ZIndex = 2, Parent = box })
		if spec.icon == "Scissors" then
			scissorsPile(art, 3, 300, 200, 2, 18)
		else
			lit(ViewIcons.Icon(art, spec.icon or "Medal", { zIndex = 2 }))
		end
		if spec.credits then
			countLabel(box, spec.credits, 40, 330, W - 80, 84, 74, 3)
		elseif spec.desc then
			stroke(RK.label({ Text = spec.desc, FontFace = FM, TextSize = 30, TextXAlignment = CENTER, TextWrapped = true, Position = UDim2.fromOffset(50, 340),
				Size = UDim2.fromOffset(W - 100, 110), ZIndex = 3, Parent = box }), 1.5, 0.45)
		end
	end
	local x = Kit.closeButton(UDim2.fromOffset(251, 110))
	x.Position = UDim2.fromOffset(676, 845)
	x.ZIndex = 3
	x.Parent = layer
	local value = spec.value and spec.value()
	local badge = value and ("x" .. value .. " VALUE") or (spec.tag and string.upper(spec.tag))
	if badge then valueTag(layer, 1117, 768, badge, 226, 54, 32, 4) end
	local buy, upd, row = priceTag(layer, spec.kind == "robux" and "robux" or "scissors", spec.amount() or 0, 1117, 845, 251, 110, nil,
		{ owned = spec.owned, amount = spec.amount, ts = 70, isz = 56, z = 3 })
	Kit.bindButton(buy, { hover = 1.05 })
	local function short()
		return spec.kind == "scissors" and (data().Credits or 0) < (spec.amount() or 0)
	end
	local function update()
		upd()
		for _, f in updaters do f() end
	end
	Kit.toScale(layer)
	body.Visible = false
	Kit.sfx("open")
	local me = { layer = layer, update = update }
	detail = me
	local function close() if detail == me then closeDetail() end end
	x.Activated:Connect(close)
	dim.Activated:Connect(close)
	buy.Activated:Connect(function()
		if buying or (spec.owned and spec.owned()) then return end
		if short() then
			shakeOnce(buy)
			local ok = pcall(Toast.show, { title = "Not Enough Scissors", text = "Get more in the Scissors tab!" })
			if not ok and ctx.toast then ctx.toast("Not enough scissors", "bad") end
			return
		end
		buying = true
		row.Visible = false -- the dots sit alone on the button (t0073.4s)
		local stop = Kit.busy(buy)
		task.spawn(function()
			local ok, res = pcall(spec.buy)
			buying = false
			stop()
			row.Visible = not (spec.owned and spec.owned())
			if ok and res and res.ok then
				if spec.kind == "robux" then
					pending = { spec = spec, credits = data().Credits or 0, at = os.clock() } -- Roblox's prompt is up; Refresh banners it
				else
					purchaseComplete(spec)
				end
				close()
			elseif detail == me then
				update()
				shakeOnce(buy)
			end
		end)
	end)
end

-------------------------------------------------------------------------------
-- Frame
-------------------------------------------------------------------------------
-- the zoom = each live 3D icon filling the same 60x60 box that rises out of its tab
local TABS = { { "Featured", "Medal", 0.95 }, { "Bundles", "Crate", 1.1 }, { "Arms", "Weapon", 1.35 }, { "Scissors", "Scissors", 1.4 } }

local function build()
	gui = new("ScreenGui", { Name = "ShopUI2", IgnoreGuiInset = true, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 25, Enabled = false, Parent = Players.LocalPlayer:WaitForChild("PlayerGui") })
	gui:SetAttribute("NoStyle", true)
	blur = Lighting:FindFirstChild("MenuUIBlur") or new("BlurEffect", { Name = "MenuUIBlur", Size = 0, Parent = Lighting })
	scrim = new("Frame", { Name = "Scrim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.scrim, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = gui })
	local canvas = Kit.canvas(gui)
	canvasF = canvas -- the detail card's layer goes here, over root
	root = new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = canvas })
	body = new("Frame", { Name = "Body", BackgroundTransparency = 1, Size = UDim2.fromOffset(1920, 1080), Parent = root })

	-- (2026-10-21, RIVALS 1:1) the tab row (replica): separate 144x48 pills 12 apart, centred, black at 0.35, the selected
	-- one white; a big 3D icon rises out of each (60 box, its foot 16 px into the pill); the Bold 27 label sits low with a
	-- black outline (also on the white tab, t0068.4s). The red X follows the row.
	local x0 = (1920 - (#TABS * TAB_STEP + 86)) / 2
	for i, t in TABS do
		local b = new("TextButton", { Name = t[1], Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(x0 + (i - 1) * TAB_STEP, TAB_Y), Size = UDim2.fromOffset(TAB_W, TAB_H),
			BackgroundColor3 = BLACK, BackgroundTransparency = 0.35, BorderSizePixel = 0, Parent = body }, { RK.corner(6) })
		local hold = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(TAB_W / 2, 32), Size = UDim2.fromOffset(60, 60), ZIndex = 2, Parent = b })
		local vp
		if t[2] == "Weapon" then
			vp = ViewIcons.Viewport(hold, ViewIcons.Weapon("AutoRifle"), { view = ViewIcons.GunView, zoom = t[3], zIndex = 2 })
		else
			vp = ViewIcons.Icon(hold, t[2], { zoom = t[3], zIndex = 2 })
		end
		b.MouseEnter:Connect(function() vp.SetHover(true) end)
		b.MouseLeave:Connect(function() vp.SetHover(tab == t[1]) end)
		stroke(RK.label({ Name = "Label", Text = t[1], FontFace = FB, TextSize = 27, TextXAlignment = CENTER, Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 32), ZIndex = 3, Parent = b }), 2.5, 0)
		Kit.bindButton(b, { hover = 1.05 })
		b.Activated:Connect(function() Screen.SetTab(t[1]) end)
		tabBtns[t[1]] = { b = b, vp = vp }
	end
	local close = Kit.closeButton(UDim2.fromOffset(86, 48))
	close.Position = UDim2.fromOffset(x0 + #TABS * TAB_STEP, TAB_Y)
	close.Parent = body
	close.Activated:Connect(function() Screen.Close() end)

	-- (2026-10-21, RIVALS 1:1) wallet, top centre (replica): the currency render, a black 0.45 count pill, the lime "+"
	local wallet = new("Frame", { Name = "Wallet", BackgroundTransparency = 1, Position = UDim2.fromOffset(856, 30), Size = UDim2.fromOffset(208, 60), Parent = root })
	new("ImageLabel", { BackgroundTransparency = 1, Image = SCISSORS_IMG, ScaleType = Enum.ScaleType.Fit, Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(60, 60), ZIndex = 3, Parent = wallet })
	local pill = new("Frame", { Name = "Pill", Position = UDim2.fromOffset(48, 10), Size = UDim2.fromOffset(108, 40), BackgroundColor3 = BLACK, BackgroundTransparency = 0.45, BorderSizePixel = 0, Parent = wallet }, { RK.corner(4) })
	walletText = RK.label({ Name = "Count", Text = "0", FontFace = FB, TextSize = 30, TextXAlignment = CENTER, Position = UDim2.fromOffset(12, 0), Size = UDim2.fromOffset(84, 40), Parent = pill })
	local plus = new("TextButton", { Name = "AddScissors", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(157, 15), Size = UDim2.fromOffset(31, 31), BackgroundColor3 = WHITE,
		BorderSizePixel = 0, ZIndex = 2, Parent = wallet }, { RK.corner(4), RK.vgrad(G.robux) })
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(17, 6), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 3, Parent = plus }, { RK.corner(2) })
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(6, 17), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 3, Parent = plus }, { RK.corner(2) })
	Kit.bindButton(plus, { hover = 1.12 })
	plus.Activated:Connect(function() Screen.SetTab("Scissors") end)

	pageHolder = new("Frame", { Name = "Pages", BackgroundTransparency = 1, Position = UDim2.fromOffset(PAGE_X, PAGE_Y), Size = UDim2.fromOffset(PAGE_W, PAGE_H), Parent = body })
	Kit.toScale(root)
	root.Visible = false
	-- the wallet pill pops from its centre when the count changes
	walletPill = pill
	Kit.centreAnchor(pill)
	-- (standing rule) the three loading dots, shown if the shop is opened before its pages are built
	loader = Kit.loadingDots(canvas)
	loader.Visible = false

	GuiService.MenuOpened:Connect(function() if isOpen then root.Visible = false end end)
	GuiService.MenuClosed:Connect(function() if isOpen and ready then Kit.open(root) end end)
end

-- one persistent ScrollingFrame per tab. Built at join (Init) and again only when a tab is shown while its page is dirty
-- (what you own changed since it was built). Everything else updates in place via its updaters.
local function buildPage(t)
	local old = pages[t]
	if old and old.pg then old.pg:Destroy() end
	local pg = new("ScrollingFrame", {
		Name = t, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = true, Visible = false,
		ScrollBarThickness = 10, ScrollBarImageColor3 = BLACK, ScrollBarImageTransparency = 0.45, -- (2026-10-21, RIVALS 1:1) the replica's black bar
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = pageHolder,
	})
	local P = { pg = pg, updaters = {}, post = {}, sig = ownedSig(), dirty = false }
	pages[t] = P
	curPage = P
	local ok, err = pcall(RENDER[t], pg, pageSpotlight(pg))
	curPage = nil
	if not ok then
		warn("[ShopScreen] building " .. t .. " failed: " .. tostring(err))
		P.dirty = true -- try again next time it's shown
	end
	Kit.toScale(pageHolder, Vector2.new(PAGE_W, PAGE_H))
	for _, f in P.post do pcall(f) end
	return P
end

-- the wallet counts up (Kit.countTo) and its pill pops; snaps while the shop is closed
local function updateWallet()
	local c = data().Credits or 0
	if shownCredits ~= nil and isOpen and c ~= shownCredits then
		Kit.countTo(walletText, shownCredits, c, 0.4, fmtN)
		Kit.pop(walletPill, 1.12)
	else
		Kit.countTo(walletText, c, c, 0, fmtN) -- (also cancels a count still running)
	end
	shownCredits = c
end

-- (2026-10-21, RIVALS 1:1) the selected tab is white, the rest black at 0.35 (replica selectTab); its 3D icon stays turned
-- toward you. The round-3 icon growth / pop and the label recolour are gone (RIVALS keeps the white label + outline).
local function styleTabs()
	for name, t in tabBtns do
		local on = name == tab
		t.b.BackgroundColor3 = on and WHITE or BLACK
		t.b.BackgroundTransparency = on and 0 or 0.35
		if t.vp then t.vp.SetHover(on) end
	end
end

-- (2026-10-21, RIVALS 1:1) show the current tab's page (rebuilding it first if dirty). RIVALS swaps pages at once: the
-- round-3 slide-in and staggered tile pop-in are gone.
local function showTab()
	local P = pages[tab]
	if not P or P.dirty or P.sig ~= ownedSig() then P = buildPage(tab) end
	for name, Q in pages do Q.pg.Visible = name == tab end
	P.pg.Position = UDim2.fromScale(0, 0)
	styleTabs()
end

-- no rebuild here: wallet + every tag / owned mark update in place. Pages whose owned set changed are marked dirty and
-- rebuilt when next shown (showTab), never under the cursor.
function Screen.Refresh()
	if not gui then return end
	updateWallet()
	-- (2026-10-21, RIVALS 1:1) a Robux buy lands (credits went up / the pass or bundle is now owned): Purchase Complete
	if pending then
		local p = pending
		if os.clock() - p.at > 180 then
			pending = nil
		elseif (p.spec.owned and p.spec.owned()) or (p.spec.credits and (data().Credits or 0) > p.credits) then
			pending = nil
			purchaseComplete(p.spec)
		end
	end
	if not ready then return end
	local sig = ownedSig()
	for _, P in pages do
		if P.sig ~= sig then P.dirty = true end
		for _, f in P.updaters do f() end
	end
	if detail then detail.update() end
end

function Screen.SetTab(t)
	if t == "Home" then t = "Featured" end
	if not RENDER[t] then t = "Featured" end
	tab = t
	if ready and isOpen then showTab() end
end

local function setOpen(on)
	if on == isOpen then return end
	isOpen = on
	Kit.tween(blur, 0.25, { Size = on and Theme.blur or 0 })
	Kit.tween(scrim, 0.25, { BackgroundTransparency = on and Theme.alpha.scrim or 1 })
	if on then
		gui.Enabled = true
		if ctx.onOpen then ctx.onOpen() end
		updateWallet()
		if ready then
			Screen.Refresh()
			showTab()
			Kit.open(root)
		else
			-- (standing rule) opened before the join build finished: dots until it's ready
			loader.Visible = true
			task.spawn(function()
				while not ready and isOpen do task.wait() end
				loader.Visible = false
				if isOpen then Screen.Refresh(); showTab(); Kit.open(root) end
			end)
		end
	else
		closeDetail()
		loader.Visible = false
		Kit.close(root, function() if not isOpen then gui.Enabled = false end end)
		if ctx.onClose then ctx.onClose() end
	end
end

-- (standing rule) every page is built here, at join (the lobby calls Init from its menu prewarm), so opening the shop or
-- switching tabs only toggles Visible
function Screen.Init(context)
	ctx = context or {}
	if not gui then
		build()
		for _, t in TABS do
			buildPage(t[1])
			task.wait() -- spread the viewport builds over a few frames
		end
		ready = true
	end
end
function Screen.Open(startTab)
	if startTab then
		tab = startTab == "Home" and "Featured" or startTab
		if not RENDER[tab] then tab = "Featured" end
	end
	if isOpen then
		if ready then Screen.Refresh(); showTab() end
	else
		setOpen(true)
	end
end
function Screen.Close() if gui then setOpen(false) end end
function Screen.IsOpen() return isOpen end

return Screen
