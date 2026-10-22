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
local RunService = game:GetService("RunService") -- (2026-10-21, round 3: match RIVALS) one Heartbeat drives the bobbing callouts

local UIKit = script.Parent
local Theme = require(UIKit:WaitForChild("Theme"))
local Kit = require(UIKit:WaitForChild("Kit"))
local ViewIcons = require(UIKit:WaitForChild("ViewIcons"))
local Tac = require(UIKit:WaitForChild("Tac")) -- pass 34 deployment-board look
local C, F, new = Theme.color, Theme.font, Kit.new

-- (2026-10-21) price-tag currency glyph = the flat cream scissors (art batch 1). RIVALS' price tags use flat currency glyphs
-- (key / Robux / token, t0070); the old render of the 3D scissors was id 120480559804238
local SCISSORS_IMG = "rbxassetid://117873069678184"
local ROBUX_IMG = "rbxasset://textures/ui/common/robux.png"

local Screen = {}
local ctx = {}
local gui, root, blur, scrim, pageHolder, walletText, walletPill, canvasF, loader
local tab = "Featured"
local isOpen = false
local tabBtns = {}
-- (2026-10-21, RIVALS pass) pages are built once (at join) and kept: each priceTag registers an update() on the page being
-- built, Refresh runs those in place. A page is only rebuilt on a tab switch / open, and only when what you own changed.
local pages = {} -- tab -> { pg, updaters, post, sig, dirty }
local curPage -- the page RENDER is filling right now
local ready = false -- all pages built (the shop opens behind the loading dots until then)
local buying = false -- (2026-10-21, RIVALS pass) one purchase in flight at a time: replaces pending/pendingAt (no double buys)
local shownCredits
local openDetail -- forward: the detail card (defined below the cards)

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
-- (2026-10-21, RIVALS pass) Kit.shake reads the current Position as its base, so a second shake mid-shake would drift: one at a time
local function shakeOnce(g)
	if g:GetAttribute("Shaking") then return end
	g:SetAttribute("Shaking", true)
	Kit.shake(g)
	task.delay(0.25, function() g:SetAttribute("Shaking", nil) end)
end
-- (2026-10-21, RIVALS pass) what the pages were built from: owned gear + passes (+ the hover setting); a change marks pages dirty
local function ownedSig()
	local d, parts = data(), {}
	if ctx.Config then for id in ctx.Config.Items do if ctx.owns(id) then table.insert(parts, id) end end end
	for k, v in d.Passes or {} do if v then table.insert(parts, "P:" .. k) end end
	table.sort(parts)
	return table.concat(parts, ",") .. "|" .. tostring(ctx.getSetting and ctx.getSetting("ShopHover"))
end
-- (2026-10-21, RIVALS pass) owned = a cream check on a dark round plate (two bars, like the close X). Solid fill, no stroke.
-- Built in design px (before toScale). Could move to Kit later if other screens want the same check.
local function checkMark(parent, s, props)
	local plate = new("Frame", { Name = "Check", BackgroundColor3 = C.plate, BorderSizePixel = 0, Size = UDim2.fromOffset(s, s), ZIndex = 7, Parent = parent },
		{ new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	for k, v in props or {} do plate[k] = v end
	local th = math.max(3, math.floor(s * 0.14))
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(s * 0.36, s * 0.56), Size = UDim2.fromOffset(math.floor(s * 0.3), th),
		Rotation = 45, BackgroundColor3 = C.cream, BorderSizePixel = 0, ZIndex = plate.ZIndex + 1, Parent = plate })
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(s * 0.56, s * 0.48), Size = UDim2.fromOffset(math.floor(s * 0.52), th),
		Rotation = -50, BackgroundColor3 = C.cream, BorderSizePixel = 0, ZIndex = plate.ZIndex + 1, Parent = plate })
	return plate
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

-- (2026-10-21, round 3: match RIVALS) RIVALS' bundle banners and hero cards (t0068.4s, t0072.0s) are ONE posed render of the
-- bundle's items, big and cropped by the card edge. Ours: one live viewport holding all the items fanned out, each scaled to
-- the same size, zoomed in so the card (ClipsDescendants) crops them. One viewport per banner instead of one per item.
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

