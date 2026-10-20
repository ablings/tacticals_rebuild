-- Client/Controllers/TrainingBinsController (client, lobby place): the Training weapon picker (UI session, Shadow PC, 2026-10-19).
-- Edward: "add this as a pop up screen for when you go into the training room" + "make this be the ui for when you press the
-- trash bins too". Look from RIVALS' training-room picker (notes/ref/rivals_training_picker.webp):
--   * a dark translucent pill "Try out any weapon here for free!", a row of square slot tabs (LobbyConfig.Slots: Weapon /
--     Gadget / Melee; the open one white-outlined, the others dim), and a 5-wide grid of square tiles: "Random" first (shuffle
--     mark on black), then EVERY item of that slot, owned or not, the Kit's 3D render poking out past the tile at an angle and
--     the bold outlined name across the bottom. Tiles are a dark gradient tinted by LobbyConfig rarity (Legendary sparkles);
--     this round's pick is white-edged, hover / controller selection lights the Tacticals olive.
--   * the world behind blurs hard (Lighting.TrainingPickerBlur, like the Kit).
-- Opens: on entering Training (InTraining -> true), at a weapon bin (ProximityPrompt with attribute TrainingBin), the
-- "Weapons" button at the top of the screen, T / D-pad up. Every open starts blank and walks Weapon -> Gadget -> Melee
-- (Edward's flow, see "open / close / pick" below); the last pick applies the kit and closes.
-- Closes: the X, Esc, B (gamepad), T / D-pad up again (all of these cancel: the old kit comes back), leaving Training.
-- Equip (Training only, never the real loadout): Events.Training.TrialKit / TrialItem (server: Handoff preparation).
-- UI rule: every Position / Size in Scale (design px 1920 x 1080 through S()).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local okTX, TX = pcall(require, ReplicatedStorage.Modules.Shared.Config.TrainingConfig)
local Config = require(ReplicatedStorage.Modules.Shared.Config.LobbyConfig)
local UIKit = ReplicatedStorage:WaitForChild("UIKit")
local ViewIcons = require(UIKit:WaitForChild("ViewIcons"))
local okKit, Kit = pcall(require, UIKit:WaitForChild("Kit"))

local player = Players.LocalPlayer
local controller = {}
local DW, DH = 1920, 1080
local function S(x, y) return UDim2.fromScale(x / DW, y / DH) end                       -- design px -> Scale of the canvas
local function R(x, y, w, h) return UDim2.fromScale(x / w, y / h) end                     -- px -> Scale of a w x h parent
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local OLIVE = Color3.fromRGB(138, 156, 74)                                                 -- Tac.C.oliveHi: the Kit's accent
local AMBER = Color3.fromRGB(255, 196, 92)
local FONT_H = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)
local FONT_B = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
local TITLE = "Try out any weapon here for free!"
local TRIAL_ATTR = { Weapon = "TrialWeapon", Gadget = "TrialGadget", Melee = "TrialMelee" }
local SLOTS = Config.Slots or { "Weapon", "Gadget", "Melee" }

-- grid geometry (design px, measured off the reference at 1080 high)
local TILE, PITCH, COLS = 124, 160, 5
local GRID_X, GRID_Y, GRID_H = 960 - ((COLS - 1) * PITCH + TILE) / 2, 420, 4 * PITCH
local TAB, TAB_PITCH, TAB_Y = 100, 108, 286

local gui, root, gridHolder, tabsHolder, dots, weaponsBtn, trialTag, blur
local isOpen, ready, slotNow, closedAt = false, false, SLOTS[1], 0
local grids, tabs, tiles = {}, {}, {}                                                      -- per slot; tiles[slot][id] = button
local picks = {}                                                                           -- this round's picks: [slot] = itemId
local trialEvent, swapEvent

-------------------------------------------------------------------------------
-- small builders
-------------------------------------------------------------------------------
local function new(class, props, kids)
	local o = Instance.new(class)
	for k, v in props or {} do if k ~= "Parent" then o[k] = v end end
	for _, c in kids or {} do c.Parent = o end
	if props and props.Parent then o.Parent = props.Parent end
	return o
end
local function corner(scale) return new("UICorner", { CornerRadius = UDim.new(scale, 0) }) end
local function label(parent, name, pos, size, text, font, z)
	local l = new("TextLabel", { Name = name, BackgroundTransparency = 1, Position = pos, Size = size, Text = text, TextScaled = true,
		TextColor3 = WHITE, FontFace = font or FONT_H, ZIndex = z or 1, Parent = parent })
	new("UIStroke", { Thickness = 2, Color = BLACK, Transparency = 0.1, Parent = l })
	return l
