local __TG = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("TrainingGate"))
-- StarterPlayer/StarterPlayerScripts/Client/Controllers/CameraController (ModuleScript)
-- GTA-style over-the-shoulder camera.
--
--   * Mouse look with the cursor locked to the screen centre.
--   * Hip view (wide) and aim view (right mouse: closer, narrower FOV, character faces the camera).
--   * Shoulder swap (V), smoothly sliding to the other side.
--   * Collision: the camera is pushed in front of walls instead of clipping through them.
--   * Your own character fades out if a wall pushes the camera right up against it.
--
-- Public API (for weapons, cover, UI):
--   CameraController.GetAimRay()            -> Ray through the screen centre
--   CameraController.GetAimPoint(maxDist?)  -> Vector3 the crosshair is on, RaycastResult?
--   CameraController.IsAiming()             -> boolean
--   CameraController.GetShoulder()          -> 1 (right) or -1 (left)
--   CameraController.SetShoulder(side)      -> force a shoulder (cover will use this)
--   CameraController.SetMouseFree(free)     -> unlock the cursor for menus
--   CameraController.AddRecoil(pitch, yaw, recovery) -> kick the view (degrees); it settles back
--   CameraController.FaceCamera(duration)   -> turn the character to the camera now and hold for duration
--   CameraController.IsFacingCamera()       -> aiming, or inside a FaceCamera window
-- Scoped weapons (the sniper): ScopeController drives the slide from the shoulder into your eye and the
-- zoom through the glass; this camera follows its Blend() / Zoom() / FOV().
--
-- Purely client-side and visual: nothing here is trusted by the server.

-- // Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
RunService = __TG.RunService
local UserInputService = game:GetService("UserInputService")
UserInputService = __TG.UserInputService
local ContextActionService = game:GetService("ContextActionService")
ContextActionService = __TG.ContextActionService
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- // Config
local Shared = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"):WaitForChild("CameraConfig"))

-- // Constants
local RENDER_NAME = "OverShoulderCamera"
local RENDER_PRIORITY = Enum.RenderPriority.Camera.Value + 1 -- after Roblox's default camera, so we win

local localPlayer = Players.LocalPlayer

-- [SET] Settings > ... (UI session 2026-10-16): player settings arrive as attributes (SettingsConfig.Apply)
local Binds = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("Binds"))
local function setting(name: string, default: any): any
	local v = localPlayer:GetAttribute("Setting_" .. name)
	if v == nil then return default end
	return v
end

-- // Root
local controller = {}

-- // State
local state = {
	yaw = 0,
	pitch = 0,
	aimHeld = false,
	aimBlend = 0,                           -- 0 = hip, 1 = aim (smoothed)
	shoulder = Config.DefaultShoulder,      -- target side
	shoulderBlend = Config.DefaultShoulder, -- smoothed side (-1..1)
	mouseFree = false,
	lastPivot = nil :: Vector3?,
	lastFade = -1,
	recoilPitch = 0,  -- radians, decays back to 0
	recoilYaw = 0,
	recoilRecovery = 10,
	faceUntil = 0,    -- os.clock() until which the character keeps facing the camera
	deathStart = nil :: number?,
	deathYaw = 0,
	smoothPivot = nil :: Vector3?, -- the camera's spring-followed pivot
	crouchDrop = 0,
	camDist = nil :: number?,      -- smoothed boom length (walls push it in, it eases back out)
	sideDist = nil :: number?,     -- smoothed shoulder reach
}

local character: Model?, humanoid: Humanoid?, rootPart: BasePart?

local collisionParams = RaycastParams.new()
collisionParams.FilterType = Enum.RaycastFilterType.Exclude
collisionParams.IgnoreWater = true

local aimParams = RaycastParams.new()
aimParams.FilterType = Enum.RaycastFilterType.Exclude
aimParams.IgnoreWater = true

-- // Helpers
-- Scoped guns (WeaponConfig AimFOV, e.g. the sniper) zoom in further than the normal aim
local WeaponConfigForFOV = require(game:GetService("ReplicatedStorage").Modules.Shared.Config.WeaponConfig)
local function weaponAimFOV(): number?
	local character = game:GetService("Players").LocalPlayer.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	local config = tool and WeaponConfigForFOV.Get(tool:GetAttribute("WeaponId") or "")
	return config and config.AimFOV
