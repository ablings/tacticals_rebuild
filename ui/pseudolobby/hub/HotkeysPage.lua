-- HotkeysPage: the Hotkeys tab's table layout (wiki: RIVALS UI - Screens, settings; ref_55-58).
-- Fixed "Action" header with 4 bind columns (PC, PC 2, controller, controller 2); grouped rows with
-- 4 slots each. A slot shows a keycap, a mouse glyph or a controller glyph. Hover a slot -> red
-- "clear" + blue "edit" halves; edit -> "..." waiting box until the next key/mouse/gamepad press
-- (Escape cancels). Bound glyphs play a press animation whenever their input is pressed.
local UserInputService = game:GetService("UserInputService")

local HotkeysPage = {}

local KEY_LABEL = {
	LeftShift = "LShift", RightShift = "RShift", LeftControl = "LCtrl", RightControl = "RCtrl", LeftAlt = "LAlt", RightAlt = "RAlt",
	One = "1", Two = "2", Three = "3", Four = "4", Five = "5", Six = "6", Seven = "7", Eight = "8", Nine = "9", Zero = "0",
	Up = "▲", Down = "▼", Left = "◀", Right = "▶", Return = "Enter", Backspace = "Bksp", CapsLock = "Caps",
}
local FACE = { ButtonA = "A", ButtonB = "B", ButtonX = "X", ButtonY = "Y" }
local SHOULDER = { ButtonR1 = "R1", ButtonL1 = "L1", ButtonR2 = "R2", ButtonL2 = "L2" }
local STICK = { ButtonR3 = "R3", ButtonL3 = "L3" }
local DPAD = { DPadUp = "up", DPadDown = "down", DPadLeft = "left", DPadRight = "right" }
local MOUSE = { MouseButton1 = "l", MouseButton2 = "r", MouseButton3 = "m" }

