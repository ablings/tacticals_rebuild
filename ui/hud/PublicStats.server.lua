-- PublicStats (ServerScriptService, Script): copies the few profile numbers other players may see onto attributes, so
-- the lobby UI can show them for everyone (nameplates, pad slots, the scoreboard): Level (account level) and Wins.
-- Read-only: it never changes the profile.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local LobbyConfig = require(ReplicatedStorage.Modules.Shared.Config.LobbyConfig)
local PlayerStore = require(ServerScriptService.Data.PlayerStore)

local function sync(player)
	local ok, data = pcall(PlayerStore.Get, player)
	if not ok or type(data) ~= "table" then return end
	local level = LobbyConfig.AccountLevel(data.XP or 0)
	if player:GetAttribute("Level") ~= level then player:SetAttribute("Level", level) end
	local wins = data.Stats and data.Stats.Wins or 0
	if player:GetAttribute("Wins") ~= wins then player:SetAttribute("Wins", wins) end
end

while true do
	for _, p in Players:GetPlayers() do task.spawn(sync, p) end
	task.wait(2)
end