end
local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Frame-rate independent smoothing factor
local function smoothing(speed: number, dt: number): number
	return 1 - math.exp(-speed * dt)
end

local function isAlive(): boolean
	return humanoid ~= nil and rootPart ~= nil and rootPart.Parent ~= nil and humanoid.Health > 0
end

local function allCharacters(): {Instance}
	local list = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	return list
end

-- [SET] lobby duels: the arena's collision shell (workspace.DuelArenas.<matchId>) has big CanCollide blockers that raycasts
-- can't see (CanQuery false, e.g. OutOfBounds at the doors), so the camera tests those boxes itself. Hold / FX / Props are
-- skipped. The match place does the same for its native map.
local arenaBlockers, arenaBlockersFor = {}, nil
local function duelArena(): Instance?
	-- match place: the map sits natively in Workspace (same Warehouse build, same OutOfBounds blockers)
	if not workspace:FindFirstChild("LobbyMap") then
		for _, c in workspace:GetChildren() do if c:GetAttribute("DuelArena") ~= nil then return c end end
		return workspace:FindFirstChild("Warehouse")
	end
	local id = Players.LocalPlayer:GetAttribute("DuelMatch") or Players.LocalPlayer:GetAttribute("DuelSpectate")
	if not id or not (Players.LocalPlayer:GetAttribute("InDuel") or Players.LocalPlayer:GetAttribute("DuelSpectate")) then return nil end
	local arenas = workspace:FindFirstChild("DuelArenas")
	return arenas and arenas:FindFirstChild(tostring(id))
