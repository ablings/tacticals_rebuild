-- UIKit/SettingsScreen (ModuleScript): the lobby SETTINGS screen. RIVALS-style layout ported from
-- rivals_practice (design-canvas px at 1920x1080, converted to Scale by Kit.toScale), in tacticals' theme.
-- Values come from the saved profile (data.Settings, see Shared/Config/SettingsConfig) and every
-- change is saved back, so settings follow the player into every place.
--   SettingsScreen.Init({ getSettings = fn, save = fn(settings), onOpen = fn, onClose = fn })
--   SettingsScreen.Open() / Close() / IsOpen()
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")

local UIKit = script.Parent
local Theme = require(UIKit:WaitForChild("SettingsTheme"))
local Kit = require(UIKit:WaitForChild("SettingsKit"))
local Data = require(UIKit:WaitForChild("SettingsData"))
for _, tab in ipairs(Data.tabs) do -- storage key per row (labels can repeat, e.g. "Color" under Bars and Dot)
	for _, sec in ipairs(tab.sections) do for _, row in ipairs(sec.rows) do row.key = row.key or row.name end end
end
local Assets = require(UIKit:WaitForChild("Assets"))
local HotkeysPage = require(UIKit:WaitForChild("HotkeysPage"))
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
local tabBar = new("Frame", {
	Name = "TabBar", Position = UDim2.fromOffset(304, 71), Size = UDim2.fromOffset(859, 76),
	BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = Theme.alpha.bar, Parent = root,
}, { Kit.corner(6) })

-- S2 close
local close = Kit.closeButton(UDim2.fromOffset(135, 68))
close.Position = UDim2.fromOffset(1175, 75) -- (lobby revamp Phase B: square X docked at the tab bar end)
close.Parent = root

-- S3 page rail (presets 1-3 + save)
local rail = new("Frame", {
	Name = "PageRail", Position = UDim2.fromOffset(216, 160), Size = UDim2.fromOffset(59, 232),
	BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.05, ZIndex = 10, Parent = root, -- above the list so the profile bubble sits over section titles
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
	BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.93, Parent = root,
}, { Kit.corner(10) })
local preview = new("Frame", {
	Name = "Preview", Position = UDim2.fromOffset(13, 13), Size = UDim2.fromOffset(495, 364), BackgroundColor3 = Theme.hex("#5A6E86"),
	ClipsDescendants = true, Visible = false, Parent = detail,
}, { Kit.corner(4), Kit.vgrad({ Theme.hex("#9CC7F2"), Theme.hex("#C9B38A") }) })
if Assets.misc and Assets.misc.crosshairPreview then
	new("ImageLabel", { Name = "Scene", BackgroundTransparency = 1, Image = Assets.misc.crosshairPreview, ScaleType = Enum.ScaleType.Crop, Size = UDim2.fromScale(1, 1), Parent = preview }, { Kit.corner(4) })
end
local detailTop = new("Frame", { Name = "Text", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = detail })
local dIcon = Kit.label({ Name = "Icon", Text = "", TextSize = 50, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(14, 8), Size = UDim2.fromOffset(64, 64), Parent = detailTop })
local dImage = new("ImageLabel", { Name = "IconImage", BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 10), Size = UDim2.fromOffset(60, 60), Parent = detailTop })
local dTitle = Kit.label({ Name = "Title", Text = "", FontFace = F.heavy, TextSize = 56, Position = UDim2.fromOffset(92, 8), Size = UDim2.fromOffset(420, 64), Parent = detailTop })
local dDesc = Kit.label({
	Name = "Desc", Text = "", FontFace = F.bold, TextSize = 31, TextColor3 = C.textDim, TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(26, 80), Size = UDim2.fromOffset(470, 300), Parent = detailTop,
})

local function showDetail(row)
	local img = (Assets.rowIcon and Assets.rowIcon[row.icon]) or (Assets.hotkeys and Assets.hotkeys[row.icon])
	dImage.Image = img or ""
	dIcon.Text = img and "" or (row.glyph or "")
	dTitle.Text = row.name
	dDesc.Text = row.desc or ""
	dTitle.TextTransparency = 0.6
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
				if v["Outline Enabled"] then Kit.stroke(Color3.new(0, 0, 0), 1, 0).Parent = seg end
			end
		end
	end
	if v["Dot Enabled"] ~= false then
		local w = math.max(1, (v["Dot Thickness"] or 2) * k)
		local dot = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(w, w), BackgroundColor3 = v["Dot Color"] or C.white,
			BackgroundTransparency = (v["Dot Transparency"] or 0) / 100, BorderSizePixel = 0, Parent = cross })
		if v["Dot Shape"] == "Round" then Kit.corner(w).Parent = dot end
		if v["Outline Enabled"] then Kit.stroke(Color3.new(0, 0, 0), 1, 0).Parent = dot end
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

