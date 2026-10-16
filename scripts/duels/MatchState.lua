-- ReplicatedStorage/Modules/Shared/MatchState (ModuleScript): where a player's match state lives (server + client).
--   Match place: ReplicatedStorage itself. Lobby duels: ReplicatedStorage.LobbyDuels.<matchId> (player attr DuelMatch,
--   falling back to DuelSpectate). One HUD reads both places through this.
--   MatchState.For(player) -> Instance?        the state object (nil = in the lobby, not in a match)
--   MatchState.MatchId(player) -> string?
--   MatchState.Role(player) -> "Player" | "Spectator" | nil
--   MatchState.Get(player, attr) -> any        attribute on the player's state object, else on ReplicatedStorage
--   MatchState.SameMatch(a, b) -> bool         a, b = Player or character Model (bots carry DuelMatch on the model)
--   MatchState.ArenaOf(position) -> state?     the lobby match whose arena box contains position
--   MatchState.Audience(matchId) -> {Player}    players of that match + its spectators (matchId nil = everyone NOT in a duel)
--   MatchState.FireScoped(remote, anchor, ...)  server: fire a combat FX remote only to the audience of anchor's match
--                                               (anchor = Player / character / bot Model / Vector3 / matchId string)
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

-- the match an effect belongs to: a Player / character / bot Model (DuelMatch), a position (the arena it is in) or an id
function MatchState.ScopeOf(anchor): string?
	local t = typeof(anchor)
	if t == "string" then return anchor end
	if t == "Vector3" then
		local s = MatchState.ArenaOf(anchor)
		return s and s.Name or nil
	end
	if t == "Instance" then
		local id = matchOf(anchor)
		if id then return tostring(id) end
		if anchor:IsA("BasePart") or anchor:IsA("Model") then
			local ok, pos = pcall(function() return anchor:IsA("Model") and anchor:GetPivot().Position or anchor.Position end)
			if ok then return MatchState.ScopeOf(pos) end
		end
	end
	return nil
end

-- who sees a match's effects: its players and spectators. nil = the lobby / Training: everyone not in a lobby duel.
-- (In the match place there is no LobbyDuels folder and nobody has DuelMatch, so this is every player, as before.)
function MatchState.Audience(matchId: string?): { Player }
	local out = {}
	for _, p in Players:GetPlayers() do
		if MatchState.MatchId(p) == matchId then table.insert(out, p) end
	end
	return out
end

-- RemoteEvent:FireAllClients, narrowed to the audience of anchor's match (lobby duels phase 2: no combat traffic or
-- effects cross between the lobby and an arena, or between two arenas)
function MatchState.FireScoped(remote: RemoteEvent, anchor, ...)
	if not lobbyFolder() then remote:FireAllClients(...) return end
	for _, p in MatchState.Audience(MatchState.ScopeOf(anchor)) do remote:FireClient(p, ...) end
end

return MatchState