-- (2026-10-21, round 3: match RIVALS) every tile reacts like RIVALS' shop tiles (t0083.9s hover): on hover the 3D item lifts,
-- grows and turns toward you (vp.SetHover), optionally tilts; on press it squashes, then springs back. `art` gets its own
-- UIScale (the card's UIScale belongs to bindButton). Positions are read after Kit.toScale (lift in Scale of the parent).
-- tilt = false for art inside a clipped card: Roblox does not clip rotated descendants.
local function reactArt(target, art, vp, tilt)
	local s = art:FindFirstChildOfClass("UIScale") or new("UIScale", { Name = "ArtScale", Parent = art })
	local base, rot0, hov = nil, nil, false
	local function lift(on)
		base = base or art.Position
		rot0 = rot0 or art.Rotation
		hov = on
		local dy = on and art.Size.Y.Scale * 0.06 or 0
		local goal = { Position = UDim2.new(base.X.Scale, base.X.Offset, base.Y.Scale - dy, base.Y.Offset) }
		if tilt ~= false then goal.Rotation = rot0 + (on and -5 or 0) end
		Kit.tween(art, 0.2, goal, Enum.EasingStyle.Back)
		Kit.tween(s, 0.2, { Scale = on and 1.08 or 1 }, Enum.EasingStyle.Back)
		if vp then vp.SetHover(on) end
	end
	target.MouseEnter:Connect(function() lift(true) end)
	target.MouseLeave:Connect(function() lift(false) end)
	target.SelectionGained:Connect(function() lift(true) end)
	target.SelectionLost:Connect(function() lift(false) end)
	if target:IsA("GuiButton") then
		target.MouseButton1Down:Connect(function() Kit.tween(s, 0.06, { Scale = 0.88 }) end)
		target.MouseButton1Up:Connect(function() Kit.tween(s, 0.22, { Scale = hov and 1.08 or 1 }, Enum.EasingStyle.Back) end)
	end
end

-- (2026-10-21, round 3: match RIVALS) RIVALS' "xN VALUE" / "Limited" stickers sit tilted and keep moving (t0072.0s, t0081.0s).
-- Ours rock a few degrees around their own rotation; one Heartbeat for all of them, idle while the shop is closed.
local wobbles, wobbleConn = {}, nil
local function wobble(g, amp)
	table.insert(wobbles, { g = g, base = g.Rotation, amp = amp or 3, t = math.random() * 6 })
	if wobbleConn then return g end
	wobbleConn = RunService.Heartbeat:Connect(function()
		if not isOpen then return end
		local now = os.clock()
		for i = #wobbles, 1, -1 do
			local w = wobbles[i]
			if not w.g.Parent then table.remove(wobbles, i)
			elseif w.g.Visible then w.g.Rotation = w.base + math.sin(now * 2.4 + w.t) * w.amp end
		end
	end)
	return g
end

-- (2026-10-21, round 3: match RIVALS) the red "xN value" sticker, sat just above the price like RIVALS' bundle banners
local function valueSticker(parent, value, cx, bottomY, ts)
	ts = ts or 26
	return wobble(new("TextLabel", { Name = "Value", BackgroundColor3 = C.red, Text = "x" .. value .. " VALUE", FontFace = F.display, TextSize = ts, TextColor3 = C.white,
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(cx, bottomY), Size = UDim2.fromOffset(0, math.floor(ts * 1.45)), AutomaticSize = Enum.AutomaticSize.X,
		Rotation = -3, ZIndex = 8, Parent = parent }, { Kit.corner(4), Kit.pad(12, 0, 12, 0) }), 2.5)
end

-------------------------------------------------------------------------------
-- Price tag: amber (scissors) or green (Robux), number with a soft shadow, icon beside it (RIVALS)
-------------------------------------------------------------------------------
-- (2026-10-21, RIVALS pass) the tag is built once with both faces (price / owned) and returns update(): Refresh flips it
-- in place (owned, price, can't afford) instead of rebuilding the page. `live` = { owned = fn, amount = fn } for tags whose
-- state can change; without it the tag keeps the kind / amount it was built with. onBuy(tag) runs on click (no more
-- click-again "Confirm": scissors / Robux buys go through the detail card, Kit prices open the Kit room).
local function priceTag(parent, kind, amount, cx, y, w, h, onBuy, live)
	w, h = w or 150, h or 52
	live = live or {}
	-- (lobby revamp Phase B, Edward OK: no white pills / neon lime) scissors prices = a dark plate with cream words; Robux = field green
	local STEEL = { Theme.hex("#30342B"), Theme.hex("#171913") }
	local grad = Kit.vgrad(STEEL)
	-- (2026-10-21, AI-tells cleanup) no thin border: the solid gradient plate carries the tag on its own
	local tag = new("TextButton", { Name = "Price", Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(cx, y),
		Size = UDim2.fromOffset(w, h), BackgroundColor3 = C.white, ZIndex = 5, Parent = parent },
		{ Kit.corner(7), grad })
	local row = new("Frame", { Name = "BuyRow", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = tag },
		{ new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	-- (2026-10-21, round 3: match RIVALS) RIVALS' price pills are mostly number (t0068.4s: "520" fills the green button):
	-- the number goes 0.62 -> 0.72 of the tag height (callers also made the tags taller)
	local ts = math.floor(h * 0.72)
	local num = Kit.label({ LayoutOrder = 2, Text = "0", FontFace = F.display, TextSize = ts, TextColor3 = Color3.new(0, 0, 0), TextTransparency = 0.75,
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, h), ZIndex = 6, Parent = row })
	local txt = Kit.label({ Name = "Text", Text = "0", FontFace = F.display, TextSize = ts, TextColor3 = C.white,
		Position = UDim2.fromOffset(0, -2), Size = UDim2.fromScale(1, 1), ZIndex = 7, Parent = num })
	new("ImageLabel", { LayoutOrder = kind == "robux" and 1 or 3, BackgroundTransparency = 1, Image = kind == "robux" and ROBUX_IMG or SCISSORS_IMG, ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromOffset(math.floor(h * 0.66), math.floor(h * 0.66)), ZIndex = 6, Parent = row })
	-- owned face: the old grey "Owned" plate words + the new cream check beside them
	local ownRow = new("Frame", { Name = "OwnedRow", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5, Visible = false, Parent = tag },
		{ new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local check = checkMark(ownRow, math.floor(h * 0.62), { LayoutOrder = 1 })
	Kit.label({ LayoutOrder = 2, Text = "Owned", FontFace = F.display, TextSize = ts, TextColor3 = Theme.hex("#1C2026"),
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, h), ZIndex = 7, Parent = ownRow })
	-- (lobby revamp, graders: a 4,000 tag looked the same with 500 in the wallet) can't afford = the number goes red and the
	-- tag dims; it still opens the Kit / the detail card so you can see what it is
	local shortF = new("Frame", { Name = "Short", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.6, ZIndex = 5, Visible = false, Parent = tag },
		{ Kit.corner(7) })
	local st = { own = nil, short = false, amount = nil }
	local function update()
		local own = kind == "owned" or (live.owned and live.owned()) and true or false
		local amt = live.amount and live.amount() or amount or 0
		local steel = not own and kind ~= "robux"
		if own ~= st.own then
			local pair = own and Theme.gradient.grey or (kind == "robux" and Theme.gradient.robux or STEEL)
			grad.Color = ColorSequence.new(pair[1], pair[2])
			row.Visible, ownRow.Visible = not own, own
			if own and st.own == false then Kit.pop(check, 1.4) end -- just bought: the check lands
			st.own = own
		end
		if amt ~= st.amount then
			st.amount = amt
			num.Text, txt.Text = fmtN(amt), fmtN(amt)
		end
		local short = (kind == "scissors" or kind == "kit") and not own and (data().Credits or 0) < amt
		st.short = short
		shortF.Visible = short
		txt.TextColor3 = short and Theme.hex("#FF6A5E") or (steel and Theme.hex("#ECE6D2") or C.white)
	end
	update()
	if curPage then table.insert(curPage.updaters, update) end
	if onBuy and kind ~= "owned" then
		Kit.bindButton(tag, { hover = 1.06 })
		tag.Activated:Connect(function()
			update()
			if st.own then return end
			-- (2026-10-21, RIVALS pass) can't afford: the tag shakes, then it still shows you the item (Kit room / detail card)
			if st.short then
				shakeOnce(tag)
				task.delay(0.25, function() onBuy(tag) end)
				return
			end
			onBuy(tag)
		end)
	end
	return tag, update
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
-- (2026-10-21, RIVALS pass) what the detail card shows for each kind of buy. buy() returns ctx.ask's result: the same
-- ask("BuyBundle" / "BuyRobux" / "BuyPass") calls as before; Robux ones still make Roblox show its own prompt.
-------------------------------------------------------------------------------
local function bundleSpec(bd)
	local Config = ctx.Config
	return { title = bd.Name, tag = bd.Tag, items = bd.Items, kind = "scissors",
		amount = function() return (Config.BundleCost(bd, ctx.owns)) end,
		owned = function() local _, m = Config.BundleCost(bd, ctx.owns) return m == 0 end,
		buy = function() return ctx.ask("BuyBundle", bd.Id) end }
end
local function packSpec(pr)
	return { title = pr.Name or ("+" .. fmtN(pr.Credits or 0)), tag = pr.Tag, kind = "robux", icon = "Scissors", big = "+" .. fmtN(pr.Credits or 0) .. " scissors",
		amount = function() return pr.Robux end,
		buy = function() return ctx.ask("BuyRobux", pr.Key) end }
end
local function passSpec(gp)
	return { title = gp.Name, desc = gp.Desc, kind = "robux", icon = "Medal",
		amount = function() return gp.Robux end,
		owned = function() local d = data() return d.Passes and d.Passes[gp.Key] and true or false end,
		buy = function() return ctx.ask("BuyPass", gp.Key) end }
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
	local card = new("TextButton", { Name = id, Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = C.white, ClipsDescendants = false, Parent = pg },
		{ Kit.corner(2), -- (2026-10-21, AI-tells cleanup) thin rarity border removed: the 6 px RarityStripe on top carries it
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
	-- (2026-10-21, round 3: match RIVALS) shared reactArt: lift + tilt + turn on hover, squash on press (was grow + tilt only)
	reactArt(card, art, itemArt(art, id, nil), true)
	outlined(Kit.label({ Text = item.Name, FontFace = F.display, TextSize = 34, Position = UDim2.fromOffset(16, h - 120), Size = UDim2.fromOffset(w - 32, 40), Parent = card }), 2)
	Kit.label({ Text = string.upper(item.Rarity .. " " .. (Config.SlotNames[item.Slot] or item.Slot)), FontFace = F.bold, TextSize = 18, TextColor3 = rar.Color,
		Position = UDim2.fromOffset(16, h - 85), Size = UDim2.fromOffset(w - 32, 22), Parent = card })
	-- (2026-10-21, RIVALS pass) one live tag: it turns into the owned check in place when you unlock it
	priceTag(card, "kit", item.Price, w / 2, h - 62, w - 28, 54, function() ctx.openKit(id) end, { owned = function() return ctx.owns(id) end }) -- (round 3) 46 -> 54 tall
	hover(card)
	Tac.hoverBrackets(card, Tac.brackets(card, Tac.C.line, 20, 3))
	card.Activated:Connect(function() if not ctx.owns(id) then ctx.openKit(id) end end)
	if ctx.tooltip then
		ctx.tooltip(card, item.Name, function()
			return (item.Desc or "") .. (ctx.owns(id) and "\nYou own this." or `\nUnlock it in the Kit room for {fmtN(item.Price)} scissors.`)
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
	local col = bundle.Color or C.cream
	-- (2026-10-21, AI-tells cleanup) no thin border and no left AccentBar; the bundle colour stays in the diagonal stripe,
	-- tag pill cream (was the yellow accent), tiles get a rarity bar along the bottom instead of a thin stroke
	-- (2026-10-21, round 3: match RIVALS) RIVALS' Bundles tab (t0068.4s) = full-bleed banners: a coloured backdrop, the bundle's
	-- weapons as one big posed render cropped by the card, the title top left, "xN VALUE" sat on a big price button bottom
	-- right. Ours: the backdrop is the bundle's own colour fading to the panel, sceneArt = the live 3D render (right ~70 %),
	-- the 3D tiles stay small along the bottom left (they carry the OWNED marks), price 220x58 -> 260x74.
	local card = new("TextButton", { Name = bundle.Id, Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = C.white, ClipsDescendants = true, Parent = pg },
		{ Kit.corner(2), new("UIGradient", { Rotation = 20, Color = ColorSequence.new(col:Lerp(C.panel, 0.55), C.panel) }) })
	new("Frame", { BackgroundColor3 = col, BackgroundTransparency = 0.82, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(w * 0.75, h / 2), Size = UDim2.fromOffset(w * 0.25, h * 2), Rotation = 22, Parent = card })
	local scene = new("Frame", { Name = "Scene", BackgroundTransparency = 1, Position = UDim2.fromOffset(w * 0.34, -h * 0.12), Size = UDim2.fromOffset(w * 0.72, h * 1.24), ZIndex = 2, Parent = card })
	reactArt(card, scene, sceneArt(scene, bundle.Items, 1.3), false)
	outlined(Kit.label({ Text = bundle.Name, FontFace = F.display, TextSize = 50, Position = UDim2.fromOffset(22, 12), Size = UDim2.fromOffset(w - 40, 60), ZIndex = 5, Parent = card }), 3)
	if bundle.Tag then
		wobble(new("TextLabel", { BackgroundColor3 = C.cream, Text = bundle.Tag, FontFace = F.display, TextSize = 22, TextColor3 = C.textDark, Rotation = -2,
			Position = UDim2.fromOffset(24, 74), Size = UDim2.fromOffset(0, 32), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 5, Parent = card },
			{ Kit.corner(2), Kit.pad(10, 0, 10, 0) }), 2)
	end
	local tileW = math.min(96, (w * 0.45) / math.max(1, #bundle.Items) - 10)
	for j, id in bundle.Items do
		local tile = new("Frame", { Name = "Tile" .. j, BackgroundColor3 = C.panel, BackgroundTransparency = 0.35, Position = UDim2.fromOffset(22 + (j - 1) * (tileW + 10), h - tileW - 20),
			Size = UDim2.fromOffset(tileW, tileW), ZIndex = 4, Parent = card }, { Kit.corner(2) })
		new("Frame", { Name = "RarityBar", BackgroundColor3 = (Config.Rarities[Config.Items[id].Rarity] or Config.Rarities.Standard).Color, BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 5), ZIndex = 5, Parent = tile })
		itemArt(tile, id, card).Frame.ZIndex = 5
		-- (2026-10-21, RIVALS pass) always built, shown in place when you own the piece (no page rebuild)
		local ownedL = Kit.label({ Text = "OWNED", FontFace = F.display, TextSize = 16, TextColor3 = C.cream, TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -2), Size = UDim2.fromOffset(tileW, 20), ZIndex = 6, Visible = ctx.owns(id), Parent = tile })
		if curPage then table.insert(curPage.updaters, function() ownedL.Visible = ctx.owns(id) end) end
	end
	if full > cost and missing > 0 then
		valueSticker(card, math.max(2, math.floor(full / math.max(cost, 1) + 0.5)), w - 150, h - 100, 26)
	end
	-- (2026-10-21, RIVALS pass) the tag opens the detail card (no Confirm-in-place); price / owned update in place
	local live = { owned = function() local _, m = Config.BundleCost(bundle, ctx.owns) return m == 0 end, amount = function() return (Config.BundleCost(bundle, ctx.owns)) end }
	local function view() openDetail(bundleSpec(bundle)) end
	local tag = priceTag(card, "scissors", cost, w - 150, h - 92, 260, 74, view, live)
	tag.ZIndex = 7
	hover(card)
	Tac.hoverBrackets(card, Tac.brackets(card, Tac.C.line, 20, 3))
	card.Activated:Connect(function() if not live.owned() then view() end end)
	if ctx.tooltip then
		ctx.tooltip(card, bundle.Name, function()
			local cost, missing = Config.BundleCost(bundle, ctx.owns)
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

-- (2026-10-21, RIVALS pass) RENDER.<tab>(pg, hover) fills a page made by buildPage (below); pages are no longer wiped per refresh

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
function RENDER.Featured(pg, hover)
	local Config = ctx.Config
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
		-- (2026-10-21, RIVALS pass) packs open the detail card first; its button makes the same ask("BuyRobux")
		local hold = float(4 + (i - 1) * 166, 10, 158, 152, function() openDetail(packSpec(pr)) end)
		local n = math.min(i + 1, 4)
		-- (2026-10-21, round 3: match RIVALS) the pile sits in one Pile frame so it lifts / tilts / squashes as one (RIVALS'
		-- floating crates over their price pills, t0072.0s); "+N" bigger, price 116x46 -> 140x54
		local pile = new("Frame", { Name = "Pile", BackgroundTransparency = 1, Size = UDim2.fromOffset(158, 104), Parent = hold })
		for k = 1, n do
			local art = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(4 + (k - 1) * 10, (k - 1) * 4), Size = UDim2.fromOffset(150 - (n - 1) * 10, 100), Parent = pile })
			ViewIcons.Viewport(art, ViewIcons.Scissors(), { view = CFrame.Angles(0, 0, math.rad((k - (n + 1) / 2) * 22)) * ViewIcons.Views.Scissors[1], zoom = 1, still = true })
		end
		reactArt(hold, pile, nil, true)
		outlined(Kit.label({ Text = "+" .. fmtN(pr.Credits), FontFace = F.display, TextSize = 30, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 62), Size = UDim2.fromOffset(158, 34), ZIndex = 3, Parent = hold }), 2.5)
		priceTag(hold, "robux", pr.Robux, 79, 98, 140, 54, function() openDetail(packSpec(pr)) end)
	end
	-- left, bottom: gear you don't have, floating over its steel price
	local gear = {}
	for _, id in sortedGear() do if not ctx.owns(id) then table.insert(gear, id) end end
	for i = 1, math.min(3, #gear) do
		local id = gear[i]
		local hold = float(4 + (i - 1) * 166, 176, 158, 152, function() ctx.openKit(id) end)
		local art = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(-14, -16), Size = UDim2.fromOffset(186, 124), Parent = hold })
		reactArt(hold, art, itemArt(art, id, nil), true) -- (2026-10-21, round 3: match RIVALS) lift + tilt + squash; price 46 -> 54 tall
		priceTag(hold, "kit", Config.Items[id].Price, 79, 98, 154, 54, function() ctx.openKit(id) end, { owned = function() return ctx.owns(id) end })
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
		-- (2026-10-21, round 3: match RIVALS) the hero is THE focus of Home, like RIVALS' Season Pass card (t0072.0s): one big
		-- posed render cropped by the card (sceneArt, was three separate small viewports), a bigger title, the tag rocking,
		-- the scissors bonus with its 3D scissors, and the biggest price button on the page (170x58 -> 250x84).
		local scene = new("Frame", { Name = "Scene", BackgroundTransparency = 1, Position = UDim2.fromOffset(w * 0.28, -h * 0.08), Size = UDim2.fromOffset(w * 0.66, h * 1.16), ZIndex = 2, Parent = card })
		reactArt(card, scene, sceneArt(scene, items, 1.2), false)
		local sc = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(18, 124), Size = UDim2.fromOffset(100, 74), ZIndex = 4, Parent = card })
		ViewIcons.Icon(sc, "Scissors", { hoverTarget = card, zIndex = 4 })
		outlined(Kit.label({ Text = featured.Name, FontFace = F.display, TextSize = 56, Position = UDim2.fromOffset(28, 12), Size = UDim2.fromOffset(560, 66), ZIndex = 5, Parent = card }), 3)
		if featured.Tag then
			wobble(new("TextLabel", { BackgroundColor3 = C.red, Text = featured.Tag, FontFace = F.display, TextSize = 24, TextColor3 = C.white, ZIndex = 5, Rotation = -3,
				Position = UDim2.fromOffset(30, 80), Size = UDim2.fromOffset(0, 36), AutomaticSize = Enum.AutomaticSize.X, Parent = card }, { Kit.corner(4), Kit.pad(12, 0, 12, 0) }), 3)
		end
		outlined(Kit.label({ Text = "+" .. fmtN(featured.Credits or 0), FontFace = F.display, TextSize = 40, Position = UDim2.fromOffset(116, 138), Size = UDim2.fromOffset(300, 46), ZIndex = 5, Parent = card }), 2.5)
		-- (2026-10-21, RIVALS pass) live owned state; the hero's Robux buy is unchanged (straight to Roblox's prompt)
		local function ownedAll()
			for _, id in items do if not ctx.owns(id) then return false end end
			return true
		end
		local heroTag = priceTag(card, "robux", featured.Robux, w - 145, h - 100, 250, 84, function() ctx.ask("BuyRobux", featured.Key) end, { owned = ownedAll })
		heroTag.ZIndex = 7
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
		local sl = new("Frame", { Name = "Slide" .. i, BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 0), Size = UDim2.fromScale(1, 1), Visible = i == 1, Parent = so })
		-- (2026-10-21, round 3: match RIVALS) the offer slides are banners like RIVALS' Special Offer / Starter Bundle
		-- (t0072.0s, t0076.0s): words and a big price on the left, a big live 3D placeholder on the right cropped by the panel
		-- (was centred text, a 150 px medal and three small tiles). The medal / scene lift and turn while the panel is hovered.
		if of.kind == "pass" then
			local gp = of.p
			local art = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(575, 175), Size = UDim2.fromOffset(330, 330), Parent = sl })
			reactArt(so, art, ViewIcons.Icon(art, "Medal", { zoom = 1.25 }), false)
			outlined(Kit.label({ Text = gp.Name, FontFace = F.display, TextSize = 60, Position = UDim2.fromOffset(28, 14), Size = UDim2.fromOffset(420, 68), ZIndex = 3, Parent = sl }), 3)
			Kit.label({ Text = gp.Desc or "", FontFace = F.medium, TextSize = 24, TextColor3 = C.cream, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
				Position = UDim2.fromOffset(30, 86), Size = UDim2.fromOffset(400, 110), ZIndex = 3, Parent = sl })
			priceTag(sl, "robux", gp.Robux, 150, 220, 240, 76, function() openDetail(passSpec(gp)) end, { owned = passSpec(gp).owned }) -- (2026-10-21, RIVALS pass) detail card
		else
			local bd = of.b
			local cost = Config.BundleCost(bd, ctx.owns)
			local scene = new("Frame", { Name = "Scene", BackgroundTransparency = 1, Position = UDim2.fromOffset(300, -20), Size = UDim2.fromOffset(480, 370), Parent = sl })
			reactArt(so, scene, sceneArt(scene, bd.Items, 1.25), false)
			outlined(Kit.label({ Text = bd.Name, FontFace = F.display, TextSize = 52, Position = UDim2.fromOffset(28, 14), Size = UDim2.fromOffset(440, 62), ZIndex = 3, Parent = sl }), 3)
			if bd.Tag then
				wobble(new("TextLabel", { BackgroundColor3 = C.cream, Text = bd.Tag, FontFace = F.display, TextSize = 22, TextColor3 = C.textDark, Rotation = -2,
					Position = UDim2.fromOffset(30, 80), Size = UDim2.fromOffset(0, 32), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 3, Parent = sl },
					{ Kit.corner(2), Kit.pad(10, 0, 10, 0) }), 2)
			end
			local full = 0
			for _, id in bd.Items do full += Config.Items[id].Price end
			if full > cost and cost > 0 then valueSticker(sl, math.max(2, math.floor(full / cost + 0.5)), 150, 212, 24) end
			-- (2026-10-21, RIVALS pass) detail card instead of Confirm-in-place; price / owned live
			local spec = bundleSpec(bd)
			priceTag(sl, "scissors", cost, 150, 220, 240, 76, function() openDetail(spec) end, { owned = spec.owned, amount = spec.amount })
		end
		table.insert(slides, sl)
	end
	if #slides > 1 then
		local DOT, GAP = 14, 26
		local dotsW = #slides * GAP + 22
		local dots = new("Frame", { Name = "Dots", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(377, 690), Size = UDim2.fromOffset(dotsW, 28),
			BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, Parent = pg }, { Kit.corner(14) })
		local dl, cur, paused = {}, 1, false
		-- (2026-10-21, RIVALS pass) the slides slide (out one way, in from the other, 0.25 s) and the active dot is a wider
		-- pill. Runs after Kit.toScale, so everything moves in Scale (a slide is 1 x 1 of the clipped offer panel).
		local dotBase
		local function show(i, dir)
			if i == cur then return end
			dir = dir or (i > cur and 1 or -1)
			local old, nw = slides[cur], slides[i]
			cur = i
			nw.Position = UDim2.fromScale(dir, 0)
			nw.Visible = true
			Kit.tween(nw, 0.25, { Position = UDim2.fromScale(0, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			Kit.tween(old, 0.25, { Position = UDim2.fromScale(-dir, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			task.delay(0.26, function() if slides[cur] ~= old then old.Visible = false end end)
			dotBase = dotBase or dl[1].Size
			for k, dt in dl do
				Kit.tween(dt, 0.15, { BackgroundTransparency = k == i and 0 or 0.65,
					Size = k == i and UDim2.fromScale(dotBase.X.Scale * 1.9, dotBase.Y.Scale) or dotBase })
			end
		end
		for k = 1, #slides do
			local dt = new("TextButton", { Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(11 + (k - 0.5) * GAP, 14), Size = UDim2.fromOffset(DOT, DOT),
				BackgroundColor3 = C.white, BackgroundTransparency = k == 1 and 0 or 0.65, Parent = dots }, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
			Kit.bindButton(dt, { hover = 1.35 })
			dt.Activated:Connect(function() show(k) end)
			table.insert(dl, dt)
		end
		if curPage then table.insert(curPage.post, function() -- after toScale: the first dot starts as the wide pill
			dotBase = dl[1].Size
			dl[1].Size = UDim2.fromScale(dotBase.X.Scale * 1.9, dotBase.Y.Scale)
		end) end
		so.MouseEnter:Connect(function() paused = true end)
		so.MouseLeave:Connect(function() paused = false end)
		task.spawn(function()
			while so.Parent do
				task.wait(6)
				if so.Parent and isOpen and tab == "Featured" and not paused then show(cur % #slides + 1, 1) end
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
			{ Kit.corner(8), new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.panelRaised, C.panel) }) })
		-- (2026-10-21, AI-tells cleanup) the thin rarity edge stroke is gone; the bottom RarityBar is thicker / wider to carry it
		new("Frame", { Name = "RarityBar", BackgroundColor3 = rar.Color, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6),
			Size = UDim2.fromOffset(94, 8), ZIndex = 2, Parent = tile }, { Kit.corner(2) })
		-- (2026-10-21, round 3: match RIVALS) the item sits in its own Art frame so it lifts / tilts / squashes over the plate;
		-- price 136x42 -> 146x50
		local art = new("Frame", { Name = "Art", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = tile })
		reactArt(hold, art, itemArt(art, id, nil), true)
		priceTag(hold, "kit", item.Price, 75, 108, 146, 50, function() ctx.openKit(id) end, { owned = function() return ctx.owns(id) end }) -- (2026-10-21, RIVALS pass) live
	end
	new("Frame", { Name = "End", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 722), Size = UDim2.fromOffset(10, 30), Parent = pg })
end

function RENDER.Bundles(pg, hover)
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

function RENDER.Arms(pg, hover)
	local y = gearGrid(pg, hover, sortedGear(), 6, 4)
	new("Frame", { Name = "End", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(10, 40), Parent = pg })
end

function RENDER.Scissors(pg, hover)
	local Config = ctx.Config
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
			{ Kit.corner(2), new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.panelRaised, C.panel) }) }) -- (2026-10-21, AI-tells cleanup) thin border removed; the top AccentStripe stays
		new("Frame", { Name = "AccentStripe", BackgroundColor3 = C.olive, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 6), ZIndex = 4, Parent = card })
		-- (2026-10-21, round 3: match RIVALS) RIVALS' Keys tab (t0084.0s): each tile is a giant cropped currency render as the
		-- backdrop, the name and a huge "+40" top left, the price bottom right. Ours: a giant still 3D scissors (half see-through)
		-- cropped by the card behind the pile; "+N" 52 -> 64 under the name; the pile lifts / turns / squashes as one (no tilt:
		-- the card clips); the Tag rocks; price 56 -> 66 tall.
		local back = new("Frame", { Name = "Backdrop", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(w * 0.66, h * 0.5),
			Size = UDim2.fromOffset(w * 1.3, w * 1.3), Parent = card })
		local bvp = ViewIcons.Viewport(back, ViewIcons.Scissors(), { view = CFrame.Angles(0, 0, math.rad(-35)) * ViewIcons.Views.Scissors[1], zoom = 1.15, still = true })
		bvp.Frame.ImageTransparency = 0.55
		-- a pile of scissors in 3D: more for bigger packs
		local n = math.clamp(i, 1, 4)
		local pile = new("Frame", { Name = "Pile", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 70), Size = UDim2.fromOffset(w, 170), ZIndex = 2, Parent = card })
		for k = 1, n do
			local hold = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(w / 2 + 20 + (k - (n + 1) / 2) * 34, 95 + (k % 2) * 8), Size = UDim2.fromOffset(140, 140), ZIndex = 2, Parent = pile })
			ViewIcons.Viewport(hold, ViewIcons.Scissors(), { view = CFrame.Angles(0, 0, math.rad((k - (n + 1) / 2) * 25)) * ViewIcons.Views.Scissors[1], zoom = 1, zIndex = 2 })
		end
		reactArt(card, pile, nil, false)
		outlined(Kit.label({ Text = p.Name, FontFace = F.display, TextSize = 30, TextColor3 = C.text, Position = UDim2.fromOffset(18, 14), Size = UDim2.fromOffset(w - 36, 36), ZIndex = 5, Parent = card }), 2)
		outlined(Kit.label({ Text = "+" .. fmtN(p.Credits or 0), FontFace = F.display, TextSize = 64, Position = UDim2.fromOffset(18, 48), Size = UDim2.fromOffset(w - 36, 70), ZIndex = 5, Parent = card }), 3)
		if p.Tag then
			wobble(new("TextLabel", { BackgroundColor3 = C.red, Text = p.Tag, FontFace = F.display, TextSize = 20, TextColor3 = C.white, AnchorPoint = Vector2.new(1, 0), Rotation = 3,
				Position = UDim2.fromOffset(w - 12, 16), Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 5, Parent = card }, { Kit.corner(2), Kit.pad(8, 0, 8, 0) }), 2.5)
		end
		-- (2026-10-21, RIVALS pass) the pack opens the detail card; its button makes the same ask("BuyRobux")
		local packTag = priceTag(card, "robux", p.Robux, w / 2, h - 80, w - 30, 66, function() openDetail(packSpec(p)) end)
		packTag.ZIndex = 6
		hover(card)
	Tac.hoverBrackets(card, Tac.brackets(card, Tac.C.line, 20, 3))
		card.Activated:Connect(function() openDetail(packSpec(p)) end)
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
		-- (2026-10-21, round 3: match RIVALS) the pass card is clipped so its medal can be a big cropped render (RIVALS' Season
		-- Pass card, t0072.0s: a huge crest cut by the card edge) instead of a 130 px icon in a corner
		local card = new("TextButton", { Name = p.Key, Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(x, yy), Size = UDim2.fromOffset(pw, 150),
			BackgroundColor3 = C.panelRaised, BackgroundTransparency = 0.15, ClipsDescendants = true, Parent = pg }, { Kit.corner(2) })
		-- (2026-10-21, AI-tells cleanup) the thin owned / not-owned stroke -> a solid bottom bar: field green = owned, cream = to buy
		new("Frame", { Name = "StateBar", BackgroundColor3 = have and C.field or C.cream, BackgroundTransparency = have and 0 or 0.6, BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 6), ZIndex = 2, Parent = card })
		local art = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(-34, -40), Size = UDim2.fromOffset(230, 230), Parent = card })
		reactArt(card, art, ViewIcons.Icon(art, "Medal", { zoom = 1.2 }), false)
		outlined(Kit.label({ Text = p.Name, FontFace = F.display, TextSize = 40, Position = UDim2.fromOffset(190, 12), Size = UDim2.fromOffset(pw - 450, 48), ZIndex = 3, Parent = card }), 2.5)
		Kit.label({ Text = p.Desc or "", FontFace = F.medium, TextSize = 20, TextColor3 = C.cream, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(190, 62), Size = UDim2.fromOffset(pw - 450, 80), ZIndex = 3, Parent = card })
		-- (2026-10-21, RIVALS pass) the pass opens the detail card (same ask("BuyPass")); owned flips in place
		-- (2026-10-21, round 3: match RIVALS) price 210x56 -> 230x68
		local spec = passSpec(p)
		priceTag(card, "robux", p.Robux, pw - 135, 41, 230, 68, function() openDetail(spec) end, { owned = spec.owned })
		card.Activated:Connect(function() if not spec.owned() then openDetail(spec) end end)
		hover(card)
	Tac.hoverBrackets(card, Tac.brackets(card, Tac.C.line, 20, 3))
	end
	y += math.ceil(#Config.GamePasses / 2) * 170
	new("Frame", { Name = "End", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(10, 40), Parent = pg })
end

-------------------------------------------------------------------------------
-- (2026-10-21, RIVALS pass) Detail card (RIVALS t0073-t0080 s): a centred card with the items in 3D and their names (or
-- the pack / pass art), the value badge, our square X and a big field-green price button. The button shows Kit.busy dots
-- until ctx.ask returns, then the card closes (bought, or Roblox's own prompt is up) or the button shakes (refused).
-- `buying` keeps it to one purchase in flight. Built in design px on its own layer, then Kit.toScale (Scale only).
-- Look: a solid dark plate with a thick offset shadow block, no thin border (Edward's AI-tell rule). A local function for
-- now; a generic Kit.modal could take it over later.
-------------------------------------------------------------------------------
local detail -- { layer, update }
local function closeDetail()
	if detail then
		local d = detail
		detail = nil
		d.layer:Destroy()
	end
end
openDetail = function(spec)
	closeDetail()
	if not canvasF then return end
	local Config = ctx.Config
	local items = spec.items or {}
	local W, H = 820, spec.items and 520 or 470
	local layer = new("Frame", { Name = "ShopDetail", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 30, Parent = canvasF })
	local dim = new("TextButton", { Name = "Dim", Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45,
		Position = UDim2.fromOffset(-2000, -2000), Size = UDim2.fromOffset(1920 + 4000, 1080 + 4000), Parent = layer })
	dim:AddTag("Nonapplicable")
	local wrap = new("Frame", { Name = "Wrap", BackgroundTransparency = 1, Position = UDim2.fromOffset((1920 - W) / 2, (1080 - H) / 2), Size = UDim2.fromOffset(W, H), Parent = layer })
	new("Frame", { Name = "Shadow", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, BorderSizePixel = 0, Position = UDim2.fromOffset(12, 14),
		Size = UDim2.fromOffset(W, H), Parent = wrap }, { Kit.corner(8) })
	local card = new("Frame", { Name = "Card", BackgroundColor3 = C.plate, BorderSizePixel = 0, Size = UDim2.fromOffset(W, H), Parent = wrap }, { Kit.corner(8) })
	outlined(Kit.label({ Text = spec.title or "", FontFace = F.display, TextSize = 50, TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(90, 18), Size = UDim2.fromOffset(W - 180, 60), Parent = card }), 2.5)
	if spec.tag then
		new("TextLabel", { BackgroundColor3 = C.red, Text = spec.tag, FontFace = F.display, TextSize = 22, TextColor3 = C.white, AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromOffset(W / 2, 80), Size = UDim2.fromOffset(0, 32), AutomaticSize = Enum.AutomaticSize.X, Parent = card }, { Kit.corner(4), Kit.pad(12, 0, 12, 0) })
	end
	local x = Kit.closeButton(UDim2.fromOffset(0, 60))
	x.Position = UDim2.fromOffset(W - 76, 16)
	x.Parent = card
	local updaters = {}
	if #items > 0 then
		-- the items: 3D tiles (rarity bar along the bottom, no border) with their names, a check on the ones you own
		local n = #items
		local tw = math.min(170, (W - 80) / n - 16)
		local full = 0
		for j, id in items do
			local item = Config.Items[id]
			full += item.Price
			local rar = Config.Rarities[item.Rarity] or Config.Rarities.Standard
			local tx = W / 2 + (j - (n + 1) / 2) * (tw + 16) - tw / 2
			local tile = new("Frame", { Name = "Tile" .. j, BackgroundColor3 = C.panelRaised, BorderSizePixel = 0, Position = UDim2.fromOffset(tx, 130), Size = UDim2.fromOffset(tw, tw), Parent = card }, { Kit.corner(6) })
			new("Frame", { Name = "RarityBar", BackgroundColor3 = rar.Color, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6),
				Size = UDim2.fromOffset(math.floor(tw * 0.6), 6), ZIndex = 2, Parent = tile })
			itemArt(tile, id, tile) -- (2026-10-21, round 3: match RIVALS) the item turns toward you when hovered
			local chk = checkMark(tile, 34, { Position = UDim2.fromOffset(tw - 40, 6), Visible = ctx.owns(id) })
			table.insert(updaters, function() chk.Visible = ctx.owns(id) end)
			Kit.label({ Text = item.Name, FontFace = F.bold, TextSize = 22, TextColor3 = C.cream, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true,
				Position = UDim2.fromOffset(tx - 8, 130 + tw + 8), Size = UDim2.fromOffset(tw + 16, 50), Parent = card })
		end
		local cost = spec.amount()
		if full > cost and cost > 0 then
			local value = math.max(2, math.floor(full / math.max(cost, 1) + 0.5))
			new("TextLabel", { BackgroundColor3 = C.red, Text = "x" .. value .. " value", FontFace = F.display, TextSize = 26, TextColor3 = C.white, Rotation = -4,
				Position = UDim2.fromOffset(24, 22), Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, Parent = card }, { Kit.corner(4), Kit.pad(12, 0, 12, 0) })
		end
	else
		-- a pack / pass: its 3D icon, the big number or the description
		local art = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(W / 2, 118), Size = UDim2.fromOffset(220, 170), Parent = card })
		ViewIcons.Icon(art, spec.icon or "Medal", {})
		if spec.big then
			outlined(Kit.label({ Text = spec.big, FontFace = F.display, TextSize = 46, TextXAlignment = Enum.TextXAlignment.Center,
				Position = UDim2.fromOffset(40, 294), Size = UDim2.fromOffset(W - 80, 56), Parent = card }), 2.5)
		elseif spec.desc then
			Kit.label({ Text = spec.desc, FontFace = F.medium, TextSize = 24, TextColor3 = C.cream, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true,
				Position = UDim2.fromOffset(60, 292), Size = UDim2.fromOffset(W - 120, 60), Parent = card })
		end
	end
	-- the buy button: field green (Theme.gradient.robux = the primary), the price and its icon; owned = the cream check
	local BW, BH = 320, 84
	local buy = new("TextButton", { Name = "Buy", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset((W - BW) / 2, H - BH - 28), Size = UDim2.fromOffset(BW, BH),
		BackgroundColor3 = C.white, BorderSizePixel = 0, Parent = card }, { Kit.corner(8), Kit.vgrad(Theme.gradient.robux) })
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = buy },
		{ new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }) })
	new("ImageLabel", { LayoutOrder = spec.kind == "robux" and 1 or 3, BackgroundTransparency = 1, Image = spec.kind == "robux" and ROBUX_IMG or SCISSORS_IMG,
		ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromOffset(50, 50), Parent = row })
	local price = outlined(Kit.label({ LayoutOrder = 2, Text = fmtN(spec.amount() or 0), FontFace = F.display, TextSize = 50, TextColor3 = C.white,
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, BH), Parent = row }), 2.5)
	local ownedRow = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = buy },
		{ new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }) })
	checkMark(ownedRow, 50, { LayoutOrder = 1 })
	outlined(Kit.label({ LayoutOrder = 2, Text = "Owned", FontFace = F.display, TextSize = 46, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, BH), Parent = ownedRow }), 2.5)
	Kit.bindButton(buy, { hover = 1.06 })
	local function short()
		return spec.kind == "scissors" and (data().Credits or 0) < (spec.amount() or 0)
	end
	local function update()
		local own = spec.owned and spec.owned() or false
		row.Visible, ownedRow.Visible = not own, own
		price.Text = fmtN(spec.amount() or 0)
		price.TextColor3 = short() and Theme.hex("#FF6A5E") or C.white
		for _, f in updaters do f() end
	end
	update()
	Kit.toScale(layer)
	Kit.centreAnchor(wrap)
	Kit.popIn(wrap)
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
			if ctx.toast then ctx.toast("Not enough scissors", "bad") end
			return
		end
		buying = true
		row.Visible = false -- the dots sit alone on the button
		local stop = Kit.busy(buy)
		task.spawn(function()
			local ok, res = pcall(spec.buy)
			buying = false
			stop()
			if ok and res and res.ok then
				close() -- bought (scissors), or Roblox's own prompt is up (Robux): the tag's check pops when the data lands
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
local TABS = { { "Featured", "Medal" }, { "Bundles", "Crate" }, { "Arms", "Weapon" }, { "Scissors", "Scissors" } }

local function build()
	gui = new("ScreenGui", { Name = "ShopUI2", IgnoreGuiInset = true, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 25, Enabled = false, Parent = Players.LocalPlayer:WaitForChild("PlayerGui") })
	gui:SetAttribute("NoStyle", true)
	blur = Lighting:FindFirstChild("MenuUIBlur") or new("BlurEffect", { Name = "MenuUIBlur", Size = 0, Parent = Lighting })
	scrim = new("Frame", { Name = "Scrim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.scrim, BackgroundTransparency = 1, Parent = gui })
	local canvas = Kit.canvas(gui)
	canvasF = canvas -- (2026-10-21, RIVALS pass) the detail card's layer goes here, over root
	root = new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = canvas })

	-- tab row: dark tabs, the selected one light; a 3D icon pops out over each tab (RIVALS)
	for i, t in TABS do
		local b = new("TextButton", { Name = t[1], Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(PAGE_X + (i - 1) * 176, 170), Size = UDim2.fromOffset(164, 56),
			BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, Parent = root }, { Kit.corner(8) })
		local hold = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(82, 30), Size = UDim2.fromOffset(78, 64), ZIndex = 2, Parent = b })
		-- (2026-10-21, round 3: match RIVALS) the selected tab keeps its 3D icon turned toward you (styleTabs); hover turns the
		-- others and lightens their dark plate (RIVALS t0068.4s / t0084.0s: hovered tabs brighten, the selected one is white)
		local vp
		if t[2] == "Weapon" then
			vp = ViewIcons.Viewport(hold, ViewIcons.Weapon("AutoRifle"), { view = ViewIcons.GunView, zoom = 0.95 })
		else
			vp = ViewIcons.Icon(hold, t[2], {})
		end
		b.MouseEnter:Connect(function()
			vp.SetHover(true)
			if tab ~= t[1] then Kit.tween(b, 0.1, { BackgroundTransparency = 0.12 }) end
		end)
		b.MouseLeave:Connect(function()
			vp.SetHover(tab == t[1])
			if tab ~= t[1] then Kit.tween(b, 0.1, { BackgroundTransparency = 0.35 }) end
		end)
		local l = outlined(Kit.label({ Name = "Label", Text = t[1], FontFace = F.display, TextSize = 30, TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 34), ZIndex = 3, Parent = b }), 2.5)
		Kit.bindButton(b, { hover = 1.05 })
		b.Activated:Connect(function() Screen.SetTab(t[1]) end)
		tabBtns[t[1]] = { b = b, l = l, icon = hold, vp = vp }
	end
	local close = Kit.closeButton(UDim2.fromOffset(86, 52))
	close.Position = UDim2.fromOffset(PAGE_X + PAGE_W - 86, 172)
	close.Parent = root
	close.Activated:Connect(function() Screen.Close() end)

	-- wallet (top centre): scissors + count + amber plus
	local wallet = new("Frame", { Name = "Wallet", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(960, 52), Size = UDim2.fromOffset(330, 70), Parent = root })
	local wIcon = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, -6), Size = UDim2.fromOffset(84, 84), ZIndex = 3, Parent = wallet })
	ViewIcons.Icon(wIcon, "Scissors", { zoom = 1.1 })
	local pill = new("Frame", { Name = "Pill", Position = UDim2.fromOffset(70, 14), Size = UDim2.fromOffset(190, 46), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Parent = wallet }, { Kit.corner(10) })
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
	-- (2026-10-21, RIVALS pass) the wallet pill pops from its centre when the count changes
	walletPill = pill
	Kit.centreAnchor(pill)
	-- (2026-10-21, RIVALS pass, standing rule) the three loading dots, shown if the shop is opened before its pages are built
	loader = Kit.loadingDots(canvas)
	loader.Visible = false

	GuiService.MenuOpened:Connect(function() if isOpen then root.Visible = false end end)
	GuiService.MenuClosed:Connect(function() if isOpen and ready then Kit.open(root) end end)
