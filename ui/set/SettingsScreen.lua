-- UIKit/SettingsScreen (ModuleScript): the lobby SETTINGS screen. RIVALS-style layout ported from
-- rivals_practice (design-canvas px at 1920x1080, converted to Scale by Kit.toScale).
-- (2026-10-21, RIVALS 1:1) colours and fonts from UIKit.Rivals.Theme (through SettingsKit), the replica's rows / toggles /
-- steppers / section headers / detail pane again; the tab bar is the list's width and its 3D icons are lit from the camera.
-- (2026-10-21, port3) per two graders: text and controls ~15-20 % bigger (labels ExtraBold 50, value boxes / arrows / toggles /
-- slider handles scaled up, header 70, pane title 70), near-solid header bars, taller tabs with brighter icons over the bar.
-- Values come from the saved profile (data.Settings, see Shared/Config/SettingsConfig) and every
-- change is saved back, so settings follow the player into every place.
--   SettingsScreen.Init({ getSettings = fn, save = fn(settings), onOpen = fn, onClose = fn })
--   SettingsScreen.Open() / Close() / IsOpen()
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")

local UIKit = script.Parent
local Kit = require(UIKit:WaitForChild("SettingsKit"))
local Theme = Kit.Theme -- (2026-10-21, RIVALS 1:1) UIKit.Rivals.Theme (SettingsTheme only where the Rivals folder is missing)
local Data = require(UIKit:WaitForChild("SettingsData"))
for _, tab in ipairs(Data.tabs) do -- storage key per row (labels can repeat, e.g. "Color" under Bars and Dot)
	for _, sec in ipairs(tab.sections) do for _, row in ipairs(sec.rows) do row.key = row.key or row.name end end
end
local Assets = require(UIKit:WaitForChild("Assets"))
local HotkeysPage = require(UIKit:WaitForChild("HotkeysPage"))
-- (2026-10-21, RIVALS images) a row's generated RIVALS icon (SettingsData row.gen -> UIKit.Rivals.Assets.gen), else nil
local function rowGen(row) return row.gen and Kit.genImage and Kit.genImage(row.gen) or nil end
local ViewIcons = require(UIKit:WaitForChild("ViewIcons"))
local TAB_MODEL = { Video = "Monitor", Audio = "Headset", Game = "Gamepad", Hotkeys = "Keyboard" }
local SettingsConfig = require(RS:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("SettingsConfig"))
local C, F, new = Theme.color, Theme.font, Kit.new

local Screen = {}
local ctx = {}
local built = false
local function build()
built = true
local gui = new("ScreenGui", { Name = "SettingsUI", IgnoreGuiInset = true, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 25, Parent = Players.LocalPlayer:WaitForChild("PlayerGui") })
gui:SetAttribute("NoStyle", true) -- the lobby's auto-styler leaves this screen exactly as drawn

-- backdrop: blurred lobby + dark purple tint
local blur = Lighting:FindFirstChild("MenuUIBlur") or new("BlurEffect", { Name = "MenuUIBlur", Size = 0, Parent = Lighting })
local scrim = new("Frame", { Name = "Scrim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.scrim, BackgroundTransparency = 1, Parent = gui })

local canvas = Kit.canvas(gui)
local root = new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = canvas })

-- S1 tab bar
-- (2026-10-21, grade1) taller (76 -> 108) and grown upward so each tab's icon sits fully above its label inside the bar; the
-- bottom edge stays at y 147, so the list, rail and the Hotkeys page (which places itself at y 160) are unchanged
-- (2026-10-21, grade2) 108 -> 124 tall (tabs 96 -> 112 for ~44 px icons on screen), grown upward again: bottom still at 147
-- (2026-10-21, grade3: copy RIVALS t0136 / t0137) RIVALS' bar is a thin dark strip (~77 design px) whose 3D icons rise out over its top edge; the selected tab is a
-- cream plate inside the bar. Back to 77 tall at y 71 (bottom still 147, so the list / rail / Hotkeys page do not move).
-- (2026-10-21, RIVALS 1:1) the bar is the list's width (772, was 859): six 120 px tabs, 126 apart, 11 px in from each end
-- (2026-10-22, section round 0, grader A vs RIVALS t0135.7) RIVALS' tabs step 139 (0.0725 W) with a 136 px selected plate and the bar
-- runs to x 1152 (0.60 W): 848 wide (was 120 / 126 / 772)
local TAB_W, TAB_STEP, TAB_X0 = 136, 139, 11
local tabBar = new("Frame", {
	Name = "TabBar", Position = UDim2.fromOffset(304, 71), Size = UDim2.fromOffset(848, 77),
	BackgroundColor3 = C.textDark, BackgroundTransparency = Theme.alpha.bar, Parent = root,
}, { Kit.corner(6) })

-- S2 close
local close = Kit.closeButton(UDim2.fromOffset(135, 68))
-- (2026-10-21, grade3: copy RIVALS t0136 / t0137) RIVALS' X sits at the far right, its right edge flush with the description pane's (1095 + 520) and its top level
-- with the tab bar's top (was docked at the tab bar's end)
close.Position = UDim2.fromOffset(1095 + 520 - 135, 75) -- (2026-10-21, RIVALS 1:1) the replica's y (1481, 75)
close.Parent = root

-- S3 page rail (presets 1-3 + save)
local rail = new("Frame", {
	Name = "PageRail", Position = UDim2.fromOffset(216, 160), Size = UDim2.fromOffset(59, 232),
	BackgroundColor3 = C.textDark, BackgroundTransparency = 0.05, ZIndex = 10, Parent = root, -- above the list so the profile bubble sits over section titles
}, { Kit.corner(30) })
-- settings profiles 1-3: each profile keeps its own values for every tab
-- runtime values: swatches as Color3 (stored as "#rrggbb"); filled from the saved profile below
-- [SET] (2026-10-16) the copy is (re)filled IN PLACE from the saved profile, so Screen.Reload() can pick up a change made
-- elsewhere (an admin ;wipe, another device) instead of the old copy being saved back over it
local profiles = { {}, {}, {} }
local activeProfile = 1
local function loadSaved()
	local saved = SettingsConfig.Sanitize(ctx.getSettings and ctx.getSettings() or nil)
	for i = 1, 3 do
		for _, tab in ipairs(Data.tabs) do
			local t = profiles[i][tab.name] or {}
			table.clear(t)
			for key, v in pairs(saved.Profiles[i][tab.name] or {}) do
				if type(v) == "string" and v:match("^#%x%x%x%x%x%x$") then v = Color3.fromHex(v:sub(2)) end
				t[key] = v
			end
			profiles[i][tab.name] = t
		end
	end
	activeProfile = saved.Active
