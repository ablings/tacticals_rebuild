-- ReplicatedStorage.Modules.Shared.MoveRules [MOVE1029] (2026-10-29, Edward's five mechanics; fix/move_rework_1029.lua)
-- Pure rules shared by the client controllers and the server (CombatManager, HitRewind, MovementManager), so both sides
-- use the same numbers. No state, no remotes: unit-tested by fix/move_rework_1029_tests.lua.
--   Lean        LeanWaist(lean, cfg) -> CFrame to put on the Waist joint's C0 (procedural lean; also the hitbox model)
--               LeanPart(rootCF, partCF, partName, lean, cfg) -> where an upper-body part is with that lean (server rewind)
--               Ease(current, target, dt, cfg) -> the lean value one frame later (every client and the server ease alike)
--   Facing      FlatAngle(a, b) -> degrees between two directions on the ground plane (nil when one is near vertical)
--               FacingOk(dir, facings, tolerance) -> ok, bestAngle (any facing in the list within tolerance)
--               FacingTolerance(state, cfg) -> degrees the server allows for a shot in that cover state
--   Peek gate   PeekReady(blend, bodyYawDeg, aimYawDeg, cfg) -> true when a peek shot may leave
--   Pull-up     PullUpHeightOk(floorY, topY, cfg) -> ok, why   (the ledge is reachable from this floor)
--               IsNoClimb(part) -> true when the part or any ancestor has NoClimb = true
--   Wall cover  IsWallCover(part) -> true for a wall proxy (WallProxy = true) on a map whose WallCover is on
local MoveRules = {}

-- Parts the waist carries (R15): everything above the LowerTorso
MoveRules.UPPER = {
	UpperTorso = true, Head = true, LeftUpperArm = true, LeftLowerArm = true, LeftHand = true,
	RightUpperArm = true, RightLowerArm = true, RightHand = true,
}
-- The Waist joint's pivot in root space for the default R15 body (measured in Play 2026-10-29: UpperTorso * Waist.C1 sits
-- 2.31 above the floor, the root 3.0: pivot 0.69 below the root). Clients bend the real joint; the server's rewind model
-- pivots here. With LeanRoll 17 / LeanShift 0.35 the shoulder moves out ~0.73 studs and the head ~1.0.
MoveRules.WAIST_PIVOT = Vector3.new(0, -0.69, 0)

local function knob(cfg, name, default)
	local v = cfg and cfg[name]
	if type(v) == "number" then return v end
	return default
end

-- lean in [-1, 1], + = out to the body's right. Roll the upper body out about the waist and shift it out a little.
-- Waist C0 lives in LowerTorso space (X right, Y up, Z back): a roll of -a about Z tips the top toward +X (right).
function MoveRules.LeanWaist(lean: number, cfg): CFrame
	lean = math.clamp(tonumber(lean) or 0, -1, 1)
	if lean == 0 then return CFrame.identity end
	local roll = math.rad(knob(cfg, "LeanRoll", 17)) * lean
	local shift = knob(cfg, "LeanShift", 0.35) * lean
	return CFrame.new(shift, 0, 0) * CFrame.Angles(0, 0, -roll)
end

