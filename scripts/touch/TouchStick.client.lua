-- StarterPlayer.StarterPlayerScripts.TouchStick [TOUCH] (2026-10-17): our own dynamic thumbstick, so Left Handed Mode can
-- move it to the right half (Roblox's DynamicThumbstick is fixed to the left). The installer sets
-- StarterPlayer.DevTouchMovementMode = Scriptable, which removes Roblox's stick on touch devices; this script moves the
-- character instead. Keyboard / gamepad movement is untouched (DevComputerMovementMode is not changed).
-- A finger that starts in InputActions.InJoystickZone (left half, or right half when LeftHanded) on free screen
-- (not a button) becomes the stick: ring at the touch-down point, knob follows the finger, Move() camera-relative.
-- Visual: ScreenGui "TouchStick", all Scale (the UI session may restyle Ring / Knob; keep the names).
-- Layout Editor placement: ScreenGui attributes StickX, StickY (zone centre, Scale 0-1) and StickSize (ring diameter, fraction
-- of screen height), copied into InputActions.Config so the camera rule and TouchFire use the same zone. Unset = defaults.
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local InputActions = require(RS:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("InputActions"))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local RADIUS = 0.11   -- stick travel, as a fraction of the screen height (StickSize / 2 when the editor sets it)
local DEAD = 0.12     -- inner dead zone, as a fraction of the travel

local gui = Instance.new("ScreenGui")
gui.Name = "TouchStick"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 5
gui.Parent = playerGui

local ring = Instance.new("Frame")
ring.Name = "Ring"
ring.AnchorPoint = Vector2.new(0.5, 0.5)
ring.SizeConstraint = Enum.SizeConstraint.RelativeYY
ring.Size = UDim2.fromScale(RADIUS * 2, RADIUS * 2)
ring.BackgroundColor3 = Color3.new(0, 0, 0)
ring.BackgroundTransparency = 0.6
ring.Visible = false
ring.Parent = gui
Instance.new("UICorner", ring).CornerRadius = UDim.new(0.5, 0)
local stroke = Instance.new("UIStroke", ring)
stroke.Color = Color3.new(1, 1, 1)
stroke.Transparency = 0.5
stroke.Thickness = 2

local knob = Instance.new("Frame")
knob.Name = "Knob"
knob.AnchorPoint = Vector2.new(0.5, 0.5)
knob.Size = UDim2.fromScale(0.45, 0.45)
knob.Position = UDim2.fromScale(0.5, 0.5)
knob.BackgroundColor3 = Color3.new(1, 1, 1)
knob.BackgroundTransparency = 0.25
knob.Parent = ring
Instance.new("UICorner", knob).CornerRadius = UDim.new(0.5, 0)

local function placement()
	local cfg = InputActions.Config
	local x, y, size = gui:GetAttribute("StickX"), gui:GetAttribute("StickY"), gui:GetAttribute("StickSize")
	cfg.StickX = type(x) == "number" and math.clamp(x, 0, 1) or nil
	cfg.StickY = type(y) == "number" and math.clamp(y, 0, 1) or nil
	cfg.StickSize = type(size) == "number" and math.clamp(size, 0.1, 0.5) or 0.22
	RADIUS = cfg.StickSize / 2
	ring.Size = UDim2.fromScale(cfg.StickSize, cfg.StickSize)
end
placement()
gui.AttributeChanged:Connect(placement)

local stickInput = nil -- the InputObject driving the stick
local center = Vector2.zero
local move = Vector2.zero -- -1..1, y down

local function viewport()
	local cam = workspace.CurrentCamera
	return cam and cam.ViewportSize or Vector2.new(1, 1)
end

local function enabled()
	if player:GetAttribute("InCutscene") == true then return false end
	return UIS.TouchEnabled or player:GetAttribute("_ForceTouch") == true
end

local function release()
	stickInput = nil
	move = Vector2.zero
	ring.Visible = false
	player:Move(Vector3.zero, true)
end

UIS.TouchStarted:Connect(function(input, gameProcessed)
	if gameProcessed or stickInput or not enabled() then return end
	if InputActions.IsConsumed(input) or not InputActions.InJoystickZone(input.Position) then return end
	stickInput = input
	center = Vector2.new(input.Position.X, input.Position.Y)
	local vp = viewport()
	ring.Position = UDim2.fromScale(center.X / vp.X, center.Y / vp.Y)
	knob.Position = UDim2.fromScale(0.5, 0.5)
	ring.Visible = true
end)

UIS.TouchMoved:Connect(function(input)
	if input ~= stickInput then return end
	local r = RADIUS * viewport().Y
	local d = Vector2.new(input.Position.X, input.Position.Y) - center
	if d.Magnitude > r then d = d.Unit * r end
	local v = d / r
	move = v.Magnitude < DEAD and Vector2.zero or v
	knob.Position = UDim2.fromScale(0.5 + v.X / 2, 0.5 + v.Y / 2)
end)

UIS.TouchEnded:Connect(function(input)
	if input == stickInput then release() end
end)

player:GetAttributeChangedSignal("InCutscene"):Connect(function()
	if stickInput and not enabled() then release() end
end)
player.CharacterAdded:Connect(function() if stickInput then release() end end)

-- after the ControlModule (it binds at Input priority), so a keyboard controller's zero vector can't overwrite the stick
RunService:BindToRenderStep("TouchStickMove", Enum.RenderPriority.Input.Value + 1, function()
	-- the match opening run (MatchCore RunIn: RunInClient drives the character) ignores the stick
	if stickInput and player:GetAttribute("RunInRoute") == nil then
		player:Move(Vector3.new(move.X, 0, move.Y), true)
	end
end)
