-- fix/callout_style.lua [CALLOUT] 2026-10-21 (UI session graders, tutorial UI redesign): the Instructor's world barks ("Shifting right!",
-- "On the move!") were plain white text with no plate, so they read as a different system from the new tutorial UI.
--  * StealthController.showCallout (client, match places): a dark plate (14,16,13 @ 0.15) with a small red tick on the left (red = enemy),
--    Builder Sans Heavy 26 in a 320x44 bubble (UI session round 4: "read like a debug label" at 18), sized to the text; the whole bubble fades in / out together (CanvasGroup).
--  * TutorialManager: "Repositioning!" dropped (hard for 8-10 year olds); the line pool is Moving! / On the move! / Shifting right!.
-- Match copy only (the lobby has no StealthController). Idempotent; UNDO = true swaps back.
local UNDO = false --@UNDO
local SC = game.StarterPlayer.StarterPlayerScripts:FindFirstChild("StealthController", true)
local TM = game:GetService("ServerScriptService"):FindFirstChild("TutorialManager", true)

local function patch(inst, edits)
	if not inst then return "missing" end
	local s = inst.Source
	local out = {}
	for i, e in edits do
		local old, new = e[1], e[2]
		if UNDO then old, new = new, old end
		if s:find(new, 1, true) then table.insert(out, i .. "=") else
			local a, b = s:find(old, 1, true)
			assert(a, inst.Name .. " edit " .. i .. ": anchor not found")
			assert(not s:find(old, b + 1, true), inst.Name .. " edit " .. i .. ": anchor not unique")
			s = s:sub(1, a - 1) .. new .. s:sub(b + 1)
			table.insert(out, i .. "+")
		end
	end
	local f, err = loadstring(s)
	assert(f, inst.Name .. " would not parse: " .. tostring(err))
	if inst.Source ~= s then inst.Source = s end
	return inst.Name .. " " .. table.concat(out, " ")
end

local res = {}
table.insert(res, patch(SC, {
	{ [[	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 17
	label.TextColor3 = Color3.fromRGB(255, 235, 220)
	label.TextStrokeTransparency = 0.35
	label.Text = text
	label.TextTransparency = 1
	label.TextStrokeTransparency = 1
	label.Parent = gui
	gui.Parent = localPlayer.PlayerGui
	bubbles[bot] = { gui = gui }
	local TweenService = game:GetService("TweenService")
	TweenService:Create(label, TweenInfo.new(0.15), { TextTransparency = 0, TextStrokeTransparency = 0.35 }):Play()
]], [[	-- [CALLOUT] the tutorial UI's plate: dark (14,16,13 @ 0.15), a red tick on the left (red = enemy), Builder Sans Heavy
	local group = Instance.new("CanvasGroup")
	group.AnchorPoint = Vector2.new(0.5, 0.5)
	group.Position = UDim2.fromScale(0.5, 0.5)
	group.Size = UDim2.fromScale(1, 1)
	group.BackgroundTransparency = 1
	group.GroupTransparency = 1
	group.Parent = gui
	local plate = Instance.new("Frame")
	plate.AnchorPoint = Vector2.new(0.5, 0.5)
	plate.Position = UDim2.fromScale(0.5, 0.5)
	plate.AutomaticSize = Enum.AutomaticSize.X
	plate.Size = UDim2.fromScale(0, 1)
	plate.BackgroundColor3 = Color3.fromRGB(14, 16, 13)
	plate.BackgroundTransparency = 0.15
	plate.Parent = group
	local pc = Instance.new("UICorner") pc.CornerRadius = UDim.new(0, 6) pc.Parent = plate
	local pad = Instance.new("UIPadding") pad.PaddingLeft = UDim.new(0, 20) pad.PaddingRight = UDim.new(0, 16) pad.Parent = plate
	local tick = Instance.new("Frame")
	tick.AnchorPoint = Vector2.new(0, 0.5)
	tick.Position = UDim2.new(0, -10, 0.5, 0)
	tick.Size = UDim2.new(0, 4, 0.6, 0)
	tick.BackgroundColor3 = Color3.fromRGB(210, 52, 46)
	tick.BorderSizePixel = 0
	tick.Parent = plate
	local label = Instance.new("TextLabel")
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromScale(0, 1)
	label.BackgroundTransparency = 1
	label.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy)
	label.TextSize = 26 -- (UI round 4, graders: 18 read like a debug label)
	label.TextColor3 = Color3.fromRGB(240, 236, 226)
	label.Text = text
	label.Parent = plate
	gui.Parent = localPlayer.PlayerGui
	bubbles[bot] = { gui = gui }
	local TweenService = game:GetService("TweenService")
	TweenService:Create(group, TweenInfo.new(0.15), { GroupTransparency = 0 }):Play()
]] },
	{ "\tgui.Size = UDim2.fromOffset(220, 34)\n", "\tgui.Size = UDim2.fromOffset(320, 44)\n" }, -- (UI round 4: a bigger bubble)
	{ "\t\t\tTweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()\n",
	  "\t\t\tTweenService:Create(group, TweenInfo.new(0.4), { GroupTransparency = 1 }):Play() -- [CALLOUT] the whole plate fades\n" },
}))
table.insert(res, patch(TM, {
	{ "callout(session, ({ \"Moving!\", \"Repositioning!\", \"Shifting right!\", \"On the move!\" })[math.random(1, 4)])",
	  "callout(session, ({ \"Moving!\", \"Shifting right!\", \"On the move!\" })[math.random(1, 3)]) --[[ [CALLOUT] no \"Repositioning!\" (kids) ]]" },
}))
return (UNDO and "UNDO " or "CALLOUT ") .. table.concat(res, " | ")
