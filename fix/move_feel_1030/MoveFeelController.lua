-- StarterPlayer/StarterPlayerScripts/Client/Controllers/MoveFeelController (ModuleScript) [MOVEFEEL] (2026-10-30, systems
-- session; installed by fix/move_feel_1030.lua, source fix/move_feel_1030/MoveFeelController.lua)
-- The movement feel layer. Every number is in ReplicatedStorage.Modules.Shared.Config.MoveFeelConfig. Look and input only:
-- gameplay speeds, cover / vault / dive timings and every server check stay as they were.
--   YOUR BODY: momentum (the move input eases in / out, its direction swings slower the faster you go; a reversal brakes
--     through standing). Skipped whenever another system drives you (cover, cover moves, slide, cutscene, controls disabled).
--   EVERY BODY (each client draws it, nothing replicates): a lean into acceleration and turns (waist), faded out while the gun is
--     raised; hips drop and each foot reaches its own ground on stairs and slopes (IKControl), standing or slow.
--   YOUR CAMERA (a post-process undone at the start of the next frame): a stride bob, a landing dip, a sprint / slide / dive FOV
--     ease, a slide drop and roll, a dive roll. Off while dead (and so spectating), in a cutscene or scoped; reduced motion =
--     Settings "Camera Shake" off.
-- API: controller.Lean(model) -> pitch, roll (deg); controller.CameraOffset() -> CFrame, fov

local __TG = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("TrainingGate"))
local Players = game:GetService("Players")
local RawRunService = game:GetService("RunService")
local RunService = __TG.RunService -- quiet in the hub / after-match lobby, like the other combat controllers
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared")
local C = require(Shared:WaitForChild("Config"):WaitForChild("MoveFeelConfig"))
local WeaponConfig = require(Shared.Config:WaitForChild("WeaponConfig"))
local M, LN, FT, CM = C.Momentum, C.Lean, C.Feet, C.Camera

local Get = shared.Get
local localPlayer = Players.LocalPlayer
local FLAT = Vector3.new(1, 0, 1)
local controller = {}

-- the walk loops play over the gun Hold / Lowered (those key the legs): set before any body loads its loops (modules are all
-- required before any Start), and every loop is loaded with AnimFinalConfig.Loco.Priority
do
	local afMod = Shared:FindFirstChild("Config") and Shared.Config:FindFirstChild("AnimFinalConfig")
	if C.Enabled ~= false and afMod then
		local ok, AF = pcall(require, afMod)
		if ok and type(AF) == "table" and type(AF.Loco) == "table" then
			if C.LocoPriority and Enum.AnimationPriority[C.LocoPriority] then AF.Loco.Priority = Enum.AnimationPriority[C.LocoPriority] end
			if type(C.LocoAuthored) == "table" and type(AF.Loco.Authored) == "table" then
				for k, v in C.LocoAuthored do AF.Loco.Authored[k] = v end
			end
		end
	end
end

local function on(block): boolean
	return C.Enabled ~= false and block ~= nil and block.Enabled ~= false
end

local function ctl(name: string)
	local ok, c = pcall(Get, name)
	return ok and c or nil
end

local function alpha(sharpness: number, dt: number): number
	return 1 - math.exp(-sharpness * dt)
end

local function reducedMotion(): boolean
	return localPlayer:GetAttribute("Setting_CameraShake") == false
end

local function jointOf(part: Instance?, name: string): Instance?
	local j = part and part:FindFirstChild(name)
	if j and (j:IsA("Motor6D") or j:IsA("AnimationConstraint")) then return j end
	return nil
end

-- // own body ---------------------------------------------------------------------------------------------------------------
local character: Model?, humanoid: Humanoid?, root: BasePart?
local controls = nil
local smoothMove = Vector3.zero -- the eased move input (world, flat, magnitude 0..1)
local momentumActive = false

local function alive(): boolean
	return humanoid ~= nil and root ~= nil and character ~= nil and character.Parent ~= nil and humanoid.Health > 0
end

