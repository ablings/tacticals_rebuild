-- Client/Controllers/PromptsController (ModuleScript, auto-loaded; lobby + match places). UI session 2026-10-17 night (gap audit #12).
-- RIVALS draws its own proximity prompts: a card over the object with a key square on the left and two lines (small object
-- text, big action text) and a little pointer under it. Here in TACTICALS' look: gunmetal card, bone text, an olive edge,
-- the key in a bone square (touch: TAP, gamepad: the button). Hold prompts fill an olive bar along the bottom.
-- Every ProximityPrompt is switched to Style Custom on this client (only the look changes; the server prompt is untouched).
-- Clicking / tapping the card triggers it too (a hold prompt holds while pressed).
-- Billboards are sized in studs (Scale), text is TextScaled inside fixed boxes.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local controller = {}
local player = Players.LocalPlayer

local BUILDER = "rbxasset://fonts/families/BuilderSans.json"
local F_ACTION = Font.new(BUILDER, Enum.FontWeight.ExtraBold)
local F_OBJECT = Font.new(BUILDER, Enum.FontWeight.Medium)
local BONE, FIELD, DEEP, OLIVE = Color3.fromRGB(236, 232, 218), Color3.fromRGB(150, 156, 140), Color3.fromRGB(12, 14, 11), Color3.fromRGB(157, 176, 90)

local function new(class, props, children)
	local o = Instance.new(class)
	for k, v in props do if k ~= "Parent" then o[k] = v end end
	for _, c in children or {} do c.Parent = o end
	if props.Parent then o.Parent = props.Parent end
	return o
end
local function tween(o, t, goal, style)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end

local GAMEPAD_SHORT = { ButtonA = "A", ButtonB = "B", ButtonX = "X", ButtonY = "Y", ButtonL1 = "LB", ButtonR1 = "RB", ButtonL2 = "LT", ButtonR2 = "RT",
	ButtonL3 = "LS", ButtonR3 = "RS", DPadUp = "↑", DPadDown = "↓", DPadLeft = "←", DPadRight = "→" }
local function keyText(prompt, inputType)
	if inputType == Enum.ProximityPromptInputType.Touch then return "TAP" end
	if inputType == Enum.ProximityPromptInputType.Gamepad then
		local n = prompt.GamepadKeyCode.Name
		return GAMEPAD_SHORT[n] or n
	end
	local n = prompt.KeyboardKeyCode.Name
	local short = { LeftShift = "SHFT", LeftControl = "CTRL", Return = "ENT", Space = "SPC", Tab = "TAB" }
	return short[n] or (#n <= 3 and n or n:sub(1, 3))
end

local holder -- a Folder in PlayerGui for the billboards
local shown = {} -- prompt -> { bb, fill, conns }

local function custom(prompt)
	if prompt:IsA("ProximityPrompt") and prompt.Style ~= Enum.ProximityPromptStyle.Custom and prompt:GetAttribute("KeepDefaultStyle") ~= true then
		prompt.Style = Enum.ProximityPromptStyle.Custom
	end
end

local function hide(prompt)
	local s = shown[prompt]
	if not s then return end
	shown[prompt] = nil
	for _, c in s.conns do c:Disconnect() end
	local tw = tween(s.scale, 0.1, { Scale = 0.6 })
	tween(s.group, 0.1, { GroupTransparency = 1 })
	tw.Completed:Once(function() s.bb:Destroy() end)
end

local function show(prompt, inputType)
	hide(prompt)
	local adornee = prompt.Parent
	if not (adornee and (adornee:IsA("BasePart") or adornee:IsA("Attachment") or adornee:IsA("Model"))) then return end
	local wide = #prompt.ActionText > 14 or #prompt.ObjectText > 18
	local W = wide and 11 or 9
	local bb = new("BillboardGui", { Name = "Prompt", Adornee = adornee, AlwaysOnTop = true, LightInfluence = 0, Size = UDim2.fromScale(W, 2.3),
		StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0), MaxDistance = prompt.MaxActivationDistance + 10, Active = true, ResetOnSpawn = false, Parent = holder })
	local group = new("CanvasGroup", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), GroupTransparency = 1, Parent = bb })
	local scale = new("UIScale", { Scale = 0.6, Parent = group })
	local card = new("Frame", { BackgroundColor3 = DEEP, BackgroundTransparency = 0.12, Size = UDim2.fromScale(1, 0.84), Parent = group },
		{ new("UICorner", { CornerRadius = UDim.new(0.16, 0) }), new("UIStroke", { Color = BONE, Transparency = 0.75, Thickness = 1.5 }) })
	-- pointer under the card
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45, Position = UDim2.fromScale(0.5, 0.84), Size = UDim2.fromScale(0.06, 0.2), BackgroundColor3 = DEEP,
		BackgroundTransparency = 0.12, BorderSizePixel = 0, ZIndex = 0, Parent = group }, { new("UIAspectRatioConstraint", { AspectRatio = 1 }) })
	-- olive edge on the left
	new("Frame", { BorderSizePixel = 0, BackgroundColor3 = OLIVE, Position = UDim2.fromScale(0, 0.18), Size = UDim2.fromScale(0.012, 0.64), Parent = card })
	local key = new("Frame", { BackgroundColor3 = BONE, Position = UDim2.fromScale(0.04, 0.14), Size = UDim2.fromScale(0.72, 0.72), SizeConstraint = Enum.SizeConstraint.RelativeYY, Parent = card },
		{ new("UICorner", { CornerRadius = UDim.new(0.18, 0) }) })
	new("TextLabel", { BackgroundTransparency = 1, Text = keyText(prompt, inputType), FontFace = F_ACTION, TextScaled = true, TextColor3 = DEEP,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.74, 0.6), Parent = key })
	local textX = 0.04 + 0.72 * (2.3 * 0.84) / W + 0.04
	new("TextLabel", { BackgroundTransparency = 1, Text = string.upper(prompt.ObjectText), FontFace = F_OBJECT, TextScaled = true, TextColor3 = FIELD,
		TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromScale(textX, 0.12), Size = UDim2.fromScale(0.94 - textX, 0.28), Parent = card })
	new("TextLabel", { BackgroundTransparency = 1, Text = prompt.ActionText, FontFace = F_ACTION, TextScaled = true, TextColor3 = BONE,
		TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromScale(textX, 0.4), Size = UDim2.fromScale(0.94 - textX, 0.46), Parent = card })
	-- hold progress along the bottom edge
	local track = new("Frame", { BorderSizePixel = 0, BackgroundColor3 = BONE, BackgroundTransparency = 0.85, Position = UDim2.fromScale(0.06, 0.9), Size = UDim2.fromScale(0.88, 0.05),
		Visible = prompt.HoldDuration > 0, Parent = card }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local fill = new("Frame", { BorderSizePixel = 0, BackgroundColor3 = OLIVE, Size = UDim2.fromScale(0, 1), Parent = track }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	-- click / tap the card: same as the key (held while pressed)
	local hit = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = group })
	local conns = {}
	table.insert(conns, hit.MouseButton1Down:Connect(function() prompt:InputHoldBegin() end))
	table.insert(conns, hit.MouseButton1Up:Connect(function() prompt:InputHoldEnd() end))
	table.insert(conns, hit.MouseLeave:Connect(function() prompt:InputHoldEnd() end))
	local holdTween
	table.insert(conns, prompt.PromptButtonHoldBegan:Connect(function()
		if prompt.HoldDuration > 0 then
			fill.Size = UDim2.fromScale(0, 1)
			holdTween = tween(fill, prompt.HoldDuration, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Linear)
		end
		tween(scale, 0.08, { Scale = 0.94 })
	end))
	table.insert(conns, prompt.PromptButtonHoldEnded:Connect(function()
		if holdTween then holdTween:Cancel(); holdTween = nil end
		tween(fill, 0.12, { Size = UDim2.fromScale(0, 1) })
		tween(scale, 0.12, { Scale = 1 }, Enum.EasingStyle.Back)
	end))
	table.insert(conns, prompt.Triggered:Connect(function()
		scale.Scale = 1.08
		tween(scale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
	end))
	shown[prompt] = { bb = bb, group = group, scale = scale, fill = fill, conns = conns }
	tween(scale, 0.16, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(group, 0.12, { GroupTransparency = 0 })
end

function controller.Start()
	holder = Instance.new("Folder")
	holder.Name = "TacticalsPrompts"
	holder.Parent = player:WaitForChild("PlayerGui")
	for _, d in workspace:GetDescendants() do custom(d) end
	workspace.DescendantAdded:Connect(custom)
	ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
		if prompt.Style == Enum.ProximityPromptStyle.Custom and prompt:GetAttribute("KeepDefaultStyle") ~= true then show(prompt, inputType) end
	end)
	ProximityPromptService.PromptHidden:Connect(hide)
end

return controller
