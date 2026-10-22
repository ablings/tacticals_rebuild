-- Kit: shared RIVALS-style components (wiki: RIVALS UI - Design System, 4 Component Recipes,
-- 5 States and Motion). Every constructor returns the root instance (plus a small API table where
-- the component has state). Sizes are design-canvas pixels (1920x1080), see Kit.canvas.
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Theme = require(script.Parent.Theme)

local C, F = Theme.color, Theme.font
local Kit = {}

function Kit.new(class, props, children)
	local inst = Instance.new(class)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then inst[k] = v end
	end
	for _, ch in ipairs(children or {}) do ch.Parent = inst end
	if props and props.Parent then inst.Parent = props.Parent end
	return inst
end
local new = Kit.new

function Kit.tween(obj, t, goal, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end

-- UI sounds (2026-10-17, Edward: richer, more immersive): Roblox's own client sounds (no uploads) in SoundService.Effects,
-- so Settings > Audio > SFX / Master reach them. hover / click on every Kit button, open / close on menus.
local SFX = {
	hover = { id = "rbxasset://sounds/switch.wav", vol = 0.18, speed = 1.5 },
	click = { id = "rbxasset://sounds/clickfast.wav", vol = 0.45, speed = 1.1 },
	open = { id = "rbxasset://sounds/swordlunge.wav", vol = 0.16, speed = 1.6 },
	close = { id = "rbxasset://sounds/snap.wav", vol = 0.22, speed = 1.3 },
	reward = { id = "rbxasset://sounds/electronicpingshort.wav", vol = 0.4, speed = 1 },
}
local sfxPool, sfxLast = {}, {}
function Kit.sfx(name)
	local spec = SFX[name]
	if not spec then return end
	local now = os.clock()
	if sfxLast[name] and now - sfxLast[name] < 0.04 then return end -- a sweep across buttons doesn't machine-gun
	sfxLast[name] = now
	local s = sfxPool[name]
	if not s or not s.Parent then
		local SoundService = game:GetService("SoundService")
		s = Instance.new("Sound")
		s.Name = "UI_" .. name
		s.SoundId = spec.id
		s.Volume = spec.vol
		s.PlaybackSpeed = spec.speed
		s.SoundGroup = SoundService:FindFirstChild("Effects")
		s.Parent = SoundService
		sfxPool[name] = s
	end
	s.TimePosition = 0
	s:Play()
end

function Kit.corner(r) return new("UICorner", { CornerRadius = UDim.new(0, r or Theme.corner) }) end
function Kit.stroke(color, thick, t)
	return new("UIStroke", { Color = color or C.textDark, Thickness = thick or 2, Transparency = t or 0 })
end
function Kit.textStroke(thick)
	return new("UIStroke", { Color = C.textDark, Thickness = thick or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
end
function Kit.vgrad(pair)
	return new("UIGradient", { Rotation = 90, Color = ColorSequence.new(pair[1], pair[2]) })
end
function Kit.pad(l, t, r, b)
	return new("UIPadding", { PaddingLeft = UDim.new(0, l), PaddingTop = UDim.new(0, t or l), PaddingRight = UDim.new(0, r or l), PaddingBottom = UDim.new(0, b or t or l) })
end

function Kit.label(props)
	local p = {
		BackgroundTransparency = 1, TextColor3 = C.text, FontFace = F.bold, TextSize = 36,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
	}
	for k, v in pairs(props) do p[k] = v end
	return new("TextLabel", p)
end

-- Design canvas: Scale-sized 16:9 frame, centred (letterboxed on ultrawide). Screens are written in
-- 1920x1080 design px, then Kit.toScale() converts them: UI rule (Edward) = Position/Size in Scale only.
function Kit.canvas(screenGui)
	local canvas = new("Frame", {
		Name = "Canvas", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), Parent = screenGui,
	}, { new("UIAspectRatioConstraint", { AspectRatio = Theme.design.X / Theme.design.Y }) })
	canvas:SetAttribute("DesignCanvas", true)
	if not (Kit._canvas and Kit._canvas.Parent) then Kit._canvas = canvas end
	-- (2026-10-20) rescale text when the canvas itself resizes: the old CurrentCamera ViewportSize hook went dead when a place
	-- swapped CurrentCamera (match intro / spectate), so text kept the size of the window it was built in
	canvas:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if Kit._rescalePending then return end
		Kit._rescalePending = true
		task.defer(function() Kit._rescalePending = false; Kit.rescaleText() end)
	end)
	return canvas
end

-- design px per screen px: canvas height / 1080 (all canvases share it)
function Kit.factor()
	local c = Kit._canvas
	if c and c.AbsoluteSize.Y > 0 then return c.AbsoluteSize.Y / Theme.design.Y end
	local v = workspace.CurrentCamera.ViewportSize
	return math.min(v.X / Theme.design.X, v.Y / Theme.design.Y)
end

-- Text sizes and stroke thickness have no Scale form: keep their design values as attributes and
-- size them from the screen height.
Kit._scaled = {} -- strong refs: Roblox can drop instances from weak tables while they are still on screen
local function applyScaled(o, f)
	if o:IsA("UIStroke") then
		o.Thickness = math.max(0.5, o:GetAttribute("dTh") * f)
	elseif o:IsA("UITextSizeConstraint") then
		o.MaxTextSize = math.max(1, math.floor(o:GetAttribute("dMax") * f + 0.5))
	elseif o:IsA("ScrollingFrame") then
		o.ScrollBarThickness = math.max(1, math.floor(o:GetAttribute("dSB") * f + 0.5))
	else
		o.TextSize = math.max(1, math.floor(o:GetAttribute("dTS") * f + 0.5))
		local rt = o:GetAttribute("dText")
		if rt and o.Text ~= "" then
			o.Text = (rt:gsub('size="(%d+)"', function(n) return 'size="' .. math.floor(tonumber(n) * f + 0.5) .. '"' end))
		end
	end
end
function Kit.rescaleText()
	local f = Kit.factor()
	for o in pairs(Kit._scaled) do
		if o.Parent then applyScaled(o, f) else Kit._scaled[o] = nil end
	end
end
-- call after changing a rich-text label's Text at runtime so its <font size> tags scale too
function Kit.setRichText(label, text)
	label:SetAttribute("dText", text)
	label.Text = text
	if Kit._scaled[label] then applyScaled(label, Kit.factor()) end
end

-- design size of something already on screen (converted, or the canvas itself)
local function designOf(g)
	if g:GetAttribute("DesignCanvas") then return Theme.design end
	if g:IsA("ScrollingFrame") then return g.AbsoluteCanvasSize / Kit.factor() end
	return g.AbsoluteSize / Kit.factor()
end

-- design size of a fresh (or converted) node, resolving AutomaticSize / auto canvas from its children
-- (sums a UIListLayout, otherwise the furthest child edge) instead of reading stale AbsoluteSize
local function attrOr(m, key, fallback) local v = m:GetAttribute(key); if v == nil then return fallback end return v end
local function contentExtent(g, cw, chh)
	local layout = g:FindFirstChildOfClass("UIListLayout")
	local uip = g:FindFirstChildOfClass("UIPadding")
	local pl = uip and attrOr(uip, "dPaddingLeft", uip.PaddingLeft.Offset) or 0
	local pr = uip and attrOr(uip, "dPaddingRight", uip.PaddingRight.Offset) or 0
	local pt = uip and attrOr(uip, "dPaddingTop", uip.PaddingTop.Offset) or 0
	local pb = uip and attrOr(uip, "dPaddingBottom", uip.PaddingBottom.Offset) or 0
	local inner = Vector2.new(cw - pl - pr, chh - pt - pb)
	local sumY, sumX, maxX, maxY, n = 0, 0, 0, 0, 0
	for _, c in ipairs(g:GetChildren()) do
		if c:IsA("GuiObject") and c.Visible then
			local cs = Kit._measure(c, inner)
			n += 1
			sumY += cs.Y; sumX += cs.X
			local cx = c.Position.X.Scale * inner.X + c.Position.X.Offset - c.AnchorPoint.X * cs.X
			local cy = c.Position.Y.Scale * inner.Y + c.Position.Y.Offset - c.AnchorPoint.Y * cs.Y
			maxX = math.max(maxX, layout and cs.X or cx + cs.X)
			maxY = math.max(maxY, layout and cs.Y or cy + cs.Y)
		end
	end
	local pad = layout and attrOr(layout, "dPad", layout.Padding.Offset) or 0
	if layout and layout.FillDirection == Enum.FillDirection.Vertical then
		return Vector2.new(maxX + pl + pr, sumY + pad * math.max(0, n - 1) + pt + pb)
	elseif layout then
		return Vector2.new(sumX + pad * math.max(0, n - 1) + pl + pr, maxY + pt + pb)
	end
	return Vector2.new(maxX + pl + pr, maxY + pt + pb)
end
function Kit._measure(g, pd)
	local w = g.Size.X.Scale * pd.X + g.Size.X.Offset
	local h = g.Size.Y.Scale * pd.Y + g.Size.Y.Offset
	local auto = g.AutomaticSize
	local isText = g:IsA("TextLabel") or g:IsA("TextButton") or g:IsA("TextBox")
	if auto ~= Enum.AutomaticSize.None then
		if isText then
			local ts = game:GetService("TextService"):GetTextSize(g.ContentText, attrOr(g, "dTS", g.TextSize), Enum.Font.SourceSans, Vector2.new(1e4, 1e4))
			if auto ~= Enum.AutomaticSize.Y then w = math.max(w, ts.X) end
			if auto ~= Enum.AutomaticSize.X then h = math.max(h, ts.Y) end
		else
			local e = contentExtent(g, w, h)
			if auto ~= Enum.AutomaticSize.Y then w = math.max(w, e.X) end
			if auto ~= Enum.AutomaticSize.X then h = math.max(h, e.Y) end
		end
	end
	return Vector2.new(w, h)
end

local function convertNode(g, pd)
	if g:GetAttribute("NoConvert") then return Vector2.new(pd.X * g.Size.X.Scale, pd.Y * g.Size.Y.Scale), nil end -- already Scale-only, sized by its own constraint
	-- g's design size from its current UDim2 against the parent's design size (Scale parts keep meaning)
	local auto = g.AutomaticSize
	local w = g.Size.X.Scale * pd.X + g.Size.X.Offset
	local h = g.Size.Y.Scale * pd.Y + g.Size.Y.Offset
	local isText = g:IsA("TextLabel") or g:IsA("TextButton") or g:IsA("TextBox")
	local autoX = auto == Enum.AutomaticSize.X or auto == Enum.AutomaticSize.XY
	local autoY = auto == Enum.AutomaticSize.Y or auto == Enum.AutomaticSize.XY
	if not isText and auto ~= Enum.AutomaticSize.None and not g:GetAttribute("KeepAuto") then
		-- containers: freeze their size, worked out from their children
		local m = Kit._measure(g, pd)
		w, h = m.X, m.Y
		g.AutomaticSize = Enum.AutomaticSize.None
	end
	local x = g.Position.X.Scale * pd.X + g.Position.X.Offset
	local y = g.Position.Y.Scale * pd.Y + g.Position.Y.Offset
	-- text that sizes itself keeps AutomaticSize on that axis with a 0 Scale minimum (still no Offset)
	local keep = isText or g:GetAttribute("KeepAuto") -- self-sizing boxes keep AutomaticSize with a 0 Scale minimum
	g.Size = UDim2.fromScale((keep and autoX) and 0 or (pd.X > 0 and w / pd.X or 0), (keep and autoY) and 0 or (pd.Y > 0 and h / pd.Y or 0))
	g:SetAttribute("S", true)
	g.Position = UDim2.fromScale(pd.X > 0 and x / pd.X or 0, pd.Y > 0 and y / pd.Y or 0)
	local cd = Vector2.new(w, h) -- what g's children's Scale refers to
	if g:IsA("ScrollingFrame") then
		if g.ScrollBarThickness > 0 then
			if g:GetAttribute("dSB") == nil then g:SetAttribute("dSB", g.ScrollBarThickness) end
			Kit._scaled[g] = true
			g.ScrollBarThickness = math.max(1, math.floor(g:GetAttribute("dSB") * Kit.factor() + 0.5))
		end
		local ch = h
		if g.AutomaticCanvasSize == Enum.AutomaticSize.Y or g.AutomaticCanvasSize == Enum.AutomaticSize.XY then
			ch = math.max(h, contentExtent(g, w, h).Y)
		else
			ch = g.CanvasSize.Y.Scale * h + g.CanvasSize.Y.Offset
		end
		g.AutomaticCanvasSize = Enum.AutomaticSize.None
		-- measured in Studio: CanvasSize Scale is relative to the ScrollingFrame's PARENT, not the frame
		g.CanvasSize = UDim2.fromScale(0, pd.Y > 0 and ch / pd.Y or 0)
		cd = Vector2.new(w, ch)
	end
	-- children's Scale is measured against the area inside UIPadding (measured in Studio)
	local uip = g:FindFirstChildOfClass("UIPadding")
	if uip then
		local pl = attrOr(uip, "dPaddingLeft", uip.PaddingLeft.Offset)
		local pr = attrOr(uip, "dPaddingRight", uip.PaddingRight.Offset)
		local pt = attrOr(uip, "dPaddingTop", uip.PaddingTop.Offset)
		local pb = attrOr(uip, "dPaddingBottom", uip.PaddingBottom.Offset)
		return cd - Vector2.new(pl + pr, pt + pb), cd
	end
	return cd, cd
end

local function convertModifier(m, pd)
	if m:IsA("UIListLayout") then
		local pad = m:GetAttribute("dPad") or m.Padding.Offset
		m:SetAttribute("dPad", pad)
		local axis = m.FillDirection == Enum.FillDirection.Vertical and pd.Y or pd.X
		m.Padding = UDim.new(axis > 0 and pad / axis or 0, 0)
	elseif m:IsA("UIPadding") then
		for _, side in ipairs({ { "PaddingLeft", pd.X }, { "PaddingRight", pd.X }, { "PaddingTop", pd.Y }, { "PaddingBottom", pd.Y } }) do
			local key = "d" .. side[1]
			local v = m:GetAttribute(key) or m[side[1]].Offset
			m:SetAttribute(key, v)
			m[side[1]] = UDim.new(side[2] > 0 and v / side[2] or 0, 0)
		end
	elseif m:IsA("UICorner") then
		local r = m:GetAttribute("dR") or m.CornerRadius.Offset
		m:SetAttribute("dR", r)
		local short = (pd.X > 0 and pd.Y > 0) and math.min(pd.X, pd.Y) or math.max(pd.X, pd.Y) -- self-sizing box: use the known side
		if r > 0 then m.CornerRadius = UDim.new(short > 0 and math.min(0.5, r / short) or 0.5, 0) end -- zero-size (e.g. empty bar fill): pill
	elseif m:IsA("UIStroke") then
		if m:GetAttribute("dTh") == nil then m:SetAttribute("dTh", m.Thickness) end
		Kit._scaled[m] = true
		applyScaled(m, Kit.factor())
	elseif m:IsA("UITextSizeConstraint") then
		if m:GetAttribute("dMax") == nil then m:SetAttribute("dMax", m.MaxTextSize) end
		Kit._scaled[m] = true
		applyScaled(m, Kit.factor())
	end
end

-- Convert a subtree to Scale. `root`'s own Size/Position are converted against its parent's design
-- size, unless `rootDesign` is given (then root is left as is and its children use that design size).
-- Safe to call again on an already-converted tree (stored design values are reused).
function Kit.toScale(root, rootDesign)
	local f = Kit.factor()
	local function visit(g, pd)
		local cd, full = pd, nil
		if g:IsA("GuiObject") then
			if g:IsA("TextLabel") or g:IsA("TextButton") or g:IsA("TextBox") then
				if g:GetAttribute("dTS") == nil then
					g:SetAttribute("dTS", g.TextSize)
					if g.RichText then g:SetAttribute("dText", g.Text) end
				end
				Kit._scaled[g] = true
				applyScaled(g, f)
			end
			cd, full = convertNode(g, pd)
		end
		for _, ch in ipairs(g:GetChildren()) do
			if ch:IsA("GuiObject") then
				visit(ch, cd)
			elseif ch:IsA("UIPadding") or ch:IsA("UICorner") then
				convertModifier(ch, full or cd) -- padding / corner are fractions of the whole box
			elseif ch:IsA("UIComponent") or ch:IsA("UIStroke") then
				convertModifier(ch, cd)
			end
		end
	end
	if rootDesign then
		for _, ch in ipairs(root:GetChildren()) do
			if ch:IsA("GuiObject") then visit(ch, rootDesign)
			elseif ch:IsA("UIComponent") or ch:IsA("UIStroke") then convertModifier(ch, rootDesign) end
		end
	else
		visit(root, designOf(root.Parent))
	end
end

-- Put a container's list spacing / padding back to design px (before re-measuring new content)
function Kit.restoreModifiers(g)
	for _, m in ipairs(g:GetChildren()) do
		if m:IsA("UIListLayout") and m:GetAttribute("dPad") then
			m.Padding = UDim.new(0, m:GetAttribute("dPad"))
		elseif m:IsA("UIPadding") then
			for _, side in ipairs({ "PaddingLeft", "PaddingRight", "PaddingTop", "PaddingBottom" }) do
				local v = m:GetAttribute("d" .. side)
				if v then m[side] = UDim.new(0, v) end
			end
		end
	end
end

-- Scale UDim2 for a design-px target inside `parent` (for runtime moves/tweens that must stay Scale)
function Kit.S(parent, x, y)
	if not parent:GetAttribute("S") and not parent:GetAttribute("DesignCanvas") then
		return UDim2.fromOffset(x, y) -- not converted yet: the next Kit.toScale pass converts it
	end
	local d = designOf(parent)
	return UDim2.fromScale(x / d.X, y / d.Y)
end

-- Move an element's anchor to its centre without moving it. UIScale grows from the anchor point,
-- so a top-left anchor makes hover growth drift right/down (Edward: Play and the party + did this).
function Kit.centreAnchor(g)
	local ap = g.AnchorPoint
	if ap == Vector2.new(0.5, 0.5) then return end
	local p, sz = g.Position, g.Size
	g.AnchorPoint = Vector2.new(0.5, 0.5)
	g.Position = UDim2.new(p.X.Scale + sz.X.Scale * (0.5 - ap.X), p.X.Offset + sz.X.Offset * (0.5 - ap.X), p.Y.Scale + sz.Y.Scale * (0.5 - ap.Y), p.Y.Offset + sz.Y.Offset * (0.5 - ap.Y))
end

-- Hover/press scale on any GuiButton (UIScale, never Size: keeps layouts intact). Grows from the centre.
function Kit.bindButton(btn, opts)
	opts = opts or {}
	-- re-anchor once the button has its final position (it may be placed after this call)
	task.defer(function()
		local p = btn.Parent
		if p and not p:FindFirstChildOfClass("UIListLayout") and not p:FindFirstChildOfClass("UIGridLayout") then Kit.centreAnchor(btn) end
	end)
	local s = btn:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = btn })
	local hovering = false
	btn.MouseEnter:Connect(function() hovering = true; Kit.tween(s, 0.1, { Scale = opts.hover or 1.05 }); if not opts.silent then Kit.sfx("hover") end end)
	btn.MouseLeave:Connect(function() hovering = false; Kit.tween(s, 0.1, { Scale = 1 }) end)
	btn.MouseButton1Down:Connect(function() Kit.tween(s, 0.06, { Scale = opts.press or 0.93 }) end)
	btn.Activated:Connect(function() if not opts.silent then Kit.sfx("click") end end)
	btn.MouseButton1Up:Connect(function() Kit.tween(s, 0.1, { Scale = hovering and (opts.hover or 1.05) or 1 }, Enum.EasingStyle.Back) end)
	-- a controller's selection (GamepadNavController) grows it like a hover
	btn.SelectionGained:Connect(function() Kit.tween(s, 0.1, { Scale = opts.hover or 1.05 }); if not opts.silent then Kit.sfx("hover") end end)
	btn.SelectionLost:Connect(function() if not hovering then Kit.tween(s, 0.1, { Scale = 1 }) end end)
	return btn
