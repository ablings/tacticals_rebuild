-- Managers/TrainingExtrasManager (server, lobby place): Training extras housekeeping (notes/training_extras_done.md).
-- A feature switched off in Shared.Config.TrainingConfig (or by ReplicatedStorage attribute TX_<Feature> = false) has its
-- geometry folder LobbyMap.Training.Extras.<Feature> moved to ServerStorage._TrainingExtrasOff (nothing is deleted), so a
-- disabled feature leaves no parts, prompts or targets behind. Missing config = every extra off.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local manager = {}

local FEATURES = { "Bullseyes", "DpsDummies", "JumpPads", "Tightropes", "SwapBins" }

function manager.Start()
	local ok, TX = pcall(require, ReplicatedStorage.Modules.Shared.Config.TrainingConfig)
	local map = workspace:WaitForChild("LobbyMap", 30)
	local t = map and map:WaitForChild("Training", 30)
	local ex = t and t:WaitForChild("Extras", 10)
	if not ex then return end
	for _, name in FEATURES do
		local f = ex:FindFirstChild(name)
		if f and not (ok and TX.On(name)) then
			local off = ServerStorage:FindFirstChild("_TrainingExtrasOff")
			if not off then off = Instance.new("Folder"); off.Name = "_TrainingExtrasOff"; off.Parent = ServerStorage end
			f.Parent = off
		end
	end
end

return manager
