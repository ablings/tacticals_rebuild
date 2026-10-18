-- ServerScriptService.Shared.RichNotify (ModuleScript, hub + match places) [NOTIFY] 2026-10-18 (UI session: RIVALS banner +
-- Inbox, UIKit.Notify). A table on Events.Lobby.Notify makes the black pill banner and an Inbox entry; plain strings still
-- make the old toast:  Notify:FireClient(player, { title, sub, reward = { kind = "Scissors", count } | { kind = "Item", id } | ... })
-- Callers: LobbyManager (Task Completed, Item Unlocked, Code Redeemed), RoundManager / LobbyDuelManager (Level Up, Rank Up).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RichNotify = {}

local function event(): RemoteEvent?
	local events = ReplicatedStorage:FindFirstChild("Events")
	local lobby = events and events:FindFirstChild("Lobby")
	local e = lobby and lobby:FindFirstChild("Notify")
	return (e and e:IsA("RemoteEvent")) and e or nil
end

local function config()
	local ok, C = pcall(function() return require(ReplicatedStorage.Modules.Shared.Config.LobbyConfig) end)
	return ok and C or nil
end

function RichNotify.Send(player: Player, title: string, sub: string?, reward)
	local e = event()
	if not (e and player and player.Parent) then return end
	e:FireClient(player, { title = title, sub = sub or "", reward = reward })
end

-- "Level Up" when the account level went up between two XP totals
function RichNotify.LevelUp(player: Player, xpBefore: number?, xpAfter: number?)
	local C = config()
	if not (C and C.AccountLevel) then return end
	local a = (C.AccountLevel(tonumber(xpBefore) or 0))
	local b = (C.AccountLevel(tonumber(xpAfter) or 0))
	if b > a then RichNotify.Send(player, "Level Up", ("You reached level %d!"):format(b), { kind = "Level", count = b }) end
end

function RichNotify.Item(player: Player, itemId: string)
	local C = config()
	local item = C and C.Items and C.Items[itemId]
	RichNotify.Send(player, "Item Unlocked", ((item and item.Name) or itemId) .. " is now yours!", { kind = "Item", id = itemId })
end

function RichNotify.RankUp(player: Player, rankName: string?)
	RichNotify.Send(player, "Rank Up", ("You reached %s!"):format(tostring(rankName or "a new rank")), { kind = "Rank", rank = rankName })
end

return RichNotify
