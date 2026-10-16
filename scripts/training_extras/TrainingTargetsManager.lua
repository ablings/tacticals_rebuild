-- Managers/TrainingTargetsManager (server, lobby place): floating 1-HP bullseyes in Training (notes/training_extras_done.md).
-- Targets: LobbyMap.Training.Extras.Bullseyes (Ball parts, tag TrainingTarget, built by fix/place_training.lua). Each is
-- CanQuery = true while up, so the shooter's own raycast (WeaponController) stops on it: the first thing a bullet meets wins.
--   * bullseye first -> the client sends no character hit (no dummy damage) and the claimed end point is on the target;
--     CombatManager's server wall check (WeaponUtil.IsPathClear) also refuses a dummy hit through a live target.
--   * dummy first    -> the shot's end point is on the dummy, before any target behind it, so nothing pops.
-- Hit test: ShootableManager.OnShot(origin, endPos, shooter) from CombatManager.afterShot (accepted shots only).
-- A pop hides the target (face off, CanQuery off) for Respawn seconds and tells clients (Events.Training.TargetPop).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WeaponUtil = require(ReplicatedStorage.Modules.Shared.WeaponUtil)
local function why(_reason) end   -- reason of a non-pop (the Studio-only workspace trace attribute was removed in lap1)
local manager = {}

local ok, TX = pcall(require, ReplicatedStorage.Modules.Shared.Config.TrainingConfig)
local live = {}          -- [Part] = true while up
local popEvent

local function pop(target: BasePart, shooter: Player)
	live[target] = nil
	target.CanQuery = false
	target:SetAttribute("Popped", true)
	local face = target:FindFirstChild("Face"); if face then face.Enabled = false end
	popEvent:FireAllClients(target.Position, shooter.UserId)
	task.delay(TX.Bullseyes.Respawn, function()
		if not target.Parent then return end
		target.CanQuery = true
		target:SetAttribute("Popped", nil)
		if face then face.Enabled = true end
		live[target] = true
	end)
end

function manager.OnShot(origin: Vector3, endPos: Vector3, shooter: Player?)
	if not (ok and popEvent and TX.On("Bullseyes")) then return why("off") end
	if not shooter or shooter:GetAttribute("InTraining") ~= true then return why("not in training") end
	if typeof(origin) ~= "Vector3" or typeof(endPos) ~= "Vector3" then return end
	local seg = endPos - origin
	local len = seg.Magnitude
	if len < 0.1 or len > TX.Bullseyes.MaxRange + 5 then return end
	local dir = seg / len
	local R = TX.Bullseyes.Radius
	local best, bestEntry
	for t in live do
		local v = t.Position - origin
		local a = v:Dot(dir)
		if a > 0 then
			local d = (v - dir * a).Magnitude
			if d <= R - 0.02 then   -- the client's own ray (same origin + end point) went through the ball
				-- where the bullet enters the ball: it must be at or before the shot's end point (no hits behind a dummy)
				local entry = a - math.sqrt(math.max(R * R - math.min(d, R) ^ 2, 0))
				if entry <= len + 0.05 and (not bestEntry or entry < bestEntry) then best, bestEntry = t, entry end
			end
		end
	end
	if not best then return why("no target on the shot") end
	-- first thing hit wins: from the muzzle toward the target, the first world part must be that target (walls, other
	-- live targets in front; characters ignored as in WeaponUtil.IsPathClear)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = WeaponUtil.GetAllCharacters()
	local r = workspace:Raycast(origin, (best.Position - origin) * 1.05, params)
	if r and r.Instance ~= best then return why("blocked by " .. r.Instance.Name) end
	pop(best, shooter)
	why("popped " .. best:GetFullName())
end

function manager.Start()
	if not (ok and TX.On("Bullseyes")) then return end
	local ev = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Training")
	popEvent = ev:FindFirstChild("TargetPop")
	if not popEvent then popEvent = Instance.new("RemoteEvent"); popEvent.Name = "TargetPop"; popEvent.Parent = ev end
	local map = workspace:WaitForChild("LobbyMap", 30)
	local t = map and map:WaitForChild("Training", 30)
	local ex = t and t:WaitForChild("Extras", 10)
	local folder = ex and ex:WaitForChild("Bullseyes", 5)
	if not folder then return end
	for _, p in folder:GetChildren() do
		if p:IsA("BasePart") then
			p.CanQuery = true; p:SetAttribute("Popped", nil)
			local face = p:FindFirstChild("Face"); if face then face.Enabled = true end
			live[p] = true
		end
	end
end

return manager