end
local function refreshArenaBlockers()
	local arena = duelArena()
	if arena == arenaBlockersFor and (arena == nil or #arenaBlockers > 0) then return end
	arenaBlockersFor, arenaBlockers = arena, {}
	if not arena then return end
	for _, p in arena:GetDescendants() do
		if p:IsA("BasePart") and p.CanCollide and not p.CanQuery and not p:FindFirstAncestor("Hold") and not p:FindFirstAncestor("FX") and not p:FindFirstAncestor("Props") then
			local sz = p.Size
			local big = math.max(sz.X, sz.Y, sz.Z)
			local mid = sz.X + sz.Y + sz.Z - big - math.min(sz.X, sz.Y, sz.Z)
			if big >= 6 and mid >= 6 then table.insert(arenaBlockers, p) end -- walls / shutters, not bottles
		end
	end
end
-- distance along the unit ray to an (inflated) box, nil if it misses or starts inside
local function rayBox(from: Vector3, dir: Vector3, maxDist: number, part: BasePart, pad: number): number?
	local cf = part.CFrame
	local o, d = cf:PointToObjectSpace(from), cf:VectorToObjectSpace(dir)
	local h = part.Size / 2 + Vector3.new(pad, pad, pad)
	local tmin, tmax = -math.huge, math.huge
	for _, axis in { "X", "Y", "Z" } do
		local oa, da, ha = o[axis], d[axis], h[axis]
		if math.abs(da) < 1e-6 then
			if oa < -ha or oa > ha then return nil end
		else
			local t1, t2 = (-ha - oa) / da, (ha - oa) / da
			if t1 > t2 then t1, t2 = t2, t1 end
			tmin, tmax = math.max(tmin, t1), math.min(tmax, t2)
			if tmin > tmax then return nil end
		end
	end
	if tmin < 0 or tmin > maxDist then return nil end
	return tmin
end

-- Move from `from` toward `to`, stopping short of anything solid in between
local function castTo(from: Vector3, to: Vector3, radius: number?): Vector3
	local offset = to - from
	if offset.Magnitude < 1e-3 then return to end

	local dist = offset.Magnitude
	local result = workspace:Spherecast(from, radius or Config.CollisionRadius, offset, collisionParams)
	if result then dist = result.Distance end
	for _, part in arenaBlockers do
		local t = part.Parent and rayBox(from, offset.Unit, dist, part, radius or Config.CollisionRadius)
		if t then dist = t; result = true end
	end
	if result then
		return from + offset.Unit * math.max(dist - Config.CollisionPadding, 0)
	end
	return to
end

local function setCharacterFade(alpha: number)
	if not character or math.abs(alpha - state.lastFade) < 0.02 then return end
	state.lastFade = alpha

	for _, desc in character:GetDescendants() do
		if desc:IsA("BasePart") or desc:IsA("Decal") then
			desc.LocalTransparencyModifier = alpha
		end
	end
end

local coverController
local function CoverControllerRef()
	coverController = coverController or shared.Get("CoverController")
	return coverController
end

local scopeController
local function ScopeRef()
	scopeController = scopeController or shared.Get("ScopeController")
	return scopeController
end

-- // Per-frame update
local function update(dt: number)
	local camera = workspace.CurrentCamera
	if not camera then return end

	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end

	-- Mouse look
	if state.mouseFree or state.altFree then -- (pass 45) altFree: Free Cursor key held
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	else
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false

		local delta = UserInputService:GetMouseDelta()
		-- [SET] Video > Camera: Sensitivity, While Aiming, While Scoped (50% = the tuned default)
		local sensitivity = math.rad(Config.Sensitivity) * setting("Sensitivity", 100) / 100
			* (state.aimHeld and Config.AimSensitivityMultiplier * setting("WhileAiming", 50) / 50 or 1)
		local scopeNow = ScopeRef()
		if scopeNow and scopeNow.UsesScope() then
			sensitivity *= lerp(1, scopeNow.FOV() / Config.Aim.FOV, scopeNow.Zoom()) -- through a scope: slower look to match the zoom
			sensitivity *= setting("WhileScoped", 50) / 50
		else
			local scopeFOV = state.aimHeld and weaponAimFOV()
			if scopeFOV then sensitivity *= scopeFOV / Config.Aim.FOV end -- zoomed guns: slower look to match
		end
		local invert = (Config.InvertY ~= (setting("InvertedY", false) == true)) and -1 or 1 -- [SET] Inverted Y
		local invertX = setting("InvertedX", false) == true and -1 or 1 -- [SET] Inverted X
		local sensX, sensY = setting("Horizontal", 100) / 100, setting("Vertical", 100) / 100 -- [SET] Horizontal / Vertical

		local guide = state.guide
		if guide and guide.getTarget then
			-- Guided look (tutorial "cinematography"): the camera glides onto a target on its own.
			-- The mouse is ignored until it arrives; after that it may keep softly tracking the target
			-- for `follow` seconds, and any real mouse movement hands control straight back.
			local target = guide.getTarget()
			local now = os.clock()
			if not target then
				state.guide = nil
			else
				local from = camera.CFrame.Position
				local dir = target - from
				if dir.Magnitude > 0.1 then
					dir = dir.Unit
					local wantYaw = math.atan2(-dir.X, -dir.Z)
					local wantPitch = math.clamp(math.asin(math.clamp(dir.Y, -1, 1)), math.rad(Config.PitchMin), math.rad(Config.PitchMax))
					local t = math.clamp((now - guide.start) / guide.duration, 0, 1)
					if t < 1 then
						local e = t * t * t * (t * (t * 6 - 15) + 10) -- smootherstep
						local dyaw = (wantYaw - guide.fromYaw + math.pi) % (2 * math.pi) - math.pi
						state.yaw = guide.fromYaw + dyaw * e
						state.pitch = guide.fromPitch + (wantPitch - guide.fromPitch) * e
					elseif now < guide.start + guide.duration + guide.follow then
						-- arrived: keep the target framed until the shot is over (the mouse stays locked)
						local dyaw = (wantYaw - state.yaw + math.pi) % (2 * math.pi) - math.pi
						state.yaw += dyaw * math.clamp(dt * 6, 0, 1)
						state.pitch += (wantPitch - state.pitch) * math.clamp(dt * 6, 0, 1)
					else
						state.guide = nil
					end
				end
			end
		end
		do
			if not state.guide then
				state.yaw -= delta.X * sensitivity * sensX * invertX
				state.pitch = math.clamp(
					state.pitch - delta.Y * sensitivity * sensY * invert,
					math.rad(Config.PitchMin),
					math.rad(Config.PitchMax)
				)
			end
		end
	end

	-- Studio test hook: TestAim (hold aim) / TestPitch (degrees) attributes on the LocalPlayer
	if RunService:IsStudio() then
		local ta = localPlayer:GetAttribute("TestAim")
		if ta ~= nil then state.aimHeld = ta == true end
		local tp = localPlayer:GetAttribute("TestPitch")
		if typeof(tp) == "number" then state.pitch = math.rad(tp) end
		local ty = localPlayer:GetAttribute("TestYaw")
		if typeof(ty) == "number" then state.yaw = math.rad(ty) end
	end

	-- Death camera: ease back and up over the body, slowly circling it
	if not isAlive() and character and character.Parent then
		local body = character:FindFirstChild("UpperTorso") or character:FindFirstChild("HumanoidRootPart")
		if body and body:IsA("BasePart") then
			if not state.deathStart then
				state.deathStart = os.clock()
				state.deathYaw = state.yaw
				setCharacterFade(0)
			end
			local elapsed = os.clock() - state.deathStart
			state.deathYaw += dt * Config.DeathCamOrbitSpeed
			local ease = 1 - math.exp(-elapsed * Config.DeathCamEaseSpeed)
			local distance = lerp(Config.Hip.Distance, Config.DeathCamDistance, ease)
			local height = lerp(2, Config.DeathCamHeight, ease)
			local focus = body.Position
			local offset = CFrame.fromOrientation(0, state.deathYaw, 0):VectorToWorldSpace(Vector3.new(0, height, distance))
			collisionParams.FilterDescendantsInstances = allCharacters()
			local cameraPosition = castTo(focus, focus + offset)
			camera.CFrame = camera.CFrame:Lerp(CFrame.lookAt(cameraPosition, focus), smoothing(5, dt))
			camera.FieldOfView = lerp(camera.FieldOfView, Config.Hip.FOV, smoothing(5, dt))
			return
		end
	end
	state.deathStart = nil

	-- Scripted turn (e.g. hugging round a pillar corner): eases the view round by state.turnLeft radians
	-- (ease-in-out over a fixed time: starts and stops gently, no snap at the beginning)
	if state.turnTotal then
		state.turnElapsed += dt
		local x = math.clamp(state.turnElapsed / state.turnDuration, 0, 1)
		local eased = x * x * x * (x * (x * 6 - 15) + 10) -- smootherstep
		local target = state.turnTotal * eased
		state.yaw += target - state.turnApplied
		state.turnApplied = target
		if x >= 1 then state.turnTotal = nil end
	end

	-- Recoil settles back toward where you were aiming
	local recover = smoothing(state.recoilRecovery, dt)
	state.recoilPitch -= state.recoilPitch * recover
	state.recoilYaw -= state.recoilYaw * recover
	local viewYaw = state.yaw + state.recoilYaw
	local viewPitch = math.clamp(state.pitch + state.recoilPitch, math.rad(Config.PitchMin), math.rad(Config.PitchMax))

	-- Blend hip <-> aim and left <-> right shoulder
	local aiming = controller.IsAiming()
	state.aimBlend = lerp(state.aimBlend, aiming and 1 or 0, smoothing(Config.AimTransitionSpeed, dt))
	state.shoulderBlend = lerp(state.shoulderBlend, state.shoulder, smoothing(Config.ShoulderSwapSpeed, dt))

	local hip, aim, t = Config.Hip, Config.Aim, state.aimBlend
	local distance = lerp(hip.Distance, aim.Distance, t)
	local side = lerp(hip.ShoulderOffset, aim.ShoulderOffset, t) * state.shoulderBlend
	local height = lerp(hip.HeightOffset, aim.HeightOffset, t)
	local scope = ScopeRef()
	local usesScope = scope ~= nil and scope.UsesScope()
	camera.FieldOfView = lerp(hip.FOV, (not usesScope and weaponAimFOV()) or aim.FOV, t) -- zoomed guns zoom further
	if usesScope then camera.FieldOfView = lerp(camera.FieldOfView, scope.FOV(), scope.Zoom()) end -- through the scope

	-- Pivot follows the character; freezes where you died
	local pivot: Vector3?
	if isAlive() then
		local root = rootPart :: BasePart
		-- crouched (behind cover or on foot): the camera sinks with you; rising to peek/aim lifts it back
		local crouchTarget = 0
		local cover = CoverControllerRef()
		if (cover and cover.IsCrouched and cover.IsCrouched()) or (character and character:GetAttribute("Stance") == "Crouch") then
			crouchTarget = (Config.CrouchDrop or 0.9) * (1 - 0.7 * t)
		end
		-- carrying on from one piece of cover onto the next (pillar -> low box): follow softly, no jolt
		local soft = (cover and cover.CameraSoft) and cover.CameraSoft() or 0
		state.crouchDrop = lerp(state.crouchDrop, crouchTarget, smoothing(lerp(8, 4, soft), dt))
		local target = root.Position + Vector3.new(0, Config.PivotHeight - state.crouchDrop, 0)
		local p = state.smoothPivot
		if not p or (p - target).Magnitude > 8 then
			p = target -- spawned / teleported: no long swoop
			state.pivotVel = nil
		else
			-- follow your velocity (no lag while moving), then spring onto the real position. The velocity
			-- itself is eased: a Roblox character goes from standing to a sprint in one physics step, and a
			-- camera that copied that would jolt; this one picks up speed over a few frames like an operator.
			local v = root.AssemblyLinearVelocity
			local flatV = Vector3.new(v.X, 0, v.Z)
			-- (gliding between covers: the lead is calmer and the spring softer, so the hand-off doesn't jolt)
			state.pivotVel = (state.pivotVel or flatV):Lerp(flatV, smoothing(lerp(Config.PivotInertia or 12, 5, soft), dt))
			p += state.pivotVel * dt
			local kxz = smoothing(lerp(Config.PivotFollow or 16, 9, soft), dt)
			local ky = smoothing(lerp(Config.PivotFollowY or 9, 5, soft), dt)
			p = Vector3.new(p.X + (target.X - p.X) * kxz, p.Y + (target.Y - p.Y) * ky, p.Z + (target.Z - p.Z) * kxz)
		end
		state.smoothPivot = p
		pivot = p
		state.lastPivot = pivot
	else
		pivot = state.lastPivot
	end
	if not pivot then return end

	local flat = CFrame.fromOrientation(0, viewYaw, 0)
	local rotation = CFrame.fromOrientation(viewPitch, viewYaw, 0)

	-- Two-stage collision: pivot -> shoulder (sideways), then shoulder -> camera (backwards)
	collisionParams.FilterDescendantsInstances = allCharacters()
	refreshArenaBlockers()
	-- Walls push the camera in instantly (never see through them) but it eases back out, so brushing
	-- past a corner or peeking from cover doesn't make the view pump in and out.
	local sideTarget = pivot + flat:VectorToWorldSpace(Vector3.new(side, height, 0))
	local sideFull = (sideTarget - pivot).Magnitude
	local sideHit = (castTo(pivot, sideTarget) - pivot).Magnitude
	local sideNow = state.sideDist or sideHit
	sideNow = sideHit < sideNow and sideHit or lerp(sideNow, sideHit, smoothing(Config.CollisionReturnSpeed or 5, dt))
	state.sideDist = sideNow
	local shoulderPoint = sideFull > 1e-3 and pivot + (sideTarget - pivot).Unit * sideNow or sideTarget
	-- boom: a wide "early warning" probe starts easing the camera in before a wall arrives, then the
	-- real (thin) probe is a hard limit so you never see through anything
	local boomEnd = shoulderPoint - rotation.LookVector * distance
	local backHard = (castTo(shoulderPoint, boomEnd) - shoulderPoint).Magnitude
	local backSoft = math.min((castTo(shoulderPoint, boomEnd, 1.1) - shoulderPoint).Magnitude + 0.4, backHard)
	local backNow = state.camDist or backSoft
	if backSoft < backNow then
		backNow = lerp(backNow, backSoft, smoothing(16, dt))
	else
		backNow = lerp(backNow, backSoft, smoothing(Config.CollisionReturnSpeed or 5, dt))
	end
	backNow = math.min(backNow, backHard)
	state.camDist = backNow
	local cameraPosition = shoulderPoint - rotation.LookVector * backNow
	-- scope raised: the camera slides from over the shoulder into your eye
	local eyeBlend = usesScope and scope.Blend() or 0
	if eyeBlend > 0 and character then
		local head = character:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			local eye = head.Position + Vector3.new(0, 0.15, 0) + flat.LookVector * 0.2
			cameraPosition = cameraPosition:Lerp(eye, eyeBlend)
		end
	end
	camera.CFrame = CFrame.new(cameraPosition) * rotation

	-- While aiming (or just after hip-firing), the character faces where the camera looks (GTA style)
	if humanoid and rootPart and rootPart.Parent then
		if aiming or (os.clock() < state.faceUntil and isAlive()) then
			humanoid.AutoRotate = false
			rootPart.AssemblyAngularVelocity = Vector3.zero
			-- turn to the view quickly but not in one frame (FaceCamera, used when firing, still snaps)
			local look = rootPart.CFrame.LookVector
			local currentYaw = math.atan2(-look.X, -look.Z)
			local diff = (viewYaw - currentYaw + math.pi) % (2 * math.pi) - math.pi
			-- In cover, a big turn always swings out past the edge you're peeking from (to the right when
			-- peeking right), never the long way round through the wall
			local cover = CoverControllerRef()
			local edge = cover and cover.GetPeekEdgeDirection and cover.GetPeekEdgeDirection()
			if edge and math.abs(diff) > math.rad(100) then
				local edgeYaw = math.atan2(-edge.X, -edge.Z)
				local towardEdge = (edgeYaw - currentYaw + math.pi) % (2 * math.pi) - math.pi
				if towardEdge ~= 0 and math.sign(diff) ~= math.sign(towardEdge) then
					diff -= math.sign(diff) * 2 * math.pi
				end
			end
			-- remember the direction once a big turn has started, so it can't flip halfway round
			if math.abs(diff) > math.rad(100) and state.aimTurnSign and math.sign(diff) ~= state.aimTurnSign then
				diff -= math.sign(diff) * 2 * math.pi
			end
			state.aimTurnSign = math.abs(diff) > math.rad(15) and math.sign(diff) or nil
			local maxStep = math.rad(Config.AimTurnRate or 1000) * dt
			local step = math.clamp(diff * smoothing(25, dt), -maxStep, maxStep)
			if math.abs(diff) < math.rad(1.5) then step = diff end
			rootPart.CFrame = CFrame.new(rootPart.Position) * CFrame.fromOrientation(0, currentYaw + step, 0)
		else
			state.aimTurnSign = nil -- not aiming: the next aim-turn picks its direction fresh
			-- On foot we own your facing (unless cover, a vault or a cover dash does): turn toward where
			-- you're heading at a natural rate instead of Roblox's instant snap. Done by spinning the body,
			-- never by writing its CFrame (that would cancel scripted walks like the tutorial's intro run).
			local cover = CoverControllerRef()
			local coverOwns = cover and (cover.IsInCover() or cover.IsMoving() or (cover.IsVaulting and cover.IsVaulting()))
			if not coverOwns and isAlive() then
				humanoid.AutoRotate = false
				local md = humanoid.MoveDirection * Vector3.new(1, 0, 1)
				if md.Magnitude < 0.1 then
					local v = rootPart.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
					if v.Magnitude > 2 then md = v end -- moving without input (pushed, slid, scripted)
				end
				local rate = 0
				if md.Magnitude > 0.1 then
					local look = rootPart.CFrame.LookVector
					local yawNow = math.atan2(-look.X, -look.Z)
					local wantYaw = math.atan2(-md.X, -md.Z)
					local diff = (wantYaw - yawNow + math.pi) % (2 * math.pi) - math.pi
					local maxRate = math.rad(Config.BodyTurnRate or 720)
					rate = math.clamp(diff * 14, -maxRate, maxRate)
				end
				rootPart.AssemblyAngularVelocity = Vector3.new(0, rate, 0)
			end
		end
	end

	-- Fade own character when the camera is squeezed against it
	local closeness = (cameraPosition - pivot).Magnitude
	local fade = (Config.FadeStartDistance - closeness) / (Config.FadeStartDistance - Config.FadeEndDistance)
	setCharacterFade(math.max(math.clamp(fade, 0, 1), math.clamp((eyeBlend - 0.25) / 0.4, 0, 1))) -- (in the scope: gone)
end

-- // Character binding
local function bindCharacter(newCharacter: Model)
	character, humanoid, rootPart = newCharacter, nil, nil
	state.lastFade = -1

	local hum = newCharacter:WaitForChild("Humanoid", 10) :: Humanoid?
	local root = newCharacter:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if character ~= newCharacter or not hum or not root then return end

	humanoid, rootPart = hum, root
	aimParams.FilterDescendantsInstances = { newCharacter }

	-- Start looking the way the character spawned facing
	local look = root.CFrame.LookVector
	state.yaw = math.atan2(-look.X, -look.Z)
	state.pitch = 0
	state.lastPivot = root.Position + Vector3.new(0, Config.PivotHeight, 0)
end

-- // Input
local function onAim(_, inputState: Enum.UserInputState)
	-- [SET] Game > Controls > Toggle Aim: tap to start / stop aiming (touch keeps its own control)
	local toggle = setting("ToggleAim", false) == true
	if inputState == Enum.UserInputState.Begin then
		if toggle then state.aimHeld = not state.aimHeld and not state.mouseFree else state.aimHeld = not state.mouseFree end
	elseif (inputState == Enum.UserInputState.End and not toggle) or inputState == Enum.UserInputState.Cancel then
		state.aimHeld = false
	end
	return Enum.ContextActionResult.Pass -- weapons also need to see right-click
end

local function onShoulderSwap(_, inputState: Enum.UserInputState)
	if inputState == Enum.UserInputState.Begin then
		state.shoulder = -state.shoulder
	end
	return Enum.ContextActionResult.Sink
end

-- // Public API
function controller.GetAimRay(): Ray
	local camera = workspace.CurrentCamera
	local viewport = camera.ViewportSize
	return camera:ViewportPointToRay(viewport.X / 2, viewport.Y / 2)
end

function controller.GetAimPoint(maxDistance: number?): (Vector3, RaycastResult?)
	local range = maxDistance or Config.MaxAimDistance
	local ray = controller.GetAimRay()
	local origin, direction = ray.Origin, ray.Direction

	-- Start the ray level with the character, so things between the camera and you can't be "aimed at"
	if state.lastPivot then
		local skip = (state.lastPivot - origin):Dot(direction)
		if skip > 0 then
			origin += direction * skip
		end
	end

	local result = workspace:Raycast(origin, direction * range, aimParams)
	return (result and result.Position or origin + direction * range), result
end


-- Holding aim doesn't aim in while cover blocks it (tall cover away from an edge, mid vault/dash)
function controller.IsAiming(): boolean
	if not (state.aimHeld and isAlive()) then return false end
	local cover = CoverControllerRef()
	return not (cover and cover.BlocksAim())
end

-- Glide the camera onto a target (Vector3, a BasePart, or a Model) over `duration` seconds, ignoring
-- the mouse until it arrives. `follow`: seconds to keep framing it afterwards (cancelled by moving
-- the mouse). Returns immediately.
function controller.Guide(target: any, duration: number?, follow: number?)
	local function getTarget(): Vector3?
		if typeof(target) == "Vector3" then return target end
		if typeof(target) == "Instance" and target.Parent then
			if target:IsA("Model") then
				local root = target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart
				return root and (root.Position + Vector3.new(0, 1, 0)) or target:GetPivot().Position
			elseif target:IsA("BasePart") then
				return target.Position
			end
		end
		return nil
	end
	if not getTarget() then return end
	state.guide = {
		getTarget = getTarget,
		start = os.clock(),
		duration = duration or 0.9,
		follow = follow or 0,
		fromYaw = state.yaw,
		fromPitch = state.pitch,
	}
end

function controller.IsGuiding(): boolean
	return state.guide ~= nil
end

function controller.CancelGuide()
	state.guide = nil
end

-- (pass 43) your gun hand from Settings (Game > Controls > Gun Hand): Right unless you picked Left
local function preferredShoulder(): number
	return localPlayer:GetAttribute("Setting_GunHand") == "Left" and -1 or 1
end
function controller.PreferredShoulder(): number
	return preferredShoulder()
end
function controller.ResetShoulder()
	state.shoulder = preferredShoulder()
end

function controller.GetShoulder(): number
	return state.shoulder
end

function controller.SetShoulder(side: number)
	state.shoulder = side >= 0 and 1 or -1
end

-- (pass 45) true while a menu freed the cursor or the Free Cursor key (Left Alt) is held
function controller.IsMouseFree(): boolean
	return state.mouseFree == true or state.altFree == true
end

function controller.SetMouseFree(free: boolean)
	state.mouseFree = free
	if free then
		state.aimHeld = false
	end
end

-- Turn the view by `radians` (positive = left), eased in over roughly 0.3s
function controller.TurnBy(radians: number, duration: number?)
	-- fold any unfinished turn into the new one so back-to-back wraps chain smoothly
	local remaining = state.turnTotal and (state.turnTotal - state.turnApplied) or 0
	state.turnTotal = radians + remaining
	state.turnApplied = 0
	state.turnElapsed = 0
	state.turnDuration = duration or 0.45
end

function controller.AddRecoil(pitchDegrees: number, yawDegrees: number, recovery: number?)
	state.recoilPitch += math.rad(pitchDegrees)
	state.recoilYaw += math.rad(yawDegrees)
	state.recoilRecovery = recovery or state.recoilRecovery
end

function controller.FaceCamera(duration: number?)
	state.faceUntil = math.max(state.faceUntil, os.clock() + (duration or 0))
	if isAlive() then
		local hum, root = humanoid :: Humanoid, rootPart :: BasePart
		hum.AutoRotate = false
		root.CFrame = CFrame.new(root.Position) * CFrame.fromOrientation(0, state.yaw + state.recoilYaw, 0)
	end
end

function controller.IsFacingCamera(): boolean
	return isAlive() and (state.aimHeld or os.clock() < state.faceUntil)
end

-- // Start
function controller.Start()
	if localPlayer.Character and __TG.On() then
		task.spawn(bindCharacter, localPlayer.Character)
	end
	__TG.CharacterAdded:Connect(bindCharacter)
	-- (pass 43) start in your settings hand, and go back to it on respawn / when you change it
	state.shoulder = preferredShoulder()
	localPlayer:GetAttributeChangedSignal("Setting_GunHand"):Connect(function() state.shoulder = preferredShoulder() end)
	localPlayer.CharacterAdded:Connect(function() state.shoulder = preferredShoulder() end)

	-- [SET] Settings > Hotkeys: Aim / Shoulder Swap follow your binds (config keys as the fallback)
	local function bindCamera()
		ContextActionService:UnbindAction("CameraAim")
		ContextActionService:UnbindAction("CameraShoulderSwap")
		ContextActionService:BindAction("CameraAim", onAim, false, Binds.Key(localPlayer, "Aim", Config.Keybinds.Aim), Enum.KeyCode.ButtonL2)
		ContextActionService:BindAction("CameraShoulderSwap", onShoulderSwap, false, Binds.Key(localPlayer, "ShoulderSwap", Config.Keybinds.ShoulderSwap))
	end
	bindCamera()
	Binds.Changed(localPlayer, "Aim", bindCamera)
	Binds.Changed(localPlayer, "ShoulderSwap", bindCamera)

	-- (pass 45) hold Left Alt (rebindable: Settings > Hotkeys > Free Cursor) to get the mouse back for a moment
	local function freeKey(): Enum.KeyCode
		local name = localPlayer:GetAttribute("Bind_FreeCursor")
		local ok, kc = pcall(function() return Enum.KeyCode[name] end)
		return (ok and kc) or Enum.KeyCode.LeftAlt
	end
	local function bindFree()
		ContextActionService:UnbindAction("CameraFreeCursor")
		ContextActionService:BindAction("CameraFreeCursor", function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				state.altFree = true
				state.aimHeld = false
			elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
				state.altFree = false
			end
			return Enum.ContextActionResult.Pass
		end, false, freeKey())
	end
	bindFree()
	localPlayer:GetAttributeChangedSignal("Bind_FreeCursor"):Connect(bindFree)
	UserInputService.WindowFocusReleased:Connect(function() state.altFree = false end)

	-- Alt-tabbing while holding right-click never fires "End"
	UserInputService.WindowFocusReleased:Connect(function()
		state.aimHeld = false
	end)

	RunService:BindToRenderStep(RENDER_NAME, RENDER_PRIORITY, update)
end

return controller