end

-- Gradient button (kinds: robux, key, blue, red, grey). content: text or {icon = "..."}.
function Kit.button(kind, size, text, props)
	local btn = new("TextButton", {
		Name = (text or kind) .. "Button", Size = size, AutoButtonColor = false, Text = "",
		BackgroundColor3 = C.white,
	}, { Kit.corner(3), Kit.vgrad(Theme.gradient[kind]) })
	-- (2026-10-21, user) no lip: RIVALS' buttons are a plain gradient (the darker bottom lip read as a decorative AI underline)
	-- (2026-10-21, RIVALS "alive") the button brightens a touch on hover: a white sheen fades in over its gradient
	local sheen = new("Frame", { Name = "HoverSheen", BackgroundColor3 = C.white, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
		ZIndex = 2, Parent = btn }, { Kit.corner(3) })
	btn.MouseEnter:Connect(function() Kit.tween(sheen, 0.12, { BackgroundTransparency = 0.86 }) end)
	btn.MouseLeave:Connect(function() Kit.tween(sheen, 0.12, { BackgroundTransparency = 1 }) end)
	btn.SelectionGained:Connect(function() Kit.tween(sheen, 0.12, { BackgroundTransparency = 0.86 }) end)
	btn.SelectionLost:Connect(function() Kit.tween(sheen, 0.12, { BackgroundTransparency = 1 }) end)
	if text then
		local lbl = Kit.label({
			Name = "Label", Text = text, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center,
			FontFace = F.chunky, TextSize = math.floor(size.Y.Offset * 0.55), ZIndex = 3, Parent = btn, -- (over the hover sheen)
		})
		Kit.textStroke(2).Parent = lbl
	end
	for k, v in pairs(props or {}) do btn[k] = v end
	return Kit.bindButton(btn)