end
local function button(props)
	local b = new("TextButton", props)
	b.AutoButtonColor, b.Text = false, ""
	b:AddTag("Nonapplicable")                    -- the old InterfaceController would hover-tween it (Offset) to 0 x 0
	if okKit and Kit.bindButton then Kit.bindButton(b) end
	return b
end

-- the Kit's render of any LobbyConfig item (LobbyUIController.Icons.Item), else the Repository model
local IconsMod
local function itemModel(id, slot)
	if IconsMod == nil then
		IconsMod = false
		local lui = script.Parent:FindFirstChild("LobbyUIController")
		local m = lui and lui:WaitForChild("Icons", 5)
		local ok, mod = pcall(function() return m and require(m) end)
		if ok and mod and mod.Item then IconsMod = mod end
	end
	if IconsMod then
		local ok, model, view, zoom = pcall(IconsMod.Item, id)
		if ok and model then return model, view, zoom end
	end
	if slot == "Melee" then return ViewIcons.Melee(id), CFrame.Angles(0, math.rad(-90), 0) * CFrame.Angles(math.rad(38), 0, 0), 1 end
	return ViewIcons.Weapon(id), ViewIcons.GunView, 0.95
end

-- slot items: every LobbyConfig item of the slot, rarest first, then by name
local function itemsFor(slot)
	local list = {}
	for id, it in Config.Items do if it.Slot == slot then table.insert(list, id) end end
	local rar = Config.Rarities or {}
	table.sort(list, function(a, b)
		local ra = rar[Config.Items[a].Rarity or ""]; ra = ra and ra.Order or 0
		local rb = rar[Config.Items[b].Rarity or ""]; rb = rb and rb.Order or 0
		if ra ~= rb then return ra > rb end
		return (Config.Items[a].Name or a) < (Config.Items[b].Name or b)
	end)
	return list
end


-------------------------------------------------------------------------------
-- tiles
-------------------------------------------------------------------------------
local function sparkle(parent, x, y, s, delay)
	-- a four-point star from two thin rotated diamonds, twinkling
	local f = new("Frame", { Name = "Sparkle", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(s, s), ZIndex = 4, Parent = parent }, { new("UIAspectRatioConstraint", { AspectRatio = 1 }) })
	for _, sz in { Vector2.new(0.22, 1), Vector2.new(1, 0.22) } do
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(sz.X, sz.Y),
			BackgroundColor3 = Color3.fromRGB(255, 244, 200), BorderSizePixel = 0, ZIndex = 4, Parent = f }, { corner(0.5) })
	end
	local sc = new("UIScale", { Scale = 0.4, Parent = f })
	task.delay(delay, function()
		TweenService:Create(sc, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1 }):Play()
	end)
end

local function tileLook(b)
	local hover = b:GetAttribute("Hover") == true
	local isHeld = b:GetAttribute("Held") == true
	local edge = b.Bg.Edge
	edge.Color = hover and OLIVE or WHITE
	edge.Transparency = (hover or isHeld) and 0 or 1
	edge.Thickness = isHeld and not hover and 3 or 2.5
end