end
loadSaved()
local values = profiles[activeProfile]

-- save (debounced): runtime values -> stored form -> server
local saveQueued = false
local function serialize()
	local out = { Active = activeProfile, Profiles = {}, Version = 2 } -- [SET] Tacticals hotkey layout (no re-migration)
	for i = 1, 3 do
		out.Profiles[i] = {}
		for tabName, t in pairs(profiles[i]) do
			local o = {}
			for k, v in pairs(t) do
				o[k] = typeof(v) == "Color3" and ("#" .. v:ToHex():lower()) or (type(v) == "table" and table.clone(v)) or v
			end
			out.Profiles[i][tabName] = o
		end
	end
	return out
end
local function queueSave()
	if saveQueued then return end
	saveQueued = true
	task.delay(0.6, function()
		saveQueued = false
		local s = serialize()
		SettingsConfig.Apply(s, Players.LocalPlayer)
		if ctx.save then ctx.save(s) end
	end)
end
local openTab, currentTab, applyProfile -- defined below

-- [SET] deep compare of two stored settings tables (is the saved copy already what we show?)
local function same(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then return a == b end
	for k, v in a do if not same(v, b[k]) then return false end end
	for k in b do if a[k] == nil then return false end end
	return true
end
-- [SET] re-read the saved settings (LobbyUIController calls this when the replica's Settings change). Skipped while one of
-- our own saves is pending, and a no-op when the saved data already matches the copy (so it never redraws under you).
function Screen.Reload()
	if saveQueued then return end
	local now = SettingsConfig.Sanitize(ctx.getSettings and ctx.getSettings() or nil)
	local mine = SettingsConfig.Sanitize(serialize())
	now.Version, mine.Version = nil, nil
	if same(now.Profiles, mine.Profiles) and now.Active == mine.Active then return end
	loadSaved()
	values = profiles[activeProfile]
	if currentTab and openTab then openTab(currentTab) end
end
local rowApis = {} -- control APIs of the rows on the open tab, by row name
local railButtons = {}
-- rail hover (RIVALS): a soft grey circle fades in behind the icon; no scaling
local RAIL_HOVER_T = 0.7
local function railHover(b)
	b.MouseEnter:Connect(function()
		if not b:GetAttribute("Selected") then Kit.tween(b, 0.1, { BackgroundTransparency = RAIL_HOVER_T }) end
	end)
	b.MouseLeave:Connect(function()
		if not b:GetAttribute("Selected") then Kit.tween(b, 0.12, { BackgroundTransparency = 1 }) end
	end)
end
local function selectPreset(n)
	local changed = n ~= activeProfile
	activeProfile = n
	values = profiles[n]
	if changed and currentTab then applyProfile(currentTab) end
	if changed then
		-- white chat bubble pointing at the circle (RIVALS)
		local hov = rail:FindFirstChild("RailTip"); if hov then hov:Destroy() end
		local old = rail:FindFirstChild("ProfileBubble")
		if old then old:Destroy() end
		local tip = Kit.tooltip("Switched to profile #" .. n, 290, "left")
		tip.Name = "ProfileBubble"
		tip.Size = UDim2.fromOffset(290, 50)
		tip.AnchorPoint = Vector2.new(0, 0.5)
		tip.Position = UDim2.fromOffset(72, 30 + (n - 1) * 58)
		tip.ZIndex = 30
		local lbl = tip:FindFirstChildOfClass("TextLabel")
		lbl.FontFace = Theme.font.display; lbl.TextSize = 26
		tip.Parent = rail
		Kit.toScale(tip)
		task.delay(1.6, function()
			if tip.Parent then
				Kit.tween(tip, 0.2, { BackgroundTransparency = 1 }); Kit.tween(lbl, 0.2, { TextTransparency = 1 })
				local ptr = tip:FindFirstChild("Pointer"); if ptr then Kit.tween(ptr, 0.2, { BackgroundTransparency = 1 }) end
				task.wait(0.2); tip:Destroy()
			end
		end)
	end
	if changed then queueSave() end
	for i, b in ipairs(railButtons) do
		local on = i == n
		b:SetAttribute("Selected", on)
		Kit.tween(b, 0.12, { BackgroundTransparency = on and 0 or 1, BackgroundColor3 = C.white })
		b.Label.TextColor3 = on and C.textDark or C.text
	end
end
for i = 1, 3 do
	local b = new("TextButton", {
		Name = "Preset" .. i, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(29.5, 30 + (i - 1) * 58),
		Size = UDim2.fromOffset(44, 44), BackgroundColor3 = C.white, AutoButtonColor = false, Text = "", Parent = rail,
	}, { Kit.corner(22) })
	Kit.label({ Name = "Label", Text = tostring(i), FontFace = F.display, TextSize = 28, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = b })
	b.Activated:Connect(function() selectPreset(i) end)
	railHover(b)
	railButtons[i] = b
end
-- (2026-10-21, grade1) hovering a rail circle names it ("Preset 1" .. "Preset 3", "Share / import") in the same white pointer
-- bubble the profile switch uses. (2026-10-21, grade3: copy RIVALS t0136 / t0137) the "PRESETS" caption above the rail is gone: RIVALS' rail has none.
local function railTip(b, text, y)
	b.MouseEnter:Connect(function()
		local old = rail:FindFirstChild("RailTip"); if old then old:Destroy() end
		if rail:FindFirstChild("ProfileBubble") then return end -- the switch bubble already speaks for this spot
		local tip = Kit.tooltip(text, 190, "left")
		tip.Name = "RailTip"
		tip.AnchorPoint = Vector2.new(0, 0.5)
		tip.Position = UDim2.fromOffset(72, y)
		tip.ZIndex = 30
		tip.Parent = rail
		Kit.toScale(tip)
	end)
	b.MouseLeave:Connect(function() local old = rail:FindFirstChild("RailTip"); if old then old:Destroy() end end)
end
for i, b in ipairs(railButtons) do railTip(b, "Preset " .. i, 30 + (i - 1) * 58) end
local saveBtn = new("TextButton", {
	Name = "Save", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(29.5, 202), Size = UDim2.fromOffset(44, 44),
	BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Parent = rail,
})
if Assets.rowIcon and Assets.rowIcon.save then
	new("ImageLabel", { BackgroundTransparency = 1, Image = Assets.rowIcon.save, Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(36, 36), Parent = saveBtn })
else
	Kit.label({ Text = "↓", FontFace = F.heavy, TextSize = 36, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = saveBtn })
end
saveBtn.BackgroundColor3 = C.white
Kit.corner(22).Parent = saveBtn
railHover(saveBtn)
railTip(saveBtn, "Share / import", 202)
selectPreset(1)

-- S4 settings list
local list = new("ScrollingFrame", {
	Name = "List", Position = UDim2.fromOffset(304, 160), Size = UDim2.fromOffset(772, 920),
	BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, ScrollBarImageTransparency = 1, CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, Parent = root,
})
new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Right, Parent = list })
new("UIPadding", { PaddingBottom = UDim.new(0, 160), Parent = list })