end

-- (2026-10-21, RIVALS images) gen.<name> from UIKit.Rivals.Assets (looked up lazily, nil when this place has no Rivals folder)
local genAssets
local function genImage(name)
	if genAssets == nil then
		genAssets = false
		local r = script.Parent:FindFirstChild("Rivals")
		local m = r and r:FindFirstChild("Assets")
		if m then
			local ok, A = pcall(require, m)
			if ok and type(A) == "table" and A.gen then genAssets = A.gen end
		end
	end
	return genAssets and genAssets[name] or nil
end

-- Close button (pass 34: gunmetal + olive brackets, warms red on hover) with a chunky white X built from two rotated bars.
function Kit.closeButton(size)
	-- (2026-10-21, user: "whatever RIVALS is doing") RIVALS' red X again (t0062 / t0287): a red gradient block with a chunky white
	-- X and a darker bottom lip (no hairline border). Not named "Close" and tagged Nonapplicable: the old InterfaceController
	-- hooks any "Close" button in a new ScreenGui and shrinks its parent frame to 0 x 0.
	local w, h = size.X.Offset, size.Y.Offset
	local btn = new("TextButton", { Name = "CloseX", Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(w, h), BackgroundColor3 = Color3.new(1, 1, 1) },
		{ Kit.corner(8), new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 106, 77), Color3.fromRGB(197, 42, 26)) }) })
	btn:AddTag("Nonapplicable")
	new("Frame", { Name = "Lip", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.7, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.16), ZIndex = 1, Parent = btn }, { Kit.corner(8) })
	-- (2026-10-21, RIVALS images) the X is now one image, gen.ui_close_x (the whole white ✖ with its grey lower-arm shade, never
	-- tinted), ~40/67 of the button height and centred (0.46: over the face, above the dark lip). Falls back to the old two
	-- bars if UIKit.Rivals.Assets is missing in this place.
	local glyph = genImage("ui_close_x")
	if glyph then
		local g = math.floor(h * 40 / 67)
		new("ImageLabel", { Name = "X", BackgroundTransparency = 1, Image = glyph, ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.46), Size = UDim2.fromOffset(g, g), ZIndex = 2, Parent = btn })
	else
		local len = math.floor(h * 0.62)
		for _, rot in ipairs({ 45, -45 }) do
			new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46), Rotation = rot,
				Size = UDim2.fromOffset(len, math.max(4, math.floor(h * 0.17))), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 2, Parent = btn,
			}, { Kit.corner(3) })
		end
	end
	local sheen = new("Frame", { Name = "HoverSheen", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = btn }, { Kit.corner(8) })
	btn.MouseEnter:Connect(function() Kit.tween(sheen, 0.12, { BackgroundTransparency = 0.82 }) end)
	btn.MouseLeave:Connect(function() Kit.tween(sheen, 0.12, { BackgroundTransparency = 1 }) end)
	Kit.bindButton(btn, { hover = 1.08 })
	return btn
