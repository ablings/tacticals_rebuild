-- Toast: RIVALS' notification pill (top centre, dark, rounded): left icon, bold title + grey line, an
-- optional reward icon with xN on the right. Slides down, holds ~3 s, fades. One at a time; a new one
-- replaces the old. Used for login rewards, Season Pass claims, ad rewards, level ups, contracts.
-- Toast.show({ title = "Login Reward", text = "You've earned x10 Keys!", icon = id | "check", reward = id, count = 10 })
-- Built in its own ScreenGui (above every menu) and straight in Scale (UI rule).
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIKit = script.Parent
local Theme = require(UIKit:WaitForChild("Theme"))
local Assets = require(UIKit:WaitForChild("Assets"))

local Toast = {}
local RUBIK = "rbxassetid://12187365977"
local FB = Font.new(RUBIK, Enum.FontWeight.Bold)
local FM = Font.new(RUBIK, Enum.FontWeight.Medium)
local gui, current

local function make(class, props, kids)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	for _, k in ipairs(kids or {}) do k.Parent = o end
	return o
end
local function tween(o, t, goal, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end
local function screen()
	if gui and gui.Parent then return gui end
	gui = make("ScreenGui", { Name = "PracticeUI_Toast", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 50, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui") })
	-- a 16:9 canvas so the pill keeps its proportions (same as Kit.canvas)
	make("Frame", { Name = "Canvas", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), Parent = gui },
		{ make("UIAspectRatioConstraint", { AspectRatio = 16 / 9 }) })
	return gui
end
local function icon(name)
	if type(name) == "string" and name:find("rbxasset") then return name end
	for _, key in ipairs({ "shop", "items", "pass", "more", "hud", "hud3d", "tasks", "play" }) do
		local set = Assets[key]
		if set and set[name] then return set[name] end
	end
	return ""
end

function Toast.show(opt)
	local canvas = screen().Canvas
	if current then current:Destroy() end
	-- design px (1920 x 1080): pill 600 x 76 at the top centre, y 40
	local W, H = 600, 76
	local pill = make("Frame", { Name = "Toast", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 20 / 1080), Size = UDim2.fromScale(W / 1920, H / 1080),
		BackgroundColor3 = Color3.fromRGB(14, 13, 18), BackgroundTransparency = 0.08, Parent = canvas },
		{ make("UICorner", { CornerRadius = UDim.new(0.5, 0) }), make("UIStroke", { Color = Color3.fromRGB(60, 58, 66), Thickness = 1.5, Transparency = 0.3 }) })
	current = pill
	local function sx(x) return x / W end
	local function sy(y) return y / H end
	local ic = make("ImageLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(sx(46), 0.5), Size = UDim2.fromScale(sx(46), sy(46)), Parent = pill })
	if opt.icon == "check" then
		ic.Image = icon("check")
		ic.ImageColor3 = Theme.hex("#4BD12A")
	else
		ic.Image = icon(opt.icon or "notepad")
	end
	local scale = workspace.CurrentCamera.ViewportSize.Y / 1080
	local title = make("TextLabel", { BackgroundTransparency = 1, Text = opt.title or "", FontFace = FB, TextSize = 30 * scale, TextColor3 = Color3.new(1, 1, 1),
		Position = UDim2.fromScale(sx(90), sy(6)), Size = UDim2.fromScale(sx(420), sy(36)), Parent = pill })
	local sub = make("TextLabel", { BackgroundTransparency = 1, Text = opt.text or "", FontFace = FM, TextSize = 21 * scale, TextColor3 = Theme.hex("#B4B0BA"),
		Position = UDim2.fromScale(sx(90), sy(40)), Size = UDim2.fromScale(sx(420), sy(28)), Parent = pill })
	local rewardImg, countLbl
	if opt.reward then
		rewardImg = make("ImageLabel", { BackgroundTransparency = 1, Image = icon(opt.reward), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(sx(556), sy(32)), Size = UDim2.fromScale(sx(46), sy(46)), Parent = pill })
		if opt.count then
			countLbl = make("TextLabel", { BackgroundTransparency = 1, Text = "×" .. opt.count, FontFace = FB, TextSize = 20 * scale, TextColor3 = Color3.new(1, 1, 1),
				AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(sx(556), sy(44)), Size = UDim2.fromScale(sx(60), sy(24)), ZIndex = 2, Parent = pill },
				{ make("UIStroke", { Thickness = 1.5, Transparency = 0.3 }) })
		end
	end
	-- in: drop from above; hold; out: fade
	pill.Position = UDim2.fromScale(0.5, -60 / 1080)
	tween(pill, 0.25, { Position = UDim2.fromScale(0.5, 20 / 1080) }, Enum.EasingStyle.Back)
	task.delay(opt.time or 3, function()
		if current ~= pill then return end
		tween(pill, 0.3, { BackgroundTransparency = 1 })
		for _, o in ipairs({ title, sub, countLbl }) do tween(o, 0.3, { TextTransparency = 1 }) end
		for _, o in ipairs({ ic, rewardImg }) do tween(o, 0.3, { ImageTransparency = 1 }) end
		pill:FindFirstChildOfClass("UIStroke").Transparency = 1
		task.delay(0.3, function() if current == pill then pill:Destroy(); current = nil end end)
	end)
	return pill
end

return Toast