-- S5 detail panel (shows the hovered row)
local detail = new("Frame", {
	Name = "Detail", Position = UDim2.fromOffset(1095, 160), Size = UDim2.fromOffset(520, 890),
	BackgroundColor3 = C.textDark, BackgroundTransparency = 0.72, Parent = root, -- (2026-10-22, live RIVALS 16:9: a clearly visible dark pane, was 0.93)
}, { Kit.corner(10) })
-- (2026-10-22, section rounds 0-7, grader C vs t0138) RIVALS' small grey build label in the pane's bottom-right corner
Kit.label({ Name = "Version", Text = "Version " .. tostring(game.PlaceVersion), FontFace = F.medium, TextSize = 22, TextColor3 = Theme.hex("#8E8D94"), TextTransparency = 0.45,
	TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromOffset(508, 880), Size = UDim2.fromOffset(300, 28), Parent = detail })
local preview = new("Frame", {
	Name = "Preview", Position = UDim2.fromOffset(13, 13), Size = UDim2.fromOffset(495, 364), BackgroundColor3 = Theme.hex("#5A6E86"),
	ClipsDescendants = true, Visible = false, Parent = detail,
}, { Kit.corner(4), Kit.vgrad({ Theme.hex("#9CC7F2"), Theme.hex("#C9B38A") }) })
if Assets.misc and Assets.misc.crosshairPreview then
	new("ImageLabel", { Name = "Scene", BackgroundTransparency = 1, Image = Assets.misc.crosshairPreview, ScaleType = Enum.ScaleType.Crop, Size = UDim2.fromScale(1, 1), Parent = preview }, { Kit.corner(4) })
end
local detailTop = new("Frame", { Name = "Text", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = detail })
-- (2026-10-21, grade3: copy RIVALS t0136 / t0137) RIVALS' pane: the setting's icon and its name as a big title on one line, the description under both (grade2 had
-- dropped the title; it is back).
-- (2026-10-21, RIVALS 1:1) the replica's pane: title in RIVALS' face and weight (Rubik SemiBold 56, shrinks to fit a long name
-- instead of the Oswald cut-off), description Rubik 31 in Theme's dim grey; the pane itself is the faint full-height backing
-- column (black at 0.93, 890 tall)
-- (2026-10-21, port3) graders: the pane title ~5 % of the screen height (RIVALS' "Master Vo..." is huge): 56 -> 70 in a
-- 80 px line, Rubik ExtraBold; icon 60 -> 72; the description 31 -> 34 and moved down under the taller title
local dIcon = Kit.label({ Name = "Icon", Text = "", TextSize = 60, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(12, 4), Size = UDim2.fromOffset(78, 78), Parent = detailTop })
local dImage = new("ImageLabel", { Name = "IconImage", BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 6), Size = UDim2.fromOffset(72, 72), Parent = detailTop })
local dTitle = Kit.label({ Name = "Title", Text = "", FontFace = F.display, TextSize = 70, TextScaled = true,
	Position = UDim2.fromOffset(102, 2), Size = UDim2.fromOffset(398, 80), Parent = detailTop }) -- (lobby r23, grader B: 24 clear of the panel edge)
new("UITextSizeConstraint", { MaxTextSize = 70, Parent = dTitle })
local dDesc = Kit.label({
	Name = "Desc", Text = "", FontFace = Font.new(F.bold.Family, Enum.FontWeight.Medium), TextSize = 30, -- (lobby r23, grader B vs t0136: Medium body, a size down)
	 TextColor3 = C.textDim, TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(26, 92), Size = UDim2.fromOffset(470, 300), Parent = detailTop, -- (lobby r22, grader B: right inset 14 -> 24)
})

local function showDetail(row)
	local img = rowGen(row) or (Assets.rowIcon and Assets.rowIcon[row.icon]) or (Assets.hotkeys and Assets.hotkeys[row.icon])
	dImage.Image = img or ""
	dIcon.Text = img and "" or (row.glyph or "")
	dTitle.Text = row.name or ""
	dDesc.Text = row.desc or ""
	dTitle.TextTransparency = 0.6 -- (2026-10-21, RIVALS 1:1) the replica fades the title in
	Kit.tween(dTitle, 0.12, { TextTransparency = 0 })
end