end

-- Image tab: icon overflows the top, label at the bottom with a black stroke; :setSelected(bool).
-- image = asset id, or a function(holder, tab) that draws a live 3D icon into the holder.
function Kit.imageTab(size, text, image, glyph)
	local tab = new("TextButton", {
		Name = text, Size = size, AutoButtonColor = false, Text = "", BackgroundColor3 = C.white, BackgroundTransparency = 1,
	}, { Kit.corner(6) })
	local iconSize = math.floor(size.Y.Offset * 1.55)
	if type(image) == "function" then
		-- live 3D icon: image(holder, tab) fills the holder (e.g. a ViewIcons viewport)
		local holder = new("Frame", {
			Name = "Icon", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -size.Y.Offset * 0.22),
			Size = UDim2.fromOffset(iconSize, iconSize), Parent = tab,
		})
		image(holder, tab)
	elseif image and image ~= "" then
		new("ImageLabel", {
			Name = "Icon", BackgroundTransparency = 1, Image = image, ScaleType = Enum.ScaleType.Fit,
			AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -size.Y.Offset * 0.22),
			Size = UDim2.fromOffset(iconSize, iconSize), Parent = tab,
		})
	else
		Kit.label({ Name = "Icon", Text = glyph or "?", TextSize = 44, TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -size.Y.Offset * 0.3),
			Size = UDim2.fromOffset(iconSize, iconSize * 0.8), Parent = tab })
	end
	local lbl = Kit.label({
		Name = "Label", Text = text, FontFace = F.heavy, TextSize = 31, TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 6), Size = UDim2.new(1, 0, 0, 30), ZIndex = 3, Parent = tab,
	})
	Kit.textStroke(2.5).Parent = lbl
	local bar = new("Frame", { Name = "TacUnderline", BackgroundColor3 = Theme.color.olive, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 10), Size = UDim2.new(0, 0, 0, 4), ZIndex = 4, Parent = tab })
	local api = {}
	function api.setSelected(on)
		tab:SetAttribute("NavTabOn", on == true) -- [PAD] GamepadNavController: the current tab for LB / RB
		Kit.tween(tab, 0.12, { BackgroundTransparency = on and 0 or 1 })
		Kit.tween(bar, 0.15, { Size = UDim2.new(on and 0.7 or 0, 0, 0, 4) })
	end
	Kit.bindButton(tab, { hover = 1.06 })
	return tab, api
end

-- Section header bar (settings style): dark bar + display title.
function Kit.headerBar(width, text, height)
	local bar = new("Frame", {
		Name = "Header_" .. text, Size = UDim2.fromOffset(width, height or 78),
		BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = Theme.alpha.header,
	}, { Kit.corner(3) })
	-- (2026-10-21, AI-tells sweep) no olive TacBar down the left edge (as SettingsKit); the title moves in to 22
	Kit.label({ Text = string.upper(text), FontFace = F.display, TextSize = 61, Position = UDim2.fromOffset(22, 0), Size = UDim2.new(1, -22, 1, 0), Parent = bar })
	return bar
end

-- Toggle 110x55: green + knob right when on, light + knob left when off.
function Kit.toggle(value, onChange)
	local btn = new("TextButton", {
		Name = "Toggle", Size = UDim2.fromOffset(110, 55), AutoButtonColor = false, Text = "", BackgroundColor3 = C.control,
	}, { Kit.corner(7) })
	local knob = new("Frame", { Name = "Knob", AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(41, 41), BackgroundColor3 = C.textDark, Parent = btn }, { Kit.corner(4) })
	-- (lobby revamp, graders: on vs off was unreadable) the word sits on the free side of the knob
	local word = new("TextLabel", { Name = "State", BackgroundTransparency = 1, FontFace = F.bold, TextSize = 20, TextColor3 = C.textDark,
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(52, 30), Parent = btn })
	local api = { value = value }
	-- smooth, slow slide + colour blend (RIVALS). No debounce: each click starts a new tween from the
	-- knob's current spot, so fast clicking reverses it mid-way.
	local TOGGLE_TIME = 0.25 -- Edward: a little faster than 0.35
	local function render(t)
		Kit.tween(knob, t, { Position = api.value and UDim2.fromScale(62 / 110, 0.5) or UDim2.fromScale(7 / 110, 0.5) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		Kit.tween(btn, t, { BackgroundColor3 = api.value and C.green or C.control }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		word.Text = api.value and "ON" or "OFF"
		word.TextColor3 = api.value and Color3.new(1, 1, 1) or C.textDark
		word.Position = api.value and UDim2.fromScale(32 / 110, 0.5) or UDim2.fromScale(80 / 110, 0.5)
	end
	function api.set(v) api.value = v; render(TOGGLE_TIME); if onChange then onChange(v) end end
	btn.Activated:Connect(function() api.set(not api.value) end)
	render(0)
	return Kit.bindButton(btn, { hover = 1.04 }), api
end

-- Stepper (arrows + value box) on the row's top line and a slider track under it.
-- spec: {min, max, step (rounding for drag/typing), arrowStep (per arrow click, default step), value, fmt}
function Kit.stepperSlider(rowWidth, spec, onChange)
	local holder = new("Frame", { Name = "StepperSlider", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0) })
	local api = { value = spec.value }
	local fmt = spec.fmt or function(v) return tostring(v) end

	local arrows = new("Frame", {
		Name = "Arrows", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -132, 0, 17), Size = UDim2.fromOffset(53, 55),
		BackgroundColor3 = C.control, Parent = holder,
	}, { Kit.corner(6) })
	-- two real buttons (top/bottom halves): click coordinates include the top-bar inset, so don't split by y
	local upBtn = new("TextButton", { Name = "Up", Text = "▲", TextColor3 = C.textDark, TextSize = 19, FontFace = F.bold, BackgroundTransparency = 1, AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.25, 1), Size = UDim2.new(1, 0, 0.5, -3), Parent = arrows }) -- centre anchor: UIScale grows from the anchor
	local downBtn = new("TextButton", { Name = "Down", Text = "▼", TextColor3 = C.textDark, TextSize = 19, FontFace = F.bold, BackgroundTransparency = 1, AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.75, -1), Size = UDim2.new(1, 0, 0.5, -3), Parent = arrows })
	-- value box is typeable: the typed number is rounded to the nearest step on FocusLost
	local box = new("TextBox", {
		Name = "Value", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -22, 0, 17), Size = UDim2.fromOffset(103, 55),
		BackgroundColor3 = C.control, Text = "", TextColor3 = C.textDark, FontFace = F.heavy, TextSize = 30,
		ClearTextOnFocus = false, Parent = holder,
	}, { Kit.corner(6) })

	local track = new("Frame", {
		Name = "Track", Position = UDim2.new(0, 35, 0, 100), Size = UDim2.new(1, -70, 0, 6), BackgroundColor3 = C.track, Parent = holder,
	}, { Kit.corner(3) })
	local knob = new("TextButton", {
		Name = "Knob", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(32, 34), BackgroundColor3 = C.control,
		AutoButtonColor = false, Text = "", Position = UDim2.fromScale(0, 0.5), Parent = track,
	}, { Kit.corner(7) })

	local dragging = false
	local function frac(v) return (v - spec.min) / (spec.max - spec.min) end
	local function round(v)
		local r = math.clamp(math.floor((v - spec.min) / spec.step + 0.5) * spec.step + spec.min, spec.min, spec.max)
		return math.floor(r * 1e6 + 0.5) / 1e6 -- kill float drift (0.25 must equal 0.25 for the reset check)
	end
	local function render(t)
		box.Text = fmt(api.value)
		if not dragging then Kit.tween(knob, t or 0.12, { Position = UDim2.fromScale(frac(api.value), 0.5) }, (t and t > 0.3) and Enum.EasingStyle.Quart or (t and t > 0.2) and Enum.EasingStyle.Sine or Enum.EasingStyle.Quad) end
	end
	function api.set(v, t)
		v = round(v)
		if v == api.value then render(t); return end
		api.value = v; render(t); if onChange then onChange(v) end
	end
	box.Focused:Connect(function() box.Text = tostring(api.value) end)
	box.FocusLost:Connect(function()
		local n = tonumber((box.Text:gsub("[^%d%.%-]", "")))
		if n then api.set(n) else render() end
	end)
	local d = spec.arrowStep or spec.step -- arrows can move further than the rounding step
	-- arrow motion (RIVALS): small glyphs that grow on hover; every click pulses them smaller then back
	-- up to the hover size (played on Activated, so fast clicks each get a pulse)
	local ARROW_HOVER = 1.35
	for _, pair in ipairs({ { upBtn, d }, { downBtn, -d } }) do
		local b, delta = pair[1], pair[2]
		local sc = new("UIScale", { Parent = b })
		local hovering = false
		b.MouseEnter:Connect(function() hovering = true; Kit.tween(sc, 0.12, { Scale = ARROW_HOVER }) end)
		b.MouseLeave:Connect(function() hovering = false; Kit.tween(sc, 0.12, { Scale = 1 }) end)
		b.Activated:Connect(function()
			api.set(api.value + delta, 0.25) -- knob eases to the new value instead of snapping
			Kit.tween(sc, 0.06, { Scale = 0.88 })
			task.delay(0.06, function() Kit.tween(sc, 0.2, { Scale = hovering and ARROW_HOVER or 1 }, Enum.EasingStyle.Sine) end)
		end)
	end

	-- smooth drag: the knob follows the pointer exactly, only the value snaps to the step.
	-- RIVALS: only the knob can be dragged (clicking the track does nothing), and it keeps the
	-- point where it was grabbed instead of jumping to the cursor.
	local grab = 0
	local function dragTo(x)
		local a, w = track.AbsolutePosition.X, track.AbsoluteSize.X
		local f = math.clamp((x - grab - a) / w, 0, 1)
		knob.Position = UDim2.fromScale(f, 0.5)
		api.set(spec.min + f * (spec.max - spec.min))
	end
	knob.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			grab = i.Position.X - (knob.AbsolutePosition.X + knob.AbsoluteSize.X / 2)
		end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then dragTo(i.Position.X) end
	end)
	UserInputService.InputEnded:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			render(0.1) -- settle onto the snapped value
		end
	end)
	Kit.bindButton(knob, { hover = 1.12, press = 1.0 })
	render(0)
	return holder, api
