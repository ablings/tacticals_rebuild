-- ReplicatedStorage/Modules/Shared/MatchState (ModuleScript): where a player's match state lives (server + client).
--   Match place: ReplicatedStorage itself. Lobby duels: ReplicatedStorage.LobbyDuels.<matchId> (player attr DuelMatch,
--   falling back to DuelSpectate). One HUD reads both places through this.
--   MatchState.For(player) -> Instance?        the state object (nil = in the lobby, not in a match)
--   MatchState.MatchId(player) -> string?
--   MatchState.Role(player) -> "Player" | "Spectator" | nil
--   MatchState.Get(player, attr) -> any        attribute on the player's state object, else on ReplicatedStorage
--   MatchState.SameMatch(a, b) -> bool         a, b = Player or character Model (bots carry DuelMatch on the model)
--   MatchState.ArenaOf(position) -> state?     the lobby match whose arena box contains position
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local MatchState = {}

local function lobbyFolder() return ReplicatedStorage:FindFirstChild("LobbyDuels") end

function MatchState.MatchId(player: Player?): string?
	if not player then return nil end
	local id = player:GetAttribute("DuelMatch") or player:GetAttribute("DuelSpectate")
	return id and tostring(id) or nil
end

function MatchState.Role(player: Player?)
	if not player then return nil end
	if player:GetAttribute("DuelMatch") then return "Player" end
	if player:GetAttribute("DuelSpectate") then return "Spectator" end
	return nil
end

function MatchState.For(player: Player?): Instance?
	local id = MatchState.MatchId(player)
	if id then
		local f = lobbyFolder()
		return f and f:FindFirstChild(id) or nil
	end
	-- the match place keeps its single match on ReplicatedStorage
	if ReplicatedStorage:GetAttribute("MatchState") ~= nil and not lobbyFolder() then return ReplicatedStorage end
	return nil
end

function MatchState.Get(player: Player?, attr: string)
	local o = MatchState.For(player)
	if o then return o:GetAttribute(attr) end
	return ReplicatedStorage:GetAttribute(attr)
end

local function matchOf(x): string?
	if typeof(x) ~= "Instance" then return nil end
	if x:IsA("Player") then return x:GetAttribute("DuelMatch") end
	local p = Players:GetPlayerFromCharacter(x)
	if p then return p:GetAttribute("DuelMatch") end
	return x:GetAttribute("DuelMatch")
end
MatchState.MatchOf = matchOf

function MatchState.SameMatch(a, b): boolean
	return matchOf(a) == matchOf(b)
end

function MatchState.ArenaOf(position: Vector3): Instance?
	local f = lobbyFolder()
	for _, s in (f and f:GetChildren() or {}) do
		local o, size = s:GetAttribute("ArenaOrigin"), s:GetAttribute("ArenaSize")
		if typeof(o) == "Vector3" and typeof(size) == "Vector3" then
			local d = position - o
			if math.abs(d.X) <= size.X / 2 + 50 and math.abs(d.Z) <= size.Z / 2 + 50 and d.Y > -100 and d.Y < size.Y + 100 then return s end
		end
	end
	return nil
end

return MatchState
