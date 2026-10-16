-- ReplicatedStorage.Modules.Shared.TrainingGate (MATCH PLACE shim, UI session 2026-10-16)
-- The lobby's gate switches the combat controllers on only in Training / duels. The match place is all combat, so the
-- same [SET] controllers run here with the gate always open: every field is the plain service / signal.
local Players = game:GetService("Players")
local player = Players.LocalPlayer
return {
	On = function() return true end,
	RunService = game:GetService("RunService"),
	UserInputService = game:GetService("UserInputService"),
	ContextActionService = game:GetService("ContextActionService"),
	CharacterAdded = player and player.CharacterAdded or nil,
}