local function buildRow(tab, row, order)
	local level2 = row.level == 2
	local level0 = row.level == 0
	local h = row.kind == "slider" and 132 or 88
	local frame = new("Frame", {
		Name = row.key, LayoutOrder = order, Size = UDim2.fromOffset(level0 and 772 or row.level == 3 and 657 or level2 and 695 or 734, h),
		BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = Theme.alpha.panel,
	}, { Kit.corner(8) })
	local img = (Assets.rowIcon and Assets.rowIcon[row.icon]) or (Assets.hotkeys and Assets.hotkeys[row.icon])
	local icon
	if img then
		icon = new("ImageLabel", { Name = "Icon", BackgroundTransparency = 1, Image = img, Position = UDim2.fromOffset(18, 18), Size = UDim2.fromOffset(52, 52), Parent = frame })
	else
		icon = Kit.label({ Name = "Icon", Text = row.glyph or "", TextSize = 40, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(16, 16), Size = UDim2.fromOffset(56, 56), Parent = frame })
	end
	local labelX = (level2 or row.level == 3) and 84 or level0 and 93 or 89
	local label = Kit.label({ Name = "Label", Text = row.name, FontFace = F.heavy, TextSize = 42, Position = UDim2.fromOffset(labelX, 0), Size = UDim2.new(1, -330, 0, 88), Parent = frame })

	-- red per-setting reset: appears at the row start whenever the value differs from its default
	local default = defaultOf(row)
	local resetBtn = Kit.button("red", UDim2.fromOffset(52, 52), nil, { Name = "ResetSetting", Visible = false, Position = UDim2.fromOffset(16, 18), ZIndex = 2 })
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
		icon.Position = on and Kit.S(frame, 80, 28) or Kit.S(frame, 18, 18)
		icon.Size = on and Kit.S(frame, 32, 32) or Kit.S(frame, 52, 52)
		label.Position = Kit.S(frame, on and labelX + 31 or labelX, 0)
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
		holder, api = Kit.stepperSlider(h, { min = row.min, max = row.max, step = row.step, arrowStep = row.arrow, value = v[row.key], fmt = row.fmt }, changed)
		holder.Parent = frame
	elseif row.kind == "action" then
		-- [SET] an action row (e.g. Touch > Layout Editor): the blue arrow button runs ctx.onAction(key)
		control = Kit.button("robux", UDim2.fromOffset(112, 60), "→")
		control.Activated:Connect(function() if ctx.onAction then ctx.onAction(row.key) end end)
	end
	if control then
		-- centre anchor so hover scaling grows the control in place (not from its corner)
		control.AnchorPoint = Vector2.new(0.5, 0.5)
		control.Position = UDim2.new(1, -19 - control.Size.X.Offset / 2, 0, 44)
		control.Parent = frame
	end
	resetBtn.Activated:Connect(function() if api then api.set(default) end end)
	rowApis[row.key] = api
	refreshReset(0)
	-- (2026-10-21, round 3: match RIVALS) rows react on hover like RIVALS' (t0135.7: the hovered row's plate lifts out of the
	-- list): the plate fills in and warms to a dark field green, the label goes full white and the row's icon tilts. Colour and
	-- transparency only on the row (a UIScale on a list row would shove its neighbours); the icon tilts by Rotation, which turns
	-- about its centre (its top-left anchor is owned by the reset-button shuffle above, so a UIScale would drift it).
	local HOVER_TINT, REST_TINT = Color3.fromRGB(30, 44, 22), Color3.new(0, 0, 0)
	local restText = label.TextColor3
	frame.MouseEnter:Connect(function()
		Kit.tween(frame, 0.08, { BackgroundTransparency = Theme.alpha.panel - 0.22, BackgroundColor3 = HOVER_TINT })
		Kit.tween(label, 0.08, { TextColor3 = Color3.new(1, 1, 1) })
		Kit.tween(icon, 0.14, { Rotation = -10 }, Enum.EasingStyle.Back)
		showDetail(row)
	end)
	frame.MouseLeave:Connect(function()
		Kit.tween(frame, 0.12, { BackgroundTransparency = Theme.alpha.panel, BackgroundColor3 = REST_TINT })
		Kit.tween(label, 0.12, { TextColor3 = restText })
		Kit.tween(icon, 0.12, { Rotation = 0 })
	end)
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
			local hb = Kit.headerBar(772, sec.title)
			hb.LayoutOrder = order
			if si > 1 then
				-- breathing room before each new section (reference gap)
				new("Frame", { Name = "Gap", BackgroundTransparency = 1, Size = UDim2.fromOffset(772, 32), LayoutOrder = order, Parent = list })
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
		Name = "Reset", LayoutOrder = order, Size = UDim2.fromOffset(772, 93), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = Theme.alpha.header, Parent = list,
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
	local img = model and function(holder, tabBtn) ViewIcons.Icon(holder, model, { hoverTarget = tabBtn }) end
		or (Assets.tabIcon and Assets.tabIcon[tab.icon])
	local t, api = Kit.imageTab(UDim2.fromOffset(136, 54), tab.name, img, tab.glyph)
	t.Position = UDim2.fromOffset(12 + (i - 1) * 140, 11)
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
		FontFace = Font.new("rbxassetid://12187365977", Enum.FontWeight.Bold), TextSize = 30, TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 63, Parent = field,
	})
	local importBtn = new("TextButton", {
		Name = "Import", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(160, 64),
		BackgroundColor3 = C.textDark, AutoButtonColor = false, Text = "Import", TextColor3 = C.white,
		FontFace = Font.new("rbxassetid://12187365977", Enum.FontWeight.Bold), TextSize = 32, ZIndex = 63, Parent = field,
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