local function makeTile(parent, slot, id, index)
	local col, row = (index - 1) % COLS, (index - 1) // COLS
	local gw, gh = (COLS - 1) * PITCH + TILE, GRID_H
	local b = button({ Name = id, BackgroundTransparency = 1, Position = R(col * PITCH, row * PITCH, gw, gh), Size = R(TILE, TILE, gw, gh),
		ZIndex = 2, Parent = parent })
	b:SetAttribute("Slot", slot)
	local bg = new("Frame", { Name = "Bg", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 2, Parent = b }, { corner(0.07) })
	new("UIStroke", { Name = "Edge", ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = WHITE, Thickness = 2.5, Transparency = 1, Parent = bg })
	if id == "Random" then
		bg.BackgroundColor3 = BLACK
		-- RIVALS' shuffle mark: two crossing arrows, drawn from bars
		local mark = new("Frame", { Name = "Shuffle", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42),
			Size = UDim2.fromScale(0.56, 0.4), ZIndex = 3, Parent = bg })
		local grey = Color3.fromRGB(58, 58, 62)
		for _, s in { 1, -1 } do
			new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.45, 0.5), Size = UDim2.fromScale(0.95, 0.16), Rotation = 28 * s,
				BackgroundColor3 = grey, BorderSizePixel = 0, ZIndex = 3, Parent = mark }, { corner(0.5) })
			local tip = UDim2.fromScale(0.9, s == 1 and 0.88 or 0.12)
			for _, r in { 45, -45 } do
				new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = tip, Size = UDim2.fromScale(0.32, 0.15), Rotation = r + 28 * s,
					BackgroundColor3 = grey, BorderSizePixel = 0, ZIndex = 3, Parent = mark }, { corner(0.5) })
			end
		end
		label(b, "Name", UDim2.fromScale(-0.15, 0.7), UDim2.fromScale(1.3, 0.24), "Random", FONT_H, 6)
	else
		local it = Config.Items[id] or {}
		local rar = Config.Rarities and Config.Rarities[it.Rarity or ""]
		local top, bottom = Color3.fromRGB(64, 64, 70), Color3.fromRGB(14, 14, 16)
		if rar and it.Rarity ~= "Standard" then top, bottom = rar.Color, rar.Color:Lerp(BLACK, 0.78) end
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(top, bottom), Parent = bg })
		if it.Rarity == "Legendary" then
			sparkle(bg, 0.16, 0.2, 0.2, 0); sparkle(bg, 0.84, 0.62, 0.16, 0.45); sparkle(bg, 0.3, 0.78, 0.12, 0.8)
		end
		-- the render, bigger than the tile so it pokes out at an angle (RIVALS)
		local art = new("Frame", { Name = "Art", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4),
			Size = UDim2.fromScale(1.5, 1.5), ZIndex = 5, Parent = b })
		local model, view, zoom = itemModel(id, slot)
		local tilt = CFrame.Angles(0, 0, math.rad(slot == "Weapon" and 24 or 12))
		local vp = ViewIcons.Viewport(art, model, { view = tilt * (view or CFrame.identity), zoom = (zoom or 1) * 1.05, still = true, zIndex = 5 })
		vp.Frame.Ambient = Color3.fromRGB(165, 165, 170)
		label(b, "Name", UDim2.fromScale(-0.15, 0.7), UDim2.fromScale(1.3, 0.24), it.Name or id, FONT_H, 6)
	end
	b.MouseEnter:Connect(function() b:SetAttribute("Hover", true) end)
	b.MouseLeave:Connect(function() b:SetAttribute("Hover", false) end)
	b.SelectionGained:Connect(function() b:SetAttribute("Hover", true) end)
	b.SelectionLost:Connect(function() b:SetAttribute("Hover", false) end)
	b:GetAttributeChangedSignal("Hover"):Connect(function() tileLook(b) end)
	b:GetAttributeChangedSignal("Held"):Connect(function() tileLook(b) end)
	b.Activated:Connect(function() controller.Pick(slot, id) end)
	return b
end

-------------------------------------------------------------------------------
-- tabs
-------------------------------------------------------------------------------
local function tabLook(slot)
	for s, t in tabs do
		local on = s == slot
		t.Button.Edge.Transparency = on and 0 or 1
		t.Button.BackgroundTransparency = on and 0 or 0.35
		t.Button:SetAttribute("NavTabOn", on)
		if t.Vp then t.Vp.Frame.ImageTransparency = on and 0 or 0.45 end
		t.Name.TextTransparency = on and 0 or 0.4
	end
end

-- a tab shows what you picked for its slot this time (Edward: the boxes start empty and fill as you go)
local function tabIcon(slot)
	local t = tabs[slot]
	if not t then return end
	local id = picks[slot]
	if t.Id == id then return end
	t.Id = id
	if t.Vp then t.Vp.Frame:Destroy(); t.Vp = nil end
	if id then
		local model, view, zoom = itemModel(id, slot)
		t.Vp = ViewIcons.Viewport(t.Holder, model, { view = view, zoom = (zoom or 1) * 0.95, still = true, zIndex = 4 })
	end
	tabLook(slotNow)
end

local function showSlot(slot)
	slotNow = slot
	for s, g in grids do g.Visible = s == slot end
	tabLook(slot)
end

local function refreshPicks()
	for slot, list in tiles do
		for id, b in list do b:SetAttribute("Held", id == picks[slot]) end
		tabIcon(slot)
	end
