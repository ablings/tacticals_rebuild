-- StarterPlayer.StarterPlayerScripts.TouchFire [TOUCH] (2026-10-17): RIVALS "Double Tap To Attack" + touch ownership.
-- 1. Keeps InputActions.Config in step with the Touch tab (player attributes Setting_DoubleTapToAttack,
--    Setting_DoubleTapWindow, Setting_LeftHandedMode; the UI session's SettingsConfig sets them).
-- 2. Every touch that lands on a TouchControls button is registered with InputActions.Consume(input, button.SinkCamera),
--    so CameraController's InputActions.CameraShouldUse(input) can ignore it (or let it turn the camera when sinking is on).
-- 3. A second tap on free screen (not a button, not the joystick zone) within DoubleTapWindow presses Fire, and holding
--    that second finger keeps firing until it lifts.
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local InputActions = require(RS:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("InputActions"))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local function sync()
	local cfg = InputActions.Config
	local dt = player:GetAttribute("Setting_DoubleTapToAttack")
	cfg.DoubleTapAttack = dt ~= false
	local w = tonumber(player:GetAttribute("Setting_DoubleTapWindow"))
	cfg.DoubleTapWindow = w and math.clamp(w, 0.1, 0.6) or 0.25
	cfg.LeftHanded = player:GetAttribute("Setting_LeftHandedMode") == true
end
sync()
for _, a in { "Setting_DoubleTapToAttack", "Setting_DoubleTapWindow", "Setting_LeftHandedMode" } do
	player:GetAttributeChangedSignal(a):Connect(sync)
end

-- the touch HUD button under this touch, if any (buttons carry the SinkCamera attribute)
local function buttonAt(pos)
	local hud = playerGui:FindFirstChild("TouchControls")
	if not hud or not hud.Enabled then return nil end
	for _, g in playerGui:GetGuiObjectsAtPosition(pos.X, pos.Y) do
		if g:IsDescendantOf(hud) and g.Visible then
			local b = g
			while b and b ~= hud and b:GetAttribute("SinkCamera") == nil do b = b.Parent end
			if b and b ~= hud then return b end
		end
	end
	return nil
end

local lastTapAt = -math.huge
local lastTapPos = nil
local firing = nil -- the InputObject holding Fire
local MAX_GAP_PX = 120 -- the two taps must land near each other (a distance, not a layout size)

UIS.TouchStarted:Connect(function(input, gameProcessed)
	local b = buttonAt(input.Position)
	if b then
		InputActions.Consume(input, b:GetAttribute("SinkCamera") == true)
		return
	end
	local cfg = InputActions.Config
	if gameProcessed or not cfg.DoubleTapAttack or firing then return end
	if InputActions.IsConsumed(input) or InputActions.InJoystickZone(input.Position) then return end
	local now = os.clock()
	local p = Vector2.new(input.Position.X, input.Position.Y)
	if now - lastTapAt <= cfg.DoubleTapWindow and lastTapPos and (p - lastTapPos).Magnitude <= MAX_GAP_PX then
		lastTapAt = -math.huge
		firing = input
		InputActions.Press("Fire")
	else
		lastTapAt = now
		lastTapPos = p
	end
end)

UIS.TouchEnded:Connect(function(input)
	if input == firing then
		firing = nil
		InputActions.Release("Fire")
	end
end)