end

-- Dropdown 208x55: light box, black text, ▼; opens a list under itself (parented to popupLayer).
function Kit.dropdown(options, value, popupLayer, onChange)
	local btn = new("TextButton", {
		Name = "Dropdown", Size = UDim2.fromOffset(208, 55), AutoButtonColor = false, Text = "", BackgroundColor3 = C.control,
	}, { Kit.corner(7) })
	local lbl = Kit.label({ Text = value, TextColor3 = C.textDark, FontFace = F.heavy, TextScaled = true, Position = UDim2.fromOffset(12, 12), Size = UDim2.new(1, -50, 1, -24), Parent = btn })
	new("UITextSizeConstraint", { MaxTextSize = 27, Parent = lbl }) -- long values ("Using Controller") shrink instead of truncating
	Kit.label({ Text = "▼", TextColor3 = C.textDark, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 0), Size = UDim2.new(0, 34, 1, 0), Parent = btn })
	local api = { value = value }
	local list
	local function closeList()
		if list then list:Destroy(); list = nil end
	end
	btn.Activated:Connect(function()
		if list then closeList(); return end
		-- popupLayer is the design canvas: convert screen pixels back to canvas pixels
		local canvas = popupLayer
		local sc = canvas.AbsoluteSize.X / Theme.design.X
		local rel = (btn.AbsolutePosition - canvas.AbsolutePosition) / sc
		local OPT_H, PAD = 54, 8
		list = new("Frame", { Name = "DropdownList", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 60, Parent = canvas })
		local catcher = new("TextButton", { Name = "Catcher", Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 60, Parent = list })
		catcher.Activated:Connect(closeList)
		-- RIVALS: the list opens over the button itself, right-aligned, slightly wider than the box
		local panel = new("Frame", {
			Name = "Panel", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(rel.X + 208 + 4, rel.Y - 4),
			Size = UDim2.fromOffset(216, #options * OPT_H + PAD * 2), BackgroundColor3 = C.white, ZIndex = 61, Parent = list,
		}, { Kit.corner(8), Kit.pad(PAD), new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }) })
		local s0 = new("UIScale", { Scale = 0.92, Parent = panel })
		Kit.tween(s0, 0.12, { Scale = 1 })
		for i, opt in ipairs(options) do
			local o = new("TextButton", {
				Name = opt, LayoutOrder = i, Size = UDim2.new(1, 0, 0, OPT_H), AutoButtonColor = false, Text = "", ZIndex = 62,
				BackgroundColor3 = C.textDark, BackgroundTransparency = 1, Parent = panel,
			}, { Kit.corner(8) })
			local ol = Kit.label({ Text = opt, TextColor3 = C.textDark, FontFace = F.heavy, TextSize = 25, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -10, 1, 0), ZIndex = 63, Parent = o })
			o.MouseEnter:Connect(function() o.BackgroundTransparency = 0; ol.TextColor3 = C.white end)
			o.MouseLeave:Connect(function() o.BackgroundTransparency = 1; ol.TextColor3 = C.textDark end)
			o.Activated:Connect(function() api.set(opt) end)
		end
		Kit.toScale(list)
	end)
	api.close = closeList
	function api.set(v)
		api.value = v; lbl.Text = v; closeList()
		if onChange then onChange(v) end
	end
	return Kit.bindButton(btn, { hover = 1.08 }), api -- whole box (text + arrow) grows on hover
end

-- Colour swatch 104x52 (cycles a small palette on click).
function Kit.swatch(color, palette, onChange, icon, picker) -- picker = {layer = canvas, wheel = image id}
	local btn = new("TextButton", {
		Name = "Swatch", Size = UDim2.fromOffset(104, 52), AutoButtonColor = false, Text = "", BackgroundColor3 = color,
	}, { Kit.corner(7) })
	if icon then
		new("ImageLabel", { BackgroundTransparency = 1, Image = icon, ImageColor3 = C.textDark, ImageTransparency = 0.75, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(38, 38), Parent = btn })
	end
	local api = { value = color, i = 1 }
	function api.set(c)
		api.value = c
		for i, p in ipairs(palette) do if p == c then api.i = i end end
		Kit.tween(btn, 0.12, { BackgroundColor3 = c })
		if onChange then onChange(c) end
	end
	btn.Activated:Connect(function()
		if picker then
			Kit.colorPicker(picker.layer, btn, api.value, picker.wheel, function(c)
				api.value = c; btn.BackgroundColor3 = c
				if onChange then onChange(c) end
			end, picker.dim)
			return
		end
		api.i = api.i % #palette + 1
		api.value = palette[api.i]
		Kit.tween(btn, 0.12, { BackgroundColor3 = api.value })
		if onChange then onChange(api.value) end
	end)
	return Kit.bindButton(btn, { hover = 1.04 }), api
end

-- Key-bind box: click, then press a key.
function Kit.keybind(keyName, onChange)
	local btn = new("TextButton", {
		Name = "Keybind", Size = UDim2.fromOffset(150, 52), AutoButtonColor = false, Text = "", BackgroundColor3 = C.control,
	}, { Kit.corner(5) })
	local lbl = Kit.label({ Text = keyName, TextColor3 = C.textDark, FontFace = F.heavy, TextSize = 26, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = btn })
	local api, waiting = { value = keyName }, nil
	function api.set(k)
		api.value = k; lbl.Text = k
		if onChange then onChange(k) end
	end
	btn.Activated:Connect(function()
		lbl.Text = "..."
		if waiting then waiting:Disconnect() end
		waiting = UserInputService.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.Keyboard then
				api.value = i.KeyCode.Name; lbl.Text = api.value
				waiting:Disconnect(); waiting = nil
				if onChange then onChange(api.value) end
			end
		end)
	end)
	return Kit.bindButton(btn, { hover = 1.04 }), api
end

