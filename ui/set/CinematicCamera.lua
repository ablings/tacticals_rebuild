local __TG = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("TrainingGate"))
-- StarterPlayer/StarterPlayerScripts/Client/Controllers/CinematicCamera (ModuleScript)
-- Cinematic camera moves layered on top of the normal camera. Everything here is a spring or a
-- smooth curve, so nothing snaps:
--   Moves   : vault / dash / roll / sneak / sprint / slide each pull the camera back, low and to the side
--   Bob     : a stride bob while sprinting, a soft sway while walking
--   Breath  : out of stamina = heavy breathing - the view heaves up/down and rolls a touch, and the FOV
--             pulses; it settles as stamina returns. A faint breath sway stays while aiming.
--   Kicks   : firing punches the camera back; aiming in gives a small FOV overshoot; landing from a
--             fall / vault dips; taking a hit jolts
-- Runs after CameraController (RenderPriority Camera + 4).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
RunService = __TG.RunService

local Get = shared.Get
local localPlayer = Players.LocalPlayer
local controller = {}

-- target offsets per move: { back, down, side lag, roll (deg), fov }
local PROFILES = {
	Vault = { back = 1.6, down = 0.9, side = 0, roll = 4, fov = 8 },
	Dash = { back = 1.4, down = 0.6, side = 0.7, roll = 2, fov = 7 },
	Roll = { back = 1.8, down = 1.0, side = 0.4, roll = 7, fov = 9 },
	Sneak = { back = -0.4, down = 0.7, side = 0, roll = 0, fov = -3 },
	Sprint = { back = 1.0, down = 0.3, side = 0.4, roll = 1.5, fov = 6 },
	Slide = { back = 1.2, down = 1.6, side = 0.3, roll = 6, fov = 9 },
}
local NONE = { back = 0, down = 0, side = 0, roll = 0, fov = 0 }

local current = { back = 0, down = 0, side = 0, roll = 0, fov = 0 }
local velocity = { back = 0, down = 0, side = 0, roll = 0, fov = 0 }
local lastStyle = nil
local landingKick = 0
local fireKick = 0        -- punch from your own shot
local hitKick = 0         -- jolt from taking damage
local aimPunch = 0        -- FOV overshoot when you aim in
local wasAiming = false
local breath = 0          -- 0 = calm, 1 = gasping
local breathPhase = 0
local bobPhase = 0
local bobAmt, breathCalm = 0, 0 -- [SET] eased bob size; 1 = standing still (the winded heave fades)
local lastHealth = nil
local lastFloor = nil
local airTime = 0

local function spring(key: string, target: number, dt: number, stiffness: number, damping: number)
	local x, v = current[key], velocity[key]
	local a = (target - x) * stiffness - v * damping
	v += a * dt
	x += v * dt
	current[key], velocity[key] = x, v
end

