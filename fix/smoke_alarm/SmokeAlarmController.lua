-- StarterPlayer/StarterPlayerScripts/Client/Controllers/SmokeAlarmController (ModuleScript) [SMOKEALARM] 2026-10-28
-- Match places: every smoke alarm ShootableManager tagged "SmokeAlarm" (the placed maps' Shootable = "SmokeAlarm" models) chirps,
-- blinks, blares and breaks on this client from its attributes (SmokeAlarm.BindClient). One match per match server, so every
-- client here is that match's player or spectator. Lobby pad-duel arenas (Workspace.DuelArenas) are skipped: ArenaLoader binds
-- their client-only Visual twin for that match's players only. (fix/smoke_alarm.lua, notes/smoke_alarm.md)
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local controller = {}
local bound = {} -- [alarm] = { connections }

function controller.Start()
	local SmokeAlarm = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("SmokeAlarm"))
	local function bind(alarm: Instance)
		if bound[alarm] or alarm:FindFirstAncestor("DuelArenas") then return end
		bound[alarm] = SmokeAlarm.BindClient(alarm, alarm)
	end
	for _, a in CollectionService:GetTagged(SmokeAlarm.TAG) do task.spawn(bind, a) end
	CollectionService:GetInstanceAddedSignal(SmokeAlarm.TAG):Connect(bind)
	CollectionService:GetInstanceRemovedSignal(SmokeAlarm.TAG):Connect(function(alarm)
		local conns = bound[alarm]
		bound[alarm] = nil
		for _, c in conns or {} do c:Disconnect() end
	end)
end

return controller
