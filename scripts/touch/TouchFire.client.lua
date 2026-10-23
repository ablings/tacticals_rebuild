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
	-- (2026-10-23, Edward: "tapping on the screen twice shot my gun ... mobile has their own shoot button") off unless switched on
	cfg.DoubleTapAttack = dt == true
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

-- 4. (2026-10-23, Edward: "auto shoot ... a minimum of 25 ms and a maximum of 100 ms ... needed for mobile devices") Auto Shoot:
--    on a touch screen in combat, with a gun out, the crosshair (screen centre) resting on an enemy for Setting_AutoShootDelay ms
--    (25-100, default 50) presses Fire; it lets go the moment the crosshair leaves them. Setting_AutoShoot (default on) turns it off.
local RunService = game:GetService("RunService")
local autoFiring, onSince = false, nil
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
local function touchOn() return UIS.TouchEnabled or player:GetAttribute("_ForceTouch") == true end
local function inCombat()
	if player:GetAttribute("InDuel") or player:GetAttribute("DuelMatch") ~= nil then return true end
	local ok, on = pcall(function() return require(RS.Modules.Shared.TrainingGate).On() end)
	return ok and on == true
end
local function enemyModel(part)
	local m = part and part:FindFirstAncestorOfClass("Model")
	while m and not m:FindFirstChildOfClass("Humanoid") do m = m:FindFirstAncestorOfClass("Model") end
	if not m or m == player.Character then return nil end
	local hum = m:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return nil end
	local other = Players:GetPlayerFromCharacter(m)
	local myTeam = player:GetAttribute("Team")
	local theirTeam = other and other:GetAttribute("Team") or m:GetAttribute("Team")
	if myTeam ~= nil and theirTeam ~= nil and myTeam == theirTeam then return nil end -- a teammate
	if not other and m:GetAttribute("Team") == nil and not m:GetAttribute("IsBot") and not m.Name:find("Bot") then return nil end -- props / NPCs
	return m
end
local function stopAuto()
	if autoFiring then autoFiring = false; InputActions.Release("Fire") end
	onSince = nil
end
RunService.Heartbeat:Connect(function()
	local want = false
	local char = player.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	if touchOn() and player:GetAttribute("Setting_AutoShoot") ~= false and tool and tool:GetAttribute("Ammo") ~= nil and inCombat()
		and player:GetAttribute("InCutscene") ~= true then
		local cam = workspace.CurrentCamera
		local ray = cam:ViewportPointToRay(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
		params.FilterDescendantsInstances = { char, cam }
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 600, params)
		want = hit ~= nil and enemyModel(hit.Instance) ~= nil
	end
	if not want then stopAuto() return end
	local delayMs = math.clamp(tonumber(player:GetAttribute("Setting_AutoShootDelay")) or 50, 25, 100)
	onSince = onSince or os.clock()
	if not autoFiring and os.clock() - onSince >= delayMs / 1000 then
		autoFiring = true
		InputActions.Press("Fire")
	end
end)
player.CharacterRemoving:Connect(stopAuto)
