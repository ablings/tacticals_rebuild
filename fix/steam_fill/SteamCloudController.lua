-- StarterPlayer/StarterPlayerScripts/Client/Controllers/SteamCloudController (ModuleScript) [STEAMFILL] 2026-10-27
-- Match places: every steam valve (CollectionService tag "SteamValve", set by ShootableManager) gets a SteamCloud binding.
-- Valves on maps without SteamFill = true never draw anything (the classic jet is the server's). Lobby pad-duel arenas
-- (Workspace.DuelArenas) are skipped: their look is per match (ArenaLoader), so a cloud there must come from ArenaLoader.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local controller = {}
local bound = {} -- [valve] = handle

function controller.Start()
	local SteamCloud = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("SteamCloud"))
	local function bind(valve: Instance)
		if bound[valve] or valve:FindFirstAncestor("DuelArenas") then return end
		bound[valve] = SteamCloud.Bind(valve)
	end
	for _, v in CollectionService:GetTagged("SteamValve") do bind(v) end
	CollectionService:GetInstanceAddedSignal("SteamValve"):Connect(bind)
	CollectionService:GetInstanceRemovedSignal("SteamValve"):Connect(function(valve)
		local h = bound[valve]
		bound[valve] = nil
		if h then h:Destroy() end
	end)
end

return controller
