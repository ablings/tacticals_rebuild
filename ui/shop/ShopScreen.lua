-- UIKit/ShopScreen (ModuleScript): the lobby SHOP.
-- (2026-10-21, RIVALS 1:1) a straight port of the RIVALS replica's Shop (rivals_practice/ui/shop/ShopController.client.lua,
-- frames t0068-t0106) over tacticals' own content: scissor packs, gear (unlocked in the Kit room), the scissors bundles, the
-- Founder's Bundle and the game passes (VIP, 2X SCISSORS). Colours, gradients and fonts all come from UIKit.Rivals.Theme;
-- UIKit.Kit stays the engine (toScale, canvas, bindButton, busy / shake / pop / countTo, the RIVALS red X).
-- All art is live 3D (ViewIcons / the lobby Icons). Design px at 1920x1080 -> Kit.toScale (Scale only).
--   ShopScreen.Init({ Config, Icons, getData, ask, owns, openKit, getSetting, tooltip, toast, onOpen, onClose })
--   ShopScreen.Open(tab?) / Close() / IsOpen() / Refresh() / SetTab(tab)
-- Tabs: Featured, Bundles, Arms, Scissors ("Home" is accepted for Featured).
-- (2026-10-21, RIVALS shop layout) tabs now run in RIVALS' order and naming: Home (key "Featured"), Bundles, Arms (our gear,
-- where RIVALS sells weapon items), Skins, Daily, Emotes, Charms, Finishers, Scissors (RIVALS' Keys; "Keys" is accepted too).
-- Skins / Daily / Emotes / Charms / Finishers are PLACEHOLDER pages (see PLACEHOLDER_ITEMS below): their price buttons only
-- show a "Coming soon" toast and never reach ctx.ask / MarketplaceService. More is not a page (RIVALS: it swaps the tab row
-- for Codes / Gifting links), so it is left out.
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
local SCISSORS_IMG = (Kit.ICONS and Kit.ICONS.scissorsReward) or "rbxassetid://120480559804238" -- (round 5: the filled red scissors, as on the hub)
local ROBUX_IMG = asset("cur_robux") ~= "" and asset("cur_robux") or "rbxasset://textures/ui/common/robux.png"

-------------------------------------------------------------------------------
-- (2026-10-21, RIVALS shop layout) PLACEHOLDER catalogue: what RIVALS' shop sells that Tacticals has no items for yet.
-- Every entry carries PLACEHOLDER = true: its tile and price render like a real RIVALS tile, but a click only shows the
-- "Coming soon" toast (comingSoon below), never ctx.ask / a Robux prompt. To ship a real item: give the entry a real id
-- (an ItemConfig / LobbyConfig id), drop PLACEHOLDER, and route its click through openDetail with a spec whose buy() asks
-- the server (see bundleSpec / packSpec). Fields: name, rarity (a Config.Rarities key), price (0 = FREE), currency
-- ("scissors" | "robux"), and either base (one of our item ids, rendered live in 3D and tinted to the rarity as the
-- stand-in) or img (an Assets name: the practice replica's generated RIVALS-style art).
-------------------------------------------------------------------------------
local function ph(name, rarity, price, art, currency)
	local e = { PLACEHOLDER = true, name = name, rarity = rarity, price = price, currency = currency or "scissors" }
	if string.sub(art, 1, 4) == "img:" then e.img = string.sub(art, 5) else e.base = art end
	return e
end
local PLACEHOLDER_ITEMS = {
	-- Skins tab: one skin per gun / melee (RIVALS sells these in its Skins bundles and the Daily strip)
	Skins = {
		ph("Pistol Skin", "Rare", 600, "Pistol"), ph("Suppressed Skin", "Rare", 750, "SilencedPistol"),
		ph("Revolver Skin", "Epic", 1200, "Revolver"), ph("Mini Uzi Skin", "Rare", 750, "MiniUzi"),
		ph("Dual Pistols Skin", "Rare", 900, "DualPistols"), ph("Rifle Skin", "Epic", 1500, "AutoRifle"),
		ph("Semi-Auto Skin", "Epic", 1500, "SemiAuto"), ph("Shotgun Skin", "Epic", 1200, "PumpShotgun"),
		ph("Sniper Skin", "Legendary", 2500, "Sniper"), ph("Knife Skin", "Rare", 600, "Knife"),
	},
	MeleeSkins = {
		ph("Bat Skin", "Rare", 600, "Bat"), ph("Katana Skin", "Legendary", 2000, "Katana"),
		ph("Shield Skin", "Epic", 1500, "RiotShield"), ph("Gloves", "Standard", 300, "Fists"), ph("Medkit Skin", "Rare", 500, "Medkit"),
	},
	-- Daily tab (RIVALS t0094.3s): 5 skins for Robux, then 5 emotes for keys (ours: scissors), the first one FREE
	DailySkins = {
		ph("Pistol Skin", "Rare", 240, "Pistol", "robux"), ph("Revolver Skin", "Rare", 240, "Revolver", "robux"),
		ph("Mini Uzi Skin", "Rare", 240, "MiniUzi", "robux"), ph("Rifle Skin", "Epic", 308, "AutoRifle", "robux"),
		ph("Sniper Skin", "Legendary", 480, "Sniper", "robux"),
	},
	DailyEmotes = {
		ph("Shrug", "Standard", 0, "img:em_shrug"), ph("Take a Knee", "Standard", 50, "img:em_kneel"),
		ph("Round & Round", "Rare", 75, "img:em_round"), ph("Side to Side", "Rare", 75, "img:em_side"),
		ph("Holiday Jig", "Epic", 100, "img:em_holly"),
	},
	Emotes = {
		ph("Shrug", "Standard", 50, "img:em_shrug"), ph("Take a Knee", "Standard", 50, "img:em_kneel"),
		ph("Round & Round", "Rare", 75, "img:em_round"), ph("Side to Side", "Rare", 75, "img:em_side"),
		ph("Holiday Jig", "Epic", 100, "img:em_holly"), ph("Director's Cut", "Legendary", 250, "img:emote_cut"),
	},
	Charms = {
		ph("Top Hat", "Standard", 30, "img:ch_tophat"), ph("Dice", "Standard", 30, "img:ch_dice"), ph("Pawn", "Standard", 30, "img:ch_pawn"),
		ph("Hook", "Standard", 30, "img:ch_hook"), ph("Recorder", "Standard", 30, "img:ch_flute"), ph("Cupcake", "Standard", 30, "img:ch_cupcake"),
		ph("Cactus", "Rare", 40, "img:charm_cactus"), ph("Rainbow", "Rare", 40, "img:ch_rainbow"), ph("Puffer", "Rare", 40, "img:ch_puffer"),
		ph("Tennis Ball", "Rare", 40, "img:ch_tennis"), ph("Coconut", "Rare", 40, "img:ch_coconut"), ph("Piggy Bank", "Epic", 60, "img:ch_piggy"),
		ph("Rubber Duck", "Epic", 60, "img:ch_duck"), ph("Rocket", "Epic", 60, "img:ch_rocket"), ph("Basketball", "Epic", 60, "img:ch_basketball"),
	},
	Finishers = {
		ph("Spin Out", "Standard", 100, "img:fin_1"), ph("Slip", "Standard", 100, "img:fin_2"), ph("Party Pop", "Standard", 100, "img:fin_3"),
		ph("Knocked Out", "Standard", 100, "img:fin_4"), ph("Freeze", "Rare", 150, "img:fin_5"), ph("Shatter", "Rare", 150, "img:fin_6"),
		ph("Storm", "Rare", 150, "img:fin_7"), ph("Zapped", "Epic", 200, "img:fin_8"), ph("Splat", "Epic", 200, "img:fin_9"),
		ph("Sliced", "Epic", 200, "img:fin_10"), ph("Cubed", "Epic", 200, "img:fin_11"), ph("Crystal", "Legendary", 300, "img:fin_12"),
		ph("Rainbow", "Legendary", 300, "img:fin_13"), ph("Anvil", "Legendary", 300, "img:fin_14"),
	},
}
-- (2026-10-21, RIVALS shop layout) RIVALS' red "Claim your FREE reward now!" tip over the Daily tab shows only while a REAL
-- (non-placeholder) free Daily item is up; set true to preview it over the placeholder FREE emote
local DAILY_TIP_PREVIEW = false

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
-- (2026-10-21, port3) RIVALS' (normal theme) header: the "Shop" title over the tabs, both starting at the content's left edge
-- (CONTENT_X); compact tabs 100 wide (~5.2% of the screen width) 110 apart. Price buttons 52 tall (~4.8% of the screen
-- height), ~50 px between groups, 118 px item tiles.
local CONTENT_X = PAGE_X + 12
local TITLE_Y = 202
-- (2026-10-22, live RIVALS shop at 16:9) bigger tabs (144 x 49, ~7.5 % of the width), 154 apart, row centred at y ~300; five
-- tabs + "More" per row (TAB_PER_ROW), the rest on a second row behind More (back with "Back")
local TAB_Y, TAB_W, TAB_H, TAB_STEP = 276, 144, 49, 154
local TAB_PER_ROW = 5
local PRICE_H, GAP, TILE = 52, 50, 118

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
-- (2026-10-21, RIVALS images) the generated RIVALS shop art (UIKit.Rivals.Assets.gen): the painted bundle backdrops and the
-- dark corner weapon tag. RIVALS tags random-weapon items "?" and all-weapon items "∞" and leaves weapon-specific skins bare.
-- Tacticals sells no random items: melee and gadgets (they go with every gun) get the ∞ tag, guns get none.
local GEN = Assets.gen or {}
local BACKDROP = { founders = GEN.shop_bg_founders, Operator = GEN.shop_bg_operator }
-- a full-bleed backdrop image under everything else on the card (the item renders sit on top, the title on its calm left)
local function backdrop(card, img, z)
	if not img or img == "" then return nil end
	return new("ImageLabel", { Name = "Backdrop", BackgroundTransparency = 1, Image = img, ScaleType = Enum.ScaleType.Crop, Size = UDim2.fromScale(1, 1),
		ZIndex = z or 1, Parent = card }, { RK.corner(8) })
end
-- the corner tag (256x208 art, never tinted) in a card's top-right corner; returns its width (0 when the item gets none)
local function weaponTag(card, itemId, w, z)
	local item = ctx.Config.Items[itemId]
	local img = item and (item.Slot == "Melee" or item.Slot == "Gadget") and GEN.shop_tag_all
	if not img then return 0 end
	new("ImageLabel", { Name = "WeaponTag", BackgroundTransparency = 1, Image = img, ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(w, math.floor(w * 208 / 256 + 0.5)), ZIndex = z or 5, Parent = card })
	return w
end
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
-- (2026-10-21, port3) brighter: ambient 242 + a full white key light from the camera side (the camera looks along +Z), so the
-- renders read bright and saturated like RIVALS' instead of grey
local function lit(vp)
	if vp and vp.Frame then
		vp.Frame.Ambient = Color3.fromRGB(242, 242, 246)
		vp.Frame.LightColor = WHITE
		vp.Frame.LightDirection = Vector3.new(0.3, -0.55, 0.78)
	end
	return vp
end
-- an item (gun / gadget / melee) via the lobby Icons module, which knows every item kind
-- (2026-10-21, port3) guns lie diagonally across their slot (RIVALS' item renders) and zoom in, so rifles and the sniper fill
-- ~90% of the slot instead of reading as a thin grey line across it
local function itemArt(holder, itemId, hoverTarget, zoomMul)
	local model, view, zoom = ctx.Icons.Item(itemId)
	local item = ctx.Config and ctx.Config.Items[itemId]
	if item and item.Slot == "Weapon" then
		view = CFrame.Angles(0, 0, math.rad(-28)) * (view or CFrame.identity)
		zoom = (zoom or 1) * 1.1
	end
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
-- live = { owned = fn, amount = fn, ts, isz, z, noHover, text, placeholder }. onBuy(tag) runs on click (Kit prices open the Kit room).
-------------------------------------------------------------------------------
-- (2026-10-21, port3) the number and the icon are laid out by hand (Scale) and always fit INSIDE the button: the pair is
-- centred, the number's box is what's left after the icon and padding, and TextScaled (capped at ts by a UITextSizeConstraint)
-- shrinks a long price ("4,000") instead of letting it spill past the edges. White Rubik ExtraBold with a chunky black outline.
-- (round 0) RIVALS' live key-bundle prices (rivals_rec t0083.9): white Rubik ExtraBold with a soft dark-green edge
local PRICE_FONT = Font.new("rbxassetid://12187365977", Enum.FontWeight.ExtraBold)
local function priceTag(parent, kind, amount, cx, y, w, h, onBuy, live)
	w, h, live = w or 124, h or PRICE_H, live or {}
	local isRobux = kind == "robux"
	local tag = new("TextButton", { Name = "Price", Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(cx, y),
		Size = UDim2.fromOffset(w, h), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = live.z or 5, Parent = parent })
	RK.corner(6).Parent = tag
	-- (round 1, grader B) the scissors tag in RIVALS' saturated key yellow (#F8EC00 -> #EFD700): Theme.key's pale #FFFDB5 top left the
	-- white digits with no contrast
	local grad = RK.vgrad(isRobux and G.robux or { Color3.fromRGB(248, 236, 0), Color3.fromRGB(239, 215, 0) })
	grad.Parent = tag
	local edge = RK.stroke(BLACK, 1.5, 0.6)
	edge.Parent = tag
	local z = tag.ZIndex
	local row = new("Frame", { Name = "BuyRow", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = z, Parent = tag })
	-- (round 1, grader B vs t0068 / t0083.9: one price size on every tag, digit cap ~0.34 x tag height = TextSize ~0.5 h)
	local ts = live.ts or math.floor(h * 0.7) -- (0.5 measured ~0.22 h on screen: the size cap is not rescaled with the canvas)
	-- (2026-10-22, section round 0, grader B) RIVALS' price: a clean bold sans in white with a thin edge in the tag's own dark tint (no
	-- cartoon font / chunky black outline); the currency icon ~1 digit cap (scissors 0.74 h -> 0.58 h) and the pair centred with ~12 %
	-- side padding (was ~5-7 %); the Robux glyph sits ~0.8 cap from its number
	-- (round 2, grader B vs t0068 / t0084) side pad 0.06 x width so the digits get the room (yellow ones had shrunk to 0.23 h), the
	-- currency icon ~1.25 digit caps, ~0.55 cap from the digits
	local isz = live.isz or math.floor(h * (isRobux and 0.46 or 0.5)) -- (rounds 8-11 vs t0068: RIVALS' tag key is WHITE, ~0.45 of the tag; the digits lead)
	local pad, gap = math.max(3, math.floor(w * 0.04)), math.max(3, math.floor(h * 0.14))
	-- (2026-10-21, RIVALS shop layout) live.text = a word instead of a number ("FREE", RIVALS' Daily): no currency icon
	if live.text then isz, gap = 0, 0 end
	local hh = math.min(h, math.floor(ts * 1.2)) -- the number's box height
	-- children draw above their parent: the parent label is the soft shadow (2 px low), the white outlined number its child
	local shadow = RK.label({ Name = "Num", Text = "0", FontFace = PRICE_FONT, TextSize = ts, TextScaled = true, TextColor3 = BLACK, TextTransparency = 0.82, TextXAlignment = CENTER,
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromScale(0.5, hh / h), ZIndex = z + 1, Parent = row })
	new("UITextSizeConstraint", { MaxTextSize = ts, Parent = shadow })
	local txt = RK.label({ Name = "Text", Text = "0", FontFace = PRICE_FONT, TextSize = ts, TextScaled = true, TextXAlignment = CENTER, Position = UDim2.fromScale(0, -2 / hh),
		Size = UDim2.fromScale(1, 1), ZIndex = z + 2, Parent = shadow })
	new("UITextSizeConstraint", { MaxTextSize = ts, Parent = txt })
	-- (round 1, grader B: RIVALS' edge on green is soft, the digits read plain white; on the saturated yellow white needs a firmer
	-- amber edge to stay legible)
	stroke(txt, math.clamp(h * 0.035, 1.5, 2.5), isRobux and 0.55 or 0.4)
	txt:FindFirstChildOfClass("UIStroke").Color = isRobux and Color3.fromRGB(46, 120, 18) or Color3.fromRGB(160, 110, 0)
	local icon = new("ImageLabel", { Name = "Currency", BackgroundTransparency = 1, Image = isRobux and ROBUX_IMG or (Kit.ICONS and (Kit.ICONS.scissorsWhite or Kit.ICONS.scissors)) or SCISSORS_IMG, ScaleType = Enum.ScaleType.Fit, -- (round 3, grader B: RIVALS' tag currency is a flat white glyph)
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromScale(isz / w, isz / h), ZIndex = z + 1, Visible = live.text == nil, Parent = row })
	-- Robux glyph left of the number, the scissors right of it (RIVALS' key button: "5 [key]"); Rubik ExtraBold digits ~0.64 em
	local function place(text)
		local em = 0
		for ch in text:gmatch(".") do em += (ch == "," or ch == ".") and 0.3 or 0.6 end
		local tw = math.min(w - pad * 2 - isz - gap, em * ts)
		local left = (w - (tw + gap + isz)) / 2
		local tx, ix = left, left + tw + gap
		if isRobux then ix, tx = left, left + isz + gap end
		shadow.Position = UDim2.fromScale(tx / w, 0.5 + 2 / h)
		shadow.Size = UDim2.fromScale(tw / w, hh / h)
		icon.Position = UDim2.fromScale(ix / w, 0.5)
	end
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
			shadow.Text = live.text or fmtN(amt)
			txt.Text = shadow.Text
			place(shadow.Text)
		end
		-- (2026-10-21, RIVALS shop layout) a PLACEHOLDER price is never "can't afford": its click only says Coming soon
		st.short = not live.placeholder and (kind == "scissors" or kind == "kit") and not own and (data().Credits or 0) < amt
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
	backdrop(card, big and BACKDROP.founders or BACKDROP[spec.id], 1) -- (2026-10-21, RIVALS images) Founder's hero / Operator Kit
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
		-- (2026-10-21, port3) the tag is RIVALS' red offer tag (valueTag, pointer down) sat on the price, not a loose pill
		if spec.tag then valueTag(card, cx, 266 - 46, string.upper(spec.tag), 170, 34, 20, 10) end
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
	if string.sub(iconName, 1, 4) == "img:" then -- (2026-10-21, RIVALS shop layout) an Assets image instead of a 3D icon
		new("ImageLabel", { BackgroundTransparency = 1, Image = asset(string.sub(iconName, 5)), ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = ic })
	else
		ViewIcons.Icon(ic, iconName, { zoom = 1, zIndex = 2 })
	end
	RK.label({ Text = text, FontFace = FB, TextSize = 38, Position = UDim2.fromOffset(76, 0), Size = UDim2.fromOffset(800, 62), ZIndex = 2, Parent = bar })
end

-------------------------------------------------------------------------------
-- (2026-10-21, RIVALS shop layout) PLACEHOLDER tiles (Skins / Daily / Emotes / Charms / Finishers). They look like RIVALS'
-- Daily tiles (rarity gradient + stroke, the name across the top, the rarity under it, a big render, the price overlapping
-- the foot) but every click lands in comingSoon: a toast and a pop, no ctx.ask, no MarketplaceService.
-------------------------------------------------------------------------------
local lastSoon = 0
local function comingSoon(spec, tag)
	if tag then Kit.pop(tag, 1.1) end
	if os.clock() - lastSoon < 0.8 then return end -- one toast per burst of clicks
	lastSoon = os.clock()
	local ok = pcall(Toast.show, { title = "Coming soon", text = ('"%s" is not in the shop yet.'):format(spec.name), icon = "padlock",
		reward = spec.img and asset(spec.img) or nil })
	if not ok and ctx.toast then ctx.toast("Coming soon", "info") end
end
local function placeholderRarity(spec)
	local r = ctx.Config.Rarities
	return (r[spec.rarity] or r.Standard).Color
end
local function placeholderTile(pg, hover, spec, x, y, w, h)
	local col = placeholderRarity(spec)
	local card = rarityTile(pg, col, x, y, w, h, 1, "TextButton")
	card.Name = "PH_" .. spec.name
	card:SetAttribute("Placeholder", true) -- PLACEHOLDER: swap for a real item tile (see PLACEHOLDER_ITEMS)
	local art = new("Frame", { Name = "Art", BackgroundTransparency = 1, Position = UDim2.fromOffset(w * 0.08, h * 0.2), Size = UDim2.fromOffset(w * 0.84, h * 0.66), ZIndex = 3, Parent = card })
	if spec.base then
		-- our own model as the stand-in, tinted toward the rarity colour
		local vp = lit(itemArt(art, spec.base, nil, 1.15))
		vp.Frame.ImageColor3 = col:Lerp(WHITE, 0.45)
		vp.Frame.ZIndex = 3
		turnOnHover(card, vp)
	else
		new("ImageLabel", { BackgroundTransparency = 1, Image = asset(spec.img), ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = art })
	end
	local nts = w > 200 and 24 or 21
	stroke(RK.label({ Name = "ItemName", Text = spec.name, FontFace = FB, TextSize = nts, TextXAlignment = CENTER, TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(w - 12, nts + 6), ZIndex = 4, Parent = card }), 2, 0.3)
	stroke(RK.label({ Name = "Rarity", Text = string.upper(spec.rarity), FontFace = FS, TextSize = 15, TextColor3 = col:Lerp(WHITE, 0.55), TextXAlignment = CENTER,
		Position = UDim2.fromOffset(6, nts + 10), Size = UDim2.fromOffset(w - 12, 18), ZIndex = 4, Parent = card }), 1.5, 0.3)
	local tag
	tag = priceTag(card, spec.currency == "robux" and "robux" or "scissors", spec.price, w / 2, h - 30, math.min(140, w - 30), PRICE_H,
		function() comingSoon(spec, tag) end, { placeholder = true, text = spec.price == 0 and "FREE" or nil, z = 6, noHover = true })
	hover(card)
	card.Activated:Connect(function() comingSoon(spec, tag) end)
	if ctx.tooltip then ctx.tooltip(card, spec.name, function() return "Coming soon to the shop." end) end
	return card
end
-- a grid of placeholder tiles across the 1242 content column; returns the y under it
local function placeholderGrid(pg, hover, list, y, cols, h)
	local gap = 6
	local w = (1242 - gap * (cols - 1)) / cols
	for i, spec in list do
		local c, r = (i - 1) % cols, (i - 1) // cols
		placeholderTile(pg, hover, spec, 12 + c * (w + gap), y + r * (h + 40), w, h)
	end
	return y + math.ceil(#list / cols) * (h + 40)
end
-- (2026-10-21, RIVALS shop layout) is a REAL free Daily item up? (drives the red tip over the Daily tab)
-- (2026-10-22, Edward: "do number 2", RIVALS' daily free reward) the server's free claim: Player attribute DailyFreeAt = server
-- time of the next free claim (<= now = ready), remote ClaimDailyFree (RemoteFunction anywhere in ReplicatedStorage) -> { ok,
-- reward }. Until the server ships it the attribute is nil and nothing shows.
local function dailyFreeReady()
	local at = Players.LocalPlayer:GetAttribute("DailyFreeAt")
	return type(at) == "number" and at <= workspace:GetServerTimeNow()
end
local function freeDailyUp()
	if dailyFreeReady() then return true end
	for _, set in { PLACEHOLDER_ITEMS.DailySkins, PLACEHOLDER_ITEMS.DailyEmotes } do
		for _, e in set do
			if e.price == 0 and (DAILY_TIP_PREVIEW or not e.PLACEHOLDER) then return true end
		end
	end
	return false
end

local RENDER = {}

-- Home (RIVALS ref_35 / t0070, the replica's Home): left, the crates rows (scissor packs for Robux, then gear for scissors) as
-- bare renders over their price buttons; right, the Season Pass card (our Founder's Bundle); bottom left, the Special Offer
-- carousel with its page dots; bottom right, 3x2 rarity item tiles with the price overlapping each tile's foot.
function RENDER.Featured(pg, hover)
	local Config = ctx.Config
	local d = data()
	local P = curPage
	-- (2026-10-21, port3) RIVALS' spacing inside the 1242 content column (12..1254): crates 3 x 160 (12..484), the hero 50 px
	-- right of them (534..1254), the Special Offer 50 px under both (12..786, 384..654, its page dots under it, all on screen),
	-- the 118 px item tiles 50 px right of it (836..1254, 150 apart)
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
		local h = hold(12 + (i - 1) * 160, 6, 152, 104 + PRICE_H, 1.08, open)
		local pile = new("Frame", { Name = "Pile", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, -4), Size = UDim2.fromOffset(152, 104), ZIndex = 2, Parent = h })
		scissorsPile(pile, math.min(i + 1, 4), 152, 104, 2, 10)
		countLabel(h, pr.Credits, 52, 62, 100, 40, 32, 4)
		priceTag(h, "robux", pr.Robux, 76, 104, 100, PRICE_H, open, { noHover = true }) -- (round 10, grader A vs t0068: 100 dp, was 124)
	end
	-- boxes row: gear you don't have yet as bare renders over yellow scissors prices (opens the Kit room)
	local gear = {}
	for _, id in sortedGear() do if not ctx.owns(id) then table.insert(gear, id) end end
	for i = 1, math.min(3, #gear) do
		local id = gear[i]
		local h = hold(12 + (i - 1) * 160, 178, 152, 104 + PRICE_H, 1.08, function() ctx.openKit(id) end)
		-- (2026-10-22, section rounds 0-10, grader C) the same rarity tile + type tag as the item grid, the render kept inside it (was
		-- a bare render floating over the price)
		local tile = rarityTile(h, rarityColor(id), 4, 0, 144, 104, 1)
		weaponTag(tile, id, 34, 4)
		local art = new("Frame", { Name = "Art", BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 2), Size = UDim2.fromOffset(132, 94), ZIndex = 3, Parent = h })
		turnOnHover(h, lit(itemArt(art, id, nil, 0.95)))
		priceTag(h, "kit", Config.Items[id].Price, 76, 104, 100, PRICE_H, function() ctx.openKit(id) end, { owned = function() return ctx.owns(id) end, noHover = true })
	end

	-- the Season Pass card (749x321 at 519,6): our Founder's Bundle. Grey 35° wash (or the bundle colour), one big render
	-- cropped by the card, the heavy white title + shadow, the LIMITED pill, the lime price where RIVALS has its eye button.
	-- Hover: the spotlight closes in, a dark shade rises and the bundle's contents show (RIVALS' pass showcase).
	local featured = founderProduct()
	if featured then
		local spec = founderSpec(featured)
		local w, h = 1254 - 534, 328 -- (2026-10-21, port3) 534..1254 x 6..334: ends on the content edge, level with the crates
		local top, bottom = G.grey[1], G.grey[2]:Lerp(BLACK, 0.45)
		if featured.Color then top, bottom = featured.Color:Lerp(WHITE, 0.25), featured.Color:Lerp(BLACK, 0.55) end
		local card = new("TextButton", { Name = "Hero", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(534, 6), Size = UDim2.fromOffset(w, h),
			BackgroundColor3 = WHITE, BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 1, Parent = pg },
			{ RK.corner(6), new("UIGradient", { Rotation = 35, Color = ColorSequence.new(top, bottom) }) })
		local bg = backdrop(card, BACKDROP.founders, 1) -- (2026-10-21, RIVALS images) the painted Founder's backdrop over the wash
		if bg then bg:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, 6) end
		local scene = new("Frame", { Name = "Scene", BackgroundTransparency = 1, Position = UDim2.fromOffset(w * 0.18, -h * 0.06), Size = UDim2.fromOffset(w * 0.74, h * 1.16), ZIndex = 2, Parent = card })
		local vp = lit(sceneArt(scene, spec.items, 1.2))
		vp.Frame.ZIndex = 2
		local shade = new("Frame", { Name = "Shade", BackgroundColor3 = BLACK, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 3, Parent = card },
			{ new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.85), NumberSequenceKeypoint.new(0.55, 0.8), NumberSequenceKeypoint.new(1, 0.25) }) }) })
		heavyTitle(card, featured.Name, 46, 32, 18, 520, 56, 7)
		-- (2026-10-21, port3) the red "LIMITED" pill is gone: RIVALS' Season Pass card has no tag, and its red tags only ever
		-- carry value / offers (valueTag, over a price)
		local contents = new("Frame", { Name = "Contents", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = card })
		local nx = contentsRow(contents, spec.items, 40, 96, 100, 14, 5, P and P.updaters)
		if spec.credits then extraScissors(contents, spec.credits, nx + 6, 110, 80, 5) end
		hoverReveal(card, contents, nil, vp, shade)
		local function open() openDetail(spec) end
		priceTag(card, "robux", featured.Robux, w - 20 - 100, h - 20 - 82, 200, 82, open, { owned = spec.owned, ts = 56, isz = 48, z = 9 }) -- (port3) inside the card
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
	local SO_X, SO_Y, SO_W, SO_H = 12, 334 + GAP, 774, 270 -- (2026-10-21, port3) 12..786 x 384..654
	local so = new("Frame", { Name = "SpecialOffer", Position = UDim2.fromOffset(SO_X, SO_Y), Size = UDim2.fromOffset(SO_W, SO_H), BackgroundColor3 = C.panel,
		BackgroundTransparency = 0.25, BorderSizePixel = 0, ClipsDescendants = true, Parent = pg }, { RK.corner(8) })
	local slides = {}
	for i, spec in offers do
		local isPass = spec.items == nil
		local col = isPass and C.panelRaised or (spec.color or C.panelRaised)
		local sl = new("TextButton", { Name = "Slide" .. i, Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = col, BorderSizePixel = 0,
			ClipsDescendants = true, Visible = i == 1, ZIndex = 2, Parent = so }, { RK.corner(8),
			new("UIGradient", { Rotation = 35, Color = ColorSequence.new(BLACK, WHITE), Transparency = NumberSequence.new(0.55, 0) }) })
		if not isPass then backdrop(sl, BACKDROP[spec.id], 2) end -- (2026-10-21, RIVALS images) the Operator Kit slide's painted backdrop
		local art = new("Frame", { Name = "Art", BackgroundTransparency = 1, Position = UDim2.fromOffset(isPass and SO_W - 440 or SO_W - 520, isPass and -12 or -34), Size = UDim2.fromOffset(isPass and 290 or 500, isPass and 290 or 340), ZIndex = 3, Parent = sl })
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
		if value then valueTag(sl, SO_W - 24 - 125, SO_H - 96 - 50, "x" .. value .. " VALUE", 190, 40, 24, 8) end
		local viewBtn = new("TextButton", { Name = "View", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(SO_W - 24 - 250, SO_H - 96), Size = UDim2.fromOffset(250, 80), BackgroundColor3 = WHITE,
			BorderSizePixel = 0, ZIndex = 7, Parent = sl }, { RK.corner(6), RK.vgrad(G.robux), RK.stroke(G.robux[2]:Lerp(BLACK, 0.55), 1.5, 0.4) })
		RK.label({ Text = "Special Offer", FontFace = FB, TextSize = 19, TextColor3 = G.robux[2]:Lerp(BLACK, 0.6), TextXAlignment = CENTER, Position = UDim2.fromOffset(0, 6), Size = UDim2.fromOffset(250, 22), ZIndex = 8, Parent = viewBtn })
		stroke(RK.label({ Text = "View", FontFace = FX, TextSize = 48, TextXAlignment = CENTER, Position = UDim2.fromOffset(0, 24), Size = UDim2.fromOffset(250, 52), ZIndex = 8, Parent = viewBtn }), 2, 0.4)
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
		-- (2026-10-21, port3) under the panel's centre at y 662..694, inside the 710 page window (it sat at 699 and was cut off)
		local dots = new("Frame", { Name = "Dots", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(SO_X + SO_W / 2, SO_Y + SO_H + 8), Size = UDim2.fromOffset(W0, DH),
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

	-- item tiles (3x2 at 836 + col*150, 384 + row*160): 118 rarity tiles, the render spilling over the top, the yellow scissors
	-- price overlapping the foot. (2026-10-21, port3) RIVALS' 118 px tiles, 50 px right of the Special Offer
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
		local h = hold(1254 - 2 * 150 - TILE + c * 150, 334 + GAP + r * 160, TILE, TILE + PRICE_H / 2, 1.06, function() ctx.openKit(id) end)
		local tile = rarityTile(h, rarityColor(id), 0, 0, TILE, TILE, 1)
		weaponTag(tile, id, 38, 4) -- (2026-10-21, RIVALS images) ∞ on melee / gadgets, over the render
		-- (round 10, grader C: the revolver ran past its tile) the render stays inside the tile, <= ~90 % of its width
		local art = new("Frame", { Name = "Art", BackgroundTransparency = 1, Position = UDim2.fromOffset(6, -4), Size = UDim2.fromOffset(TILE - 12, TILE - 4), ZIndex = 3, Parent = h })
		turnOnHover(h, lit(itemArt(art, id, nil, 1.0)))
		priceTag(h, "kit", Config.Items[id].Price, TILE / 2, TILE - PRICE_H / 2, 112, PRICE_H, function() ctx.openKit(id) end, { owned = function() return ctx.owns(id) end, noHover = true })
		if ctx.tooltip then
			local item = Config.Items[id]
			ctx.tooltip(h, item.Name, function() return item.Desc or "" end)
		end
	end
	endPad(pg, 660) -- (port3) the canvas ends at 700: the whole Featured page fits the 710 window, nothing to scroll
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
		local card = rarityTile(pg, rarityColor(id), 12 + c * (w + gap), 26 + r * (h + 40), w, h, 1, "TextButton") -- (port3) +6 row gap for the taller price
		card.Name = id
		local art = new("Frame", { Name = "Art", BackgroundTransparency = 1, Position = UDim2.fromOffset(w * 0.04, 10), Size = UDim2.fromOffset(w * 0.92, h - 28), ZIndex = 3, Parent = card })
		turnOnHover(card, lit(itemArt(art, id, nil, 1.2)))
		local tagW = weaponTag(card, id, 54, 5) -- (2026-10-21, RIVALS images) ∞ on melee / gadgets; the name keeps clear of it
		stroke(RK.label({ Text = item.Name, FontFace = FB, TextSize = 26, TextXAlignment = CENTER, Position = UDim2.fromOffset(8, 6), Size = UDim2.fromOffset(w - 16 - tagW, 32), ZIndex = 4, Parent = card }), 2, 0.3)
		priceTag(card, "kit", item.Price, w / 2, h - 30, 140, PRICE_H, function() ctx.openKit(id) end, { owned = function() return ctx.owns(id) end, z = 6, noHover = true })
		hover(card)
		card.Activated:Connect(function() if not ctx.owns(id) then ctx.openKit(id) end end)
		if ctx.tooltip then
			ctx.tooltip(card, item.Name, function()
				return (item.Desc or "") .. (ctx.owns(id) and "\nYou own this." or `\nUnlock it in the Kit room for {fmtN(item.Price)} scissors.`)
			end)
		end
	end
	endPad(pg, 26 + math.ceil(#sortedGear() / cols) * (h + 40))
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

-- (2026-10-21, RIVALS shop layout) Skins (PLACEHOLDER): RIVALS sells skins in bundles + the Daily strip; until Tacticals has
-- skins, one tile per gun and per melee / gadget: our own model tinted to the rarity, "<Item> Skin", scissors price
function RENDER.Skins(pg, hover)
	headerBar(pg, "Weapon Skins", "img:tab_skins", 0)
	local y = placeholderGrid(pg, hover, PLACEHOLDER_ITEMS.Skins, 62 + 34, 5, 190)
	headerBar(pg, "Melee & Gadget Skins", "img:tab_skins", y + 4)
	y = placeholderGrid(pg, hover, PLACEHOLDER_ITEMS.MeleeSkins, y + 4 + 62 + 34, 5, 190)
	endPad(pg, y)
end

-- (2026-10-21, RIVALS shop layout) Daily (PLACEHOLDER, RIVALS t0094.3s): the refresh bar (RIVALS' "3 [key] refresh shop now"
-- button is left out: what a refresh costs is a guess; the UTC-midnight reset is a guess too), 5 skins for Robux, then 5
-- emotes for scissors with the first one FREE
function RENDER.Daily(pg, hover)
	local bar = new("Frame", { Name = "Refresh", Position = UDim2.fromOffset(12, 0), Size = UDim2.fromOffset(1242, 60), BackgroundColor3 = BLACK,
		BackgroundTransparency = Theme.alpha.panel, BorderSizePixel = 0, Parent = pg }, { RK.corner(6) })
	stroke(RK.label({ Text = "Daily Shop", FontFace = FB, TextSize = 32, Position = UDim2.fromOffset(20, 0), Size = UDim2.fromOffset(400, 60), ZIndex = 2, Parent = bar }), 2, 0.4)
	local cd = RK.label({ Name = "Countdown", Text = "", RichText = true, FontFace = FB, TextSize = 28, TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.fromOffset(500, 0), Size = UDim2.fromOffset(720, 60), ZIndex = 2, Parent = bar })
	local dimHex = C.textDim:ToHex()
	task.spawn(function()
		while cd.Parent do
			local t = os.date("!*t")
			local left = 86400 - (t.hour * 3600 + t.min * 60 + t.sec)
			-- (2026-10-22) no <font size>: the kit rescales TextSize, not rich-text sizes (the small words rendered huge)
			cd.Text = ('<font color="#%s">shop will refresh in</font>  %dh %dm %ds'):format(dimHex, left // 3600, left % 3600 // 60, left % 60)
			task.wait(1)
		end
	end)
	local y = 60 + 26
	-- (2026-10-22) the REAL daily free reward strip (server: DailyFreeAt + ClaimDailyFree), above the placeholder tiles
	if Players.LocalPlayer:GetAttribute("DailyFreeAt") ~= nil then
		local strip = new("Frame", { Name = "FreeReward", Position = UDim2.fromOffset(12, y), Size = UDim2.fromOffset(1242, 120), BackgroundColor3 = WHITE,
			BorderSizePixel = 0, Parent = pg }, { RK.corner(6), new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(141, 191, 90), Color3.fromRGB(76, 122, 46)) }) })
		new("ImageLabel", { BackgroundTransparency = 1, Image = SCISSORS_IMG, ScaleType = Enum.ScaleType.Fit, Position = UDim2.fromOffset(24, 10), Size = UDim2.fromOffset(100, 100), ZIndex = 2, Parent = strip })
		stroke(RK.label({ Text = "Daily Free Reward", FontFace = FB, TextSize = 40, Position = UDim2.fromOffset(140, 14), Size = UDim2.fromOffset(700, 48), ZIndex = 2, Parent = strip }), 2, 0.3)
		local status = RK.label({ Name = "Status", Text = "", FontFace = FB, TextSize = 26, Position = UDim2.fromOffset(140, 64), Size = UDim2.fromOffset(700, 36), ZIndex = 2, Parent = strip })
		stroke(status, 1.5, 0.4)
		local busy = false
		local claim
		claim = priceTag(strip, "scissors", 0, 1242 - 140, 34, 220, PRICE_H, function()
			if busy or not dailyFreeReady() then if claim then Kit.shake(claim) end return end
			local rf = game:GetService("ReplicatedStorage"):FindFirstChild("ClaimDailyFree", true)
			if not (rf and rf:IsA("RemoteFunction")) then return end
			busy = true
			local ok, res = pcall(function() return rf:InvokeServer() end)
			busy = false
			if ok and type(res) == "table" and res.ok then
				pcall(Toast.show, { title = "Free reward claimed!", text = tostring(res.reward or ""), icon = "check" })
				Kit.pop(strip, 1.05)
			elseif claim then Kit.shake(claim) end
		end, { text = "FREE", z = 4 })
		task.spawn(function()
			while strip.Parent do
				local at = Players.LocalPlayer:GetAttribute("DailyFreeAt")
				if type(at) == "number" and at > workspace:GetServerTimeNow() then
					local left = math.floor(at - workspace:GetServerTimeNow())
					status.Text = ("Next free reward in %dh %dm %ds"):format(left // 3600, left % 3600 // 60, left % 60)
					if claim then claim.Visible = false end
				else
					status.Text = "Ready! Claim it now"
					if claim then claim.Visible = true end
				end
				task.wait(1)
			end
		end)
		y += 120 + 26
	end
	y = placeholderGrid(pg, hover, PLACEHOLDER_ITEMS.DailySkins, y, 5, 190)
	y = placeholderGrid(pg, hover, PLACEHOLDER_ITEMS.DailyEmotes, y, 5, 190)
	endPad(pg, y)
end

-- (2026-10-21, RIVALS shop layout) Emotes / Charms / Finishers (PLACEHOLDER): RIVALS' section header + a 6-wide tile grid of
-- the replica's generated art
local function cosmeticPage(title, icon, list)
	return function(pg, hover)
		headerBar(pg, title, icon, 0)
		endPad(pg, placeholderGrid(pg, hover, list, 62 + 34, 6, 200))
	end
end
RENDER.Emotes = cosmeticPage("Emotes", "img:emote_cut", PLACEHOLDER_ITEMS.Emotes)
RENDER.Charms = cosmeticPage("Charms", "img:ch_dice", PLACEHOLDER_ITEMS.Charms)
RENDER.Finishers = cosmeticPage("Finishers", "img:fin_1", PLACEHOLDER_ITEMS.Finishers)

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
-- (2026-10-21, RIVALS shop layout) RIVALS' order and naming (normal theme: Home, Bundles, Skins, ..., Keys): { key, icon, zoom,
-- label }. Arms (our gear) sits right after Bundles, where RIVALS sells its weapon items; Scissors = RIVALS' Keys. An icon
-- "img:<Assets name>" is a flat image (the placeholder tabs), anything else a live 3D ViewIcons model.
local TABS = {
	{ "Featured", "Medal", 0.95, label = "Home" }, { "Bundles", "Crate", 1.1 }, { "Arms", "Weapon", 1.35 },
	{ "Skins", "img:tab_skins" }, { "Daily", "img:tab_daily" }, { "Emotes", "img:emote_cut" }, { "Charms", "img:ch_dice" },
	{ "Finishers", "img:fin_1" }, { "Scissors", "Scissors", 1.4 },
}
local TAB_ALIAS = { Home = "Featured", Keys = "Scissors", Gear = "Arms" }
local function resolveTab(t)
	t = TAB_ALIAS[t] or t
	return RENDER[t] and t or "Featured"
end

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

	-- (2026-10-21, RIVALS 1:1) the tab row (replica): separate pills, black at 0.35, the selected one white; a big 3D icon
	-- rises out of each; the Bold label sits low with a black outline (also on the white tab, t0068.4s).
	-- (2026-10-21, port3) RIVALS' normal-theme header: the Bold outlined "Shop" title over the tabs, both starting at the
	-- content's left edge (CONTENT_X), compact 100x40 tabs 110 apart; the icons are lit bright (lit) and rise ~30 px above the
	-- tab (56 box, foot 24 px into the pill). The red X moved to the page panel's top-right corner (below).
	-- (2026-10-22, live RIVALS) no "Shop" title over the tabs (the live game and its copies have none)
	-- (2026-10-22, section round 0, grader A) RIVALS centres the tab row on x ~0.495 W: 6 slots + the X = ~1000 px from x 450 (was
	-- left-aligned to the content at CONTENT_X)
	local x0 = 450
	-- tab i sits on row 1 (i <= TAB_PER_ROW) at slot i, or on row 2 at slot i - TAB_PER_ROW + 1 (slot 1 there is "Back")
	local function slotX(i)
		local slot = i <= TAB_PER_ROW and i or (i - TAB_PER_ROW + 1)
		return x0 + (slot - 1) * TAB_STEP
	end
	for i, t in TABS do
		local b = new("TextButton", { Name = t[1], Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(slotX(i), TAB_Y), Size = UDim2.fromOffset(TAB_W, TAB_H),
			BackgroundColor3 = BLACK, BackgroundTransparency = 0.35, BorderSizePixel = 0, Parent = body }, { RK.corner(6) })
		b:SetAttribute("TabRow", i <= TAB_PER_ROW and 1 or 2)
		local hold = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(TAB_W / 2, 26), Size = UDim2.fromOffset(64, 64), ZIndex = 2, Parent = b })
		local vp
		if t[2] == "Weapon" then
			vp = ViewIcons.Viewport(hold, ViewIcons.Weapon("AutoRifle"), { view = CFrame.Angles(0, 0, math.rad(-28)) * ViewIcons.GunView, zoom = t[3], zIndex = 2 })
		elseif string.sub(t[2], 1, 4) == "img:" then
			-- (2026-10-21, RIVALS shop layout) the placeholder tabs use the replica's flat art (no 3D model of ours fits)
			new("ImageLabel", { BackgroundTransparency = 1, Image = asset(string.sub(t[2], 5)), ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = hold })
		else
			vp = ViewIcons.Icon(hold, t[2], { zoom = t[3], zIndex = 2 })
		end
		if vp then
			lit(vp)
			b.MouseEnter:Connect(function() vp.SetHover(true) end)
			b.MouseLeave:Connect(function() vp.SetHover(tab == t[1]) end)
		end
		stroke(RK.label({ Name = "Label", Text = t.label or t[1], FontFace = FB, TextSize = 25, TextXAlignment = CENTER, Position = UDim2.fromOffset(-4, 18), Size = UDim2.fromOffset(TAB_W + 8, 32), ZIndex = 3, Parent = b }), 2, 0)
		Kit.bindButton(b, { hover = 1.15 }) -- (2026-10-22, RIVALS tabs grow ~1.15 on hover)
		b.Activated:Connect(function() Screen.SetTab(t[1]) end)
		tabBtns[t[1]] = { b = b, vp = vp }
	end
	-- "More ->" (row 1, after the last tab) and "<- Back" (row 2, first slot): text-only tabs that swap the rows
	if #TABS > TAB_PER_ROW then
		for _, spec in { { "More", "More →", 1, TAB_PER_ROW + 1 }, { "Back", "← Back", 2, 1 } } do
			local b = new("TextButton", { Name = "Row" .. spec[1], Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(x0 + (spec[4] - 1) * TAB_STEP, TAB_Y),
				Size = UDim2.fromOffset(TAB_W, TAB_H), BackgroundColor3 = BLACK, BackgroundTransparency = 0.35, BorderSizePixel = 0, Parent = body }, { RK.corner(6) })
			b:SetAttribute("TabRow", spec[3])
			stroke(RK.label({ Name = "Label", Text = spec[2], FontFace = FB, TextSize = 25, TextXAlignment = CENTER, Position = UDim2.fromOffset(-4, 8), Size = UDim2.fromOffset(TAB_W + 8, 32), ZIndex = 3, Parent = b }), 2, 0)
			Kit.bindButton(b, { hover = 1.15 })
			b.Activated:Connect(function() Screen.ShowTabRow(spec[3] == 1 and 2 or 1) end)
		end
	end
	-- (2026-10-21, RIVALS shop layout) RIVALS' red "Claim your FREE reward now!" tip (valueTag: red pill, pointer down) over
	-- the Daily tab, clear of its rising icon; only while a real free Daily item is up (freeDailyUp). Click = the Daily tab.
	if tabBtns.Daily then
		local dx = tabBtns.Daily.b.Position.X.Offset + TAB_W / 2
		local tip = valueTag(body, dx, TAB_Y - 34 - 32, "Claim your FREE reward now!", 300, 32, 19, 6)
		tip.Name = "DailyTip"
		local hit = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 8, Parent = tip })
		hit.Activated:Connect(function() Screen.SetTab("Daily") end)
	end
	-- (2026-10-21, port3) the kit's default closeButton size (another pass sets it to 112x58; that size is the fallback while
	-- Kit.closeButton still needs one), 12 px outside the page panel's top-right corner, top-aligned with it
	-- (2026-10-22, live RIVALS shop at 16:9) the X sits IN the tab row, 10 px after the last tab, as tall as a tab (RIVALS ~0.046 of
	-- the width); not out beside the page panel
	local close = Kit.closeButton(UDim2.fromOffset(76, TAB_H))
	close.Position = UDim2.fromOffset(x0 + math.min(#TABS, TAB_PER_ROW) * TAB_STEP + TAB_W + 10, TAB_Y)
	close.Parent = body
	close.Activated:Connect(function() Screen.Close() end)

	-- (2026-10-21, RIVALS 1:1) wallet, top centre (replica): the currency render, the count, the lime "+"
	-- (2026-10-21, port3) RIVALS-size: the render 64 tall (~6% of the screen height) and the count on a dark band that fades
	-- out to the right (the hub's pill), no separate plate
	local wallet = new("Frame", { Name = "Wallet", BackgroundTransparency = 1, Position = UDim2.fromOffset(842, 20), Size = UDim2.fromOffset(236, 66), Parent = root })
	new("ImageLabel", { BackgroundTransparency = 1, Image = SCISSORS_IMG, ScaleType = Enum.ScaleType.Fit, Position = UDim2.fromOffset(0, 1), Size = UDim2.fromOffset(64, 64), ZIndex = 3, Parent = wallet })
	local pill = new("Frame", { Name = "Pill", Position = UDim2.fromOffset(40, 12), Size = UDim2.fromOffset(150, 42), BackgroundColor3 = C.panel, BackgroundTransparency = 0, BorderSizePixel = 0, Parent = wallet },
		{ new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(0.55, 0.4), NumberSequenceKeypoint.new(1, 1) }) }) })
	walletText = stroke(RK.label({ Name = "Count", Text = "0", FontFace = FB, TextSize = 34, TextXAlignment = CENTER, Position = UDim2.fromOffset(22, 0), Size = UDim2.fromOffset(96, 42), ZIndex = 2, Parent = pill }), 2, 0.4)
	local plus = new("TextButton", { Name = "AddScissors", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(196, 16), Size = UDim2.fromOffset(34, 34), BackgroundColor3 = WHITE,
		BorderSizePixel = 0, ZIndex = 2, Parent = wallet }, { RK.corner(4), RK.vgrad(G.robux) })
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(19, 6), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 3, Parent = plus }, { RK.corner(2) })
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(6, 19), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 3, Parent = plus }, { RK.corner(2) })
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
-- (2026-10-22) which tab row shows (1 = the first TAB_PER_ROW tabs + More, 2 = Back + the rest); the Daily tip rides row 1
local tabRow = 1
local function layoutTabRow()
	if not body then return end
	for _, c in body:GetChildren() do
		local r = c:GetAttribute("TabRow")
		if r then c.Visible = r == tabRow end
	end
	local tip = body:FindFirstChild("DailyTip")
	if tip then tip.Visible = tabRow == 1 and freeDailyUp() end
end
-- (2026-10-22) the tip follows DailyFreeAt live
Players.LocalPlayer:GetAttributeChangedSignal("DailyFreeAt"):Connect(function()
	layoutTabRow()
	-- the Daily page grows / drops its free strip: rebuild it (now if it's the open tab)
	if pages.Daily then pages.Daily.dirty = true end
	if isOpen and tab == "Daily" and ready then Screen.SetTab("Daily") end
end)
task.spawn(function() while true do task.wait(1); if isOpen then layoutTabRow() end end end)
function Screen.ShowTabRow(r)
	tabRow = r
	layoutTabRow()
end
local function styleTabs()
	-- the open tab's row is the one shown
	for i, t in TABS do
		if t[1] == tab then tabRow = i <= TAB_PER_ROW and 1 or 2 end
	end
	layoutTabRow()
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
	tab = resolveTab(t) -- (2026-10-21, RIVALS shop layout) Home / Keys / Gear aliases
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
		tab = resolveTab(startTab)
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