end

-- (2026-10-21, RIVALS pass) one persistent ScrollingFrame per tab. Built at join (Init) and again only when a tab is shown
-- while its page is dirty (what you own changed since it was built). Everything else updates in place via its updaters.
local function buildPage(t)
	local old = pages[t]
	if old and old.pg then old.pg:Destroy() end
	local pg = new("ScrollingFrame", {
		Name = t, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = true, Visible = false,
		ScrollBarThickness = 8, ScrollBarImageColor3 = C.field, -- (2026-10-21, AI-tells cleanup) field green, explicit (was C.olive) ScrollBarImageTransparency = 0.3,
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

-- (2026-10-21, RIVALS pass) the wallet counts up (Kit.countTo) and its pill pops; snaps while the shop is closed
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

-- (2026-10-21, RIVALS pass) tab colours tween (same colours as before), the selected tab's icon pops
local function styleTabs(animate)
	for name, t in tabBtns do
		local on = name == tab
		local goal = { BackgroundColor3 = on and C.white or Color3.new(0, 0, 0), BackgroundTransparency = on and 0 or 0.35 }
		if animate then Kit.tween(t.b, 0.12, goal) else t.b.BackgroundColor3, t.b.BackgroundTransparency = goal.BackgroundColor3, goal.BackgroundTransparency end
		t.l.TextColor3 = on and C.textDark or C.text
		local st = t.l:FindFirstChildOfClass("UIStroke")
		if st then st.Enabled = not on end
		if on and animate then Kit.pop(t.icon, 1.15) end
		-- (2026-10-21, round 3: match RIVALS) RIVALS' selected tab (t0068.4s "Bundles", t0084.0s "Keys") is white AND its icon
		-- sits bigger, standing up out of the tab. Ours: the selected icon grows 1.3x upward from its bottom anchor (Scale,
		-- after toScale) and stays turned toward you; the others go back to their base size and idle sway.
		t.iconBase = t.iconBase or t.icon.Size
		local bs = t.iconBase
		local goalSize = on and UDim2.new(bs.X.Scale * 1.3, bs.X.Offset, bs.Y.Scale * 1.3, bs.Y.Offset) or bs
		if animate then Kit.tween(t.icon, 0.18, { Size = goalSize }, Enum.EasingStyle.Back) else t.icon.Size = goalSize end
		if t.vp then t.vp.SetHover(on) end
	end
end

-- show the current tab's page (rebuilding it first if dirty); a real switch slides it in 24 px over 0.15 s (Scale)
local function showTab(animate)
	local P = pages[tab]
	if not P or P.dirty or P.sig ~= ownedSig() then P = buildPage(tab) end
	for name, Q in pages do Q.pg.Visible = name == tab end
	styleTabs(animate)
	if animate then
		P.pg.Position = UDim2.fromScale(24 / PAGE_W, 0)
		Kit.tween(P.pg, 0.15, { Position = UDim2.fromScale(0, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		-- (2026-10-21, round 3: match RIVALS) the page's tiles pop in one after another (Kit.popIn shares their bindButton UIScale)
		local k = 0
		for _, c in P.pg:GetChildren() do
			if c:IsA("GuiButton") then
				k += 1
				Kit.popIn(c, math.min(k, 12) * 0.025)
			end
		end
	else
		P.pg.Position = UDim2.fromScale(0, 0)
	end
end

-- (2026-10-21, RIVALS pass) no rebuild here any more: wallet + every tag / owned mark update in place. Pages whose
-- owned set changed are marked dirty and rebuilt when next shown (showTab), never under the cursor.
function Screen.Refresh()
	if not gui then return end
	updateWallet()
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
	local changed = t ~= tab
	tab = t
	if ready and isOpen then showTab(changed) end
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
			showTab(false)
			Kit.open(root)
		else
			-- (2026-10-21, RIVALS pass, standing rule) opened before the join build finished: dots until it's ready
			loader.Visible = true
			task.spawn(function()
				while not ready and isOpen do task.wait() end
				loader.Visible = false
				if isOpen then Screen.Refresh(); showTab(false); Kit.open(root) end
			end)
		end
	else
		closeDetail()
		loader.Visible = false
		Kit.close(root, function() if not isOpen then gui.Enabled = false end end)
		if ctx.onClose then ctx.onClose() end
	end
end

-- (2026-10-21, RIVALS pass, standing rule) every page is built here, at join (the lobby calls Init from its menu prewarm),
-- so opening the shop or switching tabs only toggles Visible
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
		if ready then Screen.Refresh(); showTab(true) end
	else
		setOpen(true)
	end
end
function Screen.Close() if gui then setOpen(false) end end
function Screen.IsOpen() return isOpen end

return Screen
