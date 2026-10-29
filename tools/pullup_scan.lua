-- tools/pullup_scan.lua [MOVE1029] READ-ONLY: every pull-up the CoverController's rule allows on a map (Edit or Play).
-- Set ROOTS below (paths from game) before running: python tools/run_luau_at.py <studio id> tools/pullup_scan.lua
-- For each collidable part's side faces it samples standing spots 1.4 studs out on the floor below, then runs the same rule as
-- CoverController.findLedge + climbSpot (forward rays at 3 heights, reach PullUpReach + 1, top <= floor + PullUpMaxHeight,
-- PullUpStandDepth footing, headroom, the edge path, the ceiling over the way up, NoClimb on any part touched).
-- Returns one line per (face part -> top part) with the count of spots, the rise and a sample spot.
local ROOTS = { "Workspace.Arena" } --@ROOTS
local RS = game:GetService("ReplicatedStorage")
local cfg = loadstring(RS.Modules.Shared.Config.CoverConfig.Source)()
local mrSrc = RS.Modules.Shared:FindFirstChild("MoveRules")
assert(mrSrc, "install fix/move_rework_1029.lua first (MoveRules)")
local MoveRules = loadstring(mrSrc.Source)()
local function resolve(path)
	local node = game
	for seg in path:gmatch("[^%.]+") do node = node and node:FindFirstChild(seg) end
	return node
end
local ignore = {}
for _, m in workspace:GetChildren() do
	for _, n in { "Props", "Shootables" } do local f = m:FindFirstChild(n) if f then table.insert(ignore, f) end end
	if m:FindFirstChildOfClass("Humanoid") then table.insert(ignore, m) end
end
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = ignore
params.IgnoreWater = true
local function cast(o, d) return workspace:Raycast(o, d, params) end
local ROOT_OFF, HEAD_ABOVE_ROOT = 3, 2.1
local reach = (cfg.PullUpReach or 2.2) + 1
local half = (cfg.PullUpStandDepth or 1.4) / 2

-- the client rule, from a root position facing dir; returns face part, top part, stand, rise
local function tryFrom(root, dir)
	local below = cast(root, Vector3.new(0, -(ROOT_OFF + 8), 0))
	local floorY = below and below.Position.Y or (root.Y - ROOT_OFF)
	for _, dy in { 0.8, -0.5, -1.6 } do
		local hit = cast(root + Vector3.new(0, dy, 0), dir * reach)
		if hit and hit.Instance.CanCollide and Vector3.new(hit.Normal.X, 0, hit.Normal.Z).Magnitude > 0.7
			and -(Vector3.new(hit.Normal.X, 0, hit.Normal.Z).Unit):Dot(dir) > 0.5 and not MoveRules.IsNoClimb(hit.Instance) then
			local part = hit.Instance
			local normal = Vector3.new(hit.Normal.X, 0, hit.Normal.Z).Unit
			-- depth of the part behind the face (corners), like coverFromHit
			local maxDepth = 0
			local h = part.Size / 2
			for _, sx in { -1, 1 } do for _, sy in { -1, 1 } do for _, sz in { -1, 1 } do
				local corner = part.CFrame:PointToWorldSpace(Vector3.new(sx * h.X, sy * h.Y, sz * h.Z))
				maxDepth = math.max(maxDepth, -(corner - hit.Position):Dot(normal))
			end end end
			local inset = math.clamp(maxDepth / 2, 0.8, 1.6)
			local at = hit.Position - normal * inset
			local maxTop = floorY + (cfg.PullUpMaxHeight or 5.1)
			local down = cast(Vector3.new(at.X, maxTop + 0.5, at.Z), Vector3.new(0, -(maxTop + 1 - floorY), 0))
			if down and down.Normal.Y >= 0.7 and not MoveRules.IsNoClimb(down.Instance) and MoveRules.PullUpHeightOk(floorY, down.Position.Y, cfg) then
				local topY = down.Position.Y
				local ok = true
				for _, o in { Vector3.new(half, 0, 0), Vector3.new(-half, 0, 0), Vector3.new(0, 0, half), Vector3.new(0, 0, -half) } do
					local d2 = cast(Vector3.new(at.X + o.X, topY + 0.6, at.Z + o.Z), Vector3.new(0, -1.2, 0))
					if not d2 or math.abs(d2.Position.Y - topY) > 0.3 or MoveRules.IsNoClimb(d2.Instance) then ok = false break end
				end
				local headY = root.Y + HEAD_ABOVE_ROOT
				if ok and topY + ROOT_OFF * 2 > headY and cast(Vector3.new(root.X, headY - 0.3, root.Z), Vector3.new(0, topY + ROOT_OFF * 2 + 0.3 - headY, 0)) then ok = false end
				if ok and cast(Vector3.new(at.X, topY + 0.2, at.Z), Vector3.new(0, ROOT_OFF * 2 + 0.3, 0)) then ok = false end
				local edge = Vector3.new(root.X, topY + 0.6, root.Z)
				if ok and cast(edge, Vector3.new(at.X, topY + 0.6, at.Z) - edge) then ok = false end
				if ok then return part, down.Instance, Vector3.new(at.X, topY + ROOT_OFF, at.Z), topY - floorY end
			end
		end
	end
	return nil