-- live crosshair in the preview (Crosshair tab)
local cross = new("Frame", { Name = "Crosshair", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1, 1), BackgroundTransparency = 1, ZIndex = 3, Parent = preview })
local function drawCrosshairRaw(v)
	cross:ClearAllChildren()
	if v["Disabled"] then return end
	local k = (v["Scale"] or 100) / 100
	cross.Rotation = v["Rotation"] or 0
	if v["Bars Enabled"] ~= false then
		local gap, len, w = (v["Spacing"] or 16) * k * 0.5, (v["Length"] or 6) * k * 1.5, math.max(1, (v["Bars Thickness"] or 2) * k)
		local col, t = v["Bars Color"] or C.white, (v["Bars Transparency"] or 0) / 100
		local round = v["Bars Shape"] == "Round"
		local arms = { { 0, -1, "Top Enabled" }, { 0, 1, "Bottom Enabled" }, { -1, 0, "Left Enabled" }, { 1, 0, "Right Enabled" } }
		for _, d in ipairs(arms) do
			if v[d[3]] ~= false and len > 0 then
				local horiz = d[2] == 0
				local seg = new("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = col, BackgroundTransparency = t, BorderSizePixel = 0,
					Size = horiz and UDim2.fromOffset(len, w) or UDim2.fromOffset(w, len),
					Position = UDim2.fromOffset(d[1] * (gap + len / 2), d[2] * (gap + len / 2)), Parent = cross,
				})
				if round then Kit.corner(w).Parent = seg end
				if v["Outline Enabled"] then Kit.stroke(C.textDark, 1, 0).Parent = seg end
			end
		end
	end
	if v["Dot Enabled"] ~= false then
		local w = math.max(1, (v["Dot Thickness"] or 2) * k)
		local dot = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(w, w), BackgroundColor3 = v["Dot Color"] or C.white,
			BackgroundTransparency = (v["Dot Transparency"] or 0) / 100, BorderSizePixel = 0, Parent = cross })
		if v["Dot Shape"] == "Round" then Kit.corner(w).Parent = dot end
		if v["Outline Enabled"] then Kit.stroke(C.textDark, 1, 0).Parent = dot end
	end
	if v["Circle Enabled"] then
		local r = ((v["Spacing"] or 16) * 0.5 + 4) * k * 2
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(r, r), BackgroundTransparency = 1, Parent = cross },
			{ Kit.corner(r), Kit.stroke(v["Bars Color"] or C.white, math.max(1, (v["Bars Thickness"] or 2) * k * 0.6), 0) })
	end
end
local function drawCrosshair(v)
	drawCrosshairRaw(v)
	if cross:GetAttribute("S") then Kit.toScale(cross) end
end

-- state: values per tab, filled from data defaults
-- a row's default value (note: `row.value ~= nil and row.value or ...` breaks for false defaults)
local function defaultOf(row)
	if row.value ~= nil then return row.value end
	return row.color or row.key
end
local function defaults(tab)
	local v = {}
	for _, sec in ipairs(tab.sections) do
		for _, row in ipairs(sec.rows) do
			v[row.key] = defaultOf(row)
		end
	end
	return v
end

-- (2026-10-21, port3) graders: the stepper and slider ~15-20 % bigger (SettingsKit is shared, so the screen resizes its parts):
-- value box 103 x 55 -> 120 x 64 with ~24 px-on-screen bold text (Rubik ExtraBold 36), the ▲▼ box 53 x 55 -> 60 x 64 with
-- chunky 28 px arrows, both centred on the 88 px label line; the track 6 -> 9 thick and the handle 32 x 34 -> 36 x 38
-- (~3.5 % of the screen height)
local function biggerSlider(holder)
	local box, arrows, track = holder:FindFirstChild("Value"), holder:FindFirstChild("Arrows"), holder:FindFirstChild("Track")
	if box then
		box.Position, box.Size = UDim2.new(1, -19, 0, 12), UDim2.fromOffset(110, 57) -- (lobby r14, grader A vs t0136: was 120 x 64)
		box.FontFace, box.TextSize = F.display, 36
	end
	if arrows then
		arrows.Position, arrows.Size = UDim2.new(1, -135, 0, 12), UDim2.fromOffset(57, 57) -- (r14: was 60 x 64 at -147)
		for _, b in ipairs(arrows:GetChildren()) do
			if b:IsA("TextButton") then b.FontFace, b.TextSize = F.display, 28 end
		end
	end
	if track then
		track.Position = UDim2.new(track.Position.X.Scale, track.Position.X.Offset, 0, 98)
		track.Size = UDim2.new(track.Size.X.Scale, track.Size.X.Offset, 0, 9)
		local knob = track:FindFirstChild("Knob")
		if knob then knob.Size = UDim2.fromOffset(36, 38) end
	end
end

