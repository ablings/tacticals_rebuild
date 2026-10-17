-- ServerScriptService.Shared.MatchSpec [SECURE] (2026-10-17, overnight loophole audit)
-- TeleportData travels through the player's client, so a player can make it up: they could teleport themselves into a
-- PUBLIC server of the Ranked / Matchmaking place with fake Teams (themselves + an alt) and farm ranked Elo, or edit the
-- teams of a real match. The fix: the lobby writes the match (mode, ranked, teams) server-side, in MemoryStore under the
-- reserved server's PrivateServerId, and the match server reads it from there. TeleportData is then only trusted for
-- loadouts (validated against what each player owns anyway).
--   lobby:  MatchSpec.Write(privateServerId, { Mode, Ranked, Teams, Queue?, MatchId?, BayId?, Online?, From })
--   match:  MatchSpec.Secure(teleportData) -> the match table to play, or nil (no match on this server)
-- Rules on a match server (not Studio):
--   * a public or VIP server (not a reserved one) never runs a match;
--   * with a spec: mode / ranked / teams come from the spec;
--   * without one (a lobby server from before this fix, or MemoryStore down): the Ranked place refuses; any other
--     place plays it casual (Ranked = false), so nothing ranked can be faked.
local MemoryStoreService = game:GetService("MemoryStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchSpec = {}
local IS_STUDIO = RunService:IsStudio()
local TTL = 3 * 3600
local map = nil
local function getMap()
	if map then return map end
	local ok, m = pcall(function() return MemoryStoreService:GetHashMap((IS_STUDIO and "Studio_" or "") .. "MatchSpec") end)
	if ok then map = m end
	return map
end

function MatchSpec.Write(privateServerId: string?, spec): boolean
	if type(privateServerId) ~= "string" or privateServerId == "" then return false end
	local m = getMap()
	if not m then return false end
	spec.WrittenAt = os.time()
	for attempt = 1, 3 do
		local ok, err = pcall(function() m:SetAsync(privateServerId, spec, TTL) end)
		if ok then return true end
		warn(("[MatchSpec] write failed (%d/3): %s"):format(attempt, tostring(err)))
		task.wait(0.5 * attempt)
	end
	return false
end

local cached = nil -- nil = not read yet, false = none, table = the spec
local reading = false
local function readOnce(): any
	if cached ~= nil then return cached end
	while reading do task.wait(0.1) end
	if cached ~= nil then return cached end
	reading = true
	local m = getMap()
	local found = false
	if m then
		-- the lobby writes before the teleport; allow a little time for MemoryStore to settle
		local t0 = os.clock()
		repeat
			local ok, v = pcall(function() return m:GetAsync(game.PrivateServerId) end)
			if ok and type(v) == "table" then found = v break end
			task.wait(1)
		until os.clock() - t0 > 20
	end
	cached = found
	reading = false
	return cached
end

local function placeKind(): string?
	local v = ReplicatedStorage:FindFirstChild("PlaceKind")
	return v and v:IsA("StringValue") and v.Value or nil
end

function MatchSpec.IsReservedServer(): boolean
	return game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
end

function MatchSpec.Secure(td)
	if type(td) ~= "table" or td.Tutorial == true or type(td.Teams) ~= "table" or type(td.Mode) ~= "string" then return nil end
	if IS_STUDIO then return td end
	if not MatchSpec.IsReservedServer() then
		warn("[MatchSpec] match TeleportData on a public / VIP server: ignored")
		return nil
	end
	local spec = readOnce()
	if spec then
		return {
			Mode = spec.Mode, Ranked = spec.Ranked == true, Teams = spec.Teams,
			Queue = spec.Queue, MatchId = spec.MatchId, BayId = spec.BayId, Online = spec.Online, From = spec.From,
			Loadouts = type(td.Loadouts) == "table" and td.Loadouts or nil,
			Secured = true,
		}
	end
	if placeKind() == "Ranked" then
		warn("[MatchSpec] no server-side match spec on the Ranked place: refused")
		return nil
	end
	warn("[MatchSpec] no server-side match spec: playing casual from TeleportData")
	local d = table.clone(td)
	d.Ranked = false
	return d
end

return MatchSpec
