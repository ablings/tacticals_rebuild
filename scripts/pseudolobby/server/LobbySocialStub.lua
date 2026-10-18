-- ServerScriptService.LobbySocial (Script, MATCH places) [PSEUDOLOBBY] 2026-10-18: the hub's LobbySocial runs Challenge duels
-- through LobbyDuelManager, which a match server doesn't have. Here the same RemoteEvent exists (the hub's PlayerCards wait for
-- it) and every Challenge is answered "Sent", false with a reason, so the card shows a toast instead of hanging.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remote = ReplicatedStorage:FindFirstChild("LobbySocial") or Instance.new("RemoteEvent")
remote.Name = "LobbySocial"
remote.Parent = ReplicatedStorage

local lastCall = {}
remote.OnServerEvent:Connect(function(player, kind, target)
	if os.clock() - (lastCall[player] or 0) < 0.4 then return end
	lastCall[player] = os.clock()
	if kind == "Challenge" and typeof(target) == "Instance" and target:IsA("Player") then
		remote:FireClient(player, "Sent", target, false, "Challenges are in the hub: use Rematch here")
	end
end)
game:GetService("Players").PlayerRemoving:Connect(function(p) lastCall[p] = nil end)