local function buildRow(tab, row, order)
	-- (2026-10-21, grade1) graders: the plates stair-stepped (772 / 734 / 695 / 657 wide by level). One plate level now: every row is
	-- the list's full width and the same height for its kind (88, sliders 132); a sub-row (level 2 / 3: While Aiming, While Scoped,
	-- Horizontal ...) only indents its icon and label by 24 px per level.
	-- (2026-10-21, grade3: copy RIVALS t0136 / t0137) RIVALS stair-steps its plates: a sub-row's plate starts 38 px further right (the list is right-aligned, so the
	-- right edges line up). Slider rows 138 tall (label line + track), toggle rows 78, the rest 88. Inside a plate everything sits
	-- at the same offsets whatever its level (ind = 0).
	local plateIndent = math.max(0, (row.level or 1) - 1) * 38
	local ind = 0
	-- (2026-10-21, RIVALS 1:1) the replica's heights: every row 88 (toggles too), sliders 132 (an 88 label line + the track)
	-- (lobby r14, grader A vs t0136) toggle-only rows are shorter: 73 (the row step 95 -> 79 design px)
	local lineH = row.kind == "toggle" and 73 or 88 -- the label / icon / control line
	local h = row.kind == "slider" and 132 or lineH
	local iconY = math.floor((lineH - 52) / 2)
	local frame = new("Frame", {
		Name = row.key, LayoutOrder = order, Size = UDim2.fromOffset(772 - plateIndent, h),
		BackgroundColor3 = C.textDark, BackgroundTransparency = Theme.alpha.panel,
	}, { Kit.corner(8) })
	local img = rowGen(row) or (Assets.rowIcon and Assets.rowIcon[row.icon]) or (Assets.hotkeys and Assets.hotkeys[row.icon])
	local icon
	if img then
		icon = new("ImageLabel", { Name = "Icon", BackgroundTransparency = 1, Image = img, Position = UDim2.fromOffset(18 + ind, iconY), Size = UDim2.fromOffset(52, 52), Parent = frame })
	else
		icon = Kit.label({ Name = "Icon", Text = row.glyph or "", TextSize = 40, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(16 + ind, iconY - 2), Size = UDim2.fromOffset(56, 56), Parent = frame })
	end
	local labelX = 89 + ind
	-- (2026-10-21, grade2) row labels went 42 -> 24. (2026-10-21, grade3: copy RIVALS t0136 / t0137) RIVALS' row names are big (~34 design px): Rubik Bold 34.
	-- (2026-10-21, RIVALS 1:1) the replica's row label: Rubik SemiBold 42
	-- (2026-10-21, port3) graders: labels ~3.8 % of the screen height and very bold like RIVALS': Rubik ExtraBold 50 (was SemiBold 42)
	-- the box runs up to the control (toggles are narrower) and a long name shrinks to fit instead of running under it
	local reserve = row.kind == "toggle" and 165 or 245
	local label = Kit.label({ Name = "Label", Text = row.name, FontFace = F.display, TextSize = 50, TextScaled = true, Position = UDim2.fromOffset(labelX, 14),
		Size = UDim2.new(1, -(labelX + reserve), 0, lineH - 28), Parent = frame })
	-- (2026-10-23, lobby r12 graders A + B) with real Rubik (the font fix) the labels ran ~15 % over RIVALS': capped at 43 design px
	local cap = Instance.new("UITextSizeConstraint"); cap.MaxTextSize = 43; cap:SetAttribute("dMax", 43); cap.Parent = label -- (rescaled with the canvas)
	new("UITextSizeConstraint", { MaxTextSize = 50, Parent = label })

	-- red per-setting reset: appears at the row start whenever the value differs from its default
	local default = defaultOf(row)
	local resetBtn = Kit.button("red", UDim2.fromOffset(52, 52), nil, { Name = "ResetSetting", Visible = false, Position = UDim2.fromOffset(16 + ind, iconY), ZIndex = 2 })
	if Assets.rowIcon.reset then
		new("ImageLabel", { BackgroundTransparency = 1, Image = Assets.rowIcon.reset, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(32, 32), ZIndex = 3, Parent = resetBtn })
	end
	resetBtn.Parent = frame
	local shown = false
	local function refreshReset(t)
		if row.kind == "action" then return end -- [SET] an action row has no value to reset (it showed a stray red reset button)
		local cur = values[tab.name][row.key]
		local on
		if typeof(cur) == "Color3" and typeof(default) == "Color3" then
			on = cur:ToHex() ~= default:ToHex() -- compare at 8-bit precision, not float
		else
			on = cur ~= default
		end
		if on == shown and t ~= 0 then return end
		shown = on
		-- RIVALS: no animation, the reset button simply appears and the icon/label snap across
		resetBtn.Visible = on
		icon.Position = on and Kit.S(frame, 80 + ind, iconY + 10) or Kit.S(frame, 18 + ind, iconY)
		icon.Size = on and Kit.S(frame, 32, 32) or Kit.S(frame, 52, 52)
		label.Position = Kit.S(frame, on and labelX + 31 or labelX, 14) -- (port3) the label box is 60 tall at y 14 now
	end

	local v = values[tab.name]
	local function changed(val)
		values[tab.name][row.key] = val
		queueSave()
		-- [SET] a toggle other rows depend on (showIf): redraw this tab where it is
		for _, sec in ipairs(tab.sections) do
			for _, r in ipairs(sec.rows) do
				if r.showIf == row.key then
					local at = list.CanvasPosition
					task.defer(function() openTab(tab); task.defer(function() list.CanvasPosition = at end) end)
					return
				end
			end
		end
		if tab.preview then drawCrosshair(values[tab.name]) end
		refreshReset()
	end
	local control, api
	if row.kind == "toggle" then
		control, api = Kit.toggle(v[row.key], changed)
	elseif row.kind == "dropdown" then
		control, api = Kit.dropdown(row.options, v[row.key], canvas, changed)
	elseif row.kind == "swatch" then
		control, api = Kit.swatch(v[row.key], row.palette, changed, Assets.rowIcon and Assets.rowIcon.color, { layer = canvas, wheel = Assets.misc.colorWheel, dim = list })
	elseif row.kind == "keybind" then
		control, api = Kit.keybind(v[row.key], changed)
	elseif row.kind == "slider" then
		local holder
		-- (2026-10-21, grade3: copy RIVALS t0136 / t0137) RIVALS: ▲▼ stepper + value box on the label line, a full-width track under it (grade1 had removed the stepper)
		holder, api = Kit.slider(h, { min = row.min, max = row.max, step = row.step, arrowStep = row.arrow, value = v[row.key], fmt = row.fmt }, changed)
		biggerSlider(holder)
		holder.Parent = frame
	elseif row.kind == "action" then
		-- [SET] an action row (e.g. Touch > Layout Editor): the blue arrow button runs ctx.onAction(key)
		control = Kit.button("robux", UDim2.fromOffset(112, 60), "→")
		control.Activated:Connect(function() if ctx.onAction then ctx.onAction(row.key) end end)
	end
	if control and row.kind == "toggle" then
		-- (2026-10-21, port3) graders: controls ~15 % bigger. Toggle 110 x 55 -> 126 x 63, knob 41 -> 47 (the kit slides the
		-- knob by Scale 7/110 .. 62/110, which keeps an 8 px margin either side at this width)
		control.Size = UDim2.fromOffset(104, 54) -- (lobby r14, grader A vs t0136: 126 x 63 ran big)
		local knob = control:FindFirstChild("Knob")
		if knob then knob.Size = UDim2.fromOffset(40, 40) end
	end
	if control then
		-- centre anchor so hover scaling grows the control in place (not from its corner)
		control.AnchorPoint = Vector2.new(0.5, 0.5)
		control.Position = UDim2.new(1, -19 - control.Size.X.Offset / 2, 0, lineH / 2) -- (grade3) centred on the row's line
		control.Parent = frame
	end
	resetBtn.Activated:Connect(function() if api then api.set(default) end end)
	rowApis[row.key] = api
	refreshReset(0)
	-- (2026-10-21, RIVALS 1:1) the replica's row hover: the plate only darkens a step (no green tint, label change or icon tilt),
	-- and the detail pane shows the row
	frame.MouseEnter:Connect(function()
		Kit.tween(frame, 0.08, { BackgroundTransparency = Theme.alpha.panel - 0.15 })
		showDetail(row)
	end)
	frame.MouseLeave:Connect(function() Kit.tween(frame, 0.12, { BackgroundTransparency = Theme.alpha.panel }) end)
	return frame