end

local found = {}
local order = {}
local spots = 0
for _, path in ROOTS do
	local rootModel = resolve(path)
	assert(rootModel, "no " .. path)
	for _, p in rootModel:GetDescendants() do
		if p:IsA("BasePart") and p.CanCollide and p.Size.Y >= 1 then
			local top = p.Position.Y + p.Size.Y / 2
			for _, axis in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
				local n = p.CFrame:VectorToWorldSpace(axis)
				if math.abs(n.Y) < 0.3 then
					n = Vector3.new(n.X, 0, n.Z).Unit
					local t = Vector3.yAxis:Cross(n)
					local faceHalf = math.abs(p.CFrame:VectorToObjectSpace(t):Dot(p.Size / 2))
					local depthHalf = math.abs(p.CFrame:VectorToObjectSpace(n):Dot(p.Size / 2))
					local steps = math.clamp(math.floor(faceHalf * 2 / 2), 0, 60)
					for k = -steps, steps do
						local along = (steps == 0) and 0 or (k / steps) * math.max(faceHalf - 0.6, 0)
						local base = p.Position + n * (depthHalf + 1.4) + t * along
						-- the floor a player could stand on beside this face, up to PullUpMaxHeight below its top
						local fl = cast(Vector3.new(base.X, top - 1.0, base.Z), Vector3.new(0, -((cfg.PullUpMaxHeight or 5.1) + 0.2), 0))
						if fl and fl.Normal.Y > 0.7 then
							local root = Vector3.new(base.X, fl.Position.Y + ROOT_OFF, base.Z)
							-- a body fits there
							local ob = OverlapParams.new()
							ob.FilterType = Enum.RaycastFilterType.Exclude
							ob.FilterDescendantsInstances = ignore
							local clear = true
							for _, q in workspace:GetPartBoundsInBox(CFrame.new(root + Vector3.new(0, 0.3, 0)), Vector3.new(1.6, 4.4, 1.0), ob) do
								if q.CanCollide then clear = false break end
							end
							if clear then
								spots += 1
								local face, topPart, stand, rise = tryFrom(root, -n)
								if face then
									local key = face:GetFullName() .. " -> " .. topPart:GetFullName()
									if not found[key] then found[key] = { n = 0, rise = rise, from = root, stand = stand } table.insert(order, key) end
									found[key].n += 1
								end
							end
						end
					end
				end
			end
		end
	end
end
local lines = {}
for _, key in order do
	local f = found[key]
	table.insert(lines, ("%s x%d rise %.2f from (%.1f, %.1f, %.1f)"):format(key, f.n, f.rise, f.from.X, f.from.Y, f.from.Z))
end
return ("%d standing spots tried, %d ways up\n"):format(spots, #order) .. table.concat(lines, "\n")
