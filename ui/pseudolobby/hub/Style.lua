-- LobbyUIController/Style (ModuleScript)
-- Applies the game's UI look (ReplicatedStorage/Modules/Shared/UITheme) to everything inside a ScreenGui,
-- so the panel code can stay simple and keep using THEME tokens:
--   * THEME.Panel  (big panels)    -> fully transparent: the menu floats over the coloured backdrop
--   * THEME.Panel2 (cards/buttons) -> frosted glass
--   * THEME.Panel3 (selected)      -> brighter glass
--   * THEME.Line borders           -> hidden (thin divider lines become faint white hairlines)
--   * other thin borders (< 3 px)  -> a 3 px state ring; strokes on a see-through frame are glyph lines, left alone
--   * every legacy font            -> the game font (UITheme.Fonts: Oswald / Rubik); no text outlines
--   * rounded corners everywhere, buttons squish when pressed
-- Attribute NoFX = true on a button opts it out of the press effect; NoStyle = true skips an object.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UITheme = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("UITheme"))

local Style = {}
Style.Theme = UITheme
Style.Fonts = {
	Display = UITheme.Fonts.Display,
	Body = UITheme.Fonts.Body,
	BodyBold = UITheme.Fonts.Bold,
}
Style.Accent = UITheme.Colors.Selected

-- The panel code's THEME colours (set by LobbyUIController through Style.SetTokens)
local T = {}
function Style.SetTokens(theme)
	T = theme
end

local FONT_MAP = {
	[Enum.Font.GothamBlack] = { UITheme.Fonts.Display, 1 },
	[Enum.Font.GothamBold] = { UITheme.Fonts.Bold, 1 },
	[Enum.Font.GothamSemibold] = { UITheme.Fonts.Bold, 1 },
	[Enum.Font.GothamMedium] = { UITheme.Fonts.Body, 1 },
	[Enum.Font.Gotham] = { UITheme.Fonts.Body, 1 },
	[Enum.Font.SourceSans] = { UITheme.Fonts.Body, 0.9 },
	[Enum.Font.SourceSansBold] = { UITheme.Fonts.Bold, 0.9 },
	[Enum.Font.SourceSansSemibold] = { UITheme.Fonts.Bold, 0.9 },
	[Enum.Font.BuilderSans] = { UITheme.Fonts.Body, 0.94 },
	[Enum.Font.BuilderSansBold] = { UITheme.Fonts.Bold, 0.94 },
	[Enum.Font.BuilderSansExtraBold] = { UITheme.Fonts.Display, 0.94 },
}

local function same(a: Color3, b: Color3?): boolean
	return b ~= nil and math.abs(a.R - b.R) < 0.004 and math.abs(a.G - b.G) < 0.004 and math.abs(a.B - b.B) < 0.004
end

local function luminance(c: Color3): number
	return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
end

local function styleText(t)
	local map = FONT_MAP[t.Font]
	if map then
		t.FontFace = map[1]
		t.TextSize = math.floor(t.TextSize * map[2] + 0.5)
	end
	-- (no outlines on text any more: text sits on dark glass)
end

local function styleSurface(f: GuiObject)
	if f:IsA("ScrollingFrame") then
		f.ScrollBarImageColor3 = Color3.new(1, 1, 1)
		f.ScrollBarImageTransparency = 0.6
	end
	if f:IsA("ImageLabel") or f:IsA("ImageButton") or f:IsA("ViewportFrame") then return end
	local c = f.BackgroundColor3
	local h = f.Size.Y.Scale == 0 and f.Size.Y.Offset or 99
	local hollow = f.BackgroundTransparency >= 1 -- (read before the Panel case clears it)
	if same(c, T.Panel) then
		f.BackgroundTransparency = 1
	elseif same(c, T.Panel2) then
		f.BackgroundColor3 = UITheme.Colors.Glass
		f.BackgroundTransparency = math.max(f.BackgroundTransparency, UITheme.GlassTransparency)
	elseif same(c, T.Panel3) then
		f.BackgroundTransparency = math.max(f.BackgroundTransparency, 0.2)
	elseif same(c, T.Line) and h <= 2 then
		f.BackgroundColor3 = Color3.new(1, 1, 1)
		f.BackgroundTransparency = 0.85
	end
	-- borders: grey ones go, highlight ones stay as a chunky ring
	-- (2026-10-21, AI-tells sweep) highlight borders thinner than 3 px go up to 3 (they were clamped down to 2, a hairline);
	-- NoStyle strokes (Tac's 4 px hover glow) and strokes on a see-through frame (the padlock shackle glyph) are left alone
	for _, s in f:GetChildren() do
		if s:IsA("UIStroke") and s.ApplyStrokeMode == Enum.ApplyStrokeMode.Border and not s:GetAttribute("NoStyle") then
			if same(s.Color, T.Line) or same(c, T.Panel) then
				s.Enabled = false
			elseif not hollow then
				s.Thickness = math.max(s.Thickness, 3)
			end
		end
	end
	-- rounder corners (circles stay circles)
	local corner = f:FindFirstChildOfClass("UICorner")
	if corner and corner.CornerRadius.Scale == 0 then
		local r = corner.CornerRadius.Offset
		local s = f.Size
		local small = s.X.Scale == 0 and s.Y.Scale == 0 and r * 2.2 >= math.min(s.X.Offset, s.Y.Offset)
		if not small and r >= 3 and r < UITheme.Radius then
			corner.CornerRadius = UDim.new(0, h <= 12 and math.floor(h / 2) or UITheme.Radius)
		end
	end
end

-- No more stamped-steel plates: kept so older calls still work
function Style.Chamfer(_obj) end

-------------------------------------------------------------------------------
-- Button feedback: a quick squish, then a soft spring back
-------------------------------------------------------------------------------
local function hookButton(b: GuiButton)
	if b:GetAttribute("NoFX") or b:GetAttribute("FXHooked") then return end
	b:SetAttribute("FXHooked", true)
	local scale = b:FindFirstChildOfClass("UIScale")
	local own = scale == nil
	if own then
		scale = Instance.new("UIScale")
		scale.Name = "_Press"
		scale.Parent = b
	end
	b.MouseButton1Down:Connect(function()
		if own then TweenService:Create(scale, TweenInfo.new(0.07, Enum.EasingStyle.Quad), { Scale = 0.94 }):Play() end
	end)
	local function release()
		if own then TweenService:Create(scale, TweenInfo.new(0.32, Enum.EasingStyle.Back), { Scale = 1 }):Play() end
	end
	b.MouseButton1Up:Connect(release)
	b.MouseLeave:Connect(release)
end

-------------------------------------------------------------------------------
-- Apply to a ScreenGui (existing + future descendants)
-------------------------------------------------------------------------------
local function process(d)
	if d:GetAttribute("NoStyle") then return end
	if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
		task.defer(function() if d.Parent then styleText(d) end end)
	end
	if d:IsA("GuiButton") then hookButton(d) end
	if d:IsA("GuiObject") then
		task.defer(function()
			if d.Parent then styleSurface(d) end
		end)
	end
end

function Style.Apply(gui: ScreenGui)
	for _, d in gui:GetDescendants() do process(d) end
	gui.DescendantAdded:Connect(process)
end

-- Panel open: nothing flashy, the panel just glides in (see LobbyUI.Open)
function Style.Reveal(_panel, _title) end

return Style
