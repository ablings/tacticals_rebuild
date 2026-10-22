-- LobbyUIController/Tooltip (ModuleScript)
-- Hover bubbles: point at something for a moment and a small bubble explains it, following the
-- cursor. Tooltip.Attach(obj, title, body) on any GuiObject; turned off by Settings > Tooltips.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Tooltip = {}
-- (2026-10-21, AI-tells + RIVALS) RIVALS' hover bubble: a light pill with dark words (t0024), the same cream bubble as the Kit.
-- Was a dark glass card with a 1.5 px border, round corners and an amber bar down the left edge (all three AI-UI tells).
local CREAM, TAN, INK = Color3.fromRGB(236, 232, 218), Color3.fromRGB(176, 164, 132), Color3.fromRGB(20, 22, 18)
local OSWALD = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
local RUBIK = Font.new("rbxassetid://12187365977", Enum.FontWeight.Medium)
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
	bubble.BackgroundColor3 = CREAM
	bubble.BorderSizePixel = 0
	bubble.ZIndex = 10
	bubble.Parent = gui
	scale = Instance.new("UIScale") scale.Parent = bubble

	-- a darker lip under the pill instead of a border
	accent = Instance.new("Frame")
	accent.Name = "Lip"
	accent.BackgroundColor3 = TAN
	accent.BorderSizePixel = 0
	accent.Position = UDim2.new(0, 0, 1, 0)
	accent.Size = UDim2.new(1, 0, 0, 4)
	accent.ZIndex = 9
	accent.Parent = bubble

	-- title + body stack
	local content = Instance.new("Frame")
	content.BackgroundTransparency = 1
	content.AutomaticSize = Enum.AutomaticSize.XY
	content.Size = UDim2.fromOffset(0, 0)
	content.ZIndex = 11
	content.Parent = bubble
	local p = Instance.new("UIPadding")
	p.PaddingLeft, p.PaddingRight, p.PaddingTop, p.PaddingBottom = UDim.new(0, 12), UDim.new(0, 12), UDim.new(0, 8), UDim.new(0, 9)
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
	titleL = text(1, OSWALD, 19, INK)
	bodyL = text(2, RUBIK, 15, INK)

	RunService.RenderStepped:Connect(function()
		if not bubble.Visible then return end
		if not owner or not owner.Parent or not owner.Visible then Tooltip.Hide() return end
		local m = UserInputService:GetMouseLocation()
		-- (2026-10-21) MouseLeave doesn't always fire (a jump onto another button left PLAY's bubble up beside the nav bubble):
		-- hide as soon as the pointer is off the owner
		local sg = owner:FindFirstAncestorWhichIsA("ScreenGui")
		local inset = (sg and sg.IgnoreGuiInset) and Vector2.zero or GuiService:GetGuiInset()
		local op, osz = owner.AbsolutePosition + inset, owner.AbsoluteSize
		if m.X < op.X or m.Y < op.Y or m.X > op.X + osz.X or m.Y > op.Y + osz.Y then Tooltip.Hide() return end
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
