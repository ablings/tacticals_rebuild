-- LobbyUIController/Tooltip (ModuleScript)
-- Hover bubbles: point at something for a moment and a small bubble explains it, following the
-- cursor. Tooltip.Attach(obj, title, body) on any GuiObject; turned off by Settings > Tooltips.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local UITheme = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("UITheme"))
local UC = UITheme.Colors

local Tooltip = {}
local DELAY = 0.35
local MAX_W = 280

local gui, bubble, scale, accent, titleL, bodyL, tail
local owner, token = nil, 0
local enabledFn = function() return true end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "Tooltips"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 200
	gui:SetAttribute("NoStyle", true)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	bubble = Instance.new("Frame")
	bubble.Name = "Bubble"
	bubble.Visible = false
	bubble.AutomaticSize = Enum.AutomaticSize.XY
	bubble.Size = UDim2.fromOffset(0, 0)
	bubble.BackgroundColor3 = UC.Glass
	bubble.BorderSizePixel = 0
	bubble.ZIndex = 10
	bubble.Parent = gui
	local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = bubble
	local s = Instance.new("UIStroke") s.Color = UC.Line s.Thickness = 1.5 s.Transparency = 0.2 s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border s.Parent = bubble
	scale = Instance.new("UIScale") scale.Parent = bubble

	-- amber bar down the left edge
	accent = Instance.new("Frame")
	accent.BackgroundColor3 = UC.Selected
	accent.BorderSizePixel = 0
	accent.Position = UDim2.new(0, 6, 0, 8)
	accent.Size = UDim2.new(0, 3, 1, -16)
	accent.ZIndex = 11
	accent.Parent = bubble

	-- title + body stack
	local content = Instance.new("Frame")
	content.BackgroundTransparency = 1
	content.AutomaticSize = Enum.AutomaticSize.XY
	content.Size = UDim2.fromOffset(0, 0)
	content.ZIndex = 11
	content.Parent = bubble
	local p = Instance.new("UIPadding")
	p.PaddingLeft, p.PaddingRight, p.PaddingTop, p.PaddingBottom = UDim.new(0, 18), UDim.new(0, 12), UDim.new(0, 9), UDim.new(0, 10)
	p.Parent = content
	local l = Instance.new("UIListLayout") l.Padding = UDim.new(0, 3) l.SortOrder = Enum.SortOrder.LayoutOrder l.Parent = content

	local function text(order, font, size, color)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.FontFace = font
		t.TextSize = size
		t.TextColor3 = color
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.TextWrapped = true
		t.AutomaticSize = Enum.AutomaticSize.XY
		t.Size = UDim2.fromOffset(0, 0)
		t.LayoutOrder = order
		t.ZIndex = 11
		local m = Instance.new("UISizeConstraint") m.MaxSize = Vector2.new(MAX_W - 28, 400) m.Parent = t
		t.Parent = content
		return t
	end
	titleL = text(1, UITheme.Fonts.Display, 17, UC.Selected)
	bodyL = text(2, UITheme.Fonts.Body, 14, UC.Text)

	RunService.RenderStepped:Connect(function()
		if not bubble.Visible then return end
		if not owner or not owner.Parent or not owner.Visible then Tooltip.Hide() return end
		local m = UserInputService:GetMouseLocation()
		local view = gui.AbsoluteSize
		local size = bubble.AbsoluteSize
		local x, y = m.X + 18, m.Y + 14
		if x + size.X > view.X - 8 then x = m.X - size.X - 14 end
		if y + size.Y > view.Y - 8 then y = m.Y - size.Y - 10 end
		bubble.Position = UDim2.fromOffset(x, y)
	end)
end

function Tooltip.Init(isEnabled: (() -> boolean)?)
	if isEnabled then enabledFn = isEnabled end
	if not gui then build() end
end

function Tooltip.Show(obj: GuiObject, title: string?, body: string?)
	if not gui then build() end
	if not enabledFn() then return end
	owner = obj
	titleL.Text = title or ""
	titleL.Visible = title ~= nil and title ~= ""
	bodyL.Text = body or ""
	bodyL.Visible = body ~= nil and body ~= ""
	bubble.Visible = true
	scale.Scale = 0.9
	TweenService:Create(scale, TweenInfo.new(0.14, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

function Tooltip.Hide()
	owner = nil
	token += 1
	if bubble then bubble.Visible = false end
end

-- title/body can be functions so the text is read when the bubble opens
function Tooltip.Attach(obj: GuiObject, title: any, body: any)
	obj.MouseEnter:Connect(function()
		token += 1
		local my = token
		task.delay(DELAY, function()
			if my ~= token or not obj.Parent then return end
			local t = type(title) == "function" and title() or title
			local b = type(body) == "function" and body() or body
			Tooltip.Show(obj, t, b)
		end)
	end)
	obj.MouseLeave:Connect(function()
		if owner == obj or owner == nil then Tooltip.Hide() end
	end)
	obj.Destroying:Connect(function() if owner == obj then Tooltip.Hide() end end)
	return obj
end

return Tooltip
