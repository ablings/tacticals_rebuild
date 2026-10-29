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
local OSWALD = Font.new("rbxassetid://12187365977", Enum.FontWeight.Bold)
local RUBIK = Font.new("rbxassetid://12187365977", Enum.FontWeight.Medium)
local DELAY = 0.35
local MAX_W = 280

local gui, bubble, scale, titleL, bodyL
local owner, token = nil, 0
local enabledFn = function() return true end

-- (2026-10-29, UI survey fixes 3 + 4) a plain cream bubble: the 4 px tan "Lip" under it is gone (UI Corrections 2026-10-22: no
-- lips or accent bars), and it is Scale only: text sizes, padding and the bubble box come from the screen height (1080 design px)
-- each frame, the box and both lines are written as Scale (was AutomaticSize + Offset padding / position).
local PAD_X, PAD_T, PAD_B, GAP = 12, 8, 9, 3 -- design px

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
	bubble.Size = UDim2.fromScale(0, 0)
	bubble.BackgroundColor3 = CREAM
	bubble.BorderSizePixel = 0
	bubble.ZIndex = 10
	bubble.Parent = gui
	scale = Instance.new("UIScale") scale.Parent = bubble

	local function text(order, font, color)
		local t = Instance.new("TextLabel")
		t.Name = order == 1 and "Title" or "Body"
		t.BackgroundTransparency = 1
		t.FontFace = font
		t.TextColor3 = color
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.TextWrapped = true
		t.AutomaticSize = Enum.AutomaticSize.XY
		t.Size = UDim2.fromScale(0, 0)
		t.ZIndex = 11
		Instance.new("UISizeConstraint").Parent = t
		t.Parent = bubble
		return t
	end
	titleL = text(1, OSWALD, INK)
	bodyL = text(2, RUBIK, INK)

	-- lays the bubble out for this screen; returns its size in screen px (before the pop scale)
	local function layout(view)
		local f = view.Y / 1080
		titleL.TextSize = math.max(9, math.floor(19 * f + 0.5))
		bodyL.TextSize = math.max(9, math.floor(15 * f + 0.5))
		for _, t in { titleL, bodyL } do t:FindFirstChildOfClass("UISizeConstraint").MaxSize = Vector2.new((MAX_W - 28) * f, 400 * f) end
		local k = math.max(scale.Scale, 0.01) -- AbsoluteSize includes the pop's UIScale: measure at rest size
		local ts = titleL.Visible and titleL.AbsoluteSize / k or Vector2.zero
		local bs = bodyL.Visible and bodyL.AbsoluteSize / k or Vector2.zero
		local gap = (ts.Y > 0 and bs.Y > 0) and GAP * f or 0
		local w = math.max(ts.X, bs.X) + 2 * PAD_X * f
		local h = PAD_T * f + ts.Y + gap + bs.Y + PAD_B * f
		bubble.Size = UDim2.fromScale(w / view.X, h / view.Y)
		titleL.Position = UDim2.fromScale(PAD_X * f / w, PAD_T * f / h)
		bodyL.Position = UDim2.fromScale(PAD_X * f / w, (PAD_T * f + ts.Y + gap) / h)
		return Vector2.new(w, h) * k
	end

	RunService.RenderStepped:Connect(function()
		if not bubble.Visible then return end
		if not owner or not owner.Parent or not owner.Visible then Tooltip.Hide() return end
		local m = UserInputService:GetMouseLocation()
		-- (2026-10-21) MouseLeave doesn't always fire (a jump onto another button left PLAY's bubble up beside the nav bubble):
		-- hide as soon as the pointer is off the owner
		-- (AbsolutePosition is always measured below the top bar, IgnoreGuiInset or not; GetMouseLocation is the whole screen)
		local op, osz = owner.AbsolutePosition + GuiService:GetGuiInset(), owner.AbsoluteSize
		if m.X < op.X or m.Y < op.Y or m.X > op.X + osz.X or m.Y > op.Y + osz.Y then Tooltip.Hide() return end
		-- (menus e4, grader A) a menu opened over the owner (Invite -> the party screen) hides its bubble: the top object under
		-- the pointer belongs to a gui drawn above the owner's
		local hit = gui.Parent and gui.Parent:GetGuiObjectsAtPosition(m.X, m.Y - GuiService:GetGuiInset().Y)[1]
		if hit and hit ~= owner and not hit:IsDescendantOf(owner) then
			local hg, og = hit:FindFirstAncestorWhichIsA("LayerCollector"), owner:FindFirstAncestorWhichIsA("LayerCollector")
			if hg and og and hg ~= og and hg:IsA("ScreenGui") and og:IsA("ScreenGui") and hg.DisplayOrder > og.DisplayOrder then Tooltip.Hide() return end
		end
		local view = gui.AbsoluteSize
		if view.X < 1 or view.Y < 1 then return end
		local size = layout(view)
		local f = view.Y / 1080
		local x, y = m.X + 18 * f, m.Y + 14 * f
		if x + size.X > view.X - 8 * f then x = m.X - size.X - 14 * f end
		if y + size.Y > view.Y - 8 * f then y = m.Y - size.Y - 10 * f end
		bubble.Position = UDim2.fromScale(x / view.X, y / view.Y)
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
