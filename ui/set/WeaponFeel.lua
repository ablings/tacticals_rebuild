-- Client/Controllers/WeaponController/WeaponFeel (ModuleScript) [FEEL] 2026-10-21, Edward: "there are certain bounce and select effects
-- that make changing weapons feel good ... I want everything to look smooth"; "my game should not be fundamentally the same as RIVALS,
-- but I want a similar feel to how items are used" -> RIVALS' viewmodel springs, put on OUR over-the-shoulder body instead of a viewmodel.
-- Your own character only (it's feel; everyone else sees the normal animations). Layered on the animated pose (Motor6D.Transform) in
-- PreSimulation, after the Animator and after AimPoseController (which bends the rest pose, C0), so nothing fights:
--   * EQUIP: RIVALS' equip spring (damper 0.625, speed 12.5): value 1 on equip (0.5 on a quick swap) springing to 0 with a small
--     overshoot; the gun arm swings up from below and rolls into place (RIVALS: -45 deg pitch, 45 deg roll at 1).
--   * SWAY: the arms lag behind camera turns (yaw / pitch rate) and spring back (damper 0.6, speed 11).
--   * BOB: walking / running bobs and rolls the chest a little with your speed.
--   * KICK: each shot kicks the arms up (and the chest back a touch), sized by the gun's Recoil.Pitch; heavy guns kick hardest.
--   * RELOAD: the gun arm rolls up and out for the middle of the reload, then settles with the same spring.
-- API (WeaponController): Equip(config, quick), Unequip(), Kick(config, scoped), Reload(duration), SetGunHand(side)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local feel = {}

-- critically / under-damped spring (Quenty-style, position + velocity), stepped with the exact solution's cheap stand-in
local function spring(d, s)
	return { x = 0, v = 0, target = 0, d = d, s = s }
end
local function step(sp, dt)
	-- semi-implicit damped oscillator: a = s^2 (target - x) - 2 d s v
	local n = math.max(1, math.ceil(dt / (1 / 240)))
	local h = dt / n
	for _ = 1, n do
		local a = sp.s * sp.s * (sp.target - sp.x) - 2 * sp.d * sp.s * sp.v
		sp.v += a * h
		sp.x += sp.v * h
	end
	return sp.x
end

local equipS = spring(0.625, 12.5)                   -- RIVALS _equip_spring
local swayYaw, swayPitch = spring(0.6, 11), spring(0.6, 11)
local kickS = spring(0.5, 16)                        -- recoil (impulse into v)
local reloadS = spring(0.7, 9)
local gunSide = 1                                   -- 1 = gun in the right hand, -1 = left
local active = false
local reloadUntil, reloadStart = 0, 0
local lastLook: Vector3? = nil
local bobT = 0

local SETTINGS = { -- degrees at value 1
	EquipPitch = -45, EquipRoll = 45,
	SwayYaw = 0.9, SwayPitch = 0.7, SwayMax = 9,      -- degrees of lag per degree/frame-ish of turn, clamped
	BobPitch = 1.6, BobRoll = 1.2,
	KickPitch = 6, KickChest = 1.5,
	ReloadRoll = 28, ReloadPitch = 12,
}

function feel.SetGunHand(side: number)
	gunSide = (side == -1) and -1 or 1
end

function feel.Equip(config, quick: boolean?)
	active = true
	equipS.x, equipS.v = quick and 0.5 or 1, 0
	reloadUntil = 0
	reloadS.target = 0
	-- a small camera kick as it comes up (RIVALS' equip settle)
	local Camera = shared.Get and shared.Get("CameraController")
	if Camera and Camera.AddRecoil then pcall(Camera.AddRecoil, quick and 0.25 or 0.5, 0, 6) end
end

function feel.Unequip()
	active = false
	reloadUntil = 0
end

function feel.Kick(config, scoped: boolean?)
	if not active then return end
	local pitch = (config and config.Recoil and config.Recoil.Pitch) or 1.5
	local k = math.clamp(pitch / 2, 0.4, 2.2) * (scoped and 0.4 or 1)
	kickS.v += 9 * k
end

function feel.Reload(duration: number)
	if not active then return end
	reloadStart, reloadUntil = os.clock(), os.clock() + math.max(duration, 0.2)
end

local function joint(character: Model, part: string, name: string): Instance?
	local p = character:FindFirstChild(part)
	local m = p and p:FindFirstChild(name)
	return (m and (m:IsA("Motor6D") or m:IsA("AnimationConstraint"))) and m or nil
end

-- layer an offset on a joint's animated pose. If nothing re-animated the joint since our last write (no track drives it), take our
-- previous offset back out first, so it never compounds frame over frame.
local written = setmetatable({}, { __mode = "k" }) -- [joint] = { cf = what we wrote, off = the offset in it }
local function layer(j: Instance?, off: CFrame)
	if not j then return end
	local cur = (j :: any).Transform
	local w = written[j]
	local base = (w and cur == w.cf) and (w.cf * w.off:Inverse()) or cur
	local out = base * off
	;(j :: any).Transform = out
	written[j] = { cf = out, off = off }
end

local function onStep(_, dt)
	dt = math.min(dt, 1 / 20)
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local cam = workspace.CurrentCamera
	if not character or not humanoid or humanoid.Health <= 0 or not cam then lastLook = nil return end

	-- sway from the camera's turn rate (degrees this frame)
	local look = cam.CFrame.LookVector
	local yawRate, pitchRate = 0, 0
	if lastLook then
		local flatA = Vector3.new(lastLook.X, 0, lastLook.Z)
		local flatB = Vector3.new(look.X, 0, look.Z)
		if flatA.Magnitude > 0.01 and flatB.Magnitude > 0.01 then
			local a, b = flatA.Unit, flatB.Unit
			yawRate = math.deg(math.atan2(a:Cross(b).Y, a:Dot(b)))
		end
		pitchRate = math.deg(math.asin(math.clamp(look.Y, -1, 1)) - math.asin(math.clamp(lastLook.Y, -1, 1)))
	end
	lastLook = look
	local frameScale = (1 / 60) / math.max(dt, 1e-3) -- the same lag at any frame rate
	swayYaw.target = active and math.clamp(-yawRate * frameScale * SETTINGS.SwayYaw, -SETTINGS.SwayMax, SETTINGS.SwayMax) or 0
	swayPitch.target = active and math.clamp(-pitchRate * frameScale * SETTINGS.SwayPitch, -SETTINGS.SwayMax, SETTINGS.SwayMax) or 0

	-- reload: roll the gun up and out through the middle of the reload
	local now = os.clock()
	if active and now < reloadUntil then
		local t = (now - reloadStart) / math.max(reloadUntil - reloadStart, 0.01)
		reloadS.target = (t > 0.08 and t < 0.75) and 1 or 0
	else
		reloadS.target = 0
	end

	local e = step(equipS, dt)
	local sy, sp = step(swayYaw, dt), step(swayPitch, dt)
	local k = step(kickS, dt)
	local r = step(reloadS, dt)

	-- bob with movement speed
	local speed = (humanoid.RootPart and (humanoid.RootPart.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude) or 0
	local moving = active and humanoid.MoveDirection.Magnitude > 0.1 and speed > 1
	bobT += dt * (moving and (4 + speed * 0.35) or 0)
	local bobAmt = moving and math.clamp(speed / 16, 0, 1.4) or 0
	local bobP = math.sin(bobT * 2) * SETTINGS.BobPitch * bobAmt
	local bobR = math.sin(bobT) * SETTINGS.BobRoll * bobAmt

	local settled = not active and math.abs(e) < 1e-3 and math.abs(sy) < 0.05 and math.abs(sp) < 0.05 and math.abs(k) < 0.05 and math.abs(r) < 1e-3

	local gunArm = joint(character, gunSide > 0 and "RightUpperArm" or "LeftUpperArm", gunSide > 0 and "RightShoulder" or "LeftShoulder")
	local offArm = joint(character, gunSide > 0 and "LeftUpperArm" or "RightUpperArm", gunSide > 0 and "LeftShoulder" or "RightShoulder")
	local waist = joint(character, "UpperTorso", "Waist")

	if settled then -- back to exactly the animated pose (one identity write takes out a leftover offset), then idle
		if next(written) then
			for j in written do layer(j, CFrame.identity) end
			table.clear(written)
		end
		return
	end
	local pitch = SETTINGS.EquipPitch * e + sp + SETTINGS.KickPitch * k + SETTINGS.ReloadPitch * r + bobP
	local yaw = sy
	local roll = (SETTINGS.EquipRoll * e + SETTINGS.ReloadRoll * r) * gunSide + bobR
	local gunRot = CFrame.Angles(math.rad(pitch), math.rad(yaw), math.rad(roll))
	-- the support hand follows most of the gun's motion (two-handed hold), less of the equip roll / reload
	local offRot = CFrame.Angles(math.rad(pitch * 0.7), math.rad(yaw * 0.8), math.rad(roll * 0.35))
	layer(gunArm, gunRot)
	layer(offArm, offRot)
	layer(waist, CFrame.Angles(math.rad(-SETTINGS.KickChest * k + bobP * 0.4), math.rad(sy * 0.25), math.rad(bobR * 0.5)))
end

RunService.PreSimulation:Connect(onStep)

return feel
