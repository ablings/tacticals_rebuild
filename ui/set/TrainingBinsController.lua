-- Client/Controllers/TrainingBinsController (client, lobby place): weapon-swap bins in Training (notes/training_extras_done.md).
-- F at a bin (ProximityPrompt with attribute TrainingBin) opens a picker with the 7 guns. Owned guns swap normally; guns you
-- don't own are a TRIAL (Training only; the server, TrainingBinsManager, decides and never writes saved data).
-- Pick: click a card or press 1-7. Close: Esc, F again, or walk away. While a trial runs, a small "TRIAL" tag shows.
-- UI rule: every Position / Size in Scale (built in design px 1920 x 1080, converted).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local WeaponConfig = require(ReplicatedStorage.Modules.Shared.Config.WeaponConfig)
local ok, TX = pcall(require, ReplicatedStorage.Modules.Shared.Config.TrainingConfig)

local player = Players.LocalPlayer
local controller = {}
local DW, DH = 1920, 1080
local function S(x, y) return UDim2.fromScale(x / DW, y / DH) end           -- design px -> Scale
local CREAM, OLIVE, DARK, SAGE = Color3.fromRGB(236, 232, 218), Color3.fromRGB(138, 156, 74), Color3.fromRGB(10, 12, 10), Color3.fromRGB(167, 173, 152)
local FONT_H = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
local FONT_B = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local gui, panel, trialTag, openAt
local swapEvent

local function text(parent, name, pos, size, str, colour, font, xa)
	local l = Instance.new("TextLabel"); l.Name = name; l.BackgroundTransparency = 1; l.Position = pos; l.Size = size
	l.Text = str; l.TextScaled = true; l.TextColor3 = colour; l.FontFace = font
	l.TextXAlignment = xa or Enum.TextXAlignment.Center; l.Parent = parent
	return l
end

local function close()
	if not openAt then return end
	openAt = nil
	panel.Visible = false
	ContextActionService:UnbindAction("TrainingBinKeys")
	local cam = shared.Get and shared.Get("CameraController")
	if cam and cam.SetMouseFree then cam.SetMouseFree(false) end
end

local function pick(id)
	if swapEvent then swapEvent:FireServer(id) end
	close()
end

local function build()
	gui = Instance.new("ScreenGui"); gui.Name = "WeaponBin"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; gui.DisplayOrder = 20; gui.Parent = player:WaitForChild("PlayerGui")
	panel = Instance.new("Frame"); panel.Name = "Panel"; panel.AnchorPoint = Vector2.new(0.5, 0.5); panel.Position = UDim2.fromScale(0.5, 0.56)
	panel.Size = S(1240, 330); panel.BackgroundColor3 = DARK; panel.BackgroundTransparency = 0.15; panel.Visible = false; panel.Parent = gui
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.04, 0); c.Parent = panel
	local st = Instance.new("UIStroke"); st.Color = OLIVE; st.Thickness = 2; st.Parent = panel
	text(panel, "Title", UDim2.fromScale(0.03, 0.05), UDim2.fromScale(0.6, 0.13), "WEAPON CRATE", CREAM, FONT_H, Enum.TextXAlignment.Left)
	text(panel, "Hint", UDim2.fromScale(0.45, 0.06), UDim2.fromScale(0.52, 0.1), "CLICK OR 1-7 · ESC / F CLOSE · TRIAL = TRAINING ONLY", SAGE, FONT_B, Enum.TextXAlignment.Right)
	local n = #WeaponConfig.Loadout
	for i, id in WeaponConfig.Loadout do
		local cfg = WeaponConfig.Get(id)
		local b = Instance.new("TextButton"); b.Name = id; b.AutoButtonColor = true; b.Text = ""
		b.Position = UDim2.fromScale(0.03 + (i - 1) * (0.94 / n), 0.26); b.Size = UDim2.fromScale(0.94 / n - 0.012, 0.66)
		b.BackgroundColor3 = Color3.fromRGB(40, 44, 36); b.Parent = panel
		local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0.08, 0); bc.Parent = b
		text(b, "Key", UDim2.fromScale(0.08, 0.05), UDim2.fromScale(0.25, 0.2), tostring(i), OLIVE, FONT_H, Enum.TextXAlignment.Left)
		text(b, "Name", UDim2.fromScale(0.06, 0.38), UDim2.fromScale(0.88, 0.22), cfg and cfg.DisplayName or id, CREAM, FONT_H)
		text(b, "State", UDim2.fromScale(0.06, 0.7), UDim2.fromScale(0.88, 0.16), "", SAGE, FONT_B)
		b.Activated:Connect(function() pick(id) end)
	end
	trialTag = text(gui, "TrialTag", UDim2.fromScale(0.4, 0.08), UDim2.fromScale(0.2, 0.03), "", OLIVE, FONT_H)
	trialTag.TextStrokeTransparency = 0.4; trialTag.Visible = false
