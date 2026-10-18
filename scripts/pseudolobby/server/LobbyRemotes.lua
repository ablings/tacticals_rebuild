-- [PSEUDOLOBBY] copied from the hub (2026-10-18) for the match places' after-match lobby; changes are tagged [PSEUDOLOBBY].
-- ServerScriptService/Lobby/LobbyRemotes (ModuleScript)
-- One RemoteFunction ("Request") carries every lobby action from the client:
--   Request:InvokeServer(action, ...) -> { ok = bool, msg = string?, ... }
-- Managers register handlers with  LobbyRemotes.Handlers[action] = function(player, ...) end
-- Two RemoteEvents go the other way: QueueState (matchmaking snapshot, everyone) and Notify (toasts).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local folder = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Lobby")

local LobbyRemotes = {
	Handlers = {},
	Request = folder:WaitForChild("Request") :: RemoteFunction,
	QueueState = folder:WaitForChild("QueueState") :: RemoteEvent,
	NotifyEvent = folder:WaitForChild("Notify") :: RemoteEvent,
}

local MIN_GAP = 0.12 -- seconds between requests per player
local lastRequest = {}

LobbyRemotes.Request.OnServerInvoke = function(player, action, ...)
	if type(action) ~= "string" then
		return { ok = false, msg = "Bad request" }
	end
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < MIN_GAP then
		return { ok = false, msg = "Slow down" }
	end
	lastRequest[player] = now

	local handler = LobbyRemotes.Handlers[action]
	if not handler then
		return { ok = false, msg = "Unknown action" }
	end
	local ok, result = pcall(handler, player, ...)
	if not ok then
		warn(`[Lobby] {action} failed for {player.Name}: {result}`)
		return { ok = false, msg = "Something went wrong, try again" }
	end
	return result or { ok = true }
end

Players.PlayerRemoving:Connect(function(player)
	lastRequest[player] = nil
end)

-- kind: "info" | "good" | "bad"
function LobbyRemotes.Notify(player: Player, text: string, kind: string?)
	LobbyRemotes.NotifyEvent:FireClient(player, text, kind or "info")
end

function LobbyRemotes.NotifyAll(text: string, kind: string?)
	LobbyRemotes.NotifyEvent:FireAllClients(text, kind or "info")
end

return LobbyRemotes
