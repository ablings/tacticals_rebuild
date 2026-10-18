-- ReplicatedStorage.Modules.Shared.TrainingGate (MATCH PLACE, UI session; 2026-10-16 pass-through shim, 2026-10-18 gate)
-- The lobby's gate switches the combat controllers on only in Training / duels. The match place is all combat, so the
-- gate is open, EXCEPT in the after-match lobby (player attribute InPseudoLobby, the lead session's PostMatch phase):
-- there the [SET] combat controllers go quiet like in the hub (no scripted camera / mouse lock / hotbar input), so the
-- lobby's own camera, the Kit room and the menus work. Same proxies as the hub's gate. Differences on purpose:
--   * CharacterAdded is NOT gated: a rematch respawns you around the moment InPseudoLobby clears, and the controllers
--     must still set up that character.
--   * no UI switching here: UIKit.PseudoLobby's guard hides the match HUD in the lobby and puts it back for the game.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local Gate = {}
local player = Players.LocalPlayer
function Gate.On() return player == nil or player:GetAttribute("InPseudoLobby") ~= true end
local function signal(sig)
	return setmetatable({
		Connect = function(_, fn) return sig:Connect(function(...) if Gate.On() then fn(...) end end) end,
		Once = function(_, fn) return sig:Once(function(...) if Gate.On() then fn(...) end end) end,
		Wait = function() return sig:Wait() end,
	}, {})
end
local function proxy(real, signals, extra)
	local p = {}
	for _, n in signals do p[n] = signal(real[n]) end
	for k, v in (extra or {}) do p[k] = v end
	return setmetatable(p, {
		__index = function(_, k)
			local v = real[k]
			if type(v) == "function" then return function(_, ...) return v(real, ...) end end
			return v
		end,
		__newindex = function(_, k, v) real[k] = v end,
	})
end
Gate.RunService = proxy(RunService, {"Heartbeat", "RenderStepped", "Stepped", "PreRender", "PreSimulation", "PostSimulation", "PreAnimation"}, {
	BindToRenderStep = function(_, name, prio, fn) RunService:BindToRenderStep(name, prio, function(...) if Gate.On() then fn(...) end end) end,
})
Gate.UserInputService = proxy(UserInputService, {"InputBegan", "InputEnded", "InputChanged", "TouchStarted", "TouchEnded", "TouchMoved", "JumpRequest", "WindowFocusReleased"})
local function wrapAction(fn)
	return function(name, state, input)
		if not Gate.On() then return Enum.ContextActionResult.Pass end
		return fn(name, state, input)
	end
end
Gate.ContextActionService = proxy(ContextActionService, {}, {
	BindAction = function(_, name, fn, touch, ...) ContextActionService:BindAction(name, wrapAction(fn), touch, ...) end,
	BindActionAtPriority = function(_, name, fn, touch, prio, ...) ContextActionService:BindActionAtPriority(name, wrapAction(fn), touch, prio, ...) end,
})
Gate.CharacterAdded = player and player.CharacterAdded or nil

-- entering the lobby: hand the camera / mouse / speed back to Roblox's defaults (the hub's lobby feel)
if player then
	local lastOn = Gate.On()
	player:GetAttributeChangedSignal("InPseudoLobby"):Connect(function()
		local on = Gate.On()
		if lastOn and not on then
			local cam = workspace.CurrentCamera
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if cam then
				cam.CameraType = Enum.CameraType.Custom
				if hum then cam.CameraSubject = hum end
				cam.FieldOfView = 70
			end
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
			if hum then hum.WalkSpeed = 16; hum.CameraOffset = Vector3.zero; hum.AutoRotate = true end
		end
		lastOn = on
	end)
end
return Gate