end

local function refreshCards()
	local owned = string.split(player:GetAttribute("TX_OwnedGuns") or "", ",")
	local current = player:GetAttribute("Loadout") or WeaponConfig.DefaultWeapon
	for _, id in WeaponConfig.Loadout do
		local b = panel:FindFirstChild(id)
		if b then
			local mine = table.find(owned, id) ~= nil
			b.State.Text = id == current and "IN HAND" or (mine and "OWNED" or "TRIAL")
			b.State.TextColor3 = id == current and OLIVE or (mine and SAGE or Color3.fromRGB(230, 180, 90))
		end
	end
end

local function open(prompt)
	if not panel then return end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local par = prompt and prompt.Parent
	openAt = (par and par:IsA("Attachment") and par.WorldPosition) or (par and par:IsA("BasePart") and par.Position) or (root and root.Position)
	if not openAt then return end
	refreshCards()
	panel.Visible = true
	local cam = shared.Get and shared.Get("CameraController")
	if cam and cam.SetMouseFree then cam.SetMouseFree(true) end
	local keys = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six, Enum.KeyCode.Seven }
	ContextActionService:BindActionAtPriority("TrainingBinKeys", function(_, state, input)
		if state ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Sink end
		if input.KeyCode == Enum.KeyCode.Escape then close(); return Enum.ContextActionResult.Sink end
		local i = table.find(keys, input.KeyCode)
		if i and WeaponConfig.Loadout[i] then pick(WeaponConfig.Loadout[i]) end
		return Enum.ContextActionResult.Sink
	end, false, 3000, Enum.KeyCode.Escape, table.unpack(keys))
end

function controller.Open(prompt) open(prompt) end     -- test hook
function controller.Pick(id) pick(id) end

function controller.Start()
	if not (ok and TX.On("SwapBins")) then return end
	build()
	task.spawn(function() swapEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Training"):WaitForChild("SwapWeapon", 30) end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt:GetAttribute("TrainingBin") and player:GetAttribute("InTraining") == true then
			if openAt then close() else open(prompt) end                -- F again (the prompt is still showing) closes
		end
	end)
	local function trial()
		local t = player:GetAttribute("TrialWeapon")
		local cfg = t and WeaponConfig.Get(t)
		trialTag.Text = t and ("TRIAL · " .. (cfg and cfg.DisplayName or t)) or ""
		trialTag.Visible = t ~= nil and player:GetAttribute("InTraining") == true
	end
	player:GetAttributeChangedSignal("TrialWeapon"):Connect(trial)
	player:GetAttributeChangedSignal("InTraining"):Connect(function() trial(); if player:GetAttribute("InTraining") ~= true then close() end end)
	player:GetAttributeChangedSignal("Loadout"):Connect(function() if openAt then refreshCards() end end)
	RunService.Heartbeat:Connect(function()
		if not openAt then return end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root or (root.Position - openAt).Magnitude > 12 then close() end
	end)
end

return controller
