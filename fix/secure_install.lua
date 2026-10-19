-- secure_install.lua : [SECURE] server-side match specs (notes/loophole_audit.md), 2026-10-17. Built by tools/secure_build.py
-- from scripts/secure/* (sources embedded below). Idempotent; the place is detected (lobby = Workspace.LobbyMap exists):
--   lobby       python tools/secure_build.py --run lobby        (studio 829eb64d)
--   match place python tools/secure_build.py --run match        (studio 331cb3a0)
--   UNDO        add UNDO to either line
-- New (attribute SecureInstall = true): ServerScriptService.Shared.MatchSpec + HitRewind, ServerScriptService.MoveGuard
--   (Script, flag-only speed check) (both places)
-- [SECURE] edits (string swap; UNDO swaps back; backups ServerStorage._RebuildRemoved.SECURE_<name>_Orig):
--   lobby: Managers.QueueManager (pad deploy writes the spec), Managers.MatchmakingManager (PLAY matchmaker writes the spec),
--          Managers.LobbyManager (a game pass is granted only after UserOwnsGamePassAsync confirms it)
--   match: Managers.RoundManager (joinMatchData plays only MatchSpec.Secure's answer; ranked dodge guard in Loading)
--   both:  Managers.CombatManager (claimed hits checked by HitRewind: lag-compensated, 1.25 studs instead of ~7)
-- ORDER: any time after match_place_build / ranked (independent of split: split works on the copies made from match_place_ref,
-- which already carry this). Re-run after tools/match_place_build.py rewrites RoundManager.
local UNDO = false --@UNDO

local SS = game:GetService("ServerStorage")
local SSS = game:GetService("ServerScriptService")
local CHS = game:GetService("ChangeHistoryService")
local IS_LOBBY = workspace:FindFirstChild("LobbyMap") ~= nil
local TAG = "SecureInstall"
local SOURCES = {}
--@@BEGIN SOURCES
SOURCES.MatchSpec = [=[-- ServerScriptService.Shared.MatchSpec [SECURE] (2026-10-17, overnight loophole audit)
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
]=]
SOURCES.HitRewind = [=[-- ServerScriptService.Shared.HitRewind [SECURE] (2026-10-17, overnight loophole audit)
-- Lag-compensated hit check for CombatManager. The old rule accepted a claimed hit point up to
-- part radius + HitPositionTolerance (6) studs from where the server sees the part, so a cheater could claim "Head" on any
-- shot that passed within ~7 studs of a head (free headshots / a bigger hitbox). Now the server keeps ~1 s of every
-- character's root CFrame and checks the claimed point against the claimed part where it WAS during the shooter's lag
-- window (ping x 2 + interpolation), with a small tolerance for animation pose (RewindTolerance, default 1.25 studs).
--   HitRewind.Start()                                        once, on the server
--   HitRewind.Check(shooter, victimCharacter, hitPart, hitPosition) -> ok, bestDistance
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local HitRewind = {}
HitRewind.Tolerance = 1.25   -- studs between the claimed point and the rewound part box (pose differences)
HitRewind.History = 1.2      -- seconds of root CFrames kept per character
HitRewind.MaxWindow = 0.25   -- longest lag window looked back, seconds (was 1.0). [LAGCAP] 2026-10-18, Edward: "if on my
                             -- screen i am fully behind a pillar" a shooter's stale view stops counting after this: favour
                             -- the shooter only up to a quarter second, like Overwatch / Valorant cap it
HitRewind.MinWindow = 0.1
HitRewind.Interp = 0.1       -- the shooter's client shows others ~this far in the past (interpolation)

local tracks = setmetatable({}, { __mode = "k" }) -- [Model] = { root = BasePart, t = {}, cf = {}, head = n }
local started = false

local function track(model: Model)
	if tracks[model] then return end
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if not (root and root:IsA("BasePart")) then return end
	tracks[model] = { root = root, t = {}, cf = {}, n = 0 }
end

local function onHumanoid(h: Instance)
	if h:IsA("Humanoid") and h.Parent and h.Parent:IsA("Model") then
		-- the root may arrive a moment after the humanoid (characters are built in pieces)
		task.defer(track, h.Parent)
	end
end

function HitRewind.Start()
	if started then return end
	started = true
	for _, d in workspace:GetDescendants() do if d:IsA("Humanoid") then onHumanoid(d) end end
	workspace.DescendantAdded:Connect(onHumanoid)
	local SLOTS = 90
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for model, tr in tracks do
			if not model.Parent or not tr.root.Parent then
				tracks[model] = nil
				continue
			end
			tr.n = tr.n % SLOTS + 1
			tr.t[tr.n] = now
			tr.cf[tr.n] = tr.root.CFrame
		end
	end)
end

-- distance from point p to a box (cframe cf, size s); 0 inside
local function boxDistance(cf: CFrame, s: Vector3, p: Vector3): number
	local lp = cf:PointToObjectSpace(p)
	local dx = math.max(math.abs(lp.X) - s.X / 2, 0)
	local dy = math.max(math.abs(lp.Y) - s.Y / 2, 0)
	local dz = math.max(math.abs(lp.Z) - s.Z / 2, 0)
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function HitRewind.Check(shooter: Player, victimCharacter: Model, hitPart: BasePart, hitPosition: Vector3): (boolean, number)
	local best = boxDistance(hitPart.CFrame, hitPart.Size, hitPosition)
	if best <= HitRewind.Tolerance then return true, best end
	local tr = tracks[victimCharacter]
	if not tr then
		track(victimCharacter)
		tr = tracks[victimCharacter]
	end
	if not tr or tr.n == 0 then
		-- no history yet (just spawned): the old, looser rule
		return best <= hitPart.Size.Magnitude / 2 + 6, best
	end
	-- the claimed part's offset from the root now (accessories included: their own CFrame follows the head)
	local rel = tr.root.CFrame:ToObjectSpace(hitPart.CFrame)
	local ok, ping = pcall(shooter.GetNetworkPing, shooter)
	ping = ok and tonumber(ping) or 0.1
	local window = math.clamp(ping * 2 + HitRewind.Interp, HitRewind.MinWindow, HitRewind.MaxWindow)
	local now = os.clock()
	for i, t in tr.t do
		if now - t <= window + 1 / 30 then
			local d = boxDistance(tr.cf[i] * rel, hitPart.Size, hitPosition)
			if d < best then best = d end
		end
	end
	return best <= HitRewind.Tolerance, best
end

return HitRewind
]=]
SOURCES.MoveGuard = [=[-- ServerScriptService.MoveGuard [SECURE] (2026-10-17, overnight loophole audit): FLAG-ONLY speed check.
-- Movement is client-driven (as in every Roblox game), so a speed hack is invisible to the server. This watches each
-- character's horizontal speed averaged over WINDOW seconds and flags averages above LIMIT studs/s (legit tops: cover
-- sprint 31, dive 34 in short bursts). It never moves or kicks anyone: it only logs, counts, and tells the admin audit.
--   player attribute MoveFlags = how many windows were flagged this session
--   server log: "[MoveGuard] <name> averaged 57.3 studs/s over 2 s (flag 3)"
--   AdminFramework audit (when present): command "moveguard"
-- Skipped: dead / anchored / seated characters, InCutscene, server teleports (a single step longer than TELEPORT studs
-- resets the window instead of counting), and the first seconds after a spawn.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SSS = game:GetService("ServerScriptService")

local WINDOW = 2
local LIMIT = 42
local TELEPORT = 40 -- one Heartbeat step longer than this = a server teleport (spawn, duel arena, cutscene)
local SPAWN_GRACE = 3
local FLAT = Vector3.new(1, 0, 1)

local auditOk, Audit = pcall(function() return require(SSS:WaitForChild("AdminFramework", 10):WaitForChild("Audit", 5)) end)
if not auditOk then Audit = nil end

local state = {} -- [Player] = { last = Vector3, dist = 0, t0 = os.clock(), spawnedAt = os.clock() }

local function reset(s, pos)
	s.last = pos
	s.dist = 0
	s.t0 = os.clock()
end

local function flag(player: Player, avg: number)
	local n = (player:GetAttribute("MoveFlags") or 0) + 1
	player:SetAttribute("MoveFlags", n)
	local msg = ("[MoveGuard] %s averaged %.1f studs/s over %d s (flag %d)"):format(player.Name, avg, WINDOW, n)
	warn(msg)
	if Audit and Audit.Log then
		pcall(Audit.Log, { admin = "MoveGuard", adminId = 0, level = "System", command = "moveguard", args = ("%.1f"):format(avg),
			targets = player.Name, ok = true, result = msg, source = "server" })
	end
end

local function hook(player: Player)
	player.CharacterAdded:Connect(function()
		state[player] = { last = nil, dist = 0, t0 = os.clock(), spawnedAt = os.clock() }
	end)
end
Players.PlayerAdded:Connect(hook)
for _, p in Players:GetPlayers() do hook(p) end
Players.PlayerRemoving:Connect(function(p) state[p] = nil end)

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local s = state[player]
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if not (s and root and hum) then continue end
		local pos = root.Position * FLAT
		if hum.Health <= 0 or root.Anchored or hum.Sit or player:GetAttribute("InCutscene") or now - s.spawnedAt < SPAWN_GRACE
			or not s.last then
			reset(s, pos)
			continue
		end
		local step = (pos - s.last).Magnitude
		if step > TELEPORT then
			reset(s, pos)
			continue
		end
		s.dist += step
		s.last = pos
		local elapsed = now - s.t0
		if elapsed >= WINDOW then
			local avg = s.dist / elapsed
			if avg > LIMIT then flag(player, avg) end
			reset(s, pos)
		end
	end
end)
]=]
--@@END SOURCES
local rec = CHS:TryBeginRecording("SECURE install" .. (UNDO and " UNDO" or ""))
local bin = SS:FindFirstChild("_RebuildRemoved") or Instance.new("Folder")
bin.Name = "_RebuildRemoved"; bin.Parent = SS
local log = { "place: " .. (IS_LOBBY and "lobby" or "match") }
local function say(...) local t = {} for _, v in ipairs({ ... }) do table.insert(t, tostring(v)) end table.insert(log, table.concat(t, " ")) end
local managers = SSS:FindFirstChild("ServerScripts")
managers = managers and managers:FindFirstChild("[Server] Init")
managers = managers and managers:FindFirstChild("GameManager")
managers = managers and managers:FindFirstChild("Managers")
assert(managers, "GameManager.Managers not found")

local REQ = 'local MatchSpec = require(game:GetService("ServerScriptService").Shared.MatchSpec) -- [SECURE]\n'

local EDITS = IS_LOBBY and {
	-- QueueManager.deploy: keep the reserved server's id and write the spec before teleporting
	{ "QueueManager",
		"\t\tlocal okReserve, code = pcall(TeleportService.ReserveServer, TeleportService, placeId)\n",
		"\t\tlocal okReserve, code, specId = pcall(TeleportService.ReserveServer, TeleportService, placeId) -- [SECURE] specId\n" },
	{ "QueueManager",
		"\t\tlocal options = Instance.new(\"TeleportOptions\")\n\t\toptions.ReservedServerAccessCode = code\n",
		"\t\t-- [SECURE] the match itself is written server-side (MatchSpec): TeleportData can be faked by the client.\n"
			.. "\t\t-- A ranked bay whose spec can't be written doesn't start (the Ranked place would refuse it).\n"
			.. "\t\tlocal MatchSpec = require(game:GetService(\"ServerScriptService\").Shared.MatchSpec)\n"
			.. "\t\tif not MatchSpec.Write(specId, { Mode = bay.mode, Ranked = bay.ranked == true, BayId = bay.id, Teams = teams, From = game.PlaceId }) and bay.ranked then\n"
			.. "\t\t\tfor _, p in players do Remotes.Notify(p, \"Couldn't start the match server. Try again.\", \"bad\") end\n"
			.. "\t\t\tresetBay(bay, false)\n"
			.. "\t\t\treturn\n"
			.. "\t\tend\n"
			.. "\t\tlocal options = Instance.new(\"TeleportOptions\")\n\t\toptions.ReservedServerAccessCode = code\n" },
	-- MatchmakingManager.startMatch: same for the PLAY queues
	{ "MatchmakingManager",
		"\t\tlocal ok, res = pcall(TeleportService.ReserveServer, TeleportService, placeId)\n",
		"\t\tlocal ok, res, sid = pcall(TeleportService.ReserveServer, TeleportService, placeId) -- [SECURE] sid\n" },
	{ "MatchmakingManager",
		"\t\tcode = res\n\tend\n",
		"\t\tcode = res\n\t\tspecId = sid -- [SECURE]\n\tend\n" },
	{ "MatchmakingManager",
		"local function startMatch(q, group, matchId: string): boolean\n\tlocal code = \"STUDIO\"\n",
		"local function startMatch(q, group, matchId: string): boolean\n\tlocal code = \"STUDIO\"\n\tlocal specId = nil -- [SECURE] the reserved server's PrivateServerId\n" },
	{ "MatchmakingManager",
		"\tfor _, e in group do\n\t\tpcall(function() results:SetAsync(tostring(e.v.u), result, RESULT_TTL) end)\n\tend\n",
		"\t-- [SECURE] the match itself is written server-side (MatchSpec): TeleportData can be faked by the client.\n"
			.. "\t-- A ranked match whose spec can't be written isn't started (the players are unclaimed and matched again).\n"
			.. "\tif not IS_STUDIO then\n"
			.. "\t\tlocal MatchSpec = require(ServerScriptService.Shared.MatchSpec)\n"
			.. "\t\tlocal wrote = MatchSpec.Write(specId, { Mode = q.Mode, Ranked = q.Ranked == true, Queue = q.Id, MatchId = matchId, Teams = result.teams, Online = true, From = game.PlaceId })\n"
			.. "\t\tif not wrote and q.Ranked then return false end\n"
			.. "\tend\n"
			.. "\tfor _, e in group do\n\t\tpcall(function() results:SetAsync(tostring(e.v.u), result, RESULT_TTL) end)\n\tend\n" },
	-- LobbyManager: PromptGamePassPurchaseFinished alone is not proof of purchase (Roblox: verify with UserOwnsGamePassAsync)
	{ "LobbyManager",
		"MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)\n\tif not purchased then return end\n",
		"MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)\n\tif not purchased then return end\n"
			.. "\t-- [SECURE] the event alone is not proof of purchase: ask Roblox before granting\n"
			.. "\tlocal okOwn, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)\n"
			.. "\tif not (okOwn and owns) then warn(\"[LobbyManager] pass \" .. tostring(passId) .. \" not confirmed for \" .. player.Name) return end\n" },
} or {
	-- RoundManager.runMatchServer: dodge guard. A ranked arrival is marked pending at once, so leaving during Loading (after
	-- seeing the opponent on the loading screen) pays the normal leave at the next join; the real tiers overwrite the mark
	-- after Loading; a cancelled match (the other team never came) clears it for everyone here.
	-- RankedCore.Config.DodgePenalty = false turns it off.
	{ "RoundManager",
		"\t\tp:SetAttribute(\"Team\", side)\n",
		"\t\tp:SetAttribute(\"Team\", side)\n"
			.. "\t\t-- [SECURE] dodge guard: marked pending on arrival (a leave during Loading pays at the next join)\n"
			.. "\t\tif first.Ranked == true and not IS_STUDIO and RankedCore.Config.DodgePenalty ~= false then\n"
			.. "\t\t\ttask.spawn(function()\n"
			.. "\t\t\t\tlocal t = RankedCore.TierOf(RankedServer.EloOf(p, first.Mode))\n"
			.. "\t\t\t\tRankedServer.MarkPending(p, first.Mode, t, t)\n"
			.. "\t\t\tend)\n"
			.. "\t\tend\n" },
	{ "RoundManager",
		"\tif cancel then\n\t\tsetState(\"Cancelled\", 5)\n",
		"\tif cancel then\n\t\tsetState(\"Cancelled\", 5)\n"
			.. "\t\t-- [SECURE] dodge guard: a cancelled match costs nobody here anything\n"
			.. "\t\tif first.Ranked == true and not IS_STUDIO then\n"
			.. "\t\t\tfor _, p in Players:GetPlayers() do task.spawn(RankedServer.ClearPending, p, first.Mode) end\n"
			.. "\t\tend\n" },
	-- RoundManager.joinMatchData: a live server plays only what MatchSpec.Secure returns
	{ "RoundManager",
		"\tlocal ok, data = pcall(function() return player:GetJoinData().TeleportData end)\n"
			.. "\tif ok and type(data) == \"table\" and type(data.Teams) == \"table\" and type(data.Mode) == \"string\" and data.Tutorial ~= true then return data end\n",
		"\tlocal ok, data = pcall(function() return player:GetJoinData().TeleportData end)\n"
			.. "\t-- [SECURE] live servers: the match comes from the lobby's server-side spec (TeleportData can be faked by the client);\n"
			.. "\t-- a public / VIP server never runs a match. Studio keeps the TeleportData path below.\n"
			.. "\tif not IS_STUDIO then\n"
			.. "\t\treturn require(game:GetService(\"ServerScriptService\").Shared.MatchSpec).Secure(ok and data or nil)\n"
			.. "\tend\n"
			.. "\tif ok and type(data) == \"table\" and type(data.Teams) == \"table\" and type(data.Mode) == \"string\" and data.Tutorial ~= true then return data end\n" },
}

-- both places: CombatManager's claimed-hit check goes through HitRewind
-- (the lobby's CombatManager has the [DUEL] MatchState require; the match place's doesn't)
local COMBAT_ANCHOR = IS_LOBBY and "local MatchState = require(Shared.MatchState)\n" or "local RateLimiter = require(Shared.Madwork.RateLimiter)\n"
local COMMON = {
	{ "CombatManager",
		COMBAT_ANCHOR,
		COMBAT_ANCHOR
			.. "-- [SECURE] lag-compensated hit check (HitRewind keeps ~1 s of every character's root CFrame)\n"
			.. "local HitRewind = require(game:GetService(\"ServerScriptService\").Shared.HitRewind)\n"
			.. "HitRewind.Start()\n" },
	{ "CombatManager",
		"\tlocal partReach = hitPart.Size.Magnitude / 2 + V.HitPositionTolerance\n"
			.. "\tif (hitPosition - hitPart.Position).Magnitude > partReach then return finish(\"hit too far from target\") end\n",
		"\t-- [SECURE] the claimed point must touch the claimed part where it was during the shooter's lag (HitRewind);\n"
			.. "\t-- the old rule (6 studs + the part's size from where the server sees it) allowed free headshots\n"
			.. "\tlocal hitOk, hitGap = HitRewind.Check(player, victimCharacter, hitPart, hitPosition)\n"
			.. "\tif not hitOk then return finish((\"hit too far from target (%.1f studs)\"):format(hitGap)) end\n" },
}
for _, e in COMMON do table.insert(EDITS, e) end

local function backup(s)
	local name = "SECURE_" .. s.Name .. "_Orig"
	if not bin:FindFirstChild(name) and not s.Source:find("[SECURE]", 1, true) then
		local b = s:Clone(); b.Name = name; b:ClearAllChildren()
		if b:IsA("BaseScript") then b.Disabled = true end
		b.Parent = bin
	end
end

local shared = SSS:FindFirstChild("Shared")
if UNDO then
	for i = #EDITS, 1, -1 do
		local e = EDITS[i]
		local s = managers:FindFirstChild(e[1])
		if s then
			local a, b = s.Source:find(e[3], 1, true)
			if a then s.Source = s.Source:sub(1, a - 1) .. e[2] .. s.Source:sub(b + 1); say("UNDO edit", i, s.Name)
			else say("edit", i, s.Name, "not applied") end
		end
	end
	local m = shared and shared:FindFirstChild("MatchSpec")
	if m and m:GetAttribute(TAG) then m:Destroy(); say("removed MatchSpec") end
	local hr = shared and shared:FindFirstChild("HitRewind")
	if hr and hr:GetAttribute(TAG) then hr:Destroy(); say("removed HitRewind") end
	local mg = SSS:FindFirstChild("MoveGuard")
	if mg and mg:GetAttribute(TAG) then mg:Destroy(); say("removed MoveGuard") end
else
	assert(shared, "ServerScriptService.Shared not found")
	-- check every edit first, so a missing text changes nothing at all
	for i, e in ipairs(EDITS) do
		local s = managers:FindFirstChild(e[1])
		assert(s, e[1] .. " not found")
		assert(s.Source:find(e[3], 1, true) or s.Source:find(e[2], 1, true), "edit " .. i .. " " .. e[1] .. ": original text not found (nothing changed)")
	end
	local m = shared:FindFirstChild("MatchSpec")
	if m and not m:GetAttribute(TAG) then error("MatchSpec exists and is not ours") end
	if not m then
		m = Instance.new("ModuleScript"); m.Name = "MatchSpec"; m:SetAttribute(TAG, true); m.Parent = shared
		say("new", m:GetFullName())
	end
	m.Source = SOURCES.MatchSpec
	local hr = shared:FindFirstChild("HitRewind")
	if hr and not hr:GetAttribute(TAG) then error("HitRewind exists and is not ours") end
	if not hr then
		hr = Instance.new("ModuleScript"); hr.Name = "HitRewind"; hr:SetAttribute(TAG, true); hr.Parent = shared
		say("new", hr:GetFullName())
	end
	hr.Source = SOURCES.HitRewind
	local mg = SSS:FindFirstChild("MoveGuard")
	if mg and not mg:GetAttribute(TAG) then error("MoveGuard exists and is not ours") end
	if not mg then
		mg = Instance.new("Script"); mg.Name = "MoveGuard"; mg:SetAttribute(TAG, true); mg.Parent = SSS
		say("new", mg:GetFullName())
	end
	mg.Source = SOURCES.MoveGuard
	for i, e in ipairs(EDITS) do
		local s = managers:FindFirstChild(e[1])
		assert(s, e[1] .. " not found")
		if s.Source:find(e[3], 1, true) then say("edit", i, s.Name, "already in")
		else
			local a, b = s.Source:find(e[2], 1, true)
			assert(a, "edit " .. i .. " " .. s.Name .. ": original text not found")
			backup(s)
			s.Source = s.Source:sub(1, a - 1) .. e[3] .. s.Source:sub(b + 1)
			say("edit", i, s.Name, "applied")
		end
	end
end
if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
return table.concat(log, "\n")
