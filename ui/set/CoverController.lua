local __TG = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("TrainingGate"))
-- StarterPlayer/StarterPlayerScripts/Client/Controllers/CoverController (ModuleScript)
-- GTA-style cover.
--   Q near a wall/pillar/crate      -> ease into cover. A/D slide along it. Q or jump leaves.
--   Q with the crosshair on cover further away (in range) -> move to it and take cover:
--       crouched dash (default) / tactical roll (short hop to low cover) / sprint dash (hold Shift)
--   Space behind low cover          -> vault over it (you can fire mid-vault, at blind-fire accuracy)
--   C behind tall cover             -> crouch / stand
--   Tall cover: aiming only works near an edge (you step out past it). Away from an edge,
--     holding aim does nothing, so you can't "aim into the wall".
--   Low cover: where your crosshair is when you aim picks the peek:
--     over the top -> rise up; past the left/right end -> lean out around that side.
--
-- Client-side movement only. The server doesn't trust "in cover": it validates shots against
-- where your character actually is, so none of this can be used to cheat.
--
-- API: IsInCover, IsPeeking, IsCrouched, IsBlindFiring, IsMoving, BlocksAim, BlindFire

-- // Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
RunService = __TG.RunService
local ContextActionService = game:GetService("ContextActionService")
ContextActionService = __TG.ContextActionService
local UserInputService = game:GetService("UserInputService")
UserInputService = __TG.UserInputService
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- // Config
local Shared = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"):WaitForChild("CoverConfig"))

-- // Constants
local RENDER_NAME = "CoverUpdate"
local RENDER_PRIORITY = Enum.RenderPriority.Camera.Value - 1 -- before the camera, which may then set facing while aiming
local FLAT = Vector3.new(1, 0, 1)

local localPlayer = Players.LocalPlayer

-- [SET] the duel arena: any Workspace child tagged DuelArena (lobby duels, any map), else workspace.Warehouse (match place)
local function arenaMap()
	for _, c in workspace:GetChildren() do
		if c:GetAttribute("DuelArena") ~= nil then return c end
	end
	-- (2026-10-20) the match place holds several maps (Warehouse, PracticeRange): use the one this match is on
	local chosen = ReplicatedStorage:GetAttribute("ArenaMap") or ReplicatedStorage:GetAttribute("MapChosen")
	return (typeof(chosen) == "string" and workspace:FindFirstChild(chosen)) or workspace:FindFirstChild("Warehouse")
end

-- [SET] Settings > Hotkeys / Controls (UI session 2026-10-16): binds and settings arrive as player attributes
local Binds = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("Binds"))
-- [ABILITY] the weapon speed ladder (WeaponConfig MoveSpeed): lighter guns dash to cover and vault faster
local WeaponConfig = require(Shared:WaitForChild("Config"):WaitForChild("WeaponConfig"))
local function mobility(): number
	return WeaponConfig.Mobility and WeaponConfig.Mobility(localPlayer.Character) or 1
end
local Get = shared.Get

-- // Root
local controller = {}

-- // State
local character: Model?, humanoid: Humanoid?, rootPart: BasePart?
local cover = nil -- { part, normal, tangent, point, minT, maxT, depth, isLow, side, peekMode, nearEdge }
local peekBlend = 0 -- 0 = hidden, 1 = fully peeking / standing
local pendingJump: { at: number, fast: boolean, double: boolean? }? = nil -- Space pressed a moment early
local doubleVaultUntil = 0 -- (old double-tap vault back: no longer used - Q mid-vault replaced it)
local pendingDash: number? = nil -- E pressed mid-vault: sneak to the cover under the crosshair once you land
local diveArmUntil = 0 -- (unused: the old Shift+Space+E dive)
local lastSpaceAt = 0 -- double-tap Space = jump dive
local lastHopAt = 0 -- [MECH] dive only from jump (Edward 2026-10-16): when onJumpKey last started a real hop
local shoulderNow = 1 -- last camera shoulder chosen in cover
local suppressUntil = 0 -- near miss: no peeking/aiming until then
local blindUntil = 0 -- os.clock() until which the blind-fire pose is held
local crouched = false -- C: crouch behind tall cover (low cover is always crouched)
local move = nil -- cover-to-cover move in progress { style, standPoint, normal, deadline, track }
local moveCancelRequested = false -- set by a movement key pressed during a move (see Start)
local coverSpeed = 0 -- current shuffle speed along the wall (ramps up/down)
local vault = nil -- vault in progress { from, peak, to, start, track }
local dive = nil -- dive-roll in progress (Shift+E in mid-air) { from, over, to, facing, start, duration, hit, stand }
local lastVaulted: BasePart? = nil -- the low cover you most recently vaulted (Space near it vaults back)
local coverTracks: { [string]: AnimationTrack }? = nil
local moveTracks: { [string]: AnimationTrack }? = nil
local savedWalkSpeed = 16
local lastShotAt = -math.huge -- WeaponController reports shots; a hop waits for the shot to finish
local hopLockUntil = 0 -- covers the frame between pressing hop and the Humanoid actually leaving the ground
local CameraController
local controls -- PlayerModule controls, disabled while a move/vault drives the character

local worldParams = RaycastParams.new()
worldParams.FilterType = Enum.RaycastFilterType.Exclude
worldParams.IgnoreWater = true

-- // Helpers
-- Shift held? (Studio tests can fake it with the LocalPlayer attribute "TestShift")
local forceFast = false -- a scripted (tutorial) move: counts as Shift held
local function sprintHeld(): boolean
	if forceFast then return true end
	local sk = Binds.Key(Players.LocalPlayer, "Sprint", Config.Keybinds.Sprint) -- [SET] your Sprint bind
	if sk.EnumType == Enum.UserInputType and UserInputService:IsMouseButtonPressed(sk) then return true end
	if sk.EnumType == Enum.KeyCode and UserInputService:IsKeyDown(sk) then return true end
	if Players.LocalPlayer:GetAttribute("Setting_AutoSprint") == true then return true end -- [SET] Auto Sprint
	if Players.LocalPlayer:GetAttribute("PadSprint") == true then return true end -- [PAD] L3 sprint (MovementController)
	return RunService:IsStudio() and Players.LocalPlayer:GetAttribute("TestShift") == true
end

local function isAlive(): boolean
	return humanoid ~= nil and rootPart ~= nil and rootPart.Parent ~= nil and humanoid.Health > 0
end

local function castWorld(origin: Vector3, direction: Vector3, extraIgnore: Instance?): RaycastResult?
	local list = {}
	for _, player in Players:GetPlayers() do
		if player.Character then table.insert(list, player.Character) end
	end
	if extraIgnore then table.insert(list, extraIgnore) end
	-- set dressing (bottles, chairs, pallets...) and shootables (barrels, valves) are never cover
	local mapModel = arenaMap()
	if mapModel then
		for _, name in { "Props", "Shootables" } do
			local f = mapModel:FindFirstChild(name)
			if f then table.insert(list, f) end
		end
	end
	worldParams.FilterDescendantsInstances = list
	return workspace:Raycast(origin, direction, worldParams)
end

local function moveToward(current: number, target: number, step: number): number
	if current < target then return math.min(current + step, target) end
	return math.max(current - step, target)
end

local function getControls()
	if controls then return controls end
	local ok, result = pcall(function()
		local playerModule = localPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 5)
		return require(playerModule):GetControls()
	end)
	if ok then controls = result end
	return controls
end

-- Where the player is asking to move, in world space (flat). Read from the input itself rather than
-- Humanoid.MoveDirection: in cover we hold WalkSpeed at 0 to stop you walking in place, and the
-- engine reports MoveDirection as zero while WalkSpeed is 0, which used to lock A/D out for good.
local function inputDirection(): Vector3
	local c = getControls()
	local mv = c and c:GetMoveVector() or Vector3.zero
	local test = game:GetService("RunService"):IsStudio() and Players.LocalPlayer:GetAttribute("TestMove") -- Studio test hook
	if typeof(test) == "Vector3" then mv = test end
	if mv.Magnitude > 0.05 then
		local cam = workspace.CurrentCamera.CFrame
		local forward = cam.LookVector * FLAT
		local right = cam.RightVector * FLAT
		if forward.Magnitude < 0.01 then forward = -cam.UpVector * FLAT end
		local world = right.Unit * mv.X + forward.Unit * -mv.Z
		if world.Magnitude > 0.01 then return world.Unit * math.min(mv.Magnitude, 1) end
	end
	local h = humanoid
	return h and h.MoveDirection or Vector3.zero
end

local function loadTracks(names: { [string]: string }, forceLoop: boolean): { [string]: AnimationTrack }
	local tracks = {}
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then return tracks end

	local sources = ReplicatedStorage:FindFirstChild("Repository")
		and ReplicatedStorage.Repository:FindFirstChild("AnimationSources")
	for name, id in names do
		-- (pass 40) published to the group: the source carries its asset id
		local pub = id == "" and sources and sources:FindFirstChild("Cover" .. name)
		if pub and pub:GetAttribute("PublishedId") then id = pub:GetAttribute("PublishedId") end
		-- Studio only: no published ID yet -> play the local KeyframeSequence source
		if id == "" and RunService:IsStudio() and sources then
			local source = sources:FindFirstChild("Cover" .. name)
			if source then
				local ok, tempId = pcall(function()
					return game:GetService("KeyframeSequenceProvider"):RegisterKeyframeSequence(source)
				end)
				if ok then id = tempId else warn(`[CoverController] Studio preview of {name} failed: {tempId}`) end
			end
		end
		if id ~= "" then
			local animation = Instance.new("Animation")
			animation.AnimationId = id
			local ok, track = pcall(animator.LoadAnimation, animator, animation)
			if ok then
				if forceLoop then track.Looped = true end
				tracks[name] = track
			else
				warn(`[CoverController] Could not load {name}: {track}`)
			end
		end
	end
	return tracks
end

local function stopCoverTracks(fade: number?)
	for _, track in (coverTracks or {}) do
		if track.IsPlaying then track:Stop(fade or 0.15) end
	end
end

local function playMoveTrack(name: string, speed: number?): AnimationTrack?
	moveTracks = moveTracks or loadTracks(Config.MoveAnimations, false)
	local track = moveTracks[name]
	if track then track:Play(0.08, 1, speed or 1) end
	return track
end

-- Point on the camera's crosshair ray
local crosshairOverride = nil -- Studio test hook only (see controller.Start)
local function crosshairRay(): (Vector3, Vector3)
	if crosshairOverride then return crosshairOverride[1], crosshairOverride[2] end
	local camera = workspace.CurrentCamera
	return camera.CFrame.Position, camera.CFrame.LookVector
end