end

-------------------------------------------------------------------------------
-- build
-------------------------------------------------------------------------------
local function build()
	-- Global: every render (ZIndex 5) and name (6) draws over every tile (2), so a gun poking out overlaps its neighbours (RIVALS)
	gui = new("ScreenGui", { Name = "WeaponBin", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Global,
		DisplayOrder = 20, Parent = player:WaitForChild("PlayerGui") })
	-- 16:9 canvas so the design px map 1:1 to Scale everywhere
	local canvas = new("Frame", { Name = "Canvas", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1), Parent = gui }, { new("UIAspectRatioConstraint", { AspectRatio = DW / DH }) })

	-- the reopen button + trial line (top centre, only in Training)
	weaponsBtn = button({ Name = "WeaponsButton", AnchorPoint = Vector2.new(0.5, 0), Position = S(960, 74), Size = S(214, 50),
		BackgroundColor3 = BLACK, BackgroundTransparency = 0.45, Visible = false, Parent = canvas })
	corner(0.5).Parent = weaponsBtn
	new("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = WHITE, Transparency = 0.75, Thickness = 1.5, Parent = weaponsBtn })
	label(weaponsBtn, "Label", UDim2.fromScale(0.08, 0.16), UDim2.fromScale(0.58, 0.68), "Weapons", FONT_H, 2).TextXAlignment = Enum.TextXAlignment.Left
	local chip = new("Frame", { Name = "KeyChip", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(0.93, 0.5), Size = UDim2.fromScale(0.26, 0.64),
		BackgroundColor3 = WHITE, BackgroundTransparency = 0.1, Parent = weaponsBtn }, { corner(0.3) })
	local keyText = new("TextLabel", { Name = "Key", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "T", TextScaled = true,
		TextColor3 = BLACK, FontFace = FONT_H, Parent = chip }, { new("UIPadding", { PaddingTop = UDim.new(0.14, 0), PaddingBottom = UDim.new(0.14, 0) }) })
	local function keyHint()
		local t = UserInputService:GetLastInputType()
		local pad = t.Name:find("Gamepad") ~= nil
		local touch = t == Enum.UserInputType.Touch
		chip.Visible = not touch
		keyText.Text = pad and "D-Up" or "T"
	end
	UserInputService.LastInputTypeChanged:Connect(keyHint); keyHint()
	weaponsBtn.Activated:Connect(function() if isOpen then controller.Close() else controller.Open() end end)
	trialTag = label(canvas, "TrialTag", S(760, 130), S(400, 30), "", FONT_H, 1)
	trialTag.TextColor3 = AMBER; trialTag.Visible = false

	-- the picker
	root = new("Frame", { Name = "Picker", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = canvas })
	local pill = new("Frame", { Name = "TitlePill", AnchorPoint = Vector2.new(0.5, 0.5), Position = S(960, 232), Size = S(500, 58),
		BackgroundColor3 = BLACK, BackgroundTransparency = 0.5, Parent = root }, { corner(0.3) })
	label(pill, "Title", UDim2.fromScale(0.05, 0.18), UDim2.fromScale(0.9, 0.62), TITLE, FONT_H, 2)
	-- the X: RIVALS' red close, right of the pill
	local x = button({ Name = "CloseX", AnchorPoint = Vector2.new(0.5, 0.5), Position = S(1250, 232), Size = S(52, 52), BackgroundColor3 = WHITE, Parent = root })
	corner(0.2).Parent = x
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 86, 76), Color3.fromRGB(196, 32, 32)), Parent = x })
	new("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = BLACK, Transparency = 0.5, Thickness = 1.5, Parent = x })
	for _, rot in { 45, -45 } do
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.6, 0.17), Rotation = rot,
			BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = x }, { corner(0.4) })
	end
	x.Activated:Connect(function() controller.Close() end)

	-- slot tabs
	local n = #SLOTS
	tabsHolder = new("Frame", { Name = "Tabs", BackgroundTransparency = 1, Position = S(960 - ((n - 1) * TAB_PITCH + TAB) / 2, TAB_Y),
		Size = S((n - 1) * TAB_PITCH + TAB, TAB + 26), Parent = root })
	local tw, th = (n - 1) * TAB_PITCH + TAB, TAB + 26
	for i, slot in SLOTS do
		local b = button({ Name = slot .. "Tab", Position = R((i - 1) * TAB_PITCH, 0, tw, th), Size = R(TAB, TAB, tw, th), BackgroundColor3 = WHITE, ZIndex = 2, Parent = tabsHolder })
		corner(0.12).Parent = b
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(70, 70, 76), Color3.fromRGB(10, 10, 12)), Parent = b })
		new("UIStroke", { Name = "Edge", ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = WHITE, Thickness = 5, Transparency = 1, Parent = b })
		b:SetAttribute("NavTab", i)
		local holder = new("Frame", { Name = "Icon", BackgroundTransparency = 1, Position = UDim2.fromScale(0.08, 0.06), Size = UDim2.fromScale(0.84, 0.84), ZIndex = 3, Parent = b })
		local nm = label(tabsHolder, slot .. "Name", R((i - 1) * TAB_PITCH, TAB + 4, tw, th), R(TAB, 22, tw, th), (Config.SlotNames and Config.SlotNames[slot]) or slot:upper(), FONT_B, 2)
		tabs[slot] = { Button = b, Holder = holder, Name = nm }
		b.Activated:Connect(function() showSlot(slot) end)
		b:GetAttributeChangedSignal("NavPressed"):Connect(function() showSlot(slot) end)   -- LB / RB (GamepadNavController)
	end

	-- grids: one per slot, built behind the loading dots
	gridHolder = new("Frame", { Name = "Grids", BackgroundTransparency = 1, Position = S(GRID_X, GRID_Y), Size = S((COLS - 1) * PITCH + TILE, GRID_H), Parent = root })
	if okKit and Kit.loadingDots then
		dots = Kit.loadingDots(root)
		dots.Position = S(960, 560)
	end
