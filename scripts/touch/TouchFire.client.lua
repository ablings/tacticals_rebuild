-- StarterPlayer.StarterPlayerScripts.TouchFire [TOUCH] (2026-10-17): RIVALS "Double Tap To Attack".
-- A second tap on free screen (not a button, not the joystick zone) within Config.DoubleTapWindow presses Fire, and holding
-- that second finger keeps firing until it lifts. Settings come from InputActions.Config (the Touch tab writes them).
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local InputActions = require(RS:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("InputActions"))

local lastTapAt = -math.huge
local lastTapPos = nil
local firing = nil -- the InputObject holding Fire
local MAX_GAP_PX = 120 -- the two taps must land near each other (a scale of the shorter screen side would be nicer; px is fine for a distance)

UIS.TouchStarted:Connect(function(input, gameProcessed)
	local cfg = InputActions.Config
	if gameProcessed or not cfg.DoubleTapAttack or firing then return end
	if InputActions.IsConsumed(input) or InputActions.InJoystickZone(input.Position) then return end
	local now = os.clock()
	local near = lastTapPos and (Vector2.new(input.Position.X, input.Position.Y) - lastTapPos).Magnitude <= MAX_GAP_PX
	if now - lastTapAt <= cfg.DoubleTapWindow and near then
		lastTapAt = -math.huge
		firing = input
		InputActions.Press("Fire")
	else
		lastTapAt = now
		lastTapPos = Vector2.new(input.Position.X, input.Position.Y)
	end
end)

UIS.TouchEnded:Connect(function(input)
	if input == firing then
		firing = nil
		InputActions.Release("Fire")
	end
end)