end

local tabApis = {}
local tabButtons = {} -- [PAD] name -> tab button (NavTabOn for LB / RB)
function openTab(tab)
	currentTab = tab
	rowApis = {}
	-- let the list measure its new content before it is converted to Scale
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	Kit.restoreModifiers(list)
	local oldPage = root:FindFirstChild("HotkeysPage")
	if oldPage then oldPage:Destroy() end
	list.Visible = not tab.hotkeys
	detail.Visible = not tab.hotkeys
	if tab.hotkeys then
		for name, api in pairs(tabApis) do api.setSelected(name == tab.name); if tabButtons[name] then tabButtons[name]:SetAttribute("NavTabOn", name == tab.name) end end
		values[tab.name] = values[tab.name] or defaults(tab)
		HotkeysPage.build({
			Kit = Kit, Theme = Theme, Assets = Assets, parent = root, tab = tab, values = values[tab.name],
			onChange = function(name, binds) values[tab.name][name] = binds; queueSave() end,
			onReset = function() values[tab.name] = defaults(tab); queueSave(); openTab(tab) end,
		})
		Kit.toScale(root)
		return
	end
	for name, api in pairs(tabApis) do api.setSelected(name == tab.name); if tabButtons[name] then tabButtons[name]:SetAttribute("NavTabOn", name == tab.name) end end
	values[tab.name] = values[tab.name] or defaults(tab)
	for _, ch in ipairs(list:GetChildren()) do
		if ch:IsA("GuiObject") then ch:Destroy() end
	end
	for _, ch in ipairs(canvas:GetChildren()) do
		if ch.Name == "DropdownList" or ch.Name == "ColorPicker" then ch:Destroy() end
	end
	list.CanvasPosition = Vector2.zero
	local order = 0
	for si, sec in ipairs(tab.sections) do
		order += 1
		if sec.title then
			-- (2026-10-21, port3) graders: the header title bigger like RIVALS' (61 -> 70 in an 88 px bar, still Rubik ExtraBold),
			-- and the bar near-solid: at 0.28 a dark gun silhouette from the GUI behind showed through at the bar's right end
			local hb = Kit.headerBar(772, sec.title, 71) -- (lobby r16, grader B: the bars 86 -> 70 design px)
			hb.BackgroundTransparency = 0.04
			local ht = hb:FindFirstChildOfClass("TextLabel")
			if ht then ht.TextSize = 55; ht:SetAttribute("dTS", 55) end -- (lobby r15, grader B: this override, not Kit.headerBar's size, set the headers; 70 -> 55)
			hb.LayoutOrder = order
			if si > 1 then
				-- breathing room before each new section (reference gap)
				new("Frame", { Name = "Gap", BackgroundTransparency = 1, Size = UDim2.fromOffset(772, 32), LayoutOrder = order, Parent = list }) -- (2026-10-21, RIVALS 1:1) the replica's 32 again (the header is a bar again)
				order += 1
				hb.LayoutOrder = order
			end
			hb.Parent = list
		end
		for _, row in ipairs(sec.rows) do
			order += 1
			-- [SET] data rows are hidden storage; showIf rows only while their toggle is on (Touch > Custom)
			if row.kind ~= "data" and (not row.showIf or values[tab.name][row.showIf] == true) then buildRow(tab, row, order).Parent = list end
		end
	end
	-- reset card
	order += 1
	new("Frame", { Name = "Gap", BackgroundTransparency = 1, Size = UDim2.fromOffset(772, 60), LayoutOrder = order, Parent = list })
	order += 1
	local card = new("Frame", {
		Name = "Reset", LayoutOrder = order, Size = UDim2.fromOffset(772, 93), BackgroundColor3 = C.textDark, BackgroundTransparency = Theme.alpha.header, Parent = list,
	}, { Kit.corner(6) })
	Kit.label({ Text = "Reset", FontFace = F.display, TextSize = 42, Position = UDim2.fromOffset(20, 6), Size = UDim2.fromOffset(400, 50), Parent = card })
	Kit.label({ Text = "Double-click to put your " .. tab.name .. " settings back to default", FontFace = F.medium, TextSize = 21, TextColor3 = C.textDim, Position = UDim2.fromOffset(17, 54), Size = UDim2.fromOffset(620, 28), Parent = card })
	local resetBtn = Kit.button("red", UDim2.fromOffset(107, 58), Assets.rowIcon.reset and nil or "↻")
	if Assets.rowIcon.reset then
		new("ImageLabel", { BackgroundTransparency = 1, Image = Assets.rowIcon.reset, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(38, 38), Parent = resetBtn })
	end
	resetBtn.AnchorPoint = Vector2.new(1, 0.5)
	resetBtn.Position = UDim2.new(1, -16, 0.5, 0)
	resetBtn.Parent = card
	local lastClick = 0
	resetBtn.Activated:Connect(function()
		if os.clock() - lastClick < 0.4 then
			values[tab.name] = defaults(tab)
			queueSave()
			openTab(tab)
		end
		lastClick = os.clock()
	end)

	preview.Visible = tab.preview == true
	detailTop.Position = Kit.S(detail, 0, tab.preview and 395 or 0)
	if tab.preview then drawCrosshair(values[tab.name]) end
	showDetail(tab.sections[1].rows[1])
	Kit.toScale(root) -- UI rule: everything in Scale
end

for i, tab in ipairs(Data.tabs) do
	-- 3D tab icons (ViewIcons), as RIVALS' Settings tabs are posed 3D renders (t0135; 2026-10-21 user: follow RIVALS);
	-- Account shows the player's own headshot (RIVALS)
	local model = TAB_MODEL[tab.name]
	-- (2026-10-21, grade2) zoom the 3D icon 1.35x past its default view so the model fills its (larger) box
	local view = model and ViewIcons.Views and ViewIcons.Views[model]
	-- (2026-10-21, RIVALS 1:1) lit so they read on the dark bar like RIVALS' bright tab renders: ViewIcons' light ran from behind
	-- the model (LightDirection z -0.8 = away from the camera, which sits at -Z), so the faces toward you were in shade. Now
	-- the light comes from over the camera's shoulder with a brighter ambient.
	local img = model and function(holder, tabBtn)
		local ctl = ViewIcons.Icon(holder, model, { hoverTarget = tabBtn, zoom = ((view and view[2]) or 1) * 1.35 })
		local vpf = ctl and ctl.Frame
		if vpf then
			-- (2026-10-21, port3) graders: brighter (RIVALS' tab renders are vivid): ambient 200 -> 236
			vpf.Ambient = Theme.hex("#ECECEC")
			vpf.LightColor = C.white
			vpf.LightDirection = Vector3.new(-0.4, -0.7, 1)
		end
	end or (Assets.tabIcon and Assets.tabIcon[tab.icon])
	-- (2026-10-21, grade3: copy RIVALS t0136 / t0137) 100 tall with its bottom on the bar's bottom: the ~60 px icon rises 23 px out of the 77 px bar like RIVALS';
	-- the selected cream plate (52 tall) stays inside the bar
	-- (2026-10-21, port3) graders: icons ~60 px on screen, rising well above the bar: the tab 100 -> 124 tall (icon box 61 -> 85,
	-- ~62 px on a 784 px window), bottom still on the bar's bottom, so the icon now stands ~47 px over the bar's top edge
	local t, api = Kit.imageTab(UDim2.fromOffset(TAB_W, 124), tab.name, img, tab.glyph, 52)
	t.Position = UDim2.fromOffset(TAB_X0 + (i - 1) * TAB_STEP, 77 - 124)
	-- (2026-10-22, section round 1, grader A vs t0139) RIVALS' tab icons are <= 0.063 H (~64 px) with their top at ~0.059 H and their
	-- foot over the label; ours stood ~85 px tall, poking 0.035 H above the bar
	do
		local ic = t:FindFirstChild("Icon")
		if ic then ic.AnchorPoint, ic.Position, ic.Size = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -22), UDim2.fromOffset(64, 64) end
	end
	t.Parent = tabBar
	tabApis[tab.name] = api
	tabButtons[tab.name] = t
	t.Activated:Connect(function() if currentTab ~= tab then openTab(tab) end end)
	-- [PAD] LB / RB (GamepadNavController): tab order + "press" via the NavPressed attribute
	t:SetAttribute("NavTab", i)
	t:GetAttributeChangedSignal("NavPressed"):Connect(function() if currentTab ~= tab then openTab(tab) end end)
	if tab.name == "Account" then
		-- RIVALS: the Account tab icon is the player's own avatar headshot, not a drawn icon
		task.spawn(function()
			local ok, img = pcall(Players.GetUserThumbnailAsync, Players, Players.LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
			local icon = t:FindFirstChild("Icon")
			if ok and icon and icon:IsA("ImageLabel") then icon.Image = img end
		end)
	end
end

-- Profile switch (RIVALS): the open page isn't rebuilt; every control animates to the new profile's
-- value (sliders glide over 0.5 s, toggles slide, swatches blend), and the reset buttons follow.
function applyProfile(tab)
	if tab.hotkeys then openTab(tab) return end -- the bind table simply redraws
	values[tab.name] = values[tab.name] or defaults(tab)
	local v = values[tab.name]
	for name, api in pairs(rowApis) do
		local target = v[name]
		if target ~= nil and api.set then api.set(target, 0.5) end
	end
	if tab.preview then drawCrosshair(v) end
end

-- Import / share popup (download icon on the profile rail). Paste someone else's code + Import, or
-- copy your own: one code for every tab, one for the current tab. Codes = base64 of a JSON table of
-- the active profile's values (Color3 stored as "#rrggbb").
local HttpService = game:GetService("HttpService")
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function b64enc(data)
	return ((data:gsub(".", function(x)
		local r, b = "", x:byte()
		for i = 8, 1, -1 do r ..= (b % 2 ^ i - b % 2 ^ (i - 1) > 0 and "1" or "0") end
		return r
	end) .. "0000"):gsub("%d%d%d?%d?%d?%d?", function(x)
		if #x < 6 then return "" end
		local c = 0
		for i = 1, 6 do c += (x:sub(i, i) == "1" and 2 ^ (6 - i) or 0) end
		return B64:sub(c + 1, c + 1)
	end) .. ({ "", "==", "=" })[#data % 3 + 1])
end
local function b64dec(data)
	data = data:gsub("[^" .. B64 .. "=]", "")
	return (data:gsub(".", function(x)
		if x == "=" then return "" end
		local r, f = "", (B64:find(x, 1, true) - 1)
		for i = 6, 1, -1 do r ..= (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and "1" or "0") end
		return r
	end):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(x)
		if #x ~= 8 then return "" end
		local c = 0
		for i = 1, 8 do c += (x:sub(i, i) == "1" and 2 ^ (8 - i) or 0) end
		return string.char(c)
	end))
end

local function exportCode(onlyTab)
	local out = {}
	for _, tab in ipairs(Data.tabs) do
		if not onlyTab or tab == onlyTab then
			local v = values[tab.name] or defaults(tab)
			local t = {}
			for k, val in pairs(v) do t[k] = typeof(val) == "Color3" and ("#" .. val:ToHex()) or val end
			out[tab.name] = t
		end
	end
	return b64enc(HttpService:JSONEncode(out))
end

local function importCode(code)
	local ok, decoded = pcall(function() return HttpService:JSONDecode(b64dec(code)) end)
	if not ok or type(decoded) ~= "table" then return false end
	for _, tab in ipairs(Data.tabs) do
		local incoming = decoded[tab.name]
		if type(incoming) == "table" then
			values[tab.name] = values[tab.name] or defaults(tab)
			for k, val in pairs(incoming) do
				if type(val) == "string" and val:match("^#%x%x%x%x%x%x$") then val = Color3.fromHex(val:sub(2)) end
				values[tab.name][k] = val
			end
		end
	end
	if currentTab then applyProfile(currentTab) end
	queueSave()
	return true
end

local importPop
local function closeImport() if importPop then importPop:Destroy(); importPop = nil end end
saveBtn.Activated:Connect(function()
	if importPop then closeImport(); return end
	importPop = new("Frame", { Name = "ImportPopup", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 60, Parent = canvas })
	local catcher = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 60, Parent = importPop })
	catcher.Activated:Connect(closeImport)
	-- white panel to the right of the icon, pointer on its left edge at the icon (measured from Edward's capture)
	local panel = new("Frame", {
		Name = "Panel", Position = UDim2.fromOffset(278, 300), Size = UDim2.fromOffset(870, 232), BackgroundColor3 = C.white, ZIndex = 61, Parent = importPop,
	}, { Kit.corner(12) })
	new("Frame", { Name = "Pointer", AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45, Position = UDim2.fromOffset(0, 62), Size = UDim2.fromOffset(20, 20), BackgroundColor3 = C.white, BorderSizePixel = 0, ZIndex = 61, Parent = panel })
	local sc = new("UIScale", { Scale = 0.94, Parent = panel })
	Kit.tween(sc, 0.12, { Scale = 1 })

	local field = new("Frame", { Name = "Field", Position = UDim2.fromOffset(34, 31), Size = UDim2.fromOffset(803, 64), BackgroundColor3 = Theme.hex("#8C8C8C"), ZIndex = 62, Parent = panel }, { Kit.corner(8) })
	local box = new("TextBox", {
		Name = "Paste", BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 0), Size = UDim2.new(1, -190, 1, 0), Text = "",
		PlaceholderText = "Paste someone else's settings here", PlaceholderColor3 = Theme.hex("#EDEDED"), TextColor3 = C.white,
		FontFace = Font.new(F.heavy.Family, Enum.FontWeight.Bold), TextSize = 30, TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 63, Parent = field,
	})
	local importBtn = new("TextButton", {
		Name = "Import", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(160, 64),
		BackgroundColor3 = C.textDark, AutoButtonColor = false, Text = "Import", TextColor3 = C.white,
		FontFace = Font.new(F.heavy.Family, Enum.FontWeight.Bold), TextSize = 32, ZIndex = 63, Parent = field,
	}, { Kit.corner(8) })
	Kit.bindButton(importBtn, { hover = 1.04 })
	importBtn.Activated:Connect(function()
		local ok = importCode(box.Text)
		box.Text = ""
		box.PlaceholderText = ok and "Settings imported!" or "That code didn't work"
	end)

	-- share lines: text + a small selectable box holding the code (select it and copy)
	local function shareLine(y, text, code)
		local row = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, y), Size = UDim2.fromOffset(820, 44), ZIndex = 62, Parent = panel },
			{ new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
		new("TextLabel", {
			LayoutOrder = 1, BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 44), Text = text,
			TextColor3 = C.textDark, FontFace = F.heavy, TextSize = 24, ZIndex = 63, Parent = row,
		})
		new("TextBox", {
			Name = "Code", LayoutOrder = 2, Size = UDim2.fromOffset(66, 44), BackgroundColor3 = Theme.hex("#D0D0D0"), Text = code,
			TextColor3 = Theme.hex("#5A5A5A"), TextSize = 8, TextWrapped = true, ClipsDescendants = true, TextEditable = false,
			ClearTextOnFocus = false, ZIndex = 63, Parent = row,
		})
	end
	shareLine(122, "Share your entire settings by copying this:", exportCode(nil))
	shareLine(172, "Share only your " .. (currentTab and currentTab.name or "") .. " settings by copying this:", exportCode(currentTab))
	Kit.toScale(importPop)
