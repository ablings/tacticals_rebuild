-- StarterPlayer/StarterPlayerScripts/Client/Controllers/WindowGlassController (ModuleScript) [GLASS] 2026-10-28
-- Match places: every window ShootableManager tagged "WindowGlass" (the placed maps' Shootable = "Glass" models) follows its
-- GlassBroken attribute: pane hidden, BrokenGlass shown, shatter + sound when it breaks (Openings.BindClient). One match per match
-- server, so every client here is that match's player or spectator. Lobby pad-duel arenas (Workspace.DuelArenas) are skipped:
-- ArenaLoader binds their client-only Visual twin for that match's players only.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local controller = {}
local bound = {} -- [window] = { RBXScriptConnection }

function controller.Start()
	local Openings = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("Openings"))
	local function bind(window: Instance)
		if bound[window] or window:FindFirstAncestor("DuelArenas") then return end
		bound[window] = Openings.BindClient(window)
	end
	for _, w in CollectionService:GetTagged(Openings.WINDOW_TAG) do task.spawn(bind, w) end
	CollectionService:GetInstanceAddedSignal(Openings.WINDOW_TAG):Connect(bind)
	CollectionService:GetInstanceRemovedSignal(Openings.WINDOW_TAG):Connect(function(window)
		local conns = bound[window]
		bound[window] = nil
		for _, c in conns or {} do c:Disconnect() end
	end)
end

return controller
