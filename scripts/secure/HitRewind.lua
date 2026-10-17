-- ServerScriptService.Shared.HitRewind [SECURE] (2026-10-17, overnight loophole audit)
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
HitRewind.MaxWindow = 1.0    -- longest lag window looked back, seconds
HitRewind.MinWindow = 0.2

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
	local window = math.clamp(ping * 2 + 0.15, HitRewind.MinWindow, HitRewind.MaxWindow)
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
