-- ReplicatedStorage/Modules/Shared/UITheme (ModuleScript)
-- One visual language for every screen in the game (lobby + match place keep identical copies).
--
--   * Military skybase HUD: gunmetal panels, olive drab borders, amber signal colour. Layout and
--     button feel follow Rivals (chunky two-tone buttons with dark outlines), recoloured to our theme.
--   * Opening a menu fades in a dark BACKDROP behind it (RIVALS scrim purple + edge vignette over the blurred world,
--     2026-10-21 port3), closing fades it out.
--   * Selected = bone. Play / buy = olive (pass 34: no amber), secondary actions = olive, close = red.
--   * Fonts: Oswald (condensed, stencil-like) for headings and buttons, Rubik for body copy.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UITheme = {}

UITheme.Colors = {
	Backdrop = Color3.fromRGB(8, 10, 9),      -- top of the menu backdrop
	Backdrop2 = Color3.fromRGB(14, 16, 24),   -- bottom of the menu backdrop
	Text = Color3.fromRGB(255, 255, 255),     -- white (2026-10-20 palette)
	Sub = Color3.fromRGB(195, 199, 212),      -- secondary text
	Glass = Color3.fromRGB(20, 23, 32),       -- charcoal-navy card fill
	Line = Color3.fromRGB(60, 66, 82),      -- borders
	Selected = Color3.fromRGB(255, 212, 0),  -- the accent
	SelectedText = Color3.fromRGB(17, 17, 20),
	Primary = Color3.fromRGB(43, 49, 66),    -- secondary actions: dark navy
	PrimaryDark = Color3.fromRGB(22, 26, 36),
	Go = Color3.fromRGB(141, 191, 90),         -- field green: play / buy / equip (2026-10-20, Edward)
	GoDark = Color3.fromRGB(76, 122, 46),
	Danger = Color3.fromRGB(255, 77, 58),     -- red: close / warnings
	DangerDark = Color3.fromRGB(150, 36, 28),
	Outline = Color3.fromRGB(10, 10, 8),
}
UITheme.GlassTransparency = 0.12 -- how see-through cards are (0 = solid)
UITheme.Radius = 3

-- (2026-10-21, AI-tells sweep) body / bold copy in Rubik (was Gotham SSm, the "AI-made" font)
local RUBIK = "rbxassetid://12187365977"
local OSWALD = "rbxassetid://12187365977"
UITheme.FontFamily = RUBIK
UITheme.Fonts = {
	Display = Font.new(OSWALD, Enum.FontWeight.Bold),
	Bold = Font.new(RUBIK, Enum.FontWeight.Bold),
	Body = Font.new(RUBIK, Enum.FontWeight.Medium),
}

-- Text outlines are switched off game-wide (text sits on dark glass instead). Kept so older calls
-- still work: it hands back a disabled stroke.
function UITheme.Outline(text: GuiObject, thickness: number?, transparency: number?)
	local s = text:FindFirstChild("_Outline")
	if not s then
		s = Instance.new("UIStroke")
		s.Name = "_Outline"
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		s.Parent = text
	end
	s.Enabled = false
	return s
end

-- Frosted-glass card look
function UITheme.Glass(frame: GuiObject, transparency: number?, radius: number?)
	frame.BackgroundColor3 = UITheme.Colors.Glass
	frame.BackgroundTransparency = transparency or UITheme.GlassTransparency
	frame.BorderSizePixel = 0
	local c = frame:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or UITheme.Radius)
	c.Parent = frame
	return frame
end

-- Vertical two-tone fill for big buttons (top light, bottom dark)
function UITheme.Fill(button: GuiObject, top: Color3, bottom: Color3)
	button.BackgroundColor3 = Color3.new(1, 1, 1)
	button.BackgroundTransparency = 0
	local g = button:FindFirstChild("_Fill") or Instance.new("UIGradient")
	g.Name = "_Fill"
	g.Rotation = 90
	g.Color = ColorSequence.new(top, bottom)
	g.Parent = button
	return g
end

