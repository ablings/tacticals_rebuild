-- ServerScriptService.DeviceBridge (Script, hub + match places) 2026-10-20 (UI session: RIVALS shows each player's device after
-- their name). Clients report what they're playing on (StarterPlayerScripts.DeviceReport); the server keeps it as the
-- replicated player attribute Device = "PC" | "Controller" | "Phone" | "Tablet" | "Console" for nameplates / the leaderboard.
-- Cosmetic only: a client could lie about it, so nothing gameplay-related may read it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VALID = { PC = true, Controller = true, Phone = true, Tablet = true, Console = true }
local remote = ReplicatedStorage:FindFirstChild("ReportDevice") or Instance.new("RemoteEvent")
remote.Name = "ReportDevice"
remote.Parent = ReplicatedStorage

local lastReport = {}
remote.OnServerEvent:Connect(function(player: Player, device: any)
	if type(device) ~= "string" or not VALID[device] then return end
	local now = os.clock()
	if now - (lastReport[player] or 0) < 0.5 then return end -- input switches can come fast; keep it cheap
	lastReport[player] = now
	if player:GetAttribute("Device") ~= device then player:SetAttribute("Device", device) end
end)
Players.PlayerRemoving:Connect(function(p) lastReport[p] = nil end)
