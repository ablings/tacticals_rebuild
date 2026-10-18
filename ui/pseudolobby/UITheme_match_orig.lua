-- ReplicatedStorage/Modules/Shared/UITheme (ModuleScript)
-- One visual language for every screen in the game (lobby + match place keep identical copies).
--
--   * Menus float: no big boxes. Text sits straight on the world with a soft dark outline,
--     small cards are frosted glass (dark, see-through, rounded).
--   * Opening a menu fades in a coloured BACKDROP behind it (Colors.Backdrop -> Backdrop2), closing
--     fades it out. Change those two colours to re-tint every menu in the game.
--   * Selected = solid white with dark text. Main actions = blue, buy / play = green, close = red.
--   * Font: Builder Sans everywhere, heavy (extra bold for big names, bold for headings, medium for body
--     copy) with a subtle dark edge on text that sits over the world - the same type as the lobby armory.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UITheme = {}

UITheme.Colors = {
	Backdrop = Color3.fromRGB(6, 7, 9),       -- top of the menu backdrop
	Backdrop2 = Color3.fromRGB(16, 17, 20),   -- bottom of the menu backdrop
	Text = Color3.fromRGB(255, 255, 255),
	Sub = Color3.fromRGB(160, 162, 170),      -- secondary text: neutral grey
	Glass = Color3.fromRGB(16, 17, 20),       -- card fill, drawn see-through
	Line = Color3.fromRGB(255, 255, 255),     -- hairline borders (drawn ~90% see-through)
	Selected = Color3.fromRGB(255, 255, 255),
	SelectedText = Color3.fromRGB(12, 12, 14),
	Primary = Color3.fromRGB(74, 77, 86),     -- main actions: graphite
	PrimaryDark = Color3.fromRGB(48, 50, 57),
	Go = Color3.fromRGB(92, 222, 104),        -- green: buy / play / equip
	GoDark = Color3.fromRGB(38, 162, 64),
	Danger = Color3.fromRGB(255, 70, 86),     -- red: close / warnings
	DangerDark = Color3.fromRGB(200, 30, 52),
	Outline = Color3.fromRGB(0, 0, 0),
}
UITheme.GlassTransparency = 0.2 -- how see-through cards are (0 = solid)
UITheme.Radius = 10

local GOTHAM = "rbxasset://fonts/families/GothamSSm.json"
local BUILDER = "rbxasset://fonts/families/BuilderSans.json"
local FAMILY = BUILDER -- (set to GOTHAM to go back to Gotham SSm)
UITheme.FontFamily = FAMILY
UITheme.Fonts = {
	Display = Font.new(FAMILY, Enum.FontWeight.ExtraBold),
	Bold = Font.new(FAMILY, Enum.FontWeight.Bold),
	Body = Font.new(FAMILY, Enum.FontWeight.Medium),
}

-- Subtle dark edge on light text so it reads on top of anything (no box needed) - the lobby armory's edge:
-- thin, black, about half see-through
function UITheme.Outline(text: GuiObject, thickness: number?, transparency: number?)
	local s = text:FindFirstChild("_Outline")
	if not s then
		s = Instance.new("UIStroke")
		s.Name = "_Outline"
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		s.Parent = text
	end
	s.Color = UITheme.Colors.Outline
	s.Thickness = math.min(thickness or 1.5, 2)
	s.Transparency = math.max(transparency or 0.45, 0.45)
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Enabled = true
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

