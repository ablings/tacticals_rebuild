-- ServerScriptService.MoveGuard [SECURE] (2026-10-17, overnight loophole audit): FLAG-ONLY speed check.
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