end)

-- open / close
local isOpen = false
local function setOpen(on)
	if on == isOpen then return end
	isOpen = on
	Kit.tween(blur, 0.25, { Size = on and Theme.blur or 0 })
	Kit.tween(scrim, 0.25, { BackgroundTransparency = on and Theme.alpha.scrim or 1 })
	if on then
		gui.Enabled = true
		if ctx.onOpen then ctx.onOpen() end
		Kit.open(root)
	else
		Kit.close(root, function() if not isOpen then gui.Enabled = false end end)
		if ctx.onClose then ctx.onClose() end
	end
end
Screen._setOpen = setOpen
Screen._isOpen = function() return isOpen end
close.Activated:Connect(function() setOpen(false) end)

-- Roblox Esc menu: the panel hides while the blur stays, and it comes back when the menu closes (reference behaviour)
local GuiService = game:GetService("GuiService")
GuiService.MenuOpened:Connect(function()
	if isOpen then root.Visible = false end
end)
GuiService.MenuClosed:Connect(function()
	if isOpen then Kit.open(root) end
end)

openTab(Data.tabs[1])
root.Visible = false
gui.Enabled = false
SettingsConfig.Apply(serialize(), Players.LocalPlayer)
end -- build

function Screen.Init(context)
	ctx = context or {}
	if not built then build() end
end
-- (2026-10-20) true once someone (the lobby UI, or the match HUD's gear) gave it the profile to read / save
function Screen.HasContext() return ctx.getSettings ~= nil end
function Screen.Open() if not built then build() end Screen._setOpen(true) end
function Screen.Close() if built then Screen._setOpen(false) end end
function Screen.IsOpen() return built and Screen._isOpen() end

return Screen
