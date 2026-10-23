-- Client: fill the lobby with live-like data (placed rank, a full Warlord board, a busy inbox with rewards) so Studio shots
-- show the states real players see. Local only (client attributes don't replicate); nothing is saved.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local p = Players.LocalPlayer
for k, v in {
	RankPlaced = 10, RankPlacements = 10, RankTier = "Gold", RankName = "Gold 2", RankElo = 812, RankPeak = 905,
	RankFloor = 800, RankNextFloor = 900, RankNextName = "Gold 3", RankShield = true, RankWarlord = false,
} do p:SetAttribute(k, v) end
local names = { "Kuroko169", "SpooookyyyWarrior", "Chill_snowwhite", "oooooitsamonkey", "bthepro113", "buyminiuu", "actedpure",
	"67_RizzlerOfOhio", "NYX", "Miiaaa", "jeremiah", "rosie", "arachne", "ReziThePlayer", "debits" }
local top = {}
for i, n in names do
	table.insert(top, { name = n, elo = 3400 - i * 73, userId = (n == "debits") and p.UserId or (1000 + i) })
end
local key = "1v1"
pcall(function()
	local core = RS:FindFirstChild("RankedCore", true)
	if core then local C = require(core) if C.Config and not C.Config.PerModeLadders then key = C.Config.SharedKey end end
end)
RS:SetAttribute("RankedTop_" .. key, HttpService:JSONEncode(top))
RS:SetAttribute("RankedCutoff_" .. key, 2315)
local N = require(RS.UIKit.Notify)
local items = {
	{ title = "Contract Complete", sub = "Revolver: you've earned x100 Scissors!", reward = { kind = "Scissors", count = 100 } },
	{ title = "Mission complete", sub = "Win matches 2/2", reward = { kind = "Scissors", count = 300 } },
	{ title = "Rank up!", sub = "You reached Gold 2" },
	{ title = "Daily login", sub = "Day 3: x150 Scissors", reward = { kind = "Scissors", count = 150 } },
	{ title = "Weapon level 5", sub = "Pistol reached level 5" },
	{ title = "Friend joined", sub = "jeremiah is in this server" },
	{ title = "Contract Complete", sub = "Fists: you've earned x1,000 Scissors!", reward = { kind = "Scissors", count = 1000 } },
	{ title = "Mission complete", sub = "Headshots 5/5", reward = { kind = "Scissors", count = 300 } },
	{ title = "Weekly contract", sub = "Play 20 matches 16/20" },
	{ title = "Shop", sub = "New items in the shop" },
}
for _, n in items do N.Push(n) end
return "ok"