-- Colour picker popup (RIVALS settings): R/G/B boxes + hex box on the left, hue/saturation wheel,
-- brightness bar on the right. Opens under the anchor, right-aligned; outside click closes.
-- Layout in canvas px measured from Edward's capture (panel 567x334).
function Kit.colorPicker(layer, anchor, color, wheelImage, onChange, dimTarget)
	local old = layer:FindFirstChild("ColorPicker")
	if old then old:Destroy() end
	local sc = layer.AbsoluteSize.X / Theme.design.X
	local rel = (anchor.AbsolutePosition - layer.AbsolutePosition) / sc
	local asz = anchor.AbsoluteSize / sc

	local root = new("Frame", { Name = "ColorPicker", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 60, Parent = layer })
	local catcher = new("TextButton", { Name = "Catcher", Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 60, Parent = root })
	catcher.Activated:Connect(function() root:Destroy() end)
	if dimTarget then
		-- RIVALS darkens the settings list behind the picker
		local dp = (dimTarget.AbsolutePosition - layer.AbsolutePosition) / sc
		local ds = dimTarget.AbsoluteSize / sc
		local dim = new("Frame", { Name = "Dim", Position = UDim2.fromOffset(dp.X, dp.Y), Size = UDim2.fromOffset(ds.X, ds.Y), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, ZIndex = 60, Parent = root }, { Kit.corner(8) })
		Kit.tween(dim, 0.15, { BackgroundTransparency = 0.45 })
	end
	local panel = new("Frame", {
		Name = "Panel", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(rel.X + asz.X + 12, rel.Y + asz.Y + 17),
		Size = UDim2.fromOffset(567, 334), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.05, ZIndex = 61, Parent = root,
	}, { Kit.corner(8) })
	local pop = new("UIScale", { Scale = 0.92, Parent = panel })
	Kit.tween(pop, 0.14, { Scale = 1 })

	local h, s, v = color:ToHSV()
	local boxes = {}
	local chans = { { "R", Color3.fromRGB(255, 0, 0) }, { "G", Color3.fromRGB(0, 230, 0) }, { "B", Color3.fromRGB(0, 0, 255) } }
	for i, ch in ipairs(chans) do
		local box = new("Frame", { Name = ch[1], Position = UDim2.fromOffset(14, 15 + (i - 1) * 78), Size = UDim2.fromOffset(128, 64), BackgroundColor3 = C.white, ZIndex = 62, Parent = panel }, { Kit.corner(6) })
		-- (2026-10-21, AI-tells sweep) the 3 px left accent bar is gone (as SettingsKit); the channel colour stays on the number itself
		boxes[i] = new("TextBox", {
			Name = "Value", BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -12, 1, 0),
			TextColor3 = ch[2], FontFace = F.heavy, TextSize = 38, ClearTextOnFocus = false, ZIndex = 63, Parent = box,
		})
	end
	local hex = new("TextBox", {
		Name = "Hex", Position = UDim2.fromOffset(12, 248), Size = UDim2.fromOffset(132, 72), BackgroundColor3 = color,
		TextColor3 = C.white, FontFace = F.heavy, TextSize = 27, ClearTextOnFocus = false, ZIndex = 62, Parent = panel,
	}, { Kit.corner(6), Kit.textStroke(1.5) }) -- outlined so #ffffff stays readable on white

	local WHEEL = 275
	local wheel = new("ImageLabel", {
		Name = "Wheel", BackgroundTransparency = 1, Image = wheelImage or "", Position = UDim2.fromOffset(164, 28), Size = UDim2.fromOffset(WHEEL, WHEEL),
		ZIndex = 62, Parent = panel,
	})
	-- black disc over the wheel whose transparency = brightness, so the wheel darkens with the bar
	local dim = new("Frame", { Name = "Dim", BackgroundColor3 = Color3.new(0, 0, 0), Size = UDim2.fromScale(1, 1), ZIndex = 63, Parent = wheel }, { Kit.corner(WHEEL) })
	local cursor = new("Frame", {
		Name = "Cursor", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(16, 16), BackgroundTransparency = 1, ZIndex = 64, Parent = wheel,
	}, { Kit.corner(8), Kit.stroke(C.white, 3, 0) })

	local bar = new("Frame", { Name = "Brightness", Position = UDim2.fromOffset(467, 9), Size = UDim2.fromOffset(63, 310), BackgroundColor3 = C.white, ZIndex = 62, Parent = panel }, { Kit.corner(4) })
	local barGrad = new("UIGradient", { Rotation = 90, Parent = bar })
	local knob = new("Frame", { Name = "Knob", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(70, 18), BackgroundColor3 = C.white, ZIndex = 63, Parent = bar }, { Kit.corner(9) })

	local quiet = false -- the first render only draws; it must not report a "change" (HSV round-trip drift)
	local function render(skip)
		local c = Color3.fromHSV(h, s, v)
		local r, g, b = math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)
		if skip ~= "rgb" then boxes[1].Text, boxes[2].Text, boxes[3].Text = tostring(r), tostring(g), tostring(b) end
		if skip ~= "hex" then hex.Text = "#" .. c:ToHex():lower() end
		hex.BackgroundColor3 = c
		dim.BackgroundTransparency = v
		local ang = h * 2 * math.pi
		cursor.Position = UDim2.fromScale(0.5 + math.sin(ang) * s * 0.5, 0.5 - math.cos(ang) * s * 0.5)
		barGrad.Color = ColorSequence.new(Color3.fromHSV(h, s, 1), Color3.new(0, 0, 0))
		knob.Position = UDim2.new(0.5, 0, 1 - v, 0)
		if not quiet then onChange(c) end
	end

	local mode
	local function update(pos)
		if mode == "wheel" then
			local ctr = wheel.AbsolutePosition + wheel.AbsoluteSize / 2
			local d = Vector2.new(pos.X, pos.Y) - ctr
			local rad = wheel.AbsoluteSize.X / 2
			s = math.clamp(d.Magnitude / rad, 0, 1)
			h = (math.atan2(d.X, -d.Y) / (2 * math.pi)) % 1
		elseif mode == "bar" then
			v = 1 - math.clamp((pos.Y - bar.AbsolutePosition.Y) / bar.AbsoluteSize.Y, 0, 1)
		end
		render()
	end
	for _, pair in ipairs({ { wheel, "wheel" }, { bar, "bar" } }) do
		pair[1].InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
				mode = pair[2]; update(i.Position)
			end
		end)
	end
	local c1 = UserInputService.InputChanged:Connect(function(i)
		if mode and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then update(i.Position) end
	end)
	local c2 = UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then mode = nil end
	end)
	root.Destroying:Connect(function() c1:Disconnect(); c2:Disconnect() end)

	for _, bx in ipairs(boxes) do
		bx.FocusLost:Connect(function()
			local r = math.clamp(tonumber(boxes[1].Text) or 0, 0, 255)
			local g = math.clamp(tonumber(boxes[2].Text) or 0, 0, 255)
			local b = math.clamp(tonumber(boxes[3].Text) or 0, 0, 255)
			h, s, v = Color3.fromRGB(r, g, b):ToHSV()
			render()
		end)
	end
	hex.FocusLost:Connect(function()
		local ok, c = pcall(Color3.fromHex, (hex.Text:gsub("#", "")))
		if ok then h, s, v = c:ToHSV() end
		render()
	end)
	quiet = true; render(); quiet = false
	Kit.toScale(root)
	return root
end

-- White tooltip with a pointer (pointer = "down" | "up").
function Kit.tooltip(text, width, pointer, red)
	local bg = red and C.badge or C.white
	local tip = new("Frame", { Name = "Tooltip", Size = UDim2.fromOffset(width, 40), BackgroundColor3 = bg }, { Kit.corner(6) })
	Kit.label({ Text = text, TextColor3 = red and C.white or C.textDark, FontFace = F.bold, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = tip })
	local tri = new("Frame", {
		Name = "Pointer", AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45, Size = UDim2.fromOffset(14, 14), BackgroundColor3 = bg, BorderSizePixel = 0,
		Position = (pointer == "up" and UDim2.new(0.5, 0, 0, 0)) or (pointer == "left" and UDim2.new(0, 0, 0.5, 0)) or UDim2.new(0.5, 0, 1, 0), ZIndex = 0, Parent = tip,
	})
	return tip
end