-- name of an input as stored in a bind
local function inputName(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then return "MouseButton1" end
	if input.UserInputType == Enum.UserInputType.MouseButton2 then return "MouseButton2" end
	if input.UserInputType == Enum.UserInputType.MouseButton3 then return "MouseButton3" end
	if input.KeyCode ~= Enum.KeyCode.Unknown then return input.KeyCode.Name end
	return nil
end
HotkeysPage.inputName = inputName

function HotkeysPage.build(ctx)
	local Kit, Theme, Assets, new = ctx.Kit, ctx.Theme, ctx.Assets, ctx.Kit.new
	local C, F = Theme.color, Theme.font
	local A = Assets.hotkeys or {}
	local page = new("Frame", { Name = "HotkeysPage", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = ctx.parent })
	local glyphs = {} -- input name -> list of {press(), release()}
	local conns = {}

	-- fixed header
	local header = new("Frame", {
		Name = "Header", Position = UDim2.fromOffset(304, 160), Size = UDim2.fromOffset(1312, 69),
		BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = Theme.alpha.header, ZIndex = 3, Parent = page,
	}, { Kit.corner(8) })
	Kit.label({ Text = "Action", FontFace = F.display, TextSize = 40, Position = UDim2.fromOffset(114, 0), Size = UDim2.fromOffset(300, 69), ZIndex = 4, Parent = header })
	local COLX = { 722, 846, 971, 1096 } -- column centres relative to x 304 (1026 / 1150 / 1275 / 1400 on screen)
	for i, x in ipairs(COLX) do
		local img = (i <= 2) and A.monitor or A.gamepad
		local ic = new("ImageLabel", { BackgroundTransparency = 1, Image = img or "", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, 34), Size = UDim2.fromOffset(52, 52), ZIndex = 4, Parent = header })
		if i % 2 == 0 then
			Kit.label({ Text = "2", FontFace = F.display, TextSize = 30, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(1, -6, 1, 10), Size = UDim2.fromOffset(20, 30), ZIndex = 5, Parent = ic })
		end
	end

	-- scrolling table
	local scroll = new("ScrollingFrame", {
		Name = "Table", Position = UDim2.fromOffset(304, 229), Size = UDim2.fromOffset(1312, 851), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 0, ScrollBarImageTransparency = 1, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = page,
	})
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 64), Parent = scroll })
	new("UIPadding", { PaddingBottom = UDim.new(0, 60), Parent = scroll })
	local panel = new("Frame", {
		Name = "Panel", LayoutOrder = 1, Size = UDim2.fromOffset(1296, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.55, Parent = scroll,
	})
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 7.6), Parent = panel })
	new("UIPadding", { PaddingTop = UDim.new(0, 27), PaddingBottom = UDim.new(0, 90), Parent = panel })

	-- glyph builders ------------------------------------------------------------------------------
	local function register(name, press, release)
		glyphs[name] = glyphs[name] or {}
		table.insert(glyphs[name], { press = press, release = release })
	end

	local function keycap(parent, name)
		local text = KEY_LABEL[name] or name
		local w = math.max(40, #text * 14 + 18)
		local cap = new("Frame", { Name = "Keycap", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(w, 46), BackgroundColor3 = Theme.hex("#1C1C1F"), Parent = parent }, { Kit.corner(8) })
		local face = new("Frame", { Name = "Face", Size = UDim2.new(1, 0, 0, 41), BackgroundColor3 = Theme.hex("#4A4A4F"), Parent = cap }, { Kit.corner(8) }) -- (2026-10-21, AI-tells sweep) no 1.5 px edge: the dark cap below is the lip
		Kit.label({ Text = text, FontFace = F.display, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = face })
		register(name, function()
			Kit.tween(face, 0.05, { Position = Kit.S(cap, 0, 4), BackgroundColor3 = Theme.hex("#3A3A3F") })
		end, function()
			Kit.tween(face, 0.12, { Position = UDim2.fromScale(0, 0), BackgroundColor3 = Theme.hex("#4A4A4F") })
		end)
	end

	local function mouseGlyph(parent, name)
		local which = MOUSE[name]
		local body = new("ImageLabel", { Name = "Mouse", BackgroundTransparency = 1, Image = A.mouse_body or "", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(46, 46), Parent = parent })
		local hl = new("ImageLabel", { Name = "Button", BackgroundTransparency = 1, Image = A["mouse_hl_" .. which] or "", ImageColor3 = C.white, Size = UDim2.fromScale(1, 1), Parent = body })
		register(name, function() Kit.tween(hl, 0.05, { ImageColor3 = Theme.hex("#E53935") }) end,
			function() Kit.tween(hl, 0.15, { ImageColor3 = C.white }) end)
	end

	local function padGlyph(parent, name)
		local g = new("Frame", { Name = "Pad", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(46, 46), Parent = parent })
		if FACE[name] then
			local c = new("Frame", { BackgroundColor3 = C.white, Size = UDim2.fromScale(1, 1), Parent = g }, { Kit.corner(23) })
			Kit.label({ Text = FACE[name], TextColor3 = C.textDark, FontFace = F.display, TextSize = 30, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = c })
		elseif SHOULDER[name] or STICK[name] then
			local isStick = STICK[name] ~= nil
			local c = new("Frame", { BackgroundColor3 = C.white, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromOffset(44, isStick and 30 or 36), Parent = g }, { Kit.corner(7) })
			Kit.label({ Text = SHOULDER[name] or STICK[name], TextColor3 = C.textDark, FontFace = F.display, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = c })
			if isStick then
				new("ImageLabel", { BackgroundTransparency = 1, Image = A.tri_down or "", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(12, 10), Parent = g })
			end
		elseif DPAD[name] then
			new("Frame", { BackgroundColor3 = C.white, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(44, 16), Parent = g }, { Kit.corner(3) })
			new("Frame", { BackgroundColor3 = C.white, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(16, 44), Parent = g }, { Kit.corner(3) })
			local d = DPAD[name]
			local pos = ({ up = UDim2.new(0.5, 0, 0, 7), down = UDim2.new(0.5, 0, 1, -7), left = UDim2.new(0, 7, 0.5, 0), right = UDim2.new(1, -7, 0.5, 0) })[d]
			new("ImageLabel", { BackgroundTransparency = 1, Image = A["tri_" .. d] or "", ImageColor3 = C.textDark, AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = UDim2.fromOffset(9, 9), Parent = g })
		else
			keycap(parent, name); g:Destroy(); return
		end
		local sc = new("UIScale", { Parent = g })
		register(name, function() Kit.tween(sc, 0.05, { Scale = 0.85 }) end, function() Kit.tween(sc, 0.15, { Scale = 1 }, Enum.EasingStyle.Back) end)
	end

	local function drawGlyph(slot, name)
		for _, ch in ipairs(slot:GetChildren()) do
			if ch.Name ~= "Hover" and not ch:IsA("UICorner") then ch:Destroy() end
		end
		if name == "" or name == nil then return end
		if MOUSE[name] then mouseGlyph(slot, name)
		elseif name:match("^Button") or name:match("^DPad") then padGlyph(slot, name)
		else keycap(slot, name) end
		if slot:GetAttribute("S") then Kit.toScale(slot) end -- runtime redraws convert themselves
	end

	-- rows ----------------------------------------------------------------------------------------
	local listening -- {slot, row, i}
	local order = 0
	for gi, sec in ipairs(ctx.tab.sections) do
		if gi > 1 then
			order += 1
			new("Frame", { Name = "GroupGap", LayoutOrder = order, BackgroundTransparency = 1, Size = UDim2.fromOffset(1296, 90), Parent = panel })
		end
		for _, row in ipairs(sec.rows) do
			order += 1
			local r = new("Frame", { Name = row.name, LayoutOrder = order, Size = UDim2.fromOffset(1296, 58), BackgroundTransparency = 1, Parent = panel })
			-- faint band that fades out to the right (reference rows)
			new("Frame", { Name = "Band", Size = UDim2.fromOffset(700, 58), BackgroundColor3 = C.white, BackgroundTransparency = 0.96, Parent = r },
				{ new("UIGradient", { Transparency = NumberSequence.new(0, 1) }) })
			local img = Assets.rowIcon and (Assets.rowIcon[row.icon] or A[row.icon])
			new("ImageLabel", { Name = "Icon", BackgroundTransparency = 1, Image = img or "", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 102, 0.5, 0), Size = UDim2.fromOffset(44, 44), Parent = r })
			Kit.label({ Name = "Label", Text = row.name, FontFace = F.heavy, TextSize = 32, Position = UDim2.fromOffset(156, 0), Size = UDim2.fromOffset(480, 58), Parent = r })
			for i = 1, 4 do
				local slot = new("TextButton", {
					Name = "Slot" .. i, Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(COLX[i] - 59 - 8, 0), Size = UDim2.fromOffset(118, 58),
					BackgroundColor3 = Theme.hex("#0E0C10"), BackgroundTransparency = 0.25, Parent = r,
				}, { Kit.corner(6) })
				local hover = new("Frame", { Name = "Hover", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 5, Parent = slot })
				local clear = new("TextButton", { Name = "Clear", Text = "", AutoButtonColor = false, BackgroundColor3 = Theme.hex("#E0302F"), Size = UDim2.new(0.5, 0, 1, 0), ZIndex = 5, Parent = hover }, { Kit.corner(6), Kit.vgrad({ Theme.hex("#FF4A4A"), Theme.hex("#D42A2A") }) })
				new("ImageLabel", { BackgroundTransparency = 1, Image = Assets.rowIcon and Assets.rowIcon.hide or "", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(34, 34), ZIndex = 6, Parent = clear })
				local edit = new("TextButton", { Name = "Edit", Text = "", AutoButtonColor = false, BackgroundColor3 = Theme.hex("#0A78E8"), Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(0.5, 0, 1, 0), ZIndex = 5, Parent = hover }, { Kit.corner(6), Kit.vgrad({ Theme.hex("#2E9BFF"), Theme.hex("#0A62D8") }) })
				new("ImageLabel", { BackgroundTransparency = 1, Image = A.pencil or "", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(32, 32), ZIndex = 6, Parent = edit })

				local function current() return (ctx.values[row.name] or row.value)[i] or "" end
				local function setBind(name)
					local binds = table.clone(ctx.values[row.name] or row.value) -- never mutate the defaults table
					binds[i] = name
					ctx.onChange(row.name, binds)
					drawGlyph(slot, name)
				end
				drawGlyph(slot, current())
				-- hover: bound slot -> red clear + blue edit halves; empty slot -> only the blue edit, full width
				local function layoutHover()
					local empty = current() == ""
					clear.Visible = not empty
					edit.Position = empty and UDim2.fromScale(0, 0) or UDim2.fromScale(0.5, 0)
					edit.Size = empty and UDim2.fromScale(1, 1) or UDim2.new(0.5, 0, 1, 0)
				end
				slot.MouseEnter:Connect(function() if not listening then layoutHover(); hover.Visible = true end end)
				slot.MouseLeave:Connect(function() hover.Visible = false end)
				clear.Activated:Connect(function() setBind(""); hover.Visible = false end)
				edit.Activated:Connect(function()
					hover.Visible = false
					drawGlyph(slot, "")
					-- waiting box: grey rounded with three white dots
					local wait = new("Frame", { Name = "Waiting", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(104, 44), BackgroundColor3 = Theme.hex("#4E4E52"), Parent = slot }, { Kit.corner(8) })
					for d = -1, 1 do
						new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, d * 22, 0.5, 0), Size = UDim2.fromOffset(11, 11), BackgroundColor3 = C.white, Parent = wait }, { Kit.corner(6) })
					end
					if slot:GetAttribute("S") then Kit.toScale(slot) end
					task.delay(0.2, function() listening = { slot = slot, set = setBind, current = current } end) -- skip the click that opened it
				end)
			end
		end
	end

	-- reset card (centred under the table)
	local card = new("Frame", { Name = "Reset", LayoutOrder = 2, Size = UDim2.fromOffset(771, 93), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = Theme.alpha.header, Parent = scroll }, { Kit.corner(6) })
	Kit.label({ Text = "Reset", FontFace = F.display, TextSize = 42, Position = UDim2.fromOffset(60, 6), Size = UDim2.fromOffset(400, 50), Parent = card })
	if Assets.rowIcon and Assets.rowIcon.reset then
		new("ImageLabel", { BackgroundTransparency = 1, Image = Assets.rowIcon.reset, Position = UDim2.fromOffset(20, 14), Size = UDim2.fromOffset(34, 34), Parent = card })
	end
	Kit.label({ Text = "Double-click to put your Hotkeys settings back to default", FontFace = F.medium, TextSize = 21, TextColor3 = C.textDim, Position = UDim2.fromOffset(17, 54), Size = UDim2.fromOffset(620, 28), Parent = card })
	local resetBtn = Kit.button("red", UDim2.fromOffset(107, 58), nil)
	resetBtn.AnchorPoint = Vector2.new(1, 0.5); resetBtn.Position = UDim2.new(1, -16, 0.5, 0); resetBtn.Parent = card
	if Assets.rowIcon and Assets.rowIcon.reset then
		new("ImageLabel", { BackgroundTransparency = 1, Image = Assets.rowIcon.reset, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(38, 38), Parent = resetBtn })
	end
	local last = 0
	resetBtn.Activated:Connect(function()
		if os.clock() - last < 0.4 then ctx.onReset() end
		last = os.clock()
	end)

	-- input: rebind while listening, otherwise play press animations
	table.insert(conns, UserInputService.InputBegan:Connect(function(input)
		local name = inputName(input)
		if not name then return end
		if listening then
			local l = listening
			listening = nil
			if name == "Escape" then
				drawGlyph(l.slot, l.current()) -- cancel: restore what was there
			else
				l.set(name)
			end
			return
		end
		for _, g in ipairs(glyphs[name] or {}) do g.press() end
	end))
	table.insert(conns, UserInputService.InputEnded:Connect(function(input)
		local name = inputName(input)
		for _, g in ipairs(glyphs[name or ""] or {}) do g.release() end
	end))
	page.Destroying:Connect(function() for _, c in ipairs(conns) do c:Disconnect() end end)
	return page
end

return HotkeysPage
