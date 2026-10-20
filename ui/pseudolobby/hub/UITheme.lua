-- ReplicatedStorage/Modules/Shared/UITheme (ModuleScript)
-- One visual language for every screen in the game (lobby + match place keep identical copies).
--
--   * Military skybase HUD: gunmetal panels, olive drab borders, amber signal colour. Layout and
--     button feel follow Rivals (chunky two-tone buttons with dark outlines), recoloured to our theme.
--   * Opening a menu fades in a dark BACKDROP behind it (Colors.Backdrop -> Backdrop2), closing
--     fades it out.
--   * Selected = bone. Play / buy = olive (pass 34: no amber), secondary actions = olive, close = red.
--   * Fonts: Oswald (condensed, stencil-like) for headings and buttons, Gotham SSm for body copy.

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
	Go = Color3.fromRGB(90, 178, 255),         -- blue: play / buy / equip (2026-10-20 palette)
	GoDark = Color3.fromRGB(30, 99, 214),
	Danger = Color3.fromRGB(255, 77, 58),     -- red: close / warnings
	DangerDark = Color3.fromRGB(150, 36, 28),
	Outline = Color3.fromRGB(10, 10, 8),
}
UITheme.GlassTransparency = 0.12 -- how see-through cards are (0 = solid)
UITheme.Radius = 3

local GOTHAM = "rbxasset://fonts/families/GothamSSm.json"
local OSWALD = "rbxasset://fonts/families/Oswald.json"
UITheme.FontFamily = GOTHAM
UITheme.Fonts = {
	Display = Font.new(OSWALD, Enum.FontWeight.Bold),
	Bold = Font.new(GOTHAM, Enum.FontWeight.Bold),
	Body = Font.new(GOTHAM, Enum.FontWeight.Medium),
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
-------------------------------------------------------------------------------
local backdrop, holders = nil, {}
local function getBackdrop()
	if backdrop and backdrop.Parent then return backdrop end
	local gui = Instance.new("ScreenGui")
	gui.Name = "UIBackdrop"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 3 -- under every menu
	local wash = Instance.new("Frame")
	wash.Name = "Wash"
	wash.Size = UDim2.fromScale(1, 1)
	wash.BorderSizePixel = 0
	wash.BackgroundColor3 = Color3.new(1, 1, 1)
	wash.BackgroundTransparency = 1
	wash.Parent = gui
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(UITheme.Colors.Backdrop, UITheme.Colors.Backdrop2)
	g.Parent = wash
	-- darker edges pull the eye to the middle
	local vignette = Instance.new("Frame")
	vignette.Name = "Vignette"
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.BorderSizePixel = 0
	vignette.BackgroundColor3 = Color3.new(0, 0, 0)
	vignette.BackgroundTransparency = 1
	vignette.Parent = gui
	local vg = Instance.new("UIGradient")
	vg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(0.25, 1),
		NumberSequenceKeypoint.new(0.75, 1), NumberSequenceKeypoint.new(1, 0.35),
	})
	vg.Parent = vignette
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
	TweenService:Create(gui.Wash, info, { BackgroundTransparency = 1 - 0.78 * s }):Play()
	TweenService:Create(gui.Vignette, info, { BackgroundTransparency = 1 - 0.6 * s }):Play()
	-- world reacts to menus: soft blur + slightly cooler, darker grade (client-local Lighting effects)
	local Lighting = game:GetService("Lighting")
	local blur = Lighting:FindFirstChild("UIWorldBlur")
	if not blur then blur = Instance.new("BlurEffect"); blur.Name = "UIWorldBlur"; blur.Size = 0; blur.Parent = Lighting end
	local cc = Lighting:FindFirstChild("UIWorldGrade")
	if not cc then cc = Instance.new("ColorCorrectionEffect"); cc.Name = "UIWorldGrade"; cc.Parent = Lighting end
	TweenService:Create(blur, info, { Size = 14 * s }):Play()
	TweenService:Create(cc, info, { Brightness = -0.06 * s, Saturation = -0.25 * s, TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(236, 232, 210), s) }):Play()
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
