-- Client/Controllers/PromptsController (ModuleScript, auto-loaded; lobby + match places). UI session 2026-10-17 night (gap audit #12).
-- RIVALS draws its own proximity prompts: a card over the object with a key square on the left and two lines (small object
-- text, big action text) and a little pointer under it. (2026-10-21, RIVALS pass) now a bright cream card on a dark offset
-- shadow block, ink text with the action big, the key in an ink square (touch: TAP, gamepad: the button), a small idle bob.
-- Hold prompts fill the field-green bar along the bottom.
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

-- (2026-10-21, RIVALS pass) the game's font decision (Edward): Oswald Bold for the big action word and the key, Rubik for the
-- small object line (was Builder Sans ExtraBold / Medium)
local F_ACTION = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
local F_OBJECT = Font.new("rbxassetid://12187365977", Enum.FontWeight.Medium)
local BONE, FIELD, DEEP, OLIVE = Color3.fromRGB(236, 232, 218), Color3.fromRGB(150, 156, 140), Color3.fromRGB(12, 14, 11), Color3.fromRGB(141, 191, 90)
-- (2026-10-21, AI-tells cleanup) OLIVE = the hold-bar fill: field green #8DBF5A (was comic yellow 255,212,0, low contrast on cream)
-- (2026-10-21, RIVALS pass) the agreed new prompt look: cream card (Theme.color.cream #ECE6D2) with ink text (Theme.color.ink #111114).
-- Literals, not a UIKit require: this module also runs in the match places and must not wait on UIKit.
local CREAM, INK = Color3.fromRGB(236, 230, 210), Color3.fromRGB(17, 17, 20)

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
	-- (2026-10-21, RIVALS pass) bright cream card with one big action word (RIVALS' white prompt, in our cream), dark text.
	-- Chunky look: a solid cream block over a thick dark offset "shadow" block; no rounded corner + hairline stroke and no
	-- left accent bar (Edward: both read as AI-made UI). Pointer hangs under the shadow block.
	new("Frame", { BorderSizePixel = 0, BackgroundColor3 = DEEP, BackgroundTransparency = 0.25, Position = UDim2.fromScale(0.018, 0.1), Size = UDim2.fromScale(1 - 0.018, 0.74), ZIndex = 0, Parent = group })
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45, Position = UDim2.fromScale(0.5, 0.84), Size = UDim2.fromScale(0.06, 0.16), BackgroundColor3 = DEEP,
		BackgroundTransparency = 0.25, BorderSizePixel = 0, ZIndex = 0, Parent = group }, { new("UIAspectRatioConstraint", { AspectRatio = 1 }) })
	local card = new("Frame", { BorderSizePixel = 0, BackgroundColor3 = CREAM, Size = UDim2.fromScale(1 - 0.018, 0.74), Parent = group })
	-- the key / button glyph: an ink square with cream text (keyboard key, gamepad button or TAP)
	local key = new("Frame", { BackgroundColor3 = INK, Position = UDim2.fromScale(0.035, 0.14), Size = UDim2.fromScale(0.72, 0.72), SizeConstraint = Enum.SizeConstraint.RelativeYY, Parent = card },
		{ new("UICorner", { CornerRadius = UDim.new(0.18, 0) }) })
	new("TextLabel", { BackgroundTransparency = 1, Text = keyText(prompt, inputType), FontFace = F_ACTION, TextScaled = true, TextColor3 = CREAM,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.74, 0.6), Parent = key })
	local textX = 0.035 + 0.72 * (2.3 * 0.74) / W + 0.045
	-- small object line on top (e.g. "Trash Can"), the action big under it (e.g. "Change Weapons"); no object text = the action fills the card
	local hasObject = prompt.ObjectText ~= ""
	if hasObject then
		new("TextLabel", { BackgroundTransparency = 1, Text = string.upper(prompt.ObjectText), FontFace = F_OBJECT, TextScaled = true, TextColor3 = INK, TextTransparency = 0.4,
			TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromScale(textX, 0.1), Size = UDim2.fromScale(0.95 - textX, 0.24), Parent = card })
	end
	new("TextLabel", { BackgroundTransparency = 1, Text = prompt.ActionText, FontFace = F_ACTION, TextScaled = true, TextColor3 = INK,
		TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromScale(textX, hasObject and 0.32 or 0.14), Size = UDim2.fromScale(0.95 - textX, hasObject and 0.56 or 0.72), Parent = card })
	-- (2026-10-21, RIVALS pass) small idle bob: the billboard drifts 0.08 studs up and down (cancelled on hide)
	local bob = TweenService:Create(bb, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { StudsOffsetWorldSpace = Vector3.new(0, 3.28, 0) })
	bb.StudsOffsetWorldSpace = Vector3.new(0, 3.12, 0)
	bob:Play()
	-- hold progress along the bottom edge
	local track = new("Frame", { BorderSizePixel = 0, BackgroundColor3 = INK, BackgroundTransparency = 0.8, Position = UDim2.fromScale(0.06, 0.9), Size = UDim2.fromScale(0.88, 0.06), -- (2026-10-21, RIVALS pass) ink track reads on cream
		Visible = prompt.HoldDuration > 0, Parent = card }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local fill = new("Frame", { BorderSizePixel = 0, BackgroundColor3 = OLIVE, Size = UDim2.fromScale(0, 1), Parent = track }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	-- click / tap the card: same as the key (held while pressed)
	local hit = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = group })
	local conns = {}
	table.insert(conns, { Disconnect = function() bob:Cancel() end }) -- (2026-10-21, RIVALS pass) hide() stops the bob
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