local function update(dt: number)
	dt = math.min(dt, 1 / 30)
	local Cover = Get("CoverController")
	local Movement = Get("MovementController")
	local Camera = Get("CameraController")
	if not Cover then return end
	local character = localPlayer.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local alive = hum and hum.Health > 0
	local cam = workspace.CurrentCamera

	-- // which move we're in
	local style = Cover.GetMoveStyle and Cover.GetMoveStyle() or nil
	if not style and Movement then
		if Movement.IsSliding and Movement.IsSliding() then style = "Slide"
		elseif Movement.IsSprinting and Movement.IsSprinting() then style = "Sprint" end
	end
	local profile = (style and PROFILES[style]) or NONE
	if lastStyle == "Vault" and style ~= "Vault" then landingKick = 1 end
	lastStyle = style

	-- // landing from a fall / jump
	if hum and alive then
		local inAir = hum.FloorMaterial == Enum.Material.Air
		if inAir then airTime += dt
		else
			if lastFloor == false and airTime > 0.25 then landingKick = math.max(landingKick, math.clamp(airTime * 1.6, 0.4, 1.3)) end
			airTime = 0
		end
		lastFloor = not inAir
	end

	-- // taking a hit
	if hum and alive then
		if lastHealth and hum.Health < lastHealth - 0.5 then hitKick = math.min(1, hitKick + math.clamp((lastHealth - hum.Health) / 40, 0.25, 1)) end
		lastHealth = hum.Health
	else
		lastHealth = nil
	end

	-- // aim in: a quick overshoot
	local aiming = Camera and Camera.IsAiming and Camera.IsAiming() or false
	if aiming and not wasAiming then aimPunch = 1 end
	wasAiming = aiming

	-- // breathing: how winded are we?
	local stamina = Movement and Movement.GetStamina and Movement.GetStamina() or 100
	local winded = math.clamp(1 - stamina / 45, 0, 1) -- starts showing under 45 stamina, full at 0
	breath += (winded - breath) * math.clamp(dt * (winded > breath and 2.5 or 0.6), 0, 1) -- gasps come on fast, calm slowly
	local rate = 1.1 + breath * 1.3 -- breaths per second: calm 1.1, gasping 2.4
	breathPhase += dt * rate * math.pi * 2
	-- [SET] (Edward: "the running bob stays after you stop") the winded heave read as a bob that never ends: it is now a
	-- faint sway, nearly no roll / FOV pulse, and it eases out while you stand still
	local still = (root and (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude or 0) < 1
	breathCalm += ((still and 1 or 0) - breathCalm) * math.clamp(dt * 3, 0, 1)
	local windedShown = breath * (1 - 0.8 * breathCalm)
	local breathAmt = 0.02 + windedShown * 0.1 -- studs of heave
	if aiming then breathAmt *= 0.45 end
	local heave = math.sin(breathPhase) * breathAmt
	local breathRoll = math.sin(breathPhase * 0.5 + 1) * windedShown * 0.3
	local breathFov = math.sin(breathPhase) * windedShown * 0.5

	-- // stride bob
	local speed = root and (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude or 0
	local onFoot = alive and not Cover.IsInCover() and not (Cover.IsMoving and Cover.IsMoving()) and hum.FloorMaterial ~= Enum.Material.Air
	local bobWant = 0
	if onFoot and speed > 2 then
		bobPhase += dt * (speed / 1.9) -- one stride per ~1.9 studs
		bobWant = style == "Sprint" and 0.22 or 0.07
		if style == "Slide" then bobWant = 0 end
	end
	-- [SET] ease in / out (fast out): the bob settles to zero the moment you stop or stop sprinting
	bobAmt += (bobWant - bobAmt) * math.clamp(dt * (bobWant < bobAmt and 12 or 6), 0, 1)
	if bobAmt < 0.002 and bobWant == 0 then bobAmt = 0 end
	local bobY = math.abs(math.sin(bobPhase)) * bobAmt
	local bobX = math.sin(bobPhase * 0.5) * bobAmt * 0.6

	-- decay the kicks
	landingKick = math.max(0, landingKick - dt * 4)
	fireKick = math.max(0, fireKick - dt * 9)
	hitKick = math.max(0, hitKick - dt * 3)
	aimPunch = math.max(0, aimPunch - dt * 6)

	-- which side to lag toward: the move direction relative to the camera
	local sideSign = 0
	local dir = Cover.GetMoveDirection and Cover.GetMoveDirection()
	if not dir and root and speed > 1 then dir = root.AssemblyLinearVelocity.Unit end
	if dir then sideSign = dir:Dot(cam.CFrame.RightVector) >= 0 and 1 or -1 end

	spring("back", profile.back + fireKick * 0.35, dt, 40, 11)
	spring("down", profile.down + landingKick * 0.6, dt, 50, 12)
	spring("side", profile.side * -sideSign, dt, 30, 10)
	spring("roll", profile.roll * sideSign, dt, 45, 11)
	spring("fov", profile.fov - aimPunch * 4 + fireKick * 2.5, dt, 35, 10)

	-- hit jolt: a sharp random shake that dies quickly
	local t = os.clock() * 55
	local jolt = hitKick * hitKick
	local joltX = math.noise(t, 2.2) * 2.4 * jolt
	local joltY = math.noise(t, 6.8) * 2.4 * jolt
	local joltZ = math.noise(t, 4.1) * 1.6 * jolt

	local offX = current.side + bobX
	local offY = -current.down + heave + bobY
	local offZ = current.back
	local roll = -current.roll + breathRoll + joltZ
	local pitch = (heave * 0.6) + joltX + landingKick * 1.2
	local yaw = joltY

	-- looking through a scope, the scope does its own motion (ScopeController): these moves fade out
	local Scope = Get("ScopeController")
	local scoped = 1 - math.clamp((Scope and Scope.Blend and Scope.Blend()) or 0, 0, 1)
	offX, offY, offZ = offX * scoped, offY * scoped, offZ * scoped
	roll, pitch, yaw = roll * scoped, pitch * scoped, yaw * scoped
	local fovAdd = (current.fov + breathFov) * scoped

	if math.abs(offX) + math.abs(offY) + math.abs(offZ) + math.abs(roll) + math.abs(pitch) + math.abs(yaw) + math.abs(fovAdd) < 0.003 then return end
	cam.CFrame = cam.CFrame
		* CFrame.new(offX, offY, offZ)
		* CFrame.Angles(math.rad(pitch), math.rad(yaw), math.rad(roll))
	cam.FieldOfView = math.clamp(cam.FieldOfView + fovAdd, scoped < 0.99 and 5 or 30, 100)
end

-- Your own shot: a short punch (called by WeaponController)
function controller.Kick(strength: number?)
	fireKick = math.min(1.5, fireKick + (strength or 1))
end

function controller.Start()
	RunService:BindToRenderStep("CinematicCamera", Enum.RenderPriority.Camera.Value + 4, update)
end

return controller
