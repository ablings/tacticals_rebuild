-- PublicStats (ServerScriptService, Script): copies the few profile numbers other players may see onto attributes, so
-- the lobby UI can show them for everyone (nameplates, pad slots, the scoreboard, the profile card): Level (account level),
-- Wins, StatMatches, StatKills, StatHeadshots.
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
	local streak = tonumber(data.WinStreak) or 0 -- [STREAK] the killer card's flame badge
	if player:GetAttribute("WinStreak") ~= streak then player:SetAttribute("WinStreak", streak) end
	-- the profile card (UIKit.PlayerCards): matches / kills / headshots, for the win rate and headshot %
	local st = type(data.Stats) == "table" and data.Stats or {}
	for attr, key in { StatMatches = "MatchesPlayed", StatKills = "Kills", StatHeadshots = "Headshots" } do
		local v = tonumber(st[key]) or 0
		if player:GetAttribute(attr) ~= v then player:SetAttribute(attr, v) end
	end
end

while true do
	for _, p in Players:GetPlayers() do task.spawn(sync, p) end
	task.wait(2)
end