-- Panel open/close motion (UIScale + fade of a CanvasGroup-free tree: we fade via GroupTransparency when available).
-- RIVALS' loading dots (ported from the replica): three white dots pulsing in turn, centred on the canvas.
-- Menus that load a lot open behind these until everything is in (standing rule).
function Kit.loadingDots(parent)
	local holder = new("Frame", { Name = "LoadingDots", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(950 / 1920, 569 / 1080), Size = UDim2.fromScale(230 / 1920, 70 / 1080),
		BackgroundTransparency = 1, ZIndex = 50, Parent = parent })
	local dots = {}
	for d = 1, 3 do
		local dot = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5 + (d - 2) * 0.3, 0.5), Size = UDim2.fromScale(1, 64 / 70),
			BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 50, Parent = holder },
			{ new("UICorner", { CornerRadius = UDim.new(0.5, 0) }), new("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Height }) })
		dots[d] = new("UIScale", { Scale = 0.7, Parent = dot })
	end
	local conn
	conn = game:GetService("RunService").RenderStepped:Connect(function()
		if not holder.Parent then conn:Disconnect(); return end
		if not holder.Visible then return end
		local PERIOD, STEP, PULSE = 1.15, 0.1, 0.3
		local t = os.clock() % PERIOD
		for i, sc in ipairs(dots) do
			local u = (t - (i - 1) * STEP) / PULSE
			sc.Scale = 0.7 + 0.3 * ((u > 0 and u < 1) and math.sin(u * math.pi) or 0)
		end
	end)
	return holder
end

-------------------------------------------------------------------------------
-- (2026-10-21, RIVALS three-qualities pass) shared motion helpers: every screen uses these instead of its own copies.
-- They only move / scale / recolour things already built; they never change a screen's look.
-------------------------------------------------------------------------------
-- Roblox honours only ONE UIScale per object, so the motion helpers share whichever UIScale the object already has
-- (bindButton's, Kit.open's MotionScale) instead of adding a second one that would be ignored
local function motionScale(g: GuiObject, name: string)
	return g:FindFirstChildOfClass("UIScale") or new("UIScale", { Name = name, Parent = g })
end

-- count a TextLabel's number from `from` to `to` (fmt(n) -> text; default commas); returns at once
function Kit.countTo(label: TextLabel, from: number, to: number, dur: number?, fmt: ((number) -> string)?)
	fmt = fmt or function(n)
		local s = tostring(math.floor(n + 0.5))
		while true do local k; s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2"); if k == 0 then break end end
		return s
	end
	dur = dur or 0.5
	local token = (label:GetAttribute("_CountToken") or 0) + 1
	label:SetAttribute("_CountToken", token)
	if from == to or dur <= 0 then label.Text = fmt(to) return end
	task.spawn(function()
		local t0 = os.clock()
		while label.Parent and label:GetAttribute("_CountToken") == token do
			local u = math.clamp((os.clock() - t0) / dur, 0, 1)
			local e = 1 - (1 - u) ^ 3
			label.Text = fmt(from + (to - from) * e)
			if u >= 1 then break end
			task.wait()
		end
	end)
end

-- tween a bar's fill width to frac (0..1) of its parent, keeping its height
function Kit.fillTo(fill: GuiObject, frac: number, dur: number?)
	local h = fill.Size.Y
	return Kit.tween(fill, dur or 0.45, { Size = UDim2.new(math.clamp(frac, 0, 1), 0, h.Scale, h.Offset) }, Enum.EasingStyle.Quart)
end

-- a quick punch: grow to `amount` and settle back (a value changed, a check landed)
function Kit.pop(g: GuiObject, amount: number?)
	local s = motionScale(g, "PopScale")
	s.Scale = amount or 1.18
	Kit.tween(s, 0.28, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- appear: scale up from 0.85 with a little overshoot after `delay` (stagger lists with i * 0.04)
function Kit.popIn(g: GuiObject, delay: number?)
	local s = motionScale(g, "PopScale")
	s.Scale = 0.85
	if g:IsA("CanvasGroup") then g.GroupTransparency = 1 end
	task.delay(delay or 0, function()
		if not g.Parent then return end
		Kit.tween(s, 0.24, { Scale = 1 }, Enum.EasingStyle.Back)
		if g:IsA("CanvasGroup") then Kit.tween(g, 0.18, { GroupTransparency = 0 }) end
	end)
end

-- a slow scale breathe (something is ready / wants a tap); returns stop()
function Kit.breathe(g: GuiObject, amount: number?, period: number?)
	local s = motionScale(g, "BreatheScale")
	local amp, per, alive = amount or 0.04, period or 1.4, true
	task.spawn(function()
		while alive and g.Parent do
			s.Scale = 1 + amp * math.sin(os.clock() / per * math.pi * 2)
			task.wait()
		end
		if s.Parent then s.Scale = 1 end
	end)
	return function() alive = false end
end

-- one beat of a pulse (a timer's last seconds); optional colour flash on a TextLabel
function Kit.pulse(g: GuiObject, flash: Color3?)
	Kit.pop(g, 1.12)
	if flash and g:IsA("TextLabel") then
		local base = g.TextColor3
		g.TextColor3 = flash
		Kit.tween(g, 0.4, { TextColor3 = base })
	end
end

-- a short horizontal shake (wrong input, can't afford)
function Kit.shake(g: GuiObject)
	local base = g.Position
	task.spawn(function()
		for i = 1, 6 do
			g.Position = base + UDim2.fromScale((i % 2 == 0 and 1 or -1) * 0.006 * (1 - i / 7), 0)
			task.wait(0.03)
		end
		g.Position = base
	end)
end

-- a button waiting on the server: its words hide and three dots bob inside it; returns stop()
function Kit.busy(btn: GuiObject)
	local hidden = {}
	for _, d in btn:GetDescendants() do
		if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.TextTransparency < 1 then hidden[d] = d.TextTransparency; d.TextTransparency = 1 end
	end
	if btn:IsA("TextButton") and btn.Text ~= "" then hidden[btn] = btn.TextTransparency; btn.TextTransparency = 1 end
	local holder = new("Frame", { Name = "Busy", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = (btn.ZIndex or 1) + 5, Parent = btn })
	local dots = {}
	for i = 1, 3 do
		dots[i] = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5 + (i - 2) * 0.12, 0.5), Size = UDim2.fromScale(0.3, 0.3),
			BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = holder.ZIndex, Parent = holder },
			{ new("UICorner", { CornerRadius = UDim.new(0.5, 0) }), new("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Height }) })
	end
	local alive = true
	task.spawn(function()
		while alive and holder.Parent do
			local t = os.clock()
			for i, d in dots do d.Position = UDim2.fromScale(0.5 + (i - 2) * 0.12, 0.5 - 0.12 * math.max(0, math.sin(t * 6 - i * 0.9))) end
			task.wait()
		end
	end)
	return function()
		alive = false
		holder:Destroy()
		for d, tr in hidden do if d.Parent then d.TextTransparency = tr end end
	end
end

function Kit.open(frame)
	Kit.sfx("open")
	Kit.centreAnchor(frame) -- scale from the centre
	local s = frame:FindFirstChild("MotionScale") or new("UIScale", { Name = "MotionScale", Parent = frame })
	frame:SetAttribute("_MotionToken", (frame:GetAttribute("_MotionToken") or 0) + 1) -- (cancels a pending close's hide)
	frame.Visible = true
	s.Scale = 0.9
	Kit.tween(s, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
	if frame:IsA("CanvasGroup") then frame.GroupTransparency = 1; Kit.tween(frame, 0.18, { GroupTransparency = 0 }) end
end
function Kit.close(frame, done)
	Kit.sfx("close")
	local s = frame:FindFirstChild("MotionScale") or new("UIScale", { Name = "MotionScale", Parent = frame })
	Kit.tween(s, 0.12, { Scale = 0.92 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local tw = frame:IsA("CanvasGroup") and Kit.tween(frame, 0.12, { GroupTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local token = (frame:GetAttribute("_MotionToken") or 0) + 1
	frame:SetAttribute("_MotionToken", token)
	-- (2026-10-21) an open() straight after this close wins: only hide if nothing re-opened it meanwhile
	task.delay(0.12, function() if frame:GetAttribute("_MotionToken") == token then frame.Visible = false end; if done then done() end end)
	return tw
end

-- (2026-10-18, live RIVALS party checks with Edward) the party leader's gold crown, drawn in Scale inside `parent`
-- (three points on a band). size / position are Scale of the parent; it keeps a 1.3 : 1 shape.
function Kit.crown(parent, pos, size, z)
	local GOLD, EDGE = Color3.fromRGB(255, 204, 48), Color3.fromRGB(150, 100, 10)
	local c = new("Frame", { Name = "Crown", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = size, Rotation = 18,
		ZIndex = z or 6, Parent = parent }, { new("UIAspectRatioConstraint", { AspectRatio = 1.3 }) })
	new("Frame", { BackgroundColor3 = GOLD, BorderSizePixel = 0, Position = UDim2.fromScale(0.08, 0.56), Size = UDim2.fromScale(0.84, 0.36), ZIndex = (z or 6) + 1, Parent = c },
		{ new("UICorner", { CornerRadius = UDim.new(0.2, 0) }), new("UIStroke", { Color = EDGE, Thickness = 1, Transparency = 0.3 }) })
	for _, x in { 0.18, 0.5, 0.82 } do
		new("Frame", { BackgroundColor3 = GOLD, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, 0.5), Size = UDim2.fromScale(0.26, 0.34),
			Rotation = 45, ZIndex = z or 6, Parent = c }, { new("UIStroke", { Color = EDGE, Thickness = 1, Transparency = 0.3 }) })
	end
	return c
end

-- RIVALS' "Whoops!" box: a black card in the middle of the screen, the reason, and the red X to close it.
-- Kit.whoops("Only the party leader can join a queue!")
local whoopsGui
function Kit.whoops(message)
	local pg = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
	if whoopsGui then whoopsGui:Destroy() end
	whoopsGui = new("ScreenGui", { Name = "Whoops", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 60, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = pg })
	local dim = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1), Parent = whoopsGui })
	dim:AddTag("Nonapplicable")
	local canvas = Kit.canvas(whoopsGui)
	local root = new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = canvas })
	local card = new("Frame", { Name = "Card", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.05, Position = UDim2.fromOffset(700, 368),
		Size = UDim2.fromOffset(520, 344), Parent = root }, { Kit.corner(6) })
	Kit.label({ Text = "Whoops!", FontFace = F.display or F.bold, TextSize = 50, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 14),
		Size = UDim2.fromOffset(520, 64), Parent = card })
	Kit.label({ Text = message, FontFace = F.bold, TextSize = 34, TextWrapped = true, TextColor3 = Color3.fromRGB(200, 200, 204), TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(40, 96), Size = UDim2.fromOffset(440, 130), Parent = card })
	local x = Kit.closeButton(UDim2.fromOffset(140, 64))
	x.Position = UDim2.fromOffset(228, 252) -- (square X since the lobby revamp: centred)
	x.Parent = card
	Kit.toScale(root)
	local pop = new("UIScale", { Scale = 0.85, Parent = card })
	TweenService:Create(pop, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	local function close() if whoopsGui then whoopsGui:Destroy(); whoopsGui = nil end end
	x.Activated:Connect(close)
	dim.Activated:Connect(close)
	if Kit.sfx then pcall(Kit.sfx, "close") end
end


-- (2026-10-18, Edward: "vector silhouettes" like RIVALS, not 3D viewmodels) white silhouette icons (ui/art/icons by codex,
-- Gunsy Funsy uploads); tint them with ImageColor3
Kit.ICONS = { bell = "rbxassetid://93058069459479", check = "rbxassetid://134680054948193", elims = "rbxassetid://87495411854172", inbox = "rbxassetid://106780166776464", level = "rbxassetid://122349404580689", news = "rbxassetid://98784760577764", play = "rbxassetid://112398761342835", rank = "rbxassetid://127088807913977", scissors = "rbxassetid://124651407398623", settings = "rbxassetid://77423905055797", streak = "rbxassetid://89001729086571", trophy = "rbxassetid://112797256867777" }

-- the win-streak badge: an orange flame with the streak number over it (RIVALS, next to names). Scale inside `parent`.
-- (2026-10-20, Edward: the old flame "looks flat and bland in comp to rivals") a full-colour codex flame (ui/art/streak/streak_v2):
-- shown in its own colours (no tint). Empty until it's uploaded under the group: the old tinted silhouette meanwhile.
-- (2026-10-21, art batch 1: flat cream line icons, Gunsy Funsy uploads; image ids read from the decals in Studio)
Kit.ICONS.gadget = "rbxassetid://122224655406431"
Kit.ICONS.melee = "rbxassetid://81713790092609"
Kit.ICONS.cover = "rbxassetid://94141250592215"
Kit.ICONS.matches = "rbxassetid://125681613105062"
Kit.ICONS.scissorsFlat = "rbxassetid://117873069678184"
Kit.ICONS.lock = "rbxassetid://124085037377046"
Kit.ICONS.eye = "rbxassetid://139964028443214"
Kit.ICONS.live = "rbxassetid://85639052729616"
Kit.ICONS.thumbsup = "rbxassetid://133746546608841"
Kit.ICONS.lbStreak = "rbxassetid://139831914155940"
Kit.ICONS.lbElims = "rbxassetid://83789042758416"
Kit.ICONS.lbWins = "rbxassetid://120316362189428"
Kit.ICONS.lbLevel = "rbxassetid://81711657935672"
Kit.ICONS.streakColor = "rbxassetid://99079058513557" -- tac_streak_color (Gunsy Funsy upload 2026-10-20)
-- (2026-10-20, Edward: "look at their levels lets get unique") our level badge: a tactical hex shield in five tiers (codex,
-- ui/art/level). Kit.levelTier(level) -> image, the number's edge colour
Kit.LEVEL_TIERS = {
	{ min = 200, img = "rbxassetid://114661007103309", edge = Color3.fromRGB(148, 98, 16) },  -- gold
	{ min = 100, img = "rbxassetid://85417993163392", edge = Color3.fromRGB(21, 68, 148) },   -- blue
	{ min = 50, img = "rbxassetid://140385134180578", edge = Color3.fromRGB(58, 74, 38) },    -- olive
	{ min = 25, img = "rbxassetid://71445899871171", edge = Color3.fromRGB(122, 94, 52) },    -- tan
	{ min = 0, img = "rbxassetid://138983138877521", edge = Color3.fromRGB(74, 85, 99) },     -- steel
}
function Kit.levelTier(level)
	level = tonumber(level) or 1
	for _, t in Kit.LEVEL_TIERS do if level >= t.min then return t.img, t.edge end end
	return Kit.LEVEL_TIERS[#Kit.LEVEL_TIERS].img, Kit.LEVEL_TIERS[#Kit.LEVEL_TIERS].edge
end
function Kit.streakImage()
	local full = Kit.ICONS.streakColor ~= nil and Kit.ICONS.streakColor ~= ""
	return full and Kit.ICONS.streakColor or Kit.ICONS.streak, full and Color3.new(1, 1, 1) or Color3.fromRGB(255, 140, 40)
end
function Kit.streak(parent, n, pos, size, z)
	local img, tint = Kit.streakImage()
	local f = new("ImageLabel", { Name = "Streak", BackgroundTransparency = 1, Image = img, ImageColor3 = tint,
		ScaleType = Enum.ScaleType.Fit, Position = pos or UDim2.fromScale(0, 0), Size = size or UDim2.fromScale(1, 1), ZIndex = z or 3, Parent = parent },
		{ new("UIAspectRatioConstraint", { AspectRatio = 1 }) })
	local l = new("TextLabel", { Name = "N", BackgroundTransparency = 1, Text = tostring(n or 0), FontFace = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold), -- (2026-10-21: no Builder Sans)
		TextScaled = true, TextColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.64), Size = UDim2.fromScale(0.7, 0.5),
		ZIndex = (z or 3) + 1, Parent = f })
	new("UIStroke", { Thickness = 2.5, Transparency = 0, Color = Color3.fromRGB(240, 70, 30), Parent = l }) -- (2026-10-20) RIVALS: a thick orange-red edge on the number
	-- (Edward: "white number also has his gradient") white at the top easing to a warm cream at the bottom
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(255, 222, 196)), Parent = l })
	return f
end

return Kit