end

local function buildGrids()
	for _, slot in SLOTS do
		local g = new("Frame", { Name = slot, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = gridHolder })
		grids[slot], tiles[slot] = g, {}
		local list = itemsFor(slot)
		makeTile(g, slot, "Random", 1)
		for i, id in list do
			tiles[slot][id] = makeTile(g, slot, id, i + 1)
			if i % 4 == 0 then task.wait() end                -- spread the viewport builds over frames
		end
	end
	ready = true
	if dots then dots.Visible = false end
	refreshPicks()
	showSlot(slotNow)
end

-------------------------------------------------------------------------------
-- open / close / pick
-------------------------------------------------------------------------------
local function setBlur(on)
	blur = Lighting:FindFirstChild("TrainingPickerBlur") or new("BlurEffect", { Name = "TrainingPickerBlur", Size = 0, Parent = Lighting })
	blur.Enabled = true
	TweenService:Create(blur, TweenInfo.new(on and 0.25 or 0.18), { Size = on and 22 or 0 }):Play()
end

local function keys(_, state, input)
	if state ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Sink end
	local k = input.KeyCode
	if k == Enum.KeyCode.Escape or k == Enum.KeyCode.ButtonB or k == Enum.KeyCode.T or k == Enum.KeyCode.DPadUp then controller.Close() end
	return Enum.ContextActionResult.Sink
end

-- Edward's flow (2026-10-19): every open starts blank on Weapon and clears the trial kit from your hands ("when you open the
-- crate it removes your weapons and makes you do this again"); a pick fills its tab and moves to the next empty slot
-- (Weapon -> Gadget -> Melee); the last one applies all three and closes. A filled tab can be clicked to redo that step.
-- X / Esc / B before the end applies nothing and gives back what you held before opening.
-- Server: Events.Training.TrialKit (Handoff preparation): FireServer("Clear") / ("Apply", {Weapon=, Gadget=, Melee=}) /
-- ("Cancel"). Without it: no clear, and Apply falls back to TrialItem per slot (spaced past its 0.25 s rate limit).
local kitEvent
local cleared = false