-------------------------------------------------------------------------------
-- Backdrop: one full-screen coloured wash that fades in under open menus
-- (2026-10-21, port3) graders (both): RIVALS darkens the blurred lobby behind every menu hard (to ~20-25 % brightness) with a
-- dark purple tint (UIKit.Rivals.Theme.color.scrim, #140C1C) and darker edges; ours was a light grey blur at ~45 %. Now: a flat
-- scrim-purple wash (0.26 transparent at full strength) + a radial-ish vignette made only of full-screen gradient layers (left/
-- right, top/bottom and both diagonals, all transparent in the middle, so no shape ever shows), over the kept world blur with a
-- darker, cooler grade. Match place has no UIKit.Rivals: falls back to the same hex.
-------------------------------------------------------------------------------
local function rivalsScrim()
	local ok, c = pcall(function()
		local rs = game:GetService("ReplicatedStorage")
		local kit = rs:FindFirstChild("UIKit")
		local r = kit and kit:FindFirstChild("Rivals")
		local t = r and r:FindFirstChild("Theme")
		return t and require(t).color.scrim
	end)
	return (ok and c) or Color3.fromRGB(20, 12, 28) -- #140C1C
end
local WASH_ALPHA = 0.74 -- (2026-10-21, port3) wash opacity at strength 1 (was 0.78 over a grey-navy gradient, read ~45 %)
local VIG_ALPHA = 0.9 -- (2026-10-21, port3) vignette layer opacity at strength 1 (each layer's gradient fades it to 0 inward)
-- (2026-10-21, port3) vignette layers: {rotation, edge transparency}. The straight pair darkens the sides, the diagonals round the
-- corners off, so together they read as one radial falloff.
local VIG_LAYERS = { { 0, 0.15 }, { 90, 0.3 }, { 45, 0.45 }, { -45, 0.45 } }

local backdrop, holders, vigFrames = nil, {}, {}
local function getBackdrop()
	if backdrop and backdrop.Parent then return backdrop end
	local scrim = rivalsScrim()
	local gui = Instance.new("ScreenGui")
	gui.Name = "UIBackdrop"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 3 -- under every menu
	local wash = Instance.new("Frame")
	wash.Name = "Wash"
	wash.Size = UDim2.fromScale(1, 1)
	wash.BorderSizePixel = 0
	wash.BackgroundColor3 = scrim -- (2026-10-21, port3) flat RIVALS scrim purple (was a grey-navy vertical gradient)
	wash.BackgroundTransparency = 1
	wash.Parent = gui
	-- (2026-10-21, port3) edge vignette: near-black purple, clear across the middle 50 % of each axis
	local edge = scrim:Lerp(Color3.new(0, 0, 0), 0.6)
	vigFrames = {}
	for i, spec in VIG_LAYERS do
		local v = Instance.new("Frame")
		v.Name = "Vignette" .. i
		v.Size = UDim2.fromScale(1, 1)
		v.BorderSizePixel = 0
		v.BackgroundColor3 = edge
		v.BackgroundTransparency = 1
		v.ZIndex = 2
		v.Parent = gui
		local e = spec[2]
		local vg = Instance.new("UIGradient")
		vg.Rotation = spec[1]
		vg.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, e), NumberSequenceKeypoint.new(0.1, e + (1 - e) * 0.45),
			NumberSequenceKeypoint.new(0.25, 1), NumberSequenceKeypoint.new(0.75, 1),
			NumberSequenceKeypoint.new(0.9, e + (1 - e) * 0.45), NumberSequenceKeypoint.new(1, e),
		})
		vg.Parent = v
		table.insert(vigFrames, v)
	end
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	backdrop = gui
	return gui
end

-- Show the backdrop for `who` (any key: a menu name). strength 0..1 (1 = full colour).
-- Several menus can hold it at once; it fades out when the last one lets go.
function UITheme.ShowBackdrop(who: string, strength: number?)
	holders[who] = strength or 1
	UITheme._UpdateBackdrop()
end

function UITheme.HideBackdrop(who: string)
	holders[who] = nil
	UITheme._UpdateBackdrop()
end

function UITheme._UpdateBackdrop()
	local gui = getBackdrop()
	local s = 0
	for _, v in holders do s = math.max(s, v) end
	local info = TweenInfo.new(s > 0 and 0.28 or 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui.Wash, info, { BackgroundTransparency = 1 - WASH_ALPHA * s }):Play()
	for _, v in vigFrames do TweenService:Create(v, info, { BackgroundTransparency = 1 - VIG_ALPHA * s }):Play() end
	-- world reacts to menus: blur (kept) + a darker, desaturated, slightly purple grade (client-local Lighting effects)
	local Lighting = game:GetService("Lighting")
	local blur = Lighting:FindFirstChild("UIWorldBlur")
	if not blur then blur = Instance.new("BlurEffect"); blur.Name = "UIWorldBlur"; blur.Size = 0; blur.Parent = Lighting end
	local cc = Lighting:FindFirstChild("UIWorldGrade")
	if not cc then cc = Instance.new("ColorCorrectionEffect"); cc.Name = "UIWorldGrade"; cc.Parent = Lighting end
	TweenService:Create(blur, info, { Size = 14 * s }):Play()
	-- (2026-10-21, port3) grade: brightness -0.06 -> -0.12, tint warm cream -> a cool lilac so the purple wash doesn't turn brown
	TweenService:Create(cc, info, { Brightness = -0.12 * s, Saturation = -0.3 * s, TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(222, 212, 236), s) }):Play()
end

-- Fade a whole menu in / out (CanvasGroup or any GuiObject tree)
function UITheme.FadeIn(obj: GuiObject, fromOffset: UDim2?)
	if obj:IsA("CanvasGroup") then
		obj.GroupTransparency = 1
		TweenService:Create(obj, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { GroupTransparency = 0 }):Play()
	end
	if fromOffset then
		local target = obj.Position
		obj.Position = target + fromOffset
		TweenService:Create(obj, TweenInfo.new(0.32, Enum.EasingStyle.Quint), { Position = target }):Play()
	end
end

return UITheme