-- Where an upper-body part is when the body leans `lean`, given where it is unleaned (the server's pose). Lower-body parts
-- and lean 0 come back unchanged.
function MoveRules.LeanPart(rootCF: CFrame, partCF: CFrame, partName: string, lean: number, cfg): CFrame
	if not MoveRules.UPPER[partName] or (tonumber(lean) or 0) == 0 then return partCF end
	local pivot = rootCF * CFrame.new(MoveRules.WAIST_PIVOT)
	local rel = pivot:ToObjectSpace(partCF)
	return pivot * MoveRules.LeanWaist(lean, cfg) * rel
end

-- One frame of easing toward the target lean (linear, LeanTime from 0 to full)
function MoveRules.Ease(current: number, target: number, dt: number, cfg): number
	local step = dt / math.max(knob(cfg, "LeanTime", 0.12), 1e-3)
	if current < target then return math.min(current + step, target) end
	return math.max(current - step, target)
end

-- Degrees between two directions on the ground plane; nil when either is nearly vertical (shooting straight up / down)
function MoveRules.FlatAngle(a: Vector3, b: Vector3): number?
	local fa, fb = Vector3.new(a.X, 0, a.Z), Vector3.new(b.X, 0, b.Z)
	if fa.Magnitude < 0.25 or fb.Magnitude < 0.25 then return nil end
	return math.deg(math.acos(math.clamp(fa.Unit:Dot(fb.Unit), -1, 1)))
end

-- Is the shot direction within `tolerance` degrees of any of these facings (look vectors)? Returns ok, best angle.
function MoveRules.FacingOk(dir: Vector3, facings: { Vector3 }, tolerance: number): (boolean, number)
	local best = math.huge
	for _, f in facings do
		local a = MoveRules.FlatAngle(dir, f)
		if a == nil then return true, 0 end
		if a < best then best = a end
	end
	if #facings == 0 then return true, 0 end
	return best <= tolerance, best
end

-- What the server allows for a shot in this cover state (character attribute CoverState), `dist` studs long: the gun and the
-- over-the-shoulder camera sit a little apart, so a shot at something close leaves at an angle to the body even when the body
-- faces the crosshair exactly (FacingParallaxStuds, measured: an honest shot at a shelf ~7 studs away left 25 deg off)
function MoveRules.FacingTolerance(state: string?, cfg, dist: number?): number
	local base = knob(cfg, "FireFacingTolerance", 22)
	if state == "Blind" or state == "Move" then base = knob(cfg, "BlindFacingTolerance", 115) end
	local d = math.max(tonumber(dist) or 1e4, 0.5)
	return base + math.deg(math.atan(knob(cfg, "FacingParallaxStuds", 2) / d))
end

local function wrapDeg(a: number): number
	return (a + 180) % 360 - 180
end

-- A peek shot may leave once the peek pose is full (blend 1) and the body faces within PeekFireMaxAngle of the aim
function MoveRules.PeekReady(blend: number, bodyYawDeg: number, aimYawDeg: number, cfg): boolean
	if blend < 0.999 then return false end
	return math.abs(wrapDeg(bodyYawDeg - aimYawDeg)) <= knob(cfg, "PeekFireMaxAngle", 10)
end

-- The ledge top must be above a step and no higher than the standing head top over the floor you're on
function MoveRules.PullUpHeightOk(floorY: number, topY: number, cfg): (boolean, string?)
	local rise = topY - floorY
	if rise < knob(cfg, "PullUpMinHeight", 1.2) then return false, "too low (a step)" end
	if rise > knob(cfg, "PullUpMaxHeight", 5.1) + 0.05 then return false, ("too high (%.2f over the floor)"):format(rise) end
	return true, nil
end

-- NoClimb on the part or any ancestor (a whole map, a folder, one part)
function MoveRules.IsNoClimb(part: Instance?): boolean
	local node = part
	while node and node ~= game do
		if node:GetAttribute("NoClimb") == true then return true end
		node = node.Parent
	end
	return false
end

-- A NotCover wall proxy that counts as tall cover because its map turned WallCover on (MapInfo.WallCover, map attribute)
function MoveRules.IsWallCover(part: Instance?): boolean
	if not part or part:GetAttribute("WallProxy") ~= true then return false end
	local node = part.Parent
	while node and node ~= game do
		local v = node:GetAttribute("WallCover")
		if v ~= nil then return v == true end
		node = node.Parent
	end
	return false
end

-- Cover test used everywhere a part may be cover: collides, and either not NotCover or a wall-cover proxy
function MoveRules.CoverPart(part: Instance?): boolean
	if not part or not part:IsA("BasePart") or not part.CanCollide then return false end
	if part:GetAttribute("NotCover") then return MoveRules.IsWallCover(part) end
	return true
end

return MoveRules