local function nextEmpty()
	local i = table.find(SLOTS, slotNow) or 0
	for k = 1, #SLOTS do
		local s = SLOTS[(i + k - 1) % #SLOTS + 1]
		if not picks[s] then return s end
	end
	return nil
end

local function apply()
	local kit = table.clone(picks)
	if kitEvent then
		kitEvent:FireServer("Apply", kit)
	elseif trialEvent then
		task.spawn(function()
			for _, s in SLOTS do
				if kit[s] then trialEvent:FireServer(s, kit[s]); task.wait(0.3) end
			end
		end)
	elseif kit.Weapon and swapEvent then
		swapEvent:FireServer(kit.Weapon)                       -- the bins' old path (server checks you stand at a bin)
	end
end

function controller.Open()
	if not root or player:GetAttribute("InTraining") ~= true then return end
	if isOpen then return end
	table.clear(picks)
	slotNow = SLOTS[1]
	if dots then dots.Visible = not ready end
	if ready then refreshPicks(); showSlot(slotNow) end
	cleared = kitEvent ~= nil
	if kitEvent then kitEvent:FireServer("Clear") end         -- hands empty until the three picks are made
	isOpen = true
	root.Visible = true
	if okKit and Kit.open then Kit.open(root) end
	setBlur(true)
	local cam = shared.Get and shared.Get("CameraController")
	if cam and cam.SetMouseFree then cam.SetMouseFree(true) end
	ContextActionService:BindActionAtPriority("TrainingPickerKeys", keys, false, 3000,
		Enum.KeyCode.Escape, Enum.KeyCode.ButtonB, Enum.KeyCode.T, Enum.KeyCode.DPadUp)
end

function controller.Close(applied)
	if not isOpen then return end
	isOpen = false
	closedAt = os.clock()
	if not applied and cleared and kitEvent then kitEvent:FireServer("Cancel") end   -- closed early: give the old kit back
	cleared = false
	ContextActionService:UnbindAction("TrainingPickerKeys")
	setBlur(false)
	if okKit and Kit.close then Kit.close(root) else root.Visible = false end
	local cam = shared.Get and shared.Get("CameraController")
	if cam and cam.SetMouseFree then cam.SetMouseFree(false) end
end
function controller.IsOpen() return isOpen end

function controller.Pick(slot, id)
	if not isOpen then return end
	if id == "Random" then
		local list = itemsFor(slot)
		id = list[math.random(1, math.max(#list, 1))]
	end
	if not id then return end
	picks[slot] = id
	slotNow = slot
	refreshPicks()
	local nxt = nextEmpty()
	if nxt then
		showSlot(nxt)
	else
		apply()
		controller.Close(true)
	end
end

-------------------------------------------------------------------------------
function controller.Start()
	if not (okTX and TX.On("SwapBins")) then return end
	build()
	task.spawn(buildGrids)
	task.spawn(function()
		local ev = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Training", 30)
		if not ev then return end
		swapEvent = ev:WaitForChild("SwapWeapon", 30)
		trialEvent = ev:FindFirstChild("TrialItem")
		kitEvent = ev:FindFirstChild("TrialKit")
		ev.ChildAdded:Connect(function(c)
			if c.Name == "TrialItem" then trialEvent = c elseif c.Name == "TrialKit" then kitEvent = c end
		end)
	end)
	-- a bin opens the picker (on its slot's tab when the prompt / bin says one)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if not prompt:GetAttribute("TrainingBin") or player:GetAttribute("InTraining") ~= true then return end
		if isOpen then controller.Close() else controller.Open() end
	end)
	-- T / D-pad up (re)open it while in Training (Close's own binding handles the closing press)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or isOpen or os.clock() - closedAt < 0.25 or player:GetAttribute("InTraining") ~= true then return end
		if UserInputService:GetFocusedTextBox() then return end
		if input.KeyCode == Enum.KeyCode.T or input.KeyCode == Enum.KeyCode.DPadUp then controller.Open() end
	end)
	local function trial()
		local inT = player:GetAttribute("InTraining") == true
		local parts = {}
		for _, slot in SLOTS do
			local t = player:GetAttribute(TRIAL_ATTR[slot])
			local it = t and Config.Items[t]
			if t then table.insert(parts, (it and it.Name) or t) end
		end
		trialTag.Text = #parts > 0 and ("TRIAL · " .. table.concat(parts, " · ")) or ""
		trialTag.Visible = inT and #parts > 0
	end
	for _, a in TRIAL_ATTR do player:GetAttributeChangedSignal(a):Connect(trial) end
	local function onTraining()
		local inT = player:GetAttribute("InTraining") == true
		weaponsBtn.Visible = inT
		trial()
		if inT then
			task.delay(0.6, function()                         -- let the teleport / camera settle first
				if player:GetAttribute("InTraining") == true then controller.Open("Weapon") end
			end)
		else
			controller.Close()
		end
	end
	player:GetAttributeChangedSignal("InTraining"):Connect(onTraining)
	if player:GetAttribute("InTraining") == true then onTraining() end
end

return controller