local function getControls()
	if controls then return controls end
	local ok, r = pcall(function()
		return require(localPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()
	end)
	if ok then controls = r end
	return controls
end

-- someone else is driving the body this frame: no momentum (and no feedback from our own last output)
local function drivenElsewhere(): boolean
	if not alive() then return true end
	local hum, r = humanoid :: Humanoid, root :: BasePart
	if r.Anchored or hum.Sit or hum.PlatformStand then return true end
	if localPlayer:GetAttribute("Cutscene") or localPlayer:GetAttribute("CoverMoving") then return true end
	local Move = ctl("MovementController")
	if Move and Move.IsSliding and Move.IsSliding() then return true end
	local Cover = ctl("CoverController")
	if Cover and ((Cover.IsInCover and Cover.IsInCover()) or (Cover.IsMoving and Cover.IsMoving())) then return true end
	local c = getControls()
	local active = c and c.activeController
	if active and active.enabled == false then return true end -- controls switched off (a freeze, a scripted move)
	return false
end

local function rotateToward(from: Vector3, to: Vector3, maxAngle: number): Vector3
	-- both flat unit vectors; swing `from` toward `to` by at most maxAngle radians
	local dot = math.clamp(from:Dot(to), -1, 1)
	local ang = math.acos(dot)
	if ang <= maxAngle or ang < 1e-4 then return to end
	local cross = from.X * to.Z - from.Z * to.X
	local a = (cross >= 0 and 1 or -1) * maxAngle
	local cs, sn = math.cos(a), math.sin(a)
	-- rotate in the XZ plane (x' = x cos - z sin, z' = x sin + z cos)
	return Vector3.new(from.X * cs - from.Z * sn, 0, from.X * sn + from.Z * cs)
end

local function stepMomentum(dt: number)
	if not on(M) or drivenElsewhere() then
		momentumActive = false
		smoothMove = humanoid and (humanoid.MoveDirection * FLAT) or Vector3.zero
		return
	end
	local hum = humanoid :: Humanoid
	local raw = hum.MoveDirection * FLAT
	local rawMag = math.min(raw.Magnitude, 1)
	local curMag = smoothMove.Magnitude
	local speed = ((root :: BasePart).AssemblyLinearVelocity * FLAT).Magnitude
	local k = math.clamp((speed - M.WalkSpeed) / math.max(M.SprintSpeed - M.WalkSpeed, 1), 0, 1)
	local turnRate = math.rad(M.TurnRateWalk + (M.TurnRateSprint - M.TurnRateWalk) * k)
	local newDir, newMag
	if rawMag < 0.01 then
		newMag = math.max(0, curMag - dt / M.DecelTime)
		newDir = curMag > 1e-3 and smoothMove.Unit or Vector3.zero
	elseif curMag < 0.02 then
		newDir = raw.Unit
		newMag = math.min(rawMag, curMag + dt / M.AccelTime)
	else
		local cu = smoothMove.Unit
		local ang = math.deg(math.acos(math.clamp(cu:Dot(raw.Unit), -1, 1)))
		if ang > M.ReverseAngle then
			-- brake through standing, then start the other way
			newDir = cu
			newMag = math.max(0, curMag - dt / M.DecelTime)
		else
			newDir = rotateToward(cu, raw.Unit, turnRate * dt)
			if curMag < rawMag then newMag = math.min(rawMag, curMag + dt / M.AccelTime)
			else newMag = math.max(rawMag, curMag - dt / M.DecelTime) end
		end
	end
	smoothMove = newDir * newMag
	momentumActive = true
	hum:Move(smoothMove, false)
end

-- // lean (every body) -------------------------------------------------------------------------------------------------------
local bodies = {} -- [Model] = { v, a, pitch, roll, yaw, ik = {...} }  (strong keys, cleared when the body leaves)

local function weaponRaised(model: Model): boolean
	local tool = model:FindFirstChildOfClass("Tool")
	if not (tool and tool:GetAttribute("WeaponId")) then return false end
	if model == character then
		local Cam = ctl("CameraController")
		return Cam ~= nil and Cam.IsFacingCamera ~= nil and Cam.IsFacingCamera()
	end
	return model:GetAttribute("AimRaised") == true
end

local function bodyList(): { Model }
	local list = {}
	for _, p in Players:GetPlayers() do
		if p.Character then table.insert(list, p.Character) end
	end
	for _, m in CollectionService:GetTagged("Bot") do
		if m:IsA("Model") and m.Parent then table.insert(list, m) end
	end
	return list
end

local function stepLean(model: Model, b, r: BasePart, dt: number)
	local v = r.AssemblyLinearVelocity * FLAT
	local raw = b.v and (v - b.v) / math.max(dt, 1 / 240) or Vector3.zero
	b.v = v
	b.a = (b.a or Vector3.zero):Lerp(raw, alpha(LN.AccelFilter, dt))
	local look = r.CFrame.LookVector * FLAT
	if look.Magnitude < 1e-3 then return end
	look = look.Unit
	local right = Vector3.new(-look.Z, 0, look.X)
	local fwdA = b.a:Dot(look)
	local sideA = b.a:Dot(right)
	-- a turn: the velocity swinging round = centripetal acceleration, already in b.a's sideways part
	local wantPitch = math.clamp(fwdA * LN.PitchPerAccel, -LN.MaxPitchBack, LN.MaxPitchForward)
	local wantRoll = math.clamp(sideA * LN.RollPerAccel, -LN.MaxRoll, LN.MaxRoll)
	local hum = model:FindFirstChildOfClass("Humanoid")
	local grounded = hum and hum.FloorMaterial ~= Enum.Material.Air
	local blocked = not grounded or r.Anchored
	if model == character then
		local Cover = ctl("CoverController")
		local Move = ctl("MovementController")
		if (Cover and ((Cover.IsInCover and Cover.IsInCover()) or (Cover.IsMoving and Cover.IsMoving())))
			or (Move and Move.IsSliding and Move.IsSliding()) then blocked = true end
	elseif model:GetAttribute("CoverState") and model:GetAttribute("CoverState") ~= "" then
		blocked = true
	end
	local keep = weaponRaised(model) and LN.AimKeep or 1
	if blocked then keep = 0 end
	local sharp = model == character and LN.Sharpness or LN.RemoteSharpness
	b.pitch = (b.pitch or 0) + (wantPitch * keep - (b.pitch or 0)) * alpha(sharp, dt)
	b.roll = (b.roll or 0) + (wantRoll * keep - (b.roll or 0)) * alpha(sharp, dt)
	if math.abs(b.pitch) < 0.02 and math.abs(b.roll) < 0.02 then return end
	local waist = jointOf(model:FindFirstChild("UpperTorso"), "Waist")
	if waist then
		-- forward lean = pitch down (negative X); roll into the turn (toward the inside = negative Z for a right turn)
		(waist :: any).Transform = (waist :: any).Transform * CFrame.Angles(math.rad(-b.pitch), 0, math.rad(-b.roll))
	end
end

-- // feet (every body near you) ---------------------------------------------------------------------------------------------
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = true

local function makeIK(model: Model, side: string)
	local hum = model:FindFirstChildOfClass("Humanoid")
	local upper, foot = model:FindFirstChild(side .. "UpperLeg"), model:FindFirstChild(side .. "Foot")
	if not (hum and upper and foot) then return nil end
	local target = Instance.new("Attachment")
	target.Name = "MoveFeelFootTarget"
	target.Parent = workspace.Terrain
	local pole = Instance.new("Attachment")
	pole.Name = "MoveFeelKneePole"
	pole.Parent = workspace.Terrain
	local ik = Instance.new("IKControl")
	ik.Name = "MoveFeelIK_" .. side
	ik.Type = Enum.IKControlType.Position
	ik.ChainRoot = upper
	ik.EndEffector = foot
	ik.Target = target
	ik.Pole = pole
	ik.Weight = 0
	ik.Enabled = false
	ik.Parent = hum
	return { ik = ik, target = target, pole = pole, foot = foot, upper = upper }
end

local function dropIK(b)
	if not b.ik then return end
	for _, e in b.ik do
		if e then e.ik:Destroy() e.target:Destroy() e.pole:Destroy() end
	end
	b.ik = nil
end

local function groundY(x: number, z: number, top: number, ignore): number?
	rayParams.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(Vector3.new(x, top, z), Vector3.new(0, -(FT.RayUp + FT.RayDown), 0), rayParams)
	return hit and hit.Position.Y or nil
end

local function stepFeet(model: Model, b, r: BasePart, dt: number, near: boolean)
	local hum = model:FindFirstChildOfClass("Humanoid")
	local speed = (r.AssemblyLinearVelocity * FLAT).Magnitude
	local want = 0
	local drop = 0
	local gL, gR
	if near and hum and hum.Health > 0 and hum.FloorMaterial ~= Enum.Material.Air and not r.Anchored and speed < FT.MaxSpeed then
		local busy = false
		if model == character then
			local Cover = ctl("CoverController")
			local Move = ctl("MovementController")
			busy = (Cover and Cover.IsMoving and Cover.IsMoving()) or (Move and Move.IsSliding and Move.IsSliding()) or false
		end
		local lf, rf = model:FindFirstChild("LeftFoot"), model:FindFirstChild("RightFoot")
		if not busy and lf and rf then
			local floor = r.Position.Y - hum.HipHeight - r.Size.Y * 0.5
			local top = floor + FT.RayUp
			local ignore = { model, workspace.CurrentCamera }
			gL = groundY(lf.Position.X, lf.Position.Z, top, ignore)
			gR = groundY(rf.Position.X, rf.Position.Z, top, ignore)
			if gL and gR then
				local low = math.min(gL, gR)
				local d = floor - low
				if d > FT.MinDrop then
					drop = math.min(d, FT.MaxDrop)
					want = 1
				end
			end
		end
	end
	b.feetW = (b.feetW or 0) + (want - (b.feetW or 0)) * alpha(FT.Sharpness, dt)
	b.drop = (b.drop or 0) + (drop - (b.drop or 0)) * alpha(FT.Sharpness, dt)
	if b.feetW < 0.01 then
		b.feetW, b.drop = 0, 0
		if b.ik then for _, e in b.ik do if e then e.ik.Enabled = false end end end
		return
	end
	-- hips: sink the lower torso so the lower foot reaches its ground
	local rootJoint = jointOf(model:FindFirstChild("LowerTorso"), "Root")
	if rootJoint then
		(rootJoint :: any).Transform = CFrame.new(0, -b.drop * b.feetW, 0) * (rootJoint :: any).Transform
	end
	-- each foot to its own ground
	b.ik = b.ik or { L = makeIK(model, "Left"), R = makeIK(model, "Right") }
	local fwd = r.CFrame.LookVector
	for side, e in b.ik do
		if e then
			local g = side == "L" and gL or gR
			if g then
				local fp = e.foot.Position
				e.target.WorldPosition = Vector3.new(fp.X, g + FT.FootHeight + e.foot.Size.Y * 0.5, fp.Z)
				local knee = (e.upper.Position + fp) * 0.5
				e.pole.WorldPosition = knee + fwd * 2
			end
			e.ik.Weight = b.feetW
			e.ik.Enabled = true
		end
	end
end

local function stepBodies(dt: number)
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or Vector3.zero
	for model, b in bodies do
		if not model.Parent then
			dropIK(b)
			bodies[model] = nil
		end
	end
	local list = bodyList()
	table.sort(list, function(a, c)
		local ra, rc = a:FindFirstChild("HumanoidRootPart"), c:FindFirstChild("HumanoidRootPart")
		local da = ra and (ra.Position - camPos).Magnitude or math.huge
		local dc = rc and (rc.Position - camPos).Magnitude or math.huge
		return da < dc
	end)
	for i, model in list do
		local r = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = model:FindFirstChildOfClass("Humanoid")
		if not r or not hum or hum.Health <= 0 then
			local b = bodies[model]
			if b then dropIK(b) bodies[model] = nil end
			continue
		end
		local b = bodies[model]
		if not b then
			b = {}
			bodies[model] = b
			model.Destroying:Connect(function() local bb = bodies[model] if bb then dropIK(bb) end bodies[model] = nil end)
		end
		local dist = (r.Position - camPos).Magnitude
		if on(LN) and i <= LN.MaxBodies and dist <= LN.MaxDistance then stepLean(model, b, r, dt) end
		if on(FT) then stepFeet(model, b, r, dt, i <= FT.MaxBodies and dist <= FT.MaxDistance) end
	end
end

function controller.Lean(model: Model?): (number, number)
	local b = bodies[model or character]
	return b and b.pitch or 0, b and b.roll or 0
end

-- // camera ----------------------------------------------------------------------------------------------------------------
local applied: CFrame? = nil
local appliedFov = 0
local bobPhase = 0
local fovAdd = 0
local slideShape = 0 -- 0..1
local diveShape = 0
local diveSide = 0
local dip, dipVel = 0, 0
local fallSpeed = 0

local function camUndo()
	local cam = workspace.CurrentCamera
	if not cam then return end
	if applied then cam.CFrame = cam.CFrame * applied:Inverse() end
	if appliedFov ~= 0 then cam.FieldOfView -= appliedFov end
	applied, appliedFov = nil, 0
end

local function scopedNow(Cam): boolean
	if not (Cam and Cam.IsAiming and Cam.IsAiming()) then return false end
	local tool = character and character:FindFirstChildOfClass("Tool")
	local cfg = tool and WeaponConfig.Get(tool:GetAttribute("WeaponId") or "")
	return cfg ~= nil and cfg.AimFOV ~= nil
end

local camWhy = "" -- (Studio test hook: why the last frame did or didn't move the camera)
local function camApply(dt: number)
	applied, appliedFov = nil, 0
	camWhy = "off"
	if not on(CM) or not alive() then
		dip, dipVel, fovAdd, slideShape, diveShape = 0, 0, 0, 0, 0
		return
	end
	local cam = workspace.CurrentCamera
	-- (not CameraSubject: the over-the-shoulder camera never updates it, it can name a body from an earlier life; spectating
	-- only happens while you're dead, and alive() above already stops then)
	if not cam or localPlayer:GetAttribute("Cutscene") then camWhy = "cutscene" return end
	local Cam = ctl("CameraController")
	local Move = ctl("MovementController")
	local Cover = ctl("CoverController")
	local r = root :: BasePart
	local hum = humanoid :: Humanoid
	local reduced = reducedMotion()
	local aiming = Cam and Cam.IsAiming and Cam.IsAiming() or false
	local scoped = scopedNow(Cam)
	local sprinting = Move and Move.IsSprinting and Move.IsSprinting() or false
	local sliding = Move and Move.IsSliding and Move.IsSliding() or false
	local crouched = Move and Move.IsCrouched and Move.IsCrouched() or false
	local diving = Cover and Cover.IsDiving and Cover.IsDiving() or false
	local grounded = hum.FloorMaterial ~= Enum.Material.Air
	local flatV = r.AssemblyLinearVelocity * FLAT
	local speed = flatV.Magnitude

	-- stride bob (one dip per step, from the distance covered)
	local bob, roll = 0, 0
	if grounded and not sliding and not diving and speed > 0.5 then
		bobPhase = (bobPhase + speed * dt / CM.StrideLength * math.pi) % (math.pi * 2)
		local k = math.clamp((speed - 10) / 10, 0, 1)
		local amp = crouched and CM.BobCrouch or (CM.BobWalk + (CM.BobSprint - CM.BobWalk) * k)
		if aiming then amp *= CM.BobAimKeep end
		bob = -amp * math.abs(math.sin(bobPhase))
		roll = (sprinting and CM.BobRollSprint or 0) * math.sin(bobPhase)
	end
	-- landing dip (spring)
	local vy = r.AssemblyLinearVelocity.Y
	if not grounded then
		if -vy > fallSpeed then fallSpeed = -vy end
	elseif fallSpeed > 0 then
		-- a damped spring kicked with velocity v peaks near v / (omega e): kick with e * omega * amount so the dip reaches amount
		if fallSpeed >= CM.LandMinSpeed then dipVel -= math.min(fallSpeed * CM.LandDipPerSpeed, CM.LandDipMax) * CM.DipFrequency * math.exp(1) end
		fallSpeed = 0
	end
	local w = CM.DipFrequency
	dipVel += (-w * w * dip - 2 * CM.DipDamping * w * dipVel) * dt
	dip += dipVel * dt
	dip = math.clamp(dip, -CM.LandDipMax, CM.LandDipMax)
	local nod = math.clamp(-dip / math.max(CM.LandDipMax, 1e-3), 0, 1) * CM.LandPitchMax
	-- FOV and slide / dive shapes
	local wantFov = 0
	if sliding then wantFov = CM.SlideFOV elseif diving then wantFov = CM.DiveFOV elseif sprinting then wantFov = CM.SprintFOV end
	if aiming then wantFov = 0 end
	fovAdd += (wantFov - fovAdd) * alpha(CM.FOVSharpness, dt)
	slideShape += ((sliding and 1 or 0) - slideShape) * alpha(CM.ShapeSharpness, dt)
	if diving and speed > 1 then
		local right = cam.CFrame.RightVector * FLAT
		diveSide = right.Magnitude > 0 and math.clamp(flatV.Unit:Dot(right.Unit), -1, 1) or 0
	end
	diveShape += ((diving and 1 or 0) - diveShape) * alpha(CM.ShapeSharpness, dt)

	camWhy = ("aim %s sprint %s slide %s bob %.3f dip %.3f fov %.2f"):format(tostring(aiming), tostring(sprinting), tostring(sliding), bob, dip, fovAdd)
	if scoped or reduced then
		-- nothing that moves the view; the FOV ease stays off too
		fovAdd = 0
		camWhy ..= " (scoped / reduced)"
		return
	end
	local side = 1
	if Cam and Cam.GetShoulder then local ok, s = pcall(Cam.GetShoulder) if ok and type(s) == "number" and s ~= 0 then side = s end end
	local totalRoll = roll + CM.SlideRoll * slideShape * side + CM.DiveRoll * diveShape * diveSide
	local off = CFrame.new(0, bob + dip - CM.SlideDrop * slideShape, 0)
		* CFrame.Angles(math.rad(-nod), 0, math.rad(-totalRoll))
	cam.CFrame = cam.CFrame * off
	applied = off
	if math.abs(fovAdd) > 0.01 then
		cam.FieldOfView += fovAdd
		appliedFov = fovAdd
	end
end

function controller.CameraOffset(): (CFrame, number)
	return applied or CFrame.identity, appliedFov
end

-- // lifecycle -------------------------------------------------------------------------------------------------------------
local function bindCharacter(newCharacter: Model)
	character = newCharacter
	humanoid = newCharacter:WaitForChild("Humanoid", 10) :: Humanoid?
	root = newCharacter:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	smoothMove = Vector3.zero
	fallSpeed, dip, dipVel = 0, 0, 0
end

function controller.Start()
	if localPlayer.Character then task.spawn(bindCharacter, localPlayer.Character) end
	localPlayer.CharacterAdded:Connect(bindCharacter)
	-- momentum: after Roblox's control script (Input) and the touch stick (Input + 1) wrote this frame's raw input
	RunService:BindToRenderStep("MoveFeelMomentum", Enum.RenderPriority.Input.Value + 2, stepMomentum)
	-- lean + feet: after the Animator wrote this frame's pose (Transform), like the breathing layer
	RunService.Stepped:Connect(function(_, dt)
		if C.Enabled == false then return end
		stepBodies(dt)
	end)
	-- camera: undone first thing next frame (after the breath sway's undo at First), applied after the camera controller
	RawRunService:BindToRenderStep("MoveFeelCameraUndo", Enum.RenderPriority.First.Value + 1, camUndo)
	RunService:BindToRenderStep("MoveFeelCamera", Enum.RenderPriority.Camera.Value + 3, camApply)

	if RawRunService:IsStudio() then
		local hook = Instance.new("BindableFunction")
		hook.Name = "MoveFeelTestHook"
		hook.OnInvoke = function(action, arg)
			if action == "state" then
				local b = character and bodies[character]
				local n = 0
				for _ in bodies do n += 1 end
				return { momentum = momentumActive, move = { smoothMove.X, smoothMove.Z }, pitch = b and b.pitch or 0,
					roll = b and b.roll or 0, feetW = b and b.feetW or 0, drop = b and b.drop or 0, fov = appliedFov,
					cam = applied and { applied.Position.Y, select(3, applied:ToEulerAnglesXYZ()) } or nil, bodies = n, camWhy = camWhy }
			elseif action == "moves" then -- the live controllers' states (the test VM's require gets fresh copies)
				local Move, Cover = ctl("MovementController"), ctl("CoverController")
				local function q(m, f) return m and m[f] and m[f]() or false end
				return { sprint = q(Move, "IsSprinting"), slide = q(Move, "IsSliding"), crouch = q(Move, "IsCrouched"),
					cover = q(Cover, "IsInCover"), moving = q(Cover, "IsMoving"), vault = q(Cover, "IsVaulting"), dive = q(Cover, "IsDiving"),
					style = Cover and Cover.GetMoveStyle and Cover.GetMoveStyle() or nil }
			elseif action == "set" then -- arg = { block, key, value } on the live config (block "" = the top level)
				local t = (arg[1] == "" or arg[1] == nil) and C or C[arg[1]]
				if t then t[arg[2]] = arg[3] end
				return t and t[arg[2]]
			elseif action == "setAF" then -- the body animation pass's live config (AnimFinalConfig), same shape
				local AF = require(Shared.Config:WaitForChild("AnimFinalConfig"))
				local t = (arg[1] == "" or arg[1] == nil) and AF or AF[arg[1]]
				if t and arg[3] ~= nil then t[arg[2]] = arg[3] end
				return t and t[arg[2]]
			end
			return nil
		end
		hook.Parent = localPlayer
	end
end

return controller