-- Build cover info from a wall hit
local function coverFromHit(hit: RaycastResult)
	local root = rootPart :: BasePart
	local part = hit.Instance :: BasePart
	local normal = (hit.Normal * FLAT).Unit
	local tangent = Vector3.yAxis:Cross(normal).Unit

	-- How far the cover extends left/right of the contact point, and how thick it is (from the part's corners)
	local minT, maxT = math.huge, -math.huge
	local maxDepth = 0
	local half = part.Size / 2
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local corner = part.CFrame:PointToWorldSpace(Vector3.new(sx * half.X, sy * half.Y, sz * half.Z))
				local offset = corner - hit.Position
				local t = offset:Dot(tangent)
				minT = math.min(minT, t)
				maxT = math.max(maxT, t)
				maxDepth = math.max(maxDepth, -offset:Dot(normal))
			end
		end
	end

	-- Low cover: the wall at the exact contact point doesn't reach head height.
	-- (Tested at the contact point, not from where you stand: standing back or off to the side of
	-- a narrow pillar used to make a head-height ray miss it and read the pillar as a crate.)
	local probe = Vector3.new(hit.Position.X, root.Position.Y + Config.HeadHeight, hit.Position.Z) + normal * 1
	local isLow = castWorld(probe, -normal * 1.6) == nil

	-- Face the edge your crosshair is toward (falls back to the nearer edge)
	local origin, look = crosshairRay()
	local aimAlong = (look * FLAT):Dot(tangent)
	local side
	if math.abs(aimAlong) > 0.15 then
		side = aimAlong > 0 and 1 or -1
	else
		side = (maxT < -minT) and 1 or -1
	end

	return {
		part = part, normal = normal, tangent = tangent, point = hit.Position,
		minT = minT, maxT = maxT, depth = maxDepth, isLow = isLow, side = side,
		top = part.Position.Y + half.Y, -- approximate (fine for axis-aligned crates)
	}
end

local function isUsableWall(hit: RaycastResult?): boolean
	return hit ~= nil and hit.Instance.CanCollide and (hit.Normal * FLAT).Magnitude > 0.7
		and not hit.Instance:GetAttribute("NotCover")
end

-- Cover right in front of you (camera direction first, then facing, then movement)
local function findNearbyCover(preferFacing: boolean?)
	if not isAlive() then return nil end
	local root = rootPart :: BasePart
	local hum = humanoid :: Humanoid

	local directions = {}
	-- (Studio tests drive the 'camera' through the crosshair override)
	local camLook = (crosshairOverride and crosshairOverride[2] or workspace.CurrentCamera.CFrame.LookVector) * FLAT
	if camLook.Magnitude > 0.1 then table.insert(directions, camLook.Unit) end
	table.insert(directions, (root.CFrame.LookVector * FLAT).Unit)
	if hum.MoveDirection.Magnitude > 0.1 then table.insert(directions, hum.MoveDirection.Unit) end
	-- Q means "the cover right next to me": check all around (incl. diagonals, so standing just past a
	-- corner still finds the face - you then glide in until you're fully behind it)
	for i = 0, 15 do
		local angle = math.rad(i * 22.5)
		table.insert(directions, Vector3.new(math.cos(angle), 0, math.sin(angle)))
	end

	local waist = root.Position + Vector3.new(0, Config.WaistHeight, 0)
	local best: RaycastResult? = nil
	local bestScore = math.huge
	local camFlat = camLook.Magnitude > 0.1 and camLook.Unit or nil
	for _, dir in directions do
		local result = castWorld(waist, dir * Config.DetectDistance)
		if isUsableWall(result) then
			local score = result.Distance
			-- Q: between two covers about as close (a low wall beside a pillar), take the one you're facing
			if preferFacing and camFlat then
				local facingIt = -((result.Normal * FLAT).Unit):Dot(camFlat)
				score -= math.max(facingIt, 0) * 1.5
			end
			if score < bestScore then best, bestScore = result, score end
		end
	end
	return best and coverFromHit(best) or nil
end

-- The wall face of `part` facing you, found by casting from your waist toward `point`
local function faceToward(part: BasePart, point: Vector3): RaycastResult?
	local root = rootPart :: BasePart
	local waist = root.Position + Vector3.new(0, Config.WaistHeight, 0)
	local target = Vector3.new(point.X, waist.Y, point.Z)
	local dir = (target - waist) * FLAT
	if dir.Magnitude < 0.1 then return nil end
	local ignore = cover and cover.part or nil
	local hit = castWorld(waist, dir.Unit * (dir.Magnitude + 3), ignore)
	if hit and hit.Instance == part and isUsableWall(hit) then return hit end
	return nil
end

-- Move a target point on a cover face away from its ends, so a cover move never aims at the
-- corner itself (catching your body on the corner is how you'd end up stuck in the open).
-- Returns a hit-like table { Instance, Position, Normal } that the rest of the code uses like a RaycastResult.
local function insetOnFace(hit)
	local part = hit.Instance
	if not part:IsA("BasePart") then return hit end
	local normal = (hit.Normal * FLAT).Unit
	local tangent = Vector3.yAxis:Cross(normal).Unit
	local minT, maxT = math.huge, -math.huge
	local half = part.Size / 2
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local corner = part.CFrame:PointToWorldSpace(Vector3.new(sx * half.X, 0, sz * half.Z))
			local t = (corner - hit.Position):Dot(tangent)
			minT, maxT = math.min(minT, t), math.max(maxT, t)
		end
	end
	local inset = Config.EdgeMargin + 0.6
	local t = (minT + inset <= maxT - inset) and math.clamp(0, minT + inset, maxT - inset) or (minT + maxT) / 2
	return { Instance = part, Position = hit.Position + tangent * t, Normal = hit.Normal }
end

-- Can a character run straight from a to b? (waist and knee height, shoulder width)
-- `allowPart` (the cover you're heading for) may only be touched in the last stretch, where you arrive at it;
-- hitting it any earlier means the line goes into or around it.
local lastBlocker: Instance? = nil
local cornerParams = OverlapParams.new()
cornerParams.FilterType = Enum.RaycastFilterType.Exclude -- the object that blocked the most recent failed segment check
-- Solid things that are NOT cover still block your path: barrels, valves, tables, chairs, boxes...
-- (castWorld skips them on purpose - they're never cover - and most props can't be raycast at all,
-- so routes check them as plain boxes.) Anything you can step over (a pallet) or that sits up on a
-- shelf/table doesn't count.
local obstacleBoxes: { { cf: CFrame, size: Vector3 } }? = nil
local obstaclesBuiltAt = 0
local lastBlockerBox: { cf: CFrame, size: Vector3 }? = nil
local function getObstacles()
	if obstacleBoxes and os.clock() - obstaclesBuiltAt < 5 then return obstacleBoxes end
	obstacleBoxes, obstaclesBuiltAt = {}, os.clock()
	local map = arenaMap()
	local floor = map and map:FindFirstChild("CollisionProxies") and map.CollisionProxies:FindFirstChild("COLP_Floor")
	local floorTop = floor and floor.Position.Y + floor.Size.Y / 2 or 0.4
	for _, folderName in { "Props", "Shootables" } do
		local folder = map and map:FindFirstChild(folderName)
		for _, model in (folder and folder:GetChildren() or {}) do
			local solid = false
			for _, p in model:GetDescendants() do
				if p:IsA("BasePart") and p.CanCollide and p.LocalTransparencyModifier < 1 then solid = true break end
			end
			if model:IsA("BasePart") and model.CanCollide then solid = true end
			if solid then
				local cf, size
				if model:IsA("Model") then cf, size = model:GetBoundingBox() else cf, size = model.CFrame, model.Size end
				-- world-aligned footprint of the (possibly tilted) box: barrels lie on their side, etc.
				local minV, maxV = Vector3.one * math.huge, -Vector3.one * math.huge
				for _, sx in { -1, 1 } do for _, sy in { -1, 1 } do for _, sz in { -1, 1 } do
					local p = cf:PointToWorldSpace(size / 2 * Vector3.new(sx, sy, sz))
					minV, maxV = minV:Min(p), maxV:Max(p)
				end end end
				local bottom, top = minV.Y - floorTop, maxV.Y - floorTop
				if top > 0.7 and bottom < 3 then
					table.insert(obstacleBoxes, { cf = CFrame.new((minV + maxV) / 2), size = maxV - minV })
				end
			end
		end
	end
	return obstacleBoxes
end

-- flat (XZ) segment vs box grown by `pad`
local function segmentHitsBox2D(a: Vector3, b: Vector3, box, pad: number): boolean
	local la, lb = box.cf:PointToObjectSpace(a), box.cf:PointToObjectSpace(b)
	local d = lb - la
	local tmin, tmax = 0, 1
	for _, axis in { "X", "Z" } do
		local o, v, h = la[axis], d[axis], box.size[axis] / 2 + pad
		if math.abs(v) < 1e-6 then
			if o < -h or o > h then return false end
		else
			local t1, t2 = (-h - o) / v, (h - o) / v
			if t1 > t2 then t1, t2 = t2, t1 end
			tmin, tmax = math.max(tmin, t1), math.min(tmax, t2)
			if tmin > tmax then return false end
		end
	end
	return true
end

local function pointInObstacle(p: Vector3, pad: number): boolean
	for _, box in getObstacles() do
		local l = box.cf:PointToObjectSpace(p)
		if math.abs(l.X) < box.size.X / 2 + pad and math.abs(l.Z) < box.size.Z / 2 + pad then return true end
	end
	return false
end

local function segmentClear(a: Vector3, b: Vector3, allowPart: Instance?): boolean
	local root = rootPart :: BasePart
	if ((b - a) * FLAT).Magnitude > 0.1 then
		for _, box in getObstacles() do
			-- (starting or finishing right beside it - e.g. cover next to a barrel - is fine)
			local la, lb = box.cf:PointToObjectSpace(a), box.cf:PointToObjectSpace(b)
			local hx, hz = box.size.X / 2 + 1.05, box.size.Z / 2 + 1.05
			local besideA = math.abs(la.X) < hx and math.abs(la.Z) < hz
			local besideB = math.abs(lb.X) < hx and math.abs(lb.Z) < hz
			if not besideA and not besideB and segmentHitsBox2D(a, b, box, 1.05) then
				lastBlocker = nil
				lastBlockerBox = box
				return false
			end
		end
	end
	local offset = (b - a) * FLAT
	local length = offset.Magnitude
	if length < 0.1 then return true end
	local side = Vector3.yAxis:Cross(offset.Unit) * 1.05 -- a little wider than the body, so routes don't clip corners
	for _, height in { Config.WaistHeight, -1.8 } do
		for _, lateral in { -1, 0, 1 } do
			local from = Vector3.new(a.X, root.Position.Y + height, a.Z) + side * lateral
			local blocked = castWorld(from, offset - offset.Unit * 0.3)
			if blocked and not (blocked.Instance == allowPart and blocked.Distance >= length - 1.6) then
				lastBlocker = blocked.Instance
				return false
			end
		end
	end
	return true
end

-- A route to `stand`: straight if possible, otherwise around the corners of the target
-- (and of the cover you're leaving) through one or two turning points. Shortest wins. nil = no route.
local function planRoute(stand: Vector3, targetPart: Instance?): { Vector3 }?
	local root = rootPart :: BasePart
	local start = root.Position
	local chars = {}
	for _, player in Players:GetPlayers() do if player.Character then table.insert(chars, player.Character) end end
	cornerParams.FilterDescendantsInstances = chars
	lastBlocker = nil
	lastBlockerBox = nil
	if segmentClear(start, stand, targetPart) then return { stand } end
	local inTheWay = lastBlocker ~= targetPart and lastBlocker or nil

	-- boxes to route round: the target, the cover you're in, and whatever blocked the straight line
	local boxes = {}
	for _, part in { targetPart, cover and cover.part or nil, inTheWay } do
		if part and part:IsA("BasePart") then table.insert(boxes, { cf = part.CFrame, size = part.Size }) end
	end
	if lastBlockerBox then table.insert(boxes, lastBlockerBox) end
	local corners = {}
	for _, box in boxes do
		do
			local half = box.size / 2
			local margin = Config.WallOffset + 0.5
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local world = box.cf:PointToWorldSpace(Vector3.new(sx * (half.X + margin), 0, sz * (half.Z + margin)))
					local corner = Vector3.new(world.X, start.Y, world.Z)
					-- only turning points a body actually fits through (nothing solid within about a body width)
					local roomy = true
					for _, other in workspace:GetPartBoundsInRadius(corner + Vector3.new(0, Config.WaistHeight, 0), 1.1, cornerParams) do
						if other.CanCollide then roomy = false break end
					end
					if roomy and pointInObstacle(corner, 1.0) then roomy = false end
					if roomy then table.insert(corners, corner) end
				end
			end
		end
	end

	local fromStart, toStand = {}, {}
	for i, c in corners do
		fromStart[i] = segmentClear(start, c, nil)
		toStand[i] = segmentClear(c, stand, targetPart)
	end
	local best, bestLength = nil, Config.MoveMaxDistance * Config.RouteMaxDetour
	local function flatDist(a, b) return ((a - b) * FLAT).Magnitude end
	for i, c in corners do
		if fromStart[i] and toStand[i] then
			local length = flatDist(start, c) + flatDist(c, stand)
			if length < bestLength then best, bestLength = { c, stand }, length end
		end
	end
	for i, c1 in corners do
		if fromStart[i] then
			for j, c2 in corners do
				if i ~= j and toStand[j] then
					local length = flatDist(start, c1) + flatDist(c1, c2) + flatDist(c2, stand)
					if length < bestLength and segmentClear(c1, c2, nil) then
						best, bestLength = { c1, c2, stand }, length
					end
				end
			end
		end
	end
	return best
end

-- From cover you can only move to the BACK of other cover: the face pointing the same way as the
-- cover you're in (away from the same threat). Picking any other side means leaving cover first.
local backParams = RaycastParams.new()
backParams.FilterType = Enum.RaycastFilterType.Include
local function faceWithNormal(part: Instance, n: Vector3, aimPoint: Vector3): RaycastResult?
	if not part:IsA("BasePart") then return nil end
	local root = rootPart :: BasePart
	local reach = part.Size.Magnitude + 2
	local waistY = root.Position.Y + Config.WaistHeight
	backParams.FilterDescendantsInstances = { part }
	for _, base in { aimPoint, part.Position } do -- at the crosshair's spot along the face, else its middle
		local origin = Vector3.new(base.X, waistY, base.Z) + n * reach
		local result = workspace:Raycast(origin, -n * reach * 2, backParams)
		if result and (result.Normal * FLAT).Magnitude > 0.7 and (result.Normal * FLAT).Unit:Dot(n) > 0.7 then
			return result
		end
	end
	return nil
end

local function backFace(part: Instance, aimPoint: Vector3): RaycastResult?
	if not cover then return nil end
	return faceWithNormal(part, cover.normal, aimPoint)
end

-- From the open: the face of the box on YOUR side of it, from where you stand.
-- (Back-left of a box -> whichever of back/left you're further out past; ties go to the bigger overhang.)
local function faceOnYourSide(part: Instance, aimPoint: Vector3): RaycastResult?
	if not part:IsA("BasePart") then return nil end
	local root = rootPart :: BasePart
	local p = part.CFrame:PointToObjectSpace(root.Position)
	local half = part.Size / 2
	local rx, rz = math.abs(p.X) / half.X, math.abs(p.Z) / half.Z
	local localNormal = rx > rz and Vector3.new(math.sign(p.X), 0, 0) or Vector3.new(0, 0, math.sign(p.Z))
	local worldNormal = part.CFrame:VectorToWorldSpace(localNormal) * FLAT
	if worldNormal.Magnitude < 0.5 then return nil end -- tilted part: let the crosshair decide
	return faceWithNormal(part, worldNormal.Unit, aimPoint)
end

-- Cover further away under the crosshair, reachable in a straight line
local function findCrosshairCover(): (RaycastResult?, Vector3?, { Vector3 }?)
	if not isAlive() then return nil end
	local root = rootPart :: BasePart
	local origin, look = crosshairRay()
	local hit = castWorld(origin, look * (Config.MoveMaxDistance + 20), cover and cover.part or nil)
	if not hit then return nil end
	-- Crosshair on the top of a crate (the usual case when aiming down at low cover): use its near face
	if hit.Normal.Y > 0.7 and hit.Instance:IsA("BasePart") and hit.Instance.CanCollide then
		hit = faceToward(hit.Instance :: BasePart, hit.Position)
	end
	if not isUsableWall(hit) then return nil end
	local h = hit :: RaycastResult
	if cover and h.Instance == cover.part then return nil end -- same object: slide along it instead
	if cover then
		-- From cover: always the back of the target, whatever the camera is doing
		local back = backFace(h.Instance, h.Position)
		if not back then return nil end
		h = back
	else
		-- From the open: the face on your side of it, unless you've swung the camera far to one side
		local toTarget = ((h.Instance :: BasePart).Position - root.Position) * FLAT
		local lookFlat = look * FLAT
		local extreme = toTarget.Magnitude > 0.1 and lookFlat.Magnitude > 0.1
			and math.deg(math.acos(math.clamp(toTarget.Unit:Dot(lookFlat.Unit), -1, 1))) > Config.SideSelectAngle
		if not extreme then
			local mine = faceOnYourSide(h.Instance, h.Position)
			if mine then h = mine end
		end
	end

	h = insetOnFace(h)
	local normal = (h.Normal * FLAT).Unit
	local stand = h.Position + normal * Config.WallOffset
	stand = Vector3.new(stand.X, root.Position.Y, stand.Z)
	local offset = (stand - root.Position) * FLAT
	local distance = offset.Magnitude
	if distance < Config.MoveMinDistance or distance > Config.MoveMaxDistance then return nil end

	-- Cover behind you / its far face: run around it instead of into it
	local route = planRoute(stand, h.Instance)
	if not route then return nil end
	return h, stand, route
end

-- Ground spot under the crosshair (Dash key). Returns where to run to, and the cover there (if any).
local function findCrosshairSpot(): (Vector3?, RaycastResult?, { Vector3 }?)
	if not isAlive() then return nil end
	local root = rootPart :: BasePart
	local origin, look = crosshairRay()
	local hit = castWorld(origin, look * (Config.MoveMaxDistance + 20), cover and cover.part or nil)
	if not hit then return nil end
	-- Aimed at a wall, or the top of a crate: same as Q
	if hit.Normal.Y < 0.7 or faceToward(hit.Instance :: BasePart, hit.Position) then
		local h, stand, route = findCrosshairCover()
		return stand, h, route
	end
	local spot = Vector3.new(hit.Position.X, root.Position.Y, hit.Position.Z)
	local distance = ((spot - root.Position) * FLAT).Magnitude
	if distance < Config.MoveMinDistance or distance > Config.MoveMaxDistance then return nil end
	-- Any cover within reach of that spot? (nearest wall, 8 directions)
	local best: RaycastResult? = nil
	local waist = spot + Vector3.new(0, Config.WaistHeight, 0)
	for i = 0, 7 do
		local angle = math.rad(i * 45)
		local result = castWorld(waist, Vector3.new(math.cos(angle), 0, math.sin(angle)) * Config.SpotCoverReach)
		if isUsableWall(result) and (not best or result.Distance < best.Distance) then best = result end
	end
	-- From cover, only the back of the cover near that spot counts
	if best and cover then
		best = backFace(best.Instance, spot)
	end
	if not best then return nil end -- E only ever takes you to cover, never to open floor
	best = insetOnFace(best)
	local stand = spot
	if best then
		stand = best.Position + (best.Normal * FLAT).Unit * Config.WallOffset
		stand = Vector3.new(stand.X, root.Position.Y, stand.Z)
	end
	local route = planRoute(stand, best and best.Instance or nil)
	if not route then return nil end
	return stand, best, route
end

-- // Entering / leaving
-- your on-foot stance (MovementController): crouched or standing
local function setStance(crouch: boolean)
	local Movement = Get and Get("MovementController")
	if Movement and Movement.SetCrouched then Movement.SetCrouched(crouch) end
end

-- keepStance: a cover-to-cover run keeps its own (crouched) stance; every other way out of cover -
-- holding S, Q, Shift+direction, a vault - stands you back up.
local function exitCover(keepStance: boolean?)
	if not cover then return end
	cover = nil
	-- (pass 43) off the cover: the gun goes back to your settings hand (peeking left only lasts while you're on it)
	local Cam = Get and Get("CameraController")
	if Cam and Cam.ResetShoulder then Cam.ResetShoulder() end
	crouched = false
	peekBlend = 0
	blindUntil = 0
	stopCoverTracks()
	if humanoid then
		humanoid.WalkSpeed = savedWalkSpeed
		humanoid.AutoRotate = true
	end
	if not keepStance then setStance(false) end
end

local function enterCover(newCover)
	local hum = humanoid :: Humanoid
	cover = newCover
	peekBlend = 0
	-- crouching on foot? You go into the crouched version of this cover (low cover is always crouched)
	local Movement = Get and Get("MovementController")
	crouched = not newCover.isLow and Movement ~= nil and Movement.IsCrouched ~= nil and Movement.IsCrouched() == true
	coverSpeed = 0
	hum.WalkSpeed = Config.CoverWalkSpeed
	hum.AutoRotate = false
	coverTracks = coverTracks or loadTracks(Config.CoverAnimations, true)
end

-- Ends a move/vault and gives control back
local function finishMovement()
	if move and move.track then move.track:Stop(0.1) end
	if move and move.conn then move.conn:Disconnect() end
	-- Cancel the walk-to: otherwise the Humanoid keeps running at the target for up to 8 seconds
	if move and humanoid and rootPart then humanoid:MoveTo(rootPart.Position) end
	if vault and vault.track then vault.track:Stop(0.15) end
	if move and rootPart then rootPart.AssemblyAngularVelocity = Vector3.zero end
	if dive and character then character:SetAttribute("Diving", nil) end
	move, vault, dive = nil, nil, nil
	local c = getControls()
	if c then
		c:Enable()
		-- [MOVEKEYS] Roblox's keyboard controller zeroes its key state while disabled: keys still held (the movement key
		-- that just cancelled an E move) didn't move you until pressed again (Edward 2026-10-18). Re-read them.
		local kb = c.activeController
		if kb and kb.forwardValue ~= nil and kb.UpdateMovement then
			local function down(...)
				for _, k in { ... } do if UserInputService:IsKeyDown(k) then return true end end
				return false
			end
			kb.forwardValue = down(Enum.KeyCode.W, Enum.KeyCode.Up) and -1 or 0
			kb.backwardValue = down(Enum.KeyCode.S, Enum.KeyCode.Down) and 1 or 0
			kb.leftValue = down(Enum.KeyCode.A) and -1 or 0
			kb.rightValue = down(Enum.KeyCode.D) and 1 or 0
			pcall(kb.UpdateMovement, kb, Enum.UserInputState.Begin)
		end
	end
	if humanoid then
		humanoid.WalkSpeed = savedWalkSpeed
		humanoid.AutoRotate = true
	end
end

-- Cover-to-cover: crouched dash (default), roll (short hop onto low cover), sprint (Shift held)
local function startMove(hit: RaycastResult?, stand: Vector3, route: { Vector3 }?, forceStyle: string?)
	-- The tutorial can restrict moves to one piece of cover (LocalPlayer attribute "MoveTarget")
	local only = localPlayer:GetAttribute("MoveTarget")
	if only and (not hit or hit.Instance.Name ~= only) then return end
	local root = rootPart :: BasePart
	local hum = humanoid :: Humanoid
	route = route or { stand }
	local distance = 0
	local previous = root.Position
	for _, point in route do
		distance += ((point - previous) * FLAT).Magnitude
		previous = point
	end
	local targetLow = hit ~= nil and castWorld(
		Vector3.new(hit.Position.X, root.Position.Y + Config.HeadHeight, hit.Position.Z) + hit.Normal * FLAT,
		-(hit.Normal * FLAT).Unit * 1.6
	) == nil

	-- E alone: SNEAK there (slow, crouched, silent). Shift + E: the quick reposition - the same low dash
	-- whether you start in cover or out in the open (no roll).
	-- (pass 40, match place) the starter tutorial sets EAutoRush: plain [E] runs to cover (no Shift needed)
	local style = forceStyle or ((sprintHeld() or localPlayer:GetAttribute("EAutoRush") == true) and "Dash" or "Sneak")
	local _ = targetLow

	exitCover(true)
	local speed = Config.MoveSpeeds[style] * mobility() -- [ABILITY]
	local c = getControls()
	if c then c:Disable() end
	hum.WalkSpeed = speed
	hum.AutoRotate = false -- updateMovement turns you into the run smoothly
	hum:MoveTo(route[1])
	local thisMove
	local conn
	conn = hum.MoveToFinished:Connect(function()
		-- fires at every turning point too; only the last one counts as arriving
		if move == thisMove and move.index == #move.route then move.arrived = true end
	end)

	local track
	local rolled = nil
	if style == "Dash" or style == "Sneak" then
		track = playMoveTrack(style)
	elseif style == "Roll" then
		-- straight into the roll (a dive's follow-through): it carries you onto the spot
		track = playMoveTrack("Roll")
		if track and track.Length > 0 then track:AdjustSpeed(track.Length / math.max(distance / speed, 0.25)) end
		rolled = true
	end

	thisMove = {
		style = style, stand = stand, normal = hit and (hit.Normal * FLAT).Unit or nil, track = track, conn = conn,
		route = route, index = 1,
		targetPart = hit and hit.Instance or nil, facePoint = hit and hit.Position or nil,
		deadline = os.clock() + distance / speed * 1.5 + 1.2, -- generous: acceleration, corners, bumps
		started = os.clock(),
		forced = forceFast or style == "Roll", -- the tutorial's scripted run-backs (and a dive's roll) can't be cancelled
		rolled = rolled,
	}
	move = thisMove
end

-- Space = SILENT vault: slower and quiet. Shift + Space = RUNNING vault: fast, carries your momentum,
-- and you can aim and fire while going over. Either way you land on your feet; press Q during the vault
-- to land straight in cover, or E to sneak to the cover under your crosshair once you're down.
local function startVault(c, fast: boolean?)
	local root = rootPart :: BasePart
	local duration = (fast and Config.VaultTime or Config.VaultTime * (Config.SilentVaultSlowdown or 1.7)) / mobility() -- [ABILITY]
	-- Landing spot must be clear: just past the far side of the crate
	local landing = c.point - c.normal * (c.depth + Config.WallOffset + 0.4)
	landing = Vector3.new(landing.X, root.Position.Y, landing.Z)
	local overHeight = math.max(c.top + Config.VaultClearance, root.Position.Y + 0.5)
	local over = c.point - c.normal * (c.depth / 2)
	over = Vector3.new(over.X, overHeight, over.Z)
	if castWorld(over, landing - over) or castWorld(landing + Vector3.new(0, 1, 0), Vector3.new(0, -1.5, 0)) then
		return false -- something on the other side
	end

	local from = root.Position
	local startedInCover = cover ~= nil
	-- (Player input stays ON during a vault: the Physics state ignores it anyway, and turning the
	-- controls off makes Roblox forget that W is held, so you'd stop dead on landing.)
	-- Bezier control point placed so the curve's highest point is exactly `over`
	local control = Vector3.new(over.X, 2 * over.Y - (from.Y + landing.Y) / 2, over.Z)
	exitCover()
	local hum = humanoid :: Humanoid
	hum.AutoRotate = false
	hum:ChangeState(Enum.HumanoidStateType.Physics)

	local track = playMoveTrack("Vault")
	if track and track.Length > 0 then track:AdjustSpeed(track.Length / duration) end

	-- Vaulting back over the wall you just came over (from the open) puts you straight back in cover on it
	local revault = not startedInCover and c.part == lastVaulted
	vault = { from = from, over = control, to = landing, facing = -c.normal, start = os.clock(), track = track, fromCover = startedInCover, revault = revault, part = c.part,
		duration = duration, fast = fast == true }
	if not fast and character then character:SetAttribute("SilentMove", true) end
	lastVaulted = c.part
	return true
end

-- [CLIMB] (Edward 2026-10-21) "on vaultable objects lets say an object is very wide it shouldn't default to a vault with
-- spacebar it should be a climb animation instead to get ontop of it this can also work on taller objects aswell if your head
-- is over the object" / "if the object is too long instead of vaulting a really long object it climbs ontop of it".
-- Space on cover that is too deep to vault across (or whose far side is blocked), or on a wall a little too tall to vault whose
-- top is still under the top of your head: you climb up and stand on top of it (hands on the edge, knee up, step on).
local CLIMB_MIN_DEPTH = Config.ClimbMinDepth or 5 -- deeper than this (studs, front to back): climb instead of vault
local CLIMB_MAX_ABOVE_ROOT = Config.ClimbMaxAboveRoot or 2.6 -- the top may be up to here above the root (the top of the head)

-- the top surface just behind the wall's face, if you can stand there; nil when it is too high or there's no headroom
local function climbSpot(c): Vector3?
	local root = rootPart :: BasePart
	local hum = humanoid :: Humanoid
	local rootOffset = hum.HipHeight + root.Size.Y / 2
	local inset = math.clamp(c.depth / 2, 0.8, 1.6)
	local at = c.point - c.normal * inset
	local down = castWorld(Vector3.new(at.X, root.Position.Y + CLIMB_MAX_ABOVE_ROOT + 0.5, at.Z), Vector3.new(0, -(CLIMB_MAX_ABOVE_ROOT + 4), 0))
	if not down or down.Normal.Y < 0.7 then return nil end
	local topY = down.Position.Y
	if topY > root.Position.Y + CLIMB_MAX_ABOVE_ROOT or topY < root.Position.Y - rootOffset + 1 then return nil end
	local stand = Vector3.new(at.X, topY + rootOffset, at.Z)
	-- headroom to stand up there, and nothing between you and the edge at the top
	if castWorld(Vector3.new(at.X, topY + 0.2, at.Z), Vector3.new(0, rootOffset * 2 + 0.3, 0)) then return nil end
	local edge = Vector3.new(root.Position.X, topY + 0.6, root.Position.Z)
	if castWorld(edge, Vector3.new(at.X, topY + 0.6, at.Z) - edge) then return nil end
	return stand
end

local function startClimb(c, stand: Vector3): boolean
	local root = rootPart :: BasePart
	local hum = humanoid :: Humanoid
	local from = root.Position
	local rise = math.max(stand.Y - from.Y, 0.5)
	local duration = ((Config.ClimbTime or 0.62) + rise * 0.06) / mobility() -- [ABILITY]
	-- up the face first, then forward onto the top: the curve leaves straight up and arrives level
	local face = Vector3.new(from.X, stand.Y + 0.35, from.Z):Lerp(Vector3.new(stand.X, stand.Y + 0.35, stand.Z), 0.15)
	exitCover()
	hum.AutoRotate = false
	hum:ChangeState(Enum.HumanoidStateType.Physics)
	local track = playMoveTrack("Climb")
	if track and track.Length > 0 then track:AdjustSpeed(track.Length / duration) end
	vault = { from = from, over = face, to = stand, facing = -c.normal, start = os.clock(), track = track, fromCover = false, part = c.part,
		duration = duration, fast = false, climb = true }
	return true
end

-- JUMP DIVE: Space, then quickly Shift+E while you're in the air. You launch at the cover under your
-- crosshair in an arc - high enough to clear a low wall in the way - body thrown forward, and land in a roll
-- that carries you on to the spot. On its own the roll stands you up in the open; press Q during the dive
-- (or the roll) and you finish it in cover. Anything taller than a low wall in the way: no dive.
local function startDive(hit: RaycastResult, stand: Vector3, board: boolean?): boolean
	local root = rootPart :: BasePart
	local hum = humanoid :: Humanoid
	local from = root.Position
	local flat = (stand - from) * FLAT
	local dist = flat.Magnitude
	if dist < 2 then return false end
	local dir = flat.Unit
	-- root height above the floor, and the floor under a point
	local rootOffset = hum.HipHeight + root.Size.Y / 2
	local function groundY(at: Vector3): number?
		local down = castWorld(Vector3.new(at.X, from.Y + 1, at.Z), Vector3.new(0, -30, 0))
		return down and (down.Position.Y + rootOffset) or nil
	end
	local startFloor = (groundY(from) or from.Y) - rootOffset
	-- land a roll's length short of the spot (or right on it when it's that close) - on the floor, not on
	-- top of the wall you're going over
	local airDist = math.clamp(dist - (Config.DiveRollDistance or 3.5), math.min(dist, 2.5), Config.DiveMaxAir or 12)
	local landing, landY
	for _ = 1, 8 do
		landing = from + dir * airDist
		landY = groundY(landing)
		if landY and landY - rootOffset <= startFloor + 0.6 then break end
		landY = nil
		airDist = math.min(airDist + 1, dist)
	end
	if not landY then return false end
	landing = Vector3.new(landing.X, landY, landing.Z)
	-- the tallest thing under the flight: a low wall gets jumped, anything taller stops the dive
	local topY = startFloor
	local topAt = 0.45 -- where along the flight the wall is (0..1): the arc peaks over it
	local steps = math.max(4, math.ceil(airDist))
	for k = 1, steps - 1 do
		local p = from + dir * (airDist * k / steps)
		local down = castWorld(Vector3.new(p.X, startFloor + (Config.DiveMaxClear or 4.4) + 0.3, p.Z), Vector3.new(0, -12, 0))
		if down and down.Position.Y > topY then topY, topAt = down.Position.Y, k / steps end
		-- something at that height or above: too tall to clear
		if castWorld(Vector3.new(p.X, startFloor + (Config.DiveMaxClear or 4.4) + 0.3, p.Z), dir * 0.5) then return false end
	end
	local clearance = topY - startFloor
	if clearance > (Config.DiveMaxClear or 4.4) then return false end
	local standAt = Vector3.new(stand.X, groundY(stand) or landY, stand.Z)

	exitCover(true)
	hum.AutoRotate = false
	hum:ChangeState(Enum.HumanoidStateType.Physics)
	-- the arc: a flat lunge on open ground, a proper leap when there's a wall to get over
	local apexY = math.max(from.Y, landY) + 0.5
	if clearance > 0.6 then apexY = math.max(apexY, topY + rootOffset * 0.9 + 0.6) end -- legs clear the top
	-- off the diving board (Shift+Space+E from cover): spring well up, hang in the air, then come down
	if board then apexY = math.max(apexY, from.Y + (Config.DiveBoardLift or 3.6)) end
	local mid = from:Lerp(landing, clearance > 0.6 and math.clamp(topAt, 0.3, 0.6) or 0.45)
	dive = {
		from = from, to = landing, facing = dir, hit = hit, stand = standAt,
		over = Vector3.new(mid.X, 2 * apexY - (from.Y + landY) / 2, mid.Z),
		start = os.clock(),
		duration = math.max(airDist / (Config.DiveSpeed or 34), 0.2) + (clearance > 0.6 and 0.18 or 0) + (board and (Config.DiveBoardFloat or 0.4) or 0),
		wantCover = false, -- Q during the dive / roll: finish in cover
	}
	if character then character:SetAttribute("Diving", true) end
	-- a cloth whoosh
	pcall(function()
		local whoosh = Instance.new("Sound")
		whoosh.SoundId = "rbxassetid://12222216"
		whoosh.Volume = 0.45
		whoosh.PlaybackSpeed = 0.75
		whoosh.Parent = root
		require(Shared:WaitForChild("SoundTrim")).Play(whoosh)
		game:GetService("Debris"):AddItem(whoosh, 2)
	end)
	return true
end

-- // Per frame
local function updateMovement(): boolean
	local root = rootPart :: BasePart
	local hum = humanoid :: Humanoid

	if dive then
		local alpha = math.clamp((os.clock() - dive.start) / dive.duration, 0, 1)
		local a = dive.from:Lerp(dive.over, alpha)
		local b = dive.over:Lerp(dive.to, alpha)
		local position = a:Lerp(b, alpha)
		-- thrown forward into the dive, coming back up into the roll as you land
		local pitch = math.rad(Config.DivePitch or 62) * math.sin(math.min(alpha * 1.15, 1) * math.pi)
		local face = dive.facing
		local aiming = CameraController and CameraController.IsAiming and CameraController.IsAiming()
		if aiming then
			-- aiming mid-dive: the body stays much flatter-to-upright and turns with your aim, so the gun
			-- (and the arms) point where you're looking
			pitch *= 0.25
			local camLook = workspace.CurrentCamera.CFrame.LookVector * FLAT
			if camLook.Magnitude > 0.1 then face = camLook.Unit end
		end
		root.CFrame = CFrame.lookAt(position, position + face) * CFrame.Angles(-pitch, 0, 0)
		root.AssemblyLinearVelocity = Vector3.zero
		if alpha >= 1 then
			local d = dive
			dive = nil
			if character then character:SetAttribute("Diving", nil) end
			root.CFrame = CFrame.lookAt(d.to, d.to + d.facing)
			hum:ChangeState(Enum.HumanoidStateType.Running)
			root.AssemblyLinearVelocity = d.facing * (Config.MoveSpeeds.Roll or 22)
			-- the roll carries you the rest of the way; you finish in cover only if you pressed Q
			startMove(d.hit, d.stand, { d.stand }, "Roll")
			if move then
				move.noCover = not d.wantCover
			else
				finishMovement()
			end
		end
		return true
	end

	if vault then
		local alpha = math.clamp((os.clock() - vault.start) / (vault.duration or Config.VaultTime), 0, 1)
		-- Quadratic Bezier through the point over the crate
		local a = vault.from:Lerp(vault.over, alpha)
		local b = vault.over:Lerp(vault.to, alpha)
		local position = a:Lerp(b, alpha)
		root.CFrame = CFrame.lookAt(position, position + vault.facing)
		root.AssemblyLinearVelocity = Vector3.zero
		if alpha >= 1 and vault.climb then -- [CLIMB] standing on top: on your feet, no follow-through
			hum:ChangeState(Enum.HumanoidStateType.Running)
			finishMovement()
			root.AssemblyLinearVelocity = Vector3.zero
			return true
		end
		if alpha >= 1 then
			-- Land standing (a crouch doesn't survive a vault) and keep running if a direction is held
			local MovementController = Get("MovementController")
			local carry = MovementController and MovementController.OnVaultLanded() or 0
			-- [ABILITY2] Fists Vault Takedown: landing next to an enemy topples them
			local Abilities = Get("AbilityController")
			if Abilities and Abilities.OnVaultLanded then task.spawn(Abilities.OnVaultLanded) end
			hum:ChangeState(Enum.HumanoidStateType.Freefall)
			local facing = vault.facing
			local vaultedPart = vault.part
			local wantCover = vault.wantCover
			if character then character:SetAttribute("SilentMove", nil) end
			finishMovement()
			-- A vault is just a vault: you land on your feet in the open. Two follow-ups:
			--   * Q pressed during the vault -> you take cover the moment you land, on the wall you just came
			--     over (it's right behind you); if that face won't take you, the nearest cover around you.
			--   * E pressed during it (or right after) -> you sneak to the cover under your crosshair (pendingDash).
			if wantCover then
				local waist = root.Position + Vector3.new(0, Config.WaistHeight, 0)
				local hit = castWorld(waist, -facing * (Config.VaultCoverReach + 2))
				root.AssemblyLinearVelocity = Vector3.zero
				hum:ChangeState(Enum.HumanoidStateType.Running) -- land on your feet: cover drops you if you're falling
				if hit and hit.Instance == vaultedPart and isUsableWall(hit) then
					savedWalkSpeed = hum.WalkSpeed
					enterCover(coverFromHit(hit))
					return true
				end
				task.delay(0.1, function()
					if not cover and not move and not vault then
						local found = findNearbyCover()
						if found then
							savedWalkSpeed = (humanoid :: Humanoid).WalkSpeed
							enterCover(found)
						else
							controller._SettleIntoCover(nil)
						end
					end
				end)
				return true
			end
			if hum.MoveDirection.Magnitude > 0.1 then
				root.AssemblyLinearVelocity = hum.MoveDirection.Unit * carry
			else
				root.AssemblyLinearVelocity = facing * carry * 0.5 -- small follow-through even with no key held
			end
		end
		return true
	end

	if move then
		-- Changed your mind: tap any movement key (W/A/S/D) during an E / Shift+E move to stop right there
		if moveCancelRequested then
			moveCancelRequested = false
			if not move.forced then
				finishMovement()
				return false
			end
		end
		-- Turning points: head for the next one once this one is reached
		if move.index < #move.route then
			local waypoint = move.route[move.index]
			if ((waypoint - root.Position) * FLAT).Magnitude < 1.5 then
				move.index += 1
				move.started = os.clock() -- reset the stall timer for the new leg
				hum:MoveTo(move.route[move.index])
			end
		end
		-- Face where you're running, turning at a natural rate (Roblox's AutoRotate snaps instantly)
		do
			local heading = (move.route[move.index] - root.Position) * FLAT
			local vel = root.AssemblyLinearVelocity * FLAT
			if vel.Magnitude > 3 then heading = vel end
			if heading.Magnitude > 0.2 then
				local look = root.CFrame.LookVector
				local currentYaw = math.atan2(-look.X, -look.Z)
				local wantYaw = math.atan2(-heading.X, -heading.Z)
				local diff = (wantYaw - currentYaw + math.pi) % (2 * math.pi) - math.pi
				local dtNow = math.min(os.clock() - (move.lastTurnAt or os.clock()), 0.1)
				move.lastTurnAt = os.clock()
				-- spin the body with angular velocity (writing the CFrame every frame would cancel MoveTo)
				local maxRate = math.rad(Config.MoveTurnRate or 720)
				local rate = math.clamp(diff * 14, -maxRate, maxRate)
				local _ = dtNow
				root.AssemblyAngularVelocity = Vector3.new(0, rate, 0)
			end
		end
		local finalLeg = move.index == #move.route
		local remaining = ((move.stand - root.Position) * FLAT).Magnitude
		local speedNow = (root.AssemblyLinearVelocity * FLAT).Magnitude
		local stalled = os.clock() - move.started > 0.35 and speedNow < 1.5 -- pressed against the cover already
		if not finalLeg then
			remaining = math.huge
		end
		if move.style == "Roll" and not move.rolled and remaining <= Config.RollDistance then
			move.rolled = true
			move.track = playMoveTrack("Roll")
			if move.track and move.track.Length > 0 then
				local timeLeft = math.max(remaining / Config.MoveSpeeds.Roll, 0.25)
				move.track:AdjustSpeed(move.track.Length / timeLeft) -- the roll lands you on the spot
			end
		end
		if stalled and finalLeg == false or (stalled and remaining > Config.DetectDistance + 1.5) then
			if (move.replans or 0) < 2 and move.targetPart then
				move.replans = (move.replans or 0) + 1
				local newRoute = planRoute(move.stand, move.targetPart)
				if newRoute then
					move.route, move.index = newRoute, 1
					move.started = os.clock()
					move.deadline = math.max(move.deadline, os.clock() + 3)
					hum:MoveTo(newRoute[1])
					return true
				end
			end
		end
		if remaining < 0.7 or stalled or move.arrived or os.clock() > move.deadline then
			local finished = move
			finishMovement()
			-- Take cover on arrival (if we ran to cover, not just open ground).
			-- First straight back toward the wall; if that misses (arrived off-line), aim right at the target face.
			local waist = root.Position + Vector3.new(0, Config.WaistHeight, 0)
			if finished.style == "Roll" then
				-- a roll can still be bouncing: look for the wall from standing height, not mid-bounce
				local down = castWorld(root.Position, Vector3.new(0, -12, 0))
				if down then waist = Vector3.new(root.Position.X, down.Position.Y + hum.HipHeight + root.Size.Y / 2 + Config.WaistHeight, root.Position.Z) end
			end
			local hit = finished.normal and castWorld(waist, -finished.normal * (Config.DetectDistance + 0.5))
			if (not hit or not isUsableWall(hit)) and finished.facePoint and finished.targetPart then
				local toFace = (Vector3.new(finished.facePoint.X, waist.Y, finished.facePoint.Z) - waist) * FLAT
				if toFace.Magnitude > 0.1 and toFace.Magnitude < Config.DetectDistance + 2 then
					local direct = castWorld(waist, toFace.Unit * (toFace.Magnitude + 1.5))
					if direct and direct.Instance == finished.targetPart then hit = direct end
				end
			end
			if (not hit or not isUsableWall(hit)) and finished.targetPart then
				-- Stopped short (snagged a corner, bumped something): lock onto the target anyway if it's
				-- within reach, preferring the face we were heading for.
				local bestHit, bestScore = nil, math.huge
				for i = 0, 15 do
					local angle = math.rad(i * 22.5)
					local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
					local r = castWorld(waist, dir * (Config.DetectDistance + 1.5))
					if r and r.Instance == finished.targetPart and isUsableWall(r) then
						local sameFace = finished.normal and (r.Normal * FLAT).Unit:Dot(finished.normal) > 0.9
						local score = r.Distance - (sameFace and 10 or 0)
						if score < bestScore then bestHit, bestScore = r, score end
					end
				end
				hit = bestHit
			end
			if hit and isUsableWall(hit) and not finished.noCover then
				if finished.style == "Roll" then
					-- a roll can bounce you off the floor: land on your feet first (cover drops you mid-fall)
					root.AssemblyLinearVelocity = Vector3.zero
					hum:ChangeState(Enum.HumanoidStateType.Running)
				end
				savedWalkSpeed = hum.WalkSpeed
				enterCover(coverFromHit(hit :: RaycastResult))
			elseif finished.style == "Roll" and finished.noCover == false and not finished.targetPart then
				-- a jump dive's roll with Q pressed: into the nearest cover around you
				root.AssemblyLinearVelocity = Vector3.zero
				hum:ChangeState(Enum.HumanoidStateType.Running)
				local nearby = findNearbyCover()
				if nearby then
					savedWalkSpeed = hum.WalkSpeed
					enterCover(nearby)
				end
			elseif finished.targetPart and not finished.forced then
				-- Stopped short of the cover you were heading for: don't leave you standing in the open if
				-- there's cover right beside you
				local nearby = findNearbyCover()
				if nearby then
					savedWalkSpeed = hum.WalkSpeed
					enterCover(nearby)
				end
			end
		end
		return true
	end
	return false
end

-- The stretch of a cover face you actually fit along. Something can sit right against the face (a low
-- wall built onto a pillar, a barrel, a table): sliding or peeking into it would put you inside it,
-- because cover places you directly rather than by physics. Measured once per cover, around where you
-- entered it, and used to clamp both where you stand and how far you lean out.
local freeParams = OverlapParams.new()
freeParams.FilterType = Enum.RaycastFilterType.Exclude
local function computeFreeRange(c, standY: number, startT: number)
	local chars = {}
	for _, player in Players:GetPlayers() do if player.Character then table.insert(chars, player.Character) end end
	table.insert(chars, c.part)
	freeParams.FilterDescendantsInstances = chars
	local function free(t: number): boolean
		local p = c.point + c.tangent * t + c.normal * Config.WallOffset
		local box = CFrame.new(p.X, standY, p.Z)
		for _, other in workspace:GetPartBoundsInBox(box, Vector3.new(1.3, 2.4, 1.3), freeParams) do
			if other.CanCollide then return false end
		end
		return not pointInObstacle(Vector3.new(p.X, standY, p.Z), 0.55)
	end
	local reachLo = c.minT - Config.PeekOutDistance - 0.5
	local reachHi = c.maxT + Config.PeekOutDistance + 0.5
	local step = 0.35
	-- entered at a blocked spot: start from the nearest free spot on the face
	local start = math.clamp(startT, reachLo, reachHi)
	if not free(start) then
		local found = nil
		for k = 1, math.ceil((reachHi - reachLo) / step) do
			for _, s in { 1, -1 } do
				local t = start + s * k * step
				if t >= reachLo and t <= reachHi and free(t) then found = t break end
			end
			if found then break end
		end
		if not found then return nil end
		start = found
	end
	local lo, hi = start, start
	while lo - step >= reachLo and free(lo - step) do lo -= step end
	while hi + step <= reachHi and free(hi + step) do hi += step end
	return lo, hi
end

local function update(dt: number)
	-- a buffered Space from just before a move/vault ended
	if pendingJump and not move and not vault then
		local p = pendingJump
		pendingJump = nil
		if os.clock() - p.at < 0.7 and cover then
			local target = cover.isLow and cover or nil
			if target then startVault(target, p.fast) end
		end
	end
	-- E pressed during a vault: as soon as you've landed, go to the cover you're pointing at
	if pendingDash and not move and not vault and not dive then
		local at = pendingDash
		pendingDash = nil
		if os.clock() - at < 1.5 and isAlive() and not cover then controller._QueuedDash() end
	end
	if not isAlive() then
		if move or vault or dive then finishMovement() end
		if cover then exitCover() end
		return
	end
	if updateMovement() then return end
	if not cover then return end
	if not cover.part.Parent then
		exitCover()
		return
	end

	local root = rootPart :: BasePart
	local hum = humanoid :: Humanoid
	local moveInput = inputDirection()
	local state = hum:GetState()
	if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then
		exitCover()
		return
	end

	-- Shift + ANY movement key: break cover and sprint off (Shift+E / Shift+Space alone still rush / vault)
	if moveInput.Magnitude > 0.1 and sprintHeld()
		and UserInputService:GetFocusedTextBox() == nil
		and not Players.LocalPlayer:GetAttribute("CoverLeaveLocked") and not CameraController.IsAiming() then
		exitCover()
		local Movement = shared.Get and shared.Get("MovementController")
		if Movement and Movement.OnCoverBroken then Movement.OnCoverBroken() end
		return
	end

	-- Moving straight away from the wall (e.g. S with your back to it) steps you out of cover.
	-- Held briefly first, so a tap doesn't pull you out by accident.
	-- (The tutorial can lock this via the LocalPlayer's CoverLeaveLocked attribute.)
	-- being shot at (near miss) interrupts the hold: you have to start it again once it stops
	if moveInput:Dot(cover.normal) > Config.LeaveDot and not Players.LocalPlayer:GetAttribute("CoverLeaveLocked") and os.clock() >= suppressUntil
		and os.clock() >= (cover.wrapGrace or 0) then
		cover.leaveHeld = (cover.leaveHeld or 0) + dt
		if cover.leaveHeld >= Config.LeaveHoldTime then
			exitCover()
			return
		end
	else
		cover.leaveHeld = 0
	end

	local lessonDrive: Vector3? = nil -- the shuffle lesson moves you itself
	-- Walking along the wall picks which edge you face.
	-- Aiming commits you: once you're aiming from one edge you stay on it (no sliding along the wall, no
	-- side changes) until you let go of right click. Stops the jitter of aiming while shuffling.
	local along = moveInput:Dot(cover.tangent)
	-- Tutorials: on a pillar you're pinned to its RIGHT edge (as you look at it), facing right.
	-- No sliding along it, no hugging round it, no carrying on to the next piece of cover.
	-- (TutorialPillarFree: the server frees it for the knife kill - loop round the pillar.
	--  TutorialPillarSide = "Left": tutorial 3 pins you to the left edge instead.)
	local pillarLock = Players.LocalPlayer:GetAttribute("TutorialActive") and not cover.isLow
		and not Players.LocalPlayer:GetAttribute("TutorialPillarFree")
		and (cover.maxT - cover.minT) <= (Config.TutorialPillarWidth or 6.5)
	-- The one exception is the "slide along cover" lesson (TutorialShuffle): then A/D slide you across
	-- the pillar's face and stop dead at its ends.
	local shuffleLesson = pillarLock and Players.LocalPlayer:GetAttribute("TutorialShuffle")
	cover.pillarLocked = pillarLock and true or nil
	if pillarLock and not shuffleLesson then
		local camRight = (-cover.normal * FLAT):Cross(Vector3.yAxis)
		cover.side = cover.tangent:Dot(camRight) >= 0 and 1 or -1
		if Players.LocalPlayer:GetAttribute("TutorialPillarSide") == "Left" then cover.side = -cover.side end
		along = 0
	elseif shuffleLesson then
		-- The lesson: [A] slides you all the way across the pillar, THEN [D] all the way back. [D] does
		-- nothing until [A] is done, and one tap carries you to the end by itself.
		local tNow = (root.Position - cover.point):Dot(cover.tangent)
		local loEdge = math.max(cover.minT + Config.EdgeMargin, cover.freeLo or -math.huge)
		local hiEdge = math.min(cover.maxT - Config.EdgeMargin, cover.freeHi or math.huge)
		local stage = cover.lessonStage or 0
		if stage == 0 then
			Players.LocalPlayer:SetAttribute("ShuffleDone", nil)
			if along < -0.3 then stage = 1 end
		elseif stage == 2 and along > 0.3 then
			stage = 3
		end
		lessonDrive = nil
		if stage == 1 then
			cover.side = -1
			along = -1
			lessonDrive = -cover.tangent
			if tNow <= loEdge + 0.08 then stage = 2 end
		elseif stage == 3 then
			cover.side = 1
			along = 1
			lessonDrive = cover.tangent
			if tNow >= hiEdge - 0.08 then
				stage = 4
				Players.LocalPlayer:SetAttribute("ShuffleDone", true)
			end
		end
		if stage ~= 1 and stage ~= 3 then along = 0 lessonDrive = nil end
		cover.lessonStage = stage
	elseif CameraController.IsAiming() or peekBlend > 0.05 then
		along = 0
	elseif along > 0.3 then cover.side = 1 elseif along < -0.3 then cover.side = -1 end

	-- Stay on the wall, between its edges
	local position = root.Position
	local t = (position - cover.point):Dot(cover.tangent)
	local lo, hi = cover.minT + Config.EdgeMargin, cover.maxT - Config.EdgeMargin
	if lo > hi then -- narrow pillar: stay centred
		local mid = (cover.minT + cover.maxT) / 2
		lo, hi = mid, mid
	end
	if pillarLock and not shuffleLesson then
		-- sit at the right-hand end, still facing right, but tucked TutorialPillarTuck studs in from it so
		-- no part of you shows past the edge while you're hidden (peeking leans you back out as normal)
		-- tutorials 1-2 (right edge): 0.9 studs in; tutorial 3 (left edge): 0.3 studs in (to the right)
		local leftSide = Players.LocalPlayer:GetAttribute("TutorialPillarSide") == "Left"
		local tuckBase = leftSide and (Config.TutorialPillarTuckLeft or 0.3) or (Config.TutorialPillarTuck or 0.9)
		local tuck = tuckBase * (1 - math.clamp(peekBlend, 0, 1))
		if cover.side > 0 then
			lo = hi - tuck
			hi = lo
		else
			hi = lo + tuck
			lo = hi
		end
	end
	-- only the part of the face you fit along (see computeFreeRange)
	if cover.freeLo == nil then
		local fLo, fHi = computeFreeRange(cover, position.Y, t)
		cover.freeLo, cover.freeHi = fLo or t, fHi or t
	end
	lo, hi = math.max(lo, cover.freeLo), math.min(hi, cover.freeHi)
	if lo > hi then
		local mid = math.clamp((lo + hi) / 2, cover.freeLo, cover.freeHi)
		lo, hi = mid, mid
	end
	local tClamped = math.clamp(t, lo, hi)

	-- Moving onto touching cover (a stud or less away), in either of two ways:
	--   * you reach the end of this cover and the next piece continues past it (pillar -> thinner box)
	--   * the next piece sticks out further and blocks you before you reach the end (box -> thicker pillar)
	-- Either way you carry straight on onto the new piece's matching face.
	local dir = (along > 0.3 and 1) or (along < -0.3 and -1) or 0
	local atEnd = (dir > 0 and t >= hi - 0.05) or (dir < 0 and t <= lo + 0.05)
	local ahead = nil
	if dir ~= 0 then
		-- Cast through the wall-side half of your body (a thicker neighbour sticks out into that half,
		-- so a ray down your centre line would slip past in front of it)
		local from = position + Vector3.new(0, Config.WaistHeight, 0) - cover.normal * 0.6
		local hitAhead = castWorld(from, cover.tangent * dir * (1.2 + Config.AdjacentGap), cover.part)
		if hitAhead and hitAhead.Instance ~= cover.part and hitAhead.Instance.CanCollide then ahead = hitAhead end
	end
	local pushing = (atEnd or ahead) and dir or 0

	if pushing ~= 0 and not CameraController.IsAiming() and not pillarLock then
		local candidate = nil
		if ahead then
			-- The face of the blocking object that faces the same way as ours
			candidate = faceWithNormal(ahead.Instance, cover.normal, position + cover.tangent * dir * 2)
		end
		if not candidate and atEnd then
			local edgeT = dir > 0 and cover.maxT or cover.minT
			local probeT = edgeT + dir * (Config.AdjacentGap + 0.3)
			local probeFrom = cover.point + cover.tangent * probeT + cover.normal * Config.WallOffset
			probeFrom = Vector3.new(probeFrom.X, position.Y + Config.WaistHeight, probeFrom.Z)
			candidate = castWorld(probeFrom, -cover.normal * (Config.WallOffset + (Config.AdjacentDepth or Config.AdjacentGap) + 0.3), cover.part)
		end
		if candidate and candidate.Instance ~= cover.part and isUsableWall(candidate)
			and (candidate.Normal * FLAT).Unit:Dot(cover.normal) > 0.9
			-- the new face can't be more than the gap in front of / behind ours
			and math.abs((candidate.Position - cover.point):Dot(cover.normal)) <= (Config.AdjacentDepth or Config.AdjacentGap) + 0.6 then
			local nextCover = coverFromHit(candidate)
			nextCover.side = nextCover.tangent:Dot(cover.tangent * dir) > 0 and 1 or -1 -- keep heading the same way
			local wasCrouched = crouched
			-- Onto a face that sits further in (pillar -> thinner box, which also drops you into a crouch):
			-- glide in instead of snapping, and the camera follows softly (see CameraSoft). A face that sticks
			-- out further (box -> pillar) still steps you out briskly, or its corner would block your shuffle.
			local stepOut = (nextCover.point - cover.point):Dot(cover.normal)
			local glideTime = Config.AdjacentGlideTime or 0.5
			if stepOut < 0.3 then nextCover.softUntil = os.clock() + glideTime end
			nextCover.camSoftUntil = os.clock() + glideTime -- the camera eases through the hand-off either way
			cover = nextCover
			crouched = wasCrouched and not nextCover.isLow
			peekBlend = 0
			return
		end
	end

	-- Corner wrap: keep holding the direction at the end of TALL cover (a pillar, a crate) with nothing
	-- to carry on onto, and you hug round the corner onto the next face - so you can creep all the
	-- way round a pillar without leaving cover.
	if pushing ~= 0 and atEnd and not ahead and not cover.isLow and not CameraController.IsAiming() and os.clock() >= suppressUntil
		and Config.CornerWrap == true -- (pass 43) off: circling round pillars was too glitchy
		and not Players.LocalPlayer:GetAttribute("NoCornerWrap") and not pillarLock then
		cover.wrapHeld = (cover.wrapHeld or 0) + dt
		if cover.wrapHeld >= (Config.CornerWrapHold or 0.35) then
			cover.wrapHeld = 0
			local edgeT = dir > 0 and cover.maxT or cover.minT
			local up = Vector3.new(0, position.Y + Config.WaistHeight - cover.point.Y, 0)
			-- from just past the corner, a little behind the face, look back at the side face
			local from = cover.point + cover.tangent * (edgeT + dir * (Config.WallOffset + 0.4)) - cover.normal * 0.8 + up
			local side = castWorld(from, -cover.tangent * dir * (Config.WallOffset + 1.5))
			if side and side.Instance == cover.part and isUsableWall(side) then
				local nextCover = coverFromHit(side)
				-- keep travelling the same way round
				nextCover.side = nextCover.tangent:Dot(-cover.normal) > 0 and 1 or -1 -- facing on round the back
				-- swing the camera round with you by the angle between the two faces, so the key you're
				-- holding (input is camera-relative) keeps carrying you round instead of pushing you off
				local a, b = cover.normal * FLAT, nextCover.normal * FLAT
				local turn = math.atan2(a:Cross(b).Y, a:Dot(b))
				CameraController.TurnBy(turn)
				nextCover.wrapGrace = os.clock() + 0.5 -- don't count the turn as "leaving cover"
				-- path round the outside of the corner (diagonal off both faces)
				local cornerPoint = cover.point + cover.tangent * edgeT
				nextCover.via = cornerPoint + (cover.normal + cover.tangent * dir).Unit * (Config.WallOffset * 1.2)
				nextCover.viaUntil = os.clock() + 0.3
				nextCover.shoulderHold = shoulderNow -- keep the camera on the same shoulder through the swing
				cover = nextCover
				peekBlend = 0
				return
			end
		end
	else
		cover.wrapHeld = 0
	end

	-- Don't walk in place: no movement unless it slides you along the wall and you're not at the end
	local blockedMove = math.abs(along) < 0.3 or pushing ~= 0
	-- ease into and out of the shuffle instead of switching between full speed and a dead stop
	local wantSpeed = blockedMove and 0 or Config.CoverWalkSpeed
	local rate = (wantSpeed > coverSpeed and (Config.CoverAccel or 55) or (Config.CoverDecel or 80)) * dt
	coverSpeed = coverSpeed + math.clamp(wantSpeed - coverSpeed, -rate, rate)
	if pushing ~= 0 then coverSpeed = 0 end -- at an end / against something: stop there
	hum.WalkSpeed = coverSpeed
	if lessonDrive and pushing == 0 then hum:Move(lessonDrive, false) end

	local nearEdge = (cover.side > 0 and hi - tClamped < Config.PeekEdgeDistance)
		or (cover.side < 0 and tClamped - lo < Config.PeekEdgeDistance)
	cover.nearEdge = nearEdge
	local aiming = CameraController.IsAiming() -- already false behind tall cover away from an edge (BlocksAim)
	local blind = os.clock() < blindUntil
	local low = cover.isLow or crouched

	-- How you peek is decided when the peek starts.
	--   Tall cover: step out past the edge you're at.
	--   Low cover: by the crosshair. Aiming past an end of the crate leans out around that end;
	--   anywhere else rises up over the top.
	local wantPeek = aiming and (cover.isLow or nearEdge)
	if peekBlend == 0 and wantPeek then
		if cover.isLow then
			local origin, look = crosshairRay()
			local tAim
			local into = look:Dot(-cover.normal)
			if into > 0.05 then
				local dist = (cover.point - origin):Dot(-cover.normal) / into
				tAim = (origin + look * dist - cover.point):Dot(cover.tangent)
			else
				tAim = look:Dot(cover.tangent) > 0 and math.huge or -math.huge
			end
			if tAim > cover.maxT - Config.SidePeekMargin then
				cover.peekMode, cover.side = "side", 1
			elseif tAim < cover.minT + Config.SidePeekMargin then
				cover.peekMode, cover.side = "side", -1
			else
				cover.peekMode = "over"
			end
		else
			cover.peekMode = "side"
		end
	end
	local suppressed = os.clock() < suppressUntil
	if suppressed then wantPeek = false end
	peekBlend = moveToward(peekBlend, wantPeek and 1 or 0, dt / (suppressed and Config.PeekTime * 0.5 or Config.PeekTime))

	-- Side peeks slide out past the edge
	local tTarget = tClamped
	if cover.peekMode == "side" then
		local edgeT = cover.side > 0 and cover.maxT or cover.minT
		local peekT = edgeT + cover.side * Config.PeekOutDistance
		tTarget = tClamped + (peekT - tClamped) * peekBlend
	end
	if cover.freeLo then tTarget = math.clamp(tTarget, cover.freeLo, cover.freeHi) end -- never lean into something

	-- Ease toward the spot instead of snapping (entering from a few studs away glides in)
	local target = cover.point + cover.tangent * tTarget + cover.normal * Config.WallOffset
	-- Knocked well away from the cover (blast, server correction): let go rather than dragging you back
	-- through whatever is in between
	if not cover.via and ((target - position) * FLAT).Magnitude > Config.DetectDistance + 2.5 then
		exitCover()
		return
	end
	local alpha = 1 - math.exp(-Config.SnapSharpness * dt)
	-- Just carried on onto this piece (pillar -> box): glide onto its face instead of being yanked. The new
	-- face sits a stud or two further in, and its end is ahead of you - both are eased in gently and
	-- capped, so you keep a steady shuffle speed through the hand-off.
	local gliding = cover.softUntil ~= nil and os.clock() < cover.softUntil
	if gliding then alpha = 1 - math.exp(-Config.SnapSharpness * 0.4 * dt) end
	if cover.via then
		-- wrapping a corner: round the outside of it first instead of cutting across it
		if ((position - cover.via) * FLAT).Magnitude < 0.3 or os.clock() > cover.viaUntil then
			cover.via = nil
		else
			target = cover.via
			alpha = 1 - math.exp(-Config.SnapSharpness * 1.5 * dt)
		end
	end
	local flatPos = Vector3.new(position.X, 0, position.Z):Lerp(Vector3.new(target.X, 0, target.Z), alpha)
	if gliding and not cover.via then
		local flatNow = Vector3.new(position.X, 0, position.Z)
		local correction = flatPos - flatNow
		-- along the wall you're already walking there, so barely nudge; off the wall, settle in gently
		local alongC = cover.tangent * correction:Dot(cover.tangent)
		local acrossC = correction - alongC
		local walkingThere = coverSpeed > 1 and dir ~= 0 and correction:Dot(cover.tangent) * dir > 0
		local maxAlong, maxAcross = (walkingThere and 0 or 2.5) * dt, Config.CoverWalkSpeed * 0.45 * dt
		if alongC.Magnitude > maxAlong then alongC = alongC.Unit * maxAlong end
		if acrossC.Magnitude > maxAcross then acrossC = acrossC.Unit * maxAcross end
		flatPos = flatNow + alongC + acrossC
	end
	local newPos = Vector3.new(flatPos.X, position.Y, flatPos.Z)

	-- GTA style: back against the wall, facing out. Moving along it is a sideways shuffle with the
	-- head turned toward the edge you're heading for, so switching direction never spins you around.
	local facing = cover.tangent * cover.side -- the edge you're looking toward
	local wantRotation
	if aiming then
		wantRotation = root.CFrame.Rotation -- camera turns you toward the crosshair
	elseif blind and cover.isLow then
		wantRotation = CFrame.lookAt(Vector3.zero, -cover.normal).Rotation -- face the crate to reach over it
	elseif blind then
		wantRotation = CFrame.lookAt(Vector3.zero, facing).Rotation -- turn to curl the arm round the edge
	else
		wantRotation = CFrame.lookAt(Vector3.zero, cover.normal).Rotation -- back to the wall
	end
	-- Turn by yaw, always the way that passes the edge you're peeking from (never round the far side
	-- through the wall). A plain rotation blend picks either way for near-180 turns.
	local turnAlpha = 1 - math.exp(-Config.TurnSharpness * dt)
	local function yawOf(v: Vector3) return math.atan2(-v.X, -v.Z) end
	local function wrap(a: number) return (a + math.pi) % (2 * math.pi) - math.pi end
	local currentYaw = yawOf(root.CFrame.LookVector)
	local delta = wrap(yawOf(wantRotation.LookVector) - currentYaw)
	if math.abs(delta) > math.rad(100) then
		local towardEdge = wrap(yawOf(facing) - currentYaw)
		if towardEdge ~= 0 and math.sign(delta) ~= math.sign(towardEdge) then
			delta -= math.sign(delta) * 2 * math.pi
		end
	end
	local turnStep = delta * turnAlpha
	local maxTurn = math.rad(Config.CoverTurnRate or 620) * dt
	turnStep = math.clamp(turnStep, -maxTurn, maxTurn)
	root.CFrame = CFrame.new(newPos) * CFrame.fromOrientation(0, currentYaw + turnStep, 0)

	-- Camera on the shoulder of the edge you're facing (the gun follows to that hand)
	local cameraRight = workspace.CurrentCamera.CFrame.RightVector
	local shoulder = facing:Dot(cameraRight) >= 0 and 1 or -1
	if cover.shoulderHold and os.clock() < (cover.wrapGrace or 0) then
		shoulder = cover.shoulderHold -- mid corner-swing: don't flip shoulders while the view turns
	end
	shoulderNow = shoulder
	CameraController.SetShoulder(shoulder)

	-- Pose weights (all cover poses outrank the normal gun poses)
	local suffix = shoulder < 0 and "Left" or ""
	local weights = {}
	if blind then
		local blindPose = cover.isLow and "BlindOver" or (crouched and "BlindCornerCrouch" or "BlindCorner")
		weights[blindPose .. suffix] = 1
	elseif low and cover.peekMode == "side" then
		weights["Crouch" .. suffix] = 1 - peekBlend
		weights["CrouchPeek" .. suffix] = peekBlend
	else
		weights[(low and "Crouch" or "IdleTall") .. suffix] = 1 - peekBlend -- rising up / stepping out fades it
	end
	-- Head toward the edge, and the side-shuffle while sliding (both fade out as you peek)
	local alongSpeed = math.abs((root.AssemblyLinearVelocity):Dot(cover.tangent))
	if not blind and not aiming then
		weights[cover.side > 0 and "LookPos" or "LookNeg"] = 1 - peekBlend
		if alongSpeed > 1 then
			weights[low and "ShuffleCrouch" or "ShuffleTall"] = 1 - peekBlend
		end
	end

	for name, track in (coverTracks or {}) do
		local weight = weights[name] or 0
		if weight > 0.001 then
			if not track.IsPlaying then track:Play(0.15) end
			track:AdjustWeight(weight, 0.1)
			if name == "ShuffleTall" or name == "ShuffleCrouch" then
				track:AdjustSpeed(math.clamp(alongSpeed / Config.CoverWalkSpeed, 0.4, 1.5))
			end
		elseif track.IsPlaying then
			track:Stop(0.18)
		end
	end
end

-- // Input
local onDashKey -- [PAD] dash on a controller = D-pad up (Edward 2026-10-21; was double-tap LB)
local function onCoverKey(_, inputState: Enum.UserInputState, input: InputObject?)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	-- Q during a jump dive (or its roll): finish it in cover
	if isAlive() and dive then
		dive.wantCover = true
		return Enum.ContextActionResult.Sink
	end
	if isAlive() and move and move.noCover ~= nil then
		move.noCover = false
		return Enum.ContextActionResult.Sink
	end
	-- Q while vaulting: you'll drop into cover the moment you land
	if isAlive() and vault then
		vault.wantCover = true
		return Enum.ContextActionResult.Sink
	end
	-- Q while sliding: the slide ends in cover (otherwise a slide just stands you back up)
	local Movement = Get and Get("MovementController")
	if isAlive() and not cover and Movement and Movement.IsSliding and Movement.IsSliding() then
		if Movement.QueueSlideCover then Movement.QueueSlideCover() end
		return Enum.ContextActionResult.Sink
	end
	if not isAlive() or move or vault or dive then return Enum.ContextActionResult.Sink end

	-- Q only takes cover right next to you or leaves it. Moving to other cover is E.
	if cover then
		exitCover()
		return Enum.ContextActionResult.Sink
	else
		local found = findNearbyCover(true)
		if found then
			savedWalkSpeed = (humanoid :: Humanoid).WalkSpeed
			enterCover(found)
			-- Q right after a slide ended still counts as sliding into cover (you stay low behind it)
			if Movement and Movement.SlideEndedRecently and Movement.SlideEndedRecently(0.8) then
				controller.SetCrouched(true)
				localPlayer:SetAttribute("SlideCoverAt", os.clock())
			end
		end
	end
	return Enum.ContextActionResult.Sink
end

-- E: the cover under your crosshair, and which face of it to run to.
--   * The crosshair picks the OBJECT: the wall / crate it's on (or, aiming at the floor just short of one,
--     the cover straight ahead of that spot). Nothing there -> nothing happens: you stay where you are,
--     in cover or not. It never goes looking for the nearest cover instead.
--   * Where YOU are picks the FACE: from cover, the face looking the same way as your cover (you stay
--     hidden from the same side); from the open, the face on your side of it (south of it -> its south
--     face, west of it -> its west face). Only if that face can't be reached do the others get a turn,
--     nearest first.
local function aimedCover(origin: Vector3, look: Vector3): (BasePart?, Vector3?)
	local hit = castWorld(origin, look * (Config.MoveMaxDistance + 20), cover and cover.part or nil)
	if not hit or not hit.Instance:IsA("BasePart") then return nil end
	local part = hit.Instance :: BasePart
	if hit.Normal.Y > 0.7 then
		-- the top of a crate
		if part.CanCollide and not part:GetAttribute("NotCover") and faceToward(part, hit.Position) then
			return part, hit.Position
		end
		-- the floor just short of a piece of cover: the cover straight ahead of that spot
		local fwd = look * FLAT
		if fwd.Magnitude < 0.1 then return nil end
		local spot = Vector3.new(hit.Position.X, (rootPart :: BasePart).Position.Y + Config.WaistHeight, hit.Position.Z)
		local floorSpot = Vector3.new(hit.Position.X, (rootPart :: BasePart).Position.Y, hit.Position.Z)
		for _, deg in { 0, -20, 20 } do
			local dir = CFrame.Angles(0, math.rad(deg), 0) * fwd.Unit
			local probe = castWorld(spot, dir * Config.SpotCoverReach, cover and cover.part or nil)
			if isUsableWall(probe) then return (probe :: RaycastResult).Instance :: BasePart, (probe :: RaycastResult).Position, floorSpot end
		end
		-- [COVERAIM] (Edward 2026-10-18: aiming at the floor beside / behind a crate's corner should still take you there,
		-- "make it also be relative to the cover around you"): the nearest cover in ANY direction around the aimed spot
		local best: RaycastResult? = nil
		local reach = math.max(Config.SpotCoverReach, 7)
		for i = 0, 15 do
			local a = math.rad(i * 22.5)
			local probe = castWorld(spot, Vector3.new(math.cos(a), 0, math.sin(a)) * reach, cover and cover.part or nil)
			if isUsableWall(probe) and (not best or (probe :: RaycastResult).Distance < best.Distance) then best = probe end
		end
		if best then return best.Instance :: BasePart, best.Position, floorSpot end
		return nil
	end
	if not isUsableWall(hit) then return nil end
	return part, hit.Position
end

-- Returns stand, hit, route, takeNow (the face is right next to you: just take cover), tooFar
local function pickCoverTarget(origin: Vector3, look: Vector3)
	if not isAlive() then return nil end
	local part, aimPoint, floorSpot = aimedCover(origin, look)
	if not part or not aimPoint then return nil end
	if cover and part == cover.part then return nil end -- same object: slide along it instead
	local only = localPlayer:GetAttribute("MoveTarget")
	if only and part.Name ~= only then return nil end
	local root = rootPart :: BasePart

	local ordered, seen = {}, {}
	local function add(face)
		if not face or not isUsableWall(face) then return end
		local n = (face.Normal * FLAT).Unit
		for _, m in seen do
			if m:Dot(n) > 0.9 then return end
		end
		table.insert(seen, n)
		table.insert(ordered, face)
	end
	-- [COVERAIM] aimed at the floor: the side of that cover closest to where you aimed (behind the crate -> its back)
	if floorSpot and not cover then
		local sides = {}
		local cf0 = part.CFrame
		for _, n in { cf0.RightVector, -cf0.RightVector, cf0.LookVector, -cf0.LookVector } do
			local flat = n * FLAT
			if flat.Magnitude > 0.5 then
				local face = faceWithNormal(part, flat.Unit, floorSpot)
				if face and isUsableWall(face) then
					local st = face.Position + (face.Normal * FLAT).Unit * Config.WallOffset
					table.insert(sides, { face = face, d = ((st - floorSpot) * FLAT).Magnitude })
				end
			end
		end
		table.sort(sides, function(a, b) return a.d < b.d end)
		for _, s in sides do add(s.face) end
	end
	if cover then add(backFace(part, aimPoint)) end
	add(faceOnYourSide(part, aimPoint))
	local rest = {}
	local cf = part.CFrame
	for _, n in { cf.RightVector, -cf.RightVector, cf.LookVector, -cf.LookVector } do
		local flat = n * FLAT
		if flat.Magnitude > 0.5 then
			local face = faceWithNormal(part, flat.Unit, aimPoint)
			if face then table.insert(rest, face) end
		end
	end
	table.sort(rest, function(a, b)
		return ((a.Position - root.Position) * FLAT).Magnitude < ((b.Position - root.Position) * FLAT).Magnitude
	end)
	for _, f in rest do add(f) end

	local tooFar = false
	for _, face in ordered do
		local h = insetOnFace(face)
		local stand = h.Position + (h.Normal * FLAT).Unit * Config.WallOffset
		stand = Vector3.new(stand.X, root.Position.Y, stand.Z)
		local dist = ((stand - root.Position) * FLAT).Magnitude
		if dist < Config.MoveMinDistance then
			if not cover then return stand, h, nil, true, false end -- right next to it: take cover now
		elseif dist <= Config.MoveMaxDistance then
			local route = planRoute(stand, part)
			if route then return stand, h, route, false, false end
			-- in the air (a hop): a jump dive flies straight there over low walls, no ground route needed
			if controller.IsHopping() then return stand, h, nil, false, false end
		else
			tooFar = true
		end
	end
	return nil, nil, nil, false, tooFar
end

-- (Older E fallback, kept for reference / other callers.) The crosshair is on a piece of cover but the normal pick found nothing (the face it chose
-- was too close to bother moving to, or no route round to it). Try each side of that cover instead:
--   * a side right next to you -> just take cover on it now
--   * otherwise the nearest side you can actually run to
-- So pressing E while aiming at cover always does something.
local function fallbackTarget(origin: Vector3, look: Vector3)
	local first = castWorld(origin, look * (Config.MoveMaxDistance + 20), cover and cover.part or nil)
	if not first or not first.Instance:IsA("BasePart") then return nil end
	local part = first.Instance :: BasePart
	if cover and part == cover.part then return nil end
	if part:GetAttribute("NotCover") or not part.CanCollide then return nil end
	local only = localPlayer:GetAttribute("MoveTarget")
	if only and part.Name ~= only then return nil end
	local root = rootPart :: BasePart
	local options = {}
	if cover then
		local back = backFace(part, first.Position)
		if back then table.insert(options, back) end
	else
		local cf = part.CFrame
		for _, n in { cf.RightVector, -cf.RightVector, cf.LookVector, -cf.LookVector } do
			local flat = n * FLAT
			if flat.Magnitude > 0.5 then
				local face = faceWithNormal(part, flat.Unit, first.Position)
				if face then table.insert(options, face) end
			end
		end
	end
	local scored = {}
	for _, face in options do
		if isUsableWall(face) then
			local h = insetOnFace(face)
			local stand = h.Position + (h.Normal * FLAT).Unit * Config.WallOffset
			stand = Vector3.new(stand.X, root.Position.Y, stand.Z)
			table.insert(scored, { hit = h, stand = stand, dist = ((stand - root.Position) * FLAT).Magnitude })
		end
	end
	table.sort(scored, function(a, b) return a.dist < b.dist end)
	for _, option in scored do
		if option.dist < Config.MoveMinDistance and not cover then
			return option.stand, option.hit, nil, true -- right here: take it now
		end
		if option.dist <= Config.MoveMaxDistance then
			local route = planRoute(option.stand, part)
			if route then return option.stand, option.hit, route, false end
		end
	end
	return nil
end

-- A small cue under the crosshair when E can't do anything with what you're aiming at (e.g. too far),
-- so a press never just silently does nothing
local hintLabel: TextLabel? = nil
local hintToken = 0
local function showCoverHint(text: string)
	if not hintLabel then
		local gui = Instance.new("ScreenGui")
		gui.Name = "CoverHint"
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		local label = Instance.new("TextLabel")
		label.AnchorPoint = Vector2.new(0.5, 0)
		label.Position = UDim2.new(0.5, 0, 0.5, 34)
		label.Size = UDim2.fromOffset(200, 22)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextSize = 14
		label.TextColor3 = Color3.fromRGB(255, 200, 120)
		label.TextStrokeTransparency = 0.5
		label.TextTransparency = 1
		label.Parent = gui
		gui.Parent = localPlayer:WaitForChild("PlayerGui")
		hintLabel = label
	end
	local label = hintLabel :: TextLabel
	hintToken += 1
	local token = hintToken
	label.Text = text
	label.TextTransparency = 0
	label.TextStrokeTransparency = 0.5
	task.delay(0.7, function()
		if token ~= hintToken then return end
		game:GetService("TweenService"):Create(label, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
end

function onDashKey(_, inputState: Enum.UserInputState) -- (forward-declared above for the LB double tap)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	local boardDive = os.clock() < diveArmUntil and sprintHeld()
	if isAlive() and vault and not boardDive then
		pendingDash = os.clock() -- go there quietly the moment you land
		return Enum.ContextActionResult.Sink
	end
	if isAlive() and boardDive and (cover or vault) and not move and not dive then
		-- Shift+Space+E: launch off this cover at the one under your crosshair (from wherever the vault has got to)
		diveArmUntil = 0
		local origin, look = crosshairRay()
		local root = rootPart :: BasePart
		local realCF = root.CFrame
		local wasVault = vault
		if wasVault then
			-- judge the target from the floor below you, like a hop
			local down = castWorld(realCF.Position, Vector3.new(0, -30, 0))
			if down then
				local standY = down.Position.Y + (humanoid :: Humanoid).HipHeight + root.Size.Y / 2
				root.CFrame = realCF - Vector3.new(0, realCF.Position.Y - standY, 0)
			end
		end
		local wasCover = cover
		local stand, hit
		for _, degrees in Config.DashAimAssist do
			local s2, h2 = pickCoverTarget(origin, (CFrame.Angles(0, math.rad(degrees), 0) * look).Unit)
			if s2 and h2 and (not wasCover or h2.Instance ~= wasCover.part) then stand, hit = s2, h2 break end
		end
		root.CFrame = realCF
		if stand and hit then
			if wasVault then
				if vault.track then vault.track:Stop(0.1) end
				if character then character:SetAttribute("SilentMove", nil) end
				vault = nil
			end
			if not cover then savedWalkSpeed = (humanoid :: Humanoid).WalkSpeed end
			if startDive(hit, stand, true) then return Enum.ContextActionResult.Sink end
		end
		if wasVault then return Enum.ContextActionResult.Sink end
	end
	if not isAlive() or move or vault or dive then return Enum.ContextActionResult.Sink end
	-- (Sneaking (E alone) can be switched off below, e.g. tutorial 1 teaches only the Shift+E rush)
	if localPlayer:GetAttribute("SneakDisabled") and not sprintHeld() then
		return Enum.ContextActionResult.Sink
	end
	-- The cover under the crosshair (a hair of tolerance for thin pillars far away), on your side of it
	local baseOrigin, baseLook = crosshairRay()
	local stand, hit, route
	local takeNow, tooFar = false, false
	-- In the air (a hop), the cover is judged from where you'd be standing on the floor below you - otherwise
	-- a low box sits under your waist and doesn't count as cover. (Same frame: you never see the move.)
	local airborne = controller.IsHopping()
	local realCF = (rootPart :: BasePart).CFrame
	if airborne then
		local hum = humanoid :: Humanoid
		local down = castWorld(realCF.Position, Vector3.new(0, -30, 0))
		if down then
			local standY = down.Position.Y + hum.HipHeight + (rootPart :: BasePart).Size.Y / 2
			(rootPart :: BasePart).CFrame = realCF - Vector3.new(0, realCF.Position.Y - standY, 0)
		end
	end
	for _, degrees in Config.DashAimAssist do
		local look = (CFrame.Angles(0, math.rad(degrees), 0) * baseLook).Unit
		local s, h, r, now, far = pickCoverTarget(baseOrigin, look)
		if s and h then
			stand, hit, route, takeNow = s, h, r, now
			break
		end
		tooFar = tooFar or far == true
	end
	if airborne then
		(rootPart :: BasePart).CFrame = realCF
		takeNow = false -- in the air you dive / roll in, even when it's close
	end
	-- In mid-air (a hop) with Shift held: DIVE-roll straight into it (the quickest way into cover)
	if false and stand and hit then -- (the old Shift+E-in-the-air dive: replaced by double-tap Space)
		local only = localPlayer:GetAttribute("MoveTarget")
		if not only or hit.Instance.Name == only then
			if not cover then savedWalkSpeed = (humanoid :: Humanoid).WalkSpeed end
			if startDive(hit, stand) then return Enum.ContextActionResult.Sink end
		end
	end
	if stand and takeNow and hit then
		savedWalkSpeed = (humanoid :: Humanoid).WalkSpeed
		enterCover(coverFromHit(hit))
	elseif stand then
		if not cover then savedWalkSpeed = (humanoid :: Humanoid).WalkSpeed end
		startMove(hit, stand, route)
	else
		-- nothing under the crosshair to go to: do nothing (stay in cover if you're in it). Say why if
		-- you're aiming at cover that's out of reach.
		local aimed = castWorld(baseOrigin, baseLook * 200, cover and cover.part or nil)
		local far = tooFar
		if not far and aimed and isUsableWall(aimed) then
			far = ((aimed.Position - (rootPart :: BasePart).Position) * FLAT).Magnitude > Config.MoveMaxDistance
		end
		if far and not (localPlayer:GetAttribute("MoveTarget")) then showCoverHint("Too far") end
	end
	return Enum.ContextActionResult.Sink
end

function controller._QueuedDash()
	onDashKey("CoverDash", Enum.UserInputState.Begin)
end

local function onCrouchKey(_, inputState: Enum.UserInputState)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	-- Only matters behind tall cover; low cover already keeps you crouched
	if cover and not cover.isLow then
		crouched = not crouched
		setStance(crouched)
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

local function isGrounded(): boolean
	local state = (humanoid :: Humanoid):GetState()
	return state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.RunningNoPhysics
		or state == Enum.HumanoidStateType.Landed
end

-- Space always comes here, so Roblox's own jump never fires (this binding outranks it and sinks the key).
--   Behind / in front of low cover -> vault it.   Anywhere else -> a short GTA-style hop.
-- Hop and shooting lock each other out: no hop until the last shot has finished, no shooting mid-hop.

-- Double vault: right after a running vault (Shift+Space) lands, Space alone vaults you straight back
-- over the same wall and into cover - no Shift needed for the second one.
local function tryDoubleVault(): boolean
	if os.clock() > doubleVaultUntil or not lastVaulted or not lastVaulted.Parent or cover or move or vault then return false end
	local hit = faceToward(lastVaulted, lastVaulted.Position)
	if not hit or hit.Distance > Config.RevaultReach + 1 then return false end
	local c = coverFromHit(hit)
	if not c.isLow then return false end
	doubleVaultUntil = 0
	return startVault(c, true)
end

local function onJumpKey(_, inputState: Enum.UserInputState)
	if inputState ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Sink end
	-- Double-tap Space: JUMP DIVE, from anywhere (in the open, in any cover, mid-hop or mid-vault)
	local now = os.clock()
	local doubleTap = now - lastSpaceAt < (Config.DiveDoubleTap or 0.35)
	lastSpaceAt = now
	-- [MECH] dive only from jump (Edward 2026-10-16): the first tap must have been a real hop and you're still in the air from it
	-- (never out of a vault, from cover or off the ground)
	local fromJump = now - lastHopAt < (Config.DiveDoubleTap or 0.35) and not vault and controller.IsHopping()
	if doubleTap and fromJump and isAlive() and not dive and not move and controller.JumpDive() then
		lastSpaceAt = 0
		return Enum.ContextActionResult.Sink
	end
	if isAlive() and vault then return Enum.ContextActionResult.Sink end -- (Q mid-vault = cover on landing)
	if isAlive() and move then
		-- pressed a moment early (still sliding into cover / landing): do it as soon as we can
		if not (localPlayer:GetAttribute("SneakDisabled") and not sprintHeld()) then
			pendingJump = { at = os.clock(), fast = sprintHeld() }
		end
		return Enum.ContextActionResult.Sink
	end
	if not isAlive() then return Enum.ContextActionResult.Sink end

	-- Shift+Space in cover: press E straight after and you dive out off it like a diving board
	-- [CLIMB] tall cover whose top is still under your head: climb onto it (before the stand-up below)
	do
		local tall = (cover and not cover.isLow) and cover or nil
		if not tall and not cover then
			local nearby = findNearbyCover()
			if nearby and not nearby.isLow then tall = nearby end
		end
		local stand = tall and climbSpot(tall)
		if stand and not localPlayer:GetAttribute("SneakDisabled") and startClimb(tall, stand) then return Enum.ContextActionResult.Sink end
	end
	-- Crouched behind tall cover: Space stands you back up (you can't jump in cover anyway).
	-- (Low cover keeps you crouched, so there Space still vaults.)
	if cover and not cover.isLow and crouched then
		crouched = false
		setStance(false)
		return Enum.ContextActionResult.Sink
	end

	-- Vault: the low cover you're in, or low cover right in front of you
	local target = (cover and cover.isLow) and cover or nil
	if not target and not cover then
		local nearby = findNearbyCover()
		if nearby and nearby.isLow then target = nearby end
	end
	-- Re-vault: the low cover you just came over is right behind you (e.g. you landed against a pillar)
	local revault = false
	if lastVaulted and lastVaulted.Parent and (not target or target.part == lastVaulted) then
		local hit = faceToward(lastVaulted, lastVaulted.Position)
		if hit and hit.Distance <= Config.RevaultReach then
			local c = coverFromHit(hit)
			if c.isLow then target = c revault = true end
		end
	end
	local fast = sprintHeld()
	-- Tutorial 1 teaches only the running vault: Space alone (the silent vault) is switched off there -
	-- except going straight back over the wall you just vaulted, which is always a running vault
	if localPlayer:GetAttribute("SneakDisabled") and not fast then
		if revault then fast = true
		elseif cover or target or findNearbyCover() then return Enum.ContextActionResult.Sink end
	end
	-- [CLIMB] too deep to vault across: climb on top of it instead
	if target and not revault and target.depth > CLIMB_MIN_DEPTH then
		local stand = climbSpot(target)
		if stand and startClimb(target, stand) then return Enum.ContextActionResult.Sink end
	end
	if target and startVault(target, fast) then
		return Enum.ContextActionResult.Sink
	end
	-- [CLIMB] the far side is blocked (vault refused): climb on top instead
	if target and not revault then
		local stand = climbSpot(target)
		if stand and startClimb(target, stand) then return Enum.ContextActionResult.Sink end
	end
	-- In cover, Space never jumps (it only vaults)
	if cover then return Enum.ContextActionResult.Sink end

	-- Hop
	if not isGrounded() or os.clock() < hopLockUntil then return Enum.ContextActionResult.Sink end
	if os.clock() - lastShotAt < Config.ShotHopLock then return Enum.ContextActionResult.Sink end
	if cover then exitCover() end
	hopLockUntil = os.clock() + 0.2
	lastHopAt = os.clock() -- [MECH] dive only from jump (Edward 2026-10-16)
	local hum = humanoid :: Humanoid
	hum.JumpHeight = Config.HopHeight
	-- (Not hum.Jump = true: Roblox's control script overwrites that flag every frame)
	hum:ChangeState(Enum.HumanoidStateType.Jumping)
	task.delay(0.15, function() -- back to 0 so nothing else (Roblox's own jump input) can jump
		if hum.Parent then hum.JumpHeight = 0 end
	end)
	return Enum.ContextActionResult.Sink
end

local function bindCharacter(newCharacter: Model)
	if move or vault or dive then finishMovement() end
	exitCover()
	character = newCharacter
	coverTracks, moveTracks = nil, nil
	-- (2026-10-21) the server rebuilds the body after a spawn and then sets Ready: tracks loaded earlier sit on the old joints
	newCharacter:GetAttributeChangedSignal("Ready"):Connect(function()
		if character ~= newCharacter then return end
		for _, set in { coverTracks or {}, moveTracks or {} } do for _, t in set do t:Stop(0) end end
		coverTracks, moveTracks = nil, nil
	end)
	humanoid = newCharacter:WaitForChild("Humanoid", 10) :: Humanoid?
	rootPart = newCharacter:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if humanoid then
		savedWalkSpeed = humanoid.WalkSpeed
		humanoid.UseJumpPower = false
		humanoid.JumpHeight = 0 -- Roblox's jump is off; Space hops / vaults through onJumpKey
	end
end

-- // Public
function controller.IsInCover(): boolean
	return cover ~= nil
end

-- Take cover on whatever is right in front of you (tutorial uses this). Returns true if it worked.
function controller.TryEnterCover(): boolean
	if cover or move or vault or not isAlive() then return cover ~= nil end
	local found = findNearbyCover()
	if not found then return false end
	savedWalkSpeed = (humanoid :: Humanoid).WalkSpeed
	enterCover(found)
	return true
end

-- The cover box you're in (nil if not in cover)
function controller.GetCoverPart(): BasePart?
	return cover and cover.part or nil
end

-- Near miss. Interrupts peeking/aiming (not dashes, rolls or vaults) and plays the brace.
-- Returns "exposed" | "cover" | "open" | nil (nil = ignored: mid dash/roll/vault)
function controller.Suppress(duration: number?): string?
	if not isAlive() then return nil end
	if (move or vault) and not duration then return nil end
	local exposed = cover == nil or peekBlend > 0.2 or os.clock() < blindUntil
	local nm = Config.NearMiss
	suppressUntil = math.max(suppressUntil, os.clock() + (duration or (exposed and nm.ExposedLockout or nm.CoverLockout)))
	blindUntil = 0
	if cover then
		cover.leaveHeld = 0 -- a near miss cancels a half-held leave / corner wrap
		cover.wrapHeld = 0
		coverTracks = coverTracks or loadTracks(Config.CoverAnimations, true)
		local brace = coverTracks and coverTracks.Brace
		if brace then
			brace.Looped = false
			brace.Priority = Enum.AnimationPriority.Action4
			brace:Play(0.05)
		end
		return exposed and "exposed" or "cover"
	end
	return "open"
end

-- Drop everything (cover, a dash/roll in progress, a vault) - e.g. before a teleport
function controller.Reset()
	if move or vault or dive then finishMovement() end
	vault = nil
	if cover then exitCover() end
	local hum = humanoid
	if hum and rootPart then
		hum:MoveTo((rootPart :: BasePart).Position)
		hum.AutoRotate = true
	end
end

-- What kind of movement is happening (for the cinematic camera): "Vault" | "Dash" | "Roll" | "Sneak" | "Sprint" | nil
function controller.GetMoveStyle(): string?
	if vault then return "Vault" end
	if dive then return "Dive" end
	if move then return move.rolled and "Roll" or move.style end
	return nil
end

-- Direction of the current vault/move (flat), for the camera to lean into
function controller.GetMoveDirection(): Vector3?
	local root = rootPart
	if vault then return vault.facing end
	if dive then return dive.facing end
	if move and root then
		local d = (move.stand - root.Position) * FLAT
		return d.Magnitude > 0.1 and d.Unit or nil
	end
	return nil
end

-- After a silent vault: find the nearest usable cover within reach and sneak into it
function controller._SettleIntoCover(forward: Vector3?)
	if not isAlive() or move or vault or cover then return end
	local root = rootPart :: BasePart
	local waist = root.Position + Vector3.new(0, Config.WaistHeight, 0)
	local best, bestScore = nil, math.huge
	for i = 0, 15 do
		local angle = math.rad(i * 22.5)
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		-- never look back the way you came: these rays pass through the wall you just vaulted, and cover
		-- behind it would walk you straight back round to where you started
		local backward = forward and dir:Dot(forward) < -0.15
		local hit = not backward and castWorld(waist, dir * (Config.SilentVaultCoverReach or 9), lastVaulted) or nil
		if hit and isUsableWall(hit) then
			-- prefer cover ahead of you (the way you were going) and close
			local score = hit.Distance - ((forward and dir:Dot(forward) or 0) * 2)
			if score < bestScore then best, bestScore = hit, score end
		end
	end
	if not best then return end
	if best.Distance <= Config.DetectDistance + 0.3 then
		savedWalkSpeed = (humanoid :: Humanoid).WalkSpeed
		enterCover(coverFromHit(best))
		return
	end
	local hit = insetOnFace(best)
	local stand = hit.Position + (hit.Normal * FLAT).Unit * Config.WallOffset
	stand = Vector3.new(stand.X, root.Position.Y, stand.Z)
	local route = planRoute(stand, hit.Instance)
	if route then
		savedWalkSpeed = (humanoid :: Humanoid).WalkSpeed
		local saved = localPlayer:GetAttribute("MoveTarget")
		localPlayer:SetAttribute("MoveTarget", nil)
		startMove(hit, stand, route) -- Shift isn't held, so this is a sneak
		localPlayer:SetAttribute("MoveTarget", saved)
	end
end

function controller.IsSuppressed(): boolean
	return os.clock() < suppressUntil
end

function controller.IsPeeking(): boolean
	return cover ~= nil and peekBlend > 0.5
end

-- 0..1: how softly the camera should follow right now (1 just after carrying on from one piece of
-- cover onto the next, fading back to 0)
function controller.CameraSoft(): number
	local untilT = cover and cover.camSoftUntil
	if not untilT then return 0 end
	return math.clamp((untilT - os.clock()) / 0.3, 0, 1)
end

function controller.IsCrouched(): boolean
	return cover ~= nil and (cover.isLow or crouched)
end

function controller.IsBlindFiring(): boolean
	return cover ~= nil and os.clock() < blindUntil
end

-- In the air from a hop (not a vault). No shooting while this is true.
function controller.IsHopping(): boolean
	if vault or not isAlive() then return false end
	if os.clock() < hopLockUntil then return true end
	local state = (humanoid :: Humanoid):GetState()
	return state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall
end

function controller.IsVaulting(): boolean
	return vault ~= nil
end

-- WeaponController calls this for every shot
function controller.NotifyShot()
	lastShotAt = os.clock()
end

-- Vaulting or moving cover-to-cover. Shots fired now use blind-fire spread.
function controller.IsMoving(): boolean
	return move ~= nil or vault ~= nil or dive ~= nil
end

-- Mid dive-roll (the air part)
function controller.IsDiving(): boolean
	return dive ~= nil
end

-- True when holding aim shouldn't aim in: mid-move, or behind tall cover away from an edge
function controller.BlocksAim(): boolean
	if dive then return false end -- you can aim (and fire) through a jump dive...
	if move and move.style ~= "Roll" then return true end -- ...and the roll that ends it
	if vault and not vault.fast then return true end -- a running vault (Shift+Space) can aim and fire
	if os.clock() < suppressUntil then return true end -- flinched from a near miss
	return cover ~= nil and not cover.isLow and not cover.nearEdge
end

-- Blind fire from cover: the arm pops out (around a tall edge, or up over low cover),
-- then `shoot` is called. Returns false if blind fire isn't possible here
-- (tall cover away from an edge: there's nowhere to put the arm).
function controller.BlindFire(shoot: () -> ()): boolean
	if not cover then
		shoot()
		return true
	end
	if not cover.isLow and not cover.nearEdge then
		return false
	end
	local alreadyOut = os.clock() < blindUntil
	blindUntil = os.clock() + Config.BlindFireRaiseTime + Config.BlindFireHoldTime
	local thisCover = cover
	task.delay(alreadyOut and 0 or Config.BlindFireRaiseTime, function()
		if cover == thisCover then shoot() end
	end)
	return true
end

-- // Scripted moves (the tutorial does the move for you while the line explains the button)
-- Rush (Shift+E) to a piece of cover
-- Tutorial: are you on a pillar that pins you to its right edge?
-- The way along the wall toward the edge you're peeking from (flat unit vector), or nil out of cover.
-- Turning to aim from cover must swing past this edge, never round through the wall.
function controller.GetPeekEdgeDirection(): Vector3?
	if not cover then return nil end
	return cover.tangent * cover.side
end

-- Drop out of cover right now (melee: you step off the wall to swing)
function controller.LeaveCover(): boolean
	if not cover then return false end
	exitCover()
	return true
end

function controller.IsPillarLocked(): boolean
	return cover ~= nil and cover.pillarLocked == true
end

function controller.ForceRush(part: BasePart, standAt: Vector3?): boolean
	if not isAlive() or move or vault or not part then return false end
	local character = localPlayer.Character
	local head = character and character:FindFirstChild("Head")
	if not head then return false end
	-- A specific face was asked for (e.g. the back of your spawn pillar): go exactly there
	if standAt then
		local root = rootPart :: BasePart
		local waist = Vector3.new(standAt.X, root.Position.Y + Config.WaistHeight, standAt.Z)
		local toPart = (part.Position - waist) * FLAT
		backParams.FilterDescendantsInstances = { part }
		local faceHit = toPart.Magnitude > 0.1 and workspace:Raycast(waist, toPart.Unit * (part.Size.Magnitude + 4), backParams)
		if faceHit and isUsableWall(faceHit) then
			local normal = (faceHit.Normal * FLAT).Unit
			local stand = faceHit.Position + normal * Config.WallOffset
			stand = Vector3.new(stand.X, root.Position.Y, stand.Z)
			if ((stand - root.Position) * FLAT).Magnitude < Config.MoveMinDistance then
				-- already right there: just take the cover
				local cf = coverFromHit(faceHit)
				savedWalkSpeed = (humanoid :: Humanoid).WalkSpeed
				enterCover(cf)
				return true
			end
			local route = planRoute(stand, part) or { stand }
			if not cover then savedWalkSpeed = (humanoid :: Humanoid).WalkSpeed end
			forceFast = true
			local ok, err = pcall(startMove, faceHit, stand, route)
			forceFast = false
			controller._lastRushError = not ok and tostring(err) or nil -- (debug: why a forced rush didn't start)
			if ok and move ~= nil then return true end
		end
	end
	local look = (part.Position - head.Position)
	if look.Magnitude < 0.5 then return false end
	local previousOverride = crosshairOverride
	local stand, hit, route
	for _, degrees in Config.DashAimAssist do
		crosshairOverride = { head.Position, (CFrame.Angles(0, math.rad(degrees), 0) * look.Unit).Unit }
		stand, hit, route = findCrosshairSpot()
		if stand and hit and hit.Instance == part then break end
		stand, hit, route = nil, nil, nil
	end
	crosshairOverride = previousOverride
	if not stand then
		-- too close for a rush (you only stepped out a little): just take the cover, like Q
		crosshairOverride = { head.Position, look.Unit }
		local ok = controller.TryEnterCover()
		crosshairOverride = previousOverride
		return ok
	end
	if not cover then savedWalkSpeed = (humanoid :: Humanoid).WalkSpeed end
	forceFast = true
	local ok = pcall(startMove, hit, stand, route)
	forceFast = false
	return ok and move ~= nil
end

-- Double vault: straight back over the wall you just came over, into cover
function controller.ForceVaultBack(): boolean
	if not isAlive() or move or vault or cover then return false end
	if not lastVaulted or not lastVaulted.Parent then return false end
	local hit = faceToward(lastVaulted, lastVaulted.Position)
	if not hit or hit.Distance > Config.RevaultReach + 1 then return false end
	local c = coverFromHit(hit)
	if not c.isLow then return false end
	doubleVaultUntil = 0
	if startVault(c, true) then
		vault.wantCover = true -- the tutorial's "like this": over, and Q, so you land in cover
		return true
	end
	return false
end

-- JUMP DIVE (double-tap Space): spring off like a diving board in the way you're moving (or looking, if
-- you're standing still), float, and land in a roll. No aiming. Low walls in the way get cleared; if
-- something tall is right there, it dives a shorter way or not at all. Q during it: finish in cover.
function controller.JumpDive(): boolean
	if not isAlive() or dive or move then return false end
	local root = rootPart :: BasePart
	local hum = humanoid :: Humanoid
	local dir = hum.MoveDirection * FLAT
	if dir.Magnitude < 0.1 then dir = workspace.CurrentCamera.CFrame.LookVector * FLAT end
	if dir.Magnitude < 0.1 then return false end
	dir = dir.Unit
	if not cover then savedWalkSpeed = hum.WalkSpeed end
	local fromVault = vault
	for _, d in { Config.DiveDistance or 11, 9, 7, 5 } do
		-- [DIVE] a lunge from the hop (Edward 2026-10-18: "too high ... should feel like a lunge forward"): the plain dive,
		-- not the diving-board mode (that added 3.6 studs of lift and a 0.4 s hang on top of the hop)
		if startDive(nil :: any, root.Position + dir * d, false) then
			if fromVault then
				if fromVault.track then fromVault.track:Stop(0.1) end
				if character then character:SetAttribute("SilentMove", nil) end
				vault = nil
			end
			return true
		end
	end
	return false
end

-- Crouch behind the cover you're in (sliding into cover with C leaves you crouched)
function controller.SetCrouched(on: boolean)
	if cover and not cover.isLow then crouched = on end
end

function controller.Start()
	-- Movement keys cancel an E / Shift+E move in progress (a fresh press, so a key you were already
	-- holding when you pressed E doesn't cancel it straight away)
	local MOVE_KEYS = {
		[Enum.KeyCode.W] = true, [Enum.KeyCode.A] = true, [Enum.KeyCode.S] = true, [Enum.KeyCode.D] = true,
		[Enum.KeyCode.Up] = true, [Enum.KeyCode.Down] = true, [Enum.KeyCode.Left] = true, [Enum.KeyCode.Right] = true,
	}
	UserInputService.InputBegan:Connect(function(input)
		if move and MOVE_KEYS[input.KeyCode] and UserInputService:GetFocusedTextBox() == nil
			and os.clock() - move.started > 0.1 then
			moveCancelRequested = true
		end
	end)
	if RunService:IsStudio() then -- test hook: setting TestMove counts as pressing a movement key
		localPlayer:GetAttributeChangedSignal("TestMove"):Connect(function()
			if move and localPlayer:GetAttribute("TestMove") then moveCancelRequested = true end
		end)
	end

	CameraController = Get("CameraController")

	if localPlayer.Character and __TG.On() then task.spawn(bindCharacter, localPlayer.Character) end
	__TG.CharacterAdded:Connect(bindCharacter)
	task.spawn(getControls)

	-- [SET] Take Cover / Crouch / Dash / Jump-Vault follow Settings > Hotkeys (rebound when they change)
	local function bindCover()
		for _, a in { "Cover", "CoverCrouch", "CoverDash", "CoverVault" } do ContextActionService:UnbindAction(a) end
		ContextActionService:BindAction("Cover", onCoverKey, false, Binds.Key(localPlayer, "TakeCover", Config.Keybinds.Cover), Enum.KeyCode.ButtonL1) -- [PAD] LB (B is crouch)
		ContextActionService:BindAction("CoverCrouch", onCrouchKey, false, Binds.Key(localPlayer, "Crouch", Config.Keybinds.Crouch), Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl, Enum.KeyCode.ButtonB) -- C or Ctrl, [PAD] B
		ContextActionService:BindAction("CoverDash", onDashKey, false, Binds.Key(localPlayer, "Dash", Config.Keybinds.Dash), Enum.KeyCode.DPadUp) -- [PAD] D-pad up
		ContextActionService:BindActionAtPriority("CoverVault", onJumpKey, false,
			Enum.ContextActionPriority.High.Value, Binds.Key(localPlayer, "Jump", Config.Keybinds.Vault), Enum.KeyCode.ButtonA) -- [PAD] A: vault / hop / dive
	end
	bindCover()
	for _, a in { "TakeCover", "Crouch", "Dash", "Jump" } do Binds.Changed(localPlayer, a, bindCover) end
	-- [TOUCH] mobile: Take Cover / Dash / Crouch / Jump buttons. Jump: a vault / cover hop when there is one, else a jump
	-- (Roblox's own touch jump button is hidden by the touch HUD)
	task.spawn(function()
		local ok, IA = pcall(function() return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("InputActions", 15)) end)
		if not ok or not IA then return end
		IA.BindCAS("Cover", onCoverKey, "Cover")
		IA.BindCAS("Dash", onDashKey, "CoverDash")
		IA.BindCAS("Crouch", onCrouchKey, "CoverCrouch")
		IA.Bind("Jump", function(state)
			local fake = { UserInputType = Enum.UserInputType.Touch, KeyCode = Enum.KeyCode.Unknown, UserInputState = state, Position = Vector3.zero, Delta = Vector3.zero }
			local r = onJumpKey("CoverVault", state, fake)
			if state == Enum.UserInputState.Begin and r ~= Enum.ContextActionResult.Sink and humanoid and humanoid.Health > 0 then
				humanoid.Jump = true
			end
		end)
	end)
	RunService:BindToRenderStep(RENDER_NAME, RENDER_PRIORITY, update)

	-- Studio-only test hook: lets automated playtests press Q/E with a chosen crosshair ray.
	-- Never created in live games.
	if RunService:IsStudio() then
		local hook = Instance.new("BindableFunction")
		hook.Name = "CoverTestHook"
		hook.OnInvoke = function(action: string, origin: Vector3?, look: Vector3?)
			crosshairOverride = origin and look and { origin, look.Unit } or nil
			local ok, err = pcall(function()
				if action == "Cover" then onCoverKey("Cover", Enum.UserInputState.Begin)
				elseif action == "Dash" then onDashKey("CoverDash", Enum.UserInputState.Begin)
				elseif action == "Jump" then onJumpKey("CoverVault", Enum.UserInputState.Begin) end
			end)
			crosshairOverride = nil
			return ok and { inCover = cover ~= nil, moving = move ~= nil, vaulting = vault ~= nil, route = move and move.route,
				coverPart = cover and cover.part and cover.part.Name, crouched = crouched, style = move and move.style,
				controlsOn = (function()
					local ctl = getControls()
					local active = ctl and ctl.activeController
					return active ~= nil and active.enabled == true
				end)(),
				walkSpeed = humanoid and humanoid.WalkSpeed, autoRotate = humanoid and humanoid.AutoRotate,
				state = humanoid and humanoid:GetState().Name } or err
		end
		hook.Parent = localPlayer:WaitForChild("PlayerScripts")
	end
end

return controller
